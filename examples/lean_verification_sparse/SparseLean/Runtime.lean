/-
A small model of the Fortran features used by `sparse.f90`.

This is the runtime library that a future LFortran ASR → Lean backend would
target. Compared to the earlier Poisson prototype, arrays can now have any
element type, so the same primitives cover `integer` and `real(dp)` arrays:

* `real(dp)` is modelled by `ℚ` and `integer` by `ℤ`. Floating-point
  rounding and integer overflow are not modelled.
* A rank-1 array `a(n)` is an `Array α` of size `n`, accessed with Fortran's
  1-based indices through `fget` / `fset`.
* Every array access is bounds checked and throws `FError.outOfBounds`
  otherwise. `error stop` throws `FError.errorStop`. Keeping the two errors
  separate lets us state "never indexes out of bounds" even for a program
  that may still execute `error stop`.
* `do i = lo, hi, step` loops iterate over `frange lo hi step`.

Every primitive that can fail has a `@[spec]` Hoare triple. Its
precondition is exactly the bounds check, so `mvcgen` produces one bounds
goal per array access in a translated procedure.
-/
import Mathlib

open Std.Do

set_option mvcgen.warning false

namespace Fortran

/-- Runtime errors of a Fortran program. -/
inductive FError where
  /-- An array was accessed at index `i`, which is out of bounds. -/
  | outOfBounds (i : ℤ)
  /-- `error stop` was executed. -/
  | errorStop
  deriving Repr, DecidableEq

/-- The Fortran execution monad. -/
abbrev FM := Except FError

variable {α : Type} [Inhabited α]

/-- Allocate `a(n)`. The contents of a fresh Fortran array are undefined; we
model them as `default` (`0` for `ℤ` and `ℚ`). -/
def falloc (n : ℤ) : Array α := Array.replicate n.toNat default

/-- The value `a(i)` (1-based), as a pure function. Only meaningful for
`1 ≤ i ≤ size a`; used in specifications. -/
def fval (a : Array α) (i : ℤ) : α := a[(i - 1).toNat]!

/-- The array `a` after the assignment `a(i) = v`, as a pure function.
Only meaningful for `1 ≤ i ≤ size a`; used in specifications. -/
def fupd (a : Array α) (i : ℤ) (v : α) : Array α := a.set! (i - 1).toNat v

/-- Read `a(i)`, checking bounds. -/
def fget (a : Array α) (i : ℤ) : FM α :=
  if 1 ≤ i ∧ i ≤ a.size then pure (fval a i) else throw (.outOfBounds i)

/-- Write `a(i) = v`, checking bounds. -/
def fset (a : Array α) (i : ℤ) (v : α) : FM (Array α) :=
  if 1 ≤ i ∧ i ≤ a.size then pure (fupd a i v) else throw (.outOfBounds i)

/-- `error stop`. -/
def errorStop : FM Unit := throw .errorStop

/-- The number of iterations of `do i = lo, hi, step` (Fortran 2018, 11.1.7.4.1):
`max(0, (hi - lo + step) / step)` with truncating division. -/
def fcount (lo hi step : ℤ) : ℕ := ((hi - lo + step).tdiv step).toNat

/-- The sequence of values taken by `i` in `do i = lo, hi, step`. -/
def frange (lo hi : ℤ) (step : ℤ := 1) : List ℤ :=
  (List.range (fcount lo hi step)).map (fun k : ℕ => lo + (k : ℤ) * step)

/-! ## Hoare triples for the runtime primitives -/

@[spec] theorem fget_spec (a : Array α) (i : ℤ) :
    ⦃⌜1 ≤ i ∧ i ≤ a.size⌝⦄ fget a i ⦃⇓ r => ⌜r = fval a i⌝⦄ := by
  mintro h
  simp_all [fget]

omit [Inhabited α] in
@[spec] theorem fset_spec (a : Array α) (i : ℤ) (v : α) :
    ⦃⌜1 ≤ i ∧ i ≤ a.size⌝⦄ fset a i v ⦃⇓ r => ⌜r = fupd a i v⌝⦄ := by
  mintro h
  simp_all [fset]

/-- `error stop` establishes the exceptional postcondition. (We provide our own
spec instead of the generic one for `throw`, whose universe parameters
`mvcgen` cannot determine for `Except`.) -/
@[spec] theorem errorStop_spec (Q : PostCond Unit (.except FError .pure)) :
    ⦃Q.2.1 .errorStop⦄ errorStop ⦃Q⦄ := by
  simp [Triple.iff, errorStop]

/-! ## Lemmas about arrays -/

@[simp] theorem size_falloc (n : ℤ) : (falloc n : Array α).size = n.toNat := by
  simp [falloc]

omit [Inhabited α] in
@[simp] theorem size_fupd (a : Array α) (i : ℤ) (v : α) : (fupd a i v).size = a.size := by
  simp [fupd]

theorem fval_fupd {a : Array α} {i j : ℤ} {v : α} (hi : 1 ≤ i ∧ i ≤ a.size) (hj : 1 ≤ j) :
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

/-! ## From Hoare triples to plain statements -/

/-- A total-correctness triple for an `FM` computation means that the
computation succeeds and its result satisfies the postcondition. -/
theorem ok_of_triple {β : Type} {prog : FM β} {Q : β → Prop}
    (h : ⦃⌜True⌝⦄ prog ⦃⇓ r => ⌜Q r⌝⦄) : ∃ r, prog = .ok r ∧ Q r := by
  apply Except.of_wp_eq rfl (fun r => ∃ x, r = .ok x ∧ Q x)
  refine SPred.entails.trans h ?_
  apply (wp prog).mono
  refine ⟨fun a => ?_, ?_⟩
  · simp
  · simp

/-- If the only exception a computation may raise is `error stop`, it never
indexes out of bounds. -/
theorem no_out_of_bounds_of_triple {β : Type} {prog : FM β}
    (h : ⦃⌜True⌝⦄ prog ⦃post⟨fun _ => ⌜True⌝, fun e => ⌜e = .errorStop⌝⟩⦄) :
    ∀ i, prog ≠ .error (.outOfBounds i) := by
  apply Except.of_wp_eq rfl (fun r : FM β => ∀ i : ℤ, r ≠ .error (FError.outOfBounds i))
  refine SPred.entails.trans h ?_
  apply (wp prog).mono
  refine ⟨fun a => ?_, fun e => ?_, trivial⟩
  · simp
  · apply SPred.pure_mono
    rintro rfl i h
    cases h

/-! ## Tactics for the verification conditions -/

open Lean Elab Tactic Meta in
/-- For every loop cursor hypothesis `frange lo hi = pre ++ cur :: suf` in the
context, add the value of the loop variable `cur` and its bounds. -/
elab "frange_facts" : tactic => withMainContext do
  for ldecl in (← getLCtx) do
    if ldecl.isImplementationDetail then continue
    let ty ← instantiateMVars ldecl.type
    let some (_, lhs, _) := ty.eq? | continue
    unless lhs.isAppOf ``frange do continue
    try
      let pf ← mkAppM ``frange_split_up #[ldecl.toExpr]
      let pty ← inferType pf
      liftMetaTactic fun g => do
        let (_, g) ← (← g.assert `hloop pty pf).intro1
        return [g]
    catch _ => pure ()

open Lean Elab Tactic Meta in
/-- Instantiate the integer binders of `e : ∀ x : ℤ, P x → ∀ y : ℤ, ...` at all
terms in `vars`. Every propositional premise must be provable by `omega` in
the current context; instances with an unprovable premise are dropped. The
result is a list of facts without premises. -/
partial def instIntBinders (vars : Array Expr) (e : Expr) : TacticM (Array Expr) := do
  let ty ← instantiateMVars (← inferType e)
  match ty with
  | .forallE _ bty body _ =>
    if ← isDefEq bty (mkConst ``Int) then
      vars.foldlM (fun acc v => return acc ++ (← instIntBinders vars (mkApp e v))) #[]
    else if !body.hasLooseBVars && (← isProp bty) then
      let m ← mkFreshExprMVar bty
      let ok ← try
          let gs ← Tactic.run m.mvarId! (evalTactic (← `(tactic| omega)))
          pure gs.isEmpty
        catch _ => pure false
      if ok then instIntBinders vars (mkApp e (← instantiateMVars m)) else return #[]
    else return #[e]
  | _ => return #[e]

open Lean Meta in
/-- The integer terms used as array indices (`fval a i`) or loop variables in
the local context and the goal. -/
def indexTerms (g : MVarId) : MetaM (Array Expr) := g.withContext do
  let mut terms : Array Expr := #[]
  let mut tys : Array Expr := #[← instantiateMVars (← g.getType)]
  for ldecl in (← getLCtx) do
    if ldecl.isImplementationDetail then continue
    tys := tys.push (← instantiateMVars ldecl.type)
  for ty in tys do
    -- loop variables: `frange lo hi step = pre ++ cur :: suf`
    if let some (_, lhs, rhs) := ty.eq? then
      if lhs.isAppOf ``frange && rhs.isAppOfArity ``HAppend.hAppend 6 then
        let cons := rhs.getArg! 5
        if cons.isAppOfArity ``List.cons 3 then
          terms := terms.push (cons.getArg! 1)
    -- array indices: `fval a i`
    terms := terms ++ collectFval ty
  let mut uniq : Array Expr := #[]
  for t in terms do
    unless uniq.contains t do uniq := uniq.push t
  return uniq
where
  collectFval (e : Expr) : Array Expr :=
    let rec go (e : Expr) (acc : Array Expr) : Array Expr :=
      let acc := if e.isAppOfArity ``fval 4 && !(e.getArg! 3).hasLooseBVars then
        acc.push (e.getArg! 3) else acc
      match e with
      | .app f a => go a (go f acc)
      | .lam _ t b _ => go b (go t acc)
      | .forallE _ t b _ => go b (go t acc)
      | .letE _ t v b _ => go b (go v (go t acc))
      | .mdata _ b => go b acc
      | .proj _ _ b => go b acc
      | _ => acc
    go e #[]

open Lean Elab Tactic Meta in
/-- Instantiate every hypothesis of the form `∀ x : ℤ, ...` at all loop
variables and array indices occurring in the goal (see `indexTerms`),
including integer binders nested behind premises, as in
`∀ i, 1 ≤ i → i ≤ n → ∀ k, ...`. Together with `frange_facts` this turns
facts about "all indices" into linear facts about the indices actually used,
which `omega` can then combine. -/
elab "loop_inst" : tactic => withMainContext do
  let vars ← indexTerms (← getMainGoal)
  if vars.isEmpty then return
  let mut insts : Array Expr := #[]
  for ldecl in (← getLCtx) do
    if ldecl.isImplementationDetail then continue
    let ty ← instantiateMVars ldecl.type
    let .forallE _ bty _ _ := ty | continue
    unless ← isDefEq bty (mkConst ``Int) do continue
    insts := insts ++ (← instIntBinders vars ldecl.toExpr)
  liftMetaTactic fun g => do
    let mut g := g
    for e in insts do
      let (_, g') ← (← g.assert `hinst (← inferType e) e).intro1
      g := g'
    return [g]

open Lean Elab Tactic Meta in
/-- Split every (non-`let`) local variable of a product type, such as the tuple
of mutable variables that `mvcgen` threads through a loop, into its
components. -/
elab "destruct_state" : tactic => do
  for _ in [0:32] do
    let g ← getMainGoal
    let found ← g.withContext do
      for ldecl in (← getLCtx) do
        if ldecl.isImplementationDetail || ldecl.isLet then continue
        let ty ← whnfR (← instantiateMVars ldecl.type)
        if ty.isAppOfArity ``Prod 2 then return some ldecl.fvarId
      return none
    match found with
    | some fv =>
      let gs ← g.cases fv
      replaceMainGoal (gs.map (·.mvarId)).toList
    | none => return

open Lean Meta in
/-- Split a goal `a ∧ b ∧ ...` into its conjuncts. Unlike `constructor` or
`refine ⟨?_, ?_⟩`, this only looks at the syntactic form of the goal, so named
invariants that are *defined* as conjunctions stay intact. -/
partial def splitAndGoals (g : MVarId) : MetaM (List MVarId) := do
  let t ← instantiateMVars (← g.getType)
  if t.isAppOfArity ``And 2 then
    let [g1, g2] ← g.apply (mkConst ``And.intro) | return [g]
    return (← splitAndGoals g1) ++ (← splitAndGoals g2)
  else return [g]

/-- Split a goal `a ∧ b ∧ ...` into its conjuncts (syntactically). -/
elab "split_conj" : tactic => Lean.Elab.Tactic.liftMetaTactic splitAndGoals

/-- Close a verification condition: bounds checks by `omega` (after
`frange_facts` and `loop_inst`), size bookkeeping by `simp_all`. -/
macro "vc_close" : tactic =>
  `(tactic| first
    | omega
    | (simp_all (config := { zetaDelta := true }) [falloc] <;> omega))

/-- The generic first step on the verification conditions produced by
`mvcgen`: split the loop state, add the loop variable facts, and close every
goal that follows from linear arithmetic on the indices, which covers the
bounds checks. Goals that remain (invariant preservation) are left unchanged,
apart from the split state and the loop facts. -/
macro "fortran_vcs" : tactic =>
  `(tactic| (destruct_state; frange_facts; try (loop_inst; vc_close)))

/-- Side conditions of the loop lemmas: hypotheses and linear arithmetic. -/
macro "vc_side" : tactic =>
  `(tactic| first | assumption | omega | (simp only [Array.size_replicate] <;> omega))

end Fortran
