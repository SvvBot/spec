/-
  Carried Authority, Part II, §5.5: Theorem 9 (compromise containment), on the relying-party
  model of Sufficiency.lean.

  Build (Lean 4.35, core only):  cd papers && lake build Containment

  Assumption A2 (no key outside the carrier's control is compromised) is relaxed one kind of key
  at a time, and what a compromised key can still do is bounded:
  * Item 1 (`carrier_seal_inert`): a key the relying party recognizes for nothing seals nothing
    the relying party accepts.
  * Item 2 (`witness_compromise`): with witness keys certified for the claims in `C` lying, a
    commit still satisfies S2 for a world that agrees with the truth on every input outside `C`.
    A lying witness can move only the facts it is certified for.
  * Item 3 (`approver_compromise`, `quorum_needs_n_keys`): forged consents never turn DENIED or
    INCOMPLETE into a commit: the rules on the facts escalated, with the gate closed, before any
    consent was counted. And an escalation needing n consents is met by n distinct certified keys,
    so an attacker holding fewer than n of them cannot meet it alone.
  * Item 4 (`sealing_compromise_record_only`): a relying party that takes currency from its own
    record accepts only the artifact whose hash its record holds; a compromised sealing key that
    seals new rules under a recorded identifier authorizes nothing.
  * Item 6 lives in Chain.lean (`statement_authority_from_root`): under NOMOS-SPEC-007 rev. 1.11 a
    key that may seal is never an ancestor of a witness or an approver. Under rev. 1.8-1.10 it
    could be (`sealing_key_mints_statement_keys`), which is why rev. 1.11 exists.
  Item 5 (a root key can do anything within its scope) needs no proof.
-/
import Sufficiency

set_option linter.unusedSectionVars false
set_option linter.deprecated false

namespace CarriedAuthority.Containment
open CarriedAuthority CarriedAuthority.Sufficiency

variable {I V E Key Role Aid H Subj Nonce Rp Dig : Type}
  [DecidableEq I] [DecidableEq Subj] [DecidableEq Role] [DecidableEq Dig]

/-! ## Item 1: the carrier's own keys -/

theorem carrier_seal_inert (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat) (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (hk : ∀ p, ρ.recognized α.artifact.sealKey p = false) : ¬ Accepts Checks.all dig ρ t α := by
  intro h
  have := h.sealed.2 rfl
  rw [hk] at this; cases this

/-! ## S2 from an extension, whoever made it -/

/-- S2 for any world the assembled facts extend: the core of Theorem 7, without A4. -/
theorem s2_of_ext (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat) (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (world : I → Option V)
    (hext : Ext α.artifact.rules.auth (factsOf Checks.all ρ t α) world)
    (h : Accepts Checks.all dig ρ t α) :
    ∀ D', α.artifact.rules.IsDecider world D' →
      ¬ α.artifact.rules.GateFires world D' ∧
      (α.artifact.rules.outcome D' = .allow ∨
        ∃ e, α.artifact.rules.outcome D' = .esc e ∧ Satisfied Checks.all dig ρ α e) := by
  obtain ⟨_, _, _, _, _, ⟨D, hD, hg, hout⟩⟩ := h
  intro D' hD'
  have hc : CanCommit (α.artifact.rules.outcome D) := by
    unfold CanCommit
    rcases hout with ho | ⟨e, ho, _⟩ <;> rw [ho] <;> simp [Out.kind]
  obtain ⟨h1, h2, h3⟩ := Authority.omission_safety hext hD hD' hc (hg rfl)
  refine ⟨h3, ?_⟩
  rcases hout with ho | ⟨e, ho, hs⟩
  · exact Or.inl (h1 ho)
  · rcases h2 e ho with h | h
    · exact Or.inr ⟨e, h, hs⟩
    · exact Or.inl h

/-! ## Item 2: a compromised witness key -/

/-- The world in which the lying witnesses' values replace the truth on `C` and nothing else. -/
def worldWithLies (truth : I → Option V) (C : I → Prop) [DecidablePred C]
    (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat) (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (x : I) : Option V :=
  if C x then factsOf Checks.all ρ t α x else truthOf truth ρ α x

/-- Witness keys certified for claims in `C` may lie; every other certified witness tells the
    truth. A commit still satisfies S2 in a world that agrees with the truth on every input
    outside `C`: a compromised witness moves only the facts it was certified to state. -/
theorem witness_compromise (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (truth : I → Option V) (C : I → Prop) [DecidablePred C]
    (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat) (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (hauth : ∀ x, α.artifact.rules.auth x = true → α.artifact.chan x = .act ∨ α.artifact.chan x = .rp)
    (hcwit : ∀ x, C x → α.artifact.chan x = .wit)
    (hA4 : ∀ τ : Testimony I V Subj Key, ¬ C τ.claim → ρ.recognized τ.key (.claim τ.claim) = true →
      τ.validFrom ≤ t → t < τ.validUntil → truth τ.claim = some τ.value)
    (h : Accepts Checks.all dig ρ t α) :
    (∀ x, ¬ C x → worldWithLies truth C ρ t α x = truthOf truth ρ α x) ∧
    ∀ D', α.artifact.rules.IsDecider (worldWithLies truth C ρ t α) D' →
      ¬ α.artifact.rules.GateFires (worldWithLies truth C ρ t α) D' ∧
      (α.artifact.rules.outcome D' = .allow ∨
        ∃ e, α.artifact.rules.outcome D' = .esc e ∧ Satisfied Checks.all dig ρ α e) := by
  refine ⟨fun x hx => by simp [worldWithLies, hx], s2_of_ext dig ρ t α _ ?_ h⟩
  refine ⟨fun x v hx => ?_, fun x hx => ?_⟩
  · unfold worldWithLies
    by_cases hc : C x
    · simp only [hc, if_true]; exact hx
    · simp only [hc, if_false]
      unfold factsOf at hx; unfold truthOf
      split at hx
      · exact hx
      · exact hx
      · exact hx
      · cases hf : α.testimony.find? (fun τ => validT Checks.all ρ t α τ && τ.claim == x) with
        | none => rw [hf] at hx; cases hx
        | some τ =>
          rw [hf] at hx; simp only [Option.map_some, Option.some.injEq] at hx
          have hp := List.find?_some hf
          simp only [validT, Checks.all, Bool.not_true, Bool.false_or, Bool.and_eq_true,
            decide_eq_true_eq, beq_iff_eq] at hp
          obtain ⟨⟨⟨⟨⟨hr, _⟩, hfrom⟩, huntil⟩, _⟩, hxe⟩ := hp
          rw [← hxe, ← hx]
          exact hA4 τ (by rw [hxe]; exact hc) hr hfrom huntil
  · have hnc : ¬ C x := by
      intro hc
      rcases hauth x hx with h1 | h1 <;> rw [hcwit x hc] at h1 <;> cases h1
    unfold worldWithLies
    simp only [hnc, if_false]
    unfold factsOf truthOf
    rcases hauth x hx with hch | hch <;> simp [hch]

/-! ## Item 3: compromised approver keys -/

/-- Forged consents cannot turn DENIED or INCOMPLETE into a commit: whatever the consents, a
    commit means the rules on the assembled facts allowed or escalated, with the gate closed, and
    on the true facts (honest witnesses) they never refuse. Consents are counted only after. -/
theorem approver_compromise (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (truth : I → Option V) (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat)
    (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (hauth : ∀ x, α.artifact.rules.auth x = true → α.artifact.chan x = .act ∨ α.artifact.chan x = .rp)
    (hA4 : ∀ τ : Testimony I V Subj Key, ρ.recognized τ.key (.claim τ.claim) = true →
      τ.validFrom ≤ t → t < τ.validUntil → truth τ.claim = some τ.value)
    (h : Accepts Checks.all dig ρ t α) :
    ∀ D', α.artifact.rules.IsDecider (truthOf truth ρ α) D' →
      ¬ α.artifact.rules.GateFires (truthOf truth ρ α) D' ∧ (α.artifact.rules.outcome D').kind ≠ .block := by
  intro D' hD'
  obtain ⟨hg, ho⟩ := s2_of_ext dig ρ t α _ (facts_ext truth ρ t α hauth hA4) h D' hD'
  refine ⟨hg, ?_⟩
  rcases ho with ho | ⟨e, ho, _⟩ <;> rw [ho] <;> simp [Out.kind]

/-- An escalation needing n consents is met only by n distinct certified keys that signed this
    Act's digest: an attacker holding a set `K` of approver keys, where no honest holder signed,
    meets it only if `K` has at least n keys. -/
theorem quorum_needs_n_keys (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (ρ : RP I V Aid H Key Role Nonce Rp) (α : Act I V E Aid H Key Role Subj Nonce Rp Dig) (e : E)
    (K : List Key)
    (honest : ∀ c ∈ α.consents, c.approve = true → c.digest = dig α → c.key ∈ K)
    (h : Satisfied Checks.all dig ρ α e) : α.artifact.needCount e ≤ K.length := by
  obtain ⟨ks, hnd, hn, hks⟩ := h
  have hsub : ks ⊆ K := by
    intro k hk
    obtain ⟨_, c, hc, hck, hca, _, hcd⟩ := hks k hk
    simp only [Checks.all, Bool.not_true, Bool.false_or, beq_iff_eq] at hcd
    exact hck ▸ honest c hc hca hcd
  exact Nat.le_trans hn (hnd.length_le_of_subset hsub)

/-! ## Item 4: a compromised sealing key, record-only relying party -/

/-- A relying party that takes currency from its own record accepts only the artifact whose hash
    its record holds for that identifier. If hashes identify artifacts, a compromised sealing key
    that seals different rules under a recorded identifier authorizes nothing. -/
theorem sealing_compromise_record_only (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat) (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (legit : Artifact I V E Aid H Key Role)
    (hrec : ρ.record legit.id = some legit.hash)
    (hhash : ∀ A B : Artifact I V E Aid H Key Role, A.hash = B.hash → A = B)
    (hid : α.artifact.id = legit.id)
    (h : Accepts Checks.all dig ρ t α) : α.artifact = legit := by
  have := h.current rfl
  rw [hid, hrec] at this
  exact hhash _ _ (Option.some.inj this).symm

end CarriedAuthority.Containment

#print axioms CarriedAuthority.Containment.witness_compromise
#print axioms CarriedAuthority.Containment.approver_compromise
#print axioms CarriedAuthority.Containment.quorum_needs_n_keys
#print axioms CarriedAuthority.Containment.sealing_compromise_record_only
#print axioms CarriedAuthority.Containment.carrier_seal_inert
