// Writes vectors.json for NOMOS-SPEC-005 §2.4 (signed query statements). Deterministic: Ed25519
// keys from fixed, labelled TEST seeds. Dependency-free: node query-statement-vectors/generate.mjs
import crypto from 'node:crypto';
import fs from 'node:fs';
import { jcs } from './jcs.mjs';

const PKCS8_ED25519 = Buffer.from('302e020100300506032b657004220420', 'hex');
const keyFromSeed = (label) => {
  const seed = crypto.createHash('sha256').update(`NOMOS-SPEC-005 TEST KEY ${label} - NOT FOR USE`).digest();
  const privateKey = crypto.createPrivateKey({ key: Buffer.concat([PKCS8_ED25519, seed]), format: 'der', type: 'pkcs8' });
  const publicKey = crypto.createPublicKey(privateKey);
  const der = publicKey.export({ type: 'spki', format: 'der' });
  return { privateKey, pem: publicKey.export({ type: 'spki', format: 'pem' }).toString(), kid: crypto.createHash('sha256').update(der).digest('base64url').slice(0, 16) };
};
const issuer = keyFromSeed('ISSUER');
const other = keyFromSeed('OTHER');
const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');

function record(overrides = {}) {
  const r = {
    object: 'authority_query',
    query_id: 'qry_0000000000000000a001',
    artifact: { id: 'art_example', version: '1.0.0', seal_hash: 'c'.repeat(64) },
    inputs: { risk_classification: 'high_risk', processes_personal_data: true },
    verdict: 'ESCALATED',
    outcome_code: 'RULE_TRIGGERED_ESCALATE',
    matched_rule_id: 'rule-high-risk-review',
    open_higher_priority_count: 2,
    rules_evaluated: [
      { rule_id: 'rule-prohibited', matched: false, outcome_if_matched: 'auto_rejected' },
      { rule_id: 'rule-high-risk-review', matched: true, outcome_if_matched: 'escalated' },
    ],
    evaluator_version: '2026-11-10',
    queried_at: '2026-11-10T09:00:00.000Z',
    ...overrides,
  };
  r.audit_hash = sha256(jcs({ query_id: r.query_id, seal_hash: r.artifact.seal_hash, inputs: r.inputs, verdict: r.verdict, queried_at: r.queried_at }));
  return r;
}
function sign(r, key = issuer) {
  const statement = {
    type: 'nomos.authority_query.statement/1',
    query_id: r.query_id, artifact: r.artifact, inputs: r.inputs, verdict: r.verdict, outcome_code: r.outcome_code,
    matched_rule_id: r.matched_rule_id, open_higher_priority_count: r.open_higher_priority_count,
    rules_evaluated_digest: sha256(jcs(r.rules_evaluated)), evaluator_version: r.evaluator_version,
    queried_at: r.queried_at, audit_hash: r.audit_hash,
  };
  const value = crypto.sign(null, Buffer.from(jcs(statement)), key.privateKey).toString('base64');
  return { ...r, signature: { algorithm: 'Ed25519', kid: key.kid, value, statement } };
}
const clone = (x) => JSON.parse(JSON.stringify(x));
const valid = sign(record());

const changedVerdict = clone(valid); changedVerdict.verdict = 'AUTHORIZED';
changedVerdict.audit_hash = sha256(jcs({ query_id: changedVerdict.query_id, seal_hash: changedVerdict.artifact.seal_hash, inputs: changedVerdict.inputs, verdict: 'AUTHORIZED', queried_at: changedVerdict.queried_at }));
const changedInputs = clone(valid); changedInputs.inputs.risk_classification = 'minimal';
const changedRules = clone(valid); changedRules.rules_evaluated[0].matched = true;
const rewritten = clone(changedVerdict); rewritten.signature.statement.verdict = 'AUTHORIZED'; rewritten.signature.statement.audit_hash = changedVerdict.audit_hash;
const { signature: _s, evaluator_version: _e, ...unsignedBase } = record({ evaluator_version: undefined });
const unsigned = { ...unsignedBase, signature: null };
const otherKey = sign(record(), other);

const cases = [
  { name: 'valid', record: valid, expected: { hash: 'consistent', signature: 'valid', disagreements: [] } },
  { name: 'verdict_changed_hash_recomputed', record: changedVerdict, expected: { hash: 'consistent', signature: 'valid', disagreements: ['verdict', 'audit_hash'] } },
  { name: 'inputs_changed', record: changedInputs, expected: { hash: 'mismatch', signature: 'valid', disagreements: ['inputs'] } },
  { name: 'rules_evaluated_changed', record: changedRules, expected: { hash: 'consistent', signature: 'valid', disagreements: ['rules_evaluated'] } },
  { name: 'record_and_statement_rewritten', record: rewritten, expected: { hash: 'consistent', signature: 'invalid', disagreements: [] } },
  { name: 'unsigned_legacy', record: unsigned, expected: { hash: 'consistent', signature: 'unsigned', disagreements: [] } },
  { name: 'signed_by_another_key', record: otherKey, expected: { hash: 'consistent', signature: 'wrong_key', disagreements: [] } },
];

fs.writeFileSync(new URL('./vectors.json', import.meta.url), JSON.stringify({
  spec: 'NOMOS-SPEC-005 1.6.0 §2.4',
  published_key: { kid: issuer.kid, algorithm: 'Ed25519', public_key_pem: issuer.pem },
  cases,
}, null, 2) + '\n');
console.log(`wrote ${cases.length} cases; published key ${issuer.kid}`);
