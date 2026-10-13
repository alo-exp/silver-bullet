#!/usr/bin/env bash
# enable-alumnium.sh — verify Alumnium npm + MCP wiring.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_lib="${REPO_ROOT}/hooks/lib"
# shellcheck source=/dev/null
[[ -f "$_lib/recommended-tools.sh" ]] && source "$_lib/recommended-tools.sh"
# shellcheck source=/dev/null
[[ -f "$_lib/alumnium-gate.sh" ]] && source "$_lib/alumnium-gate.sh"

pass=0
fail=0

ok()   { echo "  [x] $1"; pass=$((pass + 1)); }
err()  { echo "  [ ] $1 — $2"; fail=$((fail + 1)); }

echo "=== Alumnium verification (repo: ${REPO_ROOT}) ==="
echo ""

if sb_alumnium_npx_available 2>/dev/null; then
  ok "npm package reachable (alumnium@$(npm view alumnium version 2>/dev/null || echo unknown))"
else
  err "alumnium npm package not reachable" "npm install -g alumnium or check network"
fi

host="$(sb_runtime_host 2>/dev/null || echo cursor)"
artifact="$(sb_alumnium_platform_artifact_path "$REPO_ROOT" "$host" 2>/dev/null || true)"
if sb_alumnium_platform_artifact_present "$REPO_ROOT" "$host" 2>/dev/null; then
  ok "MCP wired (${host}: ${artifact})"
else
  err "MCP not wired (${host})" "see docs/ALUMNIUM.md"
fi

echo ""
echo "=== Summary: $pass passed, $fail failed ==="
[[ "$fail" -eq 0 ]] || exit 1
