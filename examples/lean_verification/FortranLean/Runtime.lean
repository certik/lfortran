/-
A tiny model of the Fortran features used by `poisson.f90`.

This is the "runtime library" that a future LFortran → Lean backend would
target:

* `real(dp)` is modelled by `ℚ` (exact arithmetic, no rounding).
* `integer` is modelled by `ℤ` (no overflow).
* A rank-1 array `real(dp) :: a(n)` is an `Array ℚ` of size `n`, indexed with
  Fortran's 1-based indices through `fget` / `fset`.
* Every array access is bounds checked. An out-of-bounds access throws, so a
  program that is proven to never throw never indexes out of bounds.
* `do i = lo, hi, step` loops iterate over `frange lo hi step`.

Every operation that can fail has a `@[spec]` Hoare triple whose precondition
is exactly the bounds check. When `mvcgen` generates the verification
conditions for a translated subroutine, each array access therefore produces
one bounds-check goal.
-/
import Mathlib

open Std.Do

set_option mvcgen.warning false

namespace Fortran

/-- The Fortran execution monad: a computation that can fail (out-of-bounds). -/
abbrev FM := Except String

/-- Allocate `real(dp) :: a(n)`. The contents of a fresh Fortran array are
undefined; we model them as zeros. -/
def falloc (n : ℤ) : Array ℚ := Array.replicate n.toNat 0

/-- The value `a(i)` of a Fortran array (1-based), as a pure function.
Only meaningful for `1 ≤ i ≤ size a`; used in specifications. -/
def fval (a : Array ℚ) (i : ℤ) : ℚ := a[(i - 1).toNat]!

/-- The array `a` after the assignment `a(i) = v`, as a pure function.
Only meaningful for `1 ≤ i ≤ size a`; used in specifications. -/
def fupd (a : Array ℚ) (i : ℤ) (v : ℚ) : Array ℚ := a.set! (i - 1).toNat v

/-- Read `a(i)`, checking bounds. -/
def fget (a : Array ℚ) (i : ℤ) : FM ℚ :=
  if 1 ≤ i ∧ i ≤ a.size then pure (fval a i)
  else throw s!"index {i} out of bounds"

/-- Write `a(i) = v`, checking bounds. -/
def fset (a : Array ℚ) (i : ℤ) (v : ℚ) : FM (Array ℚ) :=
  if 1 ≤ i ∧ i ≤ a.size then pure (fupd a i v)
  else throw s!"index {i} out of bounds"

/-- `error stop`. -/
def errorStop : FM Unit := throw "error stop"

/-- The number of iterations of `do i = lo, hi, step` (Fortran 2018, 11.1.7.4.1):
`max(0, (hi - lo + step) / step)` with truncating division. -/
def fcount (lo hi step : ℤ) : ℕ := ((hi - lo + step).tdiv step).toNat

/-- The sequence of values taken by `i` in `do i = lo, hi, step`. -/
def frange (lo hi : ℤ) (step : ℤ := 1) : List ℤ :=
  (List.range (fcount lo hi step)).map (fun k : ℕ => lo + (k : ℤ) * step)

/-! ## Hoare triples for the runtime primitives -/

@[spec] theorem fget_spec (a : Array ℚ) (i : ℤ) :
    ⦃⌜1 ≤ i ∧ i ≤ a.size⌝⦄ fget a i ⦃⇓ r => ⌜r = fval a i⌝⦄ := by
  mintro h
  simp_all [fget]

@[spec] theorem fset_spec (a : Array ℚ) (i : ℤ) (v : ℚ) :
    ⦃⌜1 ≤ i ∧ i ≤ a.size⌝⦄ fset a i v ⦃⇓ r => ⌜r = fupd a i v⌝⦄ := by
  mintro h
  simp_all [fset]

/-- `error stop` establishes the exceptional postcondition. (We provide our own
spec instead of relying on the generic one for `throw`, whose universe
parameters `mvcgen` cannot determine for `Except`.) -/
@[spec] theorem errorStop_spec (Q : PostCond Unit (.except String .pure)) :
    ⦃Q.2.1 "error stop"⦄ errorStop ⦃Q⦄ := by
  simp [Triple.iff, errorStop]

/-! ## Lemmas about arrays -/

@[simp] theorem size_falloc (n : ℤ) : (falloc n).size = n.toNat := by
  simp [falloc]

@[simp] theorem size_fupd (a : Array ℚ) (i : ℤ) (v : ℚ) : (fupd a i v).size = a.size := by
  simp [fupd]

theorem fval_fupd {a : Array ℚ} {i j : ℤ} {v : ℚ} (hi : 1 ≤ i ∧ i ≤ a.size) (hj : 1 ≤ j) :
    fval (fupd a i v) j = if j = i then v else fval a j := by
  have hk : (i - 1).toNat < a.size := by omega
  unfold fval fupd
  split_ifs with h
  · subst h
    rw [getElem!_pos _ _ (by simpa using hk)]
    simp
  · have : (i - 1).toNat ≠ (j - 1).toNat := by omega
    simp only [Array.set!_eq_setIfInBounds, getElem!_def, Array.getElem?_setIfInBounds, if_neg this]

/-! ## Lemmas about loops -/

@[simp] theorem fcount_up (lo hi : ℤ) : fcount lo hi 1 = (hi - lo + 1).toNat := by
  simp [fcount]

@[simp] theorem fcount_down (lo hi : ℤ) : fcount lo hi (-1) = (lo - hi + 1).toNat := by
  simp only [fcount, Int.tdiv_neg, Int.tdiv_one]
  congr 1
  omega

@[simp] theorem length_frange (lo hi step : ℤ) :
    (frange lo hi step).length = fcount lo hi step := by
  simp [frange]

/-- If the loop `do i = lo, hi, step` is at iteration `pre.length` (0-based),
the loop variable is `i = lo + pre.length * step`. -/
theorem frange_split {lo hi step cur : ℤ} {pre suf : List ℤ}
    (h : frange lo hi step = pre ++ cur :: suf) :
    cur = lo + pre.length * step ∧ pre.length + suf.length + 1 = fcount lo hi step := by
  have hlen : (frange lo hi step).length = pre.length + suf.length + 1 := by
    rw [h]; simp; omega
  have hc : (frange lo hi step)[pre.length]'(by omega) = cur := by
    simp [h]
  simp only [frange, List.getElem_map, List.getElem_range] at hc
  simp only [length_frange] at hlen
  exact ⟨hc.symm, hlen.symm⟩

theorem frange_split_up {lo hi cur : ℤ} {pre suf : List ℤ}
    (h : frange lo hi = pre ++ cur :: suf) :
    cur = lo + pre.length ∧ lo ≤ cur ∧ cur ≤ hi ∧ pre.length + suf.length + 1 = hi - lo + 1 := by
  have := frange_split h
  simp at this
  omega

theorem frange_split_down {lo hi cur : ℤ} {pre suf : List ℤ}
    (h : frange lo hi (-1) = pre ++ cur :: suf) :
    cur = lo - pre.length ∧ hi ≤ cur ∧ cur ≤ lo ∧ pre.length + suf.length + 1 = lo - hi + 1 := by
  have := frange_split h
  simp at this
  omega

/-! ## From Hoare triples to plain equations -/

/-- A total-correctness triple for an `FM` computation means that the
computation succeeds (in particular never indexes out of bounds) and its
result satisfies the postcondition. -/
theorem ok_of_triple {α : Type} {prog : FM α} {Q : α → Prop}
    (h : ⦃⌜True⌝⦄ prog ⦃⇓ r => ⌜Q r⌝⦄) : ∃ r, prog = .ok r ∧ Q r := by
  apply Except.of_wp_eq rfl (fun r => ∃ x, r = .ok x ∧ Q x)
  refine SPred.entails.trans h ?_
  apply (wp prog).mono
  refine ⟨fun a => ?_, ?_⟩
  · simp
  · simp

end Fortran
