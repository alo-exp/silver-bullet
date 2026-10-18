#!/usr/bin/env bash
# No executable default or operator doc may point at one developer's macOS home.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

cd "$TL_REPO_ROOT"
PERSONAL_HOME='/Users/shafqat'

# Files that quote the path as data (a path-leak detector, a Codex trust-config fixture, a
# recorded terminal capture) and so legitimately keep it.
ALLOWED_DATA=(
  ':!tests/scripts/test-no-personal-machine-paths.sh'
  ':!tests/scripts/test-codex-cli-isolation.sh'
  ':!tests/tui-contract/fixtures/*'
  ':!tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh'
)

hits="$(git grep -n -- "$PERSONAL_HOME" -- hooks scripts skills site templates Makefile tests "${ALLOWED_DATA[@]}" || true)"
assert_eq "no personal home in executable code" "" "$hits"

for doc in docs/ENTERPRISE-E2E-LIVE-TEST.md scripts/ENTERPRISE-E2E-OPERATOR-PROMPT.md docs/testing/MANUAL-E2E-SMOKE-TEST.md; do
  assert_eq "operator doc $doc has no personal home" "" "$(grep -n -- "$PERSONAL_HOME" "$doc" || true)"
  assert_contains "operator doc $doc defines <sb-repo>" "$(cat "$doc")" '<sb-repo>'
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
