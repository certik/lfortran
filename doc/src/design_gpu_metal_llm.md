# Metal ↔ Fortran `do concurrent` side by side: the qwen3.6 kernels

Status: companion to `design_gpu_offloading.md`
Date: 2026-08-31

This document takes each hand-optimized Metal kernel from
`certik/qwen3.6/src-metal/kernels/` (Qwen3.6-35B-A3B inference on Apple
GPUs: 103 tok/s on M4 Max, +22–46% over MLX, ~60% of peak DRAM bandwidth
per its `PERF.md`) and shows the pure-Fortran `do concurrent` code a user
would write, plus the contract LFortran must fulfill to generate the
equivalent Metal. Unified memory is assumed throughout (Apple), so data
movement is a non-issue; the whole game is kernel quality and launch
orchestration.

Model dimensions used below: `H = 2048` (hidden), attention `Dh = 256`,
`Nq = 16` query heads, `Nkv = 4` KV heads, DeltaNet `Dk = 128`,
`Hv = 32`, `Dv = 128`, experts `E = 256` (top `K_top = 8`),
vocab `V = 248320`, q8 quantization group size 64.

Conventions: `bf` is a bfloat16 real kind (`real(bf)` — an LFortran
extension to add), `sp` is `real32`. All kernels load bf16 and
**accumulate in fp32**, exactly as the Metal does; the DeltaNet state is
fp32 in both. C row-major `X[m][k]` becomes Fortran `x(k, m)` — the
contiguous (first) index is the one lanes stride over, which is also the
coalescing-friendly choice.

The one decode-performance fact to keep in mind (from `PERF.md`): the
`linear_q8` family is ~77% of GPU time, and the model is 16× left of the
roofline ridge — ALUs are 28× over-provisioned. Getting the *memory
access pattern* of each Fortran-generated kernel identical to the
hand-written one is the entire performance story; instruction selection
is nearly irrelevant.

---

## 1. Elementwise ops (`elemwise.metal`, `glue.metal`, `rope_partial.metal`)

The easy tier: one thread per element, no cooperation. This is what
LFortran's existing `--gpu=metal` thread mapping already does.

**Metal (`silu_mul_bf16`):**

```c
kernel void silu_mul_bf16(device const bfloat* gate, device const bfloat* up,
                          device bfloat* out, constant n_param& p,
                          uint i [[thread_position_in_grid]]) {
    if (i >= p.N) return;
    out[i] = bfloat(silu_f(float(gate[i])) * float(up[i]));
}
```

**Fortran:**

```fortran
elemental pure real(sp) function silu(x)
  real(sp), intent(in) :: x
  silu = x / (1.0_sp + exp(-x))
end function

do concurrent (i = 1:n)
  h(i) = real(silu(real(gate(i), sp)) * real(up(i), sp), bf)
end do
```

Or simply the array expression `h = real(silu(real(gate,sp))*real(up,sp), bf)`.

**Compiler contract:**
- Thread mapping, `grid = n`, tail guard — already implemented.
- The elemental pure function inlines into the kernel (purity gate from
  the main design).
- Whole-array expressions and assignments between kernels must *also*
  become device kernels — a forward pass written in idiomatic Fortran
  mixes `do concurrent` with array assignments, and any array statement
  that falls back to host serializes the token step. (This is the
  Fortran analogue of `glue.metal`, whose only purpose is keeping
  trivial host-side arithmetic on the GPU; that one change was worth
  19 → 34 tok/s.)

The fused variants (`shared_expert_combine_add_bf16`:
`x = x + moe + sigmoid(sg_scalar) * sd`; RoPE's paired rotation) are the
same pattern — a `do concurrent (d, l)` with a few lines of scalar math,
including gathers like `sd(d, l)` indexed by a per-`l` scalar.

---

## 2. RMSNorm (`rmsnorm.metal`) — the cooperative-mapping "hello world"

**Metal (abridged; SG-per-row variant):** one SIMD group (32 lanes) per
row; lanes stride the row with `bfloat4` loads; `simd_sum` reduces the
sum of squares; then lanes stride again to scale.

```c
kernel void rmsnorm_bf16(...) {
    uint m = tg;                       // one threadgroup (= 1 SG) per row
    float sq = 0.0f;
    for (uint dv = lane; dv < Dvec; dv += 32)   // bfloat4 chunks
        { float4 v = float4(xrow4[dv]); sq += dot(v, v); }
    sq = simd_sum(sq);
    float rrms = rsqrt(sq / float(D) + p.eps);
    for (uint dv = lane; dv < Dvec; dv += 32)
        yrow4[dv] = bfloat4(float4(xrow4[dv]) * rrms * float4(W4[dv]));
}
```

A second variant (`rmsnorm_bf16_msg`, 8 SGs per row with a
threadgroup-memory merge of the partial sums) exists solely because at
decode `M = 1`: one SG per row would launch a single SG and leave the
GPU idle. Switching decode-shaped sites to it was worth +16%.

**Fortran (one version, both mappings):**

```fortran
pure subroutine rmsnorm(y, x, w, eps)
  real(bf), intent(out) :: y(:,:)          ! (D, M)
  real(bf), intent(in)  :: x(:,:), w(:)
  real(sp), intent(in)  :: eps
  real(sp) :: rrms
  integer :: m
  do concurrent (m = 1:size(x, 2)) local(rrms)
    rrms = 1.0_sp / sqrt(sum(real(x(:,m), sp)**2) / size(x,1) + eps)
    y(:,m) = real(real(x(:,m), sp) * rrms * real(w, sp), bf)
  end do
end subroutine
```

**Compiler contract:**
- The body contains a reduction intrinsic (`sum`) over data indexed by
  the concurrent variable → select the **cooperative mapping**: one
  iteration per SIMD group, `sum` lowered to a lane-strided loop +
  `simd_sum`, the array assignment to a lane-strided store loop.
  (Fortran's reduction intrinsics have processor-defined association
  order, so lane-parallel evaluation is legal without any fast-math
  flag — one reason to prefer `sum`/`dot_product`/`maxval` in bodies
  over hand-written accumulation loops.)
- **Granularity by occupancy**: iterations ≥ ~number of SGs the GPU can
  run → 1 SG per iteration; iterations small (decode: `M = 1`) → one
  threadgroup of `N_SG` SGs per iteration, partial `simd_sum`s merged
  through threadgroup memory. Same ASR, two schedules; the choice is a
  launch-time decision from `M` and `D`. `N_SG` is a tunable (8 won
  here; found by sweep — an autotuning hook, not a formula).
- 4-wide vectorized loads (`bfloat4`) whenever the strided access is
  contiguous and `D % 4 == 0` — a pure codegen concern.

This single kernel shape (row reduction → broadcast scalar → row map)
also covers `softmax_topk.metal` (router: `maxval`, `exp`, `sum`, then a
K-iteration masked-`maxloc` top-k, all in registers of one SG) and
`argmax.metal`.

---

## 3. The workhorse: q8 GEMV (`linear_q8.metal`) — 77% of GPU time

**Metal (structure):** one SIMD group computes `K_OUT = 4` consecutive
outputs. Lanes stride the K dimension in `uint4` steps (16 packed q8
weights, which always share one quantization group, so one scale/bias
pair serves 16 weights); the input row `x` is loaded once into registers
and reused for all 4 outputs; 4 running accumulators; 4 `simd_sum`s at
the end. See the file for the full 100 lines; the essential loop:

```c
for (uint u4 = lane; u4 < K/16; u4 += 32) {
    float4 x0..x3 = load 16 x values;          // reused across outputs
    uint g = u4 >> 2;                          // quant group of this uint4
    for (uint o = 0; o < 4; ++o) {             // register tile: 4 outputs
        uint4 wv = w_rows4[o][u4];             // 16 q8 weights, one load
        float s = s_rows[o][g], b = b_rows[o][g];
        acc[o] += dot(x0, deq(wv.x,s,b)) + ... + dot(x3, deq(wv.w,s,b));
    }
}
for (o...) { float r = simd_sum(acc[o]); if (lane==0) Y[..] = r; }
```

**Fortran:** weights stored as they are on disk — packed unsigned bytes
plus per-group scale/bias:

```fortran
! wq(K, N) : integer(int8) q8 weights (unsigned bytes)
! s(K/64, N), b(K/64, N) : real(bf) per-group scale / bias
pure subroutine linear_q8(y, wq, s, b, x)
  real(bf),      intent(out) :: y(:,:)         ! (N, M)
  integer(int8), intent(in)  :: wq(:,:)        ! (K, N)
  real(bf),      intent(in)  :: s(:,:), b(:,:), x(:,:)   ! x(K, M)
  real(sp) :: acc
  integer  :: n, m, g, k0, gs
  gs = 64
  do concurrent (n = 1:size(y,1), m = 1:size(y,2)) local(acc, g, k0)
    acc = 0.0_sp
    do g = 1, size(wq,1)/gs
      k0 = (g-1)*gs
      acc = acc + sum((real(iand(int(wq(k0+1:k0+gs, n), int32), 255), sp) &
                       * real(s(g,n), sp) + real(b(g,n), sp))             &
                      * real(x(k0+1:k0+gs, m), sp))
    end do
    y(n,m) = real(acc, bf)
  end do
end subroutine
```

**Compiler contract:**
- Cooperative mapping again (body reduces over `K`): SG per iteration,
  the `g`/`sum` nest flattened into one lane-strided K loop with
  `simd_sum` at the end. The group structure is visible in the source
  (scale/bias indexed by `g`, data by `k0+…`), so assigning each lane
  16-byte-aligned chunks *within* a group — the exact `uint4` trick —
  falls out of contiguity analysis rather than pattern magic.
- **Register tiling across outputs (`K_OUT = 4`)**: unroll-and-jam of
  the `n` dimension — one SG takes 4 adjacent `n`, hoists the
  `x(:, m)` loads out of the per-output work, keeps 4 accumulators.
  This is a classic loop transformation (legal here because iterations
  are independent by construction); the win is cutting `x` bandwidth 4×
  and amortizing loop overhead. `PERF.md` data: the uint4 + register
  tile combination was +18.7%; `K_OUT = 8` *regressed* — tile size is a
  tunable, not a constant.
- Byte-unpack idioms (`iand(int(w,int32),255)`, shifts) must map to the
  packed-load + extract forms; q8 stays `integer(int8)` in the
  language, no new types needed.
- The MoE variant (`linear_q8_gather_bf16`) is the same loop with the
  weight matrix selected per iteration:
  `e = expert_ids(kt, l)` then `wq(:, :, e)` — a per-iteration gather
  off a device array, already expressible; nothing new for the
  compiler beyond 3-D concurrent heads `(n, kt, l)`.

A negative result worth encoding as a heuristic: staging `x` in
threadgroup memory (the classic CUDA move) **regressed** on Apple
silicon — the shared L1/L2 already serves cross-SG reuse, and the
barrier cost exceeds the saved bandwidth. On this hardware, prefer
registers + cache over threadgroup memory for read-shared operands.

---

## 4. Attention (`sdpa_gqa.metal`) — online softmax across SIMD groups

**Metal (structure):** one threadgroup of `N_SG = 20` SGs per
`(lq, hq)`; the key range is split into contiguous stripes, one per SG;
each SG runs single-pass **online softmax** (running `m, s`, per-lane
output stripe `o`), with the Q·K phase 8-way unrolled for ILP; causal
masking is hoisted into the loop bound (`eff_Lk = min(Lk, q_abs+1)`);
finally the 20 partial `(m, s, o)` triples merge through threadgroup
memory with the standard rescaling
`m_g = max(m_i); o = Σ exp(m_i−m_g)·o_i / Σ exp(m_i−m_g)·s_i`.

**Fortran:** written as the *mathematical* two-pass form — no online
softmax in the source:

```fortran
pure subroutine sdpa_gqa(o, q, kc, vc, q_off, scale, causal)
  real(bf), intent(out) :: o(:,:,:)            ! (Dh, Nq, Lq)
  real(bf), intent(in)  :: q(:,:,:)            ! (Dh, Nq, Lq)
  real(bf), intent(in)  :: kc(:,:,:), vc(:,:,:)  ! (Dh, Nkv, Lk)
  integer,  intent(in)  :: q_off
  real(sp), intent(in)  :: scale
  logical,  intent(in)  :: causal
  real(sp) :: qv(size(q,1)), acc(size(q,1))
  real(sp) :: sc(size(kc,3)), w(size(kc,3)), mx
  integer  :: hq, lq, hkv, nk, lk
  do concurrent (hq = 1:size(q,2), lq = 1:size(q,3)) &
      local(qv, acc, sc, w, mx, hkv, nk, lk)
    hkv = (hq-1) / (size(q,2)/size(kc,2)) + 1
    nk  = size(kc,3)
    if (causal) nk = min(nk, q_off + lq)
    qv  = real(q(:, hq, lq), sp)
    do lk = 1, nk
      sc(lk) = scale * dot_product(qv, real(kc(:, hkv, lk), sp))
    end do
    mx = maxval(sc(1:nk))
    w(1:nk) = exp(sc(1:nk) - mx)
    acc = 0.0_sp
    do lk = 1, nk
      acc = acc + w(lk) * real(vc(:, hkv, lk), sp)
    end do
    o(:, hq, lq) = real(acc / sum(w(1:nk)), bf)
  end do
end subroutine
```

**Compiler contract:**
- **The flash/online-softmax rewrite.** The body is the canonical
  softmax-weighted-sum: scores over an axis, `maxval`, `exp(· − max)`,
  weighted accumulation, divide by `sum`. Recognize it and rewrite to
  the single-pass online recurrence — which (a) eliminates the
  `sc`/`w` locals entirely (they are runtime-sized workspaces
  otherwise; the existing `GpuVlaWorkspace` machinery could allocate
  them, but the rewrite makes that unnecessary and is the difference
  between streaming K/V once vs. twice), and (b) makes the `lk` range
  **splittable across SGs**, because the online form has an exact
  associative merge. This is the one genuinely nontrivial pattern
  rewrite in the whole file set — it is local to a single loop body,
  well-defined, and worth it: attention is the only kernel here whose
  memory traffic grows with context.
- Multi-SG scheduling: stripe `nk` over `N_SG` SGs per iteration, merge
  through threadgroup memory. Same occupancy logic as rmsnorm's msg
  variant; `N_SG = 20` was found by sweep (12 worse, 16/24/28 ties) —
  autotuning hook again.
- The causal bound hoist comes for free: the Fortran already expresses
  it as the loop bound `nk`, not a per-`lk` mask. (Worth documenting as
  the *recommended* way to write masks: bounds, not `if`s, when
  possible; the standard's `do concurrent` mask clause can lower to a
  bound when the mask is monotone in an index.)
- 8-way ILP unrolling of the score loop and register-caching `qv` are
  scheduling details downstream of the rewrite (independent reduction
  chains → unroll; loop-invariant per-iteration array → registers).

---

## 5. DeltaNet recurrence (`gated_delta_step.metal`) — fp32 state

**Metal (structure):** one SG per `(hv, dv)`; each lane owns
`Dk/32 = 4` fp32 state elements in registers; gain-scale, `simd_sum`
dot with `k`, delta update written back, second `simd_sum` dot with `q`.

**Fortran:**

```fortran
pure subroutine gated_delta_step(y, state, q, k, v, g, beta)
  real(bf), intent(out)   :: y(:,:)            ! (Dv, Hv)
  real(sp), intent(inout) :: state(:,:,:)      ! (Dk, Dv, Hv)  fp32!
  real(bf), intent(in)    :: q(:,:), k(:,:)    ! (Dk, Hk)
  real(bf), intent(in)    :: v(:,:)            ! (Dv, Hv)
  real(bf), intent(in)    :: g(:), beta(:)     ! (Hv)
  real(sp) :: st(size(state,1)), kv, delta
  integer  :: hv, dv, hk
  do concurrent (hv = 1:size(y,2), dv = 1:size(y,1)) &
      local(st, kv, delta, hk)
    hk    = (hv-1) / (size(y,2)/size(q,2)) + 1
    st    = state(:, dv, hv) * real(g(hv), sp)
    kv    = dot_product(st, real(k(:, hk), sp))
    delta = (real(v(dv,hv), sp) - kv) * real(beta(hv), sp)
    st    = st + real(k(:, hk), sp) * delta
    state(:, dv, hv) = st
    y(dv, hv) = real(dot_product(st, real(q(:, hk), sp)), bf)
  end do
end subroutine
```

The token loop around this stays an ordinary sequential `do` — the
recurrence over time is inherently serial, and expressing exactly the
per-token parallelism (`Hv·Dv = 4096` independent SGs; the optimization
that took this kernel 5 → 15 tok/s) is precisely what `do concurrent`
over `(hv, dv)` says.

**Compiler contract:** nothing new — cooperative SG mapping,
`dot_product` → lane stripe + `simd_sum`, and the constant-size
`local` array `st(Dk)` distributed across lane registers
(`Dk/32` elements per lane) instead of threadgroup memory. Mixed
precision is expressed directly by the declarations (fp32 state,
bf16 activations), matching the Metal exactly.

---

## 6. Sampling (`argmax.metal`) — no `do concurrent` at all

**Metal:** two-stage parallel argmax over the 248k-entry vocab
(strided per-thread scan, `simd_max` + ballot, threadgroup merge;
second stage reduces the 64 threadgroup winners).

**Fortran:**

```fortran
next_token = maxloc(logits, dim=1)
```

**Compiler contract:** device lowering of reduction *intrinsics* on
resident arrays — `maxloc`'s first-occurrence tie-break is exactly what
the Metal's ballot + `ctz` implements. Parallelizing this intrinsic was
worth 2.4 → 4.4 tok/s at the time it was done; a serial fallback on a
248k vector dominates a decode step.

---

## 7. The host side: one command buffer per token, barriers by dependence

`main.c` spends as much cleverness outside the kernels as inside:
every dispatch of a token step is encoded into **one command buffer**
(no CPU round-trips mid-step — eliminating those was 19 → 34 tok/s), a
**concurrent encoder** with explicit barriers only between dependent
kernels lets independent chains (MoE experts ‖ shared expert; the gate ‖
up projections) overlap, and command buffers are **two deep** so
encoding of step *t+1* overlaps GPU execution of step *t* (34 → 44
tok/s).

In Fortran none of this is written down — it is the compiler's half of
the residency design in `design_gpu_offloading.md` §5.7, specialized to
unified memory:

- Each `do concurrent` / offloaded array statement encodes a dispatch
  into the current command buffer; **no sync after kernels**.
- Barriers come from buffer-dependence analysis between consecutive
  dispatches (writer→reader on the same array ⇒ barrier; disjoint
  arrays ⇒ none). The gate‖up overlap falls out: two `linear_q8` calls
  reading the same `x`, writing different outputs — no barrier between
  them.
- The only `require_host` per token is reading the `maxloc` result to
  detokenize — that is where the command buffer commits and (double-
  buffered) waits on step *t−1*, not *t*.
- On Apple, "residency" is just: model arrays are `MTLBuffer`-backed
  from load (shared storage mode); the present-table degenerates to
  pointer bookkeeping and the state machine only guards host reads.

## 8. The capability checklist (with measured leverage)

Everything the qwen3.6 kernels need from LFortran, ranked by the
speedups recorded in `PERF.md`:

| # | Capability | Evidence / leverage |
|---|------------|---------------------|
| 1 | Async dispatch, one cmdbuf/step, dependence-based barriers, 2-deep pipelining (§7) | 19→34→44 tok/s |
| 2 | Cooperative SG mapping: body reductions (`sum`, `dot_product`, `maxval`) → lane stripe + `simd_sum` (§2–§5) | GEMV, rmsnorm, SDPA, DeltaNet all depend on it |
| 3 | Occupancy-driven schedule choice: 1 SG vs multi-SG+TG-merge per iteration, tunable `N_SG` (§2, §4) | +16% (rmsnorm msg), SDPA N_SG sweep |
| 4 | Register tiling / unroll-and-jam across adjacent outputs, register-cached shared operand (§3) | +18.7% with uint4 loads |
| 5 | 4-wide vector loads on contiguous strides (§2–§4) | part of every win |
| 6 | Online-softmax rewrite of the maxval/exp/sum pattern, SG-striped with merge (§4) | SDPA 15→18 tok/s + "endgame" D3 |
| 7 | Device lowering of reduction intrinsics (`maxloc`) (§6) | 2.4→4.4 tok/s |
| 8 | `real(bf)` bfloat16 kind; fp32 accumulate idioms; `integer(int8)` unpack idioms (§3) | prerequisite for all of it |
| 9 | ILP unrolling of independent reduction chains (§4) | SDPA D5 |
| 10 | Constant-size `local` arrays → lane-distributed registers; runtime-sized → VLA workspace (§4, §5) | DeltaNet st, SDPA o_acc |
| 11 | Autotuning hooks for the small discrete knobs (tile K_OUT, N_SG, TG size) | K_OUT=8 and TG X-share both *regressed*: measure, don't assume |

Notably absent: `simdgroup_matrix`/MMA tile kernels. Decode never needs
them (16× left of the roofline ridge; ALUs 28× over-provisioned). They
matter only for prefill — which is exactly the §7 cooperative *tile*
mapping of `design_gpu_offloading.md`, and can come later without
touching any of the Fortran above.

## 9. Takeaway

Every kernel in a state-of-the-art hand-tuned Apple-GPU LLM decoder is
the SIMT lowering of a `do concurrent` whose body is scalar math plus
`sum`/`dot_product`/`maxval`/`exp` on sections indexed by the
concurrent variables. No new language constructs are required beyond a
bf16 kind — the entire gap is compiler scheduling: cooperative SG
mapping with intrinsic-reduction lowering, occupancy-driven variant
selection, register tiling, one rewrite rule for softmax, and
barrier-minimal async dispatch. The hand-written source is ~40 KB of
Metal + 1300 lines of orchestration C; the Fortran above is a few
hundred lines that also compile with gfortran and run (serially) as
their own reference implementation — which is precisely the value
proposition of `do concurrent` offloading done well.
