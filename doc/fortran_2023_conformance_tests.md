# Fortran 2023 conformance test suite: design and plan

Status: draft for discussion. Nothing in this document is implemented yet
except the prototypes under `conformance_tests/` that are referred to below.

## 1. Goal

Build a test suite with, for every syntax rule (`R401`–`R1547`, 502 rules) and
every constraint (`C401`–`C15121`, 666 constraints) of Fortran 2023 as listed
in `doc/fortran_2023_rules.txt`:

* **valid tests**: conforming programs that exercise the rule and must compile
  and run correctly, and
* **invalid tests**: nonconforming programs that violate exactly that rule and
  must be rejected at compile time with a diagnostic that names the rule.

Then use the suite to drive LFortran: every valid test must pass and every
invalid test must fail with the correct error message.

## 2. What the standard itself says about detectability

This shapes the whole design, so it is worth stating precisely.

F2023 4.1.2 (syntax rules) and 4.1.3/4.2 (conformance) require that a
conforming processor *shall have the capability to detect and report* the use
within a submitted program unit of any form that does not conform to the
syntax rules, and any *violation of a constraint*. Constraints are, by
definition, the "shall" statements the standard chose because they are
statically checkable.

Consequences:

1. **Every invalid test is a compile-time test.** For an `R` or `C` rule there
   is no such thing as a "should fail at run time" test. If a violation is only
   detectable at run time, it is not a violation of that constraint but of some
   other normative text (see 2.1 below).
2. **Detection is required for every rule**, so "LFortran does not check this"
   is always a bug, never an accepted limitation. The suite therefore has no
   notion of "not applicable" for an invalid test, only "not implemented yet".
3. **The valid tests are the only ones that need to run**, and they need to run
   under LFortran and under at least one reference compiler, because the
   reference compiler is our only check that a "valid" program really is valid
   (see 5.3 for how often this went wrong while prototyping).

### 2.1 What is *not* an R/C rule (out of scope, for now)

Normative "shall" sentences in the body text (e.g. "the value of `dim` shall
be in the range 1 to n"), semantics that the processor need not detect
(11.1.7.5 iteration independence in DO CONCURRENT), and processor-dependent
behaviour (Annex A). These have no rule numbers and are not covered by this
suite. The suite design leaves room for a third category (working name `S`
for "semantic requirement", numbered by subclause, e.g. `S16.9.194`) that
would hold *runtime* failure tests, but that is a separate project.

## 3. Layout

```
conformance_tests/
    README.md                     short pointer to this document
    run_tests.py                  runner (prototype exists)
    expected_failures.txt         xfail list, one test name per line, with reason
    rules.toml                    (planned) one entry per rule: status, notes
    clause04/
    clause05/
    ...
    clause07/
        C726_ok_1.f90
        C726_bad_1.f90
        C726_bad_2.f90
        ...
    clause19/
```

### 3.1 Why one file per invalid case, not one file per rule with many cases

The alternative, used today by `tests/errors/continue_compilation_*.f90`, is
one large file with many violations compiled with `--continue-compilation`.
It was rejected because:

* error recovery interferes with attribution: a syntax error makes the parser
  drop a declaration and everything downstream of it produces cascade errors
  (the header comment of `continue_compilation_1.f90` documents exactly this
  problem);
* one broken case masks the others;
* the expected output is a 600-line reference file that must be regenerated on
  every wording change, and reviewing a diff of it is impractical;
* the line numbers of every case shift when one case is added.

One violation per file costs nothing but files (≈2 000–3 000 small files for
the invalid side; `integration_tests/` already has 4 500) and one compiler
invocation per file (about 10 ms each with `--semantics-only` in a debug
build, so the invalid side of a full run takes well under a minute on one
core and is trivially parallel).

### 3.2 Why one directory per clause, not one directory per rule

Per-rule directories (`C726/ok_1.f90`, `C726/bad_1.f90`) were considered.
They make the rule the unit of work, which is attractive, but 1 168 directories
with two to five files each are awkward to browse, the rule id would be
repeated in the path and lost from the file name (so `git log` output,
`ctest` names, and grep hits become less readable), and a manifest per
directory is more churn than one manifest. With the rule id in the file name
and the clause as the directory, `ls conformance_tests/clause07/C7*` shows
everything about a rule and `grep -rl C726 conformance_tests` finds it too.

The clause is the natural grouping because rule numbers already encode it
(`Rnnn`/`Cnnn` belong to clause `nn`), so nothing has to be looked up to place
a file. The biggest clauses (7, 8, 11, 15) will have 400–800 files each; that
is fine for tools and tolerable for humans.

### 3.3 File naming

```
<RULE>_ok_<n>.f90       valid program
<RULE>_bad_<n>.f90      invalid program violating <RULE>
<RULE>_ok_<n>_mod.f90   extra file (module) of a multi-file valid test  (planned)
<RULE>_ok_<n>.f         fixed-form source (clause 6 rules)              (planned)
```

`<RULE>` is spelled exactly as in the standard (`C726`, `C7100`, `C15121`,
`R1123`): no zero padding, so that the file name is greppable with the string
used in the standard, in compiler messages, and in `doc/fortran_2023_rules.txt`.
Lexical sort order of file names is therefore not numeric; nobody sorts by it.

The program/module name inside the file equals the file name in lower case
(`program c726_bad_1`) so that error output and `ctest` names line up.

Rules that are restated in clause 5 (`R1401` shown under 5.1 and under 14.1)
get their tests once, under the clause that defines them.

### 3.4 Anatomy of a test file

```fortran
! C726 (R721 R722 R723): `*` as a type-param-value used to declare a local
! variable, which is none of the permitted contexts.
program c726_bad_1
    implicit none
    character(*) :: s   ! {error C726}
    s = "abc"
end program
```

* The header comment quotes or paraphrases the rule and says *which facet* of
  it the file exercises. For valid tests with several facets, the header lists
  them (see `clause11/R1123_ok_1.f90`, which exercises all three alternatives
  of `loop-control` with and without the optional comma).
* `implicit none` everywhere.
* Valid tests check their own results with `if (...) error stop` and print
  nothing on success, so that "exit code 0" is the whole pass criterion and
  the same file can be compiled by any compiler without a driver.
* Invalid tests contain exactly one violation. The offending line carries a
  marker `! {error <RULE>}`. A file may carry several markers only if the
  same single construct necessarily produces errors on several lines.
* Small: typically 5–30 lines. A rule with many facets gets more files, not a
  bigger file.
* No output to stdout in valid tests, no reading from stdin, no files on disk
  unless the rule is about files (clause 12), in which case the test creates
  and deletes its own scratch file.

### 3.5 Expected failures

`expected_failures.txt` lists tests that LFortran currently fails, one per
line, with the reason as a trailing comment. It is regenerated with
`run_tests.py --update-xfail`, so nobody edits it by hand; a fix PR simply
runs the update and commits the shrunken list. An xfail that starts passing
is reported as `XPASS` and fails the run until the list is updated, which
keeps the list honest. This is the same mechanism the LLVM `lit` and the
GCC testsuites use and it separates two things that change at different
rates: the tests (rarely) and LFortran's status (constantly).

### 3.6 Per-rule manifest (planned)

`rules.toml`, generated once from `doc/fortran_2023_rules.txt` and then
maintained by hand, with one entry per rule:

```toml
[C726]
text = "A type-param-value of * shall be used only ..."
valid = "done"         # todo | done | not_applicable
invalid = "done"       # todo | done | not_applicable
notes = "bad_3 needs assumed-length ALLOCATE type-spec; LFortran cannot parse it yet"

[R401]
valid = "not_applicable"
invalid = "not_applicable"
notes = "meta-rule (xyz-list); has no concrete syntax of its own"
```

`not_applicable` always requires a `notes` justification. The coverage
report (`run_tests.py --coverage`) is computed from the files that exist plus
this manifest, so that rules with a justified `not_applicable` count as
covered and the report can reach 100 %. Rules expected to be
`not_applicable` on the invalid side are few: the meta-rules `R401`–`R403`,
some pure "is a name" productions (`R804 object-name is name`) whose only
violation is a lexical one already covered by `R601`–`R603`, and a handful of
restatements. Everything else must have both sides.

## 4. Runner and checking semantics

`conformance_tests/run_tests.py` (prototype committed) does the following.

Valid test:

1. `lfortran --std=f23 <file> -o exe`, must succeed;
2. run `exe`, exit code must be 0;
3. with `--reference gfortran` also compile and run with the reference
   compiler (`-std=f2018` for gfortran 13, which has no `f2023`); a rejection
   by the reference compiler fails the test, because it most likely means
   the test, not the compiler, is wrong.

Invalid test:

1. `lfortran --std=f23 --semantics-only --no-color --error-format short <file>`;
2. exit code must be non-zero (warnings do not count: LFortran currently
   reports several constraint violations as warnings, which the runner
   correctly reports as "compiled without error (warnings only)");
3. every marked line must have at least one error reported on it;
4. strict mode (default): no error may be reported on an unmarked line, so
   that cascades and misattributed locations are caught;
5. with `--codes`: the diagnostic on the marked line must carry the rule code
   (`semantic error [C726]: ...`). Until LFortran emits codes this is off and
   the runner prints "detected, but without a rule code".

The `short` error format is machine-readable
(`file:L1-L2:C1-C2: <stage> error: message`) and already exists; the runner
parses it rather than the human format.

Reference compiler results are only used for valid tests. For invalid tests
they are advisory: gfortran 13 accepts `C1302_bad_3` (`(I2 2/ I2)`, comma
required before a slash with a repeat count) and compiles
`C1302_bad_4` (format in a variable) with a run-time extension, so agreement
with gfortran cannot be a pass criterion. When authoring, disagreement with
the reference compiler is a signal to re-read the rule, not an oracle.

### 4.1 Integration with the existing suites

The valid tests are ordinary end-to-end programs and could be registered in
`integration_tests/CMakeLists.txt` with `RUN(NAME ... LABELS gfortran llvm)`
to get every backend for free. That is the right long-term home for them
(the repository's rule is "all new tests should be integration tests"), but
adding 1 000+ `RUN` lines to a 4 000-line CMakeLists is not attractive.
Proposal: the conformance runner is the primary driver for both sides, and a
generated `conformance_tests/CMakeLists.txt` (produced by
`run_tests.py --emit-cmake`) is included from `integration_tests/` so that
`ctest -L llvm` and the other backends also cover the valid tests. This keeps
one source of truth (the files on disk) and no hand-maintained list.

The invalid tests do **not** use `tests/tests.toml` and reference outputs, for
the reasons in 3.1: the pass criterion is a rule code and a line, not a
byte-exact rendering of the message, so wording can improve without touching
1 000 reference files.

CI: one job, `conformance_tests/run_tests.py --reference gfortran --codes`,
after the integration tests. It fails on `FAIL` and on `XPASS`.

## 5. Findings from prototyping

Seven rules were prototyped (25 files, `conformance_tests/`), chosen to be
awkward: a constraint with a five-item list of permitted contexts (C726), the
generic-distinguishability constraint (C1514), a constraint with an exception
list on format syntax (C1302), two near-duplicate attribute constraints (C801
vs C815), a syntax rule with three alternatives (R1123) and a plain semantic
constraint (C1121). Results on the current `main` build:

| test | LFortran today |
| --- | --- |
| `C726_ok_1` | fails to compile: LEN parameters of PDTs are not supported |
| `C726_bad_1`, `_2` | detected, but by the ASR verifier ("AssumedLength-string variable should be a dummy variable"), i.e. after semantics, with an internal-sounding message and no rule code |
| `C726_bad_3` | detected as a *syntax* error: `allocate(character(*) :: s)` does not parse (parser gap, not the constraint) |
| `C726_bad_4` | not detected (assumed-length result of a module function) |
| `C801_bad_1` | not detected (`allocatable, allocatable`) |
| `C801_bad_2` | detected ("Dimensions specified twice"), no code |
| `C815_bad_1` | not detected (`allocatable` attribute given twice via a second statement) |
| `C1121_bad_1` | warning only ("Start expression in DO loop must be integer"), must be an error |
| `C1302_bad_1`, `_2`, `_4` | warning only; the message already cites "F2023 constraint C1302" |
| `C1302_bad_3` | not detected |
| `C1514_bad_1`–`_4` | not detected: LFortran does not check generic distinguishability at all, including a generic mixing a subroutine and a function |
| `R1123_bad_1`–`_3` | detected as syntax errors; message quotes the marker comment as the unexpected token (`Token '! {error R1123}'`), a tokenizer wart |
| `R1123_ok_2` | compiles, wrong result: `LOCAL_INIT(u)` modifies the outer `u` |
| everything else | passes |

So even seven rules found four missing checks, three checks at the wrong
severity, one check in the wrong compiler stage, one parser gap and one
code-generation bug. The suite will find hundreds of these; that is the point.

### 5.1 Authoring lessons

Writing tests for the standard is harder than it looks, and every one of
these mistakes was made while writing the 25 prototypes:

1. **A "valid" test violating a different rule.** The first `R1123_ok_1`
   used `do concurrent (i = 1:3) local(i)`, which violates C1127. gfortran
   caught it. Every valid test must be run through a reference compiler
   before it is committed.
2. **A "valid" test with a runtime bug.** `write(buf, '(I2/I2)')` into a
   scalar internal file hits end-of-record. Every valid test must be *run*
   under the reference compiler, not just compiled.
3. **An invalid test violating two rules.** `C726_bad_2` declares
   `character(*)` as a component; gfortran reports it as "component length
   must be a constant expression" (C750-ish), not as C726. When several
   constraints overlap, pick the example so that the intended rule is the
   *most specific* violation, and say in the header which other rules are
   also arguably violated. The runner matches only the code of the intended
   rule; LFortran may attach more than one code to a diagnostic if it wants.
4. **A rule mis-numbered in the header** (C1120 written for what is C1121).
   The header text is copied from `doc/fortran_2023_rules.txt`, and a review
   step checks that the file name, the header and the marker agree.
5. **Reference compiler gaps.** gfortran 13 does not implement DO CONCURRENT
   locality specs at all, so `R1123_ok_2` cannot be cross-checked with it.
   The manifest records which reference compilers accept each valid test;
   flang and ifx should be added as references in CI when available.
6. **Where the error is reported is a judgement call.** For C1514 the
   marker is on the `interface g` line, but LFortran could reasonably report
   it on the second `module procedure` line. The convention: the marker goes
   on the line of the *later* of the two conflicting declarations when the
   rule is about a conflict, and on the line containing the offending token
   otherwise. This needs to be written down per rule family once and then
   followed, or the invalid suite will churn as LFortran's locations change.

### 5.2 LFortran-side prerequisites (blockers)

1. **Rule codes in diagnostics.** `diag::Diagnostic` already has a `code`
   field, rendered as `error [CODE]: message` in both the human and the
   `short` formats, but it is used nowhere. Convention to adopt: every
   diagnostic for an R/C violation passes the rule id as the code. A local
   experiment tagging the "Dimensions specified twice" diagnostic with
   `"C801"` renders as
   `C801_bad_2.f90:5-5:5-44: semantic error [C801]: Dimensions specified twice`
   and the runner's `--codes` mode accepts it. This is the single most
   valuable change: it makes the test suite independent of message wording
   and it makes `grep C801 src/` find the check.
2. **Constraint violations must be errors under `--std=f23`.** Several are
   warnings today (C1121, C1302). Whether they stay warnings in the default
   `lf` mode is a separate decision; the suite runs with `--std=f23`.
3. **Constraint checks belong in semantics, not in ASR verify.** C726 is
   caught by `asr_verify`, so the message is an internal one and the check
   only fires when verification runs. Verify is a debugging aid, not a
   front-end.
4. **`--semantics-only` must not silently accept unparsed constructs**;
   `C726_bad_3` shows a parser gap masquerading as a constraint diagnostic.
   Syntax-rule tests (`R*_ok_*`) will surface these systematically.
5. **Error location and message hygiene.** Comment tokens leak into parser
   messages; "ASR verify pass error" is not a user-facing stage name.
6. **Missing features are xfails, not skips.** PDTs (C726_ok_1), and
   presumably assumed-rank, `ENUMERATION TYPE`, `TYPEOF`, conditional
   expressions, `REDUCE` locality and coarray teams elsewhere, will make many
   valid tests xfail. The xfail list doubles as a feature roadmap, ordered by
   how many rules each missing feature blocks.

### 5.3 Special families of rules

* **Clause 6 (source form).** Fixed-form rules need `.f` files and the
  free-form rules need tests with continuation lines, `;`, `&`, 132-column
  limits and character-context rules; these are lexer tests. The runner
  must accept `.f` and pass `--fixed-form` for them.
* **Clause 5 (high-level syntax) and R501–R516.** Program-unit ordering
  rules. Their invalid tests are things like a `use` after a declaration.
  Trivially testable, but they overlap with the parser's own recovery.
* **Multi-file rules.** Submodules (`R1416`–`R1419`, `C1412`+), separate
  module procedures, `INCLUDE` lines (6.4) and `bind(c)` with a C
  counterpart (clause 18) need a second file. Convention: extra files are
  named after the test with a suffix and listed by the runner from the
  header (`! extra: R1416_ok_1_mod.f90`).
* **Coarrays (clause 5, 8, 9, 11, 16).** Valid tests need `--coarray` and
  possibly more than one image; the runner needs a per-test option line
  (`! options: --coarray`). Invalid tests are ordinary compile-time tests.
* **I/O (clause 12, 13).** Valid tests use internal files or a scratch unit
  so that nothing touches the file system permanently.
* **Intrinsic modules and IEEE (16, 17).** Clause 16 has 14 constraints
  (mostly about `INT`, `REAL`, `NULL`, `PRESENT`, `RANK` arguments); clause
  17 has none. Small.
* **Deleted and obsolescent features.** Obsolescent features are still in
  the standard (e.g. `ENTRY`, alternate return, `COMMON`, arithmetic IF)
  and have rules; they get tests like any other rule and LFortran must
  accept them (with its style warning) under `--std=f23`.
* **Rules referring to "the processor"** or to processor-dependent limits
  (kind values, `MAXEXPONENT`) are written so that the checked property is
  the one the rule guarantees, not the processor-dependent value.

## 6. How the tests get written

The scale (≈1 200 rules, ≈4 000 files) rules out writing them by hand in one
go, but each rule is small and self-contained, which is ideal for LLM-assisted
authoring with a fixed procedure:

1. Take one subclause at a time (e.g. 7.5.2, "Derived-type definition",
   R726–R731 and C733–C745). `doc/fortran_2023_rules.txt` is already grouped
   this way, and rules in the same subclause share the vocabulary needed to
   write good examples. A per-subclause "packet" for the author contains the
   rules, the normative text of the subclause (extractable from the PDF with
   the same pipeline that produced the rules file), and any existing tests
   for those rules.
2. For each rule write the valid file(s) covering every alternative/facet
   and one invalid file per facet of the "shall not".
3. Run `run_tests.py --reference gfortran -t <RULE>`: every valid test must
   pass the reference compiler (see 5.1). Where the reference compiler is
   known not to implement the feature, say so in the header and, ideally,
   verify with a second reference compiler.
4. Run against LFortran, update `expected_failures.txt`, and record the
   status in `rules.toml`.
5. One PR per subclause (10–40 files), reviewed for: header/name/marker
   agreement, single violation per invalid file, reference-compiler
   evidence in the PR description, no reliance on LFortran-specific
   behaviour.

Fixing LFortran is a separate stream of PRs, each of which flips a set of
xfails to passes ("one rule (or one check) = one PR"), and adds the rule
code to the diagnostic it introduces or touches.

Reviewing generated tests is the bottleneck, not writing them. The reference
compiler check removes the most common class of mistakes (invalid "valid"
tests) mechanically; the remaining review is about whether an invalid test
really isolates the rule it claims to.

## 7. Open questions for discussion

1. **Top-level directory name.** `conformance_tests/` next to
   `integration_tests/` and `tests/`, or `integration_tests/std/`? The
   prototype uses the former.
2. **`ok`/`bad` versus `valid`/`invalid` in file names.** Shorter wins in
   directory listings; the prototype uses `ok`/`bad`.
3. **Strictness on extra errors.** Strict by default, with a per-file
   `! allow-extra-errors` escape hatch, or lenient by default? Strict finds
   more bugs; lenient makes the initial xfail list shorter.
4. **Should the `lf` default mode also reject constraint violations?**
   The suite only needs `--std=f23` to be strict. Turning warnings into
   errors in the default mode affects users and is a product decision.
5. **Where do the tests for normative non-constraint "shall"s go** (2.1)?
   Proposed: later, as an `S` category in the same tree with the same runner
   plus a "must fail at run time" kind.
6. **Reference compilers in CI.** gfortran is available today; flang and ifx
   would catch gfortran's gaps and disagreements. Worth a nightly job even if
   not a PR gate.
7. **Marker placement conventions** per rule family (5.1 item 6) need to be
   fixed before mass authoring starts, otherwise LFortran's choice of error
   location will force test churn later.
