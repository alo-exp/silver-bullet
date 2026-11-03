#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Bash|exec_command)
# Detects git commit commands that include a phase SUMMARY.md.
# Blocks the commit if the corresponding ROADMAP.md checkbox is not ticked [x].
#
# WHY: During autonomous execution, phase completion commits are created with
# SUMMARY.md artifacts but the ROADMAP.md checkbox is never updated, causing
# milestone state to diverge from execution reality.
#
# TRIGGER: any commit the shell analysis finds (git -C/-c forms, chains, aliases, `commit -a`,
#          `commit <pathspec>`, `git add <path> && git commit`) that would record a
#          .planning/phases/N-*/N-*-SUMMARY.md
# ACTION:  Block and report which phase checkbox is unticked

# Security: restrict file creation permissions (user-only)
umask 0077

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
  sb_project_active_or_exit
fi

# jq is required — warn visibly if missing
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if declare -f sb_jq_enforcement_warn >/dev/null 2>&1; then
  sb_jq_enforcement_warn "roadmap-freshness"
fi
# shellcheck source=lib/planning-floor.sh
source "$_lib_dir/planning-floor.sh"

# Read JSON from stdin
input=$(cat)

tool_name="$(printf '%s' "$input" | jq -r '.tool_name // ""')"
sb_tool_is_shell_like "$tool_name" || exit 0

# One analysis of the command: whether it commits, and which paths it brings into the commit.
sb_tool_input_load "$input" "$PWD"
# (A command that cannot be analysed is judged by completion-audit's commit gate.)
sb_tool_input_ok || exit 0
sb_shell_analysis_has_action commit || exit 0

# Locate the project root: the nearest ancestor with .silver-bullet.json + silver-bullet.md
config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
# Not a Silver Bullet project — silent exit
[[ -n "$config_file" ]] || exit 0
project_root="$(dirname "$config_file")"

# Paths the commit would record: the index, plus what the same command stages or commits.
changed_files="$(git -C "$project_root" diff --cached --name-only 2>/dev/null || true)"
extra_paths=()
add_all=false
commit_all=false
if printf '%s' "${SB_SA_JSON:-}" | jq -e '[.commits[]? | .all] | any' >/dev/null 2>&1; then commit_all=true; fi
if printf '%s' "${SB_SA_JSON:-}" | jq -e '
     [.commands[]? | select((.argv[0] | split("/") | last) == "git") | .argv
      | select(index("add") != null and (map(select(. == "-A" or . == "--all" or . == "-u" or . == "--update" or . == ".")) | length > 0))]
     | length > 0' >/dev/null 2>&1; then add_all=true; fi
while IFS= read -r p; do
  [[ -n "$p" ]] && extra_paths+=("$p")
done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r '[.commits[]? | (.staged_paths + .pathspecs)[]] | unique | .[]' 2>/dev/null || true)

# `git status --porcelain` lines "XY path" (or "R  old -> new") -> paths
status_paths() {
  git -C "$PWD" status --porcelain -uall "$@" 2>/dev/null | sed -e 's/^...//' -e 's/^.* -> //' || true
}
if [[ "$commit_all" == true ]]; then
  changed_files="$changed_files"$'\n'"$(git -C "$project_root" diff --name-only HEAD 2>/dev/null || true)"
fi
if [[ "$add_all" == true ]]; then
  changed_files="$changed_files"$'\n'"$(status_paths)"
fi
if [[ ${#extra_paths[@]} -gt 0 ]]; then
  changed_files="$changed_files"$'\n'"$(status_paths -- "${extra_paths[@]}")"
fi

# Filter for phase SUMMARY.md files: .planning/phases/N-*/N-*-SUMMARY.md (N may be a decimal
# phase such as 7.1). Convention: plan files are {phase}-{step}-SUMMARY.md (e.g. 27-01-SUMMARY.md);
# files with more numeric segments (27-01-02-SUMMARY.md) are skipped by design.
staged_summaries=$(printf '%s\n' "$changed_files" | grep -E '^\.planning/phases/[0-9]+(\.[0-9]+)?-[^/]+/[0-9]+(\.[0-9]+)?-[0-9]+-SUMMARY\.md$' | sort -u || true)
[[ -z "$staged_summaries" ]] && exit 0

# ROADMAP.md must exist to perform the check
roadmap_file="$project_root/.planning/ROADMAP.md"
if [[ ! -f "$roadmap_file" ]]; then
  exit 0
fi

# Check each SUMMARY.md against ROADMAP.md
unticked_phases=""
while IFS= read -r summary_path; do
  # The phase directory name starts with the phase number: .planning/phases/27-demo/27-01-SUMMARY.md
  phase_dir=$(printf '%s' "$summary_path" | cut -d'/' -f3)
  phase_raw=$(printf '%s' "$phase_dir" | grep -oE '^[0-9]+(\.[0-9]+)?' || true)
  [[ -z "$phase_raw" ]] && continue

  # ROADMAP may or may not zero-pad the number: "Phase 7:" matches the directory 07-x.
  phase_int="${phase_raw%%.*}"
  phase_frac=""
  [[ "$phase_raw" == *.* ]] && phase_frac="\\.${phase_raw#*.}"
  phase_num="$((10#$phase_int))${phase_raw#"$phase_int"}"
  pattern="^- \\[ \\] \\*\\*Phase 0*$((10#$phase_int))${phase_frac}:"

  # Is there an unticked entry for this phase number?
  if grep -qE "$pattern" "$roadmap_file" 2>/dev/null; then
    phase_title=$(grep -E "$pattern" "$roadmap_file" | head -1 | sed 's/^- \[ \] //')
    # Strip to safe chars only — prevents control chars or injection content in block message (SEC: content injection guard)
    phase_title=$(printf '%s' "$phase_title" | tr -dc 'a-zA-Z0-9 .:,_-')
    unticked_phases="${unticked_phases}  [UNTICKED] Phase ${phase_num}: ${phase_title}"$'\n'
  fi
  # If already [x] or not found in ROADMAP — silent pass

done <<< "$staged_summaries"

if [[ -n "$unticked_phases" ]]; then
  msg=$(printf 'ROADMAP FRESHNESS VIOLATION\n\nA phase SUMMARY.md is part of this commit but the ROADMAP.md checkbox is not ticked.\n\n%s\nTick it through the owning skill (/sb:phase, the phase-completion workflow of /sb:execute or /sb:release), which sets the checkbox to\n  - [x] **Phase N: ... (completed YYYY-MM-DD)\nThen: git add .planning/ROADMAP.md and commit again. ROADMAP.md is a protected planning file: it cannot be edited directly.' "$unticked_phases")
  sb_emit_hook_decision PreToolUse deny "$msg"
  exit 0
fi

sb_emit_hook_message PreToolUse "ROADMAP freshness verified — phase checkbox(es) ticked."
exit 0
