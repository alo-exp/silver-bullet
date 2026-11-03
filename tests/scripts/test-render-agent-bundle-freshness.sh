#!/usr/bin/env bash
# Fail when a committed host bundle or hidden skill-source tree differs from a
# fresh render-agent-bundle.py run. Every file is compared in both directions,
# so a stale reference, a missing file and an extra (stale) skill directory all
# fail. scripts/validate-plugin-mirror.sh covers the rest of the package
# (templates, hooks, links).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
RENDER="${REPO_ROOT}/scripts/render-agent-bundle.py"
PASS=0
FAIL=0

TMP_BASE="$(mktemp -d)"
trap 'rm -rf "$TMP_BASE"' EXIT

# same_entry <a> <b>: identical regular files. The renderers write no symlinks, so
# a symlink on either side (one smuggled into a generated tree) is drift.
same_entry() {
  if [[ -L "$1" || -L "$2" ]]; then
    return 1
  fi
  cmp -s "$1" "$2"
}

list_files() {
  if [[ -d "$1" ]]; then
    (cd "$1" && find . ! -type d ! -name '*.render.lock' ! -path '*/__pycache__/*' | sed 's|^\./||')
  fi
}

# check_tree <label> <committed-root> <fresh-root>
check_tree() {
  local label="$1" committed="$2" fresh="$3" rel
  while IFS= read -r rel; do
    if same_entry "${committed}/${rel}" "${fresh}/${rel}"; then
      PASS=$((PASS + 1))
    else
      echo "FAIL: ${label}/${rel} drift — run: bash scripts/sync-codex-package.sh"
      FAIL=$((FAIL + 1))
    fi
  done < <({ list_files "$committed"; list_files "$fresh"; } | sort -u)
}

for agent in claude codex; do
  python3 "$RENDER" render --agent "$agent" --source-root "${REPO_ROOT}/skills" --dest-root "${TMP_BASE}/${agent}" >/dev/null
  check_tree "$(sb_agent_bundle_rel "$agent")" "$(sb_agent_bundle_root "$REPO_ROOT" "$agent")" "${TMP_BASE}/${agent}"
done

for pair in codex:skill-source; do
  agent="${pair%%:*}"
  tree="${pair#*:}"
  python3 "$RENDER" render --agent "$agent" --layout source --source-root "${REPO_ROOT}/skills" \
    --dest-root "${TMP_BASE}/${tree}" >/dev/null
  check_tree "plugins/silver-bullet/${tree}" "${REPO_ROOT}/plugins/silver-bullet/${tree}" "${TMP_BASE}/${tree}"
done

echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
