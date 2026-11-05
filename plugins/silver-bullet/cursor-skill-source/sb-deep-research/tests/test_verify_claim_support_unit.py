#!/usr/bin/env python3
"""In-process unit tests for verify_claim_support.py (offline, deterministic)."""

from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import json
import os
import runpy
import shutil
import sys
import tempfile
import unittest
from unittest import mock

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts', 'verify_claim_support.py')
if os.path.dirname(os.path.abspath(SCRIPT)) not in sys.path:
    sys.path.insert(0, os.path.dirname(os.path.abspath(SCRIPT)))
_spec = importlib.util.spec_from_file_location('verify_claim_support_under_test', SCRIPT)
vcs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vcs)

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


def tmpdir():
    return tempfile.mkdtemp(dir=_ROOT)


def put_jsonl(d, name, rows):
    with open(os.path.join(d, name), 'w') as f:
        for r in rows:
            f.write(json.dumps(r) + '\n')


def get_jsonl(d, name):
    with open(os.path.join(d, name)) as f:
        return [json.loads(x) for x in f if x.strip()]


def put(d, name, text):
    with open(os.path.join(d, name), 'w') as f:
        f.write(text)


class TestJsonl(unittest.TestCase):
    def test_missing_file(self):
        self.assertEqual(vcs.read_jsonl('/nonexistent/x.jsonl'), [])

    def test_roundtrip_skips_blank_lines(self):
        d = tmpdir()
        p = os.path.join(d, 'a.jsonl')
        vcs.write_jsonl_atomic(p, [{'a': 'é'}, {'b': 2}])
        with open(p, 'a') as f:
            f.write('\n   \n')
        self.assertEqual(vcs.read_jsonl(p), [{'a': 'é'}, {'b': 2}])
        with open(p, encoding='utf-8') as f:
            self.assertIn('é', f.read())


class TestParagraphBoundaries(unittest.TestCase):
    """Citation inference stays inside the claim's own paragraph (R11-02)."""

    def infer(self, md, claim):
        return vcs.infer_citation_numbers_from_context(md, claim)

    def test_long_paragraph_has_no_length_cap(self):
        md = 'Claim here. ' + 'x' * 3000 + ' [7]'
        self.assertEqual(self.infer(md, 'Claim here.'), [7])

    def test_blank_line_heading_and_list_items_end_the_paragraph(self):
        self.assertEqual(self.infer('Claim here.\n\n[7]', 'Claim here.'), [])
        self.assertEqual(self.infer('Claim here.\n## H\n[7]', 'Claim here.'), [])
        self.assertEqual(self.infer('- Claim here.\n- other [7]', 'Claim here.'), [])
        self.assertEqual(self.infer('1. Claim here.\n2) other [7]', 'Claim here.'), [])
        # A wrapped line inside the same paragraph still counts.
        self.assertEqual(self.infer('Claim here and\nit continues [7].\n\nNext [8].', 'Claim here and'), [7])


class TestLocators(unittest.TestCase):
    def test_canonicalize(self):
        c = vcs.canonicalize_locator
        self.assertEqual(c('HTTP://Example.COM/a/b/?utm_source=x&b=2&a=1&ref=y#frag'),
                         'http://example.com/a/b?a=1&b=2')
        # no scheme and no netloc: urlparse treats it as a path, host stays empty
        self.assertEqual(c('example.com/path'), 'https:example.com/path')
        self.assertEqual(c('https://x.org/p/?utm_term=1'), 'https://x.org/p')

    def test_source_id_stable(self):
        a = vcs.compute_source_id('https://x.org')
        self.assertEqual(len(a), 16)
        self.assertEqual(a, vcs.compute_source_id('https://x.org'))
        self.assertNotEqual(a, vcs.compute_source_id('https://y.org'))


CM_SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts', 'citation_manager.py')
_cm_spec = importlib.util.spec_from_file_location('citation_manager_under_test', CM_SCRIPT)
cm = importlib.util.module_from_spec(_cm_spec)
_cm_spec.loader.exec_module(cm)

PARITY_URLS = [
    ('https://doi.org/10.1000/xyz', 'doi:10.1000/xyz'),
    ('http://dx.doi.org/10.1000/XYZ.', 'doi:10.1000/XYZ'),
    ('doi:10.1234/abc', 'doi:10.1234/abc'),
    ('https://arxiv.org/abs/2101.12345v2', 'arxiv:2101.12345v2'),
    ('arXiv:2101.12345', 'arxiv:2101.12345'),
    ('HTTP://Example.COM/a/b/', 'http://example.com/a/b'),
    ('https://example.com/p?utm_source=x&b=2&a=1&ref=y#frag', 'https://example.com/p?a=1&b=2'),
    ('https://example.com/p/?utm_term=1', 'https://example.com/p'),
    ('example.com', 'https:example.com'),
    ('example.com/path', 'https:example.com/path'),
    ('//example.com/x', 'https://example.com/x'),
    ('ftp://Files.Example.com/x/', 'ftp://files.example.com/x'),
]


class TestCanonicalParity(unittest.TestCase):
    """canonicalize_locator must agree with citation_manager so source_ids match."""

    def test_table(self):
        for raw, expected in PARITY_URLS:
            with self.subTest(raw):
                self.assertEqual(cm.canonicalize_locator(raw), expected)
                self.assertEqual(vcs.canonicalize_locator(raw), expected)
                self.assertEqual(vcs.compute_source_id(vcs.canonicalize_locator(raw)),
                                 cm.compute_source_id(cm.canonicalize_locator(raw)))

    def test_regexes_and_tracking_params_match(self):
        self.assertEqual(vcs.DOI_RE.pattern, cm.DOI_RE.pattern)
        self.assertEqual(vcs.ARXIV_RE.pattern, cm.ARXIV_RE.pattern)
        self.assertEqual(vcs.TRACKING_PARAMS, cm.TRACKING_PARAMS)


class TestFindReport(unittest.TestCase):
    def test_manifest_valid(self):
        d = tmpdir()
        put(d, 'my.md', 'x')
        put(d, 'run_manifest.json', json.dumps({'artifact_paths': {'report': 'my.md'}}))
        put(d, 'research_report_a.md', 'y')
        self.assertEqual(vcs._find_report_path(d), os.path.join(d, 'my.md'))

    def test_manifest_cases_fall_through(self):
        d = tmpdir()
        put(d, 'research_report_a.md', 'y')
        for manifest in ('{not json', json.dumps({}), json.dumps({'artifact_paths': {'report': 'gone.md'}}),
                         json.dumps({'artifact_paths': None})):
            put(d, 'run_manifest.json', manifest)
            self.assertEqual(vcs._find_report_path(d), os.path.join(d, 'research_report_a.md'))

    def test_multiple_reports_newest_wins(self):
        d = tmpdir()
        a, b = os.path.join(d, 'research_report_a.md'), os.path.join(d, 'research_report_b.md')
        put(d, 'research_report_a.md', 'a')
        put(d, 'research_report_b.md', 'b')
        os.utime(a, (1000, 1000))
        os.utime(b, (2000, 2000))
        self.assertEqual(vcs._find_report_path(d), b)
        os.utime(a, (3000, 3000))
        self.assertEqual(vcs._find_report_path(d), a)

    def test_other_markdown_is_never_taken_for_the_report(self):
        # R11-14: critique.md, handoff.md or decision-record.md must never stand in for the report.
        d = tmpdir()
        put(d, 'README.md', 'r')
        put(d, 'critique.md', 'c')
        os.mkdir(os.path.join(d, 'dir.md'))
        self.assertIsNone(vcs._find_report_path(d))
        put(d, 'research_report.md', 'the report')
        os.utime(os.path.join(d, 'critique.md'), (4_000_000_000, 4_000_000_000))
        self.assertEqual(vcs._find_report_path(d), os.path.join(d, 'research_report.md'))

    def test_empty_dir(self):
        self.assertIsNone(vcs._find_report_path(tmpdir()))


BIB_MD = """# Report
## Findings
Text [1].
## Bibliography
intro line
[1] Title [link](https://a.com/x)
[2] No link here
[x] bad entry
[3] Another [l](https://b.com/y) and [m](https://c.com/z)
## Appendix
[4] After [l](https://d.com)
"""


class TestBibliography(unittest.TestCase):
    def test_parse(self):
        out = vcs.parse_bibliography_number_to_url(BIB_MD)
        self.assertEqual(out, {1: 'https://a.com/x', 3: 'https://b.com/y'})

    def test_no_bibliography(self):
        self.assertEqual(vcs.parse_bibliography_number_to_url('## Findings\n[1] x [l](https://a.com)\n'), {})


class TestHugeNumbers(unittest.TestCase):
    """Regression: int() on 5000 digits raises ValueError on Python 3.11+."""

    def test_huge_bibliography_number_ignored(self):
        md = '## Bibliography\n[' + '1' * 5000 + '] [x](http://a.com)\n[2] [y](http://b.com)\n'
        self.assertEqual(vcs.parse_bibliography_number_to_url(md), {2: 'http://b.com'})

    def test_huge_inline_citation_ignored(self):
        md = 'Claim here [3] and [' + '1' * 5000 + '].'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Claim here'), [3])
        md = 'Claim here.\n\n[' + '9' * 5000 + ', 2]'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Claim here.'), [])

    def test_citation_numbers_are_bounded_to_four_digits(self):
        # An identifier such as [20240101] in body text is not a citation.
        md = '## Bibliography\n[12345] [x](http://a.com)\n[1234] [y](http://b.com)\n'
        self.assertEqual(vcs.parse_bibliography_number_to_url(md), {1234: 'http://b.com'})
        self.assertEqual(vcs.infer_citation_numbers_from_context('Claim [20240101] [1234, 5]', 'Claim'), [1234, 5])


class TestDisplayMapping(unittest.TestCase):
    def test_by_raw_canonical_and_computed(self):
        canon = vcs.canonicalize_locator('https://c.com/z/')
        sources = [
            {'source_id': 's1', 'raw_url': 'https://a.com/x'},
            {'source_id': 's2', 'canonical_locator': vcs.canonicalize_locator('https://b.com/y')},
            {'source_id': vcs.compute_source_id(canon)},
            {'raw_url': 'https://nope.com'},  # no source_id: ignored
        ]
        bib = {1: 'https://a.com/x', 2: 'https://b.com/y?utm_source=q', 3: 'https://c.com/z/', 4: 'https://unknown.com'}
        out = vcs.build_display_number_to_source_id(sources, bib)
        self.assertEqual(out, {1: 's1', 2: 's2', 3: vcs.compute_source_id(canon)})

    def test_doi_bibliography_url_resolves_to_citation_manager_source_id(self):
        sid = cm.compute_source_id(cm.canonicalize_locator('https://doi.org/10.1000/xyz'))
        sources = [{'source_id': sid}]
        out = vcs.build_display_number_to_source_id(sources, {1: 'https://doi.org/10.1000/xyz'})
        self.assertEqual(out, {1: sid})

    def test_fallback_registration_order(self):
        sources = [{'source_id': 'a'}, {'source_id': 'a'}, {}, {'source_id': 'b'}]
        self.assertEqual(vcs.build_display_number_to_source_id(sources, None), {1: 'a', 2: 'b'})
        # bibliography present but nothing resolves -> fallback too
        self.assertEqual(vcs.build_display_number_to_source_id(sources, {1: 'https://zz.com'}), {1: 'a', 2: 'b'})


class TestInfer(unittest.TestCase):
    def test_empty_inputs(self):
        self.assertEqual(vcs.infer_citation_numbers_from_context('', 'x'), [])
        self.assertEqual(vcs.infer_citation_numbers_from_context('x', ''), [])

    def test_not_found(self):
        self.assertEqual(vcs.infer_citation_numbers_from_context('abc', 'zzz'), [])

    def test_paragraph_citations_deduped(self):
        md = 'Intro.\n\nClaim one is true. More [2, 3] and [2].\n\nOther [9].'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Claim one is true.'), [2, 3])

    def test_bold_stripped_match(self):
        md = 'The **fork** works [4].\n\nz'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'The fork works'), [4])

    def test_last_paragraph_without_blank_line(self):
        md = 'Start claim here [5]'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Start claim here'), [5])

    def test_no_inheritance_from_the_next_paragraph(self):
        md = 'Claim only.\n\nNext para cites [7].'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Claim only.'), [])

    def test_no_citations_anywhere(self):
        self.assertEqual(vcs.infer_citation_numbers_from_context('Claim.\n\nNothing.', 'Claim.'), [])


def run_cmd(fn, **kw):
    out = io.StringIO()
    code = None
    with contextlib.redirect_stdout(out):
        try:
            fn(argparse.Namespace(**kw))
        except SystemExit as e:
            code = e.code
    return code, out.getvalue()


class TestCmdVerify(unittest.TestCase):
    def test_full_flow(self):
        d = tmpdir()
        put(d, 'research_report_x.md',
            '# R\n## Findings\nTesla shipped 500 cars in 2023 [1].\n\nCited elsewhere claim text.\nSee [1].\n'
            '## Bibliography\n[1] T [l](https://t.com/a)\n')
        put_jsonl(d, 'sources.jsonl', [{'source_id': 's1', 'raw_url': 'https://t.com/a'}])
        put_jsonl(d, 'evidence.jsonl', [
            {'evidence_id': 'e1', 'source_id': 's1', 'quote': 'Tesla shipped 500 cars in 2023'},
            {'evidence_id': 'e2', 'source_id': 'other', 'quote': 'unrelated'},
        ])
        put_jsonl(d, 'claims.jsonl', [
            {'claim_id': 'c1', 'section_id': 'bibliography', 'text': 'kept, not scored'},
            {'claim_id': 'c2', 'section_id': 'findings', 'claim_type': 'factual',
             'text': 'Tesla shipped 500 cars in 2023', '_citation_numbers': [1]},
            {'claim_id': 'c2', 'section_id': 'findings', 'text': 'duplicate dropped'},
            {'claim_id': 'c3', 'section_id': 'findings', 'text': 'Cited elsewhere claim text.'},
            {'claim_id': 'c4', 'section_id': 'findings', 'claim_type': 'factual', 'text': 'No links at all'},
            {'claim_id': 'c5', 'section_id': 'findings', 'claim_type': 'speculation', 'text': 'Maybe'},
            {'claim_id': 'c6', 'section_id': 'recommendations', 'claim_type': 'factual', 'text': 'Do it'},
            {'claim_id': 'c7', 'section_id': 'synthesis', 'claim_type': 'factual', 'text': 'Interpret'},
            {'claim_id': 'c8', 'section_id': 'conclusion', 'claim_type': 'factual', 'text': 'Cited',
             '_citation_numbers': [9]},
            {'claim_id': 'c9', 'section_id': 'findings', 'claim_type': 'factual', 'text': 'x',
             'cited_source_ids': ['no-evidence-src']},
            {'claim_id': 'c10', 'section_id': 'findings', 'claim_type': 'factual', 'text': 'Tesla shipped 500 cars in 2023',
             'evidence_ids': ['e1', 'missing']},
        ])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=False, report=None)
        self.assertIsNone(code)
        summary = json.loads(out)
        rows = {c['claim_id']: c for c in get_jsonl(d, 'claims.jsonl')}
        self.assertEqual(len(rows), 10)  # every distinct claim survives, the duplicate is merged
        self.assertEqual(rows['c1']['support_status'], 'not_applicable')
        self.assertEqual(rows['c2']['support_status'], 'supported')
        self.assertEqual(rows['c2']['cited_source_ids'], ['s1'])
        self.assertEqual(rows['c3']['_citation_numbers'], [1])
        self.assertEqual(rows['c3']['cited_source_ids'], ['s1'])
        self.assertEqual(rows['c4']['support_status'], 'unsupported')
        self.assertEqual(rows['c5']['support_status'], 'not_applicable')
        self.assertEqual(rows['c6']['claim_type'], 'recommendation')
        self.assertEqual(rows['c6']['support_status'], 'unsupported')
        self.assertEqual(rows['c7']['claim_type'], 'synthesis')
        self.assertEqual(rows['c8']['claim_type'], 'factual')  # had citations: stays factual
        self.assertEqual(rows['c8']['cited_source_ids'], [])
        self.assertEqual(rows['c9']['support_status'], 'unsupported')
        self.assertEqual(rows['c9']['_support_notes'], 'cited source has no captured evidence')
        self.assertEqual(rows['c10']['support_status'], 'supported')
        self.assertIn('_support_score', rows['c10'])
        self.assertEqual(summary['status'], 'pass')
        self.assertEqual(summary['report'], 'research_report_x.md')
        self.assertEqual(summary['verified'], 8)  # not_applicable rows are not scored
        self.assertEqual(summary['factual_unsupported'], 4)  # c3, c4, c8 and c9
        self.assertEqual((summary['factual_contradicted'], summary['factual_needs_review']), (0, 0))
        self.assertEqual(summary['factual_not_supported'], 4)
        self.assertFalse(summary['review_required'])
        self.assertEqual(summary['total_factual'], 6)
        self.assertEqual(summary['support_status_counts']['unsupported'], 6)  # the four above, c6 and c7

    def test_strict_fails_exit_1(self):
        d = tmpdir()
        put(d, 'research_report.md', '# R\n')
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'claim_type': 'factual', 'text': 't'}])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True, report=None)
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)['status'], 'fail')
        self.assertEqual(json.loads(out)['unsupported_rate'], 1.0)

    def test_strict_lists_needs_review_claims_without_failing(self):
        d = tmpdir()
        put(d, 'research_report.md', '# R\n')
        put_jsonl(d, 'evidence.jsonl', [{'evidence_id': 'e1', 'source_id': 's', 'quote': 'alpha bravo'}])
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'claim_type': 'factual',
                                       'text': 'alpha bravo charlie delta eeee', 'evidence_ids': ['e1']}])
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True, report=None)
        self.assertIsNone(code)
        summary = json.loads(out)
        self.assertEqual((summary['status'], summary['factual_unsupported'], summary['factual_needs_review']), ('pass', 0, 1))
        self.assertTrue(summary['review_required'])
        self.assertEqual(summary['needs_review'][0]['claim_id'], 'a')
        self.assertIn('says more than the source text', summary['needs_review'][0]['reason'])
        self.assertIn('1 factual claim(s) need review', err.getvalue())

    def test_strict_fails_on_a_contradicted_claim(self):
        d = tmpdir()
        put(d, 'research_report.md', '# R\n')
        put_jsonl(d, 'evidence.jsonl', [{'evidence_id': 'e1', 'source_id': 's', 'quote': 'Acme raised 40 million in 2023'}])
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'claim_type': 'factual',
                                       'text': 'Acme raised 50 million in 2023', 'evidence_ids': ['e1']}])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True, report=None)
        self.assertEqual(code, 1)
        summary = json.loads(out)
        self.assertEqual((summary['status'], summary['factual_contradicted']), ('fail', 1))
        self.assertEqual(get_jsonl(d, 'claims.jsonl')[0]['support_status'], 'contradicted')
        # Without --strict nothing fails, whatever the verdict.
        code, _ = run_cmd(vcs.cmd_verify, dir=d, strict=False, report=None)
        self.assertIsNone(code)

    def test_claim_without_claim_type_defaults_to_factual_and_is_persisted(self):
        # Regression: the 'factual' default was applied to a local variable
        # only, so such a claim was never counted as factual and --strict
        # could not fail on it.
        d = tmpdir()
        put(d, 'research_report.md', '# R\n')
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'text': 't'}])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True, report=None)
        self.assertEqual(code, 1)
        summary = json.loads(out)
        self.assertEqual((summary['factual_unsupported'], summary['total_factual']), (1, 1))
        self.assertEqual(get_jsonl(d, 'claims.jsonl')[0]['claim_type'], 'factual')

    def test_strict_passes_when_no_factual_claims(self):
        d = tmpdir()
        put(d, 'research_report.md', '# R\n')
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'claim_type': 'speculation', 'text': 't'}])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True, report=None)
        self.assertIsNone(code)
        self.assertEqual(json.loads(out)['status'], 'pass')

    def test_explicit_report_wins(self):
        d = tmpdir()
        put(d, 'research_report.md', 'not this one')
        other = os.path.join(d, 'other-report.md')
        put(d, 'other-report.md', '# R\n')
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=False, report=other)
        self.assertIsNone(code)
        self.assertEqual(json.loads(out)['report'], 'other-report.md')

    def test_missing_report_fails_closed(self):
        d = tmpdir()
        err = io.StringIO()
        with contextlib.redirect_stderr(err):
            code, _ = run_cmd(vcs.cmd_verify, dir=d, strict=True, report=None)
        self.assertEqual(code, 2)
        self.assertIn('report not found', err.getvalue())
        with mock.patch.object(vcs, '_find_report_path', return_value=os.path.join(d, 'ghost.md')), \
                contextlib.redirect_stderr(io.StringIO()):
            code, _ = run_cmd(vcs.cmd_verify, dir=d, strict=False, report=None)
        self.assertEqual(code, 2)


class TestCmdReport(unittest.TestCase):
    def test_with_unsupported(self):
        d = tmpdir()
        put_jsonl(d, 'claims.jsonl', [
            {'claim_id': 'a', 'section_id': 'sec', 'claim_type': 'factual', 'support_status': 'unsupported',
             'text': 'T' * 150, '_support_notes': 'low lexical overlap'},
            {'claim_id': 'a', 'section_id': 'sec', 'claim_type': 'factual', 'support_status': 'unsupported', 'text': 'dup'},
            {'claim_id': 'b', 'section_id': 'sec2', 'claim_type': 'factual', 'support_status': 'needs_review', 'text': 'short'},
            {'claim_id': 'c', 'section_id': 'sec', 'claim_type': 'synthesis', 'support_status': 'unsupported', 'text': 'n/a'},
            {'claim_id': 'd', 'section_id': 'sec', 'claim_type': 'factual', 'support_status': 'partial', 'text': 'half'},
            {'claim_id': 'e', 'section_id': 'sec3', 'claim_type': 'factual', 'support_status': 'contradicted', 'text': 'Acme raised'},
        ])
        code, out = run_cmd(vcs.cmd_report, dir=d)
        self.assertIsNone(code)
        self.assertIn('**Total claims:** 5', out)
        self.assertIn('## Unsupported Factual Claims', out)
        self.assertIn('## Needs Review (check each against its source before relying on it)', out)
        self.assertIn('Resolve each item: quote the exact span of the source', out)
        self.assertIn('## Contradicted Factual Claims', out)
        self.assertIn('- [contradicted] `sec3`: Acme raised...', out)
        self.assertIn('- [unsupported] `sec`: ' + 'T' * 100 + '...', out)
        self.assertNotIn('T' * 101, out)
        self.assertIn('  Notes: low lexical overlap', out)
        self.assertIn('- [needs_review] `sec2`: short...', out)
        self.assertIn('- [partial] `sec`: half...', out)
        self.assertNotIn('All factual claims', out)

    def test_all_clear(self):
        d = tmpdir()
        put_jsonl(d, 'claims.jsonl', [
            {'claim_id': 'a', 'section_id': 's', 'claim_type': 'factual', 'support_status': 'supported', 'text': 't'}])
        _, out = run_cmd(vcs.cmd_report, dir=d)
        self.assertIn('## All factual claims have adequate support.', out)

    def test_missing_claims_file(self):
        _, out = run_cmd(vcs.cmd_report, dir=tmpdir())
        self.assertIn('**Total claims:** 0', out)
        self.assertIn('All factual claims have adequate support.', out)


class TestMain(unittest.TestCase):
    def test_dispatch(self):
        d = tmpdir()
        put(d, 'research_report.md', '# R\n')
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['v', 'report', '--dir', d]), contextlib.redirect_stdout(out):
            vcs.main()
        self.assertIn('Claim Support Verification Report', out.getvalue())
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['v', 'verify', '--dir', d]), contextlib.redirect_stdout(out):
            vcs.main()
        self.assertEqual(json.loads(out.getvalue())['status'], 'pass')

    def test_corrupt_ledger_exits_2(self):
        d = tmpdir()
        put(d, 'research_report.md', '# R\n')
        put(d, 'claims.jsonl', '[1, 2]\n')
        err = io.StringIO()
        with mock.patch.object(sys, 'argv', ['v', 'verify', '--dir', d]), contextlib.redirect_stderr(err), \
                self.assertRaises(SystemExit) as ctx:
            vcs.main()
        self.assertEqual(ctx.exception.code, 2)
        self.assertIn('expected a JSON object', err.getvalue())

    def test_missing_command_is_usage_error(self):
        err = io.StringIO()
        with mock.patch.object(sys, 'argv', ['v']), contextlib.redirect_stderr(err), \
                self.assertRaises(SystemExit) as cm:
            vcs.main()
        self.assertEqual(cm.exception.code, 2)

    def test_run_as_script(self):
        d = tmpdir()
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['v', 'report', '--dir', d]), contextlib.redirect_stdout(out):
            runpy.run_path(SCRIPT, run_name='__main__')
        self.assertIn('Total claims', out.getvalue())


if __name__ == '__main__':
    unittest.main()
