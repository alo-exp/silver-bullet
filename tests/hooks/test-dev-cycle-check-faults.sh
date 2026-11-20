#!/usr/bin/env bash
# dev-cycle-check: fault injection through a staged copy of hooks/ whose libraries are missing
# or replaced, and unreadable files.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$(dirname "${BASH_SOURCE[0]}")/../lib/cov-a-dc.sh"

# stage <name>: copy hooks/ and the default config into $TL_TMP/<name>; sets STG and HOOK_UNDER_TEST.
stage() {
  STG="$TL_TMP/$1"
  mkdir -p "$STG/templates"
  cp -R "$TL_REPO_ROOT/hooks" "$STG/hooks"
  cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$STG/templates/"
  HOOK_UNDER_TEST="$STG/hooks/dev-cycle-check.sh"
  export HOOK_UNDER_TEST
}
unstage() { unset HOOK_UNDER_TEST; }

# ── a broken install must not turn the planning floor off ────────────────────
mkproj f1
state ""
stage s1
rm -f "$STG/hooks/lib/planning-floor.sh"
edit
assert_eq "planning-floor lib missing: the call is denied, not silently allowed" "deny" "$(decision)"
assert_contains "the deny says to reinstall" "$(message)" "Reinstall the plugin"
assert_eq "the deny is one document" 1 "$(jq -s length <<<"$TL_OUT")"
unstage

# ── the lib directory cannot even be resolved ────────────────────────────────
mkproj f1b
state ""
tl_run_stdin "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")" bash -c 'cd() { return 1; }; export -f cd; exec bash "$0"' "$HOOK"
assert_contains "an unresolvable lib dir is refused, not silently allowed" "$TL_OUT" "Reinstall the plugin"

# ── plugin-cache guard library missing ───────────────────────────────────────
stage s2
rm -f "$STG/hooks/lib/plugin-cache-guard.sh"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/old/1.0"
mkdir -p "$SB_RUNTIME_HOME_ROOT/plugins"
printf '{"plugins":{}}' >"$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"
dc_cmd "rm -rf $SB_RUNTIME_PLUGIN_CACHE_ROOT/old/1.0"
assert_contains "without the guard lib, cache deletion is never treated as uninstall cleanup" "$(message)" "PLUGIN BOUNDARY VIOLATION via Bash"
unstage

# ── the analysis helper failing mid-run ──────────────────────────────────────
stage s3
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(3)\n' >"$STG/hooks/lib/tool-input/analyze.py"
dc_cmd 'echo x > src/app.js'
assert_eq "a helper that crashes is reported as unavailable: the write is refused" "deny" "$(decision)"
assert_contains "and says how to proceed" "$(message)" "python3"
dc_cmd 'git status'
assert_eq "a helper that crashes does not block a plainly read-only command" "none" "$(decision)"
unstage

# ── a script body that cannot be read ───────────────────────────────────────
mkproj f2
state inst-a
printf '#!/usr/bin/env bash\necho x > src/gen.js\n' >"$PROJ/gen.sh"
stage s4
printf 'sb_pf_write_records() { :; }\n' >>"$STG/hooks/lib/planning-floor.sh"
dc_cmd 'bash gen.sh'
assert_eq "no write records at all: nothing to gate" "none" "$(decision)"
unstage
if [[ "$(id -u)" -eq 0 ]]; then
  echo "SKIP: needs a non-root user (unreadable branch file and script)"
else
  mkproj f3
  state inst-a
  printf 'other/branch\n' >"$BRANCHF"
  chmod 000 "$BRANCHF"
  edit
  assert_not_contains "unreadable branch file: no mismatch warning" "$(message)" "Branch mismatch"
  assert_contains "unreadable branch file: planning verdict still reached" "$(message)" "Planning verified"
  chmod 600 "$BRANCHF"; printf "feature/test\n" >"$BRANCHF"
  printf '#!/usr/bin/env bash\necho x > src/gen.js\n' >"$PROJ/gen.sh"
  chmod 000 "$PROJ/gen.sh"
  dc_cmd 'bash gen.sh'
  assert_eq "unreadable script: body not inspected, command ignored" "none" "$(decision)"
  assert_eq "unreadable script: hook exits 0" 0 "$TL_STATUS"
  chmod 600 "$PROJ/gen.sh"
fi

tl_results
