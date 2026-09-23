/-
Manual translation of `poisson.f90` to Lean.

This is (by hand, for now) what an LFortran → Lean backend would emit: one
Lean `def` per Fortran procedure, written in imperative `do` notation that
follows the Fortran source line by line. `real(dp)` is `ℚ`, `integer` is
`ℤ`, arrays are accessed through the bounds-checked `fget` / `fset` of
`FortranLean.Runtime`, and `intent(out)` arguments become return values.
-/
import FortranLean.Runtime

namespace Fortran.Poisson

/-- `subroutine thomas(n, a, b, c, d, x)`: solve the tridiagonal system
`a(i) x(i-1) + b(i) x(i) + c(i) x(i+1) = d(i)`, `i = 1, ..., n`. -/
def thomas (n : ℤ) (a b c d : Array ℚ) : FM (Array ℚ) := do
  let mut x := falloc n
  let mut cp := falloc n
  let mut dq := falloc n
  let mut m : ℚ := 0
  cp ← fset cp 1 ((← fget c 1) / (← fget b 1))
  dq ← fset dq 1 ((← fget d 1) / (← fget b 1))
  for i in frange 2 n do
    m := (← fget b i) - (← fget a i) * (← fget cp (i - 1))
    cp ← fset cp i ((← fget c i) / m)
    dq ← fset dq i (((← fget d i) - (← fget a i) * (← fget dq (i - 1))) / m)
  x ← fset x n (← fget dq n)
  for i in frange (n - 1) 1 (-1) do
    x ← fset x i ((← fget dq i) - (← fget cp i) * (← fget x (i + 1)))
  return x

/-- `subroutine solve_poisson(n, f, u)`: assemble the finite difference
system for `-u'' = f`, `u(0) = u(1) = 0`, and solve it. -/
def solvePoisson (n : ℤ) (f : Array ℚ) : FM (Array ℚ) := do
  let mut a := falloc n
  let mut b := falloc n
  let mut c := falloc n
  let mut d := falloc n
  let mut h : ℚ := 0
  h := 1 / ((n + 1 : ℤ) : ℚ)
  for i in frange 1 n do
    a ← fset a i (-1)
    b ← fset b i 2
    c ← fset c i (-1)
    d ← fset d i (h ^ 2 * (← fget f i))
  let u ← thomas n a b c d
  return u

/-- `program poisson`, without the `print` statements. The `error stop`
becomes a `throw`. -/
def main : FM Unit := do
  let n : ℤ := 9
  let mut f := falloc n
  let mut x : ℚ := 0
  let mut h : ℚ := 0
  let mut err : ℚ := 0
  h := 1 / ((n + 1 : ℤ) : ℚ)
  for i in frange 1 n do
    x := i * h
    f ← fset f i (6 * x)
  let u ← solvePoisson n f
  err := 0
  for i in frange 1 n do
    x := i * h
    err := max err |(← fget u i) - (x - x ^ 3)|
  if err > 1 / 10 ^ 14 then errorStop

end Fortran.Poisson
