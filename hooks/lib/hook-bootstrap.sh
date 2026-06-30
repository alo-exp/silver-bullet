#!/usr/bin/env bash
# Shared hook lib sourcing for delivery gate hooks
# Expects _lib_dir to be set by the caller.

# shellcheck source=lib/workflow-utils.sh
[[ -f "$_lib_dir/workflow-utils.sh" ]] && source "$_lib_dir/workflow-utils.sh"
# Fallback definitions if sourcing failed (e.g. in test environments or path resolution issues)
if ! declare -f count_flow_log_rows >/dev/null 2>&1; then
  count_flow_log_rows() { grep -cE '^\| [0-9]+ \|' "$1" 2>/dev/null || echo 0; }
  count_complete_flow_rows() { grep -cE '^\| [^|]+\| [^|]+\| (complete|skipped)' "$1" 2>/dev/null || echo 0; }
fi

# shellcheck source=lib/skill-discovery.sh
if [[ -f "$_lib_dir/skill-discovery.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/skill-discovery.sh"
fi
if ! declare -f sb_skill_is_installed >/dev/null 2>&1; then
  sb_skill_is_installed() { return 0; }
fi

# shellcheck source=lib/github-run-list.sh
if [[ -f "$_lib_dir/github-run-list.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/github-run-list.sh"
fi
if ! declare -f sb_github_run_list_json >/dev/null 2>&1; then
  sb_github_run_list_json() { return 1; }
fi

# shellcheck source=lib/doc-scheme-gate.sh
if [[ -f "$_lib_dir/doc-scheme-gate.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/doc-scheme-gate.sh"
fi

# shellcheck source=lib/evidence-schema-gate.sh
if [[ -f "$_lib_dir/evidence-schema-gate.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/evidence-schema-gate.sh"
fi

# shellcheck source=lib/enforcement-tier-gate.sh
if [[ -f "$_lib_dir/enforcement-tier-gate.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/enforcement-tier-gate.sh"
fi

# shellcheck source=lib/artifact-substance-gate.sh
if [[ -f "$_lib_dir/artifact-substance-gate.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/artifact-substance-gate.sh"
fi

# HOOK-04 (informational half): source the phase-path lib for the
# `_phase_lock_peek_on_exit` EXIT-trap helper. The trap emits a stderr
# WARN if the phase resolved from $PWD has no active lock or is owned
# by a non-claude runtime — non-blocking, preserves original $?.
# shellcheck source=lib/phase-path.sh
if [[ -f "$_lib_dir/phase-path.sh" ]]; then
  # shellcheck disable=SC1091
  source "$_lib_dir/phase-path.sh"
  if declare -f _phase_lock_peek_on_exit >/dev/null 2>&1; then
    trap _phase_lock_peek_on_exit EXIT
  fi
fi

# Pre+PostToolUse hook (matcher: Bash)
# Detects git commit/push/deploy commands and blocks if workflow is incomplete.
#
# TWO-TIER ENFORCEMENT:
#   Intermediate commits (git commit, git push to feature branches):
#     → Only require required_planning skills (default: silver-quality-gates)
#     → Allows GSD execute-phase to make atomic commits during development
#   Final delivery (gh pr create, deploy, gh release create):
#     → Require full required_deploy skill list
#
# This prevents the deadlock where GSD's execution subagents cannot commit
# because final-delivery skills (GSD review, branch finishing, verify-tests, etc.) are not done yet.

# Security: restrict file creation permissions (user-only)
umask 0077

# Source runtime path selector so standalone Codex/Kay hook processes do not
# depend on host-provided SB_RUNTIME_* environment variables.
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/required-skills.sh" ]]; then
  # shellcheck source=lib/required-skills.sh
  # shellcheck disable=SC1091
  source "$_lib_dir/required-skills.sh"
fi
if [[ -f "$_lib_dir/quality-gates-mode.sh" ]]; then
  # shellcheck source=lib/quality-gates-mode.sh
  # shellcheck disable=SC1091
  source "$_lib_dir/quality-gates-mode.sh"
fi
# DEFAULT_* / DEVOPS_DEFAULT_* populated by required-skills.sh (single source of truth).
if [[ -f "$_lib_dir/hook-audit.sh" ]]; then
  # shellcheck source=lib/hook-audit.sh
  source "$_lib_dir/hook-audit.sh"
fi
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi

# jq is required for enforcement — block delivery/intermediate gates when missing
if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi
