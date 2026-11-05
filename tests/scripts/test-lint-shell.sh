#!/usr/bin/env bash
# Tests for scripts/lint-shell.sh with a stubbed shellcheck: file selection, the
# --app/--tests/--all modes, exit codes and the job fan-out, on a scratch checkout.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
export TMPDIR="$TL_TMP/tmp"
mkdir -p "$TMPDIR"

# A scratch repository holding a copy of the script, so REPO_ROOT is the scratch tree.
make_repo() {
  local dir="$1"
  mkdir -p "$dir/scripts" "$dir/hooks" "$dir/skills/x" "$dir/site" "$dir/tests/sub"
  cp "$TL_REPO_ROOT/scripts/lint-shell.sh" "$dir/scripts/lint-shell.sh"
  printf '#!/usr/bin/env bash\ntrue\n' >"$dir/hooks/a.sh"
  printf '#!/usr/bin/env bash\ntrue\n' >"$dir/hooks/session-start"
  printf '#!/bin/sh\ntrue\n' >"$dir/hooks/posix-tool"
  printf '#!/usr/bin/env bash\ntrue\n' >"$dir/hooks/tool.bash"
  printf 'plain text\n' >"$dir/hooks/notes.txt"
  printf '#!/usr/bin/env bash\ntrue\n' >"$dir/skills/x/run.sh"
  printf '#!/usr/bin/env bash\ntrue\n' >"$dir/site/s.sh"
  printf '#!/usr/bin/env bash\ntrue\n' >"$dir/tests/t.sh"
  printf '#!/usr/bin/env bash\ntrue\n' >"$dir/tests/sub/u.sh"
  : >"$dir/hooks/empty-tool"
  ln -s a.sh "$dir/hooks/link.sh"
  mkdir -p "$dir/scripts/lib.sh"
}

REPO="$TL_TMP/repo"
make_repo "$REPO"
git -C "$REPO" init -q -b main
git -C "$REPO" add -A
LINT="$REPO/scripts/lint-shell.sh"

# --- file selection (git checkout) ---------------------------------------------------------
tl_run bash "$LINT" --list
assert_eq "--list exits 0" 0 "$TL_STATUS"
assert_contains "app: .sh file listed" "$TL_OUT" "hooks/a.sh"
assert_contains "app: extensionless bash shebang listed" "$TL_OUT" "hooks/session-start"
assert_contains "app: skills listed" "$TL_OUT" "skills/x/run.sh"
assert_contains "app: site listed" "$TL_OUT" "site/s.sh"
assert_contains "app: script itself listed" "$TL_OUT" "scripts/lint-shell.sh"
assert_not_contains "app: sh shebang excluded" "$TL_OUT" "posix-tool"
assert_not_contains "app: dotted non-.sh excluded" "$TL_OUT" "tool.bash"
assert_not_contains "app: empty extensionless file excluded" "$TL_OUT" "empty-tool"
assert_not_contains "app: text excluded" "$TL_OUT" "notes.txt"
assert_not_contains "app: symlink excluded" "$TL_OUT" "link.sh"
assert_not_contains "app: directory named .sh excluded" "$TL_OUT" "lib.sh"
assert_not_contains "app: tests excluded" "$TL_OUT" "tests/t.sh"

tl_run bash "$LINT" --tests --list
assert_contains "tests: nested file listed" "$TL_OUT" "tests/sub/u.sh"
assert_not_contains "tests: app files excluded" "$TL_OUT" "hooks/a.sh"

tl_run bash "$LINT" --app --list
assert_contains "--app is the default selection" "$TL_OUT" "hooks/a.sh"

# --list works without shellcheck on PATH.
tl_run env PATH="$(tl_path_without shellcheck)" bash "$LINT" --list
assert_eq "--list needs no shellcheck" 0 "$TL_STATUS"

# --- help and usage errors -----------------------------------------------------------------
tl_run bash "$LINT" --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help prints usage" "$TL_OUT" "lint-shell.sh [--app|--tests|--all]"

tl_run bash "$LINT" -h
assert_eq "-h exits 0" 0 "$TL_STATUS"

tl_run bash "$LINT" --bogus
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "unknown argument named" "$TL_ERR" "unknown argument: --bogus"
assert_contains "unknown argument prints usage" "$TL_ERR" "Usage:"

tl_run bash "$LINT" --jobs
assert_eq "--jobs without value exits 2" 2 "$TL_STATUS"
assert_contains "--jobs without value message" "$TL_ERR" "--jobs needs a value"

tl_run bash "$LINT" --jobs=0 --list
assert_eq "--jobs=0 exits 2" 2 "$TL_STATUS"
assert_contains "--jobs=0 message" "$TL_ERR" "positive integer, got: 0"

tl_run bash "$LINT" --jobs abc --list
assert_eq "--jobs abc exits 2" 2 "$TL_STATUS"

tl_run env SB_LINT_SHELL_JOBS=x bash "$LINT" --list
assert_eq "bad SB_LINT_SHELL_JOBS exits 2" 2 "$TL_STATUS"

# --- shellcheck missing --------------------------------------------------------------------
tl_run env PATH="$(tl_path_without shellcheck)" bash "$LINT"
assert_eq "missing shellcheck exits 2" 2 "$TL_STATUS"
assert_contains "missing shellcheck message" "$TL_ERR" "shellcheck not found on PATH"

# --- running with a stub shellcheck ----------------------------------------------------------
CALLS="$TL_TMP/calls.log"
tl_stub shellcheck 'printf "%s|%s\n" "$PWD" "$*" >>"'"$CALLS"'"
last="${@: -1}"
case "$last" in
  *a.sh) echo "finding in $last"; exit 1 ;;
esac
exit 0'

: >"$CALLS"
tl_run bash "$LINT" --jobs 2
assert_eq "findings: exit 1" 1 "$TL_STATUS"
assert_contains "findings output relayed" "$TL_OUT" "finding in hooks/a.sh"
assert_contains "findings summary" "$TL_ERR" "application Bash — 1 file(s) with findings"
assert_contains "job count reported" "$TL_ERR" "5 files, 2 jobs"
assert_contains "app mode: no severity flag" "$(cat "$CALLS")" "|--exclude=SC2317,SC1091,SC2329 hooks/"
assert_not_contains "app mode: no -S" "$(cat "$CALLS")" "-S warning"
assert_contains "runs from repo root" "$(cat "$CALLS")" "$REPO|"
assert_eq "one shellcheck process per file" 5 "$(wc -l <"$CALLS" | tr -d ' ')"

# More jobs than files is capped at the file count.
tl_run bash "$LINT" --tests --jobs 9
assert_eq "tests mode clean: exit 0" 0 "$TL_STATUS"
assert_contains "buckets capped to file count" "$TL_ERR" "2 files (severity >= warning), 2 jobs"
assert_contains "clean message" "$TL_ERR" "test Bash clean"

# extra shellcheck args after --
: >"$CALLS"
tl_run bash "$LINT" --tests --jobs=1 -- -f gcc
assert_eq "extra args: exit 0" 0 "$TL_STATUS"
assert_contains "extra args forwarded" "$(cat "$CALLS")" "-S warning -f gcc tests/"

# default job count comes from getconf, else 4
tl_stub getconf 'echo 3'
tl_run bash "$LINT" --tests
assert_contains "default jobs from getconf" "$TL_ERR" "2 jobs"
tl_stub getconf 'exit 1'
tl_run bash "$LINT" --app
assert_contains "default jobs fall back to 4" "$TL_ERR" "5 files, 4 jobs"
rm -f "$TL_BIN/getconf"

# --all: worst status wins, both sections run
tl_run bash "$LINT" --all --jobs 2
assert_eq "--all: app findings -> 1" 1 "$TL_STATUS"
assert_contains "--all runs app section" "$TL_ERR" "application Bash"
assert_contains "--all runs test section" "$TL_ERR" "test Bash clean"

# --all: test failure while app is clean keeps the higher status
tl_stub shellcheck 'last="${@: -1}"; case "$last" in tests/*) echo "bad $last"; exit 1;; esac; exit 0'
tl_run bash "$LINT" --all --jobs 2
assert_eq "--all: test findings -> 1" 1 "$TL_STATUS"
assert_contains "--all: app clean" "$TL_ERR" "application Bash clean"
assert_contains "--all: test findings" "$TL_ERR" "test Bash — 2 file(s) with findings"

# a worker killed mid-run (the child of the main script that runs the stub) is
# reported as an unexpected failure, and its missing result counts as a failed file.
# The stub walks up from its own parent to the child of the main script, with a bound,
# and exits 3 (never loops) when it cannot find it.
if [[ -r /proc/self/stat ]] || ps -o ppid= -p $$ >/dev/null 2>&1; then
  MAINPID="$TL_TMP/main.pid"
  tl_stub shellcheck 'ppid_of() {
  if [[ -r /proc/$1/stat ]]; then awk "{print \$4}" "/proc/$1/stat"; else ps -o ppid= -p "$1" | tr -d " "; fi
}
main="$(cat "'"$MAINPID"'")"
pid=$PPID
for _ in 1 2 3 4 5 6 7 8; do
  [[ -n "$pid" && "$pid" -gt 1 ]] || exit 3
  parent="$(ppid_of "$pid")"
  if [[ "$parent" == "$main" ]]; then kill -KILL "$pid"; exit 0; fi
  pid="$parent"
done
exit 3'
  tl_run bash -c 'echo $$ >"$1"; shift; exec "$@"' _ "$MAINPID" bash "$LINT" --tests --jobs 1
  assert_eq "killed worker: exit 2" 2 "$TL_STATUS"
  assert_contains "killed worker message" "$TL_ERR" "a worker failed unexpectedly"
else
  echo "SKIP: killed-worker case needs /proc or ps"
fi

# the scratch output directory is removed after normal runs and failure paths
shopt -s nullglob
leftovers=("$TMPDIR"/sb-lint-shell.*)
shopt -u nullglob
assert_eq "no sb-lint-shell.* directories left in TMPDIR" 0 "${#leftovers[@]}"

# --- no files found --------------------------------------------------------------------------
EMPTY="$TL_TMP/empty"
mkdir -p "$EMPTY/scripts"
cp "$TL_REPO_ROOT/scripts/lint-shell.sh" "$EMPTY/scripts/lint-shell.sh"
git -C "$EMPTY" init -q -b main
tl_run bash "$EMPTY/scripts/lint-shell.sh"
assert_eq "no files: exit 2" 2 "$TL_STATUS"
assert_contains "no files message" "$TL_ERR" "no application Bash files found"

# --- outside a git checkout: find(1) fallback ---------------------------------------------------
TAR="$TL_TMP/tarball"
make_repo "$TAR"
tl_run bash "$TAR/scripts/lint-shell.sh" --list
assert_eq "no git: exit 0" 0 "$TL_STATUS"
assert_contains "no git: .sh found" "$TL_OUT" "hooks/a.sh"
assert_contains "no git: shebang file found" "$TL_OUT" "hooks/session-start"
assert_not_contains "no git: symlink excluded" "$TL_OUT" "link.sh"

# find fallback with a root that does not exist yields no files rather than an error
BARE="$TL_TMP/bare"
mkdir -p "$BARE/scripts"
cp "$TL_REPO_ROOT/scripts/lint-shell.sh" "$BARE/scripts/lint-shell.sh"
tl_run bash "$BARE/scripts/lint-shell.sh" --tests
assert_eq "no git, no roots: exit 2" 2 "$TL_STATUS"
assert_contains "no git, no roots message" "$TL_ERR" "no test Bash files found"

tl_results
