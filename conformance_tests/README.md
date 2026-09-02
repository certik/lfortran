# Fortran 2023 conformance tests (prototype)

One test file per facet of a syntax rule (`R*`) or constraint (`C*`) of
Fortran 2023, grouped by clause. `<RULE>_ok_<n>.f90` must compile and run,
`<RULE>_bad_<n>.f90` must be rejected with an error on every line marked
`! {error <RULE>}`.

Design, conventions and the plan for filling this in are in
`doc/fortran_2023_conformance_tests.md`; the rules themselves are in
`doc/fortran_2023_rules.txt`.

```
build/src/bin first on PATH, then:
conformance_tests/run_tests.py                       # LFortran only
conformance_tests/run_tests.py --reference gfortran  # also cross-check valid tests
conformance_tests/run_tests.py --codes               # require rule codes in diagnostics
conformance_tests/run_tests.py --update-xfail        # regenerate expected_failures.txt
conformance_tests/run_tests.py --coverage doc/fortran_2023_rules.txt
```
