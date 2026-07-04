#!/usr/bin/env bash
# Validate docs/audits/sentinel-skills/manifest.json for release gate completion.
#
# Usage:
#   scripts/validate-sentinel-skills-manifest.sh [--manifest PATH] [--expected-count N] [--release-tag TAG]
#
# Exit 0 when all rows are status=clean, findings_open=0, and count matches expected (default 85).

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
manifest_file="${repo_root}/docs/audits/sentinel-skills/manifest.json"
expected_count=90
release_tag=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --manifest)
      manifest_file="${2:-}"
      shift 2
      ;;
    --expected-count)
      expected_count="${2:-}"
      shift 2
      ;;
    --release-tag)
      release_tag="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,10p' "$0"
      exit 0
      ;;
    *)
      printf 'validate-sentinel-skills-manifest: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "$manifest_file" ]]; then
  printf 'validate-sentinel-skills-manifest: missing %s\n' "$manifest_file" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  printf 'validate-sentinel-skills-manifest: jq required\n' >&2
  exit 1
fi

if ! jq empty "$manifest_file" >/dev/null 2>&1; then
  printf 'validate-sentinel-skills-manifest: invalid JSON in %s\n' "$manifest_file" >&2
  exit 1
fi

row_count=$(jq 'length' "$manifest_file")
if [[ "$row_count" -ne "$expected_count" ]]; then
  printf 'validate-sentinel-skills-manifest: expected %s rows, found %s\n' "$expected_count" "$row_count" >&2
  exit 1
fi

bad_rows=$(jq -r --arg tag "$release_tag" '
  to_entries[]
  | select(
      (.value.status // "") != "clean"
      or ((.value.findings_open // -1) | tonumber) != 0
      or (($tag | length) > 0 and ((.value.release_tag // "") != $tag))
    )
  | "\(.value.skill // .key): status=\(.value.status // "missing") findings_open=\(.value.findings_open // "missing") release_tag=\(.value.release_tag // "")"
' "$manifest_file")

if [[ -n "$bad_rows" ]]; then
  printf 'validate-sentinel-skills-manifest: incomplete or dirty rows:\n%s\n' "$bad_rows" >&2
  exit 1
fi

printf 'validate-sentinel-skills-manifest: OK — %s/%s clean rows in %s\n' "$row_count" "$expected_count" "$manifest_file"
