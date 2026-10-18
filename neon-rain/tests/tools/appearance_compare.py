#!/usr/bin/env python3
"""Wallpaper-only appearance comparison against the provided assets.

Usage: appearance_compare.py <status.json> <capture-prefix> <out-prefix>

For each surface capture (<capture-prefix>-<output>.png, made by IPC `capture`, so it holds
only the wallpaper item and never application windows) it reports:

  cropFidelity : capture vs assets/city-raw.png cover-cropped with the live crop from status.
                 Measures geometry/colour fidelity of the renderer (rain adds small deltas).
  vsStyleframe : capture vs assets/city-reference.png cover-cropped the same way. The
                 styleframe is a separate approved mock-up, so this number describes how
                 far the live wallpaper is from it; it is not a pass/fail threshold.

It also writes <out-prefix>-sheet.png: styleframe | raw | live captures, downscaled, for
human review. Subjective acceptance stays a human decision.
"""
import json
import os
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def cover(img, crop, w, h):
    box = (crop["srcX"], crop["srcY"], crop["srcX"] + crop["srcW"], crop["srcY"] + crop["srcH"])
    return np.asarray(img.resize((w, h), Image.BILINEAR, box=box)).astype(np.int16)


def stats(a, b):
    d = a - b
    return {"meanAbs": round(float(np.abs(d).mean()), 2),
            "p99Abs": round(float(np.percentile(np.abs(d).max(axis=2), 99)), 1),
            "meanSigned": [round(float(x), 2) for x in d.reshape(-1, 3).mean(axis=0)]}


def main(argv):
    with open(argv[1]) as f:
        status = json.load(f)
    prefix, out = argv[2], argv[3]
    raw = Image.open(os.path.join(ROOT, "assets/city-raw.png")).convert("RGB")
    ref = Image.open(os.path.join(ROOT, "assets/city-reference.png")).convert("RGB")
    result, thumbs = {}, [ref, raw]
    for s in status["surfaces"]:
        cap = Image.open(f"{prefix}-{s['output']}.png").convert("RGB")
        a = np.asarray(cap).astype(np.int16)
        h, w = a.shape[:2]
        result[s["output"]] = {"size": f"{w}x{h}", "crop": s["crop"],
                               "cropFidelity": stats(a, cover(raw, s["crop"], w, h)),
                               "vsStyleframe": stats(a, cover(ref, s["crop"], w, h))}
        thumbs.append(cap)
    result["rawVsStyleframeFull"] = stats(np.asarray(raw).astype(np.int16), np.asarray(ref).astype(np.int16))

    th = 360
    scaled = [t.resize((round(t.width * th / t.height), th), Image.LANCZOS) for t in thumbs]
    sheet = Image.new("RGB", (sum(t.width for t in scaled) + 10 * (len(scaled) - 1), th), (40, 40, 40))
    x = 0
    for t in scaled:
        sheet.paste(t, (x, 0))
        x += t.width + 10
    sheet.save(f"{out}-sheet.png")
    with open(f"{out}.json", "w") as f:
        json.dump(result, f, indent=2)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main(sys.argv)
