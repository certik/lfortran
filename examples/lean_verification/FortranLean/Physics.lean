/-
Physics: the translated `solve_poisson` solves the finite difference
discretization of the boundary value problem

    -u''(x) = f(x),   0 < x < 1,   u(0) = u(1) = 0,

exactly (over `ℚ`), and it reproduces the exact solution `u` at the grid
points whenever `u` is a cubic polynomial. Finally, the test in
`program poisson` never reaches `error stop`.
-/
import FortranLean.Refinement

open Std.Do

set_option mvcgen.warning false

namespace Fortran.Poisson

open Tridiag

/-! ## The discrete Poisson problem (pure mathematics) -/

/-- Grid spacing `h = 1/(n+1)`; the grid points are `x_i = i h`, `i = 0, ..., n+1`. -/
def hstep (n : ℕ) : ℚ := 1 / (n + 1)

theorem hstep_pos (n : ℕ) : 0 < hstep n := by
  unfold hstep; positivity

theorem hstep_mul (n : ℕ) : ((n + 1 : ℕ) : ℚ) * hstep n = 1 := by
  unfold hstep; push_cast; field_simp

/-- The Thomas algorithm applied to the Poisson matrix `tridiag(-1, 2, -1)`
with right hand side `h^2 f_i`. -/
def poissonSol (n : ℕ) (f : ℕ → ℚ) : ℕ → ℚ :=
  sol (fun _ => -1) (fun _ => 2) (fun _ => -1) (fun j => hstep n ^ 2 * f j) n

/-- For the Poisson matrix the forward sweep has the closed form
`cp i = -i/(i+1)`. -/
theorem poisson_cp (i : ℕ) : cp (fun _ => -1) (fun _ => 2) (fun _ => -1) i = -(i / (i + 1)) := by
  induction i with
  | zero => simp [cp]
  | succ k ih =>
    have h1 : (k : ℚ) + 1 ≠ 0 := by positivity
    have h2 : (k : ℚ) + 2 ≠ 0 := by positivity
    have e : (2 : ℚ) - -1 * -(k / (k + 1)) = (k + 2) / (k + 1) := by field_simp; ring
    simp only [cp]
    rw [ih, e]
    push_cast
    field_simp
    ring

/-- The pivots are `m_i = (i+1)/i`. -/
theorem poisson_piv {i : ℕ} (hi : 1 ≤ i) :
    piv (fun _ => -1) (fun _ => 2) (fun _ => -1) i = (i + 1) / i := by
  obtain ⟨k, rfl⟩ : ∃ k, i = k + 1 := ⟨i - 1, by omega⟩
  simp only [piv, Nat.add_sub_cancel, poisson_cp]
  push_cast
  field_simp
  ring

/-- No pivot vanishes, so the Thomas algorithm never divides by zero. -/
theorem poisson_pivots_nonzero (n : ℕ) : PivotsNonzero (fun _ => -1) (fun _ => 2) (fun _ => -1) n := by
  intro i hi _
  rw [poisson_piv hi]
  have : (0 : ℚ) < i := by exact_mod_cast hi
  positivity

/-- The central difference `(-u_{i-1} + 2 u_i - u_{i+1}) / h^2`. -/
def laplacian (n : ℕ) (u : ℕ → ℚ) (i : ℕ) : ℚ :=
  (-u (i - 1) + 2 * u i - u (i + 1)) / hstep n ^ 2

/-- `u` solves the discrete Poisson problem `-Δ_h u = f`, `u_0 = u_{n+1} = 0`. -/
def SolvesPoisson (n : ℕ) (f u : ℕ → ℚ) : Prop :=
  u 0 = 0 ∧ u (n + 1) = 0 ∧ ∀ i, 1 ≤ i → i ≤ n → laplacian n u i = f i

theorem solvesPoisson_iff (n : ℕ) (f u : ℕ → ℚ) :
    SolvesPoisson n f u ↔
      Solves (fun _ => -1) (fun _ => 2) (fun _ => -1) (fun j => hstep n ^ 2 * f j) n u := by
  have hh : hstep n ^ 2 ≠ 0 := (pow_pos (hstep_pos n) 2).ne'
  unfold SolvesPoisson Solves laplacian
  refine and_congr_right fun _ => and_congr_right fun _ => forall_congr' fun i =>
    imp_congr_right fun _ => imp_congr_right fun _ => ?_
  rw [div_eq_iff hh]
  constructor <;> intro h <;> linear_combination h

/-- **The computed solution solves the discrete Poisson equation.** -/
theorem poissonSol_solves (n : ℕ) (f : ℕ → ℚ) : SolvesPoisson n f (poissonSol n f) :=
  (solvesPoisson_iff n f _).2 (sol_solves (poisson_pivots_nonzero n))

/-- **The discrete solution is unique.** -/
theorem poissonSol_unique (n : ℕ) (f u : ℕ → ℚ) (hu : SolvesPoisson n f u) :
    ∀ i, i ≤ n + 1 → u i = poissonSol n f i :=
  solves_unique (poisson_pivots_nonzero n) ((solvesPoisson_iff n f u).1 hu)

/-! ## Consistency: exactness for cubic polynomials -/

/-- A cubic polynomial `p0 + p1 x + p2 x^2 + p3 x^3`. -/
def cubic (p0 p1 p2 p3 x : ℚ) : ℚ := p0 + p1 * x + p2 * x ^ 2 + p3 * x ^ 3

/-- Its second derivative `2 p2 + 6 p3 x`. -/
def cubic'' (p2 p3 x : ℚ) : ℚ := 2 * p2 + 6 * p3 * x

/-- The central difference is exact for cubics. -/
theorem central_difference_cubic (p0 p1 p2 p3 x h : ℚ) (hh : h ≠ 0) :
    (-cubic p0 p1 p2 p3 (x - h) + 2 * cubic p0 p1 p2 p3 x - cubic p0 p1 p2 p3 (x + h)) / h ^ 2 =
      -cubic'' p2 p3 x := by
  unfold cubic cubic''
  field_simp
  ring

/-- **If the exact solution is a cubic, the discrete solution equals it at
every grid point** (no discretization error). -/
theorem poissonSol_cubic (n : ℕ) (p0 p1 p2 p3 : ℚ) (f : ℕ → ℚ)
    (h0 : cubic p0 p1 p2 p3 0 = 0) (h1 : cubic p0 p1 p2 p3 1 = 0)
    (hf : ∀ i, 1 ≤ i → i ≤ n → f i = -cubic'' p2 p3 (i * hstep n)) :
    ∀ i, i ≤ n + 1 → poissonSol n f i = cubic p0 p1 p2 p3 (i * hstep n) := by
  intro i hi
  refine (poissonSol_unique n f (fun j => cubic p0 p1 p2 p3 (j * hstep n)) ⟨?_, ?_, ?_⟩ i hi).symm
  · simpa using h0
  · rw [← hstep_mul n] at h1; exact h1
  · intro j hj1 hjn
    have e1 : ((j - 1 : ℕ) : ℚ) * hstep n = j * hstep n - hstep n := by
      push_cast [Nat.cast_sub hj1]; ring
    have e2 : ((j + 1 : ℕ) : ℚ) * hstep n = j * hstep n + hstep n := by
      push_cast; ring
    rw [hf j hj1 hjn, ← central_difference_cubic p0 p1 p2 p3 _ _ (hstep_pos n).ne']
    simp only [laplacian, e1, e2]

/-! ## Refinement for `solve_poisson` -/

section
variable {n : ℕ} {f : Array ℚ}

/-- Assembly loop invariant: rows `1..k` of the system have been filled in. -/
def AsmVals (h : ℚ) (f a b c d : Array ℚ) (k : ℕ) : Prop :=
  ∀ j : ℕ, 1 ≤ j → j ≤ k →
    fval a j = -1 ∧ fval b j = 2 ∧ fval c j = -1 ∧ fval d j = h ^ 2 * fval f j

theorem asm_init (h : ℚ) (f a b c d : Array ℚ) : AsmVals h f a b c d 0 :=
  fun _ _ _ => by omega

theorem asm_step {h v : ℚ} {a b c d : Array ℚ} {k : ℕ} {i : ℤ} (hi : i = k + 1)
    (ha : a.size = n) (hb : b.size = n) (hc : c.size = n) (hd : d.size = n) (hkn : k + 1 ≤ n)
    (hv : AsmVals h f a b c d k) (hvd : v = h ^ 2 * fval f i) :
    AsmVals h f (fupd a i (-1)) (fupd b i 2) (fupd c i (-1)) (fupd d i v) (k + 1) := by
  intro j hj1 hj2
  rw [fval_fupd (by omega) (by omega), fval_fupd (by omega) (by omega),
    fval_fupd (by omega) (by omega), fval_fupd (by omega) (by omega)]
  split_ifs with hji
  · subst hji; simp [hvd]
  · exact hv j hj1 (by omega)

theorem asm_final {h : ℚ} {a b c d : Array ℚ} {k : ℕ} (i : ℕ) (hv : AsmVals h f a b c d k)
    (hk : n ≤ k) (hh : h = hstep n) :
    sol (F a) (F b) (F c) (F d) n i = poissonSol n (F f) i := by
  rw [poissonSol]
  apply sol_congr <;> intro j hj1 hj2 <;> have := hv j hj1 (by omega) <;> simp_all [F]

end

/-- **Refinement theorem for `solve_poisson`.** -/
theorem solvePoisson_correct (n : ℕ) (f : Array ℚ) (hn : 1 ≤ n) (hf : f.size = n) :
    ⦃⌜True⌝⦄ solvePoisson n f
    ⦃⇓ u => ⌜u.size = n ∧ ∀ i : ℕ, 1 ≤ i → i ≤ n → fval u i = poissonSol n (F f) i⌝⦄ := by
  mvcgen [solvePoisson]
  invariants
  · ⇓⟨xs, a, b, c, d⟩ => ⌜a.size = n ∧ b.size = n ∧ c.size = n ∧ d.size = n ∧
      AsmVals (1 / ((n + 1 : ℤ) : ℚ)) f a b c d xs.pos⌝
  all_goals frange_facts
  all_goals simp_all (config := { zetaDelta := true }) [falloc]
  all_goals try casesm* _ ∧ _
  all_goals first
    | omega
    | exact asm_init _ _ _ _ _ _
    | (apply asm_step <;> first | vc_side | simp [inv_pow])
    | (intros; apply asm_final <;> first | vc_side | simp [hstep])

/-- `poissonSol` for an `integer` size `n`. -/
def poissonSolInt (n : ℤ) (f : ℕ → ℚ) : ℕ → ℚ := poissonSol n.toNat f

/-- `solvePoisson_correct` as a `@[spec]` triple (for an `integer` argument `n`,
as at call sites in Fortran code). -/
@[spec] theorem solvePoisson_spec (n : ℤ) (f : Array ℚ) :
    ⦃⌜1 ≤ n ∧ f.size = n⌝⦄ solvePoisson n f
    ⦃⇓ u => ⌜u.size = n ∧ ∀ i : ℕ, 1 ≤ i → i ≤ n → fval u i = poissonSolInt n (F f) i⌝⦄ := by
  mintro h
  mpure h
  obtain ⟨n, rfl⟩ : ∃ m : ℕ, n = m := ⟨n.toNat, by omega⟩
  mspec (solvePoisson_correct n f (by omega) (by omega))
  mrename_i h'
  mpure h'
  mpure_intro
  simp only [poissonSolInt, Int.toNat_natCast]
  exact ⟨by omega, fun i hi1 hi2 => h'.2 i hi1 (by omega)⟩

/-! ## Main theorems about the Fortran code -/

/-- **`solve_poisson` solves the discrete Poisson problem.** For every
`n ≥ 1` and right hand side `f(1:n)`, the Fortran subroutine terminates
without any out-of-bounds access and returns `u(1:n)` such that, with
`u(0) = u(n+1) = 0`,

    (-u(i-1) + 2 u(i) - u(i+1)) / h^2 = f(i),   i = 1, ..., n,

and `u` is the only such vector. -/
theorem solvePoisson_solves (n : ℕ) (f : Array ℚ) (hn : 1 ≤ n) (hf : f.size = n) :
    ∃ u, solvePoisson n f = .ok u ∧ u.size = n ∧
      let U : ℕ → ℚ := fun i => if 1 ≤ i ∧ i ≤ n then fval u i else 0
      SolvesPoisson n (F f) U ∧
      ∀ V : ℕ → ℚ, SolvesPoisson n (F f) V → ∀ i, i ≤ n + 1 → V i = U i := by
  obtain ⟨u, hu, hsize, hval⟩ := ok_of_triple (solvePoisson_correct n f hn hf)
  have hU : ∀ i, i ≤ n + 1 →
      (if 1 ≤ i ∧ i ≤ n then fval u i else 0) = poissonSol n (F f) i := by
    intro i hi
    split_ifs with h
    · exact hval i h.1 h.2
    · rcases Nat.lt_or_ge i 1 with h' | h'
      · obtain rfl : i = 0 := by omega
        exact (poissonSol_solves n (F f)).1.symm
      · obtain rfl : i = n + 1 := by omega
        exact (poissonSol_solves n (F f)).2.1.symm
  refine ⟨u, hu, hsize, ?_, ?_⟩
  · obtain ⟨h0, h1, heq⟩ := poissonSol_solves n (F f)
    refine ⟨by simp, by simp, fun i hi1 hin => ?_⟩
    rw [← heq i hi1 hin]
    simp only [laplacian, hU (i - 1) (by omega), hU i (by omega), hU (i + 1) (by omega)]
  · intro V hV i hi
    rw [poissonSol_unique n _ V hV i hi]
    exact (hU i hi).symm

/-- The cubic `p0 + p1 x + p2 x^2 + p3 x^3` as a real function. -/
noncomputable def cubicR (p0 p1 p2 p3 : ℚ) (x : ℝ) : ℝ :=
  p0 + p1 * x + p2 * x ^ 2 + p3 * x ^ 3

theorem hasDerivAt_cubicR (p0 p1 p2 p3 : ℚ) (x : ℝ) :
    HasDerivAt (cubicR p0 p1 p2 p3) (p1 + 2 * p2 * x + 3 * p3 * x ^ 2) x := by
  have h := ((((hasDerivAt_id' x).const_mul (p1 : ℝ)).const_add (p0 : ℝ)).add
    ((hasDerivAt_pow 2 x).const_mul (p2 : ℝ))).add ((hasDerivAt_pow 3 x).const_mul (p3 : ℝ))
  have e : cubicR p0 p1 p2 p3 =
      ((fun y => (p0 : ℝ) + p1 * y) + fun y => (p2 : ℝ) * y ^ 2) + fun y => (p3 : ℝ) * y ^ 3 := by
    funext y; simp [cubicR]
  rw [e]
  refine h.congr_deriv ?_
  norm_num
  ring

/-- The derivative of a cubic is the cubic with coefficients `(p1, 2 p2, 3 p3, 0)`. -/
theorem deriv_cubicR (p0 p1 p2 p3 : ℚ) :
    deriv (cubicR p0 p1 p2 p3) = cubicR p1 (2 * p2) (3 * p3) 0 := by
  funext x
  rw [(hasDerivAt_cubicR p0 p1 p2 p3 x).deriv]
  simp only [cubicR]; push_cast; ring

theorem deriv_deriv_cubicR (p0 p1 p2 p3 : ℚ) (x : ℝ) :
    deriv (deriv (cubicR p0 p1 p2 p3)) x = 2 * p2 + 6 * p3 * x := by
  rw [deriv_cubicR, deriv_cubicR]
  simp only [cubicR]; push_cast; ring

/-- **The Fortran code reproduces the exact solution of the continuous
problem.** Let `u : ℝ → ℝ` be a cubic polynomial (with rational
coefficients) solving the boundary value problem

    -u''(x) = F(x),   u(0) = u(1) = 0,

where `u''` is the second derivative from Mathlib's real analysis. If the
Fortran subroutine `solve_poisson` is called with `f(i) = F(x_i)`, then it
returns `u(i) = u(x_i)` exactly at every grid point `x_i = i/(n+1)`. -/
theorem solvePoisson_exact_cubic (n : ℕ) (hn : 1 ≤ n) (p0 p1 p2 p3 : ℚ) (F' : ℝ → ℝ)
    (hbvp : ∀ x, -deriv (deriv (cubicR p0 p1 p2 p3)) x = F' x)
    (hbc0 : cubicR p0 p1 p2 p3 0 = 0) (hbc1 : cubicR p0 p1 p2 p3 1 = 0)
    (f : Array ℚ) (hf : f.size = n)
    (hfF : ∀ i : ℕ, 1 ≤ i → i ≤ n → (fval f i : ℝ) = F' (i / (n + 1))) :
    ∃ u, solvePoisson n f = .ok u ∧ u.size = n ∧
      ∀ i : ℕ, 1 ≤ i → i ≤ n → (fval u i : ℝ) = cubicR p0 p1 p2 p3 (i / (n + 1)) := by
  obtain ⟨u, hu, hsize, hval⟩ := ok_of_triple (solvePoisson_correct n f hn hf)
  have hcast : ∀ x : ℚ, cubicR p0 p1 p2 p3 x = (cubic p0 p1 p2 p3 x : ℝ) := by
    intro x; simp [cubicR, cubic]
  have h0 : cubic p0 p1 p2 p3 0 = 0 := by
    have := hcast 0; rw [Rat.cast_zero, hbc0] at this; exact_mod_cast this.symm
  have h1 : cubic p0 p1 p2 p3 1 = 0 := by
    have := hcast 1; rw [Rat.cast_one, hbc1] at this; exact_mod_cast this.symm
  have hx : ∀ i : ℕ, ((i * hstep n : ℚ) : ℝ) = i / (n + 1) := by
    intro i; simp [hstep, div_eq_mul_inv]
  have hfq : ∀ i, 1 ≤ i → i ≤ n → F f i = -cubic'' p2 p3 (i * hstep n) := by
    intro i hi1 hi2
    have := hfF i hi1 hi2
    rw [← hbvp, deriv_deriv_cubicR, ← hx] at this
    unfold F cubic''
    exact_mod_cast this
  refine ⟨u, hu, hsize, fun i hi1 hi2 => ?_⟩
  rw [hval i hi1 hi2, poissonSol_cubic n p0 p1 p2 p3 _ h0 h1 hfq i (by omega), ← hx, hcast]

/-! ## `program poisson` -/

/-- Loop invariant of the first loop of `program poisson`: `f(1:k)` holds `6 x_j`. -/
def MainVals (f : Array ℚ) (k : ℕ) : Prop :=
  ∀ j : ℕ, 1 ≤ j → j ≤ k → fval f j = 6 * (j * 10⁻¹)

theorem main_init (f : Array ℚ) : MainVals f 0 := fun _ _ _ => by omega

theorem main_step {f : Array ℚ} {k : ℕ} {i : ℤ} {v : ℚ} (hi : i = k + 1) (hs : f.size = 9)
    (hk : k + 1 ≤ 9) (h : MainVals f k) (hv : v = 6 * (((k + 1 : ℕ) : ℚ) * 10⁻¹)) :
    MainVals (fupd f i v) (k + 1) := by
  intro j hj1 hj2
  rw [fval_fupd (by omega) (by omega)]
  split_ifs with hji
  · obtain rfl : j = k + 1 := by omega
    exact hv
  · exact h j hj1 (by omega)

/-- The exact solution `x - x^3` of `-u'' = 6x`, `u(0) = u(1) = 0`, is
reproduced at the grid points of `program poisson` (`n = 9`, `h = 1/10`). -/
theorem main_sol {f : Array ℚ} {K : ℕ} (hf : MainVals f K) (hK : 9 ≤ K) (i : ℕ) (hi : i ≤ 10) :
    poissonSolInt 9 (F f) i = i * 10⁻¹ - (i * 10⁻¹) ^ 3 := by
  rw [poissonSolInt, show (9 : ℤ).toNat = 9 from rfl]
  have hh : hstep 9 = 10⁻¹ := by norm_num [hstep]
  rw [poissonSol_cubic 9 0 1 0 (-1) (F f) (by norm_num [cubic]) (by norm_num [cubic]) ?_ i hi]
  · simp [cubic, hh]; ring
  · intro j hj1 hj2
    rw [F, hf j hj1 (by omega), cubic'', hh]
    ring

theorem main_err {u f : Array ℚ} {K k : ℕ} {i : ℤ} {x : ℚ} (hi : i = k + 1) (hk : k + 1 ≤ 9)
    (hu : ∀ i : ℕ, 1 ≤ i → i ≤ 9 → fval u i = poissonSolInt 9 (F f) i)
    (hf : MainVals f K) (hK : 9 ≤ K) (hx : x = ((k + 1 : ℕ) : ℚ) * 10⁻¹) :
    fval u i - (x - x ^ 3) = 0 := by
  subst hi hx
  rw [show (k : ℤ) + 1 = ((k + 1 : ℕ) : ℤ) by push_cast; ring, hu (k + 1) (by omega) hk,
    main_sol hf hK (k + 1) (by omega)]
  ring

theorem main_length : (frange 1 9).length = 9 := by simp [fcount]

/-- **The test in `program poisson` passes**: it runs without out-of-bounds
accesses and never reaches `error stop` (in exact arithmetic the error is
exactly zero). -/
theorem main_correct : ⦃⌜True⌝⦄ main ⦃⇓ _ => ⌜True⌝⦄ := by
  mvcgen [main]
  invariants
  · ⇓⟨xs, f, _⟩ => ⌜f.size = 9 ∧ MainVals f xs.prefix.length⌝
  · ⇓⟨xs, _, err⟩ => ⌜err = 0⌝
  all_goals frange_facts
  all_goals try simp_all (config := { zetaDelta := true }) [falloc, -length_frange, main_length]
  all_goals try casesm* _ ∧ _
  all_goals first
    | omega
    | exact main_init _
    | (apply main_step <;> first | vc_side | (push_cast; ring))
    | (apply main_err <;> first | vc_side | (push_cast; ring))
    | (norm_num at *)

/-- `program poisson` runs to completion. -/
theorem main_ok : main = .ok () := by
  obtain ⟨_, h, -⟩ := ok_of_triple main_correct
  exact h

end Fortran.Poisson
