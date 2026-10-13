#!/usr/bin/env bash
# Extract current GSD phase goal from .planning/ files.
# Outputs goal text to stdout, or empty string if no phase is active.
set -euo pipefail
trap 'exit 0' ERR

planning_dir=".planning"
[[ -d "$planning_dir" ]] || exit 0

# Find phase files sorted by mtime descending — newest modified file wins
phase_file=""
while IFS= read -r f; do
  phase_file="$f"
  break
done < <(ls -t "$planning_dir"/*-CONTEXT.md "$planning_dir"/*-RESEARCH.md "$planning_dir"/*-PLAN.md 2>/dev/null || true)

[[ -z "${phase_file:-}" ]] && exit 0

# Extract first heading (strip #) or first non-empty line
goal=$(grep -m1 '^#' "$phase_file" 2>/dev/null | sed 's/^#* *//;s/[[:space:]]*$//' || true)
if [[ -z "$goal" ]]; then
  goal=$(grep -m1 -v '^[[:space:]]*$' "$phase_file" 2>/dev/null | sed 's/[[:space:]]*$//' || true)
fi

printf '%s' "$goal"
