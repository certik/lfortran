/-
Functional specification of the Thomas algorithm and its correctness.

Everything here is pure mathematics over `ℚ` with 1-based natural number
indices, independent of the Fortran translation. `Refinement.lean` proves that
the imperative translation `Fortran.Poisson.thomas` computes exactly these
functions.

Conventions: the unknowns are `x 1, ..., x n`, extended by the ghost values
`x 0 = x (n+1) = 0`. With these, row `i` of the tridiagonal system reads
`a i * x (i-1) + b i * x i + c i * x (i+1) = d i` for all `1 ≤ i ≤ n`, and
`a 1`, `c n` do not matter.
-/
import Mathlib

namespace Tridiag

variable (a b c d : ℕ → ℚ)

/-- The modified super-diagonal `c'` of the forward sweep (`cp` in Fortran).
`cp 0 = 0` makes the first step `cp 1 = c 1 / b 1` a special case. -/
def cp : ℕ → ℚ
  | 0 => 0
  | i + 1 => c (i + 1) / (b (i + 1) - a (i + 1) * cp i)

/-- The pivot `m` used in row `i` of the forward sweep. -/
def piv (i : ℕ) : ℚ := b i - a i * cp a b c (i - 1)

/-- The modified right hand side `d'` of the forward sweep (`dq` in Fortran). -/
def dq : ℕ → ℚ
  | 0 => 0
  | i + 1 => (d (i + 1) - a (i + 1) * dq i) / piv a b c (i + 1)

/-- Back substitution, counted from the end: `back n k = x (n + 1 - k)`. -/
def back (n : ℕ) : ℕ → ℚ
  | 0 => 0
  | k + 1 => dq a b c d (n - k) - cp a b c (n - k) * back n k

/-- The solution computed by the Thomas algorithm, `x i` for `0 ≤ i ≤ n + 1`. -/
def sol (n i : ℕ) : ℚ := back a b c d n (n + 1 - i)

/-- `x` solves the tridiagonal system of size `n` (with zero ghost values). -/
def Solves (n : ℕ) (x : ℕ → ℚ) : Prop :=
  x 0 = 0 ∧ x (n + 1) = 0 ∧
    ∀ i, 1 ≤ i → i ≤ n → a i * x (i - 1) + b i * x i + c i * x (i + 1) = d i

/-- All pivots are nonzero, i.e. the algorithm never divides by zero. -/
def PivotsNonzero (n : ℕ) : Prop := ∀ i, 1 ≤ i → i ≤ n → piv a b c i ≠ 0

variable {a b c d}

theorem cp_succ (i : ℕ) : cp a b c (i + 1) = c (i + 1) / piv a b c (i + 1) := rfl

theorem piv_mul_cp {i : ℕ} (h : piv a b c i ≠ 0) (hi : 1 ≤ i) :
    piv a b c i * cp a b c i = c i := by
  obtain ⟨k, rfl⟩ : ∃ k, i = k + 1 := ⟨i - 1, by omega⟩
  rw [cp_succ]; field_simp

theorem piv_mul_dq {i : ℕ} (h : piv a b c i ≠ 0) (hi : 1 ≤ i) :
    piv a b c i * dq a b c d i = d i - a i * dq a b c d (i - 1) := by
  obtain ⟨k, rfl⟩ : ∃ k, i = k + 1 := ⟨i - 1, by omega⟩
  simp only [dq, Nat.add_sub_cancel]; field_simp

@[simp] theorem sol_zero (n : ℕ) : sol a b c d n 0 = 0 := by
  simp [sol, back, dq, cp]

@[simp] theorem sol_succ_n (n : ℕ) : sol a b c d n (n + 1) = 0 := by
  simp [sol, back]

/-- The back substitution recurrence `x i = dq i - cp i * x (i+1)`. -/
theorem sol_rec {n i : ℕ} (hi : i ≤ n) :
    sol a b c d n i = dq a b c d i - cp a b c i * sol a b c d n (i + 1) := by
  unfold sol
  obtain ⟨k, hk⟩ : ∃ k, n + 1 - i = k + 1 := ⟨n - i, by omega⟩
  rw [hk, back, show n - k = i by omega, show n + 1 - (i + 1) = k by omega]

/-- The Thomas algorithm solves the tridiagonal system. -/
theorem sol_solves {n : ℕ} (hp : PivotsNonzero a b c n) : Solves a b c d n (sol a b c d n) := by
  refine ⟨sol_zero n, sol_succ_n n, fun i hi1 hin => ?_⟩
  have hpi := hp i hi1 hin
  -- `x (i-1) = dq (i-1) - cp (i-1) * x i` (for `i = 1` both sides are `0`)
  have h1 : sol a b c d n (i - 1) = dq a b c d (i - 1) - cp a b c (i - 1) * sol a b c d n i := by
    have := sol_rec (a := a) (b := b) (c := c) (d := d) (n := n) (i := i - 1) (by omega)
    rwa [Nat.sub_add_cancel hi1] at this
  have h2 := sol_rec (a := a) (b := b) (c := c) (d := d) hin
  have h3 := piv_mul_cp hpi hi1
  have h4 := piv_mul_dq (d := d) hpi hi1
  simp only [piv] at h3 h4
  rw [h1]
  linear_combination (b i - a i * cp a b c (i - 1)) * h2 + h4 - sol a b c d n (i + 1) * h3

/-- The solution is unique: any solution of the system is the one computed by
the Thomas algorithm. -/
theorem solves_unique {n : ℕ} (hp : PivotsNonzero a b c n) {y : ℕ → ℚ}
    (hy : Solves a b c d n y) : ∀ i, i ≤ n + 1 → y i = sol a b c d n i := by
  obtain ⟨hy0, hyn, hyeq⟩ := hy
  -- Forward: every solution satisfies the back substitution recurrence.
  have fwd : ∀ i, i ≤ n → y i = dq a b c d i - cp a b c i * y (i + 1) := by
    intro i
    induction i with
    | zero => intro _; simp [hy0, dq, cp]
    | succ k ih =>
      intro hk
      have hpk := hp (k + 1) (by omega) hk
      have e := hyeq (k + 1) (by omega) hk
      simp only [Nat.add_sub_cancel] at e
      rw [ih (by omega)] at e
      have h3 := piv_mul_cp hpk (by omega)
      have h4 := piv_mul_dq (d := d) hpk (by omega)
      simp only [piv, Nat.add_sub_cancel] at h3 h4
      apply mul_left_cancel₀ hpk
      simp only [piv, Nat.add_sub_cancel]
      linear_combination e - h4 + y (k + 1 + 1) * h3
  -- Backward: the recurrence with `y (n+1) = 0` determines `y`.
  have bwd : ∀ k, k ≤ n + 1 → y (n + 1 - k) = sol a b c d n (n + 1 - k) := by
    intro k
    induction k with
    | zero => intro _; simp [hyn]
    | succ k ih =>
      intro hk
      rw [fwd _ (by omega), sol_rec (by omega), show n + 1 - (k + 1) + 1 = n + 1 - k by omega,
        ih (by omega)]
  intro i hi
  have := bwd (n + 1 - i) (by omega)
  rwa [show n + 1 - (n + 1 - i) = i by omega] at this

/-- The algorithm only looks at `a i, b i, c i, d i` for `1 ≤ i ≤ n`. -/
theorem sol_congr {n : ℕ} {a' b' c' d' : ℕ → ℚ}
    (ha : ∀ i, 1 ≤ i → i ≤ n → a i = a' i) (hb : ∀ i, 1 ≤ i → i ≤ n → b i = b' i)
    (hc : ∀ i, 1 ≤ i → i ≤ n → c i = c' i) (hd : ∀ i, 1 ≤ i → i ≤ n → d i = d' i) :
    ∀ i, sol a b c d n i = sol a' b' c' d' n i := by
  have hcp : ∀ i, i ≤ n → cp a b c i = cp a' b' c' i := by
    intro i
    induction i with
    | zero => simp [cp]
    | succ k ih =>
      intro hk
      simp only [cp, ih (by omega), ha _ (by omega) hk, hb _ (by omega) hk, hc _ (by omega) hk]
  have hdq : ∀ i, i ≤ n → dq a b c d i = dq a' b' c' d' i := by
    intro i
    induction i with
    | zero => simp [dq]
    | succ k ih =>
      intro hk
      simp only [dq, piv, Nat.add_sub_cancel, ih (by omega), hcp k (by omega),
        ha _ (by omega) hk, hb _ (by omega) hk, hd _ (by omega) hk]
  have hback : ∀ k, back a b c d n k = back a' b' c' d' n k := by
    intro k
    induction k with
    | zero => simp [back]
    | succ k ih =>
      simp only [back, ih, hcp _ (Nat.sub_le n k), hdq _ (Nat.sub_le n k)]
  intro i
  exact hback _

end Tridiag
