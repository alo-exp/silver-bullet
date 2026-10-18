#!/usr/bin/env bash
# Guards against ANY `producer | grep -q` (also -m, --quiet, --max-count and
# combined flags such as -qE, -qx, -qiE, -qv) in first-party Bash, tests included.
#
# grep -q (and -m) exits at the first match. bash's printf and echo write
# multi-line text one line per write(), so a writer still holding lines gets
# SIGPIPE, and under `set -o pipefail` the whole check reports "no match": a
# recorded skill looks missing, or a command gate silently skips. Feed grep a
# here-string instead: grep -q PATTERN <<<"$text". For a command producer, use
# process substitution, whose exit status is ignored: grep -q PATTERN < <(cmd 2>&1).
#
# Detected: a single-line `cmd | grep <quiet/max flags>` (not `||`), and a line
# ending in a lone `|` followed by a line starting with `grep <quiet/max flags>`.
# Not detected (documented limit): a producer split across a here-doc or a `\`
# continuation whose `|` sits mid-line before a wrapped `grep`, `xargs grep -q`,
# `{ grep -q ...; }` groups, and flags placed after the pattern (`grep PAT -q`).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

# TEMPORARY allowlist: files other in-flight packages are editing right now and
# will fix themselves. Remove each entry when its owner lands the rewrite.
ALLOWLIST=(
  # E-core-hooks
  hooks/industry-tooling-hint.sh
  hooks/session-log-init.sh
  hooks/lib/quality-gates-mode.sh
  # H-recommended-1
  scripts/install-leanctx-sb.sh
  scripts/lib/recommended-tools/probe-alumnium.sh
  scripts/lib/recommended-tools/probe-leanctx.sh
  scripts/lib/recommended-tools/probe-rtk.sh
  # F-enterprise-2
  scripts/enterprise-e2e/live-test.sh
  scripts/enterprise-e2e/matrix.sh
)

# Any producer piped into a quiet/early-exit grep, on one line (a lone `|`, not `||`).
pattern='(^|[^|])\|[[:space:]]*grep[[:space:]]+(-[^[:space:]]+[[:space:]]+)*(-[a-zA-Z]*[qm][a-zA-Z0-9]*|--quiet|--max-count)'
# The same grep at the start of a line whose previous line ends in a lone `|`.
startpat='^[[:space:]]*grep[[:space:]]+(-[^[:space:]]+[[:space:]]+)*(-[a-zA-Z]*[qm][a-zA-Z0-9]*|--quiet|--max-count)'

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
      *) grep -q 'bash' < <(head -1 "$f") || continue ;;
    esac
    allowed=0
    for a in "${ALLOWLIST[@]}"; do [[ "$f" == "$a" ]] && allowed=1; done
    ((allowed)) && continue
    grep -nE "$pattern" "$f" | grep -vE '^[0-9]+:[[:space:]]*#' | sed "s|^|$f:|" || true
    awk -v sp="$startpat" -v f="$f" '
      /^[[:space:]]*#/ { prev = ""; next }
      $0 ~ sp && prev ~ /(^|[^|])\|[[:space:]]*$/ { print f ":" NR ":" $0 }
      { prev = $0 }' "$f"
  done)"
if [[ -z "$offenders" ]]; then
  tl_pass "no producer piped into grep -q or -m"
else
  tl_fail "producer piped into grep -q/-m (use grep ... <<<\"\$text\" or grep ... < <(cmd)):
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
