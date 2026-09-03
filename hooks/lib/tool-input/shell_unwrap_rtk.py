import re
import shlex
import sys

payload = sys.argv[1]
if not payload:
    raise SystemExit(0)

assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
try:
    lexer = shlex.shlex(payload, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    sys.stdout.write(payload)
    raise SystemExit(0)

if not tokens:
    raise SystemExit(0)

idx = 0
if tokens[idx] == "env":
    idx += 1
while idx < len(tokens) and assignment_re.match(tokens[idx]):
    if tokens[idx] == "RTK_DISABLED=1" or tokens[idx].startswith("RTK_DISABLED="):
        idx += 1
        continue
    idx += 1
if idx < len(tokens) and tokens[idx] == "rtk":
    idx += 1

if idx >= len(tokens):
    raise SystemExit(0)

sys.stdout.write(" ".join(shlex.quote(t) for t in tokens[idx:]))
