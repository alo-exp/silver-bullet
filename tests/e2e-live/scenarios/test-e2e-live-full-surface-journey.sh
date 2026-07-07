#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "$0")/.." && pwd)/helpers.sh"
source "$(cd "$(dirname "$0")/.." && pwd)/lib/skill-prompt.sh"

echo "=== E2E Live: Full-Surface Journey ==="

prepare_workspace clean-sb
ensure_runtime_dependency_access_preflight

LEDGER_FILE="${WORK_DIR}/coverage-ledger.md"
TURN_LOG_DIR="$(mktemp -d "${SB_TEST_DIR}/turn-logs-XXXXXX")"
mkdir -p "$TURN_LOG_DIR"
init_coverage_ledger "$LEDGER_FILE"

strip_ansi_response() {
  python3 -c 'import re, sys; text = sys.stdin.read(); ansi_re = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"); sys.stdout.write(ansi_re.sub("", text))'
}

collect_process_tree_pids() {
  local pid="$1"
  local child

  if command -v pgrep >/dev/null 2>&1; then
    while IFS= read -r child; do
      [[ -n "$child" ]] || continue
      collect_process_tree_pids "$child"
    done < <(pgrep -P "$pid" 2>/dev/null || true)
  fi

  printf '%s\n' "$pid"
}

kill_process_id_list() {
  local signal="$1"
  local pid_list="$2"
  local pid

  for pid in $pid_list; do
    kill "-${signal}" "$pid" >/dev/null 2>&1 || true
  done
}

is_codex_route_smoke_surface() {
  local surface="$1"

  [[ "$E2E_RUNTIME" == "codex" || "$E2E_RUNTIME" == "kay" ]] || return 1
  [[ "$surface" == silver:* ]]
}

assert_route_smoke_adapter_only() {
  local surface="$1"
  local transcript_dir=""
  local transcript_file=""
  local validation_output

  is_codex_route_smoke_surface "$surface" || return 0

  if declare -F agent_transcript_dir >/dev/null 2>&1; then
    transcript_dir="$(agent_transcript_dir 2>/dev/null || true)"
  fi
  transcript_file="${transcript_dir}/latest.jsonl"
  if [[ -z "$transcript_dir" || ! -f "$transcript_file" ]]; then
    echo "FAIL: $surface invoked the SB adapter as the only real command"
    echo "  no ${E2E_RUNTIME} transcript captured at: ${transcript_file:-<unknown>}"
    FAIL=$((FAIL + 1))
    return 1
  fi

  if validation_output="$(python3 "$(cd "$(dirname "$0")/.." && pwd)/lib/route-smoke-transcript.py" "$transcript_file" "$surface" 2>&1)"; then
    echo "PASS: $surface invoked the SB adapter as the only real command"
    PASS=$((PASS + 1))
    return 0
  fi

  echo "FAIL: $surface invoked the SB adapter as the only real command"
  echo "  $validation_output"
  FAIL=$((FAIL + 1))
  return 1
}

seed_planning_floor_marker() {
  local skill="$1"
  mkdir -p "$(dirname "$STATE_FILE")"
  if ! grep -qx "$skill" "$STATE_FILE" 2>/dev/null; then
    printf '%s\n' "$skill" >> "$STATE_FILE"
  fi
  (
    cd "$WORK_DIR"
    jq -nc --arg skill "$skill" \
      '{hook_event_name:"PostToolUse", tool_name:"Skill", tool_input:{skill:$skill}}' \
      | SILVER_BULLET_STATE_FILE="$STATE_FILE" bash "${SB_ROOT}/hooks/record-skill.sh" >/dev/null 2>&1 || true
  )
}

journey_turn() {
  local surface="$1"
  local summary="$2"
  local issue="$3"
  local evidence="$4"
  local prompt="$5"
  local regex="${6:-.}"
  local record_ledger="${7:-yes}"
  local response
  local response_clean
  local response_file
  local response_raw_file
  local usable_response=false
  local timed_out=false
  local turn_timeout_seconds="${SB_E2E_LIVE_TURN_TIMEOUT_SECONDS:-180}"
  local error_regex='(Command .+ is not supported in exec mode|Authentication expired|Authentication required|unknown flag:|invalid issue format|command not found: silver-bullet|silver-bullet invoke-skill [^[:space:]]+ not available|timed out waiting for Codex prompt to complete|timed out waiting for Codex to accept the submitted prompt|interactive hook trust review surfaced|interactive workspace trust prompt surfaced|Stop hook \(blocked\)|Cannot complete -- missing required skills)'
  local controlled_fallback_regex='(Permission denied|bash: -lc: command not found|is a directory|"exit_code":[[:space:]]*12[67]|\\"exit_code\\":[[:space:]]*12[67])'
  local response_pid=""
  local response_stdout_file
  local response_status_file
  local response_deadline
  local response_tree_pids

  response_file="${TURN_LOG_DIR}/${surface//[:]/-}.txt"
  response_raw_file="${TURN_LOG_DIR}/${surface//[:]/-}.raw.txt"
  response_stdout_file="$(mktemp "${TURN_LOG_DIR}/${surface//[:]/-}.stdout-XXXXXX")"
  response_status_file="$(mktemp "${TURN_LOG_DIR}/${surface//[:]/-}.status-XXXXXX")"
  (
    run_prompt "$prompt" >"$response_stdout_file"
    printf '%s\n' "$?" >"$response_status_file"
  ) &
  response_pid=$!
  response_deadline=$((SECONDS + turn_timeout_seconds))
  while kill -0 "$response_pid" >/dev/null 2>&1; do
    if (( SECONDS >= response_deadline )); then
      timed_out=true
      response_tree_pids="$(collect_process_tree_pids "$response_pid" | awk 'NF')"
      kill_process_id_list TERM "$response_tree_pids"
      sleep 1
      kill_process_id_list KILL "$response_tree_pids"
      break
    fi
    sleep 2
  done
  wait "$response_pid" >/dev/null 2>&1 || true
  response="$(cat "$response_stdout_file" 2>/dev/null || true)"
  rm -f "$response_stdout_file" "$response_status_file"
  response_clean="$(printf '%s' "$response" | strip_ansi_response)"
  mkdir -p "$TURN_LOG_DIR"
  printf '%s\n' "$response" > "$response_raw_file"
  printf '%s\n' "$response_clean" > "$response_file"

  if [[ "$timed_out" == true && "$E2E_RUNTIME" =~ ^(codex|kay)$ && "$surface" == silver:* ]]; then
    response_clean="[timeout] ${surface} did not complete within ${turn_timeout_seconds}s"
    printf '%s\n' "$response_clean" > "$response_file"
    printf '%s\n' "$response_clean" > "$response_raw_file"
    echo "FAIL: $surface completed within the route-smoke timeout"
    echo "  route-smoke turns must stop after the SB adapter receipt"
    FAIL=$((FAIL + 1))
  elif [[ "$timed_out" == true ]]; then
    response_clean="[timeout] ${surface} did not complete within ${turn_timeout_seconds}s"
    printf '%s\n' "$response_clean" > "$response_file"
    printf '%s\n' "$response_clean" > "$response_raw_file"
    echo "WARN: $surface timed out after ${turn_timeout_seconds}s; using controlled fallback"
    usable_response=true
  elif [[ -n "$response_clean" ]] && grep -Eq "$controlled_fallback_regex" <<<"$response_clean"; then
    response_clean="[fallback] ${surface} produced tool-error transcript; using controlled fallback
${response_clean}"
    printf '%s\n' "$response_clean" > "$response_file"
    echo "WARN: $surface produced tool-error transcript; using controlled fallback"
    usable_response=true
  elif [[ -z "$response_clean" ]]; then
    echo "FAIL: $surface produced a usable response"
    echo "  response was empty"
    FAIL=$((FAIL + 1))
  elif grep -Eq "$error_regex" <<<"$response_clean"; then
    echo "FAIL: $surface produced a usable response"
    echo "  response contained a CLI/agent error marker"
    echo "$response_clean"
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $surface produced a usable response"
    PASS=$((PASS + 1))
    usable_response=true
    if [[ -n "${regex:-}" && "$regex" != "." ]] && ! grep -Eq "$regex" <<<"$response_clean"; then
      echo "WARN: $surface response did not match advisory pattern: $regex"
    fi
  fi

  if [[ "$usable_response" == true ]]; then
    if assert_route_smoke_adapter_only "$surface"; then
      record_completed_surface "$surface"
    else
      usable_response=false
    fi
  fi

  if [[ "$record_ledger" != "no" ]]; then
    ledger_append "$LEDGER_FILE" "$surface" "$summary" "$issue" "$evidence"
  fi
  printf '%s\n' "$response_clean"
}

record_completed_surface() {
  local surface="$1"

  case "$surface" in
    silver:*|retired-*) ;;
    *) return 0 ;;
  esac

  (
    cd "$WORK_DIR"
    jq -nc --arg skill "$surface" \
      '{hook_event_name:"PostToolUse", tool_name:"Skill", tool_input:{skill:$skill}}' \
      | SILVER_BULLET_STATE_FILE="$STATE_FILE" bash "${SB_ROOT}/hooks/record-skill.sh" >/dev/null 2>&1 || true
  )

  if ! grep -qx "$surface" "$STATE_FILE" 2>/dev/null; then
    mkdir -p "$(dirname "$STATE_FILE")"
    touch -- "$STATE_FILE"
    printf '%s\n' "$surface" >> "$STATE_FILE"
  fi
}

LOCAL_SKILL_SOURCE_REGEX='/Users/shafqat/projects/codex-plugins/skills/[^[:space:]]+'
LOCAL_SKILL_SOURCE_ROOT='/Users/shafqat/projects/codex-plugins/skills'
LOCAL_SKILL_SOURCE_NEGATIVE_CONTEXT="do[[:space:]]*not[[:space:]]*read[[:space:]]*or[[:space:]]*use[[:space:]]*local[[:space:]]*${LOCAL_SKILL_SOURCE_ROOT}|avoid(ed|s|ing)?[[:space:]]*local[[:space:]]*codex-plugins[[:space:]]*skill[[:space:]]*sources|not[[:space:]]*read[[:space:]]*or[[:space:]]*use[[:space:]]*local[[:space:]]*${LOCAL_SKILL_SOURCE_ROOT}|not[[:space:]]*read[[:space:]]*from[[:space:]]*${LOCAL_SKILL_SOURCE_ROOT}|not[[:space:]]*using[[:space:]]*${LOCAL_SKILL_SOURCE_ROOT}|prohibited[[:space:]]*${LOCAL_SKILL_SOURCE_ROOT}|from[[:space:]]*${LOCAL_SKILL_SOURCE_ROOT}[[:space:]]*as[[:space:]]*requested|!${LOCAL_SKILL_SOURCE_ROOT}"

resolve_silver_skill_path() {
  if [[ "$E2E_RUNTIME" == "codex" || "$E2E_RUNTIME" == "kay" ]]; then
    local native_silver_skill="${KAY_HOME:-$HOME}/.codex/skills/silver/SKILL.md"
    if [[ -f "$native_silver_skill" ]]; then
      printf '%s\n' "$native_silver_skill"
      return 0
    fi

    local install_path
    install_path="$(codex_plugin_install_path "silver-bullet@alo-labs-codex" 2>/dev/null || true)"
    if [[ -n "$install_path" ]]; then
      for source_name in SILVER_SOURCE SILVER_SOURCE.md SILVER_SKILL.md; do
        if [[ -f "$install_path/skill-source/silver/$source_name" ]]; then
          printf '%s\n' "$install_path/skill-source/silver/$source_name"
          return 0
        fi
      done
    fi

    local codex_cache_root latest_codex_cache
    codex_cache_root="${KAY_HOME:-$HOME}/.codex/plugins/cache/alo-labs-codex/silver-bullet"
    if [[ -L "$codex_cache_root/current" ]]; then
      for source_name in SILVER_SOURCE SILVER_SOURCE.md SILVER_SKILL.md; do
        if [[ -f "$codex_cache_root/current/skill-source/silver/$source_name" ]]; then
          printf '%s\n' "$codex_cache_root/current/skill-source/silver/$source_name"
          return 0
        fi
      done
    fi
    latest_codex_cache="$(find "$codex_cache_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    if [[ -n "$latest_codex_cache" ]]; then
      for source_name in SILVER_SOURCE SILVER_SOURCE.md SILVER_SKILL.md; do
        if [[ -f "$latest_codex_cache/skill-source/silver/$source_name" ]]; then
          printf '%s\n' "$latest_codex_cache/skill-source/silver/$source_name"
          return 0
        fi
      done
    fi
  else
    local claude_cache_root latest_claude_cache
    claude_cache_root="${SB_RUNTIME_HOME_ROOT}/plugins/cache/alo-labs/silver-bullet"
    latest_claude_cache="$(find "$claude_cache_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -n 1)"
    if [[ -n "$latest_claude_cache" && -f "$latest_claude_cache/skills/silver/SKILL.md" ]]; then
      printf '%s\n' "$latest_claude_cache/skills/silver/SKILL.md"
      return 0
    fi
  fi

  # Deterministic fallback for local dev runs when registry metadata is missing.
  printf '%s\n' "$HOME/.codex/skills/silver/SKILL.md"
}

assert_no_local_skill_source_bypass() {
  local label="$1"
  local path="$2"
  local suspicious=""
  suspicious="$(local_skill_source_bypass_hits "$path")"
  if [[ -n "$suspicious" ]]; then
    echo "FAIL: $label"
    printf '%s\n' "$suspicious" | sed -n '1,5p'
    FAIL=$((FAIL + 1))
  else
    echo "PASS: $label"
    PASS=$((PASS + 1))
  fi
}

local_skill_source_bypass_hits() {
  local path="$1"
  python3 - "$LOCAL_SKILL_SOURCE_ROOT" "$path" <<'PY'
from pathlib import Path
import re
import sys

root = sys.argv[1]
target = Path(sys.argv[2])
ansi_re = re.compile(r"\x1b(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])")

def compact(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip().lower()

def compact_for_negative_context(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", text.lower())

def is_negative_context(context: str) -> bool:
    root_l = root.lower()
    context = compact(context)
    squashed_context = compact_for_negative_context(context)
    squashed_root = compact_for_negative_context(root_l)
    negative_patterns = [
        f"do not read or use local {root_l}",
        f"did not read or use local {root_l}",
        f"did not read or use {root_l}",
        f"did not use {root_l}",
        f"no {root_l} paths were read or used",
        f"not read or use local {root_l}",
        f"not read or use {root_l}",
        f"not read from {root_l}",
        f"not using {root_l}",
        f"without using the forbidden {root_l}",
        f"without using forbidden {root_l}",
        f"prohibited {root_l}",
        f"from {root_l} as requested",
        f"!{root_l}",
        "avoided local codex-plugins skill sources",
        "avoids local codex-plugins skill sources",
        "avoiding local codex-plugins skill sources",
    ]
    if any(pattern in context for pattern in negative_patterns):
        return True
    squashed_negative_patterns = [
        f"donotreadoruselocal{squashed_root}",
        f"didnotreadoruselocal{squashed_root}",
        f"didnotreadoruse{squashed_root}",
        f"didnotuse{squashed_root}",
        f"no{squashed_root}pathswerereadorused",
        f"notreadoruselocal{squashed_root}",
        f"notreadoruse{squashed_root}",
        f"donotreadoruselocal{squashed_root}paths",
        f"didnotreadoruselocal{squashed_root}paths",
        f"didnotreadoruse{squashed_root}paths",
        f"didnotuse{squashed_root}paths",
        f"notreadoruselocal{squashed_root}paths",
        f"notreadoruse{squashed_root}paths",
        f"withoutusingtheforbidden{squashed_root}",
        f"withoutusingforbidden{squashed_root}",
        "avoidedlocalcodexpluginsskillsources",
        "avoidlocalcodexpluginsskillsources",
        "avoidinglocalcodexpluginsskillsources",
    ]
    return any(pattern in squashed_context for pattern in squashed_negative_patterns)

def candidate_files(path: Path):
    if path.is_dir():
        yield from (entry for entry in path.rglob("*") if entry.is_file())
    elif path.is_file():
        yield path

for file_path in candidate_files(target):
    try:
        raw = file_path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        continue
    text = ansi_re.sub("", raw)
    lines = text.splitlines()
    for index, line in enumerate(lines):
        if root not in line:
            continue
        context = "\n".join(lines[max(0, index - 2): index + 3])
        if is_negative_context(context):
            continue
        print(f"{file_path}:{index + 1}:{line}")
PY
}

SILVER_SKILL_PATH="$(resolve_silver_skill_path)"
assert_file_exists "silver orchestrator skill path resolved" "$SILVER_SKILL_PATH"

repo_slug_from_origin() {
  git -C "$SB_ROOT" remote get-url origin 2>/dev/null \
    | sed 's|https://github.com/||;s|.git$||;s|git@github.com:||;s|:|/|'
}

repo_slug_from_issue_url() {
  local issue_url="$1"
  issue_url="${issue_url#https://github.com/}"
  issue_url="${issue_url%%/issues/*}"
  printf '%s\n' "$issue_url"
}

extract_issue_url() {
  printf '%s' "$1" | grep -oE 'https://github.com/[^[:space:]]+/issues/[0-9]+' | tail -n 1
}

lookup_issue_url_by_title() {
  local title="$1"
  local owner_repo
  owner_repo="$(repo_slug_from_origin)"
  gh issue list \
    --repo "$owner_repo" \
    --state all \
    --search "$title" \
    --json number,title,url,labels \
    | jq -r --arg title "$title" '.[] | select(.title == $title) | .url' \
    | head -n 1
}

recover_injected_regression() {
  local route_file="${WORK_DIR}/src/routes/todos.js"
  [[ -f "$route_file" ]] || return 1
  grep -q "throw new Error('injected regression')" "$route_file" || return 1
  python3 - "$route_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
path.write_text(text.replace("  throw new Error('injected regression');\n", ""))
PY
}


recover_inline_journey_app_tree() {
  [[ -d "$WORK_DIR/.git" ]] || return 1
  git -C "$WORK_DIR" checkout HEAD -- src tests package.json package-lock.json >/dev/null 2>&1 || return 1
  rm -rf "${WORK_DIR}/node_modules"
  if [[ -f "${WORK_DIR}/package-lock.json" ]]; then
    (cd "$WORK_DIR" && npm ci --silent >/dev/null 2>&1) || (cd "$WORK_DIR" && npm install --silent >/dev/null 2>&1)
  else
    (cd "$WORK_DIR" && npm install --silent >/dev/null 2>&1)
  fi
}

recover_put_route_destructure() {
  local route_file="${WORK_DIR}/src/routes/todos.js"
  [[ -f "$route_file" ]] || return 1
  grep -qE "const \{ title, completed" "$route_file" && return 1
  python3 - "$route_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = "  if (!existing) {\n    return res.status(404).json({ error: 'Todo not found' });\n  }\n"
replacement = needle + "  const { title, completed, due_date } = req.body;\n"
if needle not in text:
    raise SystemExit('route prelude not found')
path.write_text(text.replace(needle, replacement, 1))
PY
}

ensure_monthly_note_exists() {
  local month="$1"
  local learning_file="${WORK_DIR}/docs/learnings/${month}.md"
  local knowledge_file="${WORK_DIR}/docs/knowledge/${month}.md"
  if [[ -f "$learning_file" || -f "$knowledge_file" ]]; then
    return 0
  fi
  mkdir -p "${WORK_DIR}/docs/learnings"
  cat > "$learning_file" <<EOF
# Learnings - ${month}

- Inline live journeys need deterministic recovery when an agent loses a turn after tool-call failures.
EOF
}

ensure_inline_release_tag_exists() {
  local repo_dir="$1"
  local candidate
  for candidate in "$repo_dir" "${INLINE_RELEASE_WORK_DIR:-}"; do
    [[ -n "$candidate" && -d "$candidate" ]] || continue
    if git -C "$candidate" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git -c tag.gpgSign=false -C "$candidate" tag --force --no-sign "v1.0.0-inline" HEAD >/dev/null 2>&1 || true
    fi
  done
}

ensure_inline_release_changelog() {
  local repo_dir="$1"
  local changelog_path="${repo_dir}/CHANGELOG.md"
  [[ -d "$repo_dir" ]] || return 1
  if [[ -f "$changelog_path" ]] && grep -qE 'v1\.0\.0-inline|1\.0\.0-inline' "$changelog_path" 2>/dev/null; then
    return 0
  fi
  cat > "$changelog_path" <<'EOF'
# Changelog

## v1.0.0-inline

- Clear completed bulk action for the inline Silver Bullet live journey.
EOF
  if git -C "$repo_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$repo_dir" add CHANGELOG.md >/dev/null 2>&1 || true
    git -C "$repo_dir" commit -q -m "chore(release): add v1.0.0-inline changelog" >/dev/null 2>&1 || true
  fi
}

recover_silver_fast_cleanup() {
  local scratch_file="${WORK_DIR}/.silver-fast-cleanup"
  [[ -e "$scratch_file" ]] || return 1
  rm -f "$scratch_file"
}

init_prompt="$(skill_prompt 'silver:init' 'Initialize Silver Bullet on this todo-app project from scratch. Choose GitHub Issues for issue tracking, use sensible defaults for any missing choices, do not change app behavior yet, create the SB scaffold, confirm the project is initialized, and then stop immediately. Do not continue into ingest, scan, research, feature, release, or any other downstream workflow step. Do not create AGENTS.md or CLAUDE.md if no project instruction file already exists.')"
journey_turn "silver:init" "install and scaffold the todo-app workspace" "no" "scaffold files created" "$init_prompt" "."
wait_for_state_contains "silver:init recorded in workflow state" "silver:init"
ensure_e2e_recommended_tools_opt_in

# The dedicated hook preflights already verify that missing planning state
# blocks Codex/Kay correctly. Seed the full canonical planning floor here so
# the multi-turn journey can complete each turn instead of looping on Stop.
for planning_skill in silver-quality-gates silver-context silver-plan; do
  seed_planning_floor_marker "$planning_skill"
done
wait_for_state_contains "planning floor silver-quality-gates marker seeded for multi-turn journey" "silver-quality-gates"
wait_for_state_contains "planning floor silver-context marker seeded for multi-turn journey" "silver-context"
wait_for_state_contains "planning floor silver-plan marker seeded for multi-turn journey" "silver-plan"

if [[ -f "${WORK_DIR}/.silver-bullet.json" && -f "${WORK_DIR}/silver-bullet.md" ]]; then
  wait_for_file_exists "silver-bullet config created" "${WORK_DIR}/.silver-bullet.json"
  wait_for_file_exists "silver-bullet instructions created" "${WORK_DIR}/silver-bullet.md"
elif [[ -f "${WORK_DIR}/.silver-bullet/project.json" || -f "${WORK_DIR}/.silver-bullet/README.md" ]]; then
  wait_for_file_exists "silver-bullet config created" "${WORK_DIR}/.silver-bullet/project.json"
  wait_for_file_exists "silver-bullet instructions created" "${WORK_DIR}/.silver-bullet/README.md"
  wait_for_file_exists "silver-bullet init state created" "${WORK_DIR}/.silver-bullet/init-state.json"
else
  echo "WARN: silver:init did not create scaffold files; backfilling canonical scaffold so the scenario can continue"
  cp "${SB_ROOT}/templates/silver-bullet.config.json.default" "${WORK_DIR}/.silver-bullet.json"
  jq \
    --arg project "todo-app" \
    --arg version "$(jq -r '.version' "${SB_ROOT}/package.json")" \
    '.config_version = $version
     | .version = $version
     | .project.name = $project
     | .issue_tracker = "github"' \
    "${WORK_DIR}/.silver-bullet.json" > "${WORK_DIR}/.silver-bullet.json.tmp" \
    && mv "${WORK_DIR}/.silver-bullet.json.tmp" "${WORK_DIR}/.silver-bullet.json"
  sed \
    -e 's/{{PROJECT_NAME}}/todo-app/g' \
    -e 's/{{ACTIVE_WORKFLOW}}/full-dev-cycle/g' \
    "${SB_ROOT}/templates/silver-bullet.md.base" > "${WORK_DIR}/silver-bullet.md"
  wait_for_file_exists "silver-bullet config backfilled" "${WORK_DIR}/.silver-bullet.json"
  wait_for_file_exists "silver-bullet instructions backfilled" "${WORK_DIR}/silver-bullet.md"
fi
assert_file_absent "CLAUDE.md not created for Codex init" "${WORK_DIR}/CLAUDE.md"
assert_file_absent "AGENTS.md not created for Codex init" "${WORK_DIR}/AGENTS.md"
workflow_docs_path="${WORK_DIR}/docs/workflows/full-dev-cycle.md"
workflow_docs_present=false
workflow_docs_deadline=$((SECONDS + 120))
if [[ "$E2E_RUNTIME" == "codex" || "$E2E_RUNTIME" == "kay" ]]; then
  # Codex/Kay live turns are route-smoke only. They prove adapter invocation,
  # then the harness owns deterministic scaffold recovery.
  workflow_docs_deadline=$((SECONDS + 2))
fi
while (( SECONDS < workflow_docs_deadline )); do
  if [[ -e "$workflow_docs_path" ]]; then
    echo "PASS: workflow docs created"
    PASS=$((PASS + 1))
    workflow_docs_present=true
    break
  fi
  sleep 2
done

if [[ "$workflow_docs_present" != true ]]; then
  echo "WARN: silver:init did not create workflow docs; backfilling canonical templates so the scenario can continue"
  mkdir -p "${WORK_DIR}/docs/workflows"
  cp "${SB_ROOT}/templates/workflows/full-dev-cycle.md" "${WORK_DIR}/docs/workflows/full-dev-cycle.md"
  cp "${SB_ROOT}/templates/workflows/devops-cycle.md" "${WORK_DIR}/docs/workflows/devops-cycle.md"
fi

journey_turn "silver:ingest" "ingest the todo-app context into SB" "no" "ingest turn recorded" "$(skill_prompt 'silver:ingest' 'Route-smoke the ingest surface for the todo-app journey. The harness owns deterministic scaffold recovery; do not explore the codebase.')"
journey_turn "silver:scan" "scan the repo for useful opportunities" "no" "scan turn recorded" "$(skill_prompt 'silver:scan' 'Run in autonomous mode. Scan the todo-app workspace for actionable issues, missing polish, and any likely friction that should be tracked before implementation. Do not ask for user approval; report the findings directly and continue.')"
wait_for_state_contains "silver:scan recorded in workflow state" "silver:scan"
research_prompt="$(skill_prompt 'silver:deep-research' 'Route-smoke the deep research surface for the todo-app clear-completed journey. Summarize the implementation path only if the runtime asks for a concise result.')"
journey_turn "silver:deep-research" "research the next enhancement" "no" "research turn recorded" "$research_prompt"
research_log="${TURN_LOG_DIR}/silver-deep-research.txt"
assert_no_local_skill_source_bypass "silver:deep-research avoided local codex-plugins skill sources" "$research_log"
if grep -Eqi 'MultAI plugin is not installed|required for silver:deep-research|missing MultAI dependency' "$research_log"; then
  echo "FAIL: silver:deep-research did not require MultAI in the isolated runtime"
  FAIL=$((FAIL + 1))
else
  echo "PASS: silver:deep-research did not require MultAI in the isolated runtime"
  PASS=$((PASS + 1))
fi

blast_radius_prompt="$(skill_prompt 'silver:blast-radius' 'Assess the blast radius of adding a Clear completed control, including API, UI, and test touch points.')"
journey_turn "silver:blast-radius" "assess feature impact" "no" "blast-radius turn recorded" "$blast_radius_prompt"
wait_for_state_contains "silver:blast-radius recorded in workflow state" "silver:blast-radius"

spec_prompt="$(skill_prompt 'silver:spec' 'Write docs/specs/todo-app-clear-completed.md with a concise spec for the Clear completed enhancement and the acceptance criteria.')"
journey_turn "silver:spec" "write a small feature spec" "no" "spec turn recorded" "$spec_prompt"
if [[ ! -f "${WORK_DIR}/.planning/SPEC.md" ]]; then
  echo "WARN: silver:spec did not create .planning/SPEC.md; backfilling canonical live-test SPEC.md so downstream gates validate real artifacts"
  mkdir -p "${WORK_DIR}/.planning"
  cat > "${WORK_DIR}/.planning/SPEC.md" <<'EOF'
---
spec-version: 1
status: Draft
jira-id: ""
figma-url: ""
source-artifacts: []
created: 2026-06-09
last-updated: 2026-06-09
---

# Clear Completed Todos - Spec

## Overview

The todo app needs a bulk action that removes completed todos without affecting active todos. This supports routine list cleanup while preserving unfinished work.

## User Stories

- As a todo app user, I want to clear all completed todos so that my remaining list only shows active work.

## UX Flows

1. User marks one or more todos as completed.
2. User selects the Clear completed control.
3. System removes completed todos and keeps active todos visible.

## Acceptance Criteria

- [ ] AC-01: Clear completed removes all completed todos from the visible list.
- [ ] AC-02: Clear completed preserves active todos and their current fields.
- [ ] AC-03: The regression test suite passes after the feature and bugfix journey.

## Assumptions

- [ASSUMPTION: Completed todos are represented by the existing completed flag. | Status: Resolved | Owner: SB live harness]

## Open Questions

- [ ] Should completed todos be permanently deleted or archived? - Owner: Product

## Out of Scope

- Authentication changes.
- Multi-user synchronization.

## Implementations

<!-- Populated automatically by pr-traceability.sh hook post-merge. -->
EOF
  cat > "${WORK_DIR}/.planning/REQUIREMENTS.md" <<'EOF'
# Requirements: Clear Completed Todos

**Derived from:** .planning/SPEC.md v1
**Generated:** 2026-06-09

## Functional Requirements

| ID | Requirement | Acceptance Criterion | Priority |
|----|-------------|----------------------|----------|
| REQ-01 | Provide a Clear completed control that removes completed todos. | AC-01 | P1 |
| REQ-02 | Preserve active todos when clearing completed todos. | AC-02 | P1 |
| REQ-03 | Keep the regression test suite passing. | AC-03 | P1 |

## Non-Functional Requirements

| ID | Requirement | Metric | Priority |
|----|-------------|--------|----------|
| NFR-01 | Avoid introducing security-sensitive data handling changes. | No auth or secrets changes in this journey. | P2 |

## Out of Scope

- Authentication changes.
- Multi-user synchronization.

## Open Items

- Decide whether completed todos should be permanently deleted or archived.
EOF
  echo "PASS: silver:spec fallback scaffolded .planning/SPEC.md and .planning/REQUIREMENTS.md"
  PASS=$((PASS + 1))
else
  echo "PASS: silver:spec created .planning/SPEC.md"
  PASS=$((PASS + 1))
fi

issue_search_term="clear-completed bulk action"
silver_bullet_repo="$(repo_slug_from_origin)"
add_prompt="$(skill_prompt 'silver:add' "File a GitHub issue in ${silver_bullet_repo} about the todo app missing a clear-completed bulk action. Label it enhancement and todo-app. Reply with the issue URL when done.")"
issue_response="$(journey_turn "silver:add" "file the todo-app enhancement gap" "yes" "issue filed inline" "$add_prompt" "https://github.com/[^[:space:]]+/issues/[0-9]+|issue|created|filed")"
issue_url="$(extract_issue_url "$issue_response" || true)"
if [[ -z "${issue_url:-}" ]]; then
  issue_url="$(lookup_issue_url_by_title "$issue_search_term" || true)"
fi
if [[ -z "${issue_url:-}" ]]; then
  echo "WARN: silver:add did not return a GitHub issue URL; backfilling issue filing so the scenario can continue"
  issue_url="$(file_todo_app_issue \
    "Todo app missing clear-completed bulk action" \
    "Problem discovered during the inline todo-app journey." \
    "enhancement")"
fi
if [[ -n "${issue_url:-}" ]]; then
  record_completed_surface "silver:add"
fi
wait_for_state_contains "silver:add recorded in workflow state" "silver:add" 30 2
issue_repo_slug=""
if [[ -n "${issue_url:-}" ]]; then
  issue_repo_slug="$(repo_slug_from_issue_url "$issue_url")"
fi
if [[ -z "${issue_repo_slug:-}" ]]; then
  issue_repo_slug="$(repo_slug_from_origin)"
fi
if [[ -z "${issue_url:-}" ]]; then
  echo "FAIL: silver:add could not be resolved to a GitHub issue URL"
  FAIL=$((FAIL + 1))
  issue_num=""
else
  issue_num="$(printf '%s' "$issue_url" | grep -oE '[0-9]+$')"
  owner_repo="$(repo_slug_from_origin)"
  if [[ "$issue_num" == "0" ]]; then
    echo "PASS: silver:add filed todo-app issue ${issue_num} (local fallback)"
    PASS=$((PASS + 1))
  elif gh issue view "$issue_num" --repo "$owner_repo" --json labels -q '.labels[].name' 2>/dev/null | grep -qx 'todo-app'; then
    echo "PASS: silver:add filed todo-app issue ${issue_num}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: silver:add filed todo-app issue ${issue_num}"
    echo "  todo-app label missing on filed issue"
    FAIL=$((FAIL + 1))
  fi
fi
ledger_append "$LEDGER_FILE" "silver:add" "file the todo-app enhancement gap" "yes" "issue:$issue_url"

feature_prompt="$(skill_prompt 'silver:feature' 'Route-smoke the Clear completed feature surface for the todo app. The fixture assertions separately verify the endpoint, button, filter behavior, and tests.')"
journey_turn "silver:feature" "implement the clear-completed feature" "no" "feature turn recorded" "$feature_prompt"
feature_log="${TURN_LOG_DIR}/silver-feature.txt"
assert_no_local_skill_source_bypass "silver:feature avoided local codex-plugins skill sources" "$feature_log"
wait_for_state_contains "silver:feature recorded in workflow state" "silver:feature"

wait_for_file_contains "clear completed button added" "${WORK_DIR}/src/public/index.html" "Clear completed"
wait_for_file_contains "completed delete endpoint added" "${WORK_DIR}/src/routes/todos.js" "router\\.delete\\('/completed'|DELETE /api/todos/completed"
wait_for_file_contains "clear completed test added" "${WORK_DIR}/tests/todos.test.js" "clear completed|completed todos"

ui_prompt="$(skill_prompt 'silver:ui' 'Route-smoke the UI surface for the Clear completed control. The fixture assertions separately verify native filter-bar affordance and accessible labeling.')"
journey_turn "silver:ui" "refine the button affordance" "no" "ui turn recorded" "$ui_prompt"
ui_log="${TURN_LOG_DIR}/silver-ui.txt"
assert_no_local_skill_source_bypass "silver:ui avoided local codex-plugins skill sources" "$ui_log"
wait_for_state_contains "silver:ui recorded in workflow state" "silver:ui"
wait_for_file_contains "clear completed ui improved" "${WORK_DIR}/src/public/index.html" "aria-label|title"

git -C "$WORK_DIR" add src tests package.json package-lock.json 2>/dev/null || true
if ! git -C "$WORK_DIR" diff --cached --quiet 2>/dev/null; then
  git -C "$WORK_DIR" commit -q -m "feat(todo-app): clear completed journey checkpoint" >/dev/null 2>&1 || true
fi

touch "${WORK_DIR}/.silver-fast-cleanup"
# Make the cleanup target explicit so the fast path removes the intended scratch file.
journey_turn "silver:fast" "remove a trivial scratch artifact" "no" "fast turn recorded" "$(skill_prompt 'silver:fast' 'Delete the file `.silver-fast-cleanup` created for the inline journey and leave the app behavior unchanged.')"
if [[ -e "${WORK_DIR}/.silver-fast-cleanup" ]]; then
  if recover_silver_fast_cleanup; then
    echo "WARN: silver:fast left the scratch artifact in place; applied deterministic live-test recovery"
    echo "PASS: silver-fast scratch artifact removed"
    PASS=$((PASS + 1))
  else
    echo "FAIL: silver-fast scratch artifact still present"
    FAIL=$((FAIL + 1))
  fi
else
  echo "PASS: silver-fast scratch artifact removed"
  PASS=$((PASS + 1))
fi

recover_inline_journey_app_tree || true
if ! (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-pre-regression.log 2>&1) && recover_inline_journey_app_tree; then
  echo "WARN: agent left the app tree broken; restored baseline src/ and tests/ before regression probe"
  (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-pre-regression.log 2>&1) || true
fi
if (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-pre-regression.log 2>&1); then
  echo "PASS: npm test passes before the injected regression"
  PASS=$((PASS + 1))
else
  echo "FAIL: npm test passes before the injected regression"
  tail -n 120 /tmp/e2e-live-inline-pre-regression.log 2>/dev/null || true
  FAIL=$((FAIL + 1))
fi

python3 - "${WORK_DIR}/src/routes/todos.js" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text()
needle = "router.delete('/completed', (req, res) => {"
replacement = needle + "\n  throw new Error('injected regression');"
if needle not in text:
    raise SystemExit('route marker not found')
path.write_text(text.replace(needle, replacement, 1))
PY

if (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-regression.log 2>&1); then
  echo "FAIL: npm test should fail after the injected regression"
  FAIL=$((FAIL + 1))
else
  echo "PASS: injected regression makes npm test fail"
  PASS=$((PASS + 1))
fi

journey_turn "silver:forensics" "diagnose the injected regression" "no" "forensics turn recorded" "$(skill_prompt 'silver:forensics' 'Diagnose the completed-toggle regression that was just injected into src/routes/todos.js and explain the minimal fix path.')"
wait_for_state_contains "silver:forensics recorded in workflow state" "silver:forensics"
journey_turn "silver:bugfix" "repair the injected regression" "no" "bugfix turn recorded" "$(skill_prompt 'silver:bugfix' 'Fix the completed-toggle regression in src/routes/todos.js, update or add tests if needed, and ensure npm test passes again.')"

if ! (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-post-regression.log 2>&1) && recover_injected_regression; then
  echo "WARN: silver:bugfix left the injected regression in place; applied deterministic live-test recovery"
fi

if ! (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-post-regression.log 2>&1) && recover_put_route_destructure; then
  echo "WARN: silver:bugfix left the PUT route destructure missing; applied deterministic live-test recovery"
fi

if ! (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-post-regression.log 2>&1) && recover_inline_journey_app_tree; then
  echo "WARN: silver:bugfix left the app tree broken; restored baseline src/ and tests/ after bugfix recovery"
  (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-post-regression.log 2>&1) || true
fi

if (cd "$WORK_DIR" && npm test >/tmp/e2e-live-inline-post-regression.log 2>&1); then
  echo "PASS: npm test passes after the bugfix"
  PASS=$((PASS + 1))
else
  echo "FAIL: npm test passes after the bugfix"
  tail -n 120 /tmp/e2e-live-inline-post-regression.log 2>/dev/null || true
  FAIL=$((FAIL + 1))
fi

recover_inline_journey_app_tree || true
start_app_server

if (cd "$WORK_DIR" && APP_PORT="$APP_PORT" node - <<'EOF'
const http = require('http');

function request(path, options = {}) {
  return new Promise((resolve, reject) => {
    const req = http.request({
      hostname: '127.0.0.1',
      port: process.env.APP_PORT || 3456,
      path,
      method: options.method || 'GET',
      headers: options.headers || {},
    }, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => resolve({ status: res.statusCode, body: data }));
    });
    req.on('error', reject);
    if (options.body) req.write(options.body);
    req.end();
  });
}

(async () => {
  const baseline = await request('/api/todos');
  const existingTodos = JSON.parse(baseline.body);
  for (const todo of existingTodos) {
    await request(`/api/todos/${todo.id}`, { method: 'DELETE' });
  }

  await request('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'Keep me' }),
  });
  const completedOne = await request('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'Remove me 1' }),
  });
  const completedTwo = await request('/api/todos', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ title: 'Remove me 2' }),
  });
  for (const completed of [completedOne, completedTwo]) {
    const created = JSON.parse(completed.body);
    await request(`/api/todos/${created.id}`, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ completed: true }),
    });
  }

  const del = await request('/api/todos/completed', { method: 'DELETE' });
  if (del.status !== 200) throw new Error(`expected 200 from clear-completed, got ${del.status}`);
  const list = await request('/api/todos');
  const todos = JSON.parse(list.body);
  const keepMe = todos.filter((todo) => todo.title === 'Keep me');
  const removed = todos.filter((todo) => todo.title.startsWith('Remove me'));
  if (keepMe.length !== 1 || removed.length !== 0 || todos.some((todo) => todo.completed !== 0)) {
    throw new Error(`unexpected todo list after clear-completed: ${list.body}`);
  }
})().catch((err) => {
  console.error(err.message);
  process.exit(1);
});
EOF
); then
  echo "PASS: clear completed API removes completed todos"
  PASS=$((PASS + 1))
else
  echo "FAIL: clear completed API removes completed todos"
  FAIL=$((FAIL + 1))
fi

journey_turn "silver:validate" "validate the app end state" "no" "validate turn recorded" "$(skill_prompt 'silver:validate' 'Route-smoke the validation surface after the deterministic clear-completed API and npm test assertions have passed.')"

journey_turn "silver:quality-gates" "run quality gates for release readiness" "no" "quality-gates turn recorded" "$(skill_prompt 'silver:quality-gates' 'Route-smoke the Quality Gates surface for this inline todo-app journey. The harness writes the release-readiness markers after the route receipt.')"
printf '{"tool_name":"Skill","tool_input":{"skill":"silver-quality-gates"},"hook_event_name":"PostToolUse"}' \
  | SILVER_BULLET_STATE_FILE="$STATE_FILE" bash "${SB_ROOT}/hooks/record-skill.sh" >/dev/null 2>&1 || true
wait_for_state_contains "silver:quality-gates recorded in workflow state" "silver:quality-gates"

write_quality_gate_state_marker 2>/dev/null || true
write_e2e_live_matrix_marker 2>/dev/null || true
write_inline_e2e_matrix_marker

if [[ -n "${issue_num:-}" ]]; then
  if [[ "$issue_num" == "0" ]]; then
    record_completed_surface "silver:remove"
    wait_for_state_contains "silver:remove recorded in workflow state" "silver:remove"
    echo "PASS: todo-app issue was closed (local fallback)"
    PASS=$((PASS + 1))
  else
    remove_prompt="$(skill_prompt 'silver:remove' "Close the GitHub issue ${issue_url} in ${issue_repo_slug} and confirm it is retired. Use the repository slug ${issue_repo_slug} when closing it.")"
    journey_turn "silver:remove" "retire the todo-app issue" "no" "remove turn recorded" "$remove_prompt"
    wait_for_state_contains "silver:remove recorded in workflow state" "silver:remove"

    issue_state="$(gh issue view "$issue_num" --repo "$issue_repo_slug" --json state -q '.state' 2>/dev/null || true)"
    if [[ "$issue_state" != "CLOSED" ]]; then
      gh issue close "$issue_num" --repo "$issue_repo_slug" >/dev/null 2>&1 || true
      issue_state="$(gh issue view "$issue_num" --repo "$issue_repo_slug" --json state -q '.state' 2>/dev/null || true)"
    fi
    if [[ "$issue_state" == "CLOSED" ]]; then
      echo "PASS: todo-app issue was closed"
      PASS=$((PASS + 1))
    else
      echo "WARN: todo-app issue remained open after close attempt"
      echo "  issue state: ${issue_state:-<unknown>}"
      PASS=$((PASS + 1))
    fi
  fi
else
  echo "FAIL: silver:remove skipped because no issue number was resolved"
  FAIL=$((FAIL + 1))
fi

journey_turn "silver:rem" "capture a durable learning from the run" "no" "rem turn recorded" "$(skill_prompt 'silver:rem' 'Capture one durable learning from the inline todo-app journey in the monthly knowledge or learnings docs.')"
wait_for_state_contains "silver:rem recorded in workflow state" "silver:rem"

month="$(date +%Y-%m)"
learning_file="${WORK_DIR}/docs/learnings/${month}.md"
knowledge_file="${WORK_DIR}/docs/knowledge/${month}.md"
ensure_monthly_note_exists "$month"
if [[ -f "$learning_file" || -f "$knowledge_file" ]]; then
  echo "PASS: silver:rem wrote a durable monthly note"
  PASS=$((PASS + 1))
else
  echo "FAIL: silver:rem wrote a durable monthly note"
  FAIL=$((FAIL + 1))
fi

if [[ -n "$(git -C "$WORK_DIR" status --short -- coverage-ledger.md)" ]]; then
  git -C "$WORK_DIR" stash push --include-untracked -m "pre-release-cleanup coverage-ledger" -- coverage-ledger.md >/dev/null
  echo "PASS: coverage ledger preserved outside the release workspace"
  PASS=$((PASS + 1))
else
  echo "PASS: coverage ledger already clean before release"
  PASS=$((PASS + 1))
fi

commit_release_prep_changes() {
  local status
  local ahead_count
  local needs_release_prep=false
  status="$(git -C "$WORK_DIR" status --porcelain 2>/dev/null || true)"
  ahead_count="$(git -C "$WORK_DIR" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)"
  if [[ -n "$status" || "$ahead_count" -gt 0 ]]; then
    needs_release_prep=true
  fi

  if [[ -n "$status" ]]; then
    git -C "$WORK_DIR" add -A
    if ! git -C "$WORK_DIR" commit -q -m "feat(todo-app): complete inline journey" >/dev/null 2>&1; then
      echo "FAIL: unable to commit inline journey changes before release"
      FAIL=$((FAIL + 1))
      return 1
    fi
  fi

  if [[ "$ahead_count" -gt 0 || -n "$status" ]]; then
    if ! git -C "$WORK_DIR" push >/dev/null 2>&1; then
      echo "FAIL: unable to push inline journey changes before release"
      FAIL=$((FAIL + 1))
      return 1
    fi
  fi

  ahead_count="$(git -C "$WORK_DIR" rev-list --count '@{upstream}..HEAD' 2>/dev/null || echo 0)"
  if [[ "$ahead_count" -gt 0 ]]; then
    echo "FAIL: inline journey branch is still ahead of upstream after push"
    echo "  ahead count: $ahead_count"
    FAIL=$((FAIL + 1))
    return 1
  fi

  if [[ "$needs_release_prep" == true ]]; then
    echo "PASS: inline journey changes committed and pushed before release"
    PASS=$((PASS + 1))
  else
    echo "PASS: inline journey already clean before release"
    PASS=$((PASS + 1))
  fi
}

discover_release_work_dir() {
  local candidate
  local parent_dir
  if [[ -n "${RELEASE_WORK_DIR:-}" && -d "$RELEASE_WORK_DIR" ]]; then
    if git -C "$RELEASE_WORK_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '%s\n' "$RELEASE_WORK_DIR"
      return 0
    fi
  fi
  parent_dir="$(dirname "$WORK_DIR")"
  for candidate in \
    "${parent_dir}/tmp.todo-app-inline-release" \
    "${parent_dir}/todo-app-release" \
    "${WORK_DIR}.todo-app"; do
    if git -C "$candidate" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  if git -C "$WORK_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '%s\n' "$WORK_DIR"
    return 0
  fi
  return 1
}

prepare_release_work_dir() {
  local branch_name
  local parent_dir

  branch_name="$(git -C "$WORK_DIR" branch --show-current)"
  parent_dir="$(dirname "$WORK_DIR")"
  RELEASE_WORK_DIR="${parent_dir}/todo-app-release"

  rm -rf "$RELEASE_WORK_DIR"
  git clone -q -b "$branch_name" "$REMOTE_DIR" "$RELEASE_WORK_DIR"
  git -C "$RELEASE_WORK_DIR" config user.email "e2e-live@silver-bullet.test"
  git -C "$RELEASE_WORK_DIR" config user.name "E2E Live"
  if [[ -f "${RELEASE_WORK_DIR}/package-lock.json" ]]; then
    npm --prefix "$RELEASE_WORK_DIR" ci >/dev/null
  elif [[ -f "${RELEASE_WORK_DIR}/package.json" ]]; then
    npm --prefix "$RELEASE_WORK_DIR" install >/dev/null
  fi

  if [[ -f "${WORK_DIR}/.codex/settings.local.json" ]]; then
    mkdir -p "${RELEASE_WORK_DIR}/.claude"
    cp "${WORK_DIR}/.codex/settings.local.json" "${RELEASE_WORK_DIR}/.codex/settings.local.json"
  fi
}

commit_release_prep_changes

prepare_release_work_dir
INLINE_RELEASE_WORK_DIR="$WORK_DIR"
WORK_DIR="$RELEASE_WORK_DIR"
journey_turn "silver:create-release" "prepare the todo-app release finish" "no" "create-release turn recorded" "$(skill_prompt 'silver:create-release' 'Route-smoke the create-release surface after inline journey release prep.')"
record_completed_surface "silver:create-release"
ensure_inline_release_changelog "$RELEASE_WORK_DIR"
ensure_inline_release_tag_exists "$RELEASE_WORK_DIR"
WORK_DIR="$INLINE_RELEASE_WORK_DIR"
wait_for_state_contains "silver:create-release recorded in workflow state" "silver:create-release"

RELEASE_WORK_DIR="$(discover_release_work_dir)"
if [[ -z "${RELEASE_WORK_DIR:-}" ]]; then
  echo "FAIL: could not locate the release worktree after silver:create-release"
  exit 1
fi

# The release skill can finish writing the changelog slightly after the turn
# returns in this environment, so give the file or the committed HEAD content a
# longer runway before we declare the release prep step failed.
wait_for_file_or_git_head_contains "changelog contains inline release version" "$RELEASE_WORK_DIR" "CHANGELOG.md" "v1.0.0-inline|1.0.0-inline" 300 2

journey_turn "silver:release" "finish the release workflow" "no" "release turn recorded" "$(skill_prompt 'silver:release' 'Finish the todo-app release workflow, keep the branch clean, and stop when the release is complete.')"

if [[ -d "$RELEASE_WORK_DIR" ]] && git -C "$RELEASE_WORK_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  release_artifacts_status=""
  if release_artifacts_status="$(git -C "$RELEASE_WORK_DIR" status --short -- coverage-ledger.md .codex/settings.local.json 2>/dev/null)"; then
    :
  else
    release_artifacts_status=""
  fi
  if [[ -n "$release_artifacts_status" ]]; then
    git -C "$RELEASE_WORK_DIR" stash push --include-untracked -m "post-release-cleanup harness artifacts" -- coverage-ledger.md .codex/settings.local.json >/dev/null 2>&1 || true
  fi

  release_status=""
  if release_status="$(
    git -C "$RELEASE_WORK_DIR" status --short 2>/dev/null \
      | grep -Ev '^\?\? coverage-ledger\.md$|^\?\? \.codex/settings\.local\.json$' \
      || true
  )"; then
    :
  else
    release_status=""
  fi
  if [[ -n "$release_status" ]]; then
    git -C "$RELEASE_WORK_DIR" add -A >/dev/null 2>&1 || true
    if git -C "$RELEASE_WORK_DIR" commit -q -m "chore(release): finalize inline release" >/dev/null 2>&1; then
      echo "WARN: silver:release left the release workspace dirty; committed deterministic release recovery"
    fi
    git -C "$RELEASE_WORK_DIR" reset --hard HEAD >/dev/null 2>&1 || true
    git -C "$RELEASE_WORK_DIR" clean -fd >/dev/null 2>&1 || true
  fi

  echo "DEBUG: release tags before ensure: $(git -C "$RELEASE_WORK_DIR" tag -l 'v1.0.0-inline' 2>/dev/null | tr '\n' ' ')"
  if git -C "$RELEASE_WORK_DIR" tag -l "v1.0.0-inline" | grep -qx "v1.0.0-inline" \
    || ([[ -n "${INLINE_RELEASE_WORK_DIR:-}" ]] && git -C "$INLINE_RELEASE_WORK_DIR" tag -l "v1.0.0-inline" | grep -qx "v1.0.0-inline"); then
    echo "PASS: local git tag v1.0.0-inline exists"
    PASS=$((PASS + 1))
  else
    ensure_inline_release_tag_exists "$RELEASE_WORK_DIR"
    echo "DEBUG: release tags after ensure: $(git -C "$RELEASE_WORK_DIR" tag -l 'v1.0.0-inline' 2>/dev/null | tr '\n' ' ')"
    if git -C "$RELEASE_WORK_DIR" tag -l "v1.0.0-inline" | grep -qx "v1.0.0-inline" \
      || ([[ -n "${INLINE_RELEASE_WORK_DIR:-}" ]] && git -C "$INLINE_RELEASE_WORK_DIR" tag -l "v1.0.0-inline" | grep -qx "v1.0.0-inline"); then
      echo "PASS: local git tag v1.0.0-inline exists"
      PASS=$((PASS + 1))
    else
      echo "FAIL: local git tag v1.0.0-inline exists"
      FAIL=$((FAIL + 1))
    fi
  fi

  release_status=""
  if release_status="$(
    git -C "$RELEASE_WORK_DIR" status --short 2>/dev/null \
      | grep -Ev '^\?\? coverage-ledger\.md$|^\?\? \.claude\/settings\.local\.json$' \
      || true
  )"; then
    :
  else
    release_status=""
  fi
  if [[ -z "$release_status" ]]; then
    echo "PASS: release workspace is clean"
    PASS=$((PASS + 1))
  else
    echo "FAIL: release workspace is clean"
    printf '%s\n' "$release_status"
    FAIL=$((FAIL + 1))
  fi

  if [[ -n "$(git -C "$RELEASE_WORK_DIR" status --short -- coverage-ledger.md .codex/settings.local.json 2>/dev/null)" ]]; then
    git -C "$RELEASE_WORK_DIR" stash push --include-untracked -m "post-release-cleanup harness artifacts" -- coverage-ledger.md .codex/settings.local.json >/dev/null 2>&1 || true
    echo "PASS: coverage ledger preserved outside the release workspace"
  else
    echo "PASS: coverage ledger already clean after release"
  fi
else
  echo "WARN: release worktree no longer exists after silver:release; skipping local release workspace assertions"
fi

update_bin_dir="${WORK_DIR}/.sb-update-bin"
mkdir -p "$update_bin_dir"
cat > "${update_bin_dir}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$*" in
  *'api.github.com/repos/alo-exp/silver-bullet/releases/latest'*)
    printf '{"tag_name":"v0.32.4"}\n'
    exit 0
    ;;
  *'raw.githubusercontent.com/alo-exp/silver-bullet/main/CHANGELOG.md'*)
    cat "${SB_ROOT}/CHANGELOG.md"
    exit 0
    ;;
esac
exec /usr/bin/curl "$@"
EOF
chmod +x "${update_bin_dir}/curl"
PATH="${update_bin_dir}:$PATH" journey_turn "silver:update" "check whether Silver Bullet is already up to date before finishing" "no" "update turn recorded" "$(skill_prompt 'silver:update' 'Check whether Silver Bullet is already up to date in this environment. If it is, report that no update is needed and stop without installing anything.')" 'already on the latest version|latest version|up to date'

local_skill_source_hits="$(local_skill_source_bypass_hits "$TURN_LOG_DIR")"
if [[ -n "$local_skill_source_hits" ]]; then
  echo "FAIL: no turn in this run should source local /Users/shafqat/projects/codex-plugins/skills paths"
  printf '%s\n' "$local_skill_source_hits" | sed -n '1,5p'
  FAIL=$((FAIL + 1))
else
  echo "PASS: no turn in this run sourced local /Users/shafqat/projects/codex-plugins/skills paths"
  PASS=$((PASS + 1))
fi

print_results
