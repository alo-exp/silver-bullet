#!/usr/bin/env bash
# The shipped host adapters (scripts/lib/agent-adapters/*.sh) against fake CLIs on PATH: CLI
# resolution, preflight, argv/env assembly, log writing, error paths, Codex transcripts (private,
# redacted, never under SB_ROOT) and OpenCode/Pi/Claude permission flags. No real host CLI or network.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

AD="$TL_REPO_ROOT/scripts/lib/agent-adapters"
W="$TL_TMP/work"; mkdir -p "$W" "$TL_TMP/tmp" "$TL_TMP/bins"
export PYTHONDONTWRITEBYTECODE=1

# ad HOST SNIPPET [ENV=VAL...]: run SNIPPET after sourcing the adapter, in a clean delegation env
ad() {
  local host="$1" snippet="$2" name
  shift 2
  local -a unset_args=()
  while IFS= read -r name; do
    unset_args+=(-u "$name")
  done < <(compgen -e | grep -E '^(SB_LIVE_|SB_AGENT_|SB_E2E_|SB_ROOT|SB_MULTI|CODEX_|CLAUDE_|OPENCODE_|PI_|WORK_DIR)' | grep -v '^SB_COV_' || true)
  tl_run timeout 120 env "${unset_args[@]}" TMPDIR="$TL_TMP/tmp" WORK_DIR="$W" TL_TMP="$TL_TMP" "$@" \
    bash -c 'source "$1"; shift; eval "$1"' _ "$AD/$host.sh" "$snippet"
}

stub_cli() { # stub_cli NAME DIR BODY
  mkdir -p "$2"
  printf '#!/usr/bin/env bash\nif [[ "${1:-}" == "--version" ]]; then echo "%s 0.0.0"; exit 0; fi\n%s\n' "$1" "$3" >"$2/$1"
  chmod +x "$2/$1"
}

# ============================================================ OpenCode
OB="$TL_TMP/bins/oc"; ARGV_OC="$TL_TMP/oc.argv"
stub_cli opencode "$OB" "printf '%s\n' \"\$*\" >>'$ARGV_OC'; echo oc-out"
ad opencode 'agent_name' 
assert_eq "opencode: agent_name" "opencode" "$TL_OUT"
ad opencode 'agent_cli_path' OPENCODE_BIN="$OB/opencode"
assert_eq "opencode: cli path" "$OB/opencode" "$TL_OUT"
ad opencode 'agent_cli_path; echo rc=$?' PATH="$(tl_path_without opencode)" OPENCODE_BIN="" HOME="$TL_TMP/nohome"
assert_contains "opencode: missing cli explained" "$TL_ERR" "native OpenCode CLI not found"
mkdir -p "$TL_TMP/bins/OpenCode.app"; stub_cli opencode "$TL_TMP/bins/OpenCode.app" "exit 0"
ad opencode 'agent_cli_path; echo rc=$?' OPENCODE_BIN="$TL_TMP/bins/OpenCode.app/opencode"
assert_contains "opencode: desktop app refused" "$TL_ERR$TL_OUT" "OpenCode.app"
ad opencode 'agent_preflight; echo rc=$?' OPENCODE_BIN="$OB/opencode"
assert_contains "opencode: preflight ok" "$TL_OUT" "rc=0"
stub_cli opencode "$TL_TMP/bins/oc-broken" "exit 0"; printf '#!/usr/bin/env bash\nexit 3\n' >"$TL_TMP/bins/oc-broken/opencode"
ad opencode 'agent_preflight; echo rc=$?' OPENCODE_BIN="$TL_TMP/bins/oc-broken/opencode"
assert_contains "opencode: preflight with a non-working cli fails" "$TL_ERR$TL_OUT" "rc=1"
ad opencode 'agent_preflight; echo rc=$?' OPENCODE_BIN="$OB/opencode" OPENCODE_MODEL=other
assert_contains "opencode: preflight enforces the model pin" "$TL_ERR" "mimo"
ad opencode 'agent_preflight; echo rc=$?' PATH="$(tl_path_without opencode)" OPENCODE_BIN="" HOME="$TL_TMP/nohome"
assert_contains "opencode: preflight without a cli fails" "$TL_OUT" "rc=1"
ad opencode 'agent_invoke permissive hi; echo rc=$?' PATH="$(tl_path_without opencode)" OPENCODE_BIN="" HOME="$TL_TMP/nohome"
assert_contains "opencode: invoke without a cli fails" "$TL_OUT" "rc=1"
ad opencode 'agent_invoke permissive hi; echo rc=$?' OPENCODE_BIN="$OB/opencode" OPENCODE_MODEL=other
assert_contains "opencode: invoke enforces the model pin" "$TL_OUT" "rc=1"
ad opencode 'unset WORK_DIR; agent_invoke permissive hi; echo rc=$?' OPENCODE_BIN="$OB/opencode"
assert_contains "opencode: invoke needs a work dir" "$TL_ERR" "OPENCODE_WORK_DIR or WORK_DIR required"
ad opencode 'agent_invoke permissive hi; echo rc=$?' OPENCODE_BIN="$OB/opencode" WORK_DIR="$TL_TMP/nodir"
assert_contains "opencode: invoke needs a real work dir" "$TL_ERR" "not a directory"
: >"$ARGV_OC"
ad opencode 'agent_invoke permissive "do it"' OPENCODE_BIN="$OB/opencode" OPENCODE_RUN_LOG_FILE="$TL_TMP/oc.log" OPENCODE_RUN_TAIL_IDLE_TIMEOUT=2
assert_contains "opencode: NI output returned" "$TL_OUT" "oc-out"
assert_contains "opencode: permissive adds --auto" "$(cat "$ARGV_OC")" "--auto"
assert_contains "opencode: NI log written" "$(cat "$TL_TMP/oc.log")" "oc-out"
: >"$ARGV_OC"
ad opencode 'agent_invoke strict "do it"' OPENCODE_BIN="$OB/opencode" OPENCODE_RUN_TAIL_IDLE_TIMEOUT=2
assert_not_contains "opencode: strict never adds --auto (NI)" "$(cat "$ARGV_OC")" "--auto"
assert_contains "opencode: strict NI still runs" "$(cat "$ARGV_OC")" "run --dir"
stub_cli opencode "$TL_TMP/bins/oc-tui" "printf 'tui-argv:%s\n' \"\$*\"; exit \"\${OC_TUI_RC:-0}\""
ad opencode 'agent_invoke permissive "do it"' OPENCODE_BIN="$TL_TMP/bins/oc-tui/opencode" OPENCODE_USE_INTERACTIVE=1 OPENCODE_RUN_LOG_FILE="$TL_TMP/oc-tui.log" OPENCODE_RUN_TIMEOUT=20
assert_contains "opencode: TUI permissive carries --auto and the prompt" "$TL_OUT" "--auto --prompt do it"
assert_contains "opencode: TUI log written" "$(cat "$TL_TMP/oc-tui.log")" "tui-argv"
ad opencode 'agent_invoke strict "do it"' OPENCODE_BIN="$TL_TMP/bins/oc-tui/opencode" OPENCODE_USE_INTERACTIVE=1 OPENCODE_RUN_TIMEOUT=20
assert_not_contains "opencode: TUI strict never adds --auto" "$TL_OUT" "--auto"
ad opencode 'agent_invoke strict "do it"; echo rc=$?' OPENCODE_BIN="$TL_TMP/bins/oc-tui/opencode" OPENCODE_USE_INTERACTIVE=1 OPENCODE_RUN_TIMEOUT=20 OC_TUI_RC=4
assert_contains "opencode: TUI failure maps to mode-unavailable (3)" "$TL_OUT" "rc=3"

# ============================================================ Pi
PB="$TL_TMP/bins/pi"
stub_cli pi "$PB" "printf '%s\n' \"\$*\" >>'$TL_TMP/pi.argv'; echo pi-out"
ad pi 'agent_name'
assert_eq "pi: agent_name" "pi" "$TL_OUT"
ad pi 'agent_cli_path' PI_BIN="$PB/pi"
assert_eq "pi: cli path" "$PB/pi" "$TL_OUT"
ad pi 'agent_cli_path; echo rc=$?' PATH="$(tl_path_without pi)" PI_BIN="" HOME="$TL_TMP/nohome"
assert_contains "pi: missing cli explained" "$TL_ERR" "Pi CLI not found"
ad pi 'agent_preflight; echo rc=$?' PI_BIN="$PB/pi"
assert_contains "pi: preflight ok" "$TL_OUT" "rc=0"
stub_cli pi "$TL_TMP/bins/pi-broken" "exit 0"; printf '#!/usr/bin/env bash\nexit 3\n' >"$TL_TMP/bins/pi-broken/pi"
ad pi 'agent_preflight; echo rc=$?' PI_BIN="$TL_TMP/bins/pi-broken/pi"
assert_contains "pi: preflight with a non-working cli fails" "$TL_OUT" "rc=1"
ad pi 'agent_preflight; echo rc=$?' PI_BIN="$PB/pi" PI_MODEL=other
assert_contains "pi: preflight enforces the model pin" "$TL_OUT" "rc=1"
ad pi 'agent_preflight; echo rc=$?' PATH="$(tl_path_without pi)" PI_BIN="" HOME="$TL_TMP/nohome"
assert_contains "pi: preflight without a cli fails" "$TL_OUT" "rc=1"
ad pi 'agent_invoke permissive hi; echo rc=$?' PATH="$(tl_path_without pi)" PI_BIN="" HOME="$TL_TMP/nohome"
assert_contains "pi: invoke without a cli fails" "$TL_OUT" "rc=1"
ad pi 'agent_invoke permissive hi; echo rc=$?' PI_BIN="$PB/pi" PI_MODEL=other
assert_contains "pi: invoke enforces the model pin" "$TL_OUT" "rc=1"
ad pi 'unset WORK_DIR; agent_invoke permissive hi; echo rc=$?' PI_BIN="$PB/pi"
assert_contains "pi: invoke needs a work dir" "$TL_ERR" "PI_WORK_DIR or WORK_DIR required"
ad pi 'agent_invoke permissive "do it"' PI_BIN="$PB/pi" PI_RUN_LOG_FILE="$TL_TMP/pi.log" PI_RUN_TAIL_IDLE_TIMEOUT=2
assert_contains "pi: NI output returned" "$TL_OUT" "pi-out"
assert_contains "pi: NI log written" "$(cat "$TL_TMP/pi.log")" "pi-out"
ad pi 'agent_invoke permissive "do it"; echo rc=$?' PI_BIN="$PB/pi" PI_USE_INTERACTIVE=1 PI_RUN_LOG_FILE="$TL_TMP/pi-tui.log" PI_RUN_TIMEOUT=20 SB_ROOT="$TL_REPO_ROOT"
assert_contains "pi: interactive output returned" "$TL_OUT" "pi-out"
assert_contains "pi: interactive log written" "$(cat "$TL_TMP/pi-tui.log")" "pi-out"
stub_cli pi "$TL_TMP/bins/pi-fail" "exit 4"
ad pi 'agent_mode_fail_unavailable() { echo FAIL-UNAVAILABLE "$1"; }; agent_invoke permissive "do it"; echo rc=$?' PI_BIN="$TL_TMP/bins/pi-fail/pi" PI_USE_INTERACTIVE=1 PI_RUN_TIMEOUT=20 SB_ROOT="$TL_REPO_ROOT"
assert_contains "pi: interactive failure maps to mode-unavailable (3)" "$TL_OUT" "rc=3"
assert_contains "pi: interactive failure reports through agent-mode when loaded" "$TL_OUT" "FAIL-UNAVAILABLE mode-unavailable"
ad pi 'agent_invoke permissive "do it"; echo rc=$?' PI_BIN="$TL_TMP/bins/pi-fail/pi" PI_USE_INTERACTIVE=1 PI_RUN_TIMEOUT=20 SB_ROOT="$TL_REPO_ROOT"
assert_contains "pi: interactive failure without agent-mode loaded" "$TL_OUT" "rc=3"
ad pi 'agent_invoke permissive "do it"' PI_BIN="$PB/pi" PI_USE_INTERACTIVE=1 SB_ROOT="$TL_TMP/no-sb-root" PI_RUN_TAIL_IDLE_TIMEOUT=2
assert_contains "pi: interactive without the host-exec lib falls back to the plain run" "$TL_OUT" "pi-out"

# ============================================================ Codex
CB="$TL_TMP/bins/codex"
stub_cli codex "$CB" "echo codex-out"
ad codex 'agent_name'
assert_eq "codex: agent_name" "codex" "$TL_OUT"
ad codex 'agent_cli_path' CODEX_BIN="$CB/codex"
assert_eq "codex: cli path" "$CB/codex" "$TL_OUT"
ad codex 'agent_cli_path; echo rc=$?' PATH="$(tl_path_without codex)" CODEX_BIN="" HOME="$TL_TMP/nohome"
assert_contains "codex: missing cli explained" "$TL_ERR" "native Codex CLI not found"
mkdir -p "$TL_TMP/bins/kay"; stub_cli codex "$TL_TMP/bins/kay" "exit 0"; cp "$TL_TMP/bins/kay/codex" "$TL_TMP/bins/kay/notcodex"
ad codex 'agent_cli_path; echo rc=$?' CODEX_BIN="$TL_TMP/bins/kay/notcodex"
assert_contains "codex: a non-codex binary is refused" "$TL_ERR$TL_OUT" "rc=1"
ad codex 'agent_preflight; echo rc=$?' CODEX_BIN="$CB/codex"
assert_contains "codex: preflight ok" "$TL_OUT" "rc=0"
ad codex 'agent_preflight; echo rc=$?' PATH="$(tl_path_without codex)" CODEX_BIN="" HOME="$TL_TMP/nohome"
assert_contains "codex: preflight without a cli fails" "$TL_OUT" "rc=1"
ad codex 'agent_invoke permissive hi; echo rc=$?' CODEX_BIN="$CB/codex" WORK_DIR="$TL_TMP/nodir"
assert_contains "codex: invoke needs a real work dir" "$TL_ERR" "WORK_DIR required"
# --- exec path: guard context, requested-skill hook
mkdir -p "$TL_TMP/sbroot/hooks" "$TL_TMP/rt/.silver-bullet"
printf '#!/usr/bin/env bash\ncat >"%s/seed.json"\n' "$TL_TMP" >"$TL_TMP/sbroot/hooks/record-requested-skill.sh"; chmod +x "$TL_TMP/sbroot/hooks/record-requested-skill.sh"
ad codex 'agent_invoke permissive "guarded"' CODEX_BIN="$CB/codex" SB_ROOT="$TL_TMP/sbroot" SB_LIVE_CODEX_USE_EXEC=1 SB_LIVE_CODEX_GUARD=1 SB_RUNTIME_HOME_ROOT="$TL_TMP/rt" CODEX_EXEC_TAIL_IDLE_TIMEOUT=2
assert_contains "codex: exec output returned" "$TL_OUT" "codex-out"
assert_contains "codex: requested-skill hook received the prompt" "$(cat "$TL_TMP/seed.json")" "guarded"
# exec path: explicit model/provider/effort reach argv; a failing codex and a failing requested-skill hook are tolerated
printf '#!/usr/bin/env bash\nexit 1\n' >"$TL_TMP/sbroot/hooks/record-requested-skill.sh"
stub_cli codex "$TL_TMP/bins/codex-argv" "printf '%s\n' \"\$*\" >'$TL_TMP/codex-exec.argv'; exit 2"
ad codex 'agent_invoke permissive "m"; echo rc=$?' CODEX_BIN="$TL_TMP/bins/codex-argv/codex" SB_ROOT="$TL_TMP/sbroot" SB_LIVE_CODEX_USE_EXEC=1 CODEX_MODEL=m1 CODEX_MODEL_PROVIDER=prov CODEX_REASONING_EFFORT=high CODEX_EXEC_TAIL_IDLE_TIMEOUT=2 CODEX_AUTO_TRUST_HOOKS=0
assert_contains "codex: exec carries the model" "$(cat "$TL_TMP/codex-exec.argv")" "--model m1"
assert_contains "codex: exec carries the provider" "$(cat "$TL_TMP/codex-exec.argv")" "model_provider=prov"
assert_contains "codex: exec carries the reasoning effort" "$(cat "$TL_TMP/codex-exec.argv")" "model_reasoning_effort=high"
assert_contains "codex: a failing exec still returns 0 to the delegate" "$TL_OUT" "rc=0"
printf 'silver-quality-gates\n' >"$TL_TMP/rt/.silver-bullet/state"
ad codex 'codex_live_guard_context' SB_RUNTIME_HOME_ROOT="$TL_TMP/rt"
assert_contains "codex: guard context shows the state" "$TL_OUT" "silver-quality-gates"
rm -f "$TL_TMP/rt/.silver-bullet/state"
ad codex 'codex_live_guard_context' SB_RUNTIME_HOME_ROOT="$TL_TMP/rt"
assert_contains "codex: guard context for an empty state" "$TL_OUT" "(empty)"

# --- TUI path with a fake launcher: transcripts are private, redacted and never under SB_ROOT
FSB="$TL_TMP/fsb"; mkdir -p "$FSB/scripts" "$FSB/hooks"
cat >"$FSB/scripts/codex-interactive-invoke.py" <<'PY'
import os
print("tui ran; sandbox=%s bypass=%s" % (os.environ.get("CODEX_SANDBOX_MODE"), os.environ.get("CODEX_BYPASS")))
with open(os.environ["CODEX_TRANSCRIPT_FILE"], "w") as fh:
    fh.write('{"line": "Authorization: Bearer abcdefgh12345678"}\n')
with open(os.environ["CODEX_LAST_MESSAGE_FILE"], "w") as fh:
    fh.write("last message")
PY
ad codex 'agent_invoke permissive "tui prompt token=hunter2hunter2"' CODEX_BIN="$CB/codex" SB_ROOT="$FSB" CLAUDE_INTERACTIVE_LOG_FILE="$TL_TMP/codex-tui.log"
assert_contains "codex: TUI output returned" "$TL_OUT" "tui ran; sandbox=danger-full-access bypass=1"
assert_contains "codex: last message appended" "$TL_OUT" "last message"
assert_contains "codex: transcript location reported" "$TL_OUT" "[codex transcript archived at "
TDIR="$(sed -n 's/.*archived at \(.*\/latest.jsonl\)\].*/\1/p' <<<"$TL_OUT" | head -1)"
TDIR="$(dirname "$TDIR")"
assert_not_contains "codex: transcripts are not under SB_ROOT" "$TDIR" "$FSB"
assert_file_exists "codex: transcript written" "$TDIR/latest.jsonl"
assert_not_contains "codex: transcript redacted (bearer)" "$(cat "$TDIR/latest.jsonl")" "abcdefgh12345678"
assert_not_contains "codex: transcript redacted (prompt secret)" "$(cat "$TDIR/latest.jsonl")" "hunter2hunter2"
assert_eq "codex: transcript dir is 0700" "0o700" "$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$TDIR")"
assert_eq "codex: transcript file is 0600" "0o600" "$(python3 -c 'import os,sys;print(oct(os.stat(sys.argv[1]).st_mode & 0o777))' "$TDIR/latest.jsonl")"
assert_eq "codex: nothing written under SB_ROOT" "0" "$(find "$FSB" -newer "$FSB/scripts/codex-interactive-invoke.py" -type f | wc -l | tr -d ' ')"
assert_file_exists "codex: log written" "$TL_TMP/codex-tui.log"
# a failing launcher is tolerated
cp "$FSB/scripts/codex-interactive-invoke.py" "$FSB/scripts/launcher.ok"
printf 'import sys\nprint("launcher failed")\nsys.exit(3)\n' >"$FSB/scripts/codex-interactive-invoke.py"
ad codex 'agent_invoke permissive "p"; echo rc=$?' CODEX_BIN="$CB/codex" SB_ROOT="$FSB" CODEX_TRANSCRIPT_DIR="$TL_TMP/tdir0"
assert_contains "codex: failing TUI launcher tolerated" "$TL_OUT" "launcher failed"
cp "$FSB/scripts/launcher.ok" "$FSB/scripts/codex-interactive-invoke.py"
# explicit transcript dir (live-test isolation) is honoured; rotation keeps four archives
for i in 1 2 3 4 5 6; do
  ad codex 'agent_invoke strict "p"' CODEX_BIN="$CB/codex" SB_ROOT="$FSB" CODEX_TRANSCRIPT_DIR="$TL_TMP/tdir"
  sleep 1
done
assert_contains "codex: strict TUI uses the workspace-write sandbox" "$TL_OUT" "sandbox=workspace-write bypass=0"
assert_eq "codex: rotation keeps latest plus four archives" "5" "$(find "$TL_TMP/tdir" -name '*.jsonl' | wc -l | tr -d ' ')"
# no transcript produced: capture returns failure quietly
ad codex 'codex_capture_transcript "$TL_TMP/absent" "$TL_TMP/absent2"; echo rc=$?' CODEX_TRANSCRIPT_DIR="$TL_TMP/tdir2"
assert_contains "codex: capture without a source fails" "$TL_OUT" "rc=1"
printf '{"a":1}\n' >"$TL_TMP/src.jsonl"
ad codex 'codex_capture_transcript "$TL_TMP/src.jsonl" "$TL_TMP/absent2"' CODEX_TRANSCRIPT_DIR="$TL_TMP/tdir3"
assert_file_exists "codex: capture without a prompt file copies the source" "$TL_TMP/tdir3/latest.jsonl"

# ============================================================ Claude
KB="$TL_TMP/bins/claude"; KARGV="$TL_TMP/claude.argv"
stub_cli claude "$KB" "printf '%s\n' \"\$*\" >>'$KARGV'; echo claude-out"
stub_cli node "$TL_TMP/bins/nodebin" "exit 0"
ad claude 'agent_name'
assert_eq "claude: agent_name" "claude" "$TL_OUT"
ad claude 'agent_cli_path' CLAUDE_BIN="$KB/claude"
assert_eq "claude: cli path from CLAUDE_BIN" "$KB/claude" "$TL_OUT"
ad claude 'agent_cli_path' PATH="$KB:$PATH"
assert_eq "claude: cli path from PATH" "$KB/claude" "$TL_OUT"
ad claude 'agent_cli_path' PATH="$(tl_path_without claude)"
assert_eq "claude: bare name when nothing resolves" "claude" "$TL_OUT"
ad claude 'agent_preflight; echo rc=$?' CLAUDE_BIN="$KB/claude" PATH="$TL_TMP/bins/nodebin:$PATH"
assert_contains "claude: preflight ok" "$TL_OUT" "rc=0"
printf '#!/usr/bin/env bash\nexit 3\n' >"$TL_TMP/bins/claude-broken"; chmod +x "$TL_TMP/bins/claude-broken"
ad claude 'agent_preflight; echo rc=$?' CLAUDE_BIN="$TL_TMP/bins/claude-broken"
assert_contains "claude: preflight with a non-working cli fails" "$TL_ERR$TL_OUT" "rc=1"
ad claude 'agent_preflight; echo rc=$?' CLAUDE_BIN="$KB/claude" PATH="$(tl_path_without node)"
assert_contains "claude: preflight needs node" "$TL_ERR" "node is required"
# interactive selection table
for case in "0|/silver x|no" "1|plain|yes" "|/silver x|yes" "|/review-triad|yes" "|/ship-readiness|yes" "|use [silver] here|yes" "|plain text|no"; do
  IFS='|' read -r use prompt want <<<"$case"
  ad claude 'if claude_should_use_interactive "$P"; then echo yes; else echo no; fi' CLAUDE_USE_INTERACTIVE="$use" P="$prompt"
  assert_eq "claude: interactive selection ($use / $prompt)" "$want" "$TL_OUT"
done
ad claude 'if claude_should_use_interactive plain; then echo yes; else echo no; fi' SB_E2E_ENTERPRISE_MATRIX=1
assert_eq "claude: matrix runs are interactive" "yes" "$TL_OUT"
# non-interactive (print) path
: >"$KARGV"
ad claude 'agent_invoke permissive "do it"' CLAUDE_BIN="$KB/claude" CLAUDE_USE_INTERACTIVE=0 CLAUDE_PRINT_SKIP_SETTINGS_EXPORT=1 SB_ROOT="$TL_REPO_ROOT"
assert_contains "claude: print output returned" "$TL_OUT" "claude-out"
assert_contains "claude: permissive maps to bypassPermissions" "$(cat "$KARGV")" "--permission-mode bypassPermissions"
: >"$KARGV"
ad claude 'CLAUDE_PROMPT_COUNT=1; agent_invoke strict "again"' CLAUDE_BIN="$KB/claude" CLAUDE_USE_INTERACTIVE=0 SB_ROOT="$TL_REPO_ROOT"
assert_contains "claude: strict maps to acceptEdits" "$(cat "$KARGV")" "--permission-mode acceptEdits"
assert_contains "claude: later prompts continue the session" "$(cat "$KARGV")" "--continue"
mkdir -p "$W/.silver-bullet"; : >"$W/.silver-bullet/agent-cert-run"
stub_cli claude "$TL_TMP/bins/claude-env" "echo cert=\${SB_AGENT_CERT_RUN:-unset}"
ad claude 'agent_invoke strict x' CLAUDE_BIN="$TL_TMP/bins/claude-env/claude" CLAUDE_USE_INTERACTIVE=0 SB_ROOT="$TL_REPO_ROOT"
assert_contains "claude: cert-run marker is honoured" "$TL_OUT" "cert=1"
rm -rf "$W/.silver-bullet"
ad claude 'agent_invoke strict x' CLAUDE_BIN="$TL_TMP/bins/claude-env/claude" CLAUDE_USE_INTERACTIVE=0 SB_AGENT_CERT_RUN=true SB_ROOT="$TL_REPO_ROOT"
assert_contains "claude: cert env passes through" "$TL_OUT" "cert=true"
stub_cli claude "$TL_TMP/bins/claude-slow" "sleep 30"
ad claude 'agent_invoke strict x; echo rc=$?' CLAUDE_BIN="$TL_TMP/bins/claude-slow/claude" CLAUDE_USE_INTERACTIVE=0 CLAUDE_INTERACTIVE_TIMEOUT=1 SB_ROOT="$TL_REPO_ROOT"
assert_contains "claude: print timeout reported" "$TL_OUT" "timed out waiting for Claude prompt"
# interactive path: fake expect on PATH
stub_cli expect "$TL_TMP/bins/expect" "printf 'expect-ran mode=%s model=%s clean=%s log=%s\n' \"\$CLAUDE_PERMISSION_MODE\" \"\$CLAUDE_MODEL\" \"\$SB_E2E_MATRIX_CLEAN_ENV\" \"\${CLAUDE_INTERACTIVE_LOG_FILE:-none}\""
ad claude 'agent_invoke permissive "/silver go"' CLAUDE_BIN="$KB/claude" PATH="$TL_TMP/bins/expect:$PATH" SB_ROOT="$TL_REPO_ROOT" CLAUDE_INTERACTIVE_LOG_FILE="$TL_TMP/cl.log" SB_E2E_MATRIX_EVIDENCE_PATH=/ev SB_E2E_ENTERPRISE_MATRIX=1 SB_E2E_MATRIX_ROUTING_ROW=r1 SB_E2E_MATRIX_SKIP_SETTINGS_EXPORT=1
assert_contains "claude: interactive path runs expect with the mapped permission mode" "$TL_OUT" "expect-ran mode=bypassPermissions"
assert_contains "claude: interactive log file passed" "$TL_OUT" "log=$TL_TMP/cl.log"
ad claude 'agent_invoke strict "/silver go"' CLAUDE_BIN="$KB/claude" PATH="$TL_TMP/bins/expect:$PATH" SB_ROOT="$TL_REPO_ROOT"
assert_contains "claude: strict interactive uses acceptEdits" "$TL_OUT" "mode=acceptEdits"
ad claude 'agent_invoke strict "/silver go"' CLAUDE_BIN="$KB/claude" PATH="$TL_TMP/bins/expect:$PATH" SB_ROOT="$TL_REPO_ROOT" SB_E2E_MATRIX_CLEAN_ENV=1
assert_contains "claude: clean-env interactive path runs expect" "$TL_OUT" "expect-ran"
stub_cli expect "$TL_TMP/bins/expect-fail" "echo expect-failed; exit 1"
ad claude 'agent_invoke strict "/silver go"; echo rc=$?' CLAUDE_BIN="$KB/claude" PATH="$TL_TMP/bins/expect-fail:$PATH" SB_ROOT="$TL_REPO_ROOT"
assert_contains "claude: a failing expect is tolerated" "$TL_OUT" "expect-failed"
ad claude 'agent_invoke strict "/silver go"; echo rc=$?' CLAUDE_BIN="$KB/claude" PATH="$TL_TMP/bins/expect-fail:$PATH" SB_ROOT="$TL_REPO_ROOT" SB_E2E_MATRIX_CLEAN_ENV=1
assert_contains "claude: a failing clean-env expect is tolerated" "$TL_OUT" "expect-failed"
ad claude 'agent_invoke strict "plain"' CLAUDE_BIN="$KB/claude" CLAUDE_USE_INTERACTIVE=0 CLAUDE_PRINT_SKIP_SETTINGS_EXPORT=1
assert_contains "claude: SB_ROOT defaults to the plugin root" "$TL_OUT" "claude-out"

tl_results
