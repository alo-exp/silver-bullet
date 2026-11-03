#!/usr/bin/env python3
"""In-process tests for verify_citations.py (no network: urlopen is mocked)."""

from __future__ import annotations

import contextlib
import importlib.util
import io
import json
import os
import shutil
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock
from urllib import error

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts', 'verify_citations.py')
_spec = importlib.util.spec_from_file_location('verify_citations_under_test', SCRIPT)
vc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vc)

_ROOT = None
_patches = []


def _no_network(*a, **k):
    raise AssertionError('network access attempted')


def setUpModule():
    global _ROOT
    _ROOT = tempfile.mkdtemp()
    for target in ('socket.socket.connect', 'socket.getaddrinfo'):
        p = mock.patch(target, side_effect=_no_network)
        p.start()
        _patches.append(p)


def tearDownModule():
    for p in _patches:
        p.stop()
    _patches.clear()
    shutil.rmtree(_ROOT, ignore_errors=True)


class FakeDT:
    class _Now:
        year = 2025

    @classmethod
    def now(cls):
        return cls._Now()


class FakeResp:
    def __init__(self, body=b'', status=200):
        self._body = body
        self.status = status

    def read(self):
        return self._body

    def __enter__(self):
        return self

    def __exit__(self, *a):
        return False


def make_verifier(text='## Bibliography\n', strict=False):
    d = tempfile.mkdtemp(dir=_ROOT)
    p = Path(d) / 'report.md'
    p.write_text(text, encoding='utf-8')
    return vc.CitationVerifier(p, strict_mode=strict)


def entry(**kw):
    e = {'num': '1', 'raw': '', 'year': None, 'title': None, 'doi': None, 'url': None}
    e.update(kw)
    return e


class TestReadAndExtract(unittest.TestCase):
    def test_unreadable_report_exits(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as cm:
            vc.CitationVerifier(Path('/nonexistent/dir/none.md'))
        self.assertEqual(cm.exception.code, 1)
        self.assertIn('Cannot read report', out.getvalue())

    def test_no_bibliography_section(self):
        v = make_verifier('# Title\nno bib here\n')
        self.assertEqual(v.extract_bibliography(), [])
        self.assertEqual(v.errors, ['No Bibliography section found'])

    def test_parses_entries_multiline_and_fields(self):
        text = (
            '## Bibliography\n'
            'stray line before any entry\n'
            '\n'
            '[1] Smith (2021). "Real Title". Venue. https://doi.org/10.1000/abc.\n'
            'continued venue text\n'
            '[2] Jones. "No year". https://example.com/page)\n'
            '[3] Plain text only\n'
            '## Appendix\n[9] ignored (1999)\n'
        )
        v = make_verifier(text)
        entries = v.extract_bibliography()
        self.assertEqual([e['num'] for e in entries], ['1', '2', '3'])
        e1, e2, e3 = entries
        self.assertEqual(e1['year'], '2021')
        self.assertEqual(e1['title'], 'Real Title')
        self.assertEqual(e1['doi'], '10.1000/abc.')
        self.assertTrue(e1['url'].startswith('https://doi.org/10.1000/abc'))
        self.assertIn('continued venue text', e1['raw'])
        self.assertEqual(e2['url'], 'https://example.com/page')
        self.assertIsNone(e2['year'])
        self.assertIsNone(e2['doi'])
        self.assertEqual((e3['title'], e3['doi'], e3['url'], e3['year']), (None, None, None, None))


class TestVerifyDoi(unittest.TestCase):
    def setUp(self):
        self.v = make_verifier()

    def test_empty_doi(self):
        self.assertEqual(self.v.verify_doi(''), (False, {}))

    def test_success_parses_metadata(self):
        body = json.dumps({
            'title': 'T', 'issued': {'date-parts': [[2020]]},
            'author': [{'family': 'Doe', 'given': 'J'}], 'container-title': 'V',
        }).encode()
        with mock.patch.object(vc.request, 'urlopen', return_value=FakeResp(body)) as uo:
            ok, md = self.v.verify_doi('10.1/x y')
        self.assertTrue(ok)
        self.assertEqual(md, {'title': 'T', 'year': 2020, 'authors': ['Doe J'], 'venue': 'V'})
        req = uo.call_args[0][0]
        self.assertEqual(req.full_url, 'https://doi.org/10.1/x%20y')
        self.assertEqual(req.get_header('Accept'), 'application/vnd.citationstyles.csl+json')

    def test_success_missing_fields_defaults(self):
        with mock.patch.object(vc.request, 'urlopen', return_value=FakeResp(b'{"issued": {}}')):
            ok, md = self.v.verify_doi('10.1/x')
        self.assertTrue(ok)
        self.assertEqual(md['title'], '')
        self.assertIsNone(md['year'])
        self.assertEqual(md['authors'], [])

    def test_http_404(self):
        exc = error.HTTPError('u', 404, 'nf', {}, None)
        with mock.patch.object(vc.request, 'urlopen', side_effect=exc):
            self.assertEqual(self.v.verify_doi('10.1/x'), (False, {'error': 'DOI not found (404)'}))

    def test_http_other(self):
        exc = error.HTTPError('u', 503, 'x', {}, None)
        with mock.patch.object(vc.request, 'urlopen', side_effect=exc):
            self.assertEqual(self.v.verify_doi('10.1/x'), (False, {'error': 'HTTP 503'}))

    def test_generic_exception(self):
        with mock.patch.object(vc.request, 'urlopen', side_effect=ValueError('boom')):
            self.assertEqual(self.v.verify_doi('10.1/x'), (False, {'error': 'boom'}))


class TestVerifyUrl(unittest.TestCase):
    def setUp(self):
        self.v = make_verifier()

    def test_empty(self):
        self.assertEqual(self.v.verify_url(''), (False, 'No URL'))

    def test_ok(self):
        with mock.patch.object(vc.request, 'urlopen', return_value=FakeResp(status=200)) as uo:
            self.assertEqual(self.v.verify_url('https://e.com'), (True, 'URL accessible'))
        req = uo.call_args[0][0]
        self.assertEqual(req.get_method(), 'HEAD')
        self.assertIn('Citation Verifier', req.get_header('User-agent'))

    def test_non_200(self):
        with mock.patch.object(vc.request, 'urlopen', return_value=FakeResp(status=204)):
            self.assertEqual(self.v.verify_url('https://e.com'), (False, 'HTTP 204'))

    def test_http_error(self):
        exc = error.HTTPError('u', 403, 'x', {}, None)
        with mock.patch.object(vc.request, 'urlopen', side_effect=exc):
            self.assertEqual(self.v.verify_url('https://e.com'), (False, 'HTTP 403'))

    def test_url_error(self):
        with mock.patch.object(vc.request, 'urlopen', side_effect=error.URLError('dns fail')):
            self.assertEqual(self.v.verify_url('https://e.com'), (False, 'URL error: dns fail'))

    def test_other_exception_truncated(self):
        with mock.patch.object(vc.request, 'urlopen', side_effect=OSError('x' * 80)):
            ok, msg = self.v.verify_url('https://e.com')
        self.assertFalse(ok)
        self.assertEqual(msg, 'Connection error: ' + 'x' * 50)


class TestHallucination(unittest.TestCase):
    def setUp(self):
        self.v = make_verifier()
        p = mock.patch.object(vc, 'datetime', FakeDT)
        p.start()
        self.addCleanup(p.stop)

    def test_no_title(self):
        self.assertEqual(self.v.detect_hallucination_patterns(entry()), [])

    def test_generic_patterns(self):
        i = self.v.detect_hallucination_patterns(entry(title='A Study of Things in Nature Today'))
        self.assertEqual(i, ['Suspicious title pattern: Generic academic title pattern'])
        i = self.v.detect_hallucination_patterns(entry(title='Recent Advances in Chemistry Methods'))
        self.assertEqual(i, ["Suspicious title pattern: Generic 'advances' title pattern"])
        i = self.v.detect_hallucination_patterns(entry(title='Machine Learning: A Comprehensive Review'))
        self.assertEqual(i, ['Suspicious title pattern: Too perfect, templated structure'])

    def test_generic_short_and_placeholder(self):
        i = self.v.detect_hallucination_patterns(entry(title='Quick guide'))
        self.assertEqual(i, ['Very generic short title'])
        i = self.v.detect_hallucination_patterns(entry(title='Unrelated example'))
        self.assertEqual(i, ['Placeholder text in title'])
        # generic word but long title: not flagged
        i = self.v.detect_hallucination_patterns(entry(title='An introduction to databases for working engineers'))
        self.assertEqual(i, [])

    def test_year_checks(self):
        t = 'Solid paper on databases'
        self.assertEqual(self.v.detect_hallucination_patterns(entry(title=t, year='2024')),
                         ['Recent year (2024) with no verification method'])
        self.assertEqual(self.v.detect_hallucination_patterns(entry(title=t, year='2024', doi='10.1/x')), [])
        self.assertEqual(self.v.detect_hallucination_patterns(entry(title=t, year='2024', url='http://x')), [])
        self.assertEqual(self.v.detect_hallucination_patterns(entry(title=t, year='2030', doi='10.1/x')),
                         ['Future year: 2030 (current: 2025)'])
        self.assertEqual(self.v.detect_hallucination_patterns(entry(title=t, year='2010')), [])
        i = self.v.detect_hallucination_patterns(entry(title='GPT of old', year='1990'))
        self.assertEqual(i, ['Anachronistic: pre-2000 (1990) citation mentioning modern AI terms'])
        self.assertEqual(self.v.detect_hallucination_patterns(entry(title=t, year='1990')), [])


class TestCitationBoundaries(unittest.TestCase):
    def setUp(self):
        self.v = make_verifier()
        p = mock.patch.object(vc, 'datetime', FakeDT)
        p.start()
        self.addCleanup(p.stop)

    def issues(self, **kw):
        return self.v.detect_hallucination_patterns(entry(**kw))

    def doi_entry(self, title, meta_title):
        with mock.patch.object(self.v, 'verify_doi', return_value=(True, {'title': meta_title})), \
                contextlib.redirect_stdout(io.StringIO()):
            return self.v.verify_entry(entry(doi='10.1/x', title=title))

    def test_similarity_threshold(self):
        # 2/4 = 0.5 exactly: accepted. 2/5 = 0.4: mismatch. 3/5 = 0.6: accepted.
        self.assertEqual(self.doi_entry('alpha beta gamma', 'alpha beta delta')['status'], 'verified')
        r = self.doi_entry('alpha beta gamma', 'alpha beta delta epsilon')
        self.assertEqual(r['status'], 'suspicious')
        self.assertEqual(r['issues'], ['Title mismatch (similarity: 40.0%)'])
        self.assertEqual(self.doi_entry('alpha beta gamma delta', 'alpha beta gamma epsilon')['status'], 'verified')

    def test_future_year_boundary(self):
        t = 'Solid paper on databases'
        self.assertEqual(self.issues(title=t, year='2025', doi='10.1/x'), [])
        self.assertEqual(self.issues(title=t, year='2026', doi='10.1/x'), ['Future year: 2026 (current: 2025)'])

    def test_recent_year_boundary(self):
        t = 'Solid paper on databases'
        self.assertEqual(self.issues(title=t, year='2025'), ['Recent year (2025) with no verification method'])
        self.assertEqual(self.issues(title=t, year='2024'), ['Recent year (2024) with no verification method'])
        self.assertEqual(self.issues(title=t, year='2023'), [])

    def test_generic_title_length_boundary(self):
        self.assertEqual(self.issues(title='Quick guide for beginners'), ['Very generic short title'])
        self.assertEqual(self.issues(title='Quick guide for new engineers'), [])

    def test_anachronism_boundary(self):
        self.assertEqual(self.issues(title='GPT of old', year='1999'),
                         ['Anachronistic: pre-2000 (1999) citation mentioning modern AI terms'])
        self.assertEqual(self.issues(title='GPT of old', year='2000'), [])

    def test_half_verified_passes_without_warning(self):
        ok, out, _ = TestVerifyAll.run_all(TestVerifyAll(), [TestVerifyAll.res('1', 'verified'),
                                                            TestVerifyAll.res('2', 'unverified')])
        self.assertTrue(ok)
        self.assertIn('CITATION VERIFICATION PASSED', out)
        self.assertNotIn('Less than 50%', out)
        ok, out, _ = TestVerifyAll.run_all(TestVerifyAll(), [TestVerifyAll.res('1', 'verified'),
                                                            TestVerifyAll.res('2', 'unverified'),
                                                            TestVerifyAll.res('3', 'unverified')])
        self.assertIn('Less than 50%', out)


class TestSimilarity(unittest.TestCase):
    def setUp(self):
        self.v = make_verifier()

    def test_empty(self):
        self.assertEqual(self.v.check_title_similarity('', 'a'), 0.0)
        self.assertEqual(self.v.check_title_similarity('a', ''), 0.0)

    def test_punctuation_only_is_empty(self):
        self.assertEqual(self.v.check_title_similarity('!!!', 'abc'), 0.0)

    def test_overlap(self):
        self.assertEqual(self.v.check_title_similarity('Deep Learning!', 'deep learning'), 1.0)
        self.assertAlmostEqual(self.v.check_title_similarity('a b c d', 'a b x y'), 2 / 6)


class TestVerifyEntry(unittest.TestCase):
    def setUp(self):
        self.v = make_verifier()
        p = mock.patch.object(vc, 'datetime', FakeDT)
        p.start()
        self.addCleanup(p.stop)

    def run_entry(self, e, doi=None, url=None):
        doi = doi if doi is not None else (False, {})
        url = url if url is not None else (False, 'x')
        out = io.StringIO()
        with mock.patch.object(self.v, 'verify_doi', return_value=doi), \
                mock.patch.object(self.v, 'verify_url', return_value=url), \
                contextlib.redirect_stdout(out):
            return self.v.verify_entry(e), out.getvalue()

    def test_doi_verified_clean(self):
        r, out = self.run_entry(entry(doi='10.1/x', title='Deep Learning', year='2020'),
                                doi=(True, {'title': 'Deep learning', 'year': 2020}))
        self.assertEqual(r['status'], 'verified')
        self.assertEqual(r['issues'], [])
        self.assertIn('Checking DOI 10.1/x', out)

    def test_doi_verified_without_titles_or_years(self):
        r, _ = self.run_entry(entry(doi='10.1/x'), doi=(True, {}))
        self.assertEqual(r['status'], 'verified')

    def test_doi_title_and_year_mismatch(self):
        r, _ = self.run_entry(entry(doi='10.1/x', title='Alpha Beta', year='2020'),
                              doi=(True, {'title': 'Gamma Delta', 'year': 2019}))
        self.assertEqual(r['status'], 'suspicious')
        self.assertTrue(any(i.startswith('Title mismatch') for i in r['issues']))
        self.assertIn('Year mismatch: report says 2020, DOI says 2019', r['issues'])

    def test_doi_failed_then_url_ok(self):
        r, out = self.run_entry(entry(doi='10.1/x', url='http://e.com'),
                                doi=(False, {'error': 'HTTP 500'}), url=(True, 'ok'))
        self.assertEqual(r['status'], 'url_verified')
        self.assertEqual(r['verification_methods'], ['URL'])
        self.assertIn('DOI resolution failed: HTTP 500', r['issues'])
        self.assertIn('URL accessible', out)

    def test_doi_failed_no_error_key(self):
        r, out = self.run_entry(entry(doi='10.1/x'), doi=(False, {}))
        self.assertEqual(r['status'], 'unverified')
        self.assertIn('DOI resolution failed: unknown', r['issues'])
        self.assertIn('Failed', out)

    def test_url_only_ok(self):
        r, _ = self.run_entry(entry(url='http://e.com'), url=(True, 'ok'))
        self.assertEqual(r['status'], 'url_verified')

    def test_url_ok_keeps_suspicious_status(self):
        r, _ = self.run_entry(entry(url='http://e.com', title='A Study of Things Here'), url=(True, 'ok'))
        self.assertEqual(r['status'], 'suspicious')
        self.assertEqual(r['verification_methods'], ['URL'])

    def test_url_fail(self):
        r, _ = self.run_entry(entry(url='http://e.com'), url=(False, 'HTTP 404'))
        self.assertEqual(r['status'], 'unknown')
        self.assertEqual(r['issues'], ['URL check failed: HTTP 404'])

    def test_no_doi_no_url(self):
        r, _ = self.run_entry(entry())
        self.assertEqual(r['status'], 'suspicious')
        self.assertEqual(r['issues'], ['No DOI or URL - cannot verify'])


class TestVerifyAll(unittest.TestCase):
    def run_all(self, entries, strict=False):
        v = make_verifier(strict=strict)
        out = io.StringIO()
        results = iter(entries)

        def fake_entry(e):
            return next(results)

        with mock.patch.object(v, 'extract_bibliography', return_value=[{}] * len(entries)), \
                mock.patch.object(v, 'verify_entry', side_effect=fake_entry), \
                mock.patch.object(vc.time, 'sleep') as sl, \
                contextlib.redirect_stdout(out):
            ok = v.verify_all()
        return ok, out.getvalue(), sl

    @staticmethod
    def res(num, status, issues=()):
        return {'num': num, 'status': status, 'issues': list(issues)}

    def test_no_entries(self):
        v = make_verifier()
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertFalse(v.verify_all())
        self.assertIn('No bibliography entries found', out.getvalue())

    def test_pass(self):
        ok, out, sl = self.run_all([self.res('1', 'verified'), self.res('2', 'url_verified')])
        self.assertTrue(ok)
        self.assertIn('CITATION VERIFICATION PASSED', out)
        self.assertIn('DOI Verified: 1/2', out)
        self.assertIn('URL Verified: 1/2', out)
        self.assertEqual(sl.call_count, 2)

    def test_low_verification_warns_but_passes(self):
        ok, out, _ = self.run_all([self.res('1', 'unverified', ['DOI resolution failed: x']),
                                   self.res('2', 'unknown')])
        self.assertTrue(ok)
        self.assertIn('UNVERIFIED CITATIONS', out)
        self.assertIn('[1] DOI resolution failed: x', out)
        self.assertIn('[2] Unknown', out)
        self.assertIn('Less than 50%', out)

    def test_suspicious_nonstrict_continues(self):
        ok, out, _ = self.run_all([self.res('1', 'verified'), self.res('2', 'suspicious', ['bad thing'])])
        self.assertTrue(ok)
        self.assertIn('SUSPICIOUS CITATIONS', out)
        self.assertIn('- bad thing', out)
        self.assertIn('(Continuing in non-strict mode)', out)

    def test_suspicious_strict_fails(self):
        ok, out, _ = self.run_all([self.res('1', 'suspicious', ['bad'])], strict=True)
        self.assertFalse(ok)
        self.assertIn('STRICT MODE: Failing due to suspicious citations', out)

    def test_strict_unverified_fails(self):
        ok, out, _ = self.run_all([self.res('1', 'verified'), self.res('2', 'unverified')], strict=True)
        self.assertFalse(ok)
        self.assertIn('STRICT MODE: Unverified citations found', out)


class TestMain(unittest.TestCase):
    def run_main(self, argv):
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['verify_citations.py', *argv]), \
                contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as cm:
            vc.main()
        return cm.exception.code, out.getvalue()

    def test_missing_report(self):
        code, out = self.run_main(['--report', '/nonexistent/none.md'])
        self.assertEqual(code, 1)
        self.assertIn('Report file not found', out)

    def test_pass_and_fail_exit_codes(self):
        d = tempfile.mkdtemp(dir=_ROOT)
        p = os.path.join(d, 'r.md')
        with open(p, 'w') as f:
            f.write('## Bibliography\n[1] X (2020). "T". https://e.com/a\n')
        with mock.patch.object(vc.CitationVerifier, 'verify_url', return_value=(True, 'ok')), \
                mock.patch.object(vc.time, 'sleep'):
            code, out = self.run_main(['-r', p])
        self.assertEqual(code, 0)
        self.assertIn('CITATION VERIFICATION PASSED', out)
        with open(p, 'w') as f:
            f.write('no bibliography\n')
        code, _ = self.run_main(['--report', p, '--strict'])
        self.assertEqual(code, 1)

    def test_run_as_script(self):
        import runpy
        d = tempfile.mkdtemp(dir=_ROOT)
        p = os.path.join(d, 'r.md')
        with open(p, 'w') as f:
            f.write('nothing\n')
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['verify_citations.py', '--report', p]), \
                contextlib.redirect_stdout(out), self.assertRaises(SystemExit) as cm:
            runpy.run_path(SCRIPT, run_name='__main__')
        self.assertEqual(cm.exception.code, 1)
        self.assertIn('No bibliography entries found', out.getvalue())


if __name__ == '__main__':
    unittest.main()
