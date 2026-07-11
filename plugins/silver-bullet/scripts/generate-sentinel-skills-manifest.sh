#!/usr/bin/env bash
# Scaffold docs/audits/sentinel-skills/manifest.json from skills/*/SKILL.md inventory.
#
# Usage:
#   scripts/generate-sentinel-skills-manifest.sh [--out-dir PATH] [--release-tag TAG]
#
# Preserves existing row status/audit fields when manifest already exists.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
out_dir="${repo_root}/docs/audits/sentinel-skills"
release_tag=""
today="$(date -u +%Y-%m-%d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --out-dir)
      out_dir="${2:-}"
      shift 2
      ;;
    --release-tag)
      release_tag="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,8p' "$0"
      exit 0
      ;;
    *)
      printf 'generate-sentinel-skills-manifest: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
done

if ! command -v jq >/dev/null 2>&1; then
  printf 'generate-sentinel-skills-manifest: jq required\n' >&2
  exit 1
fi

mkdir -p "$out_dir"
manifest_file="${out_dir}/manifest.json"
existing='[]'
if [[ -f "$manifest_file" ]]; then
  existing=$(jq -c '.' "$manifest_file" 2>/dev/null || echo '[]')
fi

skills=()
while IFS= read -r skill_md; do
  skills+=("$(basename "$(dirname "$skill_md")")")
done < <(find "$repo_root/skills" -mindepth 2 -maxdepth 2 -name 'SKILL.md' -print | LC_ALL=C sort)

if [[ ${#skills[@]} -eq 0 ]]; then
  printf 'generate-sentinel-skills-manifest: no skills found under skills/\n' >&2
  exit 1
fi

jq -n \
  --argjson existing "$existing" \
  --arg today "$today" \
  --arg tag "$release_tag" \
  --arg sentinel_version "2.3.0" \
  --argjson skills "$(printf '%s\n' "${skills[@]}" | jq -R . | jq -s .)" \
  '
  ($existing | map({key: .skill, value: .})) as $by_skill
  | [
      $skills[] as $name
      | {
          skill: $name,
          path: ("skills/" + $name + "/SKILL.md"),
          sentinel_version: $sentinel_version,
          audit_report: ("docs/audits/sentinel-skills/SENTINEL-audit-" + $name + ".md"),
          status: (if ($by_skill | map(.key) | index($name)) then ($by_skill[] | select(.key == $name) | .value.status) else "pending" end),
          verdict: (if ($by_skill | map(.key) | index($name)) then ($by_skill[] | select(.key == $name) | .value.verdict // "") else "" end),
          audited_at: (if ($by_skill | map(.key) | index($name)) then ($by_skill[] | select(.key == $name) | .value.audited_at // "") else "" end),
          release_tag: (if ($tag | length) > 0 then $tag elif ($by_skill | map(.key) | index($name)) then ($by_skill[] | select(.key == $name) | .value.release_tag // "") else "" end),
          findings_open: (if ($by_skill | map(.key) | index($name)) then ($by_skill[] | select(.key == $name) | .value.findings_open // 1) else 1 end),
          agent_bundles_parity: (if ($by_skill | map(.key) | index($name)) then ($by_skill[] | select(.key == $name) | .value.agent_bundles_parity // "pending") else "pending" end),
          content_sha256: (if ($by_skill | map(.key) | index($name)) then ($by_skill[] | select(.key == $name) | .value.content_sha256 // "") else "" end),
          evidence_note: (if ($by_skill | map(.key) | index($name)) then ($by_skill[] | select(.key == $name) | .value.evidence_note // "") else "" end)
        }
    ]
  ' > "${manifest_file}.tmp"

mv "${manifest_file}.tmp" "$manifest_file"
printf 'generate-sentinel-skills-manifest: wrote %s (%s skills)\n' "$manifest_file" "${#skills[@]}"
