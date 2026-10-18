#!/usr/bin/env bash
# sync-release-marketplace-versions.sh orchestration with stubbed per-host sync
# scripts and local git remotes: argument validation, the pre-release gate,
# the shared batch clone (one commit, one push), the in-repo-only fallback and
# temp-dir hygiene.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=tests/lib/j-install-sync-helpers.sh
source "$TL_REPO_ROOT/tests/lib/j-install-sync-helpers.sh"
# shellcheck source=tests/lib/offline-tools.sh
source "$TL_REPO_ROOT/tests/lib/offline-tools.sh"
sb_offline_tools_install "$TL_TMP/offline-bin"
j_git_identity
cd "$TL_TMP"

T="$TL_TMP/tree"
LOG="$TL_TMP/calls.log"
mkdir -p "$TL_TMP/tmpdir"
new_tree() {
  rm -rf "$T"
  mkdir -p "$T/scripts/lib"
  cp "$TL_REPO_ROOT/scripts/sync-release-marketplace-versions.sh" "$T/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/agent-plugins-common.sh" "$T/scripts/lib/"
  local host manifest
  for host in claude codex cursor; do
    case "$host" in
      claude) manifest=.claude-plugin/marketplace.json ;;
      codex) manifest=.agents/plugins/marketplace.json ;;
      cursor) manifest=.cursor-plugin/marketplace.json ;;
    esac
    # Each stub records its call and, when it has a batch root, edits its own manifest there.
    cat >"$T/scripts/stub-$host.sh" <<STUB
#!/usr/bin/env bash
echo "$host version=\${1-} root=\${AGENT_PLUGINS_REPO_ROOT-<unset>} skip_push=\${AGENT_PLUGINS_SKIP_PUSH-<unset>}" >>"$LOG"
[[ -n "\${STUB_FAIL:-}" && "\${STUB_FAIL}" == "$host" ]] && exit 4
if [[ -n "\${AGENT_PLUGINS_REPO_ROOT:-}" ]]; then
  jq --arg v "\$1" '(.plugins[] | select(.name=="silver-bullet") | .version) = \$v' "\$AGENT_PLUGINS_REPO_ROOT/$manifest" >"\$AGENT_PLUGINS_REPO_ROOT/$manifest.new" &&
    mv "\$AGENT_PLUGINS_REPO_ROOT/$manifest.new" "\$AGENT_PLUGINS_REPO_ROOT/$manifest"
fi
exit 0
STUB
  done
  cat >"$T/scripts/pre-release-gate.sh" <<GATE
#!/usr/bin/env bash
echo "gate" >>"$LOG"
exit "\${GATE_RC:-0}"
GATE
  chmod +x "$T"/scripts/*.sh
  : >"$LOG"
}
SCRIPT="$T/scripts/sync-release-marketplace-versions.sh"
run_release() {
  tl_run env -u AGENT_PLUGINS_REPO_ROOT -u AGENT_PLUGINS_REPO_URL TMPDIR="$TL_TMP/tmpdir" \
    SB_SYNC_MARKETPLACE_VERSION_SCRIPT="$T/scripts/stub-claude.sh" \
    SB_SYNC_CODEX_MARKETPLACE_VERSION_SCRIPT="$T/scripts/stub-codex.sh" \
    SB_SYNC_CURSOR_MARKETPLACE_VERSION_SCRIPT="$T/scripts/stub-cursor.sh" \
    timeout 60 "$@"
}

# --- arguments ---------------------------------------------------------------------
new_tree
run_release bash "$SCRIPT"
assert_eq "missing version exits 1" 1 "$TL_STATUS"
assert_contains "usage printed" "$TL_ERR" "usage: scripts/sync-release-marketplace-versions.sh <version>"
run_release bash "$SCRIPT" v
assert_eq "bare v exits 1" 1 "$TL_STATUS"
assert_contains "empty version explained" "$TL_ERR" "release version cannot be empty"
assert_eq "no sync ran for bad arguments" "" "$(<"$LOG")"

# --- pre-release gate -----------------------------------------------------------------
new_tree
j_make_remote "$TL_TMP/mk"
j_clone_remote "$TL_TMP/work0"
run_release env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work0" GATE_RC=3 bash "$SCRIPT" 2.0.0
assert_eq "failing gate stops the release sync" 1 "$TL_STATUS"
assert_eq "only the gate ran" "gate" "$(<"$LOG")"
: >"$LOG"
run_release env SB_SKIP_PRE_RELEASE_GATE=1 GATE_RC=3 AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work0" bash "$SCRIPT" 2.0.0
assert_eq "skipped gate: sync still succeeds" 0 "$TL_STATUS"
assert_not_contains "gate skipped on request" "$(<"$LOG")" "gate"

# --- shared batch root: one commit, one push -----------------------------------------------
new_tree
j_make_remote "$TL_TMP/mk2"
j_clone_remote "$TL_TMP/work"
run_release env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" v2.0.0
assert_eq "batch sync exits 0" 0 "$TL_STATUS"
assert_eq "gate ran first, then the three hosts in order" "gate
claude version=2.0.0 root=$TL_TMP/work skip_push=1
codex version=2.0.0 root=$TL_TMP/work skip_push=1
cursor version=2.0.0 root=$TL_TMP/work skip_push=1" "$(<"$LOG")"
assert_contains "completion banner" "$TL_OUT" "The unified agent-plugins marketplace was updated for v2.0.0."
assert_eq "one batch commit pushed" "Sync silver-bullet marketplace manifests to 2.0.0" "$(git -C "$J_REMOTE" log -1 --format=%s main)"
assert_eq "all three manifests in the pushed commit" ".agents/plugins/marketplace.json
.claude-plugin/marketplace.json
.cursor-plugin/marketplace.json" "$(git -C "$J_REMOTE" show --name-only --format= main | LC_ALL=C sort)"
assert_eq "a caller-owned batch root is left in place" 1 "$([[ -d "$TL_TMP/work" ]] && echo 1 || echo 0)"
assert_eq "skip-push flag is not left set for the commit" 1 "$([[ "$(git -C "$TL_TMP/work" rev-parse origin/main)" == "$(git -C "$J_REMOTE" rev-parse main)" ]] && echo 1 || echo 0)"

# Nothing changed: nothing committed or pushed.
before="$(git -C "$J_REMOTE" rev-parse main)"
run_release env SB_SKIP_PRE_RELEASE_GATE=1 AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" 2.0.0
assert_eq "re-run exits 0" 0 "$TL_STATUS"
assert_eq "re-run pushes nothing" "$before" "$(git -C "$J_REMOTE" rev-parse main)"

# A failing host sync aborts before the commit.
new_tree
j_make_remote "$TL_TMP/mk3"
j_clone_remote "$TL_TMP/work3"
before="$(git -C "$J_REMOTE" rev-parse main)"
run_release env SB_SKIP_PRE_RELEASE_GATE=1 AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work3" STUB_FAIL=codex bash "$SCRIPT" 2.0.0
assert_eq "host sync failure fails the release sync" 1 "$TL_STATUS"
assert_not_contains "cursor sync not reached" "$(<"$LOG")" "cursor"
assert_eq "nothing pushed after a host failure" "$before" "$(git -C "$J_REMOTE" rev-parse main)"

# --- batch clone ---------------------------------------------------------------------------------
new_tree
j_make_remote "$TL_TMP/mk4"
run_release env SB_SKIP_PRE_RELEASE_GATE=1 AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" 2.0.0
assert_eq "clone-based sync exits 0" 0 "$TL_STATUS"
assert_contains "hosts ran inside the temporary clone" "$(<"$LOG")" "claude version=2.0.0 root=$TL_TMP/tmpdir/sb-agent-plugins-release."
assert_eq "clone-based batch pushed" "Sync silver-bullet marketplace manifests to 2.0.0" "$(git -C "$J_REMOTE" log -1 --format=%s main)"
assert_eq "temporary clone removed" "" "$(ls -A "$TL_TMP/tmpdir")"

# --- clone failure: in-repo manifests only ------------------------------------------------------------
new_tree
run_release env SB_SKIP_PRE_RELEASE_GATE=1 AGENT_PLUGINS_REPO_URL="$TL_TMP/does-not-exist" bash "$SCRIPT" v2.0.0
assert_eq "clone failure still exits 0" 0 "$TL_STATUS"
assert_contains "clone failure warned" "$TL_ERR" "WARN: could not clone $TL_TMP/does-not-exist; syncing in-repo manifests only"
assert_eq "hosts ran without a batch root" "claude version=2.0.0 root=<unset> skip_push=<unset>
codex version=2.0.0 root=<unset> skip_push=<unset>
cursor version=2.0.0 root=<unset> skip_push=<unset>" "$(<"$LOG")"
assert_eq "no temporary clone directory left behind" "" "$(ls -A "$TL_TMP/tmpdir")"

tl_results
