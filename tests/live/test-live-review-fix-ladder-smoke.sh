#!/usr/bin/env bash
# Live smoke for sb:review-fix-ladder
#
# Default (no API cost): resolver + invoke-skill adapter + fixture charter checks.
# Optional live agent turn: SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 SB_LIVE_RUNTIME=codex|kay|claude
#
# Cursor automated path: detects CURSOR_AGENT=1 and validates the cursor ladder.
# Not part of the default run-live-tests.sh matrix (opt-in, like test-silver-init-migration.sh).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SB_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/review-fix-ladder-smoke"
RESOLVER="${SB_ROOT}/scripts/review-fix-ladder.py"
INVOKE_ADAPTER="${SB_ROOT}/scripts/silver-bullet"
PASS=0
FAIL=0

pass() { printf 'PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf 'FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }

detect_smoke_host() {
  if [[ -n "${SB_REVIEW_FIX_LADDER_HOST:-}" ]]; then
    printf '%s\n' "$SB_REVIEW_FIX_LADDER_HOST"
    return 0
  fi
  if [[ "${SILVER_BULLET_RUNTIME:-}" == "cursor" || -n "${CURSOR_PLUGIN_ROOT:-}" || "${CURSOR_AGENT:-}" == "1" ]]; then
    printf 'cursor\n'
    return 0
  fi
  if [[ "${SILVER_BULLET_RUNTIME:-}" == "codex" ]] || [[ -n "${CODEX_CI:-}${CODEX_THREAD_ID:-}" ]]; then
    printf 'codex\n'
    return 0
  fi
  printf 'claude\n'
}

assert_json_true() {
  local label="$1" filter="$2" json="$3"
  if jq -e "$filter" >/dev/null <<<"$json"; then
    pass "$label"
  else
    fail "$label"
    printf '%s\n' "$json"
  fi
}

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

assert_output_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qiE "$needle"; then
    pass "$label"
  else
    fail "$label"
    printf '  snippet: %s\n' "$(printf '%s' "$haystack" | head -c 400)"
  fi
}

assert_output_not_contains() {
  local label="$1" haystack="$2" needle="$3"
  if printf '%s' "$haystack" | grep -qiE "$needle"; then
    fail "$label"
    printf '  snippet: %s\n' "$(printf '%s' "$haystack" | head -c 400)"
  else
    pass "$label"
  fi
}

assert_silver_bullet_shim_ready() {
  local shim_path="${CODEX_HOME:-}/bin/silver-bullet"
  if [[ -x "$shim_path" ]]; then
    pass "live codex silver-bullet shim exists"
  else
    fail "live codex silver-bullet shim exists"
    printf '  expected executable shim at: %s\n' "$shim_path"
    return 1
  fi

  local shim_probe=""
  shim_probe="$(bash "$shim_path" invoke-skill sb:review-fix-ladder smoke-target.py 2>&1 || true)"
  assert_output_contains "live codex silver-bullet shim invokes review-fix-ladder skill" "$shim_probe" "Skill: silver-review-fix-ladder|BEGIN SKILL silver-review-fix-ladder"
}

live_transcript_text() {
  local transcript_dir=""
  local transcript_file=""

  if declare -F agent_transcript_dir >/dev/null 2>&1; then
    transcript_dir="$(agent_transcript_dir 2>/dev/null || true)"
  fi
  transcript_file="${transcript_dir}/latest.jsonl"
  if [[ -f "$transcript_file" ]]; then
    cat "$transcript_file" | strip_ansi_response
  fi
}

assert_live_turn_evidence() {
  local response="$1"
  local cleaned_response=""
  local cleaned_transcript=""
  local combined=""
  local invoke_ok=0
  local file_read_ok=0

  cleaned_response="$(printf '%s' "$response" | strip_ansi_response)"
  cleaned_transcript="$(live_transcript_text)"
  combined="${cleaned_response}
${cleaned_transcript}"
  LIVE_TURN_COMBINED_TEXT="$combined"

  assert_output_not_contains "live turn did not report silver-bullet command missing" "$combined" 'command not found: silver-bullet|silver-bullet: command not found|bash: silver-bullet: command not found|silver-bullet invoke-skill [^[:space:]]+ not available'

  if printf '%s' "$combined" | grep -qiE 'BEGIN SKILL silver-review-fix-ladder'; then
    invoke_ok=1
    pass "live turn ran silver-bullet invoke-skill"
  else
    printf 'NOTE: live turn did not run silver-bullet invoke-skill\n'
  fi

  if printf '%s' "$combined" | grep -qiE 'Explored.*Read.*(CHARTER\.md|smoke-target\.py)|Read[[:space:]]+CHARTER\.md|Read[[:space:]]+smoke-target\.py|ReadCHARTER\.md,[[:space:]]*smoke-target\.py|BUG: no zero check|Review Charter \(smoke\)|must reject division by zero'; then
    file_read_ok=1
    pass "live turn read fixture charter or target file"
  else
    fail "live turn read fixture charter or target file"
    printf '  expected Read smoke-target.py/CHARTER.md or fixture-only charter markers\n'
  fi

  if [[ "$invoke_ok" -eq 0 && "$file_read_ok" -eq 0 ]]; then
    fail "live turn engaged review-fix-ladder fixture"
    printf '  require invoke-skill output or fixture file reads, not prompt echo alone\n'
  else
    pass "live turn engaged review-fix-ladder fixture"
  fi
}

setup_smoke_workspace() {
  local work_dir="$1"
  mkdir -p "$work_dir"
  cp "${FIXTURE_DIR}/smoke-target.py" "${work_dir}/smoke-target.py"
  cp "${FIXTURE_DIR}/CHARTER.md" "${work_dir}/CHARTER.md"
  mkdir -p "${work_dir}/scripts"
  ln -sf "${RESOLVER}" "${work_dir}/scripts/review-fix-ladder.py"
  git -C "$work_dir" init -q
  git -C "$work_dir" config user.email "review-fix-ladder-smoke@silver-bullet.test"
  git -C "$work_dir" config user.name "Review Fix Ladder Smoke"
  git -C "$work_dir" add smoke-target.py CHARTER.md scripts/review-fix-ladder.py
  git -C "$work_dir" commit -q -m "smoke fixture"
}

run_automated_smoke() {
  local host work_dir ladder_json invoke_out scope_arg

  host="$(detect_smoke_host)"
  work_dir="$(mktemp -d)"

  printf '=== Review Fix Ladder Smoke (automated) ===\n'
  printf 'Detected host: %s\n' "$host"

  if [[ -f "${FIXTURE_DIR}/smoke-target.py" ]]; then
    pass "fixture smoke-target.py exists"
  else
    fail "fixture smoke-target.py exists"
  fi
  if [[ -f "${FIXTURE_DIR}/CHARTER.md" ]]; then
    pass "fixture CHARTER.md exists"
  else
    fail "fixture CHARTER.md exists"
  fi
  if grep -q 'BUG: no zero check' "${FIXTURE_DIR}/smoke-target.py"; then
    pass "fixture retains intentional divide() defect"
  else
    fail "fixture retains intentional divide() defect"
  fi

  setup_smoke_workspace "$work_dir"

  ladder_json="$(cd "$work_dir" && python3 scripts/review-fix-ladder.py --host "$host" --json)"
  assert_json_true "resolver returns host" ".host == \"${host}\"" "$ladder_json"
  assert_json_true "resolver returns non-empty rungs" '(.rungs | length) > 0' "$ladder_json"
  assert_json_true "first rung has model and reasoning" '.rungs[0].model and .rungs[0].reasoning' "$ladder_json"

  case "$host" in
    cursor)
      assert_json_true "cursor ladder starts composer-2.5 low" '.rungs[0] == {"model":"composer-2.5","reasoning":"low"}' "$ladder_json"
      ;;
    codex)
      assert_json_true "codex ladder excludes mini tier" '[.rungs[].model] | index("gpt-5.4-mini") | not' "$ladder_json"
      ;;
    claude)
      assert_json_true "claude ladder starts sonnet medium" '.rungs[0].model == "claude-sonnet-4-6"' "$ladder_json"
      ;;
  esac

  scope_arg="smoke-target.py"
  invoke_out="$(cd "$work_dir" && bash "$INVOKE_ADAPTER" invoke-skill sb:review-fix-ladder "$scope_arg" 2>&1)"
  assert_output_contains "invoke-skill loads review-fix-ladder skill" "$invoke_out" "BEGIN SKILL silver-review-fix-ladder"
  assert_output_contains "invoke-skill surfaces runtime scope argument" "$invoke_out" "smoke-target\\.py"
  assert_output_contains "skill body documents scope resolution" "$invoke_out" "Resolve Scope"
  assert_output_contains "skill body documents resolver command" "$invoke_out" "review-fix-ladder\\.py --json"
  assert_output_contains "skill body documents charter derivation" "$invoke_out" "Derive Review Charter"
  assert_output_contains "skill body documents triage state" "$invoke_out" "rung_N_triage|/sb:triage"
  assert_output_contains "charter names divide() zero goal" "$(cat "${work_dir}/CHARTER.md")" "divide\\(\\)"

  printf 'Automated phase complete (host=%s, rungs=%s)\n' \
    "$host" "$(jq -r '.rungs | length' <<<"$ladder_json")"
  rm -rf "$work_dir"
}

run_live_agent_smoke() {
  local live_test_script_dir="$SCRIPT_DIR"
  local runtime="${SB_LIVE_RUNTIME:-${SB_LIVE_AGENT:-}}"
  if [[ "${SB_LIVE_REVIEW_FIX_LADDER_LIVE:-0}" != "1" ]]; then
    printf 'SKIP: live agent phase (set SB_LIVE_REVIEW_FIX_LADDER_LIVE=1 to enable)\n'
    return 0
  fi
  if [[ -z "$runtime" ]]; then
    if [[ "${CURSOR_AGENT:-}" == "1" || "${SILVER_BULLET_RUNTIME:-}" == "cursor" ]]; then
      runtime="cursor"
    else
      fail "live agent phase requires SB_LIVE_RUNTIME or SB_LIVE_AGENT"
      return 0
    fi
  fi

  export SB_LIVE_AGENT="$runtime"
  export SB_LIVE_RUNTIME="$runtime"
  case "$runtime" in
    codex)
      SILVER_BULLET_RUNTIME="codex"
      # shellcheck source=tests/live/lib/codex-cli-isolation.sh
      source "${SCRIPT_DIR}/lib/codex-cli-isolation.sh"
      setup_codex_cli_isolation
      ;;
    kay)
      SILVER_BULLET_RUNTIME="codex"
      # shellcheck source=tests/live/lib/kay-codex-isolation.sh
      source "${SCRIPT_DIR}/lib/kay-codex-isolation.sh"
      setup_kay_codex_isolation
      ;;
    claude)
      SILVER_BULLET_RUNTIME="claude"
      ;;
    cursor)
      SILVER_BULLET_RUNTIME="cursor"
      ;;
    *)
      fail "unsupported live runtime: $runtime"
      return 0
      ;;
  esac

  # shellcheck source=tests/live/helpers.sh
  source "${live_test_script_dir}/helpers.sh"

  printf '=== Review Fix Ladder Smoke (live agent: %s) ===\n' "$runtime"

  live_setup
  cp "${FIXTURE_DIR}/smoke-target.py" "${WORK_DIR}/smoke-target.py"
  cp "${FIXTURE_DIR}/CHARTER.md" "${WORK_DIR}/CHARTER.md"
  mkdir -p "${WORK_DIR}/scripts"
  ln -sf "${RESOLVER}" "${WORK_DIR}/scripts/review-fix-ladder.py"
  git -C "$WORK_DIR" add smoke-target.py CHARTER.md scripts/review-fix-ladder.py
  git -C "$WORK_DIR" commit -q -m "add review-fix-ladder smoke fixture" || true

  case "$runtime" in
    codex)
      seed_live_codex_workspace_trust
      assert_silver_bullet_shim_ready
      ;;
  esac

  local prompt
  case "$runtime" in
    codex|kay)
      prompt="Run exactly this command as your first and only non-hook command: \`silver-bullet invoke-skill sb:review-fix-ladder smoke-target.py\`. After the adapter prints the skill, read only smoke-target.py and CHARTER.md. Reply with one sentence naming the divide() defect from the charter. Do not edit files, run tests, or invoke additional commands."
      ;;
    cursor)
      prompt="Use /sb:review-fix-ladder on smoke-target.py only. Read smoke-target.py and CHARTER.md. Derive the charter, run python3 scripts/review-fix-ladder.py --json, and reply with one sentence naming the divide() defect. Do not edit files or expand scope."
      ;;
    *)
      prompt="Use /sb:review-fix-ladder on smoke-target.py only. Read smoke-target.py and CHARTER.md. Derive the charter, run python3 scripts/review-fix-ladder.py --json, and reply with one sentence naming the divide() defect. Do not edit files or expand scope."
      ;;
  esac

  local response
  response="$(invoke_claude_permissive "$prompt")"

  case "$runtime" in
    codex|kay)
      assert_live_turn_evidence "$response"
      assert_output_contains "live agent names substantive divide() defect" "${LIVE_TURN_COMBINED_TEXT:-$response}" "ZeroDivisionError|zero-divisor|zero check|BUG: no zero|division by zero"
      ;;
    *)
      assert_response_contains "live agent names substantive divide() defect" "$(printf '%s' "$response" | strip_ansi_response)" "ZeroDivisionError|zero-divisor|zero check|BUG: no zero|division by zero"
      ;;
  esac
  live_teardown

  case "$runtime" in
    codex) teardown_codex_cli_isolation ;;
    kay) teardown_kay_codex_isolation ;;
  esac
}

run_automated_smoke
run_live_agent_smoke

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
