#!/usr/bin/env bash
# docs/TESTING.md and the coverage-campaign README cite the audited known limits by file and line.
# tests/coverage/known-limits.json is what sbcov.py validates, so the citations must match it.
set -euo pipefail
# shellcheck source=../lib/testlib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"

LIMITS="$TL_REPO_ROOT/tests/coverage/known-limits.json"

expected="$(jq -r '.entries[] | "\(.file | split("/")[-1]) \(.line)"' "$LIMITS" | sort -u)"

# docs/TESTING.md: "`<file>.sh` line N" or "`<file>.sh` lines N and M"
# (only files that have a known limit: the document also cites unrelated lines of other files)
cited="$(python3 - "$TL_REPO_ROOT/docs/TESTING.md" "$(cut -d' ' -f1 <<<"$expected" | sort -u | tr '\n' ' ')" <<'PY' | sort -u
import re, sys
text = open(sys.argv[1]).read()
known = set(sys.argv[2].split())
for m in re.finditer(r"`(?:[\w.-]+/)*([\w.-]+\.sh)` lines? (\d+)(?: and (\d+))?", text):
    if m.group(1) in known:
        for n in m.groups()[1:]:
            if n:
                print(m.group(1), n)
PY
)"
assert_eq "docs/TESTING.md cites exactly the known limits in known-limits.json" "$expected" "$cited"

# the campaign README's table: `hooks/lib/<file>.sh:N`
cited_readme="$(grep -oE '`[A-Za-z0-9_./-]+\.sh:[0-9]+`' "$TL_REPO_ROOT/docs/testing/coverage-campaign/README.md" | tr -d '`' |
  awk -F: '{n = split($1, p, "/"); print p[n], $2}' | sort -u)"
while read -r line; do
  [[ -n "$line" ]] || continue
  if grep -qxF "$line" <<<"$expected"; then
    tl_pass "campaign README citation '$line' is a known limit"
  else
    tl_fail "campaign README citation '$line' is not in known-limits.json"
  fi
done <<<"$cited_readme"
assert_match "the campaign README cites at least one known limit" '[0-9]' "$cited_readme"

tl_results
