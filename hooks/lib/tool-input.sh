#!/usr/bin/env bash

sb_tool_name() {
  local payload="${1:-}"
  printf '%s' "$payload" | jq -r '.tool_name // ""' 2>/dev/null || true
}

sb_tool_is_shell_like() {
  local tool_name="${1:-}"
  case "$tool_name" in
    Bash|Shell|shell|exec_command) return 0 ;;
    *) return 1 ;;
  esac
}

sb_tool_command_string() {
  local payload="${1:-}"
  python3 - "$payload" <<'PY' 2>/dev/null || true
import json
import shlex
import sys

try:
    payload = json.loads(sys.argv[1] or "{}")
except Exception:
    raise SystemExit(0)

tool_input = payload.get("tool_input")
if not isinstance(tool_input, dict):
    raise SystemExit(0)

command = tool_input.get("command")
if command is None:
    command = tool_input.get("cmd")
if isinstance(command, str):
    sys.stdout.write(command)
elif isinstance(command, list):
    sys.stdout.write(" ".join(shlex.quote(str(part)) for part in command))
PY
}

sb_tool_patch_paths() {
  local payload="${1:-}"
  python3 - "$payload" <<'PY' 2>/dev/null || true
import json
import re
import sys

try:
    payload = json.loads(sys.argv[1] or "{}")
except Exception:
    raise SystemExit(0)

tool_input = payload.get("tool_input")
if tool_input is None:
    raise SystemExit(0)

texts = []

def collect(value):
    if isinstance(value, str):
        texts.append(value)
    elif isinstance(value, dict):
        for item in value.values():
            collect(item)
    elif isinstance(value, list):
        for item in value:
            collect(item)

collect(tool_input)

seen = set()
for text in texts:
    for line in text.splitlines():
        match = re.match(r"^\*\*\* (?:Add|Update|Delete) File: (.+)$", line)
        if not match:
            match = re.match(r"^\*\*\* Move to: (.+)$", line)
        if not match:
            continue
        path = match.group(1).strip()
        if path and path not in seen:
            seen.add(path)
            print(path)
PY
}

sb_tool_file_path() {
  local payload="${1:-}"
  local direct_path
  direct_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_response.filePath // ""' 2>/dev/null || true)"
  if [[ -n "$direct_path" ]]; then
    printf '%s\n' "$direct_path"
    return 0
  fi
  sb_tool_patch_paths "$payload" | sed -n '1p'
}

sb_shell_invoked_script_path() {
  local command_str="${1:-}"
  local base_dir="${2:-$PWD}"

  python3 - "$base_dir" "$command_str" <<'PY'
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
PY
}

sb_shell_candidate_write_paths() {
  local command_str="${1:-}"
  local base_dir="${2:-$PWD}"

  python3 - "$base_dir" "$command_str" <<'PY'
import pathlib
import re
import shlex
import sys

base_dir = pathlib.Path(sys.argv[1])
payload = sys.argv[2]

assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
redirect_re = re.compile(r'(^|[\s;|&])(?:>>|[0-9]?>)\s*(?:"([^"]+)"|\'([^\']+)\'|([^\s;|&]+))')
redirect_token_re = re.compile(r'^(?:[0-9]*>>?|&>>?)$')
write_dest_commands = {"cp", "mv", "install", "ln"}
write_all_path_commands = {"rm", "chmod", "touch", "mkdir"}
stdout_redirect_commands = {"echo", "printf"}
shell_names = {"bash", "sh", "zsh"}
shell_control_tokens = {"|", "||", "&&", ";"}
ignored_write_targets = {"/dev/null", "/dev/stdin", "/dev/stdout", "/dev/stderr"}


def normalize_candidate(token: str):
    token = token.strip().rstrip(";|&")
    if not token or token == "-" or "$" in token or "`" in token:
        return None
    path = pathlib.Path(token).expanduser()
    if str(path) in ignored_write_targets or str(path).startswith("/dev/fd/"):
        return None
    if not path.is_absolute():
        path = base_dir / path
    try:
        return str(path.resolve(strict=False))
    except Exception:
        return str(path)


def tokenize(line: str):
    try:
        return shlex.split(line, posix=True)
    except Exception:
        return []


def next_command(tokens):
    idx = 0
    if idx < len(tokens) and tokens[idx] == "env":
        idx += 1
    while idx < len(tokens) and assignment_re.match(tokens[idx]):
        idx += 1
    if idx >= len(tokens):
        return None, []
    return pathlib.Path(tokens[idx]).name, tokens[idx + 1 :]


def unwrap_shell_command(command_name, args):
    if command_name not in shell_names:
        return None
    for index, arg in enumerate(args):
        if arg.startswith("-") and "c" in arg[1:] and index + 1 < len(args):
            return args[index + 1]
    return None


def positional_args(args):
    out = []
    skip_next = False
    for arg in args:
        if skip_next:
            skip_next = False
            continue
        if arg == "--":
            continue
        if redirect_token_re.fullmatch(arg):
            skip_next = True
            continue
        if arg.startswith("-") or arg in shell_control_tokens:
            continue
        out.append(arg)
    return out


def inline_script_arg(args, flag):
    for index, arg in enumerate(args):
        if arg == flag and index + 1 < len(args):
            return args[index + 1]
        if arg.startswith(flag) and len(arg) > len(flag):
            return arg[len(flag):]
    return None


def inline_script_write_targets(command_name, args):
    script = None
    patterns = []
    if command_name in {"python", "python3"}:
        script = inline_script_arg(args, "-c")
        patterns = [
            re.compile(r"""(?:pathlib\.)?Path\(\s*(['"])(.+?)\1\s*\)\.(?:write_text|write_bytes|touch)\s*\("""),
            re.compile(r"""(?:pathlib\.)?Path\(\s*(['"])(.+?)\1\s*\)\.open\(\s*['"](?:a|w|x)['"]"""),
            re.compile(r"""open\(\s*(['"])(.+?)\1\s*,\s*['"](?:a|w|x)['"]"""),
        ]
    elif command_name in {"node", "nodejs"}:
        script = inline_script_arg(args, "-e")
        patterns = [
            re.compile(r"""(?:appendFileSync|writeFileSync|createWriteStream)\(\s*(['"])(.+?)\1"""),
        ]
    elif command_name == "ruby":
        script = inline_script_arg(args, "-e")
        patterns = [
            re.compile(r"""File\.(?:write|binwrite)\(\s*(['"])(.+?)\1"""),
            re.compile(r"""File\.open\(\s*(['"])(.+?)\1\s*,\s*['"](?:a|w|x)['"]"""),
        ]
    elif command_name == "perl":
        script = inline_script_arg(args, "-e")
        patterns = [
            re.compile(r"""open\s*\([^)]*(['"])(?:>>|>|<<?)\1\s*,\s*(['"])(.+?)\2"""),
        ]

    if not script:
        return

    for pattern in patterns:
        for match in pattern.finditer(script):
            candidate = match.groups()[-1]
            normalized = normalize_candidate(candidate)
            if normalized:
                yield normalized


def tokenized_redirect_targets(command_name, args):
    for index, arg in enumerate(args):
        if not redirect_token_re.fullmatch(arg):
            continue
        if index + 1 >= len(args):
            continue
        candidate = args[index + 1]
        if candidate == "--" or candidate in shell_control_tokens:
            continue
        prior_operands = [
            token for token in args[:index]
            if token != "--" and not token.startswith("-") and token not in shell_control_tokens
        ]
        if not prior_operands and command_name not in stdout_redirect_commands:
            continue
        normalized = normalize_candidate(candidate)
        if normalized:
            yield normalized


seen = set()
pending_chunks = [payload]
while pending_chunks:
    raw_line = pending_chunks.pop(0)
    if not raw_line.strip():
        continue

    tokens = tokenize(raw_line)
    if tokens:
        cmd, args = next_command(tokens)
        if cmd is not None:
            nested_command = unwrap_shell_command(cmd, args)
            if nested_command is not None:
                pending_chunks.insert(0, nested_command)
                continue

            for normalized in inline_script_write_targets(cmd, args):
                seen.add(normalized)

    for match in redirect_re.finditer(raw_line):
        candidate = next(group for group in match.groups()[1:] if group)
        normalized = normalize_candidate(candidate)
        if normalized:
            seen.add(normalized)

    for segment in re.split(r'(?:\|\||&&|[;|]|\n)', raw_line):
        segment = segment.strip()
        if not segment or segment.startswith("#"):
            continue
        segment_tokens = tokenize(segment)
        if not segment_tokens:
            continue
        cmd, args = next_command(segment_tokens)
        if cmd is None:
            continue
        for normalized in tokenized_redirect_targets(cmd, args):
            seen.add(normalized)
        positional = positional_args(args)

        if cmd == "tee":
            for arg in positional:
                normalized = normalize_candidate(arg)
                if normalized:
                    seen.add(normalized)
            continue
        if cmd in write_dest_commands and positional:
            normalized = normalize_candidate(positional[-1])
            if normalized:
                seen.add(normalized)
            continue
        if cmd in write_all_path_commands:
            for arg in positional:
                normalized = normalize_candidate(arg)
                if normalized:
                    seen.add(normalized)
            continue
        if cmd in {"sed", "perl"} and any(arg == "-i" or arg.startswith("-i") for arg in args):
            for arg in reversed(args):
                if arg == "--" or arg.startswith("-"):
                    continue
                normalized = normalize_candidate(arg)
                if normalized:
                    seen.add(normalized)
                break

for path in sorted(seen):
    print(path)
PY
}

sb_shell_command_looks_read_only() {
  local command_str="${1:-}"

  python3 - "$command_str" <<'PY'
import pathlib
import re
import shlex
import sys

payload = sys.argv[1]

assignment_re = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=.*$")
redirect_re = re.compile(r'(^|[\s;|&])(?:>>|[0-9]?>)\s*(?:"([^"]+)"|\'([^\']+)\'|([^\s;|&]+))')
redirect_token_re = re.compile(r'^(?:[0-9]*>>?|&>>?)$')
read_only_commands = {
    "awk",
    "basename",
    "cat",
    "cut",
    "date",
    "dirname",
    "echo",
    "find",
    "grep",
    "head",
    "jq",
    "ls",
    "nl",
    "printf",
    "pwd",
    "readlink",
    "realpath",
    "rg",
    "sed",
    "sort",
    "stat",
    "tail",
    "test",
    "tr",
    "wc",
}
git_read_only_subcommands = {
    "branch",
    "config",
    "diff",
    "grep",
    "log",
    "ls-files",
    "remote",
    "rev-parse",
    "show",
    "status",
    "tag",
}
shell_names = {"bash", "sh", "zsh"}
stdout_redirect_commands = {"echo", "printf"}
test_command_names = {
    "jest",
    "mocha",
    "node",
    "npm",
    "npx",
    "pnpm",
    "tap",
    "vitest",
    "yarn",
}


def parse_tokens(segment: str):
    try:
        return shlex.split(segment, posix=True)
    except Exception:
        return None


def next_command(tokens):
    idx = 0
    if idx < len(tokens) and tokens[idx] == "env":
        idx += 1
    while idx < len(tokens) and assignment_re.match(tokens[idx]):
        idx += 1
    if idx >= len(tokens):
        return None, []
    return pathlib.Path(tokens[idx]).name, tokens[idx + 1 :]


def unwrap_shell_command(command_name, args):
    if command_name not in shell_names:
        return None
    for index, arg in enumerate(args):
        if arg.startswith("-") and "c" in arg[1:] and index + 1 < len(args):
            return args[index + 1]
    return None


def is_discard_redirect_target(target: str) -> bool:
    normalized = target.strip().strip('"').strip("'")
    return normalized in {"/dev/null", "NUL", "nul"} or normalized.endswith("/dev/null")


def segment_has_writing_redirect(segment: str) -> bool:
    for match in redirect_re.finditer(segment):
        target = match.group(2) or match.group(3) or match.group(4) or ""
        if not is_discard_redirect_target(target):
            return True
    return False


def arg_has_embedded_writing_redirect(arg: str) -> bool:
    if re.fullmatch(r">>?", arg):
        return False
    match = re.match(r"^(?:[1-9]\d*|&)?>>(.+)$", arg)
    if match is not None:
        return not is_discard_redirect_target(match.group(1))
    match = re.match(r"^(?:[1-9]\d*|&)?>(.+)$", arg)
    if match is not None:
        return not is_discard_redirect_target(match.group(1))
    return False


def split_shell_segments(line: str):
    segments = []
    current = []
    in_single = False
    in_double = False
    i = 0
    length = len(line)
    while i < length:
        ch = line[i]
        if in_single:
            current.append(ch)
            if ch == "'":
                in_single = False
            i += 1
            continue
        if in_double:
            current.append(ch)
            if ch == "\\" and i + 1 < length:
                current.append(line[i + 1])
                i += 2
                continue
            if ch == '"':
                in_double = False
            i += 1
            continue
        if ch == "'":
            in_single = True
            current.append(ch)
            i += 1
            continue
        if ch == '"':
            in_double = True
            current.append(ch)
            i += 1
            continue
        if i + 1 < length and line[i : i + 2] == "||":
            segments.append("".join(current).strip())
            current = []
            i += 2
            continue
        if i + 1 < length and line[i : i + 2] == "&&":
            segments.append("".join(current).strip())
            current = []
            i += 2
            continue
        if ch in ";|":
            segments.append("".join(current).strip())
            current = []
            i += 1
            continue
        if ch == "\n":
            segments.append("".join(current).strip())
            current = []
            i += 1
            continue
        current.append(ch)
        i += 1
    if current:
        segments.append("".join(current).strip())
    return [segment for segment in segments if segment and not segment.startswith("#")]


def has_tokenized_redirect(command_name, args):
    for index, arg in enumerate(args):
        if arg_has_embedded_writing_redirect(arg):
            return True
        if not redirect_token_re.fullmatch(arg):
            continue
        if index + 1 >= len(args):
            continue
        candidate = args[index + 1]
        if candidate == "--":
            continue
        if is_discard_redirect_target(candidate):
            continue
        prior_operands = [
            token for token in args[:index]
            if token != "--" and not token.startswith("-")
        ]
        if prior_operands or command_name in stdout_redirect_commands:
            return True
    return False


def first_non_option(args):
    idx = 0
    while idx < len(args):
        arg = args[idx]
        if arg in {"--"}:
            idx += 1
            break
        if arg in {"-C", "--prefix", "--cwd"} and idx + 1 < len(args):
            idx += 2
            continue
        if arg.startswith("-"):
            idx += 1
            continue
        break
    return idx if idx < len(args) else None


def looks_like_test_command(command_name, args):
    if command_name not in test_command_names:
        return False

    if command_name == "node":
        return any(arg == "--test" or arg.startswith("--test=") for arg in args)

    if command_name in {"jest", "mocha", "tap", "vitest"}:
        return True

    if command_name in {"npm", "pnpm"}:
        idx = first_non_option(args)
        if idx is None:
            return False
        subcmd = args[idx]
        if subcmd in {"test", "t"}:
            return True
        if subcmd == "run" and idx + 1 < len(args):
            script = args[idx + 1]
            return script == "test" or script.startswith("test:")
        if subcmd == "exec":
            exec_args = args[idx + 1 :]
            if exec_args and exec_args[0] == "--":
                exec_args = exec_args[1:]
            if not exec_args:
                return False
            return looks_like_test_command(pathlib.Path(exec_args[0]).name, exec_args[1:])
        return False

    if command_name == "yarn":
        idx = first_non_option(args)
        if idx is None:
            return False
        subcmd = args[idx]
        if subcmd in {"test", "jest", "vitest"}:
            return True
        if subcmd == "run" and idx + 1 < len(args):
            script = args[idx + 1]
            return script == "test" or script.startswith("test:")
        return False

    if command_name in {"npx"}:
        idx = first_non_option(args)
        if idx is None:
            return False
        return looks_like_test_command(pathlib.Path(args[idx]).name, args[idx + 1 :])

    return False


pending_chunks = [payload]
while pending_chunks:
    raw_line = pending_chunks.pop(0)
    stripped = raw_line.strip()
    if not stripped:
        continue

    tokens = parse_tokens(raw_line)
    if tokens:
        command_name, args = next_command(tokens)
        if command_name is not None:
            nested_command = unwrap_shell_command(command_name, args)
            if nested_command is not None:
                pending_chunks.insert(0, nested_command)
                continue

    for segment in split_shell_segments(raw_line):
        if segment_has_writing_redirect(segment):
            raise SystemExit(1)
        tokens = parse_tokens(segment)
        if not tokens:
            raise SystemExit(1)
        command_name, args = next_command(tokens)
        if command_name is None:
            continue
        nested_command = unwrap_shell_command(command_name, args)
        if nested_command is not None:
            pending_chunks.insert(0, nested_command)
            continue
        if has_tokenized_redirect(command_name, args):
            raise SystemExit(1)
        if command_name == "git":
            idx = 0
            while idx < len(args):
                arg = args[idx]
                if arg in {"-C", "-c"} and idx + 1 < len(args):
                    idx += 2
                    continue
                if arg.startswith("-"):
                    idx += 1
                    continue
                break
            if idx >= len(args) or args[idx] not in git_read_only_subcommands:
                raise SystemExit(1)
            continue
        if looks_like_test_command(command_name, args):
            continue
        if command_name == "sed":
            if any(arg == "-i" or arg.startswith("-i") for arg in args):
                raise SystemExit(1)
                continue
        if command_name not in read_only_commands:
            raise SystemExit(1)

print("read-only")
PY
}
