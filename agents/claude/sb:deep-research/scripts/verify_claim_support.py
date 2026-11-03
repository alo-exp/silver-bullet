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

# Extract capitalized entities (naive NER)
# Capitalised phrases (Acme Corp), acronyms (AWS, IBM, SAP) and camelCase brands (GitHub, OpenAI, iPhone).
ENTITY_RE = re.compile(
    r'\b(?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*|[A-Z]{2,}[a-z]*|[A-Z][a-z]+[A-Z]\w*|[a-z]+[A-Z]\w*)\b'
)

# Negation cues. A claim and the quote clause it matches must agree on negation, otherwise
# "does not guarantee zero downtime" would count as support for "guarantees zero downtime".
NEGATION_RE = re.compile(
    r"\b(?:not|no|never|none|neither|nor|without|cannot|fails? to|unable to|lacks?)\b|n't\b",
    re.IGNORECASE,
)
CLAUSE_SPLIT_RE = re.compile(r'[.;:!?,]|\bbut\b|\bhowever\b|\balthough\b', re.IGNORECASE)

# Common stop entities to ignore
STOP_ENTITIES = frozenset([
    'The', 'This', 'That', 'These', 'However', 'Furthermore',
    'Moreover', 'Additionally', 'Therefore', 'Nevertheless',
])

# Weights of the feature classes; renormalised over the classes the claim actually contains,
# so a class the claim lacks is neutral rather than a free full match.
WEIGHTS = {'tokens': 0.4, 'numbers': 0.25, 'years': 0.15, 'entities': 0.2}
SUPPORTED_SCORE = 0.6
PARTIAL_SCORE = 0.35
MIN_TOKEN_OVERLAP = 0.3


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
    """Extract capitalized entity mentions."""
    ents = set(ENTITY_RE.findall(text))
    return ents - STOP_ENTITIES


def _fraction_present(wanted: set[str], have: set[str]) -> float:
    return len(wanted & have) / len(wanted)


def _entity_coverage(entities: set[str], quote: str) -> float:
    """Share of claim entities named in the quote (whole words, any case)."""
    lower = quote.lower()
    found = sum(1 for e in entities if re.search(r'\b' + re.escape(e.lower()) + r'\b', lower))
    return found / len(entities)


def _negation_conflict(claim_text: str, quote: str) -> bool:
    """True when the claim and the best-matching clause of the quote disagree on negation."""
    claim_tokens = extract_tokens(claim_text)
    best, best_overlap = '', 0
    for clause in CLAUSE_SPLIT_RE.split(quote):
        overlap = len(claim_tokens & extract_tokens(clause))
        if overlap > best_overlap:
            best, best_overlap = clause, overlap
    if not best_overlap:
        return False
    return bool(NEGATION_RE.search(claim_text)) != bool(NEGATION_RE.search(best))


def compute_support_score(claim_text: str, evidence_quotes: list[str]) -> tuple[str, float, str]:
    """
    Compute support status for a claim given its linked evidence quotes.

    Returns (status, score, notes). A claim is 'supported' only when the best quote scores at
    least 0.6, shares at least 30% of the claim's significant words, and contains every number,
    year and named entity of the claim: a missing one counts as non-support.
    """
    if not evidence_quotes:
        return ('unsupported', 0.0, 'no evidence linked')

    # Inline citation markers such as [1] or [2, 3] are references, not claimed numbers.
    claim_text = INLINE_CITATION_RE.sub(' ', claim_text)
    claim_tokens = extract_tokens(claim_text)
    claim_numbers = extract_numbers(claim_text)
    claim_years = extract_years(claim_text)
    claim_entities = extract_entities(claim_text)

    best: tuple[float, bool, list[str]] = (-1.0, False, [])
    for quote in evidence_quotes:
        token_overlap = _fraction_present(claim_tokens, extract_tokens(quote)) if claim_tokens else 0.0
        parts = [('tokens', token_overlap)]
        notes: list[str] = []
        complete = token_overlap >= MIN_TOKEN_OVERLAP
        if token_overlap < MIN_TOKEN_OVERLAP:
            notes.append('low lexical overlap')
        for name, wanted, measure, note in (
            ('numbers', claim_numbers, lambda w: _fraction_present(w, extract_numbers(quote)), 'number mismatch'),
            ('years', claim_years, lambda w: _fraction_present(w, extract_years(quote)), 'year mismatch'),
            ('entities', claim_entities, lambda w: _entity_coverage(w, quote), 'entity mismatch'),
        ):
            if not wanted:
                continue
            value = measure(wanted)
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
