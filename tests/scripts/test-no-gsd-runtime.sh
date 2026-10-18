#!/usr/bin/env bash
# Assert GSD lifecycle namespace is fully removed from SB runtime surfaces.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  ok: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "[no-gsd-runtime]"

if [[ -f "$REPO_ROOT/hooks/lib/legacy-skill-alias.sh" ]]; then
  fail "legacy-skill-alias.sh must not exist"
else
  pass "legacy-skill-alias.sh absent"
fi

scenario_count="$(find "$REPO_ROOT/tests/skill-scenarios" -maxdepth 1 -name 'gsd-*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "$scenario_count" -ne 0 ]]; then
  fail "gsd-* skill scenarios must be deleted (found $scenario_count)"
else
  pass "no gsd-* skill scenarios"
fi

# scan_gsd DIR...: every gsd- / gsd: reference in .sh, .md and .json files under DIR.
# grep, not rg: rg is not installed on every runner, and a missing scanner must not read
# as "no references".
scan_gsd() {
  grep -rnE 'gsd[-:]' --include='*.sh' --include='*.md' --include='*.json' "$@" || true
}

canary="$(mktemp -d)"
trap 'rm -rf "$canary"' EXIT
printf 'route gsd-canary\n' >"$canary/probe.sh"
if [[ "$(scan_gsd "$canary")" == *gsd-canary* ]]; then
  pass "scanner finds a planted gsd reference"
else
  fail "scanner finds a planted gsd reference"
fi

violations="$(scan_gsd \
  "$REPO_ROOT/hooks" \
  "$REPO_ROOT/skills" \
  "$REPO_ROOT/scripts" \
  "$REPO_ROOT/templates" \
  "$REPO_ROOT/tests/hooks" \
  "$REPO_ROOT/tests/scripts")"

if [[ -n "$violations" ]]; then
  # Allow denylist/migration references and the research-only competitor registry.
  # The category-pack URL is discovery data; it is not a runtime dependency or route.
  # test-orchestrator-event-log-lib.sh asserts the legacy gsd-* name still resolves.
  # test-prune-stale-claude-user-hooks.sh and test-misc1-migrations.sh assert that the legacy
  # hooks and tracker value are pruned / migrated, so they must name them literally.
  unexpected="$(printf '%s\n' "$violations" | grep -vE 'hooks/forbidden-skill-check\.sh|tests/hooks/test-orchestrator-event-log-lib\.sh|tests/scripts/test-no-gsd-runtime\.sh|scripts/prune-stale-claude-user-hooks\.sh|tests/scripts/test-prune-stale-claude-user-hooks\.sh|tests/scripts/test-misc1-migrations\.sh|scripts/watch-enterprise-e2e-tui\.sh|scripts/agent-claude/lib\.sh|skills/silver-deep-research/reference/landscape/category-packs/agentic-sdlc-process-orchestrator\.json' || true)"
  if [[ -n "$unexpected" ]]; then
    fail "unexpected gsd refs outside forbidden-skill denylist"
    printf '%s\n' "$unexpected" | sed 's/^/    /'
  else
    pass "gsd refs limited to forbidden-skill denylist"
  fi
else
  pass "no gsd refs in runtime surfaces"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
