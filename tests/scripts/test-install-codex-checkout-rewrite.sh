#!/usr/bin/env bash
# R7-09: rewrite_codex_bundle_host_paths must never edit the developer's own checkout
# (marketplace root == REPO_ROOT); a separate marketplace snapshot is still rewritten.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init codex

CODEX_HOME_ROOT="$TL_TMP/chome"
mkdir -p "$CODEX_HOME_ROOT/.codex"
# shellcheck source=../../scripts/lib/install-codex/config.sh
source "$TL_REPO_ROOT/scripts/lib/install-codex/config.sh"
# shellcheck source=../../scripts/lib/install-codex/path-rewrite.sh
source "$TL_REPO_ROOT/scripts/lib/install-codex/path-rewrite.sh"

TEXT='see ~/.claude/settings.json and $HOME/.claude/x and /abs/.claude/y'

make_tree() { # root
  mkdir -p "$1/plugins/silver-bullet/skill-source/demo" "$1/host-bundles/codex/demo" "$1/agents/codex/demo"
  printf '%s\n' "$TEXT" >"$1/plugins/silver-bullet/skill-source/demo/SKILL.md"
  printf '%s\n' "$TEXT" >"$1/host-bundles/codex/demo/SKILL.md"
  printf '%s\n' "$TEXT" >"$1/agents/codex/demo/SKILL.md"
}
register() { # source path
  printf '[marketplaces.alo-labs-codex]\nsource_type = "local"\nsource = "%s"\n' "$1" >"$CODEX_HOME_ROOT/.codex/config.toml"
}

# marketplace root IS the checkout: nothing under it changes
CHECKOUT="$TL_TMP/checkout"
make_tree "$CHECKOUT"
register "$CHECKOUT"
REPO_ROOT="$CHECKOUT" rewrite_codex_bundle_host_paths
for f in plugins/silver-bullet/skill-source/demo host-bundles/codex/demo agents/codex/demo; do
  assert_eq "checkout file untouched: $f" "$TEXT" "$(cat "$CHECKOUT/$f/SKILL.md")"
done

# a separate marketplace snapshot is rewritten as before
SNAP="$TL_TMP/snapshot"
make_tree "$SNAP"
register "$SNAP"
REPO_ROOT="$CHECKOUT" rewrite_codex_bundle_host_paths
assert_contains "snapshot package rewritten to .codex" "$(cat "$SNAP/plugins/silver-bullet/skill-source/demo/SKILL.md")" '/.codex/settings.json'
assert_contains "snapshot host bundle rewritten" "$(cat "$SNAP/host-bundles/codex/demo/SKILL.md")" '$HOME/.codex/x'
assert_eq "checkout still untouched afterwards" "$TEXT" "$(cat "$CHECKOUT/host-bundles/codex/demo/SKILL.md")"

tl_results
