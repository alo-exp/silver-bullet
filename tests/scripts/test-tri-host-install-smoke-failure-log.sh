#!/usr/bin/env bash
# run-tri-host-install-smoke.sh: a failing step prints the tail of its log, so a
# CI failure is diagnosable after the temp log is gone.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

TREE="$TL_TMP/tree"
mkdir -p "$TREE/scripts/lib"
cp "$TL_REPO_ROOT/scripts/run-tri-host-install-smoke.sh" "$TREE/scripts/"
cp "$TL_REPO_ROOT/scripts/lib/command-timeout.sh" "$TREE/scripts/lib/"

# Installer that fails after printing more lines than the tail keeps.
cat >"$TREE/scripts/install-cursor.sh" <<'EOF'
#!/usr/bin/env bash
for i in $(seq 1 60); do echo "installer line $i"; done
echo "fatal: simulated clone failure" >&2
exit 7
EOF

tl_run env RTK_DISABLED=1 SB_TRIHOST_OVERALL_TIMEOUT=60 SB_TRIHOST_CMD_TIMEOUT=30 \
  bash "$TREE/scripts/run-tri-host-install-smoke.sh" --host cursor
assert_eq "failing installer fails the smoke" 1 "$TL_STATUS"
assert_contains "failure names the step and rc" "$TL_ERR" "cursor: install-cursor.sh failed (rc=7)"
assert_contains "installer stderr is shown" "$TL_ERR" "fatal: simulated clone failure"
assert_contains "last installer stdout lines are shown" "$TL_ERR" "installer line 60"
assert_not_contains "output is limited to the log tail" "$TL_ERR" $'installer line 20\n'
assert_contains "summary still counts the failure" "$TL_OUT" "1 failed"

# A passing step prints no log.
cat >"$TREE/scripts/install-cursor.sh" <<'EOF'
#!/usr/bin/env bash
echo "installer ok"
exit 0
EOF
tl_run env RTK_DISABLED=1 SB_TRIHOST_OVERALL_TIMEOUT=60 SB_TRIHOST_CMD_TIMEOUT=30 \
  bash "$TREE/scripts/run-tri-host-install-smoke.sh" --host cursor
assert_contains "passing installer is reported" "$TL_OUT" "PASS: cursor: install-cursor.sh"
assert_not_contains "passing installer log is not printed" "$TL_OUT$TL_ERR" "installer ok"

tl_results
