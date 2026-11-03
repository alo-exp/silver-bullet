#!/usr/bin/env bash
# sync-release-marketplace-versions.sh with the real per-host sync scripts against local git
# remotes; only the package syncs, the pre-release gate and the CI check are stubbed.
#   <version>            pre-release gate, then this repository's manifests only (no clone)
#   --publish <version>  only after the release tag is on origin and its commit is green:
#                        one clone, the three hosts commit, one push that must land
# Also: argument validation, refusal of a checkout holding someone else's commits, host
# failures, clone failure (R13-19) and temp-dir hygiene.
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
ORIGIN="$TL_TMP/sb-origin.git"
LOG="$TL_TMP/calls.log"
mkdir -p "$TL_TMP/tmpdir"
CLAUDE_MF=.claude-plugin/marketplace.json
CODEX_MF=.agents/plugins/marketplace.json
CURSOR_MF=.cursor-plugin/marketplace.json
CODEX_PJ=plugins/silver-bullet/.codex-plugin/plugin.json
# new_tree: a Silver Bullet repository at 2.0.0 with stale marketplace manifests, pushed to
# its own origin, holding the real sync scripts and stub package syncs, gate and CI check.
new_tree() {
  rm -rf "$T" "$ORIGIN"
  mkdir -p "$T/scripts/lib" "$T/.claude-plugin" "$T/.cursor-plugin" \
    "$T/plugins/silver-bullet/.codex-plugin" "$T/plugins/silver-bullet/.cursor-plugin"
  local s
  for s in sync-release-marketplace-versions.sh sync-marketplace-version.sh \
    sync-codex-marketplace-version.sh sync-cursor-marketplace-version.sh; do
    cp "$TL_REPO_ROOT/scripts/$s" "$T/scripts/"
  done
  cp "$TL_REPO_ROOT/scripts/lib/agent-plugins-common.sh" "$T/scripts/lib/"
  jq -n '{version: "2.0.0"}' >"$T/package.json"
  jq -n '{name: "silver-bullet", version: "2.0.0"}' >"$T/.claude-plugin/plugin.json"
  jq -n '{name: "silver-bullet", version: "2.0.0"}' >"$T/.cursor-plugin/plugin.json"
  jq -n '{name: "silver-bullet", version: "2.0.0"}' >"$T/plugins/silver-bullet/.cursor-plugin/plugin.json"
  jq -n '{name: "silver-bullet", version: "1.0.0", config_version: "1.0.0"}' >"$T/$CODEX_PJ"
  j_marketplace_json '{"source":"github","repo":"o/sb"}' >"$T/$CLAUDE_MF"
  j_marketplace_json '{"source":"github","repo":"o/sb","ref":"main","sha":"0000","path":"x"}' >"$T/$CURSOR_MF"
  cat >"$T/scripts/sync-codex-package.sh" <<STUB
#!/usr/bin/env bash
echo "codex-package" >>"$LOG"
STUB
  cat >"$T/scripts/sync-cursor-package.sh" <<'STUB'
#!/usr/bin/env bash
root="$(cd "$(dirname "$0")/.." && pwd)"
jq '.version' "$root/.cursor-plugin/plugin.json" >/dev/null
STUB
  cat >"$T/scripts/pre-release-gate.sh" <<GATE
#!/usr/bin/env bash
echo "gate" >>"$LOG"
exit "\${GATE_RC:-0}"
GATE
  cat >"$T/scripts/verify-release-commit-ci.sh" <<CI
#!/usr/bin/env bash
echo "ci \$*" >>"$LOG"
exit "\${CI_RC:-0}"
CI
  chmod +x "$T"/scripts/*.sh
  git init -q -b main "$T"
  git -C "$T" add -A
  git -C "$T" commit -q -m "release commit"
  git init -q --bare -b main "$ORIGIN"
  git -C "$T" remote add origin "$ORIGIN"
  git -C "$T" push -q -u origin main
  : >"$LOG"
}
# release_tree: new_tree with the in-repo manifests aligned, committed, tagged v2.0.0 and pushed.
release_tree() {
  new_tree
  run_release env SB_SKIP_PRE_RELEASE_GATE=1 bash "$SCRIPT" 2.0.0 >/dev/null
  git -C "$T" add -A
  git -C "$T" commit -q -m "chore(release): 2.0.0"
  git -C "$T" tag -a v2.0.0 -m "Release 2.0.0"
  git -C "$T" push -q origin main v2.0.0
  : >"$LOG"
}
SCRIPT="$T/scripts/sync-release-marketplace-versions.sh"
run_release() {
  tl_run env -u AGENT_PLUGINS_REPO_ROOT -u AGENT_PLUGINS_REPO_URL -u AGENT_PLUGINS_SKIP_PUSH \
    -u MARKETPLACE_REPO_URL -u CODEX_MARKETPLACE_REPO_URL -u CURSOR_MARKETPLACE_REPO_URL \
    TMPDIR="$TL_TMP/tmpdir" timeout 60 "$@"
}
remote_sb() { git -C "$J_REMOTE" show "main:$1" | jq -r --arg k "$2" '.plugins[] | select(.name=="silver-bullet") | getpath($k | split("."))'; }

# --- arguments ---------------------------------------------------------------------
new_tree
run_release bash "$SCRIPT"
assert_eq "missing version exits 1" 1 "$TL_STATUS"
assert_contains "usage printed" "$TL_ERR" "usage: scripts/sync-release-marketplace-versions.sh [--publish] <version>"
run_release bash "$SCRIPT" v
assert_eq "bare v exits 1" 1 "$TL_STATUS"
assert_contains "empty version explained" "$TL_ERR" "release version cannot be empty"
run_release bash "$SCRIPT" --bogus 2.0.0
assert_eq "unknown option exits 1" 1 "$TL_STATUS"
assert_contains "unknown option named" "$TL_ERR" "unknown option: --bogus"
run_release bash "$SCRIPT" 2.0.0 3.0.0
assert_eq "second version exits 1" 1 "$TL_STATUS"
assert_contains "extra argument named" "$TL_ERR" "unexpected argument: 3.0.0"
assert_eq "nothing ran for bad arguments" "" "$(<"$LOG")"

# --- prepare: pre-release gate, then this repository only ------------------------------------
new_tree
run_release env GATE_RC=3 bash "$SCRIPT" 2.0.0
assert_eq "failing gate stops the release sync" 1 "$TL_STATUS"
assert_eq "only the gate ran" "gate" "$(<"$LOG")"
assert_eq "failing gate: nothing written" "" "$(git -C "$T" status --porcelain)"

j_make_remote "$TL_TMP/mk"
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
: >"$LOG"
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" v2.0.0
assert_eq "prepare exits 0" 0 "$TL_STATUS"
assert_eq "gate ran first, then the Codex package sync" "gate
codex-package" "$(<"$LOG")"
assert_eq "Claude in-repo manifest aligned" "2.0.0" "$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$T/$CLAUDE_MF")"
assert_eq "Codex plugin manifest aligned" "2.0.0/2.0.0" "$(jq -r '"\(.version)/\(.config_version)"' "$T/$CODEX_PJ")"
assert_eq "Cursor in-repo manifest aligned" "2.0.0" "$(jq -r '.plugins[] | select(.name=="silver-bullet") | .version' "$T/$CURSOR_MF")"
assert_contains "next steps name the publish step" "$TL_OUT" "bash scripts/sync-release-marketplace-versions.sh --publish 2.0.0"
assert_contains "next steps put CI before publishing" "$TL_OUT" "verify-release-commit-ci.sh"
assert_not_contains "prepare does not claim the marketplace was updated" "$TL_OUT" "unified agent-plugins marketplace was updated"
assert_eq "prepare publishes nothing (R13-07)" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "prepare leaves no temporary clone" "" "$(ls -A "$TL_TMP/tmpdir")"
: >"$LOG"
run_release env SB_SKIP_PRE_RELEASE_GATE=1 GATE_RC=3 bash "$SCRIPT" 2.0.0
assert_eq "skipped gate: prepare still succeeds" 0 "$TL_STATUS"
assert_not_contains "gate skipped on request" "$(<"$LOG")" "gate"

# --- publish preconditions (R13-07) -----------------------------------------------------------
new_tree
run_release env SB_SKIP_PRE_RELEASE_GATE=1 bash "$SCRIPT" 2.0.0 >/dev/null
git -C "$T" commit -q -am "chore(release): 2.0.0"
: >"$LOG"
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "publish before tagging exits 1" 1 "$TL_STATUS"
assert_contains "missing tag explained" "$TL_ERR" "release tag v2.0.0 does not exist"
assert_eq "publish before tagging: no CI check, no gate" "" "$(<"$LOG")"
assert_eq "publish before tagging: nothing published" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

git -C "$T" tag -a v2.0.0 -m "Release 2.0.0"
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "tag not pushed: publish exits 1" 1 "$TL_STATUS"
assert_contains "unpushed tag explained" "$TL_ERR" "release tag v2.0.0 is not on origin"
assert_eq "unpushed tag: nothing published" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

git -C "$T" push -q origin main v2.0.0
TAGC="$(git -C "$T" rev-parse 'v2.0.0^{commit}')"
run_release env CI_RC=1 AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "red CI: publish exits 1" 1 "$TL_STATUS"
assert_eq "CI checked for the tagged commit" "ci $TAGC" "$(<"$LOG")"
assert_contains "red CI explained" "$TL_ERR" "CI is not green for v2.0.0 ($TAGC); nothing was published"
assert_eq "red CI: nothing published" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "red CI: no temporary clone left" "" "$(ls -A "$TL_TMP/tmpdir")"

jq '.version = "2.0.1"' "$T/package.json" >"$TL_TMP/p.json" && cp "$TL_TMP/p.json" "$T/package.json"
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "package.json at another version: publish exits 1" 1 "$TL_STATUS"
assert_contains "package.json mismatch explained" "$TL_ERR" "package.json is 2.0.1, not 2.0.0"
git -C "$T" checkout -q -- package.json

# A tag that moved after it was pushed is not the published release.
git -C "$T" tag -d v2.0.0 >/dev/null; git -C "$T" tag -a v2.0.0 -m "moved" HEAD~1
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "local tag differing from origin: publish exits 1" 1 "$TL_STATUS"
assert_contains "differing tag explained" "$TL_ERR" "release tag v2.0.0 is not on origin"

# Without a reachable origin the tag cannot be confirmed: refused with the same explanation.
git -C "$T" remote remove origin
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "no origin: publish exits 1" 1 "$TL_STATUS"
assert_contains "no origin explained" "$TL_ERR" "release tag v2.0.0 is not on origin"
assert_eq "no origin: nothing published" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

# --- publish: one clone, three commits, one push that lands (R13-01) --------------------------------
release_tree
TAGC="$(git -C "$T" rev-parse 'v2.0.0^{commit}')"
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish v2.0.0
assert_eq "publish exits 0" 0 "$TL_STATUS"
assert_eq "CI checked once for the tagged commit, no pre-release gate" "ci $TAGC" "$(<"$LOG")"
assert_contains "the push is reported" "$TL_OUT" "Pushed 3 commit(s) to origin/main"
assert_contains "completion banner" "$TL_OUT" "The unified agent-plugins marketplace offers silver-bullet v2.0.0"
assert_not_contains "no per-host banner before the push lands" "$TL_OUT" "manifest now offers silver-bullet"
assert_contains "hosts report their commit as pending the single push" "$TL_OUT" "push pending"
assert_eq "remote Claude entry at 2.0.0" "2.0.0" "$(remote_sb "$CLAUDE_MF" version)"
assert_eq "remote Codex entry at 2.0.0" "2.0.0" "$(remote_sb "$CODEX_MF" version)"
assert_eq "remote Codex ref is the tag" "v2.0.0" "$(remote_sb "$CODEX_MF" source.ref)"
assert_eq "remote Cursor entry at 2.0.0" "2.0.0" "$(remote_sb "$CURSOR_MF" version)"
assert_eq "remote Cursor sha is the tagged commit" "$TAGC" "$(remote_sb "$CURSOR_MF" source.sha)"
assert_eq "remote Cursor ref is the tag" "v2.0.0" "$(remote_sb "$CURSOR_MF" source.ref)"
assert_eq "one commit per host, newest first" "Bump silver-bullet Cursor manifest to 2.0.0
Bump silver-bullet Codex manifest to 2.0.0
Bump silver-bullet Claude manifest to 2.0.0" "$(git -C "$J_REMOTE" log -3 --format=%s main)"
assert_eq "each commit holds only its manifest" "$CURSOR_MF $CODEX_MF $CLAUDE_MF" \
  "$(for c in main main~1 main~2; do git -C "$J_REMOTE" show --name-only --format= "$c"; done | tr '\n' ' ' | sed 's/ $//')"
assert_eq "temporary clone removed" "" "$(ls -A "$TL_TMP/tmpdir")"
assert_eq "publish leaves this repository untouched" "" "$(git -C "$T" status --porcelain)"

# Re-run: nothing changes, nothing is pushed.
before="$(git -C "$J_REMOTE" rev-parse main)"
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "re-run exits 0" 0 "$TL_STATUS"
assert_contains "re-run reports the hosts as current" "$TL_OUT" "Cursor marketplace manifest already at silver-bullet 2.0.0"
assert_not_contains "re-run pushes nothing" "$TL_OUT" "Pushed"
assert_eq "re-run leaves the remote alone" "$before" "$(git -C "$J_REMOTE" rev-parse main)"

# --- a caller-owned marketplace checkout ---------------------------------------------------------
j_make_remote "$TL_TMP/mk2"
j_clone_remote "$TL_TMP/work"
echo note >"$TL_TMP/work/notes.txt"; git -C "$TL_TMP/work" add notes.txt; git -C "$TL_TMP/work" commit -q -m "local work"
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
: >"$LOG"
run_release env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish 2.0.0
assert_eq "checkout with unpushed commits refused" 1 "$TL_STATUS"
assert_contains "unpushed commits explained" "$TL_ERR" "has 1 unpushed commit(s) on top of origin/main"
assert_eq "refused before any host ran" "" "$(git -C "$TL_TMP/work" status --porcelain)"
assert_eq "unpushed commits not published" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"

git -C "$TL_TMP/work" reset -q --hard origin/main
echo "maintainer scratch" >"$TL_TMP/work/scratch.txt"
run_release env AGENT_PLUGINS_REPO_ROOT="$TL_TMP/work" bash "$SCRIPT" --publish 2.0.0
assert_eq "caller-owned checkout: publish exits 0" 0 "$TL_STATUS"
assert_eq "caller-owned checkout: pushed" "$(git -C "$TL_TMP/work" rev-parse HEAD)" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "caller-owned checkout kept with its untracked file" "?? scratch.txt" "$(git -C "$TL_TMP/work" status --porcelain)"

# --- a host failure publishes nothing ----------------------------------------------------------------
j_make_remote "$TL_TMP/mk3"
printf '%s' '{"plugins": [' >"$J_SEED/$CODEX_MF"
git -C "$J_SEED" commit -q -am "corrupt codex manifest" && git -C "$J_SEED" push -q origin main
remote_head="$(git -C "$J_REMOTE" rev-parse main)"
run_release env AGENT_PLUGINS_REPO_URL="$J_REMOTE" bash "$SCRIPT" --publish 2.0.0
assert_eq "host failure fails the publish" 1 "$TL_STATUS"
assert_contains "failing host named" "$TL_ERR" "$CODEX_MF is not valid JSON"
assert_eq "nothing pushed after a host failure (the Claude commit stays local)" "$remote_head" "$(git -C "$J_REMOTE" rev-parse main)"
assert_eq "temporary clone removed after a host failure" "" "$(ls -A "$TL_TMP/tmpdir")"

# --- clone failure: nothing is published or changed (R13-19) -------------------------------------------
release_tree
run_release env AGENT_PLUGINS_REPO_URL="$TL_TMP/does-not-exist" bash "$SCRIPT" --publish 2.0.0
assert_eq "clone failure exits 1" 1 "$TL_STATUS"
assert_contains "clone failure explained" "$TL_ERR" "could not clone $TL_TMP/does-not-exist; nothing was published"
assert_not_contains "no in-repo fallback is promised" "$TL_ERR" "in-repo manifests only"
assert_eq "clone failure leaves this repository untouched" "" "$(git -C "$T" status --porcelain)"
assert_eq "no temporary clone directory left behind" "" "$(ls -A "$TL_TMP/tmpdir")"

tl_results
