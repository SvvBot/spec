/-
  Parts II and III, end to end: a relying party that resolves the applicable law (Part III,
  Resolution.lean) and verifies the Act under every member with Part II's verifier
  (Sufficiency.lean) commits only when every authority its pinned registrars state for the act
  is legitimate and current, and its rules, on the true facts, permit the act or the right people
  approved exactly it.

  This closes the composition gap both files stated: Resolution.lean took each member's verdict as
  given; here that verdict is Part II's, and Part II's sufficiency theorem is applied to it.

  Build (Lean 4.35, core only):  cd papers && lake build Composition
-/
import Resolution
import Sufficiency

set_option linter.deprecated false

namespace Composition
open CarriedAuthority.Sufficiency

variable {I V E Key Role Aid H Subj Nonce Rp Dig Reg Auth F : Type}
  [DecidableEq I] [DecidableEq Subj] [DecidableEq Role] [DecidableEq Dig]
  [DecidableEq Auth] [DecidableEq Reg]

open Classical in
/-- Each member's verdict, as Part II's relying party computes it on the Act carried for that
    authority: AUTHORIZED exactly when the verification of SPEC-008 §6 accepts. -/
noncomputable def partII (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat)
    (actFor : Auth → Act I V E Aid H Key Role Subj Nonce Rp Dig) (A : Auth) (_ : F) :
    Resolution.Verdict Unit :=
  if Accepts Checks.all dig ρ t (actFor A) then .authorized else .denied

theorem end_to_end
    (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (apply : Action I V Subj → (I → Option V) → (I → Option V))
    (truth : I → Option V) (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat)
    (actFor : Auth → Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (w : Resolution.World Reg Auth) (R : List Reg) (α : Resolution.Act Auth F)
    -- Part II's assumptions, for every authority's Act
    (hauth : ∀ A x, (actFor A).artifact.rules.auth x = true →
      (actFor A).artifact.chan x = .act ∨ (actFor A).artifact.chan x = .rp)
    (hA4 : ∀ τ : Testimony I V Subj Key, ρ.recognized τ.key (.claim τ.claim) = true →
      τ.validFrom ≤ t → t < τ.validUntil → truth τ.claim = some τ.value)
    (hdig : ∀ A, ∀ β : Act I V E Aid H Key Role Subj Nonce Rp Dig,
      dig β = dig (actFor A) → β.core = (actFor A).core)
    (h : Resolution.Verdict.Commits (fun _ => False)
      (Resolution.decideWith Resolution.Checks.full t (partII dig ρ t actFor) w R α)) :
    -- every in-force, in-scope claim of every reached registrar names a member ...
    ∃ S, Resolution.resolve Resolution.Checks.full t w R = .resolved S ∧
      (∀ x, x ∈ Resolution.allCands Resolution.Checks.full t w R → x.2.auth ∈ S) ∧
      -- ... and every member passed Part II: S1 legitimate and current, S2 the true facts do
      -- not refuse, S4 here and once, S5 exactly this change
      ∀ A ∈ S, Legit ρ (actFor A).artifact ∧
        (∀ D', (actFor A).artifact.rules.IsDecider (truthOf truth ρ (actFor A)) D' →
          ¬ (actFor A).artifact.rules.GateFires (truthOf truth ρ (actFor A)) D' ∧
          ((actFor A).artifact.rules.outcome D' = .allow ∨
            ∃ e, (actFor A).artifact.rules.outcome D' = .esc e ∧
              Satisfied Checks.all dig ρ (actFor A) e)) ∧
        ((actFor A).audience = ρ.id ∧ ¬ Accepts Checks.all dig (commit apply ρ (actFor A)) t (actFor A)) ∧
        (commit apply ρ (actFor A)).state = apply (actFor A).action ρ.state := by
  obtain ⟨S, hS, _, _, hall, _, hmem⟩ := Resolution.sufficiency _ t _ _ w R α h
  refine ⟨S, hS, hall, fun A hA => ?_⟩
  have hc := hmem A hA
  have hacc : Accepts Checks.all dig ρ t (actFor A) := by
    unfold partII at hc
    by_cases hp : Accepts Checks.all dig ρ t (actFor A)
    · exact hp
    · rw [if_neg hp] at hc; exact absurd hc (by simp [Resolution.Verdict.Commits])
  obtain ⟨s1, s2, _, s4, s5⟩ :=
    sufficiency dig apply truth ρ t (actFor A) (hauth A) hA4 (hdig A) hacc
  exact ⟨s1, s2, s4, s5⟩

end Composition

#print axioms Composition.end_to_end
