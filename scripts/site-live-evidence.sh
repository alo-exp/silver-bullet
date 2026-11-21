#!/usr/bin/env bash
# site-live-evidence.sh — verify the live site and record the evidence the live-publish gate asks for.
#
# Usage (from the project): bash <plugin>/scripts/site-live-evidence.sh --marker TEXT [--marker TEXT ...]
#
# It fetches site_profile.live_url from the project's .silver-bullet.json, checks that every marker (text that
# only the newly published page contains) is present, and writes live-publish-evidence.json for the current HEAD
# into the Silver Bullet state directory. The state directory is protected from the agent, so this script is the
# sanctioned writer: the agent cannot hand-write the evidence, and what is recorded is what this script saw.
# Exit 0 when LIVE (every marker matched), 1 when NOT_LIVE, 2 on a usage or setup problem.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_lib_dir="$SCRIPT_DIR/../hooks/lib"
# shellcheck source=../hooks/lib/runtime-paths.sh
source "$_lib_dir/runtime-paths.sh"
# shellcheck source=../hooks/lib/site-session.sh
source "$_lib_dir/site-session.sh"

markers=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --marker)
      [[ $# -ge 2 && -n "$2" ]] || { echo "site-live-evidence: --marker needs a non-empty value" >&2; exit 2; }
      markers+=("$2")
      shift 2
      ;;
    *)
      echo "usage: site-live-evidence.sh --marker TEXT [--marker TEXT ...]" >&2
      exit 2
      ;;
  esac
done
[[ ${#markers[@]} -gt 0 ]] || { echo "site-live-evidence: give at least one --marker" >&2; exit 2; }

sb_site_profile_load || { echo "site-live-evidence: not a project with site_profile.enabled in .silver-bullet.json" >&2; exit 2; }
[[ -n "$SB_SITE_LIVE_URL" ]] || { echo "site-live-evidence: site_profile.live_url is not set" >&2; exit 2; }
head_sha="$(git -C "$SB_SITE_ROOT" rev-parse HEAD 2>/dev/null)" || { echo "site-live-evidence: no git HEAD in $SB_SITE_ROOT" >&2; exit 2; }

body="$(curl -fsSL --max-time 30 "$SB_SITE_LIVE_URL" 2>/dev/null)" || body=""
matched=()
for m in "${markers[@]}"; do
  if grep -qF -- "$m" <<<"$body"; then matched+=("$m"); fi
done
status=NOT_LIVE
[[ ${#matched[@]} -eq ${#markers[@]} ]] && status=LIVE

state_dir="${SB_RUNTIME_STATE_DIR:?}"
mkdir -p "$state_dir"
out="$(sb_site_session_live_evidence_file)"
tmp="${out}.tmp.$$"
matched_json="$(printf '%s\n' ${matched[@]+"${matched[@]}"} | jq -R . | jq -s 'map(select(length > 0))')"
jq -n --arg status "$status" --arg sha "$head_sha" --arg url "$SB_SITE_LIVE_URL" --arg root "$SB_SITE_ROOT" \
  --argjson matched "$matched_json" --argjson epoch "$(date +%s)" --arg at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  '{status:$status, commit_sha:$sha, project:$root, urls:[$url], markers_matched:$matched, verified_at:$at, verified_epoch:$epoch}' >"$tmp"
mv -f "$tmp" "$out"
echo "site-live-evidence: $status for $head_sha at $SB_SITE_LIVE_URL (${#matched[@]}/${#markers[@]} markers matched)"
[[ "$status" == LIVE ]]
