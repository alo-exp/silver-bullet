#!/usr/bin/env bash
# Behavior tests for hooks/lib/alumnium-gate.sh (npm/npx are stubbed)
set -euo pipefail
# The opt-in gates act only on the user's own consent, never on .silver-bullet.json alone.
# shellcheck source=../lib/consent-helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib/consent-helpers.sh"
sb_test_consent_grant_all
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
unset SB_ALUMNIUM_MCP_ARTIFACT

LIBF="$TL_REPO_ROOT/hooks/lib/alumnium-gate.sh"
# shellcheck source=../../hooks/lib/alumnium-gate.sh
source "$LIBF"

yes_t() { local n="$1"; shift; if "$@"; then tl_pass "$n"; else tl_fail "$n"; fi; }
no_t() { local n="$1"; shift; if "$@"; then tl_fail "$n"; else tl_pass "$n"; fi; }
CFG="$TL_TMP/cfg.json"
w() { printf '%s' "$1" >"$CFG"; }
PR="$TL_TMP/proj"; mkdir -p "$PR"

# required / mcp name
w '{"recommended_tools":{"alumnium":{"enabled_by_user":true,"mcp_server_name":"alum-x"}}}'
yes_t "required" sb_alumnium_required "$CFG"
no_t "not required without config" sb_alumnium_required ""
assert_eq "mcp name configured" "alum-x" "$(sb_alumnium_mcp_server_name "$CFG")"
assert_eq "mcp name default" "alumnium" "$(sb_alumnium_mcp_server_name)"
w '{}'
assert_eq "mcp name default when unset" "alumnium" "$(sb_alumnium_mcp_server_name "$CFG")"
w 'garbage'
assert_eq "mcp name default on invalid json" "alumnium" "$(sb_alumnium_mcp_server_name "$CFG")"

# npx availability: npx on PATH is enough; the npm registry is never queried
no_t "npx missing" env PATH="$(tl_path_without npx)" bash -c 'source "$1"; sb_alumnium_npx_available' _ "$LIBF"
tl_stub npx 'exit 0'
tl_stub npm 'echo "$@" >>"'"$TL_TMP"'/npm.log"; exit 1'
hash -r
yes_t "npx available without any registry query" sb_alumnium_npx_available
[[ ! -e "$TL_TMP/npm.log" ]] && tl_pass "npm is not run" || tl_fail "npm is not run"

# artifact path
export SB_ALUMNIUM_MCP_ARTIFACT=/ovr
assert_eq "artifact override" "/ovr" "$(sb_alumnium_platform_artifact_path "$PR" cursor)"
unset SB_ALUMNIUM_MCP_ARTIFACT
assert_eq "artifact cursor" "$HOME/.cursor/mcp.json" "$(sb_alumnium_platform_artifact_path "$PR" cursor)"
assert_eq "artifact codex" "/ch/config.toml" "$(CODEX_HOME=/ch sb_alumnium_platform_artifact_path "$PR" codex)"
assert_eq "artifact codex default home" "$HOME/.codex/config.toml" "$(env -u CODEX_HOME bash -c 'source "$1"; sb_alumnium_platform_artifact_path /x codex' _ "$LIBF")"
assert_eq "artifact claude" "$HOME/.claude.json" "$(sb_alumnium_platform_artifact_path "$PR" claude)"
assert_eq "artifact other host" "$HOME/.claude.json" "$(sb_alumnium_platform_artifact_path "$PR" pi)"
assert_eq "artifact default host" "$HOME/.claude.json" "$(SILVER_BULLET_RUNTIME=claude sb_alumnium_platform_artifact_path "$PR")"

# artifact present
AF="$TL_TMP/art"; export SB_ALUMNIUM_MCP_ARTIFACT="$AF"
no_t "present: missing" sb_alumnium_platform_artifact_present "$PR" claude
printf '{}' >"$AF"; no_t "present: no marker" sb_alumnium_platform_artifact_present "$PR" claude
printf '{"mcpServers":{"Alumnium":{}}}' >"$AF"; yes_t "present: case-insensitive marker" sb_alumnium_platform_artifact_present "$PR" claude
yes_t "present: default host" sb_alumnium_platform_artifact_present "$PR"
printf '{"custom-name":1}' >"$AF"
no_t "present: custom name absent" sb_alumnium_platform_artifact_present "$PR" claude
printf '{"recommended_tools":{"alumnium":{"mcp_server_name":"custom-name"}}}' >"$PR/.silver-bullet.json"
yes_t "present: custom server name from project config" sb_alumnium_platform_artifact_present "$PR" claude
yes_t "present: default project root is PWD" bash -c 'cd "$1" && source "$2" && sb_alumnium_platform_artifact_present' _ "$PR" "$LIBF"
rm -f "$AF"; ln -s "$TL_TMP/tgt" "$AF"; printf 'alumnium' >"$TL_TMP/tgt"
no_t "present: symlink refused" sb_alumnium_platform_artifact_present "$PR" claude
rm -f "$AF"; unset SB_ALUMNIUM_MCP_ARTIFACT

# edit path exemptions
no_t "edit exempt empty" sb_alumnium_edit_path_is_exempt ""
for p in /p/.silver-bullet.json /p/SETUP_REPORT.md /p/silver-bullet.md /p/CLAUDE.md /p/AGENTS.md /p/.silver-bullet/x /h/.cursor/mcp.json /h/.claude.json; do
  yes_t "edit exempt $p" sb_alumnium_edit_path_is_exempt "$p"
done
no_t "edit not exempt" sb_alumnium_edit_path_is_exempt /p/src/a.ts
no_t "edit exempt: dotdot does not escape into an exempt name" sb_alumnium_edit_path_is_exempt /p/src/../x.ts

# browser path detection
no_t "browser empty" sb_alumnium_edit_path_requires_browser ""
for p in /p/a.canvas.tsx /p/e2e/login.ts /p/playwright/x.js /p/__screenshots__/a.png /p/screenshots/a.png /p/visual-regression/a.ts /p/tests/login.cy.ts /p/tests/login.e2e.js /p/my-screenshot-helper.py /p/cypress.config.ts /p/puppeteer-run.js /p/browser-test.sh; do
  yes_t "browser path $p" sb_alumnium_edit_path_requires_browser "$p"
done
no_t "browser path unrelated" sb_alumnium_edit_path_requires_browser /p/src/util.ts
no_t "unit spec is not a browser path" sb_alumnium_edit_path_requires_browser /p/tests/util.spec.ts

# command exemptions: only provably read-only commands and alumnium's own CLI are exempt
yes_t "cmd exempt empty" sb_alumnium_command_is_exempt ""
yes_t "cmd exempt alumnium" sb_alumnium_command_is_exempt "alumnium run"
yes_t "cmd exempt cat" sb_alumnium_command_is_exempt "cat f"
no_t "cmd not exempt: alumnium mentioned in a pipeline" sb_alumnium_command_is_exempt "echo alumnium; rm -rf x"
no_t "cmd not exempt: npm install" sb_alumnium_command_is_exempt "npm install left-pad"
no_t "cmd not exempt" sb_alumnium_command_is_exempt "git commit -m x"

# which shell commands are browser work
no_t "requires browser: empty" sb_alumnium_command_requires_browser ""
no_t "requires browser: read-only" sb_alumnium_command_requires_browser "cat playwright.config.ts"
no_t "requires browser: commit" sb_alumnium_command_requires_browser "git commit -m x"
yes_t "requires browser: playwright run" sb_alumnium_command_requires_browser "npx playwright test"
yes_t "requires browser: cypress run" sb_alumnium_command_requires_browser "cypress run"
yes_t "requires browser: writes a browser test" sb_alumnium_command_requires_browser "cp a.ts e2e/login.ts"
no_t "requires browser: writes a source file" sb_alumnium_command_requires_browser "cp a.ts src/login.ts"

# messages
w '{}'
m="$(SILVER_BULLET_RUNTIME=claude sb_alumnium_block_message_no_mcp "$CFG")"
assert_contains "no_mcp header" "$m" "ALUMNIUM REQUIRED"
assert_contains "no_mcp host" "$m" "host: claude"
assert_contains "no_mcp provider key hint" "$m" "OPENAI_API_KEY"
assert_contains "no_mcp declines through the consent CLI" "$m" "sb-consent.sh"
assert_contains "no_npx header" "$(sb_alumnium_block_message_no_npx)" "npx is not on PATH"

# prompt reminder
RC="$PR/.silver-bullet.json"
rem() { SILVER_BULLET_RUNTIME=claude sb_alumnium_prompt_reminder_line "$RC"; }
printf '{"recommended_tools":{"alumnium":{"enabled_by_user":true}}}' >"$RC"
assert_contains "reminder pending (a project recommendation is not consent)" "$(XDG_CONFIG_HOME="$TL_TMP/none" rem)" "consent pending"
printf '{"recommended_tools":{"alumnium":{"enabled_by_user":false}}}' >"$RC"; assert_contains "reminder disabled" "$(rem)" "opted out"
printf '{"recommended_tools":{"alumnium":{"enabled_by_user":true}}}' >"$RC"
export SB_ALUMNIUM_MCP_ARTIFACT="$AF"
assert_contains "reminder enabled but not wired" "$(rem)" "MCP not wired"
printf 'alumnium' >"$AF"
assert_contains "reminder enabled and wired" "$(rem)" "MCP wired"
unset SB_ALUMNIUM_MCP_ARTIFACT

tl_results
