"""Unit tests for scripts/lib/agent_redact.py (R4-31, R10b-06)."""

import io
import os
import stat
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

from sbtest import load_module

agent_redact = load_module("scripts/lib/agent_redact.py")

# Fake credentials are assembled at run time so no scanner flags this file.
JWT = ".".join(["eyJhbGciOiJIUzI1NiJ9", "eyJzdWIiOiIxMjM0NTY3ODkwIn0", "SflKxwRJSMeKKF2QT4fwpMeJf36"])
LONG_VALUE = "wJalrXUtnFEMI/K7MDENG" + "/bPxRfiCYEXAMPLEKEY"
SAMPLES = {
    "github-pat": "github_pat_" + "11ABCDEFG0123456789_abcdefghijklmnopqrstuv",
    "github": "ghp_" + "abcdefghijklmnopqrstuvwxyz",
    "gitlab": "glpat-" + "abcdefghij0123456789xy",
    "slack": "xoxb-" + "123456789012-abcdefABCDEF",
    "aws": "AKIA" + "IOSFODNN7ABCDEFG",
    "google": "AIza" + "SyA-1234567890abcdefghijklmnopqrstuv",
    "sk": "sk-" + "ant-api03-abcdefgh",
    "jwt": JWT,
    "pem": "-----BEGIN RSA PRIVATE KEY-----\nMIIabc\n-----END RSA PRIVATE KEY-----",
}


class RedactTests(unittest.TestCase):
    def test_prefixed_tokens_are_removed(self):
        for kind, token in SAMPLES.items():
            with self.subTest(kind=kind):
                out = agent_redact.redact("before %s after" % token)
                self.assertNotIn(token, out)
                self.assertIn("before", out)
                self.assertIn("[REDACTED]", out)

    def test_unterminated_pem_is_removed_to_end(self):
        out = agent_redact.redact("x -----BEGIN PRIVATE KEY-----\nMIIabc\nmore")
        self.assertNotIn("MIIabc", out)

    def test_authorization_and_bearer(self):
        out = agent_redact.redact("curl -H 'Authorization: Bearer abcdefgh12345678' u")
        self.assertIn("Authorization: [REDACTED]", out)
        self.assertNotIn("abcdefgh12345678", out)
        out = agent_redact.redact("got Bearer abcdefgh12345678 here")
        self.assertEqual(out, "got Bearer [REDACTED] here")
        self.assertEqual(agent_redact.redact("authorization=token xyz123"), "authorization=[REDACTED]")

    def test_assignments_keep_names_and_case(self):
        out = agent_redact.redact("AWS_SECRET_ACCESS_KEY=%s and Api-Key: hunter2 and password = swordfish" % LONG_VALUE)
        self.assertNotIn(LONG_VALUE, out)
        self.assertNotIn("hunter2", out)
        self.assertNotIn("swordfish", out)
        self.assertIn("AWS_SECRET_ACCESS_KEY=[REDACTED]", out)

    def test_plain_text_is_left_alone(self):
        text = "used 1234 tokens; tokens: 12; the password field; secrets are stored elsewhere"
        self.assertEqual(agent_redact.redact(text), text)


class ScanTests(unittest.TestCase):
    def test_prefixed_tokens_are_found(self):
        for kind, token in SAMPLES.items():
            with self.subTest(kind=kind):
                self.assertEqual(agent_redact.scan("ctx " + token), (kind, 1))

    def test_bearer_needs_a_random_looking_value(self):
        self.assertEqual(agent_redact.scan("a\nAuthorization: Bearer " + LONG_VALUE), ("bearer", 2))
        self.assertIsNone(agent_redact.scan("Authorization: Bearer <your-token-here>"))
        self.assertIsNone(agent_redact.scan("Bearer aaaaaaaaaaaaaaaaaaaaaaaa"))

    def test_assignment_needs_a_random_looking_value(self):
        self.assertEqual(agent_redact.scan("x\ny\nGITLAB_TOKEN=" + LONG_VALUE), ("assignment", 3))
        self.assertEqual(agent_redact.scan("password: '%s'" % LONG_VALUE), ("assignment", 1))
        self.assertEqual(agent_redact.scan("secret = aB3dE5gH7jK9mN1pQ3sT5vW7"), ("assignment", 1))
        self.assertEqual(agent_redact.scan("api_key=" + "aBcDeFgHiJkLmNoPqRsTuVwXyZqWeRtYuIoP"), ("assignment", 1))

    def test_honest_text_passes(self):
        for text in (
            "returns a session token: JWT",
            "shows password: field",
            "api_key: optional",
            "GITHUB_TOKEN=${GITHUB_TOKEN}",
            "token=<paste token here>",
            "secret: your-secret-goes-here-ok",
            "password: changeme-changeme-changeme",
            "tokens: 12",
            "secret = xxxxxxxxxxxxxxxxxxxxxxxx",
            "password=example-example-example",
            "nothing here",
            # honest auth-feature code: references and calls, not literals (R10b-06)
            "client_secret: settings.GOOGLE_CLIENT_SECRET",
            "const password = req.body.passwordConfirmation",
            "secret=getSecretFromVaultClient()",
            "private_key: loadPrivateKeyFromDisk(path)",
            "Use secret: process.env.SESSION_SECRET for cookie signing",
            "api_key = os.environ['PAYMENT_API_KEY_PRIMARY']",
            "token: ${{ secrets.DEPLOY_TOKEN_LONG_NAME }}",
            "secret = SessionSecretProviderFactory",
            "password: GOOGLE_CLIENT_SECRET_VALUE_ENV",
            "key: Foo::Bar::loadSecretMaterialFromVault",
        ):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))


class MoreRedactionTests(unittest.TestCase):
    def test_url_userinfo_flags_and_registry_tokens(self):
        text = "git clone https://user:S3cr3tPassw0rdXYZ@github.com/x.git; tool --password hunter2Super --token=abc; " + "npm_" + "a" * 24 + " hf_" + "b" * 24
        out = agent_redact.redact(text)
        for leaked in ("S3cr3tPassw0rdXYZ", "hunter2Super", "abc;", "a" * 24, "b" * 24):
            self.assertNotIn(leaked, out)
        self.assertIn("github.com/x.git", out)
        self.assertIn("--password [REDACTED]", out)

    def test_plain_urls_are_untouched(self):
        text = "see https://example.com/a:b and git@github.com:org/repo.git"
        self.assertEqual(agent_redact.redact(text), text)


class RedactFileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def path(self, name):
        return os.path.join(self.tmp.name, name)

    def test_rewrites_in_place_and_keeps_mode(self):
        target = self.path("log")
        with open(target, "w") as handle:
            handle.write("token=abc123\nok\n")
        os.chmod(target, 0o640)
        self.assertTrue(agent_redact.redact_file(target))
        with open(target) as handle:
            self.assertEqual(handle.read(), "token=[REDACTED]\nok\n")
        self.assertEqual(stat.S_IMODE(os.stat(target).st_mode), 0o640)
        self.assertEqual([n for n in os.listdir(self.tmp.name) if n.startswith(".redact.")], [])

    def test_clean_file_is_not_rewritten(self):
        target = self.path("clean")
        with open(target, "w") as handle:
            handle.write("nothing secret\n")
        before = os.stat(target).st_ino
        self.assertTrue(agent_redact.redact_file(target))
        self.assertEqual(os.stat(target).st_ino, before)

    def test_missing_file_returns_false(self):
        self.assertFalse(agent_redact.redact_file(self.path("absent")))

    def test_symlink_is_refused(self):
        target = self.path("real")
        with open(target, "w") as handle:
            handle.write("token=abc123\n")
        link = self.path("link")
        os.symlink(target, link)
        with self.assertRaises(OSError):
            agent_redact.redact_file(link)
        with open(target) as handle:
            self.assertEqual(handle.read(), "token=abc123\n")

    def test_failure_cleans_the_temp_file(self):
        target = self.path("log")
        with open(target, "w") as handle:
            handle.write("token=abc123\n")
        with mock.patch.object(agent_redact.os, "replace", side_effect=OSError("boom")):
            with self.assertRaises(OSError):
                agent_redact.redact_file(target)
        self.assertEqual([n for n in os.listdir(self.tmp.name) if n.startswith(".redact.")], [])


class MainTests(unittest.TestCase):
    def run_main(self, argv, stdin=""):
        out, err = io.StringIO(), io.StringIO()
        with mock.patch("sys.stdin", io.StringIO(stdin)), redirect_stdout(out), redirect_stderr(err):
            rc = agent_redact.main(["agent_redact.py"] + argv)
        return rc, out.getvalue(), err.getvalue()

    def test_redact_filter(self):
        rc, out, _ = self.run_main(["--redact"], "token=abc\n")
        self.assertEqual((rc, out), (0, "token=[REDACTED]\n"))

    def test_scan_exit_codes(self):
        rc, out, _ = self.run_main(["--scan"], "ok\nx " + SAMPLES["github"])
        self.assertEqual((rc, out), (1, "github line 2\n"))
        rc, out, _ = self.run_main(["--scan"], "plain text")
        self.assertEqual((rc, out), (0, ""))

    def test_redact_file_modes(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = os.path.join(tmp, "f")
            with open(target, "w") as handle:
                handle.write("password=abc\n")
            rc, _, _ = self.run_main(["--redact-file", target])
            self.assertEqual(rc, 0)
            link = os.path.join(tmp, "l")
            os.symlink(target, link)
            rc, _, err = self.run_main(["--redact-file", link])
            self.assertEqual(rc, 2)
            self.assertIn("symlink", err)

    def test_usage(self):
        rc, _, err = self.run_main(["--bogus"])
        self.assertEqual(rc, 2)
        self.assertIn("Usage", err)


if __name__ == "__main__":
    unittest.main()
