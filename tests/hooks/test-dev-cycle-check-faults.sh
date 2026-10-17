#!/usr/bin/env bash
# dev-cycle-check: fault injection through a staged copy of hooks/ whose libraries are replaced
# or made to fail (missing lib, helper returning non-zero, project gate refusing, failing main).
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
# rename_fn <file> <name>: make a function undefined without changing line numbers.
rename_fn() { sed -i "s/\\b$2\\b/zz_$2/g" "$1"; }
unstage() { unset HOOK_UNDER_TEST; }

# ── apply_patch path recovery when sb_tool_file_path is unavailable ──────────
mkproj f1
state ""
stage s1
rename_fn "$STG/hooks/lib/tool-input.sh" sb_tool_file_path
PATCH_JSON="$(jq -cn --arg p "$PATCH_SRC" '{hook_event_name:"PreToolUse",tool_name:"apply_patch",tool_input:{command:"apply_patch",input:$p}}')"
run_dc "$PATCH_JSON"
assert_eq "patch path is taken from sb_tool_patch_paths when the file-path helper is absent" "deny" "$(decision)"
assert_contains "gated as a source edit" "$(message)" "HARD STOP"
unstage
run_dc "$PATCH_JSON"
assert_eq "same payload with the real lib is also gated" "deny" "$(decision)"

stage s2
printf 'sb_tool_patch_paths() { return 1; }\n' >>"$STG/hooks/lib/tool-input.sh"
run_dc "$PATCH_JSON"
assert_eq "failing patch-path helper: apply_patch is not a shell tool, ignored" "none" "$(decision)"
unstage

# ── shell helpers failing ────────────────────────────────────────────────────
stage s3
printf 'sb_shell_candidate_write_paths() { return 1; }\n' >>"$STG/hooks/lib/tool-input.sh"
dc_cmd 'echo x > src/app.js'
assert_eq "failing write-path helper falls back to opaque scope matching" "deny" "$(decision)"
unstage

stage s4
printf 'sb_shell_invoked_script_path() { return 1; }\n' >>"$STG/hooks/lib/tool-input.sh"
printf '#!/usr/bin/env bash\necho x > src/gen.js\n' >"$PROJ/gen.sh"
dc_cmd 'bash gen.sh'
assert_eq "failing script-path helper: the script body is not inspected" "none" "$(decision)"
unstage

if [[ -f /proc/self/mem ]]; then
  stage s5
  printf 'sb_shell_invoked_script_path() { printf "%%s" /proc/self/mem; }\n' >>"$STG/hooks/lib/tool-input.sh"
  dc_cmd 'bash gen.sh'
  assert_eq "unreadable script file is tolerated" "none" "$(decision)"
  assert_eq "unreadable script file does not fail the hook" 0 "$TL_STATUS"
  unstage
fi

# ── plugin-cache guard library missing ───────────────────────────────────────
stage s6
rm -f "$STG/hooks/lib/plugin-cache-guard.sh"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/old/1.0"
mkdir -p "$SB_RUNTIME_HOME_ROOT/plugins"
printf '{"plugins":{}}' >"$SB_RUNTIME_HOME_ROOT/plugins/installed_plugins.json"
dc_cmd "rm -rf $SB_RUNTIME_PLUGIN_CACHE_ROOT/old/1.0"
assert_contains "without the guard lib, cache deletion is never treated as uninstall cleanup" "$(message)" "PLUGIN BOUNDARY VIOLATION via Bash"
unstage

# ── project activation helpers ───────────────────────────────────────────────
stage s7
printf 'sb_project_active() { return 1; }\n' >>"$STG/hooks/lib/project-active.sh"
edit
assert_eq "inactive project config: hook exits quietly" "none" "$(decision)"
unstage

stage s8
rename_fn "$STG/hooks/lib/project-active.sh" sb_project_active
printf 'sb_project_is_initiated() { return 1; }\n' >>"$STG/hooks/lib/project-active.sh"
edit
assert_eq "no sb_project_active: sb_project_is_initiated decides, not initiated exits" "none" "$(decision)"
unstage

stage s9
rename_fn "$STG/hooks/lib/project-active.sh" sb_project_active
edit
assert_eq "no sb_project_active: initiated project is still enforced" "deny" "$(decision)"
unstage

# ── main failing: ERR trap does not preempt the fallback report ──────────────
# A library that turns `exit` into a function lets main finish with a non-zero status.
mkproj f2
state inst-a silver-review silver-branch-finish
stage s10
printf 'exit() { return 3; }\n' >>"$STG/hooks/lib/hook-bootstrap.sh"
edit
assert_contains "main returning non-zero prints the continue-without-blocking notice" "$TL_OUT" "dev-cycle-check.sh encountered an error"
unstage

tl_results
