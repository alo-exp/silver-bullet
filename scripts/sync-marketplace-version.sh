#!/usr/bin/env bash
# Sync marketplace.json version with plugin.json before tagging a release.
#
# Updates BOTH:
#   - .claude-plugin/marketplace.json (self-hosted entry in this repo)
#   - Prints the command to update alo-labs/claude-plugins (separate marketplace repo)
#
# Usage: scripts/sync-marketplace-version.sh
#
# Exit 0 = versions already in sync or successfully synced
# Exit 1 = jq unavailable or JSON malformed

set -euo pipefail

repo_root=$(cd "$(dirname "$0")/.." && pwd)
plugin_json="$repo_root/.claude-plugin/plugin.json"
marketplace_json="$repo_root/.claude-plugin/marketplace.json"

command -v jq >/dev/null || { echo "jq required"; exit 1; }

plugin_v=$(jq -r '.version' "$plugin_json")
market_v=$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$marketplace_json")

if [[ "$plugin_v" == "$market_v" ]]; then
  echo "✓ Versions already in sync: $plugin_v"
else
  tmp=$(mktemp)
  jq --arg v "$plugin_v" '(.plugins[] | select(.name=="silver-bullet") | .version) = $v' \
    "$marketplace_json" > "$tmp"
  mv "$tmp" "$marketplace_json"
  echo "✓ Updated in-repo marketplace.json: $market_v → $plugin_v"
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Remote marketplace sync reminder
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
After pushing v$plugin_v, also update alo-labs/claude-plugins:

  git clone https://github.com/alo-labs/claude-plugins.git /tmp/mp
  jq --arg v "$plugin_v" '(.plugins[] | select(.name=="silver-bullet") | .version) = \$v' \\
    /tmp/mp/.claude-plugin/marketplace.json > /tmp/mp/out && \\
    mv /tmp/mp/out /tmp/mp/.claude-plugin/marketplace.json
  cd /tmp/mp && git commit -am "Bump silver-bullet to $plugin_v" && git push
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
EOF
