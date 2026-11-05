# NOMOS-SPEC-011: Source Coverage

**Status:** Draft
**Version:** 0.1.0
**Extends:** NOMOS-SPEC-001
**Proposed:** 2026-11-06
**Authors:** Safehaven AI Corp. / NOMOS Protocol Working Group

---

## Abstract

A sealed artifact states rules. It does not state what became of the rest of the policy it was
compiled from. An artifact with 381 correct rules can still omit an obligation, and nothing in the
artifact shows it.

This specification adds `source_coverage`: the issuer's sealed account of every obligation it
identified in each source document, and what became of each one. An obligation is a rule, part of
another rule, a decision the source reserves for a person, or background. Every rule names the
obligations it formalises, by id, and every obligation carries the words it was read from. A verifier
checks the account offline: every reference resolves in both directions, nothing is left
unaccounted, and every classification that could hide an omission was confirmed by a named person.
Given the source document, the verifier also checks that every quoted obligation occurs in it.

Coverage changes no verdict. It is evidence about how the authority was made.

## 1. Terminology

The key words MUST, MUST NOT, SHOULD and MAY are to be read as in RFC 2119.

- **Source document:** a text an issuer compiled rules from, identified by the SHA-256 of the text
  as the issuer read it.
- **Obligation:** one or more consecutive sentences of a source document that require, forbid or
  permit something, set a threshold, a deadline or an authority, or make an exception to one of these.
- **Quote:** the exact words of an obligation, as they appear in the source document.
- **Status:** what became of an obligation (§3.2).
- **Binding wording:** language that obliges, forbids or conditions (§5).

## 2. Placement

`source_coverage` is a top-level member of the artifact. It is inside the seal: it is covered by the
artifact hash of NOMOS-SPEC-001 and changes it, unlike `attestations` (NOMOS-SPEC-004 §2.1), because
it is the issuer's own statement about the artifact rather than a later endorsement by someone else.

An artifact without `source_coverage` makes no coverage claim and is otherwise unaffected.

## 3. Structure (normative)

```json
"source_coverage": {
  "version": "0.1.0",
  "documents": [
    {
      "source_sha256": "<hex SHA-256 of the source text as read>",
      "name": "Lending Policy v4.pdf",
      "quotes": "plain",
      "obligations": [
        {
          "id": "U12.2",
          "section": "2.2.8",
          "kind": "obligation",
          "quote": "For all loan applications above ₹5 crores, the rejection of proposal will be made by the next higher level to the sanctioning authority.",
          "status": "rule",
          "rule_ids": ["R2"]
        },
        {
          "id": "U12.3",
          "section": "2.2.8",
          "kind": "exception",
          "quote": "However, this is not applicable for proposals falling under the authority of MD/Management Credit Committee.",
          "status": "part_of_rule",
          "rule_ids": ["R2"]
        },
        {
          "id": "U7.4",
          "section": "2.2.3.1",
          "kind": "condition",
          "quote": "Repayment capacity of the borrower will be one of the prime consideration while evaluating credit proposals.",
          "status": "reserved",
          "decided_by": "the sanctioning authority",
          "rule_ids": [],
          "needs_confirmation": true,
          "review": { "decision": "confirm", "by": "credit.policy@bank.example", "at": "2026-11-06T09:14:00Z" }
        }
      ]
    }
  ]
}
```

### 3.1 Documents

| Member | Required | Meaning |
|---|---|---|
| `source_sha256` | yes | Lowercase hex SHA-256 of the UTF-8 source text the issuer read (after any layout analysis). |
| `name` | yes | A name for people. Not checked. |
| `quotes` | yes | `"plain"`: each obligation carries `quote`. `"hashed"`: each carries `quote_sha256` instead (§3.4). |
| `obligations` | yes | Every obligation the issuer identified in this document, in document order. |

### 3.2 Obligations

| Member | Required | Meaning |
|---|---|---|
| `id` | yes | Unique within the artifact. |
| `section` | no | The section of the source the quote sits in, as the source numbers it. |
| `kind` | yes | `obligation`, `prohibition`, `condition`, `threshold`, `deadline`, `approval`, `exception` or `definition_or_context`. |
| `quote` / `quote_sha256` | yes, per `quotes` | The obligation's exact words, or the SHA-256 of their normalized form (§4.2). |
| `status` | yes | One of: `rule` (a rule formalises it); `part_of_rule` (it is a condition or exception inside another obligation's rule); `reserved` (the source leaves the decision to a person or body; no rule decides it); `context` (background, a definition or an introduction). |
| `rule_ids` | yes | The rules that formalise it. Non-empty for `rule` and `part_of_rule`. For `reserved`, only rules whose every outcome refers the case to a person (escalate or route), never decides it. Empty for `context`. |
| `decided_by` | no | For `reserved`: who the source says decides. |
| `needs_confirmation` | no | `true` when the issuer's process required a person to confirm this classification before sealing (§5). |
| `review` | when `needs_confirmation` | `{ decision, by, at, note? }`: who confirmed or changed the classification, when, and why. `decision` is `confirm`, `reserved`, `context` or `rule`. |

There is no `unaccounted` status. An issuer MUST NOT seal an artifact with `source_coverage` while
any identified obligation has no status.

### 3.3 Rules

Each decision of the artifact (NOMOS-SPEC-001) that formalises obligations carries
`provenance.obligation_ids`: the ids of the obligations it formalises.

### 3.4 Hashed quotes

A source may be confidential while its artifact is shared. With `"quotes": "hashed"`, each
obligation carries `quote_sha256`, the SHA-256 of its quote normalized as in §4.2. A verifier
without the source checks everything in §4.1. A verifier holding the source checks §4.2 by
normalizing every candidate span, which reveals nothing to anyone without the source.

## 4. Verification (normative)

### 4.1 Without the source

A verifier MUST check, for each document, and report every failure:

1. Every `id` is unique; every `status` and `kind` is one of the values in §3.2.
2. Every id in an obligation's `rule_ids` names a decision of the artifact, and that decision lists
   the obligation in `provenance.obligation_ids`. Every id in a decision's `provenance.obligation_ids`
   names an obligation, and that obligation lists the decision in `rule_ids`.
3. `rule` and `part_of_rule` obligations have at least one rule; `context` obligations have none.
4. Every rule of a `reserved` obligation has only outcomes that refer the case to a person.
5. Every obligation with `needs_confirmation: true` has a `review` with `by` and `at`.

An artifact that passes is **coverage-consistent**. The verifier MUST NOT report it as complete:
§4.1 shows the account is whole and internally true, not that the issuer found every obligation.

### 4.2 With the source

Given a source text whose SHA-256 equals `source_sha256`, a verifier MUST also check that every
quote occurs in the text, comparing both after this normalization: Unicode NFC; lowercase; every
character in `“ ” " ' ‘ ’ \` | * _ #` replaced by a space; `–` and `—` replaced by `-`; every run of
whitespace replaced by one space; leading and trailing space removed. For `"hashed"` quotes, it
checks that some span of the normalized text has the given hash.

A verifier SHOULD also run the binding-wording check of §5 over the source and report, as advice and
not as a failure, every sentence with binding wording that no quote covers.

## 5. Binding wording

An issuer SHOULD mark `needs_confirmation` on every obligation whose status is `context` or
`reserved` and whose quote contains binding wording, and on every obligation it found only by a
deterministic check after its first reading. These are where a misfiled obligation hides: a binding
sentence classified as background is never enforced, while the coverage still looks complete.

Binding wording is at least: *shall, must, should, may not, shall not, will not, cannot, never,
required, prohibited, mandatory, not permitted, not allowed, subject to, only if, only when, unless,
except, provided that, not applicable, at least, at most, minimum, maximum, not exceeding, within* followed
by a number, and *will* followed by a verb of action (obtain, approve, sanction, reject, require,
record, review, ensure, grant, …). Implementations MAY recognise more. The list is a floor, not a
definition of obligation.

## 6. What this specification does not claim

Coverage is the issuer's account. It shows that the account is consistent, that every quote is real,
and who confirmed every classification that could hide an omission. It does not prove that the
issuer identified every obligation; §4.2's advisory check narrows that gap, and the named reviewer
answers for the rest.

## 7. Security considerations

- `source_coverage` is inside the seal: changing a status, a quote or a review breaks the seal.
- Plain quotes disclose the source's words. Issuers of confidential sources use `"hashed"`.
- A review records an identity string the issuer asserts. Where the reviewer's identity must be
  proven, the reviewer co-signs the artifact as an attestation (NOMOS-SPEC-004).

## 8. Implementation status

One implementation: NOMOS Studio, which records every element of §3 (obligation extraction, with
per-obligation review before sealing) and does not yet place it in sealed artifacts. Conformance
vectors are to follow with the first implementation that seals coverage. Second implementations are
welcome; open an issue to coordinate vectors.
