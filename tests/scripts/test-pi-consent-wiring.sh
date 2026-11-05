#!/usr/bin/env bash
# End-to-end: the Pi adapter switches on exactly the tools the user consented to wire, whichever
# entry point runs it. scripts/lib/global-toolstack/install-pi.py runs for real (sandboxed HOME);
# only the project is a throwaway git repo. No consent enables nothing.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$TL_REPO_ROOT/tests/lib/consent-helpers.sh"
unset PI_CODING_AGENT_DIR CODEX_HOME TOOLSTACK_INSTALL_IN_PROGRESS SB_RT_APPLY_ACTIVE RTCM_DRY_RUN
cd "$TL_TMP"
PROJ="$TL_TMP/proj"; mkdir -p "$PROJ"; git -C "$PROJ" init -q
CFG="$HOME/.pi/agent/extensions/silver-bullet-five-tool-stack/config.json"

enabled() {  # sorted, comma-joined list of enabled servers in the Pi adapter config
  jq -r '[.servers | to_entries[] | select(.value.enabled == true) | .key] | sort | join(",")' "$CFG"
}
fresh() { rm -rf "$HOME/.pi" "$HOME/.local/state/five-tool-stack"; sb_test_consent_sandbox; }

# ---- scripts/optimize-rtk-context-mode.sh --host pi
fresh
tl_run bash "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host pi --project-root "$PROJ" --skip-cm-doctor
assert_eq "optimize: no consent exits 0" "0" "$TL_STATUS"
assert_file_absent "optimize: no consent writes no Pi adapter" "$CFG"

fresh; sb_test_consent_grant rtk install,wire,enforce; sb_test_consent_grant context_mode install,wire,enforce
tl_run bash "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host pi --project-root "$PROJ" --skip-cm-doctor
assert_eq "optimize: consented rtk and context_mode exits 0" "0" "$TL_STATUS"
assert_eq "optimize: consented rtk and context_mode are enabled, nothing else" "context_mode,rtk" "$(enabled)"

fresh; sb_test_consent_grant rtk install,wire,enforce
tl_run bash "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host pi --project-root "$PROJ" --skip-cm-doctor
assert_eq "optimize: rtk-only consent enables rtk only" "rtk" "$(enabled)"

fresh; sb_test_consent_grant context_mode install,wire,enforce
tl_run bash "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host pi --project-root "$PROJ" --skip-cm-doctor
assert_eq "optimize: context_mode-only consent enables context_mode only" "context_mode" "$(enabled)"

fresh; sb_test_consent_grant rtk install,enforce; sb_test_consent_grant context_mode install
tl_run bash "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host pi --project-root "$PROJ" --skip-cm-doctor
assert_file_absent "optimize: install/enforce without wire writes no Pi adapter" "$CFG"

# ---- the stack optimizer's graphify platform command (run without a shell, as in production)
# shellcheck source=../../hooks/lib/stack-optimizer.sh
source "$TL_REPO_ROOT/hooks/lib/stack-optimizer.sh"
fresh; sb_test_consent_grant graphify install,wire,enforce; sb_test_consent_grant agentmemory install,wire
line="$(_sb_stack_graphify_platform_words pre pi)"
_sb_stack_run_words "$PROJ" "$line"
assert_eq "stack optimizer: consented graphify and agentmemory are enabled, nothing else" "agentmemory,graphify" "$(enabled)"
fresh
assert_eq "stack optimizer: no consent adds no --enable-tool" "0" "$(_sb_stack_graphify_platform_words pre pi | grep -c -e '--enable-tool' || true)"

# ---- leanctx makes Pi install an npm package: that needs install consent, not only wire
fresh; sb_test_consent_grant leanctx wire
tl_run bash "$TL_REPO_ROOT/scripts/install-recommended-tools-global.sh" --host pi
assert_eq "leanctx wire-only: not enabled in Pi" "" "$( [[ -f "$CFG" ]] && enabled || true)"
assert_eq "leanctx wire-only: no npm package added to Pi settings" "0" "$( { cat "$HOME/.pi/agent/settings.json" 2>/dev/null || true; } | { grep -c 'pi-lean-ctx' || true; })"
fresh; sb_test_consent_grant leanctx install,wire
tl_run bash "$TL_REPO_ROOT/scripts/install-recommended-tools-global.sh" --host pi
assert_eq "leanctx install+wire: enabled in Pi" "leanctx" "$(enabled)"
assert_contains "leanctx install+wire: npm package added" "$(cat "$HOME/.pi/agent/settings.json")" "npm:pi-lean-ctx"
fresh; sb_test_consent_grant leanctx wire; sb_test_consent_grant graphify install,wire
line="$(_sb_stack_graphify_platform_words pre pi)"
_sb_stack_run_words "$PROJ" "$line"
assert_eq "stack optimizer: leanctx wire-only is not enabled alongside graphify" "graphify" "$(enabled)"

# ---- every path that enables leanctx in Pi: wire alone lists no npm package, install+wire does
printf '#!/usr/bin/env bash\necho "lean-ctx 3.12.0"\n' >"$TL_BIN/lean-ctx"; chmod +x "$TL_BIN/lean-ctx"
SETTINGS="$HOME/.pi/agent/settings.json"
pkgs() { jq -c '.packages // []' "$SETTINGS" 2>/dev/null || echo '[]'; }
for host in pi all; do
  fresh; sb_test_consent_grant leanctx wire
  tl_run bash "$TL_REPO_ROOT/scripts/optimize-five-tool-stack.sh" --host "$host" --project-root "$PROJ" --skip-synergy
  assert_eq "optimizer --host $host, leanctx wire-only: no npm package" "[]" "$(pkgs)"
  fresh; sb_test_consent_grant leanctx install,wire
  tl_run bash "$TL_REPO_ROOT/scripts/optimize-five-tool-stack.sh" --host "$host" --project-root "$PROJ" --skip-synergy
  assert_eq "optimizer --host $host, leanctx install+wire: npm package listed" '["npm:pi-lean-ctx"]' "$(pkgs)"
done
fresh; sb_test_consent_grant leanctx wire
tl_run bash "$TL_REPO_ROOT/scripts/install-leanctx-sb.sh" --host pi --project-root "$PROJ" --skip-verify
assert_eq "install-leanctx-sb --host pi, wire-only: no npm package" "[]" "$(pkgs)"
fresh; sb_test_consent_grant leanctx install,wire
tl_run bash "$TL_REPO_ROOT/scripts/install-leanctx-sb.sh" --host pi --project-root "$PROJ" --skip-verify
assert_eq "install-leanctx-sb --host pi, install+wire: npm package listed" '["npm:pi-lean-ctx"]' "$(pkgs)"
fresh; sb_test_consent_grant leanctx install,wire; sb_test_consent_grant graphify install,wire
_sb_stack_run_words "$PROJ" "$(_sb_stack_graphify_platform_words pre pi)"
assert_eq "stack optimizer pre:pi, leanctx install+wire: npm package listed" '["npm:pi-lean-ctx"]' "$(pkgs)"
fresh; sb_test_consent_grant graphify install,wire; sb_test_consent_grant leanctx wire
_sb_stack_run_words "$PROJ" "$(_sb_stack_graphify_platform_words pre pi)"
assert_eq "stack optimizer pre:pi, leanctx wire-only: no npm package" "[]" "$(pkgs)"

# ---- revoking consent does not switch a tool off in Pi (documented in docs/CONSENT.md)
fresh; sb_test_consent_grant rtk install,wire,enforce
tl_run bash "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host pi --project-root "$PROJ" --skip-cm-doctor
sb_test_consent_revoke_all; sb_test_consent_grant context_mode install,wire,enforce
tl_run bash "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" --host pi --project-root "$PROJ" --skip-cm-doctor
assert_eq "revoke: a previously enabled tool stays on, the new one is added" "context_mode,rtk" "$(enabled)"
assert_contains "docs say revoke does not unwire" "$(cat "$TL_REPO_ROOT/docs/CONSENT.md")" "Revoking or declining consent stops"

# ---- the recommended-tools registry command (text shown to the agent)
# shellcheck source=../../hooks/lib/recommended-tools.sh
source "$TL_REPO_ROOT/hooks/lib/recommended-tools.sh"
fresh; sb_test_consent_grant rtk install,wire,enforce; sb_test_consent_grant leanctx install,wire
pre="$(sb_recommended_tool_platform_pre_index_commands "" rtk pi)"
assert_contains "registry: consented rtk is enabled" "$pre" "--enable-tool rtk"
assert_contains "registry: consented leanctx is enabled" "$pre" "--enable-tool leanctx"
assert_not_contains "registry: unconsented context_mode is not enabled" "$pre" "--enable-tool context_mode"
fresh
pre="$(sb_recommended_tool_platform_pre_index_commands "" graphify pi)"
assert_not_contains "registry: no consent adds no --enable-tool" "$pre" "--enable-tool"

# ---- scripts/install-recommended-tools-global.sh --host pi
fresh
tl_run bash "$TL_REPO_ROOT/scripts/install-recommended-tools-global.sh" --host pi
assert_eq "global pi: no consent exits 0" "0" "$TL_STATUS"
assert_file_absent "global pi: no consent leaves settings.json alone" "$HOME/.pi/agent/settings.json"
assert_file_absent "global pi: no consent installs no extension" "$CFG"
assert_contains "global pi: no consent says how to consent" "$TL_ERR" "SKIP: Pi adapter"
fresh; sb_test_consent_grant rtk install,wire,enforce
tl_run bash "$TL_REPO_ROOT/scripts/install-recommended-tools-global.sh" --host pi
assert_eq "global pi: consented rtk exits 0" "0" "$TL_STATUS"
assert_eq "global pi: consented rtk is enabled" "rtk" "$(enabled)"
assert_file_exists "global pi: consented run registers the extension" "$HOME/.pi/agent/settings.json"

tl_results
