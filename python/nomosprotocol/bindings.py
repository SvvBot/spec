"""NOMOS-SPEC-011 (Draft) Tool Bindings: which of a tool's arguments is which fact a sealed policy reads.

Pure: no I/O. ``parse`` reads a binding file, refusing anything it does not fully understand, and
returns its normal form; ``apply`` gives the facts a policy sees for one call, and the facts it could
not get; ``digest`` is the value an enforcement point records with each decision (SPEC-012 §6).
"""
from __future__ import annotations

from decimal import ROUND_HALF_UP, Decimal
from typing import Any

from .jcs import _es_number, jcs, sha256_hex

RESERVED = {"__proto__", "constructor", "prototype"}
TOP = {"version", "artifact", "reviewed", "tools", "_review"}
TOOL = {"facts", "_why"}
FACT = {"arg", "scale", "map", "_why"}


class BindingError(ValueError):
    """The file is refused (SPEC-011 §2). The message is informative only."""


def _is_number(v: Any) -> bool:
    return isinstance(v, (int, float)) and not isinstance(v, bool) and v == v and v not in (float("inf"), float("-inf"))


def _is_scalar(v: Any) -> bool:
    return isinstance(v, (str, bool)) or _is_number(v)


def parse(raw: Any) -> dict:
    """The normal form of a binding file (comments removed), or BindingError."""
    def no(why: str):
        raise BindingError(why)
    if not isinstance(raw, dict):
        no("not a JSON object")
    if raw.get("version") != 1 or isinstance(raw.get("version"), bool) or not isinstance(raw.get("version"), int):
        no('"version" must be 1')
    if not isinstance(raw.get("artifact"), str) or not raw["artifact"]:
        no('"artifact" must name the sealed policy')
    if not isinstance(raw.get("reviewed"), bool):
        no('"reviewed" must be true or false')
    if not isinstance(raw.get("tools"), dict):
        no('"tools" must be an object')
    for k in raw:
        if k not in TOP:
            no(f'unknown setting "{k}"')
    tools: dict = {}
    for tool, entry in raw["tools"].items():
        if tool in RESERVED:
            no(f'"{tool}" is not a usable tool name')
        if not isinstance(entry, dict):
            no(f'tool "{tool}" must be an object with "facts"')
        for k in entry:
            if k not in TOOL:
                no(f'tool "{tool}": unknown setting "{k}"')
        facts = entry.get("facts")
        if not isinstance(facts, dict):
            no(f'tool "{tool}" needs "facts"')
        out: dict = {}
        for fact, b in facts.items():
            where = f"{tool}.{fact}"
            if fact == "tool":
                no(f'{where}: "tool" is set by the enforcement point')
            if fact in RESERVED:
                no(f"{where} is not a usable fact name")
            if not isinstance(b, dict):
                no(f'{where} must be an object with "arg"')
            for k in b:
                if k not in FACT:
                    no(f'{where}: "{k}" is not allowed; a fact only comes from an argument')
            arg = b.get("arg")
            if not isinstance(arg, str) or not arg:
                no(f'{where} needs "arg"')
            if any(not s or s in RESERVED for s in arg.split(".")):
                no(f'{where}: "{arg}" is not a usable argument path')
            if "scale" in b and "map" in b:
                no(f'{where}: "scale" or "map", not both')
            if "scale" in b and (not _is_number(b["scale"]) or b["scale"] == 0):
                no(f'{where}: "scale" must be a non-zero number')
            if "map" in b:
                m = b["map"]
                if not isinstance(m, dict) or any(k in RESERVED or not _is_scalar(v) for k, v in m.items()):
                    no(f'{where}: "map" must be an object of plain values')
            norm = {"arg": arg}
            if "scale" in b:
                norm["scale"] = b["scale"]
            if "map" in b:
                norm["map"] = dict(b["map"])
            out[fact] = norm
        tools[tool] = {"facts": out}
    return {"version": 1, "artifact": raw["artifact"], "reviewed": raw["reviewed"], "tools": tools}


def digest(normal: dict) -> str:
    """SHA-256 (hex) of the JCS form of a parsed binding file."""
    return sha256_hex(jcs(normal))


def _key(v: Any) -> str:
    """How a value is looked up in a map (SPEC-011 §3.3)."""
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return v
    return _es_number(float(v))


def _scaled(v: float, scale: float) -> float:
    """The product, rounded to nine decimal places, ties away from zero (SPEC-011 §3.2)."""
    return float(Decimal(v * scale).quantize(Decimal("1e-9"), rounding=ROUND_HALF_UP))


def apply(normal: dict, tool: str, args: dict) -> tuple[dict, list]:
    """The facts a policy gets for this call (``tool`` always set), and the facts it could not get."""
    inputs: dict = {"tool": tool}
    unresolved: list = []
    entry = normal["tools"].get(tool) if tool in normal["tools"] else None
    for fact, b in (entry["facts"] if entry else {}).items():
        v: Any = args
        for seg in b["arg"].split("."):
            # Through objects' own members only: never into an array.
            v = v[seg] if isinstance(v, dict) and seg in v else None
        if v is None:
            unresolved.append({"fact": fact, "arg": b["arg"], "why": "missing"})
            continue
        if "scale" in b:
            if not _is_number(v):
                unresolved.append({"fact": fact, "arg": b["arg"], "why": "not_a_number"})
                continue
            inputs[fact] = _scaled(v, b["scale"])
            continue
        if not _is_scalar(v):
            unresolved.append({"fact": fact, "arg": b["arg"], "why": "not_a_value"})
            continue
        if "map" in b:
            k = _key(v)
            if k not in b["map"]:
                unresolved.append({"fact": fact, "arg": b["arg"], "why": "not_in_map"})
                continue
            inputs[fact] = b["map"][k]
            continue
        inputs[fact] = v
    return inputs, unresolved
