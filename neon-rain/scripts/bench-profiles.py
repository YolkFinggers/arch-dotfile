#!/usr/bin/env python3
"""Bounded profile benchmark for the running NEON RAIN prototype.

Usage: python3 -I scripts/bench-profiles.py [--settle S] [--measure S] [--interval S]

Phases (each: apply IPC overrides, settle, then measure):
  eco, balanced, smooth           setProfile <name>
  static-reduced-motion           setProfile balanced + setReducedMotion true (style: static)

Per phase it records, from monotonic timestamps:
  - process CPU % of one core      (utime+stime ticks from /proc/PID/stat)
  - RSS start/end                  (VmRSS from /proc/PID/status)
  - framesSwapped rate per surface (IPC status; counts presented frames, not timer ticks)
  - i915 render-engine occupancy   (drm-engine-render ns from /proc/PID/fdinfo, deduplicated
                                    by (drm-pdev, drm-client-id): several fds share one client)

Limits: fdinfo render occupancy is this process's busy time on the render engine only. It is
NOT global GPU utilization and NOT a power measurement. No stopped-prototype baseline is taken.
Each IPC status poll costs the prototype a little CPU; polls happen only at interval edges.

Output: tests/results/bench-<stamp>.jsonl (one raw record per sample, flushed immediately)
        tests/results/bench-<stamp>.json  (summary, rewritten after every phase)
The initial IPC overrides are restored in a finally block, also on SIGINT/SIGTERM/SIGHUP.
Only IPC calls are made to the prototype; no process is ever signalled.
"""
import argparse
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROTO = os.path.join(ROOT, "scripts", "neon-rain-proto")
PIDFILE = os.path.join(ROOT, "run", "prototype.pid")
RESULTS = os.path.join(ROOT, "tests", "results")
CLK_TCK = os.sysconf("SC_CLK_TCK")

PHASES = [
    ("eco", [["setProfile", "eco"]]),
    ("balanced", [["setProfile", "balanced"]]),
    ("smooth", [["setProfile", "smooth"]]),
    ("static-reduced-motion", [["setProfile", "balanced"], ["setReducedMotion", "true"]]),
]


class Interrupted(Exception):
    pass


def on_signal(signum, _frame):
    raise Interrupted(f"signal {signum}")


def ipc(*args):
    out = subprocess.run([PROTO, "ipc", *args], capture_output=True, text=True, timeout=20)
    if out.returncode != 0:
        raise RuntimeError(f"ipc {args} failed: {out.stderr.strip()}")
    return json.loads(out.stdout.strip().splitlines()[-1])


def proc_stat(pid):
    with open(f"/proc/{pid}/stat") as f:
        rest = f.read().rsplit(")", 1)[1].split()
    # rest[0] is field 3 (state); utime=14, stime=15, starttime=22
    return int(rest[11]), int(rest[12]), int(rest[19])


def rss_kb(pid):
    with open(f"/proc/{pid}/status") as f:
        for line in f:
            if line.startswith("VmRSS:"):
                return int(line.split()[1])
    return None


def drm_clients(pid):
    """{"pdev/client-id": {"driver", "fds", "engines": {name: ns}}}, duplicates merged."""
    clients = {}
    base = f"/proc/{pid}/fdinfo"
    for fd in os.listdir(base):
        try:
            with open(os.path.join(base, fd)) as f:
                lines = f.read().splitlines()
        except OSError:
            continue  # fd closed between listdir and open
        kv = {}
        for line in lines:
            if ":" in line:
                k, v = line.split(":", 1)
                kv[k.strip()] = v.strip()
        if "drm-client-id" not in kv:
            continue
        key = f"{kv.get('drm-pdev', '?')}/{kv['drm-client-id']}"
        engines = {k[len("drm-engine-"):]: int(v.split()[0])
                   for k, v in kv.items() if k.startswith("drm-engine-") and v.endswith("ns")}
        entry = clients.setdefault(key, {"driver": kv.get("drm-driver"), "fds": [], "engines": engines})
        entry["fds"].append(int(fd))
        if entry["engines"] != engines:
            # Same client read at slightly different instants: keep the larger counters.
            for k, v in engines.items():
                entry["engines"][k] = max(entry["engines"].get(k, 0), v)
    for e in clients.values():
        e["fds"].sort()
    return clients


def snapshot(pid, start_time):
    t0 = time.monotonic_ns()
    utime, stime, st = proc_stat(pid)
    if st != start_time:
        raise RuntimeError("prototype PID was reused or restarted; aborting")
    rss = rss_kb(pid)
    drm = drm_clients(pid)
    t1 = time.monotonic_ns()
    status = ipc("status")
    t2 = time.monotonic_ns()
    return {
        "mono_ns": (t0 + t1) // 2,
        "ipc_mono_ns": (t1 + t2) // 2,
        "cpu_ticks": utime + stime,
        "rss_kb": rss,
        "drm": drm,
        "ticks": status["ticks"],
        "frames": {s["output"]: s["framesSwapped"] for s in status["surfaces"]},
        "settings": status["settings"],
        "overrides": status["overrides"],
    }


def delta(a, b):
    dt = (b["mono_ns"] - a["mono_ns"]) / 1e9
    dt_ipc = (b["ipc_mono_ns"] - a["ipc_mono_ns"]) / 1e9
    render = {}
    for key, cb in b["drm"].items():
        ca = a["drm"].get(key)
        if ca is None:
            continue
        d_ns = cb["engines"].get("render", 0) - ca["engines"].get("render", 0)
        render[key] = {"driver": cb["driver"], "fds": cb["fds"], "render_busy_ns": d_ns,
                       "render_occupancy_pct": round(d_ns / (dt * 1e9) * 100, 3)}
    return {
        "seconds": round(dt, 3),
        "cpu_pct_one_core": round((b["cpu_ticks"] - a["cpu_ticks"]) / CLK_TCK / dt * 100, 2),
        "rss_kb_start": a["rss_kb"],
        "rss_kb_end": b["rss_kb"],
        "tick_hz": round((b["ticks"] - a["ticks"]) / dt_ipc, 2),
        "frames_per_s": {o: round((b["frames"][o] - a["frames"].get(o, 0)) / dt_ipc, 2)
                         for o in b["frames"]},
        "drm_render": render,
    }


def restore(initial):
    ipc("clearOverrides")
    if initial.get("profile") is not None:
        ipc("setProfile", str(initial["profile"]))
    if initial.get("fps") is not None:
        ipc("setFps", str(initial["fps"]))
    if initial.get("reducedMotion") is not None:
        ipc("setReducedMotion", "true" if initial["reducedMotion"] else "false")
    return ipc("status")["overrides"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--settle", type=float, default=5)
    ap.add_argument("--measure", type=float, default=60)
    ap.add_argument("--interval", type=float, default=10)
    args = ap.parse_args()

    with open(PIDFILE) as f:
        pid = int(f.read().strip())
    start_time = proc_stat(pid)[2]
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    os.makedirs(RESULTS, exist_ok=True)
    raw_path = os.path.join(RESULTS, f"bench-{stamp}.jsonl")
    sum_path = os.path.join(RESULTS, f"bench-{stamp}.json")

    initial_status = ipc("status")
    initial = initial_status["overrides"]
    summary = {
        "started": datetime.now().astimezone().isoformat(timespec="seconds"),
        "pid": pid, "clk_tck": CLK_TCK,
        "params": vars(args),
        "initial_overrides": initial,
        "caveats": [
            "drm render occupancy = this process's i915 render-engine busy time / wall time; "
            "not global GPU utilization, not a power measurement",
            "fdinfo entries deduplicated by (drm-pdev, drm-client-id); duplicate fds not summed",
            "no stopped-prototype baseline in this run",
            "IPC status polls at interval edges add a small CPU cost to the prototype",
            "other desktop load was not controlled",
        ],
        "phases": [], "complete": False,
    }
    raw = open(raw_path, "a", buffering=1)

    def emit(rec):
        raw.write(json.dumps(rec) + "\n")
        raw.flush()
        os.fsync(raw.fileno())

    def write_summary():
        tmp = sum_path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(summary, f, indent=2)
        os.replace(tmp, sum_path)

    for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(s, on_signal)

    print(f"raw: {raw_path}\nsummary: {sum_path}", flush=True)
    emit({"event": "start", "pid": pid, "initial_overrides": initial,
          "settings": initial_status["settings"]})
    try:
        for name, calls in PHASES:
            ipc("clearOverrides")
            for c in calls:
                ipc(*c)
            time.sleep(args.settle)
            first = prev = snapshot(pid, start_time)
            emit({"event": "sample", "phase": name, "i": 0, **first})
            intervals = []
            end = first["mono_ns"] + int(args.measure * 1e9)
            i = 0
            while True:
                left = (end - time.monotonic_ns()) / 1e9
                if left <= 0.01:
                    break
                time.sleep(min(args.interval, left))
                i += 1
                cur = snapshot(pid, start_time)
                d = delta(prev, cur)
                intervals.append(d)
                emit({"event": "sample", "phase": name, "i": i, **cur, "interval": d})
                prev = cur
            total = delta(first, prev)
            phase = {"phase": name, "ipc_calls": calls, "settings": first["settings"],
                     "total": total,
                     "interval_cpu_pct": [x["cpu_pct_one_core"] for x in intervals]}
            summary["phases"].append(phase)
            write_summary()
            fr = ", ".join(f"{o} {v}" for o, v in total["frames_per_s"].items())
            rd = ", ".join(f"{k} {v['render_occupancy_pct']}%" for k, v in total["drm_render"].items())
            print(f"{name}: {total['seconds']}s cpu {total['cpu_pct_one_core']}% "
                  f"rss {total['rss_kb_start']}->{total['rss_kb_end']} kB tick {total['tick_hz']} Hz "
                  f"frames/s [{fr}] render [{rd}]", flush=True)
        summary["complete"] = True
    except BaseException as e:
        summary["error"] = repr(e)
        emit({"event": "error", "error": repr(e)})
        print(f"ERROR: {e!r}", file=sys.stderr, flush=True)
        raise
    finally:
        for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(s, signal.SIG_IGN)
        try:
            summary["restored_overrides"] = restore(initial)
        except Exception as e:  # report, but do not mask the original outcome
            summary["restore_error"] = repr(e)
        summary["finished"] = datetime.now().astimezone().isoformat(timespec="seconds")
        emit({"event": "end", "restored_overrides": summary.get("restored_overrides"),
              "restore_error": summary.get("restore_error"), "complete": summary["complete"]})
        write_summary()
        raw.close()
        print(f"restored overrides: {summary.get('restored_overrides')} "
              f"{summary.get('restore_error', '')}", flush=True)


if __name__ == "__main__":
    main()
