#!/usr/bin/env python3
"""Replace nav/footer blocks with canonical chrome fragments."""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
SITE = REPO / "site"
CHROME_VER = "site-chrome-11"
NAV_TMPL = (SITE / "_chrome" / "nav.html").read_text(encoding="utf-8")
FOOTER_TMPL = (SITE / "_chrome" / "footer.html").read_text(encoding="utf-8")
HELP_SUBNAV_TMPL = (SITE / "_chrome" / "help-subnav.html").read_text(encoding="utf-8")

CHROME_LINK = f'<link rel="stylesheet" href="{{root}}chrome.css?v={CHROME_VER}">'
NEUTRAL_LINK = '<link rel="stylesheet" href="{root}neutral-variants.css?v=s3-home-icons">'
CHROME_SCRIPT = f'<script src="{{root}}chrome.js?v={CHROME_VER}"></script>'
THEME_BOOT = (
    "<script>(function(){try{var t=localStorage.getItem('silver-bullet-theme')"
    "||localStorage.getItem('sb-theme');document.documentElement.setAttribute"
    "('data-theme',t==='dark'?'dark':'light');}catch(e){}})();</script>"
)
OLD_THEME_BOOT_RE = re.compile(
    r"<script>\s*document\.documentElement\.setAttribute\(\s*['\"]data-theme['\"]\s*,"
    r"\s*localStorage\.getItem\(['\"]silver-bullet-theme['\"]\)==='dark'\?'dark':'light'\)\s*;"
    r"\s*</script>"
)
LUCIDE = '<script src="https://unpkg.com/lucide@0.469.0/dist/umd/lucide.min.js"></script>'

TARGET_GLOBS = [
    "index.html",
    "help/**/*.html",
    "changelog/index.html",
    "terms/index.html",
    "privacy/index.html",
]

SECTION_TITLES = {
    "getting-started": "Getting Started",
    "concepts": "Concepts",
    "workflows": "Workflows",
    "reference": "Reference",
    "troubleshooting": "Troubleshooting",
    "dev-workflow": "Dev Workflow",
    "devops-workflow": "DevOps Workflow",
}

# Match bare `nav{` only — not `.page-nav{`, `.sidebar-nav{`, etc.
_NAV_RULE = r"(?<![\w-])nav\{[^}]*\}"

# Inline rules duplicated in page <style> blocks — owned by chrome.css
STRIP_CSS_RE = re.compile(
    r"(?:"
    + _NAV_RULE
    + r"|"
    r"nav \.nav-inner\{[^}]*\}|"
    r"\.nav-logo\{[^}]*\}|"
    r"\.nav-breadcrumb\{[^}]*\}|"
    r"\.nav-breadcrumb a\{[^}]*\}|"
    r"\.nav-breadcrumb a:hover\{[^}]*\}|"
    r"\.nav-breadcrumb \.sep\{[^}]*\}|"
    r"\.nav-right\{[^}]*\}|"
    r"\.theme-btn\{[^}]*\}|"
    r"\.theme-btn:hover\{[^}]*\}|"
    r"footer\{[^}]*\}|"
    r"\.footer-inner\{[^}]*\}|"
    r"\.footer-links\{[^}]*\}|"
    r"\.footer-links a\{[^}]*\}|"
    r"\.footer-links a:hover\{[^}]*\}|"
    r"\.footer-brand-group\{[^}]*\}|"
    r"\.footer-credit\{[^}]*\}|"
    r"\.doc-sidebar\{[^}]*\}|"
    r"\.sidebar-nav\{[^}]*\}|"
    r"\.sidebar-nav li a\{[^}]*\}|"
    r"\.sidebar-nav li a:hover\{[^}]*\}|"
    r"\.sidebar-nav li a\.active\{[^}]*\}|"
    r"\.sidebar-nav \.sidebar-section\{[^}]*\}|"
    r"\.breadcrumb-nav\{[^}]*\}|"
    r"\.breadcrumb-nav a\{[^}]*\}|"
    r"\.breadcrumb-nav a:hover\{[^}]*\}|"
    r"\.nav-search-wrap\{[^}]*\}|"
    r"\.nav-search-input\{[^}]*\}|"
    r"\.nav-search-input:focus\{[^}]*\}|"
    r"\.nav-search-input::placeholder\{[^}]*\}|"
    r"\.nav-search-results\{[^}]*\}|"
    r"\.nav-search-results\.open\{[^}]*\}|"
    r"@media\(max-width:768px\)\{\.nav-search-wrap\{display:none\}\}|"
    r"@media\(max-width:768px\)\{\.doc-sidebar\{display:none\}\}|"
    r"@media\(max-width:600px\)\{\.footer-inner\{[^}]*\}[^}]*\}|"
    r"@media\(max-width:768px\)\{footer \.footer-inner\{[^}]*\}[^}]*\}"
    r")",
    re.DOTALL,
)


def root_prefix(path: Path) -> str:
    rel = path.relative_to(SITE)
    depth = len(rel.parts) - 1
    return "../" * depth if depth else ""


def help_prefix(path: Path) -> str:
    rel = path.relative_to(SITE / "help")
    depth = len(rel.parts) - 1
    return "../" * depth if depth else "./"


def render(fragment: str, root: str, **extra: str) -> str:
    out = fragment.replace("{{ROOT}}", root)
    for key, value in extra.items():
        out = out.replace(f"{{{{{key}}}}}", value)
    return out


def slug_title(slug: str) -> str:
    base = slug.removesuffix(".html")
    if base.startswith("silver-"):
        return f"/silver:{base.removeprefix('silver-')}"
    return SECTION_TITLES.get(base, base.replace("-", " ").title())


def link_to_section(path: Path, section: str) -> str:
    rel = path.relative_to(SITE / "help")
    if rel.parts and rel.parts[0] == section:
        return "./"
    return f"{help_prefix(path)}{section}/"


def build_breadcrumb(path: Path) -> str:
    site_root = root_prefix(path)
    to_help = help_prefix(path)
    rel = path.relative_to(SITE / "help")
    parts = list(rel.parts)

    crumbs: list[str] = [
        f'<a href="{site_root}">Home</a>',
        '<span class="sep">/</span>',
    ]

    if len(parts) == 1 and parts[0] == "index.html":
        crumbs.append('<span class="current">Help Center</span>')
        return "".join(crumbs)

    crumbs.append(f'<a href="{to_help}">Help</a>')

    if len(parts) == 1:
        crumbs.extend(["<span class=\"sep\">/</span>", f'<span class="current">{slug_title(parts[0])}</span>'])
        return "".join(crumbs)

    section = parts[0]
    section_title = SECTION_TITLES.get(section, slug_title(section))

    if len(parts) == 2 and parts[1] == "index.html":
        crumbs.extend(["<span class=\"sep\">/</span>", f'<span class="current">{section_title}</span>'])
        return "".join(crumbs)

    section_href = link_to_section(path, section)
    crumbs.extend(["<span class=\"sep\">/</span>", f'<a href="{section_href}">{section_title}</a>'])

    if len(parts) >= 2 and parts[-1] != "index.html":
        crumbs.extend(["<span class=\"sep\">/</span>", f'<span class="current">{slug_title(parts[-1])}</span>'])

    return "".join(crumbs)


def help_section_links(path: Path) -> str:
    to_help = help_prefix(path)
    sections = [
        ("getting-started", "Start"),
        ("concepts", "Concepts"),
        ("workflows", "Workflows"),
        ("reference", "Reference"),
        ("troubleshooting", "Troubleshoot"),
    ]
    rel = path.relative_to(SITE / "help")
    active = rel.parts[0] if len(rel.parts) > 1 else "index"

    links = []
    for slug, label in sections:
        cls = ' class="active"' if slug == active else ""
        links.append(f'<a href="{to_help}{slug}/"{cls}>{label}</a>')
    return f'<div class="help-subnav-links">{"".join(links)}</div>'


def help_search_markup() -> str:
    return (
        '<div class="nav-search-wrap">'
        '<input type="text" class="nav-search-input" id="nav-search-input" '
        'placeholder="Search docs…" autocomplete="off">'
        '<div class="nav-search-results" id="nav-search-results"></div>'
        "</div>"
    )


def build_help_subnav(path: Path) -> str:
    rel = path.relative_to(SITE / "help")
    search = help_search_markup()
    return render(
        HELP_SUBNAV_TMPL,
        root_prefix(path),
        BREADCRUMB=build_breadcrumb(path),
        HELP_LINKS=help_section_links(path),
        HELP_SEARCH=search,
    )


def ensure_head_assets(html: str, root: str, *, help_page: bool = False) -> str:
    link = CHROME_LINK.format(root=root)
    neutral = NEUTRAL_LINK.format(root=root)
    html = re.sub(r'<link rel="stylesheet" href="[^"]*chrome\.css[^"]*">', link, html, count=1)
    if "chrome.css" not in html:
        if re.search(r'<link rel="stylesheet" href="[^"]*tokens\.css[^"]*">', html):
            html = re.sub(
                r'(<link rel="stylesheet" href="[^"]*tokens\.css[^"]*">)',
                r"\1\n" + link,
                html,
                count=1,
            )
        elif re.search(r'<link rel="stylesheet" href="[^"]*neutral-variants\.css[^"]*">', html):
            html = re.sub(
                r'(<link rel="stylesheet" href="[^"]*neutral-variants\.css[^"]*">)',
                r"\1\n" + link,
                html,
                count=1,
            )
        else:
            html = html.replace("</head>", f"  {link}\n</head>", 1)
    if help_page and "neutral-variants.css" not in html:
        if re.search(r'<link rel="stylesheet" href="[^"]*tokens\.css[^"]*">', html):
            html = re.sub(
                r'(<link rel="stylesheet" href="[^"]*tokens\.css[^"]*">)',
                r"\1\n" + neutral,
                html,
                count=1,
            )
        else:
            html = html.replace(link, f"{link}\n{neutral}", 1)
    if help_page and "data-neutral-variant" not in html:
        html = re.sub(
            r"<html lang=\"en\"([^>]*)>",
            r'<html lang="en"\1 data-neutral-variant="s3">',
            html,
            count=1,
        )
    html = normalize_theme_boot(html)
    return html


def normalize_theme_boot(html: str) -> str:
    """Ensure early head script defaults to light unless user saved dark."""
    html = OLD_THEME_BOOT_RE.sub(THEME_BOOT, html)
    if THEME_BOOT not in html and "<head>" in html:
        html = html.replace("<head>", f"<head>\n{THEME_BOOT}", 1)
    return html


def ensure_body_scripts(html: str, root: str) -> str:
    script = CHROME_SCRIPT.format(root=root)
    html = re.sub(r'<script src="[^"]*chrome\.js[^"]*"></script>', script, html, count=1)
    if "chrome.js" not in html:
        if LUCIDE in html:
            html = html.replace("</body>", f"{script}\n</body>", 1)
        else:
            html = html.replace("</body>", f"{LUCIDE}\n{script}\n</body>", 1)
    return html


def strip_chrome_css(html: str) -> str:
    return STRIP_CSS_RE.sub("", html)


def strip_inline_nav_css(html: str) -> str:
    """Remove homepage/help inline nav rules — chrome.css is the single source."""
    html = re.sub(
        r"/\* ───── NAV ───── \*/[\s\S]*?(?=/\* ───── )",
        "/* NAV — chrome.css */\n",
        html,
        count=1,
    )
    html = re.sub(
        r"/\* NAV \*/[\s\S]*?(?=/\* HERO \*/)",
        "/* NAV — chrome.css */\n",
        html,
        count=1,
    )
    scattered = [
        r"nav \.nav-alpha\{[^}]*\}\s*",
        r"nav \.nav-wordmark\{[^}]*\}\s*",
        r"nav \.nav-brand\{[^}]*\}\s*",
        r"nav \.nav-bullet\{[^}]*\}\s*",
        r"nav \.logo\{[^}]*\}\s*",
        r"nav \.logo\.gradient\{[^}]*\}\s*",
        r"nav \.nav-links\{[^}]*\}\s*",
        r"nav \.nav-links a\{[^}]*\}\s*",
        r"nav \.nav-links a:hover\{[^}]*\}\s*",
        r"nav \.nav-help\{[^}]*\}\s*",
        r"nav \.nav-help:hover\{[^}]*\}\s*",
        r"nav \.nav-cta\{[^}]*\}\s*",
        r"nav \.nav-cta:hover\{[^}]*\}\s*",
        r"\.nav-toggle\{[^}]*\}\s*",
        r"#theme-toggle svg\.lucide\{[^}]*\}\s*",
        r"/\* Mobile-only nav items[^*]*\*/\s*",
        r"\.mobile-only\{display:none\}\s*",
        r"@media\(max-width:768px\)\{\s*nav \.nav-links\{display:none\}\s*"
        r"\.nav-toggle\{display:block\}\s*"
        r"nav \.nav-links\.active\{[^}]*\}\s*\}\s*",
        r"@media\(max-width:480px\)\{\s*nav \.nav-cta\{display:none\}\s*"
        r"\.mobile-only\{display:block\}\s*"
        r"nav \.nav-links\.active \.mobile-only a\{[^}]*\}\s*\}\s*",
        r"/\* ≤ 480px — compact phones[^*]*\*/\s*"
        r"@media\(max-width:480px\)\{\s*\.mobile-only\{display:block\}\s*"
        r"nav \.nav-links\.active \.mobile-only a\{[^}]*\}\s*\}\s*",
        r"@media\(max-width:768px\)\{footer \.footer-inner\{[^}]*\}[^}]*\}\s*",
    ]
    for pattern in scattered:
        html = re.sub(pattern, "", html, flags=re.DOTALL)
    return html


def strip_inline_footer_css(html: str) -> str:
    """Remove inline footer rules duplicated in chrome.css."""
    html = re.sub(
        r"/\* ───── FOOTER ───── \*/[\s\S]*?(?=/\* ───── )",
        "/* FOOTER — chrome.css */\n",
        html,
        count=1,
    )
    html = re.sub(
        r"/\* FOOTER \*/[\s\S]*?(?=/\* (?:CALLOUT|SECTIONS|HERO) \*/)",
        "/* FOOTER — chrome.css */\n",
        html,
        count=1,
    )
    # Collateral fragments when footer\{ was stripped inside other selectors
    html = re.sub(
        r"\[data-theme=\"light\"\]\s*\n\[data-theme=\"dark\"\]\s*footer\s*",
        "",
        html,
    )
    html = re.sub(r"^footer\s*$", "", html, flags=re.MULTILINE)
    html = re.sub(
        r"footer a\{color:var\(--text-secondary\);text-decoration:none\}\s*"
        r"footer a:hover\{color:var\(--accent-light\)\}\s*",
        "",
        html,
    )
    html = re.sub(r"footer \.footer-copyright\{[^}]*\}\s*", "", html)
    html = re.sub(
        r"@media\(max-width:600px\)\{\.footer-inner\{[^}]*\}[^}]*\}\s*",
        "",
        html,
    )
    html = re.sub(
        r"@media\(max-width:768px\)\{footer \.footer-inner\{[^}]*\}[^}]*\}\s*",
        "",
        html,
    )
    return html


def collapse_style_whitespace(html: str) -> str:
    """Remove blank lines left after stripping duplicate chrome rules."""

    def clean_style(match: re.Match[str]) -> str:
        body = match.group(1)
        lines = [ln for ln in body.splitlines() if ln.strip()]
        return "<style>\n" + "\n".join(lines) + "\n</style>"

    return re.sub(r"<style>([\s\S]*?)</style>", clean_style, html, count=1)


def repair_css_damage(html: str) -> str:
    """Undo collateral damage when nav{ was stripped inside *-nav{ selectors."""
    html = re.sub(
        r"footer a\{color:var\(--text-secondary\);text-decoration:none\}\s*"
        r"footer a:hover\{color:var\(--accent-light\)\}\s*\n\s*\}",
        "",
        html,
    )
    html = re.sub(
        r"footer a\{color:var\(--text-secondary\);text-decoration:none\}footer a:hover\{color:var\(--accent-light\)\}\s*\n\s*\}",
        "",
        html,
    )
    html = html.replace(
        ".page-\n",
        ".page-nav{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:40px}\n",
    )
    html = html.replace(
        ".breadcrumb-\n",
        ".breadcrumb-nav{font-size:.9rem;color:var(--text-dim);margin-bottom:24px;"
        "display:flex;align-items:center;gap:8px}\n",
    )
    html = html.replace(
        ".sidebar-\n",
        ".sidebar-nav{list-style:none;padding:0;margin:0;display:flex;"
        "flex-direction:column;gap:2px}\n",
    )
    html = re.sub(
        r"\.breadcrumb-\.breadcrumb-nav",
        ".breadcrumb-nav{font-size:.9rem;color:var(--text-dim);margin-bottom:24px;"
        "display:flex;align-items:center;gap:8px}.breadcrumb-nav",
        html,
    )
    html = re.sub(
        r"\.sidebar-\.sidebar-nav",
        ".sidebar-nav{list-style:none;padding:0;margin:0;display:flex;"
        "flex-direction:column;gap:2px}.sidebar-nav",
        html,
    )
    html = re.sub(
        r"/\* FOOTER \*/\s*(?:footer a\{[^}]*\}\s*)+"
        r"(?:footer a:hover\{[^}]*\}\s*)?\s*\n?\}",
        "/* FOOTER */",
        html,
    )
    return html


def remove_help_index_subtitle(html: str) -> str:
    return re.sub(
        r'(<section class="hero">\s*<div class="container">.*?'
        r"<h1>How Can We Help You\?</h1>)\s*<p>.*?</p>",
        r"\1",
        html,
        count=1,
        flags=re.DOTALL,
    )


def replace_block(html: str, tag: str, replacement: str) -> str:
    pattern = re.compile(rf"<{tag}\b[^>]*>.*?</{tag}>", re.DOTALL | re.IGNORECASE)
    if not pattern.search(html):
        raise ValueError(f"missing <{tag}> block")
    return pattern.sub(replacement.strip(), html, count=1)


_HELP_CONTENT_START = (
    r'<(?:section class="hero"|div class="page-hero"|div id="search-results)'
)
_HELP_LEAD = rf'(?:<!--[^>]*-->\s*\n\s*)?{_HELP_CONTENT_START}'


def repair_unclosed_help_subnav(html: str) -> str:
    """Close .help-subnav when page content was accidentally nested inside it."""
    if 'id="help-subnav"' not in html:
        return html

    def repl(match: re.Match[str]) -> str:
        if match.group(2):
            return match.group(0)
        return f"{match.group(1)}\n</div>\n\n{match.group(3)}"

    return re.sub(
        rf'(<div class="help-subnav"[^>]*>\s*<div class="help-subnav-inner">[\s\S]*?</div>)\s*\n'
        rf'(</div>\s*\n\s*)?(\s*{_HELP_LEAD})',
        repl,
        html,
        count=1,
    )


def _find_div_block_end(html: str, start: int) -> int:
    """Return index after the closing </div> for the <div> at start."""
    depth = 0
    i = start
    length = len(html)
    while i < length:
        if html.startswith("<div", i):
            depth += 1
            i += 4
            continue
        if html.startswith("</div>", i):
            depth -= 1
            i += 6
            if depth == 0:
                return i
            continue
        i += 1
    raise ValueError("unclosed help-subnav block")


def replace_or_insert_help_subnav(html: str, subnav: str) -> str:
    marker = 'id="help-subnav"'
    start = html.find(f'<div class="help-subnav" {marker}')
    if start == -1:
        start = html.find('<div class="help-subnav" id="help-subnav"')
    if start == -1:
        return html.replace("</nav>", f"</nav>\n\n{subnav.strip()}", 1)
    end = _find_div_block_end(html, start)
    return html[:start] + subnav.strip() + html[end:]


def repair_help_subnav_close(html: str) -> str:
    """Insert missing </div> when page content was nested inside fixed .help-subnav."""
    marker = '<div class="help-subnav" id="help-subnav">'
    pos = html.find(marker)
    if pos == -1:
        return html
    inner_start = html.find('<div class="help-subnav-inner">', pos)
    if inner_start == -1:
        return html
    inner_end = _find_div_block_end(html, inner_start)
    rest = html[inner_end:]
    if re.match(r"\s*</div>", rest):
        return html
    if not re.match(r"\s*\n\s*<(?:div class=\"page-hero\"|section class=\"hero\")", rest):
        return html
    return html[:inner_end] + "\n</div>\n" + html[inner_end:]


def ensure_help_search_script(html: str, path: Path) -> str:
    if "search.js" in html:
        return html
    rel = help_prefix(path)
    script_tag = f'<script src="{rel}search.js"></script>'
    if re.search(r'<script src="[^"]*common\.js[^"]*"></script>', html):
        return re.sub(
            r'(<script src="[^"]*common\.js[^"]*"></script>)',
            script_tag + r"\n\1",
            html,
            count=1,
        )
    return html.replace("</body>", f"{script_tag}\n</body>", 1)


def ensure_body_class(html: str, class_name: str) -> str:
    if class_name in html:
        return html

    def add_class(match: re.Match[str]) -> str:
        tag = match.group(0)
        if "class=" in tag:
            return re.sub(r'class="([^"]*)"', rf'class="\1 {class_name}"', tag, count=1)
        return tag.replace("<body", f'<body class="{class_name}"', 1)

    return re.sub(r"<body\b[^>]*>", add_class, html, count=1)


def is_help_page(path: Path) -> bool:
    try:
        path.relative_to(SITE / "help")
        return True
    except ValueError:
        return False


def adjust_help_layout_padding(html: str) -> str:
    """Drop fixed top padding from inline heroes — chrome.css sets padding-top via --chrome-stack-h."""
    if "has-help-subnav" not in html:
        return html
    html = re.sub(
        r"(\.(?:page-hero|hero)\{[^}]*?)padding:\d+px(?: \d+px \d+px)?",
        r"\1padding-bottom:64px;padding-left:24px;padding-right:24px",
        html,
    )
    html = re.sub(
        r"(\.hero\{[^}]*?)padding-bottom:64px",
        r"\1padding-bottom:80px",
        html,
        count=1,
    )
    return html


def patch_file(path: Path) -> bool:
    root = root_prefix(path)
    html = path.read_text(encoding="utf-8")
    original = html
    nav = render(NAV_TMPL, root)
    footer = render(FOOTER_TMPL, root)
    html = replace_block(html, "nav", nav)
    html = replace_block(html, "footer", footer)
    html = strip_chrome_css(html)
    html = strip_inline_nav_css(html)
    html = strip_inline_footer_css(html)
    html = collapse_style_whitespace(html)
    html = repair_css_damage(html)
    html = ensure_head_assets(html, root, help_page=is_help_page(path))
    html = ensure_body_scripts(html, root)
    if is_help_page(path):
        html = repair_help_subnav_close(html)
        html = replace_or_insert_help_subnav(html, build_help_subnav(path))
        html = ensure_body_class(html, "has-help-subnav")
        html = ensure_help_search_script(html, path)
        html = adjust_help_layout_padding(html)
        if path == SITE / "help" / "index.html":
            html = remove_help_index_subtitle(html)
    if html != original:
        path.write_text(html, encoding="utf-8")
        return True
    return False


def main() -> int:
    changed = 0
    for pattern in TARGET_GLOBS:
        for path in sorted(SITE.glob(pattern)):
            if not path.is_file():
                continue
            try:
                if patch_file(path):
                    print(f"patched {path.relative_to(REPO)}")
                    changed += 1
            except ValueError as exc:
                print(f"SKIP {path.relative_to(REPO)}: {exc}", file=sys.stderr)
    print(f"done: {changed} file(s) updated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
