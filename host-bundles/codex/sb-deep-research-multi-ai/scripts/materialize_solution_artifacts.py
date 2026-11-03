#!/usr/bin/env python3
"""Materialize SCR + features.json from live DR-multi-AI contribution envelopes."""

from __future__ import annotations

import contextlib
import json
import re
from pathlib import Path
from typing import Any, Iterator

from generated_files import write_generated_text
from pack_vocabulary import activated, for_research_dir
from category_pack import (
    build_known_solutions,
    build_overview_seeds,
    feature_key,
    get_core_seed_slugs,
    normalize_slug,
    pack_overlay,
    resolve_pack_from_need,
)

# Category vocabulary (feature rubric, aliases, prose signals) is pack overlay data applied by
# pack_vocabulary.activated(); these neutral defaults match nothing.
NEVER_MATCHES = re.compile(r"(?!x)x")
HOST_RUNTIME_SLUGS: frozenset[str] = frozenset()
# [{"focus": "<name fragment>", "reject_if_any": [[needle, ...], ...]}]: card-identity leak filters.
OVERVIEW_IDENTITY_FILTERS: list[dict[str, Any]] = []
FEATURE_TEMPLATE: list[dict[str, Any]] = []

KNOWN_SOLUTIONS: dict[str, str] = {}  # category data lives in the pack overlay (reference/category-pack-overlays)

def _effective_known_solutions(need: dict[str, Any] | None = None) -> dict[str, str]:
    """Merge base KNOWN_SOLUTIONS with pack product_names when a pack is active."""
    pack = resolve_pack_from_need(need)
    base = dict(KNOWN_SOLUTIONS) or dict(_RUN["known"] or {})
    if pack:
        merged = dict(base)
        merged.update({str(k): str(v) for k, v in (pack_overlay(pack).get("known_solutions") or {}).items()})
        merged.update(build_known_solutions(pack))
        return merged
    return base


def _slug_aliases(pack: dict[str, Any] | None) -> dict[str, str]:
    """Free-text vendor alias -> slug: pack overlay data only (nothing is built in)."""
    merged = dict(SLUG_ALIASES)
    merged.update({str(k): str(v) for k, v in (pack_overlay(pack or _RUN["pack"]).get("slug_aliases") or {}).items()})
    return merged


def _head_aliases(pack: dict[str, Any] | None) -> dict[str, str]:
    merged = dict(_HEAD_SLUG_ALIASES)
    merged.update({str(k): str(v) for k, v in (pack_overlay(pack or _RUN["pack"]).get("head_slug_aliases") or {}).items()})
    return merged


def _effective_overview_seeds(need: dict[str, Any] | None = None) -> dict[str, str]:
    pack = resolve_pack_from_need(need)
    seeds = dict(OVERVIEW_SEEDS)
    if pack:
        seeds.update({str(k): str(v) for k, v in (pack_overlay(pack).get("overview_seeds") or {}).items()})
        seeds.update(build_overview_seeds(pack))
    return seeds


# Curated product blurbs for solution-card Overviews (not research-meta notes).
OVERVIEW_SEEDS: dict[str, str] = {}  # category data lives in the pack overlay (reference/category-pack-overlays)

SLUG_ALIASES: dict[str, str] = {}  # category data lives in the pack overlay (reference/category-pack-overlays)

_MATRIX_DUMP_RE = re.compile(
    r"(?:"
    r"startup-weighted\s+matrix|"
    r"prior\s+startup-weighted\s+run\s+scored|"
    r"prior\s+startup-weighted\s+live\s+matrix\s+rankings|"
    r"matrix\s+rankings\s*:|"
    r"internal\s+comparative\s+evidence|"
    r"prior\s+dry[- ]run|"
    r"persona_id\s*=\s*startup|"
    r"\bmatrix\s*[—–-]\s*|"
    r"startup\s+shortlist\s+scores|"
    r"live\s+fullpool\s+solution\s+set|"
    r"fullpool\s+solution\s+set|"
    r"re-score\s*\(\s*minimum\s*\)|"
    r"market\s+segments?\s*(?:\(\s*startup-weighted\s*\))?|"
    r"market\s+subsegments?\s+useful\s+for\s+matrix|"
    r"on\s+critical\s+['\"]workflow\s+composition['\"]|"
    r"prior\s+live\s+shortlist|"
    r"(?:\b[a-z][\w-]*\s+\d{1,3}\s*;\s*){2,}[a-z][\w-]*\s+\d{1,3}|"
    r"(?:\b[a-z][\w-]*\s+\d{1,3}\s*,\s*){2,}[a-z][\w-]*\s+\d{1,3}"
    r")",
    re.IGNORECASE,
)

_META_OVERVIEW_RE = re.compile(
    r"(?:"
    r"participates in the (?:agentic|category)|"
    r"capability profile derived|"
    r"coverage is based on multi[- ]ai|"
    r"comparison matrix signals|"
    r"\btriangulat(?:e|ion|ed)\b|"
    r"consolidated narrative|"
    r"zero triangulate|"
    r"landscape omits|"
    r"missing coverage of|"
    r"absent from consolidated|"
    r"should anchor any comparison|"
    r"ideal for teams evaluating process layers|"
    r"live multi-ai dr envelopes|"
    r"multi-ai envelope synthesis|"
    r"retrieve sources still include|"
    r"risks scoring a legacy brand|"
    r"treat gsd as legacy|"
    r"no analysis of open-source alternatives|"
    r"top credible threats to sb|"
    r"the market has consolidated around|"
    r"true pr-only review tools"
    r")",
    re.IGNORECASE,
)


def is_matrix_dump_claim(text: str) -> bool:
    """Return True when claim text is a cross-vendor matrix/score dump, not solution prose."""
    t = (text or "").strip()
    if not t:
        return True
    if _MATRIX_DUMP_RE.search(t):
        return True
    lower = t.lower()
    if "maps to must_have" in lower or "maps to must-have" in lower:
        return True
    if re.search(r"✔\s+for\s+", t) and "," in t:
        return True
    if re.search(r"\bscored\b", lower) and re.search(r"\b\d{2,}\b", t) and t.count(",") >= 2:
        return True
    return False


def is_unusable_overview_claim(
    text: str, *, focus_name: str = "", known: dict[str, str] | None = None
) -> bool:
    """Reject meta-research / multi-vendor dumps unsuitable as a solution Overview blurb."""
    t = (text or "").strip()
    if not t or is_matrix_dump_claim(t):
        return True
    if _META_OVERVIEW_RE.search(t):
        return True
    if len(t) > 420:
        return True
    focus = (focus_name or "").lower()
    lower = t.lower()
    # Card identity leaks: another product's install path or report methodology prose.
    for rule in OVERVIEW_IDENTITY_FILTERS:
        if focus and str(rule.get("focus", "")).lower() in focus and any(
            all(str(needle).lower() in lower for needle in group) for group in rule.get("reject_if_any", [])
        ):
            return True
    # Claims that list many other products are landscape notes, not overviews.
    others = 0
    for display in _known_or_run(known).values():
        name = display.lower()
        if not name or (focus and (name == focus or name in focus or focus in name)):
            continue
        if name in lower:
            others += 1
            if others >= 3:
                return True
    return False


def _slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def _normalize_slug(token: str, known: dict[str, str] | None = None, pack: dict[str, Any] | None = None) -> str | None:
    token = token.strip().lower().strip("`\"'")
    if not token:
        return None
    effective = _known_or_run(known)
    if token in effective:
        return token
    aliases = _slug_aliases(pack)
    if token in aliases:
        return aliases[token]
    compact = re.sub(r"[^a-z0-9]+", " ", token).strip()
    if compact in aliases:
        return aliases[compact]
    if pack:
        resolved = normalize_slug(token, pack)
        if resolved:
            return resolved
    slug = _slugify(token)
    return slug if slug in effective else None


def _mentions(lower_text: str, name: str) -> bool:
    """Whole-word match, so 'sbom' is not 'sb' and 'compliance' is not 'pi'."""
    if not name:
        return False
    return re.search(rf"(?<![a-z0-9]){re.escape(name)}(?![a-z0-9])", lower_text) is not None


# Product names that are also ordinary English words ("director", "factory", "cursor", ...). Pack
# vocabulary; a capitalised mention counts as a vendor only where it reads as a proper noun (see
# mentions_vendor). NON_VENDOR_TERMS are category words that a pack alias maps to a product ("sdlc"
# -> a plugin): a pack alias that is a plain category word never counts as a vendor mention.
AMBIGUOUS_NAMES: frozenset[str] = frozenset()
NON_VENDOR_TERMS: frozenset[str] = frozenset()
_CUE_AFTER = re.compile(
    r"\s*(?:\((?!\s*\d)|\.(?:ai|dev|com|io|app)\b|\s(?:AI|IDE|Agents?|Plugins?|Cloud|Platform|CLI|App|SaaS|Code|Copilot|Labs|Dev|OSS|Background)\b)"
)
_CUE_BEFORE = re.compile(r"\b(?:by|from|using|via|with|vs\.?|versus)\s+$", re.IGNORECASE)
_SENTENCE_OPENERS = "\"'“‘([*_#>•- \t\r\n"
# A sentence-initial capital proves nothing ("Linear scaling is expected"), so there the name must be
# the subject of a finite verb or a possessive ("Director is ...", "Factory provides ...", "Director's README").
_SUBJECT_OF = re.compile(
    r"[*_\"']*(?:['’]s\b|\s+(?:is|are|was|were|has|have|had|does|did|can|could|will|would|should|may|"
    r"(?:support|provide|offer|ship|add|use|run|enforce|orchestrate|install|integrate|include|require|lack|enable|"
    r"deliver|automate|claim|position|target|wrap|extend|expose|implement|ensure|bundle|cover|handle|package)s?)\b)"
)
_NOT_A_NAME_BEFORE_OF = re.compile(r"\s+of\b")


def _sentence_initial(text: str, start: int) -> bool:
    """True when only opening punctuation separates `start` from a sentence boundary (or the text start).

    Scans back over the opener characters only, so the cost does not grow with the claim length.
    """
    i = start
    while i > 0 and text[i - 1] in _SENTENCE_OPENERS:
        i -= 1
    if i == 0:
        return True
    return text[i - 1] in ".!?:;" or "\n" in text[i:start]


# A name inside an ordinary Title-Case phrase is not the product: "AI Factory", "Abstract Factory",
# "Netflix Conductor", "Linear Regression", "Continue button", "the Director agent", "VP or Director".
_LOOKBEHIND = 48  # enough for "versus" plus the whitespace after it; keeps the look-behind O(1)
_PREV_WORD = re.compile(r"([A-Za-z][A-Za-z0-9'’-]*)[ \t]+$")
_NEXT_WORD = re.compile(r"[ \t]+([A-Za-z][A-Za-z0-9'’-]*)")
_ROLE_BEFORE_CONNECTOR = re.compile(r"([A-Za-z]+)\s+(?:or|and|/)\s+$", re.IGNORECASE)
_ROLE_WORDS = frozenset(
    "vp svp evp ceo cto cio coo cfo manager managers head lead officer president chair editor producer".split()
)
# Capitalised only because they open a sentence (or are connectives): they do not modify the name.
_FUNCTION_WORDS = frozenset(
    "the a an and or but nor so yet if then else when while where which who that this these those it its is "
    "are was were be been has have had do does did can could will would should may might must in on at by "
    "for from of to with without within into over under per via as than not no also only both each all any "
    "some most many more our your their his her my we you they he she there here see using use run now "
    "however thus still just even such other another one two".split()
)
_HEAD_NOUNS = frozenset(
    "pattern patterns button buttons agent agents model models regression settings scaling role roles view "
    "class method interface node nodes tab menu step steps function process pagination key field label".split()
)


def _inside_ordinary_phrase(text: str, start: int, end: int) -> bool:
    window = text[max(0, start - _LOOKBEHIND):start]
    prev = _PREV_WORD.search(window)
    if prev and prev.group(1)[0].isupper() and prev.group(1).lower() not in _FUNCTION_WORDS:
        return True
    connector = _ROLE_BEFORE_CONNECTOR.search(window)
    if connector and connector.group(1).lower() in _ROLE_WORDS:
        return True
    following = _NEXT_WORD.match(text, end)
    if following:
        word = following.group(1)
        if word.lower() in _HEAD_NOUNS:
            return True
        return word[0].isupper() and word.lower() not in _FUNCTION_WORDS
    return False


# The vendor set of the run being parsed (known names incl. discovered vendors, and its pack):
# prose parsers that take no explicit `known` resolve vendors from it.
_RUN: dict[str, Any] = {"known": None, "pack": None}


@contextlib.contextmanager
def run_context(known: dict[str, str] | None, pack: dict[str, Any] | None) -> Iterator[None]:
    """Install the run's vendor set and pack for the prose parsers; restored on exit."""
    previous = dict(_RUN)
    _RUN["known"], _RUN["pack"] = known or previous["known"], pack or previous["pack"]
    try:
        yield
    finally:
        _RUN.update(previous)


def _known_or_run(known: dict[str, str] | None) -> dict[str, str]:
    return known or _RUN["known"] or KNOWN_SOLUTIONS


def mentions_vendor(text: str, lower: str, name: str) -> bool:
    """Whole-word vendor mention.

    A category word (NON_VENDOR_TERMS) never counts. An ambiguous common-word name counts when it
    reads as a proper noun: capitalised AND (next to a product cue, or inside a sentence and not
    "<Name> of ..." and not inside a Title-Case phrase ("AI Factory", "Linear Regression"), or opening a
    sentence as the subject of a verb). Linear in the claim length: every look-around is bounded.
    """
    if name.lower() in NON_VENDOR_TERMS or not _mentions(lower, name):
        return False
    if name.lower() not in AMBIGUOUS_NAMES:
        return True
    for match in re.finditer(rf"(?<![A-Za-z0-9]){re.escape(name)}(?![A-Za-z0-9])", text, re.IGNORECASE):
        word = match.group(0)
        if not word[:1].isupper():
            continue  # a vendor name is a proper noun: "director of engineering" is not one
        if _CUE_AFTER.match(text, match.end()) or _CUE_BEFORE.search(text, max(0, match.start() - _LOOKBEHIND), match.start()):
            return True
        if _NOT_A_NAME_BEFORE_OF.match(text, match.end()) or _inside_ordinary_phrase(text, match.start(), match.end()):
            continue
        if not _sentence_initial(text, match.start()) or _SUBJECT_OF.match(text, match.end()):
            return True
    return False


def _extract_slugs_from_text(
    text: str,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> list[str]:
    effective = _known_or_run(known)
    pack = pack or _RUN["pack"]
    found: list[str] = []
    lower = text.lower()
    for slug, display in effective.items():
        if any(mentions_vendor(text, lower, name) for name in (slug.replace("-", " "), slug, display.lower())):
            found.append(slug)
    for alias, slug in _slug_aliases(pack).items():
        if mentions_vendor(text, lower, alias) and slug not in found:
            found.append(slug)
    if pack:
        from category_pack import build_alias_map

        aliases = build_alias_map(pack)
        for alias, canonical in aliases.items():
            if len(alias) >= 2 and mentions_vendor(text, lower, alias) and canonical not in found:
                found.append(canonical)
        # one product is one vendor: "copilot" and "github-copilot" are the pack's names for the same slug
        found = list(dict.fromkeys(aliases.get(slug, slug) for slug in found))
    return found


def discover_solutions(
    envelopes: list[dict[str, Any]],
    *,
    min_solutions: int = 2,
    need: dict[str, Any] | None = None,
) -> list[str]:
    pack = resolve_pack_from_need(need)
    if pack:
        from solution_classifier import classify_solutions

        audit = classify_solutions(envelopes, need, pack)
        matrix_slugs = list(audit.get("matrix_slugs") or audit.get("core") or [])
        if len(matrix_slugs) >= min_solutions:
            return matrix_slugs
        # Fall back to the pack's seed *slugs* (callers build paths from them), not the seed dicts.
        return matrix_slugs or get_core_seed_slugs(pack)[: max(min_solutions, 5)]

    known = _effective_known_solutions(need)
    scores: dict[str, int] = {}
    for text in _iter_claim_texts(envelopes):
        for slug in _extract_slugs_from_text(text, known, pack):
            scores[slug] = scores.get(slug, 0) + 1
    # Open world: vendors the workers name in structured matrix rows are discovered too.
    for slug, (_display, rows) in structured_vendor_names(envelopes, known, pack).items():
        scores[slug] = scores.get(slug, 0) + rows
    ranked = sorted(scores, key=lambda s: (-scores[s], s))
    # Only vendors the models actually named: never pad with unrelated catalogue entries.
    return ranked


def _iter_claim_texts(envelopes: list[dict[str, Any]]) -> list[str]:
    texts: list[str] = []
    for env in envelopes:
        payload = env.get("payload") or {}
        for item in payload.get("evidence") or []:
            if isinstance(item, dict):
                claim = item.get("claim") or item.get("text") or ""
                if claim:
                    texts.append(str(claim))
        for item in payload.get("claim_candidates") or []:
            if isinstance(item, dict):
                text = item.get("text") or item.get("claim") or ""
                if text:
                    texts.append(str(text))
        for item in payload.get("critiques") or []:
            if isinstance(item, dict):
                finding = item.get("finding") or item.get("target") or ""
                if finding:
                    texts.append(str(finding))
        for item in payload.get("gaps") or []:
            if isinstance(item, dict):
                desc = item.get("description") or item.get("area") or ""
                if desc:
                    texts.append(str(desc))
    return texts

_MATRIX_ENTRY_RE = re.compile(
    r"Matrix entry\s*[—–\-]\s*(?P<feature>[^:]+?)(?:\s*\([^)]*\))?\s*:\s*(?P<body>.+)",
    re.IGNORECASE,
)
_MATRIX_ROW_RE = re.compile(
    r"(?:matrix|row|critical|very high)[^'\"]*['\"](?P<feature>[^'\"]+)['\"]"
    r"[^:]*:\s*(?P<body>.+)",
    re.IGNORECASE,
)
_MATRIX_DASH_RE = re.compile(
    r"Matrix\s*[—–\-]\s*(?P<feature>[^:]+?)(?:\s*\([^)]*\))?\s*:\s*(?P<body>.+)",
    re.IGNORECASE,
)
_CHECKMARK_FOR_RE = re.compile(
    r"(?P<feature>[^✔✓\n]{4,}?)\s*[✔✓]\s+for\s+(?P<body>.+)",
    re.IGNORECASE,
)
_SLUG_NEGATION_RE = re.compile(
    r"(?P<slug>[a-z][a-z0-9-]*)\s+(?:do(?:es)?\s+not|doesn't|fails?|lacks?)\b",
    re.IGNORECASE,
)
_CORE_SET_CLAIM_RE = NEVER_MATCHES
_MATRIX_LEADERS_RE = NEVER_MATCHES
_CRITERION_KEYWORD_TO_ID: dict[str, str] = {}
_HEAD_SLUG_ALIASES: dict[str, str] = {}  # category data lives in the pack overlay (reference/category-pack-overlays)

_FEATURE_ALIASES: dict[str, str] = {}

_INCLUSION_CRITERION_FEATURES: dict[str, list[str]] = {}

_INCLUSION_CRITERIA_SIGNAL_RE = NEVER_MATCHES
_ALL_SEVEN_INCLUSION_RE = NEVER_MATCHES
_PAREN_CRITERION_SLUGS_RE = NEVER_MATCHES

_PROSE_POSITIVE_SIGNALS: list[tuple[re.Pattern[str], list[str]]] = []


def _all_template_features() -> list[str]:
    features: list[str] = []
    for category in FEATURE_TEMPLATE:
        features.extend(category["features"])
    return features


def _resolve_features(feature_text: str) -> list[str]:
    text = feature_text.strip()
    lower = text.lower()
    matched: list[str] = []
    for feature in _all_template_features():
        if feature.lower() in lower and feature not in matched:
            matched.append(feature)
    for alias, feature in _FEATURE_ALIASES.items():
        if alias in lower and feature not in matched:
            matched.append(feature)
    return matched or [text]


def _matrix_entry_head_is_solution(
    head: str,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    """True when 'Matrix entry — {head}:' names a product, not a matrix feature row."""
    effective = _known_or_run(known)
    head_clean = re.sub(r"\([^)]*\)", "", head).strip()
    if not head_clean:
        return False
    if re.search(r"[✔✓✖✗]", head_clean):
        return False
    lower = head_clean.lower()
    for feature in _all_template_features():
        if lower == feature.lower() or lower.startswith(feature.lower() + " "):
            return False
    for alias in _FEATURE_ALIASES:
        if lower == alias or lower.startswith(alias + " "):
            return False
    if _normalize_slug(head_clean, effective, pack):
        return True
    if _extract_slugs_from_text(head_clean, effective, pack):
        return True
    if _slugify(head_clean) and not re.search(r"\s", head_clean):
        return True
    return False


def _canonical_known_slug(
    slug: str,
    known: dict[str, str] | None = None,
) -> str:
    effective = _known_or_run(known)
    if slug in effective:
        return slug
    for candidate in sorted(effective, key=len, reverse=True):
        if slug.startswith(f"{candidate}-") or candidate.startswith(f"{slug}-"):
            return candidate
    return slug


def _resolve_solution_slug(
    head: str,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> str | None:
    effective = _known_or_run(known)
    head_clean = re.sub(r"\([^)]*\)", "", head).strip()
    head_key = head_clean.lower().strip()
    head_aliases = _head_aliases(pack)
    if head_key in head_aliases:
        return _canonical_known_slug(head_aliases[head_key], effective)
    for alias, slug in sorted(head_aliases.items(), key=lambda item: len(item[0]), reverse=True):
        if head_key == alias or head_key.startswith(f"{alias} "):
            return _canonical_known_slug(slug, effective)
    lower = head_clean.lower()
    for slug, display in sorted(effective.items(), key=lambda item: len(item[1]), reverse=True):
        disp = display.lower()
        if lower == disp or lower.startswith(f"{disp} ") or disp.startswith(lower):
            return _canonical_known_slug(slug, effective)
    slug = _normalize_slug(head_clean, effective, pack)
    if slug:
        return _canonical_known_slug(slug, effective)
    slugs = _extract_slugs_from_text(head_clean, effective, pack)
    if slugs:
        return _canonical_known_slug(slugs[0], effective)
    compact = _slugify(head_clean)
    if compact and not re.search(r"\s", head_clean):
        return _canonical_known_slug(compact, effective)
    return None


_ABSENCE_MARKER = re.compile(
    r"\b(?:no|zero|without|lacks?|lacking|missing)\s+(?:\w+\s+){0,2}(?:evidence|claims?)\b(?!\s+gaps?)"
    r"|\bunresearched\b|\bnot\s+(?:yet\s+)?researched\b",
    re.IGNORECASE,
)


def _mask_feature_words_in_vendor_names(text: str) -> str:
    """Blank the vendor names that contain a feature phrase ("Barkain Workflow Orchestrator").

    The words of a product's name say nothing about what the other products in the claim do.
    """
    names = sorted(
        {
            name
            for display in _known_or_run(None).values()
            if (name := display.lower()) and (_features_in_text(name) or any(p.search(name) for p, _ in _PROSE_POSITIVE_SIGNALS))
        },
        key=len,
        reverse=True,
    )
    if not names:
        return text
    pattern = re.compile(r"(?<![a-z0-9])(?:" + "|".join(re.escape(n) for n in names) + r")(?![a-z0-9])", re.IGNORECASE)
    return pattern.sub(lambda m: " " * len(m.group(0)), text)


def _infer_features_from_solution_prose(
    support: dict[str, dict[str, bool | None]],
    slug: str,
    body: str,
) -> None:
    body = _mask_feature_words_in_vendor_names(body)
    if re.search(r"lifecycle_span\s*=", body, re.IGNORECASE):
        for criterion, features in _INCLUSION_CRITERION_FEATURES.items():
            match = re.search(
                rf"{criterion}\s*=\s*(?P<val>yes|no|partial|true|false)",
                body,
                re.IGNORECASE,
            )
            if not match:
                continue
            val = match.group("val").lower()
            positive = val in {"yes", "true"}
            partial = val == "partial"
            for feature in features:
                if positive:
                    _assign_support(support, slug, feature, True)
                elif not partial:
                    _assign_support(support, slug, feature, False)
        return

    for pattern, features in _PROSE_POSITIVE_SIGNALS:
        if pattern.search(body):
            for feature in features:
                _assign_support(support, slug, feature, True)

    for feature in _features_in_text(body):
        _assign_support(support, slug, feature, True)


def _parse_solution_led_matrix_entry(
    support: dict[str, dict[str, bool | None]],
    head: str,
    body: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    if not _matrix_entry_head_is_solution(head, known, pack):
        return False
    slug = _resolve_solution_slug(head, known, pack)
    if not slug:
        return False
    _infer_features_from_solution_prose(support, slug, body)
    return True


class _VoteMap(dict):
    """Per-vendor feature cells that remember who said yes and who said no.

    One claim is one voter (however many parsers read it); inside a single claim a
    negation beats a positive. The cell value is the majority outcome over voters and a
    tie is not a tick, so a single positive mention can neither silence contrary claims
    nor depend on the order the claims arrive in.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None:
        super().__init__(*args, **kwargs)
        self.votes: dict[str, dict[Any, bool]] = {}


_VOTER: list[Any] = [None]


def _assign_rubric(
    support: dict[str, dict[str, bool | None]],
    slug: str,
    feature: str,
    value: bool,
) -> None:
    """Assign a feature named by a built-in prose heuristic, only when the active rubric has it."""
    if feature in _all_template_features():
        _assign_support(support, slug, feature, value)


def _assign_support(
    support: dict[str, dict[str, bool | None]],
    slug: str,
    feature: str,
    value: bool,
) -> None:
    cell = support.get(slug)
    if not isinstance(cell, _VoteMap):
        cell = _VoteMap(cell or {})
        support[slug] = cell
    voter = _VOTER[0]
    if voter is None:
        voter = ("anonymous", len(cell.votes.get(feature, {})))
    ballots = cell.votes.setdefault(feature, {})
    ballots[voter] = ballots.get(voter, True) and value if voter in ballots else value
    yes = sum(1 for v in ballots.values() if v)
    cell[feature] = yes > len(ballots) - yes


def _extract_slugs_from_list(
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> list[str]:
    effective = _known_or_run(known)
    head_aliases = _head_aliases(pack)
    found: list[str] = []
    cleaned = re.sub(r"\([^)]*\)", " ", text)
    cleaned = re.sub(
        r"\b(?:only|among|evaluated|set|peers|weaker|etc\.?|commercial peers)\b.*$",
        "",
        cleaned,
        flags=re.IGNORECASE,
    )
    for token in re.split(r"[,;/]", cleaned):
        token = re.sub(
            r"\b(pass|fail|scores?|✔|✓|✖|✗|true|yes|no|not|and|partially)\b",
            "",
            token,
            flags=re.IGNORECASE,
        ).strip()
        if not token:
            continue
        token_key = token.lower()
        if token_key in head_aliases:
            slug = head_aliases[token_key]
        else:
            slug = _normalize_slug(token, effective, pack)
        if slug in effective and slug not in found:  # exact: a list item is a known vendor or nothing
            found.append(slug)
    for slug in _extract_slugs_from_text(cleaned, effective, pack):
        if slug not in found:
            found.append(slug)
    return found


def _parse_checkmark_body(
    body: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> tuple[list[str], list[str]]:
    positive: list[str] = []
    negative: list[str] = []
    for section in re.split(r"\s*;\s*", body.strip()):
        section = section.strip()
        if not section:
            continue
        neg_match = re.match(r"[✖✗]\s*(.+)", section)
        if neg_match:
            negative.extend(_extract_slugs_from_list(neg_match.group(1), known=known, pack=pack))
            continue
        pos_match = re.match(r"[✔✓]\s*(.+)", section)
        if pos_match:
            pos_body = pos_match.group(1)
            only_match = re.search(r"^(.+?)\s+only\b", pos_body, re.IGNORECASE)
            chunk = only_match.group(1) if only_match else pos_body
            positive.extend(_extract_slugs_from_list(chunk, known=known, pack=pack))
            continue
        if re.search(r"[✖✗]", section):
            negative.extend(_extract_slugs_from_list(section, known=known, pack=pack))
        elif re.search(r"[✔✓]", section):
            positive.extend(_extract_slugs_from_list(section, known=known, pack=pack))
    return positive, negative


def _split_solution_lists(
    body: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> tuple[list[str], list[str]]:
    effective = _known_or_run(known)
    positive: list[str] = []
    negative: list[str] = []
    if re.search(r"[✔✓✖✗]", body):
        return _parse_checkmark_body(body, known=effective, pack=pack)

    parts = re.split(
        r"\b(?:but|while|whereas|;\s*(?=[a-z][a-z0-9-]*\s+do(?:es)?\s+not))\b",
        body,
        flags=re.IGNORECASE,
    )
    pos_text = parts[0]
    neg_text = parts[1] if len(parts) > 1 else ""

    for token in re.split(r"[,;]", pos_text):
        token = re.sub(r"\b(pass|fail|scores?|✔|✓|true|yes)\b", "", token, flags=re.IGNORECASE)
        slug = _normalize_slug(token, effective, pack)
        if slug in effective:
            positive.append(slug)

    for match in _SLUG_NEGATION_RE.finditer(neg_text or body):
        slug = _normalize_slug(match.group("slug"), effective, pack)
        if slug in effective:
            negative.append(slug)
    for token in re.split(r"[,;]", neg_text):
        if not re.search(r"\bdo(?:es)?\s+not\b", token, re.IGNORECASE):
            continue
        slug = _normalize_slug(
            re.sub(r"\bdo(?:es)?\s+not\b.*", "", token, flags=re.IGNORECASE),
            effective,
            pack,
        )
        if slug in effective:
            negative.append(slug)
    return positive, negative


def _apply_matrix_row(
    support: dict[str, dict[str, bool | None]],
    feature_text: str,
    body: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> None:
    features = _resolve_features(feature_text)
    positive, negative = _split_solution_lists(body, known=known, pack=pack)
    for feature in features:
        for slug in positive:
            _assign_support(support, slug, feature, True)
        for slug in negative:
            _assign_support(support, slug, feature, False)


def _features_in_text(text: str) -> list[str]:
    lower = text.lower()
    matched: list[str] = []
    for feature in _all_template_features():
        if feature.lower() in lower and feature not in matched:
            matched.append(feature)
    for alias, feature in _FEATURE_ALIASES.items():
        if alias in lower and feature not in matched:
            matched.append(feature)
    return matched


def _primary_slug_in_text(text: str) -> str | None:
    slugs = _extract_slugs_from_text(text)
    return slugs[0] if slugs else None


def _parse_comparative_claims(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    lower = text.lower()
    for slug in _extract_slugs_from_text(text):
        slug_pat = re.escape(slug.replace("-", "[ -]"))
        for match in re.finditer(rf"\b{slug_pat}\b\s+lacks?\s+([^.;]+)", lower):
            for feature in _features_in_text(match.group(1)):
                _assign_support(support, slug, feature, False)

    offer_match = re.search(
        r"\bwhile\s+(.+?)\s+offer(?:s)?\s+(.+?)(?:\.|;|$)",
        text,
        re.IGNORECASE,
    )
    if offer_match:
        for slug in _extract_slugs_from_text(offer_match.group(1)):
            for feature in _features_in_text(offer_match.group(2)):
                _assign_support(support, slug, feature, True)


_NEGATION_CUE_RE = re.compile(
    r"\b(?:lacks?|lacking|without|does\s+not|doesn['’]t|do\s+not|don['’]t|has\s+no|have\s+no|"
    r"no|not|never|cannot|can['’]t|fails?\s+to|scores?\s+poorly|trail(?:s)?)\b",
    re.IGNORECASE,
)
_POSITIVE_CUE_RE = re.compile(r"\b(?:offers?|provides?|supports?|includes?|covers?)\b", re.IGNORECASE)
_CLAUSE_SPLIT_RE = re.compile(
    r"(?P<hard>[.;]\s+|\s*,?\s*\b(?:while|whereas|unlike)\b)|(?P<soft>\s*,?\s*\bbut\b\s*)",
    re.IGNORECASE,
)


_OTHER_SUBJECT_RE = re.compile(
    r"\b(?:that|which|because|since|others?|competitors?|alternatives?|vendors?|they)\b",
    re.IGNORECASE,
)


def _negation_is_own(prefix: str) -> bool:
    """False when the words before a negation cue introduce a different subject."""
    return not _OTHER_SUBJECT_RE.search(prefix)


def _split_clauses(text: str) -> list[tuple[str, bool]]:
    """Split a sentence into clauses; the flag says the clause continues the previous subject.

    "A offers X but lacks Y" continues the subject ("but"); "A lacks X, while B provides Y"
    starts a new subject, so B is never judged by what was said about A.
    """
    out: list[tuple[str, bool]] = []
    pos = 0
    inherit = False
    for match in _CLAUSE_SPLIT_RE.finditer(text):
        out.append((text[pos: match.start()], inherit))
        inherit = bool(match.group("soft"))
        pos = match.end()
    out.append((text[pos:], inherit))
    return [(c, i) for c, i in out if c.strip()]


def _parse_prose_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    slug = _primary_slug_in_text(text)
    if not slug:
        return

    check_match = re.search(
        r"[✔✓].*?(?:rows?|features?):\s*(.+?)(?:\.|$)",
        text,
        re.IGNORECASE,
    )
    if check_match:
        for feature in _features_in_text(check_match.group(1)):
            _assign_support(support, slug, feature, True)

    previous: str | None = None
    for clause, inherit in _split_clauses(text):
        clause_slug = _primary_slug_in_text(clause) or (previous if inherit else None)
        previous = clause_slug
        if not clause_slug:
            continue
        negation = _NEGATION_CUE_RE.search(clause)
        positive_part = clause[: negation.start()] if negation else clause
        negative_part = clause[negation.end():] if negation else ""
        if _POSITIVE_CUE_RE.search(positive_part):
            for feature in _features_in_text(positive_part):
                _assign_support(support, clause_slug, feature, True)
        if negation and not _negation_is_own(clause[: negation.start()]):
            continue
        for feature in _features_in_text(negative_part):
            _assign_support(support, clause_slug, feature, False)


def _parse_checkmark_for_claims(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    match = _CHECKMARK_FOR_RE.search(text)
    if not match:
        return False
    _apply_matrix_row(
        support,
        match.group("feature"),
        match.group("body"),
        known=known,
        pack=pack,
    )
    return True


def _parse_matrix_dash_claims(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    match = _MATRIX_DASH_RE.search(text)
    if not match:
        return False
    _apply_matrix_row(
        support,
        match.group("feature"),
        match.group("body"),
        known=known,
        pack=pack,
    )
    return True


def _parse_must_have_satisfaction(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"satisfying all three matrix must-haves", text, re.IGNORECASE):
        return
    slug = _primary_slug_in_text(text)
    if not slug:
        return
    for feature in (
        "Workflow composition",
        "Parent/child agent delegation",
        "Hook-enforced gates",
    ):
        _assign_rubric(support, slug, feature, True)  # only where the run's rubric has the feature
    if re.search(r"\bci\b|ci execution|ci integration", text, re.IGNORECASE):
        _assign_rubric(support, slug, "CI integration", True)


def _parse_has_checkmark_features(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    for match in re.finditer(
        r"has\s+[✔✓]\s*([^.;]+)|[✔✓]\s*((?:Atomic|Workflow|Hook)[^.;]{0,60})",
        text,
        re.IGNORECASE,
    ):
        fragment = match.group(1) or match.group(2) or ""
        slug = _primary_slug_in_text(text[: match.start() + 40])
        if not slug:
            slug = _primary_slug_in_text(text)
        if not slug:
            continue
        for feature in _features_in_text(fragment):
            _assign_support(support, slug, feature, True)

    for match in re.finditer(
        r"([a-z][a-z0-9-]*)\s+also\s+[✔✓]\s*(?:\(([^)]+)\))?",
        text,
        re.IGNORECASE,
    ):
        slug = _normalize_slug(match.group(1))
        if not slug:
            continue
        hint = match.group(2) or text[match.end() : match.end() + 80]
        for feature in _features_in_text(hint):
            _assign_support(support, slug, feature, True)


def _parse_solution_lead_negative(
    support: dict[str, dict[str, bool | None]],
    text: str,
    known: dict[str, str] | None = None,
) -> None:
    lower = text.lower()
    for slug, display in _known_or_run(known).items():
        patterns = (
            rf"^{re.escape(display.lower())}\b",
            rf"^{re.escape(slug.replace('-', ' '))}\b",
            rf"^{re.escape(slug)}\b",
        )
        if not any(re.search(pat, lower) for pat in patterns):
            continue
        if re.search(
            r"\bno\s+(?:workflow\s+)?catalog\b|\bwithout\b.{0,40}\bcatalog\b",
            lower,
        ):
            _assign_rubric(support, slug, "Atomic flow catalog", False)
            _assign_rubric(support, slug, "Workflow composition", False)
        if re.search(r"hook[- ]enforced|hook enforcement|ide hook", lower):
            if re.search(r"\bno\b|\blacks?\b|\bwithout\b", lower):
                _assign_rubric(support, slug, "Hook-enforced gates", False)
        if re.search(r"\bpartial composition\b", lower):
            _assign_rubric(support, slug, "Workflow composition", True)
        if re.search(r"\bno catalog or\b", lower):
            _assign_rubric(support, slug, "Atomic flow catalog", False)
        if re.search(r"\bopen[- ]source\b|\boss\b", lower):
            _assign_rubric(support, slug, "Free tier / OSS core", True)
        if re.search(r"\bverification[- ]gate\b|\bverification gate\b", lower):
            if re.search(r"\bno\b|\blacks?\b|\blimited\b|\bwithout\b", lower):
                _assign_rubric(support, slug, "Hook-enforced gates", False)
        if re.search(r"\blimited multi-agent\b", lower):
            _assign_rubric(support, slug, "Parent/child agent delegation", False)
        if re.search(r"\bci/?cd\b|\bci integration\b", lower):
            _assign_rubric(support, slug, "CI integration", True)
        if re.search(r"multi-agent workflows?\b", lower) and not re.search(
            r"\bno\b.{0,20}multi-agent",
            lower,
        ):
            _assign_rubric(support, slug, "Parent/child agent delegation", True)
        break


def _parse_managed_hosting_offer(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"offer managed hosting", text, re.IGNORECASE):
        return
    # Only the clause that follows "offer managed hosting" credits vendors; a vendor named
    # in a contrasting "while ..." clause before it is not credited.
    offer = re.search(r"offer managed hosting", text, re.IGNORECASE)
    subject_text = text[: offer.start()]
    contrast = list(re.finditer(r"\b(?:while|whereas|unlike)\b", subject_text, re.IGNORECASE))
    if contrast:
        subject_text = subject_text[contrast[-1].end():]
        if "," in subject_text:  # "While X is local, Y and Z offer ...": X is the contrasted clause
            subject_text = subject_text.split(",", 1)[1]
    for slug in _extract_slugs_from_text(subject_text):
        _assign_rubric(support, slug, "Managed hosting", True)
        if re.search(r"managed hosting paths?", text, re.IGNORECASE):
            _assign_rubric(support, slug, "Zero-infra bootstrap", True)


def _parse_template_ttv(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"time-to-value through templates|managed triggers", text, re.IGNORECASE):
        return
    slug = _primary_slug_in_text(text)
    if slug:
        _assign_rubric(support, slug, "Prebuilt SDLC templates", True)


def _parse_autonomous_ship_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"plans?, writes?, tests?, and ships", text, re.IGNORECASE):
        return
    slug = _primary_slug_in_text(text)
    if not slug:
        return
    _assign_rubric(support, slug, "Managed hosting", True)
    _assign_rubric(support, slug, "CI integration", True)
    _assign_rubric(support, slug, "Zero-infra bootstrap", True)


def _parse_strong_composition_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
) -> None:
    if not re.search(r"strong git-native composition|strong BYO composition", text, re.IGNORECASE):
        return
    slug = _primary_slug_in_text(text)
    if slug:
        _assign_rubric(support, slug, "Workflow composition", True)


def _parse_inclusion_criteria_scoped_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> None:
    if not _INCLUSION_CRITERIA_SIGNAL_RE.search(text):
        return
    effective = _known_or_run(known)
    if _ALL_SEVEN_INCLUSION_RE.search(text):
        for slug in _extract_slugs_from_text(text, effective, pack):
            for feature in _default_inclusion_features():
                _assign_support(support, slug, feature, True)
        return
    for match in _PAREN_CRITERION_SLUGS_RE.finditer(text):
        slugs = _extract_slugs_from_list(match.group("list"), known=effective, pack=pack)
        if not slugs:
            continue
        features = _features_for_inclusion_mentions(match.group("phrase")) or _features_in_text(
            match.group("phrase")
        )
        for slug in slugs:
            for feature in features:
                _assign_support(support, slug, feature, True)
    for slug in _extract_slugs_from_text(text, effective, pack):
        _infer_features_from_solution_prose(support, slug, text)


def _apply_slug_scoped_prose(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> None:
    if _ABSENCE_MARKER.search(text):
        return  # a claim that says nothing was found is not a vote for any feature
    _parse_comparative_claims(support, text)
    _parse_prose_claim(support, text)
    _parse_must_have_satisfaction(support, text)
    _parse_has_checkmark_features(support, text)
    _parse_solution_lead_negative(support, text, known)
    _parse_managed_hosting_offer(support, text)
    _parse_template_ttv(support, text)
    _parse_autonomous_ship_claim(support, text)
    _parse_strong_composition_claim(support, text)
    _parse_inclusion_criteria_scoped_claim(support, text, known=known, pack=pack)
    lower = text.lower()
    for slug in _extract_slugs_from_text(text):
        slug_pat = re.escape(slug.replace("-", "[ -]"))
        slug_region = re.search(rf"\b{slug_pat}\b", lower)
        if not slug_region:
            continue
        start = slug_region.end()
        window = lower[start: min(len(lower), start + 160)]
        # the window ends where the clause does or where another vendor takes over
        boundary = _CLAUSE_SPLIT_RE.search(window)
        cut = boundary.start() if boundary else len(window)
        for other in _extract_slugs_from_text(text):
            if other == slug:
                continue
            other_pat = re.escape(other.replace("-", "[ -]"))
            hit = re.search(rf"\b{other_pat}\b", window)
            if hit:
                cut = min(cut, hit.start())
        window = window[:cut]
        negation = _NEGATION_CUE_RE.search(window)
        for feature in _features_in_text(window):
            position = window.find(feature.lower())
            if negation and position >= negation.start():
                # the cue must belong to this vendor, not to another subject introduced between
                if _negation_is_own(window[: negation.start()]):
                    _assign_support(support, slug, feature, False)
                continue
            if re.search(
                r"(?:\bsupports?\b|\bprovides?\b|\boffers?\b|\bpass\b|✔|✓|\byes\b|\bstrong\b|\bincludes?\b|\bcovers?\b|\bsatisfying\b|\bcompos)",
                window[: negation.start()] if negation else window,
            ):
                _assign_support(support, slug, feature, True)


def _features_for_inclusion_mentions(text: str) -> list[str]:
    lower = text.lower()
    features: list[str] = []
    for keyword, criterion_id in _CRITERION_KEYWORD_TO_ID.items():
        if keyword not in lower:
            continue
        for feature in _INCLUSION_CRITERION_FEATURES[criterion_id]:
            if feature not in features:
                features.append(feature)
    return features


def _default_inclusion_features() -> list[str]:
    features: list[str] = []
    for criterion_features in _INCLUSION_CRITERION_FEATURES.values():
        for feature in criterion_features:
            if feature not in features:
                features.append(feature)
    return features


def _extract_bulk_solution_list(text: str) -> str | None:
    list_part: str | None = None
    for pattern in (
        r"for matrix:\s*(.+)$",
        r"should prioritize\s+(.+)$",
        r"core set[^:]*:\s*(.+)$",
        r"matrix leaders are\s+(.+)$",
        r"Commercial-weighted peer:\s*(.+)$",
    ):
        match = re.search(pattern, text, re.IGNORECASE)
        if match:
            list_part = match.group(1)
            break
    if list_part is None and re.search(r"\bare\b", text, re.IGNORECASE):
        list_part = re.split(r"\bare\b", text, maxsplit=1, flags=re.IGNORECASE)[1]
    if not list_part:
        return None
    list_part = re.split(
        r"\s*(?:—|–|-)\s*(?:comfortably|once|then|filter|Commercial|Generic|with host|excluded)",
        list_part,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    list_part = re.split(
        r"\s*;\s*(?:Generic|Commercial|then\b)",
        list_part,
        maxsplit=1,
        flags=re.IGNORECASE,
    )[0]
    return list_part.strip(" .")


def _parse_core_set_bulk_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    if not _CORE_SET_CLAIM_RE.search(text):
        return False
    list_part = _extract_bulk_solution_list(text)
    if not list_part:
        return False
    slugs = _extract_slugs_from_list(list_part, known=known, pack=pack)
    if not slugs:
        return False
    features = _features_for_inclusion_mentions(text)
    if not features:
        features = _default_inclusion_features()
    if re.search(r"startup[- ]weighted", text, re.IGNORECASE):
        features.extend(("Quick onboarding", "Zero-infra bootstrap"))
    for slug in slugs:
        for feature in features:
            _assign_support(support, slug, feature, True)
    return True


def _parse_matrix_leaders_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    if not _MATRIX_LEADERS_RE.search(text):
        return False
    list_part = _extract_bulk_solution_list(text)
    if not list_part:
        return False
    slugs = _extract_slugs_from_list(list_part, known=known, pack=pack)
    if not slugs:
        return False
    features = _features_for_inclusion_mentions(text) or [
        "Workflow composition",
        "IDE-native integration",
        "Parent/child agent delegation",
    ]
    for slug in slugs:
        for feature in features:
            _assign_support(support, slug, feature, True)
        _infer_features_from_solution_prose(support, slug, text)
    return True


def _parse_host_runtime_substrate_claim(
    support: dict[str, dict[str, bool | None]],
    text: str,
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> bool:
    if not re.search(r"host runtime|substrate row|exclusion class host_runtime", text, re.IGNORECASE):
        return False
    effective = _known_or_run(known)
    host_slugs = {
        slug
        for slug in _extract_slugs_from_text(text, effective, pack)
        if slug in HOST_RUNTIME_SLUGS
    }
    if not host_slugs:
        return False
    for slug in host_slugs:
        _assign_rubric(support, slug, "IDE-native integration", True)
    return True


def _feature_key(raw: Any) -> str:
    """Folding key for feature names (see category_pack.feature_key)."""
    return feature_key(raw)


def _feature_name(raw: Any) -> str | None:
    """Rubric feature for a worker-supplied name (rubric/alias spelling if known, else the
    worker's wording with spacing normalised); None for blank/oversized names."""
    spaced = " ".join(str(raw or "").split())
    if not _feature_key(spaced) or len(spaced) > 80:
        return None
    key = _feature_key(spaced)
    for feature in _all_template_features():
        if _feature_key(feature) == key:
            return feature
    for alias, feature in _FEATURE_ALIASES.items():
        if _feature_key(alias) == key:
            return feature
    return spaced


def _vendor_key(name: Any) -> str:
    return re.sub(r"[^a-z0-9]+", " ", str(name or "").lower()).strip()


def resolve_structured_vendor(
    name: Any,
    known: dict[str, str],
    pack: dict[str, Any] | None,
) -> str | None:
    """Slug for a worker-named vendor: exact (normalised) match on slug, display name or alias.

    A blank name, or one that is only punctuation, never resolves; a prefix never matches.
    Without a category pack an unknown vendor becomes its own open-world slug (it is
    discovered, not attributed to someone else); with a pack unknown vendors are ignored.
    """
    key = _vendor_key(name)
    if not key or len(key) > 80:
        return None
    for slug, display in known.items():
        if key in {_vendor_key(slug), _vendor_key(display)}:
            return slug
    for aliases in (_slug_aliases(pack), _head_aliases(pack)):
        for alias, slug in aliases.items():
            if _vendor_key(alias) == key:
                return slug
    if pack:
        return None
    return _slugify(str(name)) or None


def structured_vendor_names(
    envelopes: list[dict[str, Any]],
    known: dict[str, str],
    pack: dict[str, Any] | None,
) -> dict[str, tuple[str, int]]:
    """slug -> (display, rows) for vendors workers named in ``matrix_entries`` (first spelling wins)."""
    found: dict[str, tuple[str, int]] = {}
    for env in envelopes:
        payload = env.get("payload") if isinstance(env, dict) else None
        rows = payload.get("matrix_entries") if isinstance(payload, dict) else None
        for row in rows if isinstance(rows, list) else []:
            name = row.get("vendor") if isinstance(row, dict) else None
            slug = resolve_structured_vendor(name, known, pack)
            if slug:
                shown = known.get(slug) or " ".join(str(name).split())
                found[slug] = (found[slug][0] if slug in found else shown, found.get(slug, ("", 0))[1] + 1)
    return found


def parse_structured_matrix_entries(
    envelopes: list[dict[str, Any]],
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
    preferred_features: list[str] | None = None,
) -> dict[str, dict[str, bool | None]]:
    """Votes from workers' ``matrix_entries`` rows: {vendor, feature, supported, source_ref}.

    Each model casts one vote per (vendor, feature); when it repeats a row in a later phase the
    later row wins. ``supported`` must be a boolean ("yes"/"no"/"true"/"false" strings are
    accepted, anything else is ignored). A row whose vendor does not resolve (see
    resolve_structured_vendor) or whose feature is blank is skipped. This is the primary source
    for matrix ticks; prose parsing only fills cells no worker voted on.
    """
    effective = _known_or_run(known)
    latest: dict[str, dict[tuple[str, str], bool]] = {}
    spellings: dict[str, dict[str, int]] = {}  # folding key -> spelling -> count
    for env_index, env in enumerate(envelopes):
        payload = env.get("payload") if isinstance(env, dict) else None
        rows = payload.get("matrix_entries") if isinstance(payload, dict) else None
        if not isinstance(rows, list):
            continue
        model = str(env.get("logical_model_id") or env_index)
        for row in rows:
            if not isinstance(row, dict):
                continue
            slug = resolve_structured_vendor(row.get("vendor"), effective, pack)
            feature = _feature_name(row.get("feature"))
            verdict = row.get("supported")
            if isinstance(verdict, str):
                verdict = {"yes": True, "true": True, "no": False, "false": False}.get(verdict.strip().lower())
            if slug and feature and isinstance(verdict, bool):
                key = _feature_key(feature)
                spellings.setdefault(key, {})
                spellings[key][feature] = spellings[key].get(feature, 0) + 1
                latest.setdefault(model, {})[(slug, key)] = verdict
    # One rubric row per folded key, shown with its most common spelling (first seen on a tie),
    # so models that differ only in casing/punctuation vote on the same cell.
    shown = {key: max(counts, key=lambda s: (counts[s], -list(counts).index(s))) for key, counts in spellings.items()}
    for wanted in preferred_features or []:
        if _feature_key(wanted) in shown:
            shown[_feature_key(wanted)] = str(wanted).strip()
    support: dict[str, dict[str, bool | None]] = {}
    try:
        for model, cells in latest.items():
            _VOTER[0] = ("structured", model)
            for (slug, key), verdict in cells.items():
                _assign_support(support, slug, shown[key], verdict)
    finally:
        _VOTER[0] = None
    return support


def open_world_known(
    envelopes: list[dict[str, Any]],
    need: dict[str, Any] | None,
) -> dict[str, str]:
    """Display names for a run: pack names, plus (without a pack) the vendors workers named."""
    known = _effective_known_solutions(need)
    pack = resolve_pack_from_need(need)
    if not pack:
        for slug, (display, _rows) in structured_vendor_names(envelopes, known, pack).items():
            known.setdefault(slug, display)
    return known


MIN_DERIVED_PRIORITIES = 2
DERIVED_REASON = "no must-have matched the matrix, so the most-evidenced features that separate vendors were treated as Critical"


def derive_critical_features(
    need: dict[str, Any],
    support: dict[str, dict[str, bool | None]],
    limit: int = 5,
) -> dict[str, str]:
    """{feature: "Critical"} for the most-evidenced features when the need names no usable must-have.

    The comparator ranks by priority and the content gate needs Critical rows; a run whose
    profile has no must-haves (an auto profile, or wording that matches no matrix feature) would
    otherwise fail after every model call was spent. Only features that tell vendors apart count
    (ticked for some but not all), and at least MIN_DERIVED_PRIORITIES of them are needed: a
    matrix with nothing to discriminate on gets no invented priorities and fails the gate.
    Returns {} when must-haves match or the user set a weights_override of their own. The result
    is recomputed on every packaging and never written into the user's need profile.
    """
    if need.get("weights_override") and not need.get("weights_override_derived"):
        return {}  # (a flagged override is a derived one an earlier version saved into the profile)
    declared = {_feature_key(x) for x in need.get("must_haves") or []}
    ticks: dict[str, int] = {}
    for cells in support.values():
        for feature, ok in cells.items():
            ticks[feature] = ticks.get(feature, 0) + (1 if ok else 0)
    if declared & {_feature_key(f) for f in ticks}:
        return {}
    ranked = sorted((f for f, n in ticks.items() if 0 < n < len(support)), key=lambda f: (-ticks[f], f))
    derived = {feature: "Critical" for feature in ranked[:limit]}
    return derived if len(derived) >= MIN_DERIVED_PRIORITIES else {}


def disputed_cells(support: dict[str, dict[str, bool | None]]) -> list[dict[str, Any]]:
    """Cells where voters disagreed: [{vendor, feature, yes, no}] sorted for stable output."""
    out: list[dict[str, Any]] = []
    for slug, cells in support.items():
        votes = getattr(cells, "votes", {})
        for feature, ballots in votes.items():
            yes = sum(1 for v in ballots.values() if v)
            no = len(ballots) - yes
            if yes and no:
                out.append({"vendor": slug, "feature": feature, "yes": yes, "no": no})
    return sorted(out, key=lambda c: (c["vendor"], c["feature"]))


def parse_feature_support(
    envelopes: list[dict[str, Any]],
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
    preferred_features: list[str] | None = None,
) -> dict[str, dict[str, bool | None]]:
    """Matrix cells: structured worker votes first, prose heuristics only for unvoted cells.

    `preferred_features` (the user's must-haves / nice-to-haves) fixes the spelling of a folded
    feature name, so the comparator's priority matching finds the row.
    """
    with activated(pack):
        return _parse_feature_support(envelopes, known=known, pack=pack, preferred_features=preferred_features)


def _parse_feature_support(
    envelopes: list[dict[str, Any]],
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
    preferred_features: list[str] | None = None,
) -> dict[str, dict[str, bool | None]]:
    structured = parse_structured_matrix_entries(
        envelopes, known=known, pack=pack, preferred_features=preferred_features
    )
    prose = _parse_prose_feature_support(envelopes, known=known, pack=pack)
    return _merge_folded(structured, prose, preferred_features)


def _merge_folded(
    structured: dict[str, dict[str, bool | None]],
    prose: dict[str, dict[str, bool | None]],
    preferred_features: list[str] | None,
) -> dict[str, dict[str, bool | None]]:
    """One cell per (vendor, folded feature): a cell any worker voted on is decided by those
    structured votes alone, otherwise by the prose votes.

    Every spelling of a feature (rubric, claim prose, worker rows, the user's must-have) folds to
    one key and is shown once: the rubric spelling, unless the user wrote the must-have differently
    (the comparator matches priorities on that wording), else the most common spelling.
    """
    template = {_feature_key(f): f for f in _all_template_features()}
    wanted = {_feature_key(f): str(f).strip() for f in preferred_features or []}
    spellings: dict[str, dict[str, int]] = {}
    for source in (prose, structured):
        for cells in source.values():
            for feature in cells:
                counts = spellings.setdefault(_feature_key(feature) or feature, {})
                counts[feature] = counts.get(feature, 0) + max(1, len(getattr(cells, "votes", {}).get(feature, {})))

    def shown(key: str) -> str:
        rubric, user = template.get(key), wanted.get(key)
        if rubric and (not user or rubric.lower().strip() == user.lower().strip()):
            return rubric
        counts = spellings[key]
        return user or rubric or max(counts, key=lambda spelling: (counts[spelling], -list(counts).index(spelling)))

    merged: dict[str, dict[str, bool | None]] = {}
    for slug in dict.fromkeys([*prose, *structured]):
        ballots: dict[str, dict[str, dict[Any, bool]]] = {}  # folded key -> source -> voter -> verdict
        for label, source in (("prose", prose), ("structured", structured)):
            cells = source.get(slug) or {}
            for feature in cells:
                key = _feature_key(feature) or feature
                by_voter = ballots.setdefault(key, {}).setdefault(label, {})
                for voter, verdict in getattr(cells, "votes", {}).get(feature, {}).items():
                    by_voter[voter] = by_voter[voter] and verdict if voter in by_voter else verdict
        cell = _VoteMap()
        for key, by_source in ballots.items():
            chosen = by_source.get("structured") or by_source["prose"]
            name = shown(key)
            cell.votes[name] = chosen
            yes = sum(1 for verdict in chosen.values() if verdict)
            cell[name] = yes > len(chosen) - yes
        merged[slug] = cell
    return merged


def _parse_prose_feature_support(
    envelopes: list[dict[str, Any]],
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> dict[str, dict[str, bool | None]]:
    """Prose heuristics, resolving vendors from this run's `known` set and pack."""
    with run_context(known, pack):
        return _parse_prose_unscoped(envelopes, known=known, pack=pack)


def _parse_prose_unscoped(
    envelopes: list[dict[str, Any]],
    *,
    known: dict[str, str] | None = None,
    pack: dict[str, Any] | None = None,
) -> dict[str, dict[str, bool | None]]:
    effective = _known_or_run(known)
    support: dict[str, dict[str, bool | None]] = {}
    for voter, text in enumerate(_iter_claim_texts(envelopes)):
        _VOTER[0] = voter
        if _parse_core_set_bulk_claim(support, text, known=effective, pack=pack):
            continue
        if _parse_matrix_leaders_claim(support, text, known=effective, pack=pack):
            continue
        if _parse_host_runtime_substrate_claim(support, text, known=effective, pack=pack):
            continue
        if _parse_matrix_dash_claims(support, text, known=effective, pack=pack):
            continue
        if _parse_checkmark_for_claims(support, text, known=effective, pack=pack):
            continue

        entry_match = _MATRIX_ENTRY_RE.search(text)
        if entry_match:
            head = entry_match.group("feature").strip()
            body = entry_match.group("body").strip()
            if _parse_solution_led_matrix_entry(support, head, body, known=effective, pack=pack):
                continue
            _apply_matrix_row(support, head, body, known=effective, pack=pack)
            continue

        match = _MATRIX_ROW_RE.search(text)
        if match:
            _apply_matrix_row(
                support,
                match.group("feature"),
                match.group("body"),
                known=effective,
                pack=pack,
            )
            continue

        if "matrix entry" in text.lower():
            continue
        _apply_slug_scoped_prose(support, text, known=effective, pack=pack)
    _VOTER[0] = None
    return support


def _group_features_into_categories(feature_names: list[str]) -> list[dict[str, Any]]:
    template_index: dict[str, str] = {}
    for cat in FEATURE_TEMPLATE:
        for feat in cat["features"]:
            template_index[str(feat)] = str(cat["name"])
    grouped: dict[str, list[str]] = {}
    order: list[str] = []
    for name in feature_names:
        cat = template_index.get(name) or "Run-synthesized"
        if cat not in grouped:
            grouped[cat] = []
            order.append(cat)
        if name not in grouped[cat]:
            grouped[cat].append(name)
    return [{"name": cat, "features": grouped[cat]} for cat in order]


def synthesize_feature_rubric(
    *,
    comparison: dict[str, Any] | None = None,
    support: dict[str, dict[str, bool | None]] | None = None,
) -> dict[str, Any]:
    """Build the run-level rubric from comparison rows or discovered support.

    Do not stamp the canned FEATURE_TEMPLATE when the run already produced a rubric.
    """
    grouped: dict[str, list[str]] = {}
    cat_order: list[str] = []
    current_cat = "Capabilities"
    if comparison:
        for row in comparison.get("rows") or []:
            if not isinstance(row, dict):
                continue
            if row.get("type") == "category":
                current_cat = str(row.get("name") or "Capabilities")
                continue
            if row.get("type") != "feature":
                continue
            name = str(row.get("name") or "").strip()
            if not name:
                continue
            if current_cat not in grouped:
                grouped[current_cat] = []
                cat_order.append(current_cat)
            if name not in grouped[current_cat]:
                grouped[current_cat].append(name)
        if cat_order:
            return {
                "source": "comparison.json",
                "categories": [{"name": cat, "features": grouped[cat]} for cat in cat_order],
            }

    names: list[str] = []
    seen: set[str] = set()
    for feats in (support or {}).values():
        if not isinstance(feats, dict):
            continue
        for name in feats:
            label = str(name).strip()
            if label and label not in seen:
                seen.add(label)
                names.append(label)
    if names:
        return {"source": "live-envelopes", "categories": _group_features_into_categories(names)}

    return {
        "source": "fallback-template",
        "categories": [
            {"name": str(cat["name"]), "features": list(cat["features"])}
            for cat in FEATURE_TEMPLATE
        ],
    }


def build_features_json(
    slug: str,
    support: dict[str, dict[str, bool | None]],
    *,
    known: dict[str, str] | None = None,
    comparison: dict[str, Any] | None = None,
    rubric: dict[str, Any] | None = None,
) -> dict[str, Any]:
    effective = _known_or_run(known)
    per_solution = support.get(slug, {})
    spec = rubric or synthesize_feature_rubric(comparison=comparison, support=support)
    categories: list[dict[str, Any]] = []
    for category in spec.get("categories") or []:
        features: list[dict[str, Any]] = []
        for feature in category.get("features") or []:
            name = feature if isinstance(feature, str) else str(feature.get("name") or "")
            if not name:
                continue
            features.append({"name": name, "supported": per_solution.get(name)})
        if features:
            categories.append(
                {"name": str(category.get("name") or "Capabilities"), "features": features}
            )
    return {
        "solution_name": slug,
        "display_name": effective.get(slug, slug),
        "categories": categories,
        "source": spec.get("source") or "live-envelopes",
        "rubric_source": spec.get("source") or "live-envelopes",
    }


def write_run_features_json(
    research_dir: Path,
    *,
    comparison: dict[str, Any] | None = None,
    support: dict[str, dict[str, bool | None]] | None = None,
    known: dict[str, str] | None = None,
    preserved: list[str] | None = None,
) -> dict[str, Any]:
    """Write landscape/features-rubric.json and per-solution features.json from the run rubric.

    Only ranked solutions are written, and a features.json the host or user wrote is kept
    as is (see generated_files); folders that are not ranked solutions are never touched.
    """
    research_dir = Path(research_dir)
    preserved = preserved if preserved is not None else []
    comparison = comparison if isinstance(comparison, dict) else {}
    if not comparison:
        cmp_path = research_dir / "comparison" / "comparison.json"
        if cmp_path.is_file():
            try:
                loaded = json.loads(cmp_path.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                loaded = {}
            if isinstance(loaded, dict):
                comparison = loaded
    rubric = synthesize_feature_rubric(comparison=comparison, support=support)
    write_generated_text(
        research_dir,
        research_dir / "landscape" / "features-rubric.json",
        json.dumps(rubric, indent=2) + "\n",
        preserved=preserved,
    )
    effective = _known_or_run(known)
    slugs: list[str] = []
    for item in comparison.get("rankings") or []:
        if isinstance(item, dict) and item.get("solution") and str(item["solution"]) not in slugs:
            slugs.append(str(item["solution"]))
    written: list[str] = []
    for slug in slugs:
        payload = build_features_json(slug, support or {}, known=effective, rubric=rubric)
        path = research_dir / "solutions" / slug / "features.json"
        if write_generated_text(research_dir, path, json.dumps(payload, indent=2) + "\n", preserved=preserved):
            written.append(str(path.relative_to(research_dir)))
    return {
        "status": "ok",
        "rubric_source": rubric.get("source"),
        "features_written": written,
        "preserved": preserved,
        "rubric_path": "landscape/features-rubric.json",
    }


def _scr_claims_for_slug(
    slug: str, envelopes: list[dict[str, Any]], known: dict[str, str] | None = None
) -> list[str]:
    display = _known_or_run(known).get(slug, slug)
    slug_pat = slug.replace("-", " ")
    claims: list[str] = []
    for text in _iter_claim_texts(envelopes):
        lower = text.lower()
        if slug not in lower and slug_pat not in lower and display.lower() not in lower:
            continue
        if is_unusable_overview_claim(text, focus_name=display, known=known):
            continue
        claims.append(text)
        if len(claims) >= 12:
            break
    return claims


def build_scr_md(
    slug: str,
    envelopes: list[dict[str, Any]],
    known: dict[str, str] | None = None,
    overview_seeds: dict[str, str] | None = None,
) -> str:
    display = _known_or_run(known).get(slug, slug)
    clean_claims = _scr_claims_for_slug(slug, envelopes, known)
    seed = (overview_seeds or OVERVIEW_SEEDS).get(slug, "").strip()
    exec_summary = seed or (
        clean_claims[0]
        if clean_claims
        else f"{display} is a solution identified in this research run."
    )
    lines = [
        f"# Solution Capability Report: {display}",
        "",
        f"Slug: `{slug}`",
        "",
        "## Executive summary",
        "",
        exec_summary,
        "",
        "## Evidence-backed notes",
        "",
    ]
    if clean_claims:
        for text in clean_claims:
            lines.append(f"- {text}")
    elif seed:
        lines.append(f"- {seed}")
    else:
        lines.append("_No direct prose evidence lines matched this solution slug in live envelopes._")
    lines.append("")
    return "\n".join(lines)


@for_research_dir
def materialize_solution_artifacts(
    research_dir: Path,
    *,
    envelopes: list[dict[str, Any]] | None = None,
    shortlist_count: int = 5,
) -> dict[str, Any]:
    research_dir = Path(research_dir)
    need_path = research_dir / "need_profile.json"
    need: dict[str, Any] = {}
    if need_path.is_file():
        need = json.loads(need_path.read_text(encoding="utf-8"))

    if envelopes is None:
        env_path = research_dir / "contributions" / "all-envelopes.json"
        if not env_path.is_file():
            raise FileNotFoundError(f"missing envelopes: {env_path}")
        raw = json.loads(env_path.read_text(encoding="utf-8"))
        if not isinstance(raw, list):
            raise ValueError("all-envelopes.json must be a JSON array")
        envelopes = [item for item in raw if isinstance(item, dict)]

    if not envelopes:
        raise ValueError("no contribution envelopes to materialize from")

    known = open_world_known(envelopes, need)
    pack = resolve_pack_from_need(need)
    preserved: list[str] = []

    def emit(path: Path, text: str) -> bool:
        return write_generated_text(research_dir, path, text, preserved=preserved)

    audit: dict[str, Any] | None = None
    if pack:
        from solution_classifier import classify_solutions, write_catalog_audit

        audit = classify_solutions(envelopes, need, pack)
        write_catalog_audit(research_dir, audit, preserved=preserved)

    slugs = discover_solutions(envelopes, need=need)
    wanted = [str(x) for x in (need.get("must_haves") or []) + (need.get("nice_to_haves") or [])]
    support = parse_feature_support(envelopes, known=known, pack=pack, preferred_features=wanted)
    rubric = synthesize_feature_rubric(support=support)
    shortlist = slugs[:shortlist_count]
    derived = derive_critical_features(need, support)
    # The user's need_profile.json is never rewritten: derived priorities are a per-run file that
    # packaging hands to the comparator and the report discloses (recomputed every run).
    emit(research_dir / "landscape" / "derived-priorities.json",
         json.dumps({"weights_override": derived, "reason": DERIVED_REASON if derived else ""}, indent=2) + "\n")
    disputed = disputed_cells(support)
    emit(research_dir / "landscape" / "disputed-cells.json", json.dumps(disputed, indent=2) + "\n")

    solutions_root = research_dir / "solutions"
    written: list[str] = []
    for slug in slugs:
        features_path = solutions_root / slug / "features.json"
        if emit(features_path, json.dumps(build_features_json(slug, support, known=known, rubric=rubric), indent=2) + "\n"):
            written.append(str(features_path.relative_to(research_dir)))
        emit(solutions_root / slug / "scr.md", build_scr_md(slug, envelopes, known, _effective_overview_seeds(need)))

    # Folders outside this run's solution set (earlier runs, the host's own notes) are
    # reported, never deleted.
    slug_set = set(slugs)
    stale = sorted(
        d.name for d in (solutions_root.iterdir() if solutions_root.is_dir() else []) if d.is_dir() and d.name not in slug_set
    )

    shortlist_payload = {
        "count": len(shortlist),
        "solutions": [
            {
                "rank": i,
                "name": known.get(slug, slug),
                "slug": slug,
                "source": "live-envelopes",
            }
            for i, slug in enumerate(shortlist, start=1)
        ],
    }
    emit(research_dir / "shortlist" / "shortlist.json", json.dumps(shortlist_payload, indent=2) + "\n")

    solutions_index = {
        "count": len(slugs),
        "source": "live-envelopes",
        "solutions": [
            {
                "slug": slug,
                "name": known.get(slug, slug),
                "features_path": f"solutions/{slug}/features.json",
                "scr_path": f"solutions/{slug}/scr.md",
            }
            for slug in slugs
        ],
    }
    emit(research_dir / "solutions.json", json.dumps(solutions_index, indent=2) + "\n")
    emit(research_dir / "landscape" / "features-rubric.json", json.dumps(rubric, indent=2) + "\n")

    result: dict[str, Any] = {
        "status": "ok",
        "solutions_count": len(slugs),
        "disputed_cells": len(disputed),
        "derived_critical_features": sorted(derived),
        "derived_priorities": derived,
        "shortlist_count": len(shortlist),
        "features_written": written,
        "preserved": preserved,
        "stale_solution_dirs": stale,
        "solutions_index": "solutions.json",
        "shortlist": "shortlist/shortlist.json",
    }
    if audit:
        result["catalog_audit"] = "landscape/catalog_audit.json"
        result["core_count"] = len(audit.get("core") or [])
    return result


def main() -> int:
    import argparse

    parser = argparse.ArgumentParser(description="Materialize SCR/features from live DR envelopes")
    parser.add_argument("--dir", required=True, help="Research output directory")
    args = parser.parse_args()
    try:
        result = materialize_solution_artifacts(Path(args.dir))
    except (FileNotFoundError, ValueError) as exc:
        print(json.dumps({"status": "error", "reason": str(exc)}))
        return 1
    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
