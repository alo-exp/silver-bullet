#!/usr/bin/env bash
# hooks/lib/workflow-utils.sh — Shared utilities for WORKFLOW.md Flow Log parsing
#
# Single source of truth for the Flow Log row-counting regex.
# TD-1 fix: previously duplicated across completion-audit.sh, dev-cycle-check.sh,
# compliance-status.sh — any regex drift would cause divergent behavior.
#
# Usage: source this file, then call count_flow_log_rows <file>

# count_flow_log_rows <file>
# Counts rows in the Flow Log table only (| N | ... | ... | format).
# Excludes Phase Iterations (| 01 ...) and Autonomous Decisions (| 2026-...) rows
# by requiring the strict three-column structural anchor: "^\| [0-9]+ \|"
count_flow_log_rows() {
  local file="$1"
  grep -cE '^\| [0-9]+ \|' "$file" 2>/dev/null || echo 0
}

# count_complete_flow_rows <file>
# Counts Flow Log rows with status "complete".
count_complete_flow_rows() {
  local file="$1"
  grep -cE '^\| [^|]+\| [^|]+\| complete' "$file" 2>/dev/null || echo 0
}
