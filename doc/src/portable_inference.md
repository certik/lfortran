# Portable inference: staged roadmap

**Status: GFortran/Flang real short/reset passed; LFortran real CPU run crashed.
Experimental GPU math remains unintegrated, with exactness/regression gates open.**

This is an implementation roadmap, not a claim that LFortran currently runs
the real model correctly or at competitive speed. The verified milestones
below do not establish LFortran real-model, full text-interface, or complete
Fortran Metal acceptance. Faster-than-MLX and release claims remain unearned;
the phase exit gates remain open.

## Verified milestone checkpoint

- **Pure Fortran raw-ID driver:** tiny-model validation reports 37,997,136
  exact comparisons under both GFortran and Flang. A freshly built LFortran
  CPU driver using the verified `91f90a5a16` compiler also passes 37,997,136
  tiny comparisons, four resets, 43 scalar-bit checks and actual headers-only
  model inspection with `--fast --no-fast-math --skip-pass=fma`. Bounded typed
  payload reads also pass: **10,496 bytes total**, including BF16 and U32
  samples beyond 4 GiB. These bounded proofs do not establish real forward
  acceptance; the failed diagnostic run is recorded below. The tiny-driver
  harnesses still exit **1** for the known
  [#15568](https://github.com/lfortran/lfortran/issues/15568) diagnostic mismatch:
  all 19 invalid cases are rejected, but this is **not blanket harness green**.
  Evidence: `.fix-issue/qwen38-lfortran-real-prep/handoff.json`.
  Raw-ID checks do not establish tokenizer, NFC or chat-rendering acceptance.
- **Real 27B GFortran and Flang: short inference/full reset PASS, each exit 0.**
  Each matches all 17 expected greedy IDs and consumes 16 decode IDs after the
  18-token prompt (34 inference tokens, 52 including reset). **Each compiler's
  32,310 tensors / 2,597,615,616 values** are finite and byte-exact to saved C,
  including the full reset. Peak model RSS is **26.984 / 25.832 GiB**
  (GFortran / Flang). Both invocations and helpers have exited; full-model
  memory is released. This accepts the bounded short/reset correctness check,
  not throughput or all application gates. The final Fortran-worktree evidence
  `artifacts/fortran-real-short/handoff.json` has status `passed`.
- **LFortran real CPU: FAILED diagnostic run, no full-model acceptance.**
  The audited run ended with harness exit **2** and model **SIGSEGV (-11)**,
  with **0/17 predictions**; reset and the 52-position gate remain unverified.
  Of 1,794/32,310 tensors checked, 1,793 were exact; the sole value difference
  is the known legal BF16 RoPE result. All 64 layers emitted; the last complete
  `x_after_final_norm.bin` `[18,5120]` is byte-exact to C, but `logits.bin`
  is missing/truncated. **Crash location and root cause remain undiagnosed**:
  projection versus the following dump is unresolved. Earlier exactness proofs
  and legal-RoPE analysis are preserved; source, binary, math, oracles and
  bounds are unchanged. No automatic rerun. Peak RSS was 25.60 GiB; cleanup
  and model-memory release completed.
  Evidence: `.fix-issue/qwen38-lfortran-real-run/diagnostic-prep/later-run/`
  (`handoff.json`, `summary.json`).
- **Combined local compiler:** verified source HEAD
  `91f90a5a168a391d32e054fe486377de081f880b` integrates the reviewed Metal
  precision group pinned at `f168f2edf44520f0539659ca4fd8b2bf71cc7ac6` and
  INQUIRE group pinned at `f3d25c6b97f31eb03b21f8ec681de259cf73288d`.
  Their six focused commits were cherry-picked individually, in order, with
  matching patch identities and both groups' tests retained. No IEEE
  prototype or later advancing-worktree changes were included.
  The existing Debug Pixi `llvm11` compiler was rebuilt and its selected
  executable, runtime and embedded LLVM 11.1.0 verified. One default-mode
  suite pass verified **57/57 unit entries, 2,114 reference output comparisons, and
  5,588/5,588 LLVM integration tests**. Units were partitioned into 55 CPU
  entries and two separately leased, serial actual-Metal entries; neither
  GPU entry was waived. Exact commit mapping, commands, full logs and green
  SHA evidence are retained in `.fix-issue/qwen38-combined-compiler/`
  (`commit-mapping.tsv`, `suites-green.json`, `state.md`).
- **Original compiler failures rechecked:** sparse INQUIRE cases, actual
  two-thread ownership cases and size boundaries pass; the unchanged
  headers-only Fortran driver reports **6 shards / 2,180 tensors / 1,847 text
  tensors / 28,579,478,528 text bytes**, without loading the payload.
  Actual unchanged precision helpers pass all **65,536 BF16 patterns and
  24 q8 extractions** on Metal, with exact CPU/GFortran agreement; the
  original precision programs and 14 targeted Metal regression runs pass.
  These verify narrow integer storage/ABI, scalar typed BitCast and the
  64-bit INQUIRE fix for
  [#16353](https://github.com/lfortran/lfortran/issues/16353), not complete
  model offload.
- **Experimental Fortran math Metal, not integrated into `91f90a5a16`:**
  pinned feature HEAD `d732a688f9b7220093d68f2aeeeb46d13e3ef31a` exercises
  **17/17 source regions**, 135 primary dispatches and 244 phase completions,
  without CPU fallback. Two nested RMS regions execute inside enclosing kernels.
  Math-policy `70db95a4de` and incoming-alias `d732a688f9` targeted checks and
  independent reviews are clean. Safe/Precise propagation, including cached
  options, selects fast policy only for `fast && !no_fast_math`.
  **173 qualified same-input comparisons pass unchanged bounds**, all finite;
  65,536 BF16 patterns and 24 q8 bytes remain exact. Qualified recurrent-state
  maximum error is 1.78814e-7; accumulated drift is excluded from that bound.
  The original **bit-exact fixture still FAILS with 85,665 differences**.
  Its first difference is strongly localized to a subnormal reciprocal becoming
  zero; no semantic bug or explanation of all differences is established.
  Feature-worktree evidence:
  `.fix-issue/qwen38-compiler/worktrees/metal-precision/`, under
  `.fix-issue/metal-precision/math-gpu-check/d732/FINAL_HANDOFF.txt`.
  Two control regressions (`gpu_liveout_15` verifier and
  `gpu_derived_component_03` identifiers) were **introduced by `532f56`
  renaming**, not upstream waivers; repair is active. Sixteen baseline CPU/
  emission checks pass, but baseline actual-Metal execution was not done.
  Attribution evidence in the `ibset-signbit` worktree:
  `.fix-issue/metal-control-attribution/CPU_ATTRIBUTION_HANDOFF.txt`.
  GPU reference reconciliation, full suites and integration remain pending;
  tiny/full Fortran GPU drivers are not validated.
- **Existing C/Metal performance, not Fortran-generated Metal:** last accepted
  short decode/effective-prefill medians are **3.734683 / 6.438657 tokens/s**
  versus MLX **16.567978 / 64.690424**: **not faster than MLX**.
  Matched 2K-prefill and sustained-decode comparisons remain pending.
  Reviewed, **uncommitted RMS-output WIP** passes tiny and combined same-input
  checks plus traced/untraced production 17-ID/full-reset checks. Its **30,294
  complete unique finite traced tensors are byte-exact to the accepted
  baseline**; untraced endpoints and reset also agree.
  Quiet before/after timing is still pending; this earns **no new performance
  gain or commit acceptance**. Metal-worktree evidence:
  `artifacts/perf-rms-output/production-correctness.json`.
- **Correctness limits remain explicit:** strict C80 stress checks still
  fail at **94/96 and 16/17**. The user authorized continued performance
  work despite those failures, not correctness acceptance or relaxed
  tolerances. Frozen C, primitive bounds, immutable oracles and the exact
  17-token short check remain mandatory. Final matched workloads
  **18/65, 2048/65 and 29/1536** (input/generated tokens), startup and total
  wall-time measurements remain goals. Older checkpoint weights are
  unavailable; no new old-checkpoint inference claim is made.

Deferred, unfixed work remains separate:
IEEE [#16342](https://github.com/lfortran/lfortran/issues/16342),
read-only OPEN [#16346](https://github.com/lfortran/lfortran/issues/16346),
array TRANSFER [#16349](https://github.com/lfortran/lfortran/issues/16349),
Metal toolchain [#16350](https://github.com/lfortran/lfortran/issues/16350),
internal READ [#15568](https://github.com/lfortran/lfortran/issues/15568),
conditional OpenMP sentinels
[#16126](https://github.com/lfortran/lfortran/issues/16126), and BLOCK-local
PRIVATE [#16364](https://github.com/lfortran/lfortran/issues/16364).

## Scope and fixed decisions

- The application belongs in `src-fortran/` in the existing `qwen3.6`
  application repository, not in LFortran. Below, `QWEN_REPO` denotes that
  checkout and `MODEL_DIR` denotes the local model directory; portable commands
  must use these placeholders rather than personal absolute paths.
- Start with text-only, batch-size-one, greedy decoding. Preserve existing
  Qwen3.6 model support, including its MoE path. Do not assume vision, MTP,
  or speculative decoding support.
- Target the artifact named **Qwen3.8-27B-MLX-8bit**, but derive architecture
  from its configuration and verified MLX behavior, never its directory name.
- Start with portable integer storage, explicit BF16/q8 conversions, and
  `real32` arithmetic. Consider native low-precision kind extensions only
  after a demonstrated need and after the standard fallback works.
- Balance short chat, approximately 2K-token prefill, and approximately
  1.5K-token sustained decode. The goal is faster-than-MLX performance across
  this balanced workload set, not a promise of an unbounded optimum.
- Work on local branches with focused commits only. No fetching, rebasing,
  pushing, or opening PRs is authorized by this milestone. Future execution
  is coordinated by Astra using GPT-6.1-Sol agents with high reasoning effort
  for bounded implementation tasks; coordination does not replace acceptance
  evidence. The explicitly authorized IEEE issue report below does not
  authorize source publication.
- Prioritize high-performance Fortran + LFortran inference. IEEE exception-flag
  and procedure-lifecycle diagnostics are not inference prerequisites; defer
  that facility to [#16342](https://github.com/lfortran/lfortran/issues/16342).
  No IEEE ASR-schema or procedure-lifecycle implementation belongs in this
  project. Fix compiler bugs required by inference; record and report
  orthogonal bugs separately rather than expanding implementation scope.

## Assessment inputs, not benchmark results

The prior model inspection supplied the following configuration and storage
findings. Phase 0 must record their exact identities and verify them against
the selected artifact before implementation relies on them.

| Property | Inspected value |
| --- | --- |
| Declared architecture | `qwen3_5` / `qwen3_5_text` |
| Layers / hidden width | 64 / 5120 |
| Dense FFN intermediate width | 17408 |
| Hybrid layers | 48 recurrent, 16 full-attention |
| Attention Q / KV heads; head dimension | 24 / 4; 256 |
| Recurrent K / V heads; head dimension | 16 / 48; 128 |
| Quantized weights | Packed U32 affine q8, group size 64 |
| Precision | BF16 scales, biases, and activations; FP32 recurrent state |
| Text tensor payload | 28,579,478,528 bytes |
| Inspected machine | Apple M4 Max, 40 GPU cores, 64 GiB unified memory |

Using the documented 546 GB/s bandwidth specification gives an idealized
weight-only estimate of `546e9 / 28,579,478,528`, approximately 19.1 tokens/s
(roughly 20). This assumes one full text-weight read per token at peak
bandwidth. It excludes other traffic and computation and is **not measured
target-model performance**, a guaranteed ceiling for every workload, or a
performance acceptance threshold. Recompute measured and estimated bandwidth
ceilings separately as the actual access patterns become known.

## Shared correctness and measurement contract

### Reproducible inputs and identities

Generate a benchmark manifest outside tracked artifacts. It must include:

- Application and compiler repository identities, source commits, dirty-state
  fingerprints, build flags, Pixi environment/lock identities, pinned MLX
  version, exact versions and executable/installation provenance of both
  approved PATH GFortran and Flang, and relevant runtime/Metal versions.
- OS/build, machine/chip, GPU core count, memory, power/thermal conditions,
  and whether other work could have contended for the GPU.
- Model identity/revision, configuration and safetensors index identities and
  hashes, tensor-shard hashes, tensor names/shapes/dtypes, and text payload size.
  Record tokenizer and chat-template identities/hashes as well.
- Exact rendered chat, input token IDs, template flags (including thinking and
  generation-prompt settings), greedy tie-breaking, special tokens, stop/EOS
  policy, context limits, and requested versus actual generated token counts.
- Precision, BF16 rounding locations, reduction order, reassociation/FMA policy,
  numerical tolerances, workload definitions, warmup/cooldown protocol, run
  order, and cold/warm status.

Keep manifests, oracle tensors, profiles, logs, weights, and artifact dumps out
of Git; retain their hashes and locations for reproducibility. Small authored
standalone regression fixtures are distinct from model/oracle dumps.

### Numerical acceptance

Initially require at least 16 generated tokens for CPU correctness, but never
infer numerical correctness merely from matching those first 16 tokens.
Compare teacher-forced per-layer outputs, logits, attention/cache contents,
and recurrent states using identical input tokens, including longer sequences
and at least two context lengths. Include a CPU case with context greater
than 64 tokens. Validate state across consecutive calls and reset/reuse paths,
not only isolated kernels.

Before accepting implementations, fix explicit numerical absolute/relative
bounds and ULP limits per operation/tensor in the validation specification,
for example `abs(actual - reference) <= atol + rtol * abs(reference)`.
Choose and justify the numeric limits from representation and reference
behavior, then freeze them. Check exact bit patterns where the contract
requires exact conversion; specify special-value handling separately.
Maintain the same precision, BF16 round points, reduction order, and
rounding/reassociation/FMA policy throughout each comparison. Never loosen
tolerances or regenerate an oracle merely to accept a failure. A reference
correction requires independent evidence, a versioned change, and rerunning
all dependent validation.

Core BF16/q8 bit-pattern, special-value, binary32-representation, and immutable
oracle checks remain mandatory. Separate optional IEEE exception-flag and
procedure-lifecycle conformance tests from those core checks, explicitly
reporting unsupported or failing IEEE features without hiding them. This test
separation is validated by the reviewed CORE checks below; their success does
not imply optional IEEE conformance.

### Performance acceptance

- Benchmark the pinned MLX implementation's **actual comparable greedy path**,
  with identical exact inputs, precision, context, stop policy, and generated
  token counts. Do not compare against an unrelated convenience API or a
  different decoding algorithm.
- Use balanced short-chat, approximately 2K-input-token prefill, and
  approximately 1.5K-generated-token sustained-decode workloads. Every
  reported decode benchmark must generate at least 64 tokens. Define how
  fixed-length runs handle EOS before measurement; do not silently truncate
  one implementation or compare different lengths.
- Run one GPU job at a time, including MLX, Metal, and compiler-generated
  workloads. Use a recorded warmup/cooldown protocol and separate cold-process
  and warm steady-state results; identify filesystem/JIT/cache conditions.
- Report best of at least three measured repetitions, medians, and spread,
  not just the fastest run. Use the same protocol on both sides.
- Separate startup, tokenizer/config loading, JIT, and weight loading from
  TTFT, prefill tokens/s, decode tokens/s, and total wall time. Report GPU-busy
  time alongside wall time, plus allocation, copy (counts and bytes), and
  dispatch counts.
- Keep each optimization only with a meaningful reproducible gain of at
  least 2% on its declared metric/workload, beyond observed noise, and disclose
  effects on the other balanced workloads. One profile-driven technique per
  focused commit; rerun correctness after every change.
- Report unmet goals, regressions, and both measured and estimated bandwidth
  ceilings honestly. Do not trade precision or validation for throughput.

## Phases, deliverables, and exit gates

The order below establishes trustworthy references before portability and
compiler optimization. Passing a later timing target never waives an earlier
correctness gate.

### Phase 0 — Setup, reproducibility, and a trustworthy harness

- [ ] Pin a working MLX installation through the application repository's
  Pixi manifest/lock, verify the artifact/configuration, and produce the input
  fixtures and manifest described above.
- [ ] Audit and close existing test false-acceptance holes before using the
  harness as evidence. Nonzero subprocess exits, missing/truncated outputs,
  mismatched token IDs/counts, incorrect context lengths, non-finite unexpected
  results, and numerical mismatches must fail rather than print apparent
  success. Add deliberately failing cases to verify these failure paths.
- [ ] Capture the existing Qwen3.6 regression baseline and the target model's
  comparable MLX baseline, serializing all GPU jobs.

**Deliverable / acceptance:** a pinned, repeatable harness with negative tests,
exact input/stop contracts, machine/model/source identities, and recorded
baseline measurements. No later speed claim proceeds without this gate.

### Phase 1a — Adapt and freeze the C correctness reference

- [ ] Adapt the existing simple C correctness reference for the inspected
  dense FFN and hybrid recurrent/full-attention model. Preserve the old MoE
  path and its kernels and regression coverage.
- [ ] Capture verified MLX oracle data for dense FFN, recurrent and attention
  kernels, cache/state transitions, per-layer outputs, and logits. Validate
  the C implementation under the shared numerical contract.
- [ ] Test at least 16 generated tokens initially, teacher-forced longer
  sequences at two contexts including context greater than 64, and
  state reset/reuse and cache boundaries.

**Deliverable / acceptance:** a correct simple C implementation and versioned,
immutable oracle with model/source/input hashes; existing model tests pass.
Freeze C after correctness. It is the comparison reference, not a new CPU
optimization project.

### Phase 1b — Make the existing optimized Metal implementation correct

- [ ] Bring the existing optimized Metal path to correctness before further
  tuning, preserving existing Qwen3.6 support.
- [ ] Apply `port-c-to-metal` discipline to new kernels: mirror the frozen C
  operations and validate each kernel before composing the model, rather than
  introducing optimization and semantic changes together.
- [ ] Check recurrent-state update ordering, in-place aliasing, command-buffer
  hazards/barriers, attention cache updates, and every BF16 rounding point.

**Deliverable / acceptance:** per-kernel and complete-model agreement with the
frozen C reference, including teacher-forced states, longer-context tests, and
existing model regressions. Greedy token agreement alone is insufficient.

### Phase 1c — Optimize Metal against a fair MLX baseline

- [ ] Profile the correct implementation, then apply one technique per commit
  using the shared >=2% gain rule and full precision/correctness contract.
- [ ] Measure startup and end-to-end costs as well as kernels. Collect wall
  and GPU-busy times, allocation/copy/dispatch telemetry, and bandwidth
  estimates before choosing the next optimization.
- [ ] Compare against MLX on all three balanced workloads using at least three
  repetitions, cold/warm separation, exact token counts, and serialized GPU use.

**Deliverable / acceptance:** reproducible comparisons, retained improvements
with evidence, and an explicit account of whether faster-than-MLX goals were
met. A measured plateau or unmet goal is a reportable outcome, not permission
to invent a speedup or weaken correctness.

### Phase 2 — Pure Fortran application, first on PATH GFortran and Flang

**Validated precursor, not phase acceptance:** application commit
`c2cc7e36483ef331b2ef614ed87155640467230c` on `project/qwen38-dense`
integrates `src-fortran/precision_formats.f90`, its contract and tests, and
the optional `fortran-precision` Pixi environment. The module is standalone
standard Fortran 2018, without C/Python linkage; C is an independent test
oracle only. The reviewed numerical sources and existing C reference are
unchanged by integration.

Both receiving-root tasks, `precision-versions` and `precision-test`, passed
through `pixi run -e fortran-precision`. Each of GFortran 16.1.0
(`conda-forge gcc 16.1.0-3`) and Flang 24.0.0git
(`e8e9abb11b3d199d861900858a7b42dcaabe4de3`) passed all 65,536 BF16
patterns/`DO CONCURRENT` roundtrips, 22,032 C-oracle binary32 inputs,
256 q8 boundary-byte combinations, and nine controlled rejection cases
(each exited 1 with its expected diagnostic); IEEE invalid/overflow/underflow
flags remained clear. Exact PATH selections, versions, Flang installation
and configuration provenance, and C-oracle compiler identity are recorded
in `$QWEN_REPO/build/fortran-precision/versions.log`; the full task results
are in `tests.log` alongside it, with positive/rejection logs under each
compiler's `checks/` directory. Two known GFortran duplicate-rpath linker
warnings remain; no Fortran source or Flang/C-oracle warnings occurred.

This validates only BF16 conversion and packed-q8 byte extraction, not
groupwise q8 arithmetic, whole-model inference, the MLX-baseline gate,
full-application LFortran compatibility, or Metal offload. The subsequent
staged LFortran CORE result is recorded in Phase 3a. No GPU/model runs were
performed for these precision checks.

- [ ] Implement inference kernels, driver, configuration, safetensors reader,
  tokenizer, chat rendering, and CLI in `$QWEN_REPO/src-fortran`. No C kernel
  calls or embedded Metal source. Initially, read-only deterministic input-ID
  fixtures may isolate numerical work; full pure-Fortran I/O and text handling
  remain required for application acceptance.
- [ ] Use standard `iso_fortran_env` integer storage (`int8`, `int16`,
  `int32`, `int64`) and `real32` arithmetic. Packed q8 codes and quantization
  metadata are not floating-point `real(kind=1)` values.
- [ ] Implement explicit BF16 round-to-nearest-even and q8 unpack/dequantization.
  Test NaN, infinity, signed zero, subnormal and overflow behavior, bit patterns,
  endianness, safe shift counts, unsigned extraction, and 64-bit file offsets.
  Do not depend on signed overflow. Check IEEE binary32 prerequisites and
  diagnose unsupported representations.
- [ ] Express independent rows/outputs as `DO CONCURRENT` with properly local,
  correctly initialized temporaries. Keep sequential reductions as the initial
  baseline, and keep token and state recurrences serial. Do not transliterate
  SIMD scheduling into mathematically dependent concurrent iterations.
- [ ] Run both user-selected working PATH GFortran and Flang through declared
  Pixi task entry points, recording exact versions and executable provenance,
  and compare both programs against the immutable C oracle, including
  existing Qwen3.6 support. Do not install or substitute a conda Flang package.

**Deliverable / acceptance:** the pure Fortran application passes bit-conversion
edge cases, per-layer/state numerical checks, CPU context greater than 64,
at least 16 generated tokens initially, longer/two-context checks, and finally
end-to-end config/weights/tokenizer/chat/CLI acceptance without C kernels.

### Phase 3a — The same Fortran program on LFortran CPU

**Validated standalone CORE probe, not phase acceptance:** local commits
`7c56cb05f9` and `4a05e9b0b9` integrate exactly the reviewed IBSET fixes
`76f72aa530` and `6991e04c5d`, respectively: sign-extension of folded
integer sign bits and diagnostics for out-of-range constant positions.
At that earlier integration checkpoint, the receiving branch's `src`,
`grammar`, `tests`, and `integration_tests` trees exactly matched accepted
HEAD `6991e04c5d`; only documentation/history differed. Its final LLVM 11
default suites passed: unit 57/57, reference 2,114
output checks, integration 5,582/5,582. That source-equivalent suite evidence
is retained under
`.fix-issue/qwen38-compiler/worktrees/ibset-signbit/.fix-issue/ibset-signbit/`
(`final_{unit,reference,integration}.log`); the full suites were not repeated.

At that milestone, the caller's existing `build/llvm11` compiler was rebuilt with four jobs
through `pixi run -e llvm11 rebuild`; compiler and runtime paths and
LLVM 11.1.0 were verified. Unchanged staged `precision_formats.f90`,
`precision_test_cases.f90`, `test_precision.f90`, and `run_checks.sh`
passed directly with this compiler in normal, `--fast`, and `--std=f23`
modes, with separate module/output directories. **Each mode** passed all
65,536 BF16 roundtrips and independent `DO CONCURRENT` outputs, 22,032
existing C-oracle conversions, 256 q8 boundary combinations, and all nine
rejections (each exited 1 with its required diagnostic). The oracle was
read-only and unchanged. These are the reviewed staged CORE files already
validated with GFortran 16.1.0 and Flang 24.0.0git, not a weakened subset.

Complete local evidence is under `.fix-issue/qwen38-precision-core/`:
`rebuild.log`, `compiler-identity-final.log`, `source-equivalence.log`,
`input-identities.log`, `core-results.tsv`, and each of
`{normal,fast,f23}/{compile.log,checks.log,checks/}`.
No `IEEE_EXCEPTIONS` imports, flag tests, IEEE implementation commits,
lifecycle/schema work, GPU/model runs, or application edits were included.
IEEE remains deferred to #16342. No new compiler blocker was found; this
does not validate groupwise q8 arithmetic or whole-model inference.

- [ ] Keep mandatory CORE precision/oracle checks separate from optional IEEE
  diagnostics in the live application; never waive CORE to accept a compiler.
- [ ] Compile the same application with LFortran, without compiler-specific
  application rewrites that conceal incorrect semantics.
- [ ] Reduce actual failures into MREs and registered standalone integration
  regressions. Fix inference-required compiler bugs in focused commits and
  scoped, isolated worktrees; verify both the reduction and original
  application case. The `IBSET` signed sign-bit conversion fix remains in
  scope because the actual precision conversion needs it. Defer orthogonal
  IEEE flag/lifecycle work to #16342, not an inference-blocking compiler change.
- [ ] Validate against the frozen oracle and both the GFortran and Flang
  applications under the shared correctness contract.

**Deliverable / acceptance:** CPU application correctness with actionable
reduced tests for compiler failures. These are local-only compiler fixes;
publication defaults do not override the explicit no-push/no-PR scope.

### Phase 3b — Correct LFortran Metal offload

- [ ] Establish early standalone capability tests for `int8`/`int16` buffer
  ABI, `transfer`/BitCast lowering, and sign-sensitive shifts before committing
  to the packed-weight implementation.
- [ ] Require diagnostics for unsupported offload, with no silent fallback.
  Record which regions are eligible and prove all eligible concurrent regions
  are offloaded using compiler diagnostics/generated code and runtime evidence.
  Do not force inherently dependent loops into concurrent form.
- [ ] Verify device-resident weights, mutation and alias semantics, recurrent
  states/caches across calls, host/device visibility, and synchronization.
  Prove complete application correctness, not just individual dispatches.

**Deliverable / acceptance:** the same application satisfies the numerical and
text/I/O gates on Metal, with an offload-coverage ledger and explicit
diagnostics for unsupported cases.

### Phase 3c — Architecture-neutral compiler optimization

- [ ] Collect compiler/runtime profiles and optimize demonstrated bottlenecks
  in focused passes with explicit semantic ASR operations and type invariants.
  Keep the backend mechanical: no Qwen-specific names, dimensions, or heuristics.
- [ ] Investigate device residency and mutation/alias correctness, device
  reductions, SIMD lane/workgroup mapping, matrix tiling/shared memory/MMA,
  explicit dequantization and legal fusion, and command-buffer scheduling/sync.
  Apply only transformations whose legality and numerical policy are established.
- [ ] Reapply the reproducible performance contract to compiler-generated code.
  Preserve CPU behavior and standalone regression coverage.

**Deliverable / acceptance:** generic, tested compiler improvements with
profiles and balanced application measurements, not model-specialized backend
shortcuts. Native low-precision real formats need a separate design based on
representation, rounding, and IEEE rules, not width alone or magic kind
numbers. Broader CPU, multivendor GPU, and custom-accelerator support is a
long-term portability roadmap, not a completion claim for this milestone.

## LFortran source assessment: support and candidate gaps

These are source-assessment findings at
`c6ad75832664996251c231ffb541f8c33ac899e1`, **not reproduced bugs** or evidence
that the application works. The historical narrow-integer/scalar-BitCast
gaps below are superseded by the verified milestones above; further Metal
work remains unintegrated and full-application offload is unvalidated. Recheck
candidates with capability tests before deciding that a compiler change is necessary.

| Assessment | Source evidence and implication |
| --- | --- |
| Existing staged GPU pipeline | [Pass manager, lines 323–430][pipeline] contains dispatch, offload, device partition/storage, memory-space, lane, and launch-sync passes. Extend explicit semantics and focused passes rather than duplicating orchestration in codegen. |
| Integer-width restrictions | [Shared scalar-width check, lines 516–535][widths] admits integer kinds 4/8, not 1/2; [Metal capabilities, lines 35–41][caps] further limit integer/real kinds to 4. Packed `int8`/`int16` buffer ABI is an early capability question. |
| Bit reinterpretation and shifts | [GPU expression emitter][expressions] has ordinary Cast lowering but no BitCast case in this assessment; [lines 6073–6075][shifts] map arithmetic and logical right shift operators to `>>`. Test `transfer` and sign-sensitive extraction rather than assuming equivalent bit semantics. |
| Read-only arguments can be copied | [Metal runtime, lines 880–898][copies] reuses a dirty resident buffer when available, otherwise uses inline bytes or acquires/copies a read-only buffer. Measure persistent-weight residency and copy traffic instead of assuming zero-copy reuse. |
| Procedure-boundary synchronization | [Launch-sync policy, lines 24–41][sync] waits before procedure return/end with pending launches, among other hazards. Measure consequences for cross-procedure scheduling without removing required visibility guarantees. |
| Existing lane strategy | [Vector-lane pass, lines 19–110][lanes] distributes proven-independent inner work; [Metal lane capabilities][metal-lanes] select 32 lanes. This is existing machinery, not proof of optimal matrix scheduling. |
| Shared-memory production gap | [Memory-space pass, lines 19–43][spaces] represents Shared/Constant but documents no producer yet. Tiling needs explicit storage semantics and synchronization, not codegen-only annotations. |
| Host-side reduction fold | [Offload launch, lines 401–529][reductions] allocates per-iteration accumulators and folds them on the host. Device reduction work must preserve the declared reduction and numerical contracts. |
| Transform applicability | [Loop-transform applicability, lines 96–98][transforms] currently selects CUDA only. Metal legality/profitability needs demonstrated capability, not merely enabling an existing switch. |

## Toolchain, regression, and authorship rules

Use Pixi exclusively for dependency provisioning and declared build/test task
entry points; no system installers or unapproved substitute toolchains. Keep
MLX pinned through the application manifest/lock. The approved CPU oracles
are **both existing working PATH GFortran and Flang**, invoked through Pixi
tasks with exact versions and executable/installation provenance saved and
inspected, not compiler packages to install or pin. Preserve the selected
PATH tools; do not install conda Flang, change global/user toolchains, or
substitute a host LFortran.

The application's optional `fortran-precision` environment uses
`no-default-feature = true` and no package dependencies, so precision checks
do not pull in MLX/Python. From `$QWEN_REPO`, run:

```bash
mkdir -p build/fortran-precision
pixi run -e fortran-precision precision-versions > build/fortran-precision/versions.log 2>&1
pixi run -e fortran-precision precision-test > build/fortran-precision/tests.log 2>&1
```

Inspect both complete logs. The C test oracle is built/generated before the
Fortran builds; use separate module/output directories for both compilers
and at most two CPU compiler jobs. This approval does not change LFortran's
toolchain policy: compiler builds use Pixi `llvm11` unless a task explicitly
requires another environment, and all reference tests/updates require LLVM 11.

From the assigned LFortran worktree root, the established entry points are:

```bash
CMAKE_BUILD_PARALLEL_LEVEL=8 pixi run -e llvm11 build > build.log 2>&1
# After source edits; configure again only when required by generator inputs/options.
CMAKE_BUILD_PARALLEL_LEVEL=8 pixi run -e llvm11 rebuild > rebuild.log 2>&1
pixi run -e llvm11 ctest -j8 > unit.log 2>&1
pixi run -e llvm11 tests -j8 > reference.log 2>&1
pixi run -e llvm11 integration_tests -j8 > integration.log 2>&1
```

The verified combined-compiler run above used these Pixi entry points with
three CPU jobs and separately leased serial GPU units. Build once, then rebuild
unless generator inputs or configuration change; allocate the job budget
across workers. Save and inspect logs, verify
the selected compiler and LLVM versions, and follow the repository's targeted
and full-suite requirements for compiler changes before any later authorized
push. No push is authorized now.

Whole models are application validation and compiler-bug generators. Compiler
regressions must be reduced, standalone, and registered, normally integration
tests with at least `gfortran` and `llvm` labels; do not add full models to
Quick CI. Preserve tracked and untracked user changes. Stage only owned files,
keep commits focused, and use the configured human author/committer identity
without coauthor or AI-attribution trailers.

## Risk ledger

| Risk | Mitigation / gate |
| --- | --- |
| Artifact name suggests the wrong architecture | Verify config/index, tensor shapes, and pinned MLX behavior; hash identities in phase 0. |
| Existing tests accept failure or short matching prefixes | Negative harness tests; exact counts; teacher-forced per-layer/state validation at longer/two contexts. |
| Hybrid recurrence or cache bugs emerge only later | Context greater than 64, sustained sequences, reset/reuse tests, and explicit update/alias/hazard checks. |
| Packed storage changes numerical meaning | Portable bit conversions and special-value tests first; explicit round points and immutable oracle. |
| Optimizations change precision or reduction semantics | Fixed FMA/reassociation policy and numerical bounds; reject failures rather than relaxing acceptance. |
| Residency, host folds, or procedure waits hide transfer costs | Copy/allocation/dispatch telemetry, offload ledger, and compiler/runtime profiles before optimization. |
| GPU contention or thermal/cache state creates false speedups | Serial GPU jobs, warmup/cooldown, separate cold/warm runs, repeated medians/spread and >=2% evidence. |
| Narrow optimization regresses another workload or old model | Balanced measurements plus preserved Qwen3.6/MoE regression coverage at every relevant gate. |
| Full-model complexity obscures compiler defects | Reduce actual failures into registered standalone tests; isolated scoped local fixes. |
| Native kinds or model-specific compiler shortcuts consume scope | Standard fallback first; separate representation design; generic ASR invariants and focused passes. |

## Next immediate action

Diagnose the LFortran CPU failure boundary from the retained evidence in a
separately authorized reduction; do not automatically rerun the model or assert
an unproved cause. Repair the introduced GPU control regressions, reconcile
references and run the feature-branch suites before integration. Distinguish
qualified same-input math evidence from the still-failing bit-exact fixture
and unvalidated Fortran GPU drivers. The integrated compiler's green suites do
not cover this newer work. Preserve frozen bounds and the documented C80
failure while awaiting quiet RMS-candidate timing and the remaining matched
MLX/text-interface gates. Optional IEEE work remains deferred.

[pipeline]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/pass/pass_manager.h#L323-L430
[widths]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/codegen/gpu_utils.h#L516-L535
[caps]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/pass/gpu_decline.cpp#L35-L41
[expressions]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/codegen/asr_to_gpu_c.h#L4987-L5267
[shifts]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/codegen/asr_to_gpu_c.h#L6073-L6075
[copies]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/runtime/lfortran_gpu_metal.m#L880-L898
[sync]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/pass/gpu_launch_sync.cpp#L24-L41
[lanes]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/pass/gpu_vector_lanes.cpp#L19-L110
[metal-lanes]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/pass/gpu_decline.cpp#L45-L48
[spaces]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/pass/gpu_memory_space.cpp#L19-L43
[reductions]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/pass/gpu_offload_launch.cpp#L401-L529
[transforms]: https://github.com/lfortran/lfortran/blob/c6ad75832664996251c231ffb541f8c33ac899e1/src/libasr/pass/gpu_loop_utils.cpp#L96-L98
