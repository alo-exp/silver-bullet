#!/usr/bin/env python3
"""
Claim-Support Verification — checks whether evidence supports claims.

CLI subcommands:
  verify       Check all claims against evidence, update support_status
  report       Generate a support verification summary

Version 1 is deterministic and cheap: no LLM calls, no semantics. The rule is a strict near-quote:

* ``supported``: the claim repeats the cited quote word for word. Only case, punctuation, articles and
  other stopwords, simple inflection (plural, -s/-ed/-ing of one stem), a tiny table of exact aliases and
  the written form of a number ("40 percent", "five thousand") may differ. The words, figures, dates and
  units must come in the same order. Any rewording, reordering, voice change or paraphrase is
  ``needs_review``, never ``supported``.
* ``contradicted``: only a clear conflict, which is the same sentence with an explicit "not"/"never"
  added or removed, or the same sentence with one exact figure replaced by another of the same kind.
* ``unsupported``: no cited quote shares enough words with the claim to address it.
* ``needs_review``: everything else. A reader checks it against the source.

--strict exits 1 on 'contradicted' and 'unsupported' factual claims and lists 'needs_review' ones for a
reader to check against the source. Synthesis/recommendation need traceability but softer thresholds;
speculation and bibliography rows are 'not_applicable'.
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


# ---------------------------------------------------------------------------
# Words: what may differ between a claim and its quote
# ---------------------------------------------------------------------------

# Articles and other function words that carry no claim of their own.
STOPWORDS = frozenset('a an the its their this that these those also'.split())
# A figure: optional currency (a symbol or a letter-prefixed dollar such as A$), digits with thousands
# separators and decimals, then an optional % / k / M / bn / x / + marker. Words keep trailing digits (Q3, EC2).
TOKEN_RE = re.compile(
    r'(?:[a-z]{1,2}\$|[$€£¥₹₩])?\d[\d,]*(?:\.\d+)?(?:%|[kmb]n?(?![a-z0-9])|x(?![a-z0-9])|\+)?'
    r'|[a-z]+\d*')
FIGURE_RE = re.compile(r'(?:[a-z]{0,2}[$\u20ac\u00a3\u00a5\u20b9\u20a9]|\d)')
NEGATORS = frozenset(['not', 'never'])
AUXILIARIES = frozenset(['do', 'does', 'did'])
MIN_OVERLAP = 0.3  # share of the claim's words that must appear in a quote for it to address the claim


def _stem(word: str) -> str:
    """Light stemmer: plural/-ed/-ing endings and a final -e ("employees" == "employee")."""
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


# Exact aliases, by stem. Deliberately tiny: anything looser is a paraphrase and goes to a reader.
ALIASES = {_stem(a): _stem(b) for a, b in (('staff', 'employee'), ('client', 'customer'), ('are', 'is'), ('am', 'is'))}


def _words(text: str) -> list[str]:
    """The lowercase words and figures of a text, in order. Contractions are opened up ("doesn't" is
    "does not") and the possessive 's is dropped."""
    text = normalize_text(INLINE_CITATION_RE.sub(' ', text)).lower()
    text = re.sub(r"\bcannot\b", 'can not', text)
    text = re.sub(r"\bwon't\b", 'will not', text)
    text = re.sub(r"n't\b", ' not', text)
    text = re.sub(r"'s\b", '', text)
    return [w.replace(',', '') for w in TOKEN_RE.findall(text)]


def _is_figure(word: str) -> bool:
    return bool(FIGURE_RE.match(word))


def _shape(word: str) -> str:
    """A figure without its digits: "$50m" and "$20m" share a shape, "30%" and "30" do not."""
    return re.sub(r'\d[\d.]*', '#', word)


def _key(word: str) -> str:
    """The form in which two words count as the same: figures exactly, other words by stem and alias."""
    if _is_figure(word):
        return word
    stem = _stem(word)
    return ALIASES.get(stem, stem)


def _keys(words: list[str]) -> list[str]:
    return [_key(w) for w in words if w not in STOPWORDS]


def _without_negation(words: list[str]) -> Optional[list[str]]:
    """The words with every "not"/"never" (and the "do/does/did" before it) removed; None if there is none."""
    kept = []
    for word in words:
        if word in NEGATORS:
            if kept and kept[-1] in AUXILIARIES:
                kept.pop()
        else:
            kept.append(word)
    return kept if len(kept) < len(words) else None


def _figure_conflict(claim: list[str], quote: list[str]) -> bool:
    """The same sentence with one or more exact figures replaced by figures of the same kind."""
    if len(claim) != len(quote):
        return False
    differing = [(c, q) for c, q in zip(claim, quote) if c != q]
    return (bool(differing) and len(claim) - len(differing) >= 2
            and all(_is_figure(c) and _is_figure(q) and _shape(c) == _shape(q) for c, q in differing))


def _inside(part: list[str], whole: list[str]) -> bool:
    """Do the words of ``part`` appear in ``whole`` as one unbroken run?"""
    return any(whole[i:i + len(part)] == part for i in range(len(whole) - len(part) + 1))


def _assess_quote(claim_words: list[str], quote: str) -> dict:
    """Judge one claim against one quote. Returns the share of the claim's words found in the quote
    (``overlap``), whether the quote is a near-verbatim match (``match``), what clearly contradicts the claim
    (``conflict``) and why a reader must look (``reason``)."""
    quote_words = _words(quote)
    claim, source = _keys(claim_words), _keys(quote_words)
    overlap = len(set(claim) & set(source)) / len(set(claim))
    result = {'overlap': overlap, 'match': claim == source, 'conflict': '', 'reason': ''}
    if result['match']:
        return result
    stripped_claim, stripped_quote = _without_negation(claim_words), _without_negation(quote_words)
    if stripped_claim is not None and stripped_quote is None and _keys(stripped_claim) == source:
        result['conflict'] = 'the claim negates what the source says'
    elif stripped_quote is not None and stripped_claim is None and _keys(stripped_quote) == claim:
        result['conflict'] = 'the source negates what the claim says'
    elif _figure_conflict(claim, source):
        wrong = [f'{c} (source: {q})' for c, q in zip(claim, source) if c != q]
        result['conflict'] = 'the source gives a different figure: ' + ', '.join(wrong)
    elif _inside(claim, source):
        result['reason'] = ('the claim repeats only part of the source text: quote just the span that supports it, '
                            'or make the claim say all of it')
    elif _inside(source, claim):
        result['reason'] = 'the claim says more than the source text: the extra words are not in the quote'
    elif sorted(claim) == sorted(source):
        result['reason'] = 'the source has the same words in a different order (reordered or changed voice)'
    else:
        result['reason'] = (f'reworded, not a near-quote: {round(overlap * 100)}% of the claim\'s words are in the '
                            'source')
    return result


def compute_support_score(claim_text: str, evidence_quotes: list[str]) -> tuple[str, float, str]:
    """
    Judge a claim against its linked evidence quotes. Returns (status, score, notes).

    * ``supported`` only when the claim nearly repeats one quote word for word (see the module
      docstring) and no other quote contradicts it. The score is 1.0.
    * ``contradicted`` when a quote is that same sentence with an explicit "not"/"never" added or removed, or
      with one exact figure replaced, and no quote supports the claim.
    * ``unsupported`` when no quote shares at least 30% of the claim's words.
    * ``needs_review`` otherwise, with the reason (reworded, reordered, only part of the quote). A reader must
      check these against the source; they are never counted as supported.
    """
    if not evidence_quotes:
        return ('unsupported', 0.0, 'no evidence linked')
    claim_words = _words(claim_text)
    if not _keys(claim_words):
        return ('needs_review', 0.0, 'the claim has no words to check')
    assessed = [_assess_quote(claim_words, q) for q in evidence_quotes]
    supporting = [a for a in assessed if a['match']]
    contradicting = [a for a in assessed if a['conflict']]
    if supporting and contradicting:
        return ('needs_review', 1.0, 'conflicting evidence: one quote supports the claim, another says: '
                + contradicting[0]['conflict'])
    if supporting:
        return ('supported', 1.0, 'near-verbatim match')
    if contradicting:
        return ('contradicted', round(max(a['overlap'] for a in contradicting), 3),
                '; '.join(a['conflict'] for a in contradicting))
    best = max(assessed, key=lambda a: a['overlap'])
    if best['overlap'] < MIN_OVERLAP:
        return ('unsupported', round(best['overlap'], 3),
                f'only {round(best["overlap"] * 100)}% of the claim\'s words appear in the source')
    return ('needs_review', round(best['overlap'], 3), best['reason'])


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
