#!/usr/bin/env bash
set -euo pipefail
trap 'exit 0' ERR

# PreToolUse hook (matcher: Edit|Write|MultiEdit|NotebookEdit|apply_patch|Bash|exec_command)
# Blocks direct edits to GSD-managed planning artifacts (.planning/ROADMAP.md etc.)
# that must only be modified through the appropriate GSD skill.
#
# Protected files (GSD-managed — updated by GSD CLI tools, not by direct
# Write/Edit): top-level project state plus nested phase lifecycle artifacts
# such as .planning/phases/**/PLAN.md, SUMMARY.md, REVIEW.md, SECURITY.md,
# and VERIFICATION.md. SB may own separate spec/quality artifacts, but it does
# not directly mutate GSD lifecycle artifacts.
#
# Every path a call writes is judged: the file tools' paths (every apply_patch path, Move to
# targets), and the write targets of shell commands (redirects, sed -i, cp, mv, tee, rm...,
# resolved by the shell analysis). Paths compare in canonical form (symlinks, '..', Windows
# spellings) and case-insensitively.
#
# Bypass (user-owned): set SB_ALLOW_PLANNING_EDITS=1 before starting Claude Code, or have the
# USER create <host runtime>/.silver-bullet/planning-edit-override (PLAN files) from a
# terminal. The roadmap-edit-override sentinel (ROADMAP.md/STATE.md) is honoured only while
# the owning skill (sb:phase or sb:undo) is recorded in this session's state, and the dev-cycle
# gate refuses an agent writing any other sentinel or the audit logs. Overrides are audited.

# Security: restrict file creation permissions (user-only)
umask 0077

# Source runtime path selector so the override/trivial files follow the host.
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd 2>/dev/null)" || _lib_dir=""
if [[ -f "$_lib_dir/runtime-paths.sh" ]]; then
  # shellcheck source=lib/runtime-paths.sh
  source "$_lib_dir/runtime-paths.sh"
fi
if [[ -f "$_lib_dir/hook-audit.sh" ]]; then
  # shellcheck source=lib/hook-audit.sh
  source "$_lib_dir/hook-audit.sh"
fi
if [[ -f "$_lib_dir/tool-input.sh" ]]; then
  # shellcheck source=lib/tool-input.sh
  source "$_lib_dir/tool-input.sh"
fi
# shellcheck source=lib/planning-floor.sh
source "$_lib_dir/planning-floor.sh"
if [[ -f "$_lib_dir/cert-bypass.sh" ]]; then
  # shellcheck source=lib/cert-bypass.sh
  source "$_lib_dir/cert-bypass.sh"
fi

if [[ -f "$_lib_dir/jq-gate.sh" ]]; then
  # shellcheck source=lib/jq-gate.sh
  source "$_lib_dir/jq-gate.sh"
fi
if [[ -f "$_lib_dir/sb-project-gate.sh" ]]; then
  # shellcheck source=lib/sb-project-gate.sh
  source "$_lib_dir/sb-project-gate.sh"
fi

emit_block_jq_missing() {
  local reason="$1"
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$reason" <<'PY'
import json, sys
msg = sys.argv[1]
print(json.dumps({
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": msg,
  }
}))
PY
    return 0
  fi
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"jq required for Silver Bullet enforcement"}}'
}

if declare -f sb_jq_enforcement_block_sb_initiated >/dev/null 2>&1; then
  sb_jq_enforcement_block_sb_initiated "planning-file-guard" "emit_block_jq_missing"
elif ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

input=$(cat)
if declare -f sb_hook_exit_on_cert_run >/dev/null 2>&1; then
  sb_hook_exit_on_cert_run
elif declare -f sb_cert_run_bypass_active >/dev/null 2>&1 && sb_cert_run_bypass_active; then
  exit 0
fi

deny() {
  sb_hook_audit_record "planning-file-guard" "PreToolUse" "deny" "$1" "${2:-}"
  sb_emit_hook_decision PreToolUse deny "$1"
  exit 0
}

# ── Exit early if project is not using Silver Bullet ─────────────────────────
config_file="$(sb_find_project_config_walk_only 2>/dev/null || true)"
[[ -n "$config_file" ]] || exit 0
if declare -f sb_project_active >/dev/null 2>&1; then
  sb_project_active "$config_file" || exit 0
fi
project_root="$(sb_pf_canon "$(dirname "$config_file")")"

sb_tool_input_load "$input" "$PWD"
if ! sb_tool_input_ok; then
  [[ "${SB_TI_STATUS:-}" == "empty" ]] && exit 0
  # The call cannot be analysed: refuse only what names the planning directory.
  [[ "$(printf '%s' "$input" | tr '[:upper:]' '[:lower:]')" == *.planning* ]] || exit 0
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // .tool_input.cmd // ""' 2>/dev/null || true)"
  sb_pf_plain_read_only "$cmd" && exit 0
  deny "$(sb_pf_unanalysable_message)"
fi

# Is this canonical path one of the SB-managed planning artifacts? Sets planning_rel.
is_protected() {
  local target="$1" rel
  case "$target" in
    "$project_root"/.planning/*) rel="${target#"$project_root"/.planning/}" ;;
    *) return 1 ;;
  esac
  planning_rel="$rel"
  local ret=1
  shopt -s nocasematch
  case "$rel" in
    ROADMAP.md | STATE.md | PROJECT.md | RELEASE.md | REQUIREMENTS.md | UAT.md) ret=0 ;;
    v*-MILESTONE-*.md | milestones/*.md) ret=0 ;;
    phases/*/*-PLAN.md | phases/*/*-SUMMARY.md | phases/*/*-REVIEW.md | phases/*/*-SECURITY.md | phases/*/*-VERIFICATION.md) ret=0 ;;
    # SB-native phase layout (phases/<phase>/PLAN.md etc.) is owned by SB skills
    # (silver-plan, silver-review, silver-verify, silver-secure) and written through the
    # agent's file tools by design: not protected here (completion-audit checks the evidence).
  esac
  shopt -u nocasematch
  return "$ret"
}

notices=""
note() {
  if [[ -n "$notices" ]]; then notices="$notices"$'\n'"$1"; else notices="$1"; fi
}

_override="${SB_RUNTIME_STATE_DIR}/planning-edit-override"
_roadmap_override="${SB_RUNTIME_STATE_DIR}/roadmap-edit-override"
_trivial_file="${SB_RUNTIME_STATE_DIR}/trivial"

while IFS=$'\t' read -r via target; do
  [[ -n "$target" ]] || continue
  planning_rel=""
  is_protected "$target" || continue
  basename_path="$(basename "$target")"

  # ── Bypass: env var override ────────────────────────────────────────────────
  if [[ "${SB_ALLOW_PLANNING_EDITS:-}" == "1" ]]; then
    note "⚠️  planning-file-guard: SB_ALLOW_PLANNING_EDITS=1 — allowing direct edit to ${basename_path}. Prefer the owning SB skill."
    continue
  fi

  # ── Bypass: user-created PLAN override (M-03: PLAN files only) ──────────────
  if [[ -f "$_override" && ! -L "$_override" ]]; then
    case "$basename_path" in
      *-PLAN.md | PLAN.md)
        printf '%s override-used path=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$basename_path" >>"${SB_RUNTIME_STATE_DIR}/planning-edit-override-audit.log" 2>/dev/null || true
        note "⚠️  planning-file-guard: PLAN override active — allowing direct edit to ${basename_path}. Remove ${_override} when done."
        continue
        ;;
    esac
  fi

  # ── Bypass: roadmap phase CRUD (sb:phase / sb:undo own it) ──────────────────
  if [[ -f "$_roadmap_override" && ! -L "$_roadmap_override" ]] && sb_pf_state_has_skill silver-phase silver-undo; then
    case "$basename_path" in
      ROADMAP.md | STATE.md)
        printf '%s override-used path=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "$basename_path" >>"${SB_RUNTIME_STATE_DIR}/roadmap-edit-override-audit.log" 2>/dev/null || true
        note "⚠️  planning-file-guard: roadmap-edit-override active — allowing ${basename_path} edit via owning SB skill. Remove ${_roadmap_override} when done."
        continue
        ;;
    esac
  fi

  # ── Trivial bypass (user-created marker; the configured path is never honoured) ──
  if [[ -f "$_trivial_file" && ! -L "$_trivial_file" ]]; then
    continue
  fi

  # ── Block direct edit ───────────────────────────────────────────────────────
  skill_hint=""
  case "$basename_path" in
    ROADMAP.md)
      skill_hint="Use /sb:phase for phase CRUD, /sb:plan, /sb:add, /sb:release, or the owning roadmap workflow instead."
      ;;
    STATE.md)
      skill_hint="Use /sb:execute, /sb:release, or the owning resume/pause workflow instead."
      ;;
    PROJECT.md)
      skill_hint="Use /sb:init instead."
      ;;
    RELEASE.md)
      skill_hint="Use /sb:release or /sb:create-release instead."
      ;;
    REQUIREMENTS.md)
      skill_hint="Use /sb:spec, /sb:ingest, /sb:init, or /sb:plan instead. SB requirements should be updated through SB-owned spec and planning workflows."
      ;;
    UAT.md)
      skill_hint="Use /sb:verify or /sb:validate instead."
      ;;
    v*-MILESTONE-*.md)
      skill_hint="Use /sb:release instead."
      ;;
    *-PLAN.md | PLAN.md)
      skill_hint="Use /sb:plan instead."
      ;;
    *-SUMMARY.md | SUMMARY.md)
      skill_hint="Use /sb:execute, /sb:release, or the relevant SB phase completion workflow instead."
      ;;
    *-REVIEW.md | REVIEW.md)
      skill_hint="Use /sb:review instead."
      ;;
    *-SECURITY.md | SECURITY.md)
      skill_hint="Use /sb:secure instead."
      ;;
    *-VERIFICATION.md | VERIFICATION.md)
      skill_hint="Use /sb:verify or /sb:validate instead."
      ;;
  esac

  deny "🚫 PLANNING FILE GUARD — Direct edits to .planning/${planning_rel} are not permitted (${via}).

SB-managed planning artifacts must be modified only through their owning skills.
${skill_hint}

A one-off doc fix is the user's decision: only the user can allow it, from their own terminal
(\`touch ${SB_RUNTIME_STATE_DIR}/planning-edit-override\`, removed when done)." "$target"
done < <(sb_pf_write_records "$input")

if [[ -n "$notices" ]]; then
  sb_emit_hook_message PreToolUse "$notices"
fi
exit 0
