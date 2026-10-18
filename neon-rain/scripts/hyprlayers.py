#!/usr/bin/env python3
"""Print Hyprland layer surfaces from `hyprctl layers -j` on stdin.

Usage: hyprctl layers -j | hyprlayers.py [--pid PID] [--namespace NS]
One line per surface: <monitor> layer=<name> ns=<namespace> pid=<pid> <w>x<h>+<x>+<y>
"""
import argparse
import json
import sys

LEVELS = {0: "background", 1: "bottom", 2: "top", 3: "overlay"}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pid", type=int)
    ap.add_argument("--namespace")
    args = ap.parse_args()

    data = json.load(sys.stdin)
    for mon, v in data.items():
        for lvl, surfaces in v["levels"].items():
            for s in surfaces:
                if args.pid is not None and s["pid"] != args.pid:
                    continue
                if args.namespace is not None and s["namespace"] != args.namespace:
                    continue
                name = LEVELS.get(int(lvl), lvl)
                print(f"{mon} layer={name} ns={s['namespace']} pid={s['pid']} "
                      f"{s['w']}x{s['h']}+{s['x']}+{s['y']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
