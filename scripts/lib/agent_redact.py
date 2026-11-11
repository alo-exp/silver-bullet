#!/usr/bin/env python3
"""Secret redaction and brief scanning for the /sb:agent-* delegation scripts (R4-31, R10b-06).

Usage:
  agent_redact.py --redact              stdin -> stdout with credentials replaced by [REDACTED]
  agent_redact.py --redact-file PATH    redact PATH in place (temp file + rename; refuses symlinks)
  agent_redact.py --scan                exit 1 (printing "<rule> line <n>") when stdin holds a
                                        literal credential; exit 0 otherwise; exit 3 when the input is
                                        too large or too complex to scan

One linear-time pipeline serves all three modes. The text is split into lines; a line that is a JSON
object or array is decoded, every string in it is scanned and, only when something changed, the line is
re-serialized (so transcripts stay valid JSONL). Anchor passes (private-key blocks, vendor tokens, URL
userinfo, secret-named assignments, XML, command-line flags, netrc, bearer tokens) find candidate spans
with forward-only cursors and bounded windows; one classifier decides each span (refuse, mask or keep).
scan() reports the first refused span; redact() replaces every refused or masked span, so a refused value
is always also redacted. The rule tables (VENDOR, CLI, NAMES) are the coverage claim: adding a form is
adding a row, and tests/python/test_agent_redact.py runs every row on its own example.

Guarantee and limits: this is a best-effort layer, not a proof. Time is linear in the input (checked by
the ratio tests in the test suite). One call handles at most SB_REDACT_MAX_BYTES (default 16 MiB, bytes)
and runs at most SB_REDACT_BUDGET_SEC (default 60, clamped to (0, 600]; a non-number, zero, negative, nan
or inf means the default). Past a limit, or on any internal error, the call fails CLOSED: --scan refuses
the text, --redact and --redact-file withhold the output and leave a marker in its place (exit 3).
"""

import bisect
import collections
import contextlib
import json
import math
import os
import re
import signal
import sys
import tempfile
import time

REDACTED = "[REDACTED]"
NONE, POSSIBLE, SECRET = 0, 1, 2
NAME_MAX, VALUE_MAX, URL_MAX = 128, 1024, 2048

# ---------------------------------------------------------------- tables
CLS = {
    "A": "A-Za-z0-9", "W": "A-Za-z0-9_", "U": "A-Za-z0-9_-", "B": "A-Za-z0-9+/=", "H": "a-f0-9", "HX": "a-fA-F0-9",
    "D": "0-9", "UD": "A-Z0-9", "UE": "A-Za-z0-9_=-", "P": "A-Za-z0-9_.-", "LD": "a-z0-9",
}
# name, anchors, parts (class, min, max) with literal separators between, end_boundary, left (class,min,max)
VENDOR = [
    ("jwt", ("eyJ",), [("U", 8, 4096), ".", ("U", 8, 8192), ".", ("U", 8, 4096)], False, None),
    ("github-pat", ("github_pat_",), [("W", 20, 255)], False, None),
    ("github", ("ghp_", "gho_", "ghu_", "ghs_", "ghr_"), [("A", 20, 255)], False, None),
    ("gitlab", ("glpat-",), [("U", 20, 255)], False, None),
    ("slack", ("xoxa-", "xoxb-", "xoxp-", "xoxr-", "xoxs-"), [("A-", 10, 255)], False, None),
    ("slack-app", ("xapp-",), [("D", 1, 2), "-", ("A", 1, 64), "-", ("D", 1, 20), "-", ("A", 1, 255)], False, None),
    ("aws", ("AKIA", "ASIA"), [("UD", 16, 16)], True, None),
    ("google", ("AIza",), [("U", 35, 35)], False, None),
    ("google-oauth-secret", ("GOCSPX-",), [("U", 28, 28)], False, None),
    ("google-access-token", ("ya29.",), [("U", 50, 4096)], False, None),
    ("stripe", ("sk_live_", "sk_test_", "rk_live_", "rk_test_"), [("A", 10, 255)], False, None),
    ("stripe-webhook", ("whsec_",), [("A", 16, 255)], False, None),
    ("sk", ("sk-",), [("U", 8, 255)], False, None),
    ("sendgrid", ("SG.",), [("U", 22, 22), ".", ("U", 43, 43)], False, None),
    ("digitalocean", ("dop_v1_", "doo_v1_", "dor_v1_"), [("H", 64, 64)], False, None),
    ("pypi", ("pypi-AgEIcHlwaS5vcmc",), [("U", 50, 4096)], False, None),
    ("shopify", ("shpat_", "shpca_", "shppa_", "shpss_"), [("HX", 32, 32)], False, None),
    ("docker-pat", ("dckr_pat_",), [("U", 20, 255)], False, None),
    ("sentry", ("sntrys_", "sntryu_"), [("A", 40, 255)], False, None),
    ("linear", ("lin_api_",), [("A", 40, 40)], False, None),
    ("atlassian", ("ATATT",), [("UE", 50, 4096)], False, None),
    ("mailgun", ("key-",), [("H", 32, 32)], True, None),
    ("twilio", ("SK",), [("H", 32, 32)], True, None),
    ("npm", ("npm_",), [("A", 20, 255)], False, None),
    ("huggingface", ("hf_",), [("A", 20, 255)], False, None),
    ("groq", ("gsk_",), [("A", 40, 255)], False, None),
    ("netlify", ("nfp_",), [("A", 30, 255)], False, None),
    ("planetscale", ("pscale_tkn_", "pscale_pw_", "pscale_oauth_"), [("P", 30, 255)], False, None),
    ("render", ("rnd_",), [("A", 28, 255)], False, None),
    ("pat", ("pat_",), [("A", 36, 255)], False, None),
    ("airtable", ("pat",), [("A", 14, 14), ".", ("H", 64, 64)], False, None),
    ("xai", ("xai-",), [("A", 60, 255)], False, None),
    ("perplexity", ("pplx-",), [("A", 40, 255)], False, None),
    ("replicate", ("r8_",), [("A", 36, 255)], False, None),
    ("supabase", ("sbp_",), [("H", 40, 40)], False, None),
    ("circleci", ("CCIPAT_",), [("A", 20, 64), "_", ("H", 40, 40)], False, None),
    ("vault", ("hvs.", "hvb."), [("U", 24, 255)], False, None),
    ("telegram-bot", (":AA",), [("U", 33, 33)], True, ("D", 8, 10)),
    ("terraform-cloud", (".atlasv1.",), [("A", 60, 255)], False, ("LD", 14, 14)),
    ("slack-webhook", ("https://hooks.slack.com/services/T",), [("A", 6, 32), "/B", ("A", 6, 32), "/", ("A", 16, 64)], False, None),
]
CLS["A-"] = "A-Za-z0-9-"

# word-driven CLI table: program -> list of (flag, mode, tier). mode: next | attached | eq | either
P, T = "cli-pass", "cli-token"
CLI = {
    "mysql": [("-p", "attached", P), ("--password", "eq", P)],
    "mysqldump": [("-p", "attached", P), ("--password", "eq", P)],
    "mysqladmin": [("-p", "attached", P), ("--password", "eq", P)],
    "mariadb": [("-p", "attached", P), ("--password", "eq", P)],
    "docker": [("-p", "either", P), ("--password", "either", P)],
    "podman": [("-p", "either", P), ("--password", "either", P)],
    "sshpass": [("-p", "either", P)],
    "redis-cli": [("-a", "next", P), ("--pass", "next", P)],
    "az": [("-p", "either", P), ("--password", "either", P)],
    "keytool": [("-storepass", "next", P), ("-keypass", "next", P), ("-srcstorepass", "next", P), ("-deststorepass", "next", P)],
    "ldapsearch": [("-w", "next", P)], "ldapmodify": [("-w", "next", P)], "ldapadd": [("-w", "next", P)],
    "ldapdelete": [("-w", "next", P)], "ldapwhoami": [("-w", "next", P)], "ldappasswd": [("-w", "next", P), ("-s", "next", P)],
    "twine": [("-p", "next", P)], "mongosh": [("-p", "next", P)], "mongo": [("-p", "next", P)],
    "doctl": [("-t", "next", T), ("--access-token", "either", T)],
    "kubeadm": [("--token", "either", T)],
    "*": [("--password", "either", P), ("--passwd", "either", P), ("--token", "either", T), ("--secret", "either", T),
          ("--api-key", "either", T), ("--apikey", "either", T), ("--access-token", "either", T), ("--auth-token", "either", T),
          ("--client-secret", "either", T), ("--http-password", "either", P), ("--ftp-password", "either", P)],
}
USERPASS_FLAGS = {"--user", "--proxy-user"}
USERPASS_SHORT = {"curl", "wget", "http", "https", "httpie"}  # curl / wget style user:pass
POSITIONAL = {  # (program, subcommand words) -> (index of name arg or None, index of value arg)
    ("aws", "configure", "set"): "name-value",
    ("poetry", "config"): "http-basic",
    ("htpasswd",): "htpasswd",
}
STDIN_SECRET_FLAGS = {"--password-stdin", "--with-token"}
SCHEMES = {"bearer", "basic", "token", "digest", "bot", "apikey", "sso-key"}

STRONG_WORDS = {"password", "passwd", "pass", "pwd", "passphrase", "passcode"}
CRED_WORDS = {"secret", "token", "credential", "credentials", "apikey", "dsn"}
WEAK_WORDS = {"sig", "signature"}
KEY_QUALIFIERS = {"api", "access", "secret", "private", "signing", "encryption", "auth", "license", "account", "master",
                  "app", "client", "shared", "storage", "service", "role", "subscription", "consumer", "webhook",
                  "deploy", "publish", "admin", "sendgrid", "stripe", "mailgun", "x"}
ID_NAMES = re.compile(r"csrf|xsrf|session|request|trace|correlation|tracking|idempotency|nonce|state|device|visitor|tenant|upload|order", re.I)

# ---------------------------------------------------------------- helpers
_NAME_WORDS = re.compile(r"[A-Z]{2,}(?![a-z])|[A-Z]?[a-z]+|[A-Z]|[0-9]+|[㐀-鿿]+")
_NAME_CHAR = re.compile(r"[A-Za-z0-9_.\-㐀-鿿]")


def name_tier(name):
    if not name or len(name) > NAME_MAX:
        return None
    if re.search("密码|口令", name):
        return "strong"
    if re.search("密钥|令牌", name):
        return "cred"
    words = [w.lower() for w in _NAME_WORDS.findall(name)]
    if not words:
        return None
    low = name.lower().strip("-_.")
    if low in ("authorization", "proxy-authorization"):
        return "auth-header"
    last = words[-1]
    prev = words[-2] if len(words) > 1 else ""
    if last in STRONG_WORDS or (last.endswith(("password", "passwd", "pass", "pwd")) and name.isupper()):
        return "strong"
    if last == "auth" and (len(words) == 1 or name.startswith("_")):
        return "cred"
    if last in CRED_WORDS:
        return "cred"
    if last == "key":
        if prev == "key" or prev in KEY_QUALIFIERS:
            return "cred"
        return "weak"
    if last == "base" and words[-3:-1] == ["secret", "key"]:
        return "cred"
    if last in WEAK_WORDS:
        return "weak"
    return None


def entropy(v):
    n = len(v)
    return -sum(c / n * math.log2(c / n) for c in collections.Counter(v).values())


_REF = re.compile(r"^(?:\$\{|\$\(|\$[A-Za-z_]|\{\{|<[^>]*>$|%\(|#\{|\[REDACTED|process\.env|os\.environ|os\.getenv|getenv|ENV\[|"
                  r"vault:|op://|arn:|ssm:|file:|env:|secret:|kms:|!vault|secrets\.)", re.I)
_REF_WHOLE = re.compile(r"^(?:\$\{\{[^{}]{1,200}\}\}|\$\{[^{}]{1,200}\}|\$\([^()]{1,200}\)|\$[A-Za-z_]\w*|\{\{[^{}]{1,200}\}\}|"
                        r"\{[^{}]{1,200}\}|<[^<>]{1,100}>|%\([A-Za-z_]\w*\)s|#\{[^{}]{1,200}\}|\[REDACTED[^\]]*\])(?:[/:.\-_@][\w./:@\-]*)?$")


def is_reference(v):
    """The WHOLE value is a reference (variable, template, placeholder, env accessor), never a prefix test."""
    return bool(_REF_WHOLE.match(v) or v.startswith(("$(", "${", "`")) or re.fullmatch(r"\$(?:\d|[@*#?!])(?:[/:.\-_@][\w./:@\-]*)?", v)
                or (_REF.match(v) and not v.startswith(("$", "{", "<", "%", "#"))))


_DUMMY = re.compile(r"dummy|fake|placeholder|replace[-_ ]?me|change[-_ ]?me|not[-_]a[-_]real|example|sample|redacted|x{4,}|"
                    r"^test[-_]|[-_]test$|for[-_]tests?|^your[-_]|[-_]your[-_]|^\*+$|\.\.\.|\u2026", re.I)
_UUID = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
_HUMPS = re.compile(r"[A-Z]{2,}(?![a-z])|[A-Z]?[a-z]+|[A-Z]|[0-9]+")
_SEG_SPLIT = re.compile(r"(?:\.|::|->|[_\-:#@/])+")
_VOWEL = set("aeiouyAEIOUY")
_CONS_RUN = re.compile(r"[^aeiouyAEIOUY0-9]{6,}")
_CALL = re.compile(r"^(?:new |await )?[A-Za-z_$][\w$]*(?:(?:\.|::|->)[A-Za-z_$][\w$]*)*\((?P<args>[^()]*)\)(?:\.[A-Za-z_]\w*(?:\([^()]*\))?)*$")


def word_segment(seg):
    """A segment of an identifier: dictionary-like humps, small numbers, or short tokens."""
    if not seg or (seg.isdigit() and len(seg) <= 4):
        return True
    if len(seg) <= 3:
        return True
    humps = _HUMPS.findall(seg)
    if "".join(humps) != seg:
        return False
    letters = [h for h in humps if not h.isdigit()]
    nums = [h for h in humps if h.isdigit()]
    if not letters or len(nums) > 2 or any(len(h) > 4 for h in nums):
        return False
    if sum(len(h) for h in letters) / len(letters) < 3 or sum(1 for h in letters if len(h) == 1) * 4 > len(letters) + 1:
        return False
    for h in letters:
        if len(h) > 14:
            return False
        if len(h) >= 4 and (not (_VOWEL & set(h)) or _CONS_RUN.search(h)):
            if not (h.isupper() and len(h) <= 6):
                return False
    return True


def is_ident(v):
    segs = [s for s in _SEG_SPLIT.split(v) if s]
    if not segs or not re.fullmatch(r"[A-Za-z0-9_.:\-#@/$>]+", v):
        return False
    if not all(word_segment(s) for s in segs):
        return False
    words = sum(1 for s in segs if any(len(h) >= 3 and not h.isdigit() for h in _HUMPS.findall(s)))
    return words * 2 >= len(segs)


def is_path(v):
    if not ("/" in v or v.startswith("~")):
        return False
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*://", v):
        return False
    body = v.lstrip("~./")
    segs = [s for s in re.split(r"[/]", body) if s]
    return len(segs) >= 1 and (v[0] in "/~." or len(segs) >= 2) and all(
        all(word_segment(x) for x in re.split(r"[._-]+", re.sub(r"\.[A-Za-z0-9]{1,5}$", "", s)) if x) for s in segs)


_CALL_HEAD = re.compile(r"^(?:new |await )?([A-Za-z_$][\w$]*(?:(?:\.|::|->)[A-Za-z_$][\w$]*)*)\((.*)$")


def is_code(v):
    """A call (identifier chain + '(' + identifier/number arguments, possibly cut at a quote) or an attribute chain."""
    m = _CALL_HEAD.match(v)
    if m:
        head, args = m.group(1), m.group(2)
        if not is_ident(head.replace("::", ".").replace("->", ".")) and not re.fullmatch(r"[a-z_][a-z0-9_]{1,30}", head):
            return False
        args = re.sub(r"\)[\w.()]*$", "", args)
        return all(is_ident(a) or a.isdigit() for a in re.split(r"[\s,=*]+", args) if a)
    if re.fullmatch(r"[A-Za-z_$][\w$]*(?:(?:\.|::|->)[A-Za-z_$][\w$]*)+", v):
        return is_ident(v)
    return False


def unwrap(v):
    v = v.strip()
    while len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'`":
        v = v[1:-1]
    v = v.strip("\"'`")
    v = v.rstrip(",;")
    if len(v) >= 2 and v[0] + v[-1] in ("[]", "()", "{}") and not v.startswith("${"):
        v = v[1:-1]
    while v and v[-1] in ")]}" and v.count({")": "(", "]": "[", "}": "{"}[v[-1]]) < v.count(v[-1]):
        v = v[:-1]
    return v


def classify(value, tier, name=""):
    v = unwrap(value)
    if not v:
        return NONE
    if is_reference(v):
        return NONE
    if _DUMMY.search(v):
        return NONE
    if tier == "bearer":
        if len(v) < 8 or re.fullmatch(r"[a-z]+", v) or entropy(v) < 2.5:
            return NONE
        return SECRET
    if _UUID.match(v):
        if tier in ("cred", "strong") and not ID_NAMES.search(name):
            return SECRET
        return NONE
    if is_path(v):
        return NONE
    nested = re.fullmatch(r"([A-Za-z_][\w.-]{0,63})=([\w.:/-]{0,64})", v)
    if nested and is_ident(nested.group(1)) and (not nested.group(2) or nested.group(2).isdigit() or is_ident(nested.group(2))):
        return NONE  # NAME=simple: an inner assignment, judged by its own anchor
    if ( re.match(r"^--[a-z][a-z0-9-]*(?:=|$)", v) or re.search(r"\{[A-Za-z_]\w*\}|\$\{|%\([A-Za-z_]\w*\)[sd]|\{\}", v) or re.fullmatch(r"\d{4}-\d\d-\d\d[T ][\d:.]+Z?", v)
            or re.fullmatch(r"[\w-]+(?:\.[\w-]+)*\.(?:sh|py|js|ts|md|json|ya?ml|toml|txt|pem|key|crt|env|conf|cfg|ini|log)", v)):
        return NONE  # a nested NAME=value, a flag, a format template or a file name: not itself a literal secret
    if re.search(r"\s", v):
        return POSSIBLE if tier in ("strong", "cred", "cli-pass", "cli-token") else NONE  # a phrase, not a token
    possible = POSSIBLE if tier in ("strong", "cred", "cli-pass", "cli-token") else NONE
    if is_code(v):
        return possible
    if tier in ("strong", "cli-pass"):
        if is_ident(v):
            single = not _SEG_SPLIT.search(v)
            if single and any(c.isdigit() for c in v) and len(v) >= 8:
                return SECRET
            return possible
        if v.isdigit():
            return possible
        return SECRET if len(v) >= (6 if tier == "cli-pass" else 8) else possible
    if is_ident(v):
        return possible
    e = entropy(v)
    has_d = any(c.isdigit() for c in v)
    if tier in ("cred", "cli-token"):
        if re.fullmatch(r"[0-9a-fA-F]{16,}", v):
            return SECRET
        if len(v) >= 16 and e >= 3.0:
            return SECRET
        if len(v) >= 12 and e >= 3.0 and sum(bool(re.search(p, v)) for p in ("[a-z]", "[A-Z]", "[0-9]", "[^A-Za-z0-9]")) >= 3:
            return SECRET
        return possible
    # tier "weak" (cache_key, sig): only hashes and long random values
    if re.fullmatch(r"[0-9a-f]{32,}", v):
        return SECRET
    if re.fullmatch(r"[A-Za-z][A-Za-z0-9_.-]*[-_:][0-9a-f]{7,}", v) and is_ident(re.sub(r"[-_:][0-9a-f]{7,}$", "", v)):
        return NONE  # word-prefixed digest (cache keys)
    if len(v) >= 20 and e >= 3.3 and (has_d or not v.islower()):
        return SECRET
    return NONE


TRIVIAL = {"password", "passwd", "secret", "admin", "root", "test", "changeme", "example", "user", "pass", "postgres", "mysql", "guest", "app", "dev"}
LOCAL_HOST = re.compile(r"^(?:localhost|127\.0\.0\.1|\[?::1\]?|0\.0\.0\.0|[A-Za-z0-9_-]+|[A-Za-z0-9.-]*\.(?:localhost|local))$", re.I)


# ---------------------------------------------------------------- passes (each appends (start, end, rule, verdict))
def _compile_vendor():
    anchors = {}
    for rule in VENDOR:
        name, prefs, parts, endb, left = rule
        rx = ""
        for p in parts:
            rx += re.escape(p) if isinstance(p, str) else "[%s]{%d,%d}" % (CLS[p[0]], p[1], p[2])
        if endb:
            rx += "(?![A-Za-z0-9_])"
        first = parts[0]
        comp = (name, re.compile(rx), re.compile("[%s]*" % CLS[first[0]]), first[2], left)
        for a in prefs:
            anchors.setdefault(a, []).append(comp)
    alts = sorted(anchors, key=len, reverse=True)
    return anchors, re.compile("|".join(re.escape(a) for a in alts))


_ANCH, _ANCH_RE = _compile_vendor()
_WORD_BOUND = re.compile(r"[A-Za-z0-9_]")


def pass_vendor(text, out):
    memo = {}
    for m in _ANCH_RE.finditer(text):
        _tick()
        a, s = m.group(0), m.start()
        for name, rx, first_run, fmax, left in _ANCH[a]:
            if s < memo.get(name, -1):
                continue
            start = s
            if left:
                cls = re.compile("[%s]" % CLS[left[0]])
                i = s
                while i > 0 and s - i < left[2] and cls.match(text[i - 1]):
                    i -= 1
                if s - i < left[1] or (i > 0 and _WORD_BOUND.match(text[i - 1])):
                    continue
                start = i
            elif s > 0 and _WORD_BOUND.match(text[s - 1]) and not a.startswith(("http", ":", ".")):
                continue
            hit = rx.match(text, m.end())
            if hit:
                memo[name] = hit.end()
                body = text[m.end():hit.end()]
                if not placeholder_token(name, body):
                    out.append((start, hit.end(), name, SECRET))
                break
            memo[name] = first_run.match(text, m.end(), min(len(text), m.end() + fmax + 1)).end()


def placeholder_token(name, body):
    return (body.endswith("EXAMPLE") or body.lower().startswith(("your", "example", "placeholder"))
            or (len(body) >= 8 and entropy(body) < 2.0))


_DISCORD = re.compile(r"[A-Za-z0-9_.-]{59,90}")


def pass_shapes(text, out):
    for m in _DISCORD.finditer(text):
        _tick()
        w = m.group(0)
        p = w.split(".")
        if len(p) == 3 and len(p[0]) == 24 and len(p[1]) == 6 and 27 <= len(p[2]) <= 38 and any(c.isdigit() for c in w):
            out.append((m.start(), m.end(), "discord-bot", SECRET))


def pass_pem(text, out):
    pos = 0
    while True:
        _tick()
        b = text.find("-----BEGIN ", pos)
        if b < 0:
            return
        eol = text.find("-----", b + 11, b + 80)
        label = text[b + 11:eol] if eol > 0 else ""
        if eol < 0 or "PRIVATE KEY" not in label:
            pos = b + 11
            continue
        end = text.find("-----END ", eol + 5)
        stop = len(text) if end < 0 else text.find("-----", end + 9, end + 90) + 5
        if stop < 5:
            stop = len(text)
        body = text[eol + 5:min(stop, eol + 5 + 4096)].replace("\\n", "\n").replace("\r", "")
        verdict = SECRET if re.search(r"(?m)^[ \t]*[A-Za-z0-9+/=]{16,}[ \t]*$", body) else POSSIBLE
        out.append((b, stop, "pem", verdict))
        pos = stop


_HOST = re.compile(r"[A-Za-z0-9.-]*[A-Za-z0-9](?::\d+)?")
_AUTH_STOP = set(" \t\r\n\"'`<>()[]{}\\,;|/")


def pass_url(text, out):
    pos = 0
    n = len(text)
    while True:
        _tick()
        k = text.find("://", pos)
        if k < 0:
            return
        i = k
        while i > 0 and k - i < 32 and (text[i - 1].isalnum() or text[i - 1] in "+.-"):
            i -= 1
        j = k + 3
        lim = min(n, j + URL_MAX)
        while j < lim and text[j] not in _AUTH_STOP:
            j += 1
        auth = text[k + 3:j]
        pos = max(j, k + 3)
        at = auth.rfind("@")
        if at <= 0 or i == k:
            continue
        host_m = _HOST.match(auth, at + 1)
        if not host_m or host_m.end() == at + 1:
            continue
        host = auth[at + 1:host_m.end()].split(":")[0]
        userinfo = auth[:at]
        s0 = k + 3
        if ":" in userinfo:
            user, pw = userinfo.split(":", 1)
            ps = s0 + len(user) + 1
            if not pw or is_reference(pw) or _DUMMY.search(pw):
                v = NONE
            elif LOCAL_HOST.match(host) and (pw.lower() in TRIVIAL or pw == user):
                v = NONE
            else:
                v = SECRET
            out.append((ps, s0 + at, "url-userinfo", v))
        else:
            if re.fullmatch(r"[0-9a-f]{32,}", userinfo):
                out.append((s0, s0 + at, "url-token-user", SECRET))


_REF_SCHEMES = ("arn:", "vault:", "op://", "ssm:", "kms:", "secret:", "env:")
_SEP = re.compile(r"=>|:=|[=:：＝]|%3[dD]")
_STOP_UNQ = set(" \t\r\n\"'`,;&|<>[]{}\\")
_QPARAM = re.compile(r"&[A-Za-z_][\w.-]{0,63}=")
_SEP_CHARS = set("=:：＝%")


def _value_at(text, j, ticks=None):
    """Return (vstart, vend) of the value starting at j (after separator and blanks). ``ticks`` (sorted backtick
    positions) says whether j is inside a Markdown code span: then a backtick closes the span and ends the value."""
    n = len(text)
    inside = ticks is not None and bisect.bisect_left(ticks, j) % 2 == 1
    while j < n and text[j] in " \t*":
        j += 1
    if j < n and text[j] == "f" and j + 1 < n and text[j + 1] in "\"'":
        j += 1
    esc = j + 1 < n and text[j] == "\\" and text[j + 1] in "\"'"
    if esc:
        j += 1
    if j < n and (text[j] in "\"'" or (text[j] == "`" and not inside)):
        q = ("\\" if esc else "") + text[j]
        close = text.find(q, j + 1, min(n, j + 1 + VALUE_MAX))
        if close > j:
            return j + 1, close
        j += 1
    e = j
    lim = min(n, j + VALUE_MAX)
    while e < lim:
        c = text[e]
        if c in _STOP_UNQ and (c != "&" or _QPARAM.match(text, e) or e + 1 >= n or text[e + 1] in " \t\n&"):
            break
        e += 1
    return j, e


_KEY_ANCHOR = re.compile(r"(?i)(?:password|passwd|pass|pwd|passphrase|passcode|secret|token|credentials?|key|auth|"
                         r"authorization|dsn|sig|signature|base|密码|口令|密钥|令牌)[\"'`\\* \t]{0,4}(?:=>|:=|[=:：＝]|%3[dD])")


def pass_assign(text, out):
    consumed = 0
    ticks = [m.start() for m in re.finditer("`", text)] if "`" in text else None
    for m in _KEY_ANCHOR.finditer(text):
        _tick()
        p = m.start()
        if p < consumed:
            continue
        sep = _SEP.search(text, p, m.end())
        j = sep.start()
        while j > p and text[j - 1] in " \t\"'`\\*":
            j -= 1
        i = j
        lim = max(0, j - NAME_MAX)
        while i > lim and _NAME_CHAR.match(text[i - 1]):
            i -= 1
        name = text[i:j]
        tier = name_tier(name)
        if tier is None:
            continue
        vs, ve = _value_at(text, sep.end(), ticks)
        if ve <= vs:
            continue
        if tier == "auth-header":
            word = text[vs:ve]
            parts = word.split(None, 1)
            if len(parts) == 2 and parts[0].lower() in SCHEMES:
                vs = vs + word.index(parts[1])
            elif word.lower() in SCHEMES:
                vs, ve = _value_at(text, ve)
            v = classify(text[vs:ve], "bearer")
            out.append((vs, ve, "authorization", v if v else POSSIBLE))
        else:
            out.append((vs, ve, "assignment", classify(text[vs:ve], tier, name)))
        consumed = ve


_XML = re.compile(r"<([A-Za-z_][\w.:-]{0,63})>")
_XML_ATTR = re.compile(r"key=\"([^\"<>]{1,128})\"[ \t]+value=\"")


def pass_xml(text, out):
    for m in _XML.finditer(text):
        _tick()
        tier = name_tier(m.group(1))
        if tier is None:
            continue
        e = text.find("<", m.end(), min(len(text), m.end() + VALUE_MAX))
        if e > m.end() and text.startswith("</" + m.group(1), e):
            out.append((m.end(), e, "xml-element", classify(text[m.end():e], tier, m.group(1))))
    for m in _XML_ATTR.finditer(text):
        _tick()
        tier = name_tier(m.group(1))
        if tier is None:
            continue
        e = text.find('"', m.end(), min(len(text), m.end() + VALUE_MAX))
        if e > m.end():
            out.append((m.end(), e, "xml-attribute", classify(text[m.end():e], tier, m.group(1))))


_WORD = re.compile(r"[^\s`'\"|;&()<>]+|'[^'\n]{0,1024}'|\"[^\"\n]{0,1024}\"|[|;&]+|\n")
_BEARER = re.compile(r"(?i)(?<![A-Za-z0-9_])bearer[ \t]+")
_EXTRA_PROGS = ("aws", "poetry", "htpasswd", "curl", "wget", "gh", "convertto-securestring")
_PROGS = set(CLI) - {"*"} | set(_EXTRA_PROGS)
FLAGS = {prog: {f: (mode, tier) for f, mode, tier in rows} for prog, rows in CLI.items()}
ATTACHED = {prog: {f: tier for f, mode, tier in rows if mode in ("attached", "either") and len(f) == 2} for prog, rows in CLI.items()}
GFLAGS = FLAGS["*"]
_ANCHOR_WORDS = sorted(_PROGS | set(GFLAGS) | USERPASS_FLAGS | STDIN_SECRET_FLAGS | {"echo", "printf"}, key=len, reverse=True)
_CLI_ANCHOR = re.compile(r"(?i)(?<![\w.\-])(?:[\w.\-]*/)?(?:%s)(?![\w\-])" % "|".join(map(re.escape, _ANCHOR_WORDS)))
_NETRC_ANCHOR = re.compile(r"(?i)(?<![\w\-])(?:login|machine)(?![\w\-])")
MAX_CMD = 4096


def _lex_command(text, p, end, out):
    prog, pending, args = None, None, []
    prev_echo = seg_echo = None
    for m in _WORD.finditer(text, p, end):
        w = m.group(0)
        if w[0] in "|;&":
            prev_echo = seg_echo if w[0] == "|" else None
            seg_echo, prog, pending, args = None, None, None, []
            continue
        ws, we = m.start(), m.end()
        if w[0] in "'\"" and len(w) >= 2:
            ws, we, w = ws + 1, we - 1, w[1:-1]
        if pending:
            tier, rule = pending
            pending = None
            if tier == "userpass":
                c = w.find(":")
                if c >= 0 and c + 1 < len(w):
                    out.append((ws + c + 1, we, rule, classify(w[c + 1:], "cli-pass")))
            else:
                out.append((ws, we, rule, classify(w, tier)))
            continue
        low = w.lower()
        if seg_echo == "await":
            seg_echo = (ws, we, w)
            continue
        if low in ("echo", "printf"):
            seg_echo = "await"
            continue
        if low in STDIN_SECRET_FLAGS and isinstance(prev_echo, tuple):
            s0, e0, lit = prev_echo
            out.append((s0, e0, "stdin-secret", classify(lit, "cli-pass")))
            continue
        base = low.rsplit("/", 1)[-1]
        if base in _PROGS:
            prog, args = base, []
            continue
        if w in USERPASS_FLAGS or (w == "-u" and prog in USERPASS_SHORT):
            pending = ("userpass", "cli-user")
            continue
        flags = FLAGS.get(prog, {})
        hit = flags.get(w) or GFLAGS.get(w)
        if hit and hit[0] in ("next", "either"):
            pending = (hit[1], "cli-%s" % (prog or "flag"))
            continue
        if "=" in w and w.startswith("-"):
            f, val = w.split("=", 1)
            hit = flags.get(f) or GFLAGS.get(f)
            if hit and hit[0] in ("eq", "either") and val:
                out.append((ws + len(f) + 1, we, "cli-%s" % (prog or "flag"), classify(val, hit[1])))
                continue
        att = ATTACHED.get(prog, {}).get(w[:2])
        if att and len(w) > 2 and w[2] not in "-=":
            out.append((ws + 2, we, "cli-" + prog, classify(w[2:], att)))
            continue
        if prog is None:
            continue
        args.append(w)
        if prog == "convertto-securestring" and len(args) == 1:
            out.append((ws, we, "powershell-secure", classify(w, "cli-pass")))
        elif prog == "aws" and args[:2] == ["configure", "set"] and len(args) == 4 and name_tier(args[2]):
            out.append((ws, we, "cli-aws", classify(w, name_tier(args[2]), args[2])))
        elif prog == "poetry" and len(args) == 4 and args[0] == "config" and args[1].startswith("http-basic."):
            out.append((ws, we, "cli-poetry", classify(w, "cli-pass")))
        elif prog == "poetry" and len(args) == 3 and args[0] == "config" and args[1].startswith("pypi-token."):
            out.append((ws, we, "cli-poetry", classify(w, "cli-token")))
        elif prog == "htpasswd" and args and args[0].startswith("-") and "b" in args[0]:
            pos = [a for a in args[1:] if not a.startswith("-")]
            if len(pos) == 3:
                out.append((ws, we, "cli-htpasswd", classify(w, "cli-pass")))


def pass_words(text, out):
    """Anchor-driven: a program name / secret flag / echo starts the shell-word lexer for the rest of the line
    (bounded by MAX_CMD); anchors inside an already lexed region are skipped, so each character is lexed once."""
    consumed = 0
    n = len(text)
    for a in _CLI_ANCHOR.finditer(text):
        _tick()
        p = a.start()
        if p < consumed:
            continue
        eol = text.find("\n", p, p + MAX_CMD)
        end = eol if eol >= 0 else min(n, p + MAX_CMD)
        _lex_command(text, p, end, out)
        consumed = end
    consumed = 0
    for a in _NETRC_ANCHOR.finditer(text):
        _tick()
        if a.start() < consumed:
            continue
        words = []
        for m in _WORD.finditer(text, a.start(), min(n, a.start() + 512)):
            if m.group(0) != "\n":
                words.append(m)
            if len(words) >= 6:
                break
        for i, m in enumerate(words[:-1]):
            if m.group(0).lower() in ("password", "passwd"):
                v = words[i + 1]
                out.append((v.start(), v.end(), "netrc", classify(v.group(0), "cli-pass")))
                break
        consumed = words[-1].end() if words else a.end()
    for m in _BEARER.finditer(text):
        _tick()
        vs, ve = _value_at(text, m.end())
        if ve > vs:
            out.append((vs, ve, "bearer", classify(text[vs:ve], "bearer")))


PASSES = (pass_pem, pass_vendor, pass_shapes, pass_url, pass_assign, pass_xml, pass_words)


_OPAQUE = re.compile(r"(?i)(?<![\w.-])(?:arn:aws|arn:aws-[a-z-]+|vault:|op://|ssm:|kms:)")


def _opaque_spans(text):
    """Reference URIs (ARNs, vault:/op:// references) are opaque: no candidate may start inside one."""
    spans = []
    for m in _OPAQUE.finditer(text):
        _tick()
        if spans and m.start() < spans[-1][1]:
            continue
        e = m.end()
        lim = min(len(text), e + VALUE_MAX)
        while e < lim and text[e] not in _STOP_UNQ:
            e += 1
        spans.append((m.start(), e))
    return spans


# Text-facing patterns, linted by the test suite: no nested or lazy repeats and no back-references.
_PATTERNS = (_ANCH_RE, _DISCORD, _KEY_ANCHOR, _XML, _XML_ATTR, _WORD, _BEARER, _CLI_ANCHOR, _NETRC_ANCHOR, _OPAQUE,
             _QPARAM, _HOST, _SEP)


def candidates(text):
    out = []
    for p in PASSES:
        p(text, out)
    spans = _opaque_spans(text)
    if spans:
        starts = [s0 for s0, _ in spans]
        keep = []
        for c in out:
            k = bisect.bisect_right(starts, c[0]) - 1
            if k >= 0 and spans[k][0] <= c[0] < spans[k][1]:
                continue
            keep.append(c)
        out = keep
    return out


# ---------------------------------------------------------------- JSONL + driver
def _walk_json(obj, base_line, finds):
    """Return (new_obj, changed). Every string is scanned as text; every (key, str) pair is an assignment."""
    stack_changed = [False]

    def fix(v, key=None):
        if isinstance(v, dict):
            return {k: fix(x, k) for k, x in v.items()}
        if isinstance(v, list):
            return [fix(x) for x in v]
        if isinstance(v, str):
            cands = candidates(v)
            tier = name_tier(key) if key else None
            if tier and tier != "auth-header":
                cands.append((0, len(v), "json-field", classify(v, tier, key)))
            elif tier == "auth-header":
                pass  # text pass sees "Bearer x" via bearer rule
            for s, e, rule, verdict in cands:
                if verdict == SECRET:
                    finds.append((rule, base_line))
            new = apply(v, cands)
            if new != v:
                stack_changed[0] = True
            return new
        if isinstance(v, (int, float)) and not isinstance(v, bool) and key and name_tier(key) == "strong" and len(str(v)) >= 8:
            finds.append(("json-field", base_line))
            stack_changed[0] = True
            return REDACTED
        return v
    new = fix(obj)
    return new, stack_changed[0]


def apply(text, cands):
    spans = sorted((s, e) for s, e, _r, v in cands if v >= POSSIBLE and e > s)
    if not spans:
        return text
    outp, last = [], 0
    for s, e in spans:
        if e <= last:
            continue
        s = max(s, last)
        outp.append(text[last:s])
        outp.append(REDACTED)
        last = e
    outp.append(text[last:])
    return "".join(outp)


def analyze(text):
    """Return (findings [(rule, line)], redacted_text)."""
    lines = text.split("\n")
    finds = []
    out_lines = []
    chunk, chunk_start = [], 0

    def flush():
        if not chunk:
            return
        t = "\n".join(chunk)
        cands = candidates(t)
        nl = [mm.start() for mm in re.finditer("\n", t)]
        for s, e, rule, verdict in cands:
            if verdict == SECRET:
                finds.append((rule, chunk_start + bisect.bisect_left(nl, s) + 1))
        out_lines.extend(apply(t, cands).split("\n"))
        chunk.clear()

    for n, line in enumerate(lines):
        _tick()
        st = line.lstrip()
        obj = None
        if st[:1] in ("{", "["):
            try:
                obj = json.loads(line)
            except (ValueError, RecursionError):
                obj = None
        if isinstance(obj, (dict, list)):
            flush()
            try:
                new, changed = _walk_json(obj, n + 1, finds)
            except RecursionError:
                obj = None
        if isinstance(obj, (dict, list)):
            compact = '": ' not in line and '", ' not in line
            out_lines.append(json.dumps(new, ensure_ascii=False, separators=(",", ":") if compact else (", ", ": ")) if changed else line)
            chunk_start = n + 1
            continue
        if not chunk:
            chunk_start = n
        chunk.append(line)
    flush()
    return finds, "\n".join(out_lines)


def scan(text):
    finds, _ = analyze(text)
    if not finds:
        return None
    return min(finds, key=lambda f: f[1])


def redact(text):
    return analyze(text)[1]


# ---------------------------------------------------------------- limits (fail closed)
WITHHELD = "[REDACTED: output withheld, too large or too complex to redact safely]\n"
TOO_COMPLEX = "too large or too complex to scan"
DEFAULT_BUDGET, MAX_BUDGET, DEFAULT_BYTES = 60.0, 600.0, 16 * 1024 * 1024


class LimitExceeded(Exception):
    """The input is over the size cap or the wall-clock budget."""


class Deadline:
    """Cooperative wall-clock budget, checked every 256 anchors by the passes (see _tick)."""

    def __init__(self, seconds):
        self.end = time.monotonic() + seconds
        self.count = 0

    def tick(self):
        self.count += 1
        if not self.count & 255 and time.monotonic() > self.end:
            raise LimitExceeded()


_DEADLINE = None


def _tick():
    if _DEADLINE is not None:
        _DEADLINE.tick()


def _limits():
    """(max_bytes, budget_seconds) from the environment, with junk values falling back to the defaults."""
    try:
        max_bytes = int(float(os.environ.get("SB_REDACT_MAX_BYTES") or DEFAULT_BYTES))
    except (ValueError, OverflowError):
        max_bytes = DEFAULT_BYTES
    if max_bytes <= 0:
        max_bytes = DEFAULT_BYTES
    try:
        budget = float(os.environ.get("SB_REDACT_BUDGET_SEC") or DEFAULT_BUDGET)
    except ValueError:
        budget = DEFAULT_BUDGET
    if not 0 < budget < math.inf:  # also false for nan
        budget = DEFAULT_BUDGET
    return max_bytes, min(budget, MAX_BUDGET)


def _guarded(func, text):
    """Run func(text) under the deadline (cooperative, plus a SIGALRM backstop in the main thread)."""
    global _DEADLINE
    max_bytes, budget = _limits()
    if len(text.encode("utf-8", "surrogateescape")) > max_bytes:
        raise LimitExceeded()
    _DEADLINE = Deadline(budget)
    previous = None
    try:
        previous = signal.signal(signal.SIGALRM, lambda _signum, _frame: (_ for _ in ()).throw(LimitExceeded()))
        signal.setitimer(signal.ITIMER_REAL, budget + 5)
    except ValueError:  # not the main thread: the cooperative deadline still applies
        previous = None
    try:
        return func(text)
    finally:
        _DEADLINE = None
        if previous is not None:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous)


def _decode(data):
    return data.decode("utf-8", "surrogateescape")


def _encode(text):
    return text.encode("utf-8", "surrogateescape")


def read_bounded(stream):
    """Read at most the byte cap plus one byte; more than the cap raises LimitExceeded."""
    data = stream.read(_limits()[0] + 1)
    if len(data) > _limits()[0]:
        raise LimitExceeded()
    return _decode(data)


def redact_file(path):
    """Redact ``path`` in place, atomically, keeping its mode. Symlinks are refused. Over the limits, or on
    any internal error, the file is replaced by the withheld marker and LimitExceeded is raised afterwards."""
    if os.path.islink(path):
        raise OSError("refusing to redact through a symlink: %s" % path)
    if not os.path.isfile(path):
        return False
    original = cleaned = None
    try:
        if os.path.getsize(path) > _limits()[0]:
            raise LimitExceeded()
        with open(path, "rb") as handle:
            original = read_bounded(handle)
        cleaned = _guarded(redact, original)
    except Exception:  # fail closed: whatever went wrong, the unredacted text must not stay
        cleaned = None
    failed = cleaned is None
    if failed:
        cleaned = WITHHELD
    elif cleaned == original:
        return True
    directory = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(prefix=".redact.", dir=directory)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(_encode(cleaned))
        os.chmod(tmp, os.stat(path).st_mode & 0o7777)
        os.replace(tmp, path)
    except BaseException:
        with contextlib.suppress(FileNotFoundError):
            os.unlink(tmp)
        raise
    if failed:
        raise LimitExceeded()
    return True


def _write(text):
    sys.stdout.buffer.write(_encode(text))
    sys.stdout.buffer.flush()


def main(argv):
    if len(argv) == 2 and argv[1] == "--redact":
        try:
            _write(_guarded(redact, read_bounded(sys.stdin.buffer)))
        except Exception:  # fail closed on the limits and on any internal error
            _write(WITHHELD)
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
            found = _guarded(scan, read_bounded(sys.stdin.buffer))
        except LimitExceeded:
            sys.stdout.write(TOO_COMPLEX + "\n")
            return 3
        except Exception as exc:  # a crash is not a pass
            sys.stderr.write("ERROR: scanner failed: %s\n" % (str(exc).splitlines() or [type(exc).__name__])[0])
            return 2
        if found:
            sys.stdout.write("%s line %d\n" % found)
            return 1
        return 0
    sys.stderr.write(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
