/-
Refinement: the imperative translation of `subroutine thomas` never indexes
out of bounds (for `n ≥ 1`) and computes exactly the functional
specification `Tridiag.sol`.

The proof uses `mvcgen`, Lean's verification condition generator for
monadic `do` programs. Each `fget` / `fset` generates one bounds-check goal
(closed automatically by `omega`); the loop invariants of the two sweeps are
given explicitly, and their preservation is proved by the lemmas below.
-/
import FortranLean.Poisson
import FortranLean.Spec

open Std.Do

set_option mvcgen.warning false

namespace Fortran

open Lean Elab Tactic Meta in
/-- For every loop cursor hypothesis `frange lo hi step = pre ++ cur :: suf`
in the context, add the value of the loop variable `cur` and its bounds. -/
elab "frange_facts" : tactic => withMainContext do
  for ldecl in (← getLCtx) do
    if ldecl.isImplementationDetail then continue
    let ty ← instantiateMVars ldecl.type
    let some (_, lhs, _) := ty.eq? | continue
    unless lhs.isAppOf ``frange do continue
    for lem in [``frange_split_up, ``frange_split_down] do
      try
        let pf ← mkAppM lem #[ldecl.toExpr]
        let pty ← inferType pf
        liftMetaTactic fun g => do
          let (_, g) ← (← g.assert `hloop pty pf).intro1
          return [g]
      catch _ => pure ()

/-- Side conditions of the loop lemmas: hypotheses, linear arithmetic, sizes. -/
macro "vc_side" : tactic =>
  `(tactic| first | assumption | omega | (simp only [Array.size_replicate] <;> omega))

/-- A Fortran array `a(1:n)` as a 1-based function `ℕ → ℚ`. -/
def F (a : Array ℚ) : ℕ → ℚ := fun i => fval a i

end Fortran

namespace Fortran.Poisson

open Tridiag

section
variable {n : ℕ} {a b c d : Array ℚ}

/-- Forward sweep invariant: `cp(1:k)` and `dq(1:k)` hold their final values. -/
def FwdVals (a b c d cp dq : Array ℚ) (k : ℕ) : Prop :=
  ∀ j : ℕ, 1 ≤ j → j ≤ k →
    fval cp j = Tridiag.cp (F a) (F b) (F c) j ∧ fval dq j = Tridiag.dq (F a) (F b) (F c) (F d) j

/-- Back substitution invariant: `x(k:n)` holds the solution. -/
def BwdVals (n : ℕ) (a b c d x : Array ℚ) (k : ℕ) : Prop :=
  ∀ j : ℕ, k ≤ j → j ≤ n → fval x j = sol (F a) (F b) (F c) (F d) n j

theorem FwdVals.mono {cp dq : Array ℚ} {k m : ℕ} (h : FwdVals a b c d cp dq k) (hm : m ≤ k) :
    FwdVals a b c d cp dq m :=
  fun j hj1 hj2 => h j hj1 (by omega)

/-- `cp(1) = c(1) / b(1)`, `dq(1) = d(1) / b(1)` establish the invariant for `k = 1`. -/
theorem fwd_init {cp dq : Array ℚ} (hcp : 1 ≤ cp.size) (hdq : 1 ≤ dq.size) :
    FwdVals a b c d (fupd cp 1 (fval c 1 / fval b 1)) (fupd dq 1 (fval d 1 / fval b 1)) 1 := by
  intro j hj1 hj2
  obtain rfl : j = 1 := by omega
  rw [fval_fupd (by omega) (by omega), fval_fupd (by omega) (by omega)]
  simp [Tridiag.cp, Tridiag.dq, Tridiag.piv, F]

/-- One iteration `i = k + 2` of the forward sweep preserves the invariant. -/
theorem fwd_step {cp dq : Array ℚ} {k : ℕ} {i : ℤ} (hi : i = k + 2)
    (hcp : cp.size = n) (hdq : dq.size = n) (hkn : k + 2 ≤ n)
    (h : FwdVals a b c d cp dq (k + 1)) :
    FwdVals a b c d
      (fupd cp i (fval c i / (fval b i - fval a i * fval cp (i - 1))))
      (fupd dq i ((fval d i - fval a i * fval dq (i - 1)) / (fval b i - fval a i * fval cp (i - 1))))
      (k + 1 + 1) := by
  intro j hj1 hj2
  rw [fval_fupd (by omega) (by omega), fval_fupd (by omega) (by omega)]
  split_ifs with hji
  · obtain rfl : j = k + 2 := by omega
    subst hi
    obtain ⟨h1, h2⟩ := h (k + 1) (by omega) le_rfl
    rw [show (k : ℤ) + 2 - 1 = ((k + 1 : ℕ) : ℤ) by push_cast; ring, h1, h2]
    simp only [Tridiag.cp, Tridiag.dq, Tridiag.piv, F, Nat.add_sub_cancel]
    push_cast
    constructor <;> ring_nf
  · exact h j hj1 (by omega)

/-- `x(n) = dq(n)` establishes the back substitution invariant for `k = n`. -/
theorem bwd_init {x cp dq : Array ℚ} {K : ℕ} (hx : x.size = n) (hn : 1 ≤ n)
    (hf : FwdVals a b c d cp dq K) (hK : n ≤ K) :
    BwdVals n a b c d (fupd x n (fval dq n)) n := by
  intro j hj1 hj2
  obtain rfl : j = n := by omega
  rw [fval_fupd (by omega) (by omega), if_pos rfl, sol_rec le_rfl, sol_succ_n,
    (hf j (by omega) hK).2]
  ring

/-- One iteration `i = k` of the back substitution preserves the invariant. -/
theorem bwd_step {x cp dq : Array ℚ} {k K m : ℕ} {i : ℤ} (hi : i = k)
    (hk1 : 1 ≤ k) (hkn : k < n) (hx : x.size = n)
    (hf : FwdVals a b c d cp dq K) (hK : n ≤ K)
    (hb : BwdVals n a b c d x m) (hm : m ≤ k + 1) :
    BwdVals n a b c d (fupd x i (fval dq i - fval cp i * fval x (i + 1))) k := by
  intro j hj1 hj2
  rw [fval_fupd (by omega) (by omega)]
  split_ifs with hji
  · obtain rfl : j = k := by omega
    subst hi
    obtain ⟨h1, h2⟩ := hf j hk1 (by omega)
    rw [show (j : ℤ) + 1 = ((j + 1 : ℕ) : ℤ) by push_cast; ring, h1, h2,
      hb (j + 1) (by omega) (by omega), sol_rec (i := j) (by omega)]
  · exact hb j (by omega) hj2

theorem bwd_final {x : Array ℚ} {m : ℕ} (hb : BwdVals n a b c d x m) (hm : m ≤ 1) :
    ∀ i : ℕ, 1 ≤ i → i ≤ n → fval x i = sol (F a) (F b) (F c) (F d) n i :=
  fun i hi1 hi2 => hb i (by omega) hi2

end

/-- **Refinement theorem for `thomas`.** For `n ≥ 1` and input arrays of size
`n`, the translated Fortran subroutine never indexes out of bounds and
returns an array of size `n` whose entries are the Thomas algorithm solution
`Tridiag.sol`. (No assumption on the pivots is needed here: a zero pivot
divides by zero, which in `ℚ` gives `0` in both the program and the spec.) -/
theorem thomas_correct (n : ℕ) (a b c d : Array ℚ) (hn : 1 ≤ n)
    (ha : a.size = n) (hb : b.size = n) (hc : c.size = n) (hd : d.size = n) :
    ⦃⌜True⌝⦄ thomas n a b c d
    ⦃⇓ x => ⌜x.size = n ∧ ∀ i : ℕ, 1 ≤ i → i ≤ n → fval x i = sol (F a) (F b) (F c) (F d) n i⌝⦄ := by
  mvcgen [thomas]
  invariants
  · ⇓⟨xs, cp, dq, _⟩ => ⌜cp.size = n ∧ dq.size = n ∧ FwdVals a b c d cp dq (xs.pos + 1)⌝
  · ⇓⟨xs, x⟩ => ⌜x.size = n ∧ BwdVals n a b c d x (n - xs.pos)⌝
  all_goals frange_facts
  all_goals simp_all (config := { zetaDelta := true }) [falloc]
  all_goals try casesm* _ ∧ _
  all_goals first
    | omega
    | (apply fwd_init <;> vc_side)
    | (apply fwd_step <;> vc_side)
    | (apply bwd_init <;> vc_side)
    | (apply bwd_step <;> vc_side)
    | (apply bwd_final <;> vc_side)

/-- The same statement as a `@[spec]` Hoare triple, so that `mvcgen` can use
it at call sites of `thomas`. -/
@[spec] theorem thomas_spec (n : ℕ) (a b c d : Array ℚ) :
    ⦃⌜1 ≤ n ∧ a.size = n ∧ b.size = n ∧ c.size = n ∧ d.size = n⌝⦄ thomas n a b c d
    ⦃⇓ x => ⌜x.size = n ∧ ∀ i : ℕ, 1 ≤ i → i ≤ n → fval x i = sol (F a) (F b) (F c) (F d) n i⌝⦄ := by
  mintro h
  mpure h
  obtain ⟨hn, ha, hb, hc, hd⟩ := h
  exact thomas_correct n a b c d hn ha hb hc hd

/-- Memory safety of `thomas`: for `n ≥ 1` it never indexes out of bounds. -/
theorem thomas_no_out_of_bounds (n : ℕ) (a b c d : Array ℚ) (hn : 1 ≤ n)
    (ha : a.size = n) (hb : b.size = n) (hc : c.size = n) (hd : d.size = n) :
    ∃ x, thomas n a b c d = .ok x := by
  obtain ⟨x, hx, -⟩ := ok_of_triple (thomas_correct n a b c d hn ha hb hc hd)
  exact ⟨x, hx⟩

/-- The precondition `n ≥ 1` is necessary: for `n = 0` the Fortran code reads
`c(1)` out of bounds. -/
theorem thomas_zero_out_of_bounds : thomas 0 #[] #[] #[] #[] = .error "index 1 out of bounds" := by
  rfl

end Fortran.Poisson
