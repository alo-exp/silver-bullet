#!/usr/bin/env bash
# scripts/install-global-toolstack.sh and scripts/lib/global-toolstack/install-body.sh:
# staging into ~/.cursor, config/rules sync, backups and the reconciler hand-off.
# Runs against a fake repo checkout with a stub installer library; nothing is
# installed for real and every write stays inside the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/toolstack-helpers.sh"
tl_init
source "$TL_REPO_ROOT/tests/lib/consent-helpers.sh"
sb_test_consent_grant_all   # the user said yes to every tool (docs/CONSENT.md)
tl_stub cursor 'exit 0'     # Cursor is installed

CUR="$HOME/.cursor"
TSD="$CUR/hooks/toolstack"
tl_stub date 'echo 20260101T000000'

make_fake_repo() { # <dir> [with-installer=1] [with-rules=1]
  local f="$1"
  rm -rf "$f"
  mkdir -p "$f/scripts/lib"
  cp "$TL_REPO_ROOT/scripts/install-global-toolstack.sh" "$f/scripts/"
  cp "$TL_REPO_ROOT/scripts/lib/sb_host_config.py" "$f/scripts/lib/"
  mkdir -p "$f/hooks"
  ln -s "$TL_REPO_ROOT/hooks/lib" "$f/hooks/lib"
  cp -R "$TS_SRC" "$f/scripts/lib/global-toolstack"
  cp -R "$TL_REPO_ROOT/scripts/lib/five_tool_runtime" "$f/scripts/lib/five_tool_runtime"
  if [[ "${2:-1}" == 1 ]]; then
    mkdir -p "$f/scripts/lib/recommended-tools"
    cat >"$f/scripts/lib/recommended-tools/installer.sh" <<'INST'
rt_installer_post_install() {
  printf '%s|%s|%s|%s\n' "$1" "$2" "${TOOLSTACK_REPO_ROOT:-}" "${SB_RECONCILE_PROJECT_ROOT:-}" >>"$HOME/post-install.log"
  return "${POST_RC:-0}"
}
INST
  fi
  if [[ "${3:-1}" == 1 ]]; then
    mkdir -p "$f/.cursor/rules"
    local r
    for r in graphify agentmemory leanctx context-mode token-compression-enforcement; do printf 'rule %s\n' "$r" >"$f/.cursor/rules/$r.mdc"; done
    printf 'other\n' >"$f/.cursor/rules/unrelated.mdc"
  fi
}

# ===== entry script =====
FAKE="$TL_TMP/fake"
make_fake_repo "$FAKE"
ENTRY="$FAKE/scripts/install-global-toolstack.sh"

tl_run bash "$ENTRY" --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help usage" "$TL_OUT" "Usage: bash scripts/install-global-toolstack.sh [--project-root PATH] [--force]"
assert_file_absent "--help does not touch HOME" "$CUR"
tl_run bash "$ENTRY" -h
assert_eq "-h exits 0" 0 "$TL_STATUS"

proj="$TL_TMP/proj"
mkdir -p "$proj"
printf '{}' >"$proj/.silver-bullet.json"
rm -f "$HOME/post-install.log"
tl_run bash "$ENTRY" --bogus --project-root "$proj" extra
assert_eq "install exits 0" 0 "$TL_STATUS"
assert_contains "completion banner" "$TL_OUT" "== Global toolstack install complete =="
assert_contains "verify hint" "$TL_OUT" "Run: bash $TSD/parity-verify.sh && bash $TSD/verify.sh"
assert_contains "backup hint uses stamp" "$TL_OUT" "Backups: hooks.json.bak.20260101T000000 mcp.json.bak.20260101T000000"

# staging
assert_file_exists "common.sh staged under lib/" "$TSD/lib/common.sh"
assert_file_absent "common.sh not staged at top level" "$TSD/common.sh"
assert_eq "install-body deployed as install.sh" "$(cat "$FAKE/scripts/lib/global-toolstack/install-body.sh")" "$(cat "$TSD/install.sh")"
assert_file_exists "gate staged" "$TSD/graphify-gate.sh"
[[ -x "$TSD/graphify-gate.sh" ]] && tl_pass "gate staged executable" || tl_fail "gate staged executable"
[[ -x "$TSD/install.sh" ]] && tl_pass "install.sh executable" || tl_fail "install.sh executable"
[[ -x "$TSD/parity-verify.sh" && -x "$TSD/verify.sh" ]] && tl_pass "verify scripts executable" || tl_fail "verify scripts executable"
assert_file_exists "python helper staged" "$TSD/patch-mcp.py"
assert_file_exists "fix-shell-compression-hook.py staged" "$TSD/fix-shell-compression-hook.py"
assert_file_exists "generic runtime staged" "$TSD/lib/five_tool_runtime/runtime.py"
assert_file_absent "typescript sources are not staged" "$TSD/opencode-rtk-plugin.ts"
assert_file_exists "state dir created" "$CUR/state/toolstack"
assert_eq "repo root recorded" "$FAKE" "$(cat "$CUR/state/toolstack/repo-root")"
assert_eq "toolstack.json profile" five_tool_routed "$(jq -r .profile "$CUR/toolstack.json")"
assert_eq "toolstack.json enforcement" always "$(jq -r .enforcement "$CUR/toolstack.json")"
assert_eq "toolstack.json sb_wire route" leanctx "$(jq -r .routes.sb_wire "$CUR/toolstack.json")"
assert_eq "toolstack.json graphify required" true "$(jq -r .tools.graphify.required "$CUR/toolstack.json")"

assert_file_exists "the config writers' helper module is staged beside them" "$TSD/sb_host_config.py"

# rules
assert_eq "repo rule copied" "rule graphify" "$(cat "$CUR/rules/graphify.mdc")"
assert_file_exists "all five rules copied" "$CUR/rules/token-compression-enforcement.mdc"
assert_file_absent "unrelated rules ignored" "$CUR/rules/unrelated.mdc"
assert_eq "global recommended-tools rule installed" "$(cat "$TS_SRC/global-recommended-tools.mdc")" "$(cat "$CUR/rules/recommended-tools.mdc")"

# reconciler hand-off through the deployed copy
assert_eq "post-install gets repo root, project root, env" "$FAKE|$proj|$FAKE|$proj" "$(cat "$HOME/post-install.log")"

# second run with backups of existing configs
printf '{"h":1}' >"$CUR/hooks.json"
printf '{"m":1}' >"$CUR/mcp.json"
tl_run bash "$ENTRY"
assert_eq "re-install exits 0" 0 "$TL_STATUS"
assert_eq "hooks.json backed up" '{"h":1}' "$(cat "$CUR/hooks.json.bak.20260101T000000")"
assert_eq "mcp.json backed up" '{"m":1}' "$(cat "$CUR/mcp.json.bak.20260101T000000")"

# SB_RECONCILE_PROJECT_ROOT env is honoured by the entry script
rm -f "$HOME/post-install.log"
SB_RECONCILE_PROJECT_ROOT="$proj" tl_run bash "$ENTRY"
assert_eq "env project root forwarded" "$FAKE|$proj|$FAKE|$proj" "$(cat "$HOME/post-install.log")"

# ===== consent, host check, and a user's own toolstack.json (R6-12) =====
rm -rf "$CUR"
sb_test_consent_revoke_all
tl_run bash "$ENTRY"
assert_eq "no consent: exits 0" 0 "$TL_STATUS"
assert_contains "no consent: says why and how to grant" "$TL_OUT" "no tool has your 'wire' consent"
assert_contains "no consent: grant command" "$TL_OUT" "sb-consent.sh grant <tool> --all-projects --capabilities wire"
assert_file_absent "no consent: nothing written under ~/.cursor" "$CUR"

sb_test_consent_grant rtk wire
rm -f "$TL_BIN/cursor"
tl_run bash "$ENTRY"
assert_eq "no Cursor: exits 0" 0 "$TL_STATUS"
assert_contains "no Cursor: skipped" "$TL_OUT" "Cursor is not installed"
assert_file_absent "no Cursor: nothing written" "$CUR"
tl_run bash "$ENTRY" --force
assert_contains "--force installs without Cursor" "$TL_OUT" "Global toolstack install complete"
assert_eq "enforcement is on when a tool is wired" always "$(jq -r .enforcement "$CUR/toolstack.json")"
assert_eq "wired rtk is required" true "$(jq -r .tools.rtk.required "$CUR/toolstack.json")"
assert_eq "a tool without consent is not required" false "$(jq -r .tools.graphify.required "$CUR/toolstack.json")"

# the user's toolstack.json is theirs: a re-install keeps it
jq '.enforcement = "off" | .tools.rtk.usage_ttl_seconds = 77' "$CUR/toolstack.json" >"$CUR/t.new" && mv "$CUR/t.new" "$CUR/toolstack.json"
tl_run bash "$ENTRY" --force
assert_contains "existing toolstack.json is kept" "$TL_OUT" "KEEP: $CUR/toolstack.json exists"
assert_eq "user enforcement kept" off "$(jq -r .enforcement "$CUR/toolstack.json")"
assert_eq "user ttl kept" 77 "$(jq -r .tools.rtk.usage_ttl_seconds "$CUR/toolstack.json")"

# no tool consented at install time of body: enforcement off
rm -f "$CUR/toolstack.json"
sb_test_consent_revoke_all
sb_test_consent_grant rtk install
tl_run env TOOLSTACK_REPO_ROOT="$FAKE" bash "$TSD/install.sh"
assert_eq "no wire consent: enforcement off" off "$(jq -r .enforcement "$CUR/toolstack.json")"
assert_eq "no wire consent: nothing required" false "$(jq -r '[.tools[].required] | any' "$CUR/toolstack.json")"

# rules the installer overwrites keep the previous content once
sb_test_consent_grant_all
tl_stub cursor 'exit 0'
printf 'my own graphify rule\n' >"$CUR/rules/graphify.mdc"
tl_run bash "$ENTRY"
assert_eq "the user's differing rule is backed up" "my own graphify rule" "$(cat "$CUR/rules/graphify.mdc.sb-backup")"
assert_eq "the Silver Bullet rule is installed" "rule graphify" "$(cat "$CUR/rules/graphify.mdc")"

# a rule that is a symlink into the user's dotfiles is updated through the link, with a backup
sb_test_consent_grant_all
tl_stub cursor 'exit 0'
mkdir -p "$TL_TMP/dotfiles"
printf 'dotfile graphify rule\n' >"$TL_TMP/dotfiles/graphify.mdc"
rm -f "$CUR/rules/graphify.mdc" "$CUR/rules/graphify.mdc.sb-backup"
ln -s "$TL_TMP/dotfiles/graphify.mdc" "$CUR/rules/graphify.mdc"
tl_run bash "$ENTRY"
assert_eq "a symlinked rule stays a symlink" "yes" "$([[ -L "$CUR/rules/graphify.mdc" ]] && echo yes || echo no)"
assert_eq "the link target got the Silver Bullet rule" "rule graphify" "$(cat "$TL_TMP/dotfiles/graphify.mdc")"
assert_eq "and its previous content is backed up beside the link" "dotfile graphify rule" "$(cat "$CUR/rules/graphify.mdc.sb-backup")"

# without a recorded or given repository root there is no consent library: nothing is wired or required
rm -f "$CUR/toolstack.json" "$CUR/state/toolstack/repo-root"
tl_run env -u TOOLSTACK_REPO_ROOT bash "$TSD/install.sh"
assert_eq "an install without a repository root still completes" 0 "$TL_STATUS"
assert_eq "without the consent library nothing is required" false "$(jq -r '[.tools[].required] | any' "$CUR/toolstack.json")"
assert_eq "and enforcement is off" off "$(jq -r .enforcement "$CUR/toolstack.json")"

# ===== entry script: copy failures are tolerated =====
rm -rf "$CUR"
REAL_CP="$(command -v cp)"
tl_stub cp "case \"\$*\" in *graphify-gate.sh*|*patch-mcp.py*|*global-recommended-tools.mdc*) exit 1;; esac; exec $REAL_CP \"\$@\""
tl_run bash "$ENTRY"
assert_eq "entry tolerates failing copies" 0 "$TL_STATUS"
assert_contains "entry still completes" "$TL_OUT" "Global toolstack install complete"
assert_file_absent "failed .sh copy leaves nothing" "$TSD/graphify-gate.sh"
assert_file_absent "failed .py copy leaves nothing" "$TSD/patch-mcp.py"
assert_file_exists "other files still staged" "$TSD/rtk-gate.sh"
rm -f "$TL_BIN/cp"
tl_stub chmod 'exit 1'
tl_run bash "$ENTRY"
assert_eq "entry tolerates failing chmod" 0 "$TL_STATUS"
rm -f "$TL_BIN/chmod"

# ===== install-body.sh run from the repo tree =====
BODY="$FAKE/scripts/lib/global-toolstack/install-body.sh"
rm -rf "$CUR" "$HOME/post-install.log"
tl_run bash "$BODY"
assert_eq "repo-mode install exits 0" 0 "$TL_STATUS"
assert_eq "repo-mode records repo root" "$FAKE" "$(cat "$CUR/state/toolstack/repo-root")"
assert_eq "repo-mode: no project root => empty" "$FAKE|||" "$(cat "$HOME/post-install.log")"
assert_file_exists "repo-mode self-deploys install.sh" "$TSD/install.sh"
assert_file_exists "repo-mode stages gates" "$TSD/rtk-gate.sh"
assert_file_exists "repo-mode stages common.sh" "$TSD/lib/common.sh"

# existing hooks.json / mcp.json are backed up; a project root with SB config is resolved
printf '{"h":2}' >"$CUR/hooks.json"
printf '{"m":2}' >"$CUR/mcp.json"
rm -f "$HOME/post-install.log"
SB_RECONCILE_PROJECT_ROOT="$proj" tl_run bash "$BODY"
assert_eq "repo-mode backs up hooks.json" '{"h":2}' "$(cat "$CUR/hooks.json.bak.20260101T000000")"
assert_eq "repo-mode backs up mcp.json" '{"m":2}' "$(cat "$CUR/mcp.json.bak.20260101T000000")"
assert_eq "repo-mode passes resolved project root" "$FAKE|$proj||$proj" "$(cat "$HOME/post-install.log")"
ln -s "$proj" "$TL_TMP/proj-link"
rm -f "$HOME/post-install.log"
SB_RECONCILE_PROJECT_ROOT="$TL_TMP/proj-link" tl_run bash "$BODY"
assert_eq "project root is canonicalised (pwd -P)" "$FAKE|$proj||$TL_TMP/proj-link" "$(cat "$HOME/post-install.log")"

# project root without .silver-bullet.json is ignored
rm -f "$HOME/post-install.log"
SB_RECONCILE_PROJECT_ROOT="$TL_TMP/nothing-here" tl_run bash "$BODY"
assert_eq "project root without SB config ignored" "$FAKE|||$TL_TMP/nothing-here" "$(cat "$HOME/post-install.log")"

# post-install failure only warns
rm -f "$HOME/post-install.log"
POST_RC=3 tl_run bash "$BODY"
assert_eq "post-install failure keeps exit 0" 0 "$TL_STATUS"
assert_contains "post-install failure warns" "$TL_ERR" "WARN: reconciler post-install exited nonzero"
assert_contains "still prints completion" "$TL_OUT" "Global toolstack install complete"

# graphify cursor install is attempted when graphify exists, failure ignored
tl_stub graphify 'echo "$*" >>"$HOME/graphify-calls"; exit "${GRAPHIFY_RC:-0}"'
rm -f "$HOME/graphify-calls"
tl_run bash "$BODY"
assert_eq "graphify cursor install called" "cursor install" "$(cat "$HOME/graphify-calls")"
rm -f "$HOME/graphify-calls"
GRAPHIFY_RC=1 tl_run bash "$BODY"
assert_eq "failing graphify cursor install tolerated" 0 "$TL_STATUS"
assert_eq "graphify attempted despite failure" "cursor install" "$(cat "$HOME/graphify-calls")"
rm -f "$TL_BIN/graphify"
rm -f "$HOME/graphify-calls"
tl_run bash "$BODY"
assert_file_absent "no graphify => no cursor install" "$HOME/graphify-calls"

# rules fall back to the script directory when the repo has no .cursor/rules
FAKE2="$TL_TMP/fake2"
make_fake_repo "$FAKE2" 1 0
printf 'from srcdir\n' >"$FAKE2/scripts/lib/global-toolstack/graphify.mdc"
rm -rf "$CUR"
tl_run bash "$FAKE2/scripts/lib/global-toolstack/install-body.sh"
assert_eq "rules fall back to the script dir" "from srcdir" "$(cat "$CUR/rules/graphify.mdc")"
assert_file_absent "missing rule sources skipped" "$CUR/rules/agentmemory.mdc"

# without the global-recommended-tools rule nothing is installed for it
FAKE3="$TL_TMP/fake3"
make_fake_repo "$FAKE3" 1 1
rm "$FAKE3/scripts/lib/global-toolstack/global-recommended-tools.mdc"
rm -rf "$CUR"
tl_run bash "$FAKE3/scripts/lib/global-toolstack/install-body.sh"
assert_file_absent "no global-recommended-tools => no recommended-tools rule" "$CUR/rules/recommended-tools.mdc"

# no installer library anywhere => reconciler step skipped silently
FAKE4="$TL_TMP/fake4"
make_fake_repo "$FAKE4" 0 1
rm -rf "$CUR" "$HOME/post-install.log"
tl_run bash "$FAKE4/scripts/lib/global-toolstack/install-body.sh"
assert_eq "no installer lib: exit 0" 0 "$TL_STATUS"
assert_file_absent "no installer lib: nothing invoked" "$HOME/post-install.log"
assert_not_contains "no installer lib: no warning" "$TL_ERR" "WARN"

# installer library found in the deployed toolstack lib/ when the repo has none
mkdir -p "$TSD/lib/recommended-tools"
cat >"$TSD/lib/recommended-tools/installer.sh" <<'INST'
rt_installer_post_install() { printf 'deployed-lib:%s\n' "$1" >"$HOME/post-install.log"; }
INST
tl_run bash "$FAKE4/scripts/lib/global-toolstack/install-body.sh"
assert_eq "deployed installer lib used as fallback" "deployed-lib:$FAKE4" "$(cat "$HOME/post-install.log")"

# copy/chmod failures in install-body are tolerated up to the unguarded self-deploy
rm -rf "$CUR"
tl_stub cp 'exit 1'
tl_stub chmod 'exit 1'
tl_run bash "$BODY"
assert_contains "failing cp: config still written" "$(cat "$CUR/toolstack.json")" '"profile": "five_tool_routed"'
assert_eq "failing cp: self-deploy copy is unguarded" 1 "$TL_STATUS"
rm -f "$TL_BIN/cp" "$TL_BIN/chmod"

# ===== install-body.sh in deployed mode (copy outside the repo tree) =====
DEP="$TL_TMP/dep/global-toolstack"
mkdir -p "$DEP"
cp "$BODY" "$DEP/install-body.sh"
cp "$TS_SRC/common.sh" "$TS_SRC/graphify-gate.sh" "$DEP/"
rm -rf "$CUR" "$HOME/post-install.log"
mkdir -p "$CUR/state/toolstack"
printf '%s' "$FAKE" >"$CUR/state/toolstack/repo-root"
env -u TOOLSTACK_REPO_ROOT bash -c 'cd "$HOME"; bash "$1"' _ "$DEP/install-body.sh" >"$TL_TMP/dep.out" 2>"$TL_TMP/dep.err" || true
assert_eq "deployed mode picks repo root from state file" "$FAKE|||" "$(cat "$HOME/post-install.log")"
assert_file_exists "deployed mode stages only available files" "$TSD/graphify-gate.sh"
assert_file_absent "deployed mode skips missing files" "$TSD/rtk-gate.sh"
rm -rf "$CUR" "$HOME/post-install.log"
env -u TOOLSTACK_REPO_ROOT bash "$DEP/install-body.sh" >"$TL_TMP/dep.out" 2>"$TL_TMP/dep.err" || true
assert_file_absent "deployed mode without any repo root: no reconciler" "$HOME/post-install.log"
assert_file_absent "deployed mode without repo root: no repo-root file" "$CUR/state/toolstack/repo-root"
TOOLSTACK_REPO_ROOT="$FAKE" bash "$DEP/install-body.sh" >"$TL_TMP/dep.out" 2>"$TL_TMP/dep.err" || true
assert_eq "TOOLSTACK_REPO_ROOT honoured in deployed mode" "$FAKE" "$(cat "$CUR/state/toolstack/repo-root")"

tl_results
