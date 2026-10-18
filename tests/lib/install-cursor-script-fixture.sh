# shellcheck shell=bash
# Shared fixture for the install-cursor.sh end-to-end tests: a trimmed disposable
# snapshot of the checkout (its own one-commit repository), recording stubs for the
# sub-agent installer and the five-tool reconciler (they have their own suites),
# GitHub replaced by that local repository, and a sandboxed HOME/CURSOR_HOME.
# Source it after tl_init. Provides SNAP, SNAP_SHA, SCRIPT, CALLS, VERSION, CACHE, PROJ and
# the helpers fresh/run; the variables are read by the sourcing tests.
# shellcheck disable=SC2034
# shellcheck source=tests/lib/repo-snapshot.sh
source "$TL_REPO_ROOT/tests/lib/repo-snapshot.sh"
# shellcheck source=tests/lib/offline-tools.sh
source "$TL_REPO_ROOT/tests/lib/offline-tools.sh"
sb_offline_tools_install "$TL_TMP/offline-bin"

SNAP="$(sb_repo_snapshot "$TL_REPO_ROOT" "$TL_TMP/snap")"
for _d in tests docs site agents host-bundles .agentmemory .github research; do rm -rf "${SNAP:?}/$_d"; done
(
  cd "$SNAP" || exit 1
  export GIT_AUTHOR_NAME="SB Test" GIT_AUTHOR_EMAIL="sb-test@example.invalid" GIT_COMMITTER_NAME="SB Test" GIT_COMMITTER_EMAIL="sb-test@example.invalid"
  git -c init.defaultBranch=main init -q
  git config gc.auto 0
  git config maintenance.auto false
  git add -A
  git -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -q -m "test snapshot"
)
SNAP_SHA="$(git -C "$SNAP" rev-parse HEAD)"
SCRIPT="$SNAP/scripts/install-cursor.sh"

# Recording stubs for the two collaborators that have their own suites.
CALLS="$TL_TMP/calls.log"
printf 'rt_installer_post_install() { echo "rt-post-install root=$1 project=${2:-}" >>"%s"; return "${STUB_RT_RC:-0}"; }\n' "$CALLS" \
  >"$SNAP/scripts/lib/recommended-tools/installer.sh"
printf '#!/usr/bin/env bash\necho "csba $* repo=${CSBA_REPO_ROOT:-}" >>"%s"\nexit "${STUB_CSBA_RC:-0}"\n' "$CALLS" \
  >"$SNAP/scripts/install-cursor-sb-agents.sh"
chmod +x "$SNAP/scripts/install-cursor-sb-agents.sh"

export CURSOR_HOME="$HOME/.cursor"
export RT_SKIP_VENDOR_DOCTOR=1
export SB_CURSOR_SB_AGENTS_OFFLINE=1
export CURSOR_MARKETPLACE_ROOT="$CURSOR_HOME/plugins/marketplaces/alo-labs-cursor"
export CURSOR_UNIFIED_MARKETPLACE_SOURCE="$SNAP" CURSOR_AGENT_PLUGINS_REPO_URL="$SNAP" CURSOR_GITHUB_REPO_URL="$SNAP"
PROJ="$TL_TMP/project"
mkdir -p "$PROJ"
unset CSBA_REPO_ROOT

fresh() { rm -rf "${CURSOR_HOME:?}" "${TL_TMP:?}/calls.log"; mkdir -p "$CURSOR_HOME"; : >"$CALLS"; }
run() { tl_run bash "$SCRIPT" "$@"; }
VERSION="$(jq -r .version "$SNAP/package.json")"
CACHE="$CURSOR_HOME/plugins/cache/alo-labs/silver-bullet"

