#!/usr/bin/env bash
# Behavior tests for scripts/sb-verify-synergy.sh, scripts/sb-prerequisite-repair.sh
# and the error paths of scripts/sb-bootstrap.sh. Scripts that resolve their repo
# root from their own location run from a staged copy so nothing touches the checkout.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
cd "$TL_TMP"
unset CI SB_STACK_OPTIMIZER_DRY_RUN SB_AGENTMEMORY_HOME

# ---------- sb-verify-synergy.sh ----------
ST="$TL_TMP/stage"
mkdir -p "$ST/scripts" "$ST/hooks"
cp "$TL_REPO_ROOT/scripts/sb-verify-synergy.sh" "$ST/scripts/"
ln -s "$TL_REPO_ROOT/hooks/lib" "$ST/hooks/lib"
VS="$ST/scripts/sb-verify-synergy.sh"

tl_run bash "$VS" --help
assert_eq "help exits 0" "0" "$TL_STATUS"
assert_contains "help usage" "$TL_OUT" "Usage: bash scripts/sb-verify-synergy.sh"

tl_run bash "$VS" --bogus
assert_eq "unknown option exits 2" "2" "$TL_STATUS"
assert_contains "unknown option message" "$TL_ERR" "Unknown option: --bogus"

tl_run bash "$VS"
assert_eq "missing config exits 1" "1" "$TL_STATUS"
assert_contains "missing config message" "$TL_ERR" ".silver-bullet.json missing"

# nothing opted in: score 0, no fails -> NEEDS_WORK, still exit 0
printf '{}\n' >"$ST/.silver-bullet.json"
tl_run bash "$VS"
assert_eq "no opt-in exits 0" "0" "$TL_STATUS"
assert_contains "no opt-in verdict" "$TL_OUT" "Synergy audit verdict: NEEDS_WORK (score=0/100, fails=0, warns=0)"
assert_contains "no opt-in report line" "$TL_OUT" "skip|graphify-opt|graphify not opted in|0"
assert_file_absent "no report without flag" "$ST/SETUP_REPORT.md"

# graphify opted in but nothing installed: fails > 0 -> NEEDS_WORK and exit 1
printf '{"recommended_tools":{"graphify":{"enabled_by_user":true}}}\n' >"$ST/.silver-bullet.json"
tl_run bash "$VS"
assert_eq "fails exit 1" "1" "$TL_STATUS"
assert_contains "fails verdict" "$TL_OUT" "Synergy audit verdict: NEEDS_WORK"
assert_contains "fails counted" "$TL_OUT" "fails=2"
assert_contains "fail row" "$TL_OUT" "fail|graphify-cli|CLI missing|10"

# --write-setup-report appends the addendum (also when verdict fails)
tl_run bash "$VS" --write-setup-report
assert_eq "report run keeps exit 1 on fails" "1" "$TL_STATUS"
assert_contains "report announced" "$TL_OUT" "Appended addendum to SETUP_REPORT.md"
REP="$(cat "$ST/SETUP_REPORT.md")"
assert_contains "addendum heading" "$REP" "## Optimization verification addendum ("
assert_contains "addendum verdict row" "$REP" "| Verdict | NEEDS_WORK |"
assert_contains "addendum fails row" "$REP" "| Fails | 2 |"
tl_run bash "$VS" --write-setup-report
assert_eq "second append" "2" "$(grep -c '^## Optimization verification addendum' "$ST/SETUP_REPORT.md")"

# ACCEPTABLE / OPTIMAL verdicts: score thresholds with no fails. Stub the
# optimizer library with fixed scores.
mk_stub_lib() {  # score fails
  rm -rf "$ST/hooks"; mkdir -p "$ST/hooks/lib"
  cat >"$ST/hooks/lib/stack-optimizer.sh" <<STUB
sb_optimization_score() { export SB_STACK_SCORE=$1 SB_STACK_SCORE_FAILS=$2 SB_STACK_SCORE_WARNS=1 SB_STACK_SCORE_REPORT='pass|x|y|10\\n'; printf '%s' $1; }
STUB
}
mk_stub_lib 85 0
tl_run bash "$VS"
assert_eq "optimal exit 0" "0" "$TL_STATUS"
assert_contains "optimal verdict" "$TL_OUT" "Synergy audit verdict: OPTIMAL (score=85/100, fails=0, warns=1)"
mk_stub_lib 60 0
tl_run bash "$VS"
assert_contains "acceptable verdict" "$TL_OUT" "Synergy audit verdict: ACCEPTABLE (score=60/100"
mk_stub_lib 59 0
tl_run bash "$VS"
assert_contains "below 60 needs work" "$TL_OUT" "Synergy audit verdict: NEEDS_WORK (score=59/100"
mk_stub_lib 95 1
tl_run bash "$VS"
assert_eq "high score with a fail exits 1" "1" "$TL_STATUS"
assert_contains "high score with a fail is NEEDS_WORK" "$TL_OUT" "Synergy audit verdict: NEEDS_WORK (score=95/100, fails=1"

# ---------- sb-prerequisite-repair.sh ----------
PR="$TL_REPO_ROOT/scripts/sb-prerequisite-repair.sh"
LOG="$TL_TMP/pkg.log"
: >"$LOG"
NOJQ="$(tl_path_without jq brew apt-get sudo)"

tl_run bash "$PR" "$TL_TMP"
assert_eq "jq present exits 0" "0" "$TL_STATUS"

# jq missing, no package manager -> exit 1
PATH_SAVE="$PATH"
PATH="$NOJQ" tl_run bash "$PR" "$TL_TMP"
assert_eq "no jq and no manager exits 1" "1" "$TL_STATUS"

# jq missing, brew present: brew install jq attempted (still missing -> exit 1)
tl_stub brew 'echo "brew $*" >>"'"$LOG"'"; exit 1'
NOJQ_BREW="$(tl_path_without jq apt-get sudo)"
PATH="$NOJQ_BREW" tl_run bash "$PR" "$TL_TMP"
assert_eq "brew failure tolerated, still exits 1" "1" "$TL_STATUS"
assert_contains "brew install jq attempted" "$(cat "$LOG")" "brew install jq"
# brew that really "installs" jq: next probe finds it
JQREAL="$(command -v jq)"
mkdir -p "$TL_TMP/instbin"
tl_stub brew 'echo "brew $*" >>"'"$LOG"'"; ln -sf "'"$JQREAL"'" "'"$TL_TMP"'/instbin/jq"'
NOJQ_BREW2="$(tl_path_without jq apt-get sudo)"
PATH="$NOJQ_BREW2:$TL_TMP/instbin" tl_run bash "$PR" "$TL_TMP"
assert_eq "brew installing jq gives exit 0" "0" "$TL_STATUS"
rm -f "$TL_BIN/brew"

# jq missing, apt-get present (no brew): sudo apt-get install -y jq
: >"$LOG"
tl_stub apt-get 'exit 0'
tl_stub sudo 'echo "sudo $*" >>"'"$LOG"'"; exit 1'
NOJQ_APT="$(tl_path_without jq brew)"
PATH="$NOJQ_APT" tl_run bash "$PR" "$TL_TMP"
assert_eq "apt failure tolerated, exits 1" "1" "$TL_STATUS"
assert_contains "sudo apt-get install attempted" "$(cat "$LOG")" "sudo apt-get install -y jq"
rm -f "$TL_BIN/apt-get" "$TL_BIN/sudo"
PATH="$PATH_SAVE"

# plugin cache repair is invoked with the repo root when a cache exists
SD="$TL_TMP/prscripts"
mkdir -p "$SD/lib"
cp "$PR" "$SD/"
cat >"$SD/lib/plugin-cache-version.sh" <<STUB
sb_claude_ensure_plugin_cache_ready() { echo "ensure \$1" >>"$LOG"; return 1; }
STUB
: >"$LOG"
tl_run bash "$SD/sb-prerequisite-repair.sh" "/some/repo"
assert_eq "failing cache repair tolerated" "0" "$TL_STATUS"
assert_contains "cache repair receives repo root" "$(cat "$LOG")" "ensure /some/repo"
: >"$LOG"
(cd "$TL_TMP/home" && bash "$SD/sb-prerequisite-repair.sh" >/dev/null 2>&1)
assert_contains "repo root defaults to PWD" "$(cat "$LOG")" "ensure $TL_TMP/home"

# ---------- sb-bootstrap.sh ----------
BS="$TL_REPO_ROOT/scripts/sb-bootstrap.sh"
PATH="$(tl_path_without jq)" tl_run bash "$BS" "$TL_TMP"
assert_eq "bootstrap without jq exits 1" "1" "$TL_STATUS"
assert_contains "bootstrap jq failure message" "$TL_OUT" "FAIL: jq is required."
assert_contains "bootstrap macOS hint" "$TL_OUT" "brew install jq"
assert_not_contains "bootstrap stops before diagnostics" "$TL_OUT" "PASS: jq installed"

# staged bootstrap: diagnostics script missing / failing, project initialized or not
BD="$TL_TMP/bs"
mkdir -p "$BD"
cp "$BS" "$BD/"
TGT="$TL_TMP/target"; mkdir -p "$TGT"
tl_run bash "$BD/sb-bootstrap.sh" "$TGT"
assert_eq "bootstrap without diagnostics exits 0" "0" "$TL_STATUS"
assert_contains "diagnostics missing warning" "$TL_OUT" "WARN: sb-diagnostics.sh not found"
assert_contains "uninitialized project guidance" "$TL_OUT" "Project: not initialized"
assert_contains "init step" "$TL_OUT" "In this repo, run: /sb:init"
assert_contains "graphify hint" "$TL_OUT" "uv tool install graphifyy"

printf '#!/usr/bin/env bash\necho DIAG-RAN; exit 3\n' >"$BD/sb-diagnostics.sh"; chmod +x "$BD/sb-diagnostics.sh"
printf '{}\n' >"$TGT/.silver-bullet.json"
tl_run bash "$BD/sb-bootstrap.sh" "$TGT"
assert_eq "failing diagnostics tolerated" "0" "$TL_STATUS"
assert_contains "diagnostics ran" "$TL_OUT" "DIAG-RAN"
assert_contains "initialized project message" "$TL_OUT" "Silver Bullet already initialized in $TGT"
assert_contains "next step" "$TL_OUT" "run /sb in your coding agent"
assert_not_contains "no init guidance when initialized" "$TL_OUT" "Project: not initialized"

(cd "$TGT" && bash "$BD/sb-bootstrap.sh") >"$TL_TMP/o.txt" 2>&1
assert_contains "target defaults to PWD" "$(cat "$TL_TMP/o.txt")" "already initialized in $TGT"

tl_results
