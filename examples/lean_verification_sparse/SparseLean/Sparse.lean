/-
Manual translation of `sparse.f90` to Lean.

This is (by hand, for now) what an LFortran ASR → Lean backend would emit.
The translation is statement by statement:

* one Lean `def` per Fortran procedure, with the same name;
* `intent(in)` arguments become parameters, `intent(out)` arguments become
  the return value (a tuple if there are several);
* the actual arguments of explicit-shape dummy arrays must have the declared
  size; this is part of the precondition of each procedure's spec;
* `x = e` becomes `x := e` (scalars) or `x ← fset x i e` (array elements);
* every array element read `a(i)` becomes `(← fget a i)`;
* `do i = lo, hi` becomes `for i in frange lo hi do`;
* `call s(a, b)` becomes `b ← s a` (for an `intent(out)` argument `b`);
* `error stop` becomes `errorStop`.
-/
import SparseLean.Runtime

-- Fortran code routinely declares variables it does not use in the Lean
-- sense (e.g. `nnz`, which only appears in declarations).
set_option linter.unusedVariables false

namespace Fortran.Sparse

/-- `subroutine tridiag_coo(n, row, col, val)` -/
def tridiag_coo (n : ℤ) : FM (Array ℤ × Array ℤ × Array ℚ) := do
  let mut row : Array ℤ := falloc (3 * n - 2)
  let mut col : Array ℤ := falloc (3 * n - 2)
  let mut val : Array ℚ := falloc (3 * n - 2)
  let mut k : ℤ := 0
  k := 0
  for i in frange 1 n do
    k := k + 1
    row ← fset row k i
    col ← fset col k i
    val ← fset val k 2
  for i in frange 2 n do
    k := k + 1
    row ← fset row k i
    col ← fset col k (i - 1)
    val ← fset val k (-1)
  for i in frange 1 (n - 1) do
    k := k + 1
    row ← fset row k i
    col ← fset col k (i + 1)
    val ← fset val k (-1)
  return (row, col, val)

/-- `subroutine coo2csr(n, nnz, row, col, val, row_ptr, col_ind, csr_val)` -/
def coo2csr (n nnz : ℤ) (row col : Array ℤ) (val : Array ℚ) :
    FM (Array ℤ × Array ℤ × Array ℚ) := do
  let mut row_ptr : Array ℤ := falloc (n + 1)
  let mut col_ind : Array ℤ := falloc nnz
  let mut csr_val : Array ℚ := falloc nnz
  let mut next : Array ℤ := falloc n
  let mut r : ℤ := 0
  let mut p : ℤ := 0
  for i in frange 1 (n + 1) do
    row_ptr ← fset row_ptr i 0
  for k in frange 1 nnz do
    row_ptr ← fset row_ptr ((← fget row k) + 1) ((← fget row_ptr ((← fget row k) + 1)) + 1)
  row_ptr ← fset row_ptr 1 1
  for i in frange 1 n do
    row_ptr ← fset row_ptr (i + 1) ((← fget row_ptr (i + 1)) + (← fget row_ptr i))
  for i in frange 1 n do
    next ← fset next i (← fget row_ptr i)
  for k in frange 1 nnz do
    r := (← fget row k)
    p := (← fget next r)
    col_ind ← fset col_ind p (← fget col k)
    csr_val ← fset csr_val p (← fget val k)
    next ← fset next r (p + 1)
  return (row_ptr, col_ind, csr_val)

/-- `subroutine csr_matvec(n, nnz, row_ptr, col_ind, val, x, y)` -/
def csr_matvec (n nnz : ℤ) (row_ptr col_ind : Array ℤ) (val x : Array ℚ) :
    FM (Array ℚ) := do
  let mut y : Array ℚ := falloc n
  for i in frange 1 n do
    y ← fset y i 0
    for k in frange (← fget row_ptr i) ((← fget row_ptr (i + 1)) - 1) do
      y ← fset y i ((← fget y i) + (← fget val k) * (← fget x (← fget col_ind k)))
  return y

/-- `program sparse`, without the `print` statements. -/
def main : FM Unit := do
  let n : ℤ := 5
  let nnz : ℤ := 3 * n - 2
  let mut row : Array ℤ := falloc nnz
  let mut col : Array ℤ := falloc nnz
  let mut row_ptr : Array ℤ := falloc (n + 1)
  let mut col_ind : Array ℤ := falloc nnz
  let mut val : Array ℚ := falloc nnz
  let mut csr_val : Array ℚ := falloc nnz
  let mut x : Array ℚ := falloc n
  let mut y : Array ℚ := falloc n
  (row, col, val) ← tridiag_coo n
  (row_ptr, col_ind, csr_val) ← coo2csr n nnz row col val
  for i in frange 1 n do
    x ← fset x i i
  y ← csr_matvec n nnz row_ptr col_ind csr_val x
  for i in frange 1 (n - 1) do
    if (← fget y i) ≠ 0 then errorStop
  if (← fget y n) ≠ n + 1 then errorStop

end Fortran.Sparse
