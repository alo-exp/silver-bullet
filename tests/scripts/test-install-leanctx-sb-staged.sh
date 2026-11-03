#!/usr/bin/env bash
# scripts/install-leanctx-sb.sh from a staged copy: lean-ctx, curl, the MCP patch /
# merge / Pi helpers and the wire-proxy validator are stubs that log their calls,
# so no binary is installed, no host MCP config is rewritten and nothing touches
# the network. Complements test-install-leanctx-sb.sh (which drives the real helpers).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/consent-helpers.sh"
sb_test_consent_grant_all   # the user said yes to every tool (docs/CONSENT.md)

STAGE="$TL_TMP/repo"
INST="$STAGE/scripts/install-leanctx-sb.sh"
LOG="$TL_TMP/calls.log"
PROJ="$TL_TMP/proj"
PROFILE="$SB_RUNTIME_HOME_ROOT/leanctx-profile/five-tool-routed.env"
export LOG

mkdir -p "$STAGE/scripts/lib/global-toolstack" "$STAGE/hooks" "$PROJ"
cp "$TL_REPO_ROOT/scripts/install-leanctx-sb.sh" "$INST"
cp "$TL_REPO_ROOT/scripts/sb-consent.sh" "$STAGE/scripts/" 2>/dev/null || true
ln -s "$TL_REPO_ROOT/hooks/lib" "$STAGE/hooks/lib"
stub_py() { # <path> <label>
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<EOF
import os, sys
env = " ".join("%s=%s" % (k, os.environ[k]) for k in sorted(os.environ) if k.startswith("RT_PATCH_"))
open(os.environ["LOG"], "a").write("$2 %s %s\n" % (" ".join(sys.argv[1:]), env))
hook = os.environ.get("STUB_HOOK")
if hook:
    os.system(hook)
sys.exit(int(os.environ.get("STUB_RC", "0")))
EOF
}
stub_py "$STAGE/scripts/lib/global-toolstack/patch-mcp.py" patch-mcp
stub_py "$STAGE/scripts/lib/global-toolstack/install-pi.py" install-pi
stub_py "$STAGE/scripts/lib/merge-leanctx-mcp-config.py" merge-mcp
VERIFY="$STAGE/scripts/lib/verify-leanctx-wire-proxy-ordering.py"
cat >"$VERIFY" <<'EOF'
import os, sys
if "--generate-fixture" in sys.argv:
    print("FIXTURE")
    sys.exit(0)
open(os.environ["LOG"], "a").write("verify %s stdin=%s\n" % (" ".join(sys.argv[1:]), sys.stdin.read()))
sys.exit(int(os.environ.get("VERIFY_RC", "0")))
EOF

# lean-ctx stand-in driven by LC_* variables
tl_stub lean-ctx '
printf "lean-ctx %s\n" "$*" >>"$LOG"
case "$1" in
  --version) [[ -n "${LC_BROKEN:-}${LC_NOVERSION:-}" ]] && exit 1; echo "lean-ctx 3.12.0"; exit 0 ;;
  --help) [[ -n "${LC_BROKEN:-}" ]] && exit 1; exit 0 ;;
  init) [[ "${2:-}" == "--help" && -n "${LC_LIBMODE:-}" ]] && echo "  --library-mode"; exit 0 ;;
  config) if [[ "${2:-}" == set ]]; then exit 0; fi; printf "%s\n" "${LC_CONFIG:-}"; exit 0 ;;
  proxy) exit "${LC_PROXY_RC:-0}" ;;
esac
exit 0'
# never reach the network: the upstream installer fetch is a failing stand-in by default
tl_stub curl 'printf "curl %s\n" "$*" >>"$LOG"; exit 22'

run_inst() { : >"$LOG"; rm -rf "$SB_RUNTIME_HOME_ROOT/leanctx-profile"; tl_run bash "$INST" "$@" --project-root "$PROJ"; }
calls() { cat "$LOG"; }

# ---- arguments
tl_run bash "$INST" --help
assert_eq "help exits 0" "0" "$TL_STATUS"
assert_contains "help text" "$TL_OUT" "Usage: bash scripts/install-leanctx-sb.sh [options]"
tl_run bash "$INST" -h
assert_eq "-h exits 0" "0" "$TL_STATUS"
tl_run bash "$INST" --bogus
assert_eq "unknown arg exits 2" "2" "$TL_STATUS"
assert_contains "unknown arg message" "$TL_ERR" "Unknown arg: --bogus"
tl_run bash "$INST" --project-root "$PROJ"
assert_eq "missing host exits 2" "2" "$TL_STATUS"
assert_contains "missing host message" "$TL_ERR" "ERROR: --host is required"
tl_run bash "$INST" --host cursor
assert_eq "missing project root exits 2" "2" "$TL_STATUS"
assert_contains "missing project root message" "$TL_ERR" "ERROR: --project-root is required"

# ---- full cursor run against a lean-ctx without library mode
mkdir -p "$HOME/.cursor"
printf '{"mcpServers":{"context-mode":{}}}\n' >"$HOME/.cursor/mcp.json"
printf 'agents\n' >"$HOME/.cursor/AGENTS.md"
LC_CONFIG='excluded_commands = []
[setup]
manage_hooks = true' run_inst --host cursor --skip-verify
assert_eq "cursor run exits 0" "0" "$TL_STATUS"
assert_contains "banner" "$TL_OUT" "=== LeanCTX SB install (host=cursor) ==="
assert_contains "context-mode overlap noted" "$TL_OUT" "Context Mode detected"
assert_contains "binary already present" "$TL_OUT" "OK: lean-ctx already on PATH"
assert_contains "library mode unavailable -> merge-only" "$TL_OUT" "NOTE: --library-mode not in lean-ctx init --help; using SB merge-only wiring"
assert_not_contains "never runs init --agent" "$(calls)" "init --agent"
assert_contains "cursor merges through patch-mcp with only leanctx enabled" "$(calls)" "patch-mcp  RT_PATCH_GRAPHIFY=0 RT_PATCH_LEANCTX=1"
assert_file_exists "profile env written" "$PROFILE"
assert_contains "profile disables overlapping tools" "$(cat "$PROFILE")" "LEAN_CTX_DISABLED_TOOLS=ctx_shell,shell,ctx_execute"
assert_contains "profile keeps the lctx_ prefix" "$(cat "$PROFILE")" "LEANCTX_MCP_TOOL_PREFIX=lctx_"
assert_contains "rtk passthrough configured" "$(calls)" "lean-ctx config set excluded_commands rtk"
assert_contains "hook management turned off" "$(calls)" "lean-ctx config set setup.manage_hooks false"
assert_contains "guard preserved" "$TL_OUT" "=== LeanCTX SB install complete ==="
assert_eq "guarded AGENTS.md untouched" "agents" "$(cat "$HOME/.cursor/AGENTS.md")"

# already configured lean-ctx: nothing to set; excluded list from the user: warn only
LC_CONFIG='excluded_commands = ["rtk","git"]
[setup]
manage_hooks = false
[other]
x = 1' run_inst --host cursor --skip-verify --skip-merge
assert_contains "excluded_commands already has rtk" "$TL_OUT" "OK: lean-ctx excluded_commands already includes rtk"
assert_contains "manage_hooks already false" "$TL_OUT" "OK: lean-ctx setup.manage_hooks already false"
assert_contains "merge skipped" "$TL_OUT" "SKIP: MCP merge"
assert_not_contains "no config set when already right" "$(calls)" "config set"
LC_CONFIG='excluded_commands = ["git"]' run_inst --host cursor --skip-verify --skip-merge
assert_eq "foreign exclusions only warn" "0" "$TL_STATUS"
assert_contains "warns to add rtk" "$TL_ERR" 'WARN: lean-ctx excluded_commands=["git"]; add rtk to it'
assert_not_contains "foreign exclusions untouched" "$(calls)" "excluded_commands rtk"

# library mode verified upstream
LC_LIBMODE=1 run_inst --host cursor --skip-verify --skip-merge
assert_contains "library-mode init invoked" "$TL_OUT" "Running lean-ctx init --library-mode (verified upstream flag)"
assert_contains "init --library-mode logged" "$(calls)" "lean-ctx init --library-mode"

# ---- no lean-ctx binary
NOLC="$(tl_path_without lean-ctx)"
: >"$LOG"
tl_run env PATH="$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --skip-install --skip-verify --skip-merge
assert_eq "skip-install without binary still succeeds" "0" "$TL_STATUS"
assert_contains "skip-install announced" "$TL_OUT" "SKIP: lean-ctx binary install"
assert_contains "library init skipped with warning" "$TL_ERR" "WARN: lean-ctx missing — skip library init"
assert_contains "rtk passthrough skipped" "$TL_OUT" "SKIP: lean-ctx not installed; RTK passthrough not configured"

# ---- the upstream installer is never piped into a shell (R6-17)
sb_test_consent_grant_all
GOOD_INSTALLER='#!/bin/sh
printf "#!/bin/sh\nexit 0\n" > "$LC_DEST/lean-ctx"; chmod +x "$LC_DEST/lean-ctx"'
LC_DEST="$TL_TMP/lc-bin"; mkdir -p "$LC_DEST"
GOOD_SHA="$(printf '%s\n' "$GOOD_INSTALLER" | { shasum -a 256 2>/dev/null || sha256sum; } | awk '{print $1}')"
tl_stub curl 'printf "curl %s\n" "$*" >>"'"$LOG"'"
out=""; while [[ $# -gt 0 ]]; do [[ "$1" == "-o" ]] && out="$2"; shift; done
printf "%s\n" "$STUB_INSTALLER" >"$out"'
export LC_DEST STUB_INSTALLER="$GOOD_INSTALLER"
: >"$LOG"
tl_run env PATH="$LC_DEST:$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge
assert_eq "no lean-ctx and no pinned checksum: refused" "1" "$TL_STATUS"
assert_contains "refusal explains the checksum" "$TL_ERR" "will not run an unverified installer"
assert_contains "refusal shows the pin option" "$TL_ERR" "--installer-sha256"
assert_contains "refusal offers cargo" "$TL_ERR" "cargo install lean-ctx"
assert_not_contains "nothing was downloaded" "$(calls)" "curl"
tl_run env PATH="$LC_DEST:$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 not-hex
assert_eq "a malformed checksum is refused" "1" "$TL_STATUS"
assert_contains "malformed checksum explained" "$TL_ERR" "--installer-sha256 must be 64 hexadecimal characters"
: >"$LOG"
tl_run env PATH="$LC_DEST:$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$GOOD_SHA"
assert_eq "a verified installer runs" "0" "$TL_STATUS"
assert_file_exists "the verified installer produced the binary" "$LC_DEST/lean-ctx"
assert_contains "the download is https-only and bounded" "$(calls)" "curl -fsSL --proto =https --max-time 60 -o"
assert_contains "the install is confirmed" "$TL_OUT" "OK: lean-ctx installed"
rm -f "$LC_DEST/lean-ctx"
# the checksum is computed with sha256sum when shasum is missing
NOSHASUM="$(tl_path_without lean-ctx shasum)"
tl_run env PATH="$LC_DEST:$NOSHASUM" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$GOOD_SHA"
assert_eq "a verified installer runs without shasum" "0" "$TL_STATUS"
rm -f "$LC_DEST/lean-ctx"
# an uppercase checksum is accepted
tl_run env PATH="$LC_DEST:$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$(printf '%s' "$GOOD_SHA" | tr 'a-f' 'A-F')"
assert_eq "an uppercase checksum matches" "0" "$TL_STATUS"
rm -f "$LC_DEST/lean-ctx"
# a different installer (tampered) does not run
: >"$LOG"
tl_run env PATH="$LC_DEST:$NOLC" STUB_INSTALLER='#!/bin/sh
touch "$LC_DEST/tampered-ran"' bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$GOOD_SHA"
assert_eq "a checksum mismatch aborts" "1" "$TL_STATUS"
assert_contains "the mismatch is reported" "$TL_ERR" "checksum mismatch"
assert_file_absent "the tampered installer never ran" "$LC_DEST/tampered-ran"
# an installer that exits non-zero is reported, and the missing binary still aborts
FAIL_INSTALLER='#!/bin/sh
exit 3'
FAIL_SHA="$(printf '%s\n' "$FAIL_INSTALLER" | { shasum -a 256 2>/dev/null || sha256sum; } | awk '{print $1}')"
tl_run env PATH="$LC_DEST:$NOLC" STUB_INSTALLER="$FAIL_INSTALLER" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$FAIL_SHA"
assert_eq "an installer that fails aborts" "1" "$TL_STATUS"
assert_contains "its non-zero exit is reported" "$TL_ERR" "WARN: lean-ctx installer exited non-zero"
# the download itself fails
tl_stub curl 'exit 22'
tl_run env PATH="$LC_DEST:$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$GOOD_SHA"
assert_eq "a failed download aborts" "1" "$TL_STATUS"
assert_contains "a failed download is reported" "$TL_ERR" "could not download the lean-ctx installer"
# the installer ran but produced nothing
tl_stub curl 'out=""; while [[ $# -gt 0 ]]; do [[ "$1" == "-o" ]] && out="$2"; shift; done; printf "#!/bin/sh\nexit 0\n" >"$out"'
EMPTY_SHA="$(printf '#!/bin/sh\nexit 0\n' | { shasum -a 256 2>/dev/null || sha256sum; } | awk '{print $1}')"
tl_run env PATH="$LC_DEST:$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$EMPTY_SHA"
assert_eq "an installer that installs nothing aborts" "1" "$TL_STATUS"
assert_contains "and warns" "$TL_ERR" "WARN: lean-ctx not on PATH after installer — try: cargo install lean-ctx"
# curl itself missing
NOCURL="$(tl_path_without lean-ctx curl)"
rm -f "$TL_BIN/curl"
tl_run env PATH="$NOCURL" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$GOOD_SHA"
assert_eq "no curl and no binary aborts" "1" "$TL_STATUS"
assert_contains "no curl is explained" "$TL_ERR" "curl is required to download the lean-ctx installer"
# installing needs the separate install consent
sb_test_consent_revoke_all
sb_test_consent_grant leanctx wire
tl_run env PATH="$LC_DEST:$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --skip-verify --skip-merge --installer-sha256 "$GOOD_SHA"
assert_eq "wire consent alone does not allow an install" "1" "$TL_STATUS"
assert_contains "the install consent is requested" "$TL_ERR" "grant leanctx --all-projects --capabilities install"
sb_test_consent_grant_all
# dry run never fetches
: >"$LOG"
rm -rf "$SB_RUNTIME_HOME_ROOT/leanctx-profile"
tl_run env PATH="$NOLC" bash "$INST" --host cursor --project-root "$PROJ" --dry-run --skip-verify --installer-sha256 "$GOOD_SHA"
assert_eq "dry-run without binary exits 0" "0" "$TL_STATUS"
assert_contains "dry-run shows the verified download" "$TL_OUT" "DRY-RUN: download https://leanctx.com/install.sh, verify sha256 ${GOOD_SHA}, run it"
assert_contains "dry-run skips guard check" "$TL_OUT" "SKIP: guard unchanged check (dry-run — no writes)"
assert_file_absent "dry-run writes no profile" "$PROFILE"
assert_contains "dry-run profile" "$TL_OUT" "DRY-RUN: write ${PROFILE}"
assert_contains "dry-run cursor merge" "$TL_OUT" "DRY-RUN: RT_PATCH_LEANCTX=1 RT_PATCH_GRAPHIFY=0 python3 ${STAGE}/scripts/lib/global-toolstack/patch-mcp.py"
assert_eq "dry-run runs no helper" "" "$(calls)"

# ---- no consent: nothing is changed (R6-03)
sb_test_consent_revoke_all
: >"$LOG"
run_inst --host cursor --skip-verify
assert_eq "without consent the run exits 0" "0" "$TL_STATUS"
assert_contains "without consent: skipped" "$TL_OUT" "SKIP: LeanCTX install - no consent"
assert_contains "without consent: the grant command" "$TL_OUT" "sb-consent.sh grant leanctx --all-projects --capabilities wire,install"
assert_eq "without consent nothing ran" "" "$(calls)"
assert_file_absent "without consent no profile is written" "$PROFILE"
sb_test_consent_grant_all

# the AGENTS.md guard protects the project's files, not the plugin checkout's
printf 'project agents\n' >"$PROJ/AGENTS.md"
printf 'cursor rules\n' >"$PROJ/.cursorrules"
run_inst --host cursor --skip-verify --skip-merge
assert_eq "a run that leaves the project files alone passes the guard" "0" "$TL_STATUS"
assert_eq "project AGENTS.md untouched" "project agents" "$(cat "$PROJ/AGENTS.md")"
tl_run env STUB_HOOK='echo clobbered > "'"$PROJ"'/AGENTS.md"' bash "$INST" --host cursor --project-root "$PROJ" --skip-verify
assert_eq "clobbering the project's AGENTS.md fails the guard" "1" "$TL_STATUS"
assert_contains "the guard names the project file" "$TL_ERR" "install modified guarded path: $PROJ/AGENTS.md"
rm -f "$PROJ/AGENTS.md" "$PROJ/.cursorrules"

# ---- wire-proxy evidence (R6-30)
run_inst --host codex --skip-merge
assert_contains "the self-test is labeled as proving the validator only" "$TL_OUT" "this proves the validator, not the proxy"
printf '{"schema":"x"}' >"$TL_TMP/evidence.json"
run_inst --host codex --skip-merge --wire-proxy-evidence "$TL_TMP/evidence.json"
assert_contains "real evidence is validated" "$TL_OUT" "Validating the captured wire-proxy evidence $TL_TMP/evidence.json"
assert_contains "the validator received the file" "$(calls)" "verify $TL_TMP/evidence.json"
assert_contains "valid evidence is confirmed" "$TL_OUT" "OK: wire-proxy evidence preserves message ordering"
tl_run env VERIFY_RC=1 bash "$INST" --host codex --project-root "$PROJ" --skip-merge --wire-proxy-evidence "$TL_TMP/evidence.json"
assert_eq "invalid evidence fails the install" "1" "$TL_STATUS"
assert_contains "invalid evidence is reported" "$TL_ERR" "wire-proxy evidence is not valid message ordering"
tl_run env VERIFY_RC=1 bash "$INST" --host codex --project-root "$PROJ" --skip-merge
assert_eq "a failing validator self-test fails the install" "1" "$TL_STATUS"
assert_contains "and says so" "$TL_ERR" "wire-proxy ordering validator self-test failed"

# dry-run with the binary: library init and config sets are only printed
LC_LIBMODE=1 run_inst --host cursor --dry-run
assert_contains "dry-run library init" "$TL_OUT" "DRY-RUN: "
assert_contains "dry-run excluded_commands" "$TL_OUT" "DRY-RUN: lean-ctx config set excluded_commands rtk"
assert_contains "dry-run manage_hooks" "$TL_OUT" "DRY-RUN: lean-ctx config set setup.manage_hooks false"
assert_not_contains "dry-run never changes lean-ctx config" "$(calls)" "config set"

# ---- merge targets per host
for h in claude codex opencode; do
  run_inst --host "$h" --skip-verify
  assert_contains "$h merges via merge-leanctx-mcp-config" "$TL_OUT" "Merging LeanCTX MCP for host=${h} via merge-leanctx-mcp-config.py"
  assert_contains "$h merge helper args" "$(calls)" "merge-mcp --host $h"
  run_inst --host "$h" --skip-verify --dry-run
  assert_contains "$h dry-run merge" "$TL_OUT" "DRY-RUN: python3 ${STAGE}/scripts/lib/merge-leanctx-mcp-config.py --host $h"
done
run_inst --host pi --skip-verify
assert_contains "pi installer args" "$(calls)" "install-pi --repo-root ${STAGE}"
run_inst --host pi --skip-verify --dry-run
assert_contains "pi dry-run" "$TL_OUT" "DRY-RUN: python3 ${STAGE}/scripts/lib/global-toolstack/install-pi.py --repo-root ${STAGE}"
run_inst --host hermes --skip-verify
assert_eq "unknown host skips the merge" "0" "$TL_STATUS"
assert_contains "no merge target message" "$TL_OUT" "SKIP: MCP merge (host=hermes; no merge target implemented"

# helper failures propagate
STUB_RC=5 run_inst --host cursor --skip-verify
assert_eq "failing patch-mcp aborts" "5" "$TL_STATUS"
rm "$STAGE/scripts/lib/global-toolstack/patch-mcp.py"
run_inst --host cursor --skip-verify
assert_eq "missing patch-mcp aborts" "1" "$TL_STATUS"
assert_contains "missing patch-mcp warns" "$TL_ERR" "patch-mcp helper missing"
run_inst --host cursor --skip-verify --skip-merge
assert_eq "missing patch-mcp irrelevant with --skip-merge" "0" "$TL_STATUS"
rm "$STAGE/scripts/lib/merge-leanctx-mcp-config.py"
run_inst --host claude --skip-verify
assert_eq "missing merge helper aborts" "1" "$TL_STATUS"
assert_contains "missing merge helper warns" "$TL_ERR" "merge-leanctx-mcp-config helper missing"
rm "$STAGE/scripts/lib/global-toolstack/install-pi.py"
run_inst --host pi --skip-verify
assert_eq "missing pi installer aborts" "1" "$TL_STATUS"
assert_contains "missing pi installer warns" "$TL_ERR" "Pi adapter installer missing"
stub_py "$STAGE/scripts/lib/global-toolstack/patch-mcp.py" patch-mcp
stub_py "$STAGE/scripts/lib/global-toolstack/install-pi.py" install-pi
stub_py "$STAGE/scripts/lib/merge-leanctx-mcp-config.py" merge-mcp

# ---- wire-proxy verification
run_inst --host cursor --skip-merge
assert_eq "verify passes" "0" "$TL_STATUS"
assert_contains "verify ran" "$TL_OUT" "OK: validator self-test passed"
assert_contains "validator received the generated fixture" "$(calls)" "verify - stdin=FIXTURE"
VERIFY_RC=1 run_inst --host cursor --skip-merge
assert_eq "verify failure aborts" "1" "$TL_STATUS"
assert_contains "verify failure warns" "$TL_ERR" "WARN: wire-proxy ordering validator self-test failed"
run_inst --host cursor --skip-merge --skip-verify
assert_contains "verify skip announced" "$TL_OUT" "SKIP: wire-proxy ordering verify"
mv "$VERIFY" "$VERIFY.off"
run_inst --host cursor --skip-merge
assert_eq "missing validator is only a warning" "0" "$TL_STATUS"
assert_contains "missing validator warns" "$TL_ERR" "WARN: verify helper missing"
mv "$VERIFY.off" "$VERIFY"
run_inst --host codex --skip-merge
assert_contains "codex proxy subcommand present" "$TL_OUT" "OK: lean-ctx proxy subcommand available for Codex wire path"
LC_PROXY_RC=1 run_inst --host codex --skip-merge
assert_contains "codex proxy subcommand missing warns" "$TL_ERR" "WARN: lean-ctx proxy subcommand not found"
assert_eq "codex proxy warning is not fatal" "0" "$TL_STATUS"

# ---- guarded host files must survive the install
mkdir -p "$HOME/.codex"
printf 'codex agents\n' >"$HOME/.codex/AGENTS.md"
STUB_HOOK='echo tampered >> "$HOME/.codex/AGENTS.md"' run_inst --host codex --skip-verify
assert_eq "modified guard file fails the install" "1" "$TL_STATUS"
assert_contains "modification reported" "$TL_ERR" "WARN: install modified guarded path: ${HOME}/.codex/AGENTS.md"
assert_contains "guard failure summary" "$TL_ERR" "Guard check failed — SB install must not clobber host agent config"
printf 'codex agents\n' >"$HOME/.codex/AGENTS.md"
STUB_HOOK='rm -f "$HOME/.codex/AGENTS.md"' run_inst --host codex --skip-verify
assert_eq "removed guard file fails the install" "1" "$TL_STATUS"
assert_contains "removal reported" "$TL_ERR" "WARN: install removed guarded path: ${HOME}/.codex/AGENTS.md"
rm -f "$HOME/.codex/AGENTS.md"
STUB_HOOK='echo new > "$HOME/.codex/AGENTS.md"' run_inst --host codex --skip-verify
assert_eq "created guard file fails the install" "1" "$TL_STATUS"
assert_contains "creation reported" "$TL_ERR" "WARN: install touched guarded path (created): ${HOME}/.codex/AGENTS.md"
rm -f "$HOME/.codex/AGENTS.md"

# guard paths per host (the install must not modify them; snapshot detects the file for each host)
guard_for() { # <host> <path-to-guard> [env...]
  local host="$1" path="$2"; shift 2
  mkdir -p "$(dirname "$path")"
  printf 'g\n' >"$path"
  tl_run env "$@" STUB_HOOK='echo x >> "'"$path"'"' bash "$INST" --host "$host" --project-root "$PROJ" --skip-verify
  assert_eq "$host: guard path $path is enforced" "1" "$TL_STATUS"
  assert_contains "$host: tamper reported" "$TL_ERR" "install modified guarded path: $path"
  rm -f "$path"
}
guard_for opencode "$HOME/.config/opencode/AGENTS.md"
guard_for pi "$HOME/.pi/agent/AGENTS.md"
guard_for pi "$TL_TMP/pi-agent/AGENTS.md" PI_CODING_AGENT_DIR="$TL_TMP/pi-agent"
guard_for claude "$HOME/.claude/CLAUDE.md"
guard_for cursor "$PROJ/.cursorrules"
guard_for cursor "$PROJ/AGENTS.md"
guard_for codex "$PROJ/AGENTS.md"
guard_for cursor "$HOME/.cursor/AGENTS.md"

# Functions-only copy of the script (same line numbers, main flow cut off) so the
# helpers older callers use can be exercised directly and still map to the source.
FN="$TL_TMP/fn/scripts/install-leanctx-sb.sh"
mkdir -p "$TL_TMP/fn/scripts" "$TL_TMP/fn/hooks"
ln -sfn "$TL_REPO_ROOT/hooks/lib" "$TL_TMP/fn/hooks/lib"
awk '/^while \[\[ \$# -gt 0 \]\]/ { exit } { print }' "$TL_REPO_ROOT/scripts/install-leanctx-sb.sh" >"$FN"
mkdir -p "$TL_TMP/fn/scripts/lib"; cp "$VERIFY" "$TL_TMP/fn/scripts/lib/verify-leanctx-wire-proxy-ordering.py"
fn_run() { # <snippet> -> runs with the functions loaded; sets TL_OUT/TL_ERR/TL_STATUS
  tl_run bash -c 'source "$1"; shift; eval "$1"' _ "$FN" "$1"
}

# legacy mtime snapshots of older callers
LEGACY_TARGET="$TL_TMP/legacy.txt"; printf 'a\n' >"$LEGACY_TARGET"
LEGACY_MTIME="$(stat -c '%Y' "$LEGACY_TARGET")"
fn_run "assert_guard_unchanged '${LEGACY_TARGET}=${LEGACY_MTIME}'"
assert_eq "legacy snapshot: unchanged mtime passes" "0" "$TL_STATUS"
fn_run "assert_guard_unchanged '${LEGACY_TARGET}=12345'"
assert_eq "legacy snapshot: changed mtime fails" "1" "$TL_STATUS"
assert_contains "legacy snapshot: reports modification" "$TL_ERR" "install modified guarded path: ${LEGACY_TARGET}"
fn_run "assert_guard_unchanged '${TL_TMP}/absent.txt=12345'"
assert_eq "legacy snapshot: absent file is tolerated" "0" "$TL_STATUS"
fn_run "assert_guard_unchanged '${LEGACY_TARGET}=hash:'"
assert_eq "hash snapshot with empty digest fails" "1" "$TL_STATUS"
tl_stub stat 'exit 1'
fn_run "assert_guard_unchanged '${LEGACY_TARGET}=0'"
assert_eq "legacy snapshot: unreadable mtime counts as 0" "0" "$TL_STATUS"
/bin/rm -f "$TL_BIN/stat"; hash -r

# leanctx_binary_ok: --version, then --help
LC_NOVERSION=1 fn_run 'leanctx_binary_ok'
assert_eq "binary ok: --version fails but --help works" "0" "$TL_STATUS"
LC_NOVERSION=1 LC_BROKEN=1 fn_run 'leanctx_binary_ok'
assert_eq "binary not ok: both --version and --help fail" "1" "$TL_STATUS"
fn_run 'leanctx_binary_ok'
assert_eq "binary ok: --version works" "0" "$TL_STATUS"

# helpers that the main flow only reaches in special situations
fn_run 'HOST=nowhere; context_mode_configured'
assert_eq "context_mode_configured: unknown host" "1" "$TL_STATUS"
fn_run 'leanctx_cli_path() { return 1; }; leanctx_supports_library_mode'
assert_eq "library mode: no binary" "1" "$TL_STATUS"
fn_run 'HOST=codex; n=0; leanctx_binary_ok() { return 0; }; leanctx_cli_path() { return 1; }; verify_wire_proxy_ordering'
assert_eq "wire-proxy verify: codex without a resolvable binary only warns" "0" "$TL_STATUS"
assert_contains "wire-proxy verify: warns" "$TL_ERR" "lean-ctx proxy subcommand not found"

tl_results
