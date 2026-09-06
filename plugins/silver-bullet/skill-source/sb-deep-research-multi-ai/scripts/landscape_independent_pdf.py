#!/usr/bin/env python3
"""Independent landscape PDF: charts from chart-data.json, not SPA page.pdf()."""

from __future__ import annotations

import base64
import html
import json
import math
import re
import shutil
import subprocess
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any

from vendor_link_labels import BARE_HTTP_URL_RE, split_url_trailing_punct

INDEPENDENT_PDF_MARKER = "sb-independent-landscape-pdf"
PRINT_ROOT_ID = "independent-report"

SPA_CHROME_NEEDLES = (
    "pdfExportBtn",
    "exportBar",
    "copyGdocsBtn",
    "data-sb-landscape-viewer",
    "insertVendorFilterBar",
    "filter-chip",
    "themeToggle",
    "id=\"snav\"",
    "id='snav'",
    "Create PDF",
    "Copy for Google Docs",
)

_DEFAULT_QUAD_COLORS = {
    "Leaders": "#1f3864",
    "Challengers": "#475569",
    "Visionaries": "#2f5597",
    "Niche Players": "#94a3b8",
}

# Match landscape-preview.template.html light-theme quadrant fills.
_QUAD_FILLS = {
    "Leaders": "#e8f4fd",
    "Challengers": "#f0eaf8",
    "Visionaries": "#fff3e6",
    "Niche Players": "#f0f0f0",
}

SPA_FONT_FAMILY = "Roboto Condensed"
SPA_FONT_STACK = "'Roboto Condensed', 'Arial Narrow', Arial, sans-serif"
GOOGLE_FONTS_HREF = (
    "https://fonts.googleapis.com/css2?family=Roboto+Condensed:wght@300;400;500&display=swap"
)

# SPA Chart.js bubble radii (canvas px) — reused on the independent SVG Wave.
_WAVE_BUBBLE_R = {4: 26.0, 3: 18.0, 2: 13.0, 1: 8.0}
_WAVE_PALETTE = (
    "#1f3864",
    "#2f5597",
    "#3d6fa8",
    "#2563eb",
    "#0f766e",
    "#7c3aed",
    "#b45309",
    "#be123c",
)
_WAVE_ZONE = {
    "outer": "rgba(135,193,238,0.30)",
    "mid": "rgba(195,225,248,0.44)",
    "inner": "rgba(230,244,253,0.70)",
    "stroke": "rgba(75,145,200,0.38)",
    "label": "rgba(20,85,145,0.62)",
}

_LIST_UL_RE = re.compile(r"^([ \t]*)([-*•–—])\s+(.*)$")
_LIST_OL_RE = re.compile(r"^([ \t]*)(\d+)\.\s+(.*)$")
_LEFTOVER_MARKER_RE = re.compile(r"^[\s]*[-*•–—]\s+")
_REPORT_DATA_RE = re.compile(
    r'<script\b[^>]*\bid=["\']report-data["\'][^>]*>(.*?)</script>',
    re.I | re.S,
)
_MODEL_ID_RE = re.compile(r"(?:ocg-|claude-|gemini-|gpt-)[A-Za-z0-9._-]+")


def _playwright_argv() -> list[str]:
    exe = shutil.which("playwright")
    if exe:
        return [exe]
    npx = shutil.which("npx")
    if npx:
        return [npx, "--yes", "playwright"]
    raise FileNotFoundError(
        "playwright CLI not found — install Playwright to write landscape-report.pdf"
    )


def _load_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


CANONICAL_MD_REL = Path("landscape") / "landscape-report.md"
CANONICAL_CHART_REL = Path("landscape") / "chart-data.json"
CANONICAL_COMPARISON_REL = Path("comparison") / "comparison.json"


def load_canonical_landscape_sources(root: Path) -> dict[str, Any]:
    """Read landscape-report.md + chart-data.json + comparison.json (synthesize outputs)."""
    root = root.resolve()
    md_path = root / CANONICAL_MD_REL
    chart_path = root / CANONICAL_CHART_REL
    cmp_path = root / CANONICAL_COMPARISON_REL
    markdown = md_path.read_text(encoding="utf-8") if md_path.is_file() else ""
    return {
        "markdown": markdown,
        "chart_data": _load_json(chart_path),
        "comparison": _load_json(cmp_path),
        "paths": {
            "markdown": str(md_path),
            "chart_data": str(chart_path),
            "comparison": str(cmp_path),
        },
    }


def load_spa_report_data(root: Path) -> dict[str, Any]:
    """SPA payload embedded in landscape-report.html (debug/legacy only)."""
    html_path = root / "landscape-report.html"
    if not html_path.is_file():
        return {}
    try:
        text = html_path.read_text(encoding="utf-8")
    except OSError:
        return {}
    match = _REPORT_DATA_RE.search(text)
    if not match:
        return {}
    try:
        data = json.loads(match.group(1))
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def load_chart_data(root: Path) -> dict[str, Any]:
    data = load_canonical_landscape_sources(root)["chart_data"]
    return data if isinstance(data, dict) else {}


def load_comparison(root: Path) -> dict[str, Any]:
    data = load_canonical_landscape_sources(root)["comparison"]
    return data if isinstance(data, dict) else {}


def load_consolidation(root: Path) -> dict[str, Any]:
    return _load_json(root / "consolidated" / "consolidation.json")


def load_landscape_markdown(root: Path) -> str:
    text = load_canonical_landscape_sources(root)["markdown"]
    return text if isinstance(text, str) else ""


def market_chart_block(chart: dict[str, Any], market_id: str) -> dict[str, Any]:
    markets = chart.get("markets") if isinstance(chart.get("markets"), dict) else {}
    block = markets.get(market_id) if isinstance(markets.get(market_id), dict) else None
    if block:
        return block
    if market_id == chart.get("primary_market_id") or not markets:
        return chart
    return {}


def iter_market_ids(chart: dict[str, Any]) -> list[str]:
    markets = chart.get("markets") if isinstance(chart.get("markets"), dict) else {}
    if markets:
        primary = str(chart.get("primary_market_id") or "")
        ids = [primary] if primary in markets else []
        ids.extend(mid for mid in markets if mid not in ids)
        return ids
    return [str(chart.get("primary_market_id") or "primary")]


def quadrant_divergences(chart: dict[str, Any]) -> list[dict[str, str]]:
    """Vendors whose MQ quadrant disagrees with GMQ (notable score divergence)."""
    out: list[dict[str, str]] = []
    for mid in iter_market_ids(chart):
        block = market_chart_block(chart, mid)
        mq = {str(p.get("slug")): p for p in block.get("mq_data") or [] if isinstance(p, dict)}
        gmq = {str(p.get("slug")): p for p in block.get("gmq_data") or [] if isinstance(p, dict)}
        for slug, mp in mq.items():
            gp = gmq.get(slug)
            if not gp:
                continue
            mq_q = str(mp.get("q") or "")
            gmq_q = str(gp.get("q") or "")
            if mq_q and gmq_q and mq_q != gmq_q:
                out.append(
                    {
                        "market": mid,
                        "slug": slug,
                        "label": str(mp.get("label") or gp.get("label") or slug),
                        "mq": mq_q,
                        "gmq": gmq_q,
                    }
                )
    return out


def _esc(text: Any) -> str:
    return html.escape(str(text), quote=True)


def _html_ext_anchor(url: str, inner_html: str) -> str:
    return (
        f'<a href="{_esc(url)}" target="_blank" rel="noopener noreferrer">{inner_html}</a>'
    )


def _clip_id(chart_kind: str) -> str:
    return "c" + re.sub(r"[^a-zA-Z0-9]+", "-", chart_kind).strip("-")


_FONT_CSS_CACHE: str | None = None


def _embed_roboto_font_css() -> str:
    """Inline Roboto Condensed woff2 so Playwright PDF does not fall back to Times."""
    global _FONT_CSS_CACHE
    if _FONT_CSS_CACHE is not None:
        return _FONT_CSS_CACHE
    req = urllib.request.Request(
        GOOGLE_FONTS_HREF,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
            )
        },
    )
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            css = resp.read().decode("utf-8", errors="replace")
    except (urllib.error.URLError, TimeoutError, OSError):
        _FONT_CSS_CACHE = ""
        return ""

    def _data_uri(match: re.Match[str]) -> str:
        url = match.group(1)
        try:
            with urllib.request.urlopen(url, timeout=20) as font_resp:
                raw = font_resp.read()
        except (urllib.error.URLError, TimeoutError, OSError):
            return match.group(0)
        b64 = base64.b64encode(raw).decode("ascii")
        return f"url('data:font/woff2;base64,{b64}')"

    _FONT_CSS_CACHE = re.sub(r"url\((https://[^)]+)\)", _data_uri, css)
    return _FONT_CSS_CACHE


def _boxes_overlap(
    a: tuple[float, float, float, float], b: tuple[float, float, float, float], pad: float = 2.0
) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return not (ax + aw + pad < bx or bx + bw + pad < ax or ay + ah + pad < by or by + bh + pad < ay)


def _apply_plot_coord_collisions(
    points: list[dict[str, Any]],
    *,
    wave: bool,
) -> list[dict[str, Any]]:
    """Same unique-x / unique-y jitter as synthesize; idempotent when already unique."""
    rows = [dict(pt) for pt in points if isinstance(pt, dict)]
    try:
        from synthesize_landscape import avoid_chart_coord_collisions, avoid_wave_coord_collisions
    except ImportError:
        return rows
    if wave:
        return avoid_wave_coord_collisions(rows)
    return avoid_chart_coord_collisions(rows)


def _clamp_label_box(
    box: tuple[float, float, float, float],
    x_min: float,
    x_max: float,
    y_min: float,
    y_max: float,
) -> tuple[float, float, float, float]:
    bx, by, bw, bh = box
    max_w = max(8.0, x_max - x_min)
    max_h = max(8.0, y_max - y_min)
    bw = min(bw, max_w)
    bh = min(bh, max_h)
    bx = min(x_max - bw, max(x_min, bx))
    by = min(y_max - bh, max(y_min, by))
    return (bx, by, bw, bh)


def _box_in_plot(
    box: tuple[float, float, float, float],
    x_min: float,
    x_max: float,
    y_min: float,
    y_max: float,
) -> bool:
    bx, by, bw, bh = box
    return bx >= x_min - 0.01 and by >= y_min - 0.01 and bx + bw <= x_max + 0.01 and by + bh <= y_max + 0.01


def _place_point_labels(
    items: list[tuple[float, float, str, float]],
    *,
    x_min: float,
    x_max: float,
    y_min: float,
    y_max: float,
) -> list[tuple[float, float, str]]:
    """Place labels inside the plot: no overlap, no overflow past axes. Leader lines OK."""
    ordered = sorted(enumerate(items), key=lambda t: (t[1][0], t[1][1]))
    placed_boxes: list[tuple[float, float, float, float]] = []
    result: list[tuple[float, float, str] | None] = [None] * len(items)
    obstacles = [(cx, cy, radius + 2.5) for cx, cy, _label, radius in items]
    angles = (90, 270, 0, 180, 45, 135, 225, 315, 60, 120, 240, 300, 30, 150, 210, 330)
    dists = (12, 20, 28, 38, 50, 64, 80, 98, 118, 140)

    def collides(box: tuple[float, float, float, float], skip: int, pad: float = 4.0) -> bool:
        if any(_boxes_overlap(box, prev, pad=pad) for prev in placed_boxes):
            return True
        bx, by, bw, bh = box
        for idx, (px, py, pr) in enumerate(obstacles):
            if idx == skip:
                continue
            nearest_x = max(bx, min(px, bx + bw))
            nearest_y = max(by, min(py, by + bh))
            if (nearest_x - px) ** 2 + (nearest_y - py) ** 2 < pr * pr:
                return True
        return False

    def anchor_from_box(box: tuple[float, float, float, float]) -> tuple[float, float]:
        bx, by, bw, bh = box
        return (bx + bw / 2.0, by + bh - 3.0)

    for orig_i, (cx, cy, label, radius) in ordered:
        # Roboto Condensed 9px ≈ 5px/char; cap so long names still fit the plot.
        width = max(24.0, min(x_max - x_min - 4.0, len(label) * 5.0 + 4.0))
        height = 12.0
        chosen_box: tuple[float, float, float, float] | None = None
        for dist in dists:
            for ang in angles:
                rad = math.radians(float(ang))
                tx = cx + (radius + dist) * math.cos(rad)
                ty = cy - (radius + dist) * math.sin(rad)
                box = _clamp_label_box(
                    (tx - width / 2.0, ty - height + 3.0, width, height),
                    x_min,
                    x_max,
                    y_min,
                    y_max,
                )
                if not _box_in_plot(box, x_min, x_max, y_min, y_max):
                    continue
                if collides(box, orig_i):
                    continue
                chosen_box = box
                break
            if chosen_box:
                break
        if chosen_box is None:
            inward_x = cx + (12.0 if cx < (x_min + x_max) / 2.0 else -12.0)
            inward_y = cy - 14.0
            chosen_box = _clamp_label_box(
                (inward_x - width / 2.0, inward_y - height + 3.0, width, height),
                x_min,
                x_max,
                y_min,
                y_max,
            )
            found = False
            for dy in range(0, 220, 8):
                for sign in (1.0, -1.0):
                    nudged = _clamp_label_box(
                        (chosen_box[0], chosen_box[1] + sign * dy, chosen_box[2], chosen_box[3]),
                        x_min,
                        x_max,
                        y_min,
                        y_max,
                    )
                    if _box_in_plot(nudged, x_min, x_max, y_min, y_max) and not collides(
                        nudged, orig_i, pad=2.0
                    ):
                        chosen_box = nudged
                        found = True
                        break
                if found:
                    break
        placed_boxes.append(chosen_box)
        tx, ty = anchor_from_box(chosen_box)
        result[orig_i] = (tx, ty, label)
    return [(x, y, lab) for x, y, lab in result]  # type: ignore[misc]


def _svg_scatter(
    *,
    points: list[dict[str, Any]],
    title: str,
    x_label: str,
    y_label: str,
    colors: dict[str, str],
    chart_kind: str,
    axis_max: float = 10.0,
    axis_min: float = 0.0,
    x_key: str = "x",
    y_key: str = "y",
    size_key: str | None = None,
    size_max: float = 5.0,
    named_regions: bool = True,
    wave: bool = False,
) -> str:
    width, height = 760, 560
    pad_l, pad_r, pad_t, pad_b = (100, 64, 50, 82) if wave else (96, 56, 36, 74)
    plot_w = width - pad_l - pad_r
    plot_h = height - pad_t - pad_b
    span = max(axis_max - axis_min, 0.001)
    mid = axis_min + span / 2.0
    clip = _clip_id(chart_kind)

    def px(val: float) -> float:
        t = (max(axis_min, min(axis_max, val)) - axis_min) / span
        return pad_l + t * plot_w

    def py(val: float) -> float:
        t = (max(axis_min, min(axis_max, val)) - axis_min) / span
        return pad_t + (1.0 - t) * plot_h

    layers: list[str] = [
        f'<rect x="0" y="0" width="{width}" height="{height}" fill="#ffffff"/>',
        f'<defs><clipPath id="{_esc(clip)}">'
        f'<rect x="{pad_l}" y="{pad_t}" width="{plot_w}" height="{plot_h}"/></clipPath></defs>',
    ]

    if wave:
        diag = math.hypot(plot_w, plot_h)
        r1 = diag * 0.37
        r2 = diag * 0.67
        cx0, cy0 = pad_l, pad_t + plot_h

        def pie(radius: float) -> str:
            return (
                f"M {cx0:.1f} {cy0:.1f} L {cx0:.1f} {cy0 - radius:.1f} "
                f"A {radius:.1f} {radius:.1f} 0 0 1 {cx0 + radius:.1f} {cy0:.1f} Z"
            )

        layers.append(f'<g clip-path="url(#{_esc(clip)})">')
        layers.append(
            f'<rect x="{pad_l}" y="{pad_t}" width="{plot_w}" height="{plot_h}" '
            f'fill="{_WAVE_ZONE["outer"]}"/>'
        )
        layers.append(f'<path d="{pie(r2)}" fill="{_WAVE_ZONE["mid"]}"/>')
        layers.append(f'<path d="{pie(r1)}" fill="{_WAVE_ZONE["inner"]}"/>')
        for radius in (r1, r2):
            layers.append(
                f'<path d="M {cx0:.1f} {cy0 - radius:.1f} '
                f'A {radius:.1f} {radius:.1f} 0 0 1 {cx0 + radius:.1f} {cy0:.1f}" '
                f'fill="none" stroke="{_WAVE_ZONE["stroke"]}" stroke-width="1.1"/>'
            )
        layers.append("</g>")
        layers.append(
            f'<text x="{pad_l + plot_w * 0.14:.1f}" y="{pad_t - 14:.1f}" '
            f'text-anchor="middle" class="zone-label">CONTENDERS</text>'
        )
        layers.append(
            f'<text x="{pad_l + plot_w * 0.50:.1f}" y="{pad_t - 14:.1f}" '
            f'text-anchor="middle" class="zone-label">STRONG PERFORMERS</text>'
        )
        layers.append(
            f'<text x="{pad_l + plot_w * 0.86:.1f}" y="{pad_t - 14:.1f}" '
            f'text-anchor="middle" class="zone-label">LEADERS</text>'
        )
    else:
        regions = (
            ("Niche Players", axis_min, axis_min, mid, mid, "start", pad_l + 8, pad_t + plot_h - 10),
            ("Visionaries", mid, axis_min, axis_max, mid, "end", pad_l + plot_w - 8, pad_t + plot_h - 10),
            ("Challengers", axis_min, mid, mid, axis_max, "start", pad_l + 8, pad_t + 16),
            ("Leaders", mid, mid, axis_max, axis_max, "end", pad_l + plot_w - 8, pad_t + 16),
        )
        for name, x0, y0, x1, y1, anchor, lx, ly in regions:
            layers.append(
                f'<rect x="{px(x0):.1f}" y="{py(y1):.1f}" width="{px(x1) - px(x0):.1f}" '
                f'height="{py(y0) - py(y1):.1f}" fill="{_QUAD_FILLS[name]}"/>'
            )
            if named_regions:
                layers.append(
                    f'<text x="{lx:.1f}" y="{ly:.1f}" text-anchor="{anchor}" class="quad-label">'
                    f"{_esc(name.upper())}</text>"
                )
        layers.append(
            f'<line x1="{px(mid):.1f}" y1="{pad_t}" x2="{px(mid):.1f}" y2="{pad_t + plot_h}" '
            f'stroke="#94a3b8" stroke-width="1" stroke-dasharray="5 4"/>'
        )
        layers.append(
            f'<line x1="{pad_l}" y1="{py(mid):.1f}" x2="{pad_l + plot_w}" y2="{py(mid):.1f}" '
            f'stroke="#94a3b8" stroke-width="1" stroke-dasharray="5 4"/>'
        )

    points = _apply_plot_coord_collisions(points, wave=wave)

    parsed: list[tuple[dict[str, Any], float, float, float, str, str]] = []
    palette = colors or _DEFAULT_QUAD_COLORS
    for i, pt in enumerate(points):
        if not isinstance(pt, dict):
            continue
        try:
            x = float(pt.get(x_key) or 0)
            y = float(pt.get(y_key) or 0)
        except (TypeError, ValueError):
            continue
        q = str(pt.get("q") or "")
        color = palette.get(q) or _WAVE_PALETTE[i % len(_WAVE_PALETTE)]
        radius = 6.5
        if wave and size_key:
            try:
                presence = int(float(pt.get(size_key) or 1))
            except (TypeError, ValueError):
                presence = 1
            radius = _WAVE_BUBBLE_R.get(presence, 10.0)
        elif size_key:
            try:
                raw = float(pt.get(size_key) or 1)
            except (TypeError, ValueError):
                raw = 1.0
            radius = 5.0 + (max(0.0, min(size_max, raw)) / size_max) * 10.0
        label = str(pt.get("label") or pt.get("slug") or "")
        slug = str(pt.get("slug") or label)
        parsed.append((pt, x, y, radius, label, slug))

    label_layout = _place_point_labels(
        [(px(x), py(y), label, radius) for _pt, x, y, radius, label, _slug in parsed],
        x_min=pad_l + 3,
        x_max=pad_l + plot_w - 3,
        y_min=pad_t + 11,
        y_max=pad_t + plot_h - 3,
    )

    dots: list[str] = []
    labels_g: list[str] = []
    for i, ((pt, x, y, radius, _label, slug), (lx, ly, lab)) in enumerate(zip(parsed, label_layout)):
        q = str(pt.get("q") or "")
        color = palette.get(q) or _WAVE_PALETTE[i % len(_WAVE_PALETTE)]
        cx, cy = px(x), py(y)
        fill_opacity = "0.42" if wave else "1"
        stroke = color if wave else "#ffffff"
        stroke_w = "2" if wave else "1.2"
        if math.hypot(lx - cx, ly - cy) > radius + 8:
            labels_g.append(
                f'<line x1="{cx:.1f}" y1="{cy:.1f}" x2="{lx:.1f}" y2="{ly:.1f}" '
                f'stroke="#94a3b8" stroke-width="0.6" opacity="0.55"/>'
            )
        dots.append(
            f'<circle class="fig-pt" data-chart="{_esc(chart_kind)}" data-slug="{_esc(slug)}" '
            f'data-x="{x}" data-y="{y}" cx="{cx:.1f}" cy="{cy:.1f}" r="{radius:.1f}" '
            f'fill="{_esc(color)}" fill-opacity="{fill_opacity}" stroke="{_esc(stroke)}" '
            f'stroke-width="{stroke_w}"/>'
        )
        labels_g.append(
            f'<text x="{lx:.1f}" y="{ly:.1f}" text-anchor="middle" class="pt-label">'
            f"{_esc(lab)}</text>"
        )

    legend: list[str] = []
    used: list[str] = []
    for pt, *_rest in parsed:
        q = str(pt.get("q") or "")
        if q and q not in used:
            used.append(q)
    if used:
        lx = pad_l
        for q in ("Leaders", "Challengers", "Visionaries", "Niche Players"):
            if q not in used:
                continue
            color = palette.get(q, "#64748b")
            legend.append(
                f'<circle cx="{lx}" cy="{height - 16}" r="5" fill="{_esc(color)}"/>'
                f'<text x="{lx + 10}" y="{height - 12}" class="legend">{_esc(q)}</text>'
            )
            lx += 118
    elif wave:
        legend.append(
            f'<text x="{pad_l}" y="{height - 14}" class="legend">'
            f"Bubble size = Market Presence · Strong=4 · Good=3 · Moderate=2</text>"
        )

    if wave:
        tick_names = {1: "Emerging", 2: "Moderate", 3: "Good", 4: "Strong"}
        for val, name in tick_names.items():
            legend.append(
                f'<text x="{px(float(val)):.1f}" y="{pad_t + plot_h + 16:.1f}" '
                f'text-anchor="middle" class="tick">{_esc(name)}</text>'
            )
            legend.append(
                f'<text x="{pad_l - 8:.1f}" y="{py(float(val)) + 3:.1f}" '
                f'text-anchor="end" class="tick">{_esc(name)}</text>'
            )
            legend.append(
                f'<line x1="{px(float(val)):.1f}" y1="{pad_t + plot_h}" '
                f'x2="{px(float(val)):.1f}" y2="{pad_t + plot_h + 4}" stroke="#94a3b8"/>'
            )
            legend.append(
                f'<line x1="{pad_l - 4}" y1="{py(float(val)):.1f}" x2="{pad_l}" '
                f'y2="{py(float(val)):.1f}" stroke="#94a3b8"/>'
            )

    x_mid = pad_l + plot_w / 2
    y_mid = pad_t + plot_h / 2
    return f"""<svg class="chart-svg" data-chart="{_esc(chart_kind)}" viewBox="0 0 {width} {height}"
      xmlns="http://www.w3.org/2000/svg" role="img" aria-label="{_esc(title)}">
  {''.join(layers)}
  <rect x="{pad_l}" y="{pad_t}" width="{plot_w}" height="{plot_h}" fill="none"
        stroke="#1f3864" stroke-width="1.4"/>
  <g clip-path="url(#{_esc(clip)})">{''.join(labels_g)}</g>
  {''.join(dots)}
  <text x="{x_mid:.1f}" y="{height - 40}" text-anchor="middle" class="axis-label">{_esc(x_label)}</text>
  <text x="20" y="{y_mid:.1f}" text-anchor="middle" class="axis-label"
        transform="rotate(-90 20 {y_mid:.1f})">{_esc(y_label)}</text>
  {''.join(legend)}
</svg>"""


def _figure(title: str, svg: str, caption: str) -> str:
    return (
        f'<figure class="chart-figure" data-independent-figure="1">'
        f"<figcaption class=\"fig-title\">{_esc(title)}</figcaption>"
        f"{svg}"
        f"<p class=\"fig-cap\">{_esc(caption)}</p></figure>"
    )


def render_market_figures(chart: dict[str, Any], market_id: str) -> str:
    block = market_chart_block(chart, market_id)
    titles = block.get("titles") if isinstance(block.get("titles"), dict) else {}
    mq = [p for p in (block.get("mq_data") or []) if isinstance(p, dict)]
    gmq = [p for p in (block.get("gmq_data") or []) if isinstance(p, dict)]
    wave = [p for p in (block.get("wave_data") or []) if isinstance(p, dict)]
    mq_colors = block.get("mq_colors") if isinstance(block.get("mq_colors"), dict) else _DEFAULT_QUAD_COLORS
    gmq_colors = block.get("gmq_colors") if isinstance(block.get("gmq_colors"), dict) else _DEFAULT_QUAD_COLORS
    parts = [f'<section class="market-charts" data-market="{_esc(market_id)}">']
    if mq:
        parts.append(
            _figure(
                str(titles.get("mq") or f"{market_id} positioning matrix"),
                _svg_scatter(
                    points=mq,
                    title=str(titles.get("mq") or "Positioning matrix"),
                    x_label=str(titles.get("mq_x") or "Process orchestration"),
                    y_label=str(titles.get("mq_y") or "Autonomous execution"),
                    colors=mq_colors,
                    chart_kind=f"mq:{market_id}",
                ),
                "Figure from landscape/chart-data.json mq_data (vector plot, not SPA canvas).",
            )
        )
    if gmq:
        parts.append(
            _figure(
                str(titles.get("gmq") or f"{market_id} Magic Quadrant"),
                _svg_scatter(
                    points=gmq,
                    title=str(titles.get("gmq") or "Magic Quadrant"),
                    x_label=str(titles.get("gmq_x") or "Completeness of Vision"),
                    y_label=str(titles.get("gmq_y") or "Ability to Execute"),
                    colors=gmq_colors,
                    chart_kind=f"gmq:{market_id}",
                ),
                "Figure from landscape/chart-data.json gmq_data (Gartner-style MQ).",
            )
        )
    if wave:
        parts.append(
            _figure(
                str(titles.get("wave") or f"{market_id} Wave-style assessment"),
                _svg_scatter(
                    points=wave,
                    title=str(titles.get("wave") or "Wave"),
                    x_label="Strength of Strategy  (1=Emerging → 4=Strong)",
                    y_label="Strength of Offering  (1=Emerging → 4=Strong)",
                    colors={},
                    chart_kind=f"wave:{market_id}",
                    axis_min=0.5,
                    axis_max=4.9,
                    x_key="strategy",
                    y_key="offering",
                    size_key="presence",
                    size_max=4.0,
                    named_regions=False,
                    wave=True,
                ),
                "Wave plot from chart-data.json (SPA mapping): x=strategy, y=offering, bubble=presence.",
            )
        )
    parts.append("</section>")
    return "\n".join(parts)


def _md_inline(text: str) -> str:
    pieces: list[str] = []
    idx = 0
    link_re = re.compile(r"\[([^\]]+)\]\(([^)]+)\)")
    while idx < len(text):
        m = link_re.search(text, idx)
        if not m:
            pieces.append(_inline_fmt_raw(text[idx:]))
            break
        start, end = m.start(), m.end()
        wrapped_strong = start >= 2 and text[start - 2 : start] == "**" and text[end : end + 2] == "**"
        wrapped_em = (
            not wrapped_strong
            and start >= 1
            and text[start - 1] == "*"
            and (start < 2 or text[start - 2] != "*")
            and text[end : end + 1] == "*"
            and text[end : end + 2] != "**"
        )
        left = start - (2 if wrapped_strong else 1 if wrapped_em else 0)
        right = end + (2 if wrapped_strong else 1 if wrapped_em else 0)
        pieces.append(_inline_fmt_raw(text[idx:left]))
        anchor = _html_ext_anchor(m.group(2), _inline_fmt_raw(m.group(1), autolink=False))
        if wrapped_strong:
            pieces.append(f"<strong>{anchor}</strong>")
        elif wrapped_em:
            pieces.append(f"<em>{anchor}</em>")
        else:
            pieces.append(anchor)
        idx = right
    return "".join(pieces)


def _inline_fmt(text: str, bold_re: re.Pattern[str], em_re: re.Pattern[str], code_re: re.Pattern[str]) -> str:
    out = html.escape(text)

    def _bold(m: re.Match[str]) -> str:
        return f"<strong>{m.group(1)}</strong>"

    # Operate on escaped text; recreate patterns against escaped form is messy.
    # Re-parse original then escape segments:
    return _inline_fmt_raw(text)


def _inline_fmt_raw(text: str, *, autolink: bool = True) -> str:
    out: list[str] = []
    i = 0
    n = len(text)
    while i < n:
        if text.startswith("**", i):
            j = text.find("**", i + 2)
            if j != -1:
                out.append(f"<strong>{html.escape(text[i + 2 : j])}</strong>")
                i = j + 2
                continue
        if text[i] == "`":
            j = text.find("`", i + 1)
            if j != -1:
                inner = text[i + 1 : j]
                if autolink:
                    stripped = inner.strip()
                    url, trail = split_url_trailing_punct(stripped)
                    lowered = url.lower()
                    if lowered.startswith("http://") or lowered.startswith("https://"):
                        if stripped in {url, url + trail}:
                            out.append(f"<code>{_html_ext_anchor(url, html.escape(url))}</code>")
                            i = j + 1
                            continue
                out.append(f"<code>{html.escape(inner)}</code>")
                i = j + 1
                continue
        if text[i] == "*" and (i + 1 >= n or text[i + 1] != "*"):
            j = text.find("*", i + 1)
            if j != -1 and (j + 1 >= n or text[j + 1] != "*"):
                out.append(f"<em>{html.escape(text[i + 1 : j])}</em>")
                i = j + 1
                continue
        if text.startswith("__", i) and not text.startswith("___", i):
            j = text.find("__", i + 2)
            if j != -1:
                out.append(f"<strong>{html.escape(text[i + 2 : j])}</strong>")
                i = j + 2
                continue
        if (
            text[i] == "_"
            and (i == 0 or not text[i - 1].isalnum())
            and (i + 1 < n and text[i + 1] != "_")
        ):
            j = text.find("_", i + 1)
            if j != -1 and (j + 1 >= n or not text[j + 1].isalnum()):
                out.append(f"<em>{html.escape(text[i + 1 : j])}</em>")
                i = j + 1
                continue
        if autolink and (text.startswith("https://", i) or text.startswith("http://", i)):
            matched = BARE_HTTP_URL_RE.match(text, i)
            if matched:
                url, _trail = split_url_trailing_punct(matched.group(0))
                lowered = url.lower()
                if lowered.startswith("http://") or lowered.startswith("https://"):
                    out.append(_html_ext_anchor(url, html.escape(url)))
                    i += len(url)
                    continue
        out.append(html.escape(text[i]))
        i += 1
    return "".join(out)


def _clean_list_body(text: str) -> str:
    prev = None
    while prev != text:
        prev = text
        text = _LEFTOVER_MARKER_RE.sub("", text)
    return text.strip()


def _parse_list_line(line: str) -> tuple[int, str, str] | None:
    m = _LIST_UL_RE.match(line)
    if m:
        return len(m.group(1).expandtabs(2)), "ul", _clean_list_body(m.group(3))
    m = _LIST_OL_RE.match(line)
    if m:
        return len(m.group(1).expandtabs(2)), "ol", _clean_list_body(m.group(3))
    return None


def markdown_to_html(md: str) -> str:
    """Small markdown subset for print (headings, nested lists, tables, paragraphs)."""
    lines = md.replace("\r\n", "\n").split("\n")
    html_parts: list[str] = []
    i = 0
    list_stack: list[tuple[int, str]] = []

    def close_lists(to_indent: int = -1) -> None:
        while list_stack and list_stack[-1][0] > to_indent:
            html_parts.append("</li>")
            html_parts.append(f"</{list_stack[-1][1]}>")
            list_stack.pop()
        if list_stack and list_stack[-1][0] == to_indent:
            html_parts.append("</li>")

    def open_item(indent: int, tag: str, body: str) -> None:
        if not list_stack or indent > list_stack[-1][0]:
            html_parts.append(f"<{tag}>")
            list_stack.append((indent, tag))
        elif indent == list_stack[-1][0]:
            if list_stack[-1][1] != tag:
                html_parts.append("</li>")
                html_parts.append(f"</{list_stack[-1][1]}>")
                list_stack.pop()
                html_parts.append(f"<{tag}>")
                list_stack.append((indent, tag))
            else:
                html_parts.append("</li>")
        else:
            close_lists(indent)
            if not list_stack or list_stack[-1][0] < indent:
                html_parts.append(f"<{tag}>")
                list_stack.append((indent, tag))
            elif list_stack[-1][1] != tag:
                html_parts.append(f"</{list_stack[-1][1]}>")
                list_stack.pop()
                html_parts.append(f"<{tag}>")
                list_stack.append((indent, tag))
        html_parts.append(f"<li>{_md_inline(body)}")

    while i < len(lines):
        line = lines[i]
        if line.strip().startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|?\s*:?-{3,}", lines[i + 1]):
            close_lists()
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                raw = lines[i].strip()
                if re.match(r"^\|?\s*:?-{3,}", raw.replace("|", " ").strip() or "-") or set(raw.replace("|", "").strip()) <= set("-: "):
                    i += 1
                    continue
                cells = [c.strip() for c in raw.strip("|").split("|")]
                rows.append(cells)
                i += 1
            if rows:
                html_parts.append("<table>")
                head, body = rows[0], rows[1:]
                html_parts.append("<thead><tr>" + "".join(f"<th>{_md_inline(c)}</th>" for c in head) + "</tr></thead>")
                html_parts.append("<tbody>")
                for row in body:
                    html_parts.append("<tr>" + "".join(f"<td>{_md_inline(c)}</td>" for c in row) + "</tr>")
                html_parts.append("</tbody></table>")
            continue
        m = re.match(r"^(#{1,6})\s+(.*)$", line)
        if m:
            close_lists()
            level = len(m.group(1))
            html_parts.append(f"<h{level}>{_md_inline(m.group(2))}</h{level}>")
            i += 1
            continue
        parsed = _parse_list_line(line)
        if parsed:
            indent, tag, body = parsed
            open_item(indent, tag, body)
            i += 1
            continue
        if not line.strip():
            close_lists()
            i += 1
            continue
        close_lists()
        html_parts.append(f"<p>{_md_inline(line)}</p>")
        i += 1
    close_lists()
    rendered = "\n".join(html_parts)
    rendered = re.sub(r"(<li>)\s*[-*•–—]\s+", r"\1", rendered)
    rendered = re.sub(r"(<li>)\s*\d+\.\s+", r"\1", rendered)
    return rendered


def _split_md_sections(md: str) -> list[tuple[str, str]]:
    parts = re.split(r"(?m)^(## .+)$", md)
    if len(parts) == 1:
        return [("", md)]
    out: list[tuple[str, str]] = []
    if parts[0].strip():
        out.append(("", parts[0]))
    for i in range(1, len(parts), 2):
        heading = parts[i]
        body = parts[i + 1] if i + 1 < len(parts) else ""
        out.append((heading, body))
    return out


def _strip_notable_divergences_block(text: str) -> str:
    """Avoid duplicating the dedicated Notable divergences section inside other chapters."""
    return re.sub(
        r"\n*\*\*Notable divergences\*\*[^\n]*\n+(?:- .+\n*)+",
        "\n",
        text or "",
        flags=re.I,
    )


def _section_html(heading: str, body: str) -> str:
    chunk = f"{heading}\n{body}" if heading else body
    return markdown_to_html(_strip_notable_divergences_block(chunk))


def _slugify_label(label: str) -> str:
    text = re.sub(r"\s*\([^)]*\)\s*", "", str(label or "").lower())
    text = re.sub(r"[^\w\s-]", "", text).strip()
    return re.sub(r"[\s_]+", "-", text)


def _comparison_rankings(comparison: dict[str, Any]) -> list[dict[str, Any]]:
    raw = comparison.get("rankings")
    rows: list[dict[str, Any]] = []
    if isinstance(raw, list):
        rows = [r for r in raw if isinstance(r, dict) and r.get("solution")]
    elif isinstance(raw, dict):
        rows = [r for r in raw.values() if isinstance(r, dict) and r.get("solution")]
        rows.sort(key=lambda r: int(r.get("rank") or 10**9))
    return rows


def _comparison_features(comparison: dict[str, Any]) -> list[dict[str, Any]]:
    return [
        r
        for r in (comparison.get("rows") or [])
        if isinstance(r, dict) and r.get("type") == "feature" and r.get("name")
    ]


def _solution_label(slug: str, chart: dict[str, Any] | None) -> str:
    slug = str(slug or "")
    if not slug:
        return ""
    if isinstance(chart, dict):
        for label in (chart.get("vendor_urls") or {}):
            if str(label) == slug or _slugify_label(str(label)) == slug:
                return str(label)
        for market in (chart.get("markets") or {}).values():
            if not isinstance(market, dict):
                continue
            for key in ("mq_data", "gmq_data", "wave_data"):
                for point in market.get(key) or []:
                    if not isinstance(point, dict):
                        continue
                    if point.get("slug") == slug or _slugify_label(str(point.get("label") or "")) == slug:
                        return str(point.get("label") or slug)
    return slug.replace("-", " ")


def comparison_matrix_html(
    comparison: dict[str, Any],
    chart: dict[str, Any] | None = None,
) -> str:
    """Full SPA comparison matrix as static tables (same rows/solutions, A4-chunked)."""
    rankings = _comparison_rankings(comparison)
    features = _comparison_features(comparison)
    winner = str(comparison.get("winner") or "")
    runner = str(comparison.get("runner_up") or "")
    caveats = comparison.get("caveats") if isinstance(comparison.get("caveats"), list) else []
    slugs = [str(r.get("solution") or "") for r in rankings]
    score_by = {
        str(r.get("solution") or ""): r.get("score", r.get("total_score", "—"))
        for r in rankings
    }
    parts = [
        '<section class="comparison">',
        "<h2>Comparison matrix</h2>",
        f"<p>Winner: <strong>{_esc(winner)}</strong>. Runner-up: <strong>{_esc(runner)}</strong>. "
        "Same startup-weighted feature matrix as the SPA <code>#report-data</code> comparison "
        "payload (static table — not filter chips).</p>",
    ]
    if not slugs or not features:
        parts.append("<p>Comparison matrix not populated yet.</p>")
    else:
        chunk = 7
        for offset in range(0, len(slugs), chunk):
            cols = slugs[offset : offset + chunk]
            parts.append('<div class="table-wrap">')
            parts.append('<table class="matrix">')
            parts.append("<thead><tr><th>Feature</th><th>Priority</th>")
            for slug in cols:
                label = _solution_label(slug, chart)
                score = score_by.get(slug, "—")
                parts.append(
                    f"<th>{_esc(label)}<div class=\"score\">Score {_esc(score)}</div></th>"
                )
            parts.append("</tr></thead><tbody>")
            parts.append(
                '<tr class="cmp-score-row"><td><strong>Weighted score</strong></td><td>—</td>'
            )
            for slug in cols:
                parts.append(f"<td>{_esc(score_by.get(slug, '—'))}</td>")
            parts.append("</tr>")
            for feat in features:
                sols = feat.get("solutions") if isinstance(feat.get("solutions"), dict) else {}
                parts.append(
                    f"<tr><td>{_esc(feat.get('name'))}</td>"
                    f"<td>{_esc(feat.get('priority') or '—')}</td>"
                )
                for slug in cols:
                    parts.append(f"<td>{_esc(sols.get(slug) or '—')}</td>")
                parts.append("</tr>")
            parts.append("</tbody></table></div>")
    shown = [
        str(c)
        for c in caveats
        if isinstance(c, str) and "landscape-report.html" not in c and "Interactive SPA" not in c
    ]
    if shown:
        parts.append("<h3>Matrix caveats</h3><ul>")
        parts.extend(f"<li>{_md_inline(c)}</li>" for c in shown)
        parts.append("</ul>")
    parts.append("</section>")
    return "\n".join(parts)


def comparison_highlights_html(
    comparison: dict[str, Any],
    chart: dict[str, Any] | None = None,
) -> str:
    """Alias — full matrix, never a top-N summary."""
    return comparison_matrix_html(comparison, chart)


def section_body_needles(body: str, *, min_len: int = 48) -> list[str]:
    """Distinctive ##-section body phrases (not the heading)."""
    needles: list[str] = []
    for raw in (body or "").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or re.fullmatch(r"[\s|:-]+", line):
            continue
        text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", line)
        text = re.sub(r"[*`_#>|-]+", " ", text)
        text = re.sub(r"\s+", " ", text).strip()
        if len(text) >= min_len:
            needles.append(text[:80])
    return needles


def _norm_body_haystack(text: str) -> str:
    text = re.sub(r"https?://\S+", " ", text or "")
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    text = re.sub(r"[^a-zA-Z0-9]+", " ", text).lower()
    return re.sub(r"\s+", " ", text).strip()


def assert_section_bodies_in_text(markdown: str, haystack: str) -> None:
    """Fail if a SPA ## section body is absent — headings alone are not enough."""
    hay = f" {_norm_body_haystack(haystack)} "
    missing: list[str] = []
    for heading, body in _split_md_sections(markdown or ""):
        if not heading:
            continue
        needles = section_body_needles(body)
        if not needles:
            continue
        hits = 0
        for needle in needles:
            words = _norm_body_haystack(needle).split()
            if len(words) < 4:
                continue
            # Tail window survives markdown links expanding to href + label in HTML/PDF.
            window = " ".join(words[-5:])
            if f" {window} " in hay:
                hits += 1
        if hits == 0:
            missing.append(heading)
    if missing:
        raise AssertionError(
            "SPA ## section bodies missing from PDF/print text: " + ", ".join(missing)
        )


def sync_canonical_payload_files(
    root: Path,
    payload: dict[str, Any] | None = None,
) -> dict[str, str]:
    """Write sibling md/json to the exact #report-data blobs both formats consume."""
    data = payload if isinstance(payload, dict) and payload else load_spa_report_data(root)
    written: dict[str, str] = {}
    if not data:
        return written
    markdown = data.get("markdown")
    if isinstance(markdown, str) and markdown.strip():
        dest = root / "landscape" / "landscape-report.md"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(markdown if markdown.endswith("\n") else markdown + "\n", encoding="utf-8")
        written["markdown"] = str(dest)
    chart = data.get("chart_data")
    if isinstance(chart, dict) and chart:
        dest = root / "landscape" / "chart-data.json"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(chart, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        written["chart_data"] = str(dest)
    comparison = data.get("comparison")
    if isinstance(comparison, dict) and comparison:
        dest = root / "comparison" / "comparison.json"
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(comparison, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        written["comparison"] = str(dest)
    return written


def notable_divergence_bullets(
    markdown: str,
    consolidation: dict[str, Any] | None = None,
) -> list[str]:
    """Pull Notable divergences from SPA markdown (inter-model), else consolidation."""
    match = re.search(r"\*\*Notable divergences\*\*[^\n]*\n+", markdown or "")
    bullets: list[str] = []
    if match:
        for line in (markdown or "")[match.end() :].splitlines():
            stripped = line.strip()
            if stripped.startswith("## "):
                break
            if stripped.startswith("**") and "Notable divergences" not in stripped:
                break
            if line.startswith("- "):
                bullets.append(line[2:].strip())
                continue
            if bullets and not stripped:
                continue
        if bullets:
            return bullets
    items = (consolidation or {}).get("divergence") or []
    for item in items:
        if not isinstance(item, dict):
            continue
        text = str(item.get("text") or item.get("claim_key") or "").strip()
        if not text:
            continue
        ids: list[str] = []
        for key in ("supporting_agents", "model_families", "agents"):
            val = item.get(key)
            if isinstance(val, list):
                for raw in val:
                    sid = str(raw).strip()
                    if sid and sid not in ids:
                        ids.append(sid)
            elif isinstance(val, str) and val.strip() and val.strip() not in ids:
                ids.append(val.strip())
        for found in _MODEL_ID_RE.findall(text):
            if found not in ids:
                ids.append(found)
        if ids:
            joined = ", ".join(f"`{sid}`" for sid in ids[:8])
            bullets.append(f"{joined} — {text}")
        else:
            bullets.append(text)
    return bullets


def divergences_html(
    chart: dict[str, Any],
    comparison: dict[str, Any],
    markdown: str = "",
    consolidation: dict[str, Any] | None = None,
) -> str:
    _ = (chart, comparison)
    bullets = notable_divergence_bullets(markdown, consolidation)
    parts = [
        '<section class="divergences">',
        "<h2>Notable divergences</h2>",
        "<p>Disagreements among contributing models, triangulation waves, and critique SCRs "
        "(model A said X, model B said Y) — not MQ vs GMQ chart-axis mismatches.</p>",
    ]
    if bullets:
        parts.append("<ul>")
        parts.extend(f"<li>{_md_inline(b)}</li>" for b in bullets)
        parts.append("</ul>")
    else:
        parts.append(
            "<p>No inter-model research disagreements were extracted from triangulation "
            "or critique envelopes.</p>"
        )
    parts.append("</section>")
    return "\n".join(parts)


def _plain_html_text(fragment: str) -> str:
    return re.sub(r"<[^>]+>", "", fragment or "")


def _inject_after_matching_h2(body: str, predicate, injection: str) -> tuple[str, bool]:
    """Insert HTML after the first <h2> whose visible text matches predicate."""
    placed = False

    def repl(match: re.Match[str]) -> str:
        nonlocal placed
        if placed:
            return match.group(0)
        if predicate(_plain_html_text(match.group(0))):
            placed = True
            return match.group(0) + "\n" + injection
        return match.group(0)

    out = re.sub(r"<h2>.*?</h2>", repl, body, flags=re.I | re.S)
    return out, placed


def build_independent_print_html(root: Path) -> str:
    """Full markdown body + chart figures + comparison matrix. No chapter picker."""
    sources = load_canonical_landscape_sources(root)
    chart = sources["chart_data"] if isinstance(sources["chart_data"], dict) else {}
    comparison = sources["comparison"] if isinstance(sources["comparison"], dict) else {}
    markdown = sources["markdown"] if isinstance(sources["markdown"], str) else ""
    title = "Landscape report"
    body_md = markdown
    heading = re.search(r"^#\s+(.+)$", markdown, re.M)
    if heading:
        title = heading.group(1).strip()
        body_md = markdown[: heading.start()] + markdown[heading.end() :]
    body_html = markdown_to_html(body_md)
    chart_blocks = "".join(render_market_figures(chart, mid) for mid in iter_market_ids(chart))
    comparison_html = comparison_matrix_html(comparison, chart)

    def _is_positioning(text: str) -> bool:
        key = text.lower()
        return "competitive positioning" in key or bool(re.match(r"\s*3[\.:]\s", text))

    body_html, charts_placed = _inject_after_matching_h2(body_html, _is_positioning, chart_blocks)
    if not charts_placed:
        body_html += chart_blocks
    body_html += comparison_html
    font_face = _embed_roboto_font_css()
    css = f"""
@page {{ size: A4; margin: 16mm 16mm 18mm; }}
html, body {{ margin: 0; padding: 0; }}
body {{
  font-family: {SPA_FONT_STACK};
  font-weight: 300;
  font-size: 10.5pt; line-height: 1.45; color: #1e293b; background: #fff;
  -webkit-print-color-adjust: exact; print-color-adjust: exact;
}}
.masthead {{ border-bottom: 3px solid #1f3864; padding: 0 0 12px; margin: 0 0 18px; }}
.kicker {{ font-size: 9pt; letter-spacing: 0.14em; text-transform: uppercase; color: #2f5597; font-weight: 500; }}
h1 {{ font-size: 22pt; color: #1f3864; margin: 6px 0 8px; line-height: 1.15; font-weight: 500; }}
h2 {{ font-size: 14pt; color: #1f3864; font-weight: 500; border-bottom: 1px solid #c5d0e0; padding-bottom: 4px;
     break-after: avoid; page-break-after: avoid; }}
h3 {{ font-size: 12pt; color: #2f5597; font-weight: 500; break-after: avoid; page-break-after: avoid; }}
h4 {{ font-size: 11pt; color: #334155; font-weight: 500; break-after: avoid; page-break-after: avoid; }}
p {{ margin: 0 0 0.7em; }}
.divergences {{ break-before: page; page-break-before: always; }}
.divergences h2 {{ font-size: 16pt; }}
.chart-figure {{ break-inside: avoid; page-break-inside: avoid; margin: 16px 0 24px; }}
.fig-title {{ font-weight: 500; color: #1f3864; margin: 0 0 8px; font-size: 11pt;
              break-after: avoid; page-break-after: avoid; }}
.chart-svg {{ width: 100%; height: auto; display: block; border: 1px solid #d0d7e2; background: #fff; }}
.chart-svg text {{ font-family: {SPA_FONT_STACK}; }}
.fig-cap {{ font-size: 8.5pt; color: #64748b; margin: 8px 0 0; font-weight: 300; }}
.quad-label {{ font-size: 11px; fill: rgba(15,23,42,0.28); font-weight: 500; }}
.zone-label {{ font-size: 10px; fill: rgba(20,85,145,0.62); font-weight: 500; letter-spacing: 0.04em; }}
.pt-label {{ font-size: 9px; fill: #0f172a; font-weight: 500; }}
.axis-label {{ font-size: 11px; fill: #1f3864; font-weight: 500; }}
.tick {{ font-size: 8px; fill: #64748b; font-weight: 400; }}
.legend {{ font-size: 10px; fill: #334155; font-weight: 400; }}
ul, ol {{ margin: 0 0 0.85em; padding-left: 1.35em; }}
ul {{ list-style: disc; }}
ul ul {{ list-style: circle; margin: 0.2em 0 0.4em; }}
li {{ margin: 0.18em 0; font-weight: 300; }}
li > strong:first-child {{ font-weight: 500; }}
table {{ border-collapse: collapse; width: 100%; margin: 8px 0 16px; font-size: 9pt; }}
th, td {{ border: 1px solid #d0d7e2; padding: 5px 7px; vertical-align: top; }}
th {{ background: #1f3864; color: #fff; font-weight: 500; text-align: left; }}
tr:nth-child(even) td {{ background: #f8fafc; }}
.comparison {{ break-before: page; page-break-before: always; }}
.comparison .table-wrap {{ overflow: visible; margin: 8px 0 14px; }}
.comparison table.matrix {{ font-size: 7.5pt; }}
.comparison table.matrix th, .comparison table.matrix td {{ padding: 3px 4px; word-break: break-word; }}
.comparison table.matrix .score {{ font-size: 7pt; font-weight: 600; }}
a {{ color: #2563eb; text-decoration: none; }}
code {{ font-family: 'SF Mono', Consolas, 'Liberation Mono', monospace; font-size: 0.92em; }}
"""
    body = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8"/>
<title>{_esc(title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com"/>
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin="anonymous"/>
<link rel="stylesheet" href="{GOOGLE_FONTS_HREF}"/>
<style>
{font_face}
{css}
</style>
</head>
<body id="{PRINT_ROOT_ID}" data-sb-independent-pdf="1">
<!-- {INDEPENDENT_PDF_MARKER} -->
<header class="masthead">
  <div class="kicker">Market landscape report</div>
  <h1>{_esc(title)}</h1>
</header>
{body_html}
</body>
</html>
"""
    return body


def assert_print_html_independent(print_html: str) -> None:
    lowered = print_html
    if INDEPENDENT_PDF_MARKER not in lowered:
        raise RuntimeError("print HTML missing independent PDF marker")
    if f'id="{PRINT_ROOT_ID}"' not in lowered:
        raise RuntimeError("print HTML missing independent root id")
    if "<svg" not in lowered or 'class="fig-pt"' not in lowered:
        raise RuntimeError("print HTML missing vector chart figures")
    visible = re.sub(r"<!--.*?-->", "", print_html, flags=re.S)
    if "Renderer:" in visible:
        raise RuntimeError("print HTML still has renderer attribution line")
    if INDEPENDENT_PDF_MARKER in visible:
        raise RuntimeError("independent PDF marker leaked into visible print HTML")
    for needle in SPA_CHROME_NEEDLES:
        if needle in lowered:
            raise RuntimeError(f"print HTML contains SPA chrome: {needle}")


def write_independent_landscape_pdf(
    root: Path,
    pdf_path: Path | None = None,
    *,
    timeout_ms: int = 120000,
    print_html_path: Path | None = None,
) -> dict[str, Any]:
    """Write landscape-report.pdf from landscape-report.md + chart-data.json + comparison.json."""
    root = root.resolve()
    pdf_path = (pdf_path or (root / "landscape-report.pdf")).resolve()
    print_html = build_independent_print_html(root)
    assert_print_html_independent(print_html)
    markdown = load_landscape_markdown(root)
    for heading, _ in _split_md_sections(markdown):
        if heading.startswith("## "):
            title_text = heading[3:].strip()
            escaped = html.escape(title_text, quote=False)
            if title_text and title_text not in print_html and escaped not in print_html:
                raise RuntimeError(f"independent print HTML dropped SPA heading: {title_text}")
    comparison = load_comparison(root)
    for feat in _comparison_features(comparison):
        name = str(feat.get("name") or "")
        if name and name not in print_html:
            raise RuntimeError(f"independent print HTML dropped comparison feature: {name}")
    if "Comparison matrix highlights" in print_html:
        raise RuntimeError("independent print HTML still uses highlights-only comparison")
    source = (print_html_path or pdf_path.with_name("landscape-report.print.html")).resolve()
    source.write_text(print_html, encoding="utf-8")
    cmd = [
        *_playwright_argv(),
        "pdf",
        "--paper-format",
        "A4",
        "--wait-for-selector",
        f"#{PRINT_ROOT_ID}",
        "--wait-for-timeout",
        "4000",
        "--timeout",
        str(timeout_ms),
        source.as_uri(),
        str(pdf_path),
    ]
    subprocess.run(cmd, check=True)
    if not pdf_path.is_file() or pdf_path.stat().st_size < 8:
        raise RuntimeError(f"Playwright did not write independent PDF: {pdf_path}")
    header = pdf_path.read_bytes()[:4]
    if header != b"%PDF":
        raise RuntimeError(f"independent PDF is not a PDF file: {pdf_path}")
    raw = pdf_path.read_bytes()
    if b"pdfExportBtn" in raw or b"exportBar" in raw:
        raise RuntimeError("independent PDF contains SPA chrome bytes")
    return {
        "status": "ok",
        "pdf": str(pdf_path),
        "bytes": pdf_path.stat().st_size,
        "engine": INDEPENDENT_PDF_MARKER,
        "print_selector": f"#{PRINT_ROOT_ID}",
    }


def main(argv: list[str] | None = None) -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Write independent landscape-report.pdf")
    parser.add_argument("--dir", required=True, help="Research root containing landscape/")
    parser.add_argument("--out", default="", help="PDF output path (default: <dir>/landscape-report.pdf)")
    args = parser.parse_args(argv)
    root = Path(args.dir)
    pdf = Path(args.out) if args.out else None
    info = write_independent_landscape_pdf(root, pdf)
    print(json.dumps(info))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
