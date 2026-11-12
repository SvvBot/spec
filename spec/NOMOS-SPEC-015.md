# NOMOS-SPEC-015: Issuance Proofs

**Status:** Draft
**Version:** 0.2.0
**Proposed:** 2026-11-12
**Revised:** 2026-11-12 (0.2.0: consents only from certified holders; currency judged when the seal was made; see §10)
**Authors:** Safehaven AI Corp. / NOMOS Protocol Working Group
**Uses:** NOMOS-SPEC-001, NOMOS-SPEC-007, NOMOS-SPEC-008, NOMOS-SPEC-013, NOMOS-SPEC-014

---

## Abstract

Every guarantee in this family flows from a seal, and every specification so far rests on one
premise stated nowhere: **the key is the institution.** Custody — the sealing key in the
organization's own HSM, certified under its root, operated with dual control — establishes that
whoever sealed *could*. It establishes nothing about whether the organization *decided*. An
officer holding the genuine key can seal an authority the institution never adopted, and every
verifier will call it genuine, because cryptographically it is.

This specification closes the gap with one reflexive move: **sealing is an act**, and
NOMOS-SPEC-008 already defines how an act carries its authorization. An organization's
**constitution** K — who may propose a sealing, which roles must consent and how many — is a
sealed artifact like any other, whose rules read governance facts. The act "seal digest D as
version V" is evaluated under K, and the result is the **issuance proof ι**, published detached
beside the artifact it authorizes, verifiable offline by the same machinery that verifies
everything else. Constitutions amend by supersession authorized under their predecessor, and
the regress terminates at a **genesis the relying party pins** — never at the organization's
own word.

§8 names the four attacks this defeats, each built from genuine keys alone: the faithless
officer, the stale constitution, the self-certified genesis, the midnight amendment. Each is a
published vector in [`issuance-vectors/`](../issuance-vectors/).

Out of scope, deliberately: legal conclusiveness (ι proves the constitution's procedure was
satisfied, not that a court would uphold the meeting — §7), the truthfulness of offchain
governance witnesses (NOMOS-SPEC-008's A4 assumption, relocated and shrunk, not solved), and
the justice of any constitution (ι exposes governance; it never judges it).

This specification remains a **Draft** until a second, independent implementation passes every
published vector. The key words MUST, MUST NOT, SHOULD and MAY are to be read as in RFC 2119.

## 1. Terminology

- **Constitution K:** a sealed artifact whose rules govern the organization's own acts of
  governance. Its conditions read governance facts (`governance_action`, `authority`, …); its
  escalations name consent requirements (`{ role_required, required_consents }`).
- **Issuance act:** `{ type: "authority.seal", subject, params: { digest, version } }` — or
  `constitution.amend` for amending K itself. `governance_action` is the type's final segment
  (`seal`, `amend`).
- **Issuance proof ι:** `{ act, constitution, at, facts?, consents[] }` — the record that K,
  current at `at`, authorized exactly this act. `constitution` is the digest of the K the proof
  claims; `consents` are `{ role, holder, over }`.
- **Issuance digest:** the SHA-256 of the JCS of `{ act, constitution, at }`. The ONLY thing a
  consent may cover (`over`): an approval bound to anything less transplants.
- **Genesis K₀:** the first constitution on an organization's chain, whose digest the relying
  party pins (beside or inside the NOMOS-SPEC-007 root it already pins).
- **Relying party ρ:** as in NOMOS-SPEC-008, extended with the genesis pin and a **role roster**:
  for each role, the holders whose consent keys chain, with that role in scope, to a root ρ
  pinned (NOMOS-SPEC-007).
- **Seal time:** when the seal was made, as ρ knows it from a source the presenter does not
  control (the registrar log's listing time, ρ's own record of the seal) — never ι's word.

## 2. The constitutional chain

An organization's constitutions form a chain K₀ … Kₙ, each with an in-force time. Every Kᵢ
(i ≥ 1) MUST carry its own ι whose act is `constitution.amend`, whose `params.digest` is the
digest of Kᵢ, whose claimed `constitution` is the digest of Kᵢ₋₁, and whose consents satisfy
Kᵢ₋₁ — **amendment binds only under the old law**. K₀ carries no ι; it is pinned instead.

The chain SHOULD be published where the organization's other statements live (its
NOMOS-SPEC-013/-014 registrar log); verification needs only the records themselves.

## 3. Verification

Given a pinned genesis digest, a role roster, a constitutional chain, a seal digest to justify,
the seal time `t`, and ι (or its absence), a conforming verifier proceeds in this order. Two
constitutions with the same in-force time make the chain ambiguous: `INVALID_AMENDMENT`, under
every presentation order.

1. **C11 — genesis pinning.** The chain's earliest constitution, by in-force time, MUST hash to
   the pinned genesis. A chain that certifies its own origin establishes nothing:
   `GENESIS_NOT_PINNED`.
2. **C12 — amendment under the old law.** Every later constitution MUST carry an ι that is
   ISSUED (per step 5) under its predecessor, binding exactly its own digest. Any failure:
   `INVALID_AMENDMENT`, naming the position and the inner failure. A constitution that fails
   here binds nobody, and everything issued under it fails transitively.
3. **C9 — issuance as act.** Absent ι: `NO_ISSUANCE_PROOF`. A valid signature without ι is a
   draft, not an authority. The ι presented MUST authorize exactly the seal digest in question
   with `governance_action = seal`, else `WRONG_ACT`.
4. **C10 — constitutional currency.** ι's `at` is the presenter's word, so it MUST lie within
   ρ's bound of the seal time `t` (default 7 days), else `OUT_OF_TIME`. The constitution in force
   at `t` is taken from the chain, never from the proof; ι's claimed `constitution` MUST equal its
   digest, else `STALE_CONSTITUTION` — consents satisfying withdrawn governance authorize
   nothing, however genuine, and a backdated ι cannot reach a superseded constitution.
5. **The decision.** The issuance act's governance facts are evaluated against K by a conforming
   NOMOS-SPEC-008 evaluator (three-valued; a blocking governance fact ι omits yields
   `INCOMPLETE` naming it — silence about a fact that could forbid issuance is never
   permission). `block` → `PROHIBITED`, whatever the consents. `allow` → `ISSUED` with no
   consents (a constitution may carve out routine acts). `escalate` → the named escalation's
   `{ role_required, required_consents }` MUST be met by **distinct holders** of that role,
   each consenting `over` exactly this issuance digest; met → `ISSUED`, else
   `CONSENTS_INSUFFICIENT` naming required and counted. A consent counts only from a holder ρ's
   roster lists for the role it claims: a self-declared role is no consent. In a committed Act
   (§4) this is the SPEC-008 check that the consent key is certified for the role.

Verification MUST be deterministic and order-independent: shuffling the chain's presentation
order or any consent list never changes the result.

## 4. Transport

A real ι SHOULD travel as a committed NOMOS-SPEC-008 Act; whatever the transport, a consent
counts only from a holder certified for its role (§3 step 5). A real ι (the consents as its consent
statements, witnesses for governance facts), in which case signature verification is SPEC-008's
`verifyAct` and this specification adds only the constitutional layer above it. ι is published
**detached** beside the artifact — in the NOMOS-SPEC-004 attestation pattern, never under the
seal hash — so attaching it never re-seals, and its absence is detectable without breaking
anything.

An onchain governance event (a passed proposal with a quorum) MAY serve directly as a consent:
the chain is the witness, `holder` identifies the proposal, and the vote's own binding to the
issuance digest replaces a signature. This is the easy case, not the hard one.

## 5. What one compromised key can do

- **The sealing key alone: nothing binds** (C9). A thief mints drafts.
- **One consent key: one vote** toward a quorum the constitution set and published — an
  institution's compromise tolerance is legible in its own K.
- **A quorum of consent keys is the institution**, for verification purposes, as a captured
  board majority is at law. What the construction guarantees is that capture must be
  quorum-sized and leaves ι — a permanent, signed record of exactly which keys consented.
  Detection and attribution where prevention is impossible.
- **Recovery is constitutional:** a compromised K is superseded under its own amendment rule by
  the uncompromised quorum (C12), with revocations travelling as they already do.

## 6. Conformance

[`issuance-vectors/vectors.json`](../issuance-vectors/vectors.json) carries, per vector, a world
(a pinned genesis + the constitutional chain), a query (the seal, the time, ι or null), and the
expected result; vectors with an `ablate` field also carry `expect_ablated` — the behavior of an
implementation missing exactly that condition, i.e. the attack succeeding. A conforming
implementation MUST produce every `expect`, MUST NOT produce any `expect_ablated` outside an
explicit test-only ablation mode, and MUST be order-independent under shuffling.

## 7. What an issuance proof must not claim

**Procedure, not legal conclusiveness.** ι proves the constitution's procedure was satisfied.
A court may still void the vote for fraud, duress, or a defect the compiled K never expressed.
What changes is the default and the burden: the procedural record is complete, signed and
public, so residual disputes are litigated over facts everyone already holds.

**The offchain witness assumption, stated.** A board that votes in a room enters through an
attesting officer — a witness whose certification bounds what they may attest, not whether it
is true (NOMOS-SPEC-008's A4, relocated). The unverifiable thing shrinks from "what did the
institution decide?" to "did this named, certified, revocable officer truthfully attest one
datable event?" — scoped, signed, permanently on the record. Not solved; smaller, priced, and
explicit.

**Legitimacy.** ι verifies issuance under K and is silent on whether K is just. A counterparty
can now read the governance it is trusting as a verifiable object; judging it remains the
counterparty's work.

## 8. Security considerations: the four attacks

Each uses only genuine, correctly signed artifacts, except where the attack is precisely that
something is not signed by whom it claims. Each is a published vector.

- **The faithless officer** (defeats a verifier without C9): the correctly appointed officer
  seals an unapproved version with the genuine institution key. Everything in NOMOS-SPEC-001
  through 014 passes. Under C9 the artifact is a draft wearing a signature, and the absence of
  ι is a verification failure, not a suspicious circumstance.
- **The stale constitution** (without C10): the board tightened K in June; a November ι names
  April's lenient text and satisfies it honestly. Governance the institution withdrew
  authorizes nothing.
- **The self-certified genesis** (without C11): a complete counterfeit institution — fresh
  constitution, internally valid ι, every signature genuine, sound relative to itself. Only the
  relying party's pin distinguishes it from the real one, which is the point: legitimacy is
  conferred by the verifier's choice, never the presenter's self-description.
- **The backdated issuance** (C10's time arm): a seal made in November carries an ι that claims
  May, names April's lenient constitution and has one director's consent. Judged at ι's own time
  (0.1.0) it issues; judged at the seal time, with ι's time bounded to it, it is `OUT_OF_TIME`.
- **The invented consents** (C9's consent arm): the officer writes the quorum himself, consents
  over exactly this issuance from holders nobody certified for the role. Counting claimed roles
  (0.1.0) issues it, for a seal or an amendment; counting only rostered holders refuses it.
- **The midnight amendment** (without C12): the officer who cannot meet the quorum first seals
  a friendlier constitution (their own consent suffices there), then issues validly under it.
  Under C12 the new constitution binds nobody — its own ι fails under the old K — and the coup
  fails transitively, silently to no one.

## 9. Open problems

Stated, not hidden: witness selection and bonding for offchain governance (A4's residue); the
review bar for compiling constitutions, whose miscompiled quorum is constitutional by
definition; privacy of consents (threshold signatures prove k-of-n without naming the k);
genesis ceremonies (for registered companies the state registry is the natural attester; for
DAOs and informal bodies the pin records a social fact); jurisdictional recognition of ι as
evidence of due authorization; and the Draft-exit condition — a second, independent
implementation agreeing on every vector.

## 10. Changes

**0.2.0 (2026-11-12).** Found by mechanizing the decision core in Lean
([`papers/issuance/lean/Issuance.lean`](../papers/issuance/lean/Issuance.lean)), both reproduced
against the reference implementation:

- Currency is judged at the seal time ρ knows, and ι's own time must lie within ρ's bound of it
  (§3 step 4). In 0.1.0 currency was judged at ι's `at`, which the presenter writes: a backdated
  ι reached a superseded constitution.
- A consent counts only from a holder certified for the role it claims (§3 step 5, §4). In 0.1.0
  the verifier counted claimed roles, so whoever assembled ι, the faithless officer included,
  could write the quorum himself, for a seal or an amendment.
- Two constitutions with the same in-force time are refused as ambiguous (§3); 0.1.0's answer
  depended on presentation order.
- Vectors: 17 (from 14), with the roster at the top level of the file.

**0.1.0 (2026-11-12).** First draft.
