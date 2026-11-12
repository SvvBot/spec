# Evidence for "Authorize the Act, Not the Agent" (Computable Authority, Part II)

Everything here runs offline, with no secrets. The keys come from the published seeds of the SPEC-008 test vectors; never use them as trust material.

| File | What it is |
|---|---|
| `act_verify_040.py`, `generate_040.py`, `vectors_040.json` | SPEC-008 0.4.0 reference verifier, generator and 29 vectors, frozen byte-for-byte from commit `c8fa382` (the 0.5.0 versions are in `../../act-vectors/`) |
| `ablate.py` → `ablation-results.json` | §7.1: removes one obligation at a time from the 0.4.0 verifier and presents an attack built from genuine statements (12/12 witnessed, plus the certificate-order ablation) |
| `modelcheck2.py` → `modelcheck2-results.txt` | §7.2: small-scope check of omission safety over random prioritized rule sets, for the 0.4.0 gate, the 0.5.0 gate and a two-valued control |
| `modelcheck.py` → `modelcheck-results.txt` | an earlier run where every escalation shares one identity; it cannot see the 0.4.0 gap, which is why the gap survived earlier testing |
| `lean/Chain.lean` | NOMOS-SPEC-007 chain resolution as the reference resolver performs it: Proposition 2 (no amplification) and Proposition 3 (revocation is complete) proved; a gap in rev. 1.8–1.10 (key purpose is checked per key, so a sealing key certifies witness and approver keys) shown as a counterexample, and the fix (statement terms only directly under the root) proved to keep every sealing key off every statement key's path. Proposition 4 (order independence) is not modelled: it fails in the reference resolver when two certificates differ only in signature (reproduced in TypeScript) |
| `lean/Completeness.lean` | §5.4 and §5.6: the deciding decision exists, is unique and is computed by one pass (`pick`); Theorem 8 (completeness under disclosure: all read inputs present and in-domain means no condition is undecided, the gate cannot fire, and a truthful carrier gets exactly the rules' verdict on the truth); Theorem 10 (reproducibility: the outcome is a function of the authority and the facts) |
| `lean/Sufficiency.lean` | §5.3: Theorem 7 (sufficiency): an AUTHORIZED verdict implies S1–S5, with S2 composed from Proposition 1; and the necessity of C1.1, C1.2, C2.1, C2.2, C3 and C4 as counterexamples from genuine statements. S1 and S3–S5 follow from the checks under A1, A2, A4 and a collision-resistant binding digest (hypotheses); chain resolution (Propositions 2–4) is the relying party's `recognized` function, tested by the SPEC-007 vectors, not modelled |
| `lean/CarriedAuthority.lean` | §5: Proposition 1 (omission safety) for the 0.5.0 gate, the never-DENIED corollary, and the 0.4.0 counterexample (vector 30), mechanized in Lean 4 (core only, no Mathlib) |
| `pub_lending_v1.nomos` | the generator's input policy, copied from `../../act-vectors/` |

```
pip install cryptography
python3 ablate.py vectors_040.json      # 12/12 necessity witnesses; rewrites ablation-results.json identically
python3 modelcheck2.py 20000 2026       # ~17 minutes; reproduces modelcheck2-results.txt
cd lean && lean CarriedAuthority.lean   # Lean 4.35; prints nothing on success
cd .. && lake build Sufficiency           # Theorem 7 and the six necessity counterexamples (imports CarriedAuthority)
lake build Completeness                   # Theorems 8 and 10
lake build Chain                          # Propositions 2-3, and the key-purpose gap
cd ../../../act-vectors && python3 check.py vectors.json   # 32/32 under SPEC-008 0.5.0
```
