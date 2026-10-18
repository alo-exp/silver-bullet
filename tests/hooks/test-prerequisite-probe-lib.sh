#!/usr/bin/env bash
# Unit tests for hooks/lib/prerequisite-probe.sh, run against staged copies of hooks/.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
source "$(dirname "${BASH_SOURCE[0]}")/../lib/dgates-helpers.sh"
tl_init

S="$TL_TMP/stage"
dg_stage_hooks "$S"
mkdir -p "$S/scripts"
# shellcheck source=/dev/null
source "$S/hooks/lib/prerequisite-probe.sh"
P="$TL_TMP/proj"; dg_project "$P"
CACHE="$TL_TMP/cache"; mkdir -p "$CACHE/mkt/silver-bullet/1.0"
export SB_RUNTIME_PLUGIN_CACHE_ROOT="$CACHE"
rc() { local r=0; "$@" >/dev/null 2>&1 || r=$?; echo "$r"; }
probe() { PR_RC=0; PR_OUT="$(sb_prereq_run_probe "$@")" || PR_RC=$?; }
NOJQ="$(tl_path_without jq)"

# --- find_repair_script -----------------------------------------------------------
assert_eq "repair: none available" 1 "$(rc sb_prereq_find_repair_script "$P")"
printf '#!/bin/sh\nexit 0\n' >"$S/scripts/sb-prerequisite-repair.sh"
assert_eq "repair: non-executable ignored" 1 "$(rc sb_prereq_find_repair_script "$P")"
chmod +x "$S/scripts/sb-prerequisite-repair.sh"
assert_eq "repair: plugin-relative script found" "$S/scripts/sb-prerequisite-repair.sh" "$(sb_prereq_find_repair_script "$P")"
mkdir -p "$P/scripts"; printf '#!/bin/sh\nexit 0\n' >"$P/scripts/sb-prerequisite-repair.sh"; chmod +x "$P/scripts/sb-prerequisite-repair.sh"
assert_eq "repair: project script preferred" "$P/scripts/sb-prerequisite-repair.sh" "$(sb_prereq_find_repair_script "$P")"
rm -f "$P/scripts/sb-prerequisite-repair.sh"
assert_eq "repair: default root is PWD" "$P/scripts/x" "$(cd "$P" && printf '#!/bin/sh\n' >scripts/sb-prerequisite-repair.sh && chmod +x scripts/sb-prerequisite-repair.sh && sb_prereq_find_repair_script | sed 's|sb-prerequisite-repair.sh|x|')"
rm -f "$P/scripts/sb-prerequisite-repair.sh"

# --- checks ------------------------------------------------------------------------
assert_eq "check jq: present" 0 "$(rc sb_prereq_check_jq)"
assert_eq "check jq: absent" 1 "$(PATH="$NOJQ" rc sb_prereq_check_jq)"
assert_eq "plugin cache: present" 0 "$(rc sb_prereq_check_plugin_cache)"
assert_eq "plugin cache: unset" 1 "$(SB_RUNTIME_PLUGIN_CACHE_ROOT="" rc sb_prereq_check_plugin_cache)"
assert_eq "plugin cache: missing dir" 1 "$(SB_RUNTIME_PLUGIN_CACHE_ROOT="$TL_TMP/none" rc sb_prereq_check_plugin_cache)"
mkdir -p "$TL_TMP/emptycache"
assert_eq "plugin cache: no silver-bullet entry" 1 "$(SB_RUNTIME_PLUGIN_CACHE_ROOT="$TL_TMP/emptycache" rc sb_prereq_check_plugin_cache)"
mkdir -p "$TL_TMP/flatcache/my-silver-bullet-plugin"
assert_eq "plugin cache: flat silver-bullet directory" 0 "$(SB_RUNTIME_PLUGIN_CACHE_ROOT="$TL_TMP/flatcache" rc sb_prereq_check_plugin_cache)"

# --- run_probe -----------------------------------------------------------------------
rm -f "$S/scripts/sb-prerequisite-repair.sh"
probe "$P"
assert_eq "probe: healthy install" 0 "$PR_RC"; assert_eq "probe: healthy prints nothing" "" "$PR_OUT"
(cd "$P" && sb_prereq_run_probe >/dev/null) && r=0 || r=$?
assert_eq "probe: default root is PWD" 0 "$r"
PATH="$NOJQ" probe "$P"
assert_eq "probe: missing jq fails" 1 "$PR_RC"; assert_contains "probe: names jq" "$PR_OUT" "jq missing"
SB_RUNTIME_PLUGIN_CACHE_ROOT="$TL_TMP/none" probe "$P"
assert_contains "probe: names plugin cache" "$PR_OUT" "plugin cache not found"
mkdir -p "$TL_TMP/incomplete"
probe "$TL_TMP/incomplete"
assert_contains "probe: incomplete project files" "$PR_OUT" "SB project files incomplete"
SB_RUNTIME_PLUGIN_CACHE_ROOT="$TL_TMP/none" PATH="$NOJQ" probe "$TL_TMP/incomplete"
assert_eq "probe: all issues joined" "jq missing Silver Bullet plugin cache not found SB project files incomplete — run /sb:init" "$PR_OUT"

# core-rules integrity pin
assert_file_exists "staged core-rules.md" "$S/hooks/core-rules.md"
echo "tampered" >>"$S/hooks/core-rules.md"
probe "$P"
assert_eq "probe: tampered core rules fail" 1 "$PR_RC"; assert_contains "probe: integrity message" "$PR_OUT" "integrity pin mismatch"
cp "$TL_REPO_ROOT/hooks/core-rules.md" "$S/hooks/core-rules.md"
probe "$P"; assert_eq "probe: restored core rules pass" 0 "$PR_RC"
rm -f "$S/hooks/core-rules.sha256"
echo tampered >>"$S/hooks/core-rules.md"
probe "$P"; assert_eq "probe: no pin file means no integrity check" 0 "$PR_RC"
cp "$TL_REPO_ROOT/hooks/core-rules.md" "$S/hooks/core-rules.md"; cp "$TL_REPO_ROOT/hooks/core-rules.sha256" "$S/hooks/core-rules.sha256"
rm -f "$S/hooks/lib/core-rules-integrity.sh"; echo tampered >>"$S/hooks/core-rules.md"
probe "$P"; assert_eq "probe: no integrity helper means no check" 0 "$PR_RC"
cp "$TL_REPO_ROOT/hooks/core-rules.md" "$S/hooks/core-rules.md"; cp "$TL_REPO_ROOT/hooks/lib/core-rules-integrity.sh" "$S/hooks/lib/"

# repair script
cat >"$S/scripts/sb-prerequisite-repair.sh" <<'REP'
#!/usr/bin/env bash
echo "$1" >>"$REPAIR_LOG"
[[ -n "${REPAIR_FIX:-}" ]] && { echo '{}' >"$1/.silver-bullet.json"; echo x >"$1/silver-bullet.md"; }
exit "${REPAIR_RC:-0}"
REP
chmod +x "$S/scripts/sb-prerequisite-repair.sh"
export REPAIR_LOG="$TL_TMP/repair.log"
rm -f "$REPAIR_LOG"
probe "$TL_TMP/incomplete"
assert_eq "repair: attempted for the failing project" "$TL_TMP/incomplete" "$(cat "$REPAIR_LOG")"
assert_eq "repair: unrepaired still fails" 1 "$PR_RC"
REPAIR_FIX=1 probe "$TL_TMP/incomplete"
assert_eq "repair: successful repair re-probes clean" 0 "$PR_RC"
assert_eq "repair: successful repair prints nothing" "" "$PR_OUT"
rm -rf "$TL_TMP/incomplete2"; mkdir -p "$TL_TMP/incomplete2"
REPAIR_RC=1 probe "$TL_TMP/incomplete2"
assert_eq "repair: failing repair script tolerated" 1 "$PR_RC"
SB_RUNTIME_PLUGIN_CACHE_ROOT="$TL_TMP/none" PATH="$NOJQ" probe "$TL_TMP/incomplete2"
assert_eq "repair: re-probe reports every remaining issue" "jq missing Silver Bullet plugin cache not found SB project files incomplete — run /sb:init" "$PR_OUT"
probe "$P"; r="$(wc -l <"$REPAIR_LOG" | tr -d ' ')"
assert_eq "repair: not attempted for a healthy install" 4 "$r"

# --- blocking message -------------------------------------------------------------------------
m="$(sb_prereq_blocking_message "jq missing")"
assert_contains "message: lists issues" "$m" "prerequisites missing: jq missing"
assert_contains "message: remedy" "$m" "/sb:init"
assert_contains "message: linux hint" "$m" "apt install jq"

tl_results
