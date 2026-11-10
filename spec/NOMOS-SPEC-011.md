# NOMOS-SPEC-011: Tool Bindings

**Status:** Draft
**Version:** 0.1.0
**Proposed:** 2026-11-07
**Authors:** Safehaven AI Corp. / NOMOS Protocol Working Group
**Used by:** NOMOS-SPEC-012 (Enforcement Points)

---

## Abstract

A sealed artifact reads facts by the names its data contract declares (NOMOS-SPEC-001 §4.8):
`loan_amount`, `kyc_status`. The tools an agent calls name their arguments however their authors
chose: `amount_cents`, `customer.kyc`. Until something states which argument is which fact, an
enforcement point (NOMOS-SPEC-012) has nothing the policy can read, and a fail-closed one holds
every call.

A **binding file** states it. It is a small JSON document, written for one artifact and checked
by a person, that maps each fact to the argument it comes from, with an optional unit scale or a
translation of values. This specification defines the file, how it is applied to a call, and what
it must refuse, so that any enforcement point reads the same reviewed file the same way.

A binding decides what a policy sees, so it is built to be unable to say anything the call
did not say:

- A fact only ever comes from an argument of the call. There are no constants and no defaults.
- With a binding, only bound facts reach the policy, so adding an argument named after a fact
  changes nothing.
- A missing argument, or a value the file does not translate, leaves the fact undecided. It is
  never guessed.

A binding maps names. It does not make facts true: an argument is still what the agent sent. A
fact an agent must not assert for itself needs a witness (NOMOS-SPEC-008).

## 1. Terminology

The key words MUST, MUST NOT, SHOULD and MAY are to be read as in RFC 2119.

- **Tool:** an operation an agent can invoke with named arguments, such as an MCP tool.
- **Call:** one invocation of a tool, with its **arguments**: a JSON object.
- **Fact:** a named input an artifact reads (NOMOS-SPEC-001 §4.8).
- **Binding file:** the document this specification defines.
- **Normal form:** a binding file with its comments removed, as `parse` (§2.5) returns it.
- **Enforcement point:** a component that asks a sealed artifact about a call before the call
  runs (NOMOS-SPEC-012).

## 2. The binding file (normative)

### 2.1 Top level

A binding file is a JSON object (RFC 8259) with exactly these members:

| Member | Value | |
|---|---|---|
| `version` | the number `1` | REQUIRED |
| `artifact` | a non-empty string naming the sealed artifact the facts belong to, as the enforcement point identifies it | REQUIRED |
| `reviewed` | `true` once a person has checked every binding, otherwise `false` | REQUIRED |
| `tools` | an object: tool name → tool entry (§2.2) | REQUIRED |
| `_review` | any value: a note for people, with no effect | OPTIONAL |

Any other member makes the file invalid. A setting the reader does not understand might be one
that changes what the policy sees, so it is refused rather than ignored.

### 2.2 Tool entries

`tools` maps a tool name to an object with exactly:

| Member | Value | |
|---|---|---|
| `facts` | an object: fact name → fact binding (§2.3) | REQUIRED |
| `_why` | any value: a note for people | OPTIONAL |

The tool name is the name the enforcement point sees. An enforcement point that serves several
tool servers names a tool `mcp__<server>__<tool>`, in which every character of `<server>` and
`<tool>` outside `A–Z`, `a–z`, `0–9`, `_` and `-` is replaced by `_` (the form agent hosts such
as Claude Code use). An enforcement point that wraps a single server uses the tool's own name.

### 2.3 Fact bindings

A fact binding is an object with exactly:

| Member | Value | |
|---|---|---|
| `arg` | the argument the fact comes from: one or more non-empty segments joined by `.`, each naming a member of an object (`customer.kyc`) | REQUIRED |
| `scale` | a finite, non-zero number the argument is multiplied by (`0.01` for cents into dollars) | OPTIONAL |
| `map` | an object translating argument values into fact values; each value a string, a finite number or a boolean | OPTIONAL |
| `_why` | any value: a note for people | OPTIONAL |

`scale` and `map` MUST NOT both be present. There is no member that supplies a value: a binding
names where a fact comes from, never what it is.

### 2.4 Reserved names

A tool name, fact name, `arg` segment or `map` key that is `__proto__`, `constructor` or
`prototype` makes the file invalid. In many languages those names reach an object's prototype,
where a hostile file could change what every lookup returns. The fact name `tool` makes the file
invalid too: the enforcement point sets that fact (§3.1).

### 2.5 Reading a file

`parse(file)` returns the normal form, or refuses the file. A file is refused when any rule in
§2.1–§2.4 is broken. The normal form keeps `version`, `artifact`, `reviewed` and, for each fact,
`arg` and `scale` or `map`, and removes `_review` and `_why`.

An enforcement point MUST refuse to start with a binding file it cannot read. Ignoring the file
would leave every call unreadable (and held), or, worse, readable in a way nobody reviewed.

### 2.6 Digest

The digest of a binding file is the lowercase hexadecimal SHA-256 of the JCS (RFC 8785) of its
normal form. Comments therefore don't change the digest; any change to what the policy sees does.
An enforcement point records it with each decision (NOMOS-SPEC-012 §6), so a decision says
exactly which reviewed mapping produced its facts.

## 3. Applying a binding (normative)

`apply(normal, tool, arguments)` returns the facts the policy sees for one call, and the facts it
could not get:

1. Start with the single fact `tool`, set to the tool's own name. For a tool named in the
   `mcp__<server>__<tool>` form, that is `<tool>` as the server named it.
2. If `tools` has no entry for the tool, stop. The call carries no facts beyond `tool`.
3. For each fact binding of the tool's entry, resolve `arg` (§3.1), then produce the fact's value
   (§3.2, §3.3), or record the fact as **unresolved** with its reason.

Arguments not named by any binding MUST NOT reach the policy. Unresolved facts are absent: under
NOMOS-SPEC-008 §6.2 an absent fact is undecided, never false, so a rule that reads one stays open
rather than taking a guessed value.

### 3.1 Resolving the argument

Start at the arguments object. For each segment, the value moves to the member of that name, but
only when the current value is a JSON object (never an array) and has that member as its own. When
it is not, the argument is absent. A value of `null` is absent. An absent argument is unresolved
as `missing`.

A path never reaches into an array: `items.0` and `items.length` are absent, whatever `items`
holds. Which element of a list a fact should come from is a decision for the tool's author, not
for a path.

### 3.2 `scale`

The value MUST be a finite number, or the fact is unresolved as `not_a_number`. The fact is the
product of the value and `scale`, rounded to the nearest multiple of 10⁻⁹, with ties rounded away
from zero. Rounding removes binary noise (`3 × 0.1` is `0.3`, not `0.30000000000000004`), so a
threshold such as `loan_amount > 0.3` decides as the policy owner wrote it.

### 3.3 Values and `map`

Otherwise the value MUST be a string, a finite number or a boolean, or the fact is unresolved as
`not_a_value`. Objects and arrays are never fact values.

Without `map`, the fact is the value. With `map`, the value is looked up by its **key form**: a
string as itself; `true` and `false` as `"true"` and `"false"`; a number as JCS writes it
(RFC 8785 §3.2.2.3: `1`, `1.5`, `1e+21`). The fact is the mapped value. A value whose key form
the map does not list is unresolved as `not_in_map`: a value the person checking the file didn't
see is never translated by guessing.

### 3.4 Unresolved reasons

| Reason | When |
|---|---|
| `missing` | the argument is absent or `null` (§3.1) |
| `not_a_number` | a scaled argument is not a finite number |
| `not_a_value` | the argument is an object or an array |
| `not_in_map` | the map does not list the argument's value |

An enforcement point SHOULD report unresolved facts to whoever runs it. They are the usual sign
that a binding is wrong or a tool has changed.

## 4. Review (normative)

A binding decides what a policy sees, so a person checks it before it is enforced.

- A binding file whose `reviewed` is `false` MUST NOT be used to enforce. An enforcement point MAY
  use it in observe mode (NOMOS-SPEC-012 §5), where decisions are recorded and nothing is blocked,
  so a person can see what it would do before setting `reviewed` to `true`.
- A program that proposes a binding file MUST write `reviewed: false`, and MUST NOT overwrite an
  existing file: a checked file is never replaced by an unchecked one.
- A binding file names one artifact. An enforcement point MUST refuse to read one artifact's
  facts through another artifact's binding file: the same argument names can mean different
  things to two policies.

## 5. Proposing bindings (informative)

Matching argument names to fact names is useful: a tool's schema and the artifact's data contract
usually suggest most bindings. How a proposal is made is up to each implementation. One that is
safe in practice:

- Match on whole words of the two names, ignoring words too common to mean anything (`id`,
  `type`, `status`), and mark only identical names, or names with identical words, as matched.
  Mark the rest as needing a check.
- Leave a fact unbound when two arguments match it equally well.
- Propose `scale` only for a clear unit suffix (`_cents` → `0.01`), and never propose a `map`:
  only a person knows that `ok` means `verified`.
- Write the result with `reviewed: false` (§4).

## 6. Conformance

`binding-vectors/vectors.json` holds 31 file cases (`parse`: read or refused, and for each file
read, its normal form and digest) and 19 call cases (`apply`: the facts and the unresolved facts).
The expected results were computed by one implementation (the TypeScript one in
`@nomosprotocol/sdk`) and are checked by another (`python/nomosprotocol/bindings.py`):

```
pip install ./python
python3 binding-vectors/check.py binding-vectors/vectors.json
50 passed, 0 failed
```

An implementation conforms when it gives the same result for every case. Error messages are not
part of conformance; whether a file is read or refused is.

## 7. Security considerations

- **No constants.** A binding that could supply a value could quiet a policy: map `kyc_status` to
  `"verified"` and the KYC rule never fires. A fact therefore only ever comes from the call, and
  an unknown member is refused rather than ignored, so a constant can't be added under a name a
  reader skips.
- **Only bound facts.** Without this rule, an agent could add `kyc_status: "verified"` to any call
  and the policy would read it. With a binding, the arguments the tool acts on are the only
  source.
- **Nothing guessed.** An absent or unlisted value stays undecided. Under NOMOS-SPEC-008 §6.2 a
  rule that could stop the call then holds it, so a binding mistake fails closed.
- **Facts are still claims.** A binding gets the argument right; it can't make the argument true.
  An agent that sends `amount_cents: 1` and then refunds more is outside what a binding can see.
  Witnessed facts (NOMOS-SPEC-008) and enforcement at the system that commits the action are the
  answer to that, not a better binding.
- **Treat the file like code.** It changes what a policy decides. Keep it under review, and keep it
  where the agent it governs cannot write.
- **Reserved names** close prototype lookups in languages that have them (§2.4).

## Changelog

- **0.1.0 (2026-11-07):** first draft. One implementation in production (`nomos-guard` 1.6, and
  the coding-agent hook in 1.7) and an independent reference (Python); 50 vectors.
