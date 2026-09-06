#!/usr/bin/env bash
# Shared helpers for review-fix-ladder live smoke and full-ladder runs.

review_fix_ladder_cursor_slug() {
  local sb_root="${SB_ROOT:-}"
  python3 - "$1" "$2" "$sb_root" <<'PY'
import importlib.util
import pathlib
import sys

repo_root = pathlib.Path(sys.argv[3])
spec = importlib.util.spec_from_file_location(
    "review_fix_ladder",
    repo_root / "scripts" / "review-fix-ladder.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.cursor_task_slug(sys.argv[1], sys.argv[2]))
PY
}

review_fix_ladder_cursor_agent_model() {
  local sb_root="${SB_ROOT:-}"
  python3 - "$1" "$2" "$sb_root" <<'PY'
import importlib.util
import pathlib
import sys

repo_root = pathlib.Path(sys.argv[3])
spec = importlib.util.spec_from_file_location(
    "review_fix_ladder",
    repo_root / "scripts" / "review-fix-ladder.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.cursor_agent_model(sys.argv[1], sys.argv[2]))
PY
}

review_fix_ladder_rung_delegation() {
  local sb_root="${SB_ROOT:-}"
  python3 - "$1" "$2" "$sb_root" <<'PY'
import importlib.util
import pathlib
import sys

repo_root = pathlib.Path(sys.argv[3])
spec = importlib.util.spec_from_file_location(
    "review_fix_ladder",
    repo_root / "scripts" / "review-fix-ladder.py",
)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.cursor_rung_delegation(sys.argv[1], sys.argv[2]))
PY
}

review_fix_ladder_resolve_host() {
  local runtime="${1:-${SB_LIVE_RUNTIME:-${SB_LIVE_AGENT:-}}}"
  case "$runtime" in
    codex|kay) printf 'codex\n' ;;
    claude) printf 'claude\n' ;;
    cursor) printf 'cursor\n' ;;
    *)
      printf 'ERROR: unsupported runtime for review-fix-ladder: %s\n' "$runtime" >&2
      return 1
      ;;
  esac
}

review_fix_ladder_ladder_json() {
  local host="$1"
  local work_dir="$2"

  if [[ "$host" == "codex" && -n "${CODEX_HOME:-}" ]]; then
    (cd "$work_dir" && python3 scripts/review-fix-ladder.py --host "$host" --codex-home "$CODEX_HOME" --json)
    return 0
  fi

  (cd "$work_dir" && python3 scripts/review-fix-ladder.py --host "$host" --json)
}

review_fix_ladder_seed_workspace() {
  local work_dir="$1"
  local fixture_dir="$2"
  local resolver="$3"

  cp "${fixture_dir}/smoke-target.py" "${work_dir}/smoke-target.py"
  cp "${fixture_dir}/CHARTER.md" "${work_dir}/CHARTER.md"
  mkdir -p "${work_dir}/scripts"
  ln -sf "${resolver}" "${work_dir}/scripts/review-fix-ladder.py"
  git -C "$work_dir" add smoke-target.py CHARTER.md scripts/review-fix-ladder.py
  git -C "$work_dir" commit -q -m "review-fix-ladder fixture" || true
}

review_fix_ladder_reset_fixture() {
  local work_dir="$1"
  local fixture_dir="$2"

  cp "${fixture_dir}/smoke-target.py" "${work_dir}/smoke-target.py"
  git -C "$work_dir" add smoke-target.py
  git -C "$work_dir" commit -q -m "reset review-fix-ladder fixture" || true
}

review_fix_ladder_rung_prompt() {
  local rung_index="$1"
  local rung_total="$2"
  local model="$3"
  local reasoning="$4"
  local runtime="$5"
  local clean_pass="$6"
  local lite="${SB_LIVE_REVIEW_FIX_LADDER_LITE_PROMPT:-1}"

  if [[ "$lite" == "1" && "${SB_LIVE_REVIEW_FIX_LADDER_TRIAGE_SCENARIO:-0}" != "1" ]]; then
    cat <<EOF
Review-fix ladder smoke rung ${rung_index}/${rung_total}: model=${model}, reasoning=${reasoning}.

Read smoke-target.py and CHARTER.md in this workspace only.

Pass ${clean_pass}: reply with one line starting "LADDER_PASS:" naming the divide() zero-check defect from the charter. Do not edit files or run other commands.
EOF
    return 0
  fi

  if [[ "${SB_LIVE_REVIEW_FIX_LADDER_TRIAGE_SCENARIO:-0}" == "1" ]]; then
    # shellcheck source=tests/live/lib/review-fix-ladder-triage-scenario.sh
    source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/review-fix-ladder-triage-scenario.sh"
    review_fix_ladder_phase_prompt "review" "$rung_index" "$rung_total" "$model" "$reasoning"
    return 0
  fi

  case "$runtime" in
    codex|kay)
      cat <<EOF
Review-fix ladder smoke rung ${rung_index}/${rung_total}: model=${model}, reasoning=${reasoning}.

Run exactly this command first: \`silver-bullet invoke-skill sb:review-fix-ladder smoke-target.py\`.
Then read only smoke-target.py and CHARTER.md in this workspace.

Pass ${clean_pass}: audit divide() against the charter. Reply with a line starting "LADDER_PASS:" and one sentence naming the zero-check defect. Review/verify only — do not edit files or patch smoke-target.py. The launcher applies ACCEPT fixes.
EOF
      ;;
    *)
      cat <<EOF
Review-fix ladder smoke rung ${rung_index}/${rung_total}: model=${model}, reasoning=${reasoning}.

Scope: smoke-target.py only. Read CHARTER.md for goals. Run python3 scripts/review-fix-ladder.py --json if helpful.

Pass ${clean_pass}: audit divide() against the charter. Reply with a line starting "LADDER_PASS:" and one sentence naming the zero-check defect. Review/verify only — do not edit files or patch smoke-target.py. The launcher applies ACCEPT fixes.
EOF
      ;;
  esac
}

# Policy B APPLY ACCEPT: launcher (not the rung) patches the smoke fixture.
# Completeness: land every finding that is not wrong, including Low/deferred/nitpicks/minor.
review_fix_ladder_launcher_apply_accept() {
  local work_dir="$1"
  local target="${work_dir}/smoke-target.py"

  python3 - "$target" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
old = '''def divide(a: float, b: float) -> float:
    """Divide a by b. BUG: no zero check."""
    return a / b
'''
new = '''def divide(a: float, b: float) -> float:
    """Divide a by b. Reject zero divisors."""
    if b == 0:
        raise ValueError("division by zero")
    return a / b
'''
if "b == 0" in text:
    sys.exit(0)
if old not in text:
    sys.exit(1)
path.write_text(text.replace(old, new, 1))
PY
}

review_fix_ladder_response_passes() {
  local response="$1"
  if printf '%s' "$response" | grep -qiE 'LADDER_PASS:|ZeroDivisionError|zero-divisor|zero check|BUG: no zero|division by zero|reject.*zero|b == 0|!= 0'; then
    return 0
  fi
  return 1
}

review_fix_ladder_fixture_fixed() {
  local work_dir="$1"
  grep -qE 'b == 0|!= 0|ZeroDivisionError|ValueError' "${work_dir}/smoke-target.py" 2>/dev/null
}

review_fix_ladder_apply_rung_env() {
  local host="$1"
  local model="$2"
  local reasoning="$3"

  case "$host" in
    codex)
      export CODEX_MODEL="$model"
      export CODEX_REASONING_EFFORT="$reasoning"
      export SB_LIVE_CODEX_MODEL="$model"
      export SB_LIVE_CODEX_REASONING_EFFORT="$reasoning"
      ;;
    claude)
      export CLAUDE_MODEL="$model"
      export CLAUDE_EFFORT="$reasoning"
      export CLAUDE_LIVE_CONTINUE="0"
      CLAUDE_PROMPT_COUNT=0
      ;;
    cursor)
      local delegation
      delegation="$(review_fix_ladder_rung_delegation "$model" "$reasoning")"
      if [[ "$delegation" == "agent-cursor" ]]; then
        export CURSOR_AGENT_MODEL="$(review_fix_ladder_cursor_agent_model "$model" "$reasoning")"
      else
        export CURSOR_AGENT_MODEL="$(review_fix_ladder_cursor_slug "$model" "$reasoning")"
      fi
      export CURSOR_MODEL="$CURSOR_AGENT_MODEL"
      ;;
  esac
}

review_fix_ladder_print_results_table() {
  local host="$1"
  shift
  local -a rows=("$@")

  printf '\n=== Full ladder results (%s) ===\n' "$host"
  printf '%-4s %-22s %-10s %-8s\n' 'Rung' 'Model' 'Reasoning' 'Status'
  printf '%-4s %-22s %-10s %-8s\n' '----' '----------------------' '----------' '--------'
  local row
  for row in "${rows[@]}"; do
    printf '%s\n' "$row"
  done
}
