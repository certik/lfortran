Reviewed with the repository's own `pr-review` skill (`.agents/skills/pr-review/SKILL.md`
plus `references/review-rules.md`), against `lfortran/lfortran@cb4e4d9e9` (`main`).

Each PR was first rebased onto that commit and force-pushed to the `certik/lfortran`
fork, so every line and claim below refers to the **rebased** branch, not to the
pre-rebase head. This is filed as an issue on the fork because this session has no
write access to `lfortran/lfortran`.

Findings use the skill's classification: **blocker** (wrong semantics, invalid ASR,
regression, or untested core behaviour), **rework** (placement or maintainability
problem that shapes the implementation), **follow-up** (bounded debt).

Everything asserted about `main`'s behaviour below was produced with an in-tree
build: `0.64.0-361-gcb4e4d9e9`, LLVM 21.1.2, Debug. `gfortran` is not installed in
this environment, so the `gfortran`-labelled half of each new test was not run here.

---

# Rebase summary

| PR | rebase | new head | comments addressed |
| --- | --- | --- | --- |
| #12421 | clean, 1 commit | `2e7aeb6ea` | none outstanding (label + draft toggle only) |
| #12384 | 1 conflict in `asr_to_llvm.cpp`; reference commit dropped and regenerated | `776c97991` | 2 of 7 were already fixed on the branch; rest below |
| #12380 | 13 commits, 4 conflicts (test renumbering + `asr_verify.cpp`) | `5d5226d17` | self-review comment body is not retrievable from the PR page |
| #12310 | clean rebase but did not build; parser commit dropped as redundant; 2 blockers addressed | `daa95b89e` | all four comments answered below |
| #12309 | empty — every commit is on `main` | `a04cc341a` | resolved by the author's own split |

---

# Cross-PR: #12421 and #12384 solve the same problem twice

Both fix the same bug — a specific procedure that shares its generic interface's
name links against the wrong object-file symbol — in opposite ways:

| | #12384 | #12421 |
| --- | --- | --- |
| `Function.name` | stays `foo~genericprocedure` | stays `foo` |
| symbol-table key | equals `name` | `foo~genericprocedure` |
| new ASR state | `Function.link_name` (`string?`) | none |
| reference churn | 670 files | 10 files |
| hand-written `.asr` fixtures | all 33 need a new field | untouched |
| backend changes | `compute_llvm_function_name` gains a parameter | none |

They cannot both land: `Function.name` cannot simultaneously be the disambiguated
key and the plain name. #12421 is much smaller and needs no backend change at all,
which is the better answer to "the backend must not invent or strip frontend naming
conventions". Its cost is that "what key is this symbol stored under?" becomes a
*search* (`ASRUtils::symbol_table_key`) instead of a field lookup. #12384's cost is
one positional ASR field, and the rebase showed what that costs now that `main` has
hand-written ASR-text fixtures: every `(Function ...)` node in `tests/asr/` has to
grow a field or the ASR text parser rejects the fixture outright.

My recommendation is #12421, with `symbol_table_key()` tightened as below. But this
is the author's call, and it should be made before either branch gets more work.

---

# #12421 — fix: keep the generic-named specific procedure's real name

Rebased cleanly. The two PR comments (a `Tests::Run-Exhaustive` label from
@HarshitaKalani, @assem2002 marking it draft) carried no requested change, so
nothing else was applied.

**Verified locally:** all non-LLVM reference tests pass unchanged, and
`generic_name_09` / `generic_name_10` build and pass under the `llvm` backend.

**What it does.** Splits "symbol-table key" from "symbol name". The
`GenericProcedure` keeps `foo`; the same-named specific is stored under
`foo~genericprocedure` but keeps `Function.m_name == "foo"`, so every backend that
emits `m_name` emits the right link symbol with no backend change.
`ASRUtils::symbol_table_key()` recovers the key where one is needed
(`ExternalSymbol::m_original_name`, serialization), and ASR verification is
tightened from "`m_original_name` equals `m_external`'s name" to "`m_original_name`
is the key `m_external` is stored under". That is the right layer: decided in
AST→ASR, recorded in the symbol table, enforced by the verifier.

### rework — `symbol_table_key()` is a reverse search with a silent fallback

```cpp
static inline std::string symbol_table_key(const ASR::symbol_t *f) {
    std::string name = symbol_name(f);
    SymbolTable *parent = symbol_parent_symtab(f);
    if (parent == nullptr || parent->get_symbol(name) == f) return name;
    for (auto &item : parent->get_scope()) {
        if (item.second == f) return item.first;
    }
    return name;                     // <-- silent fallback
}
```

1. The final `return name` is a success-shaped error path (review rule 3). It is
   reached exactly when `f` is not in the table it claims as its parent — an invalid
   ASR state — and answers with a key that is known to be wrong. Callers then write
   that wrong key into `m_original_name` or into the modfile, and the failure
   surfaces far away as "symbol not found while loading module". Make it an
   assertion or a verifier requirement.
2. The linear scan makes the answer O(scope size). Only the rare disambiguated
   symbol reaches it, so it is not hot today, but `serialization.cpp::write_symbol()`
   calls it for *every* symbol written, so the cost is structural rather than local.

### follow-up — the disambiguated key leaks into `ExternalSymbol::m_name`

In the generic-procedure import path in `ast_symboltable_visitor.cpp`:

```cpp
std::string proc_key = ASRUtils::symbol_table_key(gp->m_procs[i]);
...
ASR::make_ExternalSymbol_t(al, fn->base.base.loc, current_scope,
    s2c(al, proc_key), s, m->m_name, nullptr, 0,
    s2c(al, proc_key), dflt_access);
current_scope->add_symbol(proc_key, ep_s);
```

`m_original_name = proc_key` is correct and is the point of the PR. But `a_name` is
*also* `proc_key`, so the importing scope holds a symbol whose **name** — not just
its key — is `foo~genericprocedure`. The premise of this PR is that the suffix is a
key and never a name; here it becomes both. Harmless for LLVM (which resolves past
the `ExternalSymbol` and uses `Function::m_name`), but it is exactly the state the C
backend prints. Either keep `a_name` as the plain name, or say in the commit message
why an `ExternalSymbol`'s name is allowed to be a key.

### follow-up — nothing pins the invariant the verifier now enforces

`generic_name_09` and `generic_name_10` are good end-to-end tests, correctly
labelled `gfortran llvm`. Neither exercises the new verifier rule directly: no
reference test contains an `ExternalSymbol` whose `original_name` differs from the
external's name, so a regression that put the plain name back would be caught only
indirectly, as a link failure. An `asr = true` reference test over `generic_name_10`
would pin it.

### note — `interface_name == to_lower(sym_name)` → `interface_name == sym_name`

Verified safe: `sym_name` is `to_lower(x.m_name)` at the top of `visit_Function`,
and `interface_name` is assigned `to_lower(...)` in `visit_Interface`, so the removed
`to_lower` was redundant. The real case-sensitivity fix is in
`add_generic_procedures()`, where `pname.first` was compared un-lowered against the
already-lowered generic name — that is what makes `generic_name_09`
(`interface addCNullChar` / `module procedure addCNullChar`) work. It is a second,
independent bug fixed in the same commit and deserves its own sentence in the commit
message, or its own PR.

---

# #12384 — Add `Function.link_name` for self-named external generics

Rebased onto `main`. One content conflict in `src/libasr/codegen/asr_to_llvm.cpp`
(`main` had meanwhile routed the mangle prefix through `tu_symbol_prefix()`);
resolved by keeping both changes. The commit "Update ASR references for
Function.link_name" was dropped and the references regenerated against current
`main` instead — hand-merging 600+ mechanically generated files is not reviewable.

Two of the seven items in the author's 2026-07-30 self-review are already fixed on
the branch: `link_name` is no longer set for module procedures (`977cfe1`), and the
verifier no longer string-matches `~genericprocedure` (`bb127c3`). I also checked
the "third suffix site" item: all three `~genericprocedure` append sites in
`ast_symboltable_visitor.cpp` now set `is_self_named_generic` and route through
`self_named_generic_link_name()`, and `is_module` / `deftype` are both final at
each call site. That item is closed.

**Verified locally:** with the regenerated references, every reference category
except the LLVM-version-sensitive ones passes; `generic_name_09`, `_10` and `_11`
build and pass under `llvm`.

### blocker — a positional ASR field breaks every hand-written `.asr` fixture

This is new since the PR was written. `main` now has `tests/asr/compile/*.asr` and
`tests/asr/verify/*.asr` — hand-written ASR text fixtures with **positional**
`Function` fields. Adding `link_name` makes the ASR text parser reject all of them:

```
ASR syntax error: 'Function' expects 12 positional fields or exactly 12 named fields
  --> tests/asr/compile/procedure_declaration_interface.asr:18:22 - 88:13
```

47 `(Function ...)` nodes across 33 fixtures need the extra null field. I have added
them on the rebased branch, but it is worth stating the general rule: **every
positional ASR field addition is now a breaking change to that fixture suite**, and
the PR that adds a field owns updating it. (An argument for #12421, which adds no
field.)

### follow-up — the field is now covered by exactly one reference

Regeneration produced exactly one non-null value in the whole reference suite:
`tests/reference/asr-interface_generic_procedure_same_name-708e46e.stdout` now
contains `link_name = "frexp"`. So the author's "no reference anywhere contains a
non-null link_name" finding is resolved. What is still unpinned is the *invariant*:
nothing exercises the verifier's "`link_name` implies `deftype == Interface` and
`!module`" rule, and `generic_name_10` (the motivating case) has no `asr` reference.
One `asr = true` entry for `generic_name_10` covers both.

### rework — two independent fixes in one PR

`generic_name_09` passes because of the case-insensitive comparison in
`add_generic_procedures()`, not because of `link_name`. AGENTS.md's "one bug = one
MRE = one PR" applies: that is a two-line change that can merge on its own today and
would shrink this PR's reviewable surface.

### follow-up — `SymbolDuplicator::duplicate_Function` change is wider than `link_name`

```cpp
function->m_side_effect_free, function->m_module_file,
function->m_link_name, function->m_start_name, function->m_end_name));
```

`m_module_file`, `m_start_name` and `m_end_name` were previously dropped by the
duplicator (they defaulted to `nullptr`). Propagating them is very likely a bug fix
— a duplicated function currently loses its source locations, which shows up as
missing diagnostic locations — but it is not this PR's subject and it is untested
here. Split it out with a test that shows a duplicated function keeping its
`start_name`.

### follow-up — the C backend still emits the disambiguated key

`asr_to_c_cpp.h` prints the symbol-table name for a call, so C output for
`generic_name_10` contains `get_text~genericprocedure()`. Pre-existing, but the
moment `link_name` exists the C backend is a one-line consumer of it, and a field
with two consumers is much easier to trust than a field with one.

---

# #12380 — Fix EXTERNAL procedures via ImplicitInterface deftype and FunctionPointerCast

Rebased onto `main`: 13 commits, four conflicts. Three were the same collision —
`main` gained its own `integration_tests/implicit_interface_44.f90` (a fixed-form
test) while this branch adds a different `implicit_interface_44`, so the branch's
test is renumbered to `implicit_interface_48`/`_48b` throughout, including in the
commit that later removes it and the commit that re-adds it. The fourth was
`asr_verify.cpp`, where `main`'s new `FunctionCall` result-type check and this
branch's implicit-interface check were both kept.

The author's inline self-review comment on `asr_to_llvm.cpp` is anchored at

```cpp
F = new_F;
llvm_symtab_fn[old_h] = F;
llvm_symtab_fn_names[fn_name] = h;
```

but its body does not render on the PR page and could not be retrieved, so it is not
answered here. The finding below covers that code independently.

The direction is right and is what the skill asks for: four shape-guessing
heuristics are replaced by one explicit ASR fact, `deftype = ImplicitInterface`, and
ASR verification rejects a call that targets a bare declaration. That is rule 1
applied exactly. Three things stand in the way.

### blocker — `FunctionPointerCast` has no exhaustive-consumer support

The new expression node appears in `ASR.asdl` and is handled in `asr_to_llvm.cpp`
and one `asr_utils.cpp` switch. It is **not** handled in:

- `asr_verify.cpp` — no `visit_FunctionPointerCast`, so nothing checks that `m_to`
  is a `Function`, that `m_arg`'s type is a `FunctionType`, or that the node's
  `m_type` agrees with `m_to`'s signature;
- `asr_to_c_cpp.h`, `asr_to_fortran.cpp`, `asr_to_julia.cpp`, `asr_to_mlir.cpp`,
  `asr_to_wasm.cpp`.

Review rule 9: "A new ASR node is not reviewable until exhaustive consumers have a
minimal, correct case for it: verifier, dependency walkers, serializers, and
round-trip printers. A reachable 'not implemented' path in one of these consumers is
a blocker." `asr_to_fortran` in particular is how the skill suggests inspecting a
new transformation. At minimum: a verifier case, and an explicit located diagnostic
in each backend that cannot lower it.

### blocker — `is_synthesized_implicit_interface()` reintroduces the heuristic the PR removes

```cpp
bool is_synthesized_implicit_interface(ASR::symbol_t* v) {
    ...
    return ft->m_abi == ASR::abiType::BindC
        && ft->m_deftype == ASR::deftypeType::Interface
        && fn->n_body == 0;
}
```

That is the third of the four heuristics the PR's own commit message says it is
deleting, re-added under a new name — and it is the unsound one. A user-written

```fortran
interface
   integer(c_int) function foo(x) bind(c)
     use iso_c_binding
     integer(c_int), value :: x
   end function
end interface
```

matches all three conditions. Under `--implicit-interface`, a later call with
different argument types then treats the user's explicit interface as "synthesized"
and either drops it as a duplicate or files it under `foo@fpcast` and calls through
a bitcast. The fix is the same as the rest of the PR: state the fact. A synthesized
interface is created by `create_implicit_interface_function()`; record that
provenance in ASR rather than re-deriving it from ABI + deftype + emptiness.

### rework — the LLVM placeholder swap is backend type repair

```cpp
if (F->isDeclaration() && F->getFunctionType() != function_type) {
    llvm::Function* new_F = llvm::Function::Create(function_type, ..., "", module.get());
    new_F->takeName(F);
    if (!F->use_empty()) {
        llvm::Value* cast = llvm::ConstantExpr::getBitCast(new_F, F->getType());
        F->replaceAllUsesWith(cast);
    }
    F->eraseFromParent();
    F = new_F;
    ...
}
```

This is the pattern the skill names explicitly: "Querying LLVM for a type and casting
based on the result is a warning that ASR does not yet express what is happening."
The condition being tested — "a bare `ImplicitInterface` already claimed this link
name with a placeholder" — is an ASR fact, known before codegen starts. Deciding
emission order in ASR (or not emitting the placeholder at all, which commit 13
already moves towards by gating on `deftype` instead of the parent `Module`) removes
the need to erase and re-create an `llvm::Function` mid-walk. Note also that
`F->getFunctionType() != function_type` is a pointer comparison that is only
meaningful because LLVM uniques function types; that is true, and deserves a comment.

### rework — provenance encoded in a mangled name, and visitor state used as an out-parameter

```cpp
std::string cast_name = sym_scope->get_unique_name(sym_name + "@fpcast", false);
nw_mut->m_name = s2c(al, cast_name);
```

Rule 2: "Do not encode internal facts in reserved or mangled name prefixes and scan
those strings later." The relationship between the `@fpcast` view and the canonical
procedure is exactly what `FunctionPointerCast.m_to` already expresses. Related:
`implicit_interface_fpcast_canonical` / `implicit_interface_fpcast_target` are
visitor members used as implicit out-parameters of
`create_implicit_interface_function()`, and the "same signature, drop the duplicate"
branch returns early without clearing them, so the next caller can read a stale pair.

### follow-up — dead code in `call_args_match_function()`

```cpp
size_t offset = 0;
if (fn->n_args != args.size() + offset) {
    if (fn->n_args != args.size()) return false;
}
```

`offset` is always zero, so the outer condition equals the inner one and the inner
`if` is unreachable as written. Delete it.

### follow-up — `implicit_interface_46` needs `--skip-pass unused_functions`

The PR description says so; the test is registered without that flag. If the pass
still prunes something it should not, that is the bug to fix; if the note is stale,
remove it from the description.

---

# #12310 — fix: implicit typing / implicit interface handling

Rebased onto `main` and reduced, because three of the four comments are requests to
*remove* things. All four are answered:

**@Jatinagarwal24, "THis is also not failing" (`implicit_typing_14.f90`) and
@certik, "The parsing issue is already fixed" — confirmed, and acted on.** On `main`,
`lfortran --implicit-typing --fixed-form implicit_typing_14.f90` compiles and runs.
The grammar rework in `8559853` (which reintroduced `program_unit_statements` and
`split_implicit_statements()`, and conflicts irreconcilably with `main`'s
`decl_statements` grammar) is dropped from the branch. The test is kept as a
regression test in its own commit.

**@Jatinagarwal24, "This is not failing in current main"
(`implicit_interface_39.f90`) — this one is wrong.** With the options the test is
registered with (`--implicit-typing --implicit-interface`, `CMakeLists.txt:2181`),
`main` fails:

```
asr_to_llvm: module failed verification. Error:
Function return type does not match operand type of return inst!
  ret void
 i32
```

Without `--implicit-interface` it compiles, which is probably how the comment came
about. The fix stays.

**@certik, "I don't like this. I think this is related to #11924"** (the
`ImplicitInterface` deftype) — left in place, because #12380 builds directly on it
and removing it here only moves the same change to another branch. This needs the
author's decision, not a reviewer's.

### blocker — the branch did not compile against current `main`

The rebase applied cleanly as text and then failed to build:

```
src/lfortran/semantics/ast_common_visitor.h:2456:32: error:
  'struct LCompilers::SymbolTable' has no member named 'get_global_scope';
  did you mean 'get_tu_scope'?
```

`main` renamed `SymbolTable::get_global_scope()` to `get_tu_scope()` in `68fe387cd`
("interactive: one TranslationUnit per cell"). Fixed on the rebased branch. Worth
noting because it is invisible to `git rebase` — a clean rebase is not evidence that
a branch still builds, and this one had been open through that rename.

### blockers from the author's own review — addressed, but untestable today

Both walkers were fixed on the rebased branch:

- `collect_defs()` now collects **only file-scope** `Implementation`s. An `EXTERNAL`
  name denotes a global procedure, so an internal or module procedure that merely
  shares the name can no longer reconcile — and strip the return value from — an
  unrelated interface in a different scope.
- `reconcile()` now walks every symbol-owning scope via `ASRUtils::symbol_symtab`,
  not only `Function_t`, so a `PROGRAM`, `MODULE` or `BLOCK DATA` scope is reached.

No test accompanies either change, and I want to be explicit about why rather than
quietly shipping an untested fix. The walk fires only on an interface whose `deftype`
is `ImplicitInterface`, whose return variable is non-null, and whose body is empty —
and that combination is produced only by `create_implicit_interface_function()`, in
procedure scope. I tried and failed to construct an input that reaches it in program
or module scope (a program-scope `EXTERNAL` yields an interface with a null return
variable, which the walk skips) or one where the cross-scope name collision is
reachable (a called external is promoted to `deftype == Interface`, which the walk
also skips). Both changes are strictly narrowing and strictly widening respectively,
so they cannot regress the covered cases — but the honest reading is that these two
blockers are **latent**. They stop being latent the moment the trigger is widened,
and that is the order to do the work in: widen the trigger, and these two fixes
become load-bearing and testable in the same change.

Verified after the changes: all non-LLVM reference tests pass, and all 47
`implicit_interface_*`, `implicit_typing_*` and `external_*` integration tests build
and pass under `llvm`.

### rework — ENTRY provenance is still partly reconstructed from generated names

`restore_entry_master_metadata()` rebuilds the master/wrapper relation from the
`_main__lcompilers` suffix, an `entry__lcompilers` symbol, matching `Location`s, and
dependency strings. The branch now also *records* the relation explicitly in
`entry_master_wrappers` when the master is created, which is the right direction —
but the string-based reconstruction is still the fallback, and it is what runs when
the master arrives from a modfile. Rule 2: derive it from the canonical definition
and store it in ASR. Until then the fallback can match an unrelated user procedure
whose name ends in `_main__lcompilers`.

### follow-up — `resolve_variable()` grew a ~90-line inline block

The implicit-local-vs-external disambiguation computes six booleans inline in a
function that is already one of the hottest and most-edited in the frontend. Extract
it (`bool implicit_local_shadows_procedure(...)`) so the condition can be read and
tested on its own.

---

# #12309 — fix: COMMON block fixes

**Resolved by the author's own 2026-08-20 comment.** The branch was split into
#12550–#12554 and all five are merged. Rebasing onto `main` confirms it: git
identifies the fixed-form `/` commit and the `StringItem` commit as already applied,
and the remaining inline-character work is the same change that landed as `842130aff`
and `475de4145` — identical file lists and identical reference-output deltas. The
descriptor-based `setup_common_block_string_storage()` workaround the author rejected
on 2026-07-23 ("The common block must inline everything in it, not use descriptors
and we should not be fixing descriptors in the backend like this") is absent from
`main`'s version, as intended.

So the rebase is empty. One thing was left behind by the split: no merged PR covers a
`COMMON` `CHARACTER` array initialised by a `BLOCK DATA` in a separately compiled
unit. That scenario **passes** on `main` (verified end to end with
`--implicit-interface --separate-compilation`), so the branch now carries a single
commit adding it as `separate_compilation_54` — the branch's own
`separate_compilation_51` number was taken by an unrelated test on `main` in the
meantime. Once that merges, close this PR.
