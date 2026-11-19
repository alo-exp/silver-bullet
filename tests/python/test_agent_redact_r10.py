"""Round-10 regression tests for scripts/lib/agent_redact.py: identifiers inside calls are not secrets (keyed on the parameter name),
chained fallbacks, and the setter/login scans never read an unquoted value."""

import random
import string
import unittest
import uuid
from unittest import mock

from sbtest import load_module
import redact_cloud_honest

agent_redact = load_module("scripts/lib/agent_redact.py")
_RNG = random.Random(1111)


def secret(n=28):
    return "".join(_RNG.choice(string.ascii_letters + string.digits) for _ in range(n))


class CloudHonestTests(unittest.TestCase):
    def test_cloud_sdk_and_cli_lines_are_not_refused(self):
        lines = redact_cloud_honest.build()
        self.assertGreaterEqual(len(lines), 40)
        refused = [t for t in lines if agent_redact.scan(t)]
        self.assertEqual(refused, [])

    def test_the_parameter_name_decides_for_uuid_shaped_literals(self):
        u = str(uuid.UUID(int=_RNG.getrandbits(128)))
        for text in ('x = ClientSecretCredential(tenant_id="a", client_secret="%s")' % u, 'password = make(api_key="%s")' % u,
                     'secret = f(token="arn:aws:iam::123456789012:role/%s")' % secret(), "token = Client(secret_key='%s')" % u):
            with self.subTest(text=text.replace(u, "<uuid>")):
                self.assertIsNotNone(agent_redact.scan(text))
                self.assertNotIn(u, agent_redact.redact(text))
        for text in ('cred = ClientSecretCredential(tenant_id="%s", client_id="%s")' % (u, u), 'secret = vault.get(vault_id="%s")' % u):
            with self.subTest(text=text.replace(u, "<uuid>")):
                self.assertIsNone(agent_redact.scan(text))

    def test_a_random_literal_under_a_neutral_name_is_still_a_secret(self):
        val = secret(32)
        self.assertIsNotNone(agent_redact.scan('password = connect(blob="%s")' % val))


class FallbackEdgeTests(unittest.TestCase):
    def test_chained_fallbacks_reach_the_literal(self):
        val = secret()
        text = "const JWT_SECRET = process.env.JWT_SECRET || process.env.SECRET || '%s';" % val
        self.assertIsNotNone(agent_redact.scan(text))
        self.assertNotIn(val, agent_redact.redact(text))

    def test_error_and_alternative_forms_have_no_default(self):
        for text in ("DB_PASSWORD=${DB_PASSWORD:?DB_PASSWORD must be set}", "TOKEN=${TOKEN:+enabled}", "TOKEN=${TOKEN?missing}"):
            with self.subTest(text=text):
                self.assertIsNone(agent_redact.scan(text))
                self.assertEqual(agent_redact.redact(text), text)


class SetterCostTests(unittest.TestCase):
    def test_setter_and_login_scans_never_read_unquoted_values(self):
        for unit in ("with_token(", "setPassword(", "login(a, "):
            text = unit * 5000
            with mock.patch.object(agent_redact, "_unquoted_value", wraps=agent_redact._unquoted_value) as spy:
                agent_redact.candidates(text)
            self.assertLess(spy.call_count, 50, unit)


if __name__ == "__main__":
    unittest.main()
