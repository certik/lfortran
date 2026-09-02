# Fortran 2023 conformance tests (prototype)

For every syntax rule (`R*`) and constraint (`C*`) of Fortran 2023 there is
one valid file and one invalid file, grouped by clause:

* `<RULE>_valid.f90` exercises all facets of the rule in one program that
  must compile and run with exit code 0;
* `<RULE>_invalid.f90` holds many independent invalid cases, one per
  top-level program unit, each offending line marked `! {error <RULE> <case>}`.

`<RULE>` is `R<n>` or `C<n>` from the standard, or `S<subclause>` for a
normative requirement without a number (`S15_5_2_4_invalid.f90`, marker
`S15.5.2.4`).

Design, conventions and the plan for filling this in are in
`doc/fortran_2023_conformance_tests.md`; the rules are in
`doc/fortran_2023_rules.txt`.

```
# build/src/bin first on PATH, then:
conformance_tests/run_tests.py                                   # LFortran only
conformance_tests/run_tests.py --reference gfortran --reference flang-new-18
conformance_tests/run_tests.py --codes                           # require rule codes
conformance_tests/run_tests.py --update-xfail                    # regenerate expected_failures.txt
conformance_tests/run_tests.py --coverage doc/fortran_2023_rules.txt
```
