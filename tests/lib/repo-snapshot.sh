# shellcheck shell=bash
# Disposable copies of the Silver Bullet checkout for tests.
#
# Some product scripts deliberately rewrite the checkout they run from:
# sync-codex-package.sh regenerates plugins/silver-bullet, agents/ and
# host-bundles/; install-codex.sh and install-cursor.sh run it, and the Cursor
# installer also records install state (.silver-bullet.json, .e2e-* files).
# A test must not write into the repository under test — test files running in
# parallel race on those trees, and a read-only checkout fails outright — so it
# runs such scripts from a snapshot instead:
#
#   source "$REPO_ROOT/tests/lib/repo-snapshot.sh"
#   SNAP="$(sb_repo_snapshot "$REPO_ROOT" "$TMP/repo")"         # plain copy
#   SNAP="$(sb_repo_snapshot --git "$REPO_ROOT" "$TMP/repo")"   # copy + own git repo
#
# The copy leaves out .git and the large trees no script reads (graphify-out,
# .planning, research, .agentmemory) plus caches and local install artifacts.
# With --git the copy becomes a repository of its own holding a single commit
# with fixed author, committer and dates, so commit-SHA logic works offline and
# never needs the original repository's object store (which another user may
# not be allowed to read). Prints the snapshot path.

sb_repo_snapshot() {
  local with_git=0
  if [[ "${1:-}" == "--git" ]]; then
    with_git=1
    shift
  fi
  local src="${1:?usage: sb_repo_snapshot [--git] <repo-root> <dest>}"
  local dest="${2:?usage: sb_repo_snapshot [--git] <repo-root> <dest>}"

  mkdir -p "$dest" || return 1
  rsync -a \
    --exclude='/.git' \
    --exclude='/graphify-out/' \
    --exclude='/.planning/' \
    --exclude='/research/' \
    --exclude='/.agentmemory/' \
    --exclude='node_modules/' \
    --exclude='__pycache__/' \
    --exclude='.pytest_cache/' \
    --exclude='/.e2e-*' \
    --exclude='*.render.lock' \
    "${src%/}/" "${dest%/}/" || return 1
  # Generated trees may carry 0600 modes written under a restrictive umask;
  # the copy belongs to the test, so make it readable and writable for it.
  chmod -R u+rwX "$dest" || return 1

  if [[ "$with_git" -eq 1 ]]; then
    (
      cd "$dest" || exit 1
      export GIT_AUTHOR_NAME="SB Test" GIT_AUTHOR_EMAIL="sb-test@example.invalid"
      export GIT_COMMITTER_NAME="SB Test" GIT_COMMITTER_EMAIL="sb-test@example.invalid"
      export GIT_AUTHOR_DATE="2026-01-01T00:00:00Z" GIT_COMMITTER_DATE="2026-01-01T00:00:00Z"
      git -c init.defaultBranch=main init -q &&
        git add -A &&
        git -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m "test snapshot"
    ) >/dev/null || return 1
  fi
  printf '%s\n' "$dest"
}
