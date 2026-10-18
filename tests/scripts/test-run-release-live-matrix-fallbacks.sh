#!/usr/bin/env bash
# run-release-live-matrix.sh dispatch order (override script, bundled live matrix, none) and
# verify-tests marker restore. The script is staged in a temp tree so the real live suites
# can never run; every launched command is a stub.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

stage() { # <dir>: staged repo with a byte-identical script copy
  local d="$1"
  mkdir -p "$d/scripts" "$d/hooks/lib"
  cp "$TL_REPO_ROOT/scripts/run-release-live-matrix.sh" "$d/scripts/"
  cp "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$d/hooks/lib/"
}
marker() { printf '%s/verify-tests-state' "$SB_RUNTIME_STATE_DIR"; }
write_marker() { printf 'verified_at=x\n' >"$(marker)"; }
run_matrix() { # <staged dir> [env...]
  local d="$1"; shift
  tl_run env "$@" bash "$d/scripts/run-release-live-matrix.sh"
}

# 0. a configured command wins over every script and runs from the repo root
S0="$TL_TMP/s0"; stage "$S0"
mkdir -p "$S0/tests/live"
printf '#!/usr/bin/env bash\necho bundled >>"%s"\n' "$TL_TMP/s0.log" >"$S0/tests/live/run-live-tests.sh"; chmod +x "$S0/tests/live/run-live-tests.sh"
write_marker
run_matrix "$S0" HOME="$HOME" SILVER_BULLET_RUNTIME="$SILVER_BULLET_RUNTIME" SB_RELEASE_LIVE_MATRIX_CMD='echo configured-ran-in-$PWD'
assert_eq "configured command exits 0" 0 "$TL_STATUS"
assert_contains "configured command announced" "$TL_OUT" "Running configured command: echo configured-ran-in-"
assert_contains "configured command ran from the repo root" "$TL_OUT" "configured-ran-in-$S0"
assert_file_absent "bundled matrix not run when a command is configured" "$TL_TMP/s0.log"
write_marker
run_matrix "$S0" HOME="$HOME" SILVER_BULLET_RUNTIME="$SILVER_BULLET_RUNTIME" SB_RELEASE_LIVE_MATRIX_CMD='exit 9'
assert_eq "configured command failure propagates" 9 "$TL_STATUS"
assert_file_exists "marker restored after configured command failure" "$(marker)"

# 1. override script is preferred over the bundled matrix
S1="$TL_TMP/s1"; stage "$S1"
mkdir -p "$S1/tests/live"
cat >"$S1/scripts/release-live-matrix.sh" <<EOS
#!/usr/bin/env bash
echo "override ran in \$PWD" >>'$TL_TMP/dispatch.log'
rm -f '$(marker)'
exit 0
EOS
chmod +x "$S1/scripts/release-live-matrix.sh"
cat >"$S1/tests/live/run-live-tests.sh" <<EOS
#!/usr/bin/env bash
echo "bundled ran" >>'$TL_TMP/dispatch.log'
EOS
chmod +x "$S1/tests/live/run-live-tests.sh"
write_marker
run_matrix "$S1" HOME="$HOME" SILVER_BULLET_RUNTIME="$SILVER_BULLET_RUNTIME" SB_RELEASE_LIVE_MATRIX_CMD=
assert_eq "override script exits 0" 0 "$TL_STATUS"
assert_contains "override script announced" "$TL_OUT" "Running repo-local override script: $S1/scripts/release-live-matrix.sh"
assert_eq "only the override ran" "override ran in $S1" "$(cat "$TL_TMP/dispatch.log")"
assert_file_exists "marker restored after override deleted it" "$(marker)"
assert_eq "marker content restored" "verified_at=x" "$(cat "$(marker)")"

# 2. no override: bundled live matrix runs
rm -f "$S1/scripts/release-live-matrix.sh" "$TL_TMP/dispatch.log"
write_marker
run_matrix "$S1" HOME="$HOME" SILVER_BULLET_RUNTIME="$SILVER_BULLET_RUNTIME" SB_RELEASE_LIVE_MATRIX_CMD=
assert_eq "bundled matrix exits 0" 0 "$TL_STATUS"
assert_contains "bundled matrix announced" "$TL_OUT" "Running bundled live matrix: $S1/tests/live/run-live-tests.sh"
assert_eq "only bundled ran" "bundled ran" "$(cat "$TL_TMP/dispatch.log")"

# 3. nothing configured: error, exit 1, marker still restored
S2="$TL_TMP/s2"; stage "$S2"
write_marker
run_matrix "$S2" HOME="$HOME" SILVER_BULLET_RUNTIME="$SILVER_BULLET_RUNTIME" SB_RELEASE_LIVE_MATRIX_CMD=
assert_eq "no command configured exits 1" 1 "$TL_STATUS"
assert_contains "no command message" "$TL_ERR" "No release live matrix command is configured"
assert_file_exists "marker kept after failure" "$(marker)"

# 4. a non-executable override is ignored
printf '#!/usr/bin/env bash\necho nope\n' >"$S2/scripts/release-live-matrix.sh"
run_matrix "$S2" HOME="$HOME" SILVER_BULLET_RUNTIME="$SILVER_BULLET_RUNTIME" SB_RELEASE_LIVE_MATRIX_CMD=
assert_eq "non-executable override ignored" 1 "$TL_STATUS"
assert_not_contains "non-executable override not run" "$TL_OUT" "nope"

# 5. missing verify-tests marker is refused before anything runs
rm -f "$(marker)"
run_matrix "$S1" HOME="$HOME" SILVER_BULLET_RUNTIME="$SILVER_BULLET_RUNTIME"
assert_eq "missing marker exits 1" 1 "$TL_STATUS"
assert_contains "missing marker message" "$TL_ERR" "requires a fresh verify-tests marker"

tl_results
