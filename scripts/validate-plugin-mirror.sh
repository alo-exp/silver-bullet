#!/usr/bin/env bash
# Validate plugins/silver-bullet mirror matches source hooks/skills (P5).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
FAIL=0

check_file() {
  local rel="$1"
  local src="$REPO_ROOT/$rel"
  local dst="$REPO_ROOT/plugins/silver-bullet/$rel"
  if [[ ! -f "$src" ]]; then
    echo "MISSING source: $rel"
    FAIL=1
    return
  fi
  if [[ ! -f "$dst" ]]; then
    echo "DRIFT missing in plugin mirror: $rel"
    FAIL=1
    return
  fi
  if ! cmp -s "$src" "$dst"; then
    echo "DRIFT content mismatch: $rel"
    FAIL=1
    return
  fi
}

echo "Checking plugin mirror hooks..."
while IFS= read -r f; do
  rel="${f#"$REPO_ROOT/"}"
  check_file "$rel"
done < <(find "$REPO_ROOT/hooks" -type f \( -name '*.sh' -o -name 'session-start' -o -name 'core-rules.md' -o -name 'core-rules.sha256' -o -name 'hooks.json' \) ! -path '*/__pycache__/*' | sort)

# Spot-check critical orchestrator hooks and thinned composer plugin sources
for rel in \
  hooks/lib/orchestrator-state.sh \
  hooks/flow-advance.sh \
  hooks/orchestrator-directive-guard.sh \
  hooks/lib/orchestrator-directive.sh \
  scripts/workflows.sh; do
  check_file "$rel"
done

THINNED_COMPOSERS=(silver-feature silver-ui silver-devops silver-bugfix silver-research silver-release)
for composer in "${THINNED_COMPOSERS[@]}"; do
  src="$(sb_agent_bundle_root "$REPO_ROOT" codex)/${composer}/SKILL.md"
  dst="${REPO_ROOT}/plugins/silver-bullet/skill-source/${composer}/SILVER_SOURCE"
  if [[ ! -f "$src" ]]; then
    echo "MISSING codex bundle: host-bundles/codex/${composer}/SKILL.md"
    FAIL=1
    continue
  fi
  if [[ ! -f "$dst" ]]; then
    echo "DRIFT missing in plugin mirror: plugins/silver-bullet/skill-source/${composer}/SILVER_SOURCE"
    FAIL=1
    continue
  fi
  if ! cmp -s "$src" "$dst"; then
    echo "DRIFT content mismatch: plugins/silver-bullet/skill-source/${composer}/SILVER_SOURCE"
    FAIL=1
  fi
done

# Full skill-source parity is enforced by tests/scripts/test-render-agent-bundle-freshness.sh
# (all 85 skills). This script spot-checks hooks symlink parity + thinned composers only.

if [[ "$FAIL" -ne 0 ]]; then
  echo "::error::Plugin mirror drift detected — sync plugins/silver-bullet/ from source"
  exit 1
fi
echo "Plugin mirror OK"
exit 0
