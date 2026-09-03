# shellcheck shell=bash
# Silver Bullet — evidence schema gate helpers (delivery gate, warn-first).
#
# Validates finding tables in quality artifacts per docs/evidence-schema.md.
# First pass: WARN on malformed tables (does not block delivery).
# Set SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1 to treat warnings as blockers.

_sb_evidence_gate__script_path() {
  local repo_root="$1"
  local candidate=""
  for candidate in \
    "$repo_root/scripts/validate-evidence-findings.sh" \
    "$repo_root/plugins/silver-bullet/scripts/validate-evidence-findings.sh"; do
    if [[ -f "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  return 1
}

# Args:
#   $1 mode ("task" or "delivery") — only delivery is enforced today
#   $2 repo_root
#   $3 emit_warn_fn — called with one string (informational, non-blocking)
#   $4 emit_block_fn — called with one string when strict mode blocks
sb_evidence_schema_gate_enforce() {
  local mode="$1"
  local repo_root="$2"
  local emit_warn_fn="$3"
  local emit_block_fn="$4"
  local strict="${SILVER_BULLET_EVIDENCE_SCHEMA_STRICT:-0}"
  local validator=""
  local json_out=""
  local warn_count=0
  local err_count=0
  local message=""

  [[ "$mode" == "delivery" ]] || return 0

  if ! validator="$(_sb_evidence_gate__script_path "$repo_root")"; then
  # No validator in tree — fail-open.
    return 0
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    "$emit_warn_fn" "⚠️  EVIDENCE SCHEMA — python3 unavailable; skipped finding-table validation."
    return 0
  fi

  if [[ "$strict" == "1" ]]; then
    json_out="$(bash "$validator" "$repo_root" --strict --json 2>/dev/null || true)"
  else
    json_out="$(bash "$validator" "$repo_root" --json 2>/dev/null || true)"
  fi

  if [[ -z "$json_out" ]] || ! jq -e '.artifacts_scanned' >/dev/null <<<"$json_out" 2>/dev/null; then
    "$emit_warn_fn" "⚠️  EVIDENCE SCHEMA — validator failed to run; skipped finding-table check."
    return 0
  fi

  warn_count=$(jq -r '.warnings | length' <<<"$json_out" 2>/dev/null || echo 0)
  err_count=$(jq -r '.errors | length' <<<"$json_out" 2>/dev/null || echo 0)

  if [[ "$err_count" -eq 0 && "$warn_count" -eq 0 ]]; then
    return 0
  fi

  message=$(jq -r '
    "⚠️  EVIDENCE SCHEMA — finding tables deviate from docs/evidence-schema.md (" +
    (.warnings | length | tostring) + " warning(s), " +
    (.errors | length | tostring) + " error(s)).\n\n" +
    (
      [.warnings[], .errors[]]
      | map("  - " + .path + ": " + .message)
      | join("\n")
    ) +
    "\n\nRun: bash scripts/validate-evidence-findings.sh\n" +
    "Reference: docs/evidence-schema.md\n" +
    "Strict delivery block: set SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1 after warnings are resolved."
  ' <<<"$json_out" 2>/dev/null || true)

  if [[ -z "$message" ]]; then
    return 0
  fi

  if [[ "$strict" == "1" && ( "$err_count" -gt 0 || "$warn_count" -gt 0 ) ]]; then
    message=$(printf '🛑 EVIDENCE SCHEMA GATE — Delivery blocked until finding tables match docs/evidence-schema.md.\n\n%s' "$message")
    "$emit_block_fn" "$message"
    exit 0
  fi

  "$emit_warn_fn" "$message"
  return 0
}
