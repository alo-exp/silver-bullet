#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Bash)
# Detects git commit commands that stage a phase SUMMARY.md.
# Blocks the commit if the corresponding ROADMAP.md checkbox is not ticked [x].
#
# WHY: During autonomous execution, phase completion commits are created with
# SUMMARY.md artifacts but the ROADMAP.md checkbox is never updated, causing
# milestone state to diverge from execution reality.
#
# TRIGGER: git commit (any form) with a staged .planning/phases/N-*/N-*-SUMMARY.md
# ACTION:  Block and report which phase checkbox is unticked

# Security: restrict file creation permissions (user-only)
umask 0077

# jq is required — warn visibly if missing
if ! command -v jq >/dev/null 2>&1; then
  printf '{"hookSpecificOutput":{"message":"ROADMAP check inactive — jq not installed."}}'
  exit 0
fi

# Read JSON from stdin
input=$(cat)

# Extract command
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""')
[[ -z "$cmd" ]] && exit 0

# Only trigger on git commit commands
if ! printf '%s' "$cmd" | grep -qE '\bgit commit\b'; then
  exit 0
fi

# Locate project root by walking up from $PWD for .silver-bullet.json
config_file=""
project_root=""
search_dir="$PWD"
while true; do
  if [[ -f "$search_dir/.silver-bullet.json" ]]; then
    config_file="$search_dir/.silver-bullet.json"
    project_root="$search_dir"
    break
  fi
  if [[ -d "$search_dir/.git" ]] || [[ "$search_dir" == "/" ]]; then
    break
  fi
  search_dir=$(dirname "$search_dir")
done

# Not a Silver Bullet project — silent exit
[[ -z "$config_file" ]] && exit 0

# Get staged files
staged_files=$(git -C "$project_root" diff --cached --name-only 2>/dev/null || true)
[[ -z "$staged_files" ]] && exit 0

# Filter for phase SUMMARY.md files: .planning/phases/N-*/N-*-SUMMARY.md
# Convention: phase plan files are named {phase}-{step}-SUMMARY.md (e.g. 27-01-SUMMARY.md).
# Files with more numeric segments (e.g. 27-01-02-SUMMARY.md) are silently skipped — by design.
staged_summaries=$(printf '%s' "$staged_files" | grep -E '^\.planning/phases/[0-9]+-[^/]+/[0-9]+-[0-9]+-SUMMARY\.md$' || true)
[[ -z "$staged_summaries" ]] && exit 0

# ROADMAP.md must exist to perform the check
roadmap_file="$project_root/.planning/ROADMAP.md"
if [[ ! -f "$roadmap_file" ]]; then
  exit 0
fi

# Emit a PreToolUse block (this hook is registered as PreToolUse only)
emit_block() {
  local reason="$1"
  local json_reason
  json_reason=$(printf '%s' "$reason" | jq -Rs '.')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":%s}}' "$json_reason"
}

# Check each staged SUMMARY.md against ROADMAP.md
unticked_phases=""
while IFS= read -r summary_path; do
  # Extract phase number from path: .planning/phases/27-silver-fast-redesign/27-01-SUMMARY.md
  # The phase directory name starts with the phase number
  phase_dir=$(printf '%s' "$summary_path" | cut -d'/' -f3)       # e.g. "27-silver-fast-redesign"
  phase_num=$(printf '%s' "$phase_dir" | grep -oE '^[0-9]+' || true)  # e.g. "27"

  [[ -z "$phase_num" ]] && continue

  # Check if ROADMAP.md has an unticked entry for this phase number
  # Pattern: - [ ] **Phase 27: (ERE, no unnecessary backslash escapes)
  if grep -qE "^- \[ \] \*\*Phase ${phase_num}:" "$roadmap_file" 2>/dev/null; then
    # Checkbox is unticked — flag it
    phase_title=$(grep -E "^- \[ \] \*\*Phase ${phase_num}:" "$roadmap_file" | head -1 | sed 's/^- \[ \] //')
    unticked_phases="${unticked_phases}  [UNTICKED] Phase ${phase_num}: ${phase_title}\n"
  fi
  # If already [x] or not found in ROADMAP — silent pass

done <<< "$staged_summaries"

if [[ -n "$unticked_phases" ]]; then
  msg=$(printf 'ROADMAP FRESHNESS VIOLATION\n\nA phase SUMMARY.md is staged but the ROADMAP.md checkbox is not ticked.\nTick the checkbox before committing:\n\n%s\nFix by updating .planning/ROADMAP.md:\n  Change:  - [ ] **Phase N: ...\n  To:      - [x] **Phase N: ... (completed YYYY-MM-DD)\n\nThen: git add .planning/ROADMAP.md' "$unticked_phases")
  emit_block "$msg"
  exit 0
fi

printf '{"hookSpecificOutput":{"message":"ROADMAP freshness verified — phase checkbox(es) ticked."}}'
exit 0
