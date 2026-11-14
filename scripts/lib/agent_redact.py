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

import base64
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
_B64_PEM = tuple(
    base64.b64encode(raw[:len(raw) // 3 * 3]).decode()
    for raw in (("-----BEGIN %s-----" % label).encode() for label in
                ("PRIVATE KEY", "RSA PRIVATE KEY", "EC PRIVATE KEY", "OPENSSH PRIVATE KEY", "DSA PRIVATE KEY", "ENCRYPTED PRIVATE KEY")))
VENDOR = [
    ("jwt", ("eyJ",), [("U", 8, 4096), ".", ("U", 8, 8192), ".", ("U", 8, 4096)], False, None),
    ("github-pat", ("github_pat_",), [("W", 20, 255)], False, None),
    ("github", ("ghp_", "gho_", "ghu_", "ghs_", "ghr_"), [("A", 20, 255)], False, None),
    ("gitlab", ("glpat-", "glrt-", "glptt-", "gldt-", "glsoat-", "glcbt-", "glft-", "glagent-"), [("U", 20, 255)], False, None),
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
    ("discord-webhook", ("https://discord.com/api/webhooks/", "https://discordapp.com/api/webhooks/"), [("D", 17, 20), "/", ("U", 60, 80)], False, None),
    ("mapbox", ("sk.eyJ",), [("U", 20, 4096), ".", ("U", 10, 255)], False, None),
    ("pem-base64", _B64_PEM, [("B", 40, 8192)], False, None),  # kubeconfig client-key-data, Secret ssh-privatekey
    ("fly", ("fm2_", "fm1_"), [("FB", 40, 8192)], False, None),
    ("teams-webhook", (".webhook.office.com/webhookb2/",), [("U2", 60, 400)], False, None),
    ("slack-webhook", ("https://hooks.slack.com/services/T",), [("A", 6, 32), "/B", ("A", 6, 32), "/", ("A", 16, 64)], False, None),
]
CLS["A-"] = "A-Za-z0-9-"
CLS["FB"] = "A-Za-z0-9_+/=-"  # Fly.io tokens
CLS["U2"] = "A-Za-z0-9_@/.-"  # Teams webhook paths

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
    "kubectl": [("--docker-password", "either", P), ("--token", "either", T)],
    "aliyun": [("--access-key-secret", "either", T)],
    "*": [("--password", "either", P), ("--passwd", "either", P), ("--token", "either", T), ("--secret", "either", T),
          ("--api-key", "either", T), ("--apikey", "either", T), ("--access-token", "either", T), ("--auth-token", "either", T),
          ("--client-secret", "either", T), ("--http-password", "either", P), ("--ftp-password", "either", P)],
}
USERPASS_FLAGS = {"--user", "--proxy-user"}
USERPASS_SHORT = {"curl", "wget", "http", "https", "httpie"}  # curl / wget style user:pass
STDIN_SECRET_FLAGS = {"--password-stdin", "--with-token"}
SCHEMES = {"bearer", "basic", "token", "digest", "bot", "apikey", "sso-key", "ssws", "key", "api-key", "splunk", "geniekey", "oauth",
           "sharedkey", "sharedkeylite", "negotiate", "hmac"}

STRONG_WORDS = {"password", "passwd", "pass", "pwd", "pw", "passphrase", "passcode"}
CRED_WORDS = {"secret", "token", "credential", "credentials", "apikey", "dsn", "psk"}
WEAK_WORDS = {"sig", "signature"}
KEY_QUALIFIERS = {"api", "access", "secret", "private", "signing", "encryption", "auth", "license", "account", "master",
                  "app", "client", "shared", "storage", "service", "role", "subscription", "consumer", "webhook",
                  "deploy", "publish", "admin", "sendgrid", "stripe", "mailgun", "x"}
PUBLIC_WORDS = {"public", "publishable", "pub", "pk"}
# a credential word at the END of a name written as one concatenated word (dbpassword, NGROK_AUTHTOKEN, secretkey)
CONCAT_STRONG = ("password", "passwd", "passphrase", "passcode", "adminpass", "userpass", "rootpass", "dbpass", "rootpw", "adminpw",
                 "dbpw", "userpw", "adminpwd", "userpwd", "rootpwd", "dbpwd")
CONCAT_CRED = ("authtoken", "accesstoken", "apitoken", "bearertoken", "refreshtoken", "secrettoken", "clientsecret", "apisecret",
               "appsecret", "secretkey", "privatekey", "apikey", "accesskey", "masterkey", "authkey", "encryptionkey", "signingkey",
               "licensekey", "accountkey", "keydata", "dockerconfigjson", "token", "secret")
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
    if last == "auth" and (len(words) == 1 or name.startswith("_") or prev in ("cloud", "basic", "http", "proxy")):
        return "cred"
    if last in CRED_WORDS:
        return None if prev == "existing" else "cred"
    if last == "pat" and name.isupper():
        return "cred"
    if last == "key":
        if PUBLIC_WORDS & set(words):
            return None
        if prev == "key" or prev in KEY_QUALIFIERS:
            return "cred"
        return "weak"
    if last == "base" and words[-3:-1] == ["secret", "key"]:
        return "cred"
    if last in WEAK_WORDS:
        return "weak"
    norm = re.sub(r"[^a-z0-9]", "", name.lower())
    if norm.endswith(CONCAT_STRONG):
        return "strong"
    if norm.endswith(CONCAT_CRED) and not (PUBLIC_WORDS & set(words) and norm.endswith("key")):
        return "cred"
    return None


def entropy(v):
    n = len(v)
    return -sum(c / n * math.log2(c / n) for c in collections.Counter(v).values())


_REF = re.compile(r"^(?:\$\{|\$\(|\$[A-Za-z_]|\{\{|<[^>]*>$|%\(|#\{|\[REDACTED|process\.env|os\.environ|os\.getenv|getenv|ENV\[|"
                  r"vault:|op://|arn:|ssm:|file:|env:|secret:|kms:|!vault|secrets\.)", re.I)
_REF_WHOLE = re.compile(r"^(?:\$\{\{[^{}]{1,200}\}\}|\$\{[^{}]{1,200}\}|\$\([^()]{1,200}\)|\$[A-Za-z_]\w*|\{\{[^{}]{1,200}\}\}|"
                        r"\{[^{}]{1,200}\}|<[^<>]{1,100}>|%\([A-Za-z_]\w*\)s|#\{[^{}]{1,200}\}|\[REDACTED[^\]]*\])(?:[/:.\-@][\w./:@\-]*)?$")


def is_reference(v):
    """The WHOLE value is a reference (variable, template, placeholder, env accessor), never a prefix test."""
    return bool(_REF_WHOLE.match(v) or v.startswith(("$(", "${", "`")) or re.fullmatch(r"\$(?:\d|[@*#?!])(?:[/:.\-@][\w./:@\-]*)?", v)
                or (_REF.match(v) and not v.startswith(("$", "{", "<", "%", "#"))))


_PLACEHOLDER = re.compile(r"(?i)^[(<\[]?(?:sensitive(?: value)?|known after apply|redacted|secret|hidden|masked|omitted|computed|empty|none)[)>\]]?$"
                          r"|^\*{3,}$|^\d+\s+bytes$")
_TAG_NAMES = (r"Ref|Sub|GetAtt|Join|FindInMap|ImportValue|Select|Split|Base64|Cidr|If|Equals|Not|And|Or|Condition|env_var|env|secret|vault|"
              r"include|include_dir_\w+|reference|ssm|unsafe|Transform|GetAZs")
_REF_TAG = re.compile(r"^(?:!(?:%s)(?![\w-])|@Microsoft\.KeyVault\(|%%env\(|<%%)" % _TAG_NAMES)
_DUMMY = re.compile(r"dummy|fake|placeholder|replace[-_ ]?me|change[-_ ]?me|not[-_]a[-_]real|example|sample|redacted|x{4,}|"
                    r"^test[-_]|[-_]test$|for[-_]tests?|^your[-_]|[-_]your[-_]|^\*+$|\.\.\.|\u2026", re.I)
_UUID = re.compile(r"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
_HUMPS = re.compile(r"[A-Z]{2,}(?![a-z])|[A-Z]?[a-z]+|[A-Z]|[0-9]+")
_SEG_SPLIT = re.compile(r"(?:\.|::|->|[_\-:/])+")
_VOWEL = set("aeiouyAEIOUY")
_CONS_RUN = re.compile(r"[^aeiouyAEIOUY0-9]{6,}")


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


def is_path(v, strict=False):
    """strict (credential-named values): a relative path needs a file extension or segments of 3+ characters, so a random
    password that happens to hold a slash is not taken for a path."""
    if not ("/" in v or v.startswith("~")):
        return False
    if re.match(r"^[A-Za-z][A-Za-z0-9+.-]*://", v):
        return False
    body = v.lstrip("~./")
    segs = [s for s in re.split(r"[/]", body) if s]
    if strict and v[0] not in "/~." and not re.search(r"\.[A-Za-z0-9]{1,5}$", v) and any(len(s) < 3 for s in segs):
        return False
    return len(segs) >= 1 and (v[0] in "/~." or len(segs) >= 2) and all(
        all(word_segment(x) for x in re.split(r"[._#-]+", re.sub(r"\.[A-Za-z0-9]{1,5}$", "", s)) if x) for s in segs)


_CALL_HEAD = re.compile(r"^(?:new |await )?([A-Za-z_$][\w$]*(?:(?:\.|::|->)[A-Za-z_$][\w$]*)*)\((.*)$")


_EXPR_HEAD = re.compile(r"(?:new |await )?[@$]?[A-Za-z_][\w$]*(?:(?:\.|::|->)[A-Za-z_$][\w$]*)*")
_METHOD = re.compile(r"(?:\.|->)[A-Za-z_$][\w$]*")
_ARG_NAME = re.compile(r"(?:\*{1,2}|[A-Za-z_]\w*[ \t]*=(?!=))[ \t]*")
_NUMBER = re.compile(r"-?\d+(?:\.\d+)?")
_LITERALS = {"None", "True", "False", "null", "true", "false", "undefined", "nil", "NULL"}
_EXPR_DEPTH = 6


def _random_literal(lit):
    """A quoted argument that is itself shaped like a secret (long, mixed, with digits): not a harmless word."""
    return len(lit) >= 12 and not re.search(r"\s", lit) and bool(re.search(r"\d", lit)) and entropy(lit) >= 3.2 and not is_ident(lit)


def _split_args(body):
    parts, cur, depth, quote = [], [], 0, None
    for c in body:
        if quote:
            quote = None if c == quote else quote
        elif c in "\"'":
            quote = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == "," and depth == 0:
            parts.append("".join(cur))
            cur = []
            continue
        cur.append(c)
    parts.append("".join(cur))
    return parts


def _arg_ok(arg, depth):
    arg = arg.strip()
    if not arg:
        return True
    m = _ARG_NAME.match(arg)
    if m:
        arg = arg[m.end():].strip()
        if not arg:
            return True
    if _NUMBER.fullmatch(arg) or arg in _LITERALS:
        return True
    lit = re.fullmatch(r"[fbru]{0,2}([\"'])(.*)\1", arg, re.S)
    if lit:
        return not _random_literal(lit.group(2))
    if re.search(r"\s[-+*/%]\s", arg):  # salt + pw
        return all(_arg_ok(x, depth) for x in re.split(r"\s[-+*/%]\s", arg))
    if depth < _EXPR_DEPTH and is_expr(arg, depth + 1):
        return True
    return bool(re.fullmatch(r"[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)*", arg)) and (len(arg) <= 3 or is_ident(arg))


def is_expr(v, depth=0):
    """A code expression: an identifier/attribute chain with balanced call or subscript groups and method chains
    (f(g()), a.b(c).d(), x['k'].m()), whose arguments are identifiers, numbers or harmless literals. A call that carries a
    random-looking literal argument is NOT an expression."""
    m = _EXPR_HEAD.match(v)
    if not m:
        return False
    i, groups = m.end(), 0
    while i < len(v):
        if v[i] in "([":
            close = _balanced_end(v, i, len(v))
            if close < 0 or (v[i] == "(" and not all(_arg_ok(a, depth) for a in _split_args(v[i + 1:close - 1]))) or (
                    v[i] == "[" and not _arg_ok(v[i + 1:close - 1], depth)):
                return False
            i, groups = close, groups + 1
            continue
        n = _METHOD.match(v, i)
        if not n:
            return False
        i = n.end()
    return groups > 0 or (("." in m.group(0) or "::" in m.group(0) or "->" in m.group(0)) and is_ident(v))


def is_code(v):
    """A call, subscript or attribute chain (see is_expr), or a call cut short by a quote (identifier arguments only)."""
    if is_expr(v):
        return True
    cut = _CALL_HEAD.match(v)
    if cut:
        head, args = cut.group(1), re.sub(r"\)[\w.()]*$", "", cut.group(2))
        return (is_ident(head.replace("::", ".").replace("->", ".")) or bool(re.fullmatch(r"[a-z_][a-z0-9_]{1,30}", head))) and all(
            is_ident(a) or a.isdigit() for a in (x.strip("\"'") for x in re.split(r"[\s,=*]+", args)) if a)
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


_TYPE_WORDS = {"string", "str", "int", "integer", "long", "short", "float", "double", "decimal", "bool", "boolean", "number", "any",
               "object", "dict", "map", "list", "set", "array", "vec", "bytes", "text", "varchar", "char", "date", "datetime", "uuid",
               "none", "null", "nil", "undefined", "void", "true", "false", "required", "optional", "option", "nullable", "maybe",
               "await", "async", "new", "return", "function", "lambda", "def", "class", "import", "require", "var", "let", "const", "yield",
               "typeof", "prompt", "stdin", "interactive", "ask", "secretstr", "secretstring", "promise", "result", "self", "this", "typing", "unknown", "never", "empty", "unset"}
_HASHED = re.compile(r"^(?:\$2[aby]?\$|\$argon2|\$pbkdf2|\$scrypt|\$[156]\$|\{(?:SHA|SSHA|BCRYPT)\}|(?:sha\d+|md5)[=:][0-9a-f]{16,}$)", re.I)
_REF_ROOTS = {"var", "local", "locals", "data", "module", "each", "self", "this", "cls", "config", "conf", "cfg", "settings", "props",
              "args", "params", "request", "req", "form", "input", "user", "options", "opts", "env", "secrets", "vars", "ctx", "context",
              "state", "os", "process", "inputs", "parameters", "values", "default", "defaults", "kwargs", "payload", "body"}
_CHAIN = re.compile(r"[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[\"']?[\w.\-]{0,64}[\"']?\])+")


def is_syntax(v):
    """Operators, type names and keywords, password hashes and attribute chains off a well-known root: code, not a secret."""
    if len(v) <= 3 and all(c in "=!<>~&|+-*/%^?:." for c in v):
        return True
    if re.fullmatch(r"[A-Z][a-z]{2,}-[A-Z][a-z]{2,}", v):
        return True  # a PowerShell cmdlet (Read-Host, Get-Credential)
    if re.fullmatch(r"[A-Z][A-Z]+(?:_[A-Z0-9]+)+", v) and is_ident(v):
        return True  # SCREAMING_SNAKE constant or environment-variable name
    parts = [x for x in re.split(r"[\[\]|,?\s<>()]+", v.lower()) if x]
    if parts and all(x in _TYPE_WORDS for x in parts):
        return True
    if _HASHED.match(v):
        return True
    return bool(_CHAIN.fullmatch(v) and re.split(r"[.\[]", v, maxsplit=1)[0].lower() in _REF_ROOTS)


def classify(value, tier, name=""):
    v = unwrap(value)
    if not v or v == "$":
        return NONE
    if name and v.lower() in (name.lower(), name.lower().replace("_", "")):
        return NONE  # SECRET = 'SECRET': an enum member, not a value
    if is_reference(v) or _REF_TAG.match(v) or _PLACEHOLDER.search(v) or _ANGLE.search(v):
        return NONE
    if tier != "bearer" and is_syntax(v):
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
    if is_path(v, strict=tier in ("strong", "cred", "cli-pass", "cli-token")):
        return NONE
    nested = re.fullmatch(r"([A-Za-z_][\w.-]{0,63})=([\w.:/-]{0,64})", v)
    if nested and is_ident(nested.group(1)) and (not nested.group(2) or nested.group(2).isdigit() or is_ident(nested.group(2))):
        return NONE  # NAME=simple: an inner assignment, judged by its own anchor
    if ( re.match(r"^--[a-z][a-z0-9-]*(?:=|$)", v) or re.search(r"\{[A-Za-z_]\w*\}|\$\{|%\([A-Za-z_]\w*\)[sd]|\{\}", v) or re.fullmatch(r"\d{4}-\d\d-\d\d[T ][\d:.]+Z?", v)
            or re.fullmatch(r"[\w-]+(?:\.[\w-]+)*\.(?:sh|py|js|ts|md|json|ya?ml|toml|txt|pem|key|crt|env|conf|cfg|ini|log)", v)):
        return NONE  # a nested NAME=value, a flag, a format template or a file name: not itself a literal secret
    possible = POSSIBLE if tier in ("strong", "cred", "cli-pass", "cli-token") else NONE
    if is_code(v):
        return NONE if "(" in v or "[" in v else possible  # a call is code; a dotted word chain may be a passphrase (masked, not refused)
    if re.search(r"\s", v):
        return possible  # a phrase, not a token
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
        if re.fullmatch(r"[0-9A-Fa-f]{8,16}", v) and re.search("sign", name, re.I):
            return NONE  # a GPG key id, not the key
        if re.fullmatch(r"[0-9a-fA-F]{16,}", v):
            return SECRET
        if len(v) >= 16 and e >= 3.0:
            return SECRET
        if len(v) >= 12 and e >= 3.0 and sum(bool(re.search(p, v)) for p in ("[a-z]", "[A-Z]", "[0-9]", "[^A-Za-z0-9]")) >= 3:
            return SECRET
        return possible
    # tier "weak" (cache_key, sig): only hashes and long random values
    if re.fullmatch(r"[0-9a-f]{40}|[0-9a-f]{64}", v):
        return NONE  # a sha1 / sha256 digest (cache key, content hash), not an API key
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


_OPENERS = "({["
_CLOSERS = {"(": ")", "{": "}", "[": "]"}
_HEADCHARS = frozenset("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_.$:>-@%!")
_PLACEHOLDER_AT = re.compile(r"(?i)\(?(?:sensitive(?: value)?|known after apply|redacted|hidden|computed)\)?|\*{3,}|\d+[ \t]+bytes\b")
_TAG_AT = re.compile(r"!(?:%s)(?![\w-])" % _TAG_NAMES)  # YAML tags that make a value a reference (CloudFormation, Home Assistant)
_ANGLE = re.compile(r"<[A-Za-z_][\w.\- ]{0,30}>")
# Work done by _balanced_end is capped per text (a text of unclosed "${" openers would otherwise rescan its window at every
# anchor): past the cap an opener is simply not extended.
_BAL_BUDGET = [0]


def _balanced_end(text, e, lim):
    """Index just past the bracket that closes the one at ``e`` on the same line (within ``lim``), or -1."""
    stack = []
    if _BAL_BUDGET[0] <= 0:
        return -1
    i = e
    for i in range(e, lim):
        c = text[i]
        if c in _CLOSERS:
            stack.append(_CLOSERS[c])
        elif c in ")}]":
            if not stack or stack.pop() != c:
                break
            if not stack:
                _BAL_BUDGET[0] -= i - e
                return i + 1
        elif c == "\n":
            break
    _BAL_BUDGET[0] -= i - e + 1
    return -1


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
    placeholder = _PLACEHOLDER_AT.match(text, j)
    if placeholder:  # (sensitive value), (known after apply), ***, 16 bytes: one value, not cut at its first word
        return j, placeholder.end()
    tag = _TAG_AT.match(text, j)
    if tag:  # a YAML tag (!Ref X, !Sub "...", !secret x) takes the rest of the line
        nl = text.find("\n", j, min(n, j + VALUE_MAX))
        return j, (nl if nl >= 0 else min(n, j + VALUE_MAX))
    e = j
    lim = min(n, j + VALUE_MAX)
    head_ok = True  # everything so far is an identifier/attribute chain (balanced groups included)
    tried = False
    while e < lim:
        c = text[e]
        if c in _OPENERS and e > j and head_ok and not tried:
            close = _balanced_end(text, e, lim)  # a reference or call keeps its brackets: ${X}, $(cmd), f(a, b), x['k'].m()
            if close > 0:
                e = close
                continue
            tried = True
        elif c == "<" and e > j and _ANGLE.match(text, e):
            e = _ANGLE.match(text, e).end()  # https://<key>@host: a placeholder inside a value
            continue
        if c in _STOP_UNQ and (c != "&" or _QPARAM.match(text, e) or e + 1 >= n or text[e + 1] in " \t\n&"):
            break
        head_ok = head_ok and c in _HEADCHARS
        e += 1
    return j, e


_SCHEME_PREFIX = re.compile(r"[A-Za-z][A-Za-z-]{0,31}[ \t]+(?=\S)")


def _header_end(text, vs, name_start):
    """End of an unquoted Authorization value: the end of the line, or the quote that was open before the header name."""
    end = min(len(text), vs + VALUE_MAX)
    nl = text.find("\n", vs, end)
    if nl >= 0:
        end = nl
    opener = text[name_start - 1] if name_start > 0 else ""
    if opener in ("\"", "'", "`"):
        close = text.find(opener, vs, end)
        if close >= 0:
            end = close
    while end > vs and text[end - 1] in " \t\r":
        end -= 1
    return end


def _auth_span(text, vs, ve):
    """(start, end, verdict) of the credential in an Authorization value. A leading scheme word is kept, whatever its spelling;
    the credential is the next word, or everything after the scheme when it holds name=value pairs (Digest, Hawk, Token
    token="..."), so any scheme's secret is masked and scan and redact agree. References and prose are left alone."""
    m = _SCHEME_PREFIX.match(text, vs, ve)
    if m:
        vs = m.end()
    rest = text[vs:ve]
    if not re.search(r"\w=\S", rest):  # no name=value pairs: the credential is the next word only
        ve = vs + len(rest.split(None, 1)[0]) if rest.strip() else vs
        rest = text[vs:ve]
    verdict = classify(rest, "bearer")
    if not verdict and len(rest) >= 6 and re.search(r"[^A-Za-z]", rest) and not is_reference(unwrap(rest)) and rest.lower() not in SCHEMES:
        verdict = POSSIBLE
    return vs, ve, verdict


_KEY_ANCHOR = re.compile(r"(?i)(?:password|passwd|pass|pwd|pw|pat|psk|passphrase|passcode|secret|token|credentials?|key|keydata|dockerconfigjson|auth|"
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
            if not (vs > 0 and text[vs - 1] in "\"'`" and text[ve:ve + 1] == text[vs - 1]):
                ve = _header_end(text, vs, i)  # unquoted: the rest of the line (or up to the quote that opened the header)
            if _SCHEME_PREFIX.match(text, vs, ve) is None and text[vs:ve].lower() in SCHEMES:
                vs, ve = _value_at(text, ve)  # the scheme word alone: the credential is the next word
            vs, ve, verdict = _auth_span(text, vs, ve)
            if ve > vs:
                out.append((vs, ve, "authorization", verdict))
        else:
            out.append((vs, ve, "assignment", classify(text[vs:ve], tier, name)))
        consumed = ve


_XML = re.compile(r"<([A-Za-z_][\w.:-]{0,63})>")
_XML_ATTR = re.compile(r"(?:key|name)=\"([^\"<>]{1,128})\"[ \t]+value=\"")
_XML_NAMED = re.compile(r"<([A-Za-z_][\w.:-]{0,63})[ \t]+(?:name|key)=\"([^\"<>]{1,128})\"[ \t]*>")


def pass_xml(text, out):
    for m in _XML.finditer(text):
        _tick()
        tier = name_tier(m.group(1))
        if tier is None:
            continue
        e = text.find("<", m.end(), min(len(text), m.end() + VALUE_MAX))
        if e > m.end() and text.startswith("</" + m.group(1), e):
            out.append((m.end(), e, "xml-element", classify(text[m.end():e], tier, m.group(1))))
    for m in _XML_NAMED.finditer(text):  # <property name="db.password">value</property>, <entry key="x.secret">value</entry>
        _tick()
        tier = name_tier(m.group(2))
        if tier is None:
            continue
        e = text.find("<", m.end(), min(len(text), m.end() + VALUE_MAX))
        if e > m.end() and text.startswith("</" + m.group(1), e):
            out.append((m.end(), e, "xml-element", classify(text[m.end():e], tier, m.group(2))))
    for m in _XML_ATTR.finditer(text):
        _tick()
        tier = name_tier(m.group(1))
        if tier is None:
            continue
        e = text.find('"', m.end(), min(len(text), m.end() + VALUE_MAX))
        if e > m.end():
            out.append((m.end(), e, "xml-attribute", classify(text[m.end():e], tier, m.group(1))))


_NV_NAME = re.compile(r"(?i)(?<![\w])[\"']?(?:name|key)[\"']?[ \t]*[:=][ \t]*[\"']?([A-Za-z_][\w.\-]{0,127})")
_NV_VALUE = re.compile(r"(?i)(?<![\w])[\"']?value[\"']?[ \t]*[:=]")
_OBJ_VALUE = re.compile(r"\{[ \t\r\n]*[\"']?value[\"']?[ \t]*:")  # the name sits before the brace: found by looking backwards
_ENV_LINE = re.compile(r"(?<![\w.-])(?:ENV|ARG)[ \t]+([A-Za-z_][\w.\-]{0,127})[ \t]+(?=[^=\s])")
_MD_ROW = re.compile(r"(?m)^[ \t>*-]{0,8}\|[ \t]*`?([A-Za-z_][\w.\-]{0,127})`?[ \t]*\|[ \t]*`?")
_FORM_FIELD = re.compile(r"form-data;[ \t]*name=\"([A-Za-z_][\w.\-]{0,127})\"[^\n]{0,200}\n\r*\n")
_LIST_VALUE = re.compile(r"(?m)^[ \t]*-[ \t]+value[\"']?[ \t]*:[ \t]*")
_HDR_DIRECTIVE = re.compile(r"(?i)\b(?:proxy_set_header|add_header|header|set_header)[ \t]+Authorization[ \t]+")
PAIR_WINDOW = 300


def pass_pairs(text, out):
    """Name/value pairs whose name and value sit in different fields: Kubernetes env (name: X / value: Y), ECS and Terraform
    {"name": X, "value": Y}, ARM {"X": {"value": Y}}, Dockerfile ENV X Y and Markdown table rows | X | Y |."""
    consumed = 0
    for m in _NV_NAME.finditer(text):
        _tick()
        tier = name_tier(m.group(1))
        if m.start() < consumed or tier is None or tier == "auth-header":
            continue
        vm = _NV_VALUE.search(text, m.end(), min(len(text), m.end() + PAIR_WINDOW))
        if vm is None or _NV_NAME.search(text, m.end(), vm.start()):
            continue  # no value field soon enough, or another name comes first
        vs, ve = _value_at(text, vm.end())
        if ve > vs:
            out.append((vs, ve, "pair-value", classify(text[vs:ve], tier, m.group(1))))
            consumed = ve
    for m in _LIST_VALUE.finditer(text):  # "- value: V" followed by "name: X" (the order swapped)
        _tick()
        vs, ve = _value_at(text, m.end())
        nm = _NV_NAME.search(text, ve, min(len(text), ve + PAIR_WINDOW))
        tier = name_tier(nm.group(1)) if nm else None
        if ve > vs and tier and tier != "auth-header" and not _NV_VALUE.search(text, ve, nm.start()):
            out.append((vs, ve, "pair-value", classify(text[vs:ve], tier, nm.group(1))))
    for m in _FORM_FIELD.finditer(text):  # multipart/form-data: the part body is the value
        _tick()
        tier = name_tier(m.group(1))
        if tier is None or tier == "auth-header":
            continue
        eol = text.find("\n", m.end(), min(len(text), m.end() + VALUE_MAX))
        ve = (eol if eol >= 0 else min(len(text), m.end() + VALUE_MAX))
        while ve > m.end() and text[ve - 1] == "\r":
            ve -= 1
        if ve > m.end():
            out.append((m.end(), ve, "form-data", classify(text[m.end():ve], tier, m.group(1))))
    for m in _HDR_DIRECTIVE.finditer(text):  # nginx: proxy_set_header Authorization "Basic ..."
        _tick()
        vs, ve = _value_at(text, m.end())
        if ve > vs:
            vs, ve, verdict = _auth_span(text, vs, ve)
            if ve > vs:
                out.append((vs, ve, "authorization", verdict))
    for m in _OBJ_VALUE.finditer(text):
        _tick()
        j = m.start()
        while j > 0 and text[j - 1] in " \t\r\n":
            j -= 1
        if j == 0 or text[j - 1] != ":":
            continue
        j -= 1
        while j > 0 and text[j - 1] in " \t\"'":
            j -= 1
        i = j
        while i > max(0, j - NAME_MAX) and _NAME_CHAR.match(text[i - 1]):
            i -= 1
        name = text[i:j]
        tier = name_tier(name)
        if tier is None or tier == "auth-header":
            continue
        vs, ve = _value_at(text, m.end())
        if ve > vs:
            out.append((vs, ve, "pair-value", classify(text[vs:ve], tier, name)))
    for m in _ENV_LINE.finditer(text):
        _tick()
        tier = name_tier(m.group(1))
        if tier is None or tier == "auth-header":
            continue
        vs, ve = _value_at(text, m.end())
        if ve > vs:
            out.append((vs, ve, "dockerfile-env", classify(text[vs:ve], tier, m.group(1))))
    for m in _MD_ROW.finditer(text):
        _tick()
        tier = name_tier(m.group(1))
        if tier is None or tier == "auth-header":
            continue
        end = min(len(text), m.end() + VALUE_MAX)
        for stop in ("|", "\n"):
            k = text.find(stop, m.end(), end)
            if k >= 0:
                end = k
        cell = text[m.end():end]
        vs = m.end() + (len(cell) - len(cell.lstrip()))
        ve = m.end() + len(cell.rstrip(" \t`"))
        verdict = classify(text[vs:ve], tier, m.group(1))
        if verdict == SECRET and ve > vs:
            out.append((vs, ve, "table-row", SECRET))  # a table cell is documentation unless it is plainly a literal


_SUBSCRIPT_SET = re.compile(r"\[[ \t]*[\"']([A-Za-z_][\w.\-]{0,127})[\"'][ \t]*\][ \t]*=(?!=)[ \t]*")
_CALL_ARG = re.compile(r"\([ \t]*[\"']([A-Za-z_][\w.\-]{0,127})[\"'][ \t]*,[ \t]*")


def pass_calls(text, out):
    """A credential name that is a string subscript or the first literal argument of a call, with its value after it:
    app.config['SECRET_KEY'] = 'v', os.environ["X"] = 'v', $cfg['password'] = 'v', define('DB_PASSWORD', 'v'),
    props.setProperty("password", "v"), os.environ.get("TOKEN", "default")."""
    for rx, rule in ((_SUBSCRIPT_SET, "subscript-assign"), (_CALL_ARG, "call-argument")):
        for m in rx.finditer(text):
            _tick()
            name = m.group(1)
            tier = name_tier(name)
            if tier is None:
                continue
            vs, ve = _value_at(text, m.end())
            if ve <= vs:
                continue
            if tier == "auth-header":
                vs, ve, verdict = _auth_span(text, vs, ve)
            else:
                verdict = classify(text[vs:ve], tier, name)
                if verdict == POSSIBLE and text[vs - 1] not in "\"'":
                    verdict = NONE  # a bare argument (a variable) is a reference, not a literal
            if ve > vs:
                out.append((vs, ve, rule, verdict))


_WORD = re.compile(r"[^\s`'\"|;&()<>]+|'[^'\n]{0,1024}'|\"[^\"\n]{0,1024}\"|[|;&]+|\n")
_BEARER = re.compile(r"(?i)(?<![A-Za-z0-9_])bearer[ \t]+")
_EXTRA_PROGS = ("aws", "poetry", "htpasswd", "curl", "wget", "gh", "convertto-securestring", "npm", "yarn", "pnpm", "vault")
_PKG_MANAGERS = ("npm", "yarn", "pnpm")
_PROGS = set(CLI) - {"*"} | set(_EXTRA_PROGS)
FLAGS = {prog: {f: (mode, tier) for f, mode, tier in rows} for prog, rows in CLI.items()}
ATTACHED = {prog: {f: tier for f, mode, tier in rows if mode in ("attached", "either") and len(f) == 2} for prog, rows in CLI.items()}
GFLAGS = FLAGS["*"]
_ANCHOR_WORDS = sorted(_PROGS | set(GFLAGS) | USERPASS_FLAGS | STDIN_SECRET_FLAGS | {"echo", "printf"}, key=len, reverse=True)
# a program / flag from the tables, or ANY long flag that ends in a credential word (--docker-password, --api-token)
_CLI_ANCHOR = re.compile(r"(?i)(?<![\w.\-])(?:(?:[\w.\-]*/)?(?:%s)(?![\w\-])|--[a-z0-9-]{0,60}(?:password|passwd|token|secret|key|pat)(?![\w\-]))"
                         % "|".join(map(re.escape, _ANCHOR_WORDS)))
_FLAG_SKIP = re.compile(r"^--(?:no|skip|without|disable|enable|use|ask|prompt|show|print|hide|with)-")


def _flag_tier(w):
    """CLI tier of a long flag that is not in the tables but is named like a credential (--docker-password, --api-token)."""
    if "=" in w or not w.startswith("--") or _FLAG_SKIP.match(w):
        return None
    return {"strong": "cli-pass", "cred": "cli-token"}.get(name_tier(w[2:]))
_NETRC_ANCHOR = re.compile(r"(?i)(?<![\w\-])(?:login|machine)(?![\w\-])")
MAX_CMD = 4096


def _lex_command(text, p, end, out):
    prog, pending, args = None, None, []
    prev_echo = seg_echo = attached = None
    for m in _WORD.finditer(text, p, end):
        w = m.group(0)
        if attached and m.start() == attached[2] and w[0] in "'\"" and len(w) >= 2:
            out.append((m.start() + 1, m.end() - 1, "cli-" + attached[1], classify(w[1:-1], attached[0])))  # -p'secret'
            attached = None
            continue
        attached = None
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
        if prog == "gh" and w in ("--body", "-b") and args[:2] == ["secret", "set"]:
            pending = ("cli-token", "cli-gh")
            continue
        ft = _flag_tier(w)
        if ft:
            pending = (ft, "cli-%s" % (prog or "flag"))
            continue
        att = ATTACHED.get(prog, {}).get(w[:2])
        if att and len(w) > 2 and w[2] not in "-=":
            out.append((ws + 2, we, "cli-" + prog, classify(w[2:], att)))
            continue
        if att and len(w) == 2:
            attached = (att, prog, we)
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
        elif prog == "vault" and args[0] == "login" and len(args) == 2 and not w.startswith("-"):
            out.append((ws, we, "cli-vault", classify(w, "cli-token")))
        elif prog in _PKG_MANAGERS and args[:2] == ["config", "set"] and len(args) == 4 and name_tier(args[2]) in ("strong", "cred"):
            out.append((ws, we, "cli-" + prog, classify(w, "cli-pass" if name_tier(args[2]) == "strong" else "cli-token")))
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
                if text[v.start() - 1] == "<":
                    break  # <token>: a placeholder
                out.append((v.start(), v.end(), "netrc", classify(v.group(0), "cli-pass")))
                break
        consumed = words[-1].end() if words else a.end()
    for m in _BEARER.finditer(text):
        _tick()
        vs, ve = _value_at(text, m.end())
        if ve > vs:
            out.append((vs, ve, "bearer", classify(text[vs:ve], "bearer")))


PASSES = (pass_pem, pass_vendor, pass_shapes, pass_url, pass_assign, pass_xml, pass_pairs, pass_calls, pass_words)


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
_PATTERNS = (_ANCH_RE, _DISCORD, _KEY_ANCHOR, _XML, _XML_ATTR, _XML_NAMED, _NV_NAME, _NV_VALUE, _OBJ_VALUE, _ENV_LINE, _MD_ROW, _SUBSCRIPT_SET, _CALL_ARG, _FORM_FIELD, _LIST_VALUE, _HDR_DIRECTIVE, _SCHEME_PREFIX, _WORD, _BEARER, _CLI_ANCHOR, _NETRC_ANCHOR, _OPAQUE,
             _QPARAM, _HOST, _SEP)


def candidates(text):
    _BAL_BUDGET[0] = 8 * len(text) + 4096
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
class _Pairs(list):
    """A decoded JSON object kept as a list of (key, value) pairs, so duplicate keys are still seen."""


_SURROGATE = re.compile("[\ud800-\udfff]")


def _walk_json(obj, base_line, finds):
    """Return (new_obj, changed). Every string (and every object key) is scanned as text; a (key, string) pair is an
    assignment, a {"name": N, "value": V} pair is N = V, and {"K": {"value": V}} is K = V."""
    changed = [False]

    def text_of(v, tier, key):
        if v[:1] in ("{", "[") or v.lstrip()[:1] in ("{", "["):  # JSON text inside a string (a log line quoted in a transcript)
            try:
                inner = json.loads(v, object_pairs_hook=_Pairs)
            except (ValueError, RecursionError):
                inner = None
            if isinstance(inner, (_Pairs, list)):
                outer, changed[0] = changed[0], False
                new_inner = fix(inner)
                inner_changed, changed[0] = changed[0], outer or changed[0]
                return _dump_json(new_inner, "", v, "") if inner_changed else v
        cands = candidates(v)
        if tier == "auth-header":
            vs, ve, verdict = _auth_span(v, 0, len(v))
            if vs < ve:
                cands.append((vs, ve, "authorization", verdict))
        elif tier:
            cands.append((0, len(v), "json-field", classify(v, tier, key)))
        for _s, _e, rule, verdict in cands:
            if verdict == SECRET:
                finds.append((rule, base_line))
        new = apply(v, cands)
        if new != v:
            changed[0] = True
        return new

    def fix(v, key=None):
        if isinstance(v, _Pairs):
            label = None
            for k, x in v:
                if k.lower() in ("name", "key") and isinstance(x, str):
                    label = x
                    break
            if len({k for k, _x in v}) != len(v):
                changed[0] = True  # a duplicate key is dropped by the dict below; its value was scanned
            out = {}
            for k, x in v:
                sub = (label or key or k) if k.lower() == "value" else k
                out[text_of(k, None, None)] = fix(x, sub)
            return out
        if isinstance(v, list):
            return [fix(x, key) for x in v]
        if isinstance(v, str):
            return text_of(v, name_tier(key) if key else None, key)
        if isinstance(v, (int, float)) and not isinstance(v, bool) and key and name_tier(key) == "strong" and len(str(v)) >= 8:
            finds.append(("json-field", base_line))
            changed[0] = True
            return REDACTED
        return v
    return fix(obj), changed[0]


def _dump_json(obj, lead, body, trail):
    """Re-serialize a changed line in the style of the original (compact or spaced), between its original lead (indent,
    Markdown quote or bullet) and trail (CR, closing backtick); lone surrogates (from \\ud83d escapes) force ASCII escapes
    so the result stays valid JSON and encodable."""
    seps = (",", ":") if '": ' not in body and '", ' not in body else (", ", ": ")
    text = json.dumps(obj, ensure_ascii=False, separators=seps)
    if _SURROGATE.search(text):
        text = json.dumps(obj, ensure_ascii=True, separators=seps)
    return lead + text + trail


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
        lead_len = len(line) - len(line.lstrip(" \t>-*`"))  # a Markdown quote, bullet or code span around a JSON line
        body = line[lead_len:].rstrip(" \t\r`")
        obj = None
        if body[:1] in ("{", "["):
            try:
                obj = json.loads(body, object_pairs_hook=_Pairs)
            except (ValueError, RecursionError):
                obj = None
        if isinstance(obj, (dict, list)):
            flush()
            try:
                new, changed = _walk_json(obj, n + 1, finds)
            except RecursionError:
                obj = None
        if isinstance(obj, (dict, list)):
            out_lines.append(_dump_json(new, line[:lead_len], body, line[lead_len + len(body):]) if changed else line)
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
    """Redact ``path`` in place, atomically, keeping its mode. Symlinks are refused. Over the limits, or on any internal
    error (including text that cannot be encoded back), the file is replaced by the withheld marker and LimitExceeded is
    raised afterwards."""
    if os.path.islink(path):
        raise OSError("refusing to redact through a symlink: %s" % path)
    if not os.path.isfile(path):
        return False
    raw = payload = None
    try:
        with open(path, "rb") as handle:  # at most cap+1 bytes are ever read
            raw = handle.read(_limits()[0] + 1)
        if len(raw) > _limits()[0]:
            raise LimitExceeded()
        payload = _encode(_guarded(redact, _decode(raw)))
    except Exception:  # fail closed: whatever went wrong, the unredacted text must not stay
        payload = None
    failed = payload is None
    if failed:
        payload = WITHHELD.encode("ascii")
    elif payload == raw:
        return True
    directory = os.path.dirname(os.path.abspath(path))
    fd, tmp = tempfile.mkstemp(prefix=".redact.", dir=directory)
    try:
        with os.fdopen(fd, "wb") as handle:
            handle.write(payload)
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
        except Exception as exc:  # OSError and anything unexpected: a message and exit 2, never a traceback
            sys.stderr.write("ERROR: %s\n" % (str(exc).splitlines() or [type(exc).__name__])[0])
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
