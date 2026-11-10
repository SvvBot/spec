// RFC 8785 JSON Canonicalization, enough for these vectors: strings, finite numbers, booleans, null,
// arrays, objects (keys in UTF-16 code-unit order, which is JavaScript's default sort).
export function jcs(v) {
  if (v === null || typeof v === 'boolean') return JSON.stringify(v);
  if (typeof v === 'number') { if (!Number.isFinite(v)) throw new Error('JCS: non-finite number'); return JSON.stringify(v); }
  if (typeof v === 'string') return JSON.stringify(v);
  if (Array.isArray(v)) return '[' + v.map((x) => (x === undefined ? 'null' : jcs(x))).join(',') + ']';
  return '{' + Object.keys(v).filter((k) => v[k] !== undefined).sort().map((k) => JSON.stringify(k) + ':' + jcs(v[k])).join(',') + '}';
}
