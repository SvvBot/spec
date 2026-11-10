#!/usr/bin/env node
/**
 * Every relative link in every Markdown file resolves: the file or folder exists, and a
 * `#fragment` into a Markdown file names a heading it has (GitHub's slug rules) or an explicit
 * `<a id>` / `<a name>`. External links (http, https, mailto) are not fetched.
 *
 *   node scripts/check-links.mjs
 *
 * No dependencies. Exits 1 and lists every broken link.
 */
import { readFileSync, readdirSync, lstatSync, existsSync } from 'node:fs';
import { join, dirname, resolve, relative, extname } from 'node:path';

const root = resolve(dirname(new URL(import.meta.url).pathname), '..');
const skipDirs = new Set(['node_modules', '.git', '.venv', 'venv', '__pycache__', 'dist']);

function walk(dir, out = []) {
  for (const name of readdirSync(dir)) {
    if (skipDirs.has(name)) continue;
    const p = join(dir, name);
    const s = lstatSync(p);
    if (s.isSymbolicLink()) continue;
    if (s.isDirectory()) walk(p, out);
    else if (extname(name) === '.md') out.push(p);
  }
  return out;
}

/** Text with fenced code blocks and inline code removed, so examples are not read as links. */
function prose(md) {
  return md.replace(/^(```|~~~)[^\n]*\n[\s\S]*?^\1[^\n]*$/gm, '').replace(/`[^`\n]*`/g, '');
}

/** GitHub's heading anchors: lower case, punctuation dropped, spaces to hyphens, repeats numbered. */
const anchorCache = new Map();
function anchors(file) {
  if (anchorCache.has(file)) return anchorCache.get(file);
  const md = readFileSync(file, 'utf8');
  const set = new Set();
  const seen = new Map();
  for (const line of prose(md).split('\n')) {
    const m = /^#{1,6}\s+(.+?)\s*#*\s*$/.exec(line);
    if (!m) continue;
    const text = m[1].replace(/<[^>]+>/g, '').replace(/!?\[([^\]]*)\]\([^)]*\)/g, '$1').replace(/[*_~]/g, '');
    let slug = text.toLowerCase().trim().replace(/[^\p{L}\p{N}\s-]/gu, '').replace(/\s/g, '-');
    const n = seen.get(slug) ?? 0;
    seen.set(slug, n + 1);
    set.add(n ? `${slug}-${n}` : slug);
  }
  for (const m of md.matchAll(/<a\s+(?:id|name)="([^"]+)"/g)) set.add(m[1]);
  anchorCache.set(file, set);
  return set;
}

const broken = [];
const files = walk(root);
for (const file of files) {
  const text = prose(readFileSync(file, 'utf8'));
  const links = [
    ...[...text.matchAll(/!?\[[^\]]*\]\(\s*<?([^)\s>]+)>?(?:\s+"[^"]*")?\s*\)/g)].map((m) => m[1]),
    ...[...text.matchAll(/^\s*\[[^\]]+\]:\s*<?(\S+?)>?(?:\s+"[^"]*")?\s*$/gm)].map((m) => m[1]),
  ];
  for (const link of links) {
    if (/^[a-z][a-z0-9+.-]*:/i.test(link)) continue;          // http:, https:, mailto:, …
    const [pathPart, frag] = link.split('#');
    const target = pathPart ? resolve(dirname(file), decodeURIComponent(pathPart)) : file;
    const where = relative(root, file);
    if (!existsSync(target)) { broken.push(`${where}: ${link} (no such file)`); continue; }
    if (frag && extname(target) === '.md' && !anchors(target).has(decodeURIComponent(frag).toLowerCase())) {
      broken.push(`${where}: ${link} (no heading #${frag} in ${relative(root, target)})`);
    }
  }
}

if (broken.length) {
  console.error(`${broken.length} broken link(s):\n` + broken.map((b) => '  ' + b).join('\n'));
  process.exit(1);
}
console.log(`All relative links resolve (${files.length} Markdown files).`);
