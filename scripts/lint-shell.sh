#!/usr/bin/env bash
# lint-shell.sh — run ShellCheck over Silver Bullet's first-party Bash.
#
# Usage:
#   bash scripts/lint-shell.sh [--app|--tests|--all] [--list] [--jobs N] [-- <shellcheck args>]
#
#   --app    (default) application Bash at full severity: hooks/, scripts/,
#            skills/ and site/ — every tracked *.sh file plus extensionless
#            files whose shebang names bash (hooks/session-start,
#            scripts/silver-bullet, ...).
#   --tests  test Bash under tests/ at -S warning (info/style findings in
#            tests are tolerated).
#   --all    both of the above; exit status is non-zero if either fails.
#   --list   print the selected file list instead of running ShellCheck.
#   --jobs N parallel ShellCheck processes (default: CPU count; env
#            SB_LINT_SHELL_JOBS).
#   --       everything after is passed to shellcheck (e.g. -f gcc).
#
# Each file is checked by its own shellcheck process, so results never depend
# on which other files share an invocation (ShellCheck follows `source` only
# into files named on the same command line, which made one big invocation
# both order-dependent and very slow).
#
# Global excludes (kept deliberately narrow):
#   SC2317  command appears unreachable — false positives on trap handlers and
#           functions invoked indirectly (dispatch tables, "$@" runners).
#   SC2329  function is never invoked — same indirect-call false positives.
#   SC1091  not following sourced file — sources are resolved at runtime via
#           computed paths; ShellCheck is not run with -x.
#
# Exit status: 0 when clean, 1 when ShellCheck reports findings, 2 on usage or
# environment errors (shellcheck missing, no files found).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXCLUDES="SC2317,SC1091,SC2329"
APP_ROOTS=(hooks scripts skills site)
TEST_ROOTS=(tests)

usage() {
  sed -n '2,32p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

default_jobs() {
  local n=""
  n="$(getconf _NPROCESSORS_ONLN 2>/dev/null || true)"
  [[ "$n" =~ ^[1-9][0-9]*$ ]] || n=4
  printf '%s\n' "$n"
}

mode="app"
list_only=0
jobs="${SB_LINT_SHELL_JOBS:-}"
extra_args=()
while (($# > 0)); do
  case "$1" in
    --app) mode="app" ;;
    --tests) mode="tests" ;;
    --all) mode="all" ;;
    --list) list_only=1 ;;
    --jobs)
      if (($# < 2)); then
        printf 'lint-shell: --jobs needs a value\n' >&2
        exit 2
      fi
      jobs="$2"
      shift
      ;;
    --jobs=*) jobs="${1#--jobs=}" ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      shift
      extra_args=("$@")
      break
      ;;
    *)
      printf 'lint-shell: unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

[[ -n "$jobs" ]] || jobs="$(default_jobs)"
if ! [[ "$jobs" =~ ^[1-9][0-9]*$ ]]; then
  printf 'lint-shell: --jobs needs a positive integer, got: %s\n' "$jobs" >&2
  exit 2
fi

# tracked_files <root>... — NUL-separated list of tracked files under the roots.
# Falls back to find(1) outside a git checkout (e.g. a source tarball).
tracked_files() {
  if git -C "$REPO_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$REPO_ROOT" ls-files -z -- "$@"
  else
    (cd "$REPO_ROOT" && find "$@" -type f -print0 2>/dev/null) || true
  fi
}

# is_bash_file <path> — *.sh, or an extensionless file with a bash shebang.
is_bash_file() {
  local path="$1" base first_line=""
  [[ -f "$REPO_ROOT/$path" && ! -L "$REPO_ROOT/$path" ]] || return 1
  [[ "$path" == *.sh ]] && return 0
  base="${path##*/}"
  [[ "$base" == *.* ]] && return 1
  IFS= read -r first_line <"$REPO_ROOT/$path" || true
  [[ "$first_line" == '#!'*bash* ]]
}

# collect <roots...> — print matching repo-relative paths, one per line.
collect() {
  local path
  while IFS= read -r -d '' path; do
    if is_bash_file "$path"; then
      printf '%s\n' "$path"
    fi
  done < <(tracked_files "$@")
}

# check_bucket <outdir> <bucket> <nbuckets> <file...> — check every file whose
# index falls in this bucket, one shellcheck process per file.
check_bucket() {
  local outdir="$1" bucket="$2" nbuckets="$3"
  shift 3
  local idx=0 rc path
  for path in "$@"; do
    if ((idx % nbuckets == bucket)); then
      rc=0
      (cd "$REPO_ROOT" && shellcheck "${sc_args[@]}" "$path") >"$outdir/$idx.out" 2>&1 || rc=$?
      printf '%s\n' "$rc" >"$outdir/$idx.rc"
    fi
    idx=$((idx + 1))
  done
}

run_shellcheck() {
  local label="$1" severity="$2"
  shift 2
  local files=() path
  while IFS= read -r path; do
    files+=("$path")
  done < <(collect "$@" | LC_ALL=C sort -u)

  if ((${#files[@]} == 0)); then
    printf 'lint-shell: no %s files found\n' "$label" >&2
    return 2
  fi

  if ((list_only)); then
    printf '%s\n' "${files[@]}"
    return 0
  fi

  sc_args=(--exclude="$EXCLUDES")
  if [[ -n "$severity" ]]; then
    sc_args+=(-S "$severity")
  fi
  if ((${#extra_args[@]} > 0)); then
    sc_args+=("${extra_args[@]}")
  fi

  local nbuckets="$jobs"
  ((nbuckets <= ${#files[@]})) || nbuckets=${#files[@]}
  printf 'lint-shell: %s — %d files%s, %d jobs\n' "$label" "${#files[@]}" \
    "${severity:+ (severity >= $severity)}" "$nbuckets" >&2

  local outdir bucket pids=() rc=0 idx file_rc failed=0
  outdir="$(mktemp -d "${TMPDIR:-/tmp}/sb-lint-shell.XXXXXX")"
  for ((bucket = 0; bucket < nbuckets; bucket++)); do
    check_bucket "$outdir" "$bucket" "$nbuckets" "${files[@]}" &
    pids+=("$!")
  done
  for bucket in "${pids[@]}"; do
    wait "$bucket" || rc=2
  done

  for ((idx = 0; idx < ${#files[@]}; idx++)); do
    if [[ -f "$outdir/$idx.out" ]]; then
      cat "$outdir/$idx.out"
    fi
    file_rc="$(cat "$outdir/$idx.rc" 2>/dev/null || echo 2)"
    if [[ "$file_rc" != "0" ]]; then
      failed=$((failed + 1))
    fi
  done
  rm -rf "$outdir"

  if ((rc != 0)); then
    printf 'lint-shell: %s — a worker failed unexpectedly\n' "$label" >&2
    return 2
  fi
  if ((failed > 0)); then
    printf 'lint-shell: %s — %d file(s) with findings\n' "$label" "$failed" >&2
    return 1
  fi
  printf 'lint-shell: %s clean\n' "$label" >&2
  return 0
}

if ! ((list_only)) && ! command -v shellcheck >/dev/null 2>&1; then
  printf 'lint-shell: shellcheck not found on PATH (apt-get install shellcheck / brew install shellcheck)\n' >&2
  exit 2
fi

sc_args=()
status=0
case "$mode" in
  app) run_shellcheck "application Bash" "" "${APP_ROOTS[@]}" || status=$? ;;
  tests) run_shellcheck "test Bash" "warning" "${TEST_ROOTS[@]}" || status=$? ;;
  all)
    run_shellcheck "application Bash" "" "${APP_ROOTS[@]}" || status=$?
    test_status=0
    run_shellcheck "test Bash" "warning" "${TEST_ROOTS[@]}" || test_status=$?
    if ((test_status > status)); then
      status=$test_status
    fi
    ;;
esac
exit "$status"
