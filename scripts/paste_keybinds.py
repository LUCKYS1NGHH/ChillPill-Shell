#!/usr/bin/python3
"""ChillPill-Shell managed keybinds for hyprland.lua.

Modes:
  paste <block> [path]   replace the managed block, scrub old duplicate binds
  remove [path]          strip the managed block
  check [path]           JSON report: pill-state binds, old lines, duplicate combos

A "chillpill bind" is any hl.bind whose command mentions the shell, e.g.
"qs ipc -p /usr/share/chillpill-shell call <state> toggle" or
"chillpill-shell-ipc call <state> toggle". On paste, old (non-managed)
binds for the all states are removed so each combo is bound once.
"""

import json
import os
import re
import sys

HEAD = "-- >>> chillpill-shell keybinds (managed)"
TAIL = "-- <<< chillpill-shell keybinds"
STATES = ["controlCenter", "cliphist", "miniDashboard", "spotlight", "wallpaperSwitcher", "powerMenu"]
BIND_RE = re.compile(r'hl\.bind\((.*?),.*?exec_cmd\("(.*?)"\)\)')
IPC_RE = re.compile(r'(?:-p\s+\S*chillpill-shell\S*|chillpill-shell-ipc).*?call\s+(\w+)\s+toggle')


def get_path():
    last = sys.argv[-1]
    if len(sys.argv) > 2 and not last.startswith("--"):
        return last
    return os.path.expanduser("~/.config/hypr/hyprland.lua")


def parse_bind(line):
    m = BIND_RE.search(line)
    if not m:
        return None
    arg, cmd = m.group(1), m.group(2)
    keys = [k.strip() for q in re.findall(r'"([^"]*)"', arg) for k in q.split("+") if k.strip()]
    combo = " + ".join(keys) or arg.strip()
    mc = IPC_RE.search(cmd)
    return {"combo": combo, "state": mc.group(1) if mc else None, "chillpill": bool(mc)}


def analyze(lines):
    head = tail = -1
    in_block = False
    binds = []
    for i, ln in enumerate(lines):
        s = ln.strip()
        if s.startswith(HEAD):
            head = i
            in_block = True
            continue
        if s.startswith(TAIL):
            tail = i
            in_block = False
            continue
        b = parse_bind(ln)
        if b:
            b["managed"] = in_block
            binds.append((i, ln, b))
    return head, tail, binds


def report(binds):
    states = {s: {"count": 0, "managed": False, "combo": ""} for s in STATES}
    old = []
    combo_n = {}
    for i, ln, b in binds:
        if b["state"] in states:
            r = states[b["state"]]
            r["count"] += 1
            if b["managed"]:
                r["managed"] = True
                r["combo"] = b["combo"]
        if b["chillpill"] and not b["managed"]:
            old.append(i)
        combo_n[b["combo"]] = combo_n.get(b["combo"], 0) + 1
    return {"states": states, "old_lines": old,
            "dup_combos": {c: n for c, n in combo_n.items() if n > 1}}


def main():
    mode = (sys.argv[1] if len(sys.argv) > 1 else "paste").lstrip("-")
    path = get_path()
    try:
        text = open(path).read() if os.path.exists(path) else ""
    except OSError as e:
        print("error: cannot read %s: %s" % (path, e), file=sys.stderr)
        sys.exit(1)
    lines = text.split("\n") if text else []
    head, tail, binds = analyze(lines)

    if mode == "check":
        rep = report(binds)
        rep["path"] = path
        json.dump(rep, sys.stdout, indent=1)
        return

    if mode == "remove":
        if head >= 0 and tail >= 0:
            del lines[head:tail + 1]
            open(path, "w").write("\n".join(lines).strip() + "\n")
            print("Removed keybinds from", path)
        else:
            print("No managed keybinds found in", path)
        return

    if mode != "paste":
        print("error: unknown mode %s" % mode, file=sys.stderr)
        sys.exit(1)

    block = sys.argv[2] if len(sys.argv) > 2 else ""
    if not block:
        print("error: no block given", file=sys.stderr)
        sys.exit(1)

    removed = []
    scrub = [i for i, ln, b in binds if b["chillpill"] and not b["managed"] and b["state"] in STATES]
    for i in sorted(scrub, reverse=True):
        removed.append(parse_bind(lines[i])["combo"])
        del lines[i]

    h2, t2, _ = analyze(lines)
    b = block.split("\n")
    if h2 >= 0 and t2 >= 0:
        lines = lines[:h2] + b + lines[t2 + 1:]
    elif h2 >= 0:
        lines = lines[:h2] + b
    elif t2 >= 0:
        lines = [l for l in lines if l.strip() != TAIL.strip()] + b
    else:
        lines = lines + ([""] * (1 if lines and lines[-1].strip() else 0)) + b

    open(path, "w").write("\n".join(lines).strip() + "\n")

    msg = ["Pasted keybinds to " + path]
    if removed:
        msg.append("Removed %d old bind line(s): %s" % (len(removed), ", ".join(removed)))
    _, _, fbinds = analyze(open(path).read().split("\n"))
    dups = report(fbinds)["dup_combos"]
    msg.append("Duplicate combos remaining: " + (", ".join(sorted(dups)) if dups else "none"))
    print("\n".join(msg))


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("error: %s" % e, file=sys.stderr)
        sys.exit(1)
