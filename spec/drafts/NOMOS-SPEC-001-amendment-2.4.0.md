# NOMOS-SPEC-001 Amendment 2.4.0: Comparisons Between Two Fields

**Status:** Draft (proposed amendment)
**Version:** 2.4.0 (amends 2.3.0)
**Proposed:** 2026-11-03
**Authors:** Safehaven AI Corp. / NOMOS Protocol Working Group

---

## Abstract

A rule often compares two facts, not a fact and a constant: "no purchase may exceed the remaining
budget" is `amount > budget_remaining`. §4.1 shows such a comparison in its own example
(`fee_cap`), but never says what an unquoted identifier on the right-hand side means. Two
implementations read it two ways. The reference verifier of NOMOS-SPEC-008 reads it as a field.
The reference deployment's server evaluator read it as the literal string `"budget_remaining"`,
under which the rule could never fire. Under the second reading, the same sealed artifact allowed a
purchase through `can()` that an Act refused. This amendment fixes the meaning.

## Change to §4.1 (normative)

Add after the paragraph on `in`, `contains` and `between`:

> **A right-hand operand that is a single unquoted identifier, other than `true`, `false` and
> `null`, is a reference to another field**, read from the same inputs as the left-hand side:
> `amount > budget_remaining` compares the two facts. A string constant MUST be quoted
> (`payment_type == "treasury_deal"`). An unquoted comma-joined list on the right of `in` or
> `between` remains one string, as before.
>
> The referenced field is read like any other. A runtime MUST NOT treat an absent referenced field
> as false: under NOMOS-SPEC-008 §6.2 the comparison is UNDECIDED, and an evaluation that reports
> missing inputs MUST name the referenced field among them. A producer MUST declare the referenced
> field in `data_contract.inputs` (§3.5) like any field a rule reads.

## Compatibility

An artifact that used an unquoted word on the right-hand side as a string constant changes meaning.
Conformant producers have always quoted string constants (§4.1 examples; the reference Studio
quotes every string), so the change affects only hand-written artifacts that relied on an
undefined reading. NOMOS-SPEC-008 relying parties already read the operand as a field, so for them
nothing changes.

## Test

`scripts/test-field-references.ts` in the reference deployment checks that the server evaluator
and `@nomosprotocol/verify` give the same result on the same artifact.
