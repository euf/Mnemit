#!/usr/bin/python3
# coding: utf-8
"""Resolves a git merge conflict in Shared/Resources/Localizable.xcstrings key by key.

Parallel branches each add or change their own keys; git sees text conflicts in the sorted
JSON although the keys rarely collide. This takes the three stages of the conflicted file
(base, ours, theirs), applies theirs' additions, changes and deletions onto ours, and writes
the catalog in its own format (2-space indent, `": "`, sorted keys). A key both sides changed
differently is reported and left as ours.

    Scripts/merge-xcstrings.py && git add Shared/Resources/Localizable.xcstrings
"""
import json
import subprocess
import sys

PATH = "Shared/Resources/Localizable.xcstrings"


def stage(n):
    out = subprocess.run(["git", "show", f":{n}:{PATH}"], capture_output=True, text=True, check=True).stdout
    return json.loads(out), out


def main():
    base = stage(1)[0]["strings"]
    ours_doc, ours_raw = stage(2)
    theirs = stage(3)[0]["strings"]
    ours = ours_doc["strings"]
    conflicts = []
    for key, value in theirs.items():
        if key not in ours:
            if key not in base:
                ours[key] = value  # added by theirs
        elif ours[key] != value:
            if key in base and ours[key] == base[key]:
                ours[key] = value  # changed only by theirs
            elif not (key in base and value == base[key]):
                conflicts.append(key)  # changed by both
    for key in list(ours):
        if key in base and key not in theirs and ours[key] == base[key]:
            del ours[key]  # deleted by theirs, untouched by ours
    text = json.dumps(ours_doc, ensure_ascii=False, indent=2, separators=(",", ": "), sort_keys=True)
    with open(PATH, "w", encoding="utf-8") as f:
        f.write(text + ("\n" if ours_raw.endswith("\n") else ""))
    for key in conflicts:
        print(f"both changed, kept ours: {key}", file=sys.stderr)
    print(f"{PATH}: merged, {len(conflicts)} key conflicts")


if __name__ == "__main__":
    main()
