#!/usr/bin/env python3
"""
Claim-Support Verification — checks whether evidence supports claims.

CLI subcommands:
  verify       Check all claims against evidence, update support_status
  report       Generate a support verification summary

Version 1 is deterministic and cheap: entity, number, date, and
lexical-overlap checks over stored evidence. No LLM calls.

Factual claims hard-fail under --strict unless their status is 'supported'.
Synthesis/recommendation need traceability but softer thresholds; speculation and
bibliography rows are 'not_applicable'.
"""

import argparse
import json
import os
import re
import sys
from collections import Counter
from glob import glob
from hashlib import sha256
from typing import Optional
from urllib.parse import urlparse, urlunparse

from extract_claims import NON_CLAIM_SECTIONS, compute_claim_id
from jsonl_store import JsonlError, locked, read_jsonl, write_jsonl_atomic  # noqa: F401


# ---------------------------------------------------------------------------
# Support verification logic
# ---------------------------------------------------------------------------

# Extract numbers (integers and decimals)
NUMBER_RE = re.compile(r'\b\d+(?:\.\d+)?(?:%|[xX]\b|\b)')

# Extract year-like numbers
YEAR_RE = re.compile(r'\b(?:19|20)\d{2}\b')

# Capitalised phrases (Acme Corp), acronyms (AWS, IBM, SAP) and camelCase brands (GitHub, OpenAI, iPhone).
ENTITY_RE = re.compile(
    r'\b(?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*|[A-Z]{2,}[a-z]*|[A-Z][a-z]+[A-Z]\w*|[a-z]+[A-Z]\w*)\b'
)

# Alphanumeric identifiers (EC2, S3, GPT4, H100, FY2018, Q3) are names, not quantities.
ID_RE = re.compile(r'\b[A-Za-z]+\d+[A-Za-z0-9]*\b')

# Common stop entities to ignore
STOP_ENTITIES = frozenset([
    'The', 'This', 'That', 'These', 'However', 'Furthermore',
    'Moreover', 'Additionally', 'Therefore', 'Nevertheless', 'It', 'Its', 'They', 'We',
    'About', 'According', 'Many', 'Most', 'Some', 'Several', 'Over', 'Nearly', 'Roughly', 'Around',
    'Approximately', 'Each', 'Every', 'All', 'Both', 'Our', 'Their', 'Under', 'Since', 'During',
    'Between', 'Among', 'Across', 'After', 'Before', 'Despite', 'Although', 'While', 'Because',
    'When', 'Where', 'If', 'For', 'From', 'With', 'Without', 'In', 'On', 'At', 'By', 'As', 'Of',
    'Recent', 'Recently', 'Currently', 'Today', 'Now', 'Also', 'Still', 'Only', 'Just', 'Even',
    'Another', 'Other', 'Such', 'There', 'Here', 'What', 'Which', 'Who', 'How', 'Why', 'No', 'Not',
    'Neither', 'Nor', 'Yes', 'See', 'Overall', 'Note', 'Per',
])

# Weights of the feature classes; renormalised over the classes the claim actually contains,
# so a class the claim lacks is neutral rather than a free full match.
WEIGHTS = {'tokens': 0.4, 'numbers': 0.25, 'years': 0.15, 'entities': 0.2}
SUPPORTED_SCORE = 0.6
PARTIAL_SCORE = 0.35
MIN_TOKEN_OVERLAP = 0.3
PROSE_TOKEN_OVERLAP = 0.9


# ---------------------------------------------------------------------------
# Text normalisation
# ---------------------------------------------------------------------------

_QUOTE_TABLE = {
    0x2018: "'", 0x2019: "'", 0x02BC: "'", 0x2032: "'", 0x201C: '"', 0x201D: '"',
    0x2010: '-', 0x2011: '-', 0x2012: '-', 0x2013: '-', 0x2014: '-', 0x00A0: ' ',
}
PERCENT_RE = re.compile(r'(\d)\s*(?:percent|per cent|pct)\b', re.IGNORECASE)
CURRENCY_CODE_RE = re.compile(r'\b(USD|EUR|GBP)\s*(?=\d)')
_CODE_SYMBOL = {'USD': '$', 'EUR': '€', 'GBP': '£'}
FREE_RE = re.compile(r'\bat no (?:extra |additional )?(?:cost|charge|fee)\b', re.IGNORECASE)


_UNITS = {w: i for i, w in enumerate(
    'zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen '
    'sixteen seventeen eighteen nineteen'.split())}
_TENS = {w: 10 * i for i, w in enumerate('_ _ twenty thirty forty fifty sixty seventy eighty ninety'.split())}
_MULT = {'hundred': 100, 'thousand': 1000, 'million': 1_000_000, 'billion': 1_000_000_000}
_NUM_FIRST = '|'.join(list(_UNITS) + [w for w in _TENS if w != '_'])
_NUM_ANY = _NUM_FIRST + '|' + '|'.join(_MULT)
# A run of number words that starts with a units/tens word (a bare "million" after a digit stays).
NUMBER_WORDS_RE = re.compile(
    r'\b(?:' + _NUM_FIRST + r')\b(?:[\s-]+(?:and\s+)?(?:' + _NUM_ANY + r')\b)*[ \t]*',
    re.IGNORECASE,
)
VERSION_RE = re.compile(r'\bv(?=\d)')


def _words_to_number(match: 're.Match') -> str:
    text = match.group(0)
    words = re.findall(r'[a-z]+', text.lower())
    if words in (['one'], ['zero']):  # "one who", "zero downtime": not quantities
        return text
    trailing = text[len(text.rstrip()):]
    total, current = 0, 0
    for word in words:
        if word == 'and':
            continue
        if word in _UNITS:
            current += _UNITS[word]
        elif word in _TENS:
            current += _TENS[word]
        elif word == 'hundred':
            current = max(current, 1) * 100
        else:
            total += max(current, 1) * _MULT[word]
            current = 0
    return str(total + current) + trailing


def normalize_text(text: str) -> str:
    """NFKC, typographic quotes/dashes to ASCII, '40 percent' to '40%', 'USD 50' to '$50',
    'five thousand' to '5000', 'v1.29' to '1.29'."""
    import unicodedata
    text = unicodedata.normalize('NFKC', text).translate(_QUOTE_TABLE)
    text = NUMBER_WORDS_RE.sub(_words_to_number, text)
    text = VERSION_RE.sub('', text)
    text = PERCENT_RE.sub(r'\1%', text)
    text = CURRENCY_CODE_RE.sub(lambda m: _CODE_SYMBOL[m.group(1)], text)
    return FREE_RE.sub('for free', text)


def extract_tokens(text: str) -> set[str]:
    """Extract significant lowercase tokens (>3 chars)."""
    words = re.findall(r'\b[a-z]{4,}\b', text.lower())
    return set(words)


def extract_numbers(text: str) -> set[str]:
    """Extract numeric values other than years (years are checked separately)."""
    return set(NUMBER_RE.findall(text)) - extract_years(text)


def extract_years(text: str) -> set[str]:
    """Extract year mentions."""
    return set(YEAR_RE.findall(text))


def extract_entities(text: str) -> set[str]:
    """Extract capitalized entity mentions and alphanumeric identifiers (EC2, GPT4, FY2018)."""
    ents = set(ENTITY_RE.findall(text)) | set(ID_RE.findall(text))
    # A sentence-opening "-ly" word ("Quarterly", "Recently") is an adverb or adjective, not a name.
    ents = {e for e in ents if not (e.endswith('ly') and ' ' not in e and e.istitle() and len(e) > 5)}
    return ents - STOP_ENTITIES


# ---------------------------------------------------------------------------
# Figures: value, unit, currency, and what each is attached to
# ---------------------------------------------------------------------------

# A figure: optional currency, digits with optional thousands separators and decimals, then an
# optional unit/scale (%, k, M, bn, million, ...). Digits glued to letters (EC2) are not figures.
FIGURE_RE = re.compile(
    r'(?<![\w.])([$€£])?\s?(\d{1,3}(?:,\d{3})+|\d+)(\.\d+)?'
    r'(?:\s*(%|trillion|billion|million|thousand)\b|(%|bn|mn|[kKmMbBxX])(?![A-Za-z0-9]))?'
)
SCALES = {'k': 1e3, 'thousand': 1e3, 'm': 1e6, 'mn': 1e6, 'million': 1e6, 'b': 1e9, 'bn': 1e9,
          'billion': 1e9, 'trillion': 1e12}
CURRENCY_WORDS = {'dollar': '$', 'dollars': '$', 'usd': '$', 'euro': '€', 'euros': '€', 'eur': '€',
                  'pound': '£', 'pounds': '£', 'gbp': '£'}
# Words that carry no binding information next to a figure (articles, prepositions, auxiliaries,
# quantity hedges, dates and period words such as "fiscal", "year over year", months).
FILLER_WORDS = frozenset(
    'a an the of in on at to by for from with and or as per than over under about around nearly '
    'roughly approximately more less up down into across during since until while after before '
    'is are was were be been has have had its their his her our it that which who whose this these '
    'also now only just still about almost close fiscal year years yoy quarter month months week '
    'january february march april may june july august september october november december '
    'jan feb mar apr jun jul aug sep sept oct nov dec each every any all some '
    'reported reports said says according billion million thousand trillion percent'.split()
) | frozenset(CURRENCY_WORDS)
ADJUNCT_PREPOSITIONS = frozenset(
    'in on at by for from with versus vs compared during since through across between among under '
    'than until before after within without'.split()
)
CONJUNCTIONS = frozenset(['and', 'or', 'but', 'while', 'whereas', 'although', 'however'])
WORD_RE = re.compile(r"[A-Za-z]+|\d+")
def _stem(word: str) -> str:
    """Light stemmer: plural/-ed/-ing endings and a final -e ("employees" == "employee")."""
    word = word.lower()
    for suffix in ('ing', 'ed'):
        if len(word) > len(suffix) + 3 and word.endswith(suffix):
            word = word[:-len(suffix)]
            if len(word) > 3 and word[-1] == word[-2] and word[-1] in 'bdgmnprt':
                word = word[:-1]  # shipped -> ship
            break
    else:
        if len(word) > 4 and word.endswith('ies'):
            word = word[:-3] + 'y'
        elif len(word) > 4 and word.endswith(('ches', 'shes', 'sses', 'xes', 'zes')):
            word = word[:-2]
        elif len(word) > 3 and word.endswith('s') and not word.endswith('ss'):
            word = word[:-1]
    return word[:-1] if len(word) > 4 and word.endswith('e') else word


# Interchangeable head nouns for the same quantity (stemmed).
SYNONYM_GROUPS = tuple(frozenset(_stem(w) for w in g) for g in (
    ('people', 'employees', 'staff', 'workers', 'headcount', 'personnel'),
    ('customers', 'clients'),
))


def _same_noun(a: str, b: str) -> bool:
    return a == b or any(a in g and b in g for g in SYNONYM_GROUPS)


# Segments: the smallest stretch a figure is attached to. Split at sentence ends, commas (except
# inside "13, 2023"), and coordinating words, so "founded in 2015 and acquired in 2019" has two.
SEGMENT_SPLIT_RE = re.compile(
    r'(?<=[.;:!?])\s+|,(?!\s*\d)|\band\b|\bbut\b|\bwhile\b|\bwhereas\b|\bhowever\b|\balthough\b|\bwhich\b',
    re.IGNORECASE,
)


class Figure:
    """A figure with the words it is attached to."""

    __slots__ = ('value', 'kind', 'currency', 'noun', 'before', 'after', 'stems')

    def __init__(self, value, kind, currency, noun, before, after, stems=frozenset()):
        self.value, self.kind, self.currency = value, kind, currency
        self.noun, self.before, self.after, self.stems = noun, before, after, stems

    def __getitem__(self, i):  # (value, kind, noun, before, after): the shape older callers use
        return (self.value, self.kind, self.noun, self.before, self.after)[i]


def _segment_figures(text: str, drop: frozenset = frozenset()) -> list[Figure]:
    # Words naming the claim's entities are dropped: a shared subject ("Acme") says nothing about
    # what a figure belongs to.
    stems = frozenset(_stem(t) for t in extract_tokens(text) if t not in drop)
    out = []
    for m in FIGURE_RE.finditer(text):
        currency, whole, frac, word_unit, abbr = m.group(1), m.group(2), m.group(3), m.group(4), m.group(5)
        value = float(whole.replace(',', '') + (frac or ''))
        unit = (word_unit or abbr or '').lower()
        if unit == '%':
            kind = '%'
        elif unit == 'x' and not currency:
            kind = 'x'
        else:
            value *= SCALES.get(unit, 1)
            kind = 'num'
            if not currency and not unit and not frac and len(whole) == 4 and 1900 <= value <= 2099:
                kind = 'year'
        after_words = WORD_RE.findall(text[m.end():m.end() + 80])
        if not currency and kind == 'num':
            for w in after_words[:2]:
                if w.lower() in CURRENCY_WORDS:
                    currency = CURRENCY_WORDS[w.lower()]
                    break
        after: list[str] = []
        for w in after_words:
            # A preposition ends the noun phrase: "35% compared with placebo", "31% in the fourth quarter".
            if w.isdigit() or w.lower() in ADJUNCT_PREPOSITIONS:
                break
            if w.lower() not in FILLER_WORDS:
                after.append(_stem(w))
        noun = after[0] if after and kind != 'year' else None
        before = [_stem(w) for w in reversed(WORD_RE.findall(text[max(0, m.start() - 60):m.start()]))
                  if not w.isdigit() and w.lower() not in FILLER_WORDS][:3]
        out.append(Figure(value, kind, currency, noun, tuple(before), tuple(after[:3]), stems))
    return out


def extract_figures(text: str, drop_entities: bool = False) -> list[Figure]:
    """Normalised figures. $50M and 50 million dollars are both 5e7 dollars; 2,500 is 2500.0,
    not {2, 500}; kind is 'year', '%', 'x' or 'num'. Each figure knows its segment's words, the
    first content word after it (``noun``) and the nearest content words on each side."""
    text = normalize_text(text)
    drop = frozenset(w.lower() for e in extract_entities(text) for w in e.split()) if drop_entities else frozenset()
    figures: list[Figure] = []
    for segment in SEGMENT_SPLIT_RE.split(text):
        if segment and segment.strip():
            figures.extend(_segment_figures(segment, drop))
    return figures


# ---------------------------------------------------------------------------
# Clauses and negation
# ---------------------------------------------------------------------------

CLAUSE_SPLIT_RE = re.compile(
    r'[.;:!?]\s|[.;:!?]$|,\s*(?:which|who|whose|but|while|whereas)\b|\bbut\b|\bhowever\b|\balthough\b'
    r'|\bwhereas\b|\bwhile\b',
    re.IGNORECASE,
)
# "and" separates clauses only when a new predicate starts after it and its polarity differs
# ("opened 40 stores and closed none"; "does not include logs and is limited to 3 users").
# Inside one negated scope ("does not support SSO and SCIM") it stays one clause.
AND_PREDICATE_RE = re.compile(
    r'\s+and\s+(?=(?:is|are|was|were|has|have|had|does|do|did|can|could|will|would|cannot|\w+ed)\b)',
    re.IGNORECASE,
)
# Cues that negate a clause. "without X" and "no longer" are content, not clause polarity:
# "works offline without an account" is the same polarity as "works offline and without an account".
NEGATION_RE = re.compile(
    r"\b(?:not|no|never|none|neither|nor|nothing|cannot|absent|fails? to|unable to|lacks?|lacking)\b|n't\b",
    re.IGNORECASE,
)
NO_LONGER_RE = re.compile(r'\bno longer\b', re.IGNORECASE)
UN_RE = re.compile(r'\bun(available|supported|able|certified)\b', re.IGNORECASE)
NOT_ONLY_RE = re.compile(r'\bnot only\b|\bnot even\b|\bnot just\b', re.IGNORECASE)
ZERO_RE = re.compile(r'\bzero\s+([a-z]+)', re.IGNORECASE)
WITHOUT_RE = re.compile(r'\bwithout\s+(?:an?\s+|the\s+|any\s+)?([a-z]+)(?:\s+([a-z]+))?', re.IGNORECASE)
# A coordinated list of named things: "Kubernetes and Nomad", "Slack, Jira or Teams".
ENTITY_LIST_RE = re.compile(
    r'\b([A-Z][\w.+-]*(?:\s[A-Z][\w.+-]*)*(?:\s*,\s*[A-Z][\w.+-]*(?:\s[A-Z][\w.+-]*)*)*'
    r'(?:\s*,?\s*(?:and|or)\s+[A-Z][\w.+-]*(?:\s[A-Z][\w.+-]*)*)+)'
)


def _is_negated(clause: str, claim_side: bool = False) -> bool:
    """Whether a clause is negated (boolean polarity: "neither ... nor", "No, ... does not" and
    "does not ..., not even ..." are each one negation; "not only ... but also" is none)."""
    text = NOT_ONLY_RE.sub(' ', _normalize_negation(clause))
    return bool(NEGATION_RE.search(text))


def _normalize_negation(text: str) -> str:
    return UN_RE.sub(r'not \1', normalize_text(text))


def _has_cue(text: str) -> bool:
    return _is_negated(text)


def _clauses(text: str) -> list[str]:
    parts: list[str] = []
    for chunk in CLAUSE_SPLIT_RE.split(text):
        if not chunk or not chunk.strip():
            continue
        pieces = [p.strip() for p in AND_PREDICATE_RE.split(chunk) if p and p.strip()]
        merged = [pieces[0]]
        for piece in pieces[1:]:
            # Keep the "and" (one clause) unless the two parts differ in polarity.
            if _has_cue(merged[-1]) == _has_cue(piece):
                merged[-1] += ' and ' + piece
            else:
                merged.append(piece)
        parts.extend(merged)
    return parts


def _stems(text: str) -> set[str]:
    return {_stem(t) for t in extract_tokens(NEGATION_RE.sub(' ', text))}


def _subject(claim_text: str) -> Optional[str]:
    for m in ENTITY_RE.finditer(claim_text):
        if m.group(0) not in STOP_ENTITIES:
            return m.group(0)
    return None


def _want(clause: str, subject: Optional[str]) -> set[str]:
    skip = {x.lower() for x in (subject or '').split()} | {(subject or '').lower()}
    return {w.lower() for w in extract_entities(clause) if w.lower() not in skip}


def _variants(clause: str) -> list[str]:
    """The clause itself plus, for a coordinated list of named things, one variant per item
    ("supports Kubernetes and Nomad" -> "supports Kubernetes", "supports Nomad")."""
    out = [clause]
    for m in ENTITY_LIST_RE.finditer(clause):
        items = [i.strip() for i in re.split(r'\s*,\s*|\s+(?:and|or)\s+', m.group(1)) if i.strip()]
        out.extend(clause[:m.start()] + item + clause[m.end():] for item in items)
    return out


def _aligned(claim_clause: str, quote_clause: str, subject: Optional[str]) -> bool:
    """Does the quote clause talk about what the claim clause says?

    With named terms in the claim clause (entities, identifiers, figures, apart from the subject)
    the quote clause must contain all of them, whatever other words the claim adds; without
    them, at least half of the claim's significant words (and two, when it has that many) must
    be shared."""
    want = _want(claim_clause, subject)
    figs = {(f.value, f.kind) for f in extract_figures(claim_clause)}
    q_lower = quote_clause.lower()
    q_figs = {(f.value, f.kind) for f in extract_figures(quote_clause)}
    if want or figs:
        return (all(re.search(r'\b' + re.escape(w) + r'\b', q_lower) for w in want) and figs <= q_figs)
    tokens = _stems(claim_clause)
    if not tokens:
        return False
    shared = len(tokens & _stems(quote_clause))
    return shared >= min(2, len(tokens)) and shared / len(tokens) >= 0.5


# Verb/noun opposites a lexical check would otherwise read as the same claim ("raised" vs "lost").
ANTONYM_PAIRS = tuple(
    (frozenset(_stem(w) for w in a.split()), frozenset(_stem(w) for w in b.split())) for a, b in (
        ('raise raised raises secure secured gain gained add added adds', 'lose lost loses lost'),
        ('increase increased increases grow grew grown rise rose rises raise raised raises expand expanded', 'decrease decreased decreases shrink shrank fall fell falls drop dropped cut cuts lower lowered reduce reduced contract contracted'),
        ('acquire acquired acquires buy bought', 'sell sold sells divest divested'),
        ('hire hired hires', 'fire fired fires layoff laid'),
        ('open opened opens launch launched launches', 'close closed closes shut discontinue discontinued retire retired'),
        ('add added adds enable enabled enables', 'remove removed removes disable disabled disables'),
        ('start started starts', 'stop stopped stops'),
        ('win won wins', 'lose lost loses'),
        ('profit profitable profitability', 'loss unprofitable'),
        ('approve approved approves', 'reject rejected rejects deny denied'),
        ('support supported supports', 'deprecate deprecated deprecates'),
        ('pause paused pauses halt halted', 'continue continued continues resume resumed'),
        ('mandatory required compulsory', 'optional'),
        ('allow allowed allows', 'block blocked blocks forbid forbidden prohibit prohibited'),
    )
)


def _antonym_conflict(claim_clause: str, quote_clause: str) -> bool:
    c, q = _stems(claim_clause), _stems(quote_clause)
    return any((c & left and q & right and not q & left) or (c & right and q & left and not q & right)
               for left, right in ANTONYM_PAIRS)


def _quantifier_conflict(claim_clause: str, quote_clause: str) -> bool:
    """"zero <thing>" / "without <thing>" in one text but not the other, about the same thing."""
    for pattern in (ZERO_RE, WITHOUT_RE):
        c = {_stem(w) for m in pattern.findall(claim_clause) for w in (m if isinstance(m, tuple) else (m,)) if w}
        q = {_stem(w) for m in pattern.findall(quote_clause) for w in (m if isinstance(m, tuple) else (m,)) if w}
        if (q - c) & _stems(claim_clause) or (c - q) & _stems(quote_clause):
            return True
    return False


def _negation_conflict(claim_text: str, quote: str) -> bool:
    """True when a claim clause and an aligned quote clause disagree on polarity, or one says
    "zero/without <thing>" about something the other asserts plainly. Any clause of the whole
    quote can contradict."""
    claim_text, quote = normalize_text(claim_text), normalize_text(quote)
    subject = _subject(claim_text)
    quote_clauses = _clauses(quote)
    for claim_clause in _clauses(claim_text):
        # "no longer ..." may be worded in the quote as "retired"/"discontinued": no polarity check.
        check_polarity = not NO_LONGER_RE.search(claim_clause)
        claim_neg = _is_negated(claim_clause)
        for variant in _variants(claim_clause):
            for q in quote_clauses:
                if not _aligned(variant, q, subject):
                    continue
                if check_polarity and _is_negated(q) != claim_neg:
                    return True
                if _quantifier_conflict(variant, q) or _antonym_conflict(variant, q):
                    return True
    return False


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def _fraction_present(wanted: set[str], have: set[str]) -> float:
    return len(wanted & have) / len(wanted)


def _entity_coverage(entities: set[str], quote: str) -> float:
    """Share of claim entities named in the quote: whole words in any case, or the same word
    stems ("Webhooks" / "webhook")."""
    lower = quote.lower()
    quote_stems = {_stem(w) for w in WORD_RE.findall(lower)}
    found = sum(
        1 for e in entities
        if re.search(r'\b' + re.escape(e.lower()) + r'\b', lower) or all(_stem(w) in quote_stems for w in e.split())
    )
    return found / len(entities)


def _figure_matches(claim: Figure, quote: Figure, others: list[Figure]) -> bool:
    """Same value, kind and (when both state one) currency, in a segment about the same thing.

    Years only need the segment to share a word ("founded in 2015" must not match "acquired in
    2015"). Other figures must also be attached to the same noun: the claim's noun follows the
    quote's figure (or precedes it: "Seats cost $20"), or, without a noun, the claim's nearest
    preceding words are the quote's. A quote figure whose nearest word is what the claim attaches
    to a *different* figure ("latency by 10%" vs "cost by 30%") does not match."""
    if claim.value != quote.value or claim.kind != quote.kind:
        return False
    if claim.currency and quote.currency and claim.currency != quote.currency:
        return False
    if claim.stems and quote.stems and not claim.stems & quote.stems:
        return False
    if claim.kind == 'year':
        return True
    if claim.noun is not None:
        return any(_same_noun(claim.noun, w) for w in quote.after[:2] + quote.before[:2])
    if not claim.before or not quote.before:
        return True
    if any(o is not claim and o.before and o.before[0] == quote.before[0] != claim.before[0] for o in others):
        return False
    return bool(set(claim.before[:2]) & set(quote.before))


def _figures_supported(claim_text: str, quote_text: str, kinds) -> tuple[int, int]:
    """(matched, total) of the claim's figures of the given kinds."""
    claim_figs = extract_figures(claim_text, drop_entities=True)
    quote_figs = extract_figures(quote_text)
    wanted = [f for f in claim_figs if f.kind in kinds]
    matched = sum(1 for f in wanted if any(_figure_matches(f, q, claim_figs) for q in quote_figs))
    return matched, len(wanted)


def compute_support_score(claim_text: str, evidence_quotes: list[str]) -> tuple[str, float, str]:
    """
    Compute support status for a claim given its linked evidence quotes.

    Returns (status, score, notes). A claim is 'supported' only when the best quote scores at
    least 0.6, shares at least 30% of the claim's significant words, contains every named entity
    of the claim, matches every figure (same value, unit and currency, in a clause about the same
    thing and attached to the same noun) and no aligned quote clause contradicts a claim clause's
    polarity.
    """
    if not evidence_quotes:
        return ('unsupported', 0.0, 'no evidence linked')

    # Inline citation markers such as [1] or [2, 3] are references, not claimed numbers.
    claim_text = normalize_text(INLINE_CITATION_RE.sub(' ', claim_text))
    claim_tokens = extract_tokens(claim_text)
    claim_entities = extract_entities(claim_text)
    claim_figs = extract_figures(claim_text)
    has_numbers = any(f.kind != 'year' for f in claim_figs)
    has_years = any(f.kind == 'year' for f in claim_figs)
    number_kinds = ('num', '%', 'x')

    best: tuple[float, bool, list[str]] = (-1.0, False, [])
    for quote in evidence_quotes:
        quote = normalize_text(quote)
        token_overlap = _fraction_present(claim_tokens, extract_tokens(quote)) if claim_tokens else 0.0
        parts = [('tokens', token_overlap)]
        notes: list[str] = []
        # A claim with no named thing and no figure is judged on its words alone: nearly all must appear.
        needed = MIN_TOKEN_OVERLAP if (claim_entities or claim_figs) else PROSE_TOKEN_OVERLAP
        complete = token_overlap >= needed
        if token_overlap < needed:
            notes.append('low lexical overlap')
        checks = []
        if has_numbers:
            checks.append(('numbers', _ratio(_figures_supported(claim_text, quote, number_kinds)), 'number mismatch'))
        if has_years:
            checks.append(('years', _ratio(_figures_supported(claim_text, quote, ('year',))), 'year mismatch'))
        if claim_entities:
            checks.append(('entities', _entity_coverage(claim_entities, quote), 'entity mismatch'))
        for name, value, note in checks:
            parts.append((name, value))
            if value < 1.0:
                complete = False
                notes.append(note)
        if _negation_conflict(claim_text, quote):
            complete = False
            notes.append('negation mismatch')
        score = sum(WEIGHTS[name] * value for name, value in parts) / sum(WEIGHTS[name] for name, _ in parts)
        if score > best[0]:
            best = (score, complete, notes)

    score, complete, notes = best
    if score >= SUPPORTED_SCORE and complete:
        status = 'supported'
    elif score >= PARTIAL_SCORE:
        status = 'partial'
    else:
        status = 'needs_review'
    return (status, round(score, 3), '; '.join(notes) if notes else 'adequate overlap')


def _ratio(pair: tuple[int, int]) -> float:
    return pair[0] / pair[1]

# Kept identical to citation_manager.py so source_id matching stays stable
# (tests/test_verify_claim_support_unit.py::TestCanonicalParity enforces it).
DOI_RE = re.compile(r'(?:https?://(?:dx\.)?doi\.org/|doi:)(10\.\d{4,}/\S+)', re.IGNORECASE)
ARXIV_RE = re.compile(r'(?:https?://arxiv\.org/abs/|arxiv:)(\d{4}\.\d{4,}(?:v\d+)?)', re.IGNORECASE)

TRACKING_PARAMS = frozenset([
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'ref', 'source', 'fbclid', 'gclid', 'mc_cid', 'mc_eid',
])


def canonicalize_locator(raw_url: str) -> str:
    """Derive a canonical locator from a raw URL or identifier string.

    Mirrors citation_manager.py behavior (DOI > arXiv > normalized URL) to
    keep source_id matching stable.
    """
    m = DOI_RE.search(raw_url)
    if m:
        return f'doi:{m.group(1).rstrip(".")}'
    m = ARXIV_RE.search(raw_url)
    if m:
        return f'arxiv:{m.group(1)}'
    parsed = urlparse(raw_url)
    scheme = (parsed.scheme or 'https').lower()
    host = (parsed.hostname or '').lower()
    path = parsed.path.rstrip('/')
    if parsed.query:
        pairs = []
        for part in parsed.query.split('&'):
            kv = part.split('=', 1)
            if kv[0].lower() not in TRACKING_PARAMS:
                pairs.append(part)
        query = '&'.join(sorted(pairs))
    else:
        query = ''
    return urlunparse((scheme, host, path, '', query, ''))


def compute_source_id(canonical_locator: str) -> str:
    return sha256(canonical_locator.encode('utf-8')).hexdigest()[:16]


BIB_HEADING_RE = re.compile(r'^##\s+Bibliography\s*$', re.I)
# Citation numbers are bounded to 4 digits: an ID such as [20240101] is not a citation, and
# int() can never hit the 4300-digit cap.
BIB_ENTRY_RE = re.compile(r'^\[(\d{1,4})\]\s+')
MD_LINK_URL_RE = re.compile(r'\]\((https?://[^)\s]+)\)')
PLAIN_URL_RE = re.compile(r'https?://[^\s<>()\[\]]+')
INLINE_CITATION_RE = re.compile(r'\[(\d{1,4}(?:,\s*\d{1,4})*)\]')
# Where an uncited sentence's own paragraph ends: a blank line, a heading or a new list item.
PARAGRAPH_END_RE = re.compile(r'\n\s*\n|\n#|\n\s*(?:[-*+]|\d+[.)])\s')
REPORT_NAME = 'research_report.md'


def _find_report_path(run_dir: str) -> Optional[str]:
    """Locate the run's report: manifest artifact_paths.report, research_report.md, or a
    single legacy research_report_*.md. Never guesses from other markdown files (critique.md,
    handoff.md and decision-record.md are not the report)."""
    manifest_path = os.path.join(run_dir, 'run_manifest.json')
    if os.path.exists(manifest_path):
        try:
            with open(manifest_path, encoding='utf-8') as f:
                manifest = json.load(f)
            rel = (manifest.get('artifact_paths') or {}).get('report')
        except (OSError, ValueError, AttributeError):
            rel = None
        if rel:
            cand = os.path.join(run_dir, rel)
            if os.path.isfile(cand):
                return cand

    cand = os.path.join(run_dir, REPORT_NAME)
    if os.path.isfile(cand):
        return cand

    # Legacy convention: research_report_<date>_<slug>.md (newest wins).
    cands = sorted(glob(os.path.join(run_dir, 'research_report_*.md')), key=os.path.getmtime, reverse=True)
    return cands[0] if cands else None


def _first_url(line: str) -> Optional[str]:
    """First URL on a bibliography line: a markdown link, a plain URL or 'Title - URL'."""
    m = MD_LINK_URL_RE.search(line)
    if m:
        return m.group(1)
    m = PLAIN_URL_RE.search(line)
    if m:
        return m.group(0).rstrip('.,;:')
    return None


def parse_bibliography_number_to_url(report_md: str) -> dict[int, str]:
    """Parse the Bibliography section and return citation_number -> url mapping."""
    in_bib = False
    out: dict[int, str] = {}
    for line in report_md.splitlines():
        if BIB_HEADING_RE.match(line.strip()):
            in_bib = True
            continue
        if not in_bib:
            continue
        if line.startswith('## ') and not BIB_HEADING_RE.match(line.strip()):
            break
        m = BIB_ENTRY_RE.match(line.strip())
        if not m:
            continue
        url = _first_url(line)
        if url:
            out[int(m.group(1))] = url
    return out


def build_display_number_to_source_id(
    sources: list[dict],
    bib_num_to_url: Optional[dict[int, str]],
) -> dict[int, str]:
    """Build a mapping of display citation numbers -> source_id.

    Prefers Bibliography parsing when available; otherwise falls back to
    sources.jsonl registration order.
    """
    if bib_num_to_url:
        by_raw_url = {s.get('raw_url'): s.get('source_id') for s in sources if s.get('raw_url') and s.get('source_id')}
        by_canon = {s.get('canonical_locator'): s.get('source_id') for s in sources if s.get('canonical_locator') and s.get('source_id')}
        out: dict[int, str] = {}
        for num, url in bib_num_to_url.items():
            sid = by_raw_url.get(url)
            if not sid:
                canon = canonicalize_locator(url)
                sid = by_canon.get(canon)
                if not sid:
                    # Last resort: compute expected source_id and see if it exists.
                    expected = compute_source_id(canon)
                    if expected in {s.get('source_id') for s in sources}:
                        sid = expected
            if sid:
                out[num] = sid
        if out:
            return out

    # Fallback: assign display numbers in registration order.
    out: dict[int, str] = {}
    seen = set()
    i = 1
    for src in sources:
        sid = src.get('source_id')
        if not sid or sid in seen:
            continue
        seen.add(sid)
        out[i] = sid
        i += 1
    return out


def infer_citation_numbers_from_context(report_md: str, claim_text: str) -> list[int]:
    """Heuristically infer citation numbers for a claim by scanning nearby text.

    This handles cases where a bullet/paragraph has citations at the end, but
    the claim was extracted as an earlier sentence without inline [N] markers.
    """
    if not report_md or not claim_text:
        return []
    pos = report_md.find(claim_text)
    if pos < 0:
        # Common mismatch: claim extraction strips markdown emphasis, but the
        # report still contains it (e.g. **fork**).
        simplified = report_md.replace('**', '')
        pos = simplified.find(claim_text)
        if pos < 0:
            return []
        report_md = simplified

    # Only the claim's own paragraph counts: up to a blank line, a heading or the next list
    # item. An uncited claim never inherits a citation from a later paragraph or bullet.
    end = PARAGRAPH_END_RE.search(report_md, pos)
    snippet = report_md[pos:end.start() if end else len(report_md)]
    out: list[int] = []
    for m in INLINE_CITATION_RE.finditer(snippet):
        for n in m.group(1).split(','):
            num = int(n.strip())
            if num not in out:
                out.append(num)
    return out


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def _unique_claims(claims: list[dict]) -> list[dict]:
    """De-duplicate by claim_id, computing a missing id from section and text (never by None)."""
    seen: set[str] = set()
    unique = []
    for c in claims:
        cid = c.get('claim_id') or compute_claim_id(c.get('section_id', ''), c.get('text', ''))
        c['claim_id'] = cid
        if cid not in seen:
            seen.add(cid)
            unique.append(c)
    return unique


def _resolve_report(args: argparse.Namespace) -> str:
    """The report to read: --report when given, else the run's own report. Exit 2 if missing."""
    path = args.report or _find_report_path(args.dir)
    if not path or not os.path.isfile(path):
        wanted = args.report or os.path.join(args.dir, REPORT_NAME)
        print(json.dumps({'error': f'report not found: {wanted} (pass --report PATH)'}), file=sys.stderr)
        sys.exit(2)
    return path


def _verify_claim(claim: dict, report_md: str, display_num_to_source_id: dict[int, str],
                  ev_by_source: dict[str, list[str]], ev_by_id: dict[str, dict]) -> None:
    section_id = claim.get('section_id', '')
    claim_type = claim.get('claim_type', 'factual')

    # Normalize claim types based on section intent.
    if section_id == 'recommendations':
        claim_type = 'recommendation'
    elif section_id in ('limitations', 'synthesis', 'conclusion'):
        # Uncited statements in these sections are usually interpretive synthesis.
        if claim_type == 'factual' and not claim.get('_citation_numbers'):
            claim_type = 'synthesis'
    claim['claim_type'] = claim_type

    # If the sentence has no inline citations, use citations from its own paragraph only.
    if not claim.get('_citation_numbers'):
        inferred = infer_citation_numbers_from_context(report_md, claim.get('text', ''))
        if inferred:
            claim['_citation_numbers'] = inferred

    # Backfill cited_source_ids from extracted citation numbers if missing.
    if not claim.get('cited_source_ids') and claim.get('_citation_numbers'):
        cited = []
        for n in claim.get('_citation_numbers', []):
            sid = display_num_to_source_id.get(n)
            if sid and sid not in cited:
                cited.append(sid)
        claim['cited_source_ids'] = cited

    cited_ids = claim.get('cited_source_ids', [])
    evidence_ids = claim.get('evidence_ids', [])
    quotes = [ev_by_id[eid].get('quote', '') for eid in evidence_ids if eid in ev_by_id]
    for sid in cited_ids:
        quotes.extend(ev_by_source.get(sid, []))

    if claim_type == 'speculation' and not quotes:
        claim['support_status'] = 'not_applicable'  # labelled speculation needs no evidence
    elif not quotes and not cited_ids and not evidence_ids:
        claim['support_status'] = 'unsupported'
    elif not quotes:
        # Has cited sources but no evidence captured yet
        claim['support_status'] = 'needs_review'
    else:
        status, score, notes = compute_support_score(claim['text'], quotes)
        claim['support_status'] = status
        claim['_support_score'] = score
        claim['_support_notes'] = notes


def cmd_verify(args: argparse.Namespace) -> None:
    """Verify all claims against evidence, update claims.jsonl (atomically, losing no row)."""
    claims_path = os.path.join(args.dir, 'claims.jsonl')
    report_path = _resolve_report(args)
    with open(report_path, encoding='utf-8') as f:
        report_md = f.read()

    with locked(claims_path):
        claims = read_jsonl(claims_path)
        evidence = read_jsonl(os.path.join(args.dir, 'evidence.jsonl'))
        sources = read_jsonl(os.path.join(args.dir, 'sources.jsonl'))
        display_num_to_source_id = build_display_number_to_source_id(
            sources, parse_bibliography_number_to_url(report_md))

        ev_by_source: dict[str, list[str]] = {}
        ev_by_id: dict[str, dict] = {}
        for ev in evidence:
            ev_by_source.setdefault(ev.get('source_id', ''), []).append(ev.get('quote', ''))
            ev_by_id[ev.get('evidence_id', '')] = ev

        claims = _unique_claims(claims)
        for claim in claims:
            if claim.get('section_id', '') in NON_CLAIM_SECTIONS:
                # Bibliography rows are citations, not claims: kept, but never scored.
                claim['support_status'] = 'not_applicable'
                continue
            _verify_claim(claim, report_md, display_num_to_source_id, ev_by_source, ev_by_id)

        write_jsonl_atomic(claims_path, claims)

    scored = [c for c in claims if c.get('support_status') != 'not_applicable']
    status_counts = Counter(c.get('support_status') for c in claims)
    factual = [c for c in scored if c.get('claim_type') == 'factual']
    factual_unsupported = sum(1 for c in factual if c.get('support_status') == 'unsupported')
    factual_not_supported = sum(1 for c in factual if c.get('support_status') != 'supported')

    # Strict mode: every factual claim must be supported (partial and needs_review fail too).
    passed = not (args.strict and factual_not_supported > 0)

    print(json.dumps({
        'status': 'pass' if passed else 'fail',
        'report': os.path.basename(report_path),
        'verified': len(scored),
        'support_status_counts': dict(status_counts),
        'factual_unsupported': factual_unsupported,
        'factual_not_supported': factual_not_supported,
        'total_factual': len(factual),
        'unsupported_rate': round(factual_not_supported / max(len(factual), 1), 3),
    }, indent=2))

    if not passed:
        sys.exit(1)


def cmd_report(args: argparse.Namespace) -> None:
    """Generate human-readable support verification report."""
    claims_path = os.path.join(args.dir, 'claims.jsonl')
    unique = _unique_claims(read_jsonl(claims_path))

    lines = ['# Claim Support Verification Report', '']

    # Summary
    status_counts = Counter(c.get('support_status') for c in unique)
    type_counts = Counter(c.get('claim_type') for c in unique)
    lines.append(f'**Total claims:** {len(unique)}')
    lines.append(f'**By type:** {dict(type_counts)}')
    lines.append(f'**By status:** {dict(status_counts)}')
    lines.append('')

    # Factual claims that are not fully supported (the strict-gate failures)
    unsupported_factual = [
        c for c in unique
        if c.get('claim_type') == 'factual'
        and c.get('support_status') in ('unsupported', 'needs_review', 'partial')
    ]
    if unsupported_factual:
        lines.append('## Unsupported/Review-needed Factual Claims')
        lines.append('')
        for c in unsupported_factual:
            lines.append(f'- [{c["support_status"]}] `{c.get("section_id", "")}`: {c.get("text", "")[:100]}...')
            if c.get('_support_notes'):
                lines.append(f'  Notes: {c["_support_notes"]}')
        lines.append('')

    # All clear
    if not unsupported_factual:
        lines.append('## All factual claims have adequate support.')
        lines.append('')

    print('\n'.join(lines))


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        prog='verify_claim_support',
        description='Claim-support verification for deep-research v3.0',
    )
    sub = parser.add_subparsers(dest='command', required=True)

    # verify
    p_ver = sub.add_parser('verify', help='Verify claims against evidence')
    p_ver.add_argument('--dir', required=True, help='Run directory')
    p_ver.add_argument('--report', help=f'Report markdown (default: the manifest report or {REPORT_NAME})')
    p_ver.add_argument('--strict', action='store_true', help='Exit 1 unless every factual claim is supported')

    # report
    p_rep = sub.add_parser('report', help='Generate verification report')
    p_rep.add_argument('--dir', required=True, help='Run directory')

    args = parser.parse_args()
    dispatch = {
        'verify': cmd_verify,
        'report': cmd_report,
    }
    try:
        dispatch[args.command](args)
    except JsonlError as exc:
        print(json.dumps({'error': str(exc)}), file=sys.stderr)
        sys.exit(2)


if __name__ == '__main__':
    main()
