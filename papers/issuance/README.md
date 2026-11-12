# Evidence for "Seal the Decision, Not the Document" (Computable Authority, Part IV)

Everything here runs offline, with no secrets.

| File | What it is |
|---|---|
| `lean/Issuance.lean` | A mechanized model of the NOMOS-SPEC-015 issuance-proof decision core, following the reference implementation (`server/lib/issuance.ts`): `Checks.v010` is 0.1.0, `Checks.fixed` is 0.2.0. Lean 4.35, core library only, standard axioms only. |

## What is proved

| Theorem | In plain words |
|---|---|
| `C9_necessary` … `C12_necessary` | Each of the four conditions is necessary: dropping it lets the faithless officer, the stale constitution, the self-certified genesis or the midnight amendment through. |
| `backdating_issues` | **A gap in 0.1.0, closed in 0.2.0.** Currency was judged at ι's own time, which the presenter chooses: a November seal whose ι claims May was issued under April's constitution. 0.2.0 judges currency when the seal was made and bounds ι's time to it. |
| `invented_consents_issue`, `forged_amendment` | **A gap in 0.1.0, closed in 0.2.0.** Consents were counted by their claimed role and holder; the spec only said they SHOULD travel as signed Acts. The officer could write his own quorum, for a seal or for an amendment. 0.2.0 counts only holders certified for the role. |
| `officer_indifference` | For 0.2.0: ISSUED implies the pinned genesis, every amendment issued under its predecessor, ι authorizing exactly this seal at a time within the bound, the constitution in force when the seal was made, and n distinct certified holders over exactly this issuance. |
| `no_proof_no_authority`, `one_key_one_vote` | The sealing key alone mints nothing; one director's key is one vote. |

## Not proved here

- What a constitution requires for an act: SPEC-008's evaluator, assumed here; its omission safety is Part II's Proposition 1.
- Signatures, and how a holder comes to be certified for a role (SPEC-007), stated as `cert`.
- The order of presentation: two constitutions with the same `from` gave different refusals depending on input order in 0.1.0; 0.2.0 refuses such a chain as ambiguous. Tested in TypeScript (vector `ambiguous-in-force-time` and the shuffle check), not modelled.
- Independence: one implementation so far.

```
cd lean && lean Issuance.lean      # Lean 4.35; prints the axioms each main theorem uses
cd ../.. && lake build             # every proof in the series
```
