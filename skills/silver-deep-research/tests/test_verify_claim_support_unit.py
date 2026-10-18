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
import sys
import tempfile
import unittest
from unittest import mock

SCRIPT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'scripts', 'verify_claim_support.py')
_spec = importlib.util.spec_from_file_location('verify_claim_support_under_test', SCRIPT)
vcs = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(vcs)


def tmpdir():
    return tempfile.mkdtemp()


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
        vcs.write_jsonl(p, [{'a': 'é'}, {'b': 2}])
        with open(p, 'a') as f:
            f.write('\n   \n')
        self.assertEqual(vcs.read_jsonl(p), [{'a': 'é'}, {'b': 2}])
        with open(p, encoding='utf-8') as f:
            self.assertIn('é', f.read())


class TestExtractors(unittest.TestCase):
    def test_percent_and_x_suffixes_kept(self):
        # Regression: a trailing % was dropped unless a word character followed.
        self.assertEqual(vcs.extract_numbers('up 50% now'), {'50%'})
        self.assertEqual(vcs.extract_numbers('up 50%.'), {'50%'})
        self.assertEqual(vcs.extract_numbers('3x faster, 4X slower'), {'3x', '4X'})
        self.assertEqual(vcs.extract_numbers('3xyz and 7'), {'7'})
        self.assertNotIn('50%', vcs.extract_numbers('50 people'))
        score_pct = vcs.compute_support_score('Revenue grew 50% overall', ['Revenue grew 50 people overall'])[1]
        score_same = vcs.compute_support_score('Revenue grew 50% overall', ['Revenue grew 50% overall'])[1]
        self.assertLess(score_pct, score_same)

    def test_extractors(self):
        self.assertEqual(vcs.extract_tokens('The Quick fox jumped'), {'quick', 'jumped'})
        self.assertEqual(vcs.extract_numbers('grew 12.5 in 2020 by 3x'), {'12.5', '2020', '3x'})
        self.assertEqual(vcs.extract_years('in 1999 and 2024 but 3000'), {'1999', '2024'})
        self.assertEqual(vcs.extract_entities('Big Apple, However, Tesla'), {'Big Apple', 'Tesla'})


class TestScore(unittest.TestCase):
    def test_no_evidence(self):
        self.assertEqual(vcs.compute_support_score('x', []), ('unsupported', 0.0, 'no evidence linked'))

    def test_supported_full_match(self):
        text = 'Tesla delivered vehicles during 2023 numbering 500'
        status, score, notes = vcs.compute_support_score(text, [text])
        self.assertEqual((status, score, notes), ('supported', 1.0, 'adequate overlap'))

    def test_partial(self):
        claim = 'revenue growth accelerated sharply markets 2020'
        quote = 'revenue growth markets'
        status, score, notes = vcs.compute_support_score(claim, [quote])
        self.assertEqual((status, score), ('partial', 0.44))
        self.assertEqual(notes, 'number mismatch; year mismatch')

    def test_year_mismatch_is_detected_between_different_years(self):
        # Regression: the year regex captured only the century prefix, so
        # "2020" and "2019" both looked like "20" and always matched.
        claim = 'Tesla shipped vehicles in 2020'
        quote = 'Tesla shipped vehicles in 2019'
        status, score, notes = vcs.compute_support_score(claim, [quote])
        self.assertIn('year mismatch', notes)
        self.assertLess(score, 1.0)

    def test_zero_score_still_reports_notes(self):
        # Regression: a score of exactly 0.0 never replaced the initial best
        # score, so the notes stayed empty and read "adequate overlap".
        status, score, notes = vcs.compute_support_score('Zebra 2020 99', ['Giraffe words'])
        self.assertEqual((status, score), ('needs_review', 0.0))
        self.assertIn('low lexical overlap', notes)
        self.assertNotIn('adequate overlap', notes)

    def test_needs_review_all_notes(self):
        claim = 'Quantum Computing broke encryption 2020 in 99 cases'
        quote = 'Unrelated words zebra giraffe'
        status, score, notes = vcs.compute_support_score(claim, [quote])
        self.assertEqual(status, 'needs_review')
        self.assertEqual(notes, 'low lexical overlap; number mismatch; year mismatch; entity mismatch')

    def test_best_of_multiple_quotes_and_empty_claim_tokens(self):
        claim = 'Hi'  # no tokens (<4 chars), entity {Hi}
        status, score, _ = vcs.compute_support_score(claim, ['nothing', 'Hi there'])
        self.assertEqual(score, 0.6)
        self.assertEqual(status, 'supported')

    def test_later_lower_quote_does_not_override(self):
        claim = 'alpha bravo charlie delta'
        status, score, notes = vcs.compute_support_score(claim, [claim, 'zzz'])
        self.assertEqual((status, score), ('supported', 1.0))


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

    def test_any_md_excluding_readme(self):
        d = tmpdir()
        put(d, 'README.md', 'r')
        self.assertIsNone(vcs._find_report_path(d))
        put(d, 'old.md', 'o')
        put(d, 'new.md', 'n')
        os.mkdir(os.path.join(d, 'dir.md'))
        os.utime(os.path.join(d, 'old.md'), (1000, 1000))
        os.utime(os.path.join(d, 'new.md'), (2000, 2000))
        self.assertEqual(vcs._find_report_path(d), os.path.join(d, 'new.md'))

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
        md = 'Claim here [' + '1' * 5000 + '] and [3].'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Claim here'), [3])
        md = 'Claim here.\n\n[' + '9' * 5000 + ', 2]'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Claim here.'), [])

    def test_nine_digit_numbers_still_parsed(self):
        md = '## Bibliography\n[123456789] [x](http://a.com)\n'
        self.assertEqual(vcs.parse_bibliography_number_to_url(md), {123456789: 'http://a.com'})
        self.assertEqual(vcs.infer_citation_numbers_from_context('Claim [123456789, 5]', 'Claim'),
                         [123456789, 5])


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

    def test_forward_window_when_paragraph_has_none(self):
        md = 'Claim only.\n\nNext para cites [7].'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Claim only.'), [7])
        # duplicates collapse in the window as well
        md = 'Claim only.\n\nNext [7] and [7, 8].'
        self.assertEqual(vcs.infer_citation_numbers_from_context(md, 'Claim only.'), [7, 8])

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
            {'evidence_id': 'e1', 'source_id': 's1', 'quote': 'Tesla shipped 500 cars in 2023 worldwide'},
            {'evidence_id': 'e2', 'source_id': 'other', 'quote': 'unrelated'},
        ])
        put_jsonl(d, 'claims.jsonl', [
            {'claim_id': 'c1', 'section_id': 'bibliography', 'text': 'dropped'},
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
            {'claim_id': 'c10', 'section_id': 'findings', 'claim_type': 'factual', 'text': 'Tesla',
             'evidence_ids': ['e1', 'missing']},
        ])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=False)
        self.assertIsNone(code)
        summary = json.loads(out)
        rows = {c['claim_id']: c for c in get_jsonl(d, 'claims.jsonl')}
        self.assertNotIn('c1', rows)
        self.assertEqual(rows['c2']['support_status'], 'supported')
        self.assertEqual(rows['c2']['cited_source_ids'], ['s1'])
        self.assertEqual(rows['c3']['_citation_numbers'], [1])
        self.assertEqual(rows['c3']['cited_source_ids'], ['s1'])
        self.assertEqual(rows['c4']['support_status'], 'unsupported')
        self.assertEqual(rows['c5']['support_status'], 'supported')
        self.assertEqual(rows['c6']['claim_type'], 'recommendation')
        self.assertEqual(rows['c6']['support_status'], 'unsupported')
        self.assertEqual(rows['c7']['claim_type'], 'synthesis')
        self.assertEqual(rows['c8']['claim_type'], 'factual')  # had citations: stays factual
        self.assertEqual(rows['c8']['cited_source_ids'], [])
        self.assertEqual(rows['c9']['support_status'], 'needs_review')
        self.assertIn(rows['c10']['support_status'], ('supported', 'partial', 'needs_review'))
        self.assertIn('_support_score', rows['c10'])
        self.assertEqual(summary['status'], 'pass')
        self.assertEqual(summary['verified'], 9)
        self.assertEqual(summary['factual_unsupported'], 2)  # c4 and c8
        self.assertEqual(summary['total_factual'], sum(1 for c in rows.values() if c['claim_type'] == 'factual'))
        self.assertEqual(summary['support_status_counts']['unsupported'], 4)

    def test_strict_fails_exit_1(self):
        d = tmpdir()
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'claim_type': 'factual', 'text': 't'}])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True)
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)['status'], 'fail')
        self.assertEqual(json.loads(out)['unsupported_rate'], 1.0)

    def test_claim_without_claim_type_defaults_to_factual_and_is_persisted(self):
        # Regression: the 'factual' default was applied to a local variable
        # only, so such a claim was never counted as factual and --strict
        # could not fail on it.
        d = tmpdir()
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'text': 't'}])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True)
        self.assertEqual(code, 1)
        summary = json.loads(out)
        self.assertEqual((summary['factual_unsupported'], summary['total_factual']), (1, 1))
        self.assertEqual(get_jsonl(d, 'claims.jsonl')[0]['claim_type'], 'factual')

    def test_strict_passes_when_no_unsupported(self):
        d = tmpdir()
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'claim_type': 'speculation', 'text': 't'}])
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True)
        self.assertIsNone(code)
        self.assertEqual(json.loads(out)['status'], 'pass')

    def test_empty_dir_and_unreadable_report(self):
        d = tmpdir()
        code, out = run_cmd(vcs.cmd_verify, dir=d, strict=True)
        self.assertIsNone(code)
        self.assertEqual(json.loads(out)['verified'], 0)
        # report exists but open() fails -> tolerated
        put(d, 'research_report_a.md', '# x')
        put_jsonl(d, 'claims.jsonl', [{'claim_id': 'a', 'section_id': 's', 'text': 't', 'claim_type': 'speculation'}])
        real_open = open

        def flaky(path, *a, **k):
            if str(path).endswith('research_report_a.md'):
                raise OSError('denied')
            return real_open(path, *a, **k)
        with mock.patch('builtins.open', flaky):
            code, out = run_cmd(vcs.cmd_verify, dir=d, strict=False)
        self.assertIsNone(code)
        self.assertEqual(json.loads(out)['verified'], 1)

    def test_report_path_without_existing_file(self):
        d = tmpdir()
        with mock.patch.object(vcs, '_find_report_path', return_value=os.path.join(d, 'ghost.md')):
            code, out = run_cmd(vcs.cmd_verify, dir=d, strict=False)
        self.assertIsNone(code)
        self.assertEqual(json.loads(out)['status'], 'pass')


class TestCmdReport(unittest.TestCase):
    def test_with_unsupported(self):
        d = tmpdir()
        put_jsonl(d, 'claims.jsonl', [
            {'claim_id': 'a', 'section_id': 'sec', 'claim_type': 'factual', 'support_status': 'unsupported',
             'text': 'T' * 150, '_support_notes': 'low lexical overlap'},
            {'claim_id': 'a', 'section_id': 'sec', 'claim_type': 'factual', 'support_status': 'unsupported', 'text': 'dup'},
            {'claim_id': 'b', 'section_id': 'sec2', 'claim_type': 'factual', 'support_status': 'needs_review', 'text': 'short'},
            {'claim_id': 'c', 'section_id': 'sec', 'claim_type': 'synthesis', 'support_status': 'unsupported', 'text': 'n/a'},
        ])
        code, out = run_cmd(vcs.cmd_report, dir=d)
        self.assertIsNone(code)
        self.assertIn('**Total claims:** 3', out)
        self.assertIn('## Unsupported/Review-needed Factual Claims', out)
        self.assertIn('- [unsupported] `sec`: ' + 'T' * 100 + '...', out)
        self.assertNotIn('T' * 101, out)
        self.assertIn('  Notes: low lexical overlap', out)
        self.assertIn('- [needs_review] `sec2`: short...', out)
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
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['v', 'report', '--dir', d]), contextlib.redirect_stdout(out):
            vcs.main()
        self.assertIn('Claim Support Verification Report', out.getvalue())
        out = io.StringIO()
        with mock.patch.object(sys, 'argv', ['v', 'verify', '--dir', d]), contextlib.redirect_stdout(out):
            vcs.main()
        self.assertEqual(json.loads(out.getvalue())['status'], 'pass')

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
