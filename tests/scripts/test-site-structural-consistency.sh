#!/usr/bin/env bash
# Structural consistency gate for the complete static website.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT

python3 - <<'PY'
from __future__ import annotations

import html
import json
import os
import re
import sys
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(os.environ["REPO_ROOT"]).resolve()
SITE = ROOT / "site"
HELP = SITE / "help"
PACKAGE = json.loads((ROOT / "package.json").read_text(encoding="utf-8"))
CATALOG = json.loads((ROOT / "docs" / "apo-catalog.json").read_text(encoding="utf-8"))

failures: list[str] = []
passes = 0


def check(description: str, ok: bool, details: list[str] | str = "") -> None:
    global passes
    if ok:
        passes += 1
        print(f"PASS: {description}")
        return
    failures.append(description)
    print(f"FAIL: {description}")
    if isinstance(details, str):
        details = [details] if details else []
    for detail in details[:40]:
        print(f"  {detail}")
    if len(details) > 40:
        print(f"  ... and {len(details) - 40} more")


version = str(PACKAGE.get("version", ""))
atomic_flows = CATALOG.get("atomic_flows", [])
workflows = CATALOG.get("workflows", [])
flow_steps = CATALOG.get("flow_steps", [])
internal_workflows = {
    "WF-POST-EXEC-GATES",
    "WF-VALIDATE-SUBSTEP",
    "WF-REVIEW-TRIAD",
    "WF-SHIP-READINESS",
}
public_workflows = [item for item in workflows if item.get("id") not in internal_workflows]

check("package version is available", bool(re.fullmatch(r"\d+\.\d+\.\d+", version)), version)
check("catalog has exactly 29 atomic flows", len(atomic_flows) == 29, f"found {len(atomic_flows)}")
check("catalog has exactly 26 workflows", len(workflows) == 26, f"found {len(workflows)}")
check(
    "catalog workflow split is exactly 22 public + 4 internal",
    len(public_workflows) == 22 and len(internal_workflows) == 4
    and internal_workflows <= {item.get("id") for item in workflows},
    f"public={len(public_workflows)} internal={len(internal_workflows)}",
)
check("catalog has exactly 118 flow-step contracts", len(flow_steps) == 118, f"found {len(flow_steps)}")


class SiteHTMLParser(HTMLParser):
    HISTORY_ATTRS = {"data-historical", "data-history", "data-version-history"}
    HISTORY_CLASSES = {"historical", "history", "version-history", "release-history", "changelog-entry"}
    VOID_TAGS = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "param", "source", "track", "wbr"}

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids: set[str] = set()
        self.links: list[tuple[str, str]] = []
        self.scripts: list[str] = []
        self.classes: set[str] = set()
        self.tags: set[str] = set()
        self.visible: list[str] = []
        self.meta: list[str] = []
        self._hidden_depth = 0
        self._history_depth = 0
        self._stack: list[tuple[str, bool, bool]] = []

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        data = {key.lower(): value or "" for key, value in attrs}
        classes = set(data.get("class", "").split())
        hidden = tag in {"script", "style", "template", "noscript"}
        historical = bool(self.HISTORY_ATTRS & set(data)) or bool(self.HISTORY_CLASSES & classes)
        if tag not in self.VOID_TAGS:
            self._stack.append((tag, hidden, historical))
            if hidden:
                self._hidden_depth += 1
            if historical:
                self._history_depth += 1
        self.tags.add(tag)
        self.classes.update(classes)
        if data.get("id"):
            self.ids.add(data["id"])
        if data.get("name") and tag in {"a", "map"}:
            self.ids.add(data["name"])
        for attr in ("href", "src"):
            if data.get(attr):
                self.links.append((attr, data[attr]))
        if tag == "script" and data.get("src"):
            self.scripts.append(data["src"])
        if tag == "meta" and data.get("content"):
            key = data.get("name") or data.get("property")
            if key in {"description", "og:title", "og:description", "twitter:title", "twitter:description"}:
                self.meta.append(data["content"])

    def handle_startendtag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        self.handle_starttag(tag, attrs)
        if tag not in self.VOID_TAGS:
            self.handle_endtag(tag)

    def handle_endtag(self, tag: str) -> None:
        if not self._stack:
            return
        _opened_tag, hidden, historical = self._stack.pop()
        if hidden:
            self._hidden_depth -= 1
        if historical:
            self._history_depth -= 1

    def handle_data(self, data: str) -> None:
        if not self._hidden_depth and not self._history_depth and data.strip():
            self.visible.append(data)


html_files = sorted(SITE.rglob("*.html"))
parsers: dict[Path, SiteHTMLParser] = {}
texts: dict[Path, str] = {}
for page in html_files:
    raw = page.read_text(encoding="utf-8")
    parser = SiteHTMLParser()
    parser.feed(raw)
    parsers[page.resolve()] = parser
    texts[page.resolve()] = raw


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def resolve_local(source: Path, value: str) -> tuple[Path, str] | None:
    value = html.unescape(value.strip())
    if not value or "{{" in value or "}}" in value:
        return None
    split = urlsplit(value)
    if split.scheme in {"mailto", "tel", "data", "javascript"} or value.startswith("//"):
        return None
    site_absolute = split.scheme in {"http", "https"}
    if site_absolute:
        if split.netloc not in {"sb.alolabs.dev", "www.sb.alolabs.dev"}:
            return None
        raw_path = split.path
    elif split.scheme:
        return None
    else:
        raw_path = split.path

    if raw_path.startswith("/"):
        target = SITE / unquote(raw_path.lstrip("/"))
    else:
        target = source.parent / unquote(raw_path)
    if not raw_path:
        target = SITE if site_absolute else source
    target = target.resolve()
    try:
        target.relative_to(SITE.resolve())
    except ValueError:
        return target, unquote(split.fragment)
    if target.is_dir() or raw_path.endswith("/"):
        target = target / "index.html"
    elif not target.exists() and not target.suffix:
        target = target / "index.html"
    return target, unquote(split.fragment)


link_errors: list[str] = []
for page in html_files:
    parser = parsers[page.resolve()]
    for attr, value in parser.links:
        resolved = resolve_local(page, value)
        if resolved is None:
            continue
        target, fragment = resolved
        if not target.exists() or not target.is_file():
            link_errors.append(f"{rel(page)}: {attr}=\"{value}\" -> missing {rel(target)}")
            continue
        if fragment and target.suffix.lower() in {".html", ".htm"}:
            target_parser = parsers.get(target.resolve())
            if target_parser is None:
                target_parser = SiteHTMLParser()
                target_parser.feed(target.read_text(encoding="utf-8"))
                parsers[target.resolve()] = target_parser
            if fragment not in target_parser.ids:
                link_errors.append(f"{rel(page)}: {attr}=\"{value}\" -> missing #{fragment} in {rel(target)}")
check("all local HTML href/src targets and fragments resolve", not link_errors, link_errors)


search_path = HELP / "search.js"
search_errors: list[str] = []
entries: list[dict] = []
try:
    search_source = search_path.read_text(encoding="utf-8")
    match = re.search(r"\b(?:var|const|let)\s+IDX\s*=", search_source)
    if not match:
        raise ValueError("IDX assignment not found")
    entries, _ = json.JSONDecoder().raw_decode(search_source[match.end():].lstrip())
    if not isinstance(entries, list):
        raise ValueError("IDX is not an array")
except (OSError, ValueError, json.JSONDecodeError) as exc:
    search_errors.append(f"site/help/search.js: {exc}")

for position, entry in enumerate(entries):
    url = str(entry.get("url", ""))
    anchor = str(entry.get("anchor", ""))
    final = url + (f"#{anchor}" if anchor else "")
    if not url:
        search_errors.append(f"IDX[{position}] has no URL")
        continue
    if "#" in url or "#" in anchor or final.count("#") > 1:
        search_errors.append(f"IDX[{position}] duplicates or embeds a fragment: {final}")
        continue
    resolved = resolve_local(search_path, final)
    if resolved is None:
        search_errors.append(f"IDX[{position}] is not a local Help URL: {final}")
        continue
    target, fragment = resolved
    if not target.exists():
        search_errors.append(f"IDX[{position}] -> missing {rel(target)} ({final})")
        continue
    if fragment:
        target_parser = parsers.get(target.resolve())
        if target_parser is None or fragment not in target_parser.ids:
            search_errors.append(f"IDX[{position}] -> missing #{fragment} in {rel(target)}")
check("every Help search URL and final anchor resolves exactly once", not search_errors, search_errors)


fragment_errors: list[str] = []
fragment_contracts = {
    SITE / "_chrome" / "nav.html": ("{{ROOT}}", "nav-inner", "nav-links", "nav-actions", "nav-help", "theme-toggle"),
    SITE / "_chrome" / "help-subnav.html": ("{{BREADCRUMB}}", "{{HELP_LINKS}}", "{{HELP_SEARCH}}", "help-subnav"),
    SITE / "_chrome" / "footer.html": ("{{ROOT}}", "footer-inner", "footer-credit", "footer-links"),
}
for fragment, markers in fragment_contracts.items():
    raw = fragment.read_text(encoding="utf-8") if fragment.exists() else ""
    missing = [marker for marker in markers if marker not in raw]
    if missing:
        fragment_errors.append(f"{rel(fragment)} missing {', '.join(missing)}")
check("shared chrome fragments retain their template contract", not fragment_errors, fragment_errors)


chrome_errors: list[str] = []
for page in sorted(HELP.rglob("*.html")):
    raw = texts[page.resolve()]
    parser = parsers[page.resolve()]
    required_markers = {
        "shared tokens": "tokens.css",
        "shared chrome CSS": "chrome.css",
        "site navigation": "nav-inner",
        "navigation links": "nav-links",
        "navigation actions": "nav-actions",
        "Help subnavigation": "help-subnav",
        "Help breadcrumb": "help-breadcrumb",
        "Help section links": "help-subnav-links",
        "footer": "footer-inner",
        "footer legal links": "footer-links",
    }
    for label, marker in required_markers.items():
        if marker not in raw:
            chrome_errors.append(f"{rel(page)} missing {label} ({marker})")
    if "has-help-subnav" not in parser.classes:
        chrome_errors.append(f"{rel(page)} body does not declare has-help-subnav")
    script_names = {urlsplit(src).path.rsplit("/", 1)[-1] for src in parser.scripts}
    for required in ("search.js", "common.js", "chrome.js"):
        if required not in script_names:
            chrome_errors.append(f"{rel(page)} missing {required}")
    if not any("lucide" in src.lower() for src in parser.scripts):
        chrome_errors.append(f"{rel(page)} missing Lucide icon script")
check("every canonical Help page has complete shared chrome, navigation, scripts, and footer", not chrome_errors, chrome_errors)


help_corpus = "\n".join(
    page.read_text(encoding="utf-8")
    for page in sorted(HELP.rglob("*.html"))
)
missing_af = [flow["id"] for flow in atomic_flows if flow.get("id") not in help_corpus]
missing_wf = [workflow["id"] for workflow in workflows if workflow.get("id") not in help_corpus]
check("every catalog atomic flow is documented in Help", not missing_af, missing_af)
check("every catalog workflow is documented in Help", not missing_wf, missing_wf)

workflow_page_errors: list[str] = []
dedicated_workflow_pages = {
    page: page.read_text(encoding="utf-8")
    for page in sorted((HELP / "workflows").glob("*.html"))
    if page.name != "index.html"
}
for workflow in public_workflows:
    workflow_id = workflow["id"]
    matching_pages = [page for page, raw in dedicated_workflow_pages.items() if workflow_id in raw]
    if not matching_pages:
        workflow_page_errors.append(f"{workflow_id} has no dedicated site/help/workflows/*.html page")
check(
    "all 22 public workflows have catalog-linked Help pages (only 4 internal workflows are page-optional)",
    not workflow_page_errors,
    workflow_page_errors,
)


def bounded_source(path: Path, start: str, end: str) -> str:
    raw = path.read_text(encoding="utf-8") if path.exists() else ""
    start_at = raw.find(start)
    end_at = raw.find(end, start_at + len(start)) if start_at >= 0 else -1
    if start_at < 0 or end_at < 0:
        return ""
    return raw[start_at:end_at]


capability_order = [
    "AF-ROUTE", "AF-BOOTSTRAP", "AF-ORIENT", "AF-CLARIFY", "AF-DECIDE",
    "AF-SPECIFY", "AF-PLAN", "AF-DESIGN-CONTRACT", "AF-VALIDATE",
    "AF-QUALITY-GATE", "AF-FAST-PATH", "AF-EXECUTE", "AF-AGENT-DELEGATE",
    "AF-MULTI-AI-TASK", "AF-DEBUG", "AF-UI-QUALITY", "AF-VERIFY", "AF-SECURE",
    "AF-REVIEW-REQUEST", "AF-REVIEW", "AF-REVIEW-TRIAGE", "AF-BLAST-RADIUS",
    "AF-DEVOPS-ROUTE", "AF-BRANCH-FINISH", "AF-COMPLETION-AUDIT", "AF-SHIP",
    "AF-RELEASE", "AF-DOCUMENT", "AF-PHASE-MANAGE",
]
catalog_ids = [flow.get("id") for flow in atomic_flows]
listing_errors: list[str] = []
if set(capability_order) != set(catalog_ids) or len(capability_order) != len(catalog_ids):
    listing_errors.append("structural gate capability order does not match the canonical catalog ID set")

listing_surfaces = [
    (
        "homepage atomic-flow table",
        SITE / "index.html",
        'id="workflow-flows"',
        "</table>",
        r"<code>([A-Z][A-Z0-9_]+)</code>",
        [flow_id.removeprefix("AF-").replace("-", "_") for flow_id in capability_order],
    ),
    (
        "Help composable atomic-flow table",
        HELP / "concepts" / "composable-workflow.html",
        'id="atomic-flow-catalog"',
        'id="legacy-alias-map"',
        r"\b(AF-[A-Z0-9-]+)\b",
        capability_order,
    ),
    (
        "Help workflow-index atomic-flow table",
        HELP / "workflows" / "index.html",
        'id="atomic-flows"',
        'id="post-execution"',
        r"\b(AF-[A-Z0-9-]+)\b",
        capability_order,
    ),
    (
        "Help reference atomic-flow table",
        HELP / "reference" / "index.html",
        'id="atomic-flow-list"',
        'id="recommended-tools"',
        r"<tr><td>([A-Z][A-Z0-9_]+)</td>",
        [flow_id.removeprefix("AF-").replace("-", "_") for flow_id in capability_order],
    ),
]
for label, path, start, end, pattern, expected in listing_surfaces:
    section = bounded_source(path, start, end)
    actual = re.findall(pattern, section)
    duplicates = sorted({item for item in actual if actual.count(item) > 1})
    if actual != expected or len(actual) != len(expected) or duplicates:
        missing = [item for item in expected if item not in actual]
        extra = [item for item in actual if item not in expected]
        listing_errors.append(
            f"{label}: canonical capability order mismatch; missing={missing}, extra={extra}, duplicates={duplicates}, found={len(actual)}"
        )
check("every full catalog listing surface contains all canonical atomic flows in capability order", not listing_errors, listing_errors)


workflow_order_errors: list[str] = []
workflow_order_surfaces = [
    (
        "homepage workflow table",
        SITE / "index.html",
        'id="workflow-orch"',
        'id="workflow-flows"',
        ["silver-deep-research.html", "silver-new-workflow.html", "silver-feature.html", "silver-agent-delegate.html", "silver-devops.html", "silver-release.html"],
    ),
    (
        "Help workflow index",
        HELP / "workflows" / "index.html",
        'id="composer-workflows"',
        'id="atomic-flows"',
        ["/sb:deep-research</td>", "/sb:new-workflow</td>", "/sb:feature</td>", "agent delegation</td>", "/sb:devops</td>", "/sb:release</td>"],
    ),
    (
        "Help reference workflow table",
        HELP / "reference" / "index.html",
        'id="orchestration-workflows"',
        'id="complexity-triage"',
        ["silver-deep-research.html", "silver-new-workflow.html", "silver-feature.html", "silver-agent-delegate.html", "/sb:worktree", "silver-devops.html", "silver-release.html"],
    ),
]
for label, path, start, end, markers in workflow_order_surfaces:
    section = bounded_source(path, start, end)
    positions = [section.find(marker) for marker in markers]
    if any(position < 0 for position in positions):
        missing = [marker for marker, position in zip(markers, positions) if position < 0]
        workflow_order_errors.append(f"{label}: missing order markers {missing}")
    elif positions != sorted(positions):
        workflow_order_errors.append(f"{label}: discovery/planning, execution, infrastructure, and release rows are out of SDLC order")
check("workflow listing surfaces preserve canonical SDLC order", not workflow_order_errors, workflow_order_errors)


summary_surfaces = [
    SITE / "index.html",
    HELP / "index.html",
    HELP / "reference" / "index.html",
    HELP / "workflows" / "index.html",
    HELP / "concepts" / "composable-workflow.html",
    HELP / "search.js",
]
summary_errors: list[str] = []
count_patterns = {
    "29 atomic flows": re.compile(r"(?:\b29\b.{0,45}(?:AF-\*)?.{0,15}atomic flows|atomic flows.{0,45}\b29\b)", re.I | re.S),
    "26 workflows": re.compile(r"(?:\b26\b.{0,45}(?:WF-\*)?.{0,15}workflows|workflows.{0,45}\b26\b)", re.I | re.S),
    "118 flow steps": re.compile(r"(?:\b118\b.{0,45}flow[- ]steps?|flow[- ]steps?.{0,45}\b118\b)", re.I | re.S),
}
for surface in summary_surfaces:
    raw = surface.read_text(encoding="utf-8") if surface.exists() else ""
    for label, pattern in count_patterns.items():
        if not pattern.search(raw):
            summary_errors.append(f"{rel(surface)} missing current {label} summary")
check("catalog summary surfaces show 29 AF / 26 WF / 118 flow-step counts", not summary_errors, summary_errors)

site_without_history = "\n".join(
    " ".join(parsers[page.resolve()].visible + parsers[page.resolve()].meta)
    for page in html_files
    if not any(part in {"changelog", "brute", "gaps"} for part in page.relative_to(SITE).parts)
)
unqualified_public_count = re.compile(r"\b22\s+(?:WF-\*\s+)?workflows\b", re.I)
count_claim_errors: list[str] = []
for match in unqualified_public_count.finditer(site_without_history):
    context = site_without_history[max(0, match.start() - 60):match.end() + 60]
    if not re.search(r"\b(public|user-facing|external)\b", context, re.I):
        count_claim_errors.append(f"22-workflow subtotal is not qualified as public: {context.strip()}")
for stale, label in ((r"\b27\b.{0,45}(?:AF-\*.{0,20})?atomic flows\b", "27 atomic flows"),
                     (r"\b85\b.{0,30}flow[- ]steps?\b", "85 flow steps")):
    if re.search(stale, site_without_history, re.I):
        count_claim_errors.append(f"stale catalog count remains: {label}")
check("site has no stale or unqualified catalog count claims", not count_claim_errors, count_claim_errors)


og_source = (SITE / "og-card.html").read_text(encoding="utf-8")
og_errors = []
if f"v{version}" not in og_source:
    og_errors.append(f"site/og-card.html missing v{version}")
for label, pattern in list(count_patterns.items())[:2]:
    if not pattern.search(og_source):
        og_errors.append(f"site/og-card.html missing {label}")
check("OG card source carries the current version and catalog counts", not og_errors, og_errors)


legal_errors: list[str] = []
legal_corpus = site_without_history
if not re.search(r"\bsource[- ]available\b", legal_corpus, re.I):
    legal_errors.append("public site never says source-available")
if not re.search(r"\bBUSL(?:-|\s*)1\.1\b|Business Source License(?:\s+1\.1)?", legal_corpus, re.I):
    legal_errors.append("public site never names BUSL-1.1")
for pattern, label in (
    (r"\bopen[- ]source\b", "open-source"),
    (r"\bfree\s+forever\b", "free forever"),
    (r"\bno[- ]strings(?:\s+attached)?\b", "no strings attached"),
):
    if re.search(pattern, legal_corpus, re.I):
        legal_errors.append(f"false licensing claim remains: {label}")
check("public licensing terminology is source-available BUSL-1.1 without false free/open-source claims", not legal_errors, legal_errors)


version_errors: list[str] = []
semver = re.compile(r"(?<![\w@])v?(0\.\d+\.\d+)(?![\w])", re.I)
historical_dirs = {"changelog", "brute", "gaps"}
for page in html_files:
    if any(part in historical_dirs for part in page.relative_to(SITE).parts):
        continue
    parser = parsers[page.resolve()]
    operational_text = " ".join(parser.visible + parser.meta)
    for match in semver.finditer(operational_text):
        if match.group(1) != version:
            context = operational_text[max(0, match.start() - 45):match.end() + 45].strip()
            version_errors.append(f"{rel(page)}: stale {match.group(0)} in {context}")
for position, entry in enumerate(entries):
    operational_text = " ".join(str(entry.get(key, "")) for key in ("page", "title", "text"))
    if str(entry.get("page", "")).lower() in {"changelog", "release history"}:
        continue
    for match in semver.finditer(operational_text):
        if match.group(1) != version:
            version_errors.append(f"site/help/search.js IDX[{position}]: stale {match.group(0)}")
check(
    "operational site content uses only the current Silver Bullet version (historical pages/blocks excluded)",
    not version_errors,
    version_errors,
)


canonical_cert = ROOT / ".planning" / "enterprise-e2e" / "CERTIFICATION-STATUS.json"
site_cert = HELP / "data" / "certification-status.json"
cert_errors: list[str] = []
if canonical_cert.exists():
    if not site_cert.exists():
        cert_errors.append(f"missing {rel(site_cert)}")
    elif canonical_cert.read_bytes() != site_cert.read_bytes():
        cert_errors.append(f"{rel(site_cert)} differs byte-for-byte from {rel(canonical_cert)}")
check("site certification status mirrors the canonical generated artifact", not cert_errors, cert_errors)


print()
print(f"Results: {passes} passed, {len(failures)} failed")
if failures:
    sys.exit(1)
PY
