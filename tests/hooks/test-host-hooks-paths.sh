#!/usr/bin/env bash
# Regression: canonical hooks.json stays Claude-format; Codex install surfaces get adapter wrap.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { echo "PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL + 1)); }

TMP_HOME="$(mktemp -d "${TMPDIR:-/tmp}/sb-host-hooks-paths.XXXXXX")"
trap 'rm -rf "$TMP_HOME"' EXIT

export HOME="$TMP_HOME"
export CODEX_HOME_ROOT="$TMP_HOME"
mkdir -p "$TMP_HOME/.codex"

MARKETPLACE="$TMP_HOME/marketplace"
mkdir -p "$MARKETPLACE/hooks" "$MARKETPLACE/plugins/silver-bullet/hooks"
cp "$REPO_ROOT/hooks/hooks.json" "$MARKETPLACE/hooks/hooks.json"
cp -a "$REPO_ROOT/hooks/codex-hook-adapter.sh" "$MARKETPLACE/plugins/silver-bullet/hooks/"

cat >"$TMP_HOME/.codex/config.toml" <<EOF
[marketplaces.alo-labs-codex]
source_type = "local"
source = "${MARKETPLACE}"
EOF

bash -c "
  set -euo pipefail
  CODEX_HOME_ROOT='$TMP_HOME'
  codex_marketplace_root() { printf '%s\n' '$MARKETPLACE'; }
  # shellcheck source=/dev/null
  source '$REPO_ROOT/scripts/lib/install-codex/path-rewrite.sh'
  rewrite_codex_bundle_host_paths
"

canonical_text="$(cat "$MARKETPLACE/hooks/hooks.json")"
package_text="$(cat "$MARKETPLACE/plugins/silver-bullet/hooks/hooks.json")"
repo_text="$(cat "$REPO_ROOT/hooks/hooks.json")"

if [[ "$canonical_text" == *'${CLAUDE_PLUGIN_ROOT}'* ]] && [[ "$canonical_text" != *'codex-hook-adapter'* ]]; then
  pass "canonical hooks.json remains Claude-format after Codex path rewrite"
else
  fail "canonical hooks.json remains Claude-format after Codex path rewrite"
fi

if [[ "$package_text" == *'codex-hook-adapter.sh'* ]] && grep -q SubagentStart "$MARKETPLACE/plugins/silver-bullet/hooks/hooks.json"; then
  pass "Codex package hooks.json includes SubagentStart via adapter wrap"
else
  fail "Codex package hooks.json includes SubagentStart via adapter wrap"
fi

if grep -q 'codex-hook-adapter.*codex-hook-adapter' "$MARKETPLACE/plugins/silver-bullet/hooks/hooks.json"; then
  fail "Codex package hooks avoid double adapter wrapping"
else
  pass "Codex package hooks avoid double adapter wrapping"
fi

if [[ "$repo_text" == "$canonical_text" || "$repo_text" == *'${CLAUDE_PLUGIN_ROOT}'* ]]; then
  pass "repo canonical hooks.json unchanged by isolated Codex path rewrite"
else
  fail "repo canonical hooks.json unchanged by isolated Codex path rewrite"
fi

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
