import pathlib
import re
import shlex
import sys

payload = sys.argv[1]
assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
try:
    lexer = shlex.shlex(payload, posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    tokens = list(lexer)
except Exception:
    raise SystemExit(1)

if not tokens:
    raise SystemExit(1)
if any(token in {";", "|", "||", "&", "&&", ">", ">>", "<", "<<"} for token in tokens):
    raise SystemExit(1)

idx = 0
if tokens[idx] == "env":
    idx += 1
while idx < len(tokens) and assignment_re.match(tokens[idx]):
    idx += 1
if idx + 1 >= len(tokens):
    raise SystemExit(1)

command = tokens[idx]
if not (command == "scripts/silver-bullet" or command.endswith("/scripts/silver-bullet")):
    raise SystemExit(1)
if tokens[idx + 1] != "invoke-skill":
    raise SystemExit(1)

print("adapter")
