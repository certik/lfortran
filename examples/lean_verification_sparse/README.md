# Verifying a Fortran sparse matrix-vector multiply in Lean

This is the second prototype of an LFortran ASR → Lean backend. The first
one is `../lean_verification`. Here the Fortran program `sparse.f90` has
three routines:

1. `tridiag_coo` builds the tridiagonal matrix `tridiag(-1, 2, -1)` in COO
   (coordinate) format. The entries are deliberately not sorted by row.
2. `coo2csr` converts COO to CSR (Compressed Sparse Row) in three steps:
   count the entries in each row, take a prefix sum, and scatter.
3. `csr_matvec` computes `y = A x` in CSR format.

The Lean translation is a hand-written, statement-by-statement copy of the
Fortran. We prove that no array is ever indexed out of bounds.

    lfortran sparse.f90 && ./a.out

## Files

| File | Contents |
| --- | --- |
| `SparseLean/Runtime.lean` | Fortran runtime model, generic over the element type (`ℤ` for `integer`, `ℚ` for `real(dp)`). Arrays use 1-based, bounds-checked `fget`/`fset`, and `do` loops use `frange`. Errors are either `FError.outOfBounds i` or `FError.errorStop`. The file also defines the generic VC tactics described below. |
| `SparseLean/Sparse.lean` | The translation: one `def` per Fortran procedure, with the same names. The header lists the translation rules. |
| `SparseLean/Bounds.lean` | The proofs. |

## Theorems

* `csr_matvec_in_bounds`: `csr_matvec` never indexes out of bounds, for every
  valid CSR matrix and every `x(1:n)`. A CSR matrix is valid (`ValidCSR`)
  when:
  * `row_ptr(1) = 1` and `row_ptr(n+1) = nnz + 1`;
  * `row_ptr` is non-decreasing;
  * every column index stored in a row is in `1..n`.
* `csr_matvec_invalid_col`: without that precondition the code does index
  out of bounds.
* `coo2csr_valid`: `coo2csr` never indexes out of bounds for every valid COO
  matrix, and its output is a valid CSR matrix. The hard case is the scatter
  step `col_ind(p) = col(k)`. It is in bounds by a counting argument: row `r`
  owns exactly `cnt r` positions starting at `row_ptr(r)`, and entry `k` is
  itself one of them.
* `tridiag_coo_valid`: `tridiag_coo` never indexes out of bounds and
  produces a valid COO matrix with `3n - 2` entries.
* `main_no_out_of_bounds`: `program sparse` never indexes out of bounds.
  The only way it can fail is one of its `error stop` checks.

None of the proofs use `sorry` or `native_decide`.

## How the proofs work

`mvcgen` turns each routine into verification conditions (VCs). Every
`fget`/`fset` becomes one bounds goal. The VCs are handled in two steps.

1. `fortran_vcs` is the same for every routine:
   * `destruct_state` splits the tuple of loop variables;
   * `frange_facts` adds the value and bounds of each loop variable;
   * `loop_inst` instantiates the "for all indices" hypotheses at the indices
     that actually occur, keeping only instances whose premises `omega` can
     prove;
   * `omega` then closes the goal.

   This closes every bounds check except the two scatter accesses in
   `coo2csr`.
2. The remaining goals are loop invariant preservation plus the two scatter
   bounds. They are closed by applying small step lemmas. Each loop invariant
   is a named predicate such as `Counted` or `Scattered`.

A generator could emit the translation directly. For the proofs, it would
emit the invariants and the second step, while the first step stays generic.

## Building

    lake exe cache get   # download prebuilt Mathlib
    lake build

## Modelling assumptions

* Exact arithmetic: `real(dp)` is `ℚ` and `integer` is `ℤ`. Floating-point
  rounding and integer overflow are not modelled.
* A freshly allocated array is modelled as all zeros.
* Actual arguments of explicit-shape dummy arrays must have the declared
  size. This is part of each routine's precondition.
* `print` statements are omitted.
