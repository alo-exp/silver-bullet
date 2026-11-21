"""Unit tests for scripts/lib/agent_redact.py (R4-31, R10b-06)."""

import gc
import io
import json
import os
import re
import random
import string
import stat
import tempfile
import time
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

from sbtest import load_module
import redact_corpus
import redact_corpus_r5
import redact_corpus_r6
import redact_corpus_r7
import redact_corpus_r8

agent_redact = load_module("scripts/lib/agent_redact.py")

# Armor headers and name/value pairs are assembled at run time so no committed line looks like a credential.
_BEGIN = "-----" + "BEGIN "
_EQ = "="
_CO = ":"

# Fake credentials are assembled at run time so no scanner flags this file.
JWT = ".".join(["eyJhbGciOiJIUzI1NiJ9", "eyJzdWIiOiIxMjM0NTY3ODkwIn0", "SflKxwRJSMeKKF2QT4fwpMeJf36"])
LONG_VALUE = "wJalrXUtnFEMI/K7MDENG" + "/bPxRfiCYQwErTyUiOp1"
SAMPLES = {
    "github-pat": "github_pat_" + "11ABCDEFG0123456789_abcdefghijklmnopqrstuv",
    "github": "ghp_" + "abcdefghijklmnopqrstuvwxyz",
    "gitlab": "glpat-" + "abcdefghij0123456789xy",
    "slack": "xoxb-" + "123456789012-abcdefABCDEF",
    "aws": "AKIA" + "IOSFODNN7ABCDEFG",
    "google": "AIza" + "SyA-1234567890abcdefghijklmnopqrstuv",
    "sk": "sk-" + "ant-api03-abcdefgh",
    "jwt": JWT,
    "pem": _BEGIN + "RSA PRIVATE KEY-----\nMIIabcdefghijklmnop\n-----END RSA PRIVATE KEY-----",
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
        out = agent_redact.redact("x " + _BEGIN + "PRIVATE KEY-----\nMIIabc\nmore")
        self.assertNotIn("MIIabc", out)

    def test_authorization_and_bearer(self):
        out = agent_redact.redact("curl -H 'Authori" + "zation: Bearer abcdefgh12345678' u")
        self.assertIn("Authorization: Bearer [REDACTED]", out)
        self.assertNotIn("abcdefgh12345678", out)
        out = agent_redact.redact("got Bearer abcdefgh12345678 here")
        self.assertEqual(out, "got Bearer [REDACTED] here")
        self.assertEqual(agent_redact.redact("authorization=token xyz123abc789"), "authorization=token [REDACTED]")

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
        self.assertEqual(agent_redact.scan("secret " + _EQ + " aB3dE5gH7jK9mN1pQ3sT5vW7"), ("assignment", 1))
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
    return (_BEGIN + "%s-----\n%s\n-----END %s-----") % (kind, body, kind)


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
    pgp = _BEGIN + "PGP PRIVATE KEY BLOCK-----\nVersion: GnuPG v2\n\n" + _rand(60, string.ascii_letters + string.digits + "+/") + "\n-----END PGP PRIVATE KEY BLOCK-----"
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
    add("DB=postgres://app:%s@db.prod.test:5432/x", _rand(18))
    add("redis://cache:%s@redis.prod.test", _rand(14) + "5")
    v.append(("curl https://admin:admin@prod-db.corp.test/secret", "admin:admin"))
    v.append(("mysql://root:root@db.prod.test/db", "root:root"))
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
        "TOKEN" + _EQ + "GOOGLE_CLIENT_SECRET_2_VALUE",
        "API_KEY" + _EQ + "STRIPE_SECRET_KEY_NAME_V2",
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
        "https://deploy:deploy@host.local/r",
        "Never commit files that start with " + _BEGIN + "PRIVATE KEY----- markers.",
        "The " + _BEGIN + "PGP PRIVATE KEY BLOCK----- header marks an armored key.",
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
        "build_key_name" + _CO + " release-linux-x86_64-2024",
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


CORPORA = {
    "r4": redact_corpus.build,
    "r5": redact_corpus_r5.build,
    "r6": redact_corpus_r6.build,
    "r7": redact_corpus_r7.build,
    "r8": redact_corpus_r8.build,
}
# exotic formats of the r5 corpus that the best-effort layer documents as residuals (by name only)
R5_RESIDUALS = {"ansible vault blob", "session cookie random", "base64-wrapped env", "tab separated"}
# documented residuals of the r7 corpus: Terraform maps keyed by a plain name, .pgpass colon lines, YAML block scalars, JSON map values
R7_RESIDUALS = {"tfvars token map", "pgpass line", "composer github-oauth hex", "yaml folded scalar"}
# documented residuals of the r8 corpus: a bare Heroku CLI uuid and a Rails master.key (a bare 32-hex file body)
R8_RESIDUALS = {"heroku auth token", "rails master.key"}
RESIDUALS = {"r4": (), "r5": R5_RESIDUALS, "r6": (), "r7": R7_RESIDUALS, "r8": R8_RESIDUALS}
# a JSON object quoted inside a prose sentence is not a JSON line, so its \\u escapes stay undecoded
WRAPPER_RESIDUALS = {("jsonl unicode escape sep", "prefix-text")}
WRAPPERS = {
    "plain": lambda t: t,
    "backtick": lambda t: "`" + t + "`",
    "md-quote": lambda t: "> " + t,
    "code-fence": lambda t: "```\n" + t + "\n```",
    "bullet": lambda t: "- " + t,
    "crlf": lambda t: t.replace("\n", "\r\n") + "\r\n",
    "json-str": lambda t: json.dumps({"out": t}),
    "prefix-text": lambda t: "Run this: " + t + " then retry.",
}


def _build_vendor_token(row):
    """A token for a VENDOR row built from the row itself: anchor + each part at a realistic length."""
    name, anchors, parts, _end, left = row
    rng = random.Random(name)
    body = ""
    for part in parts:
        if isinstance(part, str):
            body += part
        else:
            alphabet = _expand(agent_redact.CLS[part[0]])
            body += "".join(rng.choice(alphabet) for _ in range(min(part[2], max(part[1], 24))))
    prefix = ""
    if left:
        prefix = "".join(rng.choice(_expand(agent_redact.CLS[left[0]])) for _ in range(left[1]))
    return prefix + anchors[0] + body, body


def _expand(spec):
    out = ""
    i = 0
    while i < len(spec):
        if i + 2 < len(spec) and spec[i + 1] == "-":
            out += "".join(chr(c) for c in range(ord(spec[i]), ord(spec[i + 2]) + 1))
            i += 3
        else:
            out += spec[i]
            i += 1
    return out


def _value(tag, n=20):
    rng = random.Random(tag)
    return "".join(rng.choice(_ALNUM) for _ in range(n - 3)) + rng.choice("!#%") + "9" + "Q"


class RuleTableTests(unittest.TestCase):
    def test_every_vendor_row_catches_its_own_token(self):
        for row in agent_redact.VENDOR:
            with self.subTest(rule=row[0]):
                token, body = _build_vendor_token(row)
                self.assertEqual(agent_redact.scan("x " + token + " y")[0], row[0])
                self.assertNotIn(body, agent_redact.redact("x " + token + " y"))

    def test_vendor_rows_obey_the_table_lint(self):
        names = [row[0] for row in agent_redact.VENDOR]
        self.assertEqual(len(names), len(set(names)))
        for name, anchors, parts, _end, left in agent_redact.VENDOR:
            with self.subTest(rule=name):
                self.assertTrue(anchors)
                bodies = [p for p in parts if not isinstance(p, str)]
                self.assertTrue(bodies)
                for cls, lo, hi in bodies:
                    self.assertLessEqual(lo, hi)
                    self.assertLessEqual(hi, 8192)
                if left:
                    self.assertLessEqual(left[2], 16)
                for i, part in enumerate(parts):
                    if isinstance(part, str):  # a separator never starts with a char of a neighbouring class
                        for j in (i - 1, i + 1):
                            if 0 <= j < len(parts) and not isinstance(parts[j], str):
                                self.assertNotIn(part[0], _expand(agent_redact.CLS[parts[j][0]]))

    def test_every_cli_row_catches_its_own_secret(self):
        value = _value("cli")
        for prog, rows in agent_redact.CLI.items():
            command = "deploy-cli" if prog == "*" else prog
            for flag, mode, tier in rows:
                forms = []
                if mode in ("next", "either"):
                    forms.append("%s %s %s" % (command, flag, value))
                if mode in ("eq", "either"):
                    forms.append("%s %s=%s" % (command, flag, value))
                if mode in ("attached", "either") and len(flag) == 2:
                    forms.append("%s %s%s" % (command, flag, value))
                for form in forms:
                    with self.subTest(form=form.replace(value, "<v>")):
                        self.assertIsNotNone(agent_redact.scan(form))
                        self.assertNotIn(value, agent_redact.redact(form))

    def test_cli_rows_keep_honest_values(self):
        for text in ("mysql -u app -p app", "docker login -u ci --password-stdin ghcr.io", "deploy-cli --token $GH_TOKEN",
                     "redis-cli -a $REDIS_PASSWORD ping", "sshpass -p '${PW}' ssh host", "curl -" + "u user:$PASS https://h"):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))

    def test_positional_commands(self):
        value = _value("pos")
        for text in ("aws configure set aws_secret_access_key " + value, "poetry config http-basic.corp ci " + value,
                     "poetry config pypi-token.pypi " + value, "htpasswd -b users.txt alice " + value,
                     "ConvertTo-SecureString " + value + " -AsPlainText", "echo " + value + " | docker login --password-stdin",
                     "curl --" + "user ci:" + value + " https://h", "curl -" + "u ci:" + value + " https://h",
                     "login a\n  password " + value, "machine h login u password " + value):
            with self.subTest(text=text.replace(value, "<v>")):
                self.assertIsNotNone(agent_redact.scan(text))
                self.assertNotIn(value, agent_redact.redact(text))
        self.assertIsNone(agent_redact.scan("aws configure set region eu-west-1"))
        self.assertIsNone(agent_redact.scan("htpasswd -b users.txt alice"))

    def test_name_tiers(self):
        tier = agent_redact.name_tier
        self.assertEqual([tier(n) for n in ("password", "DB_PASS", "DB_PWD", "dbPassword", "密码")], ["strong"] * 5)
        self.assertEqual([tier(n) for n in ("token", "client_secret", "dsn", "SECRET_KEY_BASE", "API_KEY", "_auth", "密钥")], ["cred"] * 7)
        self.assertEqual([tier(n) for n in ("cache_key", "sort_key", "sig", "signature")], ["weak"] * 4)
        self.assertEqual(tier("Authorization"), "auth-header")
        for name in ("", "x" * 200, "username", "keyboard", "tokenizer", "!!"):
            self.assertIsNone(tier(name))


class ClassifierTests(unittest.TestCase):
    CASES = (
        # (value, tier, name, minimum verdict: "none" | "possible" | "secret")
        ("${DB_PASSWORD}", "strong", "", "none"), ("$(gh auth token)", "cred", "", "none"), ("{{ vault_pw }}", "strong", "", "none"),
        ("<your-token>", "cred", "", "none"), ("[REDACTED]", "cred", "", "none"), ("process.env.X_TOKEN", "cred", "", "none"),
        ("placeholder-value-123", "strong", "", "none"), ("changeme-changeme", "strong", "", "none"), ("xxxxxxxxxxxxxxxx", "cred", "", "none"),
        ("/etc/app/secrets.yaml", "strong", "", "none"), ("~/.config/app/keys", "cred", "", "none"),
        ("--flag=value", "cred", "", "none"), ("config.json", "cred", "", "none"), ("2024-01-02T03:04:05Z", "weak", "", "none"),
        ("format-{name}", "cred", "", "none"), ("user_name=simple", "cred", "", "none"), ("", "cred", "", "none"),
        ("a phrase with spaces", "strong", "", "possible"), ("a phrase with spaces", "weak", "", "none"),
        ("aGVsbG8gd29ybGQ", "bearer", "", "secret"), ("abc", "bearer", "", "none"), ("justletters", "bearer", "", "none"),
        ("123e4567-e89b-12d3-a456-426614174000", "cred", "api_key", "secret"),
        ("123e4567-e89b-12d3-a456-426614174000", "cred", "session_token", "none"),
        ("getAccessTokenSilently()", "cred", "", "none"), ("Foo::barBazQuxQuuxCorge", "cred", "", "possible"),
        ("this.settings.apiKeyHolderObject", "cred", "", "none"), ("river.horse.battery.staple", "cred", "", "possible"), ("get_token_for_user", "strong", "", "possible"),
        ("Zq8mK2pL9x", "strong", "", "secret"), ("12345678", "strong", "", "possible"), ("Zq8mK2", "strong", "", "possible"),
        ("Zq8mK2pL9xRt4Wv", "cli-pass", "", "secret"), ("Zq8mK2", "cli-pass", "", "secret"),
        ("0123456789abcdef0123", "cred", "", "secret"), ("Zq8mK2pL9xRt4WvB", "cred", "", "secret"),
        ("Zq8!mK2pL9xW", "cred", "", "secret"), ("Zq8mK2pL", "cred", "", "possible"), ("qwertyuiopasdf", "cred", "", "possible"),
        ("0123456789abcdef0123456789abcdef", "weak", "", "secret"), ("cache-1a2b3c4d5e6f7a8b", "weak", "", "none"),
        ("Zq8mK2pL9xRt4WvBn6Yc", "weak", "", "secret"), ("short", "weak", "", "none"),
    )

    def test_decision_list(self):
        order = {"none": 0, "possible": 1, "secret": 2}
        for value, tier, name, expected in self.CASES:
            with self.subTest(value=value[:30], tier=tier):
                self.assertEqual(agent_redact.classify(value, tier, name), order[expected])

    def test_unwrap(self):
        self.assertEqual(agent_redact.unwrap(' "abc" '), "abc")
        self.assertEqual(agent_redact.unwrap("`abc`"), "abc")
        self.assertEqual(agent_redact.unwrap("(abc)"), "abc")
        self.assertEqual(agent_redact.unwrap("f(abc))"), "f(abc)")
        self.assertEqual(agent_redact.unwrap("${X}"), "${X}")

    def test_spans_and_edge_shapes(self):
        pem_open = _BEGIN + "PRIVATE KEY-----\n" + "".join(random.Random(3).choice(_ALNUM) for _ in range(64))
        self.assertEqual(agent_redact.scan(pem_open + "\n-----END PRIVATE KEY")[0], "pem")
        self.assertIsNone(agent_redact.scan("<div>" + _value("x", 30) + "</div> <span>x</span> <add key=\"timeout\" value=\"30\"/> <add key=\"password\" value=\"\"/>"))
        self.assertTrue(agent_redact.is_ident("HTTPS_proxy_setting"))
        opaque = "role arn:aws:iam::123456789012:role/arn:aws:x vault:secret/app/path password=" + _value("opaque", 20)
        self.assertEqual(agent_redact.scan(opaque)[0], "assignment")
        self.assertIsNone(agent_redact.scan("password=arn:aws:secretsmanager:eu-west-1:123456789012:secret:prod/db-AbCdEf"))

    def test_references_are_whole_value(self):
        self.assertTrue(agent_redact.is_reference("${X}/path"))
        self.assertTrue(agent_redact.is_reference("$1"))
        self.assertTrue(agent_redact.is_reference("vault:secret/app"))
        self.assertFalse(agent_redact.is_reference("x$(Zq8mK2pL9xRt4)"))


class CorpusTests(unittest.TestCase):
    def check(self, build, wrapper_name, residuals=()):
        wrap = WRAPPERS[wrapper_name]
        secrets, honest = build()
        for fmt, text, core, *_common in secrets:
            if fmt in residuals or (fmt, wrapper_name) in WRAPPER_RESIDUALS:
                continue
            wrapped = wrap(text)
            with self.subTest(fmt=fmt, wrapper=wrapper_name):
                self.assertIsNotNone(agent_redact.scan(wrapped), "scanner missed")
                expected = json.dumps(core)[1:-1] if wrapper_name == "json-str" else core
                if wrapper_name == "crlf":
                    expected = core.replace("\n", "\r\n")
                self.assertNotIn(expected, agent_redact.redact(wrapped), "redactor kept the secret")
        for fmt, text in honest:
            with self.subTest(honest=fmt, wrapper=wrapper_name):
                self.assertIsNone(agent_redact.scan(wrap(text)), "honest string blocked")

    def test_corpus_sizes(self):
        sizes = {name: tuple(len(part) for part in build()) for name, build in CORPORA.items()}
        self.assertEqual(sizes, {"r4": (122, 133), "r5": (87, 67), "r6": (80, 65), "r7": (114, 87), "r8": (103, 85)})

    def test_every_corpus_in_every_wrapper(self):
        for name, build in CORPORA.items():
            for wrapper in WRAPPERS:
                with self.subTest(corpus=name, wrapper=wrapper):
                    self.check(build, wrapper, RESIDUALS[name])

    def test_logs_of_honest_text_are_mostly_untouched(self):
        """redact() masks a value under a credential name even when scan() does not refuse it (a log is not a brief); the
        honest corpora may lose at most 8% of their strings that way (prose labels, dictionary-word passphrases, PEM mentions)."""
        total = changed = 0
        for build in CORPORA.values():
            for _fmt, text in build()[1]:
                total += 1
                changed += agent_redact.redact(text) != text
        self.assertGreater(total, 340)
        self.assertLessEqual(changed, total * 8 // 100, "%d of %d honest strings are altered" % (changed, total))

    def test_scan_catches_whatever_redact_changes(self):
        for name, build in CORPORA.items():
            secrets, _honest = build()
            for fmt, text, *_rest in secrets:
                if fmt not in RESIDUALS[name] and agent_redact.redact(text) != text:
                    with self.subTest(corpus=name, fmt=fmt):
                        self.assertIsNotNone(agent_redact.scan(text))

    def test_every_refused_span_is_redacted(self):
        for name, build in CORPORA.items():
            for fmt, text, *_rest in build()[0]:
                if any(line.lstrip()[:1] in ("{", "[") for line in text.split("\n")):
                    continue  # JSON lines are scanned on their decoded strings, not on the raw text
                redacted = agent_redact.redact(text)
                for start, end, rule, verdict in agent_redact.candidates(text):
                    if verdict == agent_redact.SECRET and end > start and text.count(text[start:end]) == 1:
                        with self.subTest(corpus=name, fmt=fmt, rule=rule):
                            self.assertNotIn(text[start:end], redacted)

    def test_scan_and_redact_share_the_pipeline(self):
        with mock.patch.object(agent_redact, "analyze", wraps=agent_redact.analyze) as spy:
            agent_redact.scan("password" + _EQ + "Zq8mK2pL9xRt4")
            agent_redact.redact("password" + _EQ + "Zq8mK2pL9xRt4")
        self.assertEqual(spy.call_count, 2)

    def test_rule_names_come_from_the_tables_or_the_passes(self):
        known = {row[0] for row in agent_redact.VENDOR}
        known |= {"pem", "discord-bot", "url-userinfo", "url-token-user", "assignment", "authorization", "xml-element",
                  "xml-attribute", "json-field", "stdin-secret", "netrc", "bearer", "powershell-secure", "cli-aws",
                  "cli-poetry", "cli-htpasswd", "cli-flag", "cli-user", "pair-value", "dockerfile-env", "table-row", "call-argument", "subscript-assign", "form-data"}
        known |= {"cli-" + prog for prog in agent_redact._PROGS}
        for build in CORPORA.values():
            for _fmt, text, *_rest in build()[0]:
                for rule, _line in agent_redact.analyze(text)[0]:
                    self.assertIn(rule, known)


class IdentTests(unittest.TestCase):
    ATTACKS_REFUSED = (
        "API_TOKEN" + _EQ + "deploy_Kx9mQ2Lp8Zr4Tn6W", "SECRET" + _EQ + "river.Kx9mQ2Lp8Zr4Tn6W", "token" + _EQ + "Alpha_Bravo_Kx9mQ2Lp8Zr4",
        "API_KEY" + _EQ + "prod_api_key_v2_Kx9mQ2Lp", "API_KEY" + _EQ + "ab12_cd34_ef56_gh78", "TOKEN" + _EQ + "ab_cd_ef_gh_ij_kl_mn_op",
        "secret=ab_cd_ef_gh_ij_kl_mn_op", "SECRET=Ab_Cd_Ef_Gh_Ij_Kl_Mn_Op", "API_KEY=AB_CD_EF_GH_IJ_KL_MN_OP_QR",
        "SECRET" + _EQ + "sha256_md5_s3_v2_k8s_x1", "password" + _EQ + "Winter2025", "db_password" + _EQ + "Hunter22", "PASSWORD" + _EQ + "qwerty123", "pwd=Summer24",
        "PASS=Admin123", "SECRET_KEY" + _EQ + "thisisnotsecure123", "JWT_SECRET" + _EQ + "supersecretjwtkey", "STRIPE_SECRET" + _EQ + "Ab-Cd-Ef-Gh-Ij-Kl-Mn-Op",
        "TOKEN" + _EQ + "aGVsbG8td29ybGQtdG9rZW4",
    )
    # dictionary words, passphrases and short values: documented residuals for scan(); redact() still masks them
    ATTACKS_MASKED = (
        "API_KEY" + _EQ + "sunsetRiverMountainBlue", "TOKEN" + _EQ + "QuietOceanSilverLamp", "client_secret" + _EQ + "purple_monkey_dishwasher_42",
        "TOKEN" + _EQ + "v1_v2_v3_v4_v5_v6_v7", "PASSWORD" + _EQ + "correct-horse-battery-staple", "PASSWORD" + _EQ + "Correct-Horse-Battery-Staple-9",
        "PASSWORD=correct_horse_battery_staple", "PASSWORD=correct.horse.battery.staple", "PASSWORD=CorrectHorseBatteryStaple",
        "password" + _EQ + "Spring#2025", "API_KEY" + _EQ + "MyCompanyApiKey2024", "JWT_SECRET" + _EQ + "my-jwt-secret-key", "SESSION_SECRET" + _EQ + "keyboardcat",
        "API_KEY=Kx9mQ2Lp",
    )
    HONEST = (
        "token = get_token_for_user", "TOKEN_TYPE=access_token", "secret = load_secret_from_vault", "api_key = settings.STRIPE_API_KEY",
        "password = form.cleaned_data.password", "PASSWORD_FIELD=user_password_hash", "token: ACCESS_TOKEN_V2", "secret_key=SECRET_KEY_NAME",
        "auth_token = AuthToken.objects.create", "token = jwt.encode", "password_validator=MinimumLengthValidator",
        "TOKEN_BACKEND=redis_cache_v3", "secret: app-secrets-prod", "secretName: db-credentials", "api_key: ${{ secrets.API_KEY }}",
        "token" + _EQ + "TokenKind.Refresh", "password" + _EQ + "PasswordHasher.argon2", "PASSWORD_HASHER" + _EQ + "Argon2PasswordHasher", "token_url" + _EQ + "/oauth/token",
        "secret_file=./secrets/prod.env", "passphrase_file=~/.gnupg/passphrase.txt", "pass = handle_password_reset",
        "token = request.cookies.get", "key_file=keys/service-account.json", "TOKEN=github_token_input", "secret = os.urandom",
        "access_token " + _EQ + " response.json", "token " + _EQ + " self._token_cache", "API_KEY_ENV" + _EQ + "OPENAI_API_KEY", "SECRET_ARN" + _EQ + "prod/db/credentials",
        "password: \"{{ vault_db_password }}\"", "token=$(gh auth token)", "client_secret=client_secret_basic",
        "token_endpoint_auth_method" + _EQ + "client_secret_post", "credentials" + _EQ + "DefaultAzureCredential", "password" + _EQ + "PASSWORD_PLACEHOLDER_V1",
        "token=TOKEN_FROM_STEP_3", "pwd = os.getcwd()", "password_reset_token = PasswordResetTokenGenerator",
        "token_key=user:42:refresh", "secret_key_ref=k8s/secret/app#key", "password=Get-Credential", "token=uuid4().hex",
        "authToken: authTokenFromContext", "apiKey: apiKeyFromEnv", "secret = SecretStr", "token: CancellationToken.None",
        "password_policy" + _EQ + "StrongPasswordPolicyV2", "secret_backend" + _EQ + "aws_secrets_manager", "TOKEN_ALGO=HS256", "secret_version" + _EQ + "AWSCURRENT",
    )

    def test_random_tails_and_grouped_values_are_refused(self):
        for text in self.ATTACKS_REFUSED:
            with self.subTest(text=text):
                self.assertIsNotNone(agent_redact.scan(text))
                self.assertIn("[REDACTED]", agent_redact.redact(text))

    def test_passphrases_are_masked_in_logs(self):
        for text in self.ATTACKS_MASKED:
            with self.subTest(text=text):
                self.assertIn("[REDACTED]", agent_redact.redact(text))

    def test_honest_identifiers_pass(self):
        for text in self.HONEST:
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))


class DjangoTests(unittest.TestCase):
    def test_thousand_secret_keys_in_four_forms(self):
        rng = random.Random(1234)
        alphabet = string.ascii_letters + string.digits + "!@#$%^&*(-_=+)"
        missed = []
        for i in range(1000):
            key = "".join(rng.choice(alphabet) for _ in range(rng.choice((50, 51, 64))))
            # an unquoted value cannot hold "&": it would read as the start of a query parameter
            forms = ("SECRET_KEY = '%s'" % key, 'SECRET_KEY = "%s"' % key, "SECRET_KEY=%s" % key.replace("&", "%"),
                     "SECRET_KEY = 'django-insecure-%s'" % key)
            for form in forms:
                if agent_redact.scan(form) is None or key in agent_redact.redact(form):
                    missed.append(form[:30])
        self.assertEqual(missed, [])

    def test_parenthesis_is_not_a_bypass(self):
        for text in ("password=(Zq8mK2pL9xRt4)", "token=f(Zq8mK2pL9xRt4WvB)", "secret=+(Zq8mK2pL9xRt4WvBn)", "password=(x)Zq8mK2pL9xRt4"):
            with self.subTest(text=text):
                self.assertIsNotNone(agent_redact.scan(text))
        for text in ("password=getPassword()", "token = generate_token(user, expires_in=3600)", "secret=load(config.secret)"):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))


class JsonlTests(unittest.TestCase):
    def lines(self, *objs, spaced=False):
        sep = (", ", ": ") if spaced else (",", ":")
        return "\n".join(json.dumps(o, separators=sep) for o in objs) + "\n"

    def test_redacted_lines_stay_valid_json(self):
        secret = _value("jsonl", 24)
        for spaced in (False, True):
            text = self.lines({"type": "exec_output", "output": "export API_TOKEN=" + secret + "\nok"},
                              {"type": "message", "text": "nothing secret here"}, spaced=spaced)
            out = agent_redact.redact(text)
            self.assertNotIn(secret, out)
            rows = [json.loads(line) for line in out.splitlines()]
            self.assertEqual(rows[1], {"type": "message", "text": "nothing secret here"})
            self.assertEqual(out.splitlines()[1], text.splitlines()[1])
            self.assertEqual(agent_redact.scan(text), ("assignment", 1))

    def test_every_r4_secret_inside_a_json_string(self):
        secrets, _honest = redact_corpus.build()
        for fmt, text, core in secrets:
            for spaced in (False, True):
                line = json.dumps({"type": "exec_output", "output": text}, separators=(", ", ": ") if spaced else (",", ":"))
                with self.subTest(fmt=fmt):
                    out = agent_redact.redact(line)
                    json.loads(out)
                    self.assertNotIn(json.dumps(core)[1:-1], out)

    def test_nested_escaped_and_cjk_forms(self):
        secret = _value("nested", 22)
        inner = json.dumps({"password": secret})
        cases = (
            json.dumps({"out": inner}), json.dumps({"out": "密码：" + secret}), json.dumps({"out": "token＝" + secret}),
            json.dumps({"out": _BEGIN + "PRIVATE KEY-----\n" + "".join(random.Random(7).choice(_ALNUM) for _ in range(64)) + "\n-----END PRIVATE KEY-----"}),
            json.dumps({"password": secret}), json.dumps({"a": [{"b": {"api_key": secret}}]}),
            '{"out": "{\\"password\\": \\"' + secret + '\\"}"}',
        )
        for line in cases:
            with self.subTest(line=line[:40]):
                out = agent_redact.redact(line)
                json.loads(out)
                self.assertNotIn(secret, out)
                self.assertIsNotNone(agent_redact.scan(line))

    def test_numbers_under_password_and_non_json(self):
        out = agent_redact.redact('{"password": 123456789, "count": 3}')
        self.assertEqual(json.loads(out), {"password": "[REDACTED]", "count": 3})
        self.assertEqual(agent_redact.scan('{"pin": 1}\n{"password": 12345678}'), ("json-field", 2))
        text = '{not json: password=' + _value("nj", 20) + "}"
        self.assertIsNotNone(agent_redact.scan(text))
        self.assertIsNone(agent_redact.scan('{"password": 12}'))

    def test_deep_nesting_falls_back_to_text(self):
        deep = "[" * 100000
        self.assertIsNone(agent_redact.scan(deep))
        self.assertEqual(agent_redact.redact(deep + "\npassword=" + _value("deep", 20)).splitlines()[0], deep)
        nested = "[" * 5000 + '"x"' + "]" * 5000
        self.assertIsNone(agent_redact.scan(nested))

    def test_scan_reports_the_physical_line(self):
        text = self.lines({"a": 1}, {"b": 2}, {"output": "AWS_SECRET_ACCESS_KEY=" + _value("line", 40)})
        self.assertEqual(agent_redact.scan(text), ("assignment", 3))


class MarkdownTests(unittest.TestCase):
    def test_honest_fixture_has_no_findings(self):
        path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "fixtures", "redact_honest_markdown.md")
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
        self.assertGreaterEqual(len(text.splitlines()), 40)
        self.assertIsNone(agent_redact.scan(text))
        self.assertEqual(agent_redact.redact(text), text)

    def test_code_spans_and_fences(self):
        secret = _value("md", 20)
        self.assertIsNone(agent_redact.scan("Use `redis://:pw@` as the prefix, and `.npmrc _auth=` for npm."))
        self.assertIsNone(agent_redact.scan("**Pass:** `[x]` and \"<your-key>\" and sk-... with an ellipsis"))
        self.assertIsNotNone(agent_redact.scan("```\nDB_PASSWORD=" + secret + "\n```"))
        self.assertIsNotNone(agent_redact.scan("set `password=" + secret + "` now"))
        self.assertNotIn(secret, agent_redact.redact("set `password=" + secret + "` now"))
        self.assertIn("`", agent_redact.redact("set `password=" + secret + "` now"))

    def test_prose_label_before_a_random_token_stays_a_documented_false_positive(self):
        self.assertIsNotNone(agent_redact.scan("this pass: `" + _value("sha", 30) + "`"))


class LinearityTests(unittest.TestCase):
    SIZES = (8 * 1024, 128 * 1024)

    @staticmethod
    def shapes():
        def jsonl_row():
            return json.dumps({"type": "exec_output", "output": "psql -h db -U app -c 'select 1' returned 1 rows; " * 2}) + "\n"
        return {
            "dots": "a.", "dashes": "a-", "unders": "a_", "equals": "=", "token=": "token=", "quotes": "\"'\"'token\"'=\"'",
            "short-lines": "k=v\n", "alnum": "Zq8mK2pL9x", "unicode": "密码：令牌ü€", "nul": "a\x00b=\x00",
            "many-ghp": "ghp_" + "A1b2C3d4E5f6G7h8I9j0K1l2M3n4O5p6Q7r8 ", "many-pw": "password=Zq8!mK2pL9x ",
            "jwt-dash": "eyJ-", "discord-near": "A" * 24 + "." + "B" * 6 + "-", "mysql-line": "mysql ", "docker-login": "docker login ",
            "sshpass": "sshpass ", "redis-cli": "redis-cli ", "netrc-nl": "\n", "netrc-many": "login a\n\n\n\n ", "login-run": "login ",
            "url-colon": "a:", "url-many": "://u:p/", "pem-begins": _BEGIN + "RSA PRIVATE KEY-----\n", "auth-hdr": "Authorization: x ",
            "bearer": "Bearer abcdefgh ", "bearer-spaces": "bearer" + " " * 50, "flags": "--password ", "cli-user": " -u aaaaaaaa",
            "xml": "<password>a", "sig": "?sig=" + "A" * 19 + "&", "minified-js": "function(a,b){return a.token=b.key||c[\"secret\"]};",
            "key-sep-spaces": "token   :", "htpasswd": "htpasswd -b ", "pscale": "pscale_tkn_" + "a." * 20, "fullwidth": "token＝",
            "pct": "token%3D", "json-open": "{", "json-nest": "[", "esc-quote": "\\\"password\\\": \\\"", "backticks": "`",
            "url-at": "https://a@", "url-long-auth": "https://" + "a" * 3000, "pat-run": "pat", "eyJ-dot": "eyJaaaaaaaa.",
            "aws-cfg": "aws configure set ", "echo-pipe": "echo x | ", "name-128": "a" * 127 + "=", "sk-run": "sk-", "amp": "password=a&",
            "paren": "token=f(", "md-fence": "```\n", "json-escapes": '{"a":"' + '\\"' * 4 + '"}\n',
            "jsonl-psql": jsonl_row(),
            # round 7 reviewer shapes
            "ref-underscore": "token=$a" + "_" * 1010 + "! ", "ref-brace": "password={" + "a" * 199 + "}" + "_" * 800 + "! ",
            "backslash-run": "\\", "bs-quote": "\\\"", "eq-token": "token==", "colon-run": ":", "nul-run": "\x00", "uni-run": "密",
            "surrogate-ish": "\udcff", "long-value-ident": "password=" + "Ab_" * 340 + " ", "long-value-path": "secret=/" + "abc/" * 250 + " ",
            "call-args": "token=f(" + "a," * 500 + ") ", "weak-hex": "key=a" + "-abcdef0" * 127 + " ", "cli-quotes": "mysql -p '" + "x" * 1000 + " ",
            "cli-long": "docker login " + "-u " * 2000 + "\n", "netrc-paren": "login(((((((((((((((((", "pem-label": _BEGIN + "" + "A" * 60 + "\n",
            "pem-noend": _BEGIN + "PRIVATE KEY-----\n" + "A" * 64 + "\n", "url-at-run": "a://" + "@" * 100 + " ",
            "url-host-dots": "a://u:p@" + "." * 2000 + " ", "xml-attr": 'key="password" value="', "vendor-SK": "-SK", "vendor-key-": "-key-",
            "tele": "12345678:AA", "slackwh": "https://hooks.slack.com/services/T", "opaque-run": "arn:aws", "ticks-assign": "`token=a` ",
            "md-table": "| API_TOKEN | x |\n", "auth-unknown": "Authorization: SSWS " + "a" * 40 + "\n", "echo-run": "echo ", "bearer-quote": 'bearer "',
            "json-many-pw": '{"password": "Zq8!mK2pL9x"}\n', "k8s-pairs": "- name: DB_PASSWORD\n  value: x\n", "name-flood": "name: password ",
            "obj-value": 'adminPassword": {"value": ', "dockerfile-env": "ENV API_KEY x\n", "long-flag": "--docker-" + "a-" * 20 + "password ",
            "npm-config": "npm config set ", "bracket-open": "token=f(", "dollar-brace": "token=${", "mysql-quoted": "mysql -p'x' -p'y' ",
            "subscript-set": "a['password'] = ", "call-arg": "define('PASSWORD', ", "yaml-tag": "password: !Ref ", "placeholder": "password = (sensitive ",
            "form-data": 'form-data; name="password"\n\n', "nginx-auth": "proxy_set_header Authorization ", "list-value": "- value: x\n",
            "angle-run": "token=https://<a>@<b", "unclosed-dollar": "token=${", "unclosed-paren": "token=f(", "hdr-prose": "Authorization: Basic words and words ",
            "string-prefix": "SECRET_KEY = rb'", "triple-quote": "token = \'\'\'", "rust-raw": 'secret = r##"', "ruby-q": "api_key = %q(", "fallback-op": "token = a || ",
            "env-access": "process.env.TOKEN || ", "setter": "setPassword(", "login-call": "login(a, ", "default-filter": "{{ password | default(",
            "dollar-default": "token=${A:-", "template-run": "{{ ", "symbol-subscript": "cfg[:api_key] = ",
            "json-nested-str": json.dumps({"o": json.dumps({"pass" + "word": "Zq8mK2pL9xRt4"})}) + "\n",
        }

    MEASURE_ROUNDS = 4  # the MEASUREMENT is repeated under load; the asserted bound never changes

    def timed(self, text):
        """CPU seconds of one scan + redact, the best of three runs (a spike from another process only ever adds)."""
        best = 1e9
        gc.collect()
        gc.disable()
        try:
            for _ in range(3):
                start = time.process_time()
                agent_redact.scan(text)
                agent_redact.redact(text)
                best = min(best, time.process_time() - start)
        finally:
            gc.enable()
        return best

    def assert_linear(self, name, unit):
        small, large = (((unit * (size // len(unit) + 1))[:size]) for size in self.SIZES)
        # Measure small and large in the same process, alternately, and keep the best ratio of a few rounds: a
        # quadratic scanner shows ~256x in every round, a linear one ~16x in at least one even on a busy machine.
        best_ratio, shown = None, ""
        for _ in range(self.MEASURE_ROUNDS):
            t_small, t_large = self.timed(small), self.timed(large)
            if t_large < 0.02:
                return
            ratio = t_large / max(t_small, 1e-4)
            if best_ratio is None or ratio < best_ratio:
                best_ratio, shown = ratio, "%s: %.3fs -> %.3fs" % (name, t_small, t_large)
            if best_ratio <= 32:
                break
        # linear is 16; quadratic is 256
        self.assertLessEqual(best_ratio, 32, shown)

    def test_adversarial_shapes_scale_linearly(self):
        for name, unit in self.shapes().items():
            with self.subTest(shape=name):
                self.assert_linear(name, unit)

    def test_every_table_row_scales_linearly(self):
        units = {}
        for name, anchors, parts, _end, _left in agent_redact.VENDOR:
            first = _expand(agent_redact.CLS[parts[0][0]])
            units["vendor-%s-flood" % name] = anchors[0] * 4 + " "
            units["vendor-%s-run" % name] = anchors[0] + first[:1] * (parts[0][2] + 1) + " "
        for prog, rows in agent_redact.CLI.items():
            command = "deploy-cli" if prog == "*" else prog
            for flag, _mode, _tier in rows:
                units["cli-%s-%s" % (prog, flag)] = "%s %s " % (command, flag)
                units["cli-%s-%s-attached" % (prog, flag)] = "%s %s" % (command, flag[:2])
        for name, unit in units.items():
            with self.subTest(row=name):
                self.assert_linear(name, unit)

    def test_regexes_have_no_nested_lazy_or_backreference_shapes(self):
        parser = getattr(re, "_parser", None) or __import__("sre_parse")
        patterns = list(agent_redact._PATTERNS)
        patterns += [rx for rules in agent_redact._ANCH.values() for _name, rx, _first, _fmax, _left in rules]
        self.assertGreater(len(patterns), 40)

        def walk(items, inside_repeat):
            for op, arg in items:
                name = str(op)
                self.assertNotIn(name, ("MIN_REPEAT", "GROUPREF", "GROUPREF_EXISTS"), name)
                if name in ("MAX_REPEAT", "POSSESSIVE_REPEAT"):
                    optional = arg[1] <= 1  # "(...)?" is a choice, not a loop
                    self.assertFalse(inside_repeat and not optional, "nested repeat")
                    walk(arg[2], inside_repeat or not optional)
                elif name == "SUBPATTERN":
                    walk(arg[-1], inside_repeat)
                elif name == "BRANCH":
                    for branch in arg[1]:
                        walk(branch, inside_repeat)
                elif name in ("ASSERT",):
                    walk(arg[1], inside_repeat)
        for pattern in patterns:
            with self.subTest(pattern=pattern.pattern[:50]):
                walk(parser.parse(pattern.pattern, pattern.flags), False)

    def test_one_mebibyte_smoke_bound(self):
        text_units = self.shapes()
        for name in ("dots", "many-pw", "netrc-many", "jsonl-psql", "url-many", "pem-begins", "mysql-line", "jwt-dash"):
            unit = text_units[name]
            text = (unit * (1024 * 1024 // len(unit) + 1))[:1024 * 1024]
            with self.subTest(shape=name):
                # CPU time, not wall time (a loaded machine stretches wall time, not the work done), measured up
                # to three times: the bound itself (10 s for 1 MiB) is unchanged.
                best = 1e9
                for _ in range(3):
                    start = time.process_time()
                    agent_redact.scan(text)
                    agent_redact.redact(text)
                    best = min(best, time.process_time() - start)
                    if best < 10:
                        break
                self.assertLess(best, 10)

    @unittest.skipUnless(os.environ.get("SB_REDACT_LINEARITY_FULL"), "set SB_REDACT_LINEARITY_FULL=1 for the 1 MiB / 64 KiB variant")
    def test_full_ratio_variant(self):
        self.SIZES = (64 * 1024, 1024 * 1024)
        for name, unit in self.shapes().items():
            with self.subTest(shape=name):
                self.assert_linear(name, unit)


class _Std:
    """A stand-in for sys.stdin / sys.stdout with a binary buffer."""

    def __init__(self, data=b""):
        self.buffer = io.BytesIO(data)

    def write(self, text):
        self.buffer.write(text.encode("utf-8", "surrogateescape"))

    def value(self):
        return self.buffer.getvalue().decode("utf-8", "surrogateescape")


class LimitsTests(unittest.TestCase):
    def setUp(self):
        self.env = mock.patch.dict(os.environ)
        self.env.start()
        self.addCleanup(self.env.stop)
        for name in ("SB_REDACT_MAX_BYTES", "SB_REDACT_BUDGET_SEC"):
            os.environ.pop(name, None)

    def run_main(self, argv, stdin=""):
        out, err = _Std(), io.StringIO()
        with mock.patch("sys.stdin", _Std(stdin.encode("utf-8", "surrogateescape"))), mock.patch("sys.stdout", out), redirect_stderr(err):
            rc = agent_redact.main(["agent_redact.py"] + argv)
        return rc, out.value(), err.getvalue()

    def test_budget_clamp(self):
        default = agent_redact.DEFAULT_BUDGET
        self.assertEqual(default, 60)
        for raw in ("0", "-1", "nan", "inf", "-inf", "junk", ""):
            os.environ["SB_REDACT_BUDGET_SEC"] = raw
            self.assertEqual(agent_redact._limits()[1], default, raw)
        os.environ["SB_REDACT_BUDGET_SEC"] = "1e9"
        self.assertEqual(agent_redact._limits()[1], 600)
        os.environ["SB_REDACT_BUDGET_SEC"] = "2.5"
        self.assertEqual(agent_redact._limits()[1], 2.5)

    def test_byte_cap_counts_bytes_not_characters(self):
        os.environ["SB_REDACT_MAX_BYTES"] = "100"
        rc, out, _ = self.run_main(["--scan"], "é" * 60)  # 60 characters, 120 bytes
        self.assertEqual((rc, out), (3, agent_redact.TOO_COMPLEX + "\n"))
        rc, out, _ = self.run_main(["--scan"], "é" * 40)
        self.assertEqual((rc, out), (0, ""))
        for junk in ("junk", "0", "-5", "inf"):
            os.environ["SB_REDACT_MAX_BYTES"] = junk
            self.assertEqual(agent_redact._limits()[0], 16 * 1024 * 1024, junk)

    def test_oversize_redact_is_withheld(self):
        os.environ["SB_REDACT_MAX_BYTES"] = "50"
        rc, out, _ = self.run_main(["--redact"], "password=" + _value("big", 20) + "x" * 60)
        self.assertEqual((rc, out), (3, agent_redact.WITHHELD))

    def test_tiny_budget_on_a_large_input_fails_closed(self):
        os.environ["SB_REDACT_BUDGET_SEC"] = "0.0001"
        big = "login x\n" * 300000
        self.assertEqual(self.run_main(["--scan"], big)[:2], (3, agent_redact.TOO_COMPLEX + "\n"))
        self.assertEqual(self.run_main(["--redact"], big)[:2], (3, agent_redact.WITHHELD))
        with tempfile.TemporaryDirectory() as tmp:
            target = os.path.join(tmp, "log")
            with open(target, "w") as handle:
                handle.write(big)
            rc, _, err = self.run_main(["--redact-file", target])
            self.assertEqual(rc, 3)
            self.assertIn("withheld", err)
            with open(target) as handle:
                self.assertEqual(handle.read(), agent_redact.WITHHELD)

    def test_internal_error_fails_closed(self):
        with mock.patch.object(agent_redact, "analyze", side_effect=RuntimeError("boom\nsecond line")):
            rc, out, err = self.run_main(["--scan"], "x")
            self.assertEqual((rc, out), (2, ""))
            self.assertIn("scanner failed: boom", err)
            self.assertNotIn("second line", err)
            self.assertEqual(self.run_main(["--redact"], "x")[:2], (3, agent_redact.WITHHELD))
            with tempfile.TemporaryDirectory() as tmp:
                target = os.path.join(tmp, "log")
                with open(target, "w") as handle:
                    handle.write("password=hunter")
                self.assertEqual(self.run_main(["--redact-file", target])[0], 3)
                with open(target) as handle:
                    self.assertEqual(handle.read(), agent_redact.WITHHELD)

    def test_error_without_a_message_names_the_exception(self):
        with mock.patch.object(agent_redact, "analyze", side_effect=KeyError()):
            self.assertIn("KeyError", self.run_main(["--scan"], "x")[2])

    def test_guard_works_off_the_main_thread(self):
        import threading
        result = []
        thread = threading.Thread(target=lambda: result.append(agent_redact._guarded(lambda t: t + "!", "ok")))
        thread.start()
        thread.join()
        self.assertEqual(result, ["ok!"])
        self.assertIsNone(agent_redact._DEADLINE)

    def test_alarm_handler_raises_limit_exceeded(self):
        captured = {}

        def fake_signal(signum, handler):
            captured["handler"] = handler
            return None
        with mock.patch.object(agent_redact.signal, "signal", side_effect=fake_signal), mock.patch.object(agent_redact.signal, "setitimer"):
            agent_redact._guarded(lambda t: t, "x")
        with self.assertRaises(agent_redact.LimitExceeded):
            captured["handler"](14, None)

    def test_guard_and_file_enforce_the_byte_cap_directly(self):
        os.environ["SB_REDACT_MAX_BYTES"] = "10"
        with self.assertRaises(agent_redact.LimitExceeded):
            agent_redact._guarded(len, "x" * 20)
        with tempfile.TemporaryDirectory() as tmp:
            target = os.path.join(tmp, "log")
            with open(target, "w") as handle:
                handle.write("y" * 50)
            with self.assertRaises(agent_redact.LimitExceeded):
                agent_redact.redact_file(target)
            with open(target) as handle:
                self.assertEqual(handle.read(), agent_redact.WITHHELD)

    def test_script_runs_as_a_program(self):
        import subprocess
        import sys
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "scripts", "lib", "agent_redact.py")
        done = subprocess.run([sys.executable, script, "--scan"], input=b"password=" + _value("prog", 20).encode(),
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
        self.assertEqual((done.returncode, done.stdout), (1, b"assignment line 1\n"))

    def test_bounded_stdin_read(self):
        os.environ["SB_REDACT_MAX_BYTES"] = "10"
        stream = io.BytesIO(b"x" * 1000)
        with self.assertRaises(agent_redact.LimitExceeded):
            agent_redact.read_bounded(stream)
        self.assertEqual(stream.tell(), 11)


class RedactFileTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)

    def path(self, name):
        return os.path.join(self.tmp.name, name)

    def test_rewrites_in_place_and_keeps_mode(self):
        target = self.path("log")
        secret = _value("file", 20)
        with open(target, "w") as handle:
            handle.write("token=%s\nok\n" % secret)
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
            handle.write("token=%s\n" % _value("fail", 20))
        with mock.patch.object(agent_redact.os, "replace", side_effect=OSError("boom")):
            with self.assertRaises(OSError):
                agent_redact.redact_file(target)
        self.assertEqual([n for n in os.listdir(self.tmp.name) if n.startswith(".redact.")], [])

    def test_invalid_utf8_bytes_survive(self):
        target = self.path("bin")
        with open(target, "wb") as handle:
            handle.write(b"caf\xe9 token=" + _value("bin", 20).encode() + b"\n")
        self.assertTrue(agent_redact.redact_file(target))
        with open(target, "rb") as handle:
            self.assertEqual(handle.read(), b"caf\xe9 token=[REDACTED]\n")


class MainTests(unittest.TestCase):
    def run_main(self, argv, stdin=""):
        out, err = _Std(), io.StringIO()
        with mock.patch("sys.stdin", _Std(stdin.encode("utf-8"))), mock.patch("sys.stdout", out), redirect_stderr(err):
            rc = agent_redact.main(["agent_redact.py"] + argv)
        return rc, out.value(), err.getvalue()

    def test_redact_filter(self):
        rc, out, _ = self.run_main(["--redact"], "token=%s\n" % _value("main", 20))
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
                handle.write("password=%s\n" % _value("rf", 20))
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
