"""Guardrails for landscape vendor hyperlinks — solution names only, not category words."""

from __future__ import annotations

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


def filter_vendor_link_pairs(pairs: list[list[str]]) -> list[list[str]]:
    """Drop generic labels; keep longest unique labels first."""
    out: list[list[str]] = []
    seen: set[str] = set()
    for pair in sorted(pairs, key=lambda p: -len(str(p[0]))):
        if not isinstance(pair, (list, tuple)) or len(pair) < 2:
            continue
        label = normalize_vendor_link_label(str(pair[0]))
        url = str(pair[1]).strip()
        if not label or not url.startswith("http"):
            continue
        if is_generic_link_label(label) or label in seen:
            continue
        out.append([label, url])
        seen.add(label)
    return out
