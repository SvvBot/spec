# NOMOS-SPEC-013: Authority Registries

**Status:** Draft
**Version:** 0.1.0
**Proposed:** 2026-11-07
**Authors:** Safehaven AI Corp. / NOMOS Protocol Working Group
**Uses:** NOMOS-SPEC-001, NOMOS-SPEC-004, NOMOS-SPEC-005, NOMOS-SPEC-006, NOMOS-SPEC-007, NOMOS-SPEC-008, NOMOS-SPEC-010

---

## Abstract

An **authority registry** publishes sealed artifacts (laws, regulations, standards, institutions'
policies) so that agents can find the ones that govern what they are about to do, and ask them.
This specification says how a registry publishes what it offers so that nobody has to trust the
registry's database to rely on it:
- a **catalogue** of every listed authority, signed and mirrorable;
- an append-only, hash-chained **log** of every change to what it offers, with a signed head, so a
  client holding an earlier head can tell whether history was rewritten;
- what each catalogue record says about **standing** (who stands behind a version) and **evidence**
  (how well it holds up), kept apart;
- how a caller **declares who is asking**, what a registry records and what it may show publicly;
- how an agent **finds** an authority from a description, and **requests** one that isn't listed.

A registry evaluates nothing new: queries are answered as in NOMOS-SPEC-005, and a sealed artifact
verifies offline as in NOMOS-SPEC-001 and NOMOS-SPEC-010 whether or not the registry exists.

## 1. Terminology

The key words MUST, MUST NOT, SHOULD and MAY are to be read as in RFC 2119.

- **Registry:** a service that lists sealed artifacts and answers queries against them.
- **Authority:** a listed artifact, known by its **name**.
- **Name:** lowercase ASCII letters, digits and `-`, optionally in `/`-separated segments
  (`eu-ai-act`, `uae/cbuae/consumer-protection`). A registry MAY accept a `.nomos` suffix on input
  and MUST NOT include it in a name it publishes.
- **Version:** the artifact's own sealed `meta.version`. Distinct from the version of the source text
  it was compiled from, which a record MAY name under `source`.
- **Platform key:** an Ed25519 key the registry publishes at `/.well-known/nomos-signing-keys`
  (NOMOS-SPEC-001, NOMOS-SPEC-010). A registry keeps publishing a retired platform key for as long as
  anything signed with it is listed.
- **JCS:** RFC 8785.

## 2. The catalogue

`GET /.well-known/nomos-authorities` returns one JSON object:

| Member | Meaning |
|---|---|
| `catalogue` | `"nomos-authorities"` |
| `spec` | this specification and its status, e.g. `"NOMOS-SPEC-013 (Draft)"` |
| `generated_at` | RFC 3339 UTC time it was built |
| `base` | the registry's base URL (§2.2) |
| `log_head` | `{ size, hash }`: the log head (§3) this catalogue reflects |
| `authorities` | an array of authority records (§2.1), one per listed authority |
| `algorithm` | `"Ed25519"`, or `null` when unsigned |
| `kid` | the platform key that signed it, or `null` |
| `signature` | base64 Ed25519 signature, or `null` |

**Signature.** The signature is over the UTF-8 JCS of the object **without** `algorithm`, `kid` and
`signature`. A client verifies it with the platform key named by `kid`. A registry without a platform
key MUST set all three to `null` and MAY add a `note`; a client MUST treat such a catalogue as
unauthenticated.

A registry SHOULD serve the catalogue with a short cache lifetime (60 seconds is RECOMMENDED) and MAY
serve the same signed document for that long.

### 2.1 Authority records

Each record has at least:

| Member | Meaning |
|---|---|
| `name`, `artifact_id`, `title`, `version`, `seal_hash` | identity of the exact sealed version listed |
| `status` | `listed` (a registry MAY use its own word, e.g. `active`) |
| `standing` | §4 |
| `evidence` | §5 |
| `source` | `{ document, sha256, obtained_from, verification_note, identifiers }`: the source text, its hash, where the copy came from, what the hash proves, and official identifiers |
| `usage` | `{ queries_30d, named_agents_30d }`: production queries (§6) in the last 30 days, and how many distinct agents named themselves |
| `endpoints` | `{ query, schema, atlas, transcripts, page }`: absolute URLs under `base` |

`identifiers` holds the source's own official identifiers, where their format is known, and nothing
invented. For a Regulation of the European Union: `eli` (`http://data.europa.eu/eli/reg/YYYY/N/oj`)
and `celex` (`3YYYYRNNNN`). A registry MUST NOT use an official identifier as a name.

### 2.2 Base

`base`, and every URL derived from it, MUST come from the registry's configuration, never from the
request (its `Host` or forwarded-host headers). The catalogue is signed, and a signed document must
not name whatever host a caller sent.

## 3. The log

Every change to what a registry offers is an entry in one append-only log.

### 3.1 Entries

| Member | Meaning |
|---|---|
| `seq` | 1, 2, 3, … with no gaps |
| `kind` | `baseline`, `listed`, `withdrawn`, `attested`, `attestation_revoked` or `revoked` |
| `name`, `version`, `seal_hash` | the authority and exact version concerned (`version`/`seal_hash` MAY be `null`) |
| `entry` | a JSON object with kind-specific detail (§3.2) |
| `at` | RFC 3339 UTC time of the change |
| `prev_hash` | the previous entry's `hash`; for `seq` 1, 64 `0` characters |
| `hash` | lowercase hex SHA-256 of the UTF-8 JCS of `{ seq, kind, name, version, seal_hash, entry, at, prev_hash }` |

A registry MUST append entries in `seq` order with each `prev_hash` equal to the previous `hash`, and
MUST serialise appends so that no two entries share a `seq` and the chain never forks. Recording a
change in the log MUST NOT be a condition for the change itself: if an append fails, the registry
records the failure and the next append still extends the chain.

### 3.2 Kinds

- `baseline`: written once, when a registry starts its log, for each authority already listed. Its
  `entry` SHOULD say `listed_before_log: true`. A registry MUST write the baseline before any other
  entry.
- `listed` / `withdrawn`: an authority version became, or stopped being, available to query.
- `attested` / `attestation_revoked`: a third party co-signed this exact version (NOMOS-SPEC-004), or
  withdrew it. `attested` SHOULD carry the attester, its role and statement, and the signature, `kid`
  and `algorithm`, so the attestation can be checked against the attester's published key without
  asking the registry.
- `revoked`: the issuer revoked this exact sealed version (NOMOS-SPEC-006). It SHOULD carry the reason
  and the revocation statement's signature and `kid`.

A registry MUST NOT write an entry for a change that didn't change what it offers (for example, a
status set to the value it already had).

### 3.3 Reading the log

- `GET /.well-known/nomos-exchange-log?after=<seq>&limit=<n>` returns `{ log, after, entries, next? }`
  with entries after `seq`, oldest first, at most `limit` (a registry MAY cap it; 1000 is
  RECOMMENDED). `next` is present when more entries follow.
- `GET /.well-known/nomos-exchange-log/head` returns `{ size, hash, at, algorithm, kid, signature }`:
  `size` is the last `seq` (0 for an empty log), `hash` its `hash` (64 zeros when empty), signed with a
  platform key over the UTF-8 JCS of `{ log: "nomos-exchange-log", size, hash, at }`.

### 3.4 What a client checks

A client that wants to rely on the registry's history:
1. Reads every entry, recomputes each `hash`, and checks every `prev_hash` and `seq` (§3.1).
2. Reads the head, checks that `hash` is the hash of entry `size`, and verifies the signature.
3. If it kept an earlier head `(size₀, hash₀)`, checks that entry `size₀` of today's log has hash
   `hash₀`. If not, history was rewritten.
4. Checks that the catalogue's `log_head` is a point on this chain.

A hash chain lets a client that holds an earlier head detect a rewrite by replaying forward. It doesn't
give a client a short proof that one entry is included without downloading the log; Merkle-tree
inclusion and consistency proofs (in the manner of RFC 9162) are the upgrade path (§10).

## 4. Standing

`standing` says who stands behind this exact version:

| Member | Meaning |
|---|---|
| `level` | `compiled`, `published` or `issued` |
| `summary` | the level in plain words, for a person |
| `publisher` | who listed it |
| `signed_by` | `{ kid, algorithm, platform_key }`: the seal's key, and whether it is a platform key |
| `attestations` | live attestations of this exact version (NOMOS-SPEC-004): attester, role, statement, time |

- `compiled`: compiled by the registry operator from public text. The `summary` MUST say the issuing
  authority didn't issue or endorse it.
- `published`: listed by an organisation other than the operator.
- `issued`: sealed by the issuing authority itself, with a key whose certificate chain (NOMOS-SPEC-007)
  resolves to that authority's own root. A registry MUST NOT report `issued` without verifying that
  chain, and MUST NOT infer it from the seal's key merely not being the current platform key: it
  compares against every platform key it publishes, current and retired.

Standing MUST NOT be derived from evidence, nor evidence from standing.

## 5. Evidence

`evidence` says how well a version holds up, measured by tools anyone can run on the artifact:

| Member | Meaning |
|---|---|
| `rules` | how many rules |
| `unconditional_rules` | rules whose condition is vacuous (`always == true`, `true`, empty): they apply to every query |
| `open_verifier` | `{ artifact_evaluable, evaluable_rules, unevaluable_rules, by_reason }` |
| `lint` | `{ errors, warnings, findings[] }`, each `{ level, code, message, count }` |

`open_verifier` reports what a NOMOS-SPEC-008 relying party can evaluate. A rule is unevaluable if its
outcome is neither a ruling (`allow`, `block`, `escalate`) nor an obligation (NOMOS-SPEC-008 §6.0), or
if its condition does not parse. One unevaluable rule makes the whole artifact unevaluable for an
Act-verifying relying party, so `artifact_evaluable` is `true` only when `unevaluable_rules` is 0.
`by_reason` counts them by cause (e.g. `outcome_set`).

`count` in a lint finding is the number of rules it names, or `null` when the finding doesn't name
rules. A client MUST NOT read `null` as zero.

Evidence is a property of the sealed artifact and MUST NOT change while the seal doesn't.

## 6. Who is asking

### 6.1 Declaring

A caller MAY declare who is asking on any query:
- in headers, on any query route: `X-Nomos-Agent` (an agent name), `X-Nomos-Acts-For` (who it acts
  for), `X-Nomos-Purpose` (`production` or `test`);
- in a `caller` object `{ agent_id, acts_for, purpose }` where the query body has a place for it (on
  routes whose facts share the body's top level, `caller` is the caller only when it is an object and
  the artifact doesn't read a fact named `caller`; it is then removed before evaluation).

A registry normalises labels to printable text of at most 120 characters, and SHOULD strip anything
that reads as a URL.

### 6.2 Recording

A registry records, with each query: `agent_id`, `acts_for`, `purpose` (default `production`),
`caller_kind` (`web`, `sdk`, `mcp` or `api`, by how the query arrived) and `identity`:
- `declared`: the names were chosen by the caller and not verified;
- `key`: an API key established the account, and the caller asked to be named (it sent `acts_for`);
  `acts_for` is the key's account, never the claim;
- `key_private`: an API key established the account; not to be shown publicly;
- `anonymous`: nothing was said.

These fields describe the asker, not the decision, and MUST NOT be included in the transcript's audit
hash (NOMOS-SPEC-005): a verifier recomputes that hash from the decision alone.

### 6.3 Test traffic

A query with purpose `test` MUST be answered and sealed exactly as any other. It MUST NOT appear in
public history, and MUST NOT count in any public count (§2.1 `usage`).

### 6.4 What may be shown publicly

In public history and on a transcript anyone can fetch:
- an `agent_id` MAY be shown, marked with its `identity`;
- `acts_for` MUST NOT be shown unless `identity` is `key`. A declared organisation is never shown,
  since anyone could claim to act for a ministry, and an API key's account is private unless the
  caller asked to be named.

### 6.5 Verified identity (not yet specified)

A caller presenting a statement signed with a key that chains (NOMOS-SPEC-007) to its institution's
root would let a registry record `verified`. This version does not define that statement.

## 7. Finding an authority

A registry SHOULD offer `GET <base>/api/exchange/find?q=<description>&jurisdiction=<tag>&limit=<n>`
returning `{ query, jurisdiction, query_terms, matches[], requested[], next? }`. Each match has
`name`, `title`, `score`, `matched_terms`, `facts` (the inputs it reads that match the description:
what to supply) and `rules` (the most relevant rules, each with where it comes from in the source),
and `ask` (the query and schema URLs). `requested` lists matching requests (§8) not yet listed. With
no match, `next` says how to request one.

Ranking is the registry's own. It SHOULD be deterministic for a given catalogue, so that the same
description finds the same authorities.

## 8. Requesting an authority

A registry MAY accept requests for authorities it doesn't list:
- `POST <base>/api/exchange/requests` with `{ title, jurisdiction?, source_url? }` (`source_url` http
  or https only) returns the request with its count;
- `GET <base>/api/exchange/requests` lists them, most requested first.

Requests for the same authority in other words SHOULD be one request. Each asker SHOULD count once.
A registry SHOULD prefer undercounting to overcounting: a name the caller chooses MUST NOT make one
asker count as several. A request never creates an authority; only an issuer, or the operator
compiling public text, can.

Request titles are free text from anyone. A registry that shows them to people SHOULD show only those
it has reviewed, and its API SHOULD say which are (`reviewed`).

## 9. Security considerations

- **A rewritten log** is detectable only by a client that kept an earlier head (§3.4). Clients that
  rely on a registry's history SHOULD keep the last head they checked, and mirrors SHOULD publish the
  heads they have seen.
- **A registry withholding entries** (serving different logs to different clients) is not detected by
  a hash chain alone. Comparing heads across mirrors, or gossip as in Certificate Transparency,
  addresses it; this version doesn't specify either.
- **Declared identity is a claim.** Nothing in §6 authenticates an agent. A relying party that needs
  to know who acts uses an Act (NOMOS-SPEC-008), not a query's caller record.
- **Catalogue base** is fixed by configuration (§2.2), so a signed catalogue can't be made to point
  elsewhere by a forged host header.
- **Privacy.** Public history reveals that an authority was asked, by whom if they named themselves,
  and the redacted facts (NOMOS-SPEC-001 §4.8.1). §6.4 keeps organisations private by default.

## 10. Open questions

- Merkle inclusion and consistency proofs for the log, and signed heads that commit to them.
- A verified caller identity statement (§6.5).
- "As of" queries: answering with the version in force at a past date (NOMOS-SPEC-003).
- Mirrors: how a mirror republishes the catalogue and log, and how clients compare heads.
- Source ingestion from Akoma Ntoso where an issuer publishes it.

## 11. Conformance

This Draft has one implementation (the NOMOS platform: the catalogue, log, caller identity, search
and requests of the NOMOS Exchange, with a zero-dependency log verifier). It makes no interoperability
claim until a second, independent implementation exists.
