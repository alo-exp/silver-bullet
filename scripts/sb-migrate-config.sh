#!/usr/bin/env bash
# Merge .silver-bullet.json forward from templates/silver-bullet.config.json.default.
# Preserves project customizations; unions skill lists; sets sb_initiated and orchestrator_mode.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="${1:-$PWD}"
CONFIG="$REPO_ROOT/.silver-bullet.json"
TEMPLATE="$PLUGIN_ROOT/templates/silver-bullet.config.json.default"
PKG_VERSION="$(jq -r '.version' "$PLUGIN_ROOT/package.json" 2>/dev/null || echo "unknown")"

# shellcheck source=../hooks/lib/nofollow-guard.sh
source "$PLUGIN_ROOT/hooks/lib/nofollow-guard.sh"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Template not found: $TEMPLATE" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq required" >&2
  exit 1
fi

if [[ -L "$CONFIG" ]]; then
  echo "Refusing to write through a symlink: $CONFIG" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  # shellcheck disable=SC2016
  jq --arg ver "$PKG_VERSION" '
    .config_version = $ver
    | .version = $ver
    | .sb_initiated = true
    | .orchestrator_mode = "parent"
  ' "$TEMPLATE" | sb_atomic_write_file "$CONFIG"
  echo "Created $CONFIG from template (sb_initiated: true)"
  exit 0
fi

# Deep-merge: the template supplies defaults, the existing file always wins, and keys the template
# does not know (recommended_tools consent, ci, custom settings) are kept (R3-22). The required
# skill lists are the union of both, in order: template entries first, then the project's own.
merged="$(jq \
  --arg ver "$PKG_VERSION" \
  --slurpfile tmpl "$TEMPLATE" \
  --slurpfile ex "$CONFIG" '
  def union_arrays(a; b): reduce (a + b)[] as $x ([]; if any(.[]; . == $x) then . else . + [$x] end);
  ($tmpl[0]) as $t |
  ($ex[0]) as $e |
  ($t * $e)
  | .skills.required_planning = union_arrays($t.skills.required_planning; ($e.skills.required_planning // []))
  | .skills.required_planning_devops = union_arrays($t.skills.required_planning_devops; ($e.skills.required_planning_devops // []))
  | .skills.required_deploy = union_arrays($t.skills.required_deploy; ($e.skills.required_deploy // []))
  | .skills.required_deploy_devops = union_arrays($t.skills.required_deploy_devops; ($e.skills.required_deploy_devops // []))
  | .skills.required_release = union_arrays($t.skills.required_release; ($e.skills.required_release // []))
  | .skills.required_release_devops = union_arrays($t.skills.required_release_devops; ($e.skills.required_release_devops // []))
  | .skills.all_tracked = union_arrays($t.skills.all_tracked; ($e.skills.all_tracked // []))
  | .skills.forbidden = union_arrays($t.skills.forbidden; ($e.skills.forbidden // []))
  | .enterprise_policy.profiles = (($t.enterprise_policy.profiles // {}) * ($e.enterprise_policy.profiles // {}))
  | .issue_tracker = (
      if (($e.issue_tracker // "") == ("gs" + "d")) then "local"
      else ($e.issue_tracker // $t.issue_tracker)
      end
    )
  | .config_version = $ver
  | .version = $ver
  | .sb_initiated = true
  | .orchestrator_mode = "parent"
  | if .verify_commands == null then del(.verify_commands) else . end
  ' "$CONFIG")"

if [[ "$merged" == "$(jq . "$CONFIG")" ]]; then
  echo "$CONFIG is already current (version $PKG_VERSION); nothing to write"
  exit 0
fi
# Keep the original beside it before replacing it.
backup="${CONFIG}.bak-$(date +%Y%m%d%H%M%S)"
cp -p -- "$CONFIG" "$backup"
printf '%s\n' "$merged" | sb_atomic_write_file "$CONFIG"
echo "Merged $CONFIG forward (version $PKG_VERSION, sb_initiated: true, orchestrator_mode: parent)"
echo "Previous file kept as ${backup##*/}"
