#!/usr/bin/env bash
# prune-stale-claude-user-hooks.sh removes only stale Silver Bullet hook entries from
# ~/.claude/settings.json: entries whose Silver Bullet hook script no longer exists. The
# user's hooks ($HOME, ${CLAUDE_PROJECT_DIR} and relative paths), other tools' gsd-*.sh and
# every file under ~/.claude/hooks survive (R7-12, R8-16), and nothing else in the settings
# is dropped or corrupted.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/prune-stale-claude-user-hooks.sh"
CH="$TL_TMP/claude-home"
S="$CH/settings.json"
SBC="$CH/plugins/cache/alo-labs/silver-bullet"
mkdir -p "$CH/hooks" "$SBC/1.0.0/hooks" "$HOME/bin"
printf '#!/bin/sh\n' >"$SBC/1.0.0/hooks/stop-check.sh"
STALE="\"$SBC/0.9.0/hooks/stop-check.sh\""   # an old, deleted plugin-cache version
LIVE="\"$SBC/1.0.0/hooks/stop-check.sh\""
cd "$TL_TMP"

run_prune() { tl_run env CLAUDE_HOME="$CH" bash "$SCRIPT"; }
stale_doc() { printf '{"hooks":{"Stop":[{"hooks":[{"command":%s}%s]}]}%s}' "$(jq -Rn --arg c "$STALE" '$c')" "${1:-}" "${2:-}"; }

# --- R7-12 / R8-16: only stale Silver Bullet entries go ----------------------------------------
printf '#!/bin/sh\n' >"$HOME/bin/fmt.sh"
for f in gsd-statusline.sh gsd-session-state.sh my-hook.js; do printf 'x' >"$CH/hooks/$f"; done
jq -n \
  --arg home_js 'node "$HOME/.claude/hooks/my-hook.js"' \
  --arg project 'bash "${CLAUDE_PROJECT_DIR}/.claude/hooks/lint.sh"' \
  --arg home_sh '"$HOME/bin/fmt.sh"' \
  --arg gone "bash \"$CH/hooks/gone-user-script.sh\"" \
  --arg stale "$STALE" --arg live "$LIVE" \
  '{model: "opus", note: "café ☕",
    statusLine: {type: "command", command: "bash ~/.claude/hooks/gsd-statusline.sh"},
    hooks: {
      PreToolUse: [{matcher: "Bash", hooks: [
        {type: "command", command: $home_js}, {type: "command", command: $project},
        {type: "command", command: $home_sh}, {type: "command", command: "bash .claude/hooks/relative.sh"},
        {type: "command", command: $gone}]}],
      SessionStart: [{hooks: [
        {type: "command", command: "bash ~/.claude/hooks/gsd-statusline.sh"},
        {type: "command", command: "bash gsd-session-state.sh"},
        {type: "command", command: $stale}, {type: "command", command: $live},
        {type: "command", command: "\"${CLAUDE_PLUGIN_ROOT}/hooks/session-start\""},
        {type: "command", command: "\"${CLAUDE_PLUGIN_ROOT}/hooks/other-plugin.sh\""}]}]}}' >"$S"
run_prune
assert_eq "prune exits 0" 0 "$TL_STATUS"
assert_contains "the removal is reported with its count" "$TL_ERR" "removed 2 stale Silver Bullet hook(s) from $S"
assert_eq "every user PreToolUse hook kept (\$HOME, \${CLAUDE_PROJECT_DIR}, relative, missing user script)" 5 "$(jq '.hooks.PreToolUse[0].hooks | length' "$S")"
assert_eq "SessionStart keeps the gsd hooks, the live SB hook and other plugins' placeholders" \
  "[\"bash ~/.claude/hooks/gsd-statusline.sh\",\"bash gsd-session-state.sh\",$(jq -Rn --arg c "$LIVE" '$c'),\"\\\"\${CLAUDE_PLUGIN_ROOT}/hooks/other-plugin.sh\\\"\"]" \
  "$(jq -c '[.hooks.SessionStart[0].hooks[].command]' "$S")"
assert_eq "statusLine untouched" '"bash ~/.claude/hooks/gsd-statusline.sh"' "$(jq -c .statusLine.command "$S")"
for f in gsd-statusline.sh gsd-session-state.sh my-hook.js; do
  assert_file_exists "the user's hooks/$f is never deleted" "$CH/hooks/$f"
done
assert_contains "non-ASCII text written verbatim" "$(<"$S")" "café ☕"
assert_eq "unrelated keys preserved" '"opus"' "$(jq -c .model "$S")"
assert_file_exists "the previous settings are backed up" "$S.sb-backup"
cp "$S" "$TL_TMP/settings.after-1"
run_prune
assert_eq "second run exits 0" 0 "$TL_STATUS"
assert_eq "second run leaves the file byte-identical" "$(<"$TL_TMP/settings.after-1")" "$(<"$S")"
assert_not_contains "second run reports nothing" "$TL_ERR" "removed"

# $HOME in an SB path is expanded before judging; a path that cannot be expanded is kept.
rm -f "$S.sb-backup"
jq -n --arg old "\"\$HOME/gone/plugins/cache/alo-labs/silver-bullet/0.1.0/hooks/stop-check.sh\"" \
  --arg unknown "\"\${UNSET_SB_ROOT}/plugins/cache/alo-labs/silver-bullet/0.1.0/hooks/stop-check.sh\"" \
  '{hooks: {Stop: [{hooks: [{command: $old}, {command: $unknown}]}]}}' >"$S"
tl_run env -u UNSET_SB_ROOT CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "an expandable stale SB path is removed, an unexpandable one kept" \
  '["\"${UNSET_SB_ROOT}/plugins/cache/alo-labs/silver-bullet/0.1.0/hooks/stop-check.sh\""]' \
  "$(jq -c '[.hooks.Stop[0].hooks[].command]' "$S")"

# Entries that are not hook groups (no "hooks" list) are foreign data and survive a cleanup
# triggered by a different, stale entry.
jq -n --arg c "$STALE" '{hooks: {SessionStart: [{hooks: [{type: "command", command: $c}]},
  {type: "command", command: "echo flat-legacy-entry"}, {matcher: "startup", hooks: []}]}}' >"$S"
run_prune
assert_eq "mixed file exits 0" 0 "$TL_STATUS"
assert_eq "stale group removed" 0 "$(grep -c '0.9.0' "$S" || true)"
assert_eq "entry without a hooks list preserved" '"echo flat-legacy-entry"' "$(jq -c '.hooks.SessionStart[] | select(.command? != null) | .command' "$S")"
assert_eq "group with an empty hooks list preserved" '"startup"' "$(jq -c '.hooks.SessionStart[] | select(.matcher? != null) | .matcher' "$S")"

# Nothing stale: the file is not rewritten at all.
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"echo hi"}]}]},"a":1}' >"$S"
cp "$S" "$TL_TMP/untouched"
run_prune
assert_eq "clean settings exit 0" 0 "$TL_STATUS"
assert_eq "clean settings byte-identical" "$(<"$TL_TMP/untouched")" "$(<"$S")"

# JSON nulls and settings without a hooks section.
printf '%s' '{"hooks":null,"x":null}' >"$S"
cp "$S" "$TL_TMP/untouched"
run_prune
assert_eq "null hooks section exits 0" 0 "$TL_STATUS"
assert_eq "null hooks section byte-identical" "$(<"$TL_TMP/untouched")" "$(<"$S")"
printf '%s' '{"model":"x"}' >"$S"
run_prune
assert_eq "no hooks section exits 0" 0 "$TL_STATUS"
assert_eq "no hooks section unchanged" '{"model":"x"}' "$(<"$S")"

# Wrong-typed content: clear error, file byte-identical, never a traceback.
check_malformed() {
  local label="$1" content="$2"
  printf '%s' "$content" >"$S"
  cp "$S" "$TL_TMP/before"
  run_prune
  assert_eq "$label: exits non-zero" 1 "$TL_STATUS"
  assert_contains "$label: clear error" "$TL_ERR" "prune-stale-claude-user-hooks: ERROR"
  assert_not_contains "$label: no traceback" "$TL_ERR" "Traceback"
  assert_eq "$label: file byte-identical" "$(<"$TL_TMP/before")" "$(<"$S")"
}
check_malformed "invalid json" 'not json {'
check_malformed "top-level list" '[1,2]'
check_malformed "hooks section is a list" '{"hooks":[1]}'

# Wrong-typed entries inside an event are foreign data: kept as they are, while stale
# siblings are still pruned.
jq -n --arg c "$STALE" '{hooks: {Stop: [{hooks: ["str", {command: $c}]}, {hooks: {a: 1}}, {hooks: null}], Other: "text"}}' >"$S"
run_prune
assert_eq "wrong-typed entries exit 0" 0 "$TL_STATUS"
assert_eq "string hook kept, stale sibling pruned" '["str"]' "$(jq -c '.hooks.Stop[0].hooks' "$S")"
assert_eq "object-valued hooks entry kept" '{"a":1}' "$(jq -c '.hooks.Stop[1].hooks' "$S")"
assert_eq "null-valued hooks entry kept" 'null' "$(jq -c '.hooks.Stop[2].hooks' "$S")"
assert_eq "non-list event kept" '"text"' "$(jq -c '.hooks.Other' "$S")"

# --- exact rewrite bytes -----------------------------------------------------------
stale_doc ',{"command":"echo keep"}' ',"model":"opus"' >"$S"
run_prune
assert_eq "rewrite exits 0" 0 "$TL_STATUS"
printf '{\n  "hooks": {\n    "Stop": [\n      {\n        "hooks": [\n          {\n            "command": "echo keep"\n          }\n        ]\n      }\n    ]\n  },\n  "model": "opus"\n}\n' >"$TL_TMP/expected.json"
assert_eq "rewritten file is indent 2 with one trailing newline" "$(cmp "$TL_TMP/expected.json" "$S" && echo identical)" "identical"

# --- the rewrite normalises the document ---------------------------------------------
stale_doc "" ',"n":2.50,"e":1e3,"d":1,"d":2' >"$S"
run_prune
assert_eq "normalising rewrite exits 0" 0 "$TL_STATUS"
assert_contains "2.50 becomes 2.5" "$(<"$S")" '"n": 2.5,'
assert_contains "1e3 becomes 1000.0" "$(<"$S")" '"e": 1000.0,'
assert_eq "duplicate key keeps the last value, once" '1 2' "$(grep -c '"d"' "$S") $(jq '.d' "$S")"

# --- lone surrogate: the rewrite must never truncate settings.json -------------------
stale_doc "" ',"note":"bad \ud800 here","ok":"café"' >"$S"
run_prune
assert_eq "surrogate settings exit 0" 0 "$TL_STATUS"
assert_eq "surrogate settings still valid JSON" 0 "$(python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$S" >/dev/null 2>&1; echo $?)"
assert_contains "lone surrogate preserved as an escape" "$(<"$S")" '\ud800'
assert_eq "stale hook pruned despite the surrogate" 0 "$(grep -c '0.9.0' "$S" || true)"

# --- a symlinked settings.json stays a symlink ---------------------------------------
mkdir -p "$TL_TMP/dotfiles"
stale_doc ',{"command":"echo keep"}' >"$TL_TMP/dotfiles/settings.json"
rm -f "$S" "$S.sb-backup"
ln -s "$TL_TMP/dotfiles/settings.json" "$S"
run_prune
assert_eq "symlinked settings exit 0" 0 "$TL_STATUS"
assert_eq "settings.json is still a symlink" "$TL_TMP/dotfiles/settings.json" "$(readlink "$S")"
assert_eq "the link target was rewritten" '["echo keep"]' "$(jq -c '[.hooks.Stop[].hooks[].command]' "$TL_TMP/dotfiles/settings.json")"
assert_file_exists "the backup sits beside the link target" "$TL_TMP/dotfiles/settings.json.sb-backup"

# --- file mode, backup and temp files ------------------------------------------------
rm -f "$S"
stale_doc ',{"command":"echo keep"}' >"$S"
chmod 640 "$S"
run_prune
assert_eq "mode run exits 0" 0 "$TL_STATUS"
assert_eq "a 0640 settings file keeps its mode" "640" "$(stat -c %a "$S" 2>/dev/null || stat -f %Lp "$S")"
assert_eq "only the settings and its backup remain (no temp file)" "hooks plugins settings.json settings.json.sb-backup" "$(ls -A "$CH" | tr '\n' ' ' | sed 's/ $//')"
chmod 600 "$S"
stale_doc >"$S"
run_prune
assert_eq "a 0600 settings file keeps its mode" "600" "$(stat -c %a "$S" 2>/dev/null || stat -f %Lp "$S")"

# Temp files are created in the directory of the (symlink-resolved) settings file, so the
# final rename stays on one filesystem.
mkdir -p "$TL_TMP/pylog"
cat >"$TL_TMP/pylog/sitecustomize.py" <<'PY'
import os, tempfile

_real = tempfile.mkstemp

def _logged(*args, **kwargs):
    with open(os.environ["MKSTEMP_LOG"], "a") as log:
        log.write(kwargs.get("dir", "") + "\n")
    return _real(*args, **kwargs)

tempfile.mkstemp = _logged
PY
stale_doc >"$S"
: >"$TL_TMP/mkstemp.log"
tl_run env PYTHONPATH="$TL_TMP/pylog" MKSTEMP_LOG="$TL_TMP/mkstemp.log" CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "temp files created beside the settings file" "$CH" "$(sort -u "$TL_TMP/mkstemp.log")"
rm -f "$S"
ln -s "$TL_TMP/dotfiles/settings.json" "$S"
stale_doc >"$TL_TMP/dotfiles/settings.json"
: >"$TL_TMP/mkstemp.log"
tl_run env PYTHONPATH="$TL_TMP/pylog" MKSTEMP_LOG="$TL_TMP/mkstemp.log" CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "temp files created beside the symlink target" "$TL_TMP/dotfiles" "$(sort -u "$TL_TMP/mkstemp.log")"
rm -f "$S"

# --- a failing rename leaves the original untouched and no temp file behind ----------
mkdir -p "$TL_TMP/pyfault"
cat >"$TL_TMP/pyfault/sitecustomize.py" <<'PY'
import os

def _boom(*_args, **_kwargs):
    raise OSError("injected replace failure")

os.replace = _boom
PY
rm -f "$S" "$S.sb-backup"
stale_doc >"$S"
cp "$S" "$TL_TMP/before"
tl_run env PYTHONPATH="$TL_TMP/pyfault" CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "failed rename exits non-zero" 1 "$TL_STATUS"
assert_contains "failed rename reports the cause" "$TL_ERR" "injected replace failure"
assert_eq "failed rename leaves settings.json byte-identical" "$(<"$TL_TMP/before")" "$(<"$S")"
assert_eq "failed rename leaves no temp file" "hooks plugins settings.json" "$(ls -A "$CH" | tr '\n' ' ' | sed 's/ $//')"

# python3 absent: nothing is touched.
NOPY="$(tl_path_without python3)"
tl_run env PATH="$NOPY" CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "no python3 exits 0" 0 "$TL_STATUS"
assert_eq "no python3: settings untouched" "$(<"$TL_TMP/before")" "$(<"$S")"
assert_file_exists "no python3: hook files untouched" "$CH/hooks/gsd-statusline.sh"

# No settings file: nothing is created.
rm -f "$S"
run_prune
assert_eq "missing settings exits 0" 0 "$TL_STATUS"
assert_file_absent "no settings.json created" "$S"

# Default location comes from HOME.
mkdir -p "$HOME/.claude"
stale_doc >"$HOME/.claude/settings.json"
tl_run env -u CLAUDE_HOME bash "$SCRIPT"
assert_eq "default CLAUDE_HOME exits 0" 0 "$TL_STATUS"
assert_eq "default CLAUDE_HOME under HOME used" '[]' "$(jq -c '.hooks.Stop' "$HOME/.claude/settings.json")"

tl_results
