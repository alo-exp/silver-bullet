"""Guardrails for landscape vendor hyperlinks — solution names only, not category words."""

from __future__ import annotations

import os
import re
import ssl
import urllib.error
import urllib.request
from typing import Any

# Bare labels that must never become prose hyperlinks (category / market jargon).
GENERIC_LINK_BLOCKED_LABELS: frozenset[str] = frozenset(
    {
        "sdlc",
        "apo",
        "saas",
        "oss",
        "ai",
        "plugin",
        "plugins",
        "api",
        "cli",
        "ide",
        "pr",
        "ci",
        "cd",
        "devops",
        "orchestration",
        "workflow",
        "workflows",
    }
)

# Intentional short product aliases (uppercase acronyms) that may link in prose.
ALLOWED_SHORT_ACRONYM_LABELS: frozenset[str] = frozenset({"BMAD", "GSD"})

# Slug → canonical link/display label when pack seeds use ambiguous short names.
SLUG_LINK_LABEL_OVERRIDES: dict[str, str] = {
    "sdlc-plugin": "SDLC Plugin",
}

# Known wrong / sunset vendor URLs → corrected research-backed targets (or drop).
# Keys normalized without trailing slash, lowercased host+path.
VENDOR_URL_REWRITES: dict[str, str | None] = {
    "https://agentsys.ai": "https://github.com/agent-sh/agentsys",
    "https://agentsys.ai/": "https://github.com/agent-sh/agentsys",
    "http://agentsys.ai": "https://github.com/agent-sh/agentsys",
    "http://agentsys.ai/": "https://github.com/agent-sh/agentsys",
    "https://aws.amazon.com/ai-dlc": "https://github.com/awslabs/aidlc-workflows",
    "https://aws.amazon.com/ai-dlc/": "https://github.com/awslabs/aidlc-workflows",
    "https://github.com/ai-dlc/ai-dlc": "https://github.com/awslabs/aidlc-workflows",
    # Community IBM article is not the canonical AI-DLC product — AWS Labs is.
    "https://developer.ibm.com/articles/ai-driven-development-life-cycle/": "https://github.com/awslabs/aidlc-workflows",
    "https://developer.ibm.com/articles/ai-driven-development-life-cycle": "https://github.com/awslabs/aidlc-workflows",
    "http://developer.ibm.com/articles/ai-driven-development-life-cycle/": "https://github.com/awslabs/aidlc-workflows",
    "https://deepwork.ai": None,
    "https://deepwork.ai/": None,
    "http://deepwork.ai": None,
    "http://deepwork.ai/": None,
    "https://github.com/ruvnet/ruvnet-director": None,
    "https://github.com/SuperClaude-Org/SuperClaude": "https://github.com/SuperClaude-Org/SuperClaude_Framework",
    "https://github.com/nicobailon/oh-my-pi": None,
    "https://github.com/oh-my-pi/oh-my-pi": None,
    "https://github.com/director-ai/director": None,
    "https://github.com/zuvo-ai/zuvo": "https://github.com/greglas75/zuvo",
    "https://github.com/zuvo-labs/zuvo": "https://github.com/greglas75/zuvo",
    "https://github.com/zuvo": "https://github.com/greglas75/zuvo",
    # Invented/parked marketing domains — canonical repos verified 2026-08-14.
    "https://cc10x.dev": "https://github.com/romiluz13/cc10x",
    "https://cc10x.dev/": "https://github.com/romiluz13/cc10x",
    "http://cc10x.dev": "https://github.com/romiluz13/cc10x",
    "http://cc10x.dev/": "https://github.com/romiluz13/cc10x",
    "https://cavekit.ai": "https://github.com/JuliusBrussee/cavekit",
    "https://cavekit.ai/": "https://github.com/JuliusBrussee/cavekit",
    "http://cavekit.ai": "https://github.com/JuliusBrussee/cavekit",
    "http://cavekit.ai/": "https://github.com/JuliusBrussee/cavekit",
    "https://www.cavekit.ai": "https://github.com/JuliusBrussee/cavekit",
    "https://www.cavekit.ai/": "https://github.com/JuliusBrussee/cavekit",
    "https://barkain.com": "https://github.com/barkain/claude-code-workflow-orchestration",
    "https://barkain.com/": "https://github.com/barkain/claude-code-workflow-orchestration",
    "http://barkain.com": "https://github.com/barkain/claude-code-workflow-orchestration",
    "http://barkain.com/": "https://github.com/barkain/claude-code-workflow-orchestration",
    "https://www.barkain.com": "https://github.com/barkain/claude-code-workflow-orchestration",
    "https://www.barkain.com/": "https://github.com/barkain/claude-code-workflow-orchestration",
}


def normalize_vendor_url_key(url: str) -> str:
    return str(url or "").strip().rstrip("/")


def rewrite_vendor_url(url: str) -> str | None:
    """Rewrite known-wrong vendor URLs; return None to drop the link."""
    raw = str(url or "").strip()
    if not raw:
        return None
    if raw in VENDOR_URL_REWRITES:
        return VENDOR_URL_REWRITES[raw]
    key = normalize_vendor_url_key(raw)
    for bad, good in VENDOR_URL_REWRITES.items():
        if normalize_vendor_url_key(bad) == key:
            return good
    # Case-insensitive host match for agentsys.ai
    lower = raw.lower()
    if "agentsys.ai" in lower and "github.com/agent-sh/agentsys" not in lower:
        return "https://github.com/agent-sh/agentsys"
    if "aws.amazon.com/ai-dlc" in lower:
        return "https://github.com/awslabs/aidlc-workflows"
    if "developer.ibm.com" in lower and "ai-driven-development" in lower:
        return "https://github.com/awslabs/aidlc-workflows"
    if re.search(r"https?://(www\.)?deepwork\.ai/?$", lower):
        return None
    if re.search(r"github\.com/(zuvo-ai/zuvo|zuvo-labs/zuvo|zuvo)/?$", lower):
        return "https://github.com/greglas75/zuvo"
    return raw


def scrub_embedded_vendor_urls(obj: Any) -> Any:
    """Recursively rewrite/drop known-wrong URLs inside envelopes / JSON payloads."""
    if isinstance(obj, str):
        if obj.startswith("http://") or obj.startswith("https://"):
            rewritten = rewrite_vendor_url(obj)
            return rewritten if rewritten is not None else ""
        # Non-URL strings: rewrite IBM AI-DLC community attribution to AWS Labs canonical.
        cleaned = obj
        cleaned = re.sub(
            r"AI-DLC\s*[—–-]\s*AI-Driven Development Lifecycle\s*\(developer\.ibm\.com\s*/\s*community\)",
            "AI-DLC — AI-Driven Development Lifecycle (AWS Labs / awslabs/aidlc-workflows)",
            cleaned,
            flags=re.I,
        )
        cleaned = re.sub(
            r"https?://(?:www\.)?developer\.ibm\.com/articles/ai-driven-development-life-cycle/?",
            "https://github.com/awslabs/aidlc-workflows",
            cleaned,
            flags=re.I,
        )
        cleaned = re.sub(r"\bAI-DLC\s*\(IBM\)", "AI-DLC (AWS / awslabs)", cleaned, flags=re.I)
        cleaned = re.sub(r"\bIBM'?s?\s+AI-DLC\b", "AWS AI-DLC", cleaned, flags=re.I)
        return cleaned
    if isinstance(obj, list):
        return [x for x in (scrub_embedded_vendor_urls(i) for i in obj) if x is not None]
    if isinstance(obj, dict):
        out: dict[str, Any] = {}
        title = str(obj.get("title") or obj.get("name") or "")
        # Invented seed — drop source rows / null URLs entirely.
        if re.search(r"claude\s*code\s*expert", title, flags=re.I):
            return None
        for key, val in obj.items():
            if key in {"url", "homepage", "href", "source_ref"} and isinstance(val, str):
                if "claude-code-expert" in val.lower():
                    out[key] = None
                    continue
                rewritten = rewrite_vendor_url(val) if val.startswith("http") else scrub_embedded_vendor_urls(val)
                out[key] = rewritten if rewritten is not None else None
            elif key in {"claim", "text", "title", "name", "relevance"} and isinstance(val, str):
                cleaned = re.sub(
                    r"Claude Code Expert is a primary-market APO candidate[^.]*\.?",
                    "Claude Code Expert is excluded (invented/sunset seed — not a product).",
                    val,
                    flags=re.I,
                )
                out[key] = scrub_embedded_vendor_urls(cleaned)
            else:
                scrubbed = scrub_embedded_vendor_urls(val)
                if scrubbed is not None:
                    out[key] = scrubbed
        return out
    return obj


# Env: set SB_SKIP_VENDOR_URL_HEALTH=1 to skip network checks (offline unit tests).
_SKIP_HEALTH_ENV = "SB_SKIP_VENDOR_URL_HEALTH"
_DEFAULT_HEALTH_TIMEOUT = 12.0
_OK_STATUSES = frozenset({200, 201, 202, 203, 204, 301, 302, 303, 307, 308})
# Rate-limit / gateway blips are not dead homepages — keep unless STRICT.
_TRANSIENT_HTTP = frozenset({429, 502, 503, 504})


def normalize_vendor_link_label(label: str) -> str:
    return str(label or "").strip()


def is_generic_link_label(label: str) -> bool:
    """True when label is a category word, not a product name."""
    norm = normalize_vendor_link_label(label)
    if not norm:
        return True
    if norm.lower() in GENERIC_LINK_BLOCKED_LABELS:
        return True
    # Block bare short uppercase tokens unless explicitly allow-listed (BMAD, GSD).
    if norm.isupper() and len(norm) <= 4 and norm not in ALLOWED_SHORT_ACRONYM_LABELS:
        return True
    return False


def resolve_vendor_link_label(slug: str, label: str) -> str:
    """Prefer full product titles; never keep bare generic collisions."""
    slug_key = str(slug or "").strip()
    resolved = normalize_vendor_link_label(label)
    if slug_key in SLUG_LINK_LABEL_OVERRIDES:
        return SLUG_LINK_LABEL_OVERRIDES[slug_key]
    if is_generic_link_label(resolved) and slug_key:
        derived = slug_key.replace("-", " ").title()
        if not is_generic_link_label(derived):
            return derived
    return resolved


def check_url_health(
    url: str,
    *,
    timeout: float = _DEFAULT_HEALTH_TIMEOUT,
) -> dict[str, Any]:
    """Probe a vendor/homepage URL; non-OK HTTP (incl. 404) → ok=False.

    Returns dict: ok, status (int|None), final_url, error (str|None),
    transport_error (bool) — True when the probe failed before an HTTP status
    (timeout/DNS/SSL). Transport errors are treated as soft failures by
    filter_healthy_* (keep URL, do not invent replacements).
    """
    target = str(url or "").strip()
    if not target.startswith("http"):
        return {
            "ok": False,
            "status": None,
            "final_url": target,
            "error": "not-http",
            "transport_error": False,
        }
    if os.environ.get(_SKIP_HEALTH_ENV, "").strip() in {"1", "true", "yes"}:
        return {
            "ok": True,
            "status": 0,
            "final_url": target,
            "error": "skipped",
            "transport_error": False,
        }

    ctx = ssl.create_default_context()
    headers = {"User-Agent": "SB-vendor-link-health/1.0"}

    def _open(method: str) -> dict[str, Any]:
        req = urllib.request.Request(target, method=method, headers=headers)
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            status = int(getattr(resp, "status", 200) or 200)
            final = str(resp.geturl() or target)
            return {
                "ok": status in _OK_STATUSES,
                "status": status,
                "final_url": final,
                "error": None if status in _OK_STATUSES else f"http-{status}",
                "transport_error": False,
            }

    try:
        return _open("HEAD")
    except urllib.error.HTTPError as exc:
        # Some hosts reject HEAD; retry GET for 401/403/405.
        if exc.code in (401, 403, 405):
            try:
                return _open("GET")
            except urllib.error.HTTPError as retry_http:
                return {
                    "ok": False,
                    "status": int(retry_http.code),
                    "final_url": target,
                    "error": f"http-{retry_http.code}",
                    "transport_error": False,
                }
            except Exception as retry_exc:  # noqa: BLE001
                return {
                    "ok": False,
                    "status": None,
                    "final_url": target,
                    "error": f"{type(retry_exc).__name__}: {retry_exc}",
                    "transport_error": True,
                }
        return {
            "ok": False,
            "status": int(exc.code),
            "final_url": target,
            "error": f"http-{exc.code}",
            "transport_error": False,
        }
    except Exception as exc:  # noqa: BLE001
        return {
            "ok": False,
            "status": None,
            "final_url": target,
            "error": f"{type(exc).__name__}: {exc}",
            "transport_error": True,
        }


def filter_healthy_vendor_urls(
    urls: dict[str, str],
    *,
    timeout: float = _DEFAULT_HEALTH_TIMEOUT,
) -> tuple[dict[str, str], list[dict[str, Any]]]:
    """Drop URLs with confirmed non-OK HTTP status. Keep transport-error URLs.

    Returns (kept, dropped_reports). Transport failures are recorded on kept
    entries via warnings in dropped with action='kept_transport_error' only when
    SB_VENDOR_URL_HEALTH_STRICT=1 is set (then transport errors also drop).
    """
    strict_transport = os.environ.get("SB_VENDOR_URL_HEALTH_STRICT", "").strip() in {
        "1",
        "true",
        "yes",
    }
    kept: dict[str, str] = {}
    dropped: list[dict[str, Any]] = []
    for label, url in (urls or {}).items():
        label_n = normalize_vendor_link_label(label)
        url_n = str(url or "").strip()
        if not label_n or not url_n.startswith("http"):
            continue
        report = check_url_health(url_n, timeout=timeout)
        if report.get("ok"):
            kept[label_n] = url_n
            continue
        if report.get("transport_error") and not strict_transport:
            # Ambiguous network failure — do not unlink (avoid false 404 drops).
            kept[label_n] = url_n
            continue
        status = report.get("status")
        if status in _TRANSIENT_HTTP and not strict_transport:
            kept[label_n] = url_n
            continue
        dropped.append(
            {
                "label": label_n,
                "url": url_n,
                "status": report.get("status"),
                "error": report.get("error"),
                "final_url": report.get("final_url"),
                "transport_error": bool(report.get("transport_error")),
            }
        )
    return kept, dropped


def filter_healthy_link_pairs(
    pairs: list[list[str]],
    *,
    timeout: float = _DEFAULT_HEALTH_TIMEOUT,
) -> tuple[list[list[str]], list[dict[str, Any]]]:
    """Drop link pairs whose URL fails health check."""
    as_dict = {
        normalize_vendor_link_label(str(p[0])): str(p[1]).strip()
        for p in pairs
        if isinstance(p, (list, tuple)) and len(p) >= 2
    }
    kept_map, dropped = filter_healthy_vendor_urls(as_dict, timeout=timeout)
    kept_pairs = [[label, kept_map[label]] for label in as_dict if label in kept_map]
    return kept_pairs, dropped


def _url_label_token_score(label: str, url: str) -> int:
    """How well a display label matches tokens in the URL host/path."""
    url_l = str(url or "").lower()
    tokens = re.findall(r"[a-z0-9]+", str(label or "").lower())
    return sum(1 for tok in tokens if len(tok) > 2 and tok in url_l)


def drop_ambiguous_shared_homepage_urls(pairs: list[list[str]]) -> list[list[str]]:
    """Drop colliding product→URL mappings that share one homepage across distinct labels.

    Marketplace roots (e.g. claude.com/plugins) must not be reused as the homepage for
    unrelated products. When multiple labels share an exact URL, keep only the best
    URL-token match; if none match, drop all (do not invent a winner).
    """
    by_url: dict[str, list[str]] = {}
    for pair in pairs:
        if not isinstance(pair, (list, tuple)) or len(pair) < 2:
            continue
        label = normalize_vendor_link_label(str(pair[0]))
        url = str(pair[1]).strip()
        if not label or not url.startswith("http"):
            continue
        by_url.setdefault(url, []).append(label)

    drop: set[str] = set()
    for url, labels in by_url.items():
        unique = list(dict.fromkeys(labels))
        if len(unique) < 2:
            continue
        # Same-product aliases ("Devin" + "Devin (Cognition)") share a homepage on
        # purpose so bare prose still linkifies. That is not a marketplace collision.
        shortest = min(unique, key=len)
        if shortest and all(
            lab == shortest
            or lab.startswith(shortest + " ")
            or lab.startswith(shortest + "(")
            for lab in unique
        ):
            continue
        scored = sorted(
            (
                (_url_label_token_score(lab, url), len(lab), lab)
                for lab in unique
            ),
            reverse=True,
        )
        best_score = scored[0][0]
        if best_score <= 0:
            drop.update(unique)
            continue
        keep = {lab for score, _length, lab in scored if score == best_score}
        if len(keep) > 1:
            keep = {max(keep, key=len)}
        drop.update(set(unique) - keep)

    return [
        [normalize_vendor_link_label(str(pair[0])), str(pair[1]).strip()]
        for pair in pairs
        if isinstance(pair, (list, tuple))
        and len(pair) >= 2
        and normalize_vendor_link_label(str(pair[0])) not in drop
    ]


def filter_vendor_link_pairs(pairs: list[list[str]]) -> list[list[str]]:
    """Drop generic labels; keep longest unique labels first; reject shared homepage collisions."""
    out: list[list[str]] = []
    seen: set[str] = set()
    for pair in sorted(pairs, key=lambda p: -len(str(p[0]))):
        if not isinstance(pair, (list, tuple)) or len(pair) < 2:
            continue
        label = normalize_vendor_link_label(str(pair[0]))
        url = rewrite_vendor_url(str(pair[1]).strip())
        if not label or not url or not url.startswith("http"):
            continue
        if is_generic_link_label(label) or label in seen:
            continue
        # Claude Harness is unverified — never borrow the Claude Code host repo as homepage.
        if re.search(r"(?i)^claude\s*harness$", label) and "anthropics/claude-code" in url.lower():
            continue
        out.append([label, url])
        seen.add(label)
    return drop_ambiguous_shared_homepage_urls(out)


def scrub_vendor_markdown_links(
    markdown: str,
    *,
    vendor_urls: dict[str, str],
    known_labels: set[str] | None = None,
) -> str:
    """Rewrite/remove vendor markdown links to match authoritative homepages only.

    Labels in known_labels/vendor_urls with no homepage become plain text (never keep
    a stale invented URL). Authoritative URLs are rewritten to the current mapping.
    """
    urls = {normalize_vendor_link_label(k): str(v).strip() for k, v in (vendor_urls or {}).items()}
    known = {normalize_vendor_link_label(x) for x in (known_labels or set())} | set(urls)
    pattern = re.compile(r"\[([^\]]+)\]\((https?://[^)]+)\)")

    def _repl(match: re.Match[str]) -> str:
        label = normalize_vendor_link_label(match.group(1))
        url = match.group(2).strip()
        if label not in known:
            return match.group(0)
        auth = urls.get(label)
        if auth:
            return f"[{label}]({auth})"
        return label

    return pattern.sub(_repl, markdown or "")


# Bare http(s) autolink — wrap existing URLs only; never invent targets.
BARE_HTTP_URL_RE = re.compile(r"https?://[^\s<>\"'`\\]+", re.IGNORECASE)
_MD_LINK_OR_BARE_ANGLE_RE = re.compile(
    r"(\[[^\]]+\]\([^)]+\)|<https?://[^>]+>)",
    re.IGNORECASE,
)
_MD_CODE_SPAN_RE = re.compile(r"(`[^`]+`)")


def split_url_trailing_punct(raw: str) -> tuple[str, str]:
    """Split a matched URL from trailing sentence punctuation."""
    url = raw or ""
    trail = ""
    while url and url[-1] in ".,;:!?":
        trail = url[-1] + trail
        url = url[:-1]
    while url.endswith(")") and url.count("(") < url.count(")"):
        trail = ")" + trail
        url = url[:-1]
    while url.endswith("]") and url.count("[") < url.count("]"):
        trail = "]" + trail
        url = url[:-1]
    while url.endswith(">") and url.count("<") < url.count(">"):
        trail = ">" + trail
        url = url[:-1]
    return url, trail


def _linkify_prose_urls(text: str) -> str:
    def _repl(match: re.Match[str]) -> str:
        url, trail = split_url_trailing_punct(match.group(0))
        if not url.lower().startswith("http://") and not url.lower().startswith("https://"):
            return match.group(0)
        return f"[{url}]({url}){trail}"

    return BARE_HTTP_URL_RE.sub(_repl, text)


def _linkify_code_span_url(span: str) -> str:
    """Turn `https://example` into [`https://example`](https://example)."""
    if len(span) < 3 or span[0] != "`" or span[-1] != "`":
        return span
    inner = span[1:-1]
    stripped = inner.strip()
    url, trail = split_url_trailing_punct(stripped)
    lowered = url.lower()
    if not lowered.startswith("http://") and not lowered.startswith("https://"):
        return span
    if stripped not in {url, url + trail}:
        return span
    return f"[`{url}`]({url})" + (trail if stripped == url + trail else "")


def linkify_bare_http_urls(markdown: str) -> str:
    """Wrap remaining bare http(s) URLs as markdown links.

    Skips existing ``[text](url)`` and ``<https://...>`` autolinks. Code-span URLs
    become ``[`url`](url)`` so SPA/PDF render real anchors. Does not invent URLs.
    """
    if not markdown:
        return markdown
    parts: list[str] = []
    for i, block in enumerate(_MD_LINK_OR_BARE_ANGLE_RE.split(markdown)):
        if i % 2 == 1:
            parts.append(block)
            continue
        span_parts: list[str] = []
        for j, piece in enumerate(_MD_CODE_SPAN_RE.split(block)):
            if j % 2 == 1:
                span_parts.append(_linkify_code_span_url(piece))
            else:
                span_parts.append(_linkify_prose_urls(piece))
        parts.append("".join(span_parts))
    return "".join(parts)
