#!/usr/bin/env python3
"""Post-hoc analysis of the Ticket-07 photometry frames.

Mean luminance alone cannot answer "can I see the walls?" — a frame can be bright and
still be a blank sheet, or dim and still be perfectly legible. What matters is whether
local structure survives: gradient energy (edges), histogram distinctness, and whether
adjacent regions of the room resolve to different levels.
"""
import sys
from PIL import Image
import numpy as np

FRAMES = [
    ("REF normal (clean)", "t07_0_ref_normal.png"),
    ("A  OLD clinical    ", "t07_A_old_clinical.png"),
    ("B  NEW clinical    ", "t07_B_new_clinical.png"),
    ("C  SUBDUED         ", "t07_C_subdued.png"),
]

W = np.array([0.2126, 0.7152, 0.0722])


def load(path):
    im = Image.open(path).convert("RGB")
    a = np.asarray(im, dtype=np.float64) / 255.0
    return a @ W  # luminance map


def stats(lum):
    gx = np.abs(np.diff(lum, axis=1))          # horizontal gradient
    gy = np.abs(np.diff(lum, axis=0))          # vertical gradient
    edge = np.concatenate([gx.ravel(), gy.ravel()])
    mean_edge = edge.mean()
    # Fraction of pixels sitting on a real edge (>=2% luminance step to a neighbour)
    strong = (edge > 0.02).mean()
    # Distinctness: how many of the 256 buckets actually get used, and how evenly.
    hist, _ = np.histogram(lum, bins=256, range=(0.0, 1.0))
    used = (hist > 0).sum()
    p = hist[hist > 0] / hist.sum()
    entropy = float(-(p * np.log2(p)).sum())
    # Region resolution: compare the 4 quadrants + a mid-band. If the room were a flat
    # wash these collapse onto each other.
    h, w = lum.shape
    quads = [
        lum[: h // 2, : w // 2].mean(),
        lum[: h // 2, w // 2:].mean(),
        lum[h // 2:, : w // 2].mean(),
        lum[h // 2:, w // 2:].mean(),
    ]
    return dict(
        mean=lum.mean(),
        p05=np.percentile(lum, 5),
        p95=np.percentile(lum, 95),
        spread=np.percentile(lum, 95) - np.percentile(lum, 5),
        pure_white=float(((lum > 0.995) & (lum > 0.99)).mean() * 100),
        crushed=float((lum < 0.03).mean() * 100),
        edge=mean_edge,
        strong_edge_pct=float(strong * 100),
        buckets=int(used),
        entropy=entropy,
        region_delta=max(quads) - min(quads),
    )


print(f"{'frame':22s} {'mean':>6s} {'spread':>7s} {'white%':>7s} {'crush%':>7s} "
      f"{'edge':>7s} {'strEdge%':>9s} {'bkt':>4s} {'H(bits)':>8s} {'regionD':>8s}")
print("-" * 100)

rows = {}
for label, fn in FRAMES:
    try:
        lum = load(f"/Users/alain/Desktop/Game/.qwen/tmp/{fn}")
    except FileNotFoundError:
        print(f"{label:22s}  (missing {fn})")
        continue
    s = stats(lum)
    rows[label] = s
    print(f"{label:22s} {s['mean']:6.3f} {s['spread']:7.3f} {s['pure_white']:7.3f} "
          f"{s['crushed']:7.2f} {s['edge']:7.4f} {s['strong_edge_pct']:9.2f} "
          f"{s['buckets']:4d} {s['entropy']:8.2f} {s['region_delta']:8.3f}")

print("\nInterpretation targets:")
print("  edge / strEdge%  -> geometry legibility. A blown-out or crushed frame loses edges.")
print("  buckets/H(bits)  -> tonal distinctness. Flat wash = few buckets, low entropy.")
print("  regionD          -> do different parts of the room resolve differently?")

ref = rows.get("REF normal (clean)")
if ref:
    print(f"\nRelative to the clean-room reference (edge={ref['edge']:.4f}, "
          f"entropy={ref['entropy']:.2f}):")
    for label, s in rows.items():
        if label.startswith("REF"):
            continue
        print(f"  {label}: edge {s['edge']/ref['edge']:5.2f}x   "
              f"entropy {s['entropy']-ref['entropy']:+5.2f} bits   "
              f"mean {s['mean']/ref['mean']:5.2f}x")
