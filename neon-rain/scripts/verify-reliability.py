#!/usr/bin/env python3
"""M1 reliability checks against the running NEON RAIN prototype.

Usage: python3 -I scripts/verify-reliability.py [--skip-stop-start] [--timeout S]

Config phase (temporarily edits config/wallpaper.json, always restored):
  hot-reload        valid edit (profile eco, rain.intensity 0.7) is applied without restart
  malformed         truncated JSON is rejected, a parse warning is logged, previous
                    settings (eco/0.7) stay active
  recover           a valid edit after the malformed one (profile smooth) is applied again
  unknown-profile   valid JSON with profile "turbo" falls back to balanced with a warning
  override-wins     an IPC setProfile override beats a later config edit; clearing the
                    override returns to the config value
  restore           original bytes written back (sha256 compared), settings equal the
                    pre-test settings, IPC overrides equal the pre-test overrides

Stop/start phase (stops and restarts ONLY the prototype via scripts/neon-rain-proto):
  new PID, three bottom layers, artwork Ready on every surface, framesSwapped grows,
  settings equal the pre-stop settings, pre-stop IPC overrides re-applied.

Config edits are written in place (same inode), like a normal editor save. A byte copy of
the original config is saved under tests/results/ before any edit. The original bytes and
overrides are restored in a finally block, also on SIGINT/SIGTERM/SIGHUP.
Output: tests/results/reliability-<stamp>.json (rewritten after every check).
"""
import argparse
import hashlib
import json
import os
import signal
import subprocess
import sys
import time
from datetime import datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROTO = os.path.join(ROOT, "scripts", "neon-rain-proto")
CONFIG = os.path.join(ROOT, "config", "wallpaper.json")
LOG = os.path.join(ROOT, "logs", "latest.log")
PIDFILE = os.path.join(ROOT, "run", "prototype.pid")
RESULTS = os.path.join(ROOT, "tests", "results")
OUTPUTS = {"eDP-1", "DP-1", "HDMI-A-1"}


class Interrupted(Exception):
    pass


def on_signal(signum, _frame):
    raise Interrupted(f"signal {signum}")


def proto(*args, timeout=30):
    return subprocess.run([PROTO, *args], capture_output=True, text=True, timeout=timeout)


def ipc(*args):
    out = proto("ipc", *args, timeout=20)
    if out.returncode != 0:
        raise RuntimeError(f"ipc {args} failed: {out.stderr.strip()}")
    return json.loads(out.stdout.strip().splitlines()[-1])


def sha(data):
    return hashlib.sha256(data).hexdigest()


def write_in_place(data):
    with open(CONFIG, "r+b") as f:
        f.seek(0)
        f.write(data)
        f.truncate()
        f.flush()
        os.fsync(f.fileno())


def log_size():
    return os.path.getsize(LOG)


def log_tail(offset):
    """New text in latest.log since byte offset."""
    with open(LOG, "rb") as f:
        f.seek(offset)
        return f.read().decode("utf-8", "replace")


def wait_for(pred, timeout, step=0.25):
    """Polls IPC status until pred(status). Returns (ok, last_status, seconds)."""
    t0 = time.monotonic()
    st = None
    while time.monotonic() - t0 < timeout:
        st = ipc("status")
        if pred(st):
            return True, st, round(time.monotonic() - t0, 2)
        time.sleep(step)
    return False, st, round(time.monotonic() - t0, 2)


def core(settings):
    """Settings without the warnings list, for equality checks."""
    return {k: v for k, v in settings.items() if k != "warnings"}


def dump(obj):
    return (json.dumps(obj, indent=2) + "\n").encode()


def restore_overrides(target):
    if ipc("status")["overrides"] == target:
        return
    ipc("clearOverrides")
    if target.get("profile") is not None:
        ipc("setProfile", str(target["profile"]))
    if target.get("fps") is not None:
        ipc("setFps", str(target["fps"]))
    if target.get("reducedMotion") is not None:
        ipc("setReducedMotion", "true" if target["reducedMotion"] else "false")


class Report:
    def __init__(self, path):
        self.path = path
        self.data = {"started": datetime.now().isoformat(timespec="seconds"), "checks": []}

    def check(self, name, ok, **detail):
        self.data["checks"].append({"name": name, "pass": bool(ok), **detail})
        print(f"{'PASS' if ok else 'FAIL'} {name} {json.dumps(detail, separators=(',', ':'))[:300]}", flush=True)
        self.flush()

    def flush(self):
        checks = self.data["checks"]
        self.data["passed"] = sum(c["pass"] for c in checks)
        self.data["failed"] = sum(not c["pass"] for c in checks)
        tmp = self.path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(self.data, f, indent=2)
        os.replace(tmp, self.path)


def config_phase(rep, original, timeout):
    base_intensity = json.loads(original).get("rain", {}).get("intensity", 1.0)

    # hot-reload
    edit = json.loads(original)
    edit["profile"] = "eco"
    edit.setdefault("rain", {})["intensity"] = 0.7
    off = log_size()
    write_in_place(dump(edit))
    ok, st, secs = wait_for(lambda s: s["settings"]["profile"] == "eco" and s["settings"]["intensity"] == 0.7, timeout)
    logged = "settings profile=eco" in log_tail(off)
    rep.check("hot-reload", ok and logged, seconds=secs, logLine=logged, settings=core(st["settings"]))
    eco_settings = core(st["settings"])

    # malformed: previous settings must stay
    off = log_size()
    write_in_place(b'{ "profile": "smooth", "rain": { "intensity": ')
    time.sleep(3)
    st = ipc("status")
    new_log = log_tail(off)
    kept = core(st["settings"]) == eco_settings
    warned = "config parse error, keeping previous config" in new_log
    rep.check("malformed-keeps-previous", kept and warned, keptPrevious=kept, parseWarning=warned,
              settings=core(st["settings"]),
              warnLines=[l for l in new_log.splitlines() if "neon-rain" in l][:4])

    # recover with a valid edit
    edit2 = json.loads(original)
    edit2["profile"] = "smooth"
    off = log_size()
    write_in_place(dump(edit2))
    ok, st, secs = wait_for(lambda s: s["settings"]["profile"] == "smooth"
                            and s["settings"]["intensity"] == base_intensity, timeout)
    rep.check("recover-after-malformed", ok and "settings profile=smooth" in log_tail(off),
              seconds=secs, settings=core(st["settings"]))

    # unknown profile: documented fallback to balanced plus a warning
    edit3 = json.loads(original)
    edit3["profile"] = "turbo"
    off = log_size()
    write_in_place(dump(edit3))
    ok, st, secs = wait_for(lambda s: any("unknown profile 'turbo'" in w for w in s["settings"]["warnings"]), timeout)
    logged = "unknown profile 'turbo'" in log_tail(off)
    rep.check("unknown-profile-fallback", ok and st["settings"]["profile"] == "balanced" and logged,
              seconds=secs, profile=st["settings"]["profile"], warnings=st["settings"]["warnings"], logged=logged)

    # IPC override beats config; clearing it returns to the config value
    ipc("setProfile", "eco")
    edit4 = json.loads(original)
    edit4["profile"] = "smooth"
    write_in_place(dump(edit4))
    time.sleep(2)
    st = ipc("status")
    held = st["settings"]["profile"] == "eco" and st["overrides"]["profile"] == "eco"
    ipc("clearOverrides")
    ok, st2, secs = wait_for(lambda s: s["settings"]["profile"] == "smooth", timeout)
    rep.check("ipc-override-wins", held and ok, overrideHeld=held, afterClear=st2["settings"]["profile"])


def restore_config(rep, original, base_settings, base_overrides, timeout):
    write_in_place(original)
    with open(CONFIG, "rb") as f:
        now = f.read()
    restore_overrides(base_overrides)
    ok, st, secs = wait_for(lambda s: core(s["settings"]) == base_settings
                            and s["overrides"] == base_overrides, timeout)
    rep.check("restore-exact", now == original and ok, sha256Original=sha(original), sha256Now=sha(now),
              bytes=len(now), settingsEqual=core(st["settings"]) == base_settings,
              overridesEqual=st["overrides"] == base_overrides, overrides=st["overrides"], seconds=secs)


def stop_start_phase(rep, base_settings, base_overrides, timeout):
    with open(PIDFILE) as f:
        pid_before = f.read().strip()
    out = proto("stop")
    stopped = out.returncode == 0 and proto("status").returncode == 3
    rep.check("stop", stopped, pid=pid_before, out=out.stdout.strip())

    out = proto("start", timeout=40)
    pid_after = None
    if out.returncode == 0:
        with open(PIDFILE) as f:
            pid_after = f.read().strip()
    layers = [l for l in out.stdout.splitlines() if "layer=bottom ns=neon-rain-wallpaper" in l]
    rep.check("start", out.returncode == 0 and pid_after != pid_before and len(layers) == 3,
              pid=pid_after, layers=layers, err=out.stderr.strip()[-300:])

    # Overrides live in memory only, so a restart resets them; re-apply the pre-test values.
    restore_overrides(base_overrides)
    ok, st, secs = wait_for(lambda s: {x["output"] for x in s["surfaces"]} == OUTPUTS
                            and all(x["artworkStatus"] == "Ready" for x in s["surfaces"]), timeout)
    f1 = {x["output"]: x["framesSwapped"] for x in st["surfaces"]}
    time.sleep(2)
    st2 = ipc("status")
    f2 = {x["output"]: x["framesSwapped"] for x in st2["surfaces"]}
    growing = all(f2[o] > f1.get(o, 0) for o in f2)
    same = core(st2["settings"]) == base_settings and st2["overrides"] == base_overrides
    rep.check("recovered-after-restart", ok and growing and same, readySeconds=secs,
              frames1=f1, frames2=f2, settingsEqual=core(st2["settings"]) == base_settings,
              overrides=st2["overrides"], shaderHealth=[x["shader"]["health"] for x in st2["surfaces"]])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-stop-start", action="store_true")
    ap.add_argument("--timeout", type=float, default=10.0)
    a = ap.parse_args()

    if proto("status").returncode != 0:
        sys.exit("prototype not running; start it with scripts/neon-rain-proto start")
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    rep = Report(os.path.join(RESULTS, f"reliability-{stamp}.json"))

    with open(CONFIG, "rb") as f:
        original = f.read()
    backup = os.path.join(RESULTS, f"reliability-{stamp}-config-backup.json")
    with open(backup, "wb") as f:
        f.write(original)
    st = ipc("status")
    base_settings, base_overrides = core(st["settings"]), st["overrides"]
    rep.data.update(configSha256=sha(original), configBackup=os.path.relpath(backup, ROOT),
                    inodeBefore=os.stat(CONFIG).st_ino, baseSettings=base_settings, baseOverrides=base_overrides)
    rep.flush()

    for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(s, on_signal)
    try:
        config_phase(rep, original, a.timeout)
    except Exception as e:  # recorded; restore still runs below
        rep.check("config-phase-exception", False, error=repr(e))
    finally:
        for s in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
            signal.signal(s, signal.SIG_IGN)
        try:
            restore_config(rep, original, base_settings, base_overrides, a.timeout)
        except Exception as e:
            write_in_place(original)
            rep.check("restore-exact", False, error=repr(e))
        rep.data["inodeAfter"] = os.stat(CONFIG).st_ino

    if not a.skip_stop_start:
        try:
            stop_start_phase(rep, base_settings, base_overrides, a.timeout)
        except Exception as e:
            rep.check("stop-start-exception", False, error=repr(e))
            if proto("status").returncode == 3:
                rep.check("emergency-start", proto("start", timeout=40).returncode == 0)

    rep.data["finished"] = datetime.now().isoformat(timespec="seconds")
    rep.flush()
    print(f"report: {os.path.relpath(rep.path, ROOT)} passed={rep.data['passed']} failed={rep.data['failed']}")
    sys.exit(1 if rep.data["failed"] else 0)


if __name__ == "__main__":
    main()
