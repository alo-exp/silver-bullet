#!/usr/bin/env python3
"""
Citation Verification Script

Catches fabricated citations by checking:
1. DOI resolution (via doi.org) and that the DOI's metadata matches the entry
2. Basic metadata matching (title similarity, year match)
3. URL accessibility verification
4. Hallucination pattern detection (generic titles, suspicious patterns)
5. Flags suspicious entries for manual review

Decision (default): fail when any citation is suspicious or fewer than half are verified.
--strict also fails on any unverified citation; --lenient only reports (use it offline).

Bibliography URLs come from model output, so only public http(s) addresses are requested:
loopback, private, link-local, metadata and other non-global addresses are skipped, before the
request and on every redirect. Response bodies are read with a size cap and the whole run has
a time budget.

Usage:
    python verify_citations.py --report [path]
    python verify_citations.py --report [path] --strict   # fail on any unverified
    python verify_citations.py --report [path] --lenient  # report only (offline use)

Does NOT require API keys - uses free DOI resolver and heuristics.
"""

import sys
import argparse
import ipaddress
import re
import socket
from pathlib import Path
from typing import Callable, List, Dict, Optional, Tuple
from urllib import request, error
from urllib.parse import quote, urlparse
import json
import time
from datetime import datetime

# Largest DOI metadata body read into memory.
MAX_RESPONSE_BYTES = 1_000_000
# Default wall-clock budget for all network checks of one report (seconds).
DEFAULT_TIME_BUDGET = 300.0
# Host names that reach cloud metadata or the local machine whatever they resolve to.
BLOCKED_HOSTS = frozenset(['localhost', 'metadata', 'metadata.google.internal', 'metadata.goog'])

BIB_SECTION_RE = re.compile(r'^##[ \t]+Bibliography\b[^\n]*\n(.*?)(?=^#{1,2}(?!#)|\Z)',
                            re.DOTALL | re.IGNORECASE | re.MULTILINE)


def unsafe_url_reason(url: str, resolver: Optional[Callable] = None) -> Optional[str]:
    """Why ``url`` must not be requested, or None when it is a public http(s) URL."""
    resolver = resolver or socket.getaddrinfo
    parsed = urlparse(url)
    if parsed.scheme not in ('http', 'https'):
        return f"scheme {parsed.scheme or 'missing'} not allowed"
    host = (parsed.hostname or '').lower()
    if not host:
        return 'no host'
    if host in BLOCKED_HOSTS or host.endswith(('.localhost', '.internal', '.local')):
        return f'internal host name {host}'
    try:
        infos = resolver(host, parsed.port or (443 if parsed.scheme == 'https' else 80), proto=socket.IPPROTO_TCP)
    except (OSError, UnicodeError, ValueError):
        return f'cannot resolve {host}'
    for info in infos:
        addr = ipaddress.ip_address(info[4][0].split('%')[0])
        if addr.version == 6 and addr.ipv4_mapped:
            addr = addr.ipv4_mapped
        if not addr.is_global:
            return f'non-public address {addr}'
    return None


class _SafeRedirectHandler(request.HTTPRedirectHandler):
    """Follow a redirect only to another public http(s) address."""

    def __init__(self, resolver: Optional[Callable] = None):
        super().__init__()
        self.resolver = resolver

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        reason = unsafe_url_reason(newurl, self.resolver)
        if reason:
            raise error.URLError(f'redirect blocked ({reason})')
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def _urlopen(req: request.Request, timeout: float, resolver: Optional[Callable]):
    return request.build_opener(_SafeRedirectHandler(resolver)).open(req, timeout=timeout)


class CitationVerifier:
    """Verify citations in research report"""

    def __init__(self, report_path: Path, strict_mode: bool = False, lenient: bool = False,
                 time_budget: float = DEFAULT_TIME_BUDGET, resolver: Optional[Callable] = None):
        self.report_path = report_path
        self.strict_mode = strict_mode
        self.lenient = lenient
        self.resolver = resolver
        self.deadline = time.monotonic() + time_budget
        self.content = self._read_report()
        self.suspicious = []
        self.verified = []
        self.errors = []

        # Hallucination detection patterns (2025 CiteGuard enhancement)
        self.suspicious_patterns = [
            # Generic academic-sounding but fake patterns
            (r'^(A |An |The )?(Study|Analysis|Review|Survey|Investigation) (of|on|into)',
             "Generic academic title pattern"),
            (r'^(Recent|Current|Modern|Contemporary) (Advances|Developments|Trends) in',
             "Generic 'advances' title pattern"),
            # Too perfect, templated titles
            (r'^[A-Z][a-z]+ [A-Z][a-z]+: A (Comprehensive|Complete|Systematic) (Review|Analysis|Guide)$',
             "Too perfect, templated structure"),
        ]

    def _read_report(self) -> str:
        """Read report file"""
        try:
            with open(self.report_path, 'r', encoding='utf-8') as f:
                return f.read()
        except Exception as e:
            print(f"L ERROR: Cannot read report: {e}")
            sys.exit(1)

    def extract_bibliography(self) -> List[Dict]:
        """Extract bibliography entries (sub-headings such as '### Primary sources' included)."""
        match = BIB_SECTION_RE.search(self.content)

        if not match:
            self.errors.append("No Bibliography section found")
            return []

        bib_section = match.group(1)

        # Parse entries: [N] Author (Year). "Title". Venue. URL
        entries = []
        lines = bib_section.strip().split('\n')

        current_entry = None
        for line in lines:
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            # Check if starts with citation number [N]
            match_num = re.match(r'^\[(\d{1,4})\]\s+(.+)$', line)
            if match_num:
                if current_entry:
                    entries.append(current_entry)

                num = match_num.group(1)
                rest = match_num.group(2)

                # Try to parse: Author (Year). "Title". Venue. URL
                year_match = re.search(r'\((\d{4})\)', rest)
                title_match = re.search(r'"([^"]+)"', rest)
                doi_match = re.search(r'doi\.org/(10\.\S+)', rest)
                url_match = re.search(r'https?://[^\s\)]+', rest)

                current_entry = {
                    'num': num,
                    'raw': rest,
                    'year': year_match.group(1) if year_match else None,
                    'title': title_match.group(1) if title_match else None,
                    'doi': doi_match.group(1) if doi_match else None,
                    'url': url_match.group(0) if url_match else None
                }
            elif current_entry:
                # Multi-line entry, append to raw
                current_entry['raw'] += ' ' + line

        if current_entry:
            entries.append(current_entry)

        return entries

    def _open(self, req: request.Request):
        return _urlopen(req, 10, self.resolver)

    def verify_doi(self, doi: str) -> Tuple[bool, Dict]:
        """
        Verify DOI exists and get metadata.
        Returns (success, metadata_dict)
        """
        if not doi:
            return False, {}

        url = f"https://doi.org/{quote(doi)}"
        reason = unsafe_url_reason(url, self.resolver)
        if reason:
            return False, {'error': f'skipped ({reason})'}
        try:
            # Use content negotiation to get JSON metadata
            req = request.Request(url)
            req.add_header('Accept', 'application/vnd.citationstyles.csl+json')

            with self._open(req) as response:
                body = response.read(MAX_RESPONSE_BYTES + 1)
                if len(body) > MAX_RESPONSE_BYTES:
                    return False, {'error': f'response too large (over {MAX_RESPONSE_BYTES} bytes)'}
                data = json.loads(body.decode('utf-8'))

                return True, {
                    'title': data.get('title', ''),
                    'year': data.get('issued', {}).get('date-parts', [[None]])[0][0],
                    'authors': [
                        f"{a.get('family', '')} {a.get('given', '')}"
                        for a in data.get('author', [])
                    ],
                    'venue': data.get('container-title', '')
                }
        except error.HTTPError as e:
            if e.code == 404:
                return False, {'error': 'DOI not found (404)'}
            return False, {'error': f'HTTP {e.code}'}
        except Exception as e:
            return False, {'error': str(e)}

    def verify_url(self, url: str) -> Tuple[bool, str]:
        """
        Verify URL is accessible (2025 CiteGuard enhancement).
        Returns (accessible, status_message)
        """
        if not url:
            return False, "No URL"

        reason = unsafe_url_reason(url, self.resolver)
        if reason:
            return False, f"skipped ({reason})"
        try:
            # HEAD request to check accessibility without downloading
            req = request.Request(url, method='HEAD')
            req.add_header('User-Agent', 'Mozilla/5.0 (Research Citation Verifier)')

            with self._open(req) as response:
                if 200 <= response.status < 300:
                    return True, "URL accessible"
                else:
                    return False, f"HTTP {response.status}"
        except error.HTTPError as e:
            return False, f"HTTP {e.code}"
        except error.URLError as e:
            return False, f"URL error: {e.reason}"
        except Exception as e:
            return False, f"Connection error: {str(e)[:50]}"

    def detect_hallucination_patterns(self, entry: Dict) -> List[str]:
        """
        Detect common LLM hallucination patterns in citations (2025 CiteGuard).
        Returns list of detected issues.
        """
        issues = []
        title = entry.get('title', '')

        if not title:
            return issues

        # Check against suspicious patterns
        for pattern, description in self.suspicious_patterns:
            if re.match(pattern, title, re.IGNORECASE):
                issues.append(f"Suspicious title pattern: {description}")

        # Check for overly generic titles
        generic_words = ['overview', 'introduction', 'guide', 'handbook', 'manual']
        if any(word in title.lower() for word in generic_words) and len(title.split()) < 5:
            issues.append("Very generic short title")

        # Check for placeholder-like titles
        if any(x in title.lower() for x in ['tbd', 'todo', 'placeholder', 'example']):
            issues.append("Placeholder text in title")

        # Check for inconsistent metadata
        if entry.get('year'):
            year = int(entry['year'])
            current_year = datetime.now().year
            # Very recent without DOI or URL is suspicious
            if year >= current_year - 1 and not entry.get('doi') and not entry.get('url'):
                issues.append(f"Recent year ({year}) with no verification method")
            # Future year is definitely wrong
            if year > current_year:
                issues.append(f"Future year: {year} (current: {current_year})")
            # Very old with modern phrasing is suspicious
            if year < 2000 and any(word in title.lower() for word in ['ai', 'llm', 'gpt', 'transformer']):
                issues.append(f"Anachronistic: pre-2000 ({year}) citation mentioning modern AI terms")

        return issues

    @staticmethod
    def _words(text: str) -> set:
        return set(re.sub(r'[^\w\s]', ' ', text.lower()).split())

    def check_title_similarity(self, title1: str, title2: str) -> float:
        """
        Simple title similarity check (word overlap).
        Returns score 0.0-1.0
        """
        if not title1 or not title2:
            return 0.0

        words1 = self._words(title1)
        words2 = self._words(title2)

        if not words1 or not words2:
            return 0.0

        overlap = len(words1 & words2)
        total = len(words1 | words2)

        return overlap / total if total > 0 else 0.0

    def title_coverage(self, title: str, text: str) -> float:
        """Share of the title's significant words (3+ letters) that appear in ``text``."""
        wanted = {w for w in self._words(title) if len(w) >= 3}
        if not wanted:
            return 0.0
        return len(wanted & self._words(text)) / len(wanted)

    def _doi_metadata_issues(self, entry: Dict, metadata: Dict) -> List[str]:
        """A DOI only verifies an entry whose own title and year match the DOI's metadata."""
        issues = []
        meta_title = str(metadata.get('title') or '')
        if entry.get('title'):
            similarity = self.check_title_similarity(entry['title'], meta_title)
            if similarity < 0.5:
                issues.append(f"Title mismatch (similarity: {similarity:.1%})")
        elif self.title_coverage(meta_title, entry.get('raw', '')) < 0.5:
            issues.append("DOI metadata title not found in the entry")
        if entry.get('year') and metadata.get('year'):
            if int(entry['year']) != int(metadata['year']):
                issues.append(
                    f"Year mismatch: report says {entry['year']}, DOI says {metadata['year']}"
                )
        return issues

    def verify_entry(self, entry: Dict) -> Dict:
        """Verify a single bibliography entry (Enhanced 2025 with CiteGuard)"""
        result = {
            'num': entry['num'],
            'status': 'unknown',
            'issues': [],
            'metadata': {},
            'verification_methods': []
        }

        # STEP 1: Hallucination detection. A later DOI or URL success never clears it.
        hallucination_issues = self.detect_hallucination_patterns(entry)
        result['issues'].extend(hallucination_issues)
        suspicious = bool(hallucination_issues)
        doi_verified = False
        url_verified = False

        # STEP 2: Has DOI?
        if entry['doi']:
            print(f"  [{entry['num']}] Checking DOI {entry['doi']}...", end=' ')
            success, metadata = self.verify_doi(entry['doi'])

            if success:
                result['metadata'] = metadata
                mismatches = self._doi_metadata_issues(entry, metadata)
                result['issues'].extend(mismatches)
                suspicious = suspicious or bool(mismatches)
                doi_verified = not mismatches
                print("")
            else:
                print(f"✗ {metadata.get('error', 'Failed')}")
                result['issues'].append(f"DOI resolution failed: {metadata.get('error', 'unknown')}")

        # STEP 3: Check URL accessibility (if no DOI or the DOI did not verify)
        if entry['url'] and not doi_verified:
            url_ok, url_status = self.verify_url(entry['url'])
            if url_ok:
                result['verification_methods'].append('URL')
                url_verified = True
                print(f"  [{entry['num']}] URL accessible ✓")
            else:
                result['issues'].append(f"URL check failed: {url_status}")

        # STEP 4: Final fallback - no verification method
        if not entry['doi'] and not entry['url']:
            result['issues'].append("No DOI or URL - cannot verify")
            suspicious = True

        if suspicious:
            result['status'] = 'suspicious'
        elif doi_verified:
            result['status'] = 'verified'
        elif url_verified:
            result['status'] = 'url_verified'
        else:
            # A DOI or URL was checked and neither confirmed the entry.
            result['status'] = 'unverified'
        return result

    def verify_all(self):
        """Verify all bibliography entries"""
        print(f"\n{'='*60}")
        print(f"CITATION VERIFICATION: {self.report_path.name}")
        print(f"{'='*60}\n")

        entries = self.extract_bibliography()

        if not entries:
            print("L No bibliography entries found\n")
            return False

        print(f"Found {len(entries)} citations\n")

        results = []
        for entry in entries:
            if time.monotonic() > self.deadline:
                results.append({'num': entry.get('num'), 'status': 'unverified',
                                'issues': ['verification time budget exhausted'],
                                'metadata': {}, 'verification_methods': []})
                continue
            result = self.verify_entry(entry)
            results.append(result)

            # Rate limiting
            time.sleep(0.5)

        # Summarize
        print(f"\n{'='*60}")
        print(f"VERIFICATION SUMMARY")
        print(f"{'='*60}\n")

        verified = [r for r in results if r['status'] == 'verified']
        url_verified = [r for r in results if r['status'] == 'url_verified']
        suspicious = [r for r in results if r['status'] == 'suspicious']
        unverified = [r for r in results if r['status'] in ['unverified', 'no_doi', 'unknown']]

        print(f'DOI Verified: {len(verified)}/{len(results)}')
        print(f'URL Verified: {len(url_verified)}/{len(results)}')
        print(f'Suspicious: {len(suspicious)}/{len(results)}')
        print(f'Unverified: {len(unverified)}/{len(results)}')
        print()

        if suspicious:
            print('SUSPICIOUS CITATIONS (Manual Review Needed):')
            for r in suspicious:
                print(f"\n  [{r['num']}]")
                for issue in r['issues']:
                    print(f"    - {issue}")
            print()

        if unverified:
            print('UNVERIFIED CITATIONS (Could not check):')
            for r in unverified:
                print(f"  [{r['num']}] {r['issues'][0] if r['issues'] else 'Unknown'}")
            print()

        # Decision: suspicious or mostly-unverified bibliographies fail unless --lenient.
        total_verified = len(verified) + len(url_verified)
        failures = []
        if suspicious:
            failures.append('Suspicious citations detected')
        if self.strict_mode and unverified:
            failures.append('STRICT MODE: Unverified citations found')
        if total_verified / len(results) < 0.5:
            failures.append('Less than 50% citations verified')

        if not failures:
            print('CITATION VERIFICATION PASSED')
            return True
        for failure in failures:
            print(f'WARNING: {failure}')
        if self.lenient:
            print('  (--lenient: reporting only, not failing)')
            return True
        print('CITATION VERIFICATION FAILED (fix the citations, or use --lenient only when offline)')
        return False


def main():
    parser = argparse.ArgumentParser(
        description="Verify citations in research report",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python verify_citations.py --report report.md

Note: Requires internet connection to check DOIs (use --lenient offline).
Uses free DOI resolver - no API key needed.
        """
    )

    parser.add_argument(
        '--report', '-r',
        type=str,
        required=True,
        help='Path to research report markdown file'
    )

    mode = parser.add_mutually_exclusive_group()
    mode.add_argument(
        '--strict',
        action='store_true',
        help='Strict mode: also fail on any unverified citation'
    )
    mode.add_argument(
        '--lenient',
        action='store_true',
        help='Report problems without failing (for offline runs)'
    )
    parser.add_argument(
        '--time-budget',
        type=float,
        default=DEFAULT_TIME_BUDGET,
        help=f'Seconds allowed for all network checks (default {DEFAULT_TIME_BUDGET:.0f})'
    )

    args = parser.parse_args()
    report_path = Path(args.report)

    if not report_path.exists():
        print(f"ERROR: Report file not found: {report_path}")
        sys.exit(1)

    verifier = CitationVerifier(report_path, strict_mode=args.strict, lenient=args.lenient,
                                time_budget=args.time_budget)
    passed = verifier.verify_all()

    sys.exit(0 if passed else 1)


if __name__ == '__main__':
    main()
