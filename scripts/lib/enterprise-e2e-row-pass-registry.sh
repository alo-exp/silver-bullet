#!/usr/bin/env bash
# Install-version row pass registry for enterprise E2E matrix.
#
# One live + outcome PASS per matrix row per install fingerprint. Prevents re-FORCE
# of rows that already passed on the same SB install surface.
#
# Fingerprint scheme (documented in ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md):
#   <host>@<sb_git_sha>+<surface_hash>
#   surface_hash = sha256(hooks/hooks.json_digest + package.json version)[:12]
#
# Registry: .planning/enterprise-e2e/.row-pass-registry.json
#
# Environment:
#   SB_E2E_ROW_PASS_REGISTRY  Override registry path
#   SB_E2E_MATRIX_FORCE_ALL=1 Bypass registry skip (full re-run)
set -euo pipefail

_enterprise_e2e_row_pass_registry_root() {
  if [[ -n "${SB_ROOT:-}" ]]; then
    printf '%s\n' "$SB_ROOT"
  else
    cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
  fi
}

enterprise_e2e_row_pass_registry_file() {
  local root
  root="$(_enterprise_e2e_row_pass_registry_root)"
  printf '%s\n' "${SB_E2E_ROW_PASS_REGISTRY:-${root}/.planning/enterprise-e2e/.row-pass-registry.json}"
}

# Surface hash — changes when hooks.json or package version changes (re-install signal).
enterprise_e2e_install_surface_hash() {
  local sb_root="${1:-$(_enterprise_e2e_row_pass_registry_root)}"
  python3 - "$sb_root" <<'PY'
import hashlib, json, sys
from pathlib import Path

root = Path(sys.argv[1])
parts: list[str] = []
hooks = root / "hooks" / "hooks.json"
if hooks.is_file():
    parts.append(hashlib.sha256(hooks.read_bytes()).hexdigest()[:16])
pkg = root / "package.json"
if pkg.is_file():
    try:
        parts.append(json.loads(pkg.read_text(encoding="utf-8")).get("version", "unknown"))
    except Exception:
        parts.append("unknown")
digest = hashlib.sha256("|".join(parts).encode()).hexdigest()
print(digest[:12])
PY
}

# Full install fingerprint for the active host.
enterprise_e2e_install_fingerprint() {
  local host sb_root sb_sha surface
  sb_root="$(_enterprise_e2e_row_pass_registry_root)"
  if declare -f enterprise_e2e_matrix_host >/dev/null 2>&1; then
    host="$(enterprise_e2e_matrix_host)"
  else
    host="${SB_E2E_LIVE_RUNTIME:-${SILVER_BULLET_RUNTIME:-claude}}"
  fi
  sb_sha="$(git -C "$sb_root" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)"
  surface="$(enterprise_e2e_install_surface_hash "$sb_root")"
  printf '%s@%s+%s\n' "$host" "$sb_sha" "$surface"
}

enterprise_e2e_row_pass_registry_ensure() {
  local reg dir
  reg="$(enterprise_e2e_row_pass_registry_file)"
  dir="$(dirname "$reg")"
  mkdir -p "$dir"
  if [[ ! -f "$reg" ]]; then
    python3 - "$reg" <<'PY'
import json, sys
from datetime import datetime, timezone

path = sys.argv[1]
doc = {
    "schema_version": 1,
    "fingerprint_scheme": "host@sb_git_sha12+surface_hash12",
    "surface_hash_inputs": ["hooks/hooks.json sha256[:16]", "package.json version"],
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "installs": {},
}
with open(path, "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)
    f.write("\n")
PY
  fi
}

# True when registry records live+outcome pass for row on current install_fp.
enterprise_e2e_row_pass_registry_has_pass() {
  local row="$1" install_fp reg
  install_fp="${2:-$(enterprise_e2e_install_fingerprint)}"
  reg="$(enterprise_e2e_row_pass_registry_file)"
  [[ -f "$reg" ]] || return 1
  python3 - "$reg" "$install_fp" "$row" <<'PY'
import json, sys
path, install_fp, row = sys.argv[1:4]
row = str(int(row))
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
entry = doc.get("installs", {}).get(install_fp, {})
row_entry = entry.get("rows", {}).get(row)
if not row_entry:
    sys.exit(1)
if not row_entry.get("outcome_pass"):
    sys.exit(1)
sys.exit(0)
PY
}

# True when row should skip due to prior pass on same install (allowed skip class).
enterprise_e2e_row_pass_registry_should_skip() {
  local row="$1"
  [[ "${SB_E2E_MATRIX_FORCE_ALL:-}" == "1" ]] && return 1
  enterprise_e2e_row_pass_registry_has_pass "$row"
}

enterprise_e2e_row_pass_registry_record() {
  local row="$1" log_ref="${2:-}" outcome_pass="${3:-true}" source="${4:-matrix}"
  local install_fp host sb_sha reg passed_at
  install_fp="$(enterprise_e2e_install_fingerprint)"
  host="${install_fp%%@*}"
  sb_sha="$(printf '%s' "$install_fp" | sed -E 's/^[^@]+@([^+]+)\+.*/\1/')"
  reg="$(enterprise_e2e_row_pass_registry_file)"
  enterprise_e2e_row_pass_registry_ensure
  passed_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  python3 - "$reg" "$install_fp" "$host" "$sb_sha" "$row" "$passed_at" "$log_ref" "$outcome_pass" "$source" <<'PY'
import json, sys
from pathlib import Path

path, install_fp, host, sb_sha, row, passed_at, log_ref, outcome_pass, source = sys.argv[1:10]
row = str(int(row))
outcome_pass = outcome_pass.lower() in ("1", "true", "yes")

doc = json.loads(Path(path).read_text(encoding="utf-8"))
installs = doc.setdefault("installs", {})
inst = installs.setdefault(install_fp, {
    "host": host,
    "sb_sha": sb_sha,
    "install_fp": install_fp,
    "rows": {},
})
inst["host"] = host
inst["sb_sha"] = sb_sha
inst["install_fp"] = install_fp
rows = inst.setdefault("rows", {})
rows[row] = {
    "passed_at": passed_at,
    "log_ref": log_ref,
    "outcome_pass": outcome_pass,
    "source": source,
}
Path(path).write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
PY
}

# Count rows with outcome_pass for install_fp (default: current).
enterprise_e2e_row_pass_registry_pass_count() {
  local install_fp="${1:-$(enterprise_e2e_install_fingerprint)}"
  local reg
  reg="$(enterprise_e2e_row_pass_registry_file)"
  [[ -f "$reg" ]] || { printf '0\n'; return 0; }
  python3 - "$reg" "$install_fp" <<'PY'
import json, sys
path, install_fp = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
rows = doc.get("installs", {}).get(install_fp, {}).get("rows", {})
count = sum(1 for r in rows.values() if r.get("outcome_pass"))
print(count)
PY
}

# Exit 0 when all 22 rows passed on current install_fp with outcome_pass.
enterprise_e2e_row_pass_registry_complete() {
  local count
  count="$(enterprise_e2e_row_pass_registry_pass_count)"
  [[ "${count:-0}" -ge 22 ]]
}

# True when the latest "=== Row N:" slice in matrix/pilot log shows pass (not first slice).
enterprise_e2e_pilot_log_row_passed() {
  local n="${1:?row number}"
  local log_file="${2:?log path}"
  local slice
  slice="$(awk -v n="$n" '
    /^=== Row [0-9]+:/ {
      rid = $0
      sub(/^=== Row /, "", rid)
      sub(/:.*$/, "", rid)
      if (rid == n) { buf = ""; collecting = 1 }
      else if (collecting) { collecting = 0 }
      next
    }
    /^=== PILOT row/ {
      if (collecting) { collecting = 0 }
      next
    }
    collecting { buf = buf $0 ORS }
    END { printf "%s", buf }
  ' "$log_file" 2>/dev/null || true)"
  if printf '%s\n' "$slice" | grep -q "  FAIL:"; then
    return 1
  fi
  if printf '%s\n' "$slice" | grep -q "OUTCOMES: all applicable criteria pass"; then
    return 0
  fi
  if printf '%s\n' "$slice" | grep -q "  PASS: evidence at"; then
    return 0
  fi
  return 1
}
