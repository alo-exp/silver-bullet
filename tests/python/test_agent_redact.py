"""Unit tests for scripts/lib/agent_redact.py (R4-31, R10b-06)."""

import io
import os
import random
import string
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
    "pem": "-----BEGIN RSA PRIVATE KEY-----\nMIIabcdefghijklmnop\n-----END RSA PRIVATE KEY-----",
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
        self.assertEqual(agent_redact.scan("a\nAuthorization: Bearer " + LONG_VALUE), ("authorization", 2))
        self.assertEqual(agent_redact.scan("x\ny\nsend Bearer " + LONG_VALUE), ("bearer", 3))
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


# Regression corpus (R10b-06 r2/r3). Every real-shaped secret must be caught by BOTH the brief scanner
# (scan) and the log redactor (redact); every honest string must pass the scanner. Values come from a
# seeded generator and are assembled at run time so no secret scanner flags this file.
_RNG = random.Random(20261105)
_ALNUM = string.ascii_letters + string.digits


def _rand(n, alphabet=_ALNUM):
    return "".join(_RNG.choice(alphabet) for _ in range(n))


def _uuid():
    h = _rand(32, "0123456789abcdef")
    return "-".join([h[:8], h[8:12], h[12:16], h[16:20], h[20:]])


def _b64(n):
    return _rand(n, string.ascii_letters + string.digits + "+/") + "=="


def _groups():
    return "_".join(_rand(4, string.ascii_uppercase + string.digits[1:]) for _ in range(5))


def _pem(kind):
    body = "\n".join(_rand(64, string.ascii_letters + string.digits + "+/") for _ in range(3))
    return "-----BEGIN %s-----\n%s\n-----END %s-----" % (kind, body, kind)


def _secret_cases():
    """(text, fragment that must not survive redaction)"""
    v = []

    def add(template, secret):
        v.append((template % secret, secret))

    for prefix, n in (("ghp_", 36), ("gho_", 36), ("ghs_", 36), ("ghu_", 36), ("github_pat_", 40), ("glpat-", 24),
                      ("xoxb-", 30), ("xoxp-", 30), ("npm_", 36), ("hf_", 34), ("sk-", 40), ("sk-ant-", 40),
                      ("sk-proj-", 40), ("sk_live_", 30), ("sk_test_", 30), ("rk_live_", 30), ("whsec_", 32)):
        add("token seen: %s in the log", prefix + _rand(n))
    add("id %s", "AKIA" + _rand(16, string.ascii_uppercase + string.digits))
    add("id %s", "ASIA" + _rand(16, string.ascii_uppercase + string.digits))
    add("g %s", "AIza" + _rand(35, string.ascii_letters + string.digits + "_-"))
    add("POST https://hooks.slack.com/services/T%s", "0123ABCD/B0456EFGH/" + _rand(24))
    add("jwt %s", ".".join("eyJ" + _rand(20, string.ascii_letters + string.digits + "_-") for _ in range(3)))
    for kind in ("RSA PRIVATE KEY", "EC PRIVATE KEY", "OPENSSH PRIVATE KEY", "PRIVATE KEY"):
        pem = _pem(kind)
        v.append(("key:\n" + pem, pem.split("\n")[1]))
    pgp = "-----BEGIN PGP PRIVATE KEY BLOCK-----\nVersion: GnuPG v2\n\n" + _rand(60, string.ascii_letters + string.digits + "+/") + "\n-----END PGP PRIVATE KEY BLOCK-----"
    v.append((pgp, pgp.split("\n")[3]))
    for name in ("API_KEY", "api_key", "AWS_SECRET_ACCESS_KEY", "DB_PASSWORD", "client_secret", "SECRET_KEY",
                 "STRIPE_SECRET_KEY", "private_key", "signing_key", "AZURE_STORAGE_KEY", "ACCESS_TOKEN", "auth_token",
                 "password", "passwd", "x-api-key"):
        add(name + "=%s", _b64(40) if name not in ("password", "passwd") else _rand(14) + "9!")
    add("HEROKU_API_KEY=%s", _uuid())
    add("client_secret: %s", _uuid())
    add("TOKEN=%s", _groups())
    add("API_KEY=%s", _groups())
    add("api_token = '%s'", _rand(10) + "_" + _rand(12))
    add("app.secret-key: %s", _rand(8) + "." + _rand(8) + "." + _rand(8) + "7")
    add("Authorization: Basic %s", _b64(22))
    add("Proxy-Authorization: Basic %s", _b64(22))
    add("Authorization: token %s", _rand(40))
    add("Authorization: Bearer %s", _rand(8) + "_" + _rand(8) + "_" + _rand(8))
    add("curl -H 'Authorization: Digest %s'", _rand(32))
    add("header: Bearer %s", _rand(8) + "." + _rand(8) + "." + _rand(8))
    add("send Bearer %s now", _rand(30, string.ascii_letters + "_"))
    add("deploy --token %s", _rand(24))
    add("login --password %s", _rand(10) + "7Q")
    add("tool --password=%s", _rand(12) + "3x")
    add("run --secret %s", _rand(20))
    add("run --api-key %s", _rand(26))
    add("git clone https://admin:%s@git.corp.test/org/repo", _rand(16))
    add("DB=postgres://app:%s@db-prod:5432/x", _rand(18))
    add("redis://cache:%s@redis-prod", _rand(14) + "5")
    v.append(("curl https://admin:admin@prod-db/secret", "admin:admin"))
    v.append(("mysql://root:root@db-prod-internal/db", "root:root"))
    return v


def _honest_cases():
    v = [
        "csrf_token = " + _uuid(),
        "session_token: " + _uuid(),
        "request_id=" + _uuid() + " trace_token=" + _uuid(),
        "idempotency_key: " + _uuid(),
        "correlation_token = " + _uuid(),
        "client_secret: settings.GOOGLE_CLIENT_SECRET",
        "const password = req.body.passwordConfirmation",
        "secret=getSecretFromVaultClient()",
        "private_key: loadPrivateKeyFromDisk(path)",
        "Use secret: process.env.SESSION_SECRET for cookie signing",
        "api_key = os.environ['PAYMENT_API_KEY_PRIMARY']",
        "token: ${{ secrets.DEPLOY_TOKEN_LONG_NAME }}",
        "secret = SessionSecretProviderFactory",
        "password: GOOGLE_CLIENT_SECRET_VALUE_ENV",
        "TOKEN=GOOGLE_CLIENT_SECRET_2_VALUE",
        "API_KEY=STRIPE_SECRET_KEY_NAME_V2",
        "key: Foo::Bar::loadSecretMaterialFromVault",
        "signing_key = config.signingKeyProvider.current",
        "AZURE_STORAGE_KEY=${AZURE_STORAGE_KEY}",
        "DB_PASSWORD=$DB_PASSWORD",
        "access_token=<your access token here>",
        "api_key: <PASTE_API_KEY_HERE>",
        "git clone https://x-access-token:${GH_TOKEN}@github.test/org/repo",
        "https://user:<password>@host.test/x",
        "DATABASE_URL=postgres://postgres:postgres@localhost:5432/test",
        "DATABASE_URL=postgres://user:password@localhost/db",
        "mysql://root:root@127.0.0.1/db",
        "redis://admin:admin@cache.local:6379",
        "https://deploy:deploy@host.test/r",
        "Never commit files that start with -----BEGIN PRIVATE KEY----- markers.",
        "The -----BEGIN PGP PRIVATE KEY BLOCK----- header marks an armored key.",
        "Authorization: Bearer <token> is documented",
        "Authorization: header is required",
        "uses Bearer authentication scheme",
        "returns a session token: JWT",
        "shows password: field and api_key: optional",
        "tokens: 12 used, secret: none",
        "--password-file ./secret.txt",
        "--token=<your token>",
        "--token $GH_TOKEN",
        "--password ${DB_PASSWORD}",
        "--secret my-secret-name",
        "--api-key sandbox",
        "commit: " + _rand(40, "0123456789abcdef"),
        "sha256: " + _rand(64, "0123456789abcdef"),
        "integrity: sha512-" + _b64(60),
        "checksum = " + _rand(40, "0123456789abcdef"),
        "image: data:image/png;base64," + _b64(60),
        "fixture_blob = '" + _b64(48) + "'",
        "etag: W/\"" + _rand(20) + "\"",
        "uuid: " + _uuid(),
        "order_id=" + _uuid(),
        "version: 1.2.3-beta.4+build.5",
        "build_key_name: release-linux-x86_64-2024",
        "primary_key = user_id",
        "cache_key = tenant_id + ':' + user_id",
        "api_key=my_api_key_variable_name",
        "token_name = my_long_token_variable_name",
        "secret = aaaa/aaaa/aaaa/aaaa/aaaa",
        "password = getpass.getpass('Password: ')",
        "client_secret = vault.read('secret/data/app')['client_secret']",
        "const apiKey = this.configService.get('API_KEY')",
        "export GITHUB_TOKEN=\"${{ github.token }}\"",
        "ssh-key: id_ed25519 (stored in the agent)",
    ]
    return v


CORPUS_SECRETS = _secret_cases()
CORPUS_HONEST = _honest_cases()


class CorpusTests(unittest.TestCase):
    def test_corpus_sizes(self):
        self.assertGreaterEqual(len(CORPUS_SECRETS), 60)
        self.assertGreaterEqual(len(CORPUS_HONEST), 60)

    def test_every_secret_is_caught_by_scanner_and_redactor(self):
        for text, fragment in CORPUS_SECRETS:
            with self.subTest(text=text[:40]):
                self.assertIsNotNone(agent_redact.scan(text), "scanner missed")
                out = agent_redact.redact(text)
                self.assertNotIn(fragment, out, "redactor kept the secret")
                self.assertIn("[REDACTED]", out)

    def test_honest_briefs_pass_the_scanner(self):
        for text in CORPUS_HONEST:
            with self.subTest(text=text[:40]):
                self.assertIsNone(agent_redact.scan(text))

    def test_scanner_and_redactor_share_one_pattern_set(self):
        # every compiled pattern the scanner consults is the object redact() substitutes with
        for name in ("_PREFIXED", "_PASSWORD_FLAG", "_AUTH_HEADER", "_BEARER", "_ASSIGN"):
            self.assertTrue(hasattr(agent_redact, name))
        src = open(agent_redact.__file__, encoding="utf-8").read()
        scan_src = src[src.index("def scan("):src.index("def redact_file(")]
        for name in ("_PREFIXED", "_PASSWORD_FLAG", "_AUTH_HEADER", "_BEARER", "_ASSIGN"):
            self.assertIn(name, scan_src)

    def test_pem_line_number_and_prose(self):
        self.assertEqual(agent_redact.scan("a\nb\n-----BEGIN PRIVATE KEY-----\nMIIEowIBAAKCAQEAabcdefgh"), ("pem", 3))
        self.assertIsNone(agent_redact.scan("a header line -----BEGIN PRIVATE KEY----- in prose"))

    def test_userinfo_rules(self):
        self.assertEqual(agent_redact.scan("x https://deploy:Zq8vLm2Xr9TnW4@host.test/r")[0], "url-userinfo")
        self.assertIsNone(agent_redact.scan("x https://deploy:deploy@host.test/r"))
        # the trivial-password exemption (not the user==password rule) and its host limit
        self.assertIsNone(agent_redact.scan("postgres://app:password@localhost/db"))
        self.assertIsNone(agent_redact.scan("postgres://app:changeme@[::1]:5432/db"))
        self.assertEqual(agent_redact.scan("postgres://app:password@db-prod/db")[0], "url-userinfo")
        self.assertEqual(agent_redact.scan("https://admin:admin@prod-db/x")[0], "url-userinfo")

    def test_camel_case_names_and_random_letter_runs(self):
        self.assertIsNone(agent_redact.scan("secret=getSecretFromVaultClientFactory"))
        self.assertIsNotNone(agent_redact.scan("secret=qWeRtYuIoPaSdFgHjKlZxCvB"))
        self.assertIsNotNone(agent_redact.scan("secret=" + "qwertyuiopasdfghjklzxcvbnm"[::-1] + "ABCDEFGHIJKLMNOPQRSTUV"))


class MoreRedactionTests(unittest.TestCase):
    def test_url_userinfo_flags_and_registry_tokens(self):
        text = "git clone https://user:S3cr3tPassw0rdXYZ@host.test/x.git; tool --password hunter2Super --token=abc; " + "npm_" + "a" * 24 + " hf_" + "b" * 24
        out = agent_redact.redact(text)
        for leaked in ("S3cr3tPassw0rdXYZ", "hunter2Super", "abc;", "a" * 24, "b" * 24):
            self.assertNotIn(leaked, out)
        self.assertIn("host.test/x.git", out)
        self.assertIn("--password [REDACTED]", out)

    def test_plain_urls_are_untouched(self):
        text = "see https://example.com/a:b and ssh://host/org/repo.git"
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
