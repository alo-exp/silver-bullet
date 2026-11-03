#!/usr/bin/env python3
"""
Atomic Claim Extractor — decomposes report sections into typed claims.

CLI subcommands:
  extract      Parse a markdown report into atomic claims (claims.jsonl)
  add          Manually add a single claim
  list         List claims, optionally filtered by section or type
  stats        Show claim statistics (counts by type/status)

Claim identity:
  claim_id = sha256(section_id + normalized_text)[:16]

Claim types (per GPT Pro's refinement of Codex's proposal):
  - factual: hard-fails on lack of support
  - synthesis: needs traceability, softer threshold
  - recommendation: needs traceability, softer threshold
  - speculation: labeled, no support gate
"""

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone

from jsonl_store import (  # noqa: F401
    add_json_input_args,
    append_jsonl,
    append_unique,
    load_json_input,
    locked,
    read_jsonl,
)


# ---------------------------------------------------------------------------
# Claim ID computation
# ---------------------------------------------------------------------------

_WHITESPACE_RE = re.compile(r'\s+')


def normalize_text(text: str) -> str:
    """Normalize for stable hashing."""
    return _WHITESPACE_RE.sub(' ', text.strip()).lower()


def compute_claim_id(section_id: str, text: str) -> str:
    """sha256(section_id + normalized_text)[:16] hex."""
    payload = section_id + normalize_text(text)
    return hashlib.sha256(payload.encode('utf-8')).hexdigest()[:16]


# ---------------------------------------------------------------------------
# Report parsing helpers
# ---------------------------------------------------------------------------

# Section header patterns
SECTION_PATTERNS = [
    (re.compile(r'^##\s+Executive\s+Summary', re.I), 'executive_summary'),
    (re.compile(r'^##\s+Introduction', re.I), 'introduction'),
    (re.compile(r'^##\s+Finding\s+(\d+)', re.I), lambda m: f'finding_{m.group(1)}'),
    (re.compile(r'^##\s+Synthesis', re.I), 'synthesis'),
    (re.compile(r'^##\s+Limitations', re.I), 'limitations'),
    (re.compile(r'^##\s+Recommendations', re.I), 'recommendations'),
    (re.compile(r'^##\s+Conclusion', re.I), 'conclusion'),
    (re.compile(r'^##\s+(.+)', re.I), lambda m: re.sub(r'\W+', '_', m.group(1).strip().lower())[:30]),
]

# Citation pattern [N] or [N, M]; bounded so an ID such as [20240101...] in body text can
# neither become a citation number nor overflow int() on a long digit run.
CITATION_RE = re.compile(r'\[(\d{1,4}(?:,\s*\d{1,4})*)\]')

# Sections that list sources rather than make claims.
NON_CLAIM_SECTIONS = frozenset(['bibliography', 'references', 'sources', 'works_cited'])

# Sentence splitting (basic but handles abbreviations)
# A sentence ends at ". " before a capital letter; at a blank line (a paragraph break); and after a
# citation marker ("... [1]. 62% of ...") before a digit or a lower-case brand ("iPhone sales ...").
SENTENCE_RE = re.compile(r'(?<=[.!?])\s+(?=[A-Z])|[ \t]*\n[ \t]*\n\s*|(?<=\][.!?])\s+(?=[\da-z])')


# Whole-word cues: "considerable", "suggests" (as in "data suggests") and "Mighty" must not
# turn a factual sentence into a recommendation or speculation that escapes the hard gate.
RECOMMENDATION_RE = re.compile(
    r"\bshould\b|\brecommend(?:s|ed|ation|ations)?\b|\badvis(?:e|es|ed|able)\b"
    r"|\b(?:we|i) (?:suggest|propose)\b|^consider\b",
    re.IGNORECASE,
)
SPECULATION_RE = re.compile(
    r"\bmight\b|\bcould potentially\b|\bit is possible\b|\bmay eventually\b"
    r"|\bhypothetically\b|\bspeculatively\b",
    re.IGNORECASE,
)
SYNTHESIS_RE = re.compile(
    r"\boverall\b|\btaken together\b|\bcollectively\b|\bthe evidence suggests\b|\bthis implies\b",
    re.IGNORECASE,
)


CITATION_MARK_RE = re.compile(r'\[\d{1,4}(?:,\s*\d{1,4})*\]')
# A year, a percentage, a currency amount or a scaled quantity: figures that state a fact
# ("recommend 3 vendors" does not).
CHECKABLE_FIGURE_RE = re.compile(
    r'\b(?:19|20)\d{2}\b|\d\s*%|[$€£]\s*\d|\b\d+(?:\.\d+)?\s*(?:k|m|bn|million|billion|trillion|thousand)\b',
    re.IGNORECASE,
)


# A count of something measurable ("7 days", "3 regions", "500 employees"): a short sentence that
# states one is a claim, though a bare "4 vendors" in "We compared 4 vendors." is not.
MEASURE_RE = re.compile(
    r'\b\d+(?:\.\d+)?\s*(?:days?|hours?|weeks?|months?|minutes?|seconds?|ms|[kmgt]b|users?|seats?|regions?|'
    r'offices?|countries|employees|staff|customers|engineers|nodes|servers)\b',
    re.IGNORECASE,
)

COMPLIANCE_RE = re.compile(
    r'\b(?:hipaa|gdpr|ccpa|soc\s?[12]|iso\s?\d+|pci|fedramp|certified|certification|compliant|compliance|'
    r'audited|accredited|encrypts?|encrypted)\b',
    re.IGNORECASE,
)
SUPERLATIVE_RE = re.compile(
    r'\b(?:largest|biggest|smallest|fastest|slowest|cheapest|best|worst|leading|leader|leads|'
    r'only|first|last|most|least|never|always|every|all)\b',
    re.IGNORECASE,
)
# A reference to a table, figure or section is navigation, not a finding.
NAVIGATION_RE = re.compile(
    r'^(?:see|refer to|as shown in|shown in|results are in|details are in|presented in|listed in)\b'
    r'|^(?:next|below|above|finally|first|then|now),?\s+(?:we|let|i)\b'
    r'|\b(?:table|figure|fig\.|section|appendix|chapter|page)\s+\d+',
    re.IGNORECASE,
)
# Words that open a sentence without naming anything.
SENTENCE_STARTERS = frozenset(
    'the this that these those it its they their we our you your i he she there here see overall '
    'however also but and so then thus hence note notes results result summary conclusion in on at by for '
    'from with without as of to if when while although because since after before during some many most '
    'several each every all both either neither none one two three four five six seven eight nine ten '
    'recent recently currently today now first second third finally additionally moreover furthermore'.split()
)


# Everyday nouns that open an evaluation ("Pricing is simple.", "Setup took minutes."): not names.
GENERIC_OPENERS = frozenset(
    'pricing price prices cost costs support documentation docs setup onboarding installation usability '
    'performance design quality speed interface ui ux integration integrations reliability security '
    'scalability stability customization flexibility maintenance training service services features '
    'feature licensing billing migration deployment configuration analytics reporting community '
    'overall everything nothing something'.split()
)


def _has_name(sentence: str) -> bool:
    """A named thing: a capitalised word that is not the sentence opener, an opener that is not a
    common starter ("Acme leads on price"), an acronym or an identifier."""
    words = re.findall(r"[A-Za-z][\w.+-]*", sentence)
    if not words:
        return False
    if words[0].lower() not in SENTENCE_STARTERS | GENERIC_OPENERS and words[0][0].isupper():
        return True
    return any(w[0].isupper() and (len(w) > 1 or w == 'I') and w != 'I' for w in words[1:])


def _long_enough(sentence: str) -> bool:
    """A claim is a sentence over 30 characters, or a shorter one with a factual signal: a figure,
    a named thing, a compliance/certification term or a superlative. Navigation ("See Figure 3
    below."), list numbers and bare labels are not claims."""
    sentence = re.sub(r'\s*\n\s*\d+[.)]\s*$', '', sentence).strip()
    if len(sentence) > 30:
        return True
    if len(sentence.split()) < 3:
        return False
    plain = CITATION_MARK_RE.sub(' ', sentence)
    if CHECKABLE_FIGURE_RE.search(plain) or MEASURE_RE.search(plain):
        return True
    if NAVIGATION_RE.search(plain):
        return False
    return bool(_has_name(plain) or COMPLIANCE_RE.search(plain) or SUPERLATIVE_RE.search(plain))


def classify_claim(text: str, section_id: str) -> str:
    """Heuristic claim type classification (whole-word cues only)."""
    stripped = text.strip()
    # A hedge or recommendation clause does not exempt a checkable figure: "Acme raised 50
    # million in 2023 and should be shortlisted" still asserts a fact that needs evidence.
    if CHECKABLE_FIGURE_RE.search(CITATION_MARK_RE.sub(' ', stripped)):
        return 'synthesis' if _is_synthesis(stripped, section_id) else 'factual'
    if RECOMMENDATION_RE.search(stripped):
        return 'recommendation'
    if SPECULATION_RE.search(stripped):
        return 'speculation'
    if _is_synthesis(stripped, section_id):
        return 'synthesis'
    return 'factual'


def _is_synthesis(stripped: str, section_id: str) -> bool:
    return section_id in ('synthesis', 'conclusion', 'limitations') and bool(SYNTHESIS_RE.search(stripped))


def parse_sections(markdown: str) -> list[tuple[str, str]]:
    """Parse markdown into (section_id, content) pairs."""
    lines = markdown.split('\n')
    sections = []
    current_id = 'preamble'
    current_lines = []

    for line in lines:
        matched = False
        for pattern, id_or_fn in SECTION_PATTERNS:
            m = pattern.match(line)
            if m:
                if current_lines:
                    sections.append((current_id, '\n'.join(current_lines)))
                current_id = id_or_fn(m) if callable(id_or_fn) else id_or_fn
                current_lines = []
                matched = True
                break
        if not matched:
            current_lines.append(line)

    if current_lines:
        sections.append((current_id, '\n'.join(current_lines)))

    return sections


def extract_sentences(text: str) -> list[str]:
    """Split text into sentences, filtering noise."""
    # Remove markdown formatting noise
    text = re.sub(r'^[-*]\s+', '', text, flags=re.M)  # bullet points
    text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)  # bold
    text = re.sub(r'\*([^*]+)\*', r'\1', text)  # italic

    sentences = SENTENCE_RE.split(text)
    result = []
    for s in sentences:
        s = s.strip()
        # Filter out very short fragments, headings, empty lines
        if _long_enough(s) and not s.startswith('#') and not s.startswith('|'):
            result.append(re.sub(r'\s*\n\s*\d+[.)]\s*$', '', s).strip())
    return result


# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

def cmd_extract(args: argparse.Namespace) -> None:
    """Extract atomic claims from a markdown report."""
    report_path = args.report
    if not os.path.exists(report_path):
        print(json.dumps({'error': f'Report not found: {report_path}'}), file=sys.stderr)
        sys.exit(1)

    with open(report_path) as f:
        markdown = f.read()

    claims_path = os.path.join(args.dir, 'claims.jsonl')
    with locked(claims_path):
        added, skipped, total = _extract_into(claims_path, markdown)

    print(json.dumps({
        'status': 'ok',
        'claims_added': added,
        'claims_skipped': skipped,
        'total_claims': total,
    }))


def _extract_into(claims_path: str, markdown: str) -> tuple[int, int, int]:
    """Append new claims from ``markdown``; the caller holds the store lock."""
    existing_ids = {r.get('claim_id') for r in read_jsonl(claims_path)}
    added = 0
    skipped = 0

    for section_id, content in parse_sections(markdown):
        if section_id == 'preamble' or section_id in NON_CLAIM_SECTIONS:
            continue
        sentences = extract_sentences(content)
        for sentence in sentences:
            claim_id = compute_claim_id(section_id, sentence)
            if claim_id in existing_ids:
                skipped += 1
                continue

            # Extract citation numbers from sentence
            citation_nums = []
            for m in CITATION_RE.finditer(sentence):
                nums = [int(n.strip()) for n in m.group(1).split(',')]
                citation_nums.extend(nums)

            claim = {
                'claim_id': claim_id,
                'section_id': section_id,
                'text': sentence,
                'claim_type': classify_claim(sentence, section_id),
                'cited_source_ids': [],  # Populated by linking step
                'evidence_ids': [],  # Populated by verify_claim_support
                'support_status': 'unverified',
                'extracted_at': datetime.now(timezone.utc).isoformat(),
                '_citation_numbers': citation_nums,  # Temporary, for linking
            }
            append_jsonl(claims_path, claim)
            existing_ids.add(claim_id)
            added += 1
    return added, skipped, len(existing_ids)


def cmd_add(args: argparse.Namespace) -> None:
    """Manually add a single claim."""
    data = load_json_input(args)
    section_id = data.get('section_id', 'unknown')
    text = data.get('text', '')
    if not text:
        print(json.dumps({'error': 'text is required'}), file=sys.stderr)
        sys.exit(1)

    claim_id = compute_claim_id(section_id, text)
    claims_path = os.path.join(args.dir, 'claims.jsonl')

    valid_types = {'factual', 'synthesis', 'recommendation', 'speculation'}
    claim_type = data.get('claim_type', 'factual')
    if claim_type not in valid_types:
        claim_type = 'factual'

    claim = {
        'claim_id': claim_id,
        'section_id': section_id,
        'text': text,
        'claim_type': claim_type,
        'cited_source_ids': data.get('cited_source_ids', []),
        'evidence_ids': data.get('evidence_ids', []),
        'support_status': 'unverified',
        'extracted_at': datetime.now(timezone.utc).isoformat(),
    }
    if append_unique(claims_path, claim, 'claim_id') is not None:
        print(json.dumps({'status': 'duplicate', 'claim_id': claim_id}))
        return
    print(json.dumps({'status': 'added', 'claim_id': claim_id}))


def cmd_list(args: argparse.Namespace) -> None:
    """List claims with optional filters."""
    claims_path = os.path.join(args.dir, 'claims.jsonl')
    rows = read_jsonl(claims_path)

    if args.section:
        rows = [r for r in rows if r.get('section_id') == args.section]
    if args.type:
        rows = [r for r in rows if r.get('claim_type') == args.type]
    if args.status:
        rows = [r for r in rows if r.get('support_status') == args.status]

    # Deduplicate
    seen = set()
    unique = []
    for r in rows:
        cid = r.get('claim_id')
        if cid not in seen:
            seen.add(cid)
            unique.append(r)

    print(json.dumps({'count': len(unique), 'claims': unique}, indent=2, ensure_ascii=False))


def cmd_stats(args: argparse.Namespace) -> None:
    """Show claim statistics."""
    claims_path = os.path.join(args.dir, 'claims.jsonl')
    rows = read_jsonl(claims_path)

    # Deduplicate
    seen = set()
    unique = []
    for r in rows:
        cid = r.get('claim_id')
        if cid not in seen:
            seen.add(cid)
            unique.append(r)

    by_type = {}
    by_status = {}
    by_section = {}
    for r in unique:
        t = r.get('claim_type', 'unknown')
        s = r.get('support_status', 'unknown')
        sec = r.get('section_id', 'unknown')
        by_type[t] = by_type.get(t, 0) + 1
        by_status[s] = by_status.get(s, 0) + 1
        by_section[sec] = by_section.get(sec, 0) + 1

    print(json.dumps({
        'total': len(unique),
        'by_type': by_type,
        'by_status': by_status,
        'by_section': by_section,
    }, indent=2))


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        prog='extract_claims',
        description='Atomic claim extraction and ledger for deep-research v3.0',
    )
    sub = parser.add_subparsers(dest='command', required=True)

    # extract
    p_ext = sub.add_parser('extract', help='Extract claims from markdown report')
    p_ext.add_argument('--report', required=True, help='Path to report.md')
    p_ext.add_argument('--dir', required=True, help='Run directory containing claims.jsonl')

    # add
    p_add = sub.add_parser('add', help='Manually add a single claim')
    add_json_input_args(p_add, 'JSON with section_id, text, claim_type')
    p_add.add_argument('--dir', required=True, help='Run directory')

    # list
    p_list = sub.add_parser('list', help='List claims')
    p_list.add_argument('--dir', required=True, help='Run directory')
    p_list.add_argument('--section', default=None, help='Filter by section_id')
    p_list.add_argument('--type', default=None, help='Filter by claim_type')
    p_list.add_argument('--status', default=None, help='Filter by support_status')

    # stats
    p_stats = sub.add_parser('stats', help='Claim statistics')
    p_stats.add_argument('--dir', required=True, help='Run directory')

    args = parser.parse_args()
    dispatch = {
        'extract': cmd_extract,
        'add': cmd_add,
        'list': cmd_list,
        'stats': cmd_stats,
    }
    dispatch[args.command](args)


if __name__ == '__main__':
    main()
