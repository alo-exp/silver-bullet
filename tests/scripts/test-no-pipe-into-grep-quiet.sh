#!/usr/bin/env bash
# Guards against `printf ... | grep -q` / `echo ... | grep -q` in first-party Bash,
# tests included.
#
# grep -q (and -m) exits at the first match. bash's printf and echo write
# multi-line text one line per write(), so a writer still holding lines gets
# SIGPIPE, and under `set -o pipefail` the whole check reports "no match": a
# recorded skill looks missing, or a command gate silently skips. Feed grep a
# here-string instead: grep -q PATTERN <<<"$text".
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# A writer pipeline into a quiet/early-exit grep, on one line.
pattern='(printf|echo)[^|]*\|[[:space:]]*grep[[:space:]]+(-[a-zA-Z]*[qm][a-zA-Z]*|--quiet|--max-count)'

# The mechanism itself: with the match first and more lines than a pipe buffer
# holds, the pipeline fails under pipefail while the here-string form succeeds.
big="$(printf 'match\n'; printf 'line-%06d\n' $(seq 1 20000))"
rc=0
(set -o pipefail; printf '%s\n' "$big" | grep -q '^match$') || rc=$?
# 141 (SIGPIPE) normally; 1 (EPIPE write error) where SIGPIPE is ignored, as on CI runners.
assert_match "printf | grep -q fails under pipefail when grep exits early" '^(141|1)$' "$rc"
rc=0
grep -q '^match$' <<<"$big" || rc=$?
assert_eq "grep -q with a here-string succeeds" 0 "$rc"

offenders="$(cd "$TL_REPO_ROOT" &&
  git ls-files -- 'hooks/*' 'scripts/*' 'skills/*' 'site/*' 'tests/*' |
  while IFS= read -r f; do
    [[ -f "$f" && ! -L "$f" ]] || continue
    [[ "$f" == tests/scripts/test-no-pipe-into-grep-quiet.sh ]] && continue  # demonstrates the pattern
    case "$f" in
      *.sh | hooks/session-start | scripts/silver-bullet) ;;
      *) head -1 "$f" | grep -q 'bash' || continue ;;
    esac
    grep -nE "$pattern" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | sed "s|^|$f:|" || true
  done)"
if [[ -z "$offenders" ]]; then
  tl_pass "no printf/echo piped into grep -q or -m"
else
  tl_fail "printf/echo piped into grep -q/-m (use grep ... <<<\"\$text\"):
$offenders"
fi

# The replacement must keep one element per line: a here-string of "${arr[@]}"
# or "$@" joins the elements with spaces, so grep -x never matches.
joined="$(cd "$TL_REPO_ROOT" &&
  git ls-files -- 'hooks/*' 'scripts/*' 'skills/*' 'tests/*' |
  while IFS= read -r f; do
    [[ -f "$f" && ! -L "$f" && "$f" == *.sh ]] || continue
    grep -nE '<<<"(\$\{[A-Za-z_][A-Za-z0-9_]*\[@\]\}|\$@)"' "$f" | sed "s|^|$f:|" || true
  done)"
if [[ -z "$joined" ]]; then
  tl_pass "no here-string over an array or \$@"
else
  tl_fail "here-string over an array joins elements (use <<<\"\$(printf '%s\\n' \"\${arr[@]}\")\"):
$joined"
fi

tl_results
