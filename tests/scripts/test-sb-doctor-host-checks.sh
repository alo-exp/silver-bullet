#!/usr/bin/env bash
# sb-doctor.sh D11 (hook smoke), D13-D20 (host surfaces, stack mutex) against a staged repo
# (tests/lib/h-doctor-stage.sh). Validators and installers are logging stubs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-doctor-stage.sh"
cd "$TL_TMP"
unset SB_DOCTOR_FIX SB_DOCTOR_FIX_SCOPE SB_DOCTOR_DEEP SB_DOCTOR_DRY_RUN SB_DOCTOR_FORMAT SB_DOCTOR_RECONCILER SB_DOCTOR_ASSUME_YES SB_DOCTOR_STUB_HOST_INSTALL
hd_stage
hd_happy claude
C='SILVER_BULLET_RUNTIME=claude'
run() { hd_run "$C" "$@"; }
CX='SILVER_BULLET_RUNTIME=codex'
cx() { hd_run "$CX" "$@"; }
CACHE="$HOME/.claude/plugins/cache/alo-labs/silver-bullet"

# ---------- D11: hook smoke ----------
run -- "$HD_PROJ"
assert_contains "session-start smoke payload" "$(hd_logs)" "hook session-start 1 SessionStart"
assert_contains "outcomes-check smoke payload" "$(hd_logs)" "hook outcomes-check 1 UserPromptSubmit"
assert_contains "stop-check smoke payload" "$(hd_logs)" "hook stop-check 1 Stop"
# R8-09: the smoke runs in a sandbox (temp HOME, throwaway project, source=resume), never on the user's state.
assert_not_contains "no smoke hook saw the user's HOME" "$(hd_logs)" "home=$HOME "
assert_not_contains "no smoke hook ran inside the user's project" "$(hd_logs)" "cwd=$HD_PROJ"
assert_contains "smoke HOME is a temp sandbox" "$(hd_logs)" "hook-env session-start home=$TMPDIR/sb-doctor-smoke."
assert_contains "smoke sends source=resume" "$(hd_logs)" "source=resume cfg=.git,.silver-bullet.json,silver-bullet.md,"
assert_contains "state dir is not pinned to the user's" "$(hd_logs)" "state=unset"
assert_eq "sandbox removed afterwards" "" "$(find "$TMPDIR" -maxdepth 1 -name 'sb-doctor-smoke.*')"
# the sandbox is best effort: no git still smokes, no temp dir fails the check
tl_stub git 'exit 1'
run -- "$HD_PROJ"
assert_contains "smoke tolerates a failing git init" "$TL_OUT" "PASS: D11 — session-start smoke exit 0"
rm -f "$TL_BIN/git"
run TMPDIR="$TL_TMP/no-such-tmp" -- "$HD_PROJ"
assert_contains "no sandbox dir: the smoke fails, the audit goes on" "$TL_OUT" "FAIL: D11 — session-start smoke failed"
# a user's runtime state survives the doctor
mkdir -p "$HOME/.claude/.silver-bullet"
printf 'adversarial-review-clean\n' >"$HOME/.claude/.silver-bullet/quality-gate-state"
printf 'matrix=inline-full-surface\n' >"$HOME/.claude/.silver-bullet/release-live-matrix"
printf 'silver-quality-gates\n' >"$HOME/.claude/.silver-bullet/state"
before="$(cd "$HOME/.claude/.silver-bullet" && find . -type f | LC_ALL=C sort | xargs cat | cksum)"
run -- "$HD_PROJ"
assert_eq "user runtime state untouched by the doctor" "$before" "$(cd "$HOME/.claude/.silver-bullet" && find . -type f | LC_ALL=C sort | xargs cat | cksum)"
assert_file_absent "no orchestrator directive written" "$HOME/.claude/.silver-bullet/orchestrator-directive.json"
run STUB_RC_HOOK=1 -- "$HD_PROJ"
assert_eq "failing smoke exits 1" "1" "$TL_STATUS"
assert_contains "session-start smoke failure" "$TL_OUT" "FAIL: D11 — session-start smoke failed"
assert_contains "stop-check smoke failure" "$TL_OUT" "FAIL: D11 — stop-check smoke failed"
mv "$HD_ST/hooks/stop-check" "$HD_ST/hooks/stop-check.sh"
run -- "$HD_PROJ"
assert_contains "hooks resolved with a .sh suffix" "$TL_OUT" "PASS: D11 — stop-check smoke exit 0"
rm -f -- "${HD_ST:?}/hooks/stop-check.sh"
run -- "$HD_PROJ"
assert_contains "missing hook" "$TL_OUT" "FAIL: D11 — stop-check not found under $HD_ST/hooks"
hd_stage
# without a source-tree session-start the smoke uses the active plugin cache
rm -f -- "${HD_ST:?}/hooks/session-start"
mkdir -p "$CACHE/$HD_VER/hooks"
for h in session-start outcomes-check stop-check; do
  printf '#!/usr/bin/env bash\necho "cachehook %s" >>"$HD_LOG"\n' "$h" >"$CACHE/$HD_VER/hooks/$h"
  chmod +x "$CACHE/$HD_VER/hooks/$h"
done
run -- "$HD_PROJ"
assert_contains "smoke runs the cached hooks" "$(hd_logs)" "cachehook session-start"
rm -f -- "${CACHE:?}/current"
run -- "$HD_PROJ"
assert_contains "no current link: the checkout hooks are searched" "$TL_OUT" "FAIL: D11 — session-start not found under $HD_ST/hooks"
rm -rf -- "${HOME:?}/.claude/plugins"
run -- "$HD_PROJ"
assert_contains "no cache at all: the checkout hooks are searched" "$TL_OUT" "FAIL: D11 — session-start not found under $HD_ST/hooks"
hd_stage
hd_happy claude

# validators run through bash: a checkout without exec bits is audited, not skipped
chmod -x "$HD_ST"/scripts/validate-*.sh
run -- "$HD_PROJ"
assert_contains "D16 runs a non-executable validator" "$TL_OUT" "PASS: D16 — repo install surface clean"
assert_contains "D17 runs a non-executable validator" "$TL_OUT" "PASS: D17 — SB core is host-agent agnostic"
assert_contains "D15 runs a non-executable validator" "$TL_OUT" "PASS: D15 — Claude agent description token budget within limit"
assert_not_contains "no 'not found' warning for existing validators" "$TL_OUT" "not found; skipped"
chmod +x "$HD_ST"/scripts/validate-*.sh

# ---------- D13 / D14: cross-host contamination and cache surface ----------
echo '{"hooks":"silver-bullet","path":"/home/u/.codex/plugins/cache/x"}' >"$HOME/.claude/settings.json"
run -- "$HD_PROJ"
assert_contains "claude settings with a codex plugin path" "$TL_OUT" "FAIL: D13 — $HOME/.claude/settings.json contains foreign host plugin paths"
echo '{"hooks":"silver-bullet","path":"/home/u/.claude/plugins/cache/x"}' >"$HOME/.claude/settings.json"
run -- "$HD_PROJ"
assert_contains "own plugin path is not contamination" "$TL_OUT" "PASS: D13 — no cross-host plugin paths in Claude settings"
rm -rf -- "${CACHE:?}/$HD_VER/agents"
run -- "$HD_PROJ"
assert_contains "agent bundle missing from the cache" "$TL_OUT" "FAIL: D13 — agents/claude/ missing in active plugin cache ($CACHE/current)"
run STUB_RC_SURFACE_CACHE=1 -- "$HD_PROJ"
assert_contains "cache surface bleed" "$TL_OUT" "FAIL: D14 — plugin cache cross-host bleed — run: bash scripts/install-claude.sh"
assert_contains "cache surface arguments" "$(hd_logs)" "surface --cache-root $CACHE/$HD_VER --host claude"
rm -f -- "${CACHE:?}/current"
run -- "$HD_PROJ"
assert_contains "no active install: surface check skipped" "$TL_OUT" "WARN: D14 — plugin cache surface check skipped (no active install)"
hd_happy claude
rm -f -- "${HD_ST:?}/scripts/validate-host-install-surface.sh"
run -- "$HD_PROJ"
assert_contains "surface validator missing: D14" "$TL_OUT" "WARN: D14 — plugin cache surface check skipped"
assert_contains "surface validator missing: D16" "$TL_OUT" "WARN: D16 — validate-host-install-surface.sh not found; skipped"
hd_stage

hd_happy codex
echo '[plugins."silver-bullet@alo-labs-codex"] # /home/u/.claude/plugins/x' >"$HOME/.codex/config.toml"
cx -- "$HD_PROJ"
assert_contains "codex config with a claude plugin path" "$TL_OUT" "FAIL: D13 — $HOME/.codex/config.toml contains foreign host plugin paths"
echo '[plugins."silver-bullet@alo-labs-codex"]' >"$HOME/.codex/config.toml"
cx -- "$HD_PROJ"
assert_contains "codex config is clean" "$TL_OUT" "PASS: D13 — no cross-host plugin paths in Codex config"
assert_contains "codex agent bundle in the cache" "$TL_OUT" "PASS: D13 — active install has skill-source/"
assert_contains "token budget N/A on codex" "$TL_OUT" "PASS: D15 — Claude token budget N/A (host=codex)"
hd_happy claude
echo '{"hooks":"silver-bullet","p":"/home/u/.codex/plugins/x"}' >"$HOME/.claude/settings.json"
run -- "$HD_PROJ"
assert_contains "claude settings with a codex plugin path" "$TL_OUT" "FAIL: D13 — $HOME/.claude/settings.json contains foreign host plugin paths"

# ---------- D15 / D16 / D17: validators ----------
hd_happy claude
run STUB_RC_TOKENS=1 -- "$HD_PROJ"
assert_contains "token budget exceeded" "$TL_OUT" "FAIL: D15 — Claude agent descriptions exceed token budget"
rm -f -- "${HD_ST:?}/scripts/validate-claude-agent-token-budget.sh"
run -- "$HD_PROJ"
assert_contains "token budget script missing" "$TL_OUT" "WARN: D15 — validate-claude-agent-token-budget.sh not found; skipped"
run STUB_RC_SURFACE_REPO=1 -- "$HD_PROJ"
assert_contains "repo install surface bleed" "$TL_OUT" "FAIL: D16 — repo install surface bleed — run: bash scripts/install-claude.sh"
assert_contains "repo surface arguments" "$(hd_logs)" "surface --repo-root $HD_ST --host claude"
run STUB_RC_AGNOSTIC=1 -- "$HD_PROJ"
assert_contains "host-specific bleed in core" "$TL_OUT" "FAIL: D17 — host-specific bleed in SB core — run: bash scripts/validate-host-agnostic-core.sh"
rm -f -- "${HD_ST:?}/scripts/validate-host-agnostic-core.sh"
run -- "$HD_PROJ"
assert_contains "agnostic validator missing" "$TL_OUT" "WARN: D17 — validate-host-agnostic-core.sh not found; skipped"
hd_stage

# ---------- D20: stack compression mutex ----------
hd_happy claude
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\",\"recommended_tools\":{\"rtk\":{\"enabled_by_user\":true},\"context_mode\":{\"enabled_by_user\":true}}}"
run -- "$HD_PROJ"
assert_contains "clean mutex" "$TL_OUT" "PASS: D20 — stack compression mutex clean"
MUTEX="$SB_RUNTIME_STATE_DIR/stack-compression-mutex"
echo '{"violations":["double"]}' >"$MUTEX"
run -- "$HD_PROJ"
assert_contains "dirty mutex" "$TL_OUT" "FAIL: D20 — stack compression mutex dirty — run: bash scripts/sb-doctor.sh --fix"
rm -f -- "${MUTEX:?}"
hd_cfg "{\"sb_initiated\":true,\"config_version\":\"$HD_VER\"}"
run -- "$HD_PROJ"
assert_contains "coordinator not needed" "$TL_OUT" "PASS: D20 — stack coordinator N/A (five-tool not active)"
rm -f -- "${HD_PROJ:?}/.silver-bullet.json"
run -- "$HD_PROJ"
assert_contains "no project config: coordinator N/A" "$TL_OUT" "PASS: D20 — stack coordinator N/A"
rm -f -- "${HD_ST:?}/hooks/lib"
mkdir -p "$HD_ST/hooks/lib"
for f in "$TL_REPO_ROOT"/hooks/lib/*; do
  [[ "${f##*/}" == stack-compression-coordinator.sh ]] || ln -s "$f" "$HD_ST/hooks/lib/${f##*/}"
done
hd_happy claude
run -- "$HD_PROJ"
assert_contains "coordinator library missing" "$TL_OUT" "WARN: D20 — stack-compression-coordinator lib missing; skipped"
hd_stage

# ---------- an unreadable project config does not stop the audit ----------
hd_happy claude
echo 'not json' >"$HD_PROJ/.silver-bullet.json"
run -- "$HD_PROJ"
assert_contains "unreadable config is reported by D6" "$TL_OUT" "FAIL: D6 — project config is not valid JSON ($HD_PROJ/.silver-bullet.json)"
assert_contains "unreadable config is reported by D5" "$TL_OUT" "FAIL: D5 — sb_initiated is not true"
assert_contains "the audit continues to D20" "$TL_OUT" "D20"
hd_stage

tl_results
