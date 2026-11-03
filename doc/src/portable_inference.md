# Portable inference: staged roadmap

**Status: #16701's #16713 is READY on verified 12/12 Quick success; #14625 draft #16716 has a
qualified local gate but an observed c7dc-head macOS CI failure. Test-lock support
#16709 is READY, not merged. The local #14626 candidate passes targeted original
checks; full suites are in progress. Combined `1b9434d1` compiles 9 modules/
3 drivers, but its first qwen-raw link fails, exit 10. No new native process,
GPU launch, loaded runtime, token or reset result; prior tiny reset failed.
No real-27B Fortran GPU trial or tokens/s. The user's other agents own compiler
fixes; six original PRs were user-merged, not by us.**

The cef-bound synthetic adapter is accepted only at its saved scope;
production bindings/admission, tiny and real-GPU inference remain unqualified.
Historical CPU/H proofs are retained; slow CPU model reruns stay cancelled.

This roadmap records bounded real-CPU short/reset correctness, not all-workload
correctness or competitive LFortran speed. The milestones below do not establish
full LFortran real-model, text-interface, or complete
Fortran Metal acceptance. Unqualified MLX parity and release claims remain
unearned; the phase exit gates remain open.

## Current status, speeds and next plan

**Overnight fixing milestone (2026-11-03):** independent workers have progressed
beyond the historical vanilla-93fa compile blocker. These are isolated compiler
fixes, **not root integration, current-main/model acceptance or a combined gate**.
Fixing worktrees below are under `K=.fix-issue/qwen38-compiler/worktrees`.
The initial CI snapshot was **2026-11-03T13:23Z**, bound to the stated heads.
#16713 readiness now uses later completed direct checks/readback; other later
outcomes are not inferred.

| Effort | Pinned source / publication | Qualified current status |
| --- | --- | --- |
| Host shape, `K/issue-16701-host-shape` | Compiler `21d20efd7fdfac974c0b55be2f5aedfb50700afa`; portability-only `db36ebaa809b24f864cb42ac5950c36b7d182afc`; [#16713](https://github.com/lfortran/lfortran/pull/16713) **READY**, not merged | Original #16701 fixed; fresh review2 clean 0/0/0. Accepted unit 59/59 with reviewed lock-only overlay; source-equivalent reference 1650 cases/2154 outputs and default integration 5810 PASS retained. Direct current-head Quick 12/12 PASS, run `41634361332` SUCCESS/no failed jobs; zero human/inline feedback, REST mergeable-clean, non-draft/unchanged-head readback verified. |
| Identifiers, `K/issue-14625-metal-identifiers` | Original name fix `540d357d`, CUDA_CPU closure `9780e662`, reference-only `d9474dd`; draft [#16716](https://github.com/lfortran/lfortran/pull/16716), observed `c7dc84d3fa1a7e9f257214b6715b6fb45ea49a2e` | Prior macOS `gpu_metal_80` host `t`/`x_gpu` regression repaired by canonical host-member capture before BLOCK-alias retarget; new `gpu_identifiers_02`. NEW 59 units/5812 default integration/2154 LLVM11 outputs PASS, one inert entry, no updates/skips; three fresh native processes, total 3 dispatches/completions. Fresh review2 clean 0/0/0, 263 proofs audited. NEW Quick `41640146296` fails macOS job `125931854869`, others pending—not green; dedicated CI fixer owns investigation. Not silently attributed to the prior repaired failure. |
| Test-lock location, `J=K/gpu-run-lock-location` | [#16709](https://github.com/lfortran/lfortran/pull/16709), `b561092e08ad7f38c98e113bafc893aca99f2acd` | **READY**, not merged; all 12 Quick PASS, run `41629493893`, fresh review2 zero issues, no human/inline feedback; live non-draft/mergeable-clean. Runner source unchanged from reviewed `06cc418…`: default `/tmp` remains; opt-in `LFORTRAN_GPU_LOCK_DIR` changes environment-specific test-lock location only. Not a numerical compiler fix, PATH shim or guard relaxation. |
| Optional launch, `P=K/issue-14626-optional-launch` | Local clean `0e46434d4dbc92f5ef6044b659455d273b861167`, **unpushed/no PR**; reproduced on vanilla `4768d2a7` too | Original #14626 fully fixed within verified GFortran/CPU/CUDA_CPU/Metal scope. Full default suites in progress: reviewed-overlay unit 59 PASS, reference/integration pending; **not suites-green**. Native CUDA hardware untested; no whole-LLM acceptance. |

**Unit-gate qualification is mandatory:** host-shape/identifier/optional units
use the exact reviewed J `06cc418…` **lock-assignment-only overlay**, normal
Pixi CTest, then exact restoration. Host-shape's earlier PATH-adapter 59/59 is
**rejected gate evidence**, never silently substituted. Its reference/default
integration logs are reused, not rerun after the compiler-unchanged test-only
portability follow-up; original zero-interception/PATH-exposure qualifications
remain attached. These are not unmodified default-`/tmp` executions or new
original-fixture gates. Identifier's current full suites are new, not pooled.
Host-shape's watcher **exit 1** receipt is retained, cause unasserted; it is
**not a CI-failure claim**. Readiness is independently based on direct job/run
success and non-draft readback, not the watcher status or human sign-off.

The optional fix also repairs tightly coupled addressable backing-state for
aggregate views using unchanged #16694 conservative alias rules. Fresh original
body **2/2**, comment **2/2**, presence **3/3** native dispatch/completion checks
pass. Qualified exact-current proof reuse covers projection **4/4**, regression
**15/15 each normal/fast/f23**, aggregate **1/1**; not fresh execution of every
reused row or a native-CUDA claim. Full-suite ownership remains separate.

**Combined application, local only:** `O=K/overnight-combined-metal` is
**not PR/pushable**. Prior executed `0a273ba778bbe17279fab87bd5956291e602917b`
compiled unchanged **9/9 modules + 3/3 drivers** and executed tiny, but failed
reset after **966 dispatches/completions**. First identical-input divergence:
prefix000/layer0/QKV, absent optional bias suppresses the needed projection
(kernel5 ran, kernel6 did not), matching #14626. Older `d276` nonfinite/
631-dispatch failure is preserved; **same cause is not established**.
The older host-shape-worker static mapping was **27 concurrent sites = 16 outer
GPU kernels + 11 nested device sites**; it is not new-O lowering/execution proof.
Composer has released clean **`1b9434d15ebdd87c92141701e17432035b5a8f3a`**:
P `0e464` then identifiers `c7dc` integrated without conflicts, **REBUILD PASS**.
Compiler SHA-256 `f008e56a8fb235f3f49f0eb3fb03d55be38766997189d06a2cfb4f7d6b87002c`;
runtime prefix `97587eaa…`, Metal prefix `bd50f4b49…`, composition pins
`update-canonical-member`. Old 540 artifacts/four native ledgers/FN17 are
preserved. The completed checker compiled **9/9 modules + 3/3 drivers**, but
the **first qwen-raw link FAILED, exit 10**, with an undefined specialized
`linear_q8_bf16_integer…` symbol. The native ledger is **0/3 sealed**:
**no GPU launch, loaded runtime, token or reset result**. All FN17/source pins
are unchanged. Only **27 source DC sites** were counted; fresh 16+11 lowering
and dynamic coverage are **unverified**.
Proof: `O/.fix-issue/overnight-combined/optional-correctness/{report.json,binding-manifest.json,result-receipt.json}`.
A fresh reducer compares the prior working 0a compile/link protocol before
classifying **compiler regression versus harness mistake**; no issue filed or
cause assigned. This is separate from G's independent CI2 investigation.
No fresh tiny/reset PASS, real
27B Fortran GPU trial or GPU tokens/s. FN numerical c077/all 17 protected hashes
remain unchanged; `750367` is supervisor-only.

Evidence: host-shape `.fix-issue/16701/{state.md,suites.md,suites-summary.json}`;
identifier `.fix-issue/14625/ci-fix1/{diagnosis.md,publication.json,manifest.json}`;
optional `.fix-issue/14626/{fix_1.md,check_1.md,original-check/handoff.json,state.md}`
in their respective K worktrees. No new unrelated compiler bug is established
by the identifier CI metadata.

**Historical completed 93fa readiness milestone:** W remains
`.fix-issue/qwen38-compiler/worktrees/main-retry-4472fde0b6df`;
C is `.fix-issue/qwen38-publish-20261101`. The required generator **BUILD** at f4
was followed by incremental **REBUILD** to include newly merged #16628.
Latest TESTED source is `93fa1ca0fa1b58607418030183ba446671c14551`,
LLVM11.1.0 Debug `-g -O2` / assertions / native Metal. Compiler SHA-256:
`730e45e15c49b5b11c78430594c9632c469c2f7b923d651b99f156b46eb21e50`;
runtime:
`20ba972375c9b9fbcff1a7ac905268cf3c13ed9b54779635ea9352fb90d31dfc`.
Displayed `0.68.0-536-gf4e95` is stale text, not the actual source identity.
Evidence: `W/.fix-issue/main-93fa-fortran-gpu-readiness/handoff.json`.

Original **#16604/#16606/#16616/#16613/#16628 all compile/link/native PASS**,
each **one dispatch / one completion**. The newer #16616 19/58-line modules
also compile-only PASS. FN c077/all 17 hashes are unchanged; seven modules
pass, but `dense_kernels` lines **545–609** block on host temporary sizing.
Dense model/three drivers remain blocked, tiny **NOT_RUN**, and complete
27-site execution/conditional coverage is unproved. The old three barriers
are no longer current failures of those original inputs.

New report **#16701**, “Metal offload: runtime BLOCK-local row gather cannot
be sized on the host”, has a **54-line MRE**: strict GFortran `-c` 0 /
LFortran `-c` 5, only `gpu_kernel_finalize`, on 93fa. Host shape recovery for
generated `UBOUND(partials,2)` is missing with runtime extent/nested concurrency;
fast mode is unnecessary. Not a proved #16640 regression, and old A/B/C
candidates are not demonstrated remedies. A qualified dump-only follow-on
crash is recorded locally, **not a separate confirmed bug**.
Proofs: `C/main-93fa-host-workspace-bug-report/` (verified public body/#16617)
and `W/.fix-issue/main-93fa-host-workspace-mre/handoff.json`.

**Unmasked follow-ups:** A exact-section c17 and C scalar SUM now compile/link
with passing GFortran controls; old A graph/C #16616 masks are resolved.
Exact archived E (`dd96e` source prefix) passes minimal/original-strict
LFortran `-c` and fresh GFortran checks: old verifier failure gone, **E not run**.
The 128 MiB guard correctly blocked unchanged 256 MiB heap plans; a separate
bounded **512 MiB total / 2 GiB RSS grant** followed a 320 MiB forecast/normal
pressure. Only the A/C test programs were recompiled/relinked from unchanged
inputs/flags/compiler/runtime and freshly hash-bound, **not a compiler rebuild
or source workaround**.

One A-c17 native run exits 0, `PASS 17 0 0.25 0`; one C run exits 0, `ok`.
Original assertions pass; pinned runtime and AGX Metal are confirmed.
**For A/C, actual dispatch/completion counts, allocation bytes and physical
peaks are UNMEASURED**:
the unchanged recipe exported no counters. Host-sampled RSS **38.4/46.9 MB
is not GPU footprint**; the 320 MiB forecast and OS 86% indicator are not
physical-RAM proof. Heap remains 256 MiB; no observed optimization savings,
model fit or all-GPU coverage follows. Children/scratch/lock are released;
earlier proofs/ledgers are preserved.
Evidence: `W/.fix-issue/main-93fa-unmasked-followups/{handoff.json,completion.json}`
and `W/.fix-issue/main-93fa-unmasked-followups/native-256m/recreated/{report.txt,handoff.json,completion.json}`.
These A/C functional passes remain separate from historical #16649 candidate
handoffs and B's measured cumulative-buffer observations.

**Historical upstream-int16 acceptance:** in worktree
`W=.fix-issue/qwen38-compiler/worktrees/main-retry-4472fde0b6df`, tested source
`a76f9fb5b3d547bfffb70b36f7b54c1a0455a45c` contains the user's merged #16614,
separate from our six original PRs. W used **rebuild only**: no actual generator/
native-configuration change. Debug `-g -O2` / assertions / LLVM11.1.0 / native Metal.
Compiler SHA-256:
`5a5564cee7561b3333c8acc1fc9f2665b30148bcb5ad5ba06f2ae73eebac71a5`;
runtime remains
`8397f04d5687dc3dd9f064f3dee138ce9a4c093be5fd6d1b10af0785c638820d`.
Reported `0.68.0-493-g7d9` is **stale version text, not actual source**;
do not reconfigure solely to change that string.
Evidence: `W/.fix-issue/latest-main-qwen-retry/update-a76f/` and
`W/.fix-issue/main-a76f-llm-recheck/{handoff.json,diagnostic-comparison.json}`.

The **unchanged original #16603**, SHA-256
`c690fc6b6c6ee407137bc35043c32fd9993894e5da567822d04dfe1e4446335f`,
passes minimal/strict compile+link and **one native Metal run**:
**1 dispatch / 1 completion / 512 B, `y=[3,3]`**. The generated kernel has
`device int16_t *partial_values`. This accepts **that exact original at tested
main**, not the whole int8/int16 envelope, whole #16614 PR or LLM inference.
Fortran c077/all 17 hashes are unchanged. Seven modules pass; dense kernels
exit 3, dense model/three drivers remain blocked. The **three int16 errors are
gone**; remaining primary GPU messages are #16604 (integer(8) `q_offset`) and
#16606 (strided partials copy), now without spans. Two additional ASR messages
involve symtab-not-found / `__libasr_extent_weights_1` during
`replace_with_compile_time_values`. The completed **19-line core / 58-line
BF16 reduction confirms the same #16616 host-extent ownership bug**, without
#16604/#16606 primary errors: LFortran `-c` exits 3 in `gpu_offload`, GFortran
`-c` exits 0; **no runtime**. The original whole-application terminal failure
is in `replace_with_compile_time_values`, not the reducer's `gpu_offload`
stage. This is not evidence of a #16614 regression or the old BF16 D diagnosis.
Public #16616/#16617 body updates/readbacks are verified; all 23 original
checkboxes were preserved before the new proposal below.
Proofs: `C/main-a76f-extent-report-update` and
`W/.fix-issue/main-a76f-weights-extent-mre/handoff.json`.
Tiny/real-model inference and GPU
tokens/s remain **NOT_RUN**.

**Historical completed 7d9 recheck:** worktree
`W=.fix-issue/qwen38-compiler/worktrees/main-retry-4472fde0b6df` was updated/built to
`7d9b6cc16d29d2fad47d6d1260211731ad330263`. Actual ASR/CMake/build0 inputs
changed, not just version metadata; Debug `-g -O2` / assertions / LLVM11.1.0.
Compiler SHA-256:
`b9ec46271ac78ff086b00c912ecc9f30fec561079044828e84ace823a6f8601c`;
runtime:
`8397f04d5687dc3dd9f064f3dee138ce9a4c093be5fd6d1b10af0785c638820d`.
This is the **latest tested snapshot, not a live-main claim**.
Setup: `W/.fix-issue/latest-main-qwen-retry/update-7d9/`; report-only evidence:
`W/.fix-issue/main-7d9-llm-recheck/{report.txt,handoff.json}`.

**Seven modules PASS; `dense_kernels` exit 5**, with the same five cef
diagnostics: int16 `partial_values` three times, int64 `q_offset` and strided
section copy. `dense_model` plus three drivers are blocked.
#16603/#16604/#16606 minimal/original compilation exits 5;
#16616/#16628 exits 3. #16613 compiles/links, but native Metal shader failure
exits 1 with **zero dispatches/allocations**. No new unrelated bugs;
tiny, real GPU and throughput **NOT_RUN**. Fortran remains
`c077fe0263e054dcbdde70808f938c8b71b9f3c5`, all 17 hashes untouched.
At that 7d9 checkpoint, the separate remaining-case report-only replay had
not yet completed; completed nested/identifier handoffs are recorded below.

**Tracking and ownership:** [#16617](https://github.com/lfortran/lfortran/issues/16617)
tracks **22 reports created here**: the prior 20 plus optimization proposals
#16702/#16703; reused issues/PRs are separate and these fixing steps add no new report.
#16701's verified public body/tracker update preserves prior checkbox states
and content except its own status paragraph; that checkpoint had **25 checkboxes**.
The live inventory now has **27**, with human states preserved, not ticked
because a local fix passed.
The user's other agents fix **all compiler bugs**. This effort owns LLM
bring-up, faithful MREs/issues and existing-source candidate handoffs,
**not competing fixes**. Bodies actually handed off:
`6606 -> #16603`, `05409 -> #16606`, `cf5115 -> #16613`,
`7b7 -> #16616`, `24c -> #16628`—**unverified/non-PR-ready source candidates**,
not PRs, comments or pushes. #16618 requests **explicit Safe/Precise opt-in**,
not an unconditional Fortran violation or legacy-flag regression.
Tracking/proofs: `C=.fix-issue/qwen38-publish-20261101`,
`C/sessionfiles/llm-tracking-issue` and `C/main-*-bug-report`.
#16601/#16569 chunking is **CUDA-only**, with no launch reductions and default
limit >2^31-1: **not a Metal Qwen head-memory reduction or fit claim**.
Since the preceding milestone, #16644 reports pointer-view incorrect GPU
results; #16646 reports `PASS(self)` ASR failure on CPU/Metal with
`--all-mangling --separate-compilation --verify-all-passes`. Both are already
linked from #16617. Reused **#14626 (optional), #14625 (names), #16091 (component)**
are separate, not ours. The nested case overlaps active #16640; its original
pass-after remains untested. Completed handoffs:
`C/main-nested-optional-bug-reports/handoff.json`,
`C/main-metal-identifier-bug-reports/{report.md,handoff.json}` and refreshed
`C/sessionfiles/local-upstream-inventory/{inventory.md,handoff.json}`.
These preserve qualified historical-source candidates, not current-main
acceptance or completion of the broader narrow-storage envelope.

**Final source handoffs and memory witnesses:** completed
`C/sessionfiles/int64-existing-source-handoff/handoff.json` records four
complete production diffs (`4ee/a4/be04/5740`) now public in #16604/#16617,
byte-exact **historical/unapplied, not drop-in or PR-ready**. Dependencies are
guard -> closure -> normalization; literal overlaps #15895/#16532/#16614 and
wide #16547 remain qualified. Current storage03/closure replays, native/full
suites are unproved; CUDA d27 remains unresolved.

Historical a76f memory replay evidence: `W/.fix-issue/main-a76f-memory-witness-replays/handoff.json`.
A (exact-section c17 witness): GFortran PASS / LFortran exit 3 in
`device_launch_expand` / `device_call`; qualified #16640 overlap, **no allocation
comparison**. B (false/true): both GFortran/native PASS, each **one dispatch /
one completion / 16,797,696 B observed cumulative buffers**; **16,777,216 B
unconditional workspace is codegen-derived**, not physical peak, wrong results,
OOM or real-model fit. C (scalar SUM): both GFortran controls pass, GPU is
masked by #16616, CPU `sum_11` passes. **Only two native runs**, no source fixes.

Optimization proposal **#16649**, “Metal GPU optimization: skip private workspace
storage when a uniform branch is inactive”, publishes complete **87,663 B**
byte-exact in four ordered whole-candidate comments: b823 (**6590910049**),
420 (**6590910560**), f8 (**6590911080**), f5 (**6590911515**). The body exceeded
65,536 B; the user authorized comments **on this new issue only**, with no
split/truncated candidate. Only **b823's scoped query API** is a proved
prerequisite—not whole A or B/C behavioral dependency. At that checkpoint A/C
were separately blocked/historical, not new confirmed main bugs. Matrix forwarding/M1
elimination remain unimplemented proposals; public candidate comments are
**not current patch acceptance, implementation, build/test or PR evidence**.
Receipts/grouping: `C/sessionfiles/existing-memory-optimization-report/`
(`publication/`, preparatory handoff and grouping-readiness snapshot).
#16617 then preserved all prior content/23 checkbox states, **24 total** before #16701.

**Historical vanilla round:** 93fa is that tested baseline, **not the current tip**.
Later observed remote `4639d61884e0d198a90acf030c7f873887919ead` is #16700
host-procedure-frame specialization, not an identified #16701 fix.
#16701 then had no linked fix PR; overnight #16713 above supersedes that status.
Do not refresh solely for an unrelated main advance; isolated original-case
acceptance is distinct from the pending combined tiny/reset gate.

**Historical 2026-11-02 vanilla-main retry:** the user requested latest main and every bug
reported; many Metal fixes landed, while 64-bit-index work continues.
Vanilla `4472fde0b6dfe69fb43a61596e67b911794ee28a` was fetched once at
**2026-11-02T17:04:47Z**, then freshly built in
`W=.fix-issue/qwen38-compiler/worktrees/main-retry-4472fde0b6df`,
branch `validation/qwen38-main-4472fde0b6df`: Pixi LLVM11.1.0 Debug `-g -O2`,
assertions/internal allocation checks, two CPU jobs; **307 s / 5 GiB sampled
peak are build costs**, not inference measurements. **No old H patches imported**;
Fortran `FN:c077` and all 17 application hashes are unchanged.
Built compiler SHA-256:
`321366b5459a47af8cad9e3cacaeffbd99299a5131c1a8683e7df0f14048235f`;
runtime 0.68.0 dylib:
`89321199ed7853d957cc083f411def6a4647f3e27b67eb8f3b93b1f7dac948b8`.

At that snapshot, **seven modules PASS; `dense_kernels` FAILS, exit 3**:
int16 `partial_values` occurs three times, plus int64 `q_offset` and strided
`partials(d,:)` contiguous-copy diagnostics. `dense_model`, drivers, tiny/
operator controls and current large plans are **NOT_RUN; zero application
GPU dispatches**. Separate own-GFortran strict replay and an **18-output tiny
q8 matrix oracle PASS**, not CPU model inference. An extra
`bf16_bits_to_real32` SymbolTable verifier error has **unproved independence**.
Main's runtime options are **nil = default/unknown actual math policy**,
not H's Safe/Precise proof.

| 4472 reproducer | Bounded evidence | Attribution limit |
| --- | --- | --- |
| A: int16 private array, `W/minimal.f90` + `run.sh`, 21 lines / 650 B | LFortran minimal/full flags exit 5; strict GFortran 0/0; kind(4) control PASS. | Shared GPU-preflight width floor; no verified duplicate. |
| B: captured int64 offset, `W/mre_gpu_int64_offset.f90` + unique runner, 12 lines / 315 B | LFortran exit 5 / GFortran 0/0; kind(4) control PASS. | Metal `max_integer_kind=4` rejects read-only captured int64; no RoPE/BLOCK/dummy context needed. Overlap with user index work is unproved. |

Saved proofs: `.fix-issue/main-4472-{int16-mre,int64-offset-mre}`.
At that checkpoint C (section copy) and D (verifier) were not isolated and
no new issues had been filed; the update for merged helper #16558 was pending.
The completed 7d9 recheck/tracker above supersedes that pending status.
Old H optimization work remains held; historical proofs do not certify main.

**2026-11-01 CPU milestone:** native Fortran has 140 bounded checks under both
CPU compilers and a real Flang 27B short17/full-second-request-reset PASS on
source `98773cd4`; GFortran reached its cap without a result. The `c077fe02`
diagnostic review is closed. Unchanged `G:d94db95877` with app `c077` now
passes real LFortran short17 and complete second-request reset. Current
`FN:7503676` changes only the shared supervisor; Fortran is frozen. CPU scope
is complete for Flang/LFortran short/reset, not all intermediates, workloads
or speed. No compiler fix is credited with this CPU acceptance.
Historical GPU bring-up at `H:b1834f03` passes saved primitives and tiny P5/G3/
second-request reset after five reviewed compiler fixes, with Fortran frozen.
This is **bounded correctness**, not real-27B GPU, physical-fit, universal
intermediate-bitidentity or speed acceptance. The stable-chain suite attempt
is complete but **not green**: one introduced CUDA reference failure remains.
Memory review B1–B3 remains closed at `H:23296b2c`. Bounded `f8b5dc0` reduces
unchanged-Qwen head planned private GPU scratch to **5,166,049,280 B**;
`H:f5e193c4` was warning-only, with driver bindings then pending.
H full suites and actual real-27B GPU were **NOT_RUN**. These H bounded
proofs and the scratch plan are **historical, not vanilla-main evidence**.
No fit or speed acceptance follows; current monitored-trial qualification
and real bindings/headroom/lease remain pending.
Further CPU model inference/benchmarks are cancelled/deferred; none were
active. Small compiler regressions and suites are still required.

The native C+Metal baseline is committed and backed up;
the original two-arm resident measurements are **completed and audited CLEAN**
at their saved-evidence scope. Short resident gates pass, but 2K prefill
FAILS and other 2K gates are INCONCLUSIVE; those performance outcomes remain
unchanged.
QMM64's corrected batched operator screen passes and limited local integration
passes functional controls, but the new audited three-arm model comparison
**FAILS readiness and promotion**. The completed unprivileged diagnostic did
**not reproduce the severe GPU slowdown**; it does not explain or waive the
historical failure. The user now explicitly chose **Fortran reference on CPU,
then correct offload, then optimization to match our Metal kernels**.
No further C tuning is currently selected.
Original cold results, archived residency LOSS and the
resource-count INCONCLUSIVE outcome remain unchanged.

**Selected research reference:** validated native-math source `8640d2df`
and audited PERF `86fb02f9`, not unpromoted QMM64 `4921bf7b`.
`9dd05ab` is instrumentation-only, not a different mathematical baseline.
Resuming Fortran is an **explicit user disposition**, not a waiver of the
historical C performance FAIL/outlier or a claim of unqualified MLX parity.
The goal is CPU correctness, correct offload, then comparable Metal speed;
no new Fortran throughput is accepted.

**Correctness bring-up policy:** do not change Fortran to work around compiler
bugs; **fix LFortran bugs in LFortran**. Fortran edits are allowed only for
performance and must preserve correctness. CPU success is not authorization
to weaken offload, state/reset, numerical or reference gates.

**Historical publication stream:** existing fixes/commits/proofs were reused
with fresh per-fix review and genuine dependency grouping, preserving focused
commits. The six original PRs below were user-merged, not merged by this effort.
Current compiler fixing belongs to the user's other agents. Frozen inventory has **26 fixes -> 16
tentative envelopes (11 independent / 5 groups)**, **not fully processed**.
New memory optimizations are **additional work**, not completed inventory items.
Frozen inventory base is `e264d8612ea64b53dd8e38d35a2695af54a8d833`; fork `certik/lfortran`,
remote `ondrej`. Authority:
`.fix-issue/qwen38-publish-20261101/{selection,dependency-map,reference-ownership}.json`.

| Published PR — all MERGED | Historical local/CI head | Upstream merge commit | Qualified historical evidence |
| --- | --- | --- | --- |
| [#16548](https://github.com/lfortran/lfortran/pull/16548), private test paths | `fa9338bbd02fe8444517500627314de601004025` | `3380bbc30ad83f55c047a0bd34bfff49a8168531` | Quick 12/12 SUCCESS, run `41388707191`. |
| [#16551](https://github.com/lfortran/lfortran/pull/16551), IBSET | `45498ebdb37e409d8d141b5fd06bbf555e39f0c8` | `edcaed079f2a909253be892470920c7f2d475d3d` | Two focused commits; qualified 59 units / 2128 references / 5668 default integration PASS; Quick 12/12, run `41391313055`. |
| [#16552](https://github.com/lfortran/lfortran/pull/16552), INQUIRE SIZE, fixes #16353 | `9f252ccb60660d9417f9be15c66478aa46f3feca` | `544fe19a91ab194b4d9b29afe87c9ff303684133` | Recursive metadata-import/caller failure propagated; Quick 12/12, run `41427088566`, including actual native GCC Release; partial runs not pooled. |
| [#16553](https://github.com/lfortran/lfortran/pull/16553), RESHAPE | `051b12e3397f1566c4c01e454edb3d12b55d860d` | `dcff29d2fa7fd394c5f71887a1df81eda4c1c64b` | Qualified 59 units / 2128 references / 5668 default integration PASS; Quick 12/12, run `41396318986`. |
| [#16558](https://github.com/lfortran/lfortran/pull/16558), nested BLOCK helper capture | `f1ac9a98d99e3ed6bcec21caf25cdd119277ea8c` | `86e9c2cf03b173a18dc8538e42729393fa9fdc6c` | Quick 12/12, run `41409480375`; targeted modes/current review. Old 59 units / 5668 default integration / 2128 references **CARRIED** across CMake-only rebase, not fresh full suites. |
| [#16559](https://github.com/lfortran/lfortran/pull/16559), independent scalar LOG | `260125119930abc0f14a349173cdba6598bf2f80` | `cef824dcdd1b4253736d2e466e562d80f1338876` | Local review 0/0/0; qualified 59 units / 5675 default integration / 2128 references PASS (1626 entries, one existing backendless entry); old-head Quick 12/12, run `41415635813`. |

**All six merged by upstream/user action, not this workflow.**
#16559's GitHub head is now `9d779b11e9e55917823aa13d256c262005021dff`:
the old `260125` local/CI/review proof **does not certify that later head**.
Zero feedback was recorded at readiness; automated review was not human approval.
Qualified historical local integration used the
exact user-approved #16548 **two-file,
path-only ILP64 overlay**, hash
`2321fc9ff907572337c5d0c172ccc56f9a3acaadb5151e97aff6c7ae5a97fe2b`,
then exact reversal. RESHAPE's body additionally discloses a
**synchronization-only private legacy GPU-lock redirect**. These are qualified
runs, not runs of unchanged old temporary-path fixtures; **no skips or partial-run pooling**.
The overlay/reversal and synchronization-only private GPU-lock qualifications
also apply to the nested BLOCK/scalar LOG local suites above.

**Historical INQUIRE rework:** old `899` CI failure was an unused assertion-only `success` under
**native GCC15.2 Release-Werror, not a WASM runtime failure**. Local `f981`
fixed the warning with a Clang assertion-disabled proxy, **not exact GCC parity**;
review requested located pass diagnostics/failure propagation in `openmp.cpp`.
That f981 verification stopped after **57 CPU+2 Metal
units PASS / integration interrupted at 2487/5669 / references not started**:
not final green, no partial-run pooling. Final `9f252ccb` now passes actual
native GCC Release in Quick; the old proxy/partial runs are not that evidence.

The nested BLOCK/scalar LOG ports use base `d5945a87d452b59493f5081f30cc16c03a09d7c0`.
Nested BLOCK's old `d28` had a real CMake registration conflict and no CI;
the rebase has identical source patch/no `src` conflict. An explicit
force-with-lease against d28 published f1ac; full-suite evidence is carried
under the clean-source-rebase rule, not newly run. Scalar LOG has **no f42
dependency**; original and registered native Metal controls each complete
one dispatch/completion.

**Earlier local-port/diagnostic checkpoints, not freshly rechecked on latest main:**
the rank-2 identifier regression predates H's RESHAPE/memory work:
old `532` introduced stale component imports, corrected in the isolated port
`0d395a8`. References were updated separately at `3df7a8` (24 outputs +
24 metadata; 24/24 targeted PASS). Fresh source review has no remaining defect,
but publication is blocked: the original kind(8) fixture's three registered
Metal/CUDA variants need held support; labels/source are unchanged.
**No #14625 closure claim**: CUDA_CPU scope is outside that issue's scope.

Safe actual pinned-main `e264` proof under lock reproduces a native unallocated
result-component failure, duplicate **#14654**; GFortran/host LLVM PASS,
one dispatch / 768 audited bytes. No issue filed. The earlier unguarded tiny
`--dump-all-passes` run is explicitly excluded, replaced by this safe proof.
A separate old-0d regression03 crash-diagnosis worker failed service 422 after
partial work: **one of two bounded new targets recorded; debugger exit 0 is
not Fortran PASS/GPU proof**. Cleanup is verified, no owned children.
Relationship to #14654 is **UNRESOLVED**; no issue or further execution approval.
Qualified state: `W/.fix-issue/main-7d9-derived-result-crash/partial-status.json`.
Another setup submitted BF16/CUDA_CPU commands in parallel in the same worktree;
no actual time overlap or cross-worker GPU violation is established.
Affected tiny CUDA controls are being repeated serially; no timing claim.

Nested BLOCK capture in merged #16558 supports the default i4/r4
regression (actual Metal/CUDA_CPU and other targeted checks PASS). The original
BF16 MRE passes
capture but later width/TRANSFER JIT is blocked: its original full PASS is
**composite-lineage only**, not standalone acceptance.
Nonfinite port `a06cc091` is blocked by cached BitCast before emission;
source owner `5740a318` plus structural `be04d396` are held with int64/closure.
No isolated causal proof or final grouping decision.
Narrow-storage reused commits plus regression `342e7823` remain blocked by
actual integer-only pipeline failure. A fresh investigator also reproduces
failure with standalone valid minimal MSL in Apple's AGX pipeline compiler;
attribution awaits independent review. **No dummy float/CPU fallback,
GPU pass-after or PR.** Detailed publication state owns the live queue.

The user is separately fixing #15895 and will ping; the int64/closure group
is **held**, with no polling or changes to that PR. The connected 5740 CUDA
unused-complex-struct case still needs follow-up, **not an upstream waiver or
a blanket block on independent fixes**. Existing unrelated follow-ups:
the volatile case duplicates #15732; CLI pass-contract bug #16550 is filed.
The 141-line SDPA diagnostic reproduces on **final4207** custom show-ASR/pass/
cumulative mode (device callgraph during `intrinsic_function`), unchanged at EE;
normal `-c` with the same pass options passes. Main `e264` is masked earlier
by unsupported `partials(d,:)` copy, so attribution/#16550 overlap remain
unproved; no issue filed.

### Implementation status

`F` is the original Fortran application worktree, `FN` the isolated native
Fortran worktree, `M` the historical hand-Metal worktree,
`N` the native-math C+Metal worktree (`project/qwen38-mlx-native`), and `G` the
earlier combined LFortran GPU worktree. `H` is the new isolated compiler
worktree `.fix-issue/qwen38-compiler/worktrees/native-offload`,
`project/qwen38-native-offload` from `d94`. Application features are not yet
fully consolidated into the application caller checkout.

| Effort | Verified status | Speed status |
| --- | --- | --- |
| Frozen scalar C reference, `37ff651` | Checkpoint adaptation complete for text-only, batch-one, greedy raw IDs; frozen math, oracles and bounds retained. | No comparable CPU benchmark. |
| Portable Fortran, `F:a70b69ed0a` | GFortran and Flang each pass real-27B 17-ID/full-reset checks, finite and byte-exact to saved C. Portable integer-backed BF16/q8 works; no new native real kinds. | Heavy correctness traces are **not throughput benchmarks**. |
| Native Fortran, `project/qwen38-fortran-native`, current supervisor `7503676` | Fortran frozen at `c077`; diagnostic review closed. Flang real PASS remains on `98773cd4`, LFortran real short/reset PASS on `c077`. GFortran cap remains incomplete; original `F/a70` preserved. | Flang 1663.13 s / 26.29 GiB and LF 3231.619 s / 27.004 GiB are **correctness costs, not throughput benchmarks**. |
| Historical LFortran CPU, integrated `91f90a5a16` | Earlier tiny/I/O/header/offset proofs pass; its historical real run crashed before first logits. Cause remains undiagnosed; no new compiler fix. | No accepted CPU throughput. |
| Native LFortran CPU, unchanged `G:d94db95877` / LLVM11.1.0 | Earlier `9c07860` primitive/tiny proofs retained. App `c077` real P18/G17 and complete second-request reset PASS, all 17 native IDs/lookahead/counts. Finite guard scope is logits/recurrent FP32 state, not all intermediates. | Bounded short/reset correctness only; no accepted throughput or compiler-source fix. |
| LFortran GPU, combined `G:d94db95877` | Prior tiny-driver proof is retained: IDs, finiteness/self-reset pass, exact/cross-C gates fail. Offloading the new native Fortran branch follows CPU validation, not a promotion of this checkpoint. | No 27B run or accepted throughput; optimization follows correct new offload. |
| Historical native offload, `H:b1834f03` / refs `19ba118f`; bounded `f8b5dc0`, warning-only `f5e193c4` | Saved primitive/tiny GPU gates retained. Stable units 55 CPU+2 Metal / default integration 5620 PASS; references 2122/2123, introduced CUDA failure unresolved. f8 has 48/816/104448 exact native outputs and two-entry/transition controls; planned scratch 5,166,049,280 B. | **Not suites-green**; H full suites NOT_RUN, no physical-peak/model-fit/TPS acceptance. These proofs/plan do not apply to vanilla main. |
| Overnight local combined, `O:1b9434d1`; prior executed tiny `0a273ba7` | New checker: 9 modules/3 drivers compile, first qwen-raw link FAIL exit 10, undefined specialized linear symbol; native ledger 0/3 sealed. Prior 0a reset FAIL after 966 dispatches/completions remains separate. | Local-only, not PR/pushable; 27 new source DC sites only, new 16+11 lowering/dynamic coverage unverified. No new loaded runtime/GPU/token/reset result; regression versus harness unclassified. |
| Latest TESTED upstream baseline, `93fa1ca0` | Original #16604/#16606/#16616/#16613/#16628 compile/link/native PASS, one dispatch/completion each; #16616 new 19/58-line compile-only controls pass. Seven modules pass; dense kernels/model/drivers block on host temporary sizing #16701. | Tiny/real-27B/TPS NOT_RUN; complete 27-site coverage unproved. A/C functional passes have unmeasured GPU counters/physical peaks, not memory savings/fit. 93fa is not a live-tip claim. |
| Native-math C+Metal baseline, `N:8640d2df` / docs `86fb02f9` | Reviewed source baseline committed; binary/four native libraries match the original benchmark snapshot. Short17/reset and every protected 65/1536 ID pass. User-authorized private backup verified. | Audited 24-sample table below remains the validated performance baseline; conventional-prefill qualification remains open. |
| Archived residency experiment, `c71595c7` | Local `experiment/qwen38-residency`, not pushed; functional controls pass and old Battery block is preserved. Production `86fb02f9`, binary `42c8930d…` and four libraries were restored clean. | Short65 ABBA N=2/arm screen **LOSS**, not N4/all-workload/formal regression; no runtime mode promoted. |
| Completed resident comparison, measurement host `7f048673…` | 16 fresh children, 32 fully reported requests and 2,080 exact IDs; source/count/clock/AC-auto/resource gates and independent saved-evidence audit pass. Native math/four libraries and original production remain unchanged. | Historical short PASS / 2K FAIL-INCONCLUSIVE / overall readiness **FAIL** unchanged; no new warm1536 or Fortran acceptance follows. |
| Limited QMM64 candidate, `4921bf7b` | Local `experiment/qwen38-qmm64`, parent `9dd05ab`; short/2K two-request functional controls pass. Only the exact non-split gate/up shape uses 64; other/decode paths stay 32. | Operator screen PASS, but audited three-arm model readiness/promotion **FAIL**. Not promoted or pushed. |
| Historical hand-Metal, `M:c296c2cef9` | SG was accepted for its short scope; earlier qmv4/MMA experiments and their unresolved dispositions remain preserved. | Old AC/Battery observations below, **not pooled with N**. |
| Native MLX | All three fresh paired AC cohorts have complete protected-ID/count/source/power guards. | Conventional and setup-inclusive metrics below; native GPU-busy time remains unknown. |

The root compiler is still `91f90a5a16`: its **57 / 2114 / 5588** green
unit/reference/integration evidence does **not** apply to `G:d94db95877`.
G was rebuilt with LLVM 11.1.0, source tree `7d2e9232d27c5535ea9e709446b2f91020051224`;
the original `638209ef72` fix branch is preserved. Its connected compiler fixes
have targeted/review evidence, but latest full suites, stale-GPU-reference
reconciliation and integration into root remain pending for G/H. The completed
stable `H:b183` attempt passes **55 CPU+2 Metal units / 5620 default LLVM
integration tests**, but references are **2122/2123** after 58 reviewed
updates, checkpoint `19ba118f4753bb294138d99d7d986c0941e9ad3f`.
**Not suites-green:** `gpu_decline_27` still emits invalid CUDA. Attribution
shows root91 rejecting versus Gd94 emitting invalid source after 5740;
that checkpoint's main-emitter evidence was static, runtime untested. The connected
publication job must resolve it; no waiver or blocking unrelated envelopes.

Version-specific CPU evidence: the Flang real control on
`98773cd4c02bb619573e26166919661627fee382` uses 18 prompt/17 generated tokens:
**17 exact native IDs, lookahead 48696, 19 forwards / one prefix / 18 heads
and samplers / 35 logical
tokens**, complete second-request reset, and finite checked logits/persistent
FP32 state. GFortran hit **1800.30 s**, returned no result, demonstrated no
numerical mismatch and was not retried. `c077fe02` is only the stale-z
pruned-prefix diagnostic guard: focused fail-before/pass-after on both
compilers; its diagnostic review is now closed. The Flang run was not rerun
for that guard. Later LFortran acceptance is separately recorded below.
Authority: `FN/artifacts/fortran-native/handoff.json`.

The LFortran bounded snapshot uses
`--fast --std=f23 --no-fast-math --verify-all-passes`, **without an FMA skip**.
Tiny IDs **[41,77,71]**, lookahead 125 and complete reset pass on source
`9c07860`, as earlier bounded evidence. Compiler source/executable `G:d94`
is reused unchanged; evidence:
`G/.fix-issue/qwen38-native-cpu-prep/optimized/handoff.json`.

**Completed real LFortran CPU control:** unchanged `G:d94` / app `c077`,
same optimized flags and no FMA skip, passes all 17 native IDs and lookahead
48696: **19 forwards / one prefix / 18 heads and samplers / 35 tokens**.
Complete second-request **self-reset** is bit-exact across all caches/state,
final logits/logprobs and IDs, **38 forwards / 70 tokens total**. Finite guards
cover recurrent FP32 state/head logits, **not an independent all-intermediate
scan**. Its **3231.619 s / 27.004 GiB** includes an authorized 5 s own-process
sample showing active q8 computation: correctness cost, **not a benchmark/TPS**.
Source/runtime/binary/harness pins and raw paths:
`G/.fix-issue/qwen38-native-cpu-final/real-cpu-short-handoff.json`.
The child and CPU resources are released; the old root91f crash remains
separate historical, undiagnosed evidence.

**Bounded native GPU checkpoint:** `H:b1834f0349c6b746e8f37667c72f05446401b09c`
freshly rebuilt nine modules/driver against unchanged `FN:c077` /
supervisor `7503676`. q8, formerly crashing attention L2112
(CPU/native/GPU byte-exact), and saved recurrent T1/T17 pass unchanged
primitive bounds. Tiny P5/G3 IDs **[41,77,71]**, lookahead 125, all schema3
counts and complete second-request self-reset PASS; terminal cache-prefix
checks retain required state and absent pruned z. **1,639 dispatches /
1,256 completed buffers, all 16 outer kernels observed; 27 source DC sites
mapped, 11 nested**—not all conditional-arm execution.
Identical-input G0 CPU/GPU maximum difference **5.96e-8** is within the
unchanged bound. Later terminal FP32-state differences are **accumulated
trajectory diagnostics, not same-input primitive proof** or universal
intermediate bitidentity. Authority:
`H/.fix-issue/native-fortran-gpu-controls/after-reshape-b183/handoff.json`.

**Historical H memory chain; held pending vanilla-main rebaseline.** Generic
lowering at that checkpoint creates large/repeated temporaries. The bounded
`H/mre_section_heap_growth.f90` now **proves the old heap-capacity failure**:
model-free CPU 17/2048/4096 and GPU 17/2048 PASS; GPU 4096 explicitly exits 1
with heap exhaustion on the unchanged 256 MiB arena, one dispatch/completion,
302,592,512 actual buffer bytes. **512 MiB is counterfactual full-launch
cumulative product demand, not live memory**; the initial 16 MiB reusable
workspace forecast was not acceptance. Authority:
`H/.fix-issue/native-section-extent-mre/report.json`.
Memory optimization review rounds **B1 use-site attributes, B2 late declaration
attributes and B3 missing source-tarball fixture are all CLOSED**, clean at
`H:23296b2c9ce0b16bfc67b042fbb94001f60e0eeb`. Native projection proof retains
**104,448 exact outputs / 352,166,144 cumulative buffer-allocation bytes**:
the counter is **not physical peak**.
New local candidate `H:42070928f724e3ae0c6dd4d4bd4ee90a71d1b353` captures an
explicit ASR workspace guard/logical shape with null-safe pointers. Registered
controls retain inactive **16 MiB -> 0/nil**, active 16 MiB unchanged, values/
bounds/mutations/zero extents, **333 unit assertions / 816 byte-exact small q8
outputs** and fresh review (0 blockers / 0 rework). Actual-app eligibility and
CUDA/fallback coverage are follow-ups; **full suites not run**, no head/
real-model/2K GPU or performance acceptance.

Before the SUM change, actual unchanged q8 had **all seven workspace plans unguarded**:
weights/product each **5,085,593,600 B**, total **15,337,733,120 B**.
The first gate is array-by-data specialization creating two launch sites,
disabling the ABI guard; weights also have a synthesized alias/distinct IF
fences, and product allocation statements are opaque. At M1 only codes/terms
are needed; weights/product/partials are logically inactive, not yet unallocated.
Authority: `H/.fix-issue/native-q8-workspace-gap/{handoff.json,report.md}`.
**Completed bounded local SUM milestone:** `H:ee8757fbc1d074794bbd45939a02de591da622af`
reuses `ReductionOperandReplacer` / `orderedElementwiseReduction` in ASR,
removing the unnecessary product workspace. Frozen actual **M1/parts=1 head
planned workspace is 15,337,733,120 -> 10,252,139,520 B**; the head's numeric
formula remains unchanged. Bounded M1 **48** and M17 **816+104448 outputs**
are byte-exact to native `8640d2d`; Fortran remains `c077`. Production-shaped
**cumulative buffer allocation 352,166,144 -> 289,251,584 B**, not physical peak.
**276 assertions / targeted modes PASS, fresh review 0/0/0; full suites NOT_RUN**.
At ee8757, six remaining buffers were unguarded; no real head/27B/2K GPU or fit/TPS claim.
Keep the earlier M17/parts=2 operator proof distinct from the M1/parts=1 plan.

A generic FP32 SUM follow-up yields `A8800000` (**-2^-46**) versus separately
materialized control **+0**, even with Safe/Precise/no-fast-math. Verified prior
Gd94 compiler/runtime reproduces the same pair; review confirms the unchanged
earlier GPU SUM path/documented contraction qualification, **not a new EE
finding or math-policy change**. Exact4207/main and semantic violation are
not proved; this is not a Qwen failure/regression, whose controls remain byte-exact.

The earlier proposal from `ee8757` targeted multi-launch guards/canonical
polarity, with borrowed/alias handling only when minimally proved. At that
checkpoint, two launches disabled guards; weights' alias was gone but distinct
IF identity remained. Next/work needed writable-callee-noescape proof, next
had a local alias; both site-bound predicates fit existing grammar.
**Projected full M1 plan
10,252,139,520 -> 5,165,056,000 B**; **M17/P2 private workspace
253,698,048 -> 251,731,968 B**, preserving active weights/partials. These are
historical **projections**, not total allocation or physical fit.

**Completed bounded guard milestone:** `f8b5dc0` gives the actual unchanged-Qwen
head **planned private GPU scratch 5,166,049,280 B**, down from `ee8757`
10,252,139,520 B and earlier 15,337,733,120 B; **not physical peak, model fit
or executed inference**. Exact bounded **48/816/104448 native outputs** and
genuine two-entry/transition controls PASS; that H chain's full suites **NOT_RUN**.
Live codes **5,085,593,600 B** dominate. Proposed generic rematerialization could
reach **80,455,680 B** (M17/P2 future **125,902,848 B**), **UNIMPLEMENTED**.

H snapshot `f5e193c47d4a0f0cb5fb7b5d7299a4f9d3afbb62` inserts only `(void)`,
preserving emplace/assert. AppleClang17 NDEBUG-Werror syntax fails before/
passes after; six guard-unit cases / 478 assertions PASS, fresh review 0/0/0.
GCC was missing `cc1plus`: **not Release/GCC parity**. Driver refresh was
pending; no completed new-driver claim.
Generic matrix-only forwarding may be legal, but **M1 full-codes
rematerialization remains fenced without owned-disjoint proof/explicit ASR
contracts**. The 80 MB projection is unimplemented; old optimization work is
held until main is rebaselined.
Fortran remains unchanged, with no default-cap increase.
Real-27B GPU and 2K are **not executed/verified**; targeted operator/scale and
physical-fit proof must precede full-model GPU or profiling.

**Historical strict admission attempts:** original **52 GiB** and candidate
**48 GiB** profiles did not qualify. Independent review found
four gaps: underestimated precharge, blocking/stale measurement watchdog,
descendant/PID cleanup, and one-use execution enforcement. Controller-v2
completed **12 synthetic controls**, reports all four mechanisms reworked and
known children released. The strict V2/V3 approach **was not qualified and was abandoned
for real-run use**; those proofs are preserved, not real-run acceptance.
`memory_pressure` percentage includes active memory: an indicator,
**not unused/allocatable RAM or fit proof**.

**Current user-selected approach: `monitored_trial`.** Pressure/RSS/timeout/
cleanup/headroom remain required, but unexpected Metal allocation growth is
detected **afterward, not prevented by a hard preallocation guarantee**.
Observational mechanism controls comprise **6 offline controls, positive Metal
21 outputs, 4 negatives, 8 targets; 16 owned identities absent**. A 16 MiB
request was observed as **16,859,136 B**, triggering a **post-allocation**
8 MiB-threshold abort. Review accepted **synthetic-only** 5 s bootstrap/
500 ms ongoing freshness, metrics, one-use and API preservation, but found
**one blocker: escaped-descendant ownership is discarded, allowing false
cleanup release** at that earlier mechanism-review checkpoint.

**Accepted synthetic Fortran adapter:** fresh review **0/0/0, 78 checks**;
normal and delayed controls each produce **sum 204 / one completed GPU
dispatch**, ledger **2/4 versus historical C 8/8**. Authority:
`C/sessionfiles/model-monitored-trial/fortran-adapter-v1/{review_1.md,review_1.json}`.
This approval **binds cef, not 7d9/a76f/93fa or Qwen**; do not relabel old approvals
after a rebuild. Safeguards remain observational, `full_model_memory` is
**NULL**, and **no real-model lease under this controller has ever been granted**.
Production role/bootstrap,
new runtime bindings, headroom and admission remain pending.
No real-27B GPU or tokens/s. The planned first control remains
P18/G1/full reset, expected 9419/lookahead 0, conditional on qualification;
no G17/2K/sustained/benchmark authorization. CPU model runs remain cancelled.
Disk recovered externally to 69 then 161 GiB; the capacity worker performed
**no archival/deletion**, leaving protected builds untouched.

**Benchmark-contract audit, not a benchmark:** exact workload/hash/raw-ID/reset/
counters/pruning/sampler are ready; prefix is **P-1**, decode **G-1 includes
terminal lookahead**. Application benchmarking still lacks Fortran phase clocks,
proven GPU completion, runtime bindings and admission. Synchronous Fortran is **not native queued
timing**; `CPU_time` is not GPU throughput. Authority:
`C/sessionfiles/fortran-benchmark-contract/{report.md,contract.json}`.
No new benchmarks; QMM64 remains unpromoted with its adverse sample preserved.

### Completed native-math migration

Reviewed native source is committed as
`8640d2dfd8404b803b8621ef2b80a78ee0bfc0dc`, with audited PERF documentation
at `86fb02f9b79fd9640fedea2eae006193a1417908`. The original preregistered
`acd78f8188cca76924a1d8d2483ec41b630d0c62` remains historical, not rewritten.
`N/artifacts/native-residency/{baseline-commit-mapping,docs-commit-mapping}.json`
prove benchmark binary `42c8930d…65804eb` and all four libraries unchanged.
Unchanged MIT-licensed
MLX/MLX-LM bodies now own arithmetic and actual native kernel/typed-graph
dispatch: RNN time loops, 32x32x32 BF16 qmm, prefill matrix and decode/two-pass
SDPA, RoPE/head-major KV, embedding/pointwise operations, cache sampler and
lookahead. Literal operator proofs are bit-exact to MLX, **not global C
bit identity**. This is native math, not a complete migration of MLX's generic
runtime: Shared/tracked allocation, loader, residency and submission granularity
still differ.

Protected short17/reset/full65, 2048/65 all65, and 29/1536 all1536 IDs pass.
The earlier index-3 mismatch **321 versus 271 is resolved** after remaining
math migration; which old component caused it was not isolated. Old failures
and recovered native-head/sampler common-input proofs remain retained, not
relabeled as a numerical-drift waiver. Boundary fixes cover workspace sizing
above key length8192, looped softmax above4096, and native causal-vector M2-M5.
Runtime is **g16s / macOS15.8**, built with **SDK26.2 / MSL3.2 Safe/Precise**;
SDK version is not the runtime OS.

Source pins and actual-runtime evidence: session artifact
`mlx-exact-runtime/report.md`; completed source/boundary dispositions:
`native-math-complete-review/` and its `boundary-followup/`. The earlier
`5d668140 -> acd78f81` experimental lineage is not original performance
acceptance. Frozen C `37ff651`, bounds, oracles, IDs and Fortran remain unchanged.

### Saved source and reusable lessons

The user-authorized **private**
[native-app backup](https://github.com/certik/qwen3.6/tree/project/qwen38-mlx-native)
was independently verified at `86fb02f9`: source and validation matrix are
saved. This is not an LFortran push or PR.

Latest lesson coverage is **complete, reviewed and published** in the installed
`optimize-metal` guide and references: all latest 10 items/material phases are
mapped in session `optimize-metal-upgrade/latest-round/coverage-matrix.md`.
The seven-document update `05aeabd…` plus wording follow-up
`0f7eea7709e332c3efd8384216d2a94fc5829feb` are verified on the same public
[lessons branch](https://github.com/certik/ai_skills/tree/project/qwen38-metal-lessons),
building on the earlier dbeead3/4fa787b work. Core is 278 lines; remote main
remained `404cf8f`. Original evaluation outputs are unchanged. This is
methodology coverage, **not measured hours saved or Fortran authorization**.

### Fresh all-three paired AC measurements

**A=MLX, B=native-math C+Metal; ABBABAAB, four samples per engine per workload,
24 fresh-process samples, no added warmups or purges.** Full generated-ID,
forward-count, source, power and quiet guards pass. Earlier interrupted ABB,
2K A1 and zero-model preflights remain separate, never pooled. The independent
measurement audit is **CLEAR**: all 24 samples, 13,328 protected IDs, counts,
pins, clocks, guards, statistics and pairs validate. C's outer wall is better
in every adjacent pair; these remain descriptive N4 observations.
Evidence: session artifact
`native-math-complete-review/all3-performance/review.md`.

All rates below are tokens/s and all entries are **C / MLX medians**.

| Input / generated | Conventional prefill | Common-ready / ready-to-first prefill | Decode | Actual child wall, s |
| --- | ---: | ---: | ---: | ---: |
| **18 / 65** | **14.25 / 61.27** | **14.25 / 10.16** | **16.53 / 16.56** | **7.69 / 10.70** |
| **2048 / 65** | **205.41 / 230.48** | **205.41 / 204.43** | **16.18 / 16.21** | **17.26 / 19.07** |
| **29 / 1536** | **23.76 / 96.80** | **23.75 / 19.79** | **15.14 / 15.26** | **105.42 / 107.19** |

C decode medians are approximately **0.16% / 0.22% / 0.76% lower** than MLX;
actual process wall is **28.09% / 9.51% / 1.65% lower**, respectively.
This is practical decode/end-to-end competitiveness in descriptive N4 data,
**not formal population non-inferiority or unqualified all-scope parity**.
Actual child wall includes spawn/imports/initialization/inference/teardown,
not a load-plus-warm estimate. Both engines retain the same declared
lookahead/forward counts in these cohorts; native GPU-busy time is unknown,
while C has clipped GPU-interval measurements.

**Prefill boundary caveat:** MLX's conventional inference clock starts
**inside `wired_limit`**; measured short wire-entry median is approximately
**1.51 s**. Common-ready MLX charges prewire/cache setup and wiring; C's ready
point follows **weights and workspaces**. Common-ready results meet/exceed
MLX here, but work exclusions are **not perfectly identical**. Conventional
prefill is still below target. Report both metrics and total wall; neither a
3-4x shader-gap claim from clock boundaries nor a claim that wiring caused C's
first-use gap is established.

Completed raw distributions, medians/bests and pairs:
`N/artifacts/native-benchmark-prep/all3-measurement-report.json`;
source freeze `776b0224…`, preregistration `48c5e05a…`. No old warm-resident,
native AC or Battery cohorts are mixed into this series.

### Completed resident comparison: scoped readiness FAIL

Separate short18/G65 and 2048/G65 **ABBABAAB N=4/engine** cohorts retain one
loaded model per fresh child: a fully reported conditioning request followed
by a fresh-state request. Primary resident request-to-first starts **before
reset/new cache/input/wiring**; all cold, conditioning, exit and outer costs
are reported. Resident means same-process model retention, **not physical
page pinning**. The original 24-sample table is neither retimed nor replaced.

| Resident workload | Median prefill tokens/s, C / MLX | Frozen outcome |
| --- | ---: | --- |
| **18 / 65** | **80.066587 / 67.741849** (+18.2%) | All short gates PASS |
| **2048 / 65** | **181.34 / 196.10** (C -7.5306%) | Prefill FAIL; other three gates INCONCLUSIVE from paired spread |

Short resident decode is **16.32554 / 16.57053 tokens/s** (C / MLX), within
5%, **not the original cold within-1% claim**. Overall preregistered 5%
readiness is **FAIL**, not statistical non-inferiority or Fortran acceptance.
Original 29/1536 remains separate audited cold evidence, not newly warm-tested.
Authority: session `native-resident-prefill/` (`resident-measurement-tables.txt`,
`resident-measurement-report.json`, `readiness.json`,
`review/measurement-audit.{md,json}`).

Offline 2K attribution covers **99.71–99.77% of C resident generation-to-first
with GPU intervals**: reset is approximately 14 ms, uncovered time 30 ms and
first submit 2 ms. The 2047-row GPU prefix dominates; in both losing adjacent pairs
C's GPU union alone exceeds native's **entire request-to-first**. Thus the
excess is not primarily off-GPU startup/reset. Native GPU time is unknown,
and GPU elapsed includes stalls, **not pure arithmetic**. Cold/warm C prefix
capacities 2048/2304 and changed strides are source-derived, with unchanged
logical GEMMs, **not a proved cause**. Warm/cold changes are mixed, including
one slow C and one slow native decode sample; no thermal/JIT/paging cause is
assigned. Evidence: `native-resident-prefill/offline-2k-gap/report.txt`.

The exact measured source is sealed locally as
`9dd05ab27b9e169bfbcfdd8d094555b3e97f4e6b`, preserving host `7f048673…`
and historical `e11429da…` receipts, not rewriting their original build base.
The initial bad-path attempt is retained separately. Corrected native sanity
passes 14 actual dispatches, outputs/readonly/lifetimes and isolated clocks;
one 2K/G65 cold+reset/warm model passes all 130 IDs, full-state reset hash,
lookahead and count/clock gates. Production/measured math, options and four
libraries remain unchanged.

| Conditional isolated prefix GPU elapsed | Cold | Reset-warm |
| --- | ---: | ---: |
| Total, s / dispatches | 8.229118153 / 2122 | 9.493792028 / 2090 |
| QMM/folds, s | 7.751454801 (94.20%) | 8.974141306 (94.53%) |
| Recurrent, s | 0.242 | 0.267 |
| SDPA, s | 0.132 | 0.149 (~1.6%) |

These **KPROF-isolated** intervals change batching, concurrency, cache and
frequency behavior: **not normal throughput or new acceptance**. Native GPU
time remains unknown; no thermal/page-in cause is assigned. Actual names,
ABI and counts reconcile, with no unsupported dispatched work. A CPU parser
mistook PSO-name-pointer bins for unique text labels; its failure/logs are
preserved and full label/count/time/KPROF reconciliation passed **offline,
without a model rerun**. Invalid empty-wrapper timestamps remain raw,
archived/excluded, not forged or substituted for parent intervals.
Authority: `native-resident-prefix-profile/final-report.txt`, `analysis.json`
and `final-source-seal.json`.

**Completed operator hypothesis, not model acceptance:** the 126 gate/up calls
`M=2047, N=17408, K=5120` cost **4.181087 s** in the isolated warm profile.
The `BM64/BN64/BK32` pilot instantiates the unchanged native affine-q8 body,
keeping WM/WN2x2/TG128: **34,816 -> 8,704 threadgroups**, static staging
**5,120 -> 10,240 bytes**, unchanged logical FLOPs.
This is a new source-supported specialization, not a claim pinned MLX selects
64x64. Corrected outputs/guards/typed variation and actual PSO/grid/ABI checks
pass. The predeclared eight batches of 32 serial dispatches (256 total) pass
the operator screen: paired GPU reductions **6.58 / 7.29 / 10.63 / 9.08%**,
median **8.19%**, worst **6.58%**. These are operator-only observations;
the original bias-fixture-bug and corrected eight-single-call experiments remain
**INCONCLUSIVE**, immutable and unpooled.
Evidence: `native-qmm64-pilot/final-batch-screen/final-report.txt`.

### Limited QMM64 integration and audited model outcome

Local `experiment/qwen38-qmm64` commit
`4921bf7b0e327561259c7419e1db5d75c27f7451` changes 13 focused files, with
frozen binary `b22ab369…`, base `d1610f94…` and unchanged auxiliary libraries.
Only non-split `M2047/N17408/K5120` routes to 64. Protected short and 2K
two-request controls each pass 130 IDs/state/lookahead/counts; actual 64 counts
are **0/0 short and 126/126 2K**. Local review is clear, **not production
promotion**; original production `86fb02f9`/`42c8930d…` and measurement
`9dd05ab`/`7f048673…` remain unchanged.

A separate **ABC/CBA/BCA/ACB N=4/arm** comparison has 24 children, 48 requests
and 3,120 exact IDs under manifest `192eeaf1…`. Saved-evidence audit is
**CLEAN** for bindings/clocks/counts/guards/statistics; earlier cohorts are
not pooled. Resident prefill medians, tokens/s:

| Scope | MLX (A) | Old C (B) | Candidate (C) | Overall outcome |
| --- | ---: | ---: | ---: | --- |
| 18/65 | 67.419674 | 80.181646 | 80.251395 | Readiness PASS; promotion FAIL |
| 2048/65 | 185.040938 | 182.843067 | 194.002953 | Readiness FAIL; promotion FAIL |

Candidate 2K median is **+6.1035% versus old C / +4.8433% versus MLX**, but
**C/A readiness FAILS and C/B promotion FAILS**. The 2K cold spawn-first
median C/A is **1.053265 >1.05**; C/B cold ratios are **1.078313 short /
1.217282 long**, and 2K whole-child ratio **1.080581**. Within-block prefill,
decode and outer violations remain: worst candidate 2K sample 3 retains
**112.709 prefill / 8.351 decode tokens/s / 58.9925 s child**. Never discard
it or relabel historical data. Short warm is essentially unchanged from
old C; other 2K candidate samples vary. Authority: `native-qmm64-comparison/`
(`measurement-tables.txt`, `measurement-report.json`, `review/measurement-audit.{md,json}`).

Within the worst block, **25.40 s extra child time includes 24.01 s GPU time**,
in both prefix and **unchanged decode, where 64 dispatch count is 0**. Short
cold losses mainly vary in read/copy and first-driver gaps. Inclusive
Metal/JIT labels around 0.02–0.04 s are **not isolated PSO compilation**.
No thermal/OS/JIT/paging/frequency cause is established, and no eager-PSO
source change is justified. Evidence:
`native-qmm64-comparison/offline-cost-breakdown/report.txt`.

The unprivileged diagnostic is **COMPLETE**: two children/260 exact IDs pass,
including candidate 126/126 counters; the severe slowdown is **NOT REPRODUCED**.
Public own VM/thermal/QoS state is supported, but GPU frequency/traffic/
utilization remain **UNKNOWN**. Cold decompression/driver correlation is not
causality. No root/admin access, optimization, acceptance or promotion;
historical FAIL/outlier evidence is retained. Its diagnostic owners were released.
Authority: `native-unprivileged-state/report.md`. At that checkpoint Fortran
was paused; the later explicit user disposition above resumes research,
not retrospective performance acceptance.

### Archived residency diagnostics and qualified discriminators

Residency is archived locally as
`c71595c7c71268c5893d9245a6067e8e564f1270` on
`experiment/qwen38-residency`, not pushed. The production baseline was restored
before later measurement preparation. The following N=1 diagnostics remain
historical, not the later paired screen.

The reviewed prototype passes short17/reset, short65 and 2048/65 native
IDs/counts/lifetimes after AC was restored; the initial Battery **0/3** block
is retained separately. Prototype binary is `eebdfc7d…`; native
kernels, MSL/options, barriers and Shared/TRACKED behavior are unchanged.

| N=1 diagnostic | Entry, s | Conventional prefill, s | First submit -> GPU, ms | Ready -> first, s | Actual child, s | Restore, ms |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 18/65 | 1.528470 | 0.240964 | 4.276459 | 1.769696 | 9.400685 | 0.707042 |
| 2048/65 | 1.352781 | 9.135456 | 3.312209 | 10.488500 | 18.854176 | 3.850500 |

Historical baseline N4 medians were approximately **955.574 / 1116 ms**
first-submit gaps, **1.264166 / 9.970321 s** ready-to-first, and
**7.693968 / 17.2552 s** child wall (short / 2K). This is **not a contemporary
paired comparison**. Observed submit stalls are shorter, but setup-inclusive
latency did **not demonstrate a gain**. Restore is tiny; neither a restore/
teardown diagnosis nor residency causality is established. No cost-shift win,
all-scope parity, new N4 or 1536 result is claimed. The audited 24-sample table
is unchanged; the prototype is **not accepted as production/default**.
Authority: `N/artifacts/native-residency/probe-report.json`.

The later short65 ABBA screen (A=baseline42c, B=prototypeeeb, N=2/arm) is
**LOSS**: all four ID/count/source/power gates pass, but adjacent child B/A
ratios are **1.120 / 1.033**, median-child ratio **1.0775**, ready-first ratio
**1.1236**, with decode approximately unchanged. This is not formal regression.
An unchanged-baseline observer records pread union **3.589852 s**, allocation
API sum **6.120 ms**, elapsed public-driver scheduling **1.532360 s** and
driver-end -> GPU start **0.327 ms**: not CPU-busy or established page-in;
I/O/VM internals remain unlocalized. The eight-child matched-byte 512 MiB/2 GiB
resource-count experiment is **INCONCLUSIVE**: a 15.3% better 2 GiB parent-arm
median does not clear paired/frozen thresholds. Logical-byte, length,
allocatedSize/span and readonly checks pass, but physical RSS equality is
unproved and sub-second 512 MiB RSS was
not sampled. No parent-buffer consolidation or model-performance claim follows.
Completed evidence: session artifacts `native-startup-timeline/{report.md,timeline.json}`
and `native-startup-timeline/resource-count/report.md`.

### Historical pre-native speed controls

The following SG/RMS, Battery experiments and older native controls retain
their original source-specific dispositions. They are **not the current N
implementation or its fresh paired cohorts**.

Rates are tokens/s. Effective prefill means prompt tokens divided by TTFT,
not isolated kernel throughput. Decode cells show **median (best)**. The
C+Metal short row is the accepted **SG N=4, AC** cohort; native rows are
archived controls. New Battery experiments are kept in a separate table.

| Raw input / generated IDs | Native MLX effective prefill, median | Native MLX decode | C+Metal effective prefill, median | C+Metal decode |
| --- | ---: | ---: | ---: | ---: |
| **18 / 65**, short | **63.8088** | **16.5396 (16.5467)** | **6.7041** | **5.0060 (5.0245)** |
| **2048 / 65**, prefill | 205.519 | 15.339 (15.520) | No accepted series; MMA N=1 below | No accepted series; MMA N=1 below |
| **29 / 1536**, sustained | 101.653 | 6.059 (6.237) | Not run | Not run |

That pre-native C+Metal checkpoint was far below archived MLX throughput.
These rows are **not paired Battery/AC parity tests**. The two longer native rows are
older baselines; native sustained-decode slowdown remains unexplained.
Operator fixtures do not replace long-workload correctness or benchmark series.

The archived short MLX control has three samples: warm TTFT **0.282093 s**, inference
wall **4.150924 s**, and best effective prefill **64.6884 tokens/s**.
Separately measured load **4.134746 s** plus warm inference gives an
**8.285670 s estimate, not measured fresh-process wall time**; GPU-busy time
is unknown. Native scheduling executes 67 total/65 cached forwards, including
one unemitted lookahead, versus Metal's 65/64; both decode numerators are 64.
No CPU or Fortran GPU tokens/s is inferred from traced correctness runs.
Archived first-short TTFT is **0.308596 s**, also much lower than hand-Metal:
warmup alone does not explain the gap. That one first sample is not a new
paired benchmark or a complete diagnosis.

Short-control evidence in `M`:
`artifacts/perf-rms-output/quiet-aggregate-window/outcome.json`
(`fresh_native_MLX_control`). Older rows are recorded in `M/PERF.md`, backed
by `artifacts/baseline-native/results.json`.

### Historical accepted SG checkpoint

Commit `c296c2cef953a6400718ac2e07aedbc8880e26e2`, parent RMS `961b28978d`,
is independently accepted for **18/65 only**. Its N=4 decode median is
**4.852030 -> 5.006035 tokens/s (+3.174%)**; actual child wall is
**20.956963 -> 20.299531 s (-3.137%)**. Observed effective-prefill medians
are **6.484670 -> 6.704075 tokens/s**, while prefill GPU intervals are
effectively unchanged: no matrix-kernel or loader gain is established.
Host/shader pins are `dc56cb57…` / `781dd18c…`. Evidence in `M`:
`artifacts/perf-sg-q8/finalization/handoff.json`, accepted SG reports and
`src-metal/PERF.md`. At this pre-native checkpoint SG replaced RMS as the
accepted baseline.

### Historical experiments: original dispositions

Both short experiments below were **N=4 Battery-only, power-mode-0**
cohorts. Do not pool them with each other, accepted AC SG/RMS, archived native
data, or the separately preserved interrupted qmv4 AB attempt.

| Short 18/65 experiment | Effective prefill tokens/s, before -> after | Decode tokens/s, before -> after | Actual child wall s, before -> after | Disposition |
| --- | ---: | ---: | ---: | --- |
| Parked qmv4 | 9.13456 -> 8.78883 | 4.991207 -> 6.012794 | 17.32854 -> 15.07553 | Decode +20.4677%, child -13.0017%; prefill wall +3.9505%, slower in 3/4 pairs. Overall nonregression unresolved; uncommitted. |
| MMA snapshot | 8.03037 -> 9.16304 | 4.99435 -> 4.94819 | 17.92679 -> 18.06733 | Prefill +14.1048%, decode -0.9242%, child +0.7840%, startup +11.1461%. Source/evidence review and overall nonregression were unresolved at this uncommitted checkpoint. |

qmv4 is **not an accuracy rejection or a proven bad source**: functionality
and source review passed, but prefill nonregression remains unresolved.
No noise cause or population non-inferiority is established. Exact source/runtime
and all archived artifacts are preserved; qmv4 is **not in the MMA runtime**.
Evidence: `M/artifacts/perf-qmv4/fresh-timing-02/handoff.json` and
`M/artifacts/perf-mma/qmv4-preservation-proof.json`.

MMA preserves 32x32x32 float-fragment matrix arithmetic with frozen BF16
weight/partial/fold boundaries, the unchanged M=1 SG path, four 1 MiB partial
slots and 14,336 threadgroup bytes. Numeric/operator/frozen replay and 17/reset/
65-ID checks pass, not global exact-C parity. Prefill GPU intervals fall
**1.14343 -> 0.65857 s (-42.4037%)**. Startup rises
**2.64209 -> 2.93658 s**; Metal/JIT is approximately 0.02 s in both variants.
The combined weights/workspaces increase has **no proved cause**.
Host/shader pins are `fc9460d6…` / `41a179a5…`;
`M/artifacts/perf-mma/handoff.json` records the frozen review checkpoint.

**First actual full 2048/65 control, MMA N=1:** prefill **17.1111345 tokens/s**
(119.688148 wall / 118.077135 GPU s), decode **0.495271 tokens/s**
(129.222146 wall / 128.734081 GPU s), startup **2.605843 s**, actual child
**251.79177 s**, capacity 2113. All 65 historical native IDs match, but
**correctness is UNKNOWN**: there is no corresponding C/accepted-Metal long
oracle, and internal tensor finiteness was **not captured**. This is one
experimental observation, not an accepted N=3 series or apples-to-apples
comparison with historical MLX **205.519 / 15.339 tokens/s**. The source's
**28.774925 GiB budget is not a physical GPU peak**. Sustained 29/1536 remains
unrun. Completed evidence: `M/artifacts/perf-mma/handoff.json` and its
`full2048-control/final-observation.json`.

### Historical MLX source-inferred findings

This earlier research was not runtime-captured. Later executed literal-kernel
proofs and completed native migration are recorded above; old evidence remains.

Completed `mlx-performance-trace/{report.md,report.json,source-manifest.json}`
session artifacts pin MLX 0.31.2 `68cf2fddd8de` and MLX-LM 0.31.3
`ed1fca4cef15`. Source describes four outputs per SIMD group for decode
[qmv](https://github.com/ml-explore/mlx/blob/68cf2fddd8de5edd8ab3d926391772b2e2cedad8/mlx/backend/metal/kernels/quantized.h#L750-L814),
32x32x32/four-SG [qmm](https://github.com/ml-explore/mlx/blob/68cf2fddd8de5edd8ab3d926391772b2e2cedad8/mlx/backend/metal/kernels/quantized.h#L1094-L1216)
with BF16 weights/partials/folds, and a persistent
[recurrence time loop](https://github.com/ml-explore/mlx-lm/blob/ed1fca4cef15a824c5f1702c80f70b4cffc8e4dd/mlx_lm/models/gated_delta.py#L13-L123)
per layer/chunk rather than our per-token launches. Native cache-only prefix
evaluation prunes the head (`generate.py:427-463`), but copying `[P-1,1]`
would change frozen M-dependent arithmetic. Native D=256 prefill attention
uses an unfused fallback; decode uses cooperative vector attention
(`scaled_dot_product_attention.cpp:618-636`). Hand-Metal's serial-lane SDPA
is a candidate, **not a measured TOP1 bottleneck**. Source findings guide
original, frozen-contract-compatible adaptations; they do not establish
runtime routes, timings or permission to change bounds/oracles.

### Historical accepted RMS optimization: what improved

This earlier RMS cohort is retained as history, not the later SG, Battery
or fresh native-math paired cohorts.

Commit `961b28978dd9859ac963b963b40c2d2dbb38a7eb` preserves reviewed shader
`208c8fd2…`. Eight valid, counterbalanced **ABBA BAAB** measurements give
four samples per variant; independent review accepted this **18/65 scope only**.

| Metric | Before | After |
| --- | ---: | ---: |
| Decode, median / best tokens/s | 3.7556 / 3.7653 | **4.8522 / 4.8526** |
| Effective prefill, median tokens/s | 6.1668 | 6.3291 |
| Startup, s | 4.5425 | 4.5556 |
| Inference-only TTFT, s | 2.9188 | 2.8441 |
| Startup-inclusive TTFT, s | 7.4614 | 7.3934 |
| Inference wall, s | 19.9601 | 16.0374 |
| Total wall, s | 24.5030 | **20.5832** |
| Measured GPU intervals, s | 17.8230 | 13.9118 |

Median decode improves **29.20%** and total wall falls **16.00%**. Startup
increases **0.288%**, judged nonmaterial for this scope; inclusive TTFT is
lower in all four adjacent pairs. Metrics are summarized independently,
not added as if their medians described one run. Production 17/reset,
30,294 baseline-byte-exact traced tensors and 23,972 required plus 5,746 extra
same-input checks remain passed without changed math, oracles or bounds.

The earlier BBBCCC experiment's **+5.67% startup / +2.52% inclusive TTFT**
and first counterbalanced A's **5.225665 s startup** remain in the evidence.
Their cause is not proved; the acceptance is not wholesale noise exoneration
or a claim that startup can never regress. Raw data in `M`:
`artifacts/perf-rms-output/counterbalanced/attempt-paused-20261030T105331/outcome.json`;
independent disposition: session artifact
`rms-output-wip-review/counterbalanced-review/audit.json`.

### Next priorities

1. **Complete independent fixing gates and classify the combined link failure.**
   #16713 and J/#16709 are ready, not merged; #16716's observed
   c7dc-head macOS Quick failure needs investigation despite clean review2; #14626 default suites
   are running. Local targeted success does not
   close issues, prove combined source/binary identity or accept a model.
   O P0e464/Gc7dc `1b9434d1` now has a completed link failure, not a pending
   native gate. Compare prior 0a compile/link protocol before classifying it;
   no issue/cause assigned or new tiny/reset/token result.
   Original 93fa controls/A/C remain qualified history, not memory savings/fit.
   Preserve faithful MREs/reports without claiming reused issues as newly filed.
   The user's other agents own all compiler fixes; no competing implementation.
   Hold old H optimization work; its scratch plan/proofs do not certify main.
   No app rewrite, default heap increase or full-model GPU grant. Keep Fortran
   frozen; CPU model inference/benchmarks remain cancelled/deferred, while
   small compiler regressions/suites continue.
   Keep original `F/a70` and selected native-math `8640d2df`/PERF `86fb02f9`.
2. **Preserve the sealed measured source separately from production.** The
   four C/Make files are committed locally as `9dd05ab27b` on
   `experiment/qwen38-resident-prefill`, byte-identical to measured source.
   Preserve measurement host `7f048673…` and historical `e11429da…` mapping.
   No semantic source change or production push is implied; original
   production `86fb02f9`/`42c8930d…` and four libraries remain untouched.
3. **Coordinate existing-source candidates, not competing compiler fixes.** The 16
   envelopes remain tentative and incomplete: six PRs merged upstream/by user,
   not by this workflow. Candidate bodies for #16603/#16606/#16613/#16616/#16628
   are handed off but unverified/non-PR-ready. Do not transfer old-head proofs
   to changed heads, or interpret #16618's opt-in request as a legacy regression.
   Completed int64/memory handoffs and proposal #16649 are historical source/
   optimization evidence, not current fixes or proof that all grouped cases depend.
   Memory optimization is additional to the inventory and currently held.
   Hold int64/closure for the user's #15895 ping; do not poll or touch that PR.
   Resolve connected regressions without waivers or blocking independent jobs.
4. **Qualify actual Fortran production bindings/admission before any real lease.**
   Strict V2/V3 did not qualify and is abandoned for real use. The accepted
   78-check synthetic adapter binds cef only, not O/current fixing heads/Qwen. Production role/
   bootstrap/new bindings/headroom remain pending; full_model_memory is NULL.
   This observational approach has no hard preallocation guarantee.
   Only after clearance consider planned P18/G1/reset; no authorization for
   longer runs or benchmarks. Require memory/physical-fit and full-shape correctness before
   broader real-27B GPU/profiling. Tiny PASS does not close allocation, residency,
   conditional-arm coverage or accumulated-state gates. CPU scopes remain
   unchanged; no further CPU model run/benchmark, old paused 65,536 result or
   GPU speed claim.
5. **When owner-supplied compiler fixes stabilize**, require their LLVM 11
   reference/default-suite evidence before review/local integration.
   Root's older green suites are not a substitute; consolidate application
   worktrees separately.
6. **Then optimize to match the selected Metal kernels**, with generic,
   profile-driven ASR/GPU changes: coalescing,
   SIMD reductions, tiled GEMM, residency and scheduling, not model-specific
   backend hacks. Design native BF16/new kinds only where optimization
   demonstrates a need; the portable integer representation remains the
   reference.
7. **Finish tokenizer/chat/NFC later.** Old Qwen3.6 weights remain unavailable,
   so no fresh backward whole-model claim is made. Native-app/lessons backups
   remain recorded. Compiler-fix publication is separately user-authorized;
   this docs-only task performs no push/PR or network activity.

The retained Fortran controller's 21 CPU readiness checks and independently
audited zero-blocker preflight are readiness proofs, **not larger-model acceptance**.
Fortran real-model named host storage is estimated at **26.93 GiB**;
its **9.68 GiB trace occupies disk, not RSS**. Metal READ staging copies,
pools/command lifetimes and private
physical memory remain unproven, so fit within the **38 GiB budget is not
established**. No full Fortran model before preflight. Original C80 remains an
independent historical diagnostic:
**FAILED: 94/96 positional argmaxes and 16/17 teacher predictions**, under the
approved continuation policy, with unchanged bounds/oracles and a passing
short-17 gate.
Retained pre-native accumulated-C diagnostics also fail: accepted SG
**15,545 nodes**, MMA **15,545** and qmv4 **15,432**. Equal counts do **not** establish byte
identity or causality; short functional success is not global exact-C parity.
Frozen C `37ff651`, bounds, oracles, IDs and Fortran sources remain unchanged.

## Detailed milestone evidence (pinned checkpoints)

The records below retain historical source-specific evidence; the current
tables and plan above distinguish later combined-branch progress.

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
  renaming**, not upstream waivers. At that attribution checkpoint, sixteen
  baseline CPU/emission checks passed; baseline actual-Metal execution was
  not done. These introduced regressions have since been fixed locally.
  Attribution evidence in the `ibset-signbit` worktree:
  `.fix-issue/metal-control-attribution/CPU_ATTRIBUTION_HANDOFF.txt`.
  GPU reference reconciliation, full suites and root integration remain pending.
- **Latest tiny whole Fortran GPU driver:** combined
  `d94db958772e31b95e9f12eca8f1c9c65c0dbe88`, not root `91f90a5a16`, runs the
  unchanged application in normal and strict modes with genuine 17 IDs,
  16 decodes, exact self-reset, finite outputs and **8,064 completed Metal
  dispatches**, without CPU fallback. The original exact adapters/harnesses
  retain **four failing invocations (exit 1), not four established bugs**.
  Cross-C reset is not accepted; first `g_0`/`g_1` differences are one FP32
  ULP, and millions of accumulated differences are **not same-input primitive
  bounds**. Dynamic all-17-region coverage of the whole application is not
  proved. No 27B GPU or accepted GPU-throughput claim follows.
  Evidence in `G`: `.fix-issue/qwen38-combined-gpu-driver/sdk-retry-handoff.json`;
  independent session artifact: `tiny-fortran-gpu-audit/audit.json`.
- **C+Metal checkpoint history:** the earlier accepted short medians
  **3.734683 / 6.438657 tokens/s**, versus that snapshot's native MLX
  **16.567978 / 64.690424**, remain historical, not the current A/B pair.
  The RMS production proof remains at
  `M/artifacts/perf-rms-output/production-correctness.json`: 17/reset,
  **30,294 complete unique finite traced tensors byte-exact to the accepted
  baseline**, plus matching untraced endpoints/reset. RMS timing is now
  accepted and committed as reported above, not still an uncommitted WIP.
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
  pushing, or opening PRs is performed by this docs task. The compiler-fix
  publication stream above is separately authorized. Future execution
  is coordinated by Astra using GPT-6.1-Sol agents with high reasoning effort
  for bounded implementation tasks; coordination does not replace acceptance
  evidence. The explicitly authorized IEEE issue report below does not
  authorize source publication.
  The private native-app backup and public lessons branch are earlier,
  separately authorized publication milestones.
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
reduced tests for compiler failures. That earlier milestone was local-only;
its no-push/no-PR scope is historical.
The current compiler-fix publication stream is separately authorized above.

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
push. Current publication authorization is limited to the coordinated
compiler-fix stream; this documentation writer does not publish.

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

Follow the [next priorities](#next-priorities): finish independent PR/local
suite gates and resolve/classify O1b9434's first-link failure against the prior
working 0a compile/link protocol. New 9-module/3-driver compilation is not
native acceptance; old O0a273's 966-dispatch reset failure and older host-shape mapping
retain their own provenance. No real-27B trial/TPS, unrelated
toolchain refresh or further old-crash execution approval. The user's
other agents own compiler fixes; candidate handoffs are not PR-ready fixes.
The cef-bound synthetic adapter is accepted only at that scope; production
role/bootstrap/new bindings/admission and benchmark phase clocks/completion
remain pending. No real lease or new benchmark; no hard preallocation guarantee.
H proofs/5.166 GB plan remain historical; rematerialization is unimplemented.
Publication remains incomplete: six PRs merged upstream/by user, not by us.
Further CPU model inference/benchmarks are deferred; compiler regressions/
suites remain required. Stable b183 unit/integration PASS does not hide the
remaining introduced CUDA reference failure or establish suites-green.
Real 27B GPU, physical fit and speed remain unaccepted; no root integration;
no further C tuning is selected. Keep historical performance FAIL/outlier,
original cold cohorts, archived residency
LOSS and the resource-count INCONCLUSIVE result separate.
This research resumption does not close conventional-prefill, compiler,
physical-memory or full text-interface gates, nor promote QMM64 `4921bf7b`.
Preserve frozen bounds and the documented C80 failure. Optional IEEE work
remains deferred.

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
