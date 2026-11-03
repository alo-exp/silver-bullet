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
unset AGENT_PLUGINS_REPO_URL MARKETPLACE_REPO_URL CODEX_MARKETPLACE_REPO_URL
assert_eq "default repo url" "https://github.com/alo-labs/agent-plugins.git" "$(agent_plugins_repo_url)"
export AGENT_PLUGINS_REPO_URL="file:///x/y.git"
assert_eq "env override repo url" "file:///x/y.git" "$(agent_plugins_repo_url)"

# --- legacy url per host ---
export MARKETPLACE_REPO_URL="legacy-claude"
export CODEX_MARKETPLACE_REPO_URL="legacy-codex"
export="legacy-cursor"
assert_eq "legacy claude" "legacy-claude" "$(agent_plugins_legacy_repo_url claude)"
assert_eq "legacy codex" "legacy-codex" "$(agent_plugins_legacy_repo_url codex)"
assert_eq "legacy unknown host is empty" "" "$(agent_plugins_legacy_repo_url bogus)"

# --- resolve: legacy wins, else unified ---
assert_eq "resolve prefers legacy" "legacy-codex" "$(resolve_agent_plugins_repo_url codex)"
assert_eq "resolve unknown host falls back to unified" "file:///x/y.git" "$(resolve_agent_plugins_repo_url bogus)"
assert_eq "resolve no host falls back to unified" "file:///x/y.git" "$(resolve_agent_plugins_repo_url)"

# --- commit and push helpers (a local bare repository stands in for the remote) ---
BARE="$TL_TMP/remote.git"
git init -q --bare -b main "$BARE"
WORK="$TL_TMP/work"
tl_git_repo "$WORK"
git -C "$WORK" checkout -q main
echo seed >"$WORK/m.json"
echo seed >"$WORK/notes.txt"
git -C "$WORK" add m.json notes.txt
git -C "$WORK" commit -q -m seed
git -C "$WORK" remote add origin "$BARE"
git -C "$WORK" push -q -u origin main

# Nothing to commit: no commit is made.
before="$(git -C "$WORK" rev-parse HEAD)"
rc=0; agent_plugins_commit_paths "$WORK" "noop" m.json || rc=$?
assert_eq "unchanged path: returns 0" "0" "$rc"
assert_eq "unchanged path: no commit" "$before" "$(git -C "$WORK" rev-parse HEAD)"

# Only the named path is committed (R8-19): an unrelated edit, a staged file and an
# untracked file in the marketplace checkout stay out of the bump commit.
echo bumped >"$WORK/m.json"
echo "work in progress" >"$WORK/notes.txt"
echo scratch >"$WORK/scratch-untracked.txt"
echo staged >"$WORK/staged.txt"; git -C "$WORK" add staged.txt
rc=0; agent_plugins_commit_paths "$WORK" "Bump m" m.json || rc=$?
assert_eq "commit of one path returns 0" "0" "$rc"
assert_eq "bump commit message" "Bump m" "$(git -C "$WORK" log -1 --format=%s)"
assert_eq "bump commit touches only the named path" "m.json" "$(git -C "$WORK" show --name-only --format= HEAD)"
assert_eq "unrelated edit left uncommitted" " M notes.txt" "$(git -C "$WORK" status --porcelain -- notes.txt)"
assert_eq "staged file left staged" "A  staged.txt" "$(git -C "$WORK" status --porcelain -- staged.txt)"
assert_eq "untracked file left untracked" "?? scratch-untracked.txt" "$(git -C "$WORK" status --porcelain -- scratch-untracked.txt)"

# A path with uncommitted changes is refused before the sync rewrites and commits it.
rc=0; out="$(agent_plugins_require_clean_path "$WORK" notes.txt 2>&1)" || rc=$?
assert_eq "dirty path refused" "1" "$rc"
assert_contains "dirty path named" "$out" "$WORK/notes.txt has uncommitted changes"
rc=0; agent_plugins_require_clean_path "$WORK" m.json || rc=$?
assert_eq "clean path accepted" "0" "$rc"
git -C "$WORK" checkout -q -- notes.txt; git -C "$WORK" reset -q -- staged.txt; rm -f "$WORK/staged.txt" "$WORK/scratch-untracked.txt"

# A local commit is pushed even though the working tree is clean (R13-01: the per-host
# scripts commit, the release wrapper pushes once at the end), and the remote is checked.
assert_eq "local commit not yet on the remote" 1 "$(git -C "$WORK" rev-list --count origin/main..HEAD)"
rc=0; AGENT_PLUGINS_SKIP_PUSH=1 agent_plugins_push "$WORK" || rc=$?
assert_eq "skip-push returns 0" "0" "$rc"
assert_eq "skip-push leaves the remote behind" "$before" "$(git -C "$BARE" rev-parse main)"
rc=0; out="$(agent_plugins_push "$WORK" 2>&1)" || rc=$?
assert_eq "push of a clean, ahead checkout returns 0" "0" "$rc"
assert_eq "push reaches the remote" "$(git -C "$WORK" rev-parse HEAD)" "$(git -C "$BARE" rev-parse main)"
assert_contains "push reported" "$out" "Pushed 1 commit(s) to origin/main"
rc=0; out="$(agent_plugins_push "$WORK" 2>&1)" || rc=$?
assert_eq "nothing unpushed: returns 0" "0" "$rc"
assert_eq "nothing unpushed: says nothing" "" "$out"

# A push that does not land (a remote hook rejects it) fails loudly.
cat >"$BARE/hooks/pre-receive" <<'HOOK'
#!/usr/bin/env bash
echo "rejected by test hook" >&2
exit 1
HOOK
chmod +x "$BARE/hooks/pre-receive"
echo rejected >"$WORK/m.json"; agent_plugins_commit_paths "$WORK" "Bump again" m.json
rc=0; out="$(bash -c 'set -euo pipefail; source "$1"; agent_plugins_push "$2"' _ "$LIB" "$WORK" 2>&1)" || rc=$?
assert_eq "rejected push fails" "1" "$rc"
assert_contains "remote rejection surfaced" "$out" "rejected by test hook"
rm -f "$BARE/hooks/pre-receive"

# A push reported as successful but not visible on the remote branch fails the check.
REAL_GIT="$(command -v git)"
tl_stub git "if [[ \" \$* \" == *' push '* ]]; then exit 0; fi; exec '$REAL_GIT' \"\$@\""
hash -r
rc=0; out="$(agent_plugins_push "$WORK" 2>&1)" || rc=$?
assert_eq "push that did not land fails" "1" "$rc"
assert_contains "missing push explained" "$out" "the push to origin/main did not land: the remote branch is at $(git -C "$BARE" rev-parse main), expected $(git -C "$WORK" rev-parse HEAD)"
rm -f "$TL_BIN/git"; hash -r

# Publishable: an upstream to push to and no unpushed commits of anyone else's.
rc=0; out="$(agent_plugins_check_publishable "$WORK" 2>&1)" || rc=$?
assert_eq "unpushed commit refused" "1" "$rc"
assert_contains "unpushed commit explained" "$out" "$WORK has 1 unpushed commit(s) on top of origin/main"
git -C "$WORK" push -q origin main
rc=0; agent_plugins_check_publishable "$WORK" || rc=$?
assert_eq "pushed checkout is publishable" "0" "$rc"

# A remote that cannot be fetched is an error, not a silent comparison with a stale ref.
git -C "$WORK" remote set-url origin "$TL_TMP/does-not-exist.git"
rc=0; out="$(agent_plugins_check_publishable "$WORK" 2>&1)" || rc=$?
assert_eq "unreachable remote: not publishable" "1" "$rc"
assert_contains "unreachable remote explained" "$out" "could not fetch origin/main"
git -C "$WORK" remote set-url origin "$BARE"

# The release tag must be on origin too, unless a batch wrapper already checked it.
TAGSRC="$TL_TMP/tagsrc"; tl_git_repo "$TAGSRC"
TAGORIGIN="$TL_TMP/tagorigin.git"; git init -q --bare "$TAGORIGIN"
git -C "$TAGSRC" remote add origin "$TAGORIGIN"
git -C "$TAGSRC" tag -a v3.0.0 -m r
rc=0; out="$(agent_plugins_require_tag_on_origin "$TAGSRC" 3.0.0 2>&1)" || rc=$?
assert_eq "tag only local: refused" "1" "$rc"
assert_contains "tag only local explained" "$out" "release tag v3.0.0 is not on origin"
rc=0; AGENT_PLUGINS_SKIP_PUSH=1 agent_plugins_require_tag_on_origin "$TAGSRC" 3.0.0 || rc=$?
assert_eq "batch mode leaves the origin check to the wrapper" "0" "$rc"
rc=0; out="$(agent_plugins_require_tag_on_origin "$TAGSRC" 9.9.9 2>&1)" || rc=$?
assert_eq "tag missing everywhere: refused" "1" "$rc"
NOORIGIN="$TL_TMP/noorigin"; tl_git_repo "$NOORIGIN"; git -C "$NOORIGIN" tag -a v3.0.0 -m r
rc=0; out="$(agent_plugins_require_tag_on_origin "$NOORIGIN" 3.0.0 2>&1)" || rc=$?
assert_eq "no origin at all: refused" "1" "$rc"
git -C "$TAGSRC" push -q origin v3.0.0
rc=0; agent_plugins_require_tag_on_origin "$TAGSRC" 3.0.0 || rc=$?
assert_eq "tag on origin: accepted" "0" "$rc"

# A checkout behind its remote is fast-forwarded; a diverged one is refused (nothing is
# committed on top of a stale base that the push would then reject).
git -C "$WORK" push -q origin main
BEHIND="$TL_TMP/behind"; git clone -q "$BARE" "$BEHIND"
ADV="$TL_TMP/adv"; git clone -q "$BARE" "$ADV"
git -C "$ADV" -c user.name=t -c user.email=t@e.invalid commit -q --allow-empty -m advance
git -C "$ADV" push -q origin main
rc=0; agent_plugins_check_publishable "$BEHIND" || rc=$?
assert_eq "behind checkout is publishable after a fast-forward" "0" "$rc"
assert_eq "behind checkout now at the remote head" "$(git -C "$ADV" rev-parse HEAD)" "$(git -C "$BEHIND" rev-parse HEAD)"
git -C "$ADV" -c user.name=t -c user.email=t@e.invalid commit -q --allow-empty -m advance2
git -C "$ADV" push -q origin main
git -C "$BEHIND" -c user.name=t -c user.email=t@e.invalid commit -q --allow-empty -m local-only
rc=0; out="$(agent_plugins_check_publishable "$BEHIND" 2>&1)" || rc=$?
assert_eq "diverged checkout refused" "1" "$rc"
assert_contains "diverged checkout explained" "$out" "is behind origin/main and cannot be fast-forwarded"

# CI gate: green lets the publish through, red names the version and refuses.
CIREPO="$TL_TMP/cirepo"; tl_git_repo "$CIREPO"; git -C "$CIREPO" tag -a v4.0.0 -m r
rc=0; AGENT_PLUGINS_SKIP_PUSH=1 agent_plugins_require_green_ci "$CIREPO" 4.0.0 || rc=$?
assert_eq "batch mode leaves CI to the wrapper" "0" "$rc"
rc=0; out="$(agent_plugins_require_green_ci "$CIREPO" 9.9.9 2>&1)" || rc=$?
assert_eq "no tag: CI check refused" "1" "$rc"

NOUP="$TL_TMP/noup"
tl_git_repo "$NOUP"
rc=0; out="$(agent_plugins_check_publishable "$NOUP" 2>&1)" || rc=$?
assert_eq "no upstream: not publishable" "1" "$rc"
assert_contains "no upstream explained" "$out" "$NOUP does not track an upstream branch"
rc=0; out="$(agent_plugins_push "$NOUP" 2>&1)" || rc=$?
assert_eq "no upstream: push refused" "1" "$rc"

# --- JSON rewrite: atomic, in place, mode kept (R13-28) ---
JSONF="$TL_TMP/json/m.json"
mkdir -p "$TL_TMP/json"
printf '{"v": 1}\n' >"$JSONF"
chmod 644 "$JSONF"
rc=0; agent_plugins_json_rewrite "$JSONF" --arg v 2 '.v = ($v | tonumber)' || rc=$?
assert_eq "rewrite returns 0" "0" "$rc"
assert_eq "rewrite applied" "2" "$(jq -r .v "$JSONF")"
assert_eq "rewrite keeps mode 644" "644" "$(stat -c %a "$JSONF" 2>/dev/null || stat -f %Lp "$JSONF")"
chmod 640 "$JSONF"
agent_plugins_json_rewrite "$JSONF" '.w = true'
assert_eq "rewrite keeps mode 640" "640" "$(stat -c %a "$JSONF" 2>/dev/null || stat -f %Lp "$JSONF")"
assert_eq "no temporary file left" "m.json" "$(ls -A "$TL_TMP/json")"
before_json="$(<"$JSONF")"
rc=0; agent_plugins_json_rewrite "$JSONF" '.v |= error("boom")' 2>/dev/null || rc=$?
assert_eq "failing filter returns 1" "1" "$rc"
assert_eq "failing filter leaves the file byte-identical" "$before_json" "$(<"$JSONF")"
assert_eq "failing filter leaves no temporary file" "m.json" "$(ls -A "$TL_TMP/json")"

# --- argument parsing shared by the per-host sync scripts ---
agent_plugins_parse_sync_args
assert_eq "no args: in-repo mode" "0" "$AGENT_PLUGINS_PUBLISH"
assert_eq "no args: no version" "" "$AGENT_PLUGINS_VERSION"
agent_plugins_parse_sync_args --publish v2.0.0
assert_eq "--publish sets publish mode" "1" "$AGENT_PLUGINS_PUBLISH"
assert_eq "--publish keeps the version" "v2.0.0" "$AGENT_PLUGINS_VERSION"
agent_plugins_parse_sync_args 2.0.0
assert_eq "version alone: in-repo mode" "0" "$AGENT_PLUGINS_PUBLISH"
rc=0; out="$(agent_plugins_parse_sync_args --bogus 2>&1)" || rc=$?
assert_eq "unknown option refused" "1" "$rc"
assert_contains "unknown option named" "$out" "unknown option: --bogus"
rc=0; out="$(agent_plugins_parse_sync_args 1.0.0 2.0.0 2>&1)" || rc=$?
assert_eq "second version refused" "1" "$rc"
assert_contains "extra argument named" "$out" "unexpected argument: 2.0.0"

# --- release tag lookup ---
TAGREPO="$TL_TMP/tagrepo"
tl_git_repo "$TAGREPO"
rc=0; out="$(agent_plugins_release_tag_commit "$TAGREPO" 2.0.0 2>&1)" || rc=$?
assert_eq "missing tag refused" "1" "$rc"
assert_contains "missing tag explains the release order" "$out" "release tag v2.0.0 does not exist in $TAGREPO"
assert_contains "missing tag names the publish step" "$out" "sync-release-marketplace-versions.sh --publish 2.0.0"
git -C "$TAGREPO" tag -a v2.0.0 -m release
assert_eq "annotated tag resolves to its commit" "$(git -C "$TAGREPO" rev-parse HEAD)" "$(agent_plugins_release_tag_commit "$TAGREPO" 2.0.0)"
git -C "$TAGREPO" tag v3.0.0 "$(git -C "$TAGREPO" rev-parse 'HEAD^{tree}')"
rc=0; agent_plugins_release_tag_commit "$TAGREPO" 3.0.0 >/dev/null 2>&1 || rc=$?
assert_eq "a tag that is not a commit is refused" "1" "$rc"

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
