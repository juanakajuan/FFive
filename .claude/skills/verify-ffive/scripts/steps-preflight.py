#!/usr/bin/env python3
import difflib
import re
import sys
from collections import namedtuple

CASE = re.compile(r'^\s*case\s+(\w+)\s*=\s*"([^"]+)"')
FAMILY_SET = re.compile(r"static let (indexed|keyed): Set<A11y> = \[([^\]]*)\]")
SLUG = re.compile(r"[a-z0-9]+(-[a-z0-9]+)*")
BARE_INDEX = re.compile(r"#\d+")
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


def rewrite_launch(line, words):
    if "-animations" in words:
        return re.sub(r"\s+-animations(?=\s|$)", "", line)
    if "-disableAnimations" in words:
        return line
    return line.rstrip() + " -disableAnimations"


def main(steps_in, a11y_path, steps_out):
    plain, indexed, keyed = load_ids(a11y_path)
    display = sorted(plain) + sorted(f"{f}.N" for f in indexed) + sorted(f"{f}.<key>" for f in keyed)
    out = []
    for number, line in enumerate(open(steps_in, encoding="utf-8").read().splitlines(), 1):
        words = tokenize(line.strip())
        if words[:1] and words[0].startswith("#"):
            out.append(line)
            continue
        if len(words) > 1 and words[1].startswith("#") and not BARE_INDEX.fullmatch(words[1]):
            identifier = words[1][1:]
            if not is_valid(identifier, plain, indexed, keyed):
                closest = difflib.get_close_matches(identifier, display, n=1, cutoff=0) or ["none"]
                sys.exit(f"ffive-verify: step {number}: unknown identifier {identifier}; closest {closest[0]}")
        out.append(rewrite_launch(line, words) if words[:1] == ["launch"] else line)
    with open(steps_out, "w", encoding="utf-8") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit("usage: steps-preflight.py <steps-in> <A11y.swift> <steps-out>")
    main(*sys.argv[1:])
