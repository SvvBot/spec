# NOMOS-SPEC-005 §2.4 test vectors (signed query statements)

`vectors.json`: one published Ed25519 test key and seven transcripts, each with the result a checker
must reach: `hash` (does `audit_hash` recompute), `signature` (`valid`, `invalid`, `unsigned`,
`wrong_key`) and `disagreements` (the fields where the transcript differs from what was signed).

| case | what it shows |
|---|---|
| `valid` | a signed transcript checks |
| `verdict_changed_hash_recomputed` | changing the verdict and recomputing `audit_hash` still differs from the signed statement |
| `inputs_changed` | changed facts break the hash and differ from the statement |
| `rules_evaluated_changed` | the per-rule evaluation is bound through its digest |
| `record_and_statement_rewritten` | rewriting both the transcript and the statement breaks the signature (`audit_hash` alone would pass) |
| `unsigned_legacy` | a transcript from before signing reports `unsigned`, never `valid` |
| `signed_by_another_key` | a statement signed by a key other than the published one is `wrong_key` |

```
node query-statement-vectors/check.mjs        # dependency-free checker, 7/7
node query-statement-vectors/generate.mjs     # regenerate (deterministic, labelled TEST keys)
```

The NOMOS platform's checker (`server/lib/query-statement.ts`, through `@nomosprotocol/verify`)
reaches the same result on all seven.
