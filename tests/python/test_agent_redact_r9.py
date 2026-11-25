"""Round-9 regression tests for scripts/lib/agent_redact.py: prefixed string literals, literal fallbacks behind a reference, wrappers
and setters. Values are generated at run time."""

import random
import string
import unittest

from sbtest import load_module

agent_redact = load_module("scripts/lib/agent_redact.py")
_RNG = random.Random(99)
_ALNUM = string.ascii_letters + string.digits


def secret(n=28):
    return "".join(_RNG.choice(_ALNUM) for _ in range(n))


class Case(unittest.TestCase):
    def refused_and_removed(self, text, val):
        self.assertIsNotNone(agent_redact.scan(text), text)
        self.assertNotIn(val, agent_redact.redact(text), text)

    def honest(self, text):
        self.assertIsNone(agent_redact.scan(text), text)
        self.assertEqual(agent_redact.redact(text), text, text)


class PrefixedStringTests(Case):
    def test_python_string_prefixes_in_any_case(self):
        val = secret()
        prefixes = ["", "b", "B", "r", "R", "u", "U", "f", "F", "rb", "bR", "Rb", "BR", "br", "fr", "Rf", "rF", "t", "T"]
        for pre in prefixes:
            for q in ("'", '"', "'''", '"""'):
                for text in ("SECRET_KEY = %s%s%s%s" % (pre, q, val, q), "app.secret_key = %s%s%s%s" % (pre, q, val, q)):
                    with self.subTest(text=text.replace(val, "<v>")):
                        self.refused_and_removed(text, val)

    def test_other_languages_prefixes(self):
        val = secret()
        for text in ("const apiKey = `%s`;" % val, 'string password = @"%s";' % val, 'var token = $"%s";' % val, 'let secret = r#"%s"#;' % val,
                     'let secret = b"%s";' % val, "password := `%s`" % val, "api_key = %%q(%s)" % val, "api_key = %%Q(%s)" % val,
                     "$password = '%s';" % val, 'val token = """%s"""' % val):
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)

    def test_interpolation_only_templates_stay_expressions_but_literal_text_is_caught(self):
        val = secret()
        for text in ("token = f'{prefix}-{name}'", 'password = f"{a}{b}"', "key = `${a}-${b}`", "secret = f'{env}/db'"):
            with self.subTest(text=text):
                self.honest(text)
        for text in ("token = f'{prefix}-%s'" % val, 'password = f"{a}%s"' % val, "api_key = `${base}%s`" % val):
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)


class FallbackTests(Case):
    def test_literal_fallbacks_behind_a_reference_are_secrets(self):
        val = secret()
        cases = ('const JWT_SECRET = process.env.JWT_SECRET || "%s";' % val, "jwtSecret: process.env.JWT_SECRET || '%s'," % val,
                 'const apiKey = process.env.API_KEY ?? "%s";' % val, 'API_KEY = os.getenv("API_KEY") or "%s"' % val,
                 'password = getpass() or "%s"' % val, "$token = $_ENV['TOKEN'] ?? '%s';" % val, "$password = getenv('DB_PASS') ?: '%s';" % val,
                 'val token = System.getenv("TOKEN") ?: "%s"' % val, 'var password = Environment.GetEnvironmentVariable("PW") ?? "%s";' % val,
                 'export API_TOKEN="${API_TOKEN:-%s}"' % val, "DB_PASSWORD=${DB_PASSWORD:-%s}" % val, "      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-%s}" % val,
                 '      - "JWT_SECRET=${JWT_SECRET:-%s}"' % val, 'TOKEN="${TOKEN:=%s}"' % val, "TOKEN=${TOKEN-%s}" % val,
                 "password: \"{{ db_password | default('%s') }}\"" % val, "password: \"{{ lookup('env', 'DB_PASS') | default('%s') }}\"" % val,
                 'password: {{ default "%s" .Values.password }}' % val, "spring.datasource.password=${DB_PASSWORD:%s}" % val,
                 'api_key = os.getenv("X", "%s")' % val, "api_key = os.environ.get('X', '%s')" % val, "key = ENV.fetch('API_KEY', '%s')" % val,
                 "password = os.environ['PW'] if ci else '%s'" % val, "const token = process.env.TOKEN || '%s'" % val,
                 "ARG API_KEY=%s" % val, "const k = process.env.API_KEY || '%s';" % val, "x = os.environ['API_KEY'] or '%s'" % val)
        for text in cases:
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)

    def test_honest_counterparts_stay_untouched(self):
        for text in ("const t = process.env.TOKEN || '';", "TOKEN = process.env.TOKEN || 'changeme'", "POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-postgres}",
                     "DB_PASSWORD=${DB_PASSWORD:-}", "api_key = os.getenv('X', 'changeme')", "password: \"{{ db_password | default('') }}\"",
                     "key = ENV.fetch('API_KEY', 'example')", "const apiKey = process.env.API_KEY || 'your-api-key-here';",
                     "TOKEN=${TOKEN:-${OTHER_TOKEN}}", "password = os.environ['PW'] if ci else None", "API_KEY=${API_KEY}",
                     "password = getpass() or input('Password: ')"):
            with self.subTest(text=text):
                self.honest(text)


class WrapperAndSetterTests(Case):
    def test_wrappers_setters_and_symbols(self):
        val = secret()
        for text in ('password = SecretStr("%s")' % val, "token = Secret('%s')" % val, "let t = SecretString::new(\"%s\".to_string());" % val if False else
                     'api_key = SecretString::new("%s")' % val, "const key = Buffer.from('%s')" % val, "ds.setPassword('%s');" % val,
                     'conn.set_password("%s")' % val, "client.password('%s')" % val, 'login(user, "%s")' % val, "config[:api_key] = '%s'" % val,
                     "token = str('%s')" % val):
            with self.subTest(text=text.replace(val, "<v>")):
                self.refused_and_removed(text, val)

    def test_honest_calls(self):
        for text in ("ds.setPassword(password);", "client.password(get_password())", "login(user, password)", "login('alice', 'wonderland')",
                     "conn.set_password(os.environ['DB_PASS'])", "config[:timeout] = 5"):
            with self.subTest(text=text):
                self.honest(text)


class EdgeShapeTests(Case):
    def test_unclosed_template_and_literal_shapes(self):
        for text in ("password: {{ unclosed", "token = rb'", 'secret = r#"abc', "api_key = %q(", "x = a or "):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))


if __name__ == "__main__":
    unittest.main()
