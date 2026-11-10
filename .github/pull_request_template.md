## What this changes

<!-- One or two sentences. Name the specification(s) and section(s): e.g. NOMOS-SPEC-008 §5.2. -->

## Why

<!-- The problem, or the issue this closes (Closes #…). -->

## Checklist

- [ ] A normative change is recorded in `CHANGELOG.md` with the new version, and the spec's own **Version** line is updated
- [ ] A change that alters a verdict comes with vectors that show it, and the generators still reproduce every committed vector file (`cmp` steps in CI)
- [ ] A backward-incompatible change to an Active specification takes a new specification number (`DEPRECATION.md`)
- [ ] `node scripts/check-links.mjs` passes
- [ ] Example artifacts changed? Re-sealed with `node scripts/seal-example.mjs examples/<file>.nomos`
