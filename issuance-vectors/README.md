# Issuance-proof vectors (NOMOS-SPEC-015, Draft 0.1.0)

The conformance vectors for [NOMOS-SPEC-015](../spec/NOMOS-SPEC-015.md): did the institution,
by its own constitution as it then stood, decide this sealing — custody of the sealing key
alone authorizes nothing.

`vectors.json` holds 14 vectors. Each is a **world** (a pinned genesis digest + the
organization's constitutional chain), a **query** (the seal digest being justified, the claimed
time, the issuance proof ι or `null`), and the expected result:

- `expect` — what a conforming verifier answers;
- vectors with an `ablate` field also carry `expect_ablated` — what an implementation missing
  exactly that condition answers, i.e. the attack succeeding.

Symbolic forms, resolved by the loader: `"$payload:KEY"` is the shared constitution payload of
that name; `"$digest:<key>"` is the digest of that constitution's payload; `"$artifact"` is the
fixture's artifact digest; a consent's `over` of `"$act"` is the enclosing ι's issuance digest
(the only thing a consent may bind to) and `"$other"` is a digest of something else.
Constitutional rules are evaluated by a conforming NOMOS-SPEC-008 evaluator.

The four attack vectors are NOMOS-SPEC-015 §8's necessity constructions, each built from
genuine keys alone:

| Vector | Condition it proves necessary |
| --- | --- |
| `attack-faithless-officer` | C9 — a genuine key with no ι binds nothing |
| `attack-stale-constitution` | C10 — ι is judged under the constitution in force at its time, never the one it names |
| `attack-self-certified-genesis` | C11 — the regress terminates at the relying party's pin, never the presenter's word |
| `attack-midnight-amendment` | C12 — a constitution binds only through an ι valid under its predecessor |

The remaining vectors pin the consent discipline (quorums count distinct people, over exactly
this issuance's digest — no transplant across seals, constitutions or times), prohibitions
holding whatever the consents, INCOMPLETE on a missing governance fact (never permission),
routine carve-outs issuing without a quorum, and a valid amendment chain.

A conforming implementation MUST produce every `expect`, MUST NOT produce any `expect_ablated`
outside an explicit test-only ablation mode, and MUST answer byte-identically under any
shuffling of the chain and of every consent list.

The reference implementation (TypeScript, in the NOMOS platform) runs all 14 vectors, the
necessity table (each attack succeeds under exactly its own ablation and under no other), and
the shuffle check in CI. **An independent implementation that passes this file is the condition
for NOMOS-SPEC-015 leaving Draft** — see [IMPLEMENTING.md](../IMPLEMENTING.md). We invite one.
