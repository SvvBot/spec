# NOMOS-SPEC-012: Enforcement Points

**Status:** Draft
**Version:** 0.1.0
**Proposed:** 2026-11-07
**Authors:** Safehaven AI Corp. / NOMOS Protocol Working Group
**Uses:** NOMOS-SPEC-001, NOMOS-SPEC-006, NOMOS-SPEC-008, NOMOS-SPEC-011

---

## Abstract

A sealed artifact says what an agent may do. Something has to ask it before the agent does it.
The strongest answer is the system that commits the action verifying an Act itself
(NOMOS-SPEC-008). Most agents today reach their tools through something else: a **gateway**
between the agent and a tool server, or a **hook** that the agent's own host runs before each
tool call. Both are **enforcement points**.

This specification says what an enforcement point must do to call itself NOMOS-enforcing:
- which calls it governs;
- that it fails closed;
- what each verdict lets through;
- how a call that needs a person is held and resumed: an approval bound to one exact call, used
  once, given by a person and never by the agent;
- how several policies combine;
- what it records.

It also says plainly what each kind of enforcement point can't guarantee, so that nobody buys
containment from a component that only checks calls.

## 1. Terminology

The key words MUST, MUST NOT, SHOULD and MAY are to be read as in RFC 2119.

- **Agent host:** the program that runs an agent and makes its tool calls (an IDE, a CLI agent).
- **Call, arguments, tool:** as NOMOS-SPEC-011 §1.
- **Enforcement point:** a component that, before a call runs, obtains a verdict from a sealed
  artifact and lets the call run or stops it accordingly. This specification names three:
  - **Gateway:** sits between an agent host and a tool server, forwarding the calls it allows.
  - **Agent hook:** a pre-tool hook of the agent host, which can stop a call before the host makes it.
  - **In code:** a service that asks `can()` and acts on the answer. It is an enforcement point
    only of what its own code does.
- **Evaluation:** obtaining the verdict, either locally over a verified artifact (NOMOS-SPEC-008
  §6 semantics) or from a policy service that does so.
- **Verdicts:** `AUTHORIZED`, `DENIED`, `ESCALATED`, `INCOMPLETE`, with NOMOS-SPEC-008 §6
  meanings.
- **Governed call:** a call the enforcement point is responsible for (§3.1).

## 2. What each enforcement point can guarantee (informative)

| Enforcement point | Guarantees | Does not guarantee |
|---|---|---|
| In code | The calling service acts on the verdict, if its code does | Anything about other code paths |
| Agent hook | Every governed call the host makes is checked before it is made | Containment: an agent that can run commands or write files where the hook's settings live can change or remove it. An organisation-installed hook (§3.7) is out of reach of the user's settings, but not of someone who controls the computer |
| Gateway holding the tool's credentials | Every call to that system through those credentials is checked, because the agent has no other way to make it | Calls to systems whose credentials the agent holds itself |
| Relying party (NOMOS-SPEC-008) | The action commits only as an Act the system verified itself, with witnessed facts and signed consents | — |

An enforcement point MUST NOT describe itself as containing an agent unless it holds the only
credential that can make the change. Each one checks facts as the call states them; only
witnessed facts (NOMOS-SPEC-008) are more than the agent's word.

## 3. Required behaviour (normative)

### 3.1 Which calls are governed

- With binding files (NOMOS-SPEC-011), a call is governed by a policy when a reviewed binding
  file for that policy has a tool entry for the call's tool with at least one fact binding.
- A gateway without binding files governs every call to the server it wraps, and passes the
  call's arguments as facts, with `tool` set to the tool's name.

An enforcement point MUST NOT change, delay or stop a call that no policy governs. It SHOULD NOT
contact a policy service about one: what an agent does with tools no policy covers is none of the
policy service's business.

### 3.2 Before the call

For a governed call, the enforcement point MUST complete an evaluation before the call runs, and
MUST let the call run only when the verdict is `AUTHORIZED` (§3.6 for several policies), or when
the call carries a usable approval (§4).

### 3.3 Fail closed

When the evaluation cannot be completed, a governed call MUST NOT run. That covers:
- the policy service being unreachable, timing out, failing or limiting the rate;
- the setup being missing or unreadable;
- the call being in a form the enforcement point cannot read;
- the policy service refusing the request, for example because of a revoked key.

The agent is told the call did not run and why, distinguishing an outage (retry later) from a
refusal (someone must fix the setup).

An enforcement point MAY offer an explicit option to let calls through when the policy service is
unavailable. It MUST be off by default, MUST apply only to unavailability, never to a refusal,
an unreadable call or an unreadable setup, and every call it lets through MUST be recorded as
such.

### 3.4 `DENIED` and `INCOMPLETE`

`DENIED`: the call MUST NOT run. `INCOMPLETE`: the call MUST NOT run. A rule that could stop it
can't be decided from what the call says, and NOMOS-SPEC-008 §6.2 never treats an undecided rule
as passed.

### 3.5 `AUTHORIZED` grants nothing else

An agent host may ask its user before running some calls. On `AUTHORIZED`, an agent hook MUST NOT
answer such a question for the user, or otherwise grant a permission the host would have asked
for. A policy saying a call is permitted is not the user saying they want it now.

### 3.6 Several policies

When more than one policy governs a call, the enforcement point MUST evaluate each, and the
strictest result decides, in this order:

1. `DENIED`, or a rejected approval (§4.3);
2. evaluation not completed (§3.3);
3. `INCOMPLETE`;
4. `ESCALATED`;
5. `AUTHORIZED`.

A call that several policies escalate needs an approval under each (§4.4). The agent is told
every policy that stopped the call.

### 3.7 Organisation and user setups

An enforcement point MAY read setups from two places: one installed for the computer by an
administrator, and one belonging to the user. Then:

- every policy in the computer's setup applies, whatever the user's setup holds;
- for a policy in both, the computer's binding file is used;
- nothing the user controls may change where the enforcement point evaluates a policy from the
  computer's setup. That covers the user's environment variables, their settings, and settings
  the agent can write. Otherwise a user could point it at a service that allows everything;
- the program the hook runs SHOULD be named by its full path, in a location only an administrator
  can change.

### 3.8 What the agent is told

When a call does not run, the agent MUST be told:
- that it did not run;
- which policy stopped it;
- the deciding rule's id and its description as the policy states it;
- for `ESCALATED`, where a person can approve it (§4).

The agent SHOULD also be told not to retry with altered arguments to get around the policy. The
message SHOULD be written for the person using the agent, who usually reads it next.

## 4. Calls that need a person (normative)

### 4.1 Never the agent host's own prompt

An enforcement point MUST NOT turn `ESCALATED` into the agent host's own confirmation, such as
"allow this tool call?". Whoever is at the keyboard is not necessarily the person the policy
names (NOMOS-SPEC-001 escalations: `role_required`, and how many distinct people must consent).
The call is held, and an approval is requested from the people the policy names.

### 4.2 The call digest

An approval is bound to one exact call. The **call digest** is the lowercase hexadecimal SHA-256
of `JCS({ "tool": <tool name>, "args": <the call's arguments> })` over the arguments as the agent
sent them, before any binding is applied. An approval given for one call digest MUST NOT be used
for a call with another. Changing any argument, even one no policy reads, is a different call.

### 4.3 Using an approval

When the same call arrives again, the enforcement point MUST evaluate it again, and MAY use the
approval only when:

1. the new evaluation still escalates;
2. the approval is for this call digest, this policy and this artifact;
3. it was given by enough distinct people holding the role the escalation requires. Each person
   is authenticated as themselves. An agent, an API key or any credential the agent holds MUST
   NOT be able to approve;
4. it has not been used, expired or been rejected. It SHOULD expire within an hour;
5. the artifact has not been revoked since (NOMOS-SPEC-006).

Using an approval consumes it: it lets that call run once. A rejected approval is final for that
call digest, and the agent is told not to retry.

### 4.4 Several approvals

When several policies escalate one call (§3.6), the enforcement point MUST NOT consume any
approval until every one of them has a usable approval, then consumes them all. One approval
isn't used up while another is still pending. If any cannot be consumed, the call does not run.

### 4.5 Waiting

An enforcement point MAY hold the call open while it waits for the answer, for no longer than the
agent host's own timeout. Otherwise it stops the call at once with the approval link, and the
agent retries the same call once a person has answered.

## 5. Observe mode (normative)

An enforcement point MAY run in observe mode: governed calls are evaluated and recorded, and every
call runs. A binding file not yet reviewed (NOMOS-SPEC-011 §4) may only be used in observe mode.
Decisions made in observe mode MUST be recorded as such (§6). Observe mode never requests
approvals, since nothing is held.

## 6. The record (normative)

Each evaluation of a governed call MUST be recorded, by the policy service or by the enforcement
point, with:

| Field | |
|---|---|
| artifact | the artifact's identity, and its seal hash when evaluated locally |
| tool | the tool's name |
| facts | the facts as evaluated, after the artifact's redaction policy (NOMOS-SPEC-001 §3.9) |
| outcome | the verdict, and the deciding rule's id when there is one |
| enforcement | `observe`, `gateway` or `hook` |
| binding digest | when a binding file produced the facts (NOMOS-SPEC-011 §2.6) |
| caller | the agent's identity where known, and for a computer's setup (§3.7), the user and computer the call came from |
| approval | when an approval was used, which one. This MAY be recorded with the approval instead: the call digest it was given for, who gave it, and when it was used |

An enforcement point that evaluates locally SHOULD give each decision an audit hash: the SHA-256
of the JCS of `{artifact seal hash, tool, facts, outcome, rule, binding digest}`. Anyone holding
the artifact and the call can recompute it.

## 7. Conformance

This draft has one implementation: `nomos-guard` 1.7 (its gateway and its agent hook for
Claude Code and Cursor). Its tests exercise each requirement above against a live policy service,
including:
- fail-closed cases;
- the strictest-wins order;
- approvals bound to the call digest and used once;
- several approvals;
- an organisation's setup that the user's environment cannot redirect.

This specification makes no interoperability claim until a second, independent implementation
exists. A checklist of the requirements, for implementers:

| Id | Requirement |
|---|---|
| EP-1 | Calls no policy governs are not changed, and no policy service is contacted about them (§3.1) |
| EP-2 | A governed call runs only on `AUTHORIZED` or a usable approval (§3.2) |
| EP-3 | Fails closed on every case in §3.3; any fail-open option is off by default, covers unavailability only, and is recorded |
| EP-4 | `INCOMPLETE` holds (§3.4) |
| EP-5 | `AUTHORIZED` answers no question of the agent host's (§3.5) |
| EP-6 | Strictest wins across policies (§3.6) |
| EP-7 | A computer's setup can't be loosened or redirected by the user (§3.7) |
| EP-8 | `ESCALATED` never becomes the host's own prompt (§4.1) |
| EP-9 | Approvals bound to the call digest, re-evaluated, given by people with the role, used once, not after revocation (§4.2, §4.3) |
| EP-10 | No approval consumed until all are usable (§4.4) |
| EP-11 | Unreviewed bindings only in observe mode, and observe decisions recorded as such (§5) |
| EP-12 | Every evaluation recorded with the fields in §6 |

## 8. Security considerations

- **Checking is not containment.** §2 is the honest table. A hook is the easiest enforcement point
  to install and the easiest to get around.
- **The agent's word.** Every fact an enforcement point passes is something the agent sent. Bind
  carefully (NOMOS-SPEC-011), and require witnessed facts where it matters (NOMOS-SPEC-008).
- **A shared key is a shared limit.** An organisation that installs one key on every computer
  shares its rate limit. Under §3.3 a limited check holds the call, so a large deployment should
  give groups their own keys.
- **The key in a computer's setup** can be read by every user of that computer, because the hook
  runs as them. It should be a key that can only ask its one policy.
- **Approval links** carry no facts. The approval page shows the call to a signed-in person.

## Changelog

- **0.1.0 (2026-11-07):** first draft, from `nomos-guard` 1.6 (gateway approvals) and 1.7 (agent
  hooks, several policies, organisation setups).
