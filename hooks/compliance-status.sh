#!/usr/bin/env bash
set -euo pipefail

# PostToolUse hook (matcher: .*)
# Shows a compact compliance progress score on every tool use.
# PERFORMANCE CRITICAL: must complete in <100ms. Minimal I/O.

# jq is required — silent exit if missing (don't slow down every tool use)
command -v jq >/dev/null 2>&1 || exit 0

# Consume stdin (required by hook protocol)
cat >/dev/null

# --- Resolve config file with caching ---
# Compute PWD hash for cache key (avoid word-splitting by branching explicitly)
pwd_hash=""
if command -v md5 >/dev/null 2>&1; then
  pwd_hash=$(printf '%s' "$PWD" | md5 -q)
elif command -v md5sum >/dev/null 2>&1; then
  pwd_hash=$(printf '%s' "$PWD" | md5sum | cut -d' ' -f1)
fi

config_file=""

if [[ -n "$pwd_hash" ]]; then
  cache_file="/tmp/.dev-workflows-config-path-${pwd_hash}"

  # Check cache
  if [[ -f "$cache_file" ]]; then
    cached_path=$(cat "$cache_file")
    if [[ -n "$cached_path" && -f "$cached_path" ]]; then
      config_file="$cached_path"
    else
      rm -f "$cache_file"
    fi
  fi
fi

# Walk up to find config if not cached
if [[ -z "$config_file" ]]; then
  search_dir="$PWD"
  while true; do
    if [[ -f "$search_dir/.dev-workflows.json" ]]; then
      config_file="$search_dir/.dev-workflows.json"
      break
    fi
    if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
      break
    fi
    search_dir=$(dirname "$search_dir")
  done

  # Cache result
  if [[ -n "${pwd_hash:-}" ]]; then
    cache_file="/tmp/.dev-workflows-config-path-${pwd_hash}"
    printf '%s' "$config_file" > "$cache_file"
  fi
fi

# No config → silent exit (project not set up)
[[ -z "$config_file" ]] && exit 0

# --- Read config values (single jq call for performance) ---
config_vals=$(jq -r '[
  (.state.state_file // "/tmp/.dev-workflows-state"),
  ((.skills.required_planning // ["brainstorming","write-spec","modularity","writing-plans"]) | join(" "))
] | join("\n")' "$config_file")

state_file=$(printf '%s' "$config_vals" | sed -n '1p')
required_planning=$(printf '%s' "$config_vals" | sed -n '2p')

# Env var override
state_file="${DEV_WORKFLOWS_STATE_FILE:-$state_file}"

# If no state file exists → early output with zeros
if [[ ! -f "$state_file" ]]; then
  # Count totals
  plan_total=0
  for _ in $required_planning; do ((plan_total++)) || true; done
  printf '{"hookSpecificOutput":{"message":"Dev Workflows: 0 steps | PLANNING 0/%d | EXECUTION 0/1 | REVIEW 0/3 | FINALIZATION 0/3 | Next: /%s"}}' \
    "$plan_total" \
    "$(printf '%s' "$required_planning" | cut -d' ' -f1)"
  exit 0
fi

# Read state file once
state_contents=$(cat "$state_file")
total_steps=$(printf '%s\n' "$state_contents" | grep -c . || true)

# Helper: check if skill is in state
has_skill() {
  printf '%s\n' "$state_contents" | grep -qx "$1" 2>/dev/null
}

# --- PLANNING phase ---
plan_done=0
plan_total=0
first_missing_plan=""
for skill in $required_planning; do
  ((plan_total++)) || true
  if has_skill "$skill"; then
    ((plan_done++)) || true
  elif [[ -z "$first_missing_plan" ]]; then
    first_missing_plan="$skill"
  fi
done

# --- EXECUTION phase ---
exec_done=0
exec_total=1
if has_skill "executing-plans"; then
  exec_done=1
fi

# --- REVIEW phase (hardcoded for v1 — future: make configurable via config keys) ---
review_skills="code-review receiving-code-review testing-strategy"
review_done=0
review_total=3
first_missing_review=""
for skill in $review_skills; do
  if has_skill "$skill"; then
    ((review_done++)) || true
  elif [[ -z "$first_missing_review" ]]; then
    first_missing_review="$skill"
  fi
done

# --- FINALIZATION phase (hardcoded for v1 — future: make configurable via config keys) ---
final_skills="documentation verification-before-completion finishing-a-development-branch"
final_done=0
final_total=3
first_missing_final=""
for skill in $final_skills; do
  if has_skill "$skill"; then
    ((final_done++)) || true
  elif [[ -z "$first_missing_final" ]]; then
    first_missing_final="$skill"
  fi
done

# --- Find NEXT required skill (first missing across phases in order) ---
next_skill=""
if [[ -n "$first_missing_plan" ]]; then
  next_skill="$first_missing_plan"
elif [[ $exec_done -eq 0 ]]; then
  next_skill="executing-plans"
elif [[ -n "$first_missing_review" ]]; then
  next_skill="$first_missing_review"
elif [[ -n "$first_missing_final" ]]; then
  next_skill="$first_missing_final"
fi

# --- Build output ---
msg="Dev Workflows: ${total_steps} steps | PLANNING ${plan_done}/${plan_total} | EXECUTION ${exec_done}/${exec_total} | REVIEW ${review_done}/${review_total} | FINALIZATION ${final_done}/${final_total}"
if [[ -n "$next_skill" ]]; then
  msg="${msg} | Next: /${next_skill}"
fi

printf '{"hookSpecificOutput":{"message":"%s"}}' "$msg"
