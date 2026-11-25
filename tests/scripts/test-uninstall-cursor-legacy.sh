#!/usr/bin/env bash
# scripts/uninstall-cursor-legacy.sh: strip-only cleanup wrapper (the logic is covered by
# tests/python/test_uninstall_cursor_legacy.py).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
# shellcheck source=tests/lib/testlib.sh
source "${REPO_ROOT}/tests/lib/testlib.sh"
tl_init

SCRIPT="${REPO_ROOT}/scripts/uninstall-cursor-legacy.sh"
TMP="$TL_TMP"
CURSOR="${TMP}/.cursor"
mkdir -p "${CURSOR}/agents" "${CURSOR}/rules"
printf '{"hooks":{"stop":[{"command":"\\"/h/.cursor/plugins/cache/alo-labs/silver-bullet/1.0.0/hooks/cursor-hook-bridge.sh\\""},{"command":"/mine.sh"}]}}\n' >"${CURSOR}/hooks.json"
: >"${CURSOR}/agents/sb:plan.md"

echo "=== uninstall-cursor-legacy.sh ==="

out="$(CURSOR_HOME="$CURSOR" bash "$SCRIPT" --dry-run)"
assert_contains "dry run names the hooks update" "$out" "would update"
assert_contains "dry run keeps hooks.json" "$(cat "${CURSOR}/hooks.json")" "silver-bullet"
assert_eq "dry run keeps the agent" "1" "$(find "${CURSOR}/agents" -name 'sb:plan.md' | wc -l | tr -d ' ')"

out="$(bash "$SCRIPT" --cursor-home "$CURSOR")"
assert_contains "run reports the change" "$out" "Cursor legacy cleanup: 2 change(s)"
assert_eq "SB hook gone, user hook kept" '["/mine.sh"]' "$(jq -c '[.hooks.stop[].command]' "${CURSOR}/hooks.json")"
assert_eq "hooks backup exists" "1" "$(find "$CURSOR" -maxdepth 1 -name 'hooks.json.sb-backup' | wc -l | tr -d ' ')"
assert_eq "agent moved to the backup bucket" "0" "$(find "${CURSOR}/agents" -type f | wc -l | tr -d ' ')"

out="$(bash "$SCRIPT" --cursor-home "$CURSOR")"
assert_contains "second run is a no-op" "$out" "nothing Silver Bullet created"

out="$(bash "$SCRIPT" --cursor-home "${TMP}/absent")"
assert_contains "missing home is fine" "$out" "nothing to do"

# python3 missing: refuse with a clear message and change nothing.
NOPY="${TMP}/nopy"
mkdir -p "$NOPY"
for tool in bash dirname; do ln -s "$(command -v "$tool")" "${NOPY}/${tool}"; done
rc=0
err="$(PATH="$NOPY" "${NOPY}/bash" "$SCRIPT" 2>&1)" || rc=$?
assert_eq "no python3 exits 1" "1" "$rc"
assert_contains "no python3 message" "$err" "python3 is required"

tl_results
