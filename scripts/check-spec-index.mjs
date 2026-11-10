#!/usr/bin/env node
/**
 * The two spec indexes (README.md and spec/README.md) agree with the specifications themselves:
 * every spec/NOMOS-SPEC-NNN.md is listed in both, with the Status and Version its own header states.
 *
 *   node scripts/check-spec-index.mjs
 *
 * No dependencies. Exits 1 and names every disagreement.
 */
import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';

const root = resolve(dirname(new URL(import.meta.url).pathname), '..');
const specs = readdirSync(join(root, 'spec')).filter((f) => /^NOMOS-SPEC-\d{3}\.md$/.test(f)).sort();

const header = (file) => {
  const text = readFileSync(join(root, 'spec', file), 'utf8').split('\n').slice(0, 15).join('\n');
  return {
    status: /\*\*Status:\*\*\s*([A-Za-z]+)/.exec(text)?.[1],
    version: /\*\*Version:\*\*\s*([0-9][0-9.]*)/.exec(text)?.[1],
  };
};

/** Rows of a Markdown table whose first cell links to spec file `file`: [status, version]. */
function rowFor(md, file) {
  for (const line of md.split('\n')) {
    if (!line.startsWith('|') || !line.includes(`(${file})`) && !line.includes(`(spec/${file})`)) continue;
    const cells = line.split('|').slice(1, -1).map((c) => c.trim());
    const status = cells.find((c) => /^(Active|Draft|Deprecated|Superseded)$/.test(c));
    const version = cells.find((c) => /^\d+\.\d+\.\d+$/.test(c));
    return { status, version };
  }
  return null;
}

const indexes = { 'README.md': readFileSync(join(root, 'README.md'), 'utf8'), 'spec/README.md': readFileSync(join(root, 'spec/README.md'), 'utf8') };
const problems = [];
for (const file of specs) {
  const h = header(file);
  if (!h.status || !h.version) { problems.push(`${file}: header has no **Status:** or **Version:** line`); continue; }
  for (const [name, md] of Object.entries(indexes)) {
    const row = rowFor(md, file);
    if (!row) problems.push(`${name}: no row for ${file}`);
    else if (row.status !== h.status || row.version !== h.version) {
      problems.push(`${name}: ${file} listed as ${row.status} ${row.version}, its header says ${h.status} ${h.version}`);
    }
  }
}

if (problems.length) {
  console.error(problems.map((p) => '  ' + p).join('\n'));
  process.exit(1);
}
console.log(`Both indexes agree with all ${specs.length} specifications.`);
