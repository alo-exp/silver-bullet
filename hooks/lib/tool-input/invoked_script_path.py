import pathlib
import re
import shlex
import sys

base_dir = pathlib.Path(sys.argv[1])
command = sys.argv[2]

assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
shell_names = {"bash", "sh", "zsh"}

def parse_tokens(raw_command: str):
    try:
        return shlex.split(raw_command, posix=True)
    except Exception:
        return []


def unwrap_command(raw_command: str):
    seen = set()
    current = raw_command
    while current and current not in seen:
        seen.add(current)
        tokens = parse_tokens(current)
        idx = 0
        if idx < len(tokens) and tokens[idx] == "env":
            idx += 1
        while idx < len(tokens) and assignment_re.match(tokens[idx]):
            idx += 1
        if idx >= len(tokens):
            return []
        command_name = pathlib.Path(tokens[idx]).name
        args = tokens[idx + 1 :]
        if command_name in shell_names:
            for arg_index, arg in enumerate(args):
                if arg.startswith("-") and "c" in arg[1:] and arg_index + 1 < len(args):
                    current = args[arg_index + 1]
                    break
            else:
                return tokens[idx:]
            continue
        return tokens[idx:]
    return []


tokens = unwrap_command(command)
if not tokens:
    raise SystemExit(0)

candidate = None
command_name = pathlib.Path(tokens[0]).name
if command_name in shell_names:
    idx = 1
    while idx < len(tokens) and tokens[idx].startswith("-"):
        idx += 1
    if idx < len(tokens):
        candidate = tokens[idx]
elif command_name.endswith(".sh") or tokens[0].startswith(("./", "../", "/", "~/")):
    candidate = tokens[0]

if not candidate:
    raise SystemExit(0)

path = pathlib.Path(candidate).expanduser()
if not path.is_absolute():
    path = base_dir / path
resolved = path.resolve(strict=False)
if resolved.exists() and resolved.is_file():
    print(resolved)
