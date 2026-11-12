# Issuance-proof vectors (NOMOS-SPEC-015, Draft 0.2.0)

The conformance vectors for [NOMOS-SPEC-015](../spec/NOMOS-SPEC-015.md): did the institution,
by its own constitution as it then stood, decide this sealing — custody of the sealing key
alone authorizes nothing.

`vectors.json` holds 17 vectors. Each is a **world** (a pinned genesis digest + the
organization's constitutional chain; the role roster is at the top level of the file and a world
may override it), a **query** (the seal digest being justified, the seal time as the relying
party knows it, the issuance proof ι or `null`), and the expected result:

- `expect` — what a conforming verifier answers;
- vectors with an `ablate` field also carry `expect_ablated` — what an implementation missing
  exactly that condition answers, i.e. the attack succeeding.

Symbolic forms, resolved by the loader: `"$payload:KEY"` is the shared constitution payload of
that name; `"$digest:<key>"` is the digest of that constitution's payload; `"$artifact"` is the
fixture's artifact digest; a consent's `over` of `"$act"` is the enclosing ι's issuance digest
(the only thing a consent may bind to) and `"$other"` is a digest of something else.
Constitutional rules are evaluated by a conforming NOMOS-SPEC-008 evaluator.

The six attack vectors are NOMOS-SPEC-015 §8's necessity constructions:

| Vector | Condition it proves necessary |
| --- | --- |
| `attack-faithless-officer` | C9 — a genuine key with no ι binds nothing |
| `attack-stale-constitution` | C10 — ι is judged under the constitution in force when the seal was made, never the one it names |
| `attack-backdated-issuance` | C10, time arm — ι's own time must lie within the bound of when the seal was made |
| `attack-invented-consents` | C9, consent arm — a consent counts only from a holder certified for its role (ablation `C9-certified`) |
| `attack-self-certified-genesis` | C11 — the regress terminates at the relying party's pin, never the presenter's word |
| `attack-midnight-amendment` | C12 — a constitution binds only through an ι valid under its predecessor |

The remaining vectors pin the consent discipline (quorums count distinct people, over exactly
this issuance's digest — no transplant across seals, constitutions or times), prohibitions
holding whatever the consents, INCOMPLETE on a missing governance fact (never permission),
routine carve-outs issuing without a quorum, a valid amendment chain, and a chain whose two
constitutions share an in-force time (refused as ambiguous).

A conforming implementation MUST produce every `expect`, MUST NOT produce any `expect_ablated`
outside an explicit test-only ablation mode, and MUST answer byte-identically under any
shuffling of the chain and of every consent list.

The reference implementation (TypeScript, in the NOMOS platform) runs all 17 vectors, the
necessity table (each attack succeeds under exactly its own ablation and under no other), and
the shuffle check in CI. The decision core is also mechanized in Lean 4:
[`papers/issuance/lean/`](../papers/issuance/lean/). **An independent implementation that passes this file is the condition
for NOMOS-SPEC-015 leaving Draft** — see [IMPLEMENTING.md](../IMPLEMENTING.md). We invite one.
