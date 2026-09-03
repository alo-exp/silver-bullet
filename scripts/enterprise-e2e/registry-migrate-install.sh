#!/usr/bin/env bash
# Migrate row-pass registry entries between install fingerprints (same host).
#
# Used when SB harness ff-merges to a new git SHA but surface hash is unchanged,
# or when Gate 3 resumes after smoke closure on a prior install_fp.
#
# Usage:
#   RTK_DISABLED=1 bash scripts/enterprise-e2e/registry-migrate-install.sh \
#     --from claude@ba77d1b0ed19+596e99deab17 \
#     --to claude@609ee0a1812c+596e99deab17 \
#     --rows 1,3,6,11,21,22 \
#     --source-note "gate3-resume-smoke"
#
#   --dry-run   Print planned migrate without writing
set -euo pipefail

SB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export SB_ROOT

FROM_FP=""
TO_FP=""
ROWS=""
SOURCE_NOTE=""
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM_FP="$2"; shift 2 ;;
    --to) TO_FP="$2"; shift 2 ;;
    --rows) ROWS="$2"; shift 2 ;;
    --source-note) SOURCE_NOTE="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '1,20p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$FROM_FP" && -n "$TO_FP" ]] || {
  echo "FAIL: --from and --to required" >&2
  exit 2
}

# shellcheck source=scripts/lib/enterprise-e2e-row-pass-registry.sh
source "${SB_ROOT}/scripts/lib/enterprise-e2e-row-pass-registry.sh"

REG="$(enterprise_e2e_row_pass_registry_file)"
[[ -f "$REG" ]] || { echo "FAIL: registry missing: $REG" >&2; exit 1; }

python3 - "$REG" "$FROM_FP" "$TO_FP" "$ROWS" "$SOURCE_NOTE" "$DRY_RUN" <<'PY'
import json, sys
from pathlib import Path

path, from_fp, to_fp, rows_csv, source_note, dry_run = sys.argv[1:7]
dry = dry_run == "1"
doc = json.loads(Path(path).read_text(encoding="utf-8"))
src = doc.get("installs", {}).get(from_fp)
if not src:
    print(f"FAIL: source install not in registry: {from_fp}", file=sys.stderr)
    sys.exit(1)
src_rows = src.get("rows") or {}
if rows_csv.strip():
    want = {str(int(x.strip())) for x in rows_csv.split(",") if x.strip()}
else:
    want = set(src_rows.keys())
host = src.get("host") or to_fp.split("@", 1)[0]
sb_sha = to_fp.split("@", 1)[1].split("+", 1)[0]
migrated = []
for row in sorted(want, key=int):
    entry = src_rows.get(row)
    if not entry or not entry.get("outcome_pass"):
        print(f"SKIP row {row}: no outcome_pass on {from_fp}")
        continue
    migrated.append(row)
if not migrated:
    print("FAIL: nothing to migrate", file=sys.stderr)
    sys.exit(1)
if dry:
    print(f"DRY-RUN: would migrate rows {','.join(migrated)} {from_fp} -> {to_fp}")
    sys.exit(0)
inst = doc.setdefault("installs", {}).setdefault(to_fp, {
    "host": host,
    "sb_sha": sb_sha,
    "install_fp": to_fp,
    "rows": {},
})
inst["host"] = host
inst["sb_sha"] = sb_sha
inst["install_fp"] = to_fp
note = f"migrated from {from_fp}"
if source_note:
    note = f"{source_note}:{note}"
inst["seed_note"] = note
dest_rows = inst.setdefault("rows", {})
for row in migrated:
    e = dict(src_rows[row])
    e["source"] = f"registry-migrate:{from_fp}"
    dest_rows[row] = e
Path(path).write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
print(f"OK: migrated {len(migrated)} rows -> {to_fp}: {','.join(migrated)}")
PY
