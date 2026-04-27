#!/usr/bin/env bash
# hooks/lib/workflow-utils.sh — Shared utilities for Flow Log parsing.
#
# Single source of truth for the Flow Log row-counting regex.
# TD-1 fix (v0.22): previously duplicated across completion-audit.sh,
# dev-cycle-check.sh, compliance-status.sh — any regex drift would cause
# divergent behavior.
#
# v0.29.1 fix (S4 digit-row inflation guard): the row-counting helpers are
# now SECTION-SCOPED — they only count rows that appear inside the
# `## Flow Log` heading, terminating at the next `## ` heading. This
# prevents Phase Iterations (`| 01 | ...`) and Autonomous Decisions tables
# from inflating the counts when present in the same workflow file.
#
# Usage: source this file, then call count_flow_log_rows <file>

# _flow_log_section <file>
# Internal: emits ONLY the lines inside the `## Flow Log` section.
# Starts emitting after the `## Flow Log` heading; stops at the next `## `
# heading. If no `## Flow Log` heading is found, emits nothing.
_flow_log_section() {
  local file="$1"
  awk '
    /^##[[:space:]]+Flow Log[[:space:]]*$/ { in_section = 1; next }
    in_section && /^##[[:space:]]/         { in_section = 0 }
    in_section                              { print }
  ' "$file" 2>/dev/null
}

# count_flow_log_rows <file>
# Counts rows in the Flow Log table only (| N | ... | format).
# Strict structural anchor "^| <digits> |" + section scoping excludes
# Phase Iterations / Autonomous Decisions / unrelated tables.
count_flow_log_rows() {
  local file="$1"
  _flow_log_section "$file" | grep -cE '^\| [0-9]+ \|' 2>/dev/null || echo 0
}

# count_complete_flow_rows <file>
# Counts Flow Log rows with status "complete".
count_complete_flow_rows() {
  local file="$1"
  _flow_log_section "$file" | grep -cE '^\| [^|]+\| [^|]+\| complete' 2>/dev/null || echo 0
}
