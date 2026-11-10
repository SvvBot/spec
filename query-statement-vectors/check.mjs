// Checks every case in vectors.json with a dependency-free implementation of NOMOS-SPEC-005 §2.4.
//   node query-statement-vectors/check.mjs
import crypto from 'node:crypto';
import fs from 'node:fs';
import { jcs } from './jcs.mjs';

const sha256 = (s) => crypto.createHash('sha256').update(s).digest('hex');
const same = (a, b) => jcs(a ?? null) === jcs(b ?? null);
const kidOf = (pem) => crypto.createHash('sha256').update(crypto.createPublicKey(pem).export({ type: 'spki', format: 'der' })).digest('base64url').slice(0, 16);

export function check(r, pem) {
  const hash = sha256(jcs({ query_id: r.query_id, seal_hash: r.artifact.seal_hash ?? null, inputs: r.inputs, verdict: r.verdict, queried_at: r.queried_at })) === r.audit_hash ? 'consistent' : 'mismatch';
  const sig = r.signature;
  if (!sig) return { hash, signature: 'unsigned', disagreements: [] };
  const s = sig.statement, d = [];
  const cmp = (n, shown, signed) => { if (!same(shown, signed)) d.push(n); };
  cmp('query_id', r.query_id, s.query_id);
  cmp('artifact', { id: r.artifact.id, version: r.artifact.version ?? null, seal_hash: r.artifact.seal_hash ?? null }, s.artifact);
  cmp('inputs', r.inputs, s.inputs);
  cmp('verdict', r.verdict, s.verdict);
  cmp('outcome_code', r.outcome_code ?? null, s.outcome_code);
  cmp('matched_rule_id', r.matched_rule_id ?? null, s.matched_rule_id);
  if (r.open_higher_priority_count !== undefined) cmp('open_higher_priority_count', r.open_higher_priority_count, s.open_higher_priority_count);
  if (r.rules_evaluated) cmp('rules_evaluated', sha256(jcs(r.rules_evaluated)), s.rules_evaluated_digest);
  if (r.evaluator_version !== undefined) cmp('evaluator_version', r.evaluator_version, s.evaluator_version);
  cmp('queried_at', r.queried_at, s.queried_at);
  cmp('audit_hash', r.audit_hash, s.audit_hash);
  if (s.type !== 'nomos.authority_query.statement/1') d.push('type');
  if (kidOf(pem) !== sig.kid) return { hash, signature: 'wrong_key', disagreements: d };
  const ok = sig.algorithm === 'Ed25519' && crypto.verify(null, Buffer.from(jcs(s)), pem, Buffer.from(sig.value, 'base64'));
  return { hash, signature: ok ? 'valid' : 'invalid', disagreements: d };
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const v = JSON.parse(fs.readFileSync(new URL('./vectors.json', import.meta.url), 'utf8'));
  let fail = 0;
  for (const c of v.cases) {
    const got = check(c.record, v.published_key.public_key_pem);
    const ok = same(got, c.expected);
    if (!ok) fail++;
    console.log(`  ${ok ? 'ok  ' : 'FAIL'} ${c.name}${ok ? '' : `: got ${JSON.stringify(got)}`}`);
  }
  console.log(`${v.cases.length - fail}/${v.cases.length} cases`);
  process.exit(fail ? 1 : 0);
}
