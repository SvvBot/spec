/-
  Computable Authority, Part IV ("Seal the Decision, Not the Document") and NOMOS-SPEC-015
  Draft 0.1.0: a mechanized model of the issuance-proof decision core, written to follow the
  reference implementation (server/lib/issuance.ts, `verifyIssuance` / `decideUnder`).

  Self-contained Lean 4 (core only, no Mathlib). Check with:  lean Issuance.lean

  Modelling choices:
  * What a constitution requires for an act (`evalK`) is taken as given: it is NOMOS-SPEC-008's
    three-valued evaluator, whose omission safety is Part II's Proposition 1.
  * The issuance digest a consent covers is the triple (act, constitution, at) itself, so
    "a consent over this digest covers exactly this act, under this constitution, at this time"
    holds by construction (the implementation hashes the same triple).
  * The constitutional chain is given in in-force order (the implementation sorts by `from`; see
    the order finding below, which is a TypeScript test, not a theorem).
  * `cert holder role` is whether a consent's holder is certified for the role it claims
    (SPEC-008/007 consent keys). The 0.1.0 decision core does not read it.

  Results:
  §2  The four conditions are each necessary (C9–C12), as in SPEC-015 §8.
  §3  HOLE 1 — backdating. The 0.1.0 core judges currency at ι's own `at` and never reads the
      query's time, so a November seal whose ι claims May is issued under April's constitution
      (`backdating_issues`). C10's "never from the proof" does not hold: the time is from the proof.
  §3  HOLE 2 — self-declared consents. The 0.1.0 core counts a consent's claimed role and holder;
      the spec only says consents SHOULD travel as signed Acts. The faithless officer can write
      his own quorum (`invented_consents_issue`).
  §4  Officer indifference, for the core as fixed in SPEC-015 0.2.0 (consents count only from
      holders certified for the role; currency is judged at the time the seal was made, as the
      relying party knows it, and ι's own time must lie within its bound of that): ISSUED implies
      the pinned genesis, every amendment issued under its predecessor, ι authorizing exactly this
      seal, the constitution in force when the seal was made, and n distinct certified holders over
      exactly this issuance (`officer_indifference`). `Checks.fixed` is 0.2.0; `Checks.v010` is
      0.1.0.
-/

set_option linter.unusedSectionVars false
set_option linter.deprecated false

namespace Issuance

inductive GovAction | seal | amend
  deriving DecidableEq, Repr

/-- What the constitution says about an act: SPEC-008's outcome, with an escalation's
    consent requirement `{ role_required, required_consents }`. -/
inductive Out (Role : Type) where
  | allow
  | block
  | undecided
  | esc (role : Role) (n : Nat)

variable {K Dg Role Holder Subj : Type}
  [DecidableEq Dg] [DecidableEq Role] [DecidableEq Holder] [DecidableEq Subj]

structure IAct (Subj Dg : Type) where
  gov : GovAction
  subject : Subj
  digest : Dg
  deriving DecidableEq

/-- The issuance digest: what a consent covers. -/
abbrev IDig (Subj Dg : Type) := IAct Subj Dg × Dg × Nat

structure Consent (Role Holder Subj Dg : Type) where
  role : Role
  holder : Holder
  over : IDig Subj Dg

/-- ι: the act, the constitution it claims, the time it claims, the consents. -/
structure Proof (Role Holder Subj Dg : Type) where
  act : IAct Subj Dg
  constitution : Dg
  time : Nat
  consents : List (Consent Role Holder Subj Dg)

def Proof.idig (p : Proof Role Holder Subj Dg) : IDig Subj Dg := (p.act, p.constitution, p.time)

structure Const (K Role Holder Subj Dg : Type) where
  payload : K
  from_ : Nat
  issuance : Option (Proof Role Holder Subj Dg)

/-- The relying party's world: the pinned genesis digest, the organization's chain in in-force
    order, and the evaluator and digests it uses. -/
structure World (K Role Holder Subj Dg : Type) where
  pin : Dg
  chain : List (Const K Role Holder Subj Dg)
  digest : K → Dg
  evalK : K → Proof Role Holder Subj Dg → Out Role
  cert : Holder → Role → Bool

structure Query (Role Holder Subj Dg : Type) where
  artifact : Dg
  /-- when the seal is known to have been made (e.g. its registrar-log listing time) -/
  time : Nat
  iota : Option (Proof Role Holder Subj Dg)

inductive Status | issued | noProof | wrongAct | stale | genesisNotPinned | invalidAmendment
  | insufficient | prohibited | incomplete | outOfTime
  deriving DecidableEq, Repr

/-- Which conditions are enforced. `v010` is SPEC-015 0.1.0 as specified and implemented;
    `fixed` adds certified consents and a time bound. -/
structure Checks where
  c9 : Bool := true
  c10 : Bool := true
  c11 : Bool := true
  c12 : Bool := true
  certified : Bool := false
  /-- ι's time must lie within `b` of when the seal was made (q.time) -/
  timeBound : Option Nat := none
  /-- currency is judged at q.time (when the seal was made), not at ι's own time -/
  currencyAtSeal : Bool := false

def Checks.v010 : Checks := {}
def Checks.fixed (b : Nat) : Checks := { certified := true, timeBound := some b, currencyAtSeal := true }

section
variable (ck : Checks) (w : World K Role Holder Subj Dg)

/-- The distinct holders whose consents count toward role `r` for ι `p`. -/
def counted (p : Proof Role Holder Subj Dg) (r : Role) : List Holder :=
  ((p.consents.filter fun c => c.role == r && c.over == p.idig && (!ck.certified || w.cert c.holder r)).map
    (·.holder)).eraseDups

/-- `decideUnder`: the constitution's outcome, and consent counting for an escalation. -/
def decideUnder (k : K) (p : Proof Role Holder Subj Dg) : Status :=
  match w.evalK k p with
  | .block => .prohibited
  | .undecided => .incomplete
  | .allow => .issued
  | .esc r n => if n ≤ (counted ck w p r).length then .issued else .insufficient

/-- C12 for one link: the successor carries an ι, under exactly its predecessor, for exactly its
    own digest, that its predecessor issues. -/
def linkOk (prev cur : Const K Role Holder Subj Dg) : Bool :=
  match cur.issuance with
  | none => false
  | some p => p.constitution == w.digest prev.payload && p.act.digest == w.digest cur.payload &&
      decideUnder ck w prev.payload p == .issued

def chainOk : List (Const K Role Holder Subj Dg) → Bool
  | a :: b :: rest => linkOk ck w a b && chainOk (b :: rest)
  | _ => true

/-- The constitution in force at time `t`: the last one in force by then, else the genesis. -/
def inForce (k0 : Const K Role Holder Subj Dg) (chain : List (Const K Role Holder Subj Dg)) (t : Nat) :
    Const K Role Holder Subj Dg :=
  chain.foldl (fun acc k => if k.from_ ≤ t then k else acc) k0

def inTime (q : Query Role Holder Subj Dg) (p : Proof Role Holder Subj Dg) : Bool :=
  match ck.timeBound with
  | none => true
  | some b => decide (p.time ≤ q.time + b) && decide (q.time ≤ p.time + b)

/-- `verifyIssuance`. -/
def verify (q : Query Role Holder Subj Dg) : Status :=
  match w.chain with
  | [] => .genesisNotPinned
  | k0 :: rest =>
    if ck.c11 && !(w.digest k0.payload == w.pin) then .genesisNotPinned
    else if ck.c12 && !chainOk ck w (k0 :: rest) then .invalidAmendment
    else if !ck.c9 then .issued
    else match q.iota with
      | none => .noProof
      | some p =>
        if !(p.act.digest == q.artifact && p.act.gov == .seal) then .wrongAct
        else if !inTime ck q p then .outOfTime
        else
          let kf := inForce k0 (k0 :: rest) (if ck.currencyAtSeal then q.time else p.time)
          if ck.c10 then
            (if p.constitution == w.digest kf.payload then decideUnder ck w kf.payload p else .stale)
          else
            -- C10 dropped: evaluate under the constitution the proof names, if it is on the chain
            match (k0 :: rest).find? (fun k => w.digest k.payload == p.constitution) with
            | some k => decideUnder ck w k.payload p
            | none => decideUnder ck w kf.payload p
end

/-! ## §1 A small world

  Digests are the payload ids. K1 (genesis, April): one director. K2 (June): two directors.
  K9: a counterfeit constitution in which the officer alone suffices. Holders: 1 alice and 2 bob
  are certified directors; 7 is the officer, certified for nothing; 8 and 9 are invented. -/

namespace Ex

abbrev P := Proof Unit Nat Unit Nat
abbrev C := Const Nat Unit Nat Unit Nat
abbrev W := World Nat Unit Nat Unit Nat
abbrev Q := Query Unit Nat Unit Nat

def evalK : Nat → P → Out Unit
  | 1, _ => .esc () 1
  | 2, _ => .esc () 2
  | _, _ => .allow            -- the counterfeit: anything goes

def cert : Nat → Unit → Bool
  | 1, _ => true
  | 2, _ => true
  | _, _ => false

def sealAct : IAct Unit Nat := ⟨.seal, (), 500⟩

def consentsBy (holders : List Nat) (act : IAct Unit Nat) (k t : Nat) : List (Consent Unit Nat Unit Nat) :=
  holders.map fun h => ⟨(), h, (act, k, t)⟩

def mkProof (act : IAct Unit Nat) (k t : Nat) (holders : List Nat) : P :=
  ⟨act, k, t, consentsBy holders act k t⟩

/-- The June amendment K1 → K2, approved by alice under K1. -/
def amendK2 : P := mkProof ⟨.amend, (), 2⟩ 1 6 [1]

def k1 : C := ⟨1, 1, none⟩
def k2 : C := ⟨2, 6, some amendK2⟩

def world (chain : List C) (pin : Nat := 1) : W := ⟨pin, chain, id, evalK, cert⟩

def real : W := world [k1, k2]

/-- The honest November issuance: both directors, under K2. -/
theorem honest : verify (Checks.fixed 30) real ⟨500, 11, some (mkProof sealAct 2 11 [1, 2])⟩ = .issued := by
  decide

/-! ## §2 Necessity of C9–C12 (SPEC-015 §8) -/

/-- C9: the faithless officer presents the genuine seal and no ι. -/
theorem C9_necessary :
    verify { c9 := false } real ⟨500, 11, none⟩ = .issued ∧
    verify Checks.v010 real ⟨500, 11, none⟩ = .noProof := by decide

/-- C10: a November ι names April's constitution and satisfies it honestly (alice alone). -/
theorem C10_necessary :
    verify { c10 := false } real ⟨500, 11, some (mkProof sealAct 1 11 [1])⟩ = .issued ∧
    verify Checks.v010 real ⟨500, 11, some (mkProof sealAct 1 11 [1])⟩ = .stale := by decide

/-- C11: a complete counterfeit institution, genesis K9, sound relative to itself. -/
theorem C11_necessary :
    verify { c11 := false } (world [⟨9, 1, none⟩]) ⟨500, 11, some (mkProof sealAct 9 11 [7])⟩ = .issued ∧
    verify Checks.v010 (world [⟨9, 1, none⟩]) ⟨500, 11, some (mkProof sealAct 9 11 [7])⟩ = .genesisNotPinned := by
  decide

/-- C12: the midnight amendment. The officer seals K9 as K1's successor without the director
    K1 requires, then issues under it. (Had he written a director's consent himself, 0.1.0 would
    count it and C12 would pass too: hole 2 below reaches amendments as well.) -/
def midnight : W := world [k1, ⟨9, 6, some (mkProof ⟨.amend, (), 9⟩ 1 6 [])⟩]

/-- Hole 2 reaches C12: with an invented director consent on the amendment, 0.1.0 accepts the
    midnight amendment; the fixed core does not. -/
def midnightForged : W := world [k1, ⟨9, 6, some (mkProof ⟨.amend, (), 9⟩ 1 6 [8])⟩]

theorem forged_amendment :
    verify Checks.v010 midnightForged ⟨500, 11, some (mkProof sealAct 9 11 [7])⟩ = .issued ∧
    verify (Checks.fixed 30) midnightForged ⟨500, 11, some (mkProof sealAct 9 11 [7])⟩ = .invalidAmendment := by
  decide

theorem C12_necessary :
    verify { c12 := false } midnight ⟨500, 11, some (mkProof sealAct 9 11 [7])⟩ = .issued ∧
    verify Checks.v010 midnight ⟨500, 11, some (mkProof sealAct 9 11 [7])⟩ = .invalidAmendment := by
  decide

/-! ## §3 Two holes in 0.1.0 -/

/-- HOLE 1. A November seal (q.time = 11) whose ι claims May (5): currency is judged at 5, where
    April's K1 is in force, and alice alone issues it. Every 0.1.0 check passes, C10 included.
    The time bound refuses it. -/
theorem backdating_issues :
    verify Checks.v010 real ⟨500, 11, some (mkProof sealAct 1 5 [1])⟩ = .issued ∧
    verify (Checks.fixed 2) real ⟨500, 11, some (mkProof sealAct 1 5 [1])⟩ = .outOfTime := by
  decide

/-- HOLE 2. The officer writes two consents himself, from invented holders 8 and 9 claiming the
    director role, over exactly this issuance under the current K2. 0.1.0 counts them. Counting
    only certified holders refuses it. -/
theorem invented_consents_issue :
    verify Checks.v010 real ⟨500, 11, some (mkProof sealAct 2 11 [8, 9])⟩ = .issued ∧
    verify (Checks.fixed 30) real ⟨500, 11, some (mkProof sealAct 2 11 [8, 9])⟩ = .insufficient := by
  decide

/-- One stolen director key is one vote: alice's key alone does not meet K2. -/
theorem one_key_one_vote :
    verify (Checks.fixed 30) real ⟨500, 11, some (mkProof sealAct 2 11 [1, 1])⟩ = .insufficient := by
  decide

end Ex

/-! ## §4 Officer indifference, for the fixed core -/

theorem chainOk_cons (ck : Checks) (w : World K Role Holder Subj Dg) (a b : Const K Role Holder Subj Dg) (rest) :
    chainOk ck w (a :: b :: rest) = true ↔ linkOk ck w a b = true ∧ chainOk ck w (b :: rest) = true := by
  simp [chainOk]

/-- Whatever any key-holder signs, assembles or withholds: if the fixed core says ISSUED, then the
    chain starts at the pinned genesis, every amendment was issued under its predecessor, ι
    authorizes exactly this seal, ι's time is within the bound of when the seal was made, ι names
    the constitution in force at that time, and that constitution allowed the act outright or n
    distinct holders certified for the named role consented over exactly this issuance. -/
theorem officer_indifference (b : Nat) (w : World K Role Holder Subj Dg) (q : Query Role Holder Subj Dg)
    (h : verify (Checks.fixed b) w q = .issued) :
    ∃ k0 rest p, w.chain = k0 :: rest ∧ w.digest k0.payload = w.pin ∧
      chainOk (Checks.fixed b) w (k0 :: rest) = true ∧
      q.iota = some p ∧ p.act.digest = q.artifact ∧ p.act.gov = .seal ∧
      p.time ≤ q.time + b ∧ q.time ≤ p.time + b ∧
      p.constitution = w.digest (inForce k0 (k0 :: rest) q.time).payload ∧
      (w.evalK (inForce k0 (k0 :: rest) q.time).payload p = .allow ∨
        ∃ r n, w.evalK (inForce k0 (k0 :: rest) q.time).payload p = .esc r n ∧
          n ≤ (counted (Checks.fixed b) w p r).length ∧
          ∀ x ∈ counted (Checks.fixed b) w p r, w.cert x r = true ∧
            ∃ c ∈ p.consents, c.holder = x ∧ c.role = r ∧ c.over = p.idig) := by
  unfold verify at h
  split at h
  · cases h
  · next k0 rest hch =>
    simp only [Checks.fixed, Bool.true_and, Bool.not_eq_true', beq_eq_false_iff_ne, ne_eq,
      Bool.not_true, Bool.false_eq_true, ↓reduceIte] at h
    by_cases hg : w.digest k0.payload = w.pin
    · rw [if_neg (by simpa using hg)] at h
      by_cases hc : chainOk { certified := true, timeBound := some b, currencyAtSeal := true } w (k0 :: rest) = true
      · rw [if_neg (by simpa using hc)] at h
        split at h
        · cases h
        · next p hq =>
          by_cases ha : (p.act.digest == q.artifact && p.act.gov == GovAction.seal) = true
          · rw [if_neg (by simpa using ha)] at h
            simp only [Bool.and_eq_true, beq_iff_eq] at ha
            by_cases ht : inTime { certified := true, timeBound := some b, currencyAtSeal := true } q p = true
            · rw [if_neg (by simpa using ht)] at h
              simp only [inTime, Bool.and_eq_true, decide_eq_true_eq] at ht
              split at h
              · next hk =>
                simp only [beq_iff_eq] at hk
                refine ⟨k0, rest, p, hch, hg, hc, hq, ha.1, ha.2, ht.1, ht.2, hk, ?_⟩
                unfold decideUnder at h
                split at h
                · cases h
                · cases h
                · next he => exact Or.inl he
                · next r n he =>
                  split at h
                  · next hn =>
                    refine Or.inr ⟨r, n, he, hn, fun x hx => ?_⟩
                    have hx' := (List.mem_eraseDups).mp hx
                    obtain ⟨c, hc', rfl⟩ := List.mem_map.mp hx'
                    obtain ⟨hcm, hcc⟩ := List.mem_filter.mp hc'
                    simp only [Checks.fixed, Bool.not_true, Bool.false_or, Bool.and_eq_true,
                      beq_iff_eq] at hcc
                    exact ⟨hcc.2, c, hcm, rfl, hcc.1.1, hcc.1.2⟩
                  · cases h
              · cases h
            · rw [if_pos (by simpa using ht)] at h; cases h
          · rw [if_pos (by simpa using ha)] at h; cases h
      · rw [if_pos (by simpa using hc)] at h; cases h
    · rw [if_pos (by simpa using hg)] at h; cases h

/-- Corollary: the sealing key alone mints nothing. Without ι the fixed core never issues. -/
theorem no_proof_no_authority (b : Nat) (w : World K Role Holder Subj Dg) (t : Nat)
    (artifact : Dg) : verify (Checks.fixed b) w ⟨artifact, t, none⟩ ≠ .issued := by
  intro h
  obtain ⟨_, _, _, _, _, _, hq, _⟩ := officer_indifference b w _ h
  cases hq

end Issuance

#print axioms Issuance.officer_indifference
#print axioms Issuance.Ex.backdating_issues
#print axioms Issuance.Ex.invented_consents_issue
#print axioms Issuance.Ex.C12_necessary
#print axioms Issuance.Ex.forged_amendment
#print axioms Issuance.no_proof_no_authority
