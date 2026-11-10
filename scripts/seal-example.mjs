#!/usr/bin/env node
/**
 * Re-seals an example artifact in examples/ after you change it, with the PUBLIC test key.
 *
 *   node scripts/seal-example.mjs examples/your_file.nomos
 *
 * Recomputes `seal.hash` (SHA-256 of the JCS of everything except `seal` and `attestations`,
 * NOMOS-SPEC-001 §8) and the HMAC-SHA256 `seal.signature` over it, keeping every other seal field.
 * The key is deadbeef… repeated, published so anyone can check the examples: these seals prove
 * nothing about who wrote the file, and production artifacts are sealed with Ed25519 instead.
 * Verify afterwards with `npx tsx verify/verify.ts <file> --key deadbeef…`.
 */
import { readFileSync, writeFileSync } from 'node:fs';
import { createHash, createHmac } from 'node:crypto';
import { jcs } from '../query-statement-vectors/jcs.mjs';

const TEST_KEY = Buffer.from('deadbeef'.repeat(8), 'hex');   // the hex string's 32 bytes, as verify.ts reads --key
const file = process.argv[2];
if (!file || !/(^|\/)examples\/[^/]+\.nomos$/.test(file)) {
  console.error('usage: node scripts/seal-example.mjs examples/<file>.nomos   (examples only: the key is public)');
  process.exit(2);
}

const text = readFileSync(file, 'utf8');
const artifact = JSON.parse(text);
if (!artifact.seal || artifact.seal.signature_algorithm !== 'HMAC-SHA256') {
  console.error(`${file}: expected an HMAC-SHA256 example seal`);
  process.exit(1);
}
const payload = Object.fromEntries(Object.entries(artifact).filter(([k]) => k !== 'seal' && k !== 'attestations'));
const hash = createHash('sha256').update(jcs(payload)).digest('hex');
const signature = createHmac('sha256', TEST_KEY).update(hash, 'ascii').digest('hex');
const changed = hash !== artifact.seal.hash || signature !== artifact.seal.signature;
artifact.seal = { ...artifact.seal, hash, signature };

const indent = /^\{\n( +)"/.exec(text)?.[1].length ?? 2;
writeFileSync(file, JSON.stringify(artifact, null, indent) + (text.endsWith('\n') ? '\n' : ''));
console.log(`${file}: ${changed ? 'resealed' : 'seal already current'} (hash ${hash.slice(0, 16)}…)`);
