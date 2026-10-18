#!/usr/bin/env bash
# scripts/install-cursor.sh end to end (plain install, --project-root, failing collaborators).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude
# shellcheck source=tests/lib/install-cursor-script-fixture.sh
source "$TL_REPO_ROOT/tests/lib/install-cursor-script-fixture.sh"

# ---- plain local install
fresh
run
assert_eq "local install exits 0" 0 "$TL_STATUS"
assert_contains "install reported" "$TL_OUT" "Silver Bullet Cursor plugin synced to $CACHE/$VERSION"
assert_contains "unified marketplace reported" "$TL_OUT" "Cursor marketplace: unified alo-labs/agent-plugins (alo-labs-cursor)"
assert_contains "install version key recorded" "$TL_OUT" "SB install version key: $VERSION"
assert_eq "current alias points at the version" "$CACHE/$VERSION" "$(readlink "$CACHE/current")"
assert_eq "registry records the commit" "$SNAP_SHA" "$(jq -r '.plugins["silver-bullet@alo-labs"][0].gitCommitSha' "$CURSOR_HOME/plugins/installed_plugins.json")"
assert_file_exists "SB hooks merged" "$CURSOR_HOME/hooks.json"
assert_contains "sub-agent installer ran non-interactively" "$(<"$CALLS")" "csba --global --non-interactive"
assert_contains "reconciler ran against the checkout without a project" "$(<"$CALLS")" "rt-post-install root=$SNAP project="

# ---- --project-root scopes the sub-agent config and the reconciler; failing collaborators only warn
fresh
tl_run env STUB_CSBA_RC=1 STUB_RT_RC=1 bash "$SCRIPT" --project-root "$PROJ"
assert_eq "install with failing collaborators exits 0" 0 "$TL_STATUS"
assert_contains "sub-agent installer pointed at the project" "$(<"$CALLS")" "csba --global --non-interactive repo=$PROJ"
assert_contains "reconciler received the project root" "$(<"$CALLS")" "rt-post-install root=$SNAP project=$PROJ"
assert_contains "sub-agent installer failure warned about" "$TL_ERR" "WARN: install-cursor-sb-agents.sh exited nonzero (continuing)"
assert_contains "reconciler failure warned about" "$TL_ERR$TL_OUT" "WARN: reconciler post-install exited nonzero"
fresh
run --project-root "$TL_TMP/no-such-project"
assert_eq "an unreachable project root is tolerated" 0 "$TL_STATUS"
assert_contains "reconciler ran without a project" "$(<"$CALLS")" "rt-post-install root=$SNAP project="

tl_results
