#!/usr/bin/env bash
# No executable default or operator doc may point at one developer's macOS home.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

cd "$TL_REPO_ROOT"
# R13-11: no tracked text file (code, docs, .planning, research, .agentmemory) holds a personal
# home-directory path or an email address outside the allowlist. The invariant never prints the
# value it found, so a failure names only file and line.
hits="$(python3 scripts/lib/repo_invariants.py personal-data . || true)"
assert_eq "no personal paths or foreign emails in tracked files" "" "$hits"

for doc in docs/ENTERPRISE-E2E-LIVE-TEST.md scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md docs/testing/MANUAL-E2E-SMOKE-TEST.md; do
  assert_contains "operator doc $doc defines <sb-repo>" "$(cat "$doc")" '<sb-repo>'
done

# The private files stay out of the tree and out of future commits.
for gone in SETUP_REPORT.md .planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/CLAUDE-QUOTA.md; do
  assert_eq "$gone is not tracked" "" "$(git ls-files -- "$gone")"
done
assert_eq "no AI session transcripts (.err) are tracked" "" "$(git ls-files -- '*.err')"
assert_eq "no planning run logs are tracked" "" "$(git ls-files -- '.planning/**/*.log' 'research/**/*.log')"
for pattern in SETUP_REPORT.md x.err .planning/a/run.log research/a/run.log .planning/a/CLAUDE-QUOTA.md; do
  assert_eq ".gitignore covers $pattern" "0" "$(git check-ignore -q -- "$pattern" && echo 0 || echo 1)"
done

# hosts.json: test_app_root must be portable (relative to the SB checkout), never absolute.
abs_roots="$(jq -r '.hosts | to_entries[] | select((.value.test_app_root // "") | startswith("/")) | .key' scripts/enterprise-e2e/config/hosts.json)"
assert_eq "hosts.json has no absolute test_app_root" "" "$abs_roots"

# live claude adapter: no claude on PATH and no CLAUDE_BIN -> bare name, so the preflight
# reports a clear "not found" instead of probing someone's macOS home.
out="$(env -u CLAUDE_BIN PATH="/usr/bin:/bin" bash -c '
  command -v claude >/dev/null 2>&1 && exit 3
  source tests/live/agents/claude/agent.sh; agent_cli_path')" || out="SKIP"
if [[ "$out" == "SKIP" ]]; then
  echo "SKIP: claude present in /usr/bin:/bin"
else
  assert_eq "agent_cli_path falls back to bare command name" "claude" "$out"
fi

tl_results
