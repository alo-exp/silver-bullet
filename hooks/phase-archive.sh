#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Bash|exec_command)
# Intercepts a real `phases clear` invocation (and a shell command that deletes the whole
# .planning/phases directory) before it runs, and archives all current phase directories to
# .planning/archive/{milestone}/ so they are preserved after the clear completes.
#
# Only an actual invocation counts: the argv of a command contains `phases` `clear`, so a commit
# message or an echo that mentions the phrase archives nothing. Paths come from the project root,
# not the cwd. An archive of the same milestone never makes the clear skip archiving: phases that
# differ from every earlier snapshot are copied into a new timestamped snapshot, and a missing
# PROJECT.md or milestone line archives under "unnamed-milestone" instead of letting the clear
# run unprotected. A failed archive denies the clear.

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required for JSON parsing
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi

# Read JSON from stdin
input=$(cat)

# This hook fails closed: without jq the command cannot be parsed, so a `phases clear`
# in an SB project is denied (static reason; no jq in the deny path) instead of warned about.
if ! command -v jq >/dev/null 2>&1; then
  grep -qE 'phases[[:space:]]+clear' <<<"$input" || exit 0
  if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
    # shellcheck source=lib/sb-project-gate.sh
    source "$_lib_dir/sb-project-gate.sh"
    [[ -n "$(sb_find_project_config 2>/dev/null || true)" ]] || exit 0
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"phase-archive: jq required for Silver Bullet enforcement - blocking phases clear because phases cannot be archived without it"}}'
  exit 0
fi

# shellcheck source=lib/planning-floor.sh
source "$_lib_dir/planning-floor.sh"
# shellcheck source=lib/sb-project-gate.sh
source "$_lib_dir/sb-project-gate.sh"

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // ""')"
sb_tool_is_shell_like "$tool_name" || exit 0
sb_tool_input_load "$input" "$PWD"
if ! sb_tool_input_ok; then
  # The command cannot be analysed: refuse only what mentions both words, unless it is plainly read-only.
  [[ "${SB_TI_STATUS:-}" == "empty" ]] && exit 0
  lower="$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')"
  [[ "$lower" == *phases* && "$lower" == *clear* ]] || exit 0
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // .tool_input.cmd // ""' 2>/dev/null)"
  sb_pf_plain_read_only "$cmd" && exit 0
  config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
  [[ -n "$config_file" ]] || exit 0
  sb_emit_hook_decision PreToolUse deny "$(sb_pf_unanalysable_message)"
  exit 0
fi

# A `phases clear` invocation: some command's argv holds the two words side by side, and the
# program is not one that merely prints or searches text.
runs_phases_clear() {
  printf '%s' "${SB_SA_JSON:-}" | jq -e '
    [.commands[]? | select(((.argv[0] // "") | split("/") | last)
        | IN("echo", "printf", "cat", "grep", "egrep", "fgrep", "rg", "git", "sed", "awk", "ls", "head", "tail", "jq", "less", "man", "type", "which", "gh") | not)
     | .argv | . as $a | range(0; length - 1) | select($a[.] == "phases" and $a[. + 1] == "clear")]
    | length > 0' >/dev/null 2>&1
}

# Deleting the whole phases directory (or an ancestor of it) is the same loss by another name.
deletes_phases_dir() {
  local via target
  while IFS=$'\t' read -r via target; do
    case "$via" in rm | rmdir | unlink | "git rm" | "find -delete") ;; *) continue ;; esac
    case "$phases_dir/" in
      "$target"/*) return 0 ;;
    esac
  done < <(sb_pf_write_records "$input")
  return 1
}

config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
phases_dir=""
if [[ -n "$config_file" ]]; then
  project_root="$(sb_pf_canon "$(dirname "$config_file")")"
  phases_dir="$project_root/.planning/phases"
fi

if ! runs_phases_clear; then
  [[ -n "$phases_dir" ]] && deletes_phases_dir || exit 0
fi
[[ -n "$config_file" ]] || exit 0

# From here on a failure denies: the clear must not run without a copy.
trap 'printf "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"deny\",\"permissionDecisionReason\":\"phase-archive: archive failed — blocking clear to prevent data loss\"}}" ; exit 0' ERR

# No phases to archive — nothing to protect
if [[ ! -d "$phases_dir" ]] || [[ -z "$(ls -A "$phases_dir" 2>/dev/null)" ]]; then
  exit 0
fi

# Read the milestone name from the "Current Milestone:" line of PROJECT.md, as a slug
milestone_slug=""
PROJECT_MD="$project_root/.planning/PROJECT.md"
if [[ -f "$PROJECT_MD" ]]; then
  milestone_line=$(grep "Current Milestone:" "$PROJECT_MD" || true)
  if [[ -n "$milestone_line" ]]; then
    milestone_raw=$(printf '%s' "$milestone_line" | sed 's/.*Current Milestone:[[:space:]]*//' | sed 's/[[:space:]]*$//')
    milestone_slug=$(printf '%s' "$milestone_raw" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd 'a-z0-9._-')
  fi
fi
[[ -n "$milestone_slug" ]] || milestone_slug="unnamed-milestone"

ARCHIVE_DIR="$project_root/.planning/archive/${milestone_slug}"

# Is this phase directory already preserved, identically, in an earlier snapshot?
snapshot_has() {
  local name="$1" dir="$2" snap
  [[ -d "$ARCHIVE_DIR/$name" ]] && diff -rq "$dir" "$ARCHIVE_DIR/$name" >/dev/null 2>&1 && return 0
  for snap in "$ARCHIVE_DIR"/*/; do
    [[ -d "${snap}$name" ]] && diff -rq "$dir" "${snap}$name" >/dev/null 2>&1 && return 0
  done
  return 1
}

DEST="$ARCHIVE_DIR"
if [[ -n "$(ls -A "$ARCHIVE_DIR" 2>/dev/null)" ]]; then
  missing=false
  for phase_dir in "$phases_dir"/*/; do
    [[ -d "$phase_dir" ]] || continue
    snapshot_has "$(basename "$phase_dir")" "$phase_dir" || missing=true
  done
  if [[ "$missing" == false ]]; then
    sb_emit_hook_message PreToolUse "Phase archive: every phase is already preserved in .planning/archive/${milestone_slug}/."
    exit 0
  fi
  # A new snapshot beside the earlier ones: nothing is overwritten and nothing is skipped.
  DEST="$ARCHIVE_DIR/snapshot-$(date -u +%Y%m%dT%H%M%SZ)-$$"
fi

# Create archive destination
mkdir -p "$DEST"

# Copy all phase directories (cp -r preserves structure; the clear runs after we exit 0)
for phase_dir in "$phases_dir"/*/; do
  [[ -d "$phase_dir" ]] || continue
  phase_name=$(basename "$phase_dir")
  cp -r "$phase_dir" "$DEST/${phase_name}"
done

sb_emit_hook_message PreToolUse "Phase archive: copied phases to ${DEST#"$project_root"/}/ before clear."

# Exit 0 — let the original clear command proceed
exit 0
