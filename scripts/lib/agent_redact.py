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

import collections
import contextlib
import math
import os
import re
import signal
import sys
import tempfile

REDACTED = "[REDACTED]"

# --- layer: secret-named assignments -------------------------------------------------------------
# Found separator-first (a cheap regex locates "=" / ":" / "%3D", then the NAME is the run of name
# characters before it and must END in a credential keyword), so no pattern rescans the text per
# position. "pass"/"pwd" names are STRONG: a short (8+ character) mixed value is already a password.
_KEYWORDS = (
    r"secret[_-]?access[_-]?key|secret[_-]?key[_-]?base|secret[_-]?key|client[_-]?secret|"
    r"account[_-]?key|shared[_-]?access[_-]?key|secret|token|passphrase|password|passwd|pass|pwd|"
    r"api[_-]?key|access[_-]?key|private[_-]?key|credentials?|[_-]key|_auth|密码|口令|密钥"
)
# a credential keyword that ENDS the name, i.e. is followed by blanks/quotes and a separator
_KEY_SEP = re.compile(r"(?:" + _KEYWORDS + r")(?=[\"' \t]{0,3}(?:[:=\uff1a\uff1d]|%3[dD]))", re.I)
# the value is capped (1024) so a flood of "token=token=..." cannot make each match rescan the rest
_SEP_AT = re.compile(r"[\"' \t]{0,3}(?:[:=\uff1a\uff1d]|%3[dD])[ \t]*[\"']?(?P<v>[^\s\"',;]{1,1024})")
_NAME_BREAK = re.compile(r"[^A-Za-z0-9_.\u4e00-\u9fff-]")
_KEYWORD_HINTS = ("secret", "token", "pass", "pwd", "key", "credential", "_auth", "密码", "口令", "密钥")
_STRONG_NAME = re.compile(r"(?:passphrase|password|passwd|pass|pwd)$|密码|口令", re.I)
# generic "*_key" names (cache_key, partition_key, sort_key) are not credentials by themselves
_CREDENTIAL_KEY_NAME = re.compile(
    r"(?:api|access|secret|private|signing|encryption|auth|license|account|master|app|client|shared|storage)[_-]?key$", re.I
)
_GENERIC_KEY_NAME = re.compile(r"[_-]key$", re.I)


def _assignments(text):
    """Yield (name, value_start, value_end) for every secret-named assignment in ``text``."""
    lowered = text.lower()
    if not any(hint in lowered for hint in _KEYWORD_HINTS):
        return
    consumed = 0
    for key in _KEY_SEP.finditer(text):
        if key.start() < consumed:
            continue  # inside the previous value ("token=token=..."): that value already covers it
        lo = max(0, key.start() - 64)
        window = text[lo:key.start()][::-1]
        cut = _NAME_BREAK.search(window)
        prefix = window[:cut.start()] if cut else window
        value = _SEP_AT.match(text, key.end())
        if value is not None:
            consumed = value.end("v")
            yield prefix[::-1] + key.group(0), value.start("v"), value.end("v")


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
    ("groq", re.compile(r"\bgsk_[A-Za-z0-9]{40,}"), "gsk_" + REDACTED),
    ("netlify", re.compile(r"\bnfp_[A-Za-z0-9]{30,}"), "nfp_" + REDACTED),
    ("planetscale", re.compile(r"\bpscale_(?:tkn|pw|oauth)_[A-Za-z0-9_.-]{30,}"), "pscale_" + REDACTED),
    ("render", re.compile(r"\brnd_[A-Za-z0-9]{28,}"), "rnd_" + REDACTED),
    ("pat", re.compile(r"\bpat_[A-Za-z0-9]{36,}"), "pat_" + REDACTED),
    ("airtable", re.compile(r"\bpat[A-Za-z0-9]{14}\.[a-f0-9]{64}"), REDACTED),
    ("xai", re.compile(r"\bxai-[A-Za-z0-9]{60,}"), "xai-" + REDACTED),
    ("perplexity", re.compile(r"\bpplx-[A-Za-z0-9]{40,}"), "pplx-" + REDACTED),
    ("replicate", re.compile(r"\br8_[A-Za-z0-9]{36,}"), "r8_" + REDACTED),
    ("supabase", re.compile(r"\bsbp_[a-f0-9]{40}"), "sbp_" + REDACTED),
    ("circleci", re.compile(r"\bCCIPAT_[A-Za-z0-9]{20,}_[a-f0-9]{40}"), "CCIPAT_" + REDACTED),
    ("terraform-cloud", re.compile(r"\b[a-z0-9]{14}\.atlasv1\.[A-Za-z0-9]{60,}"), REDACTED),
    ("url-token-user", re.compile(r"(?<=://)[0-9a-f]{40}(?=@)"), REDACTED),
    ("sentry-dsn", re.compile(r"(?<=://)[0-9a-f]{32}(?=@[^\s/]*sentry)"), REDACTED),
    ("url-userinfo", re.compile(r"(?<=://)([^\s/@:]*):([^\s/@]+)(?=@)"), REDACTED),
]

# --- value rules: (kind, pattern with a named group "v" for the value, optional group "c" to check).
# redact() replaces the "v" span; scan() tests the "c" (else "v") span with the rule's checker.
_AUTH_HEADER = re.compile(r"\b(?:authorization)(?:[ \t]*[:=][ \t]*)(?P<v>(?:(?:bearer|basic|token|digest)\s+)?(?P<c>[^\s\"',;]+))", re.I)
_BEARER = re.compile(r"\bbearer[ \t]+(?P<v>[A-Za-z0-9._~+/=-]{8,})", re.I)
_PASSWORD_FLAG = re.compile(r"--(?:password|passwd|token|secret|api-key)(?:=|[ \t]+)(?P<v>\S+)", re.I)
_CLI_RULES = [
    ("cli-user", re.compile(r"(?:^|\s)(?:-u|--user|--proxy-user)\s+[\"']?[^\s:\"']+:(?P<v>[^\s\"']+)")),
    ("cli-mysql", re.compile(r"\b(?:mysql|mysqldump|mysqladmin|mariadb|psql)\b[^\n]*?\s-p(?P<v>[^\s-]\S{3,})")),
    ("cli-docker", re.compile(r"\b(?:docker|podman)\s+login\b[^\n]*?\s-p\s*(?P<v>\S+)")),
    ("cli-sshpass", re.compile(r"\bsshpass\b[^\n]*?\s-p\s*[\"']?(?P<v>[^\s\"']+)")),
    ("cli-redis", re.compile(r"\bredis-cli\b[^\n]*?\s(?:-a|--pass)\s+[\"']?(?P<v>[^\s\"']+)")),
    ("cli-htpasswd", re.compile(r"\bhtpasswd\s+-[a-zA-Z]*b[a-zA-Z]*\s+\S+\s+\S+\s+[\"']?(?P<v>[^\s\"']+)")),
    ("powershell-secure", re.compile(r"ConvertTo-SecureString\s+[\"'](?P<v>[^\"']+)[\"']", re.I)),
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


# Cheap prefilter: a rule runs only when one of its literals (lower case) occurs in the text, so inputs
# with no candidate never pay for the regex (keeps scan/redact fast on adversarial text).
_HINTS = {
    "pem": ("private key",), "jwt": ("eyj",), "github-pat": ("github_pat_",), "github": ("ghp_", "gho_", "ghu_", "ghs_", "ghr_"),
    "gitlab": ("glpat-",), "slack": ("xox",), "slack-app": ("xapp-",), "aws": ("akia", "asia"), "google": ("aiza",),
    "google-oauth-secret": ("gocspx-",), "google-access-token": ("ya29.",), "slack-webhook": ("hooks.slack.com",),
    "stripe": ("sk_live_", "sk_test_", "rk_live_", "rk_test_"), "stripe-webhook": ("whsec_",), "sk": ("sk-",),
    "sendgrid": ("sg.",), "digitalocean": ("dop_v1_", "doo_v1_", "dor_v1_"), "pypi": ("pypi-",), "shopify": ("shp",),
    "docker-pat": ("dckr_pat_",), "sentry": ("sntry",), "linear": ("lin_api_",), "atlassian": ("atatt",),
    "mailgun": ("key-",), "twilio": ("sk",), "telegram-bot": (":aa",), "discord-bot": (".",), "npm": ("npm_",),
    "huggingface": ("hf_",), "groq": ("gsk_",), "netlify": ("nfp_",), "planetscale": ("pscale_",), "render": ("rnd_",),
    "pat": ("pat_",), "airtable": ("pat",), "xai": ("xai-",), "perplexity": ("pplx-",), "replicate": ("r8_",),
    "supabase": ("sbp_",), "circleci": ("ccipat_",), "terraform-cloud": (".atlasv1.",), "url-token-user": ("://",),
    "sentry-dsn": ("://",), "url-userinfo": ("://",),
    "flag": ("--",), "authorization": ("authorization",), "bearer": ("bearer",),
    "cli-user": ("-u", "--user", "--proxy-user"), "cli-mysql": ("mysql", "psql", "mariadb"), "cli-docker": ("login",),
    "cli-sshpass": ("sshpass",), "cli-redis": ("redis-cli",), "cli-htpasswd": ("htpasswd",),
    "powershell-secure": ("convertto-securestring",), "netrc": ("login",), "netrc-multiline": ("login",),
    "xml-element": ("<",), "xml-attribute": ("value=",), "docker-auth": ('"auth"',), "sas-signature": ("sig",),
}


def _wanted(kind, lowered):
    hints = _HINTS.get(kind)
    return hints is None or any(h in lowered for h in hints)


def _sub_value(pattern, text):
    def swap(m):
        lo, hi = m.start("v") - m.start(), m.end("v") - m.start()
        whole = m.group(0)
        return whole[:lo] + REDACTED + whole[hi:]
    return pattern.sub(swap, text)


def redact(text):
    """Return ``text`` with credentials replaced."""
    lowered = text.lower()
    for kind, pattern, replacement in _PREFIXED:
        if _wanted(kind, lowered):
            text = pattern.sub(replacement, text)
    for kind, pattern in (("flag", _PASSWORD_FLAG), ("authorization", _AUTH_HEADER), ("bearer", _BEARER)):
        if _wanted(kind, lowered):
            text = _sub_value(pattern, text)
    for kind, pattern in _CLI_RULES + _TEXT_RULES + _VALUE_RULES:
        if _wanted(kind, lowered):
            text = _sub_value(pattern, text)
    pieces, last = [], 0
    for _name, start, end in _assignments(text):
        pieces.append(text[last:start])
        pieces.append(REDACTED)
        last = end
    pieces.append(text[last:])
    return "".join(pieces)


def _entropy(value):
    return -sum(n / len(value) * math.log2(n / len(value)) for n in collections.Counter(value).values())


# Identifier-shaped values (code references, enum names) under a credential name are accepted, but ONLY when
# every segment is a short dictionary-like word (lower, Capitalized or UPPER case; camelCase inside a
# dotted/arrow chain) or a tiny version-like token (v2, s3, sha256) and at least half are real words.
# A random tail after a word prefix (gsk_..., pat_..., Summer_...) never qualifies.
_WORD_SEG = re.compile(r"^(?:[a-z]{2,14}|[A-Z][a-z]{1,13}|[A-Z]{2,14})$")
_NUM_SEG = re.compile(r"^[A-Za-z]{0,6}[0-9]{1,3}$")
_CAMEL_SEG = re.compile(r"^\$?(?:[a-z]{1,14}|[A-Z][a-z]{1,13})(?:[A-Z][a-z]{1,13}){0,5}$")
_HYPHEN_WORDS = re.compile(r"^[A-Za-z]{1,40}(?:-[A-Za-z]{1,40})+$")
_CHAIN_SPLIT = re.compile(r"\.|::|->")
_WORDISH = re.compile(r"^[A-Za-z][A-Za-z_-]*$")
_PLAIN_WORD = re.compile(r"^[A-Za-z]+$")
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
    """snake_case / dotted / SCREAMING_SNAKE / hyphenated word sequences (generate_secret_key_v2,
    oauth2_session.fetch_token, STRIPE_SECRET_KEY_NAME_V2, Get-Location)."""
    if _HYPHEN_WORDS.match(value):
        return all(_CAMEL_SEG.match(seg) for seg in value.split("-"))
    segments = [seg for seg in re.split(r"[_.]", value) if seg]
    if len(segments) < 2 or not re.fullmatch(r"[A-Za-z0-9_.]+", value):
        return False
    words = 0
    for seg in segments:
        if _WORD_SEG.match(seg):
            words += 1
        elif not _NUM_SEG.match(seg):
            return False
    return words * 2 >= len(segments)


def _chain_identifier(value):
    """Attribute / scope chains of camelCase names (req.body.passwordConfirmation, Foo::barBaz, a->b)."""
    parts = _CHAIN_SPLIT.split(value)
    return len(parts) > 1 and all(
        _CAMEL_SEG.match(part)
        for part in parts
    )


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
        if _chain_identifier(value):
            return False
        if _CAMEL_SEG.match(value):
            return False
        if _PLAIN_WORD.match(value):
            # camelCase / PascalCase names read as identifiers; a letter run that flips case often,
            # or a long high-entropy one, is a key
            return _case_transition_rate(value) >= 0.4 or (len(value) >= 20 and entropy >= 3.9)
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
    Uses the same compiled patterns as :func:`redact`, so the two cannot drift apart. Every rule runs
    once over the whole text (not once per line); the earliest accepted match wins, ties by rule order."""
    lowered = text.lower()
    best = [None]

    def line_of(offset):
        return text.count("\n", 0, offset) + 1

    def offer(kind, offset):
        number = line_of(offset)
        if best[0] is None or number < best[0][1]:
            best[0] = (kind, number)

    block = _PEM_BLOCK.search(text)
    if block:
        offer("pem", block.start())
    for kind, pattern in _TEXT_RULES:
        if _wanted(kind, lowered):
            for match in pattern.finditer(text):
                if _cli_value_secret(match.group("v")):
                    offer(kind, match.start())
                    break
    for kind, pattern, _replacement in _PREFIXED:
        if kind == "pem" or not _wanted(kind, lowered):
            continue
        for match in pattern.finditer(text):
            if kind == "url-userinfo":
                host = re.match(r"@([^\s/:?#]*)", text[match.end():match.end() + 256]).group(1)
                accepted = _userinfo_secret(match.group(1), match.group(2), host)
            else:
                accepted = not _vendor_placeholder(kind, match.group(0))
            if accepted:
                offer(kind, match.start())
                break
    for kind, pattern, check in (
        ("flag", _PASSWORD_FLAG, lambda m: _cli_value_secret(m.group("v"))),
        ("authorization", _AUTH_HEADER, lambda m: _looks_random(m.group("c"), bearer=True, min_len=12)),
        ("bearer", _BEARER, lambda m: _looks_random(m.group("v"), bearer=True)),
    ) + tuple((kind, pattern, lambda m: _cli_value_secret(m.group("v"))) for kind, pattern in _CLI_RULES + _VALUE_RULES):
        if _wanted(kind, lowered):
            for match in pattern.finditer(text):
                if check(match):
                    offer(kind, match.start())
                    break
    for name, start, end in _assignments(text):
        strong = bool(_STRONG_NAME.search(name))
        if _looks_random(text[start:end], name=name, min_len=8 if strong else 16):
            offer("assignment", start)
            break
    return best[0]


# --- fail-closed limits (command-line use) ------------------------------------------------------
# One call handles at most SB_REDACT_MAX_BYTES (default 16 MiB) characters and runs at most
# SB_REDACT_BUDGET_SEC (default 30) seconds. Past either limit the call fails CLOSED: --scan refuses the
# text ("too large or too complex to scan", exit 3); --redact / --redact-file withhold the output and put a
# marker in its place (exit 3). The time budget is checked between regex calls (the rules run in time
# linear in the input, about 0.5 s per MiB), so it bounds a pathological input to roughly the budget.
WITHHELD = "[REDACTED: output withheld, too large or too complex to redact safely]\n"
TOO_COMPLEX = "too large or too complex to scan"


class LimitExceeded(Exception):
    """The input is over the size cap or the wall-clock budget."""


def _limits():
    def number(name, default):
        try:
            return float(os.environ.get(name) or default)
        except ValueError:
            return float(default)
    return number("SB_REDACT_MAX_BYTES", 16 * 1024 * 1024), number("SB_REDACT_BUDGET_SEC", 30)


def _guarded(func, text):
    max_bytes, budget = _limits()
    if len(text) > max_bytes:
        raise LimitExceeded()

    def on_alarm(_signum, _frame):
        raise LimitExceeded()

    previous = signal.signal(signal.SIGALRM, on_alarm)
    signal.setitimer(signal.ITIMER_REAL, budget)
    try:
        return func(text)
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


def redact_file(path):
    """Redact ``path`` in place, atomically, keeping its mode. Symlinks are refused. Over the limits the
    file is replaced by the withheld marker and LimitExceeded is raised afterwards (fail closed)."""
    if os.path.islink(path):
        raise OSError("refusing to redact through a symlink: %s" % path)
    if not os.path.isfile(path):
        return False
    limited = os.path.getsize(path) > _limits()[0]
    original = ""
    if not limited:
        with open(path, encoding="utf-8", errors="replace") as handle:
            original = handle.read()
        try:
            cleaned = _guarded(redact, original)
        except LimitExceeded:
            limited = True
    if limited:
        cleaned = WITHHELD
    elif cleaned == original:
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
    if limited:
        raise LimitExceeded()
    return True


def main(argv):
    if len(argv) == 2 and argv[1] == "--redact":
        try:
            sys.stdout.write(_guarded(redact, sys.stdin.read()))
        except LimitExceeded:
            sys.stdout.write(WITHHELD)
            return 3
        return 0
    if len(argv) == 3 and argv[1] == "--redact-file":
        try:
            redact_file(argv[2])
        except LimitExceeded:
            sys.stderr.write("ERROR: %s withheld (too large or too complex to redact safely)\n" % argv[2])
            return 3
        except OSError as exc:
            sys.stderr.write("ERROR: %s\n" % exc)
            return 2
        return 0
    if len(argv) == 2 and argv[1] == "--scan":
        try:
            found = _guarded(scan, sys.stdin.read())
        except LimitExceeded:
            sys.stdout.write(TOO_COMPLEX + "\n")
            return 3
        if found:
            sys.stdout.write("%s line %d\n" % found)
            return 1
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
