#!/usr/bin/python3
"""ChillPill-Shell managed keybinds for hyprland.lua.

Modes:
  paste <block> [path]   write the managed block; user combos are preserved
  remove [path]          strip the managed block
  check [path]           JSON report: per-state combo/expr, old lines, duplicate combos

A "chillpill bind" is any hl.bind whose command mentions the shell, e.g.
"qs ipc -p /usr/share/chillpill-shell call <state> toggle" or
"chillpill-shell-ipc call <state> toggle|show|hide".

Paste keeps every existing key combo: each state's bind line (user combo and
all) is transplanted into the managed block verbatim; defaults are only used
for states the user has no bind for. Old/duplicate binds for the same state
are scrubbed so each state stays bound exactly once.
"""

import json
import os
import re
import sys

HEAD = "-- >>> chillpill-shell keybinds (managed)"
TAIL = "-- <<< chillpill-shell keybinds"
STATES = ["controlCenter", "cliphist", "dashboard", "spotlight", "wallpaperSwitcher", "powerMenu", "wifiState", "bluetoothState", "theme"]
STATE_SET = set(STATES)
BIND_RE = re.compile(r'hl\.bind\((.*?),\s*hl\.dsp\.exec_cmd\("(.*?)"\)\)')
IPC_RE = re.compile(r'(?:-p\s+\S*chillpill-shell\S*|chillpill-shell-ipc).*?call\s+(\w+)\s+(?:toggle|show|hide)')


def get_path():
    last = sys.argv[-1]
    if len(sys.argv) > 2 and not last.startswith("--"):
        return last
    return os.path.expanduser("~/.config/hypr/hyprland.lua")


def parse_bind(line):
    m = BIND_RE.search(line)
    if not m:
        return None
    arg, cmd = m.group(1).strip(), m.group(2)
    keys = [k.strip() for q in re.findall(r'"([^"]*)"', arg) for k in q.split("+") if k.strip()]
    combo = " + ".join(keys) or arg
    mc = IPC_RE.search(cmd)
    return {"combo": combo, "state": mc.group(1) if mc else None,
            "expr": arg, "cmd": cmd, "chillpill": bool(mc)}


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


def preferred_exprs(binds):
    """state -> arg expression the user already has.

    Non-managed (outside the block) wins over managed — that's where manual
    edits land — and the last occurrence wins among equals.
    """
    exprs = {}
    for _, _, b in binds:
        if not b["chillpill"] or b["state"] not in STATE_SET:
            continue
        if b["managed"]:
            exprs.setdefault(b["state"], b["expr"])
        else:
            exprs[b["state"]] = b["expr"]
    return exprs


def report(binds):
    pref = preferred_exprs(binds)
    states = {s: {"count": 0, "managed": False, "combo": "", "expr": pref.get(s, "")} for s in STATES}
    old = []
    combo_n = {}
    for i, ln, b in binds:
        if b["state"] in states:
            r = states[b["state"]]
            r["count"] += 1
            if b["managed"]:
                r["managed"] = True
                r["combo"] = b["combo"]
        if b["chillpill"] and not b["managed"] and b["state"] in STATE_SET:
            old.append(i)
        combo_n[b["combo"]] = combo_n.get(b["combo"], 0) + 1
    return {"states": states, "old_lines": old,
            "dup_combos": {c: n for c, n in combo_n.items() if n > 1}}


def rebuild_block(block, exprs):
    """Swap each template line's combo expression for the user's."""
    out = ["-- >>> chillpill-shell keybinds (managed)"]
    kept = []
    for ln in block.split("\n"):
        ln = ln.rstrip()
        if not ln or ln.startswith("--"):
            continue
        b = parse_bind(ln)
        if not b:
            out.append(ln)
            continue
        use = exprs.get(b["state"]) if b["state"] else None
        if use:
            kept.append(b["state"])
        out.append('hl.bind(%s,  hl.dsp.exec_cmd("%s"))' % (use or b["expr"], b["cmd"]))
    out.append("-- <<< chillpill-shell keybinds")
    return "\n".join(out), kept


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

    kept_from = preferred_exprs(binds)
    new_block, kept = rebuild_block(block, kept_from)

    # every state is now inside the managed block, so non-managed ones go
    scrub = [i for i, ln, b in binds if b["chillpill"] and not b["managed"] and b["state"] in STATE_SET]
    for i in sorted(scrub, reverse=True):
        del lines[i]

    h2, t2, _ = analyze(lines)
    b = new_block.split("\n")
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
    if kept:
        msg.append("Kept your existing combos for: " + ", ".join(kept))
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
