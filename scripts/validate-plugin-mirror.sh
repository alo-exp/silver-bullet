#!/usr/bin/env bash
# Validate plugins/silver-bullet mirror matches source hooks/skills (P5).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

# Spot-check critical orchestrator hooks
for rel in hooks/flow-advance.sh hooks/orchestrator-directive-guard.sh hooks/lib/orchestrator-directive.sh scripts/workflows.sh; do
  check_file "$rel"
done

if [[ "$FAIL" -ne 0 ]]; then
  echo "::error::Plugin mirror drift detected — sync plugins/silver-bullet/ from source"
  exit 1
fi
echo "Plugin mirror OK"
exit 0
