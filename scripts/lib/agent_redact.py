#!/usr/bin/env python3
"""Secret redaction and brief scanning for the /sb:agent-* delegation scripts (R4-31, R10b-06).

Usage:
  agent_redact.py --redact              stdin -> stdout with credentials replaced by [REDACTED]
  agent_redact.py --redact-file PATH    redact PATH in place (temp file + rename; refuses symlinks)
  agent_redact.py --scan                exit 1 (printing only the kind) when stdin holds a
                                        value-shaped credential; exit 0 otherwise

Matching is case-insensitive and value-shaped: well-known token prefixes, JWTs, PEM private
keys, "Bearer <token>" and KEY=value assignments. A bare keyword ("password: field" in a
feature description) is not a secret.
"""

import contextlib
import math
import os
import re
import sys
import tempfile

REDACTED = "[REDACTED]"

# Variable names that carry a secret: the keyword must END the name (so "tokens: 12" is left alone).
_NAME = (
    r"[A-Za-z0-9_.-]*(?:secret[_-]?access[_-]?key|secret[_-]?key|client[_-]?secret|secret|token|password|passwd|"
    r"api[_-]?key|access[_-]?key|private[_-]?key|credentials?)"
)
_VALUE = r"[^\s\"',;]+"

# (kind, compiled pattern, replacement) applied in order by redact().
_PREFIXED = [
    ("pem", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----.*?(?:-----END [A-Z ]*PRIVATE KEY-----|\Z)", re.S), REDACTED),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}"), REDACTED),
    ("github-pat", re.compile(r"\bgithub_pat_[A-Za-z0-9_]{20,}"), "github_pat_" + REDACTED),
    ("github", re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}"), "gh_" + REDACTED),
    ("gitlab", re.compile(r"\bglpat-[A-Za-z0-9_-]{20,}"), "glpat-" + REDACTED),
    ("slack", re.compile(r"\bxox[abprs]-[A-Za-z0-9-]{10,}"), "xox-" + REDACTED),
    ("aws", re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b"), REDACTED),
    ("google", re.compile(r"\bAIza[0-9A-Za-z_-]{35}"), REDACTED),
    ("slack-webhook", re.compile(r"https://hooks\.slack\.com/services/T[A-Za-z0-9]+/B[A-Za-z0-9]+/[A-Za-z0-9]+"), "https://hooks.slack.com/services/" + REDACTED),
    ("stripe", re.compile(r"\b[sr]k_(?:live|test)_[A-Za-z0-9]{10,}"), "sk_" + REDACTED),
    ("stripe-webhook", re.compile(r"\bwhsec_[A-Za-z0-9]{16,}"), "whsec_" + REDACTED),
    ("sk", re.compile(r"\bsk-[A-Za-z0-9_-]{8,}"), "sk-" + REDACTED),
    ("npm", re.compile(r"\bnpm_[A-Za-z0-9]{20,}"), "npm_" + REDACTED),
    ("huggingface", re.compile(r"\bhf_[A-Za-z0-9]{20,}"), "hf_" + REDACTED),
    ("url-userinfo", re.compile(r"(?<=://)[^\s/@:]+:[^\s/@]+(?=@)"), REDACTED),
]
_PASSWORD_FLAG = re.compile(r"(--(?:password|passwd|token|secret|api-key)(?:=|\s+))\S+", re.I)
_BEARER = re.compile(r"\b(bearer)(\s+)[A-Za-z0-9._~+/=-]{8,}", re.I)
_AUTH_HEADER = re.compile(r"\b(authorization)(\s*[:=]\s*)(?:(?:bearer|basic|token)\s+)?[^\s\"',;]+", re.I)
_ASSIGN = re.compile(r"\b(" + _NAME + r")([\"']?\s*[:=]\s*[\"']?)(" + _VALUE + ")", re.I)


def redact(text):
    """Return ``text`` with credentials replaced."""
    for _kind, pattern, replacement in _PREFIXED:
        text = pattern.sub(replacement, text)
    text = _PASSWORD_FLAG.sub(lambda m: m.group(1) + REDACTED, text)
    text = _AUTH_HEADER.sub(lambda m: m.group(1) + m.group(2) + REDACTED, text)
    text = _BEARER.sub(lambda m: m.group(1) + m.group(2) + REDACTED, text)
    return _ASSIGN.sub(lambda m: m.group(1) + m.group(2) + REDACTED, text)


def _entropy(value):
    counts = {}
    for char in value:
        counts[char] = counts.get(char, 0) + 1
    return -sum(n / len(value) * math.log2(n / len(value)) for n in counts.values())


_IDENT_CHAIN = re.compile(r"^[A-Za-z_$][A-Za-z0-9_$]*(?:(?:\.|::|->)[A-Za-z_$][A-Za-z0-9_$]*)+$")
_LOWER_SNAKE = re.compile(r"^[A-Za-z_][A-Za-z_]*$")
_UPPER_SNAKE = re.compile(r"^[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+$")
_PLAIN_WORD = re.compile(r"^[A-Za-z]+$")
_UUID = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
_ENV_REF = re.compile(r"^(?:process\.env|os\.environ|os\.getenv|getenv|ENV\[|settings\.|config\.|secrets\.|vault\.|\$\{|\$[A-Za-z_]|<|%\()", re.I)
_PEM_BLOCK = re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----[ \t]*\r?\n[ \t]*[A-Za-z0-9+/=]{16,}")
_USERINFO = re.compile(r"://([^\s/@:]+):([^\s/@]+)@")
_TRIVIAL_PASSWORDS = {"password", "passwd", "secret", "admin", "root", "test", "changeme", "example", "user", "pass"}


def _is_reference(value):
    """Placeholders and code references: nothing literal to leak."""
    return (
        value[0] in "<{$[(%"
        or value.lower().startswith(("xxxx", "your", "example", "changeme"))
        or "(" in value
        or ")" in value
        or bool(_ENV_REF.match(value))
    )


def _case_transition_rate(value):
    flips = sum(1 for a, b in zip(value, value[1:]) if a.islower() != b.islower())
    return flips / len(value)


def _looks_random(value, bearer=False):
    """A literal secret-shaped value: long, not a reference/placeholder/UUID/identifier, and
    random-looking. A Bearer token is never a code identifier, so only references are exempt there."""
    value = value.strip("\"'")
    if len(value) < 16 or _is_reference(value) or _UUID.match(value):
        return False
    entropy = _entropy(value)
    if bearer:
        return entropy >= 3.0
    has_digit = any(c.isdigit() for c in value)
    if not has_digit:
        if _IDENT_CHAIN.match(value) or (_LOWER_SNAKE.match(value) and "_" in value):
            return False
        if _PLAIN_WORD.match(value):
            # camelCase / PascalCase names read as identifiers; a letter run that flips case almost
            # every character, or a long high-entropy one, is a key
            return _case_transition_rate(value) >= 0.5 or (len(value) >= 24 and entropy >= 4.3)
    elif _UPPER_SNAKE.match(value):
        return False  # SCREAMING_SNAKE names (GOOGLE_CLIENT_SECRET_2) are identifiers
    return entropy >= 3.0


def _userinfo_secret(user, password):
    """A password in URL userinfo that is neither a reference, a trivial local default nor the user name."""
    return not (
        _is_reference(password)
        or password.lower() in _TRIVIAL_PASSWORDS
        or password == user
    )


def scan(text):
    """Return ``(kind, line_number)`` of the first literal credential in ``text``, or None."""
    block = _PEM_BLOCK.search(text)
    pem_line = text.count("\n", 0, block.start()) + 1 if block else None
    for number, line in enumerate(text.splitlines(), 1):
        if number == pem_line:
            return "pem", number
        for kind, pattern, _replacement in _PREFIXED:
            if kind in ("pem", "url-userinfo"):
                continue
            if pattern.search(line):
                return kind, number
        for match in _USERINFO.finditer(line):
            if _userinfo_secret(match.group(1), match.group(2)):
                return "url-userinfo", number
        for match in re.finditer(r"\b(?:bearer)\s+([A-Za-z0-9._~+/=-]{16,})", line, re.I):
            if _looks_random(match.group(1), bearer=True):
                return "bearer", number
        for match in _ASSIGN.finditer(line):
            if _looks_random(match.group(3)):
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
