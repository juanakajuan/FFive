#!/usr/bin/env python3
import difflib
import re
import sys
from collections import namedtuple

CASE = re.compile(r'^\s*case\s+(\w+)\s*=\s*"([^"]+)"')
FAMILY_SET = re.compile(r"static let (indexed|keyed): Set<A11y> = \[([^\]]*)\]")
SLUG = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
BARE_INDEX = re.compile(r"#\d+")
TARGET_VERBS = {"tap", "longpress", "drag", "type", "replace", "wait", "assert", "exists", "absent", "value", "selected", "unselected", "count", "scrollto"}
PAYLOAD_VERBS = {"type", "replace", "value", "count"}
Ids = namedtuple("Ids", "plain indexed keyed")


def load_ids(a11y_path):
    source = open(a11y_path, encoding="utf-8").read()
    raw = {m.group(1): m.group(2) for m in map(CASE.match, source.splitlines()) if m}
    families = {"indexed": set(), "keyed": set()}
    for kind, members in FAMILY_SET.findall(source):
        families[kind] = {raw[name.strip().lstrip(".")] for name in members.split(",") if name.strip()}
    plain = set(raw.values()) - families["indexed"] - families["keyed"]
    return Ids(plain, families["indexed"], families["keyed"])


def is_valid(identifier, plain, indexed, keyed):
    if identifier in plain:
        return True
    family, _, rest = identifier.rpartition(".")
    if family in indexed and rest.isdigit():
        return True
    return any(identifier.startswith(f + ".") and SLUG.fullmatch(identifier[len(f) + 1 :]) for f in keyed)


def tokenize(line):
    words, current, quoted, started = [], "", False, False
    for character in line:
        if character == '"':
            quoted, started = not quoted, True
            continue
        if character == " " and not quoted:
            if started:
                words.append(current)
            current, started = "", False
            continue
        current += character
        started = True
    if started:
        words.append(current)
    return words


def target_error(words, ids):
    """Why a step's target would not resolve the way it reads, or None. Mirrors DriverTests.run, resolveAll and index."""
    if words[0] not in TARGET_VERBS:
        return None
    args = words[1:]
    timeout = next((i for i, word in enumerate(args) if word.startswith("timeout=")), None)
    if timeout is not None:
        del args[timeout]
    if words[0] in PAYLOAD_VERBS:
        args = args[:-1]
    if words[0] == "drag":
        if "to" not in args:
            return "expected `drag <target> to <target>`"
        split = args.index("to")
        return target_error(["tap", *args[:split]], ids) or target_error(["tap", *args[split + 1 :]], ids)
    if not args:
        return None
    if not args[0].startswith("#"):
        stray = next((word for word in args[2:] if word.startswith("#") and not BARE_INDEX.fullmatch(word)), None)
        return stray and f"{stray} after a label: only a #n index goes there"
    identifier = args[0][1:]
    if not is_valid(identifier, *ids):
        known = sorted(ids.plain) + sorted(f"{f}.N" for f in ids.indexed) + sorted(f"{f}.<key>" for f in ids.keyed)
        closest = difflib.get_close_matches(identifier, known, n=1, cutoff=0) or ["none"]
        return f"unknown identifier {identifier}; closest {closest[0]}"
    if len(args) > 1:
        return f"{args[1]} after {args[0]}: an #id target takes nothing after it, not even a #n index"
    return None


def rewrite_launch(line, words):
    if "-animations" in words:
        return re.sub(r'\s+"?-animations"?(?=\s|$)', "", line)
    if "-disableAnimations" in words:
        return line
    return line.rstrip() + " -disableAnimations"


def main(steps_in, a11y_path, steps_out):
    ids = load_ids(a11y_path)
    out = []
    for number, line in enumerate(open(steps_in, encoding="utf-8").read().splitlines(), 1):
        words = tokenize(line.strip())
        if not words or line.strip().startswith("#"):
            out.append(line)
            continue
        error = target_error(words, ids)
        if error:
            sys.exit(f"ffive-verify: step {number}: {error}")
        out.append(rewrite_launch(line, words) if words[0] == "launch" else line)
    with open(steps_out, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: steps-preflight.py <steps-in> <A11y.swift> <steps-out>")
    main(*sys.argv[1:])
