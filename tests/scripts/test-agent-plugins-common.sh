#!/usr/bin/env bash
# Behavior tests for scripts/lib/agent-plugins-common.sh (repo URL resolution,
# commit/push helper, catalog path). git is real but the "remote" is a local bare repo.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

LIB="$TL_REPO_ROOT/scripts/lib/agent-plugins-common.sh"
# shellcheck source=../../scripts/lib/agent-plugins-common.sh
source "$LIB"

# --- agent_plugins_repo_url ---
unset AGENT_PLUGINS_REPO_URL MARKETPLACE_REPO_URL CODEX_MARKETPLACE_REPO_URL CURSOR_MARKETPLACE_REPO_URL
assert_eq "default repo url" "https://github.com/alo-labs/agent-plugins.git" "$(agent_plugins_repo_url)"
export AGENT_PLUGINS_REPO_URL="file:///x/y.git"
assert_eq "env override repo url" "file:///x/y.git" "$(agent_plugins_repo_url)"

# --- legacy url per host ---
export MARKETPLACE_REPO_URL="legacy-claude"
export CODEX_MARKETPLACE_REPO_URL="legacy-codex"
export CURSOR_MARKETPLACE_REPO_URL="legacy-cursor"
assert_eq "legacy claude" "legacy-claude" "$(agent_plugins_legacy_repo_url claude)"
assert_eq "legacy codex" "legacy-codex" "$(agent_plugins_legacy_repo_url codex)"
assert_eq "legacy cursor" "legacy-cursor" "$(agent_plugins_legacy_repo_url cursor)"
assert_eq "legacy unknown host is empty" "" "$(agent_plugins_legacy_repo_url bogus)"

# --- resolve: legacy wins, else unified ---
assert_eq "resolve prefers legacy" "legacy-codex" "$(resolve_agent_plugins_repo_url codex)"
assert_eq "resolve unknown host falls back to unified" "file:///x/y.git" "$(resolve_agent_plugins_repo_url bogus)"
assert_eq "resolve no host falls back to unified" "file:///x/y.git" "$(resolve_agent_plugins_repo_url)"

# --- commit/push helper ---
BARE="$TL_TMP/remote.git"
git init -q --bare -b main "$BARE"
WORK="$TL_TMP/work"
tl_git_repo "$WORK"
git -C "$WORK" checkout -q main
git -C "$WORK" remote add origin "$BARE"
git -C "$WORK" push -q -u origin main

# clean tree: returns 0 and creates no commit
before="$(git -C "$WORK" rev-parse HEAD)"
rc=0; agent_plugins_commit_push_if_dirty "$WORK" "noop" || rc=$?
assert_eq "clean tree returns 0" "0" "$rc"
assert_eq "clean tree makes no commit" "$before" "$(git -C "$WORK" rev-parse HEAD)"

# dirty + skip push: commits, remote untouched
echo a >"$WORK/a.txt"; git -C "$WORK" add a.txt; git -C "$WORK" commit -q -m seed-a; before="$(git -C "$WORK" rev-parse HEAD)"; git -C "$WORK" push -q origin main; echo a2 >"$WORK/a.txt"
rc=0; AGENT_PLUGINS_SKIP_PUSH=1 agent_plugins_commit_push_if_dirty "$WORK" "add a" || rc=$?
assert_eq "skip-push returns 0" "0" "$rc"
assert_eq "skip-push commit message" "add a" "$(git -C "$WORK" log -1 --format=%s)"
assert_eq "skip-push leaves remote behind" "$before" "$(git -C "$BARE" rev-parse main)"

# dirty with upstream: pushes to the upstream branch
echo b >"$WORK/a.txt"
rc=0; agent_plugins_commit_push_if_dirty "$WORK" "add b" || rc=$?
assert_eq "upstream push returns 0" "0" "$rc"
assert_eq "upstream push reaches remote" "$(git -C "$WORK" rev-parse HEAD)" "$(git -C "$BARE" rev-parse main)"

# staged-only change is also treated as dirty
echo c >"$WORK/c.txt"
git -C "$WORK" add c.txt
rc=0; agent_plugins_commit_push_if_dirty "$WORK" "add c" || rc=$?
assert_eq "staged change committed" "add c" "$(git -C "$WORK" log -1 --format=%s)"

# dirty without upstream: falls back to plain `git push` (stubbed, argument recorded)
NOUP="$TL_TMP/noup"
tl_git_repo "$NOUP"
echo d >"$NOUP/.gitkeep"
REAL_GIT="$(command -v git)"
tl_stub git "if [[ \"\$*\" == *' push'* || \"\$1\" == push ]]; then echo \"PUSH:\$*\" >>'$TL_TMP/git-push.log'; exit 0; fi; exec '$REAL_GIT' \"\$@\""
hash -r
rc=0; agent_plugins_commit_push_if_dirty "$NOUP" "add d" || rc=$?
assert_eq "no-upstream push returns 0" "0" "$rc"
assert_contains "no-upstream uses bare push" "$(cat "$TL_TMP/git-push.log")" "PUSH:-C $NOUP push"
rm -f "$TL_BIN/git"; hash -r

# --- catalog path ---
REPO="$TL_TMP/repo"
mkdir -p "$REPO/scripts/lib"
echo '{}' >"$REPO/scripts/lib/agent-plugins-catalog.json"
assert_eq "catalog in repo root" "$REPO/scripts/lib/agent-plugins-catalog.json" "$(agent_plugins_catalog_path "$REPO")"
unset AGENT_PLUGINS_CATALOG
assert_eq "catalog default when repo lacks file" "scripts/lib/agent-plugins-catalog.json" "$(agent_plugins_catalog_path "$TL_TMP/empty")"
assert_eq "catalog default when no arg" "scripts/lib/agent-plugins-catalog.json" "$(agent_plugins_catalog_path)"
export AGENT_PLUGINS_CATALOG="/custom/cat.json"
assert_eq "catalog env override" "/custom/cat.json" "$(agent_plugins_catalog_path "$TL_TMP/empty")"

tl_results
