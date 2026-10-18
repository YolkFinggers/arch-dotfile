.pragma library

// Aspect-preserving "cover" crop between the master artwork and one output.
//
// The artwork is scaled uniformly by max(viewW / imgW, viewH / imgH) so it fills the
// output with no letterboxing and no stretching; the overflowing axis is cropped.
// focusX / focusY (0..1) pick which part of the overflowing axis stays visible:
// 0 = keep the left/top edge, 0.5 = centre, 1 = keep the right/bottom edge.
//
// The result is expressed in normalised texture space so the shader can do
//   imageUv = viewUv * uvScale + uvOffset
// and in pixels so future hotspots (M2+) can map artwork coordinates to the screen.

function clamp(v, lo, hi) {
    return Math.min(hi, Math.max(lo, v));
}

function isPositiveNumber(v) {
    return typeof v === "number" && isFinite(v) && v > 0;
}

function coverCrop(imgW, imgH, viewW, viewH, focusX, focusY) {
    if (!isPositiveNumber(imgW) || !isPositiveNumber(imgH) || !isPositiveNumber(viewW) || !isPositiveNumber(viewH))
        return null;

    const fx = clamp(typeof focusX === "number" && isFinite(focusX) ? focusX : 0.5, 0, 1);
    const fy = clamp(typeof focusY === "number" && isFinite(focusY) ? focusY : 0.5, 0, 1);

    const scale = Math.max(viewW / imgW, viewH / imgH);
    // Fraction of the artwork visible on each axis (1 on the axis that fits exactly).
    const uvScaleX = Math.min(1, viewW / (imgW * scale));
    const uvScaleY = Math.min(1, viewH / (imgH * scale));
    const uvOffsetX = (1 - uvScaleX) * fx;
    const uvOffsetY = (1 - uvScaleY) * fy;

    return {
        scale: scale,
        uvScaleX: uvScaleX,
        uvScaleY: uvScaleY,
        uvOffsetX: uvOffsetX,
        uvOffsetY: uvOffsetY,
        // Visible source rectangle in artwork pixels.
        srcX: uvOffsetX * imgW,
        srcY: uvOffsetY * imgH,
        srcW: uvScaleX * imgW,
        srcH: uvScaleY * imgH
    };
}

// Artwork pixel -> output pixel. Points outside the crop land outside [0, view).
function imageToView(crop, imgX, imgY) {
    return {
        x: (imgX - crop.srcX) * crop.scale,
        y: (imgY - crop.srcY) * crop.scale
    };
}

// Output pixel -> artwork pixel.
function viewToImage(crop, viewX, viewY) {
    return {
        x: crop.srcX + viewX / crop.scale,
        y: crop.srcY + viewY / crop.scale
    };
}
