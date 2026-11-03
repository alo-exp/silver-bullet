#!/usr/bin/env bash
# Behavior tests for the modes and option parsing of scripts/sb-optimize-stack.sh.
# The script runs from a staged copy (it resolves its repo root and config from its
# own location); graphify and agentmemory are absent from PATH.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
source "$TL_REPO_ROOT/tests/lib/consent-helpers.sh"
cd "$TL_TMP"
unset CI SB_STACK_OPTIMIZER_DRY_RUN SB_AGENTMEMORY_HOME SB_STACK_SKIP_HOST_HOOKS
export SB_STACK_SKIP_HOST_HOOKS=1
export SB_AGENTMEMORY_HOME="$TL_TMP/amhome"

ST="$TL_TMP/stage"
mkdir -p "$ST/scripts" "$ST/hooks" "$ST/templates"
cp "$TL_REPO_ROOT/scripts/sb-optimize-stack.sh" "$ST/scripts/"
ln -s "$TL_REPO_ROOT/hooks/lib" "$ST/hooks/lib"
ln -s "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$ST/templates/silver-bullet.config.json.default"
S="$ST/scripts/sb-optimize-stack.sh"
cd "$ST"   # the optimized project is the working directory (not the Silver Bullet checkout the script lives in)
CFG="$ST/.silver-bullet.json"
OPTED='{"recommended_tools":{"graphify":{"enabled_by_user":true},"agentmemory":{"enabled_by_user":true}}}'

# ---------- option parsing ----------
tl_run bash "$S" --help
assert_eq "help exits 0" "0" "$TL_STATUS"
assert_contains "help usage text" "$TL_OUT" "Usage: bash scripts/sb-optimize-stack.sh [--apply|--verify|--report]"
assert_contains "help lists --host" "$TL_OUT" "--host HOST"

tl_run bash "$S" --bogus
assert_eq "unknown option exits 2" "2" "$TL_STATUS"
assert_contains "unknown option named" "$TL_ERR" "Unknown option: --bogus"
assert_contains "usage printed to stderr" "$TL_ERR" "Usage: bash scripts/sb-optimize-stack.sh"

# ---------- verify ----------
printf '{}\n' >"$CFG"
sb_test_consent_reset_mirror "$CFG" install,wire,enforce
tl_run bash "$S" --verify
assert_eq "verify without opt-in exits 0" "0" "$TL_STATUS"
assert_contains "verify header" "$TL_OUT" "== Stack optimization verify (profile=synergy_max) =="
assert_contains "verify score line" "$TL_OUT" "Score: 0/100 | fails=0 warns=0"
assert_contains "verify report rows" "$TL_OUT" "skip|graphify-opt|graphify not opted in|0"
assert_eq "verify stamped last_verified_at" "true" "$(jq -r '.recommended_tools.graphify.optimization.last_verified_at | type == "string"' "$CFG")"
assert_eq "verify stores the score" "0" "$(jq -r '.recommended_tools.agentmemory.optimization.score' "$CFG")"

# opted in with no tools installed: critical gaps -> exit 1 (and the score line shows the fails)
printf '%s\n' "$OPTED" >"$CFG"
sb_test_consent_reset_mirror "$CFG" install,wire,enforce
tl_run bash "$S" --verify
assert_eq "verify with gaps exits 1" "1" "$TL_STATUS"
assert_contains "verify counts fails" "$TL_OUT" "fails=5"
assert_contains "verify lists a failing check" "$TL_OUT" "fail|graphify-cli|CLI missing|10"
assert_eq "verify keeps no applied stamp" "null" "$(jq -r '.recommended_tools.graphify.optimization.last_applied_at' "$CFG")"

# agentmemory alone is enough to enforce
printf '{"recommended_tools":{"agentmemory":{"enabled_by_user":true}}}\n' >"$CFG"
sb_test_consent_reset_mirror "$CFG" install,wire,enforce
tl_run bash "$S" --verify
assert_eq "verify agentmemory-only gaps exit 1" "1" "$TL_STATUS"

# --dry-run verify does not touch the config
printf '{}\n' >"$CFG"
sb_test_consent_reset_mirror "$CFG" install,wire,enforce
tl_run bash "$S" --verify --dry-run
assert_eq "dry-run verify exits 0" "0" "$TL_STATUS"
assert_eq "dry-run verify leaves config untouched" "{}" "$(jq -c . "$CFG")"

# no project config: falls back to the template and writes nothing
rm -f "$CFG"
tl_run bash "$S" --verify
assert_eq "verify with template config exits 0" "0" "$TL_STATUS"
assert_contains "verify with template config header" "$TL_OUT" "== Stack optimization verify"
assert_file_absent "no project config created" "$CFG"

# ---------- report ----------
printf '%s\n' "$OPTED" >"$CFG"
sb_test_consent_reset_mirror "$CFG" install,wire,enforce
tl_run bash "$S" --report
assert_eq "report exits 0" "0" "$TL_STATUS"
assert_contains "report title" "$TL_OUT" "# Stack Optimization Report"
assert_contains "report verdict" "$TL_OUT" "- **Verdict:** NEEDS_WORK"
assert_contains "report fails" "$TL_OUT" "- **Fails:** 5"
assert_contains "report table spacing" "$TL_OUT" "fail | graphify-cli | CLI missing | 10"
assert_contains "report next steps" "$TL_OUT" "bash scripts/sb-optimize-stack.sh --apply"
assert_contains "report host" "$TL_OUT" "- **Host:** claude"

# --host overrides the runtime host
tl_run bash "$S" --report --host codex
assert_contains "host override in report" "$TL_OUT" "- **Host:** codex"
tl_run bash "$S" --report --host
assert_eq "--host without a value is a usage error" "2" "$TL_STATUS"
assert_contains "--host without a value is explained" "$TL_ERR" "--host requires a value"

# verdict thresholds with a stubbed score
mk_lib() {  # score fails
  rm -rf "$ST/hooks"; mkdir -p "$ST/hooks/lib"
  cat >"$ST/hooks/lib/stack-optimizer.sh" <<STUB
sb_runtime_host() { printf '%s' "\${SILVER_BULLET_RUNTIME:-claude}"; }
sb_stack_optimization_profile_name() { printf 'p'; }
sb_recommended_tool_consent() { printf 'enabled'; }
sb_optimization_score() { export SB_STACK_SCORE=$1 SB_STACK_SCORE_FAILS=$2 SB_STACK_SCORE_WARNS=0 SB_STACK_SCORE_REPORT=''; printf '%s' $1; }
STUB
}
mk_lib 90 0; tl_run bash "$S" --report; assert_contains "OPTIMAL verdict" "$TL_OUT" "- **Verdict:** OPTIMAL"
mk_lib 70 0; tl_run bash "$S" --report; assert_contains "ACCEPTABLE verdict" "$TL_OUT" "- **Verdict:** ACCEPTABLE"
mk_lib 90 2; tl_run bash "$S" --report; assert_contains "fails force NEEDS_WORK" "$TL_OUT" "- **Verdict:** NEEDS_WORK"

# ---------- apply ----------
rm -rf "$ST/hooks"; mkdir -p "$ST/hooks"; ln -s "$TL_REPO_ROOT/hooks/lib" "$ST/hooks/lib"
printf '{}\n' >"$CFG"
sb_test_consent_reset_mirror "$CFG" install,wire,enforce
tl_run bash "$S" --apply
assert_eq "apply without opt-in exits 0" "0" "$TL_STATUS"
assert_contains "apply header" "$TL_OUT" "== SB stack optimize (profile=synergy_max, host=claude) =="
assert_contains "apply score line" "$TL_OUT" "Optimization score: 0/100 (fails=0 warns=0)"
assert_eq "apply stamped last_applied_at" "true" "$(jq -r '.recommended_tools.graphify.optimization.last_applied_at | type == "string"' "$CFG")"

printf '{}\n' >"$CFG"
sb_test_consent_reset_mirror "$CFG" install,wire,enforce
tl_run bash "$S" --dry-run
assert_eq "dry-run apply is the default mode and exits 0" "0" "$TL_STATUS"
assert_eq "dry-run apply leaves config untouched" "{}" "$(jq -c . "$CFG")"

# apply with critical gaps fails the run (dry-run so nothing is installed)
printf '%s\n' "$OPTED" >"$CFG"
sb_test_consent_reset_mirror "$CFG" install,wire,enforce
tl_run bash "$S" --apply --dry-run
assert_eq "apply with gaps exits 1" "1" "$TL_STATUS"
assert_contains "apply prints the failing score" "$TL_OUT" "fails=5"

# ---------- the project is the working directory or --project-root, never the plugin (R6-23) ----------
sb_test_consent_revoke_all   # no tool consented: the score has no critical gaps, so the runs below exit 0
USERPROJ="$TL_TMP/userproj"; mkdir -p "$USERPROJ"
printf '{}\n' >"$USERPROJ/.silver-bullet.json"
printf '{"plugin":"config"}\n' >"$CFG"          # the Silver Bullet checkout's own file must stay untouched
TEMPLATE_BEFORE="$(cksum <"$ST/templates/silver-bullet.config.json.default")"
in_dir() { local d="$1"; shift; tl_run bash -c 'cd "$1" && shift && exec "$@"' _ "$d" "$@"; }
in_dir "$TL_TMP" bash "$S" --apply --project-root "$USERPROJ"
assert_eq "apply for another project exits 0" "0" "$TL_STATUS"
assert_eq "the project's file was stamped" "true" "$(jq -r '.recommended_tools.graphify.optimization.last_applied_at | type == "string"' "$USERPROJ/.silver-bullet.json")"
assert_eq "the plugin's own file was not touched" '{"plugin":"config"}' "$(jq -c . "$CFG")"
in_dir "$USERPROJ" bash "$S" --verify
assert_eq "verify from inside the project uses its file" "0" "$TL_STATUS"
assert_eq "the project's file records the verify" "true" "$(jq -r '.recommended_tools.graphify.optimization.last_verified_at | type == "string"' "$USERPROJ/.silver-bullet.json")"
# a project without a config: apply reads the template and creates/changes nothing
EMPTYPROJ="$TL_TMP/emptyproj"; mkdir -p "$EMPTYPROJ"
tl_run bash "$S" --apply --project-root "$EMPTYPROJ"
assert_eq "apply for a project without a config exits 0" "0" "$TL_STATUS"
assert_file_absent "no config is created for it" "$EMPTYPROJ/.silver-bullet.json"
assert_eq "the template is not rewritten" "$TEMPLATE_BEFORE" "$(cksum <"$ST/templates/silver-bullet.config.json.default")"
tl_run bash "$S" --project-root
assert_eq "--project-root without a value is a usage error" "2" "$TL_STATUS"
assert_contains "--project-root without a value is explained" "$TL_ERR" "--project-root requires a value"
tl_run bash "$S" --verify --project-root "$TL_TMP/no-such-dir"
assert_eq "a missing project root is refused" "2" "$TL_STATUS"
assert_contains "the missing project root is named" "$TL_ERR" "Not a directory: $TL_TMP/no-such-dir"
GITPROJ="$TL_TMP/gitproj"; tl_git_repo "$GITPROJ"; mkdir -p "$GITPROJ/sub"; printf '{}\n' >"$GITPROJ/.silver-bullet.json"
in_dir "$GITPROJ/sub" bash "$S" --verify
assert_eq "from a subdirectory the repository top level is the project" "true" "$(jq -r '.recommended_tools.graphify.optimization.last_verified_at | type == "string"' "$GITPROJ/.silver-bullet.json")"

tl_results
