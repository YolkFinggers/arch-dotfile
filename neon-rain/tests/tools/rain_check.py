#!/usr/bin/env python3
"""Pixel proof that the custom rain shader is drawing, from wallpaper-only captures.

For each output it compares two captures taken at different times and the plain
cover-cropped artwork:

  animated   : enough pixels change between capture A and B (only the shader's `time`
               uniform changes, so Qt's default passthrough shader would give 0 change).
  coverCrop  : capture A matches the cover-cropped artwork closely, and deviations are
               brighter-only (additive rain). uvScale/uvOffset exist only in rain.frag,
               so a stretched (passthrough) image fails this on non-16:9 outputs.

Usage: rain_check.py <artwork.png> <status.json> <captureA-prefix> <captureB-prefix>
Exits 0 only if every surface passes. Prints one JSON line per surface.
"""
import json
import sys

import numpy as np
from PIL import Image

# Thresholds (fractions of pixels). Live balanced profile measured ~2.3% changed and
# ~0.6% brighter, so these leave wide margins while rejecting a static image.
MIN_CHANGED = 0.002     # >0.2% pixels change by more than 8 levels between A and B
MAX_MEAN_ABS = 4.0      # capture vs cover-crop reference, mean absolute difference
MAX_DARKER = 0.002      # rain only adds light: <0.2% pixels darker by more than 24


def load(path):
    return np.asarray(Image.open(path).convert("RGB")).astype(np.int16)


def cover_reference(art, crop, width, height):
    box = (crop["srcX"], crop["srcY"], crop["srcX"] + crop["srcW"], crop["srcY"] + crop["srcH"])
    return np.asarray(art.resize((width, height), Image.BILINEAR, box=box)).astype(np.int16)


def check_surface(art, crop, a, b):
    if a.shape != b.shape:
        return {"pass": False, "reason": f"capture size mismatch {a.shape} vs {b.shape}"}
    height, width = a.shape[:2]
    changed = float((np.abs(a - b).max(axis=2) > 8).mean())
    d = a - cover_reference(art, crop, width, height)
    mean_abs = float(np.abs(d).mean())
    brighter = float((d.max(axis=2) > 24).mean())
    darker = float((d.min(axis=2) < -24).mean())
    animated = changed >= MIN_CHANGED
    cover = mean_abs <= MAX_MEAN_ABS and darker <= MAX_DARKER
    return {
        "pass": animated and cover,
        "animated": animated,
        "coverCrop": cover,
        "changedPct": round(100 * changed, 3),
        "meanAbsVsCrop": round(mean_abs, 2),
        "brighterPct": round(100 * brighter, 3),
        "darkerPct": round(100 * darker, 3),
    }


def main(argv):
    if len(argv) != 5:
        print(__doc__, file=sys.stderr)
        return 2
    art = Image.open(argv[1]).convert("RGB")
    with open(argv[2]) as f:
        status = json.load(f)
    ok = bool(status.get("surfaces"))
    for s in status.get("surfaces", []):
        out = s["output"]
        try:
            res = check_surface(art, s["crop"], load(f"{argv[3]}-{out}.png"), load(f"{argv[4]}-{out}.png"))
        except (OSError, KeyError, TypeError) as e:
            res = {"pass": False, "reason": str(e)}
        res = {"output": out, **res}
        ok = ok and res["pass"]
        print(json.dumps(res))
    print("RESULT:", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
