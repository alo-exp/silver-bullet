#!/usr/bin/env python3
"""Structural consistency checks for the static Help Center."""

from __future__ import annotations

import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


REPO = Path(__file__).resolve().parents[2]
SITE = REPO / "site"
HELP = SITE / "help"


class LinkParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.ids: set[str] = set()
        self.links: list[str] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        if values.get("id"):
            self.ids.add(values["id"])
        if values.get("name"):
            self.ids.add(values["name"])
        if tag == "a" and values.get("href") is not None:
            self.links.append(values["href"] or "")


def html_url(path: Path) -> str:
    rel = "/" + path.relative_to(SITE).as_posix()
    if rel.endswith("/index.html"):
        return rel[: -len("index.html")]
    return rel


def local_target(source: Path, href: str) -> tuple[Path, str] | None:
    parts = urlsplit(href)
    if parts.scheme or parts.netloc or href.startswith(("mailto:", "tel:", "javascript:", "data:")):
        return None
    raw_path = unquote(parts.path)
    if raw_path.startswith("/"):
        target = SITE / raw_path.lstrip("/")
    elif raw_path:
        target = source.parent / raw_path
    else:
        target = source
    target = target.resolve()
    try:
        target.relative_to(SITE.resolve())
    except ValueError:
        return None
    if raw_path.endswith("/") or target.is_dir():
        target /= "index.html"
    elif not target.suffix:
        target /= "index.html"
    return target, unquote(parts.fragment)


def parse_html(path: Path) -> LinkParser:
    parser = LinkParser()
    parser.feed(path.read_text(encoding="utf-8"))
    return parser


def main() -> int:
    errors: list[str] = []
    html_files = sorted(HELP.rglob("*.html"))
    parsed = {path: parse_html(path) for path in html_files}

    for source, page in parsed.items():
        for href in page.links:
            resolved = local_target(source, href)
            if resolved is None:
                continue
            target, fragment = resolved
            if not target.is_file():
                errors.append(f"{source.relative_to(REPO)}: missing local link target {href!r}")
                continue
            if fragment:
                target_page = parsed.get(target) or parse_html(target)
                if fragment not in target_page.ids:
                    errors.append(
                        f"{source.relative_to(REPO)}: missing anchor #{fragment} in "
                        f"{target.relative_to(REPO)}"
                    )

    search_text = (HELP / "search.js").read_text(encoding="utf-8")
    match = re.search(r"var IDX = (\[.*?\]);\s*\n", search_text, re.DOTALL)
    if not match:
        errors.append("site/help/search.js: unable to parse IDX array")
        entries: list[dict[str, str]] = []
    else:
        entries = json.loads(match.group(1))

    indexed_urls = {entry["url"].split("#", 1)[0] for entry in entries}
    for path in html_files:
        url = html_url(path)
        if url not in indexed_urls and not (url.endswith("index.html") and url[:-10] in indexed_urls):
            errors.append(f"{path.relative_to(REPO)}: missing Help search entry for {url}")

    for entry in entries:
        url = entry.get("url", "")
        anchor = entry.get("anchor", "")
        if "#" in url:
            errors.append(f"site/help/search.js: URL must not embed a fragment: {url}")
        resolved = local_target(HELP / "index.html", url)
        if resolved is None:
            errors.append(f"site/help/search.js: non-local indexed URL: {url}")
            continue
        target, _ = resolved
        if not target.is_file():
            errors.append(f"site/help/search.js: missing indexed target: {url}")
            continue
        if anchor:
            page = parsed.get(target) or parse_html(target)
            if anchor not in page.ids:
                errors.append(f"site/help/search.js: missing #{anchor} in {url}")

    catalog = json.loads((REPO / "docs" / "apo-catalog.json").read_text(encoding="utf-8"))
    help_text = "\n".join(path.read_text(encoding="utf-8") for path in html_files)
    for entity in [*catalog["workflows"], *catalog["atomic_flows"]]:
        if entity["id"] not in help_text:
            errors.append(f"Help Center omits catalog entity {entity['id']}")

    expected = {
        "workflows": len(catalog["workflows"]),
        "atomic_flows": len(catalog["atomic_flows"]),
        "flow_steps": len(catalog["flow_steps"]),
    }
    if expected != {"workflows": 26, "atomic_flows": 29, "flow_steps": 118}:
        errors.append(f"unexpected catalog totals: {expected}")

    if errors:
        for error in errors:
            print(f"FAIL: {error}")
        print(f"FAIL: {len(errors)} Help consistency error(s)")
        return 1
    print(
        "PASS: Help structure, links, search anchors, and catalog coverage "
        f"({expected['workflows']} workflows, {expected['atomic_flows']} atomic flows, "
        f"{expected['flow_steps']} flow steps)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
