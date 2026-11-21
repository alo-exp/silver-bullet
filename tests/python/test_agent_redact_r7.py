"""Round-7 regression tests for scripts/lib/agent_redact.py (review repair r7). Values are generated at run time."""

import io
import json
import os
import random
import re
import string
import tempfile
import unittest
from contextlib import redirect_stderr
from unittest import mock

from sbtest import load_module
from test_agent_redact import _Std, _value

agent_redact = load_module("scripts/lib/agent_redact.py")
_RNG = random.Random(77)
_ALNUM = string.ascii_letters + string.digits


def secret(n=32):
    return "".join(_RNG.choice(_ALNUM) for _ in range(n))


def password():
    return "".join(_RNG.choice(_ALNUM) for _ in range(10)) + "!#" + "7Q"


class Case(unittest.TestCase):
    def refused_and_removed(self, text, *needles):
        self.assertIsNotNone(agent_redact.scan(text), text)
        out = agent_redact.redact(text)
        for needle in needles:
            self.assertNotIn(needle, out, text)
        return out


class AuthorizationTests(Case):
    def test_any_scheme_masks_everything_after_the_header_name(self):
        for scheme in ("SSWS", "Key", "Api-Key", "Splunk", "GenieKey", "OAuth", "SharedKey", "Klaviyo-API-Key", "Basic", "Digest",
                       "Negotiate", "Bearer", "Token", "Mystery-Scheme"):
            tok = secret()
            for text in ("Authorization: %s %s" % (scheme, tok), "curl -H 'Authorization: %s %s' https://h" % (scheme, tok),
                         json.dumps({"Authorization": "%s %s" % (scheme, tok)}), 'Authorization: %s token="%s"' % (scheme, tok)):
                with self.subTest(text=text.replace(tok, "<t>")):
                    out = self.refused_and_removed(text, tok)
                    self.assertIn(scheme, out)

    def test_shared_key_with_account_prefix(self):
        tok = secret(44)
        self.refused_and_removed("Authorization: SharedKey acct:%s" % tok, tok)

    def test_references_after_a_scheme_are_left_alone(self):
        for text in ("Authorization: Bearer $TOKEN", 'curl -H "Authorization: Bearer ${API_TOKEN}"', "Authorization: Key <your-key>"):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))
        self.assertEqual(agent_redact.redact("Authorization: Bearer $TOKEN"), "Authorization: Bearer $TOKEN")


class NameTests(Case):
    def test_concatenated_credential_names(self):
        names = ("authtoken", "NGROK_AUTHTOKEN", "SYSTEM_ACCESSTOKEN", "ACCESSTOKEN", "accesstoken", "apitoken", "APITOKEN", "secretkey",
                 "SECRETKEY", "privatekey", "apisecret", "clientsecret", "masterkey", "AZURE_DEVOPS_EXT_PAT", "GITHUB_PAT", "dbpassword",
                 "adminpass", "userpassword", "rootpw", "ROOT_PW", "db_pw", "ssh-privatekey")
        for name in names:
            val = secret(32)
            for text in ("%s=%s" % (name, val), "%s: %s" % (name, val), json.dumps({name: val})):
                with self.subTest(text=text.replace(val, "<v>")):
                    self.refused_and_removed(text, val)

    def test_look_alike_names_are_not_credentials(self):
        for name in ("bypass", "compass", "keyboard", "tokenizer", "monkey", "passenger", "PublicKey", "public_key", "STRIPE_PUBLISHABLE_KEY",
                     "pubkey", "turkey", "hotkey"):
            with self.subTest(name=name):
                self.assertIsNone(agent_redact.scan("%s=%s" % (name, secret(32))))


class PairTests(Case):
    def test_kubernetes_env_name_value(self):
        val = password()
        self.refused_and_removed("env:\n  - name: DB_PASSWORD\n    value: \"%s\"\n  - name: LOG_LEVEL\n    value: debug\n" % val, val)
        key = secret(32)
        self.refused_and_removed("  - name: STRIPE_API_KEY\n    value: %s" % key, key)
        self.assertIsNone(agent_redact.scan("- name: LOG_LEVEL\n  value: %s" % secret(32)))
        self.assertIsNone(agent_redact.scan("- name: DB_PASSWORD\n  valueFrom:\n    secretKeyRef:\n      name: db\n      key: password\n"))

    def test_name_value_json_objects(self):
        val = password()
        for text in ('"environment": [\n  {"name": "DB_PASSWORD", "value": "%s"}\n]' % val,
                     '{"name":"DB_PASSWORD","value":"%s"}' % val,
                     json.dumps({"environment": [{"name": "DB_PASSWORD", "value": val}]}),
                     json.dumps({"Name": "API_TOKEN", "Value": val})):
            with self.subTest(text=text.replace(val, "<v>")):
                out = self.refused_and_removed(text, val)
                if text.startswith("{") and "\n" not in text:
                    json.loads(out)

    def test_arm_parameters(self):
        val = password()
        for text in ('{"parameters": {"adminPassword": {"value": "%s"}}}' % val,
                     '"adminPassword": {\n  "value": "%s"\n}' % val):
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)
        self.assertIsNone(agent_redact.scan('{"parameters": {"location": {"value": "%s"}}}' % secret(32)))

    def test_java_xml_properties(self):
        val = password()
        for text in ('<property name="password" value="%s"/>' % val, '<property name="hibernate.connection.password">%s</property>' % val,
                     '<entry key="db.secret">%s</entry>' % val, '<add key="ApiToken" value="%s"/>' % val):
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)
        self.assertIsNone(agent_redact.scan('<property name="hibernate.dialect">%s</property>' % "org.hibernate.dialect.PostgreSQLDialect"))

    def test_dockerfile_env_and_arg(self):
        val = secret(32)
        self.refused_and_removed("FROM x\nENV API_KEY %s\nRUN true" % val, val)
        self.refused_and_removed("ARG NPM_TOKEN %s" % val, val)
        self.assertIsNone(agent_redact.scan("ENV NODE_ENV production\nENV PATH /usr/bin"))

    def test_markdown_table_rows(self):
        val = secret(24)
        self.refused_and_removed("| Variable | Value |\n|---|---|\n| API_TOKEN | `%s` |\n" % val, val)
        self.assertIsNone(agent_redact.scan("| Token | Meaning |\n|---|---|\n| token | the auth token for the API |\n"))


class CliTests(Case):
    def test_attached_quoted_password(self):
        val = password().replace("!", "x")
        for text in ("mysql -u root -p'%s' app" % val, 'mysql -h db -u app -p"%s"' % val, "mysqldump -p'%s' db" % val):
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)
        self.assertIsNone(agent_redact.scan("mysql -u app -p 'dbname'"))

    def test_generic_credential_flags_take_the_next_word(self):
        val = secret(32)
        for flag in ("--docker-password", "--admin-password", "--api-token", "--access-key-secret", "--client-secret", "--aws-secret-access-key",
                     "--registry-token"):
            text = "somecli create thing %s %s --other" % (flag, val)
            with self.subTest(flag=flag):
                self.refused_and_removed(text, val)
        for text in ("cli --password-file /run/secrets/pw", "cli --no-password run", "cli --token $GH_TOKEN go", "cli --sort-key name",
                     "cli --token-url https://x/t", "cli --password-stdin < file"):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))

    def test_package_manager_config_set(self):
        val = secret(36)
        for text in ("yarn config set npmAuthToken %s" % val, "npm config set //registry.corp.test/:_authToken %s" % val,
                     "pnpm config set //registry.corp.test/:_authToken %s" % val):
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)
        self.assertIsNone(agent_redact.scan("npm config set registry https://registry.corp.test/"))


class ValueExtentTests(Case):
    HONEST = (
        "API_KEY=${API_KEY}", "GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}", "x_pass=$(cat /run/secrets/pw)", 'password=env("DB_PASS")',
        "token = request.headers.get('X-Auth')", "DATABASE_PASSWORD=${DB_PASSWORD:-}", "password: string", "if (password === confirm) { go(); }",
        "def login(user: str, password: str, api_key: Optional[str] = None):", "password = var.db_password", "api_key = os.environ['API_KEY']",
        "secret: Optional[str] = None", "password: bool", "token: Option<String>",
    )

    def test_references_and_code_survive_redaction_untouched(self):
        for text in self.HONEST:
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))
                self.assertEqual(agent_redact.redact(text), text)

    def test_a_real_secret_after_a_reference_prefix_is_still_masked_whole(self):
        val = secret(24)
        out = self.refused_and_removed("password=f(%s)" % val, val)
        self.assertEqual(out, "password=[REDACTED]")

    def test_unbalanced_brackets_do_not_run_away(self):
        self.assertEqual(agent_redact.redact("token=${A\nnext line"), "token=${A\nnext line")
        text = "token=" + "f(" * 20000
        agent_redact.scan(text)


class JsonRobustnessTests(Case):
    def logfile(self, tmp, data):
        path = os.path.join(tmp, "log")
        with open(path, "wb") as handle:
            handle.write(data)
        return path

    def test_lone_surrogate_escapes_are_redacted_and_stay_valid(self):
        tok, pw = "gh" + "p_" + secret(36), password()
        for escape in ("\\ud83d", "\\udcff", "\\ude00\\ud83d"):
            line = '{"type":"assistant","text":"%s %s"}' % (escape, tok)
            data = ("plain line password=%s\n%s\n" % (pw, line)).encode()
            with tempfile.TemporaryDirectory() as tmp:
                path = self.logfile(tmp, data)
                self.assertTrue(agent_redact.redact_file(path))
                with open(path, "rb") as handle:
                    raw = handle.read()
                text = raw.decode("utf-8")  # strictly valid UTF-8 afterwards
                self.assertNotIn(tok, text)
                self.assertNotIn(pw, text)
                json.loads(text.splitlines()[1])

    def test_main_never_prints_a_traceback_and_never_keeps_the_original(self):
        tok = "gh" + "p_" + secret(36)
        with tempfile.TemporaryDirectory() as tmp:
            path = self.logfile(tmp, ('{"text":"\\ud83d %s"}\n' % tok).encode())
            err = io.StringIO()
            with mock.patch.object(agent_redact, "_encode", side_effect=UnicodeEncodeError("utf-8", "x", 0, 1, "boom")), redirect_stderr(err):
                rc = agent_redact.main(["a", "--redact-file", path])
            self.assertEqual(rc, 3)
            self.assertNotIn("Traceback", err.getvalue())
            with open(path, "rb") as handle:
                self.assertEqual(handle.read(), agent_redact.WITHHELD.encode())

    def test_fuzz_inputs_never_crash_or_leak(self):
        rng = random.Random(4242)
        tok = "gh" + "p_" + secret(36)
        pieces = ['{"a":"', '"}', "\\ud83d", "\\udc00", "\\u00e9", "\\\\", '\\"', "\r\n", "\n", "\xe9".encode("latin-1").decode("latin-1"),
                  " password=" + password() + " ", " " + tok + " ", "{", "[", '"', "'", "`", "\x00", "�", "\U0001f600"]
        for _ in range(300):
            text = "".join(rng.choice(pieces) for _ in range(rng.randint(1, 14)))
            with self.subTest(text=text[:40]):
                out = agent_redact.redact(text)
                out.encode("utf-8", "surrogateescape")
                if tok in text:
                    self.assertNotIn(tok, out)
                agent_redact.scan(text)

    def test_non_utf8_bytes_truncated_json_and_crlf_in_files(self):
        tok, pw = "gh" + "p_" + secret(36), password()
        cases = (b"caf\xe9 \xff\xfe " + tok.encode() + b"\n", ('{"text":"%s", "more":"tru' % tok).encode(),
                 ('{"t":"%s"}\r\n{"u":"password=%s"}\r\n' % (tok, pw)).encode(), b"\x80\x81 password=" + pw.encode())
        for data in cases:
            with tempfile.TemporaryDirectory() as tmp:
                path = self.logfile(tmp, data)
                agent_redact.redact_file(path)
                with open(path, "rb") as handle:
                    raw = handle.read()
                self.assertNotIn(tok.encode(), raw)
                self.assertNotIn(pw.encode(), raw)

    def test_duplicate_keys_and_dict_keys_are_scanned(self):
        tok = secret(32)
        line = '{"text": "API_TOKEN=%s", "text": "ok"}' % tok
        out = self.refused_and_removed(line, tok)
        json.loads(out)
        keyed = '{"API_TOKEN=%s": true}' % tok
        self.refused_and_removed(keyed, tok)

    def test_unchanged_json_lines_are_byte_identical(self):
        line = '  {"n": 1.10, "e": 1e5, "u": "\\u00e9\\/"}\r'
        self.assertEqual(agent_redact.redact(line + "\n"), line + "\n")


class EdgeShapeTests(Case):
    def test_unusual_shapes_do_not_crash_or_invent_findings(self):
        val = password()
        for text in ("token=f(a] b", 'echo "Authorization: Bearer', "Authorization: Bearer", "Authorization: Bearer\n", '[{"value": "%s"}]' % val,
                     'x {"parameters": {"location": {"value": "%s"}}}' % secret(30), 'x {"adminPassword": {"value": ""}}',
                     'ENV API_KEY ""', "<property name=\"db.password\">v<b>", '{"Authorization": "Bearer "}', "- name: DB_PASSWORD", 'x [{"value": "%s"}]' % val, '{"Authorization": ""}'):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))
        out = agent_redact.redact("Authorization: Bearer ab-123 end")
        self.assertEqual(out, "Authorization: Bearer [REDACTED] end")


class CursorTests(unittest.TestCase):
    def test_assignment_cursor_skips_anchors_inside_a_consumed_value(self):
        calls = []
        original = agent_redact._value_at

        def counting(*args, **kwargs):
            calls.append(1)
            return original(*args, **kwargs)
        text = "token=" * 6000
        with mock.patch.object(agent_redact, "_value_at", counting):
            agent_redact.candidates(text)
        self.assertLess(len(calls), len(text) // 100)


class ReferenceCostTests(unittest.TestCase):
    def test_reference_check_is_not_quadratic_on_underscores(self):
        import time
        unit = "token=$a" + "_" * 1010 + "! "
        small, large = unit * 8, unit * 64
        t0 = time.process_time()
        agent_redact.scan(small)
        t_small = time.process_time() - t0
        t0 = time.process_time()
        agent_redact.scan(large)
        t_large = time.process_time() - t0
        if t_large > 0.05:
            self.assertLess(t_large / max(t_small, 1e-4), 24)


if __name__ == "__main__":
    unittest.main()
