#!/usr/bin/env bash
# Flow tests for scripts/optimize-rtk-context-mode.sh. The script runs from a staged
# repo (real hooks/lib, logging stubs for the merge helper, installers and vendor
# CLIs) so no host config outside the sandboxed HOME is ever touched.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$(dirname "${BASH_SOURCE[0]}")/../lib/h-recommended-helpers.sh"
cd "$TL_TMP"
unset CODEX_HOME PI_CODING_AGENT_DIR CURSOR_PLUGIN_ROOT TOOLSTACK_INSTALL_IN_PROGRESS SB_RT_APPLY_ACTIVE RTCM_DRY_RUN

ST="$TL_TMP/stage"
LOG="$TL_TMP/calls.log"
export LOG
PROJ="$TL_TMP/proj"; mkdir -p "$PROJ"
mkdir -p "$ST/scripts/lib/global-toolstack" "$ST/hooks"
cp "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" "$ST/scripts/"
ln -s "$TL_REPO_ROOT/hooks/lib" "$ST/hooks/lib"
S="$ST/scripts/optimize-rtk-context-mode.sh"
# logging stubs for helpers resolved from the script directory
mk_sh() { printf '#!/usr/bin/env bash\necho "%s $* | tsip=${TOOLSTACK_INSTALL_IN_PROGRESS:-} proj=${RT_PROJECT_ROOT:-}" >>"$LOG"\nexit "${%s:-0}"\n' "$1" "$2" >"$ST/scripts/$1.sh"; chmod +x "$ST/scripts/$1.sh"; }
mk_sh install-recommended-tools-global STUB_RC_GLOBAL
mk_sh install-recommended-tools-cursor STUB_RC_CURSOR
mk_sh enable-rtk-context-mode STUB_RC_ENABLE
cat >"$ST/scripts/lib/merge-token-compression-config.py" <<'PY'
import os, sys
open(os.environ["LOG"], "a").write("merge %s\n" % " ".join(sys.argv[1:]))
sys.exit(int(os.environ.get("STUB_RC_MERGE", "0")))
PY
for py in patch-hooks install-pi; do
cat >"$ST/scripts/lib/global-toolstack/$py.py" <<PY
import os, sys
env = " ".join("%s=%s" % (k, os.environ[k]) for k in sorted(os.environ) if k.startswith("RT_PATCH_"))
open(os.environ["LOG"], "a").write("$py %s | %s\n" % (" ".join(sys.argv[1:]), env))
PY
done

mkdir -p "$HOME/.cursor" "$HOME/.claude"
BASEP="$(hr_path_without npm claude rtk context-mode)"
run_env() { : >"$LOG"; tl_run env PATH="$HR_BIN:$BASEP" "$@"; }
run_args() { : >"$LOG"; run_env bash "$S" "$@"; }
logs() { cat "$LOG"; }
mk_rtk() {  # healthy rtk stub
  hr_bin rtk 'echo "rtk $*" >>"$LOG"
case "$1" in
  gain) [[ "${STUB_RTK_NOGAIN:-0}" == 1 ]] && exit 1; exit 0 ;;
  --help) if [[ "${STUB_RTK_WRONG:-0}" == 1 ]]; then echo "Rust Type Kit"; else echo "rtk help"; fi; exit 0 ;;
  init) exit "${STUB_RC_RTKINIT:-0}" ;;
esac'
}
mk_cm() { hr_bin context-mode 'echo "context-mode $* platform=${CONTEXT_MODE_PLATFORM:-}" >>"$LOG"
i=1; while [[ $i -le 60 ]]; do echo "doctor-line-$i"; i=$((i+1)); done
exit "${STUB_RC_CM:-0}"'; }

# ---------- argument handling ----------
run_args --help
assert_eq "help exits 0" "0" "$TL_STATUS"
assert_contains "help text" "$TL_OUT" "Usage: bash scripts/optimize-rtk-context-mode.sh [options]"
run_args --bogus
assert_eq "unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "unknown arg named" "$TL_ERR" "Unknown arg: --bogus"
run_args --project-root "$PROJ"
assert_eq "missing host exits 2" "2" "$TL_STATUS"
assert_contains "missing host message" "$TL_ERR" "ERROR: --host is required"
run_args --host cursor
assert_eq "missing project root exits 2" "2" "$TL_STATUS"
assert_contains "missing project root message" "$TL_ERR" "ERROR: --project-root is required"
run_args --project-root "$PROJ" --host
assert_eq "--host without value exits 2" "2" "$TL_STATUS"
assert_contains "--host without value explained" "$TL_ERR" "--host requires a value"
run_args --host cursor --project-root
assert_eq "--project-root without value exits 2" "2" "$TL_STATUS"
assert_contains "--project-root without value explained" "$TL_ERR" "--project-root requires a value"
run_args --host nope --project-root "$PROJ"
assert_eq "invalid host exits 2" "2" "$TL_STATUS"
assert_contains "invalid host message" "$TL_ERR" "Invalid --host: nope (use: auto claude codex cursor opencode pi hermes goose all)"
run_args --host cursor --project-root "$TL_TMP/does-not-exist" --dry-run
assert_eq "missing project dir fails" "1" "$TL_STATUS"

# ---------- host auto-detection ----------
detect() {  # env assignments... -> prints the detected host
  run_args --host auto --project-root "$PROJ" --dry-run --skip-rtk-init --skip-cm-doctor
  sed -n 's/^=== RTK + Context Mode optimization (host=\(.*\)) ===$/\1/p' <<<"$TL_OUT"
}
rm -rf "$HOME/.cursor" "$HOME/.codex" "$HOME/.hermes" "$HOME/.pi" "$HOME/.config/opencode" "$HOME/.claude"
assert_eq "auto: nothing present falls back to cursor" "cursor" "$(detect)"
mkdir -p "$HOME/.claude"; assert_eq "auto: only ~/.claude gives claude" "claude" "$(detect)"
mkdir -p "$HOME/.pi/agent"; assert_eq "auto: pi agent dir beats ~/.claude" "pi" "$(detect)"
mkdir -p "$HOME/.hermes"; assert_eq "auto: hermes dir" "hermes" "$(detect)"
mkdir -p "$HOME/.config/opencode"; assert_eq "auto: opencode dir" "opencode" "$(detect)"
mkdir -p "$HOME/.codex"; assert_eq "auto: codex dir" "codex" "$(detect)"
mkdir -p "$HOME/.cursor"; assert_eq "auto: cursor dir wins" "cursor" "$(detect)"
rm -rf "$HOME/.cursor"
mkdir -p "$HOME/.claude"
: >"$LOG"
run_args --host auto --project-root "$PROJ" --dry-run --skip-rtk-init --skip-cm-doctor
assert_eq "auto: codex dir (again)" "codex" "$(sed -n 's/^=== .*(host=\(.*\)) ===$/\1/p' <<<"$TL_OUT")"
rm -rf "$HOME/.codex" "$HOME/.config" "$HOME/.hermes" "$HOME/.pi"
run_env CODEX_HOME="$TL_TMP/ch" bash "$S" --host auto --project-root "$PROJ" --dry-run --skip-rtk-init --skip-cm-doctor
assert_contains "auto: CODEX_HOME" "$TL_OUT" "(host=codex)"
run_env PI_CODING_AGENT_DIR="$TL_TMP/pi" bash "$S" --host auto --project-root "$PROJ" --dry-run --skip-rtk-init --skip-cm-doctor
assert_contains "auto: PI_CODING_AGENT_DIR" "$TL_OUT" "(host=pi)"
run_env CURSOR_PLUGIN_ROOT="$TL_TMP/cp" bash "$S" --host auto --project-root "$PROJ" --dry-run --skip-rtk-init --skip-cm-doctor
assert_contains "auto: CURSOR_PLUGIN_ROOT" "$TL_OUT" "(host=cursor)"
mkdir -p "$HOME/.cursor"

# ---------- claude ----------
mk_rtk; mk_cm
run_args --host claude --project-root "$PROJ"
assert_eq "claude run exits 0" "0" "$TL_STATUS"
assert_contains "claude header" "$TL_OUT" "--- host: claude (status: supported) ---"
assert_contains "claude rtk init" "$(logs)" "rtk init -g"
assert_contains "claude merge" "$(logs)" "merge --host claude --repo-root $ST"
assert_contains "enable script runs after a real run" "$(logs)" "enable-rtk-context-mode --tool all"
assert_contains "project root exported (canonical)" "$(logs)" "proj=$(cd "$PROJ" && pwd -P)"
assert_contains "completion line" "$TL_OUT" "=== Optimization complete ==="
assert_contains "doctor platform for claude" "$(logs)" "context-mode doctor platform=claude"

# the doctor output is limited to 40 lines
assert_contains "doctor output kept" "$TL_OUT" "doctor-line-1"
assert_not_contains "doctor output truncated at 40 lines" "$TL_OUT" "doctor-line-41"

# failing enable script tolerated
run_env STUB_RC_ENABLE=1 bash "$S" --host claude --project-root "$PROJ" --skip-cm-doctor
assert_eq "failing enable script tolerated" "0" "$TL_STATUS"

# flags forwarded to the merge helper
run_args --host claude --project-root "$PROJ" --dry-run --skip-cli-config --skip-cm-doctor
assert_contains "dry-run + skip-cli-config reach the merge helper" "$TL_OUT" "DRY-RUN: python3 $ST/scripts/lib/merge-token-compression-config.py --host claude --repo-root $ST --dry-run --skip-cli-config"
assert_not_contains "dry-run does not run the enable script" "$(logs)" "enable-rtk-context-mode"
assert_not_contains "dry-run does not run rtk init" "$(logs)" "rtk init"
assert_contains "dry-run rtk init is announced" "$TL_OUT" "DRY-RUN: $HR_BIN/rtk init -g"

# merge failure aborts the run
run_env STUB_RC_MERGE=1 bash "$S" --host claude --project-root "$PROJ" --skip-cm-doctor
assert_eq "merge failure aborts" "1" "$TL_STATUS"
assert_not_contains "no completion after merge failure" "$TL_OUT" "Optimization complete"

# rtk init skipped / unavailable / wrong
run_args --host claude --project-root "$PROJ" --skip-rtk-init --skip-cm-doctor --dry-run
assert_contains "claude rtk init skipped" "$TL_OUT" "SKIP: rtk init (claude)"
hr_nobin rtk
run_args --host claude --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "claude without rtk" "$TL_OUT" "WARN: rtk-ai/rtk not on PATH — skip rtk init"
mk_rtk
run_env STUB_RTK_WRONG=1 bash "$S" --host claude --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "claude with the wrong rtk" "$TL_OUT" "WARN: rtk-ai/rtk not on PATH — skip rtk init"
run_env STUB_RTK_NOGAIN=1 bash "$S" --host claude --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "claude with rtk lacking gain" "$TL_OUT" "WARN: rtk-ai/rtk not on PATH — skip rtk init"

# native Context Mode plugin handling
printf '{"enabledPlugins":{"context-mode@context-mode":true}}\n' >"$HOME/.claude/settings.json"
run_args --host claude --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "native plugin disable announced" "$TL_OUT" "DRY-RUN: claude plugin disable context-mode@context-mode --scope user"
run_args --host claude --project-root "$PROJ" --skip-cm-doctor
assert_eq "enabled native plugin without claude CLI fails" "1" "$TL_STATUS"
assert_contains "native plugin error" "$TL_ERR" "ERROR: Claude Context Mode plugin is enabled but the claude CLI is unavailable"
hr_bin claude 'echo "claude $*" >>"$LOG"; exit 0'
run_args --host claude --project-root "$PROJ" --skip-cm-doctor
assert_eq "native plugin disabled via the CLI" "0" "$TL_STATUS"
assert_contains "claude plugin disable ran" "$(logs)" "claude plugin disable context-mode@context-mode --scope user"
printf '{"enabledPlugins":{"context-mode@context-mode":false}}\n' >"$HOME/.claude/settings.json"
hr_bin claude 'echo "claude $*" >>"$LOG"; case "$1 $2" in "plugin list") printf "  context-mode@context-mode\n    Status: enabled\n";; esac; exit 0'
run_args --host claude --project-root "$PROJ" --skip-cm-doctor
assert_contains "plugin list reports enabled" "$(logs)" "claude plugin disable context-mode@context-mode --scope user"
hr_bin claude 'echo "claude $*" >>"$LOG"; case "$1 $2" in "plugin list") printf "  context-mode@context-mode\n    Status: disabled\n";; esac; exit 0'
run_args --host claude --project-root "$PROJ" --skip-cm-doctor
assert_not_contains "plugin list reports disabled" "$(logs)" "plugin disable"
rm -f "$HOME/.claude/settings.json"
hr_bin claude 'echo "claude $*" >>"$LOG"; exit 0'
run_args --host claude --project-root "$PROJ" --skip-cm-doctor
assert_not_contains "no settings and no plugin list match" "$(logs)" "plugin disable"
hr_nobin claude

# context-mode CLI installation
hr_nobin context-mode
hr_bin npm 'echo "npm $*" >>"$LOG"; exit "${STUB_RC_NPM:-0}"'
run_args --host codex --project-root "$PROJ" --skip-cm-doctor
assert_contains "missing context-mode is installed with npm" "$(logs)" "npm install -g context-mode"
run_env STUB_RC_NPM=1 bash "$S" --host codex --project-root "$PROJ" --skip-cm-doctor
assert_eq "failing npm install tolerated" "0" "$TL_STATUS"
run_args --host codex --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "npm install announced in dry-run" "$TL_OUT" "DRY-RUN: npm install -g context-mode"
hr_nobin npm
run_args --host codex --project-root "$PROJ" --skip-cm-doctor
assert_eq "no npm and no context-mode is tolerated" "0" "$TL_STATUS"
mk_cm
run_args --host codex --project-root "$PROJ" --skip-cm-doctor
assert_not_contains "present context-mode is not reinstalled" "$(logs)" "npm install"

# ---------- codex / opencode / pi / hermes / goose ----------
run_args --host codex --project-root "$PROJ" --skip-cm-doctor
assert_contains "codex rtk init" "$(logs)" "rtk init -g --codex"
assert_contains "codex merge" "$(logs)" "merge --host codex"
run_args --host codex --project-root "$PROJ" --skip-rtk-init --skip-cm-doctor --dry-run
assert_contains "codex rtk init skipped" "$TL_OUT" "SKIP: rtk init (codex)"
hr_nobin rtk
run_args --host codex --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "codex without rtk" "$TL_OUT" "WARN: rtk-ai/rtk not on PATH — skip rtk init"

run_args --host opencode --project-root "$PROJ" --skip-cm-doctor
assert_contains "opencode rtk note" "$TL_OUT" "OK: OpenCode RTK is wired by the shared manifest-backed plugin"
assert_contains "opencode merge" "$(logs)" "merge --host opencode"

run_args --host pi --project-root "$PROJ" --skip-cm-doctor
assert_contains "pi rtk note" "$TL_OUT" "OK: Pi RTK is wired by the shared native tool_call adapter"
assert_contains "pi adapter installer" "$(logs)" "install-pi --repo-root $ST"
mv "$ST/scripts/lib/global-toolstack/install-pi.py" "$ST/scripts/lib/global-toolstack/install-pi.off"
run_args --host pi --project-root "$PROJ" --skip-cm-doctor
assert_eq "missing pi installer fails" "1" "$TL_STATUS"
assert_contains "pi installer error" "$TL_ERR" "ERROR: Pi adapter installer missing: $ST/scripts/lib/global-toolstack/install-pi.py"
mv "$ST/scripts/lib/global-toolstack/install-pi.off" "$ST/scripts/lib/global-toolstack/install-pi.py"

mk_rtk
run_args --host hermes --project-root "$PROJ" --skip-cm-doctor
assert_contains "hermes status" "$TL_OUT" "--- host: hermes (status: partial) ---"
assert_contains "hermes rtk init" "$(logs)" "rtk init --agent hermes"
assert_contains "hermes note" "$TL_OUT" "NOTE: Hermes has no context-mode doctor platform"
run_args --host hermes --project-root "$PROJ" --skip-rtk-init --skip-cm-doctor --dry-run
assert_contains "hermes rtk init skipped" "$TL_OUT" "SKIP: rtk init (hermes)"
hr_nobin rtk
run_args --host hermes --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "hermes without rtk" "$TL_OUT" "WARN: rtk-ai/rtk not on PATH — skip rtk init"

run_args --host goose --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "goose unsupported" "$TL_OUT" "SKIP: goose — RTK and Context Mode have no upstream integration"
assert_contains "goose status" "$TL_OUT" "--- host: goose (status: unsupported) ---"

# ---------- cursor ----------
mk_rtk
printf '{"hooks":{"preToolUse":[{"command":"rtk hook cursor"}]}}\n' >"$HOME/.cursor/hooks.json"
run_args --host cursor --project-root "$PROJ" --skip-cm-doctor
assert_eq "cursor run exits 0" "0" "$TL_STATUS"
assert_contains "cursor rtk init" "$(logs)" "rtk init -g --agent cursor"
assert_contains "cursor hook detected" "$TL_OUT" "OK: RTK Cursor hook present"
assert_contains "cursor merge" "$(logs)" "merge --host cursor"
assert_contains "cursor hook reconciler flags" "$(logs)" "patch-hooks  | RT_PATCH_CONTEXT_MODE=1 RT_PATCH_LEANCTX=1 RT_PATCH_RTK=1"
assert_contains "cursor global installer" "$(logs)" "install-recommended-tools-global --host cursor --global"
assert_not_contains "cursor installer not needed" "$(logs)" "install-recommended-tools-cursor"
echo '{}' >"$HOME/.cursor/hooks.json"
run_args --host cursor --project-root "$PROJ" --skip-cm-doctor
assert_contains "cursor hook missing" "$TL_OUT" "WARN: RTK hook not found after rtk init — check ~/.cursor/hooks.json"
rm -f "$HOME/.cursor/hooks.json"
run_args --host cursor --project-root "$PROJ" --skip-cm-doctor
assert_contains "cursor without hooks.json" "$TL_OUT" "WARN: RTK hook not found after rtk init"
run_args --host cursor --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_not_contains "dry-run skips the hook check" "$TL_OUT" "RTK Cursor hook present"
assert_not_contains "dry-run skips the hook warning" "$TL_OUT" "RTK hook not found"
run_args --host cursor --project-root "$PROJ" --skip-rtk-init --skip-cm-doctor --dry-run
assert_contains "cursor rtk init skipped" "$TL_OUT" "SKIP: rtk init (cursor)"
run_env STUB_RC_GLOBAL=1 bash "$S" --host cursor --project-root "$PROJ" --skip-cm-doctor
assert_contains "cursor installer fallback" "$(logs)" "install-recommended-tools-cursor --global"
run_env STUB_RC_GLOBAL=1 STUB_RC_CURSOR=1 bash "$S" --host cursor --project-root "$PROJ" --skip-cm-doctor
assert_eq "both cursor installers failing is tolerated" "0" "$TL_STATUS"
run_env TOOLSTACK_INSTALL_IN_PROGRESS=1 bash "$S" --host cursor --project-root "$PROJ" --skip-cm-doctor
assert_not_contains "no nested installer while one is in progress" "$(logs)" "install-recommended-tools"
run_env SB_RT_APPLY_ACTIVE=1 bash "$S" --host cursor --project-root "$PROJ" --skip-cm-doctor
assert_not_contains "no nested installer during an apply" "$(logs)" "install-recommended-tools"
mv "$ST/scripts/lib/global-toolstack/patch-hooks.py" "$ST/scripts/lib/global-toolstack/patch-hooks.off"
run_args --host cursor --project-root "$PROJ" --skip-cm-doctor
assert_not_contains "no hook reconciler when absent" "$(logs)" "patch-hooks"
mv "$ST/scripts/lib/global-toolstack/patch-hooks.off" "$ST/scripts/lib/global-toolstack/patch-hooks.py"
hr_nobin rtk
run_args --host cursor --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "cursor without rtk" "$TL_OUT" "WARN: rtk-ai/rtk not on PATH or wrong binary — skip rtk init"

# ---------- all hosts ----------
mk_rtk
run_args --host all --project-root "$PROJ" --skip-cm-doctor --dry-run
for h in claude codex cursor opencode pi hermes goose; do
  assert_contains "all: $h visited" "$TL_OUT" "--- host: $h ("
done

# ---------- Context Mode doctor ----------
run_args --host claude --project-root "$PROJ" --dry-run
assert_contains "doctor dry-run" "$TL_OUT" "DRY-RUN: CONTEXT_MODE_PLATFORM=claude context-mode doctor"
run_args --host claude --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_contains "doctor skipped" "$TL_OUT" "SKIP: context-mode doctor"
run_args --host hermes --project-root "$PROJ" --dry-run
assert_contains "doctor has no adapter for hermes" "$TL_OUT" "SKIP: context-mode doctor (no platform adapter for host=hermes)"
run_args --host pi --project-root "$PROJ" --dry-run
assert_contains "doctor has no adapter for pi" "$TL_OUT" "no platform adapter for host=pi"
run_args --host all --project-root "$PROJ" --dry-run
assert_contains "doctor for all uses the default adapter" "$TL_OUT" "DRY-RUN: CONTEXT_MODE_PLATFORM=cursor context-mode doctor"
hr_nobin context-mode
run_args --host claude --project-root "$PROJ" --dry-run
assert_contains "doctor without context-mode" "$TL_OUT" "WARN: context-mode not on PATH — skip doctor"

# a failing doctor never fails the run
mk_cm
run_env STUB_RC_CM=3 bash "$S" --host claude --project-root "$PROJ"
assert_eq "failing context-mode doctor tolerated" "0" "$TL_STATUS"
assert_contains "doctor output still shown when it fails" "$TL_OUT" "doctor-line-1"

# ---------- variants of the staged libraries ----------
ST2="$TL_TMP/stage2"
mkdir -p "$ST2/scripts/lib" "$ST2/hooks/lib"
cp "$ST/scripts/lib/merge-token-compression-config.py" "$ST2/scripts/lib/"
cp "$ST"/scripts/*.sh "$ST2/scripts/" 2>/dev/null || true
cp "$TL_REPO_ROOT/scripts/optimize-rtk-context-mode.sh" "$ST2/scripts/"
for f in "$TL_REPO_ROOT"/hooks/lib/*; do ln -s "$f" "$ST2/hooks/lib/${f##*/}"; done
S2="$ST2/scripts/optimize-rtk-context-mode.sh"

# a host known to the shared list but not handled by optimize_host is rejected
rm -f "$ST2/hooks/lib/rtk-cm-global.sh"
sed 's/^RTCM_ALL_HOSTS="\(.*\)"/RTCM_ALL_HOSTS="\1 zed"/' "$TL_REPO_ROOT/hooks/lib/rtk-cm-global.sh" >"$ST2/hooks/lib/rtk-cm-global.sh"
: >"$LOG"
tl_run env PATH="$HR_BIN:$BASEP" bash "$S2" --host zed --project-root "$PROJ" --skip-cm-doctor --dry-run
assert_eq "unhandled host exits 2" "2" "$TL_STATUS"
assert_contains "unhandled host message" "$TL_ERR" "Invalid host: zed"
rm -f "$ST2/hooks/lib/rtk-cm-global.sh"; ln -s "$TL_REPO_ROOT/hooks/lib/rtk-cm-global.sh" "$ST2/hooks/lib/rtk-cm-global.sh"

# without the Context Mode gate library, a context-mode on PATH still counts as installed
rm -f "$ST2/hooks/lib/context-mode-gate.sh"
hr_bin npm 'echo "npm $*" >>"$LOG"'
mk_cm
: >"$LOG"
tl_run env PATH="$HR_BIN:$BASEP" bash "$S2" --host codex --project-root "$PROJ" --skip-cm-doctor
assert_eq "no gate library still runs" "0" "$TL_STATUS"
assert_not_contains "context-mode on PATH is not reinstalled" "$(logs)" "npm install"
hr_nobin context-mode
: >"$LOG"
tl_run env PATH="$HR_BIN:$BASEP" bash "$S2" --host codex --project-root "$PROJ" --skip-cm-doctor
assert_contains "context-mode absent is installed" "$(logs)" "npm install -g context-mode"
hr_nobin npm

tl_results
