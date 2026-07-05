#!/usr/bin/env bash
# Bundle enterprise audit evidence into a SOC2-style export zip.
#
# Collects:
#   - docs/apo-catalog.json evidence_records (+ intent_ledgers, composition_logs excerpts)
#   - .planning/orchestrator-composition-log.jsonl (when present)
#   - docs/sessions/* intent ledger sections (when present)
#   - .planning/enterprise-e2e/CERTIFICATION-STATUS.json (regenerated)
#   - manifest.json with SHA256 checksums
#
# Usage:
#   bash scripts/export-enterprise-evidence.sh [project_root] [output_zip]
#
# Default output: ./dist/enterprise-evidence-<timestamp>.zip
set -euo pipefail

PROJECT_ROOT="$(cd "${1:-.}" && pwd)"
SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
OUT_ZIP="${2:-${PROJECT_ROOT}/dist/enterprise-evidence-${TIMESTAMP}.zip}"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/sb-evidence-export.XXXXXX")"

cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

command -v jq >/dev/null 2>&1 || { echo "FAIL: jq required" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo "FAIL: zip required" >&2; exit 1; }

mkdir -p "$STAGING/evidence" "$(dirname "$OUT_ZIP")"

CATALOG="${SB_ROOT}/docs/apo-catalog.json"
if [[ -f "$CATALOG" ]]; then
  jq '{evidence_records, intent_ledgers, composition_logs, v_loop_rollups}' "$CATALOG" \
    >"$STAGING/evidence/apo-audit-entities.json"
fi

CERT_SCRIPT="${SB_ROOT}/scripts/enterprise-e2e-certification-status.sh"
if [[ -x "$CERT_SCRIPT" ]]; then
  RTK_DISABLED=1 bash "$CERT_SCRIPT" --write --json >"$STAGING/evidence/CERTIFICATION-STATUS.json" 2>/dev/null \
    || cp -f "${SB_ROOT}/.planning/enterprise-e2e/CERTIFICATION-STATUS.json" \
      "$STAGING/evidence/CERTIFICATION-STATUS.json" 2>/dev/null || true
fi

COMP_LOG="${PROJECT_ROOT}/.planning/orchestrator-composition-log.jsonl"
if [[ -f "$COMP_LOG" && ! -L "$COMP_LOG" ]]; then
  cp -f "$COMP_LOG" "$STAGING/evidence/orchestrator-composition-log.jsonl"
fi

SESSIONS_DIR="${PROJECT_ROOT}/docs/sessions"
if [[ -d "$SESSIONS_DIR" && ! -L "$SESSIONS_DIR" ]]; then
  mkdir -p "$STAGING/evidence/session-logs"
  shopt -s nullglob
  for log in "$SESSIONS_DIR"/*.md; do
    [[ -f "$log" && ! -L "$log" ]] || continue
    base="$(basename "$log")"
    awk '
      /^## Active Intent Ledger$/ { show=1 }
      show { print }
      /^## / && !/^## Active Intent Ledger$/ { if (show && NR>1) exit }
    ' "$log" >"$STAGING/evidence/session-logs/${base%.md}-intent-ledger.md" 2>/dev/null || true
  done
  shopt -u nullglob
fi

if [[ -f "${PROJECT_ROOT}/.silver-bullet.json" ]]; then
  jq '{enterprise_policy, hooks: {evidence_schema: .hooks.evidence_schema}, orchestrator_mode}' \
    "${PROJECT_ROOT}/.silver-bullet.json" >"$STAGING/evidence/project-policy-snapshot.json" 2>/dev/null || true
fi

# Manifest + checksums
(
  cd "$STAGING"
  find evidence -type f | sort | while read -r rel; do
  if command -v shasum >/dev/null 2>&1; then
    sum="$(shasum -a 256 "$rel" | awk '{print $1}')"
  else
    sum="$(sha256sum "$rel" | awk '{print $1}')"
  fi
    printf '%s\t%s\n' "$sum" "$rel"
  done
) >"$STAGING/checksums.sha256"

jq -n \
  --arg generated_at "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  --arg project_root "$PROJECT_ROOT" \
  --arg sb_git_sha "$(git -C "$SB_ROOT" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)" \
  --arg generator "scripts/export-enterprise-evidence.sh" \
  '{
    schema_version: 1,
    generated_at: $generated_at,
    project_root: $project_root,
    sb_git_sha: $sb_git_sha,
    generator: $generator,
    bundle_purpose: "SOC2-style audit scaffold — evidence_records, composition log, intent ledger excerpts",
    files: ["evidence/", "checksums.sha256"]
  }' >"$STAGING/manifest.json"

(
  cd "$STAGING"
  zip -qr "$OUT_ZIP" manifest.json checksums.sha256 evidence
)

echo "OK: enterprise evidence export → $OUT_ZIP"
echo "    files: $(zipinfo -t "$OUT_ZIP" 2>/dev/null | tail -1 || echo "(zip created)")"
