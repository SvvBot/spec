# NOMOS Protocol: a guided tour

What each specification adds, with the artifact fields and commands that show it. The specifications themselves, in [`spec/`](../spec/), are normative; where this tour and a specification differ, the specification is right.

- [Command line: validate, verify, run, diff, lint](#command-line)
- [Confidence classification (SPEC-001 §5)](#confidence-classification-spec-001-5)
- [Multi-agent governance (SPEC-002)](#multi-agent-governance-spec-002)
- [Seal integrity (SPEC-001 §8)](#seal-integrity)
- [Temporal validity and staleness (SPEC-003)](#temporal-validity--staleness-spec-003)
- [Composition and attestation (SPEC-004)](#composition--attestation-spec-004)
- [Chain of trust, Act binding, discovery, suites (SPEC-007 to 010)](#chain-of-trust--act-binding-spec-007-spec-008)
- [Tool bindings, enforcement points, registries (SPEC-011 to 013)](#tool-bindings-enforcement-points-registries-spec-011-to-013)

---

## Command line

### Install the CLI

```bash
git clone https://github.com/nomos-spec/spec.git nomos-spec
cd nomos-spec
npm install
```

### Validate structure

```bash
npx tsx cli/nomos.ts validate examples/lending_policy_v1.nomos
```

### Verify cryptographic seal

Production artifacts are sealed with **Ed25519** and are **publicly verifiable** — anyone checks the seal offline with the published public key, no secret and no call to the sealing authority:

```bash
# Fetch the public key once from /.well-known/nomos-signing-keys, then verify locally:
npx tsx verify/verify.ts <artifact.nomos> --url https://nomosprotocol.com
# …or fully offline with a pinned public key:
npx tsx verify/verify.ts <artifact.nomos> --pubkey signing_key.pub.pem
```

The verifier runs two independent, offline checks: **integrity** (recompute the JCS/SHA-256 hash) and **authenticity** (verify the Ed25519 signature against the public key for the seal's `kid`). Tampering the artifact fails the hash check; a forged or wrong-key signature fails authenticity. See §8 of NOMOS-SPEC-001.

> **Legacy:** The bundled `examples/` are older HMAC-SHA256 test artifacts (symmetric — not third-party verifiable), sealed with the public test key `deadbeef…`. Verify them with `--key deadbeef…`. HMAC is retained for backward compatibility only; new seals SHOULD be Ed25519.

### Execute a decision locally

```bash
npx tsx cli/nomos.ts exec examples/lending_policy_v1.nomos \
  --input '{"patron_age": 18, "account_standing": "good", "item_type": "book"}'
```

### Diff two artifact versions

```bash
npx tsx cli/nomos.ts diff examples/lending_policy_v1.nomos examples/lending_policy_v2.nomos
```

### Lint for quality warnings

```bash
npx tsx cli/nomos.ts lint examples/lending_policy_v1.nomos
```

### Evaluate a decision via the hosted runtime

```bash
curl -X POST https://nomosprotocol.com/api/nomos/execute \
  -H "x-api-key: <key>" \
  -H "Content-Type: application/json" \
  -d '{
    "artifactId": "lending_policy_v1",
    "context": {
      "patron_age": 18,
      "account_standing": "good",
      "item_type": "reference"
    }
  }'
```

### Verify an artifact (Python)

```bash
# Ed25519 (production) — verify with the published public key, offline:
python verify/verify.py <artifact.nomos> --url https://nomosprotocol.com   # or --pubkey key.pem
# Legacy HMAC example artifacts:
python verify/verify.py examples/lending_policy_v1.nomos \
  --key deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
```

(Ed25519 verification needs `pip install cryptography`; the Node verifier `verify/verify.ts` is zero-dependency.)

---

## Confidence classification (SPEC-001 §5)

A sealed artifact states how much confidence a runtime should place in its rules, in `meta.verification_tier`, and a runtime preserves it verbatim:

| Tier | Meaning |
|---|---|
| `compiled` | Rules extracted from policy documents (and, if provided, behavioral data), schema-valid, seal-valid. The baseline for any sealed artifact. |
| `proven` | `compiled`, plus measurable evidence references and a performance ledger from real behavioral data. |
| `sovereign` | `proven`, plus a verified compliance profile, forensic-level audit logging, and enforced governance constraints. |

`DECLARED`, `VALIDATED` and `CERTIFIED` are a separate vocabulary, `confidence_band`, used only by the reference deployment's un-sealed public demo artifacts (§5.2). The two are never interchangeable. Listing gates a particular registry applies (the NOMOS Exchange's readiness thresholds, for example) are that registry's policy, not part of the protocol.

See [`spec/NOMOS-SPEC-001.md` §5](../spec/NOMOS-SPEC-001.md#5-confidence-classification).

---

## Multi-Agent Governance (SPEC-002)

NOMOS-SPEC-002 extends the artifact format with an optional `agents` manifest. This lets you embed agent authority and constraints directly inside the sealed artifact — so a runtime can enforce them without any external policy store.

```json
"agents": {
  "manifest_version": "1.0",
  "agents": [
    {
      "agent_id": "loan-review-agent",
      "display_name": "Loan Review Agent",
      "permissions": ["READ_RULES", "EVALUATE"],
      "cannot_call": ["SEAL", "MODIFY_RULES"],
      "constraints": [
        { "field": "risk_score", "operator": "lt", "value": 0.6 },
        { "field": "jurisdiction", "operator": "eq", "value": "US" }
      ],
      "audit_level": "full"
    }
  ]
}
```

### Constraints DSL

The `constraints` array is evaluated by the guard before rule evaluation (Phase 5). Each constraint specifies a field from the incoming request, an operator, and a threshold.

| Operator | Meaning |
|----------|---------|
| `lt` | less than |
| `lte` | at most (≤) |
| `gt` | greater than |
| `gte` | at least (≥) |
| `eq` | equals (any type) |
| `neq` | not equal (any type) |

Semantics:
- **Missing field** → skip (partial payloads don't fail)
- **Type mismatch** on numeric operators → skip
- **Violation in enforce mode** → `block`
- **Violation in advisory mode** → `escalate`

See `spec/NOMOS-SPEC-002.md §5.6` for the full specification.

---

## Seal Integrity

Every `.nomos` artifact carries a `seal` block. Ed25519 is the default, publicly verifiable form:

```json
"seal": {
  "status": "sealed",
  "canonicalization": "JCS",
  "signature_algorithm": "Ed25519",
  "kid": "<public-key-id>",
  "hash": "<sha256-of-canonical-payload>",
  "signed_by": { "name": "...", "org_id": "...", "role": "...", "timestamp": "..." },
  "signature": "<base64-ed25519-signature>"
}
```

The seal is computed over the artifact body canonicalized per [RFC 8785 (JCS)](https://www.rfc-editor.org/rfc/rfc8785), excluding the `seal` and `attestations` fields themselves. Any modification to any other field — including whitespace — produces a different hash and invalidates the signature. Verify offline with the publisher's public key at `/.well-known/nomos-signing-keys` — no secret required. Legacy `HMAC-SHA256` seals (symmetric, verifiable only by the issuer) remain valid but are not third-party verifiable.

See `spec/NOMOS-SPEC-001.md §8` for the full sealing procedure.

---

## Temporal Validity & Staleness (SPEC-003)

NOMOS-SPEC-003 lets a rule declare the window during which it's actually in force, and gives a runtime a way to say "this artifact hasn't been re-validated in a while" without blocking anything.

```json
{
  "id": "cross_border_threshold",
  "valid_from": "2026-01-01T00:00:00Z",
  "valid_until": "2026-12-31T23:59:59Z",
  "when": "...",
  "then": [ ... ]
}
```

A rule outside its window is skipped and traced in the audit record as `expired` — it's never silently ignored. Execution requests can also supply `execution_at`, replaying a decision as if it were evaluated at that historical instant — the same sealed artifact and inputs always produce the same verdict for a given point in time.

When an artifact has accumulated enough executions since it was last triangulated against real behavioral data, the runtime response carries a `staleness_advisory` — informational only, never a block:

```json
"staleness_advisory": {
  "triangulated_at": "2026-05-30T09:41:00Z",
  "decisions_since_triangulation": 503,
  "threshold": 500,
  "recommendation": "consider_retriangulation"
}
```

See `spec/NOMOS-SPEC-003.md` for the full specification.

---

## Composition & Attestation (SPEC-004)

NOMOS-SPEC-004 adds two independent capabilities: building an artifact from a shared base, and letting a third party co-sign one.

**Composition.** A child artifact declares `extends` and carries only its overlay — the rules it overrides, adds, or removes on top of a base:

```json
{
  "extends": { "artifact_id": "base_policy", "version": "2.0.0", "seal_hash": "..." },
  "overlay": {
    "decisions": [ { "id": "min_experience", "when": "...", "then": [ ... ] } ],
    "removed": ["some_base_rule_id"]
  }
}
```

Base and overlay resolve into one self-contained sealed artifact at build time — a runtime never needs the base to evaluate the child. When the base is updated, each child can re-compose against the new version with its overlay re-applied, so a shared rule changes once and propagates everywhere.

**Attestation.** A party other than the issuer signs a sealed version with their own key, over its seal hash:

```json
"attestations": [
  {
    "attester": { "name": "...", "org_id": "...", "role": "regulator" },
    "statement": "Reviewed and approved for AY2026",
    "artifact_hash": "<must equal seal.hash>",
    "algorithm": "Ed25519",
    "kid": "...",
    "signature": "...",
    "attested_at": "..."
  }
]
```

An attestation binds to one exact version — its `artifact_hash` must match the artifact's `seal.hash`, so it can't be replayed onto a different version — and is excluded from the seal-hash computation, so adding or revoking one never invalidates the seal.

See `spec/NOMOS-SPEC-004.md` for the full specification.

---

## Chain of Trust & Act Binding (SPEC-007, SPEC-008)

Together these answer the question a service asks when an agent arrives acting for an organisation: *on whose authority, to do what, and can I check it myself?*

**SPEC-007 — recognizing the issuer.** A key certificate lets one key certify another to sign, within a scope, until an expiry. A verifier pins its own root and resolves the chain offline — no prior relationship with the issuer, no call home. Revision 1.8.0 (draft) extends the same certificates to the keys that state facts (`claim` scope, for witnesses such as a credit bureau) and the keys that approve (`consent` scope, for human approvers), and resolves chains target-first so the verdict never depends on the order certificates are presented in. Revision 1.9.0 makes path selection scope-aware, fixes the order of the per-certificate checks so two verifiers report the same failure, admits ES256 and P-256 keys (SPEC-010), and adds the `suite` and `approver` dimensions, so a passkey can approve and do nothing else and consents are counted by person.

**SPEC-008 — binding the action.** A verdict computed over caller-supplied facts is advice; nothing ties it to the change made later. An Act closes five gaps an agent could otherwise exploit without breaking any cryptography:

| Gap | How the Act closes it |
|-----|-----------------------|
| Skipping the check | The relying party — the system that would make the change — demands and verifies the Act itself |
| Lying to the check | Each fact comes from the channel its input declares: the action, the relying party's own state, or signed testimony from a witness whose key is certified for that claim — and has the type its input declares, so a wrong-typed value cannot make a deny rule fall silent |
| Changing the action after the check | Consents are signed over the Act's binding digest; a changed amount invalidates them |
| Presenting yesterday's rules | The relying party establishes the version in force at verification time; a superseded or revoked authority cannot authorize a new action |
| Withholding a fact | Evaluation is three-valued: a missing fact is undecided, never false, and the verdict is `INCOMPLETE` while an outranking block or escalate rule is undecided; `exists()` treats absence as decided only for the action and the relying party's own state |

An agent is free to bypass every NOMOS component. Its act still cannot take effect, because the only system able to make the change is the one that demands the proof.

```bash
pip install ./python                                   # the Python reference (brings cryptography)
python3 act-vectors/check.py act-vectors/vectors.json  # 48 passed: 46 vectors + 2 non-finite cases
```

See `spec/NOMOS-SPEC-008.md` for the full specification and `act-vectors/README.md` for every case.

**SPEC-009 — finding the relying party and handing it the Act.** A relying party, an issuer and a witness each publish a document at a well-known path. The documents are hints: a carrier uses them to plan and gather, and the relying party evaluates the Act alone, so a false document can make an Act fail, never succeed. Testimony and approvals are requested over two small HTTP exchanges, and an Act is submitted as `application/nomos-act+json`; each verdict comes back as one status (201 AUTHORIZED with the receipt, 202 ESCALATED, 422 INCOMPLETE, 403 DENIED, 409 REPLAYED with the stored receipt, 400 any other refusal). The nonce is the idempotency key, and an escalated Act is resubmitted unchanged with the consents added.

```bash
cd submission-vectors && npm install
node run.mjs https://your-relying-party.example   # 17 checks; configure the relying party with profile.json
```

**SPEC-010 — signature suites.** One closed registry for every NOMOS verifier: `Ed25519`, `ES256` (P1363, low-S) and `WebAuthn-ES256` (consents only, user-verified), with canonical keys fixed byte for byte. It exists so the keys that confer authority can stay in KMS, HSM and passkey custody.

---

## Tool bindings, enforcement points, registries (SPEC-011 to 013)

Where the system that commits a change can't verify an Act yet, the check moves to the last point the call passes through.

**SPEC-011 — tool bindings.** A reviewed file says which tool argument is which fact a policy reads: no constants, only bound facts reach the policy, nothing guessed.

```bash
python3 binding-vectors/check.py binding-vectors/vectors.json   # 50 passed: 31 parse cases + 19 calls
```

**SPEC-012 — enforcement points.** What a gateway or an agent's own pre-tool hook must do: fail closed, the strictest policy wins, approvals are bound to one exact call and used once, and the agent host's own permission prompt is never the approval.

**SPEC-013 — authority registries.** A registry of authorities publishes a signed, mirrorable catalogue and a hash-chained public log of listings, withdrawals, attestations and revocations with a signed head, keeps standing (compiled, published, issued) apart from evidence, and lets a caller say who is asking.

See [`spec/NOMOS-SPEC-011.md`](../spec/NOMOS-SPEC-011.md), [`012`](../spec/NOMOS-SPEC-012.md) and [`013`](../spec/NOMOS-SPEC-013.md).
