# Evidence for "Seal the Decision, Not the Document" (Computable Authority, Part IV)

Everything here runs offline, with no secrets.

| File | What it is |
|---|---|
| `lean/Issuance.lean` | A mechanized model of the NOMOS-SPEC-015 0.1.0 issuance-proof decision core, following the reference implementation (`server/lib/issuance.ts`), and of a fixed core. Lean 4.35, core library only, standard axioms only. |

## What is proved

| Theorem | In plain words |
|---|---|
| `C9_necessary` … `C12_necessary` | Each of the four conditions is necessary: dropping it lets the faithless officer, the stale constitution, the self-certified genesis or the midnight amendment through. |
| `backdating_issues` | **A gap in 0.1.0.** Currency is judged at ι's own time, which the presenter chooses: a November seal whose ι claims May is issued under April's constitution. A bound between ι's time and when the seal was made refuses it. |
| `invented_consents_issue`, `forged_amendment` | **A gap in 0.1.0.** Consents are counted by their claimed role and holder; the spec only says they SHOULD travel as signed Acts. The officer can write his own quorum, for a seal or for an amendment. Counting only holders certified for the role refuses both. |
| `officer_indifference` | For the fixed core: ISSUED implies the pinned genesis, every amendment issued under its predecessor, ι authorizing exactly this seal at a time within the bound, the constitution then in force, and n distinct certified holders over exactly this issuance. |
| `no_proof_no_authority`, `one_key_one_vote` | The sealing key alone mints nothing; one director's key is one vote. |

## Not proved here

- What a constitution requires for an act: SPEC-008's evaluator, assumed here; its omission safety is Part II's Proposition 1.
- Signatures, and how a holder comes to be certified for a role (SPEC-007), stated as `cert`.
- The order of presentation: the implementation sorts constitutions by `from`; two with the same `from` give different results depending on input order (a refusal either way). Tested in TypeScript, not modelled.
- Independence: one implementation so far.

```
cd lean && lean Issuance.lean      # Lean 4.35; prints the axioms each main theorem uses
cd ../.. && lake build             # every proof in the series
```
