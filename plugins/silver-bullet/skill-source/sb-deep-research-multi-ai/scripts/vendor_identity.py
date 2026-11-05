#!/usr/bin/env python3
"""Vendor identity for research claims: which vendors a claim row is about, without guessing from prose.

A vendor whose display name has no DISTINCTIVE token is AMBIGUOUS: its name is also an ordinary word,
phrase or surname ("Director", "Cursor", "Silver Bullet", "Devin"). It is credited only by an explicit
signal (a ``vendors`` tag, a ``source_ref`` that names it, its pack URL, a qualified display such as
"Devin (Cognition)", a whole matrix slot). The words around a name never credit it. A prose spelling that
carries a distinctive token ("GitHub Copilot", "Cc10x", "Factory.ai") counts wherever it appears.

Mechanical and per run: ``build_registry`` reads the run's known vendors and pack; nothing is hand-listed
except GENERIC_TOKENS (never distinctive) and the pack vocabulary COINED_NAMES (invented words).
"""

from __future__ import annotations

import re
from typing import Any
from urllib.parse import urlparse

# Tokens of a display name that say what a product is, not which one: never distinctive.
GENERIC_TOKENS = frozenset("ai ide cli sdk api sdlc llm mcp pr ci cd saas oss apo swe ui ux ml os dev app io devops".split())
_URL = re.compile(r"(?:https?://)?(?:www\.)?[a-z0-9-]+(?:\.[a-z0-9-]+)+(?:/[^\s;,)\]]*)?")
_PARENTHETICAL = re.compile(r"\([^)]+\)")


def distinctive_tokens(display: str, coined: frozenset[str] = frozenset()) -> frozenset[str]:
    """The lower-cased tokens of a canonical-case display name that identify the product.

    A token (whitespace-separated, ``()[],;:/`` stripped) is distinctive when it is not generic and it holds a
    digit, a dot between letters, an upper-case letter after its first (not an all-caps token of three letters
    or fewer), or is a coined word listed in the pack vocabulary.
    """
    found: set[str] = set()
    for raw in display.split():
        token = raw.strip("()[],;:/")
        low = token.lower()
        if not token or low in GENERIC_TOKENS:
            continue
        letters = re.sub(r"[^A-Za-z]", "", token)
        if re.search(r"\d", token) or re.search(r"[A-Za-z]\.[A-Za-z]", token) or low in coined:
            found.add(low)
        elif re.search(r"[A-Z]", token[1:]) and not (letters.isupper() and len(letters) <= 3):
            found.add(low)
    return frozenset(found)


def _is_expansion(display: str) -> bool:
    """"GSD (Get Shit Done)", "Oh My Pi (OMP)": the parenthetical spells out the initials, which ordinary prose does too."""
    head, _, rest = display.partition("(")
    qualifier = rest.rstrip(") ")
    initials = lambda text: "".join(w[0] for w in re.findall(r"[A-Za-z0-9]+", text)).lower()  # noqa: E731
    squash = lambda text: re.sub(r"[^a-z0-9]", "", text.lower())  # noqa: E731
    return initials(qualifier) == squash(head) or initials(head) == squash(qualifier)


def _normal(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", " ", text.lower()).strip()


class Registry:
    """Spellings, distinctive tokens, URLs and qualified displays of the run's vendors."""

    def __init__(
        self,
        known: dict[str, str],
        canonical: dict[str, str],
        aliases: dict[str, str],
        coined: frozenset[str],
        urls: dict[str, list[str]],
    ) -> None:
        self.canonical_of = canonical
        self.displays: dict[str, set[str]] = {}
        self.spellings_of: dict[str, set[str]] = {}
        self._by_spelling: dict[str, set[str]] = {}
        for key, display in known.items():
            vendor = self.canonical(key)
            self.displays.setdefault(vendor, set()).add(str(display))
            for spelling in (key, key.replace("-", " "), str(display)):
                self._add(vendor, spelling)
        for alias, slug in aliases.items():
            self._add(self.canonical(slug), alias)
        for vendor, displays in self.displays.items():  # "Devin (Cognition)": the product's name, then another of its declared names
            primary = known.get(vendor)
            self.displays[vendor] |= {f"{primary} ({other})" for other in sorted(displays) if primary and "(" not in other and other != primary}
        self.distinctive = {
            vendor: frozenset().union(*(distinctive_tokens(d, coined) for d in displays))
            for vendor, displays in self.displays.items()
        }
        self.urls = {self.canonical(slug): [self._host_path(u) for u in entries] for slug, entries in urls.items()}
        self.qualified: dict[str, str] = {}
        for vendor, displays in self.displays.items():
            for display in displays:
                if _PARENTHETICAL.search(display) and not _is_expansion(display):
                    self.qualified[display] = vendor
        self._qualified_rx = re.compile(
            "|".join(rf"(?<![A-Za-z0-9]){re.escape(d)}(?![A-Za-z0-9])" for d in sorted(self.qualified, key=len, reverse=True)) or r"(?!x)x"
        )
        self._hosts = [(host, path, vendor) for vendor, entries in self.urls.items() for host, path in entries]

    def canonical(self, slug: str) -> str:
        return self.canonical_of.get(slug, self.canonical_of.get(re.sub(r"[^a-z0-9]+", "-", slug.lower()).strip("-"), slug))

    def _add(self, vendor: str, spelling: str) -> None:
        low = spelling.lower().strip()
        self.spellings_of.setdefault(vendor, set()).add(low)
        self._by_spelling.setdefault(low, set()).add(vendor)
        self._by_spelling.setdefault(_normal(low), set()).add(vendor)

    @staticmethod
    def _host_path(url: str) -> tuple[str, str]:
        parsed = urlparse(url if "://" in url else "https://" + url)
        host = parsed.netloc.lower().removeprefix("www.")
        return host, parsed.path.rstrip("/").lower()

    def slugs_of(self, spelling: str) -> frozenset[str]:
        low = spelling.lower().strip()
        return frozenset(self._by_spelling.get(low) or self._by_spelling.get(_normal(low)) or ())

    def slugs_of_vendor(self, vendor: str) -> frozenset[str]:
        return frozenset({vendor})

    def is_prose_spelling(self, spelling: str) -> bool:
        """The spelling carries a distinctive token of its own vendor as a whole token."""
        low = spelling.lower().strip()
        tokens = set(low.split()) | set(re.split(r"[\s-]+", low))
        return any(tokens & self.distinctive.get(vendor, frozenset()) for vendor in self.slugs_of(spelling))

    def ambiguous_vendors(self) -> list[str]:
        return sorted(vendor for vendor, tokens in self.distinctive.items() if not tokens)

    def audit(self) -> dict[str, dict[str, list[str]]]:
        return {
            vendor: {
                "distinctive": sorted(self.distinctive[vendor]),
                "prose_spellings": sorted(s for s in self.spellings_of.get(vendor, ()) if self.is_prose_spelling(s)),
            }
            for vendor in sorted(self.displays)
        }

    def url_slug(self, segment: str) -> str | None:
        """The vendor whose pack URL a segment is: same host (or a subdomain of a root host) and path prefix."""
        found = {vendor for vendor in self._url_vendors(segment)}
        return min(found) if found else None

    def _url_vendors(self, text: str) -> set[str]:
        found: set[str] = set()
        for hit in _URL.finditer(text.lower()):
            host, path = self._host_path(hit.group(0))
            for known_host, known_path, vendor in self._hosts:
                host_ok = host == known_host or (not known_path and host.endswith("." + known_host))
                if host_ok and (not known_path or path == known_path or path.startswith(known_path + "/")):
                    found.add(vendor)
        return found

    def signals(self, text: str) -> frozenset[str]:
        """Vendors a text names by an explicit form: a pack URL, or a qualified display in exact case."""
        found = self._url_vendors(text)
        found.update(self.qualified[m.group(0)] for m in self._qualified_rx.finditer(text))
        return frozenset(found)


def build_registry(
    known: dict[str, str],
    pack: dict[str, Any] | None,
    coined: frozenset[str] = frozenset(),
    aliases: dict[str, str] | None = None,
    alias_map: dict[str, str] | None = None,
) -> Registry:
    """The registry of one run: its known vendors, the pack's aliases (``alias_map``: slug -> canonical slug) and URLs."""
    canonical = dict(alias_map or {})
    urls: dict[str, list[str]] = {}
    spellings = dict(aliases or {})
    if pack:
        from category_pack import build_github_by_slug, build_homepage_by_slug, get_product_aliases

        spellings.update({str(k).lower(): str(v) for k, v in get_product_aliases(pack).items()})
        for table in (build_homepage_by_slug(pack), build_github_by_slug(pack)):
            for slug, url in table.items():
                urls.setdefault(canonical.get(slug, slug), []).append(url)
    return Registry(known, canonical, spellings, coined, urls)
