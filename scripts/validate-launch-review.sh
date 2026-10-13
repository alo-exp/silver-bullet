#!/usr/bin/env bash
# Validate LAUNCH-REVIEW.md frontmatter for adversarial release gate exit criteria.
#
# Usage:
#   scripts/validate-launch-review.sh [--file PATH]
#
# Exit 0 when status=clean, discovery_clean_streak>=2, manifest complete, git_clean=true.
# Exit 1 with stderr message otherwise.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
review_file="${repo_root}/.planning/phases/launch-readiness-adversarial-review/LAUNCH-REVIEW.md"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      review_file="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,8p' "$0"
      exit 0
      ;;
    *)
      printf 'validate-launch-review: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$review_file" ]]; then
  printf 'validate-launch-review: missing %s\n' "$review_file" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  printf 'validate-launch-review: python3 required\n' >&2
  exit 1
fi

python3 - "$review_file" <<'PY'
import re
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
m = re.match(r"^---\s*\n(.*?)\n---", text, re.S)
if not m:
    print(f"validate-launch-review: no YAML frontmatter in {path}", file=sys.stderr)
    sys.exit(1)

def parse_scalar(raw: str):
    raw = raw.strip()
    if not raw:
        return ""
    if raw[0] in "\"'":
        q = raw[0]
        if raw.endswith(q) and len(raw) >= 2:
            return raw[1:-1]
    if raw.lower() in ("true", "false"):
        return raw.lower() == "true"
    if re.fullmatch(r"-?\d+", raw):
        return int(raw)
    return raw

fields = {}
for line in m.group(1).splitlines():
    if not line.strip() or line.lstrip().startswith("#"):
        continue
    if line.startswith("  ") or line.startswith("\t"):
        continue
    if ":" not in line:
        continue
    key, val = line.split(":", 1)
    fields[key.strip()] = parse_scalar(val)

errors = []
status = str(fields.get("status", "")).strip().lower()
if status != "clean":
    errors.append(f"status must be 'clean' (got {status!r})")

streak = fields.get("discovery_clean_streak", fields.get("consecutive_clean_discovery_rounds", 0))
try:
    streak = int(streak)
except (TypeError, ValueError):
    streak = 0
if streak < 2:
    errors.append(f"discovery_clean_streak must be >= 2 (got {streak})")

manifest = str(fields.get("manifest_completion", ""))
if not re.fullmatch(r"\d+/\d+", manifest):
    errors.append(f"manifest_completion must look like N/N (got {manifest!r})")
else:
    done, total = manifest.split("/", 1)
    if int(done) < int(total):
        errors.append(f"manifest_completion incomplete ({manifest})")

git_clean = fields.get("git_clean", False)
if git_clean is not True:
    errors.append(f"git_clean must be true (got {git_clean!r})")

if errors:
    print(f"validate-launch-review: {path} failed:", file=sys.stderr)
    for e in errors:
        print(f"  - {e}", file=sys.stderr)
    sys.exit(1)

print(f"validate-launch-review: OK — {path} (status=clean, streak={streak}, manifest={manifest})")
PY
