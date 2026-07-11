#!/usr/bin/env bash
# Validate a GitHub Release body meets SB release-quality requirements (#217).
#
# Usage:
#   scripts/validate-github-release-notes.sh --file /path/to/notes.md
#   scripts/validate-github-release-notes.sh --tag v0.39.1 [--repo owner/name]

set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  validate-github-release-notes.sh --file PATH
  validate-github-release-notes.sh --tag TAG [--repo OWNER/REPO]
USAGE
}

body_file=""
tag=""
repo=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      body_file="${2:-}"
      shift 2
      ;;
    --tag)
      tag="${2:-}"
      shift 2
      ;;
    --repo)
      repo="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$tag" && -z "$body_file" ]]; then
  if [[ -z "$repo" ]]; then
    origin="$(git remote get-url origin 2>/dev/null || true)"
    case "$origin" in
      *github.com*/*)
        repo="$(printf '%s' "$origin" | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?$#\1#')"
        ;;
    esac
  fi
  if [[ -z "$repo" ]]; then
    echo "ERROR: could not determine GitHub repo; pass --repo owner/name" >&2
    exit 1
  fi
  body_file="$(mktemp "${TMPDIR:-/tmp}/sb-release-notes.XXXXXX")"
  gh release view "$tag" --repo "$repo" --json body --jq '.body // ""' >"$body_file"
  trap 'rm -f -- "$body_file"' EXIT
fi

if [[ -z "$body_file" || ! -f "$body_file" ]]; then
  echo "ERROR: release notes body file is required" >&2
  usage >&2
  exit 1
fi

python3 - "$body_file" <<'PY'
import re
import sys
from pathlib import Path

body = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").strip()
lower = body.lower()

generic_patterns = (
    r"see changelog\.md for details\.?",
    r"see the changelog\.?",
    r"see changelog for details\.?",
    r"details in changelog\.md\.?",
)

for pattern in generic_patterns:
    if re.search(pattern, lower):
        print(f"ERROR: generic release body rejected (matched /{pattern}/)", file=sys.stderr)
        sys.exit(1)

if len(body) < 40:
    print("ERROR: release body is empty or too short", file=sys.stderr)
    sys.exit(1)

section_re = re.compile(
    r"(?m)^#{1,3}\s+(Breaking Changes|Features|Bug Fixes|Security|Documentation|Tests|Refactoring|Chores|Other|Release And Packaging)\s*$"
)
sections = section_re.findall(body)
if not sections:
    print(
        "ERROR: release body must include at least one categorized section "
        "(Features, Bug Fixes, Documentation, Tests, Security, Other, etc.)",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"OK: release notes valid ({len(sections)} categorized section(s))")
PY
