#!/usr/bin/env python3
"""
Extract the bullet from the Grok checkerboard-background JPEG.
Uses BFS flood-fill from border: any connected achromatic light pixel
(checkerboard tile) becomes transparent.
"""
from PIL import Image, ImageFilter
import numpy as np
from collections import deque

src = "/Users/shafqat/Documents/Projects/silver-bullet/site/bullet-grok2.jpg"
dst = "/Users/shafqat/Documents/Projects/silver-bullet/site/bullet.png"

img  = Image.open(src).convert("RGB")
arr  = np.array(img, dtype=np.int32)
h, w = arr.shape[:2]

# ── Background eligibility ────────────────────────────────────────────────────
# Checkerboard has two tones: near-white (~255) and mid-gray (~192).
# Both are achromatic (R≈G≈B). Bullet has slight blue-steel tint and darker.
# Threshold: pixel is BG-eligible if it is light AND achromatic.
def is_bg(y, x):
    r, g, b = arr[y, x]
    lum     = int(r + g + b) // 3
    chroma  = max(abs(int(r)-int(g)), abs(int(g)-int(b)), abs(int(r)-int(b)))
    # Both checkerboard tones: lum > 165, chroma < 18
    return lum > 165 and chroma < 22

# ── BFS from all four borders ─────────────────────────────────────────────────
is_bg_mask = np.zeros((h, w), dtype=bool)
for y in range(h):
    for x in range(w):
        if is_bg(y, x):
            is_bg_mask[y, x] = True

visited = np.zeros((h, w), dtype=bool)
queue   = deque()

for y in range(h):
    for x in [0, w-1]:
        if is_bg_mask[y, x] and not visited[y, x]:
            visited[y, x] = True
            queue.append((y, x))
for x in range(w):
    for y in [0, h-1]:
        if is_bg_mask[y, x] and not visited[y, x]:
            visited[y, x] = True
            queue.append((y, x))

while queue:
    y, x = queue.popleft()
    for dy, dx in ((-1,0),(1,0),(0,-1),(0,1)):
        ny, nx = y+dy, x+dx
        if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx] and is_bg_mask[ny, nx]:
            visited[ny, nx] = True
            queue.append((ny, nx))

bg_mask = visited   # True = background to remove

# ── Build RGBA ────────────────────────────────────────────────────────────────
rgba = np.zeros((h, w, 4), dtype=np.uint8)
rgba[..., :3] = arr.astype(np.uint8)
rgba[bg_mask, 3] = 0
rgba[~bg_mask, 3] = 255

# ── Erode alpha edge (1px) to kill JPEG fringe ───────────────────────────────
alpha = Image.fromarray(rgba[..., 3], "L")
alpha_e = alpha.filter(ImageFilter.MinFilter(3))
rgba[..., 3] = np.array(alpha_e)

# ── Rebuild mask after erosion ────────────────────────────────────────────────
bullet_mask = rgba[..., 3] > 0

# ── Crop to bullet bounding box + small margin ────────────────────────────────
rows = np.any(bullet_mask, axis=1)
cols = np.any(bullet_mask, axis=0)
r0, r1 = np.where(rows)[0][[0, -1]]
c0, c1 = np.where(cols)[0][[0, -1]]
PAD = 8
r0 = max(0, r0 - PAD); r1 = min(h-1, r1 + PAD)
c0 = max(0, c0 - PAD); c1 = min(w-1, c1 + PAD)

# Exclude Grok watermark (bottom ~60px of image)
WATERMARK_PX = 60
r1 = min(r1, h - WATERMARK_PX)

cropped = Image.fromarray(rgba[r0:r1+1, c0:c1+1], "RGBA")

# ── Resize to match current bullet.png dimensions (188x229) ──────────────────
cropped = cropped.resize((188, 229), Image.LANCZOS)

cropped.save(dst, "PNG")
print(f"Saved {dst}  (crop {c1-c0}x{r1-r0} → 188x229)")
