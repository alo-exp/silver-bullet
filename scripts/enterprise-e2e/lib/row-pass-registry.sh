#!/usr/bin/env bash
# Install-version row pass registry — one live+outcome PASS per matrix row per SB install.
# Fingerprint: <host>@<sb_git_sha12>+<surface_hash12>
# See docs/testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md § Install-version row pass registry.
set -euo pipefail

_enterprise_e2e_row_pass_registry_root() {
  if [[ -n "${SB_ROOT:-}" ]]; then
    printf '%s\n' "$SB_ROOT"
  else
    cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd
  fi
}

enterprise_e2e_row_pass_registry_path() {
  local root
  root="$(_enterprise_e2e_row_pass_registry_root)"
  printf '%s\n' "${SB_E2E_ROW_PASS_REGISTRY:-${root}/.planning/enterprise-e2e/.row-pass-registry.json}"
}

enterprise_e2e_row_pass_registry_file() {
  enterprise_e2e_row_pass_registry_path
}

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

# Fingerprint: <host>@<sb_git_sha12>+<surface_hash12>
# Override for tests: SB_E2E_INSTALL_FP=claude@testsha+testsurface
enterprise_e2e_install_fingerprint() {
  if [[ -n "${SB_E2E_INSTALL_FP:-}" ]]; then
    printf '%s\n' "$SB_E2E_INSTALL_FP"
    return 0
  fi
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

enterprise_e2e_row_pass_registry_init() {
  local path
  path="$(enterprise_e2e_row_pass_registry_path)"
  local dir
  dir="$(dirname "$path")"
  mkdir -p "$dir"
  if [[ ! -f "$path" ]]; then
    python3 - "$path" <<'PY'
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

# Migrate legacy by_install[host:version] rows into installs[canonical install_fp].
# Idempotent — skips rows already present on target install_fp.
enterprise_e2e_row_pass_registry_migrate_legacy() {
  local target_fp="${1:-$(enterprise_e2e_install_fingerprint)}"
  local path
  path="$(enterprise_e2e_row_pass_registry_path)"
  enterprise_e2e_row_pass_registry_init
  python3 - "$path" "$target_fp" <<'PY'
import json, sys
from pathlib import Path

path, target_fp = sys.argv[1:3]
doc = json.loads(Path(path).read_text(encoding="utf-8"))
installs = doc.setdefault("installs", {})
target = installs.setdefault(target_fp, {
    "host": target_fp.split("@", 1)[0],
    "sb_sha": target_fp.split("@", 1)[1].split("+", 1)[0],
    "install_fp": target_fp,
    "rows": {},
})
target_rows = target.setdefault("rows", {})
migrated = 0

legacy = doc.get("by_install") or {}
for legacy_fp, inst in legacy.items():
    for row, entry in (inst.get("rows") or {}).items():
        if not entry.get("outcome_pass"):
            continue
        row = str(int(row))
        if row in target_rows and target_rows[row].get("outcome_pass"):
            continue
        target_rows[row] = {
            "passed_at": entry.get("passed_at", ""),
            "log_ref": entry.get("log_ref", ""),
            "outcome_pass": True,
            "source": entry.get("source", f"legacy-migrate:{legacy_fp}"),
        }
        migrated += 1

if migrated:
    doc.pop("by_install", None)
    doc.pop("version", None)
    doc.setdefault("schema_version", 1)
    doc.setdefault("fingerprint_scheme", "host@sb_git_sha12+surface_hash12")
    Path(path).write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
print(migrated)
PY
}

enterprise_e2e_row_pass_registry_has_pass() {
  local row_num="$1"
  local install_fp="${2:-$(enterprise_e2e_install_fingerprint)}"
  local path
  path="$(enterprise_e2e_row_pass_registry_path)"
  [[ -f "$path" ]] || return 1
  python3 - "$path" "$install_fp" "$row_num" <<'PY'
import json, sys
path, install_fp, row = sys.argv[1:4]
row = str(int(row))
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
entry = doc.get("installs", {}).get(install_fp, {})
row_entry = entry.get("rows", {}).get(row)
if not row_entry or not row_entry.get("outcome_pass"):
    sys.exit(1)
sys.exit(0)
PY
}

# True when row should skip due to prior pass on same install (allowed skip class).
enterprise_e2e_row_pass_registry_should_skip() {
  local row_num="$1"
  [[ "${SB_E2E_MATRIX_FORCE_ALL:-}" == "1" ]] && return 1
  enterprise_e2e_row_pass_registry_has_pass "$row_num"
}

enterprise_e2e_row_pass_registry_record() {
  local row_num="$1"
  local log_ref="${2:-}"
  local outcome_pass="${3:-true}"
  local source="${4:-matrix}"
  local path fp host sb_sha now
  path="$(enterprise_e2e_row_pass_registry_path)"
  enterprise_e2e_row_pass_registry_init
  fp="$(enterprise_e2e_install_fingerprint)"
  host="${fp%%@*}"
  sb_sha="$(printf '%s' "$fp" | sed -E 's/^[^@]+@([^+]+)\+.*/\1/')"
  now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  python3 - "$path" "$fp" "$host" "$sb_sha" "$row_num" "$now" "$log_ref" "$outcome_pass" "$source" <<'PY'
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

enterprise_e2e_row_pass_registry_pass_count() {
  local install_fp="${1:-$(enterprise_e2e_install_fingerprint)}"
  local path
  path="$(enterprise_e2e_row_pass_registry_path)"
  [[ -f "$path" ]] || { printf '0\n'; return 0; }
  python3 - "$path" "$install_fp" <<'PY'
import json, sys
path, install_fp = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
rows = doc.get("installs", {}).get(install_fp, {}).get("rows", {})
count = sum(1 for r in rows.values() if r.get("outcome_pass"))
print(count)
PY
}

enterprise_e2e_row_pass_registry_list_rows() {
  local install_fp="${1:-$(enterprise_e2e_install_fingerprint)}"
  local path
  path="$(enterprise_e2e_row_pass_registry_path)"
  [[ -f "$path" ]] || return 0
  python3 - "$path" "$install_fp" <<'PY'
import json, sys
path, install_fp = sys.argv[1:3]
with open(path, encoding="utf-8") as f:
    doc = json.load(f)
rows = doc.get("installs", {}).get(install_fp, {}).get("rows", {})
for row in sorted(rows, key=lambda k: int(k)):
    if rows[row].get("outcome_pass"):
        print(row)
PY
}
