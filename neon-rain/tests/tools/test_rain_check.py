#!/usr/bin/env python3
"""Regression tests for rain_check.py on synthetic images (no compositor needed)."""
import os
import sys
import unittest

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import rain_check  # noqa: E402

rng = np.random.default_rng(7)
ART = Image.fromarray(rng.integers(0, 200, (94, 167, 3), dtype=np.uint8))  # 16:9-ish
PORTRAIT_CROP = {"srcX": 57.0, "srcY": 0.0, "srcW": 53.0, "srcH": 94.0}
W, H = 54, 96


def rain(img, seed):
    out = img.copy()
    r = np.random.default_rng(seed)
    for x in r.integers(0, W, 12):
        y = int(r.integers(0, H - 10))
        out[y:y + 8, x] = np.minimum(out[y:y + 8, x] + 120, 255)
    return out


class RainCheckTest(unittest.TestCase):
    def setUp(self):
        self.ref = rain_check.cover_reference(ART, PORTRAIT_CROP, W, H)

    def test_animated_cover_crop_passes(self):
        res = rain_check.check_surface(ART, PORTRAIT_CROP, rain(self.ref, 1), rain(self.ref, 2))
        self.assertTrue(res["pass"], res)

    def test_static_image_fails_animation(self):
        frame = rain(self.ref, 1)
        res = rain_check.check_surface(ART, PORTRAIT_CROP, frame, frame.copy())
        self.assertFalse(res["animated"], res)
        self.assertFalse(res["pass"])

    def test_stretched_passthrough_fails_cover_crop(self):
        stretch = np.asarray(ART.resize((W, H), Image.BILINEAR)).astype(np.int16)
        res = rain_check.check_surface(ART, PORTRAIT_CROP, rain(stretch, 1), rain(stretch, 2))
        self.assertFalse(res["coverCrop"], res)
        self.assertFalse(res["pass"])

    def test_size_mismatch_fails(self):
        res = rain_check.check_surface(ART, PORTRAIT_CROP, self.ref, self.ref[:10])
        self.assertFalse(res["pass"])


if __name__ == "__main__":
    unittest.main()
