"""Round-8 regression tests for scripts/lib/agent_redact.py: honest code is not refused, references and placeholders are left
alone, and a credential name given as a subscript or call argument is paired with its value."""

import random
import string
import time
import unittest

from sbtest import load_module
import redact_code_honest
from test_agent_redact import _value

agent_redact = load_module("scripts/lib/agent_redact.py")
_RNG = random.Random(88)
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


class HonestCodeTests(Case):
    def test_everyday_code_lines_are_not_refused(self):
        lines, extras = redact_code_honest.build()
        self.assertEqual(len(lines), 240)
        refused = [t for t in lines if agent_redact.scan(t)]
        self.assertLessEqual(len(refused), len(lines) * 2 // 100, refused[:5])
        for text in extras:
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))

    def test_expressions_and_placeholders_are_not_altered_in_logs(self):
        lines, extras = redact_code_honest.build()
        altered = [t for t in lines + extras if agent_redact.redact(t) != t]
        self.assertLessEqual(len(altered), 4, altered)

    def test_a_call_that_carries_a_literal_secret_is_still_caught(self):
        val = secret(24)
        for text in ('token = Client(api_key="%s")' % val, 'password = hash("%s")' % val, "x = login(user, password='%s')" % val,
                     "secret = make(%s)" % val, "password=(x)%s" % val):
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)

    def test_expression_grammar(self):
        for ok in ("a.b(c).d()", "f(g(h(1)))", "x['k'].m()", "os.environ['X']", "a.b(c, d=e + f)", "new Foo(bar)", "await get(x)"):
            with self.subTest(expr=ok):
                self.assertTrue(agent_redact.is_expr(ok))
        for bad in ("f(Zq8mK2pL9xRt4WvB7n3)", "(x)Zq8mK2pL9xRt4", "f(x)Zq8", "plain", "f(", "a.b(c))"):
            with self.subTest(expr=bad):
                self.assertFalse(agent_redact.is_expr(bad))
        deep = "f(" * 40 + "x" + ")" * 40
        self.assertIsNotNone(agent_redact.is_expr(deep))


class PlaceholderTests(Case):
    def test_placeholders_and_references_are_left_alone(self):
        for text in ("      + password = (sensitive value)", "  ~ token = (known after apply)", "password: known after apply",
                     'Error: Invalid value for "password": (sensitive value)', "password = ***", "token: <redacted>", "secret = [REDACTED]",
                     "token = <secret>", "password: '@Microsoft.KeyVault(SecretUri=https://kv.vault.azure.net/secrets/db/)'",
                     'password: "%env(DATABASE_PASSWORD)%"', "password: %env(DATABASE_PASSWORD)%", "MasterUserPassword: !Ref DBPassword",
                     "Password: !Sub '${Stack}-db-password'", "api_key: !secret ha_api_key", "password: !env_var DB_PASSWORD",
                     "password: '{{resolve:ssm-secure:/prod/db/password:1}}'", "password:  16 bytes", "token = <%= ENV['API_TOKEN'] %>",
                     "SENTRY_DSN=https://<key>@o0.ingest.sentry.io/<project>"):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))
                self.assertEqual(agent_redact.redact(text), text)

    def test_a_secret_next_to_a_placeholder_is_still_masked(self):
        val = secret(32)
        out = self.refused_and_removed("password = (sensitive value)\napi_key = %s" % val, val)
        self.assertIn("(sensitive value)", out)


class SubscriptAndCallArgumentTests(Case):
    def test_name_as_a_subscript_or_first_argument(self):
        val, pw = secret(32), password()
        cases = ("define('DB_PASSWORD', '%s');" % pw, "define( 'AUTH_KEY', '%s' );" % val, 'os.environ["API_KEY"] = "%s"' % val,
                 "app.config['SECRET_KEY'] = '%s'" % val, "$config['db_password'] = '%s';" % pw, "ENV['API_TOKEN'] = '%s'" % val,
                 'config["api_key"] = "%s"' % val, 'os.Setenv("API_KEY", "%s")' % val, 'props.setProperty("password", "%s");' % pw,
                 'headers.put("X-Api-Key", "%s")' % val, 'os.environ.get("SERVICE_TOKEN", "%s")' % secret(40),
                 'settings.set("api_key", "%s")' % val, "putenv('API_TOKEN=%s');" % val, 'config.put("password", "%s")' % pw,
                 "session['token'] = '%s'" % val, "headers['Authorization'] = 'Bearer %s'" % val)
        for text in cases:
            with self.subTest(text=text):
                self.refused_and_removed(text, val, pw)

    def test_harmless_subscripts_and_calls_are_left_alone(self):
        for text in ("define('DB_NAME', 'wordpress');", "app.config['DEBUG'] = True", "os.environ['HOME'] = '/root'", "config.get('password', None)",
                     'os.environ.get("API_TOKEN", "")', "settings.get('api_key', default_api_key)", "headers['Accept'] = 'application/json'",
                     "session['user'] = user_id", "define('SECURE_AUTH_KEY', getenv('SECURE_AUTH_KEY'));"):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))
                self.assertEqual(agent_redact.redact(text), text)


class MinorFormatTests(Case):
    def test_new_rows_and_grammars(self):
        val, pw = secret(40), password()
        cases = ("FlyV1 fm2_%s" % val, "TEAMS=https://acme.webhook.office.com/webhookb2/%s@%s/IncomingWebhook/%s/%s" % (
            secret(8) + "-" + secret(4), secret(8) + "-" + secret(4), secret(32), secret(36)),
                 '------Boundary\r\nContent-Disposition: form-data; name="password"\r\n\r\n%s\r\n------Boundary--' % pw,
                 'proxy_set_header Authorization "Basic %s";' % val, "gh secret set API_TOKEN --body %s" % val, "vault login %s" % val,
                 "adminpwd: %s" % pw, 'cloud.auth: "elastic:%s"' % pw, "network={\n  ssid=\"x\"\n  psk=\"%s\"\n}" % pw,
                 "- value: %s\n  name: DB_PASSWORD" % pw)
        for text in cases:
            with self.subTest(text=text[:40]):
                self.refused_and_removed(text, val, pw)

    def test_honest_neighbours(self):
        for text in ("vault login -method=ldap username=alice", "gh secret set API_TOKEN < token.txt", "gh secret list",
                     "- value: debug\n  name: LOG_LEVEL", 'proxy_set_header Host "example.test";'):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))


class EdgeShapeTests(Case):
    def test_degenerate_shapes_are_quietly_ignored(self):
        self.assertTrue(agent_redact.is_expr("f(a=)"))
        for text in ('--x\r\nContent-Disposition: form-data; name="comment"\r\n\r\nhello\r\n', 'form-data; name="password"\n\n',
                     'proxy_set_header Authorization ;', 'proxy_set_header Authorization "";', 'proxy_set_header Authorization " ";',
                     "headers['Authorization'] = ' '", "headers['Authorization'] = ''"):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))


class OpenerCostTests(unittest.TestCase):
    def test_unclosed_opener_runs_have_a_bounded_amount_of_bracket_work(self):
        for unit in ("token=${", "token=$(", "token=${{ "):
            text = (unit * (64 * 1024 // len(unit) + 1))[:64 * 1024]
            agent_redact.candidates(text)
            # the per-text allowance is 8 characters of bracket scanning per input character; one scan may overrun it by a window
            self.assertGreater(agent_redact._BAL_BUDGET[0], -2 * agent_redact.VALUE_MAX, unit)
            self.assertLess(agent_redact._BAL_BUDGET[0], 8 * len(text) + 4096, unit)  # and the work really is being counted

    def test_unclosed_opener_runs_are_fast_enough(self):
        text = ("token=${" * (256 * 1024 // 8))
        start = time.process_time()
        agent_redact.scan(text)
        agent_redact.redact(text)
        self.assertLess(time.process_time() - start, 30.0)  # a coarse backstop; the work bound above is the real test


if __name__ == "__main__":
    unittest.main()
