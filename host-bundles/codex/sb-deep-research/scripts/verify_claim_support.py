#!/usr/bin/env python3
"""
Claim-Support Verification — checks whether evidence supports claims.

CLI subcommands:
  verify       Check all claims against evidence, update support_status
  report       Generate a support verification summary

Version 1 is deterministic and cheap: entity, number, date, and
lexical-overlap checks over stored evidence. No LLM calls.

Verdicts are three-valued: 'supported' only when lexical support is unambiguous,
'contradicted' when a quote clearly says the opposite, 'needs_review' (with the figure, entity or
polarity at issue) for everything ambiguous; 'unsupported' means no evidence addresses the claim.
--strict exits 1 on 'contradicted' and 'unsupported' factual claims and lists 'needs_review' ones
for a reader to check against the source. Synthesis/recommendation need traceability but softer
thresholds; speculation and bibliography rows are 'not_applicable'.
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
# A lone "one" is a quantity only when a range runs on from it ("one to three days", "one or two",
# "between one and three"); elsewhere it is a pronoun or a name ("one who", "one-to-one").
ONE_RANGE_RE = re.compile(
    r'\b(?:(between\s+)one(?=\s+and\s+)|one(?=\s+(?:to|or)\s+(?:\d|(?:' + _NUM_FIRST + r')\b)))', re.IGNORECASE)


def _compound(text: str, force: bool = False) -> str:
    """The value of one run of number words ("one hundred and twenty" -> "120")."""
    words = re.findall(r'[a-z]+', text.lower())
    if words in (['one'], ['zero']) and not force:  # "one who", "zero downtime": not quantities
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


def _words_to_number(match: 're.Match') -> str:
    """"and" joins number words only inside a compound ("two hundred and five", "one thousand and
    one"); anywhere else it separates two numbers ("between two and five days" is 2 and 5, never 7)."""
    text = match.group(0)
    previous = ''
    for word in re.finditer(r'[A-Za-z]+', text):
        if word.group(0).lower() == 'and' and previous not in _MULT:
            head, rest = text[:word.start()], text[word.start():]
            forced = bool(re.match(r'and\s+(?:\d|(?:' + _NUM_ANY + r')\b)', rest, re.IGNORECASE))
            return _compound(head, forced) + NUMBER_WORDS_RE.sub(_words_to_number, rest)
        previous = word.group(0).lower()
    return _compound(text)


def normalize_text(text: str) -> str:
    """NFKC, typographic quotes/dashes to ASCII, '40 percent' to '40%', 'USD 50' to '$50',
    'five thousand' to '5000', 'v1.29' to '1.29'."""
    import unicodedata
    text = unicodedata.normalize('NFKC', text).translate(_QUOTE_TABLE)
    text = ONE_RANGE_RE.sub(lambda m: (m.group(1) or '') + '1', text)
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
    ents = {e for e in ents if not _is_adverb(e)}
    return ents - STOP_ENTITIES


# ---------------------------------------------------------------------------
# Figures: value, unit, currency, and what each is attached to
# ---------------------------------------------------------------------------

# A figure: optional currency (a symbol, a letter-prefixed dollar such as A$ or C$, or an ISO code),
# digits with optional thousands separators and decimals, then an optional unit/scale (%, k, M, bn,
# million, ...). Digits glued to letters (EC2) are not figures.
FIGURE_RE = re.compile(
    r'(?<![\w.])([A-Z]{1,2}\$|[$\u20ac\u00a3\u00a5\u20b9\u20a9]|(?:JPY|CNY|RMB|INR|CHF|AUD|CAD|HKD|SGD|NZD|KRW)\s?)?'
    r'\s?(\d{1,3}(?:,\d{3})+|\d+)(\.\d+)?'
    r'(?:\s*(%|trillion|billion|million|thousand)\b|(%|bn|mn|[kKmMbBxX])(?![A-Za-z0-9]))?'
)
SCALES = {'k': 1e3, 'thousand': 1e3, 'm': 1e6, 'mn': 1e6, 'million': 1e6, 'b': 1e9, 'bn': 1e9,
          'billion': 1e9, 'trillion': 1e12}
# Currencies by canonical code. A bare yen sign is used for both the yen and the yuan: it is
# compatible with either, and with nothing else. Any other letter-prefixed dollar is its own currency.
CURRENCY_SYMBOLS = {'$': 'USD', 'US$': 'USD', '\u20ac': 'EUR', '\u00a3': 'GBP', '\u00a5': 'YEN-OR-YUAN', '\u20b9': 'INR',
                    '\u20a9': 'KRW', 'A$': 'AUD', 'C$': 'CAD', 'HK$': 'HKD', 'S$': 'SGD', 'NZ$': 'NZD', 'RMB': 'CNY'}
CURRENCY_WORDS = {'dollar': 'USD', 'dollars': 'USD', 'usd': 'USD', 'euro': 'EUR', 'euros': 'EUR', 'eur': 'EUR',
                  'pound': 'GBP', 'pounds': 'GBP', 'gbp': 'GBP', 'yen': 'JPY', 'jpy': 'JPY', 'yuan': 'CNY',
                  'renminbi': 'CNY', 'rmb': 'CNY', 'cny': 'CNY', 'rupee': 'INR', 'rupees': 'INR', 'inr': 'INR',
                  'franc': 'CHF', 'francs': 'CHF', 'chf': 'CHF'}


def _currency(raw: Optional[str]) -> Optional[str]:
    """Canonical currency code of a symbol or code written before a figure."""
    if not raw:
        return None
    raw = raw.strip()
    return CURRENCY_SYMBOLS.get(raw, raw)


def _currency_conflict(claim: Optional[str], quote: Optional[str]) -> bool:
    """Two stated currencies that cannot be the same one. A yen sign fits the yen and the yuan."""
    if not claim or not quote or claim == quote:
        return False
    return {claim, quote} not in ({'YEN-OR-YUAN', 'JPY'}, {'YEN-OR-YUAN', 'CNY'})


# Ranges: "between 2 and 5", "3 to 4", "3 or 4", "3-5". The connector becomes "~", so the two ends stay
# in one segment and are never confused with a single figure.
_RANGE_NUM = r'[$\u20ac\u00a3\u00a5\u20b9\u20a9]?\d[\d,]*(?:\.\d+)?(?:\s?(?:%|bn|mn|k|m|million|billion|trillion|thousand)\b)?'
RANGE_BETWEEN_RE = re.compile(r'\b(between\s+' + _RANGE_NUM + r')\s+and\s+(' + _RANGE_NUM + r')', re.IGNORECASE)
RANGE_TO_RE = re.compile(
    r'(?<![\w.\d-])(' + _RANGE_NUM + r')(?:\s+(?:to|or)\s+|-)(' + _RANGE_NUM + r')(?![\w-])', re.IGNORECASE)
# Words that carry no binding information next to a figure (articles, prepositions, auxiliaries,
# quantity hedges, dates and period words such as "fiscal", "year over year", months).
FILLER_WORDS = frozenset(
    'a an the of in on at to by for from with and or as per than over under about around nearly '
    'roughly approximately more less up down into across during since until while after before '
    'is are was were be been has have had its their his her our it that which who whose this these '
    'also now only just still about almost close fiscal year years yoy quarter month months week '
    'january february march april may june july august september october november december '
    'jan feb mar apr jun jul aug sep sept oct nov dec each every any all some '
    'reported reports said says according billion million thousand trillion percent between'.split()
) | frozenset(CURRENCY_WORDS)
# Verbs of change say how a figure moved, not what it measures ("revenue grew 30%").
CHANGE_WORDS = frozenset(
    'grow grew grown growth rise rose risen fall fell fallen drop dropped cut cuts increase increased '
    'decrease decreased reduce reduced decline declined jump jumped climb climbed gain gained lose lost '
    'shrink shrank expand expanded double doubled triple tripled reach reached hit total totals narrow narrowed '
    'widen widened improve improved surge surged soar soared plunge plunged slip slipped slide slid dip dipped '
    'swell swelled ease eased worsen worsened'.split())
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


CHANGE_STEMS = frozenset(_stem(w) for w in CHANGE_WORDS)

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
    r'(?<=[.;:!?])\s+|,(?!\s*\d)|[()]|\band\b|\bbut\b|\bwhile\b|\bwhereas\b|\bhowever\b|\balthough\b|\bwhich\b',
    re.IGNORECASE,
)
# Reporting periods are bound to a figure like years: "30% in Q3" is not "30% in Q2". "per <period>" and
# "a <period>" stay part of the unit: "$20 per month" is not "$20 per year".
PERIOD_RE = re.compile(r'\b(Q[1-4]|H[12]|FY\s?\d{2,4})\b')
PER_RE = re.compile(
    r'(?:\bper|/)\s*(month|year|annum|week|day|hour|quarter|minute|second)\b'
    r'|\b(?:an?|each|every)\s+(month|year|annum|week|day|hour|quarter)\b', re.IGNORECASE)


class Figure:
    """A figure with the words it is attached to."""

    __slots__ = ('value', 'kind', 'currency', 'noun', 'before', 'after', 'stems', 'rng', 'seg', 'raw',
                 'text', 'periods', 'per')

    def __init__(self, value, kind, currency, noun, before, after, stems=frozenset(), rng=None, seg=0, raw='',
                 text='', periods=frozenset(), per=frozenset()):
        self.value, self.kind, self.currency = value, kind, currency
        self.noun, self.before, self.after, self.stems = noun, before, after, stems
        self.rng, self.seg, self.raw = rng, seg, raw
        self.text, self.periods, self.per = text, periods, per

    def __getitem__(self, i):  # (value, kind, noun, before, after): the shape older callers use
        return (self.value, self.kind, self.noun, self.before, self.after)[i]

    def describe(self) -> str:
        """The figure as written, with the noun it is attached to ("7 days")."""
        return (self.raw + ' ' + (self.noun or '')).strip()


def _mark_ranges(text: str) -> str:
    text = RANGE_BETWEEN_RE.sub(lambda m: m.group(1) + ' ~ ' + m.group(2), text)
    return RANGE_TO_RE.sub(lambda m: m.group(1) + ' ~ ' + m.group(2), text)


def _segment_figures(text: str, drop: frozenset = frozenset(), seg: int = 0) -> list[Figure]:
    # Words naming the claim's entities are dropped: a shared subject ("Acme") says nothing about
    # what a figure belongs to.
    stems = frozenset(_stem(t) for t in extract_tokens(text) if t not in drop)
    out = []
    for m in FIGURE_RE.finditer(text):
        currency, whole, frac, word_unit, abbr = _currency(m.group(1)), m.group(2), m.group(3), m.group(4), m.group(5)
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
                  if not w.isdigit() and w.lower() not in FILLER_WORDS and _stem(w) not in CHANGE_STEMS][:3]
        rng = 'hi' if text[:m.start()].rstrip().endswith('~') else ('lo' if text[m.end():].lstrip().startswith('~') else None)
        per = frozenset(_stem('year' if (a or b).lower() == 'annum' else (a or b)) for a, b in PER_RE.findall(text[m.end():m.end() + 40]))
        periods = frozenset(re.sub(r'\s', '', p) for p in PERIOD_RE.findall(text))
        out.append(Figure(value, kind, currency, noun, tuple(before), tuple(after[:3]), stems, rng, seg, m.group(0).strip(),
                          text, periods, per))
    for low, high in zip(out, out[1:]):
        if low.rng == 'lo' and high.rng == 'hi':  # both ends of a range share the unit and the noun
            low.noun, low.after = high.noun, high.after
            low.currency, high.currency = low.currency or high.currency, high.currency or low.currency
    return out


def extract_figures(text: str, drop_entities: bool = False) -> list[Figure]:
    """Normalised figures. $50M and 50 million dollars are both 5e7 dollars; 2,500 is 2500.0,
    not {2, 500}; kind is 'year', '%', 'x' or 'num'. Each figure knows its segment's words, the
    first content word after it (``noun``) and the nearest content words on each side, and whether
    it is an end of a range. A segment with no content words of its own ("In 2019,") belongs to the
    segment that follows it."""
    text = _mark_ranges(normalize_text(text))
    drop = frozenset(w.lower() for e in extract_entities(text) for w in e.split()) if drop_entities else frozenset()
    figures: list[Figure] = []
    carried, index = '', 0
    for segment in SEGMENT_SPLIT_RE.split(text):
        if not segment or not segment.strip():
            continue
        segment = carried + segment
        if not {t for t in extract_tokens(segment) if t not in drop}:
            carried = segment + ' '  # an opener such as "In 2019," says only when: bind it to what follows
            continue
        carried = ''
        figures.extend(_segment_figures(segment, drop, index))
        index += 1
    if carried:
        figures.extend(_segment_figures(carried, drop, index))
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
    r"\b(?:not|no|never|none|neither|nor|nothing|nobody|nowhere|cannot|absent|unable to|lacks?|lacking|hardly|barely|scarcely"
    r"|fail(?:s|ed|ing)? to|refus(?:e|es|ed|ing) to)\b|n't\b",
    re.IGNORECASE,
)
NO_LONGER_RE = re.compile(r'\bno longer\b', re.IGNORECASE)
UN_RE = re.compile(r'\bun(available|supported|able|certified)\b', re.IGNORECASE)
NOT_ONLY_RE = re.compile(r'\bnot only\b|\bnot just\b', re.IGNORECASE)
# Phrases that contain a negation word but assert: "no fewer than 500", "not to mention Teams".
NEGATION_IDIOM_RE = re.compile(
    r'\b(?:no (?:fewer|less|more) than|not to mention|none other than|nothing (?:less|short) than|second to none)\b',
    re.IGNORECASE,
)
WITH_NO_RE = re.compile(r'\bwith no\b', re.IGNORECASE)
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
    """Normalised text for polarity: "unavailable" = "not available", "with no X" = "without X"
    (a term, not a negated clause), and assertive idioms such as "no fewer than" removed."""
    text = NEGATION_IDIOM_RE.sub(' ', UN_RE.sub(r'not \1', normalize_text(text)))
    return WITH_NO_RE.sub('without', text)


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


def _is_adverb(entity: str) -> bool:
    """A sentence-opening "-ly" word ("Quarterly", "Recently") is an adverb or adjective, not a name."""
    return entity.endswith('ly') and ' ' not in entity and entity.istitle() and len(entity) > 5


def _subject(claim_text: str) -> Optional[str]:
    for m in ENTITY_RE.finditer(claim_text):
        if m.group(0) not in STOP_ENTITIES and not _is_adverb(m.group(0)):
            return m.group(0)
    return None


def _want(clause: str, subject: Optional[str]) -> set[str]:
    skip = {x.lower() for x in (subject or '').split()} | {(subject or '').lower()}
    return {w.lower() for w in extract_entities(clause) if w.lower() not in skip}


LIST_SEPARATOR_RE = re.compile(r'\s*,\s*(?:(?:and|or)\s+)?|\s+(?:and|or)\s+')
# What follows a name that opens a new clause ("... and Initech does not", "... and Initech offers neither").
PREDICATE_AFTER_NAME_RE = re.compile(
    r"\s+(?:does|do|did|is|are|was|were|has|have|had|can|cannot|could|will|would|also|still|lacks?|offers?|supports?"
    r"|never|neither|\w+n't)\b")


def _variants(clause: str) -> list[str]:
    """The clause itself plus, for a coordinated list of named things, one variant per item
    ("supports Kubernetes and Nomad" -> "supports Kubernetes", "supports Nomad"). A name that is
    followed by a predicate ("SCIM and Initech does not") is the subject of the next clause, not a list
    item: it is left out of the list."""
    out = [clause]
    for m in ENTITY_LIST_RE.finditer(clause):
        end = m.end()
        if PREDICATE_AFTER_NAME_RE.match(clause, end):  # the match always holds a separator
            end = m.start(1) + list(LIST_SEPARATOR_RE.finditer(m.group(1)))[-1].start()
        items = [i.strip() for i in LIST_SEPARATOR_RE.split(clause[m.start(1):end]) if i.strip()]
        if len(items) > 1:
            out.extend(clause[:m.start()] + item + clause[end:] for item in items)
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


def _verb_stems(text: str) -> set[str]:
    """Stems of every word of three letters or more (the opposites table has "cut", "buy", "win")."""
    return {_stem(w) for w in re.findall(r'\b[a-z]{3,}\b', NEGATION_RE.sub(' ', text.lower()))}


def _antonym_conflict(claim_clause: str, quote_clause: str) -> bool:
    c, q = _verb_stems(claim_clause), _verb_stems(quote_clause)
    return any((c & left and q & right and not q & left) or (c & right and q & left and not q & right)
               for left, right in ANTONYM_PAIRS)


def _quantifier_conflict(claim_clause: str, quote_clause: str) -> bool:
    """"zero <thing>" / "without <thing>" ("with no <thing>" is "without") in one text but not the other,
    about the same thing."""
    claim_clause, quote_clause = _normalize_negation(claim_clause), _normalize_negation(quote_clause)
    for pattern in (ZERO_RE, WITHOUT_RE):
        c = {_stem(w) for m in pattern.findall(claim_clause) for w in (m if isinstance(m, tuple) else (m,)) if w}
        q = {_stem(w) for m in pattern.findall(quote_clause) for w in (m if isinstance(m, tuple) else (m,)) if w}
        if (q - c) & _stems(claim_clause) or (c - q) & _stems(quote_clause):
            return True
    return False


# "no more than 50" is not "more than 50": the idiom says the opposite of the bare comparative.
COMPARATIVE_IDIOM_RE = re.compile(r'\b(?:no|nothing)\s+(more|less|fewer)\s+than\b', re.IGNORECASE)


def _comparative_idioms(text: str) -> frozenset:
    return frozenset('most' if m == 'more' else 'least' for m in COMPARATIVE_IDIOM_RE.findall(normalize_text(text).lower()))


# Cues that make a sentence a plan, a hedge, a condition, an exception or a replacement rather than a
# plain statement of fact. A quote clause that carries one the claim does not is never plain support:
# the claim must be checked against the source (needs_review), whatever else matches.
ESCALATION_CUES = (
    ('a plan or expectation', re.compile(
        r"\b(?:plans?|planned|planning|aims?|intends?|expects?|expected|hopes?|seeks?|seeking|wants?|going|about|set|likely) to\b"
        r"|\b(?:will|would|shall|soon|upcoming|roadmap|considering|pursuing|proposed)\b", re.IGNORECASE)),
    ('a hedge', re.compile(r"\b(?:may|might|could|should|perhaps|possibly|probably|reportedly|allegedly|rumou?red)\b", re.IGNORECASE)),
    ('a condition or exception', re.compile(
        r"\b(?:if|unless|except|excluding|besides|other than|provided that)\b", re.IGNORECASE)),
    ('a replacement or earlier state', re.compile(
        r"\binstead of\b|\brather than\b|\bin place of\b|\breplac(?:e|es|ed|ing)\b|\bformerly\b|\bpreviously\b"
        r"|\bused to\b|\bswitch(?:ed|es|ing)? (?:from|away)\b", re.IGNORECASE)),
)
NO_LONGER_END_RE = re.compile(
    r'\bno longer\b|\b(?:retir(?:e|es|ed|ing)|discontinu(?:e|es|ed|ing)|end(?:s|ed|ing)?|stop(?:s|ped|ping)?'
    r'|dropp?(?:s|ed|ing)?|remov(?:e|es|ed|ing)|deprecat(?:e|es|ed|ing)|sunset(?:s|ting)?|withdr(?:aw|aws|awn|ew|awing)'
    r'|cancell?(?:s|ed|ing)?|phas(?:e|es|ed|ing) out)\b',
    re.IGNORECASE)
# A claim word that the quote writes with a negating prefix ("compliant" / "non-compliant", "encrypted" / "unencrypted").
NEGATING_PREFIX = r'(?:non-?|un-?|in-?|im-?|ir-?|il-?|dis-?)'


def _cues(text: str) -> set[str]:
    return {label for label, pattern in ESCALATION_CUES if pattern.search(text)}


def _prefixed_words(claim_clause: str, quote_clause: str) -> list[str]:
    """Words of the claim that the quote clause only has with a negating prefix."""
    claim_words = {w for w in re.findall(r'\b[a-z]{5,}\b', claim_clause.lower())}
    quote_lower = quote_clause.lower()
    claim_lower = claim_clause.lower()
    return sorted(
        w for w in claim_words
        if re.search(r'\b' + NEGATING_PREFIX + re.escape(w) + r'\b', quote_lower)
        and not re.search(r'\b' + NEGATING_PREFIX + re.escape(w) + r'\b', claim_lower)
    )


# Parts of a clause that can differ in polarity. "but"-like words open a contrast (a fresh scope);
# "and", "or" and a comma may continue a negated scope ("does not support SSO or SCIM").
CONTRAST_SPAN_RE = re.compile(r'\s*[,;]?\s*\b(?:but|yet|while|whereas)\b\s*', re.IGNORECASE)
SPAN_SPLIT_RE = re.compile(r'\s*[,;](?!\d)\s*(?:and\s+|or\s+)?|\s+(?:and|or)\s+', re.IGNORECASE)


def _squash(text: str) -> str:
    return re.sub(r'[^a-z0-9]+', ' ', text.lower()).strip()


def _spans(text: str) -> list[tuple[str, bool, bool]]:
    """The parts of a clause as (text, negated, certain). A part that follows a negated part
    without a cue of its own may be inside the same negation ("does not support SSO and SCIM") or
    outside it ("lacks SSO, offers SCIM"): its polarity is not certain."""
    out: list[tuple[str, bool, bool]] = []
    for block in CONTRAST_SPAN_RE.split(_normalize_negation(text)):
        previous_negated = False
        for i, part in enumerate(SPAN_SPLIT_RE.split(NOT_ONLY_RE.sub(' ', block))):
            if not part.strip():
                continue
            negated = bool(NEGATION_RE.search(part))
            out.append((part.strip(), negated, negated or not (i and previous_negated)))
            previous_negated = previous_negated or negated
    return out


def _terms(text: str) -> set[str]:
    return _stems(text) | {w.lower() for e in extract_entities(text) for w in e.split()}


def _covers(span: str, claim_span: str, subject: Optional[str]) -> bool:
    """Does a quote part state what a claim part says? It holds all of the claim part's terms; the
    claim's subject may be left out only when the quote part does not open with a name of its own (an elided subject)."""
    subject_words = {w.lower() for w in (subject or '').split()}
    have = _terms(span)
    if not (_terms(claim_span) - subject_words) <= have:
        return False
    return not subject_words or subject_words <= have or not re.match(r'\s*[A-Z]', span)


def _polarity(claim_clause: str, quote_clause: str, subject: Optional[str]) -> tuple[str, str]:
    """Compare the polarity of a claim clause with an aligned quote clause: ('agree' | 'conflict' |
    'ambiguous', detail). The quote part that states what the claim part says decides; when no part
    does, when the parts disagree, or when a polarity depends on how far a negation reaches, the
    result is 'ambiguous', never 'agree'."""
    if _squash(claim_clause) == _squash(quote_clause):
        return ('agree', '')
    if not _is_negated(claim_clause) and not _is_negated(quote_clause):
        return ('agree', '')
    quote_spans = _spans(quote_clause)
    verdict, detail = 'agree', ''
    for text, negated, certain in _spans(claim_clause):
        if not _terms(text) - {w.lower() for w in (subject or '').split()}:
            if negated:
                return ('ambiguous', f'cannot place the negation in "{text}"')
            continue
        anchors = quote_spans if len(quote_spans) == 1 else [q for q in quote_spans if _covers(q[0], text, subject)]
        if not anchors:
            return ('ambiguous', f'no part of the source states "{text}" on its own')
        if not certain or not all(a[2] for a in anchors) or len({a[1] for a in anchors}) > 1:
            return ('ambiguous', f'how far a negation reaches is unclear in "{anchors[0][0]}"')
        if anchors[0][1] != negated:
            verdict, detail = 'conflict', anchors[0][0]
    return (verdict, detail)


def _entity_order(text: str, entities: set[str]) -> list[str]:
    """The claim's entities in the order a clause mentions them."""
    found = [(m.start(), e) for e in entities for m in re.finditer(r'\b' + re.escape(e) + r'\b', text)]
    return [e for _, e in sorted(found)]


DATE_WORDS = frozenset(
    'January February March April May June July August September October November December '
    'Monday Tuesday Wednesday Thursday Friday Saturday Sunday'.split())
PASSIVE_RE = re.compile(r'(?i:\b(?:is|are|was|were|been|being|be)\s+\w+(?:ed|en)\s+by)\s+[A-Z]')


def _role_swap(claim_clause: str, quote_clause: str) -> bool:
    """The same named things with their roles possibly exchanged, which words alone cannot tell: two or
    more of the claim's names occur in the quote clause in another order (whatever stands between them:
    "Samsung overtook Apple", "owned by", "cheaper than", "migrated from X to Y", "invested in"), or one
    clause is passive ("Acme was acquired by Initech") and the other active. Dates are not roles."""
    entities = {e for e in extract_entities(claim_clause)
                if e in quote_clause and e not in DATE_WORDS and not re.search(r'\d\s*' + re.escape(e) + r'\b', claim_clause)}
    if len(entities) < 2:
        return False
    if bool(PASSIVE_RE.search(claim_clause)) != bool(PASSIVE_RE.search(quote_clause)):
        return True
    return _first_mentions(claim_clause, entities) != _first_mentions(quote_clause, entities)


def _first_mentions(text: str, entities: set[str]) -> list[str]:
    """The entities in the order of their first mention."""
    order = _entity_order(text, entities)
    return [e for i, e in enumerate(order) if e not in order[:i]]


def _names_subject(clause: str, quote_clause: str, subject: Optional[str]) -> bool:
    """Does the quote clause name the claim's subject, when the claim clause names it? A clause that
    does not name the subject ("It employs 400.") has nothing to check."""
    words = [w.lower() for w in (subject or '').split()]
    lower = clause.lower()
    if not words or not any(re.search(r'\b' + re.escape(w) + r'\b', lower) for w in words):
        return True
    opener = re.match(r'\s*([A-Z][\w.+-]*)', quote_clause)
    if not opener or opener.group(1) in STOP_ENTITIES:  # an elided subject ("Acme hashes and does not store ...")
        return True
    quote_lower = quote_clause.lower()
    quote_stems = {_stem(w) for w in WORD_RE.findall(quote_lower)}
    return all(re.search(r'\b' + re.escape(w) + r'\b', quote_lower) or _stem(w) in quote_stems for w in words)


def _negated_fragment(claim_clause: str, quote_clause: str) -> bool:
    """A negated part of the quote made only of words the (positive) claim uses: "liver and
    kidney" against "in the liver but not in the kidney"."""
    if _is_negated(claim_clause):
        return False
    claim_terms = _terms(claim_clause)
    for text, negated, _ in _spans(quote_clause):
        rest = _terms(NEGATION_RE.sub(' ', text))
        if negated and rest and rest <= claim_terms:
            return True
    return False


NOT_TOGETHER = 'no single source clause holds'


def _negation_findings(claim_text: str, quote: str) -> tuple[list[str], list[str]]:
    """(conflicts, ambiguities) between a claim and a quote. A conflict is a claim clause and an
    aligned quote clause that disagree on polarity, or "zero/without <thing>" against a plain
    assertion, or opposite verbs. An ambiguity is a polarity that cannot be decided from the words:
    the claim must then be checked against the source by a reader. Any clause of the whole quote
    can contradict."""
    claim_text, quote = normalize_text(claim_text), normalize_text(quote)
    subject = _subject(claim_text)
    quote_clauses = _clauses(quote)
    quote_squashed = {_squash(q) for q in quote_clauses}
    conflicts: list[str] = []
    ambiguities: list[str] = []

    def check(clause: str) -> bool:
        """Compare one claim clause with every aligned quote clause; whether a quote clause holds the whole
        clause (its names, figures and subject together) and so places it."""
        if _squash(clause) in quote_squashed:  # the clause as written: it cannot contradict itself
            return True
        # "no longer ..." may be worded in the quote as "retired"/"discontinued": no polarity check.
        check_polarity = not NO_LONGER_RE.search(clause)
        placed = False
        for variant in _variants(clause):
            claim_cues = _cues(variant)
            for q in quote_clauses:
                if not _aligned(variant, q, subject):
                    continue
                placed = placed or _names_subject(variant, q, subject)
                if check_polarity:
                    verdict, detail = _polarity(variant, q, subject)
                    if verdict == 'conflict':
                        conflicts.append(f'polarity: the source says "{q[:90]}"')
                    elif verdict == 'ambiguous':
                        ambiguities.append(f'polarity ambiguous in "{q[:90]}": {detail}')
                if _quantifier_conflict(variant, q) or _antonym_conflict(variant, q):
                    conflicts.append(f'the source says the opposite: "{q[:90]}"')
                elif _role_swap(variant, q):
                    ambiguities.append(f'roles may be swapped (the same names in another order): "{q[:90]}"')
                if _comparative_idioms(variant) != _comparative_idioms(q):
                    ambiguities.append(f'"no more/less than" is not "more/less than": "{q[:90]}"')
                for label in sorted(_cues(q) - claim_cues):
                    ambiguities.append(f'the source states {label}, the claim does not: "{q[:90]}"')
                if re.search(re.escape(q) + r'\s*\?', quote):
                    ambiguities.append(f'the source only asks: "{q[:90]}?"')
                for word in _prefixed_words(variant, q):
                    ambiguities.append(f'the source has "{word}" with a negating prefix: "{q[:90]}"')
        if check_polarity and any(_negated_fragment(clause, q) for q in quote_clauses):
            ambiguities.append(f'the source negates part of the claim: "{clause[:90]}"')
        return placed

    for claim_clause in _clauses(claim_text):
        if NO_LONGER_RE.search(claim_clause) and not NO_LONGER_END_RE.search(quote):
            ambiguities.append(f'the claim says "no longer" and the source does not: "{claim_clause[:90]}"')
        if check(claim_clause):
            continue
        # No quote clause states the whole clause: try its parts one by one ("was not profitable in
        # 2022, raised $50M in 2023" is two statements, each in its own quote sentence).
        parts = [text for text, _, _ in _spans(claim_clause)] if len(_spans(claim_clause)) > 1 else []
        unplaced = [part for part in parts if not check(part)] if parts else [claim_clause]
        for part in unplaced:
            if _is_negated(part):
                ambiguities.append(f'polarity ambiguous: no source clause states the negated "{part[:90]}"')
            elif _want(part, subject) or extract_figures(part) or len(_stems(part)) > 1:
                ambiguities.append(f'{NOT_TOGETHER} the names, figures and subject of "{part[:90]}"')
    if _quantifier_conflict(claim_text, quote):
        conflicts.append('the source says the opposite: "zero" or "without" against a plain statement')
    return conflicts, ambiguities


def _negation_conflict(claim_text: str, quote: str) -> bool:
    """True when the claim and the quote clearly disagree on polarity (see ``_negation_findings``)."""
    return bool(_negation_findings(claim_text, quote)[0])


# ---------------------------------------------------------------------------
# Scoring
# ---------------------------------------------------------------------------

def _fraction_present(wanted: set[str], have: set[str]) -> float:
    return len(wanted & have) / len(wanted)


def _missing_entities(entities: set[str], quote: str) -> list[str]:
    """Claim entities the quote does not name: whole words in any case, or the same word stems
    ("Webhooks" / "webhook")."""
    lower = quote.lower()
    quote_stems = {_stem(w) for w in WORD_RE.findall(lower)}
    return sorted(
        e for e in entities
        if not (re.search(r'\b' + re.escape(e.lower()) + r'\b', lower) or all(_stem(w) in quote_stems for w in e.split()))
    )


def _figure_matches(claim: Figure, quote: Figure, others: list[Figure]) -> bool:
    """Same value, kind, range position and (when the claim states one) currency, in a segment about
    the same thing.

    Years only need the segment to share a word ("founded in 2015" must not match "acquired in
    2015"). Other figures must also be attached to the same noun: the claim's noun follows the
    quote's figure (or precedes it: "Seats cost $20"), or, without a noun, the claim's nearest
    content word (the metric, not a verb of change) is among the quote's. A quote figure whose
    nearest word is what the claim attaches to a *different* figure ("latency by 10%" vs "cost by
    30%") does not match. A figure that is an end of a range matches only the same end of a range
    ("7 days" is not "between 2 and 5 days"). A currency the claim states must be stated, and be
    the same, in the quote."""
    if claim.value != quote.value or claim.kind != quote.kind or claim.rng != quote.rng:
        return False
    if claim.currency and (not quote.currency or _currency_conflict(claim.currency, quote.currency)):
        return False
    if claim.stems and quote.stems and not claim.stems & quote.stems:
        return False
    if not claim.periods <= quote.periods or not claim.per <= quote.per:  # Q3 is not Q2, per month is not per year
        return False
    if claim.kind == 'year':
        return True
    if claim.noun is not None:
        return any(_same_noun(claim.noun, w) for w in quote.after[:2] + quote.before[:2])
    if not claim.before or not quote.before:
        return True
    if any(o is not claim and o.before and o.before[0] == quote.before[0] != claim.before[0] for o in others):
        return False
    return any(_same_noun(claim.before[0], w) for w in quote.before[:2])


def _bound(claim: Figure, quote: Figure, claim_figs: list[Figure], quote_figs: list[Figure]) -> bool:
    """A year is bound to what happened in it: every other figure of the claim's segment must be
    matched in the quote's segment of that year ("300 employees by 2021 and 100 in 2019" does not
    say 300 employees in 2019)."""
    return all(
        any(h.seg == quote.seg and _figure_matches(g, h, claim_figs) for h in quote_figs)
        for g in claim_figs if g.seg == claim.seg and g is not claim and g.kind != 'year'
    )


def _belongs_elsewhere(figure: Figure, claim_text: str, quote_text: str, subject: Optional[str]) -> bool:
    """Is a quote figure attached to another name? Its segment ("Initech has 500 employees") names
    something the claim does not mention and not the claim's subject. A subject the quote never names is
    reported as a missing entity instead."""
    words = {w.lower() for w in (subject or '').split()}
    if not words or words <= set(WORD_RE.findall(figure.text.lower())) or not words <= set(WORD_RE.findall(quote_text.lower())):
        return False
    claim_words = set(WORD_RE.findall(claim_text.lower()))
    return bool({w.lower() for e in extract_entities(figure.text) for w in e.split()} - claim_words)


def _figures_supported(claim_text: str, quote_text: str, kinds) -> tuple[int, int, list[Figure]]:
    """(matched, total, unmatched) of the claim's figures of the given kinds. A quote figure that sits in
    another name's segment does not count."""
    claim_figs = extract_figures(claim_text, drop_entities=True)
    quote_figs = extract_figures(quote_text)
    subject = _subject(claim_text)
    wanted = [f for f in claim_figs if f.kind in kinds]
    missing = [
        f for f in wanted
        if not any(_figure_matches(f, q, claim_figs) and (f.kind != 'year' or _bound(f, q, claim_figs, quote_figs))
                   and not _belongs_elsewhere(q, claim_text, quote_text, subject)
                   for q in quote_figs)
    ]
    return len(wanted) - len(missing), len(wanted), missing


def _assess_quote(claim_text: str, quote: str, claim_tokens: set[str], claim_entities: set[str],
                  claim_figs: list[Figure]) -> dict:
    """Judge one claim against one quote. Returns the score, whether every lexical check passed
    (``complete``), what contradicts the claim (``conflicts``) and what is ambiguous or missing
    (``reasons``, each naming the figure, entity or polarity at issue)."""
    quote = normalize_text(quote)
    token_overlap = _fraction_present(claim_tokens, extract_tokens(quote)) if claim_tokens else 0.0
    parts = [('tokens', token_overlap)]
    reasons: list[str] = []
    shares = False  # does the quote share a named thing or a figure with the claim?
    # A claim with no named thing and no figure is judged on its words alone: nearly all must appear.
    needed = MIN_TOKEN_OVERLAP if (claim_entities or claim_figs) else PROSE_TOKEN_OVERLAP
    complete = token_overlap >= needed
    if not complete:
        reasons.append(f'low lexical overlap ({round(token_overlap * 100)}% of the claim\'s significant words)')
    for name, kinds, label in (('numbers', ('num', '%', 'x'), 'figure'), ('years', ('year',), 'year')):
        matched, total, missing = _figures_supported(claim_text, quote, kinds)
        if total:
            shares = shares or matched > 0
            parts.append((name, matched / total))
            if missing:
                complete = False
                reasons.append(
                    f'{label} not matched in the source: '
                    + ', '.join(f.describe() for f in missing))
    if claim_entities:
        absent = _missing_entities(claim_entities, quote)
        shares = shares or len(absent) < len(claim_entities)
        parts.append(('entities', 1 - len(absent) / len(claim_entities)))
        if absent:
            complete = False
            reasons.append('entity not found in the source: ' + ', '.join(absent))
    conflicts, ambiguities = _negation_findings(claim_text, quote)
    # Words, figures and names that are not together in one source clause matter only when nothing else
    # is already missing: the other reasons say more.
    apart = [a for a in ambiguities if a.startswith(NOT_TOGETHER)]
    ambiguities = [a for a in ambiguities if a not in apart]
    if ambiguities:
        complete = False
        reasons.extend(ambiguities)
    score = sum(WEIGHTS[name] * value for name, value in parts) / sum(WEIGHTS[name] for name, _ in parts)
    if not reasons and score < SUPPORTED_SCORE:
        reasons.append(f'too few of the claim\'s words appear in the source (score {round(score, 2)})')
    if apart and not reasons:
        complete = False
        reasons.extend(apart)
    return {'score': score, 'addresses': shares or score >= PARTIAL_SCORE, 'complete': complete and score >= SUPPORTED_SCORE and not conflicts,
            'conflicts': conflicts, 'reasons': reasons}


def compute_support_score(claim_text: str, evidence_quotes: list[str]) -> tuple[str, float, str]:
    """
    Judge a claim against its linked evidence quotes. Returns (status, score, notes).

    * ``supported`` only when lexical support is unambiguous in one quote: it scores at least 0.6,
      shares at least 30% of the claim's significant words, names every entity of the claim,
      matches every figure (same value, unit, currency and range position, attached to the same
      noun, years bound to the event) and no aligned clause has a polarity that differs or is
      ambiguous. No other quote may contradict it.
    * ``contradicted`` when a quote clearly says the opposite (a differing polarity in an aligned
      clause, zero/without against a plain assertion, opposite verbs) and no quote supports it.
    * ``unsupported`` when no quote shares a named thing, a figure or enough words with the claim.
    * ``needs_review`` otherwise, with the figure, entity or polarity that could not be settled.
      A reader must check these against the source; they are never counted as supported.
    """
    if not evidence_quotes:
        return ('unsupported', 0.0, 'no evidence linked')

    # Inline citation markers such as [1] or [2, 3] are references, not claimed numbers.
    claim_text = normalize_text(INLINE_CITATION_RE.sub(' ', claim_text))
    claim_tokens = extract_tokens(claim_text)
    claim_entities = extract_entities(claim_text)
    claim_figs = extract_figures(claim_text)

    assessed = [_assess_quote(claim_text, q, claim_tokens, claim_entities, claim_figs) for q in evidence_quotes]
    best = max(assessed, key=lambda a: a['score'])
    supporting = [a for a in assessed if a['complete']]
    contradicting = [a for a in assessed if a['conflicts']]
    if supporting and contradicting:
        return ('needs_review', round(best['score'], 3),
                'conflicting evidence: one quote supports the claim, another says ' + contradicting[0]['conflicts'][0])
    if supporting:
        return ('supported', round(max(a['score'] for a in supporting), 3), 'adequate overlap')
    if contradicting:
        worst = max(contradicting, key=lambda a: a['score'])
        return ('contradicted', round(worst['score'], 3), '; '.join(worst['conflicts']))
    notes = '; '.join(best['reasons']) or 'lexical support is not unambiguous'
    if not any(a['addresses'] for a in assessed):
        return ('unsupported', round(best['score'], 3), notes)
    return ('needs_review', round(best['score'], 3), notes)


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
        # Has cited sources but no evidence captured yet: nothing to check the claim against.
        claim['support_status'] = 'unsupported'
        claim['_support_notes'] = 'cited source has no captured evidence'
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
    factual_contradicted = sum(1 for c in factual if c.get('support_status') == 'contradicted')
    review = [c for c in factual if c.get('support_status') not in ('supported', 'unsupported', 'contradicted')]
    factual_not_supported = factual_unsupported + factual_contradicted + len(review)

    # Strict mode fails on a contradicted claim and on an unsupported or uncited factual claim.
    # needs_review claims do not fail it: they are listed for a reader to check against the source
    # (see "Resolving needs_review claims" in reference/quality-gates.md).
    passed = not (args.strict and (factual_unsupported or factual_contradicted))

    print(json.dumps({
        'status': 'pass' if passed else 'fail',
        'report': os.path.basename(report_path),
        'verified': len(scored),
        'support_status_counts': dict(status_counts),
        'factual_unsupported': factual_unsupported,
        'factual_contradicted': factual_contradicted,
        'factual_needs_review': len(review),
        'factual_not_supported': factual_not_supported,
        'total_factual': len(factual),
        'unsupported_rate': round(factual_not_supported / max(len(factual), 1), 3),
        'review_required': bool(review),
        'needs_review': [{'claim_id': c.get('claim_id'), 'text': c.get('text', '')[:200],
                          'reason': c.get('_support_notes', '')} for c in review],
    }, indent=2))

    if review:
        print(f'{len(review)} factual claim(s) need review: check each against its source '
              f'(run: verify_claim_support.py report --dir DIR)', file=sys.stderr)
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

    factual = [c for c in unique if c.get('claim_type') == 'factual']
    sections = (
        ('contradicted', '## Contradicted Factual Claims (the source says the opposite: fix the claim)'),
        ('unsupported', '## Unsupported Factual Claims (no usable evidence: add a source or remove the claim)'),
        ('needs_review', '## Needs Review (check each against its source before relying on it)'),
    )
    flagged = False
    for status, heading in sections:
        rows = [c for c in factual if c.get('support_status') == status]
        if status == 'needs_review':
            rows += [c for c in factual if c.get('support_status') == 'partial']  # legacy status
        if not rows:
            continue
        flagged = True
        lines += [heading, '']
        for c in rows:
            lines.append(f'- [{c["support_status"]}] `{c.get("section_id", "")}`: {c.get("text", "")[:100]}...')
            if c.get('_support_notes'):
                lines.append(f'  Notes: {c["_support_notes"]}')
        if status == 'needs_review':
            lines += ['', 'Resolve each item: quote the exact span of the source that supports the claim '
                          '(add it as evidence), or correct the claim to what the source says, then re-run verify.']
        lines.append('')

    # All clear
    if not flagged:
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
    p_ver.add_argument('--strict', action='store_true',
                       help='Exit 1 on a contradicted claim or an unsupported/uncited factual claim; needs_review claims are listed')

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
