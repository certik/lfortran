# Verifying Fortran code in Lean

This directory has a small numerical Fortran program, `poisson.f90`, and a
Lean 4 translation of it with machine-checked proofs about how it behaves.
The translation is written by hand for now. It is meant as a prototype of
what an LFortran → Lean backend would emit.

## The Fortran program

`poisson.f90` solves the 1D Poisson equation

    -u''(x) = f(x),   0 < x < 1,   u(0) = u(1) = 0

using second order central differences on the grid `x_i = i/(n+1)`. The
resulting tridiagonal system is solved with the Thomas algorithm
(`subroutine thomas`). The main program solves `-u'' = 6x` and checks the
result against the exact solution `u = x - x^3`.

    lfortran poisson.f90 && ./a.out

## The Lean model

| File | Contents |
| --- | --- |
| `FortranLean/Runtime.lean` | Fortran runtime model. `real(dp)` → `ℚ`, `integer` → `ℤ`, arrays → `Array ℚ` with bounds-checked 1-based `fget`/`fset`, `do` loops → `frange`, `error stop` → `errorStop`. Each primitive has a `@[spec]` Hoare triple. |
| `FortranLean/Poisson.lean` | Line-by-line translation of `thomas`, `solve_poisson` and `program poisson` into imperative `do` notation. |
| `FortranLean/Spec.lean` | Functional specification of the Thomas algorithm, with proofs that it solves the tridiagonal system and that the solution is unique when all pivots are nonzero. |
| `FortranLean/Refinement.lean` | The translated `thomas` never indexes out of bounds for `n ≥ 1` and computes exactly the specification. Verification conditions come from `mvcgen`. |
| `FortranLean/Physics.lean` | Physics theorems for `solve_poisson` and `program poisson`. |

Main theorems:

* `thomas_correct`: memory safety and functional correctness of `thomas`.
* `thomas_zero_out_of_bounds`: for `n = 0`, the Fortran code reads `c(1)`
  out of bounds, so the precondition `n ≥ 1` cannot be dropped.
* `solvePoisson_solves`: for every `n ≥ 1` and every `f`, `solve_poisson`
  returns the unique solution of the discrete Poisson equation
  `(-u(i-1) + 2u(i) - u(i+1))/h^2 = f(i)` with `u(0) = u(n+1) = 0`.
* `solvePoisson_exact_cubic`: take a cubic `u : ℝ → ℝ` that solves the
  continuous problem `-u'' = F`, `u(0) = u(1) = 0`, where the derivatives are
  Mathlib's `deriv`. Then `solve_poisson` called with `f(i) = F(x_i)` returns
  `u(x_i)` exactly.
* `main_ok`: `program poisson` runs to completion and never reaches
  `error stop`.

None of the proofs use `sorry` or `native_decide`.

## Building

    lake exe cache get   # download prebuilt Mathlib
    lake build

## Modelling assumptions

* The model uses exact rational arithmetic. It does not model floating-point
  rounding, so the theorems are about the algorithm run in exact arithmetic.
* Integers are unbounded; overflow is not modelled.
* A freshly allocated array is modelled as all zeros.
* `print` statements are omitted.
