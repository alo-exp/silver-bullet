#!/usr/bin/env python3
"""
Claim-Support Verification — checks whether evidence supports claims.

CLI subcommands:
  verify       Check all claims against evidence, update support_status
  report       Generate a support verification summary

Version 1 is deterministic and cheap: entity, number, date, and
lexical-overlap checks over stored evidence. No LLM calls.

Only factual claims hard-fail on unsupported status.
Synthesis/recommendation need traceability but softer thresholds.
"""

import argparse
import json
import os
import re
import sys
from collections import Counter
from datetime import datetime, timezone
from glob import glob
from hashlib import sha256
from typing import Optional
from urllib.parse import urlparse, urlunparse


# ---------------------------------------------------------------------------
# JSONL helpers
# ---------------------------------------------------------------------------

def read_jsonl(path: str) -> list[dict]:
    rows = []
    if not os.path.exists(path):
        return rows
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                rows.append(json.loads(line))
    return rows


def write_jsonl(path: str, rows: list[dict]) -> None:
    with open(path, 'w') as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + '\n')


# ---------------------------------------------------------------------------
# Support verification logic
# ---------------------------------------------------------------------------

# Extract numbers (integers and decimals)
NUMBER_RE = re.compile(r'\b\d+(?:\.\d+)?(?:%|x|X)?\b')

# Extract year-like numbers
YEAR_RE = re.compile(r'\b(19|20)\d{2}\b')

# Extract capitalized entities (naive NER)
ENTITY_RE = re.compile(r'\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)*\b')

# Common stop entities to ignore
STOP_ENTITIES = frozenset([
    'The', 'This', 'That', 'These', 'However', 'Furthermore',
    'Moreover', 'Additionally', 'Therefore', 'Nevertheless',
])


def extract_tokens(text: str) -> set[str]:
    """Extract significant lowercase tokens (>3 chars)."""
    words = re.findall(r'\b[a-z]{4,}\b', text.lower())
    return set(words)


def extract_numbers(text: str) -> set[str]:
    """Extract numeric values."""
    return set(NUMBER_RE.findall(text))


def extract_years(text: str) -> set[str]:
    """Extract year mentions."""
    return set(YEAR_RE.findall(text))


def extract_entities(text: str) -> set[str]:
    """Extract capitalized entity mentions."""
    ents = set(ENTITY_RE.findall(text))
    return ents - STOP_ENTITIES


def compute_support_score(claim_text: str, evidence_quotes: list[str]) -> tuple[str, float, str]:
    """
    Compute support status for a claim given its linked evidence quotes.

    Returns (status, score, notes).
    Score range: 0.0 (no overlap) to 1.0 (strong support).
    """
    if not evidence_quotes:
        return ('unsupported', 0.0, 'no evidence linked')

    claim_tokens = extract_tokens(claim_text)
    claim_numbers = extract_numbers(claim_text)
    claim_years = extract_years(claim_text)
    claim_entities = extract_entities(claim_text)

    best_score = 0.0
    best_notes = []

    for quote in evidence_quotes:
        ev_tokens = extract_tokens(quote)
        ev_numbers = extract_numbers(quote)
        ev_years = extract_years(quote)
        ev_entities = extract_entities(quote)

        # Token overlap (Jaccard-like)
        if claim_tokens:
            token_overlap = len(claim_tokens & ev_tokens) / len(claim_tokens)
        else:
            token_overlap = 0.0

        # Number match
        if claim_numbers:
            number_match = len(claim_numbers & ev_numbers) / len(claim_numbers)
        else:
            number_match = 1.0  # No numbers to check

        # Year match
        if claim_years:
            year_match = len(claim_years & ev_years) / len(claim_years)
        else:
            year_match = 1.0

        # Entity match
        if claim_entities:
            entity_match = len(claim_entities & ev_entities) / len(claim_entities)
        else:
            entity_match = 1.0

        # Weighted composite
        score = (
            0.4 * token_overlap +
            0.25 * number_match +
            0.15 * year_match +
            0.2 * entity_match
        )

        if score > best_score:
            best_score = score
            best_notes = []
            if token_overlap < 0.3:
                best_notes.append('low lexical overlap')
            if claim_numbers and number_match < 0.5:
                best_notes.append('number mismatch')
            if claim_years and year_match < 1.0:
                best_notes.append('year mismatch')
            if claim_entities and entity_match < 0.3:
                best_notes.append('entity mismatch')

    # Threshold decision
    if best_score >= 0.6:
        status = 'supported'
    elif best_score >= 0.35:
        status = 'partial'
    else:
        status = 'needs_review'

    notes = '; '.join(best_notes) if best_notes else 'adequate overlap'
    return (status, round(best_score, 3), notes)

TRACKING_PARAMS = frozenset([
    'utm_source', 'utm_medium', 'utm_campaign', 'utm_term', 'utm_content',
    'ref', 'source', 'fbclid', 'gclid', 'mc_cid', 'mc_eid',
])


def canonicalize_locator(raw_url: str) -> str:
    """Derive a canonical locator from a raw URL or identifier string.

    Mirrors citation_manager.py behavior to keep source_id matching stable.
    """
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
BIB_ENTRY_RE = re.compile(r'^\[(\d+)\]\s+')
MD_LINK_URL_RE = re.compile(r'\]\((https?://[^)\s]+)\)')
INLINE_CITATION_RE = re.compile(r'\[(\d+(?:,\s*\d+)*)\]')


def _find_report_path(run_dir: str) -> Optional[str]:
    """Locate the markdown report file for a run directory."""
    # Prefer run_manifest.json's artifact_paths.report if it exists and is valid.
    manifest_path = os.path.join(run_dir, 'run_manifest.json')
    if os.path.exists(manifest_path):
        try:
            with open(manifest_path) as f:
                manifest = json.load(f)
            rel = (manifest.get('artifact_paths') or {}).get('report')
            if rel:
                cand = os.path.join(run_dir, rel)
                if os.path.exists(cand):
                    return cand
        except Exception:
            # Fall back to glob-based discovery below.
            pass

    # Common deep-research convention.
    cands = glob(os.path.join(run_dir, 'research_report_*.md'))
    if len(cands) == 1:
        return cands[0]
    if len(cands) > 1:
        cands.sort(key=lambda p: os.path.getmtime(p), reverse=True)
        return cands[0]

    # Last-resort: any .md in the run dir (excluding common non-report names).
    md_files = [p for p in glob(os.path.join(run_dir, '*.md')) if os.path.isfile(p)]
    md_files = [p for p in md_files if os.path.basename(p).lower() not in ('readme.md',)]
    if not md_files:
        return None
    md_files.sort(key=lambda p: os.path.getmtime(p), reverse=True)
    return md_files[0]


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
        try:
            num = int(m.group(1))
        except ValueError:
            continue
        urls = MD_LINK_URL_RE.findall(line)
        if not urls:
            continue
        # Use the first markdown-link url on the line.
        out[num] = urls[0]
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

    # Prefer citations in the same paragraph (until blank line), else fall back
    # to a small forward window.
    para_end = report_md.find('\n\n', pos)
    if para_end < 0:
        para_end = min(len(report_md), pos + 1200)
    snippet = report_md[pos:para_end]
    nums: list[int] = []
    for m in INLINE_CITATION_RE.finditer(snippet):
        for n in m.group(1).split(','):
            try:
                nums.append(int(n.strip()))
            except ValueError:
                continue
    if nums:
        # Deduplicate while preserving order.
        out: list[int] = []
        for n in nums:
            if n not in out:
                out.append(n)
        return out

    # Fallback: scan a bounded window after the match.
    snippet = report_md[pos: min(len(report_md), pos + 800)]
    for m in INLINE_CITATION_RE.finditer(snippet):
        for n in m.group(1).split(','):
            try:
                nums.append(int(n.strip()))
            except ValueError:
                continue
    out: list[int] = []
    for n in nums:
        if n not in out:
            out.append(n)
    return out


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_verify(args: argparse.Namespace) -> None:
    """Verify all claims against evidence, update claims.jsonl."""
    claims_path = os.path.join(args.dir, 'claims.jsonl')
    evidence_path = os.path.join(args.dir, 'evidence.jsonl')
    sources_path = os.path.join(args.dir, 'sources.jsonl')

    claims = read_jsonl(claims_path)
    evidence = read_jsonl(evidence_path)
    sources = read_jsonl(sources_path)

    # Attempt to link claims' citation numbers -> source_ids using Bibliography.
    report_path = _find_report_path(args.dir)
    report_md = None
    bib_num_to_url = None
    if report_path and os.path.exists(report_path):
        try:
            with open(report_path) as f:
                report_md = f.read()
                bib_num_to_url = parse_bibliography_number_to_url(report_md)
        except Exception:
            report_md = None
            bib_num_to_url = None
    display_num_to_source_id = build_display_number_to_source_id(sources, bib_num_to_url)

    # Build evidence index by source_id
    ev_by_source: dict[str, list[str]] = {}
    ev_by_id: dict[str, dict] = {}
    for ev in evidence:
        sid = ev.get('source_id', '')
        eid = ev.get('evidence_id', '')
        ev_by_source.setdefault(sid, []).append(ev.get('quote', ''))
        ev_by_id[eid] = ev

    # Deduplicate claims
    seen = set()
    unique_claims = []
    for c in claims:
        cid = c.get('claim_id')
        if cid not in seen:
            seen.add(cid)
            unique_claims.append(c)

    verified = 0
    updated_claims = []

    for claim in unique_claims:
        section_id = claim.get('section_id', '')

        # Drop bibliography entries; they are citations, not claims.
        if section_id == 'bibliography':
            continue

        claim_type = claim.get('claim_type', 'factual')

        # Normalize claim types based on section intent.
        if section_id == 'recommendations':
            claim_type = 'recommendation'
            claim['claim_type'] = claim_type
        elif section_id in ('limitations', 'synthesis', 'conclusion'):
            # Uncited statements in these sections are usually interpretive synthesis.
            if claim_type == 'factual' and not claim.get('_citation_numbers'):
                claim_type = 'synthesis'
                claim['claim_type'] = claim_type

        # If the extracted sentence has no inline citations, try to infer them
        # from nearby paragraph context in the report text.
        if report_md and not claim.get('_citation_numbers'):
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

        # Gather evidence for this claim
        cited_ids = claim.get('cited_source_ids', [])
        evidence_ids = claim.get('evidence_ids', [])

        # Collect evidence quotes from linked evidence_ids
        quotes = []
        for eid in evidence_ids:
            if eid in ev_by_id:
                quotes.append(ev_by_id[eid].get('quote', ''))

        # Also gather from cited sources
        for sid in cited_ids:
            if sid in ev_by_source:
                quotes.extend(ev_by_source[sid])

        if not quotes and not cited_ids and not evidence_ids:
            # No links at all
            if claim_type == 'speculation':
                claim['support_status'] = 'supported'  # Speculation doesn't need evidence
            else:
                claim['support_status'] = 'unsupported'
        elif not quotes:
            # Has cited sources but no evidence captured yet
            claim['support_status'] = 'needs_review'
        else:
            status, score, notes = compute_support_score(claim['text'], quotes)
            claim['support_status'] = status
            claim['_support_score'] = score
            claim['_support_notes'] = notes

        verified += 1
        updated_claims.append(claim)

    # Rewrite claims.jsonl with updated statuses
    write_jsonl(claims_path, updated_claims)

    # Compute summary
    status_counts = Counter(c.get('support_status') for c in updated_claims)
    factual_unsupported = sum(
        1 for c in updated_claims
        if c.get('claim_type') == 'factual' and c.get('support_status') == 'unsupported'
    )
    total_factual = sum(1 for c in updated_claims if c.get('claim_type') == 'factual')

    # Strict mode: fail if any factual claim is unsupported
    passed = True
    if args.strict and factual_unsupported > 0:
        passed = False

    print(json.dumps({
        'status': 'pass' if passed else 'fail',
        'verified': verified,
        'support_status_counts': dict(status_counts),
        'factual_unsupported': factual_unsupported,
        'total_factual': total_factual,
        'unsupported_rate': round(factual_unsupported / max(total_factual, 1), 3),
    }, indent=2))

    if not passed:
        sys.exit(1)


def cmd_report(args: argparse.Namespace) -> None:
    """Generate human-readable support verification report."""
    claims_path = os.path.join(args.dir, 'claims.jsonl')
    claims = read_jsonl(claims_path)

    # Deduplicate
    seen = set()
    unique = []
    for c in claims:
        cid = c.get('claim_id')
        if cid not in seen:
            seen.add(cid)
            unique.append(c)

    lines = ['# Claim Support Verification Report', '']

    # Summary
    status_counts = Counter(c.get('support_status') for c in unique)
    type_counts = Counter(c.get('claim_type') for c in unique)
    lines.append(f'**Total claims:** {len(unique)}')
    lines.append(f'**By type:** {dict(type_counts)}')
    lines.append(f'**By status:** {dict(status_counts)}')
    lines.append('')

    # Unsupported factual claims (the failures)
    unsupported_factual = [
        c for c in unique
        if c.get('claim_type') == 'factual' and c.get('support_status') in ('unsupported', 'needs_review')
    ]
    if unsupported_factual:
        lines.append('## Unsupported/Review-needed Factual Claims')
        lines.append('')
        for c in unsupported_factual:
            lines.append(f'- [{c["support_status"]}] `{c["section_id"]}`: {c["text"][:100]}...')
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
    p_ver.add_argument('--strict', action='store_true', help='Exit 1 if any factual claim unsupported')

    # report
    p_rep = sub.add_parser('report', help='Generate verification report')
    p_rep.add_argument('--dir', required=True, help='Run directory')

    args = parser.parse_args()
    dispatch = {
        'verify': cmd_verify,
        'report': cmd_report,
    }
    dispatch[args.command](args)


if __name__ == '__main__':
    main()
