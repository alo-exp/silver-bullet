#!/usr/bin/env python3
"""Generate light-themed Open Graph image (1200x630) for sb.alolabs.dev."""
from __future__ import annotations

import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
TOKENS_CSS = ROOT / "tokens.css"
OUT = ROOT / "og-image.png"
BULLET = ROOT / "silver-bullet.png"
FONT_BOLD = ROOT / "fonts" / "alte-din-1451-mittelschrift.regular.ttf"
FONT_REG = ROOT / "fonts" / "Gidole-Regular.ttf"

W, H = 1200, 630

BG_STOPS = [
    (0.00, (234, 228, 218)),
    (0.25, (238, 232, 222)),
    (0.48, (244, 240, 232)),
    (0.62, (246, 242, 234)),
    (0.80, (240, 236, 228)),
    (1.00, (234, 230, 220)),
]

CHROME_STOPS = [
    (0.00, (42, 42, 42)),
    (0.09, (88, 88, 88)),
    (0.18, (56, 56, 56)),
    (0.27, (40, 40, 40)),
    (0.36, (80, 80, 80)),
    (0.43, (68, 68, 68)),
    (0.51, (48, 48, 48)),
    (0.59, (72, 72, 72)),
    (0.68, (52, 52, 52)),
    (0.76, (36, 36, 36)),
    (0.86, (64, 64, 64)),
    (1.00, (30, 30, 30)),
]


def _parse_hex(value: str) -> tuple[int, int, int]:
    value = value.strip().lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16))


def _parse_rgba(value: str) -> tuple[int, int, int, float]:
    parts = [part.strip() for part in value.removeprefix("rgba(").removesuffix(")").split(",")]
    return (int(parts[0]), int(parts[1]), int(parts[2]), float(parts[3]))


def load_light_tokens(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    dark_idx = text.find('[data-theme="dark"]')
    root_text = text[:dark_idx] if dark_idx >= 0 else text
    return {
        match.group(1): match.group(2).strip()
        for match in re.finditer(r"--([\w-]+)\s*:\s*([^;]+);", root_text)
    }


def _token_rgb(tokens: dict[str, str], name: str) -> tuple[int, int, int]:
    value = tokens[name]
    if value.startswith("#"):
        return _parse_hex(value)
    raise ValueError(f"Token --{name} is not a hex color: {value!r}")


def _token_rgba(tokens: dict[str, str], name: str) -> tuple[int, int, int, float]:
    return _parse_rgba(tokens[name])


def _alpha255(alpha: float) -> int:
    return max(0, min(255, int(round(alpha * 255))))


TOKENS = load_light_tokens(TOKENS_CSS)
ACCENT = _token_rgb(TOKENS, "accent")
ACCENT_LIGHT = _token_rgb(TOKENS, "accent-light")
ACCENT2 = _token_rgb(TOKENS, "accent2")
TEXT_PRIMARY = _token_rgb(TOKENS, "text-primary")
TEXT_SECONDARY = _token_rgb(TOKENS, "text-secondary")
TEXT_DIM = _token_rgb(TOKENS, "text-dim")
GRAD_1 = _token_rgb(TOKENS, "grad-1")
GRAD_2 = _token_rgb(TOKENS, "grad-2")
MINT_GLOW = _token_rgba(TOKENS, "mint-a28")[:3]
MINT_FILL = _token_rgba(TOKENS, "mint-a14")
MINT_OUTLINE = _token_rgba(TOKENS, "mint-a28")
MINT_BADGE_OUTLINE = _token_rgba(TOKENS, "mint-a35")
GRID_ALPHA = _alpha255(0.05)


def lerp_color(c0: tuple[int, int, int], c1: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return tuple(int(a + (b - a) * t) for a, b in zip(c0, c1))


def sample_stops(stops: list[tuple[float, tuple[int, int, int]]], t: float) -> tuple[int, int, int]:
    for i in range(len(stops) - 1):
        t0, c0 = stops[i]
        t1, c1 = stops[i + 1]
        if t0 <= t <= t1:
            frac = (t - t0) / max(t1 - t0, 1e-6)
            return lerp_color(c0, c1, frac)
    return stops[-1][1]


def gradient_h(width: int, stops: list[tuple[float, tuple[int, int, int]]]) -> Image.Image:
    img = Image.new("RGB", (width, 80))
    px = img.load()
    for x in range(width):
        c = sample_stops(stops, x / max(width - 1, 1))
        for y in range(80):
            px[x, y] = c
    return img


def gradient_bg(width: int, height: int) -> Image.Image:
    img = Image.new("RGB", (width, height))
    px = img.load()
    angle = math.radians(160)
    cos_a, sin_a = math.cos(angle), math.sin(angle)
    diag = width * cos_a + height * sin_a
    for y in range(height):
        for x in range(width):
            t = (x * cos_a + y * sin_a) / diag
            px[x, y] = sample_stops(BG_STOPS, t)
    return img


def add_glow(canvas: Image.Image, cx: int, cy: int, radius: int, color: tuple[int, int, int], alpha: float) -> None:
    glow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(glow)
    for r in range(radius, 0, -8):
        a = int(255 * alpha * (1 - r / radius) ** 2)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, a))
    glow = glow.filter(ImageFilter.GaussianBlur(radius // 4))
    canvas.alpha_composite(glow)


def add_grid(canvas: Image.Image) -> None:
    """Very subtle full-canvas grid — no masked dark regions."""
    grid = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(grid)
    step = 48
    line = (*ACCENT, GRID_ALPHA)
    for x in range(0, W, step):
        draw.line((x, 0, x, H), fill=line, width=1)
    for y in range(0, H, step):
        draw.line((0, y, W, y), fill=line, width=1)
    canvas.alpha_composite(grid)


def draw_gradient_text(
    canvas: Image.Image,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.FreeTypeFont,
    grad: Image.Image,
) -> None:
    bbox = font.getbbox(text)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x, y = xy
    mask = Image.new("L", (tw + 4, th + 4), 0)
    ImageDraw.Draw(mask).text((-bbox[0] + 2, -bbox[1] + 2), text, font=font, fill=255)
    grad_crop = grad.resize((tw + 4, th + 4), Image.LANCZOS)
    grad_crop.putalpha(mask)
    canvas.paste(grad_crop, (x, y), grad_crop)


def rounded_rect(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, ...],
    outline: tuple[int, ...] | None = None,
    width: int = 1,
) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def main() -> None:
    base = gradient_bg(W, H).convert("RGBA")
    add_glow(base, 120, 80, 320, MINT_GLOW, MINT_FILL[3])
    add_glow(base, 1050, 520, 260, MINT_GLOW, _token_rgba(TOKENS, "mint-a18")[3])
    add_grid(base)
    draw = ImageDraw.Draw(base)

    for x in range(W):
        t = x / W
        edge = min(t, 1 - t) / 0.35
        a = max(0.0, min(1.0, edge))
        c = lerp_color((234, 228, 218), ACCENT, a * 0.95)
        draw.line((x, 0, x, 3), fill=(*c, 255))

    for y in range(H):
        t = y / H
        a = int(180 * (1 - abs(t - 0.15) * 2.2))
        a = max(0, min(180, a))
        draw.line((0, y, 4, y), fill=(*ACCENT, a))

    font_label = ImageFont.truetype(str(FONT_BOLD), 15)
    font_title = ImageFont.truetype(str(FONT_BOLD), 78)
    font_tag_caps = ImageFont.truetype(str(FONT_BOLD), 16)
    font_headline = ImageFont.truetype(str(FONT_BOLD), 34)
    font_sub = ImageFont.truetype(str(FONT_REG), 22)
    font_pill = ImageFont.truetype(str(FONT_BOLD), 13)
    font_mono = ImageFont.truetype(str(FONT_REG), 14)
    font_small = ImageFont.truetype(str(FONT_REG), 13)

    chrome_grad = gradient_h(900, CHROME_STOPS)

    bullet = Image.open(BULLET).convert("RGBA")
    bullet_h = 130
    bullet_w = int(bullet.width * bullet_h / bullet.height)
    bullet = bullet.resize((bullet_w, bullet_h), Image.LANCZOS)
    shadow = Image.new("RGBA", bullet.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        (8, bullet_h - 18, bullet_w - 8, bullet_h + 8), fill=(0, 0, 0, 45)
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(6))
    bx, by = 72, 210
    base.alpha_composite(shadow, (bx, by + 4))
    base.alpha_composite(bullet, (bx, by))

    rounded_rect(
        draw,
        (W - 250, 34, W - 44, 64),
        14,
        fill=(*MINT_FILL[:3], _alpha255(MINT_FILL[3])),
        outline=(*MINT_BADGE_OUTLINE[:3], _alpha255(MINT_BADGE_OUTLINE[3])),
        width=1,
    )
    draw.text((W - 236, 42), "ALPHA · v0.48.5", font=font_mono, fill=ACCENT_LIGHT)

    label = "Agentic Process Orchestrator for the AI Era"
    lb = font_label.getbbox(label)
    lw = lb[2] - lb[0]
    lx, ly = 300, 118
    rounded_rect(
        draw,
        (lx - 14, ly - 8, lx + lw + 14, ly + 24),
        12,
        fill=(*MINT_FILL[:3], _alpha255(MINT_FILL[3])),
        outline=(*MINT_OUTLINE[:3], _alpha255(MINT_OUTLINE[3])),
    )
    draw.text((lx, ly), label, font=font_label, fill=ACCENT_LIGHT)

    draw_gradient_text(base, (300, 158), "Silver Bullet", font_title, chrome_grad)
    draw.text((300, 252), "THE PROCESS LAYER OF AI-DRIVEN DEV", font=font_tag_caps, fill=ACCENT_LIGHT)
    draw.text((300, 296), "Maximize AI-driven", font=font_headline, fill=TEXT_PRIMARY)
    draw.text((300, 338), "Dev Process Reliability", font=font_headline, fill=ACCENT_LIGHT)
    draw.text((300, 396), "From spec to release · hook-enforced AI-native delivery", font=font_sub, fill=TEXT_SECONDARY)
    draw.text(
        (300, 432),
        "27 AF-* atomic flows · 22 WF-* workflows · V-loop evidence · delivery gates",
        font=font_small,
        fill=TEXT_DIM,
    )

    pills = ["Hook Gates", "Claude · Codex · Cursor"]
    px = 300
    py = 478
    for pill in pills:
        pb = font_pill.getbbox(pill)
        pw = pb[2] - pb[0]
        rounded_rect(
            draw,
            (px, py, px + pw + 24, py + 28),
            14,
            fill=(*MINT_FILL[:3], _alpha255(MINT_FILL[3])),
            outline=(*MINT_OUTLINE[:3], _alpha255(MINT_OUTLINE[3])),
        )
        draw.text((px + 12, py + 6), pill, font=font_pill, fill=ACCENT_LIGHT)
        px += pw + 36

    draw.text((W - 170, H - 42), "sb.alolabs.dev", font=font_mono, fill=TEXT_DIM)
    draw.text((48, H - 42), "Alo Labs", font=font_mono, fill=TEXT_DIM)

    final = base.convert("RGB")
    final.save(OUT, "PNG", optimize=True)
    print(f"Saved {OUT} ({final.size[0]}x{final.size[1]})")
    print(
        "Tokens:",
        f"accent=#{ACCENT[0]:02x}{ACCENT[1]:02x}{ACCENT[2]:02x}",
        f"accent-light=#{ACCENT_LIGHT[0]:02x}{ACCENT_LIGHT[1]:02x}{ACCENT_LIGHT[2]:02x}",
        f"grad-1=#{GRAD_1[0]:02x}{GRAD_1[1]:02x}{GRAD_1[2]:02x}",
        f"grad-2=#{GRAD_2[0]:02x}{GRAD_2[1]:02x}{GRAD_2[2]:02x}",
    )


if __name__ == "__main__":
    main()
