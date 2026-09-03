#!/usr/bin/env python3
"""Generate Open Graph image (1200x630) for sb.alolabs.dev."""
from __future__ import annotations

import math
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
TOKENS_CSS = ROOT / "tokens.css"
OUT = ROOT / "og-image.png"
BULLET = ROOT / "silver-bullet.png"
FONT_BOLD = ROOT / "fonts" / "D-DIN-Bold.woff2"
FONT_REG = ROOT / "fonts" / "D-DIN.woff2"

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


def load_theme_tokens(path: Path, theme: str) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    if theme == "dark":
        start = text.find('[data-theme="dark"]')
        if start < 0:
            raise ValueError("Dark theme block not found")
        root_text = text[start:]
    else:
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


TOKENS = load_theme_tokens(TOKENS_CSS, "light")
ACCENT = _token_rgb(TOKENS, "accent")
ACCENT_LIGHT = _token_rgb(TOKENS, "accent-light")
ACCENT2 = _token_rgb(TOKENS, "accent2")
HERO_GREEN = ACCENT_LIGHT
TEXT_PRIMARY = _token_rgb(TOKENS, "text-primary")
TEXT_SECONDARY = _token_rgb(TOKENS, "text-secondary")
TEXT_DIM = _token_rgb(TOKENS, "text-dim")
BG_PAGE = _token_rgb(TOKENS, "bg-page")
BG_CARD = _token_rgb(TOKENS, "bg-card")
BORDER = _token_rgb(TOKENS, "border")
MINT_FILL = _token_rgba(TOKENS, "mint-a14")
MINT_OUTLINE = _token_rgba(TOKENS, "mint-a38")
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
    """Very subtle full-canvas grid."""
    grid = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(grid)
    step = 44
    line = (*ACCENT, _alpha255(0.045))
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


def draw_tracking_text(
    draw: ImageDraw.ImageDraw,
    xy: tuple[int, int],
    text: str,
    font: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int],
    target_width: int,
) -> None:
    x, y = xy
    natural_width = draw.textlength(text, font=font)
    gap_count = max(1, len(text) - 1)
    tracking = max(0, (target_width - natural_width) / gap_count)
    cursor = float(x)
    for char in text:
        draw.text((cursor, y), char, font=font, fill=fill)
        cursor += draw.textlength(char, font=font) + tracking


def rounded_rect(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    radius: int,
    fill: tuple[int, ...],
    outline: tuple[int, ...] | None = None,
    width: int = 1,
) -> None:
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def glow_line(
    canvas: Image.Image,
    points: list[tuple[int, int]],
    fill: tuple[int, int, int],
    width: int = 3,
    alpha: int = 170,
) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    ld.line(points, fill=(*fill, alpha), width=width, joint="curve")
    blur = layer.filter(ImageFilter.GaussianBlur(7))
    canvas.alpha_composite(blur)
    canvas.alpha_composite(layer)


def check_icon(size: int = 22, scale: int = 4) -> Image.Image:
    """Render a circle-check from vector geometry, then downsample for clean PNG edges."""
    s = size * scale
    icon = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    draw = ImageDraw.Draw(icon)
    stroke = max(2, int(round(size * 0.095))) * scale
    pad = int(round(size * 0.13)) * scale
    draw.ellipse((pad, pad, s - pad, s - pad), outline=(*HERO_GREEN, 255), width=stroke)
    points = [
        (size * 0.30 * scale, size * 0.52 * scale),
        (size * 0.44 * scale, size * 0.66 * scale),
        (size * 0.72 * scale, size * 0.36 * scale),
    ]
    draw.line(points, fill=(*HERO_GREEN, 255), width=stroke, joint="curve")
    return icon.resize((size, size), Image.Resampling.LANCZOS)


def draw_feature(draw: ImageDraw.ImageDraw, canvas: Image.Image, xy: tuple[int, int], text: str, font: ImageFont.FreeTypeFont) -> None:
    x, y = xy
    icon = check_icon()
    canvas.alpha_composite(icon, (x, y + 3))
    draw.text((x + 28, y), text, font=font, fill=TEXT_SECONDARY)


def main() -> None:
    base = gradient_bg(W, H).convert("RGBA")
    add_glow(base, 250, 130, 340, HERO_GREEN, 0.10)
    add_glow(base, 980, 500, 260, ACCENT2, 0.07)
    draw = ImageDraw.Draw(base)

    fonts = {
        "label": ImageFont.truetype(str(FONT_BOLD), 26),
        "title": ImageFont.truetype(str(FONT_BOLD), 72),
        "tag": ImageFont.truetype(str(FONT_BOLD), 22),
        "headline": ImageFont.truetype(str(FONT_BOLD), 56),
        "subhead": ImageFont.truetype(str(FONT_REG), 31),
        "feature": ImageFont.truetype(str(FONT_REG), 22),
    }

    chrome_grad = gradient_h(620, CHROME_STOPS)

    bullet = Image.open(BULLET).convert("RGBA")
    bullet_h = 104
    bullet_w = int(bullet.width * bullet_h / bullet.height)
    bullet = bullet.resize((bullet_w, bullet_h), Image.LANCZOS)
    bullet_shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    bullet_shadow.alpha_composite(bullet, (62, 61))
    bullet_shadow = bullet_shadow.filter(ImageFilter.GaussianBlur(8))
    base.alpha_composite(Image.eval(bullet_shadow, lambda p: min(p, 72)))
    bx, by = 62, 61
    base.alpha_composite(bullet, (bx, by))

    draw_gradient_text(base, (174, 73), "Silver Bullet", fonts["title"], chrome_grad)
    draw_tracking_text(draw, (176, 148), "THE PROCESS LAYER OF AI-DRIVEN DEV", fonts["tag"], HERO_GREEN, 372)

    draw.text((82, 260), "Maximize AI-driven", font=fonts["headline"], fill=TEXT_PRIMARY)
    draw.text((82, 318), "Dev Process Reliability", font=fonts["headline"], fill=HERO_GREEN)
    draw.text((82, 376), "29 Atomic Flows · 26 Workflows", font=fonts["subhead"], fill=TEXT_PRIMARY)

    draw.text((82, 458), "Enforce the Method Back to the AI Madness!", font=fonts["subhead"], fill=HERO_GREEN)

    features = [
        "Engineering Best Practices",
        "Dynamically Tailored Workflows",
        "Verification & Validation Loops",
        "Quality Gates",
        "Spec-to-Release Traceability",
        "Cost Optimization",
        "Intent-Aligned Results",
        "Knowledge Management",
    ]
    right_x = 732
    draw.text((right_x, 108), "v0.52.0 · 118 FLOW STEPS", font=fonts["tag"], fill=TEXT_DIM)
    draw.text((right_x, 150), "AGENTIC PROCESS ORCHESTRATOR", font=fonts["label"], fill=HERO_GREEN)
    for idx, feature in enumerate(features):
        draw_feature(draw, base, (right_x, 196 + idx * 42), feature, fonts["feature"])

    final = base.convert("RGB")
    final.save(OUT, "PNG", optimize=True)
    print(f"Saved {OUT} ({final.size[0]}x{final.size[1]})")
    print(
        "Tokens:",
        f"accent=#{ACCENT[0]:02x}{ACCENT[1]:02x}{ACCENT[2]:02x}",
        f"accent2=#{ACCENT2[0]:02x}{ACCENT2[1]:02x}{ACCENT2[2]:02x}",
        f"hero-green=#{HERO_GREEN[0]:02x}{HERO_GREEN[1]:02x}{HERO_GREEN[2]:02x}",
        f"bg-page=#{BG_PAGE[0]:02x}{BG_PAGE[1]:02x}{BG_PAGE[2]:02x}",
    )


if __name__ == "__main__":
    main()
