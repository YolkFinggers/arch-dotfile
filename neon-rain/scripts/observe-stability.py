#!/usr/bin/env python3
"""Bounded, read-only long-run observer for the running NEON RAIN prototype (TASKS T6).

Usage: python3 -I scripts/observe-stability.py [--duration S] [--interval S] [--tag NAME]
Defaults: 1800 s duration, 60 s interval (31 samples). Duration is capped at 7200 s.

Every interval it records:
  - process identity: PID from run/prototype.pid, cmdline must contain `--path <wallpaper>`,
    starttime from /proc/PID/stat (a change means restart or PID reuse)
  - RSS (VmRSS kB) and CPU % of one core over the interval (utime+stime ticks)
  - new WARN/ERROR/CRITICAL/fatal lines in logs/latest.log since the previous sample
  - IPC status: settings, overrides, measuredTickHz, framesSwapped per surface and its rate,
    artwork status and shader health per surface

Read-only: it never edits config, never sends IPC setters and never signals any process.
Output (flushed after every sample, so an interrupted run keeps its data):
  tests/results/<tag>-<stamp>.jsonl   one raw record per sample
  tests/results/<tag>-<stamp>.json    summary, rewritten after every sample
Stops early on SIGINT/SIGTERM/SIGHUP and writes the final summary (complete: false).
"""
import argparse
import json
import os
import re
import signal
import subprocess
import time
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROTO = os.path.join(ROOT, "scripts", "neon-rain-proto")
WALL = os.path.join(ROOT, "wallpaper")
PIDFILE = os.path.join(ROOT, "run", "prototype.pid")
LOG = os.path.join(ROOT, "logs", "latest.log")
RESULTS = os.path.join(ROOT, "tests", "results")
CLK_TCK = os.sysconf("SC_CLK_TCK")
MAX_DURATION = 7200
LOG_PROBLEM = re.compile(r"\b(WARN|ERROR|CRITICAL|FATAL)\b|segfault", re.IGNORECASE)

stop_requested = False


def on_signal(signum, _frame):
    global stop_requested
    stop_requested = True


def proc_stat(pid):
    with open(f"/proc/{pid}/stat") as f:
        rest = f.read().rsplit(")", 1)[1].split()
    return int(rest[11]), int(rest[12]), int(rest[19])  # utime, stime, starttime


def rss_kb(pid):
    with open(f"/proc/{pid}/status") as f:
        for line in f:
            if line.startswith("VmRSS:"):
                return int(line.split()[1])
    return None


def identity():
    """(pid, starttime) of the prototype, or (None, reason)."""
    try:
        with open(PIDFILE) as f:
            pid = int(f.read().strip())
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            cmd = f.read().replace(b"\0", b" ").decode("utf-8", "replace")
        if f"--path {WALL} " not in cmd:
            return None, "pidfile PID is not the prototype"
        return pid, proc_stat(pid)[2]
    except (OSError, ValueError) as e:
        return None, f"not running ({e.__class__.__name__})"


class LogCursor:
    """Follows logs/latest.log; starts from byte 0 when the symlink target changes (restart)."""

    def __init__(self):
        self.target = os.path.realpath(LOG)
        self.offset = os.path.getsize(self.target)

    def new_problems(self):
        target = os.path.realpath(LOG)
        if target != self.target:
            self.target, self.offset = target, 0
        with open(self.target, "rb") as f:
            f.seek(self.offset)
            data = f.read()
        self.offset += len(data)
        lines = data.decode("utf-8", "replace").splitlines()
        return [l for l in lines if LOG_PROBLEM.search(l)], len(lines), os.path.basename(target)


def ipc_status():
    try:
        out = subprocess.run([PROTO, "ipc", "status"], capture_output=True, text=True, timeout=20)
        if out.returncode != 0:
            return None, out.stderr.strip()[-200:]
        return json.loads(out.stdout.strip().splitlines()[-1]), None
    except (subprocess.TimeoutExpired, ValueError, IndexError) as e:
        return None, repr(e)


def write_summary(path, summary):
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(summary, f, indent=2)
    os.replace(tmp, path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--duration", type=float, default=1800)
    ap.add_argument("--interval", type=float, default=60)
    ap.add_argument("--tag", default="stability")
    a = ap.parse_args()
    duration = min(max(a.duration, 1), MAX_DURATION)
    interval = max(a.interval, 1)
    tag = re.sub(r"[^A-Za-z0-9_-]", "", a.tag)[:30] or "stability"

    for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(s, on_signal)

    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    raw_path = os.path.join(RESULTS, f"{tag}-{stamp}.jsonl")
    sum_path = os.path.join(RESULTS, f"{tag}-{stamp}.json")
    pid0, start0 = identity()
    summary = {
        "started": datetime.now().isoformat(timespec="seconds"),
        "durationRequested": duration, "interval": interval,
        "initialPid": pid0, "initialStarttime": start0,
        "samples": 0, "identityChanges": 0, "notRunningSamples": 0, "ipcFailures": 0,
        "logProblemLines": 0, "rssKb": {}, "cpuPct": {}, "tickHz": {}, "complete": False,
    }
    cursor = LogCursor()
    t0 = time.monotonic()
    prev = None  # (mono, pid, starttime, cpu_ticks, frames)
    rss_all, cpu_all, hz_all = [], [], []
    print(f"observing {duration:.0f}s every {interval:.0f}s -> {os.path.relpath(raw_path, ROOT)}", flush=True)

    with open(raw_path, "a") as raw:
        n = 0
        while True:
            mono = time.monotonic()
            rec = {"n": n, "time": datetime.now().isoformat(timespec="seconds"), "elapsed": round(mono - t0, 1)}
            pid, start = identity()
            if pid is None:
                rec.update(state="not-running", reason=start)
                summary["notRunningSamples"] += 1
                prev = None
            else:
                ut, stt, _ = proc_stat(pid)
                rec.update(state="running", pid=pid, starttime=start, rssKb=rss_kb(pid))
                rss_all.append(rec["rssKb"])
                if (pid, start) != (summary["initialPid"], summary["initialStarttime"]):
                    rec["identityChanged"] = True
                if prev and (prev[1], prev[2]) != (pid, start):
                    summary["identityChanges"] += 1
                    prev = None
                st, err = ipc_status()
                frames = None
                if st is None:
                    rec["ipcError"] = err
                    summary["ipcFailures"] += 1
                else:
                    frames = {x["output"]: x["framesSwapped"] for x in st["surfaces"]}
                    rec.update(
                        settings={k: st["settings"][k] for k in ("profile", "fps", "animate", "reducedMotion")},
                        settingsWarnings=st["settings"]["warnings"], overrides=st["overrides"],
                        uptimeSeconds=st["uptimeSeconds"], measuredTickHz=st["measuredTickHz"],
                        framesSwapped=frames,
                        surfaces={x["output"]: {"artwork": x["artworkStatus"], "shader": x["shader"]["health"],
                                                "size": x["size"]} for x in st["surfaces"]})
                    hz_all.append(st["measuredTickHz"])
                if prev:
                    dt = mono - prev[0]
                    rec["cpuPct"] = round(100 * (ut + stt - prev[3]) / CLK_TCK / dt, 2)
                    cpu_all.append(rec["cpuPct"])
                    if frames and prev[4]:
                        rec["framesPerSec"] = {o: round((frames[o] - prev[4].get(o, 0)) / dt, 2) for o in frames}
                prev = (mono, pid, start, ut + stt, frames)
            try:
                problems, nlines, logname = cursor.new_problems()
                rec.update(log=logname, logNewLines=nlines, logProblemCount=len(problems), logProblems=problems[:20])
                summary["logProblemLines"] += len(problems)
            except OSError as e:
                rec["logError"] = repr(e)

            raw.write(json.dumps(rec) + "\n")
            raw.flush()
            os.fsync(raw.fileno())
            n += 1
            summary.update(samples=n, lastState=rec["state"], elapsed=rec["elapsed"])
            if rss_all:
                summary["rssKb"] = {"first": rss_all[0], "last": rss_all[-1], "min": min(rss_all),
                                    "max": max(rss_all), "driftKb": rss_all[-1] - rss_all[0]}
            if cpu_all:
                summary["cpuPct"] = {"mean": round(sum(cpu_all) / len(cpu_all), 2),
                                     "min": min(cpu_all), "max": max(cpu_all)}
            if hz_all:
                summary["tickHz"] = {"first": hz_all[0], "last": hz_all[-1], "min": min(hz_all), "max": max(hz_all)}
            write_summary(sum_path, summary)
            print(f"[{n}] {rec['state']} pid={rec.get('pid')} rss={rec.get('rssKb')} cpu={rec.get('cpuPct')} "
                  f"hz={rec.get('measuredTickHz')} logProblems={rec.get('logProblemCount')}", flush=True)

            next_at = t0 + n * interval
            if next_at - t0 > duration + 0.5 or stop_requested:
                break
            while not stop_requested and time.monotonic() < next_at:
                time.sleep(min(1.0, max(0.0, next_at - time.monotonic())))
            if stop_requested:
                break

    summary["complete"] = not stop_requested
    summary["finished"] = datetime.now().isoformat(timespec="seconds")
    write_summary(sum_path, summary)
    print(f"summary: {os.path.relpath(sum_path, ROOT)}", flush=True)


if __name__ == "__main__":
    main()
