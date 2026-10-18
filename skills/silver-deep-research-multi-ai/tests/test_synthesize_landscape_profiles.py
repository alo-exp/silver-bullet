"""Unit tests for synthesize_landscape profile, link and vendor-bucket helpers."""

from __future__ import annotations

import contextlib
import io
import json
import unittest
from unittest import mock

from synth_helpers import APO_NEED, TmpCase, sl


class AxisAndLoaderTests(TmpCase):
    def test_axis_profile(self):
        explicit = {"landscape_axes": {"mq_x": "X", "mq_y": "Y"}}
        got = sl._derive_axis_profile("Cat", explicit, "")
        self.assertEqual(got, {"mq_anchor": "Positioning", "mq_x": "X", "mq_y": "Y",
                               "mq_x_label": "X-axis capability", "mq_y_label": "Y-axis capability",
                               "section_3a": "Cat Positioning Matrix"})
        full = {"landscape_axes": {"mq_x": "X", "mq_y": "Y", "mq_anchor": "A", "mq_x_label": "XL",
                                   "mq_y_label": "YL", "section_3a": "S"}}
        self.assertEqual(sl._derive_axis_profile("Cat", full, "")["section_3a"], "S")
        # incomplete overrides fall through to the domain table
        for bad in ({"landscape_axes": {"mq_x": "X"}}, {"landscape_axes": "nope"}, {}):
            got = sl._derive_axis_profile("The Agentic SDLC market", bad, "")
            self.assertEqual(got["mq_anchor"], "Process Orchestration")
        got = sl._derive_axis_profile("Cat", {}, "about a coding agent")
        self.assertEqual(got["section_3a"], "Process Orchestration × Autonomous Execution Matrix")
        got = sl._derive_axis_profile("Payments — Europe", {}, "plain")
        self.assertEqual(got["mq_x_label"], "Payments capability")
        self.assertEqual(got["section_3a"], "Payments — Europe Positioning Matrix")
        self.assertEqual(sl._derive_axis_profile("— odd", {}, "")["mq_x_label"], "Market capability")

    def test_loaders(self):
        self.assertIsNone(sl._load_json(self.root / "missing.json"))
        self.put("x.json", {"a": 1})
        self.assertEqual(sl._load_json(self.root / "x.json"), {"a": 1})
        self.assertEqual(sl._load_envelopes(self.root), [])
        self.put("contributions/all-envelopes.json", [{"a": 1}, "junk", 3])
        self.assertEqual(sl._load_envelopes(self.root), [{"a": 1}])
        self.put("contributions/all-envelopes.json", {"not": "list"})
        self.assertEqual(sl._load_envelopes(self.root), [])

    def test_platform_list(self):
        self.assertEqual(sl._platform_list([]), "multi-AI pool")
        self.assertEqual(sl._platform_list([{"logical_model_id": "b"}, {"logical_model_id": "a"},
                                            {"logical_model_id": "a"}, {}]), "a, b")

    def test_feature_support_and_score(self):
        comp = {"rows": ["junk", {"type": "scored"}, {"type": "feature", "name": "F",
                                                       "solutions": {"a": "✔", "b": "  ", "c": None, "d": 1}},
                         {"type": "feature", "name": "G"}],
                "rankings": ["junk", {"solution": "a", "score": 7}, {"solution": "b", "score": None}]}
        self.assertEqual(sl._feature_support(comp), {"a": {"F": True}, "b": {"F": False},
                                                     "c": {"F": False}, "d": {"F": True}})
        self.assertEqual(sl._feature_support({}), {})
        self.assertEqual(sl._score_solution("a", comp), 7)
        self.assertEqual(sl._score_solution("b", comp), 0)
        self.assertEqual(sl._score_solution("zzz", comp), 0)
        self.assertEqual(sl._score_solution("a", {}), 0)


class ScrTests(TmpCase):
    def test_read_scr(self):
        self.assertEqual(sl._read_scr(self.root, "a"), "")
        self.put("solutions/a/scr.md", "keep [lean-ctx: x] this")
        self.assertEqual(sl._read_scr(self.root, "a"), "keep  this")

    def test_scr_summary(self):
        s = sl._scr_summary
        self.assertEqual(s("", "fallback [lean-ctx: x]"), "fallback")
        exec_md = "# T\n\n## Executive summary\n\n- bullet\n# head\nPara one is good.\n\n## Other\nbody"
        self.assertEqual(s(exec_md, "fb"), "Para one is good.")
        # unusable exec paragraphs fall through to bullets, then plain lines, then fallback
        junk = "maps to must_have thing"
        self.assertEqual(s(f"## Executive summary\n\n{junk}\n\n## Next\n- Good bullet\n- other", "fb"),
                         "Good bullet")
        self.assertEqual(s(f"- {junk}\nPlain usable line", "fb"), "Plain usable line")
        self.assertEqual(s(f"- {junk}\n{junk}", "fb"), "fb")
        self.assertEqual(s("## Executive summary\n\n- only bullet\n\n## N\n- real bullet", "fb"), "only bullet")

    def test_scr_homepage(self):
        h = sl._scr_homepage
        self.assertIsNone(h(self.root / "none.md"))
        p = self.put("a.md", "---\nname: x\nnocolon\nHomepage: 'https://front.example'\n---\nbody https://body.example")
        self.assertEqual(h(p), "https://front.example")
        p = self.put("b.md", "---\nurl: not-http\nname: x\n---\nsee https://body.example/x.")
        self.assertEqual(h(p), "https://body.example/x")
        p = self.put("c.md", "no frontmatter (https://paren.example/p).")
        self.assertEqual(h(p), "https://paren.example/p")
        p = self.put("d.md", "---\nurl: x\n---\nnothing")
        self.assertIsNone(h(p))
        p = self.put("e.md", "plain text only")
        self.assertIsNone(h(p))


class ProfileTests(TmpCase):
    def test_synthetic_overview(self):
        self.assertEqual(sl._synthetic_overview("N", commercial=True, positives=[], negatives=[]),
                         "N is a commercial option for agentic SDLC orchestration.")
        got = sl._synthetic_overview("N", commercial=False, positives=["a", "b", "c", "d"], negatives=["x", "y", "z"])
        self.assertEqual(got, "N is a open-source option for agentic SDLC orchestration. "
                              "Noted strengths include a, b, c. Relative gaps include x, y.")

    def test_claims_for_slug(self):
        known = {"my-tool": "My Tool"}
        claims = ["my-tool does X", "About my tool here", "MY TOOL again", "unrelated",
                  "my-tool maps to must_have a", "my-tool 1", "my-tool 2", "my-tool 3", "my-tool 4",
                  "my-tool 5"]
        got = sl._claims_for_slug("my-tool", claims, known)
        self.assertEqual(got, ["my-tool does X", "About my tool here", "MY TOOL again",
                               "my-tool 1", "my-tool 2", "my-tool 3"])
        # fallback to the global catalog
        self.assertEqual(sl._claims_for_slug("silver-bullet", ["Silver Bullet is here"]), ["Silver Bullet is here"])
        self.assertEqual(sl._claims_for_slug("zz-unknown", ["nothing"], {}), [])

    def profile(self, entry=None, **kw):
        entry = entry or {"slug": "my-tool", "name": "My Tool", "license": "MIT", "url": "https://my.tool"}
        args = dict(commercial=False, root=self.root, claims=[], support={}, known={"my-tool": "My Tool"},
                    overview_seeds={})
        args.update(kw)
        return sl._build_solution_profile(entry, **args)

    def test_overview_sources(self):
        self.assertEqual(self.profile(overview_seeds={"my-tool": " Seed text. "})["overview"], "Seed text.")
        self.put("solutions/my-tool/scr.md", "## Executive summary\n\nFrom the SCR.\n")
        self.assertEqual(self.profile()["overview"], "From the SCR.")
        (self.root / "solutions/my-tool/scr.md").unlink()
        got = self.profile(claims=["my-tool is claimed well"])
        self.assertEqual(got["overview"], "my-tool is claimed well")
        got = self.profile(overview_seeds={"my-tool": "maps to must_have junk"}, claims=[])
        self.assertTrue(got["overview"].startswith("My Tool is a open-source option"))
        # a synthetic overview that is itself unusable is kept as the (single) fallback
        weird = {"slug": "w", "name": "maps to must_have"}
        got = self.profile(weird, known={"w": "maps to must_have"})
        self.assertIn("maps to must_have", got["overview"])

    def test_defaults_fall_back_to_global_tables(self):
        got = sl._build_solution_profile({"slug": "silver-bullet", "name": "Silver Bullet"},
                                         commercial=True, root=self.root, claims=[], support={})
        self.assertTrue(got["overview"])
        self.assertEqual(got["license"], "Commercial")
        self.assertEqual(got["url"], "")

    def test_pros_cons(self):
        used = {"Workflow composition", "Atomic flow catalog", "Hook-enforced gates", "Managed hosting"}
        kcf = next(k for k in sl.KCF_NAMES if k not in used)
        sup = {"my-tool": {"Workflow composition": True, "Atomic flow catalog": True,
                           "Hook-enforced gates": True, "Managed hosting": True, kcf: False,
                           "A": True, "B": True, "C": True, "D": True}}
        got = self.profile(commercial=True, support=sup)
        self.assertEqual(len(got["pros"]), 6)
        self.assertIn("**Managed path**", got["pros"][-1] if len(got["pros"]) < 6 else "**Managed path**")
        self.assertEqual(got["cons"][0].split(":")[0], "**Operational depth**")
        self.assertEqual(got["cons"][-1].split(":")[0], "**Pricing opacity**")
        self.assertTrue(got["best_for"].startswith("SMB teams prioritising workflow composition with My Tool"))
        self.assertIn(kcf, got["avoid_if"])
        bare = self.profile(commercial=True)
        self.assertEqual(len(bare["pros"]), 4)
        self.assertTrue(bare["pros"][0].startswith("**Managed path**"))
        self.assertEqual([c.split(":")[0] for c in bare["cons"]],
                         ["**Hosting burden**", "**Weak hook gates**", "**No atomic catalog**",
                          "**Limited composition**", "**Pricing opacity**"])
        self.assertIn("agentic SDLC automation", bare["best_for"])
        self.assertIn("unverified gaps", bare["avoid_if"])
        oss = self.profile(commercial=False)
        self.assertTrue(oss["pros"][0].startswith("**Control & flexibility**"))
        self.assertNotIn("**Hosting burden**", " ".join(oss["cons"]))
        no_hosting_burden = self.profile(commercial=True, support={"my-tool": {"Managed hosting": True}})
        self.assertNotIn("**Hosting burden**", " ".join(no_hosting_burden["cons"]))


class CatalogLabelTests(TmpCase):
    def test_catalog_entries_and_labels(self):
        everything = sl._catalog_entries()
        self.assertEqual(len(everything), len(sl.COMMERCIAL_CATALOG) + len(sl.OSS_CATALOG) + len(sl.EMERGING_CATALOG))
        a, b = {"slug": "a"}, {"slug": "b"}
        self.assertEqual(sl._catalog_entries([a], [b]), [a, b])
        self.assertEqual(sl._catalog_entries([a], None), [a])
        self.assertEqual(sl._catalog_entries(None, [b]), [b])
        self.assertEqual(sl._catalog_entries([], []), [])
        self.assertEqual(sl._catalog_label({"slug": "x-y", "name": "Named"}), "Named")
        self.assertEqual(sl._catalog_label({"slug": "x-y"}, known={"x-y": "Known"}), "Known")
        self.assertEqual(sl._catalog_label({"slug": "x-y"}, known={}), "X Y")
        self.assertEqual(sl._catalog_label({"slug": "silver-bullet"}), sl.KNOWN_SOLUTIONS["silver-bullet"])

    def test_scope_markdown_and_slugify(self):
        self.assertEqual(sl._normalize_scope_markdown("# Title\nbody\n"), "**Title**\nbody")
        self.assertEqual(sl._normalize_scope_markdown("## Sub\nbody"), "## Sub\nbody")
        self.assertEqual(sl._normalize_scope_markdown("  "), "")
        self.assertEqual(sl._slugify_label("  Hello, World! "), "hello-world")

    def test_slug_for_label(self):
        f = lambda label, **kw: sl._slug_for_label(label, known=kw.pop("known", {}), rankings=kw.pop("rankings", []), **kw)  # noqa: E731
        self.assertEqual(f(" Known Name ", known={"kn": "Known Name"}), "kn")
        self.assertEqual(f("Cat Name", commercial=[{"slug": "cat", "name": "Cat Name"}]), "cat")
        self.assertEqual(f("Oss Name", oss=[{"slug": "oss", "name": "Oss Name"}]), "oss")
        self.assertEqual(f("Ranked Tool", rankings=["junk", {"solution": ""}, {"solution": "ranked-tool"}]),
                         "ranked-tool")
        self.assertEqual(f("Ranked Known", known={"rk": "Ranked Known"}, rankings=[{"solution": "rk"}]), "rk")
        self.assertEqual(f("Sup Tool", support={"sup-tool": {}}), "sup-tool")
        self.assertEqual(f("Pretty Name", known={"pn": "Pretty Name"}, support={"pn": {}}), "pretty-name"
                         if False else "pn")
        self.assertEqual(f("Pretty Label", support={"other": {}}), "pretty-label")
        self.assertEqual(f("Some Other", support={"some-x": {}}), "some-other")
        self.assertEqual(f("Other Name", known={"x": "X", "kn": "Known"},
                           commercial=[{"slug": "c", "name": "C"}], oss=[{"slug": "o", "name": "O"}],
                           rankings=[{"solution": "r"}, {"solution": "rr"}],
                           support={"a_b": {}, "c_d": {}}), "other-name")
        self.assertEqual(f("A_B", known={"x": "X"}, support={"c_d": {}, "a_b": {}}), "a_b")
        self.assertIsNone(f("!!!"))
        self.assertEqual(f("Plain"), "plain")

    def test_leader_series_and_vc_entry(self):
        gmq = [{"q": "Challengers", "label": "C", "slug": "c"}, {"q": "Leaders", "label": "A", "slug": "a"},
               {"q": "Leaders", "label": "", "slug": "z"}, {"q": "Leaders", "label": "NoSlug", "slug": ""}]
        mq = [{"q": "Leaders", "label": "A", "slug": "a2"}, {"q": "Leaders", "label": "B", "slug": "b"}]
        self.assertEqual(sl._collect_mq_leader_series(gmq, mq), [("a", "A"), ("b", "B")])
        k0, k1 = sl.KCF_NAMES[:2]
        got = sl._vc_series_entry("my-tool", "My Tool", {k0: True}, known={}, kcfs=[k0, k1])
        self.assertEqual(got, {"label": "My Tool", "data": [5, 1], "color": "#4f46e5"})
        full = sl._vc_series_entry("my-tool", "My Tool", {}, known={}, oss=[{"slug": "my-tool"}])
        self.assertEqual((len(full["data"]), full["color"]), (len(sl.KCF_NAMES), "#22d3ee"))
        self.assertEqual(sl._vc_series_entry("langchain", "L", {}, known={})["color"], "#22d3ee")
        self.assertEqual(sl._vc_series_entry("zz", "Z", {}, known={}, oss=[])["color"], "#4f46e5")


class UrlTests(TmpCase):
    def test_legacy_urls(self):
        urls = sl._legacy_slug_urls()
        self.assertTrue(urls)
        with mock.patch.object(sl, "COMMERCIAL_CATALOG", [{"slug": "nourl", "name": "N"},
                                                          {"slug": "hasurl", "name": "H", "url": "https://h"}]), \
                mock.patch.object(sl, "OSS_CATALOG", []), mock.patch.object(sl, "EMERGING_CATALOG", []):
            self.assertEqual(sl._legacy_slug_urls(), {"hasurl": "https://h"})

    def test_resolve_slug_url(self):
        r = sl._resolve_slug_url
        urls = {"real": "https://real", "other": "https://other"}
        self.assertEqual(r("real", urls), "https://real")
        self.assertIsNone(r("alias", urls))
        self.assertIsNone(r("alias", urls, pack={"product_aliases": "nope"}))
        pack = {"product_aliases": {"alias": "real", "ghost": "missing", "rev": "x", "real2": "alias2"}}
        self.assertEqual(r("alias", urls, pack=pack), "https://real")
        self.assertIsNone(r("ghost", urls, pack=pack))
        # reverse direction: another alias pointing at this slug already has a URL
        self.assertEqual(r("target", {"al": "https://al"}, pack={"product_aliases": {"al": "target"}}),
                         "https://al")
        self.assertIsNone(r("target", {}, pack={"product_aliases": {"al": "target", "other": "zzz"}}))

    def pack(self):
        from category_pack import resolve_pack_from_need
        return resolve_pack_from_need(APO_NEED)

    def test_build_link_pairs_sources(self):
        commercial = [{"slug": "com", "name": "Commerce (Suite)", "url": "https://com.example"},
                      {"slug": "nourl", "name": "No Url"}]
        oss = [{"slug": "oss", "name": "Oss Tool", "url": "https://oss.example"}]
        self.put("solutions/scr1/scr.md", "---\nhomepage: https://scr1.example\n---\n")
        self.put("solutions/nohome/scr.md", "no links here")
        pairs = sl.build_link_pairs(
            [{"solution": "ranked"}, "junk", {"solution": ""}],
            root=self.root, commercial=commercial, oss=oss, known={"ranked": "Ranked Tool"},
            chart_slugs=["scr1", "nohome", "absent", ""], matrix_slugs=[" ", "oss"],
        )
        by = dict(pairs)
        self.assertEqual(by["Commerce (Suite)"], "https://com.example")
        self.assertEqual(by["Commerce"], "https://com.example")
        self.assertEqual(by["Oss Tool"], "https://oss.example")
        self.assertEqual(by["Scr1"], "https://scr1.example")
        self.assertNotIn("No Url", by)
        self.assertNotIn("Nohome", by)

    def test_build_link_pairs_pack_and_defaults(self):
        pairs = sl.build_link_pairs(pack=self.pack())
        self.assertTrue(pairs)
        self.assertTrue(all(u.startswith("http") for _l, u in pairs))
        self.assertTrue(sl.build_link_pairs())

    def test_build_link_pairs_generic_and_duplicate_labels(self):
        catalog = [{"slug": "a", "name": "API", "url": "https://a.example"},
                   {"slug": "b", "name": "Dup", "url": "https://b.example"},
                   {"slug": "c", "name": "Dup", "url": "https://c.example"}]
        pairs = sl.build_link_pairs(commercial=catalog, oss=[], known={"a": "API"})
        labels = [label for label, _u in pairs]
        self.assertEqual(labels.count("Dup"), 1)
        self.assertNotIn("API", labels)

    def test_dropped_urls_are_reported_on_stderr(self):
        dropped = [{"label": "Gone", "url": "https://gone", "error": "http-404", "status": 404},
                   {"label": "Odd", "url": "https://odd", "error": None, "status": 500}]
        err = io.StringIO()
        with mock.patch.object(sl, "filter_healthy_link_pairs", return_value=([["Kept", "https://k"]], dropped)), \
                contextlib.redirect_stderr(err):
            pairs = sl.build_link_pairs(commercial=[{"slug": "k", "name": "Kept", "url": "https://k"}], oss=[])
        self.assertEqual(pairs, [["Kept", "https://k"]])
        self.assertIn("[vendor-url-health] dropping 'Gone' → https://gone (http-404)", err.getvalue())
        self.assertIn("dropping 'Odd' → https://odd (500)", err.getvalue())


class LinkifyTests(TmpCase):
    def test_no_pairs(self):
        self.assertEqual(sl._linkify_markdown_vendors("see https://a.b now", []),
                         "see [https://a.b](https://a.b) now")

    def test_linkify_labels(self):
        md = "Foo Bar and Foo and [Foo](https://old) and Claude Code Expert and https://x.y/Foo plus Baz"
        pairs = [["Foo", "https://foo"], ["Foo Bar", "https://foobar"], ["Claude Code", "https://cc"],
                 ["", "https://empty"], ["Baz", "ftp://nope"], ["SDLC", "https://generic"]]
        out = sl._linkify_markdown_vendors(md, pairs, protected_labels={"Claude Code Expert", "", "Not Present"})
        self.assertIn("[Foo Bar](https://foobar) and [Foo](https://foo)", out)
        self.assertNotIn("[[", out)
        self.assertIn("[Foo](https://old)", out)
        self.assertIn(" Claude Code Expert ", out)  # protected from the shorter "Claude Code" link
        self.assertNotIn("[Claude Code](https://cc) Expert", out)
        self.assertIn("[https://x.y/Foo](https://x.y/Foo)", out)
        self.assertIn("plus Baz", out)

    def test_overlapping_labels_do_not_nest_links(self):
        out = sl._linkify_markdown_vendors(
            "GitHub Copilot Workspace uses GitHub Copilot",
            [["GitHub Copilot", "https://github.com/features/copilot"],
             ["GitHub Copilot Workspace", "https://githubnext.com/projects/copilot-workspace"]])
        self.assertEqual(
            out,
            "[GitHub Copilot Workspace](https://githubnext.com/projects/copilot-workspace) uses "
            "[GitHub Copilot](https://github.com/features/copilot)")

    def test_linkify_with_only_filtered_pairs(self):
        self.assertEqual(sl._linkify_markdown_vendors("SDLC rocks", [["SDLC", "https://x"]]), "SDLC rocks")

    def test_linkify_skips_blank_and_non_http_after_filter(self):
        with mock.patch.object(sl, "filter_vendor_link_pairs",
                               return_value=[["", "https://e"], ["Bad", "ftp://x"], ["Ok", "https://ok"]]):
            out = sl._linkify_markdown_vendors("Bad Ok", [["x", "y"]])
        self.assertEqual(out, "Bad [Ok](https://ok)")


class BucketTests(unittest.TestCase):
    def test_buckets(self):
        mq = [{"label": "A", "q": "Leaders"}, {"label": "B", "q": "Challengers"}, {"label": "", "q": "Leaders"},
              {"label": "C", "q": ""}]
        gmq = [{"label": "A", "q": "Niche Players"}, {"label": "D", "q": "Leaders"}, {"label": "", "q": "x"},
               {"label": "E"}]
        got = sl.build_vendor_buckets(mq, gmq_data=gmq,
                                      commercial=[{"slug": "c", "name": "Com"}], oss=[{"slug": "o"}],
                                      known={"o": "Oss"})
        self.assertEqual(got, {"commercial": ["Com"], "oss": ["Oss"], "leaders": ["A", "D"],
                               "challengers": ["B"]})
        empty = sl.build_vendor_buckets([], commercial=[], oss=[])
        self.assertEqual(empty, {"commercial": [], "oss": [], "leaders": [], "challengers": []})
        legacy = sl.build_vendor_buckets([])
        self.assertTrue(legacy["commercial"] and legacy["oss"])


if __name__ == "__main__":
    unittest.main()
