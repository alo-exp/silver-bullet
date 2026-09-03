#!/usr/bin/env python3
"""
Generate a clean metallic bullet PNG from scratch.
Uses supersampling + numpy gradient fills for perfect anti-aliasing.
"""
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import math

# ── Output dimensions (match current bullet.png) ────────────────────────────
OUT_W, OUT_H = 188, 229
SS = 4                          # supersampling factor
W, H = OUT_W * SS, OUT_H * SS  # working canvas

# ── Bullet axis geometry (in SS-scaled pixels) ────────────────────────────
# Tip at upper-right, base at lower-left  (matches original orientation)
TIP  = (148 * SS, 20  * SS)   # ogive tip
BASE = (30  * SS, 208 * SS)   # base centre

ax = BASE[0] - TIP[0]   # axis vector (tip → base)
ay = BASE[1] - TIP[1]
AXIS_LEN = math.hypot(ax, ay)

ux, uy = ax / AXIS_LEN, ay / AXIS_LEN           # unit axis (tip→base)
px, py = -uy, ux                                 # perp unit (90° CCW = upper-left = highlight side)

CYL_R    = 28 * SS   # cylinder half-width
RIM_R    = 23 * SS   # rim (base band) half-width
SHOULDER_T = 0.30    # fraction where ogive meets cylinder (short = round pistol-style)
RIM_T      = 0.80    # fraction where cylinder meets base band
END_T      = 1.00    # bullet end

# ── Coordinate helpers ───────────────────────────────────────────────────────
def along(t):
    """Centre point at fraction t along axis."""
    return TIP[0] + t * ax, TIP[1] + t * ay

def edge(t, r, side):
    """
    Edge point: side=+1 is upper-left (highlight), side=-1 is lower-right.
    """
    cx, cy = along(t)
    return cx + side * r * px, cy + side * r * py

# ── Build bullet silhouette polygon ─────────────────────────────────────────
def ogive_profile(side, n=40):
    """
    Points for one side of the ogive (tip → shoulder).
    Uses a tangent-ogive curve: w = R * sqrt(1-(1-t)^2)
    """
    pts = []
    for i in range(n + 1):
        frac = i / n                                       # 0=tip, 1=shoulder
        t_global = SHOULDER_T * frac
        # Tangent ogive (circular arc) — rounder, pistol-bullet style
        w = CYL_R * math.sqrt(max(0.0, 1.0 - (1.0 - frac) ** 2))
        cx, cy = along(t_global)
        pts.append((cx + side * w * px, cy + side * w * py))
    return pts

def build_outline():
    pts = []

    # Tip point
    pts.append(TIP)

    # --- RIGHT side (lower-right face), tip → base ---
    right_ogive = ogive_profile(-1)
    for p in right_ogive[1:]:      # skip [0]=tip, already added
        pts.append(p)
    # cylinder right
    pts.append(edge(SHOULDER_T, CYL_R, -1))
    pts.append(edge(RIM_T,      CYL_R, -1))
    # rim step (slight inward notch)
    pts.append(edge(RIM_T,        RIM_R, -1))
    pts.append(edge(RIM_T + 0.01, RIM_R, -1))
    # base face (right → left)
    pts.append(edge(END_T, RIM_R, -1))
    pts.append(edge(END_T, RIM_R, +1))
    # rim step (left side)
    pts.append(edge(RIM_T + 0.01, RIM_R, +1))
    pts.append(edge(RIM_T,        RIM_R, +1))
    # cylinder left
    pts.append(edge(RIM_T,      CYL_R, +1))
    pts.append(edge(SHOULDER_T, CYL_R, +1))

    # --- LEFT side (upper-left face), shoulder → tip ---
    left_ogive = ogive_profile(+1)
    for p in reversed(left_ogive[:-1]):   # skip shoulder end, already added
        pts.append(p)

    return [(int(round(x)), int(round(y))) for x, y in pts]

OUTLINE = build_outline()

# ── Axis projection field (used by masks and gradients) ───────────────────────
ys_pre, xs_pre = np.mgrid[0:H, 0:W]
rel_x_pre = xs_pre.astype(np.float32) - TIP[0]
rel_y_pre = ys_pre.astype(np.float32) - TIP[1]
t_axis = np.clip((rel_x_pre * ux + rel_y_pre * uy) / AXIS_LEN, 0.0, 1.0)

# ── Rasterise mask ────────────────────────────────────────────────────────────
def make_mask(polygon, w, h):
    img = Image.new("L", (w, h), 0)
    ImageDraw.Draw(img).polygon(polygon, fill=255)
    return np.array(img, dtype=np.float32) / 255.0

MASK = make_mask(OUTLINE, W, H)

# Also separate masks for ogive, cylinder, rim
def section_mask(t_start, t_end, w, h):
    """Boolean strip along the bullet axis between two t values."""
    img = (t_axis >= t_start) & (t_axis < t_end)
    return img.astype(np.float32)

BLEND = 0.030   # blend half-width in t-units at each junction

def smooth_step(t, center, width):
    return np.clip((t_axis - (center - width)) / (2 * width), 0.0, 1.0)

# Three-way weight fields that sum to 1 everywhere inside bullet
w_cyl_from_ogv = smooth_step(t_axis, SHOULDER_T, BLEND)   # 0→1 across shoulder
w_rim_from_cyl = smooth_step(t_axis, RIM_T,      BLEND)   # 0→1 across rim start
W_OGV = MASK * (1.0 - w_cyl_from_ogv)
W_RIM = MASK * w_rim_from_cyl
W_CYL = MASK * (1.0 - W_OGV / np.maximum(MASK, 1e-6) - W_RIM / np.maximum(MASK, 1e-6))
W_CYL = MASK * np.clip(1.0 - (1.0 - w_cyl_from_ogv) - w_rim_from_cyl, 0.0, 1.0)

# ── Metallic gradient field ───────────────────────────────────────────────────
# "side" coordinate: projection of pixel onto perp axis, from -1 (lower-right)
# to +1 (upper-left / highlight side).
ys_g, xs_g = np.mgrid[0:H, 0:W]
rel_x_g = xs_g.astype(np.float32) - TIP[0]
rel_y_g = ys_g.astype(np.float32) - TIP[1]
# Perpendicular component (positive = upper-left = highlight side)
SIDE = (rel_x_g * px + rel_y_g * py) / CYL_R   # normalised to [-1, 1] at cylinder edge

# ── Colour palette helpers ────────────────────────────────────────────────────
def gradient(stops, t):
    """
    stops: list of (position, (R,G,B)) sorted by position in [0,1].
    t: ndarray of values in [0, 1].
    Returns (H, W, 3) uint8 array.
    """
    result = np.zeros(t.shape + (3,), dtype=np.float32)
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        mask = (t >= t0) & (t <= t1)
        frac = np.where(mask, (t - t0) / max(t1 - t0, 1e-6), 0.0)[..., None]
        c0a = np.array(c0, dtype=np.float32)
        c1a = np.array(c1, dtype=np.float32)
        result += np.where(mask[..., None], c0a + frac * (c1a - c0a), 0.0)
    return np.clip(result, 0, 255).astype(np.uint8)

# ── Cylinder metallic gradient ────────────────────────────────────────────────
# Maps SIDE ∈ [-1, +1] to [0, 1] for colour lookup.
# Bright edge is at SIDE → +0.85 (not full +1, which would be extreme)
t_cyl = np.clip((SIDE + 1.0) / 2.0, 0.0, 1.0)

CYL_STOPS = [
    (0.00, (148, 157, 166)),   # lower-right edge
    (0.09, (112, 121, 130)),   # shadow deepens
    (0.20, ( 80,  88,  97)),   # deep shadow
    (0.30, ( 72,  80,  89)),   # darkest (shadow floor)
    (0.45, ( 96, 106, 115)),   # reflected light starts
    (0.58, (138, 149, 158)),   # reflected light
    (0.68, (175, 185, 194)),   # rising
    (0.78, (208, 216, 224)),   # brightening
    (0.86, (234, 240, 246)),   # near-bright
    (0.92, (250, 253, 255)),   # specular
    (0.96, (255, 255, 255)),   # hotspot peak
    (1.00, (212, 219, 226)),   # edge falloff
]
CYL_COLOR = gradient(CYL_STOPS, t_cyl)

# ── Ogive metallic gradient ───────────────────────────────────────────────────
# As ogive tapers, the shadow side gets progressively darker toward the tip
t_ogv = np.clip((SIDE * 0.90 + 1.0) / 2.0, 0.0, 1.0)

# Compute "how far into the ogive" each pixel is (0=tip, 1=shoulder)
t_in_ogive = np.clip(t_axis / SHOULDER_T, 0.0, 1.0)
# Shadow side gets darker closer to tip; highlight side stays bright
shadow_side = np.clip(-SIDE, 0.0, 1.0)   # 1.0 on shadow side, 0 on highlight
tip_darken  = (1.0 - t_in_ogive) * shadow_side * 0.40   # darkens toward tip on shadow

OGV_STOPS = [
    (0.00, (118, 127, 137)),
    (0.14, ( 90,  99, 109)),
    (0.28, ( 62,  70,  80)),   # shadow trough — matches cylinder depth
    (0.46, (108, 120, 130)),
    (0.62, (175, 187, 197)),
    (0.78, (228, 237, 244)),
    (0.90, (250, 254, 255)),
    (1.00, (255, 255, 255)),
]
OGV_COLOR_BASE = gradient(OGV_STOPS, t_ogv).astype(np.float32)
OGV_COLOR = np.clip(OGV_COLOR_BASE * (1.0 - tip_darken[..., None]), 0, 255).astype(np.uint8)

# ── Rim (base band) gradient ──────────────────────────────────────────────────
# Darker gun-metal appearance with less specular than cylinder
t_rim = np.clip((SIDE * 0.70 + 1.0) / 2.0, 0.0, 1.0)

RIM_STOPS = [
    (0.00, ( 88,  94, 102)),
    (0.18, ( 70,  76,  84)),
    (0.38, ( 60,  66,  74)),   # darkest
    (0.56, ( 72,  78,  86)),
    (0.72, ( 98, 105, 113)),
    (0.88, (122, 129, 137)),
    (1.00, (108, 116, 124)),
]
RIM_COLOR = gradient(RIM_STOPS, t_rim)

# ── Compose RGBA image (3-way weighted blend, sums to 1) ─────────────────────
def ch(color, c):
    return color[..., c].astype(np.float32)

canvas_r = ch(OGV_COLOR,0)*W_OGV + ch(CYL_COLOR,0)*W_CYL + ch(RIM_COLOR,0)*W_RIM
canvas_g = ch(OGV_COLOR,1)*W_OGV + ch(CYL_COLOR,1)*W_CYL + ch(RIM_COLOR,1)*W_RIM
canvas_b = ch(OGV_COLOR,2)*W_OGV + ch(CYL_COLOR,2)*W_CYL + ch(RIM_COLOR,2)*W_RIM

# no shoulder ring — the gradient handles the visual transition naturally

canvas = np.stack([
    np.clip(canvas_r, 0, 255).astype(np.uint8),
    np.clip(canvas_g, 0, 255).astype(np.uint8),
    np.clip(canvas_b, 0, 255).astype(np.uint8),
    (MASK * 255).astype(np.uint8),
], axis=-1)

img_big = Image.fromarray(canvas, "RGBA")

# ── Downsample to final size ──────────────────────────────────────────────────
img_final = img_big.resize((OUT_W, OUT_H), Image.LANCZOS)

# ── Save ─────────────────────────────────────────────────────────────────────
out_path = "/Users/shafqat/Documents/Projects/silver-bullet/site/bullet-new.png"
img_final.save(out_path, "PNG")
print(f"Saved: {out_path}  ({OUT_W}x{OUT_H})")
