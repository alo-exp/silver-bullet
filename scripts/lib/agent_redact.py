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

import math
import os
import re
import sys
import tempfile

REDACTED = "[REDACTED]"

# Variable names that carry a secret: the keyword must END the name (so "tokens: 12" is left alone).
_NAME = (
    r"[A-Za-z0-9_.-]*(?:secret[_-]?access[_-]?key|client[_-]?secret|secret|token|password|passwd|"
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
    ("sk", re.compile(r"\bsk-[A-Za-z0-9_-]{8,}"), "sk-" + REDACTED),
]
_BEARER = re.compile(r"\b(bearer)(\s+)[A-Za-z0-9._~+/=-]{8,}", re.I)
_AUTH_HEADER = re.compile(r"\b(authorization)(\s*[:=]\s*)(?:(?:bearer|basic|token)\s+)?[^\s\"',;]+", re.I)
_ASSIGN = re.compile(r"\b(" + _NAME + r")([\"']?\s*[:=]\s*[\"']?)(" + _VALUE + ")", re.I)


def redact(text):
    """Return ``text`` with credentials replaced."""
    for _kind, pattern, replacement in _PREFIXED:
        text = pattern.sub(replacement, text)
    text = _AUTH_HEADER.sub(lambda m: m.group(1) + m.group(2) + REDACTED, text)
    text = _BEARER.sub(lambda m: m.group(1) + m.group(2) + REDACTED, text)
    return _ASSIGN.sub(lambda m: m.group(1) + m.group(2) + REDACTED, text)


def _entropy(value):
    counts = {}
    for char in value:
        counts[char] = counts.get(char, 0) + 1
    return -sum(n / len(value) * math.log2(n / len(value)) for n in counts.values())


def _looks_random(value):
    """A secret-shaped assignment value: long, not a placeholder, and high entropy."""
    value = value.strip("\"'")
    if len(value) < 16:
        return False
    if value[0] in "<{$[(" or value.lower().startswith(("xxxx", "your", "example", "changeme")):
        return False
    return _entropy(value) >= 3.5


def scan(text):
    """Return the kind of the first value-shaped credential in ``text``, or None."""
    for kind, pattern, _replacement in _PREFIXED:
        if pattern.search(text):
            return kind
    for match in re.finditer(r"\b(?:bearer)\s+([A-Za-z0-9._~+/=-]{16,})", text, re.I):
        if _looks_random(match.group(1)):
            return "bearer"
    for match in _ASSIGN.finditer(text):
        if _looks_random(match.group(3)):
            return "assignment"
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
        if os.path.exists(tmp):
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
        kind = scan(sys.stdin.read())
        if kind:
            sys.stdout.write(kind + "\n")
            return 1
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
