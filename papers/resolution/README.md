# Evidence for "Resolve the Law, Not the Catalogue" (Computable Authority, Part III)

Everything here runs offline, with no secrets.

| File | What it is |
|---|---|
| `lean/Composition.lean` | Parts II and III end to end: a resolution commit, with each member verified by Part II's verifier, implies every in-force, in-scope authority is legitimate and current and its rules on the true facts permit the act (imports Resolution and Sufficiency) |
| `lean/Resolution.lean` | A mechanized model of NOMOS-SPEC-014 resolution and the combined verdict, written to follow the reference resolver step by step for one query. Lean 4.35, core library only, standard axioms only. |

## What is proved

| Theorem | In plain words |
|---|---|
| `combAll_perm`, `commits_combAll` | The combined verdict does not depend on the order authorities are checked in, and it commits only if every member commits. |
| `paper_comb_unsafe` | The draft paper's order (ESCALATED above INCOMPLETE) would commit while one member is still undecided. SPEC-014 §4 uses the safe order. |
| `sufficiency`, `full_commit` | A commit means every reached registrar was present, had a current covering closure and nothing undecided, and every live, in-scope claim it makes on the context names an authority whose verdict commits. |
| `decide_ignores_presented` | C5 by construction: the authorities an Act names are not an input to resolution. |
| `stricter_safe`, `reached_mono`, `add_claim_keeps_law` | More law is never less safe: reaching more registrars, or an extra claim from any key, never removes a check. |
| `noC6_never_commits_more` | Dropping C6 can only add law, so C6 prevents wrongful refusals, not wrongful commits. |
| `noC7_never_commits_more`, `C7_necessary_snapshot` | Ignoring currency altogether only adds law; judging membership at a stale instant commits under superseded law. The second is the C7 attack. |
| `C5_necessary`, `C8_necessary_unreachable`, `C8_necessary_stale` | Each condition is necessary: dropping it commits a sanctioned payment, from genuine entries alone. |
| `withdrawal_hides_law` | SPEC-014 0.1.0 read a closure's age but not its list, so a genuine withdrawal hid law under a closure that still named it. Fixed in 0.2.0 (closure agreement). |
| `hiding_needs_new_closure` | Under closure agreement, law a current closure names cannot be dropped without signing a new closure that omits it. |
| `stale_view_commits` | A cached copy of a log whose closure is still inside its bound commits under superseded law; no 0.1.0 check sees it. Fixed in 0.2.0 by the view-age bound, which this model does not cover. |

## Not proved here

- The walk over pins and recognition edges: theorems are stated for the registrars the walk reached (`WalkComplete` states what it must deliver; the reference resolver's tests check it).
- Log heads, signatures, forks and the view-age bound.
- The meaning of CONFLICT beyond its definition (exclusive claims from two registrars).

```
cd lean && lean Resolution.lean    # Lean 4.35; prints the axioms each main theorem uses
cd .. && lake build Composition    # Parts II and III together
```
