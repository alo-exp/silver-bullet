# shellcheck shell=bash
# Content searches for tests that do not depend on ripgrep.
#
# Several tests used `rg … || true` to look for forbidden text in generated
# trees. Where rg is not installed (GitHub's ubuntu runners) the command failed
# silently, every "must not contain" check passed and every audit report came
# out empty. These helpers use grep and python3 only, so a check finds the same
# matches on every machine.
#
#   sb_tree_contains <needle> <path>
#       True when <path> — a file, or a directory searched recursively — holds
#       the literal <needle>. Smart case like `rg -S`: a needle without capital
#       letters matches case-insensitively. Hidden files are searched; binary
#       files and symlinks below <path> are skipped (rg's defaults); a missing
#       <path> contains nothing.
#
#   sb_tree_grep [-i] [-F] [-g '!<glob>']... <pattern> <root>...
#       Prints <file>:<line>:<text> for each line matching <pattern> (a Python
#       regular expression; -F literal; -i ignore case) under the roots, which
#       are searched like sb_tree_contains plus .git directories skipped.
#       Missing roots are skipped. Each -g '!<glob>' excludes paths relative to
#       the root using rg's glob rules: `**/` spans directories, `*` and `?`
#       stay within one path segment, and a glob without `/` matches the file
#       name at any depth. Exit status is 0 whether or not anything matched.

sb_tree_contains() {
  local needle="$1" path="$2"
  local -a opts=(-r -I -q -s -F)
  [[ "$needle" == *[[:upper:]]* ]] || opts+=(-i)
  grep "${opts[@]}" -- "$needle" "$path"
}

sb_tree_grep() {
  python3 - "$@" <<'PY'
import os
import re
import sys

args = sys.argv[1:]
ignore_case = False
literal = False
globs = []
while args and args[0].startswith("-") and args[0] != "--":
    opt = args.pop(0)
    if opt == "-i":
        ignore_case = True
    elif opt == "-F":
        literal = True
    elif opt == "-g":
        glob = args.pop(0)
        if not glob.startswith("!"):
            raise SystemExit(f"sb_tree_grep: only exclusion globs are supported: {glob}")
        globs.append(glob[1:])
    else:
        raise SystemExit(f"sb_tree_grep: unknown option {opt}")
if args and args[0] == "--":
    args.pop(0)
if not args:
    raise SystemExit("usage: sb_tree_grep [-i] [-F] [-g '!glob']... <pattern> <root>...")
pattern, roots = args[0], args[1:]
flags = re.IGNORECASE if ignore_case else 0
regex = re.compile(re.escape(pattern) if literal else pattern, flags)


def glob_to_regex(glob):
    anchored = "/" in glob.rstrip("/")
    glob = glob.lstrip("/")
    out = []
    i = 0
    while i < len(glob):
        if glob.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
        elif glob.startswith("/**", i) and i + 3 == len(glob):
            out.append("(?:/.*)?")
            i += 3
        elif glob.startswith("**", i):
            out.append(".*")
            i += 2
        elif glob[i] == "*":
            out.append("[^/]*")
            i += 1
        elif glob[i] == "?":
            out.append("[^/]")
            i += 1
        else:
            out.append(re.escape(glob[i]))
            i += 1
    body = "".join(out)
    return re.compile(body if anchored else f"(?:.*/)?{body}")


excludes = [glob_to_regex(g) for g in globs]


def excluded(rel):
    return any(rx.fullmatch(rel) for rx in excludes)


def search(path, display):
    try:
        with open(path, "rb") as handle:
            data = handle.read()
    except OSError:
        return
    if b"\0" in data[:8192]:
        return
    for number, line in enumerate(data.decode("utf-8", "replace").splitlines(), 1):
        if regex.search(line):
            print(f"{display}:{number}:{line}")


for root in roots:
    if os.path.isfile(root) and not os.path.islink(root):
        search(root, root)
        continue
    if not os.path.isdir(root):
        continue
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(
            d for d in dirnames
            if d != ".git" and not os.path.islink(os.path.join(dirpath, d))
        )
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                continue
            rel = os.path.relpath(full, root)
            if excluded(rel):
                continue
            search(full, full)
PY
}
