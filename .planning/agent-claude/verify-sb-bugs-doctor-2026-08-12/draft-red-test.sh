#!/usr/bin/env bash
# DRAFT ONLY — do not apply / do not merge as-is.
# Proposed RED case for tests/scripts/test-silver-doctor.sh
# Expectation today: FAIL (config loses trailing newline after D11 session-start smoke).
# After fix: PASS.

set -euo pipefail

# --- snippet to integrate into test-silver-doctor.sh ---

test_d11_session_start_preserves_config_trailing_newline() {
  local tmp cfg before after
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-doctor-nl.XXXXXX")"
  cfg="${tmp}/.silver-bullet.json"

  # jq-normalized JSON WITH trailing newline (matches persist serialization)
  jq -n '{
    sb_initiated: true,
    sb_enforcement_tier: 0,
    config_version: "0.0.0"
  }' >"$cfg"
  [[ "$(tail -c1 "$cfg" | xxd -p)" == "0a" ]] || {
    echo "setup: expected trailing newline" >&2
    return 1
  }

  # Minimal project surface for doctor D5/D11
  printf '# silver-bullet\n' >"${tmp}/silver-bullet.md"
  before="$(shasum -a 256 "$cfg" | awk '{print $1}')"

  # Doctor dry-run still runs D11 hook smoke under PROJ_ROOT
  bash "${REPO_ROOT}/scripts/sb-doctor.sh" --dry-run "$tmp" >/dev/null 2>&1 || true

  after="$(shasum -a 256 "$cfg" | awk '{print $1}')"
  if [[ "$before" != "$after" ]]; then
    echo "FAIL: D11 session-start smoke dirtied .silver-bullet.json" >&2
    echo "  before=$before" >&2
    echo "  after=$after" >&2
    echo "  ends_with_nl_after=$(tail -c1 "$cfg" | xxd -p)" >&2
    # Prove sole delta is EOF newline when possible
    python3 - "$cfg" <<'PY' >&2 || true
import sys
from pathlib import Path
a = Path(sys.argv[1]).read_bytes()
print("  after_len", len(a), "endswith_nl", a.endswith(b"\n"))
PY
    rm -rf "$tmp"
    return 1
  fi

  [[ "$(tail -c1 "$cfg" | xxd -p)" == "0a" ]] || {
    echo "FAIL: trailing newline missing after doctor D11" >&2
    rm -rf "$tmp"
    return 1
  }

  echo "PASS: D11 session-start preserves .silver-bullet.json trailing newline"
  rm -rf "$tmp"
  return 0
}

# Companion unit (could live in tests/hooks/test-enforcement-tier.sh):
test_sb_enforcement_tier_persist_preserves_trailing_newline() {
  local tmp cfg
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/sb-persist-nl.XXXXXX")"
  cfg="${tmp}/.silver-bullet.json"
  cat >"$cfg" <<'EOF'
{
  "sb_enforcement_tier": 0
}
EOF
  # shellcheck source=../../hooks/lib/enforcement-tier-gate.sh
  source "${REPO_ROOT}/hooks/lib/enforcement-tier-gate.sh"
  sb_enforcement_tier_persist "$cfg" "0"
  if ! tail -c1 "$cfg" | grep -q .; then
    : # empty read means no byte — fail
  fi
  [[ "$(tail -c1 "$cfg" | xxd -p)" == "0a" ]] || {
    echo "FAIL: sb_enforcement_tier_persist stripped trailing newline" >&2
    xxd -l 16 -s -16 "$cfg" >&2 || true
    rm -rf "$tmp"
    return 1
  }
  echo "PASS: sb_enforcement_tier_persist preserves trailing newline"
  rm -rf "$tmp"
}
