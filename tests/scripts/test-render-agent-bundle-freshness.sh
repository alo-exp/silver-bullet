#!/usr/bin/env bash
# Fail when committed agents/* or skill-source/ diverge from render-agent-bundle.py output.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
RENDER="${REPO_ROOT}/scripts/render-agent-bundle.py"
PASS=0
FAIL=0

TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

for agent in claude codex cursor; do
  dest="${TMP_BASE}/${agent}"
  python3 "$RENDER" render --agent "$agent" --source-root "${REPO_ROOT}/skills" --dest-root "$dest" >/dev/null
  bundle_root="$(sb_agent_bundle_root "$REPO_ROOT" "$agent")"
  bundle_rel="$(sb_agent_bundle_rel "$agent")"

  while IFS= read -r rendered; do
    rel="${rendered#${dest}/}"
    committed="${bundle_root}/${rel}"
    if [[ ! -f "$committed" ]]; then
      echo "FAIL: missing committed ${bundle_rel}/${rel}"
      FAIL=$((FAIL + 1))
      continue
    fi
    if ! cmp -s "$rendered" "$committed"; then
      echo "FAIL: ${bundle_rel}/${rel} drift — run: bash scripts/sync-codex-package.sh"
      FAIL=$((FAIL + 1))
      continue
    fi
    PASS=$((PASS + 1))
  done < <(find "$dest" -type f -name 'SKILL.md' | sort)
done

# skill-source mirrors codex bundles
codex_dest="${TMP_BASE}/codex"
while IFS= read -r rendered; do
  rel="${rendered#${codex_dest}/}"
  skill_dir="${rel%/SKILL.md}"
  skill_name="${skill_dir##*/}"
  committed="${REPO_ROOT}/plugins/silver-bullet/skill-source/${skill_name}/SILVER_SOURCE"
  if [[ ! -f "$committed" ]]; then
    echo "FAIL: missing plugins/silver-bullet/skill-source/${skill_name}/SILVER_SOURCE"
    FAIL=$((FAIL + 1))
    continue
  fi
  if ! cmp -s "$rendered" "$committed"; then
    echo "FAIL: skill-source/${skill_name}/SILVER_SOURCE drift — run bash scripts/sync-codex-package.sh"
    FAIL=$((FAIL + 1))
    continue
  fi
  PASS=$((PASS + 1))
done < <(find "$codex_dest" -type f -name 'SKILL.md' | sort)

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
