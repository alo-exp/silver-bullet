#!/usr/bin/env bash
# prune-stale-claude-user-hooks.sh: removes stale legacy hook files and broken
# SessionStart-style hook commands from ~/.claude/settings.json without
# dropping or corrupting anything else in the user's settings.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

SCRIPT="$TL_REPO_ROOT/scripts/prune-stale-claude-user-hooks.sh"
CH="$TL_TMP/claude-home"
mkdir -p "$CH/hooks"
cd "$TL_TMP"

run_prune() { tl_run env CLAUDE_HOME="$CH" bash "$SCRIPT"; }

# --- hook files ---------------------------------------------------------
printf 'x' >"$CH/hooks/gsd-session-state.sh"
printf 'x' >"$CH/hooks/gsd-other-thing.sh"
printf 'keep' >"$CH/hooks/my-own-hook.sh"
printf 'keep' >"$CH/hooks/gsd-notes.txt"
run_prune
assert_eq "file pass exits 0" 0 "$TL_STATUS"
assert_file_absent "gsd-session-state.sh removed" "$CH/hooks/gsd-session-state.sh"
assert_file_absent "gsd-*.sh removed" "$CH/hooks/gsd-other-thing.sh"
assert_file_exists "user hook kept" "$CH/hooks/my-own-hook.sh"
assert_file_exists "non-.sh legacy-named file kept" "$CH/hooks/gsd-notes.txt"
assert_contains "removal reported" "$TL_ERR" "removed $CH/hooks/gsd-session-state.sh"

# Empty hooks dir: the unmatched glob is skipped, not treated as a file.
rm -f "$CH"/hooks/*
run_prune
assert_eq "empty hooks dir exits 0" 0 "$TL_STATUS"
rm -rf "$CH/hooks"
run_prune
assert_eq "missing hooks dir exits 0" 0 "$TL_STATUS"
assert_file_absent "no settings.json created" "$CH/settings.json"

# --- settings.json ------------------------------------------------------
mkdir -p "$CH/real-hooks"
printf '#!/bin/sh\n' >"$CH/real-hooks/ok.sh"
cat >"$CH/settings.json" <<JSON
{
  "model": "opus",
  "hooks": {
    "SessionStart": [
      {"hooks": [{"type": "command", "command": "bash gsd-session-state.sh"}]},
      {"hooks": [
        {"type": "command", "command": "bash \"$CH/real-hooks/ok.sh\""},
        {"type": "command", "command": "node \"$CH/real-hooks/missing.js\""},
        null,
        {"type": "command", "command": 42}
      ]},
      {"hooks": [{"type": "command", "command": "run gsd-foo.sh now"}]},
      "keep-this-string"
    ],
    "Stop": "not-a-list",
    "PreToolUse": [
      {"matcher": "Bash", "hooks": [{"type": "command", "command": "echo plain"}]}
    ]
  },
  "note": "café ☕"
}
JSON
run_prune
assert_eq "settings pass exits 0" 0 "$TL_STATUS"
assert_contains "settings cleanup reported" "$TL_ERR" "cleaned settings.json"
S="$CH/settings.json"
assert_eq "existing script hook kept" 1 "$(jq '[.hooks.SessionStart[].hooks? // empty | .[]? | select(type=="object") | select((.command|type)=="string") | select(.command|contains("ok.sh"))] | length' "$S")"
assert_eq "legacy session-state entry dropped" 0 "$(jq '[.. | strings | select(contains("gsd-"))] | length' "$S")"
assert_eq "missing-script hook dropped" 0 "$(jq '[.. | strings | select(contains("missing.js"))] | length' "$S")"
assert_eq "null hook entry preserved" 1 "$(jq '[.hooks.SessionStart[0].hooks[] | select(. == null)] | length' "$S")"
assert_eq "non-string command preserved" 1 "$(jq '[.hooks.SessionStart[0].hooks[] | select(type=="object" and .command == 42)] | length' "$S")"
assert_eq "foreign string entry preserved" 1 "$(jq '[.hooks.SessionStart[] | select(. == "keep-this-string")] | length' "$S")"
assert_eq "non-list event value preserved" '"not-a-list"' "$(jq -c '.hooks.Stop' "$S")"
assert_eq "other events preserved" '"echo plain"' "$(jq -c '.hooks.PreToolUse[0].hooks[0].command' "$S")"
assert_eq "unrelated keys preserved" '"opus"' "$(jq -c '.model' "$S")"
assert_contains "non-ASCII text written verbatim" "$(<"$S")" "café ☕"

# Idempotent: second run changes nothing and reports nothing.
cp "$S" "$TL_TMP/settings.after-1"
run_prune
assert_eq "second run exits 0" 0 "$TL_STATUS"
assert_eq "second run leaves file byte-identical" "$(<"$TL_TMP/settings.after-1")" "$(<"$S")"
assert_not_contains "second run reports no cleanup" "$TL_ERR" "cleaned settings.json"

# Entries that are not hook groups (no "hooks" list) are foreign data and must
# survive a cleanup triggered by a different, stale entry.
cat >"$S" <<JSON
{"hooks": {"SessionStart": [
  {"hooks": [{"type": "command", "command": "bash gsd-session-state.sh"}]},
  {"type": "command", "command": "echo flat-legacy-entry"},
  {"matcher": "startup", "hooks": []}
]}}
JSON
run_prune
assert_eq "mixed file exits 0" 0 "$TL_STATUS"
assert_eq "stale group removed" 0 "$(jq '[.. | strings | select(contains("gsd-"))] | length' "$S")"
assert_eq "entry without a hooks list preserved" '"echo flat-legacy-entry"' "$(jq -c '.hooks.SessionStart[] | select(.command? != null) | .command' "$S")"
assert_eq "group with an empty hooks list preserved" '"startup"' "$(jq -c '.hooks.SessionStart[] | select(.matcher? != null) | .matcher' "$S")"

# Nothing stale: file is not rewritten at all.
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

# Wrong-typed entries inside an event are foreign data: kept as they are, while
# stale siblings are still pruned.
printf '%s' '{"hooks":{"Stop":[{"hooks":["str",{"command":"bash gsd-x.sh"}]},{"hooks":{"a":1}},{"hooks":null}]}}' >"$S"
run_prune
assert_eq "wrong-typed entries exit 0" 0 "$TL_STATUS"
assert_eq "string hook kept, stale sibling pruned" '["str"]' "$(jq -c '.hooks.Stop[0].hooks' "$S")"
assert_eq "object-valued hooks entry kept" '{"a":1}' "$(jq -c '.hooks.Stop[1].hooks' "$S")"
assert_eq "null-valued hooks entry kept" 'null' "$(jq -c '.hooks.Stop[2].hooks' "$S")"

# --- command-path edge cases ----------------------------------------------------
mkdir -p "$CH/real-hooks/is-a-dir.sh"
printf 'x' >"$HOME/ok-home.mjs"
cat >"$S" <<JSON
{"hooks": {"Stop": [
  {"hooks": [{"command": "node \"~/x.mjs\""}]},
  {"hooks": [{"command": "node \"~/ok-home.mjs\""}]},
  {"hooks": [{"command": "bash \"$CH/real-hooks/is-a-dir.sh\""}]},
  {"hooks": [{"command": "bash GSD-FOO.SH"}]},
  {"hooks": [{"command": "bash GSD-Session-State.sh"}]},
  {"hooks": [{"command": "echo no-script-here"}]}
]}}
JSON
run_prune
assert_eq "path edge cases exit 0" 0 "$TL_STATUS"
assert_eq "only the existing-home script and the plain command remain" \
  '["node \"~/ok-home.mjs\"","echo no-script-here"]' "$(jq -c '[.hooks.Stop[].hooks[].command]' "$S")"

# --- exact rewrite bytes -----------------------------------------------------------
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-x.sh"},{"command":"echo keep"}]}]},"model":"opus"}' >"$S"
run_prune
assert_eq "rewrite exits 0" 0 "$TL_STATUS"
printf '{\n  "hooks": {\n    "Stop": [\n      {\n        "hooks": [\n          {\n            "command": "echo keep"\n          }\n        ]\n      }\n    ]\n  },\n  "model": "opus"\n}\n' >"$TL_TMP/expected.json"
assert_eq "rewritten file is indent 2 with one trailing newline" "$(cmp "$TL_TMP/expected.json" "$S" && echo identical)" "identical"

# --- the rewrite normalises the document -----------------------------------------------
printf '%s' '{"n":2.50,"e":1e3,"d":1,"d":2,"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-x.sh"}]}]}}' >"$S"
run_prune
assert_eq "normalising rewrite exits 0" 0 "$TL_STATUS"
assert_contains "2.50 becomes 2.5" "$(<"$S")" '"n": 2.5,'
assert_contains "1e3 becomes 1000.0" "$(<"$S")" '"e": 1000.0,'
assert_eq "duplicate key keeps the last value, once" '1 2' "$(grep -c '"d"' "$S") $(jq '.d' "$S")"

# --- lone surrogate: the rewrite must never truncate settings.json -------------------------
printf '%s' '{"note":"bad \ud800 here","ok":"café","hooks":{"Stop":[{"hooks":[{"command":"bash gsd-x.sh"}]}]}}' >"$S"
run_prune
assert_eq "surrogate settings exit 0" 0 "$TL_STATUS"
assert_eq "surrogate settings still valid JSON" 0 "$(python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$S" >/dev/null 2>&1; echo $?)"
assert_contains "lone surrogate preserved as an escape" "$(<"$S")" '\ud800'
assert_eq "stale hook pruned despite the surrogate" 0 "$(grep -c 'gsd-x.sh' "$S" || true)"
assert_eq "no temp files left next to settings.json" "real-hooks settings.json" "$(ls -A "$CH" | tr '\n' ' ' | sed 's/ $//')"

# --- a symlinked settings.json stays a symlink -----------------------------------------------
mkdir -p "$TL_TMP/dotfiles"
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-x.sh"},{"command":"echo keep"}]}]}}' >"$TL_TMP/dotfiles/settings.json"
rm -f "$S"
ln -s "$TL_TMP/dotfiles/settings.json" "$S"
run_prune
assert_eq "symlinked settings exit 0" 0 "$TL_STATUS"
assert_eq "settings.json is still a symlink" "$TL_TMP/dotfiles/settings.json" "$(readlink "$S")"
assert_eq "the link target was rewritten" '["echo keep"]' "$(jq -c '[.hooks.Stop[].hooks[].command]' "$TL_TMP/dotfiles/settings.json")"

# --- file mode and temp files -------------------------------------------------------------
rm -f "$S"
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-x.sh"},{"command":"echo keep"}]}]}}' >"$S"
chmod 640 "$S"
run_prune
assert_eq "mode run exits 0" 0 "$TL_STATUS"
assert_eq "a 0640 settings file keeps its mode" "640" "$(stat -c %a "$S" 2>/dev/null || stat -f %Lp "$S")"
assert_eq "no temp file remains beside the rewritten settings" "real-hooks settings.json" "$(ls -A "$CH" | tr '\n' ' ' | sed 's/ $//')"
chmod 600 "$S"
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-y.sh"}]}]}}' >"$S"
run_prune
assert_eq "a 0600 settings file keeps its mode" "600" "$(stat -c %a "$S" 2>/dev/null || stat -f %Lp "$S")"

# The temp file is created in the directory of the (symlink-resolved) settings file, so the
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
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-z.sh"}]}]}}' >"$S"
: >"$TL_TMP/mkstemp.log"
tl_run env PYTHONPATH="$TL_TMP/pylog" MKSTEMP_LOG="$TL_TMP/mkstemp.log" CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "temp file created beside the settings file" "$CH" "$(<"$TL_TMP/mkstemp.log")"
rm -f "$S"
ln -s "$TL_TMP/dotfiles/settings.json" "$S"
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-z.sh"}]}]}}' >"$TL_TMP/dotfiles/settings.json"
: >"$TL_TMP/mkstemp.log"
tl_run env PYTHONPATH="$TL_TMP/pylog" MKSTEMP_LOG="$TL_TMP/mkstemp.log" CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "temp file created beside the symlink target" "$TL_TMP/dotfiles" "$(<"$TL_TMP/mkstemp.log")"
rm -f "$S"

# --- a failing rename leaves the original untouched and no temp file behind ---------------------
mkdir -p "$TL_TMP/pyfault"
cat >"$TL_TMP/pyfault/sitecustomize.py" <<'PY'
import os

def _boom(*_args, **_kwargs):
    raise OSError("injected replace failure")

os.replace = _boom
PY
rm -f "$S"
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-x.sh"}]}]}}' >"$S"
cp "$S" "$TL_TMP/before"
tl_run env PYTHONPATH="$TL_TMP/pyfault" CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "failed rename exits non-zero" 1 "$TL_STATUS"
assert_contains "failed rename reports the cause" "$TL_ERR" "injected replace failure"
assert_eq "failed rename leaves settings.json byte-identical" "$(<"$TL_TMP/before")" "$(<"$S")"
assert_eq "failed rename leaves no temp file" "real-hooks settings.json" "$(ls -A "$CH" | tr '\n' ' ' | sed 's/ $//')"

# python3 absent: file cleanup still happens, settings are left alone.
printf '%s' '{"hooks":{"Stop":[{"hooks":[{"command":"bash gsd-x.sh"}]}]}}' >"$S"
cp "$S" "$TL_TMP/before"
mkdir -p "$CH/hooks"
printf 'x' >"$CH/hooks/gsd-a.sh"
NOPY="$(tl_path_without python3)"
tl_run env PATH="$NOPY" CLAUDE_HOME="$CH" bash "$SCRIPT"
assert_eq "no python3 exits 0" 0 "$TL_STATUS"
assert_file_absent "no python3: hook file still removed" "$CH/hooks/gsd-a.sh"
assert_eq "no python3: settings untouched" "$(<"$TL_TMP/before")" "$(<"$S")"

# Default location comes from HOME.
mkdir -p "$HOME/.claude/hooks"
printf 'x' >"$HOME/.claude/hooks/gsd-home.sh"
tl_run env -u CLAUDE_HOME bash "$SCRIPT"
assert_eq "default CLAUDE_HOME exits 0" 0 "$TL_STATUS"
assert_file_absent "default CLAUDE_HOME under HOME used" "$HOME/.claude/hooks/gsd-home.sh"

tl_results
