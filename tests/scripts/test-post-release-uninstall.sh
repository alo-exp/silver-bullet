#!/usr/bin/env bash
# scripts/lib/post-release-uninstall.sh: SB-only uninstall per host in a
# sandboxed HOME, with stubbed claude/codex CLIs.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

LIB="$TL_REPO_ROOT/scripts/lib/post-release-uninstall.sh"
export SB_POST_RELEASE_REPO_ROOT="$TL_REPO_ROOT"
export REPO_ROOT="$TL_REPO_ROOT"
export CURSOR_HOME="$HOME/.cursor"
export CLAUDE_HOME="$HOME/.claude"
unset CODEX_HOME_ROOT CLAUDE_BIN

# Each case runs in a fresh bash that sources the library.
uninstall() { tl_run bash -c 'source "$1"; shift; sb_post_release_uninstall_host "$@"' _ "$LIB" "$@"; }

# ---- dispatcher
uninstall bogus
assert_eq "unknown host exits 2" 2 "$TL_STATUS"
assert_contains "unknown host named" "$TL_ERR" "ERROR: unknown host bogus"

# ---- double sourcing is a no-op
tl_run bash -c 'source "$1"; source "$1"; declare -F sb_post_release_uninstall_cursor >/dev/null && echo loaded' _ "$LIB"
assert_eq "second source returns cleanly" "loaded" "$TL_OUT"

# ---- the already-loaded guard also holds when the file is executed
tl_run env _SB_POST_RELEASE_UNINSTALL_LOADED=1 bash "$LIB"
assert_eq "already-loaded guard exits 0 when executed" 0 "$TL_STATUS"

# ---- cursor
for d in alo-labs alo-labs-agent-plugins alo-labs-cursor; do mkdir -p "$CURSOR_HOME/plugins/cache/$d/silver-bullet/1.0"; done
mkdir -p "$CURSOR_HOME/plugins/cache/alo-labs/other-plugin" "$CURSOR_HOME/.silver-bullet"
for f in site-session.json site-visual-evidence.json site-vloops.json agent-delegation-active.json subagent-spawns.jsonl live-publish-evidence.json pending-completion-audit.json keep-me.json; do
  echo x >"$CURSOR_HOME/.silver-bullet/$f"
done
cat >"$CURSOR_HOME/hooks.json" <<'JSON'
{"version":1,"hooks":{"preToolUse":[
 {"command":"/home/u/.cursor/plugins/cache/alo-labs/silver-bullet/1.2.3/hooks/x.sh"},
 {"command":"/usr/local/bin/rtk hook"}]}}
JSON
uninstall cursor
assert_eq "cursor uninstall exits 0" 0 "$TL_STATUS"
assert_contains "cursor uninstall reports" "$TL_OUT" "uninstall: cursor SB cache + hooks stripped"
for d in alo-labs alo-labs-agent-plugins alo-labs-cursor; do assert_file_absent "cursor cache $d removed" "$CURSOR_HOME/plugins/cache/$d/silver-bullet"; done
assert_file_exists "other plugin cache preserved" "$CURSOR_HOME/plugins/cache/alo-labs/other-plugin"
assert_file_absent "site session state removed" "$CURSOR_HOME/.silver-bullet/site-session.json"
assert_file_absent "pending completion audit removed" "$CURSOR_HOME/.silver-bullet/pending-completion-audit.json"
assert_file_exists "unrelated state file preserved" "$CURSOR_HOME/.silver-bullet/keep-me.json"
HOOKS="$(<"$CURSOR_HOME/hooks.json")"
assert_not_contains "SB hook stripped" "$HOOKS" "silver-bullet"
assert_contains "foreign hook preserved" "$HOOKS" "/usr/local/bin/rtk hook"
uninstall cursor
assert_eq "cursor uninstall is idempotent" 0 "$TL_STATUS"

# removal failures are tolerated (rm unavailable)
REAL_RM="$(command -v rm)"
mkdir -p "$CURSOR_HOME/plugins/cache/alo-labs/silver-bullet"
tl_stub rm 'exit 1'
uninstall cursor
assert_eq "cursor uninstall tolerates failing rm" 0 "$TL_STATUS"
uninstall claude
assert_eq "claude uninstall tolerates failing rm" 0 "$TL_STATUS"
"$REAL_RM" -f "$TL_BIN/rm"

# strip helper missing -> error and failure
mkdir -p "$TL_TMP/norepo"
tl_run env SB_POST_RELEASE_REPO_ROOT="$TL_TMP/norepo" bash -c 'source "$1"; sb_post_release_uninstall_cursor' _ "$LIB"
assert_eq "missing strip helper fails" 1 "$TL_STATUS"
assert_contains "missing strip helper reported" "$TL_ERR" "ERROR: missing $TL_TMP/norepo/scripts/lib/strip-cursor-sb-hooks.py"

# ---- codex
CX="$HOME/.codex"
mkdir -p "$CX/skills/silver-quality-gates" "$CX/skills/unrelated-skill" "$HOME/.agents/skills/silver-plan" \
  "$CX/plugins/cache/alo-labs-codex/silver-bullet/1.0" "$CX/plugins/cache/silver-bullet-local/silver-bullet/1.0" "$CX/plugins/cache/alo-labs-codex/other"
cat >"$CX/hooks.json" <<'JSON'
{"hooks":{"PreToolUse":[{"hooks":[{"command":"/x/silver-bullet/1.0/hooks/a.sh"},{"command":"/usr/bin/keep"}]}],"Stop":[{"hooks":[{"command":"/y/silver-bullet/hooks/b.sh"}]}]}}
JSON
printf '[model]\nname = "x"\n\n[hooks.state."silver-bullet@alo-labs-codex:a"]\ntrusted = true\n\n[other]\nk = 1\n' >"$CX/config.toml"
uninstall codex
assert_eq "codex uninstall exits 0 without a codex CLI" 0 "$TL_STATUS"
assert_contains "codex uninstall reports" "$TL_OUT" "uninstall: codex SB cache, skills, hooks stripped"
assert_contains "legacy skill removal reported" "$TL_OUT" "Removed legacy skill: $CX/skills/silver-quality-gates"
assert_file_absent "standalone SB skill removed" "$CX/skills/silver-quality-gates"
assert_file_absent "agents SB skill removed" "$HOME/.agents/skills/silver-plan"
assert_file_exists "unrelated skill preserved" "$CX/skills/unrelated-skill"
assert_file_absent "codex plugin cache removed" "$CX/plugins/cache/alo-labs-codex/silver-bullet"
assert_file_absent "local codex plugin cache removed" "$CX/plugins/cache/silver-bullet-local/silver-bullet"
assert_file_exists "foreign codex cache preserved" "$CX/plugins/cache/alo-labs-codex/other"
assert_eq "SB hooks stripped, foreign kept" '["/usr/bin/keep"]' "$(jq -c '[.. | .command? // empty]' "$CX/hooks.json")"
assert_not_contains "hook state stripped from config" "$(<"$CX/config.toml")" "hooks.state"
assert_contains "other config tables preserved" "$(<"$CX/config.toml")" "[other]"
# CODEX_HOME_ROOT is honoured
mkdir -p "$TL_TMP/alt/.codex/plugins/cache/alo-labs-codex/silver-bullet"
tl_run env CODEX_HOME_ROOT="$TL_TMP/alt" bash -c 'source "$1"; sb_post_release_uninstall_codex' _ "$LIB"
assert_file_absent "alternate codex home cache removed" "$TL_TMP/alt/.codex/plugins/cache/alo-labs-codex/silver-bullet"

# codex CLI present: remove, then uninstall fallback when remove fails
tl_stub codex 'echo "codex $*" >>"'"$TL_TMP"'/codex.log"; [[ "$2" == remove ]] && exit 1; exit 0'
uninstall codex
assert_eq "codex uninstall with CLI exits 0" 0 "$TL_STATUS"
CODEX_LOG="$(<"$TL_TMP/codex.log")"
assert_contains "plugin remove attempted" "$CODEX_LOG" "codex plugin remove silver-bullet@alo-labs-codex"
assert_contains "plugin uninstall used as fallback" "$CODEX_LOG" "codex plugin uninstall silver-bullet@alo-labs-codex"
tl_stub codex 'exit 1'
uninstall codex
assert_eq "failing codex CLI tolerated" 0 "$TL_STATUS"
rm -f "$TL_BIN/codex"

# ---- claude
CL="$HOME/.claude/plugins/cache"
mkdir -p "$CL/alo-labs/silver-bullet/1.0" "$CL/alo-labs-claude/silver-bullet" "$CL/alo-labs/other"
uninstall claude
assert_eq "claude uninstall exits 0 without a CLI" 0 "$TL_STATUS"
assert_contains "claude uninstall reports" "$TL_OUT" "uninstall: claude SB plugin + cache removed"
assert_file_absent "claude cache removed" "$CL/alo-labs/silver-bullet"
assert_file_absent "claude-alias cache removed" "$CL/alo-labs-claude/silver-bullet"
assert_file_exists "foreign claude plugin preserved" "$CL/alo-labs/other"
tl_stub claude 'echo "claude $*" >>"'"$TL_TMP"'/claude.log"; exit 1'
uninstall claude
assert_eq "failing claude CLI tolerated" 0 "$TL_STATUS"
CLAUDE_LOG="$(<"$TL_TMP/claude.log")"
for id in silver-bullet@alo-labs silver-bullet@alo-labs-claude; do
  for scope in user project local; do
    assert_contains "uninstall $id --scope $scope" "$CLAUDE_LOG" "claude plugin uninstall $id --scope $scope"
  done
done

tl_results
