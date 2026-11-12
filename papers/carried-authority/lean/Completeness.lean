/-
  Carried Authority, Part II, §5.4 and §5.6: Theorem 8 (completeness under disclosure) and
  Theorem 10 (reproducibility), on the semantics of CarriedAuthority.lean.

  Build (Lean 4.35, core only):  cd papers && lake build Completeness

  * `decider_exists`, `decider_unique`: for any facts there is exactly one deciding decision, and
    `pick` (one pass over the decisions in order) computes it. So the evaluation is a function.
  * Theorem 8 (`completeness`): if every atom of every decision reads present, in-domain inputs,
    no condition is undecided, the gate cannot fire, and the outcome is the classical one: the
    rules' verdict on those facts. In particular a carrier that discloses every read input
    truthfully obtains exactly the verdict the rules give on the truth (`disclosure_is_truth`).
  * Theorem 10 (`reproducibility`): the outcome and whether the gate fires are functions of the
    authority and the facts alone. A third party holding the record recomputes the same answer.
-/
import CarriedAuthority

set_option linter.unusedSectionVars false
set_option linter.deprecated false

namespace CarriedAuthority.Completeness
open CarriedAuthority CarriedAuthority.K3 CarriedAuthority.Authority

variable {I V E : Type}

/-! ## The deciding decision exists, is unique, and is computable -/

section
variable (A : Authority I V E)

theorem rankGt_trans {i j k : Fin A.n} (h1 : A.RankGt i j) (h2 : A.RankGt j k) : A.RankGt i k := by
  unfold RankGt at *; omega

theorem rankGt_total {i j : Fin A.n} (hne : i ≠ j) : A.RankGt i j ∨ A.RankGt j i := by
  unfold RankGt
  have : i.val ≠ j.val := fun h => hne (Fin.ext h)
  omega

instance (i j : Fin A.n) : Decidable (A.RankGt i j) := by unfold RankGt; infer_instance

/-- One step: keep the best true decision seen so far. -/
def step (F : Facts I V) (acc : Option (Fin A.n)) (i : Fin A.n) : Option (Fin A.n) :=
  if A.val F i = t then
    match acc with
    | none => some i
    | some d => if A.RankGt i d then some i else some d
  else acc

/-- The deciding decision, computed by one pass over the decisions. -/
def pick (F : Facts I V) : Option (Fin A.n) := (List.finRange A.n).foldl (step A F) none

/-- What `acc` is after a prefix `l`: none iff no decision in `l` is true; otherwise a true
    decision in `l` that outranks every other true one in `l`. -/
def Inv (F : Facts I V) (l : List (Fin A.n)) : Option (Fin A.n) → Prop
  | none => ∀ j ∈ l, A.val F j ≠ t
  | some d => d ∈ l ∧ A.val F d = t ∧ ∀ j ∈ l, A.val F j = t → j ≠ d → A.RankGt d j

theorem inv_foldl (F : Facts I V) :
    ∀ (l pre : List (Fin A.n)) (acc : Option (Fin A.n)), (pre ++ l).Nodup → Inv A F pre acc →
      Inv A F (pre ++ l) (l.foldl (step A F) acc)
  | [], pre, acc, _, h => by simpa using h
  | i :: l, pre, acc, hnd, h => by
    simp only [List.foldl]
    have h' : Inv A F (pre ++ [i]) (step A F acc i) := by
      have hi : i ∉ pre := by
        intro hm
        have := (List.nodup_append.mp hnd).2.2 i hm i (List.mem_cons_self ..)
        exact this rfl
      unfold step
      by_cases hv : A.val F i = t
      · rw [if_pos hv]
        cases acc with
        | none =>
          refine ⟨by simp, hv, fun j hj hjt hne => ?_⟩
          simp only [List.mem_append, List.mem_singleton] at hj
          rcases hj with hj | hj
          · exact absurd hjt (h j hj)
          · exact absurd hj hne
        | some d =>
          obtain ⟨hdm, hdt, hbest⟩ := h
          by_cases hr : A.RankGt i d
          · dsimp only; rw [if_pos hr]
            refine ⟨by simp, hv, fun j hj hjt hne => ?_⟩
            simp only [List.mem_append, List.mem_singleton] at hj
            rcases hj with hj | hj
            · by_cases hjd : j = d
              · subst hjd; exact hr
              · exact rankGt_trans A hr (hbest j hj hjt hjd)
            · exact absurd hj hne
          · dsimp only; rw [if_neg hr]
            have hid : i ≠ d := fun e => hi (e ▸ hdm)
            refine ⟨by simp [hdm], hdt, fun j hj hjt hne => ?_⟩
            simp only [List.mem_append, List.mem_singleton] at hj
            rcases hj with hj | hj
            · exact hbest j hj hjt hne
            · subst hj
              rcases rankGt_total A hid with h1 | h1
              · exact absurd h1 hr
              · exact h1
      · rw [if_neg hv]
        cases acc with
        | none =>
          intro j hj
          simp only [List.mem_append, List.mem_singleton] at hj
          rcases hj with hj | hj
          · exact h j hj
          · subst hj; exact hv
        | some d =>
          obtain ⟨hdm, hdt, hbest⟩ := h
          refine ⟨by simp [hdm], hdt, fun j hj hjt hne => ?_⟩
          simp only [List.mem_append, List.mem_singleton] at hj
          rcases hj with hj | hj
          · exact hbest j hj hjt hne
          · subst hj; exact absurd hjt hv
    have := inv_foldl F l (pre ++ [i]) (step A F acc i) (by simpa using hnd) h'
    simpa using this

theorem pick_isDecider (F : Facts I V) : A.IsDecider F (pick A F) := by
  have h := inv_foldl A F (List.finRange A.n) [] none (by simpa using List.nodup_finRange A.n)
    (fun j hj => by cases hj)
  simp only [List.nil_append] at h
  unfold pick
  cases hp : (List.finRange A.n).foldl (step A F) none with
  | none => rw [hp] at h; exact fun j => h j (List.mem_finRange j)
  | some d =>
    rw [hp] at h
    exact ⟨h.2.1, fun j hj hne => h.2.2 j (List.mem_finRange j) hj hne⟩

theorem decider_exists (F : Facts I V) : ∃ D, A.IsDecider F D := ⟨pick A F, pick_isDecider A F⟩

theorem decider_unique {F : Facts I V} {D D' : Option (Fin A.n)}
    (h : A.IsDecider F D) (h' : A.IsDecider F D') : D = D' := by
  cases D with
  | none =>
    cases D' with
    | none => rfl
    | some d' => exact absurd h'.1 (h d')
  | some d =>
    cases D' with
    | none => exact absurd h.1 (h' d)
    | some d' =>
      by_cases he : d = d'
      · rw [he]
      · exact absurd (h.2 d' h'.1 (Ne.symm he)) (rankGt_asymm A (h'.2 d h.1 he))
end

/-! ## Theorem 10: reproducibility -/

/-- The outcome, and whether the gate holds it open, are functions of the authority and the
    facts: any two evaluations of the same authority on the same facts agree. -/
theorem reproducibility (A : Authority I V E) (F : Facts I V) {D D' : Option (Fin A.n)}
    (h : A.IsDecider F D) (h' : A.IsDecider F D') :
    A.outcome D = A.outcome D' ∧ (A.GateFires F D ↔ A.GateFires F D') := by
  rw [decider_unique A h h']; exact ⟨rfl, Iff.rfl⟩

/-! ## Theorem 8: completeness under disclosure -/

/-- An atom whose inputs are all present and in its domain (or `exists x` on a present input, or
    on one whose absence is authoritative). -/
def AtomDecided (auth : I → Bool) (F : Facts I V) : Atom I V → Prop
  | .cmp xs p => ∃ vs, getAll F xs = some vs ∧ p vs ≠ none
  | .ex x => (F x).isSome = true ∨ auth x = true

def CondDecided (auth : I → Bool) (F : Facts I V) : Cond I V → Prop
  | .atom a => AtomDecided auth F a
  | .and c d => CondDecided auth F c ∧ CondDecided auth F d
  | .or c d => CondDecided auth F c ∧ CondDecided auth F d
  | .not c => CondDecided auth F c

theorem atom_not_u {auth : I → Bool} {F : Facts I V} :
    ∀ a : Atom I V, AtomDecided auth F a → evalAtom auth F a ≠ u
  | .cmp xs p, ⟨vs, hg, hp⟩ => by
    simp only [evalAtom, hg]
    cases hpv : p vs with
    | none => exact absurd hpv hp
    | some b => cases b <;> simp [ofBool]
  | .ex x, h => by
    simp only [evalAtom]
    cases hx : F x with
    | some _ => simp
    | none =>
      rcases h with h | h
      · rw [hx] at h; cases h
      · simp [h]

theorem cond_not_u {auth : I → Bool} {F : Facts I V} :
    ∀ c : Cond I V, CondDecided auth F c → evalCond auth F c ≠ u
  | .atom a, h => atom_not_u a h
  | .and c d, ⟨hc, hd⟩ => by
    have h1 := cond_not_u c hc; have h2 := cond_not_u d hd
    simp only [evalCond]
    cases hx : evalCond auth F c <;> cases hy : evalCond auth F d <;> simp_all [K3.and]
  | .or c d, ⟨hc, hd⟩ => by
    have h1 := cond_not_u c hc; have h2 := cond_not_u d hd
    simp only [evalCond]
    cases hx : evalCond auth F c <;> cases hy : evalCond auth F d <;> simp_all [K3.or]
  | .not c, hc => by
    have h1 := cond_not_u c hc
    simp only [evalCond]
    cases hx : evalCond auth F c <;> simp_all [K3.not]

/-- Theorem 8. If every decision's condition reads only present, in-domain inputs, no condition
    is undecided, the gate cannot fire, and the result is the outcome of the unique deciding
    decision on those facts. -/
theorem completeness (A : Authority I V E) (F : Facts I V)
    (hall : ∀ i : Fin A.n, CondDecided A.auth F (A.ds i).cond) :
    (∀ i, A.val F i ≠ u) ∧ ∀ D, A.IsDecider F D → ¬ A.GateFires F D ∧ D = pick A F := by
  have hnu : ∀ i, A.val F i ≠ u := fun i => cond_not_u _ (hall i)
  refine ⟨hnu, fun D hD => ⟨?_, decider_unique A hD (pick_isDecider A F)⟩⟩
  rintro ⟨X, hu, _⟩
  exact hnu X hu

/-- Disclosure is the truth: if the carrier presents every input any decision reads, each with
    its true value, the verdict is exactly the rules' verdict on the true facts. -/
theorem disclosure_is_truth (A : Authority I V E) (F truth : Facts I V)
    (hall : ∀ i : Fin A.n, CondDecided A.auth F (A.ds i).cond)
    (hagree : ∀ i, A.val F i = A.val truth i) :
    pick A F = pick A truth ∧ ¬ A.GateFires F (pick A F) := by
  refine ⟨?_, ((completeness A F hall).2 _ (pick_isDecider A F)).1⟩
  apply decider_unique A (pick_isDecider A F)
  have h := pick_isDecider A truth
  cases hp : pick A truth with
  | none => rw [hp] at h; exact fun j => (hagree j) ▸ h j
  | some d =>
    rw [hp] at h
    exact ⟨(hagree d).trans h.1, fun j hj hne => h.2 j ((hagree j).symm.trans hj) hne⟩

end CarriedAuthority.Completeness

#print axioms CarriedAuthority.Completeness.decider_unique
#print axioms CarriedAuthority.Completeness.pick_isDecider
#print axioms CarriedAuthority.Completeness.completeness
#print axioms CarriedAuthority.Completeness.reproducibility
#print axioms CarriedAuthority.Completeness.disclosure_is_truth
