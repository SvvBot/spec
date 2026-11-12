/-
  Carried Authority, Part II, §5.3: Theorem 7 (sufficiency) mechanized, and the necessity of each
  obligation (Theorems 1–6) as counterexamples, on top of Proposition 1 (CarriedAuthority.lean).

  Build (Lean 4.35, core only):  cd papers && lake build Sufficiency

  The relying party's verification (SPEC-008 §6) is modelled as a relation `Accepts`: audience,
  window, nonce, issuer chain and currency, testimony (chain, claim scope, subject, window),
  channels, three-valued evaluation with the 0.5.0 gate, and consent counting over the binding
  digest. The commit applies exactly the action and records the nonce (C4).

  What is abstract, and stated as hypotheses rather than proved:
  * Chain resolution (SPEC-007) is the relying party's function `recognized key purpose`; that it
    is order-independent, never amplifies and honours revocation are Propositions 2–4, tested by
    the SPEC-007 vectors, not modelled here.
  * A1 (unforgeable signatures) and A2 (no compromised key outside the carrier's control) are
    folded into what `recognized` and a valid seal mean. A4 (certified witnesses state true values
    for their window) is the hypothesis `hA4`. Collision resistance of the binding digest is
    `hdig`.
  * Value types (C2.1's "declared type") are not modelled: an out-of-domain value already reads
    as undecided in the evaluator.
-/
import CarriedAuthority

set_option linter.unusedSectionVars false

namespace CarriedAuthority.Sufficiency
open CarriedAuthority

inductive Chan | act | wit | rp | pre
  deriving DecidableEq

inductive Purpose (Aid Role I : Type) where
  | seal (a : Aid)
  | claim (x : I)
  | consent (r : Role)

variable {I V E Key Role Aid H Subj Nonce Rp Dig : Type}
  [DecidableEq I] [DecidableEq Subj] [DecidableEq Role] [DecidableEq Dig]

structure Testimony (I V Subj Key : Type) where
  claim : I
  value : V
  subject : Subj
  validFrom : Nat
  validUntil : Nat
  key : Key

structure Consent (Role Dig Key : Type) where
  digest : Dig
  role : Role
  approve : Bool
  key : Key

/-- A sealed authority as the Act carries it: its rules (Part II §3.3), data contract, and the
    consent requirement of each escalation. -/
structure Artifact (I V E Aid H Key Role : Type) where
  id : Aid
  rules : Authority I V E
  hash : H
  sealKey : Key
  sealValid : Bool
  chan : I → Chan
  needRole : E → Role
  needCount : E → Nat

structure Action (I V Subj : Type) where
  subject : Subj
  params : I → Option V

structure Act (I V E Aid H Key Role Subj Nonce Rp Dig : Type) where
  action : Action I V Subj
  artifact : Artifact I V E Aid H Key Role
  testimony : List (Testimony I V Subj Key)
  consents : List (Consent Role Dig Key)
  audience : Rp
  nonce : Nonce
  nbf : Nat
  exp : Nat
  carrierFacts : I → Option V

/-- What a consent signs (SPEC-008 binding digest): everything but the consents themselves. -/
structure Core (I V Subj H Key Rp Nonce : Type) where
  action : Action I V Subj
  hash : H
  testimony : List (Testimony I V Subj Key)
  audience : Rp
  nonce : Nonce
  nbf : Nat
  exp : Nat

def Act.core (α : Act I V E Aid H Key Role Subj Nonce Rp Dig) : Core I V Subj H Key Rp Nonce :=
  ⟨α.action, α.artifact.hash, α.testimony, α.audience, α.nonce, α.nbf, α.exp⟩

/-- The relying party: its identity, chain resolution, record of versions in force, nonce
    ledger and state σ. -/
structure RP (I V Aid H Key Role Nonce Rp : Type) where
  id : Rp
  recognized : Key → Purpose Aid Role I → Bool
  record : Aid → Option H
  seen : List Nonce
  state : I → Option V

/-- Which obligations the verifier enforces (all, for the theorem; one dropped, for necessity). -/
structure Checks where
  recognition : Bool := true   -- C1.1
  currency : Bool := true      -- C1.2
  provenance : Bool := true    -- C2.1
  gate : Bool := true          -- C2.2
  binding : Bool := true       -- C3
  nonce : Bool := true         -- C4 (once)

def Checks.all : Checks := {}

section
variable (ck : Checks) (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
  (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat) (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)

/-- Step 6 and C2.1: a statement counts only from a key certified for that claim, about this
    subject, inside its window, for an input the authority declares witnessed. -/
def validT (τ : Testimony I V Subj Key) : Bool :=
  (!ck.provenance || ρ.recognized τ.key (.claim τ.claim)) &&
  τ.subject == α.action.subject && decide (τ.validFrom ≤ t) && decide (t < τ.validUntil) &&
  α.artifact.chan τ.claim == .wit

/-- F_α: each input from its declared channel only. -/
def factsOf (x : I) : Option V :=
  match α.artifact.chan x with
  | .act => α.action.params x
  | .rp => ρ.state x
  | .pre => α.carrierFacts x
  | .wit => (α.testimony.find? (fun τ => validT ck ρ t α τ && τ.claim == x)).map (·.value)

/-- Step 9: n distinct keys certified for the role signed this Act's digest. -/
def Satisfied (e : E) : Prop :=
  ∃ ks : List Key, ks.Nodup ∧ α.artifact.needCount e ≤ ks.length ∧
    ∀ k ∈ ks, ρ.recognized k (.consent (α.artifact.needRole e)) = true ∧
      ∃ c ∈ α.consents, c.key = k ∧ c.approve = true ∧ c.role = α.artifact.needRole e ∧
        (!ck.binding || c.digest == dig α) = true

/-- The relying party's verdict is AUTHORIZED (SPEC-008 §6, steps 2–9). -/
structure Accepts : Prop where
  audience : α.audience = ρ.id
  window : α.nbf ≤ t ∧ t < α.exp
  fresh : ck.nonce = true → α.nonce ∉ ρ.seen
  sealed : α.artifact.sealValid = true ∧
    (ck.recognition = true → ρ.recognized α.artifact.sealKey (.seal α.artifact.id) = true)
  current : ck.currency = true → ρ.record α.artifact.id = some α.artifact.hash
  verdict : ∃ D, α.artifact.rules.IsDecider (factsOf ck ρ t α) D ∧
    (ck.gate = true → ¬ α.artifact.rules.GateFires (factsOf ck ρ t α) D) ∧
    (α.artifact.rules.outcome D = .allow ∨
      ∃ e, α.artifact.rules.outcome D = .esc e ∧ Satisfied ck dig ρ α e)
end

/-- The commit (C4): apply exactly the action, record the nonce, atomically. -/
def commit (apply : Action I V Subj → (I → Option V) → (I → Option V))
    (ρ : RP I V Aid H Key Role Nonce Rp) (α : Act I V E Aid H Key Role Subj Nonce Rp Dig) :
    RP I V Aid H Key Role Nonce Rp :=
  { ρ with seen := α.nonce :: ρ.seen, state := apply α.action ρ.state }

/-- F⋆_t ⊕ a: the true facts, extended with the action's own parameters; relying-party inputs are
    σ (re-read at commit, C4); carrier inputs are taken as presented (their declaration is the
    institution's acceptance of the carrier's word, Part II §3.6). -/
def truthOf (truth : I → Option V) (ρ : RP I V Aid H Key Role Nonce Rp)
    (α : Act I V E Aid H Key Role Subj Nonce Rp Dig) (x : I) : Option V :=
  match α.artifact.chan x with
  | .act => α.action.params x
  | .rp => ρ.state x
  | .pre => α.carrierFacts x
  | .wit => truth x

/-- Cur_ρ(t): sealed by a key the pinned root recognises for this authority, and the version the
    relying party's record holds in force. -/
def Legit (ρ : RP I V Aid H Key Role Nonce Rp) (A : Artifact I V E Aid H Key Role) : Prop :=
  A.sealValid = true ∧ ρ.recognized A.sealKey (.seal A.id) = true ∧ ρ.record A.id = some A.hash

/-! ## The facts the relying party assembles extend to the truth -/

theorem facts_ext (truth : I → Option V) (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat)
    (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (hauth : ∀ x, α.artifact.rules.auth x = true → α.artifact.chan x = .act ∨ α.artifact.chan x = .rp)
    (hA4 : ∀ τ : Testimony I V Subj Key, ρ.recognized τ.key (.claim τ.claim) = true →
      τ.validFrom ≤ t → t < τ.validUntil → truth τ.claim = some τ.value) :
    Ext α.artifact.rules.auth (factsOf Checks.all ρ t α) (truthOf truth ρ α) where
  keep := by
    intro x v h
    unfold factsOf at h; unfold truthOf
    split at h
    · exact h
    · exact h
    · exact h
    · cases hf : α.testimony.find? (fun τ => validT Checks.all ρ t α τ && τ.claim == x) with
      | none => rw [hf] at h; cases h
      | some τ =>
        rw [hf] at h; simp only [Option.map_some, Option.some.injEq] at h
        have hp := List.find?_some hf
        simp only [validT, Checks.all, Bool.not_true, Bool.false_or, Bool.and_eq_true,
          decide_eq_true_eq, beq_iff_eq] at hp
        obtain ⟨⟨⟨⟨⟨hr, _⟩, hfrom⟩, huntil⟩, _⟩, hx⟩ := hp
        rw [← hx, ← h]; exact hA4 τ hr hfrom huntil
  fixed := by
    intro x hx
    unfold factsOf truthOf
    rcases hauth x hx with hc | hc <;> simp [hc]

/-! ## Theorem 7 (Sufficiency) -/

/-- Under A1–A4, a verifier enforcing C1–C4 is carrier-indifferent: whatever the carrier
    presents, an AUTHORIZED verdict implies S1–S5 (Part II, Definition 1). -/
theorem sufficiency (dig : Act I V E Aid H Key Role Subj Nonce Rp Dig → Dig)
    (apply : Action I V Subj → (I → Option V) → (I → Option V))
    (truth : I → Option V) (ρ : RP I V Aid H Key Role Nonce Rp) (t : Nat)
    (α : Act I V E Aid H Key Role Subj Nonce Rp Dig)
    (hauth : ∀ x, α.artifact.rules.auth x = true → α.artifact.chan x = .act ∨ α.artifact.chan x = .rp)
    (hA4 : ∀ τ : Testimony I V Subj Key, ρ.recognized τ.key (.claim τ.claim) = true →
      τ.validFrom ≤ t → t < τ.validUntil → truth τ.claim = some τ.value)
    (hdig : ∀ β : Act I V E Aid H Key Role Subj Nonce Rp Dig, dig β = dig α → β.core = α.core)
    (h : Accepts Checks.all dig ρ t α) :
    -- S1: legitimate, current authority
    Legit ρ α.artifact ∧
    -- S2: on the true facts the rules do not refuse: the gate is closed, and the outcome is an
    -- allow, or an escalation this Act's consents satisfy
    (∀ D', α.artifact.rules.IsDecider (truthOf truth ρ α) D' →
      ¬ α.artifact.rules.GateFires (truthOf truth ρ α) D' ∧
      (α.artifact.rules.outcome D' = .allow ∨
        ∃ e, α.artifact.rules.outcome D' = .esc e ∧ Satisfied Checks.all dig ρ α e)) ∧
    -- S3: every counted consent signed this Act's digest, which fixes its whole core
    (∀ e, Satisfied Checks.all dig ρ α e → ∀ c ∈ α.consents,
      (c.approve = true ∧ ρ.recognized c.key (.consent (α.artifact.needRole e)) = true ∧
        c.role = α.artifact.needRole e ∧ c.digest = dig α) →
      ∀ β : Act I V E Aid H Key Role Subj Nonce Rp Dig, dig β = c.digest → β.core = α.core) ∧
    -- S4: only at the relying party it names, and once
    (α.audience = ρ.id ∧ ¬ Accepts Checks.all dig (commit apply ρ α) t α) ∧
    -- S5: exactly this change
    (commit apply ρ α).state = apply α.action ρ.state := by
  obtain ⟨haud, _, hfresh, ⟨hsv, hrec⟩, hcur, ⟨D, hD, hg, hout⟩⟩ := h
  refine ⟨⟨hsv, hrec rfl, hcur rfl⟩, ?_, ?_, ⟨haud, ?_⟩, rfl⟩
  · intro D' hD'
    have hext := facts_ext truth ρ t α hauth hA4
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
  · intro e _ c _ ⟨_, _, _, hcd⟩ β hβ
    exact hdig β (hβ.trans hcd)
  · intro h'
    exact h'.fresh rfl (List.mem_cons_self ..)

/-! ## Necessity: each obligation dropped, an attack from genuine statements commits

  One witnessed input, `bankrupt`; one rule, "block if bankrupt", at priority 2; default allow.
  In the world the applicant is bankrupt. Keys: 1 the issuer's sealing key, 2 a witness certified
  for `bankrupt`, 7 the carrier's own key (recognised for nothing). -/

namespace Example

def blockIfBankrupt : Dec Unit Bool Unit :=
  { cond := .atom (.cmp [()] (fun vs => match vs with | [v] => some v | _ => none)),
    out := .block, prio := 2 }

def rules : Authority Unit Bool Unit where
  n := 1
  ds := fun _ => blockIfBankrupt
  tr := fun k => match k with | .allow => 0 | .esc => 1 | .block => 2
  tr_inj := by intro a b h; cases a <;> cases b <;> simp_all
  dflt := .allow
  auth := fun _ => false

def i0 : Fin rules.n := ⟨0, by decide⟩
theorem only (j : Fin rules.n) : j = i0 :=
  Fin.ext (by have h := j.isLt; change j.val < 1 at h; show j.val = 0; omega)

abbrev Art := Artifact Unit Bool Unit Unit Nat Nat Unit
abbrev A := Act Unit Bool Unit Unit Nat Nat Unit Unit Nat Unit Nat
abbrev R := RP Unit Bool Unit Nat Nat Unit Nat Unit

def art (sealKey hash : Nat) : Art :=
  { id := (), rules := rules, hash := hash, sealKey := sealKey, sealValid := true,
    chan := fun _ => .wit, needRole := fun _ => (), needCount := fun _ => 1 }

/-- Key 1 seals; key 2 testifies to `bankrupt`; version 10 is in force. -/
def rp : R :=
  { id := (), seen := [], state := fun _ => none, record := fun _ => some 10,
    recognized := fun k p => match k, p with
      | 1, .seal _ => true
      | 2, .claim _ => true
      | _, _ => false }

def dig : A → Nat := fun α => α.nonce
def noop : Action Unit Bool Unit → (Unit → Option Bool) → (Unit → Option Bool) := fun _ s => s

def act (a : Art) (ts : List (Testimony Unit Bool Unit Nat)) : A :=
  { action := ⟨(), fun _ => none⟩, artifact := a, testimony := ts, consents := [], audience := (),
    nonce := 5, nbf := 0, exp := 100, carrierFacts := fun _ => none }

/-- In the world the applicant is bankrupt: on the truth the rule fires and the decider is the
    block. -/
theorem truth_refuses :
    rules.IsDecider (fun _ => some true) (some i0) ∧ rules.outcome (some i0) = .block :=
  ⟨⟨rfl, fun j _ hne => absurd (only j) hne⟩, rfl⟩

/-- C2.2 necessary (Theorem 5): the carrier withholds the bankruptcy statement. With the gate the
    verdict is INCOMPLETE; read two-valued, the rule falls silent and the act commits. -/
theorem C22_necessary :
    Accepts { gate := false } dig rp 50 (act (art 1 10) []) ∧
    ¬ Accepts Checks.all dig rp 50 (act (art 1 10) []) := by
  constructor
  · refine ⟨rfl, by decide, fun _ => by simp [rp, act], ⟨rfl, fun _ => rfl⟩, fun _ => rfl,
      ⟨none, fun j => ?_, fun h => by simp at h, Or.inl rfl⟩⟩
    rw [only j]; decide
  · rintro ⟨_, _, _, _, _, ⟨D, hD, hg, _⟩⟩
    apply hg rfl
    refine ⟨i0, by decide, by decide, ?_⟩
    cases D with
    | none => exact Or.inl trivial
    | some d => exfalso; have := hD.1; rw [only d] at this; exact absurd this (by decide)

/-- C2.1 necessary (Theorem 4): the carrier's own key states "not bankrupt". -/
def lie : Testimony Unit Bool Unit Nat := ⟨(), false, (), 0, 100, 7⟩

theorem C21_necessary :
    Accepts { provenance := false } dig rp 50 (act (art 1 10) [lie]) ∧
    ¬ Accepts Checks.all dig rp 50 (act (art 1 10) [lie]) := by
  constructor
  · refine ⟨rfl, by decide, fun _ => by simp [rp, act], ⟨rfl, fun _ => rfl⟩, fun _ => rfl,
      ⟨none, fun j => ?_, fun _ => ?_, Or.inl rfl⟩⟩
    · rw [only j]; decide
    · rintro ⟨X, hu, _, _⟩; rw [only X] at hu; exact absurd hu (by decide)
  · rintro ⟨_, _, _, _, _, ⟨D, hD, hg, _⟩⟩
    apply hg rfl
    refine ⟨i0, by decide, by decide, ?_⟩
    cases D with
    | none => exact Or.inl trivial
    | some d => exfalso; have := hD.1; rw [only d] at this; exact absurd this (by decide)

/-- A rule set that always allows (the bankruptcy rule left out). -/
def allowAll : Authority Unit Bool Unit := { rules with n := 0, ds := fun i => i.elim0 }
theorem none0 (j : Fin allowAll.n) : False := by
  have h := j.isLt; change j.val < 0 at h; omega

/-- C1.1 necessary (Theorem 2): an authority sealed by the carrier's own key (7), which drops the
    bankruptcy rule, is accepted without recognition. -/
def permissive : Art := { art 7 10 with rules := allowAll }

theorem C11_necessary :
    Accepts { recognition := false } dig rp 50 (act permissive []) ∧
    ¬ Legit rp permissive := by
  constructor
  · exact ⟨rfl, by decide, fun _ => by simp [rp, act], ⟨rfl, fun h => by simp at h⟩, fun _ => rfl,
      ⟨none, fun j => (none0 j).elim, fun _ ⟨X, _⟩ => (none0 X).elim, Or.inl rfl⟩⟩
  · rintro ⟨_, h, _⟩; exact absurd h (by decide)

/-- C1.2 necessary (Theorem 3): a genuine, superseded version (hash 9), sealed by the real key,
    that allowed everything. -/
def oldVersion : Art := { art 1 9 with rules := allowAll }

theorem C12_necessary :
    Accepts { currency := false } dig rp 50 (act oldVersion []) ∧
    ¬ Legit rp oldVersion := by
  constructor
  · exact ⟨rfl, by decide, fun _ => by simp [rp, act], ⟨rfl, fun _ => rfl⟩, fun h => by simp at h,
      ⟨none, fun j => (none0 j).elim, fun _ ⟨X, _⟩ => (none0 X).elim, Or.inl rfl⟩⟩
  · rintro ⟨_, _, h⟩; exact absurd h (by decide)

/-- C4 necessary (Theorem 1, the "once" half): without the nonce check, the same Act is accepted
    again after it has committed. -/
theorem C4_necessary (h : Accepts { nonce := false } dig rp 50 (act (art 1 10) [⟨(), false, (), 0, 100, 2⟩])) :
    Accepts { nonce := false } dig (commit noop rp (act (art 1 10) [⟨(), false, (), 0, 100, 2⟩])) 50
      (act (art 1 10) [⟨(), false, (), 0, 100, 2⟩]) :=
  ⟨h.audience, h.window, fun hc => by simp at hc, h.sealed, h.current, h.verdict⟩

/-- And the premise is met: with a true statement from the certified witness (here: not
    bankrupt), the Act is accepted once. -/
theorem C4_premise : Accepts { nonce := false } dig rp 50 (act (art 1 10) [⟨(), false, (), 0, 100, 2⟩]) := by
  refine ⟨rfl, by decide, fun h => by simp at h, ⟨rfl, fun _ => rfl⟩, fun _ => rfl,
    ⟨none, fun j => ?_, fun _ => ?_, Or.inl rfl⟩⟩
  · rw [only j]; decide
  · rintro ⟨X, hu, _, _⟩; rw [only X] at hu; exact absurd hu (by decide)

end Example

/-! ## C3 necessary (Theorem 6): a consent for a different act is counted without binding

  One rule, "escalate always", to one approver; key 3 is a certified approver. It approved the Act
  with nonce 4; the carrier presents that consent on an Act with nonce 5. -/

namespace BindingExample

def escAlways : Dec Unit Bool Unit :=
  { cond := .atom (.cmp [] (fun _ => some true)), out := .esc (), prio := 1 }

def rules : Authority Unit Bool Unit where
  n := 1
  ds := fun _ => escAlways
  tr := fun k => match k with | .allow => 0 | .esc => 1 | .block => 2
  tr_inj := by intro a b h; cases a <;> cases b <;> simp_all
  dflt := .block
  auth := fun _ => false

def i0 : Fin rules.n := ⟨0, by decide⟩
theorem only (j : Fin rules.n) : j = i0 :=
  Fin.ext (by have h := j.isLt; change j.val < 1 at h; show j.val = 0; omega)

def art : Example.Art :=
  { id := (), rules := rules, hash := 10, sealKey := 1, sealValid := true,
    chan := fun _ => .wit, needRole := fun _ => (), needCount := fun _ => 1 }

def rp : Example.R :=
  { Example.rp with recognized := fun k p => match k, p with
      | 1, .seal _ => true
      | 3, .consent _ => true
      | _, _ => false }

def act : Example.A :=
  { action := ⟨(), fun _ => none⟩, artifact := art, testimony := [],
    consents := [⟨4, (), true, 3⟩], audience := (), nonce := 5, nbf := 0, exp := 100,
    carrierFacts := fun _ => none }

theorem C3_necessary :
    Accepts { binding := false } Example.dig rp 50 act ∧
    ¬ Accepts Checks.all Example.dig rp 50 act := by
  constructor
  · refine ⟨rfl, by decide, fun _ => by simp [rp, Example.rp, act], ⟨rfl, fun _ => rfl⟩,
      fun _ => rfl, ⟨some i0, ⟨by decide, fun j _ hne => absurd (only j) hne⟩, fun _ => ?_,
        Or.inr ⟨(), rfl, ?_⟩⟩⟩
    · rintro ⟨X, hu, _, _⟩; rw [only X] at hu; exact absurd hu (by decide)
    · refine ⟨[3], by simp, by decide, fun k hk => ?_⟩
      simp at hk; subst hk
      exact ⟨rfl, ⟨4, (), true, 3⟩, by simp [act], rfl, rfl, rfl, rfl⟩
  · rintro ⟨_, _, _, _, _, ⟨D, hD, _, hout⟩⟩
    have hD' : D = some i0 := by
      cases D with
      | none => exact absurd (hD i0) (by decide)
      | some d => exact congrArg some (only d)
    subst hD'
    rcases hout with h | ⟨e, _, ks, _, hn, hks⟩
    · simp [act, art, rules, escAlways, Authority.outcome] at h
    · cases ks with
      | nil => simp [act, art] at hn
      | cons k _ =>
        obtain ⟨_, c, hc, _, _, _, hd⟩ := hks k (List.mem_cons_self ..)
        simp [act] at hc; subst hc
        exact absurd hd (by decide)

end BindingExample

end CarriedAuthority.Sufficiency

#print axioms CarriedAuthority.Sufficiency.sufficiency
#print axioms CarriedAuthority.Sufficiency.Example.C22_necessary
#print axioms CarriedAuthority.Sufficiency.BindingExample.C3_necessary
#print axioms CarriedAuthority.Sufficiency.Example.C21_necessary
#print axioms CarriedAuthority.Sufficiency.Example.C11_necessary
#print axioms CarriedAuthority.Sufficiency.Example.C12_necessary
#print axioms CarriedAuthority.Sufficiency.Example.C4_necessary
