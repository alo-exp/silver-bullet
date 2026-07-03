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
