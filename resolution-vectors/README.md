# Resolution vectors (NOMOS-SPEC-014, Draft 0.1.0)

The conformance vectors for [NOMOS-SPEC-014](../spec/NOMOS-SPEC-014.md): which authorities
govern an act in a context at a time, with evidence that the enumeration is complete relative
to the relying party's pinned registrars.

`vectors.json` holds 16 vectors. Each is a **world** (registrar records and pins), a **query**
(`context` + `at`), and the expected result:

- `expect` — what a conforming resolver answers;
- vectors with an `ablate` field also carry `expect_ablated` — what an implementation missing
  exactly that condition answers, i.e. the attack succeeding.

The five attack vectors are NOMOS-SPEC-014 §8's necessity constructions, each built from
genuine artifacts alone:

| Vector | Condition it proves necessary |
| --- | --- |
| `attack-applicability-hiding` | C5 — the set comes from pinned logs, never the carrier |
| `attack-jurisdiction-squatting` | C6 — a claim binds only within the certified scope |
| `attack-zombie-authority` | C7 — membership is judged at `t` |
| `attack-starved-resolver` | C8 — an unreachable pinned registrar yields INCOMPLETE |
| `attack-stale-closure` | C8 — a stale closure yields INCOMPLETE |

A conforming resolver MUST produce every `expect`, MUST NOT produce any `expect_ablated`
outside an explicit test-only ablation mode, and MUST answer byte-identically under any
shuffling of registrars, claims, recognition edges and pins.

The reference implementation (TypeScript, in the NOMOS platform) runs all 16 vectors, the
necessity table (each attack succeeds under exactly its own ablation and under no other), and
the shuffle check in CI. **An independent implementation that passes this file is the condition
for NOMOS-SPEC-014 leaving Draft** — see [IMPLEMENTING.md](../IMPLEMENTING.md). We invite one.
