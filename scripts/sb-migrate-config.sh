#!/usr/bin/env bash
# Merge .silver-bullet.json forward from templates/silver-bullet.config.json.default.
# Preserves project customizations; unions skill lists; sets sb_initiated and orchestrator_mode.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="${1:-$PWD}"
CONFIG="$REPO_ROOT/.silver-bullet.json"
TEMPLATE="$PLUGIN_ROOT/templates/silver-bullet.config.json.default"
PKG_VERSION="$(jq -r '.version' "$PLUGIN_ROOT/package.json" 2>/dev/null || echo "unknown")"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "Template not found: $TEMPLATE" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq required" >&2
  exit 1
fi

if [[ ! -f "$CONFIG" ]]; then
  cp "$TEMPLATE" "$CONFIG"
  # shellcheck disable=SC2016
  jq --arg ver "$PKG_VERSION" '
    .config_version = $ver
    | .version = $ver
    | .sb_initiated = true
    | .orchestrator_mode = "parent"
  ' "$CONFIG" >"${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
  echo "Created $CONFIG from template (sb_initiated: true)"
  exit 0
fi

merged="$(jq \
  --arg ver "$PKG_VERSION" \
  --slurpfile tmpl "$TEMPLATE" \
  --slurpfile ex "$CONFIG" '
  def union_arrays(a; b): (a + b) | unique;
  ($tmpl[0]) as $t |
  ($ex[0]) as $e |
  $t
  | .project = ($t.project * ($e.project // {}))
  | .skills.required_planning = union_arrays($t.skills.required_planning; ($e.skills.required_planning // []))
  | .skills.required_planning_devops = union_arrays($t.skills.required_planning_devops; ($e.skills.required_planning_devops // []))
  | .skills.required_deploy = union_arrays($t.skills.required_deploy; ($e.skills.required_deploy // []))
  | .skills.required_deploy_devops = union_arrays($t.skills.required_deploy_devops; ($e.skills.required_deploy_devops // []))
  | .skills.required_release = union_arrays($t.skills.required_release; ($e.skills.required_release // []))
  | .skills.required_release_devops = union_arrays($t.skills.required_release_devops; ($e.skills.required_release_devops // []))
  | .skills.all_tracked = union_arrays($t.skills.all_tracked; ($e.skills.all_tracked // []))
  | .skills.forbidden = union_arrays($t.skills.forbidden; ($e.skills.forbidden // []))
  | .hooks = ($t.hooks * ($e.hooks // {}))
  | .devops_plugins = ($t.devops_plugins * ($e.devops_plugins // {}))
  | .release = ($t.release * ($e.release // {}))
  | .semantic_compression = ($t.semantic_compression * ($e.semantic_compression // {}))
  | .multi_agent = ($t.multi_agent * ($e.multi_agent // {}))
  | .enterprise_policy = (
      ($t.enterprise_policy // {}) * ($e.enterprise_policy // {})
      | if (($t.enterprise_policy.profiles // null) != null) or (($e.enterprise_policy.profiles // null) != null) then
          .profiles = (($t.enterprise_policy.profiles // {}) * (.profiles // {}))
        else .
        end
    )
  | .state = ($t.state * ($e.state // {}))
  | .compactPrompt = ($e.compactPrompt // $t.compactPrompt)
  | .issue_tracker = (
      if (($e.issue_tracker // "") == ("gs" + "d")) then "local"
      else ($e.issue_tracker // $t.issue_tracker)
      end
    )
  | .sb_enforcement_tier = ($e.sb_enforcement_tier // $t.sb_enforcement_tier)
  | .verify_commands = ($e.verify_commands // null)
  | .config_version = $ver
  | .version = $ver
  | .sb_initiated = true
  | .orchestrator_mode = "parent"
  | if .verify_commands == null then del(.verify_commands) else . end
  ' "$CONFIG")"

printf '%s\n' "$merged" >"${CONFIG}.tmp" && mv "${CONFIG}.tmp" "$CONFIG"
echo "Merged $CONFIG forward (version $PKG_VERSION, sb_initiated: true, orchestrator_mode: parent)"
