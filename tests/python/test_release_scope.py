"""Release-commit parser (release_scope.py): the R1-R26 rows of the design plus unit tests of the pflag parser."""

from __future__ import annotations

import os
import sys
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import sbtest  # noqa: E402

shell_analysis = sbtest.load_module("hooks/lib/tool-input/shell_analysis.py", "sbtest_sa_release")
release_scope = sbtest.load_module("hooks/lib/tool-input/release_scope.py", "release_scope")

ENV = {"PATH": "/usr/bin:/bin"}
ORIGIN = "acme/app"
API = "repos/{owner}/{repo}/releases"


def scope(cmd, env=None, origin=ORIGIN):
    result = shell_analysis.analyze_command(cmd, "/tmp", False)
    return release_scope.release_scope(result, None, {}, origin, ENV if env is None else env, cmd)


class ReleaseRowTests(unittest.TestCase):
    def red(self, cmd, tag="v9", **kw):
        out = scope(cmd, **kw)
        with self.subTest(cmd=cmd):
            self.assertTrue(out["ok"], out)
            self.assertEqual((out["tag"], out["target"]), (tag, "RED"), out)

    def deny(self, cmd, reason="", **kw):
        out = scope(cmd, **kw)
        with self.subTest(cmd=cmd):
            self.assertFalse(out["ok"], out)
            self.assertIn(reason.lower(), out["reason"].lower(), out)

    def test_gh_api_forms_resolve_to_the_committed_target(self):
        self.red("gh api -p corsair %s -f tag_name=v9 -f target_commitish=RED" % API)  # R1
        self.red("gh api --preview corsair %s -f tag_name=v9 -f target_commitish=RED" % API)  # R2
        self.red("gh api -pcorsair %s -f tag_name=v9 -f target_commitish=RED" % API)  # R3
        self.red("gh api %s -p corsair -f target_commitish=RED -f tag_name=v9" % API)  # R4
        self.red("gh api %s/ -f target_commitish=RED -f tag_name=v9" % API)  # R10
        self.red("gh api -if target_commitish=RED %s -f tag_name=v9" % API)  # R11
        self.red("gh api -XPOST %s -f tag_name=v9 -f target_commitish=RED" % API)  # R12
        self.red("gh api --method=post %s -f tag_name=v9 -f target_commitish=RED" % API)  # R12
        self.red("gh api https://api.github.com/repos/acme/app/releases -f tag_name=v9 -f target_commitish=RED")  # R23
        self.red("gh api /repos/acme/app/releases -f tag_name=v9 -F target_commitish=RED")
        self.red("gh api repos/ACME/App/releases -f tag_name=v9 --field=target_commitish=RED")
        self.red("gh api -ftag_name=v9 -ftarget_commitish=RED -fdraft=true %s" % API)
        self.red("gh api --raw-field tag_name=v9 --raw-field=target_commitish=RED %s" % API)
        self.red("gh api %s -f tag_name=v9 -f target_commitish=RED -H 'Accept: x' -H 'X-A: b'" % API)
        self.red("gh api --silent --include=false %s -f tag_name=v9 -f target_commitish=RED" % API)

    def test_gh_release_create_forms(self):
        self.red("gh release create v9 --target RED")
        self.red("gh release create --target=RED v9")  # R15
        self.red("gh release create v9 -p --target RED")  # R25: -p is prerelease here
        self.red("gh release new v9 --target RED --notes x")
        self.red("gh release create v9 --target RED -R acme/app")
        self.red("gh release create v9 --target RED -R{owner}/{repo}")
        self.red("gh release create v9 --target RED --repo=acme/app")
        self.red("gh release create v9 --target RED -dp -t 'My title' -n=notes")
        self.red("gh release create -t 'x' v9 --target RED a.zip b.zip")
        self.red("gh release create v9 --target RED --draft=false --latest")
        self.red("gh release create v9 --target RED -- a.zip")
        out = scope("gh release create v9")
        self.assertEqual((out["ok"], out["tag"], out["target"]), (True, "v9", ""))

    def test_denied_forms(self):
        self.deny("gh release create v9 --target main && gh api %s -f tag_name=v10 -f target_commitish=RED" % API,
                  "2 releases")  # R5
        self.deny("gh release create v9 --target main && gh release create v10 --target RED", "2 releases")  # R6
        self.deny("gh api %s -f tag_name=v9 -f target_commitish=main -f target_commitish=RED" % API, "more than once")  # R7
        self.deny("gh api %s -f tag_name=v9 -f target_commitish=main -F target_commitish=RED" % API, "more than once")  # R8
        self.deny("gh api %s --raw-field=target_commitish=main --field target_commitish=RED" % API, "more than once")  # R9
        self.deny("gh api -X GET %s -f tag_name=v9 -f target_commitish=RED" % API, "0 releases")  # R13
        self.deny("gh release create v9 --target RED --target main", "twice")  # R14
        self.deny("gh release create v9 -R other/repo --target RED", "another repository")  # R16
        self.deny("gh release create v9 --bogus x", "--bogus")  # R17
        self.deny("gh api %s -f tag_name=v9 -F target_commitish={branch}" % API, "expanded")  # R18
        self.deny("gh api %s -f tag_name=v9 -F target_commitish=@f" % API, "file")  # R19
        self.deny("gh api %s -f tag_name=v9 -f 'target_commitish[]=RED'" % API, "array")  # R20
        self.deny("hub release create -t RED v9", "only from gh release create")  # R21
        self.deny("gh api %s --input body.json" % API, "--input")  # R24
        self.deny("gh api %s --input=body.json" % API, "--input")
        self.deny("gh release create v9 --target RED", "GH_REPO", env=dict(ENV, GH_REPO="other/x"))  # R26
        self.deny("GH_REPO=other/x gh release create v9 --target RED", "GH_REPO")
        self.deny("GH_HOST=ghe.example gh release create v9 --target RED", "GH_REPO/GH_HOST")
        self.deny("gh release create v9 --target RED", "GH_REPO", env=dict(ENV, GH_REPO="x/y"))
        self.deny("gh release edit v9", "only from gh release create")
        self.deny("gh release upload v9 a.zip", "only from gh release create")
        self.deny("gh release create --target RED", "no tag")
        self.deny("gh api %s -f tag_name=v9 -f target_commitish=$T" % API, "computed")
        self.deny("gh api %s -f tag_name=v9 -f target_commitish='`x`'" % API, "computed")
        self.deny("gh api %s -f tag_name=v9 -f target_commitish" % API, "no value")
        self.deny("gh api %s --hostname ghe.example -f tag_name=v9" % API, "another host")
        self.deny("gh api repos/acme/app/releases/12 -X PATCH -f draft=false", "release")
        self.deny("gh api -X POST repos/acme/app/releases/12/assets", "endpoint")
        self.deny("gh api %s repos/x/y/releases -f tag_name=v9" % API, "exactly one endpoint")
        self.deny("gh api -f tag_name=v9", "0 releases")
        self.deny("gh api repos/x/y/releases repos/z/w/releases -f tag_name=1", "exactly one endpoint")
        self.deny("gh api repos/other/lib/releases -f tag_name=v9", "another repository")
        self.deny("gh api repos/{owner}/lib/releases -f tag_name=v9", "another repository")
        self.deny("gh api repos/acme/app/releases -f tag_name=v9", "another repository", origin=None)
        self.deny("gh api repos/ac me/app/releases", "0 releases")
        self.deny("gh release create v9 --target RED -R a/b/c", "owner/repo")
        self.deny("gh release create v9 --target RED -R", "no value")
        self.deny("gh release create v9 --target", "no value")
        self.deny("gh release create v9 --draft=maybe", "boolean")
        self.deny("gh release create v9 -x", "-x")
        self.deny("gh release create v9 -dx", "-x")
        self.deny("gh release create $X --target RED", "computed")
        self.deny("gh release $SUB v9", "only from")
        self.deny("curl -X POST https://api.github.com/repos/acme/app/releases -d x", "only from")
        self.deny("glab release create v9", "only from")

    def test_mcp_create_release(self):
        result = {"delivery": [{"action": "release_create", "possible": False}]}
        fields = {"owner": "acme", "repo": "app", "tag_name": "v9", "target_commitish": "RED"}
        out = release_scope.release_scope(result, "create_release", fields, ORIGIN, ENV)
        self.assertEqual((out["ok"], out["tag"], out["target"]), (True, "v9", "RED"))
        out = release_scope.release_scope(result, "create_release", dict(fields, owner="other"), ORIGIN, ENV)
        self.assertIn("another repository", out["reason"])
        out = release_scope.release_scope(result, "create_release", dict(fields, owner=["acme"]), ORIGIN, ENV)
        self.assertIn("owner and repo", out["reason"])
        out = release_scope.release_scope(result, "create_release", dict(fields, tag_name=7), ORIGIN, ENV)
        self.assertIn("not text", out["reason"])
        out = release_scope.release_scope(result, "create_release", {"owner": "acme", "repo": "app", "tag": "v1",
                                                                     "target": "main"}, ORIGIN, ENV)
        self.assertEqual((out["tag"], out["target"]), ("v1", "main"))
        out = release_scope.release_scope(result, "create_tag", fields, ORIGIN, ENV)
        self.assertIn("only from", out["reason"])
        out = release_scope.release_scope({"delivery": []}, "create_release", fields, ORIGIN, ENV)
        self.assertIn("0 releases", out["reason"])
        out = release_scope.release_scope({"delivery": [{"action": "release_create", "possible": True}]},
                                          "create_release", fields, ORIGIN, ENV)
        self.assertIn("only from", out["reason"])


class FlagParserTests(unittest.TestCase):
    def test_parse(self):
        flags, pos = release_scope.parse_pflags(["a", "-dn", "x", "b"], release_scope.GH_RELEASE_CREATE)
        self.assertEqual((flags, pos), ({"--draft": ["true"], "--notes": ["x"]}, ["a", "b"]))
        flags, pos = release_scope.parse_pflags(["-n=x", "--latest=false"], release_scope.GH_RELEASE_CREATE)
        self.assertEqual(flags, {"--notes": ["x"], "--latest": ["false"]})
        flags, _ = release_scope.parse_pflags(["-d=true"], release_scope.GH_RELEASE_CREATE)
        self.assertEqual(flags, {"--draft": ["true"]})
        flags, _ = release_scope.parse_pflags(["-f", "a=1", "-fb=2", "--field=c=3"], release_scope.GH_API)
        self.assertEqual(flags, {"--raw-field": ["a=1", "b=2"], "--field": ["c=3"]})
        with self.assertRaises(release_scope.Deny):
            release_scope.parse_pflags(["--dra"], release_scope.GH_RELEASE_CREATE)  # no abbreviations
        with self.assertRaises(release_scope.Deny):
            release_scope.parse_pflags(["-d=zzz"], release_scope.GH_RELEASE_CREATE)


if __name__ == "__main__":
    unittest.main()
