#!/usr/bin/env bash
# Full model-ladder live smoke for sb:review-fix-ladder.
#
# Exercises every resolver rung for the selected host with real agent turns.
# Opt-in: SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1
#
# Examples:
#   SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1 SB_LIVE_RUNTIME=codex bash tests/live/test-live-review-fix-ladder-full-ladder.sh
#   SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1 SB_LIVE_RUNTIME=all bash tests/live/test-live-review-fix-ladder-full-ladder.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIVE_TEST_DIR="$SCRIPT_DIR"
SB_ROOT="$(cd "${LIVE_TEST_DIR}/../.." && pwd)"
FIXTURE_DIR="${LIVE_TEST_DIR}/fixtures/review-fix-ladder-smoke"
RESOLVER="${SB_ROOT}/scripts/review-fix-ladder.py"
PASS=0
FAIL=0
SKIP=0
LADDER_RESULTS=()
LADDER_HOST=""

# shellcheck source=tests/live/lib/review-fix-ladder-common.sh
source "${LIVE_TEST_DIR}/lib/review-fix-ladder-common.sh"

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf 'SKIP: %s\n' "$1"; SKIP=$((SKIP + 1)); }

strip_ansi_response() {
  python3 -c 'import re, sys; text = sys.stdin.read(); ansi_re = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"); sys.stdout.write(ansi_re.sub("", text))'
}

seed_live_codex_workspace_trust() {
  [[ -n "${CODEX_HOME:-}" && -n "${WORK_DIR:-}" ]] || return 0
  python3 - "${CODEX_HOME}/config.toml" "$WORK_DIR" <<'PY'
import pathlib
import sys

config_path = pathlib.Path(sys.argv[1])
workspace = pathlib.Path(sys.argv[2])
text = config_path.read_text() if config_path.is_file() else ""

project_paths = []
for candidate in (workspace, workspace.resolve()):
    candidate_str = str(candidate)
    if candidate_str not in project_paths:
        project_paths.append(candidate_str)

def upsert_project_trust(lines, project_path):
    header = f'[projects."{project_path}"]'
    out = []
    found = False
    index = 0

    while index < len(lines):
        line = lines[index]
        if line == header:
            found = True
            out.append(line)
            index += 1
            trust_written = False
            while index < len(lines) and not lines[index].startswith("["):
                current = lines[index]
                if current.startswith("trust_level = "):
                    if not trust_written:
                        out.append('trust_level = "trusted"')
                        trust_written = True
                else:
                    out.append(current)
                index += 1
            if not trust_written:
                out.append('trust_level = "trusted"')
            continue
        out.append(line)
        index += 1

    if not found:
        if out and out[-1] != "":
            out.append("")
        out.extend([header, 'trust_level = "trusted"'])

    return out

lines = text.splitlines()
for project_path in project_paths:
    lines = upsert_project_trust(lines, project_path)

config_path.parent.mkdir(parents=True, exist_ok=True)
config_path.write_text("\n".join(lines).rstrip("\n") + "\n")
PY
}

assert_silver_bullet_shim_ready() {
  local shim_path="${CODEX_HOME:-}/bin/silver-bullet"
  if [[ ! -x "$shim_path" ]]; then
    fail "live codex silver-bullet shim exists"
    return 1
  fi
  pass "live codex silver-bullet shim exists"
}

setup_runtime_isolation() {
  local runtime="$1"
  # shellcheck disable=SC2034  # SILVER_BULLET_RUNTIME is read by the sourced live helpers
  case "$runtime" in
    codex)
      SILVER_BULLET_RUNTIME="codex"
      # shellcheck source=tests/live/lib/codex-cli-isolation.sh
      source "${LIVE_TEST_DIR}/lib/codex-cli-isolation.sh"
      setup_codex_cli_isolation
      ;;
    claude)
      SILVER_BULLET_RUNTIME="claude"
      ;;
    *)
      fail "unsupported runtime: $runtime"
      return 1
      ;;
  esac
}

teardown_runtime_isolation() {
  local runtime="$1"
  case "$runtime" in
    codex)
      if declare -F teardown_codex_cli_isolation >/dev/null 2>&1; then
        teardown_codex_cli_isolation
      fi
      ;;
  esac
}

invoke_rung_turn() {
  local prompt="$1"
  local response=""
  response="$(invoke_claude_permissive "$prompt")"
  printf '%s' "$response"
}

evaluate_rung_passes() {
  local response="$1"
  local work_dir="$2"
  local required_passes="${SB_LIVE_REVIEW_FIX_LADDER_CLEAN_PASSES:-1}"
  local pass_count=0
  local attempt prompt attempt_response cleaned

  for attempt in $(seq 1 "$required_passes"); do
    if [[ "$attempt" -eq 1 ]]; then
      attempt_response="$response"
    else
      prompt="$(review_fix_ladder_rung_prompt "$RUNG_INDEX" "$RUNG_TOTAL" "$RUNG_MODEL" "$RUNG_REASONING" "${SB_LIVE_RUNTIME:-$LADDER_HOST}" "$attempt")"
      attempt_response="$(invoke_rung_turn "$prompt")"
    fi
    cleaned="$(printf '%s' "$attempt_response" | strip_ansi_response)"
    if review_fix_ladder_response_passes "$cleaned" || review_fix_ladder_fixture_fixed "$work_dir"; then
      pass_count=$((pass_count + 1))
    else
      return 1
    fi
  done
  return 0
}

run_full_ladder_for_host() {
  local runtime="$1"
  local ladder_json rung_count start_rung max_rung rung_index
  local model reasoning prompt response cleaned
  local rung_status row

  LADDER_HOST="$(review_fix_ladder_resolve_host "$runtime")" || return 1
  LADDER_RESULTS=()

  export SB_LIVE_AGENT="$runtime"
  export SB_LIVE_RUNTIME="$runtime"
  if [[ "$runtime" == "codex" ]]; then
    export SB_LIVE_CODEX_USE_EXEC="${SB_LIVE_CODEX_USE_EXEC:-1}"
  fi

  setup_runtime_isolation "$runtime"
  # shellcheck source=tests/live/helpers.sh
  source "${LIVE_TEST_DIR}/helpers.sh"

  printf '\n=== Review Fix Ladder FULL LADDER (host=%s, runtime=%s) ===\n' "$LADDER_HOST" "$runtime"

  if ! agent_preflight; then
    fail "agent preflight for $runtime"
    skip "remaining rungs for $runtime (agent preflight failed)"
    teardown_runtime_isolation "$runtime"
    return 1
  fi
  pass "agent preflight for $runtime"

  live_setup
  review_fix_ladder_seed_workspace "$WORK_DIR" "$FIXTURE_DIR" "$RESOLVER"

  case "$runtime" in
    codex)
      seed_live_codex_workspace_trust
      assert_silver_bullet_shim_ready || true
      ;;
  esac

  ladder_json="$(review_fix_ladder_ladder_json "$LADDER_HOST" "$WORK_DIR")"
  rung_count="$(jq -r '.rungs | length' <<<"$ladder_json")"
  start_rung="${SB_LIVE_REVIEW_FIX_LADDER_START_RUNG:-1}"
  max_rung="${SB_LIVE_REVIEW_FIX_LADDER_MAX_RUNGS:-$rung_count}"
  if [[ "$max_rung" -gt "$rung_count" ]]; then
    max_rung="$rung_count"
  fi

  printf 'Ladder source=%s rungs=%s (executing %s..%s)\n' \
    "$(jq -r '.source' <<<"$ladder_json")" "$rung_count" "$start_rung" "$max_rung"

  for rung_index in $(seq "$start_rung" "$max_rung"); do
    model="$(jq -r ".rungs[$((rung_index - 1))].model" <<<"$ladder_json")"
    reasoning="$(jq -r ".rungs[$((rung_index - 1))].reasoning" <<<"$ladder_json")"
    RUNG_INDEX="$rung_index"
    RUNG_TOTAL="$rung_count"
    RUNG_MODEL="$model"
    RUNG_REASONING="$reasoning"

    review_fix_ladder_apply_rung_env "$LADDER_HOST" "$model" "$reasoning"
    printf '%s\n' "--- Rung ${rung_index}/${rung_count}: model=${model} reasoning=${reasoning} ---"

    if [[ "$rung_index" -gt "$start_rung" && "${SB_LIVE_REVIEW_FIX_LADDER_RESET_FIXTURE:-1}" == "1" ]]; then
      review_fix_ladder_reset_fixture "$WORK_DIR" "$FIXTURE_DIR"
    fi

    prompt="$(review_fix_ladder_rung_prompt "$rung_index" "$rung_count" "$model" "$reasoning" "$runtime" "1")"
    response="$(invoke_rung_turn "$prompt")"
    cleaned="$(printf '%s' "$response" | strip_ansi_response)"

    if grep -qiE 'authentication required|please run .agent login' <<<"$cleaned"; then
      rung_status="BLOCKED"
      fail "rung ${rung_index}/${rung_count} ${model}/${reasoning} (auth required)"
      row="$(printf '%-4s %-22s %-10s %-8s' "$rung_index" "$model" "$reasoning" "$rung_status")"
      LADDER_RESULTS+=("$row")
      skip "remaining rungs for $runtime (auth required)"
      break
    fi

    if evaluate_rung_passes "$response" "$WORK_DIR"; then
      rung_status="PASS"
      pass "rung ${rung_index}/${rung_count} ${model}/${reasoning}"
      review_fix_ladder_launcher_apply_accept "$WORK_DIR" || true
    else
      rung_status="FAIL"
      fail "rung ${rung_index}/${rung_count} ${model}/${reasoning}"
      printf '  response snippet: %s\n' "$(printf '%s' "$cleaned" | head -c 300)"
    fi

    row="$(printf '%-4s %-22s %-10s %-8s' "$rung_index" "$model" "$reasoning" "$rung_status")"
    LADDER_RESULTS+=("$row")
  done

  review_fix_ladder_print_results_table "$LADDER_HOST" "${LADDER_RESULTS[@]}"
  live_teardown
  teardown_runtime_isolation "$runtime"
}

main() {
  local runtime="${SB_LIVE_RUNTIME:-${SB_LIVE_AGENT:-codex}}"

  if [[ "${SB_LIVE_REVIEW_FIX_LADDER_LIVE:-0}" != "1" || "${SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER:-0}" != "1" ]]; then
    printf 'SKIP: full ladder live (set SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_REVIEW_FIX_LADDER_FULL_LADDER=1)\n'
    exit 0
  fi

  case "$runtime" in
    all)
      local host_runtime
      for host_runtime in codex claude; do
        run_full_ladder_for_host "$host_runtime" || true
      done
      ;;
    codex|claude)
      run_full_ladder_for_host "$runtime"
      ;;
    *)
      fail "unsupported SB_LIVE_RUNTIME: $runtime (use codex|claude|all)"
      ;;
  esac

  printf '\nResults: %d passed, %d failed, %d skipped\n' "$PASS" "$FAIL" "$SKIP"
  [[ "$FAIL" -eq 0 ]]
}

main "$@"
