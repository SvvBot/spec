/-
  NOMOS-SPEC-007 chain-of-trust resolution (rev. 1.8–1.10), as Part II's Propositions 2–3 use it,
  following the reference resolver (@nomosprotocol/verify, chain.ts `validate`, scope.ts).

  Self-contained Lean 4 (core only). Check with:  lean Chain.lean

  A path is a list of certificates from the pinned root to the target key. Each hop checks the
  signature and validity window (`ok`), certificate and key revocation, and that the child's scope
  never widens a dimension the effective scope already constrains; the effective scope then takes
  the child's terms over its parent's (`mergeScopes`).

  Results:
  * Proposition 2 (`no_amplification`): on a valid path, every term any certificate states holds
    of the effective scope, narrowed or equal. A delegate never exceeds a constraint above it.
  * Proposition 3 (`revocation_complete`): on a valid path no key and no certificate is revoked;
    revoking any key or certificate on it fails it.
  * HOLE (`sealing_key_mints_statement_keys`): key purpose (rev. 1.8 §3.5) is checked per key, but
    absence of a `claim` or `consent` term means "none" for what a key may sign and "anything" for
    what it may delegate. So a sealing key, which may not testify or consent, certifies keys that
    can: one stolen issuer key supplies the rules, the facts they read, and any number of
    approvers. The reference resolver accepts exactly this (reproduced).
  * Fix (`statement_authority_from_root`): a certificate may introduce a `claim` or `consent` term
    only directly under the pinned root; below it such a term may only narrow. Then every key on a
    statement key's path, below the root, is itself a statement key, so no sealing key is an
    ancestor of a witness or an approver.
  * Proposition 4 (order independence) is not modelled here: the reference resolver orders
    candidates by a fingerprint that excludes the signature, so two certificates differing only in
    signature tie and input order decides which failure is reported (reproduced in TypeScript).
-/

set_option linter.unusedSectionVars false

namespace Chain

variable {Key Dim Val : Type} [DecidableEq Key] [DecidableEq Dim]

/-- A scope: the value constrained on each dimension, if any. -/
abbrev Scope (Dim Val : Type) := Dim → Option Val

structure Cert (Key Dim Val : Type) where
  parent : Key
  child : Key
  scope : Scope Dim Val
  /-- signature valid under the parent key, and inside its validity window -/
  ok : Bool
  fp : Nat

/-- `mergeScopes`: the child's terms over its parent's. -/
def merge (eff child : Scope Dim Val) : Scope Dim Val := fun d =>
  match child d with
  | some v => some v
  | none => eff d

structure Env (Key Dim Val : Type) where
  /-- `contains d broader narrower` (`dimensionContains`) -/
  contains : Dim → Val → Val → Prop
  revokedKey : Key → Prop
  revokedCert : Nat → Prop
  /-- the statement dimensions, `claim` and `consent` -/
  stmt : Dim → Prop
  /-- rev. 1.8 §3.5 fixed: statement terms only directly under the root -/
  rootOnlyStatement : Bool

/-- One hop under effective scope `eff`, at position `pos` (0 = the root's own certificate). -/
def Hop (env : Env Key Dim Val) (eff : Scope Dim Val) (pos : Nat) (c : Cert Key Dim Val) : Prop :=
  c.ok = true ∧ ¬ env.revokedCert c.fp ∧ ¬ env.revokedKey c.child ∧
  (∀ d v pv, c.scope d = some v → eff d = some pv → env.contains d pv v) ∧
  (env.rootOnlyStatement = true → pos > 0 → ∀ d v, env.stmt d → c.scope d = some v → eff d ≠ none)

/-- A valid path from key `k` with effective scope `eff`, to target `tgt` with scope `out`. -/
def Valid (env : Env Key Dim Val) : Nat → Key → Scope Dim Val → List (Cert Key Dim Val) → Key → Scope Dim Val → Prop
  | _, k, eff, [], tgt, out => tgt = k ∧ out = eff
  | pos, k, eff, c :: cs, tgt, out =>
    c.parent = k ∧ Hop env eff pos c ∧ Valid env (pos + 1) c.child (merge eff c.scope) cs tgt out

/-- `resolveKey` on one candidate: from the pinned root, unrestricted, unrevoked. -/
def Resolves (env : Env Key Dim Val) (root : Key) (path : List (Cert Key Dim Val)) (tgt : Key)
    (out : Scope Dim Val) : Prop :=
  ¬ env.revokedKey root ∧ Valid env 0 root (fun _ => none) path tgt out

/-! ## Proposition 2: no amplification -/

theorem merge_keeps (env : Env Key Dim Val) (htrans : ∀ d a b c, env.contains d a b → env.contains d b c → env.contains d a c)
    (hrefl : ∀ d a, env.contains d a a) :
    ∀ (pos : Nat) (k : Key) (eff : Scope Dim Val) (cs : List (Cert Key Dim Val)) (tgt : Key) (out : Scope Dim Val),
      Valid env pos k eff cs tgt out → ∀ d v, eff d = some v → ∃ v', out d = some v' ∧ env.contains d v v'
  | _, _, eff, [], _, out, ⟨_, hout⟩, d, v, h => ⟨v, by rw [hout, h], hrefl d v⟩
  | pos, _, eff, c :: cs, tgt, out, ⟨_, hop, hv⟩, d, v, h => by
    obtain ⟨v1, h1, hc1⟩ : ∃ v1, merge eff c.scope d = some v1 ∧ env.contains d v v1 := by
      unfold merge
      cases hcd : c.scope d with
      | none => exact ⟨v, h, hrefl d v⟩
      | some w => exact ⟨w, rfl, hop.2.2.2.1 d w v hcd h⟩
    obtain ⟨v', h', hc'⟩ := merge_keeps env htrans hrefl (pos + 1) c.child _ cs tgt out hv d v1 h1
    exact ⟨v', h', htrans d v v1 v' hc1 hc'⟩

/-- Proposition 2. On a valid path every term any certificate on it states holds of the target's
    effective scope, narrowed or equal: a delegate never exceeds a constraint above it. -/
theorem no_amplification (env : Env Key Dim Val)
    (htrans : ∀ d a b c, env.contains d a b → env.contains d b c → env.contains d a c)
    (hrefl : ∀ d a, env.contains d a a) :
    ∀ (pos : Nat) (k : Key) (eff : Scope Dim Val) (cs : List (Cert Key Dim Val)) (tgt : Key) (out : Scope Dim Val),
      Valid env pos k eff cs tgt out →
      ∀ c ∈ cs, ∀ d v, c.scope d = some v → ∃ v', out d = some v' ∧ env.contains d v v'
  | _, _, _, [], _, _, _, _, hc, _, _, _ => by cases hc
  | pos, k, eff, c :: cs, tgt, out, ⟨_, _, hv⟩, c', hc', d, v, hcd => by
    rcases List.mem_cons.mp hc' with rfl | hin
    · have : merge eff c'.scope d = some v := by unfold merge; rw [hcd]
      exact merge_keeps env htrans hrefl (pos + 1) _ _ cs tgt out hv d v this
    · exact no_amplification env htrans hrefl (pos + 1) _ _ cs tgt out hv c' hin d v hcd

/-! ## Proposition 3: revocation is complete -/

theorem revocation_complete (env : Env Key Dim Val) :
    ∀ (pos : Nat) (k : Key) (eff : Scope Dim Val) (cs : List (Cert Key Dim Val)) (tgt : Key) (out : Scope Dim Val),
      Valid env pos k eff cs tgt out → ∀ c ∈ cs, ¬ env.revokedKey c.child ∧ ¬ env.revokedCert c.fp
  | _, _, _, [], _, _, _, c, hc => by cases hc
  | pos, _, _, c :: cs, tgt, out, ⟨_, hop, hv⟩, c', hc' => by
    rcases List.mem_cons.mp hc' with rfl | hin
    · exact ⟨hop.2.2.1, hop.2.1⟩
    · exact revocation_complete env (pos + 1) _ _ cs tgt out hv c' hin

/-- And the root: a resolved path starts from an unrevoked pinned root, so every key on it (the
    root and every child) is unrevoked. -/
theorem resolved_unrevoked (env : Env Key Dim Val) (root : Key) (path : List (Cert Key Dim Val))
    (tgt : Key) (out : Scope Dim Val) (h : Resolves env root path tgt out) :
    ¬ env.revokedKey root ∧ ∀ c ∈ path, ¬ env.revokedKey c.child ∧ ¬ env.revokedCert c.fp :=
  ⟨h.1, revocation_complete env 0 root _ path tgt out h.2⟩

/-! ## The hole: a sealing key mints statement keys -/

namespace Ex

/-- Dimensions: the artifact, and the statement dimension `claim`. -/
inductive D | artifact | claim
  deriving DecidableEq

/-- Keys: 0 the pinned root, 1 an issuer's sealing key, 2 a witness key the issuer certified. -/
def env (fixed : Bool) : Env Nat D Nat :=
  { contains := fun _ a b => a = b, revokedKey := fun _ => False, revokedCert := fun _ => False,
    stmt := fun d => d = .claim, rootOnlyStatement := fixed }

/-- root → sealing key, for artifact 7 only. -/
def toSealer : Cert Nat D Nat := ⟨0, 1, fun d => match d with | .artifact => some 7 | .claim => none, true, 1⟩
/-- sealing key → witness, artifact 7, claim "income" (100). -/
def toWitness : Cert Nat D Nat := ⟨1, 2, fun d => match d with | .artifact => some 7 | .claim => some 100, true, 2⟩

/-- A key may seal only with no statement term (rev. 1.8 §3.5); it may testify to f only with a
    `claim` term naming f. -/
def MaySeal (s : Scope D Nat) : Prop := s .claim = none
def MayTestify (s : Scope D Nat) (f : Nat) : Prop := s .claim = some f

def sealerScope : Scope D Nat := merge (fun _ => none) toSealer.scope
def witnessScope : Scope D Nat := merge sealerScope toWitness.scope

/-- Under rev. 1.8–1.10: the issuer's key resolves as a sealing key, and a key it certified
    resolves as a witness. One stolen sealing key supplies both the rules and their facts (and the
    same construction with `consent` terms supplies approvers). -/
theorem sealing_key_mints_statement_keys :
    Resolves (env false) 0 [toSealer] 1 sealerScope ∧ MaySeal sealerScope ∧
    Resolves (env false) 0 [toSealer, toWitness] 2 witnessScope ∧ MayTestify witnessScope 100 := by
  have hop1 : Hop (env false) (fun _ => none) 0 toSealer :=
    ⟨rfl, id, id, fun _ _ _ _ hpv => by simp at hpv, fun h => by simp [env] at h⟩
  have hop2 : Hop (env false) sealerScope 1 toWitness := by
    refine ⟨rfl, id, id, fun d v pv hv hpv => ?_, fun h => by simp [env] at h⟩
    cases d
    · simp [toWitness] at hv; simp [sealerScope, merge, toSealer] at hpv; subst hv; subst hpv; rfl
    · simp [sealerScope, merge, toSealer] at hpv
  exact ⟨⟨fun h => h, rfl, hop1, rfl, rfl⟩, rfl, ⟨fun h => h, rfl, hop1, rfl, hop2, rfl, rfl⟩, rfl⟩

/-- With the fix, the witness's certificate is refused: it introduces `claim` below the root. -/
theorem fixed_refuses_minted_witness : ¬ Valid (env true) 1 1 sealerScope [toWitness] 2 witnessScope := by
  rintro ⟨_, ⟨_, _, _, _, hfix⟩, _⟩
  exact hfix rfl (by decide) .claim 100 rfl rfl (by simp [sealerScope, merge, toSealer])

end Ex

/-! ## The fix: statement authority comes from the root -/

/-- Under the fix, once a path has passed its first hop, a statement term in the final effective
    scope was already present after that first hop: it can only be inherited, never introduced. -/
theorem stmt_inherited (env : Env Key Dim Val) (hfix : env.rootOnlyStatement = true) :
    ∀ (pos : Nat) (k : Key) (eff : Scope Dim Val) (cs : List (Cert Key Dim Val)) (tgt : Key) (out : Scope Dim Val),
      pos > 0 → Valid env pos k eff cs tgt out → ∀ d, env.stmt d → out d ≠ none → eff d ≠ none
  | _, _, eff, [], _, out, _, ⟨_, hout⟩, d, _, h => by rw [hout] at h; exact h
  | pos, _, eff, c :: cs, tgt, out, hpos, ⟨_, hop, hv⟩, d, hd, h => by
    have hnext := stmt_inherited env hfix (pos + 1) _ _ cs tgt out (by omega) hv d hd h
    unfold merge at hnext
    cases hcd : c.scope d with
    | none => rw [hcd] at hnext; exact hnext
    | some v => exact hop.2.2.2.2 hfix hpos d v hd hcd

/-- Every key strictly between the root and a statement key carries that statement term too:
    no key that may seal (no statement term) is an ancestor of a witness or an approver. -/
theorem statement_authority_from_root (env : Env Key Dim Val) (hfix : env.rootOnlyStatement = true) :
    ∀ (pos : Nat) (k : Key) (eff : Scope Dim Val) (cs : List (Cert Key Dim Val)) (tgt : Key) (out : Scope Dim Val),
      Valid env pos k eff cs tgt out → ∀ d, env.stmt d → out d ≠ none →
      ∀ (pre : List (Cert Key Dim Val)) (c : Cert Key Dim Val) (post : List (Cert Key Dim Val)),
        cs = pre ++ c :: post → pos + pre.length > 0 →
        ∀ e, Valid env pos k eff pre c.parent e → e d ≠ none
  | _, _, _, [], _, _, _, _, _, _, pre, c, post, hcs, _, _, _ => by
    cases pre <;> simp at hcs
  | pos, k, eff, c0 :: cs, tgt, out, hv, d, hd, hout, pre, c, post, hcs, hpos, e, hve => by
    cases pre with
    | nil =>
      simp only [List.nil_append, List.cons.injEq] at hcs
      obtain ⟨rfl, rfl⟩ := hcs
      obtain ⟨_, he⟩ := hve
      rw [he]
      simp only [List.length_nil, Nat.add_zero] at hpos
      exact stmt_inherited env hfix pos k eff (c0 :: cs) tgt out hpos hv d hd hout
    | cons p pre' =>
      simp only [List.cons_append, List.cons.injEq] at hcs
      obtain ⟨rfl, hcs'⟩ := hcs
      obtain ⟨_, _, hv'⟩ := hv
      obtain ⟨_, _, hve'⟩ := hve
      exact statement_authority_from_root env hfix (pos + 1) _ _ cs tgt out hv' d hd hout pre' c post hcs'
        (by simp only [List.length_cons] at hpos ⊢; omega) e hve'

end Chain

#print axioms Chain.no_amplification
#print axioms Chain.revocation_complete
#print axioms Chain.Ex.sealing_key_mints_statement_keys
#print axioms Chain.Ex.fixed_refuses_minted_witness
#print axioms Chain.statement_authority_from_root
