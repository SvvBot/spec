"""NOMOS-SPEC-011 test vectors through the Python reference (python/nomosprotocol/bindings.py).

    pip install ./python
    python3 binding-vectors/check.py binding-vectors/vectors.json

The expected results were computed by an independent implementation (the TypeScript one in
@nomosprotocol/sdk). Every case must agree: read or refused, the normal form, its digest, and the
facts and unresolved facts for each call.
"""
import json
import sys

from nomosprotocol.bindings import BindingError, apply, digest, parse

vectors = json.load(open(sys.argv[1] if len(sys.argv) > 1 else "binding-vectors/vectors.json"))
passed = failed = 0


def check(name, ok, detail=""):
    global passed, failed
    if ok:
        passed += 1
        print(f"  ok    {name}")
    else:
        failed += 1
        print(f"  FAIL  {name} {detail}")


for c in vectors["parse"]:
    try:
        got = parse(json.loads(c["json"]))
        valid = True
    except BindingError:
        got, valid = None, False
    if not c["valid"]:
        check(f"parse {c['name']}: refused", not valid, "(read, but must be refused)")
    else:
        check(f"parse {c['name']}: read", valid and got == c["normal"] and digest(got) == c["digest"],
              f"got {got!r}, digest {got and digest(got)}")

for c in vectors["apply"]:
    inputs, unresolved = apply(parse(c["bindings"]), c["tool"], c["args"])
    check(f"apply {c['name']}", inputs == c["inputs"] and unresolved == c["unresolved"], f"got {inputs!r} {unresolved!r}")

print(f"\n{passed} passed, {failed} failed")
sys.exit(1 if failed else 0)
