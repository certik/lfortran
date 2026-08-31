# GPU Offloading of `do concurrent` in LFortran: Design

Status: draft for discussion
Date: 2026-08-31

This document analyzes how LFortran should offload `do concurrent` (including
loop bodies that call pure functions) to GPUs, answers whether a tile-based
model such as Triton or NVIDIA's cuTile is needed for maximum performance, and
proposes a design at the IR (ASR) level. File references below are to
`lfortran/lfortran` master at commit `e2a89de` (2026-08-30), where a first
generation of GPU offloading already exists.

## 1. Goals

1. `do concurrent` nests (1–3+ indices, locality specifiers, `reduce`)
   compile to fast GPU kernels with no directives and no source changes:
   `lfortran --gpu=<backend> a.f90`.
2. Loop bodies may call arbitrary pure procedures (possibly across modules);
   the whole reachable pure call graph runs on the device.
3. Performance target: roofline (memory bandwidth) on streaming/stencil
   kernels, competitive with `nvfortran -stdpar=gpu`; a path to tensor-core
   performance for matmul-like hot spots.
4. Portability: NVIDIA and AMD as first-class targets, Apple/Metal retained,
   Intel reachable later; no hard dependency on a vendor compiler (`nvcc`)
   for the main path.
5. Keep LFortran's architecture: machine-independent ASR→ASR passes, then
   thin backends; no mandatory MLIR or libomptarget dependency in the core.

## 2. Where LFortran is today

The current pipeline (all at the ASR level, which is the right place — see
§5) is:

- **ASR**: `DoConcurrentLoop(do_loop_head* head, expr* shared, expr* local,
  reduction_expr* reduction, stmt* body)` (`src/libasr/ASR.asdl`), plus
  device nodes `GpuKernelFunction`, `GpuKernelLaunch(kernel, grid_size,
  block_size, args)`, `GpuSync`, and expressions `GpuThreadIndex`,
  `GpuBlockIndex`, `GpuBlockSize`.
- **Pass** `src/libasr/pass/gpu_offload.cpp` (enabled by `--gpu=metal|cuda`):
  extracts each acceptable `DoConcurrentLoop` into a `GpuKernelFunction` at
  translation-unit level, clones called functions and referenced struct
  definitions into the kernel scope, classifies captured symbols into kernel
  parameters vs. kernel-local scalars, flattens the (≤3) loop heads into a
  single `flat_idx = blockIdx*blockDim + threadIdx` and de-linearizes, and
  replaces the loop with a `GpuKernelLaunch` (+ `GpuSync`) with
  `block_size = 256` and `grid_size = ceil(n/256)`.
- **Device codegen as text**: `asr_to_cuda.cpp` emits CUDA C++ (compiled by
  `nvcc`, `--device-compiler`), `asr_to_metal.cpp` emits MSL (compiled at
  runtime by the Metal framework).
- **Host runtime ABI**: `src/libasr/runtime/lfortran_gpu_runtime.h` — a small
  backend-neutral C API (`lfortran_gpu_init/load_kernel/set_buffer_arg/
  set_scalar_arg/launch/sync`) with Metal and CUDA implementations; the LLVM
  backend lowers `GpuKernelLaunch` to these calls.
- Separately: an `openmp` pass lowers `do concurrent` to GOMP-based
  multithreading on the CPU (`--openmp`), and a C-backend `--target-offload`
  path exists for `!$omp target` regions.

Known gaps in this first generation:

1. `shared`/`local` are stored in ASR but **ignored by every consumer**;
   `local_init` and `default(none)` are dropped in the AST→ASR visitor.
2. Any `reduce(...)` clause makes `gpu_offload` bail out to the serial path.
3. Launch configuration is hard-coded (256 threads, 1-D grid, ≤3 heads).
4. Device code leaves the compiler as C++/MSL **text**; the CUDA path
   requires `nvcc` at compile time; there is no AMD path at all.
5. Purity (`FunctionType.m_pure`, `Function.m_side_effect_free`, both fully
   computed by semantics) is **not** used as a legality gate; illegal bodies
   are rejected only when device codegen happens to throw.
6. There is no memory-residency management: every launch re-binds buffers;
   nothing keeps arrays on the device across consecutive kernels.

## 3. Survey: how others do it

- **nvfortran `-stdpar=gpu`** (most mature): parallelizes `do concurrent`
  through its OpenACC/CUF kernel machinery straight to SIMT CUDA kernels.
  Nested concurrent headers are collapsed onto the block/thread grid;
  eligible `local` variables can be placed in CUDA shared memory. All data
  movement is implicit via **CUDA Unified (managed) Memory** — the compiler
  intercepts allocations rather than computing transfers. Pure procedure
  calls in the body are supported by device compilation/inlining.
- **flang** (`-fdo-concurrent-to-openmp=device`): a FIR/MLIR pass converts
  `fir.do_loop unordered` nests into `omp.target teams distribute parallel
  do` + `omp.loop_nest`, then reuses the OpenMP-offload infrastructure
  (libomptarget, device images, `map` clauses). GPU support is still basic;
  locality and reductions are incomplete. Notably, generic OpenMP GPU
  codegen carries overhead that LLVM is still working to remove (the
  "no-loop mode" RFC: eliminating the sequential remainder loop when the
  grid covers the iteration space) — overhead that a purpose-built
  `do concurrent` lowering never has to introduce in the first place.
- **AMD flang / Intel ifx**: same shape — lower `do concurrent` to OpenMP
  target constructs and reuse the vendor OpenMP offload runtime.
- **MLIR gpu dialect**: `scf.parallel` → `gpu.launch` → NVVM/ROCDL, device
  image serialized into the module. A clean design, but it requires adopting
  MLIR as the central IR; LFortran's MLIR backend is optional and its
  `--mlir-gpu-offloading` path today produces host OpenMP, not device code.
- **Tile models — Triton, NVIDIA cuTile / CUDA Tile IR**: the program is
  written per *tile* (block), not per thread: `tl.load`/`tl.dot`/`tl.store`
  on tile values; the compiler assigns tiles to warps/tensor cores, stages
  operands in shared memory, and pipelines loads. CUDA Tile IR is now an
  open (Apache-2.0) MLIR dialect plus a versioned, portable bytecode spec
  that third-party compilers can target; a Triton→TileIR backend exists.
  These models exist to make **compute-bound, data-reuse-heavy** kernels
  (GEMM, attention, convolutions) reach tensor-core peak without hand-written
  CUDA.

## 4. Do we need a tile model for maximum performance?

**No — not as the foundation. SIMT is the right default for `do concurrent`;
a tile path is a later, optional specialization tier.** The reasoning:

1. **Semantics match SIMT, not tiles.** `do concurrent` is a flat, unordered
   iteration space whose body is arbitrary scalar Fortran: branches, inner
   sequential `do` loops, calls to pure procedures, derived types, array
   sections. That maps one-to-one onto SIMT threads (one iteration ≈ one
   thread), which is exactly what nvfortran does. A tile IR's unit of
   computation is an *operation on a tile value*; to express a general
   `do concurrent` body there, the compiler would have to vectorize the whole
   body — every branch becomes masking, every pure call must be inlined and
   itself tile-ized, inner loops with data-dependent trip counts become
   painful or impossible. Triton and cuTile deliberately do not try to be
   general-purpose; they are DSLs for regular dense-array kernels.
2. **The common case is bandwidth-bound, where tiles buy nothing.** Published
   `do concurrent` studies (Lattice Boltzmann, solar MHD, tridiagonal-solver
   benchmarks across nvfortran/amdflang/ifx) consistently show streaming and
   stencil kernels limited by DRAM bandwidth, with speedups tracking the
   bandwidth ratio of the devices. A plain SIMT kernel with coalesced
   accesses already sits on that roofline; shared-memory tiling and tensor
   cores only matter when arithmetic intensity is high enough to be
   compute-bound.
3. **Where tiles do matter, a library call beats a tile compiler.** The
   compute-bound patterns worth tensor cores in Fortran code are almost
   always `matmul`/`transpose`/contraction shapes. The fastest and cheapest
   route to peak there is recognizing the pattern at the ASR level and
   calling cuBLAS/cuTENSOR/hipBLAS/rocBLAS (or MetalPerformanceShaders),
   not regenerating Triton. (The current `gpu_offload` pass does the
   opposite — it pre-inlines `matmul`/`sum`/`transpose` into scalar loops so
   the device codegen can handle them; that is correct as a fallback but is
   a performance anti-goal for large operands; see §5.6.)
4. **Tile IR is still a reasonable *experiment*, not a foundation.** CUDA
   Tile IR being an open MLIR dialect with a stable bytecode makes an
   `asr_to_tileir` backend feasible for a *recognized subset* (fused
   elementwise + contraction chains) where a library call cannot fuse. It is
   NVIDIA-only, and Triton (portable to AMD) is Python-hosted and awkward to
   embed in an AOT Fortran compiler. Neither should gate the main design.

So the performance architecture is a three-tier funnel, all driven from ASR:

- **Tier 1 (default)**: SIMT kernel per `do concurrent` — reaches roofline
  for the bandwidth-bound majority.
- **Tier 2 (pattern → library)**: array intrinsics and recognized
  contraction nests inside/around offloaded regions call vendor libraries on
  device operands.
- **Tier 3 (cooperative/tile mapping)**: for tile-shaped `do concurrent`
  loops, map one *iteration to a thread block* instead of a thread and lower
  the body's small-array operations to tile ops (tensor cores). This is how
  compute-bound kernels that libraries can't express (fused attention)
  reach peak; see §7–§8.

## 5. Design at the IR level

### 5.1 Keep the decision and the transformation at the ASR level

The existing choice — kernel extraction as an ASR→ASR pass — is correct and
should be kept, for the same reasons flang does this at FIR rather than LLVM
IR: at ASR we still have Fortran types, array descriptors, purity flags,
locality specifiers, intrinsic calls (`matmul` is still `matmul`), and the
whole-program symbol table needed to clone the pure call graph. At LLVM IR
all of that is gone. The pipeline stays:

```
ASR --[gpu_offload pass]--> host ASR (GpuKernelLaunch/GpuSync)
                          + device ASR (GpuKernelFunction + cloned pure fns)
host ASR  --asr_to_llvm (host triple)--> host object
device ASR --device backend (see 5.4)--> device image, embedded in host object
```

The contract between the two halves is the small set of ASR GPU nodes plus
the `lfortran_gpu_*` runtime ABI. Backends (CUDA, HIP, Metal, …) are plugins
behind that ABI; the pass never needs to know which one runs.

### 5.2 Legality: purity is the gate

The Fortran standard already does the hard work: a `do concurrent` body may
only invoke **pure** procedures and may not contain image control or
branching out of the construct. So the offload legality rule is simply:

- Every `FunctionCall`/`SubroutineCall` reachable from the body must resolve
  to a symbol with `side_effect_free`/`m_pure` true (or to an intrinsic with
  a device implementation, §5.5). Semantics already computes these flags via
  `SideEffectFinder`; `gpu_offload` must consult them *before* extraction
  instead of relying on device codegen throwing later.
- I/O statements, `allocate` of unbounded size, and `stop`/`error stop` in
  the body disqualify the loop (initially; `error stop` can later become a
  device-side abort flag).
- A disqualified loop falls back, with a `--verbose`-visible remark saying
  *why* (nvfortran's `-Minfo=accel` equivalent; essential for users chasing
  performance).

The pure call graph is cloned into the device module (the pass's
`GpuFunctionCollector` already does the cloning). Purity guarantees the
clones need no globals and no host runtime, so device compilation is closed.
Small pure functions should be force-inlined into the kernel (the ASR
`inline_function_calls` machinery) — call overhead on GPUs is nontrivial and
inlining unlocks vectorization/registers; larger ones compile as `device`
functions.

### 5.3 Semantics of the mapping: iteration → thread

Replace the flatten-to-1D + hard-coded 256 scheme with an explicit launch
model in the pass:

- **Grid mapping**: map up to 3 concurrent heads onto grid dimensions
  directly; >3 heads flatten the extra outer ones. Each thread executes
  exactly one iteration — the "no-loop" form that OpenMP GPU codegen has to
  work hard to recover is our natural output. A grid-stride loop is emitted
  only when the trip count exceeds the maximum grid size.
- **Coalescing rule (column-major!)**: threads within a warp must touch
  consecutive memory. Since Fortran arrays are column-major, the concurrent
  index that appears in the *first* subscript position of the hot arrays
  must map to `threadIdx.x`. The pass should choose the head→dimension
  assignment by scanning subscript positions in the body (a cheap heuristic:
  pick the head used most often as the first subscript), rather than fixing
  it by header order. This single rule is worth more than any other
  optimization on bandwidth-bound code.
- **Block size**: default 256 but overridable (`--gpu-block-size`), and per
  kernel chosen from an occupancy query once the driver-API backend (§5.4)
  exists (`cuOccupancyMaxPotentialBlockSize`).

### 5.4 Device code generation: from text to LLVM

Short term the CUDA-C++-via-`nvcc` and MSL paths work and should stay (MSL
permanently — Apple has no other route; CUDA text as the debugging surface
behind `--show-gpu-kernel-source`). The main path should become:

- Reuse `asr_to_llvm` on the **device ASR module** with a device target:
  `nvptx64-nvidia-cuda` or `amdgcn-amd-amdhsa`. Kernels get the proper
  calling convention (`ptx_kernel` / `amdgpu_kernel`),
  `GpuThreadIndex`/`GpuBlockIndex`/`GpuBlockSize` lower to the intrinsics
  (`llvm.nvvm.read.ptx.sreg.*`, `llvm.amdgcn.workitem.id.*`), and math
  intrinsics link against `libdevice.bc` / ROCm device libs.
- Emit PTX (forward-compatible, JIT-compiled by the driver) or AMD code
  objects, embed them as data in the host object, and load at startup via
  the existing `lfortran_gpu_*` ABI, with new backends implemented on the
  **CUDA driver API** (`cuModuleLoadData`/`cuLaunchKernel`) and **HIP**.
  This removes the `nvcc` build-time dependency, makes cross-compilation
  work, keeps LFortran's fast compile times, and gives AMD support almost
  for free since it is the same LLVM module with a different triple.
- This requires: building LFortran's LLVM with the NVPTX/AMDGPU targets
  enabled, and generalizing the existing "second object file" precedent
  (`src/bin/lfortran.cpp`, the `--mlir-gpu-offloading` two-object link) into
  "second module at a different triple".

Why not build on **libomptarget** instead? It would give data-mapping
machinery and three vendors' plugins, but it couples us to the clang/flang
offload ABI (`__tgt_*` entry tables, fat-binary wrapping), drags in the
generic-mode kernel state machine we don't need (do concurrent is always
SPMD/no-loop), and contradicts LFortran's independence from the LLVM
frontends' runtimes. The `OMPRegion` ASR nodes and the C-backend
`--target-offload` path remain the *interoperability* story for explicit
`!$omp target` code; `do concurrent` should not depend on it. Similarly,
MLIR's gpu dialect can become another device backend behind the same ASR
contract, but must not be a core dependency.

### 5.5 Device runtime and intrinsics

- Maintain a small device-side runtime as ASR/bitcode: the numeric
  intrinsics map to `libdevice`/ROCm builtins via a table in the device
  backend; string/descriptor helpers compile from a device-safe subset of
  `libasr`'s runtime, AOT-compiled to bitcode per target and linked into
  each device module (mirroring `libomptarget-nvptx.bc`'s approach, but
  LFortran-owned).
- Array descriptors: kernels should receive raw pointers + explicit
  bounds/strides as scalar arguments (the pass already decomposes
  descriptors for its parameter classification); keep full descriptors out
  of device memory where possible.

### 5.6 Locality, reductions, and shared memory

- `local` / `local_init`: become per-thread variables in the kernel
  (registers/local memory); `local_init` adds a copy-in from the mapped host
  value. This is mostly formalizing what the pass's "kernel-local scalars"
  inference already does — but the specifiers must be honored, and
  `local_init`/`default(none)` must stop being dropped at AST→ASR
  (`ast_body_visitor.cpp` needs to populate ASR; ASR needs a `local_init`
  field).
- `reduce(op:var)`: implement instead of bailing out. Standard scheme:
  per-thread partial → block-level tree reduction in static shared memory
  (`__shfl_down`/LDS) → one atomic (or a tiny second kernel) to combine
  block results. This needs two small ASR additions: a `GpuSharedMemory`
  storage class (or an attribute on kernel-scope variables) and a
  `GpuBarrier` statement (`__syncthreads`). Both are also the building
  blocks any future tile/stencil optimization needs, so they pay twice.
- `shared`: read-mostly small arrays marked `shared` (or detected) can be
  staged into shared memory — an optimization, not required for
  correctness.

### 5.7 Memory management and device residency

The guiding principle: **residency is not primarily something the user
expresses — it is something the implementation guarantees whenever the
program's access pattern permits it, and reports when it doesn't.** A
program expresses residency simply by not touching an array from host code
between kernels; the machinery below makes that sufficient, checkable, and
diagnosable. There are three layers.

#### (a) Runtime: a present-table with a validity state machine

The core mechanism is a runtime-side table (the same proven shape as
libomptarget's mapping table, but LFortran-owned), keyed by host base
address and extent. Each entry holds the device allocation and a coherence
state:

```
HostOnly → (first kernel use) → Both → host writes → DeviceStale
                                     ↘ kernel writes → HostStale
```

Two runtime entry points implement all data movement:

- `lfortran_gpu_require_device(a)` — called for each kernel argument at
  launch: looks up (or creates) the entry, copies host→device **only if
  `DeviceStale`**, returns the device pointer.
- `lfortran_gpu_require_host(a)` — copies device→host only if `HostStale`
  (and synchronizes the stream first).

Transfers are thereby *memoized*: an array used by 500 consecutive kernels
is copied at most once. "Residency across `do concurrent` loops" is not a
new construct — it is the absence of `require_host` calls between them.
Whole-array granularity initially; the table works for allocatables, module
arrays, and static arrays alike, and avoids changing the array-descriptor
ABI.

#### (b) Compiler: classify host uses, insert the calls

An ASR pass classifies every statement as *device* (inside an offloaded
region) or *host*, and inserts `require_host(a)` only before host
statements that actually access `a` (I/O statements included; `bind(c)`
escapes and pointer aliasing are treated conservatively as host use of the
whole object). Purity makes this analysis tractable: the pure call graph
reachable from kernels cannot perform I/O or touch globals invisibly, and
`intent(in)` args of pure functions cannot invalidate the device copy, so
kernel-side writes are precisely known. Interprocedurally, host
subprograms are summarized by the arrays they touch; where a summary is
unavailable (separate compilation), the call conservatively invalidates its
actual arguments only.

The result for the LLM main loop falls out automatically: weights are
written once by the host loader (`HostOnly`), copied up at the first
kernel (`Both`), and never touched by host code again — resident for the
run. Activations and the KV-cache ping-pong between kernels entirely in
`HostStale` state and are never copied back; the only per-token
`require_host` is the sampled token id (a scalar).

With `--verbose`/`-Minfo`-style remarks, the compiler and runtime report
the transfers that *do* happen ("`a` copied host→device 400 times at
line 123; host write at line 119 invalidates it"), which turns the classic
stdpar performance cliff into an actionable diagnostic instead of a
mystery.

#### (c) Explicit syntax: an assertion, not a mechanism

For cases the analysis cannot see (separate compilation, arrays handed to
external C code, or users who want guarantees), provide a thin explicit
layer that maps onto the *same* table and ASR nodes (`TargetData`/`OMPMap`
already exist):

- **Directive comments (recommended primary spelling)** — invisible to
  other compilers, so the source stays portable standard Fortran:

  ```fortran
  !lf$ resident(w_q, w_k, w_v, kv_cache)     ! declaration-site or block
  !lf$ data enter copyin(w) / data exit copyout(c)   ! region form
  ```

  `resident` asserts "host code does not touch this between kernels":
  the array is allocated device-first, `require_host` sites for it become
  compile-time warnings (or errors with `--gpu-strict`), and no coherence
  checks are emitted for it.
- **Accept the standard directive spellings too** — `!$omp target enter
  data map(to: w)` / `!$acc enter data copyin(w)` lower to the same nodes,
  so codes written for other compilers keep their performance annotations.
- Deliberately **no new declaration attribute** (`real, device ::` à la
  CUDA Fortran): it forks the language and breaks compilation with other
  compilers; the comment form carries the same information.

#### Managed memory as the substrate and the fallback

Beneath all of this, follow nvfortran's proven default: when offloading is
enabled, heap allocations route through `lfortran_gpu_alloc`
(`cuMemAllocManaged`/`hipMallocManaged`, plain `malloc` without a device).
On coherent-memory systems (Grace-Hopper, MI300A, Apple silicon — Metal's
shared-storage buffers already behave this way) the require-calls degrade
to prefetch hints (`cuMemPrefetchAsync`) and the state machine only drives
those; on discrete-memory systems the same calls perform real memoized
copies. One mechanism, two cost models — and pointer-chasing derived types
stay correct everywhere because managed memory backstops anything the
table's whole-array granularity cannot express.

Kernel launches enqueue asynchronously on a stream; `require_host` is the
synchronization point. Later: CUDA-graph capture of stable kernel
sequences (an LLM token step) to amortize launch overhead.

### 5.8 Kernel fusion (ASR-level, later)

Because extraction happens at ASR, fusing *adjacent* `do concurrent` loops
with identical heads and no intervening host code is a straightforward
ASR-to-ASR rewrite before extraction. Fusion reduces launches and re-reads
of the same arrays — on bandwidth-bound code this is the highest-value
optimization after coalescing, and it is exactly the fusion tile DSLs are
usually praised for, obtained without changing the programming model.

## 6. Roadmap

1. **Robustness of the current SIMT path**: purity-based legality gate +
   fallback remarks; honor `local`/`local_init` (fix AST→ASR drop);
   head→grid-dimension mapping with the coalescing heuristic; configurable
   block size.
2. **Reductions**: `GpuBarrier` + shared-memory storage in ASR; block-tree +
   atomic scheme for all `reduce` ops; unlocks `do concurrent ...
   reduce(+:s)` on GPU (today it silently runs serial).
3. **LLVM device path + NVIDIA driver-API backend**: device-triple module
   compilation, PTX embedding, `cuModuleLoadData` runtime backend; drop the
   hard `nvcc` requirement.
4. **Managed memory + prefetch**; then AMD (`amdgcn` triple + HIP runtime
   backend) — mostly re-plumbing of step 3.
5. **Residency**: present-table runtime with the validity state machine and
   memoized `require_device`/`require_host` transfers; host-use
   classification pass; `!lf$ resident`/`data` assertions; transfer
   diagnostics. Then **kernel fusion** at ASR.
6. **Tier 2**: `matmul`/`transpose`/`sum` on device operands call
   cuBLAS/rocBLAS/MPS instead of being scalar-inlined into kernels.
7. **Tier 3, cooperative/tile mapping (§7)**: iteration→block mapping for
   tile-shaped loops, lowered via `asr_to_tileir` (CUDA Tile IR bytecode;
   later Triton TTIR for AMD); validate on tiled matmul, then fused
   attention (§8). Reduced-precision kinds (bf16/fp16) land alongside.

## 7. Compute-bound kernels: the cooperative (tile) mapping

§4 argues SIMT is the right default because typical `do concurrent` bodies
are bandwidth-bound. That raises the obvious question: matmul-class kernels
are compute-bound *only when tiled* — `C = A·B` does `2·M·N·K` flops over
`M·K + K·N + M·N` words, so the intensity is there in principle, but a
per-element mapping never realizes it. If `do concurrent (i, j)` maps one
iteration to one thread and each thread runs the `k` loop, every thread
streams a whole row of `A` and column of `B` from global memory: ~0.5
flop/byte in bf16, a ceiling below 1% of tensor-core peak on an H100
(3.35 TB/s vs. ~990 bf16 TFLOP/s; break-even is ~300 flop/byte). Blocking
into `TM×TN` tiles raises per-element reuse to ~`TM·TN/(TM+TN)` (~64× for
128×128 tiles), which — with L2 reuse across blocks — is what reaches peak.

The resolution is that the tile paradigm is not a different parallel
semantics; it is a different *mapping* of the same construct. A Triton
program **is** a `do concurrent` over tiles. Compare a Triton matmul with
this standard Fortran:

```fortran
do concurrent (it = 1:m/TM, jt = 1:n/TN) local(acc)
  real(4) :: acc(TM, TN)
  acc = 0
  do kt = 0, k/TK - 1
    acc = acc + matmul(a((it-1)*TM+1 : it*TM, kt*TK+1 : kt*TK+TK), &
                       b(kt*TK+1 : kt*TK+TK, (jt-1)*TN+1 : jt*TN))
  end do
  c((it-1)*TM+1:it*TM, (jt-1)*TN+1:jt*TN) = acc
end do
```

The concurrent indices are `tl.program_id`, the array sections are
`tl.load`, the tile `matmul` is `tl.dot`, `acc` is the register-tile
accumulator. What Triton/cuTile add is the *execution mapping*: one program
instance runs cooperatively on a whole thread block, tile values live in
registers/shared memory with swizzled layouts, `dot` uses tensor-core MMA,
and the compiler software-pipelines the loads (`cp.async`/TMA).

LFortran should therefore support **two mappings of `do concurrent`**,
chosen per loop:

1. **Thread mapping** (default, §5.3): iteration → thread. Scalar bodies,
   bandwidth-bound code.
2. **Cooperative mapping**: iteration → thread block. Eligible when the
   body is *tile-shaped*: control flow uniform in the concurrent indices,
   and the work expressed as whole-array operations on small,
   compile-time-bounded `local` arrays. Those locals become shared-memory /
   register tiles with compiler-chosen distributed layouts; array
   operations on them (`matmul`, elementwise ops, `sum`/`maxval` along a
   dimension, `transpose`, `spread`) lower to block-cooperative tile ops,
   with `matmul` on tiles going to tensor cores. Scalar statements execute
   redundantly-uniformly across the block (cheap, standard practice).

Both mappings observe the same independence semantics, so the choice is an
implementation detail: the program remains standard-conforming Fortran that
gfortran can run serially. Selection is by heuristic (tile-shaped body with
constant-size locals) plus a hint for control — either a `!lf$ tile`
directive-comment or simply honoring the declared `local` array sizes.

Critically, LFortran should not build the layout/swizzling/pipelining
machinery itself. The cooperative-mapped device ASR lowers to **CUDA Tile
IR** (an open MLIR dialect with a stable, versioned bytecode — exactly the
"compilers that target PTX can also target Tile IR" use case NVIDIA
documents) and later, for portability, to Triton's TTIR (which targets both
NVIDIA and AMD). This is where a tile IR earns its place in this design:
as the backend of the cooperative mapping — not as the foundation of
offloading. An alternative expressible form — nested `do concurrent`
(outer nest → blocks, inner → threads, mirroring OpenMP's
`teams distribute` / `parallel do` split) — gives users CUDA-like manual
control and can share the same lowering, but the tile-locals form should be
primary because it leaves the compiler free to choose layouts and
pipelining.

## 8. Case study: an LLM on the GPU with `do concurrent`

An LLM decomposes cleanly across the three tiers, and much of it needs no
tiles at all:

- **Decode (batch 1) is bandwidth-bound end to end.** Each generated token
  reads every weight once (GEMV): ~1 flop/byte in bf16. A 70B-parameter
  bf16 model is 140 GB, so 3.35 TB/s caps decode at ~24 tokens/s
  regardless of compute. Tier-1 SIMT `do concurrent` (with split-k block
  reductions for the GEMVs) reaches that roofline.
- **Prefill, batched serving, and training are GEMM-bound**: QKV/O
  projections and the MLP matmuls go through Tier 2 (`matmul` on
  device-resident arrays dispatching to cuBLASLt/hipBLASLt, elementwise
  epilogues such as bias+SwiGLU fused via library epilogues) — or through
  the §7 cooperative mapping where fusion beyond epilogues is wanted.
- **Attention is the flagship cooperative-mapping kernel.** FlashAttention
  is a fused tiled kernel, expressible in standard array syntax:

```fortran
do concurrent (h = 1:nheads, qt = 1:nq/TQ) &
    local(qtile, ktile, vtile, s, p, acc, mrun, mnew, corr, l)
  real(2) :: qtile(TQ,hd), ktile(TK,hd), vtile(TK,hd)
  real(4) :: s(TQ,TK), p(TQ,TK), acc(TQ,hd)
  real(4) :: mrun(TQ), mnew(TQ), corr(TQ), l(TQ)
  qtile = q((qt-1)*TQ+1:qt*TQ, :, h)
  acc = 0;  l = 0;  mrun = -huge(0.0)
  do kt = 1, nk/TK
    ktile = kcache((kt-1)*TK+1:kt*TK, :, h)
    vtile = vcache((kt-1)*TK+1:kt*TK, :, h)
    s = matmul(qtile, transpose(ktile)) * scale   ! tensor cores
    mnew = max(mrun, maxval(s, dim=2))
    p = exp(s - spread(mnew, 2, TK))
    corr = exp(mrun - mnew)
    l = l*corr + sum(p, dim=2)
    acc = acc*spread(corr, 2, hd) + matmul(p, vtile)
    mrun = mnew
  end do
  o((qt-1)*TQ+1:qt*TQ, :, h) = acc / spread(l, 2, hd)
end do
```

  Every operation here is a tile op the cooperative lowering handles:
  small-`matmul` → MMA, `maxval`/`sum(dim=)` → block reductions,
  elementwise/`spread` → distributed elementwise.
- **Everything else** — RMSNorm (SIMT + block reduction), RoPE, residual
  adds, embedding gather, sampling — is Tier-1 SIMT, fused into neighbors
  where possible (§5.8).

Two requirements fall out of this case study:

1. **Device residency becomes mandatory, not an optimization.** Weights and
   KV-cache must live on the device for the whole run; a single accidental
   page migration of 140 GB per token destroys performance. This
   prioritizes §5.7's residency analysis, and eventually CUDA-graph capture
   of the per-token kernel sequence to amortize launch overhead.
2. **Reduced-precision kinds.** LFortran needs bf16/fp16 (`real(2)`-class)
   storage kinds, fp8 later, with mixed-precision semantics for `matmul`
   (low-precision operands, `real(4)` accumulation) — none of this matters
   in `real(8)`. This is a language/ASR decision independent of the GPU
   backend but gating for LLM workloads.

## 9. Summary of answers

- **Best way to offload `do concurrent`**: keep the current architecture —
  an ASR-level extraction pass producing `GpuKernelFunction` +
  `GpuKernelLaunch` against a thin backend-neutral runtime ABI — and harden
  it: purity as the legality gate, locality specifiers honored, reductions
  implemented, coalescing-aware grid mapping, managed memory by default.
- **Pure functions**: purity is the enabler, not an obstacle — the standard
  guarantees the body's call graph is side-effect-free, so it is cloned into
  the device module and aggressively inlined; this is already 80% wired.
- **Tile model (Triton/cuTile)**: not needed as the foundation — SIMT +
  coalescing + fusion reaches roofline for the bandwidth-bound majority,
  and vendor libraries cover plain contractions. For compute-bound *fused*
  kernels (attention), the tile paradigm is required but needs no new
  language: a tile program is a `do concurrent` over tiles (§7), so LFortran
  adds a *cooperative mapping* (iteration → thread block, tile-local arrays
  → shared memory/registers, small-array ops → tensor-core tile ops) and
  lowers it to CUDA Tile IR / Triton TTIR rather than building layout and
  pipelining machinery itself.
- **IR level**: ASR is the right level for everything semantic (legality,
  extraction, locality, reductions, fusion, residency); LLVM with device
  triples (NVPTX/AMDGPU) is the right level for device code generation,
  replacing text-and-`nvcc`; MLIR/gpu-dialect and Tile IR remain optional
  backends behind the same ASR contract.

## References

- Flang: DO CONCURRENT mapping to OpenMP —
  https://flang.llvm.org/docs/DoConcurrentConversionToOpenMP.html
- NVIDIA: Accelerating Fortran DO CONCURRENT with GPUs (stdpar, unified
  memory) —
  https://developer.nvidia.com/blog/accelerating-fortran-do-concurrent-with-gpus-and-the-nvidia-hpc-sdk/
- LLVM RFC: No-loop mode for OpenMP GPU kernels —
  https://discourse.llvm.org/t/rfc-no-loop-mode-for-openmp-gpu-kernels/87517
- NVIDIA CUDA Tile (Tile IR spec, cuTile Python) —
  https://developer.nvidia.com/cuda/tile, https://github.com/NVIDIA/cuda-tile
- Triton: Introducing Triton — https://openai.com/index/triton/
- Clang: Offloading Design & Internals (libomptarget) —
  https://clang.llvm.org/docs/OffloadingDesign.html
- MLIR 'gpu' dialect — https://mlir.llvm.org/docs/Dialects/GPU/
- J. Galvez Vallejo: Performance portability of do concurrent —
  https://jorgeg94.github.io/posts/2025.11.21-doconcurrent/
