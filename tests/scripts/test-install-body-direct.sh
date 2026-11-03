#!/usr/bin/env bash
# scripts/lib/global-toolstack/install-body.sh run by its source path (a repository layout and a
# deployed-style layout), so every branch is exercised where it lives: consent-derived toolstack.json,
# the user's toolstack.json kept, rule backups, tolerated copy failures and the reconciler hand-off.
# test-install-global-toolstack.sh covers the entry script and the deployed copy; nothing is installed
# for real and every write stays inside the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/consent-helpers.sh"

CUR="$HOME/.cursor"
TSD="$CUR/hooks/toolstack"
tl_stub date 'echo 20260101T000000'

# A repository checkout: the body, its siblings, the consent library and a reconciler stub.
make_repo() { # <dir> [with-rules=1] [with-installer=1]
  local f="$1"
  rm -rf "$f"
  mkdir -p "$f/scripts/lib" "$f/hooks"
  : >"$f/scripts/install-global-toolstack.sh"
  mkdir -p "$f/scripts/lib/global-toolstack"
  find "$TS_SRC" -maxdepth 1 -type f -exec cp {} "$f/scripts/lib/global-toolstack/" \;
  cp "$TL_REPO_ROOT/scripts/lib/sb_host_config.py" "$f/scripts/lib/"
  ln -s "$TL_REPO_ROOT/hooks/lib" "$f/hooks/lib"
  if [[ "${3:-1}" == 1 ]]; then
    mkdir -p "$f/scripts/lib/recommended-tools"
    cat >"$f/scripts/lib/recommended-tools/installer.sh" <<'INST'
rt_installer_post_install() {
  printf '%s|%s\n' "$1" "$2" >>"$HOME/post-install.log"
  return "${POST_RC:-0}"
}
INST
  fi
  if [[ "${2:-1}" == 1 ]]; then
    mkdir -p "$f/.cursor/rules"
    local r
    for r in graphify agentmemory leanctx context-mode token-compression-enforcement; do printf 'rule %s\n' "$r" >"$f/.cursor/rules/$r.mdc"; done
  fi
}

REPO="$TL_TMP/repo"
make_repo "$REPO"
BODY="$REPO/scripts/lib/global-toolstack/install-body.sh"
proj="$TL_TMP/proj"; mkdir -p "$proj"; printf '{}' >"$proj/.silver-bullet.json"

# ---- repository layout: consent drives toolstack.json ----
sb_test_consent_grant_all
rm -rf "$CUR"; rm -f "$HOME/post-install.log"
printf '{"h":1}' >"$HOME/hooks.json.seed"
mkdir -p "$CUR"; printf '{"h":1}' >"$CUR/hooks.json"; printf '{"m":1}' >"$CUR/mcp.json"
tl_stub graphify 'echo "graphify $*" >>"$HOME/graphify.log"'
tl_run env SB_RECONCILE_PROJECT_ROOT="$proj" bash "$BODY"
assert_eq "repo layout: exits 0" 0 "$TL_STATUS"
assert_contains "repo layout: banner" "$TL_OUT" "== Global toolstack install complete =="
assert_eq "repo layout: repo root recorded" "$REPO" "$(cat "$CUR/state/toolstack/repo-root")"
assert_eq "repo layout: hooks.json backed up" '{"h":1}' "$(cat "$CUR/hooks.json.bak.20260101T000000")"
assert_eq "repo layout: mcp.json backed up" '{"m":1}' "$(cat "$CUR/mcp.json.bak.20260101T000000")"
assert_eq "repo layout: enforcement on" always "$(jq -r .enforcement "$CUR/toolstack.json")"
assert_eq "repo layout: every consented tool required" true "$(jq -r '[.tools[].required] | all' "$CUR/toolstack.json")"
assert_eq "repo layout: graphify cursor install ran (graphify consented)" "graphify cursor install" "$(cat "$HOME/graphify.log")"
assert_eq "repo layout: reconciler hand-off with the project root" "$REPO|$proj" "$(cat "$HOME/post-install.log")"
assert_eq "repo layout: the writers' helper module is staged" "same" "$(cmp -s "$REPO/scripts/lib/sb_host_config.py" "$TSD/sb_host_config.py" && echo same || echo different)"
assert_file_exists "repo layout: install.sh self-deployed" "$TSD/install.sh"
assert_eq "repo layout: rules installed" "rule graphify" "$(cat "$CUR/rules/graphify.mdc")"
assert_eq "repo layout: global variant installed as recommended-tools.mdc" "$(cat "$TS_SRC/global-recommended-tools.mdc")" "$(cat "$CUR/rules/recommended-tools.mdc")"

# ---- a second run: the user's toolstack.json is kept, identical rules are left alone ----
jq '.enforcement = "off"' "$CUR/toolstack.json" >"$CUR/t.new" && mv "$CUR/t.new" "$CUR/toolstack.json"
: >"$HOME/graphify.log"
tl_run bash "$BODY"
assert_contains "second run: existing toolstack.json kept" "$TL_OUT" "KEEP: $CUR/toolstack.json exists - not overwritten"
assert_eq "second run: the user's enforcement setting survives" off "$(jq -r .enforcement "$CUR/toolstack.json")"
assert_eq "second run: no backup of an identical rule" "no" "$([[ -e "$CUR/rules/graphify.mdc.sb-backup" ]] && echo yes || echo no)"

# ---- without consent: nothing required, enforcement off, graphify not touched ----
rm -f "$CUR/toolstack.json"
sb_test_consent_revoke_all
: >"$HOME/graphify.log"
tl_run bash "$BODY"
assert_eq "no consent: enforcement off" off "$(jq -r .enforcement "$CUR/toolstack.json")"
assert_eq "no consent: nothing required" false "$(jq -r '[.tools[].required] | any' "$CUR/toolstack.json")"
assert_eq "no consent: graphify cursor install did not run" "" "$(cat "$HOME/graphify.log")"
sb_test_consent_grant graphify wire
rm -f "$CUR/toolstack.json"
tl_run bash "$BODY"
assert_eq "partial consent: graphify required" true "$(jq -r .tools.graphify.required "$CUR/toolstack.json")"
assert_eq "partial consent: the others are not" false "$(jq -r .tools.rtk.required "$CUR/toolstack.json")"
assert_eq "partial consent: enforcement on" always "$(jq -r .enforcement "$CUR/toolstack.json")"
sb_test_consent_grant_all

# ---- a rule that differs keeps its previous content once ----
printf 'my own\n' >"$CUR/rules/leanctx.mdc"
tl_run bash "$BODY"
assert_eq "differing rule: replaced" "rule leanctx" "$(cat "$CUR/rules/leanctx.mdc")"
assert_eq "differing rule: previous content kept" "my own" "$(cat "$CUR/rules/leanctx.mdc.sb-backup")"
printf 'edited again\n' >"$CUR/rules/leanctx.mdc"
tl_run bash "$BODY"
assert_eq "differing rule: the first backup is not overwritten" "my own" "$(cat "$CUR/rules/leanctx.mdc.sb-backup")"

# ---- the reconciler hand-off failing only warns ----
tl_run env POST_RC=1 bash "$BODY"
assert_eq "post-install failure: exit 0" 0 "$TL_STATUS"
assert_contains "post-install failure: warned" "$TL_ERR" "WARN: reconciler post-install exited nonzero"

# ---- no repository rules bundle: the rules next to the script are used; no installer: nothing to hand off ----
make_repo "$REPO" 0 0
rm -rf "$CUR"; rm -f "$HOME/post-install.log"
tl_run bash "$BODY"
assert_eq "no bundle, no installer: exits 0" 0 "$TL_STATUS"
assert_file_exists "global variant still installed" "$CUR/rules/recommended-tools.mdc"
assert_file_absent "no bundled rule installed" "$CUR/rules/graphify.mdc"
assert_file_absent "no hand-off without an installer library" "$HOME/post-install.log"

# ---- deployed-style layout: not inside a repository, TOOLSTACK_REPO_ROOT names it ----
make_repo "$REPO"
DEP="$TL_TMP/dep/global-toolstack"
mkdir -p "$DEP"
find "$TS_SRC" -maxdepth 1 -type f -exec cp {} "$DEP/" \;
DBODY="$DEP/install-body.sh"
rm -rf "$CUR"
tl_run env TOOLSTACK_REPO_ROOT="$REPO" bash "$DBODY"
assert_eq "deployed layout: exits 0" 0 "$TL_STATUS"
assert_eq "deployed layout: root from TOOLSTACK_REPO_ROOT recorded" "$REPO" "$(cat "$CUR/state/toolstack/repo-root")"
assert_eq "deployed layout: rules come from the repository bundle" "rule graphify" "$(cat "$CUR/rules/graphify.mdc")"
# no env root: the recorded one is used
tl_run env -u TOOLSTACK_REPO_ROOT bash "$DBODY"
assert_eq "recorded root used when the environment names none" "$REPO" "$(cat "$CUR/state/toolstack/repo-root")"
# neither: no consent library, nothing required; the reconciler library deployed beside the scripts is used
rm -rf "$CUR"
mkdir -p "$CUR/hooks/toolstack/lib/recommended-tools"
cat >"$CUR/hooks/toolstack/lib/recommended-tools/installer.sh" <<'INST'
rt_installer_post_install() { printf 'deployed|%s|%s\n' "$1" "$2" >>"$HOME/post-install.log"; }
INST
rm -f "$HOME/post-install.log"
tl_run env -u TOOLSTACK_REPO_ROOT bash "$DBODY"
assert_eq "no root at all: exits 0" 0 "$TL_STATUS"
assert_eq "no root at all: nothing required" false "$(jq -r '[.tools[].required] | any' "$CUR/toolstack.json")"
assert_eq "no root at all: the deployed installer library is used" "deployed||" "$(cat "$HOME/post-install.log")"
assert_file_absent "no root at all: no repo-root record" "$CUR/state/toolstack/repo-root"

# ---- copy and permission failures are tolerated ----
make_repo "$REPO"
rm -rf "$CUR"
tl_stub graphify 'exit 1'
REAL_CP="$(command -v cp)"
tl_stub cp "case \"\$*\" in */lib/common.sh*|*graphify-gate.sh*|*patch-mcp.py*) exit 1;; esac; exec $REAL_CP \"\$@\""
tl_stub chmod 'exit 1'
tl_run bash "$BODY"
assert_eq "failing copies, chmod and graphify do not abort the install" 0 "$TL_STATUS"
assert_contains "and the install still completes" "$TL_OUT" "Global toolstack install complete"
assert_file_absent "the failed gate copy left nothing" "$TSD/graphify-gate.sh"
assert_file_exists "other gates were still copied" "$TSD/rtk-gate.sh"

tl_results
