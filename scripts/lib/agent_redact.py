#!/usr/bin/env python3
"""Secret redaction and brief scanning for the /sb:agent-* delegation scripts (R4-31, R10b-06).

Usage:
  agent_redact.py --redact              stdin -> stdout with credentials replaced by [REDACTED]
  agent_redact.py --redact-file PATH    redact PATH in place (temp file + rename; refuses symlinks)
  agent_redact.py --scan                exit 1 (printing "<rule> line <n>") when stdin holds a
                                        literal credential; exit 0 otherwise

This is a documented BEST-EFFORT layer, not a proof. Layers, each a table of named patterns shared by
redact() and scan(): vendor-prefix tokens (_PREFIXED, written from the public prefix/length formats
that open-source rule sets such as gitleaks use), secret-named assignments (_ASSIGN), HTTP headers
(_AUTH_HEADER, _BEARER), command-line flags and credentials (_PASSWORD_FLAG, _CLI_RULES), URL userinfo,
structured values (_VALUE_RULES: XML, Docker auth, SAS signatures, netrc) and private-key blocks.
scan() applies exemptions (placeholders, references, paths, identifiers, UUID ids) that redact() does
not, so redact() may change more than scan() rejects, never less.
"""

import contextlib
import math
import os
import re
import sys
import tempfile

REDACTED = "[REDACTED]"

# --- layer: secret-named assignments -------------------------------------------------------------
# The keyword must END the name (so "tokens: 12" is left alone). "pass"/"pwd" names are STRONG: a
# short (8+ character) mixed value is already a password.
_NAME = (
    r"[A-Za-z0-9_.-]{0,64}(?:secret[_-]?access[_-]?key|secret[_-]?key[_-]?base|secret[_-]?key|client[_-]?secret|"
    r"account[_-]?key|shared[_-]?access[_-]?key|secret|token|passphrase|password|passwd|pass|pwd|"
    r"api[_-]?key|access[_-]?key|private[_-]?key|credentials?|[_-]key)|密码|口令|密钥"
)
_SEP = r"(?:\s*[:=\uff1a\uff1d]\s*|%3[dD])"
_VALUE = r"[^\s\"',;]+"
_STRONG_NAME = re.compile(r"(?:passphrase|password|passwd|pass|pwd)$|密码|口令", re.I)
# generic "*_key" names (cache_key, partition_key, sort_key) are not credentials by themselves
_CREDENTIAL_KEY_NAME = re.compile(
    r"(?:api|access|secret|private|signing|encryption|auth|license|account|master|app|client|shared|storage)[_-]?key$", re.I
)
_GENERIC_KEY_NAME = re.compile(r"[_-]key$", re.I)

# --- layer: vendor-prefix tokens (name, pattern, replacement) -------------------------------------
_PREFIXED = [
    ("pem", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY(?: BLOCK)?-----.*?(?:-----END [A-Z ]*PRIVATE KEY(?: BLOCK)?-----|\Z)", re.S), REDACTED),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"), REDACTED),
    ("github-pat", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}"), "github_pat_" + REDACTED),
    ("github", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}"), "gh_" + REDACTED),
    ("gitlab", re.compile(r"\bglpat-[A-Za-z0-9_-]{20,}"), "glpat-" + REDACTED),
    ("slack", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"), "xox-" + REDACTED),
    ("slack-app", re.compile(r"\bxapp-\d-[A-Za-z0-9]+-\d+-[A-Za-z0-9]+"), "xapp-" + REDACTED),
    ("aws", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"), REDACTED),
    ("google", re.compile(r"\bAIza[0-9A-Za-z_-]{35}"), REDACTED),
    ("google-oauth-secret", re.compile(r"\bGOCSPX-[A-Za-z0-9_-]{28}"), "GOCSPX-" + REDACTED),
    ("google-access-token", re.compile(r"\bya29\.[A-Za-z0-9_-]{50,}"), "ya29." + REDACTED),
    ("slack-webhook", re.compile(r"https://hooks\.slack\.com/services/T[A-Za-z0-9]+/B[A-Za-z0-9]+/[A-Za-z0-9]+"), "https://hooks.slack.com/services/" + REDACTED),
    ("stripe", re.compile(r"\b[sr]k_(?:live|test)_[A-Za-z0-9]{10,}"), "sk_" + REDACTED),
    ("stripe-webhook", re.compile(r"\bwhsec_[A-Za-z0-9]{16,}"), "whsec_" + REDACTED),
    ("sk", re.compile(r"\bsk-[A-Za-z0-9_-]{8,}"), "sk-" + REDACTED),
    ("sendgrid", re.compile(r"\bSG\.[A-Za-z0-9_-]{22}\.[A-Za-z0-9_-]{43}"), "SG." + REDACTED),
    ("digitalocean", re.compile(r"\bdo[por]_v1_[a-f0-9]{64}"), "dop_v1_" + REDACTED),
    ("pypi", re.compile(r"\bpypi-AgEIcHlwaS5vcmc[A-Za-z0-9_-]{50,}"), "pypi-" + REDACTED),
    ("shopify", re.compile(r"\bshp(?:at|ca|pa|ss)_[a-fA-F0-9]{32}"), "shpat_" + REDACTED),
    ("docker-pat", re.compile(r"\bdckr_pat_[A-Za-z0-9_-]{20,}"), "dckr_pat_" + REDACTED),
    ("sentry", re.compile(r"\bsntry[sus]_[A-Za-z0-9]{40,}"), "sntrys_" + REDACTED),
    ("linear", re.compile(r"\blin_api_[A-Za-z0-9]{40}"), "lin_api_" + REDACTED),
    ("atlassian", re.compile(r"\bATATT[A-Za-z0-9_=-]{50,}"), "ATATT" + REDACTED),
    ("mailgun", re.compile(r"\bkey-[a-f0-9]{32}\b"), "key-" + REDACTED),
    ("twilio", re.compile(r"\bSK[a-f0-9]{32}\b"), "SK" + REDACTED),
    ("telegram-bot", re.compile(r"\b\d{8,10}:AA[A-Za-z0-9_-]{33}\b"), REDACTED),
    ("discord-bot", re.compile(r"\b[A-Za-z0-9_-]{24}\.[A-Za-z0-9_-]{6}\.[A-Za-z0-9_-]{27,38}\b"), REDACTED),
    ("npm", re.compile(r"\bnpm_[A-Za-z0-9]{20,}"), "npm_" + REDACTED),
    ("huggingface", re.compile(r"\bhf_[A-Za-z0-9]{20,}"), "hf_" + REDACTED),
    ("sentry-dsn", re.compile(r"(?<=://)[0-9a-f]{32}(?=@[^\s/]*sentry)"), REDACTED),
    ("url-userinfo", re.compile(r"(?<=://)([^\s/@:]*):([^\s/@]+)(?=@)"), REDACTED),
]

# --- value rules: (kind, pattern with a named group "v" for the value, optional group "c" to check).
# redact() replaces the "v" span; scan() tests the "c" (else "v") span with the rule's checker.
_AUTH_HEADER = re.compile(r"\b(?:authorization)(?:\s*[:=]\s*)(?P<v>(?:(?:bearer|basic|token|digest)\s+)?(?P<c>[^\s\"',;]+))", re.I)
_BEARER = re.compile(r"\bbearer\s+(?P<v>[A-Za-z0-9._~+/=-]{8,})", re.I)
_PASSWORD_FLAG = re.compile(r"--(?:password|passwd|token|secret|api-key)(?:=|\s+)(?P<v>\S+)", re.I)
_ASSIGN = re.compile(r"\b(?P<n>" + _NAME + r")[\"']?" + _SEP + r"[\"']?(?P<v>" + _VALUE + ")", re.I)
_CLI_RULES = [
    ("cli-user", re.compile(r"(?:^|\s)(?:-u|--user|--proxy-user)\s+[\"']?[^\s:\"']+:(?P<v>[^\s\"']+)")),
    ("cli-mysql", re.compile(r"\b(?:mysql|mysqldump|mysqladmin|mariadb|psql)\b[^\n]*?\s-p(?P<v>[^\s-]\S{3,})")),
    ("cli-docker", re.compile(r"\b(?:docker|podman)\s+login\b[^\n]*?\s-p\s*(?P<v>\S+)")),
    ("netrc", re.compile(r"\blogin[ \t]+\S+[ \t]+password[ \t]+(?P<v>\S+)", re.I)),
]
# patterns whose match can span lines (scan() runs them over the whole text)
_TEXT_RULES = [
    ("netrc-multiline", re.compile(r"\blogin[ \t]+\S+\s*\n\s*password[ \t]+(?P<v>\S+)", re.I)),
]
_VALUE_RULES = [
    ("xml-element", re.compile(r"<(?:password|passwd|secret|token|apikey|api_key|accesskey)>(?P<v>[^<]+)</", re.I)),
    ("xml-attribute", re.compile(r"key=\"[^\"]*(?:key|secret|token|password)\"\s+value=\"(?P<v>[^\"]+)\"", re.I)),
    ("docker-auth", re.compile(r"\"auth\"\s*:\s*\"(?P<v>[A-Za-z0-9+/=]{20,})\"")),
    ("sas-signature", re.compile(r"[?&;](?:sig|signature|x-amz-signature|x-goog-signature)=(?P<v>[A-Za-z0-9%+/=_-]{20,})", re.I)),
]


def _sub_value(pattern, text):
    def swap(m):
        lo, hi = m.start("v") - m.start(), m.end("v") - m.start()
        whole = m.group(0)
        return whole[:lo] + REDACTED + whole[hi:]
    return pattern.sub(swap, text)


def redact(text):
    """Return ``text`` with credentials replaced."""
    for _kind, pattern, replacement in _PREFIXED:
        text = pattern.sub(replacement, text)
    for pattern in (_PASSWORD_FLAG, _AUTH_HEADER, _BEARER):
        text = _sub_value(pattern, text)
    for _kind, pattern in _CLI_RULES + _TEXT_RULES + _VALUE_RULES:
        text = _sub_value(pattern, text)
    return _sub_value(_ASSIGN, text)


def _entropy(value):
    counts = {}
    for char in value:
        counts[char] = counts.get(char, 0) + 1
    return -sum(n / len(value) * math.log2(n / len(value)) for n in counts.values())


_IDENT_CHAIN = re.compile(r"^[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\.|::|->)[A-Za-z_$][A-Za-z0-9_$]*)+$")
_LOWER_SNAKE = re.compile(r"^[A-Za-z_][A-Za-z_]*$")
_WORDISH = re.compile(r"^[A-Za-z][A-Za-z_-]*$")
_UPPER_SNAKE = re.compile(r"^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+$")
_PLAIN_WORD = re.compile(r"^[A-Za-z]+$")
_NAME_SEGMENTS = re.compile(r"^[A-Za-z0-9]+(?:[_.][A-Za-z0-9]+)+$")
_NAME_WORD = re.compile(r"^(?:[a-z]{3,}|[A-Z][a-z]{2,}|[A-Z]{3,})$")
_UUID = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
# UUIDs are ordinary ids (csrf/session/request/trace) unless the name says credential (Heroku API keys are UUIDs)
_ID_NAME = re.compile(r"csrf|xsrf|session|request|trace|correlation|tracking|idempotency|nonce|state|device|visitor|tenant|upload|order", re.I)
_ENV_REF = re.compile(r"^(?:process\.env|os\.environ|os\.getenv|getenv|ENV\[|settings\.|config\.|secrets\.|vault\.|vault:|op://|arn:|ssm:|file:|env:|secret:|kms:|\$\{|\$[A-Za-z_]|<|%\()", re.I)
# placeholders and obvious test dummies (secret-named-assignment layer only; vendor tokens use _vendor_placeholder)
_DUMMY = re.compile(r"dummy|fake|placeholder|replace[-_ ]?me|change[-_ ]?me|not[-_]a[-_]real|example|sample|redacted|x{4,}|^test[-_]|[-_]test$|for[-_]tests?|^your[-_]|[-_]your[-_]|^\*+$", re.I)
# file paths (absolute, ~, ./ or lowercase relative with a slash) and lowercase key-value style names
_PATH = re.compile(r"^(?:~|\.{0,2})/[a-z0-9._@<>+/-]+$|^[a-z0-9._-]+(?:/[a-z0-9._-]+)+$")
_KV_NAME = re.compile(r"^[a-z0-9]+(?:[:#._=-][a-z0-9]+)+$")
# A PEM/PGP private key counts only with a body line (optionally after "Header: value" lines); the
# newline may be the two characters backslash-n (service-account JSON)
_PEM_BLOCK = re.compile(
    r"-----BEGIN [A-Z ]*PRIVATE KEY(?: BLOCK)?-----[ \t]*(?:\r?\n|\\n)(?:[ \t]*[A-Za-z-]+:[^\n]*\n|[ \t]*\n)*[ \t]*[A-Za-z0-9+/=]{16,}"
)
_TRIVIAL_PASSWORDS = {"password", "passwd", "secret", "admin", "root", "test", "changeme", "example", "user", "pass", "postgres", "mysql", "guest", "app", "dev"}
# local-dev hosts: localhost, loopback, *.local/*.localhost, and single-label compose service names
_LOCAL_HOST = re.compile(r"^(?:localhost|127\.0\.0\.1|\[?::1\]?|0\.0\.0\.0|[A-Za-z0-9_-]+|[A-Za-z0-9.-]*\.(?:localhost|local))$", re.I)


def _is_reference(value):
    """Placeholders and code references: nothing literal to leak."""
    return (
        value[0] in "<{$[(%"
        or value.lower().startswith(("xxxx", "your", "example", "changeme"))
        or "(" in value
        or ")" in value
        or bool(_ENV_REF.match(value))
    )


def _name_identifier(value):
    """Dotted/underscored names made mostly of plain words (generate_secret_key_v2, oauth2_session.fetch_token)."""
    if not _NAME_SEGMENTS.match(value):
        return False
    segments = re.split(r"[_.]", value)
    words = sum(1 for seg in segments if _NAME_WORD.match(seg))
    return words * 2 >= len(segments)


def _screaming_identifier(value):
    """SCREAMING_SNAKE names (GOOGLE_CLIENT_SECRET_2, STRIPE_SECRET_KEY_NAME_V2): at least half of the
    segments are plain words of 4+ letters. Random groups such as AB12_CD34_EF56 contain none."""
    if not _UPPER_SNAKE.match(value):
        return False
    segments = value.split("_")
    words = sum(1 for seg in segments if len(seg) >= 4 and seg.isalpha())
    return words * 2 >= len(segments)


def _case_transition_rate(value):
    flips = sum(1 for a, b in zip(value, value[1:]) if a.islower() != b.islower())
    return flips / len(value)


def _looks_random(value, name="", bearer=False, min_len=16):
    """A literal secret-shaped value: long enough, not a reference/placeholder/path/identifier, and
    random-looking. A Bearer/Authorization value is never a code identifier, so only references and
    low entropy exempt it. A UUID is exempt unless ``name`` marks a credential."""
    value = value.strip("\"'")
    if len(value) < min_len or _is_reference(value):
        return False
    if _UUID.match(value):
        return not name or not _ID_NAME.search(name)
    entropy = _entropy(value)
    if bearer:
        # all-lowercase words ("Basic authentication ...", "Bearer tokens") are prose, not credentials
        return entropy >= 2.5 and not re.fullmatch(r"[a-z]+", value)
    if _DUMMY.search(value) or _PATH.match(value) or _name_identifier(value):
        return False
    if name and _GENERIC_KEY_NAME.search(name) and not _CREDENTIAL_KEY_NAME.search(name) and _KV_NAME.match(value):
        return False
    has_digit = any(c.isdigit() for c in value)
    if not has_digit:
        if _IDENT_CHAIN.match(value) or (_LOWER_SNAKE.match(value) and "_" in value):
            return False
        if _PLAIN_WORD.match(value):
            # camelCase / PascalCase names read as identifiers; a letter run that flips case often,
            # or a long high-entropy one, is a key
            return _case_transition_rate(value) >= 0.4 or (len(value) >= 20 and entropy >= 3.9)
    elif _screaming_identifier(value):
        return False
    return entropy >= (2.8 if min_len < 16 else 3.0)


def _cli_value_secret(value):
    """The value of a command-line credential: any literal that is not a word, reference or dummy."""
    value = value.strip("\"'")
    return _looks_random(value, bearer=True, min_len=8) and not _WORDISH.match(value) and not _DUMMY.search(value)


def _vendor_placeholder(kind, text):
    """Prefix tokens made of filler (ghp_xxxx..., sk-your-key-here, ...AKIA...EXAMPLE) are documentation."""
    body = re.sub(r"^[A-Za-z]+[_.-]", "", text) if kind != "aws" else text[4:]
    return (
        (kind == "discord-bot" and not any(c.isdigit() for c in text))
        or text.endswith("EXAMPLE")
        or body.lower().startswith(("your", "example", "placeholder"))
        or len(body) >= 8 and _entropy(body) < 2.0
    )


def _userinfo_secret(user, password, host):
    """A password in URL userinfo. Only an explicit local-dev default (trivial or equal to the user
    name, on localhost-like hosts and compose service names) is exempt, plus references and placeholders."""
    if not password or _is_reference(password) or _DUMMY.search(password):
        return False
    local = bool(_LOCAL_HOST.match(host))
    return not (local and (password.lower() in _TRIVIAL_PASSWORDS or password == user))


def scan(text):
    """Return ``(kind, line_number)`` of the first literal credential in ``text``, or None.
    Uses the same compiled patterns as :func:`redact`, so the two cannot drift apart."""
    block = _PEM_BLOCK.search(text)
    pem_line = text.count("\n", 0, block.start()) + 1 if block else None
    multiline = {}
    for kind, pattern in _TEXT_RULES:
        for match in pattern.finditer(text):
            if _cli_value_secret(match.group("v")):
                multiline.setdefault(text.count("\n", 0, match.start()) + 1, kind)
    for number, line in enumerate(text.splitlines(), 1):
        if number in multiline:
            return multiline[number], number
        if number == pem_line:
            return "pem", number
        for kind, pattern, _replacement in _PREFIXED:
            if kind == "pem":
                continue
            for match in pattern.finditer(line):
                if kind == "url-userinfo":
                    host = re.match(r"@([^\s/:?#]*)", line[match.end():]).group(1)
                    if _userinfo_secret(match.group(1), match.group(2), host):
                        return kind, number
                elif not _vendor_placeholder(kind, match.group(0)):
                    return kind, number
        for match in _PASSWORD_FLAG.finditer(line):
            if _cli_value_secret(match.group("v")):
                return "flag", number
        for match in _AUTH_HEADER.finditer(line):
            if _looks_random(match.group("c"), bearer=True, min_len=12):
                return "authorization", number
        for match in _BEARER.finditer(line):
            if _looks_random(match.group("v"), bearer=True):
                return "bearer", number
        for kind, pattern in _CLI_RULES + _VALUE_RULES:
            for match in pattern.finditer(line):
                if _cli_value_secret(match.group("v")):
                    return kind, number
        for match in _ASSIGN.finditer(line):
            strong = bool(_STRONG_NAME.search(match.group("n")))
            if _looks_random(match.group("v"), name=match.group("n"), min_len=8 if strong else 16):
                return "assignment", number
    return None


def redact_file(path):
    """Redact ``path`` in place, atomically, keeping its mode. Symlinks are refused."""
    if os.path.islink(path):
        raise OSError("refusing to redact through a symlink: %s" % path)
    if not os.path.isfile(path):
        return False
    with open(path, encoding="utf-8", errors="replace") as handle:
        original = handle.read()
    cleaned = redact(original)
    if cleaned == original:
        return True
    directory = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(prefix=".redact.", dir=directory)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write(cleaned)
        os.chmod(tmp, os.stat(path).st_mode & 0o7777)
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)
        raise
    return True


def main(argv):
    if len(argv) == 2 and argv[1] == "--redact":
        sys.stdout.write(redact(sys.stdin.read()))
        return 0
    if len(argv) == 3 and argv[1] == "--redact-file":
        try:
            redact_file(argv[2])
        except OSError as exc:
            sys.stderr.write("ERROR: %s\n" % exc)
            return 2
        return 0
    if len(argv) == 2 and argv[1] == "--scan":
        found = scan(sys.stdin.read())
        if found:
            sys.stdout.write("%s line %d\n" % found)
            return 1
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
