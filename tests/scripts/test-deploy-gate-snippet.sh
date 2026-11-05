#!/usr/bin/env bash
# scripts/deploy-gate-snippet.sh: config discovery, trivial/bypass/state/skills decisions,
# sourced vs standalone return semantics, fail-open ERR trap.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

SNIP="$TL_REPO_ROOT/scripts/deploy-gate-snippet.sh"
STATE="$SB_RUNTIME_STATE_DIR/state"
TRIVIAL="$SB_RUNTIME_STATE_DIR/trivial"

gate() { # <cwd> [args...] — standalone run
  local cwd="$1"; shift
  tl_run bash -c 'cd "$1" && shift && bash "$@"' _ "$cwd" "$SNIP" "$@"
}


NOCFG="$TL_TMP/nocfg"; mkdir -p "$NOCFG/.git"

# --- no config: default list; missing state file -> blocked ----------------------
rm -f "$STATE" "$TRIVIAL"
gate "$NOCFG"
assert_eq "no state file -> exit 1" 1 "$TL_STATUS"
assert_contains "no state message" "$TL_OUT" "No workflow state file found at $STATE"

# default list used when DEFAULT_REQUIRED unset; state with only one skill -> lists missing
echo silver-plan >"$STATE"
gate "$NOCFG"
assert_eq "missing skills -> exit 1" 1 "$TL_STATUS"
assert_contains "missing header" "$TL_OUT" "Missing required workflow skills:"
assert_contains "lists missing skill" "$TL_OUT" "    - silver-quality-gates"
assert_not_contains "present skill not listed" "$TL_OUT" "    - silver-plan"$'\n'
assert_file_exists "state kept on failure" "$STATE"

# a current-version project config with an explicit list is used verbatim
TVER="$(jq -r '.config_version // .version' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default")"
EXP="$TL_TMP/explicit"; mkdir -p "$EXP/.git"
jq -n --arg v "$TVER" '{config_version:$v, skills:{required_deploy:["alpha","beta"]}}' >"$EXP/.silver-bullet.json"
printf 'alpha\nbeta\n' >"$STATE"
gate "$EXP"
assert_eq "all present via config -> 0" 0 "$TL_STATUS"
assert_contains "all clear message" "$TL_OUT" "All required workflow skills completed. Proceeding with deploy."
assert_file_absent "state consumed on success" "$STATE"
printf 'alpha\n' >"$STATE"
gate "$EXP"
assert_eq "partial via config -> 1" 1 "$TL_STATUS"
assert_contains "beta missing" "$TL_OUT" "    - beta"
assert_not_contains "alpha satisfied" "$TL_OUT" "    - alpha"
# whole-line exact match: 'alpha-extra' does not satisfy 'alpha'
printf 'alpha-extra\nbeta\n' >"$STATE"
gate "$EXP"
assert_eq "substring does not satisfy" 1 "$TL_STATUS"

# --- bypass flag -----------------------------------------------------------------------
rm -f "$STATE"
gate "$NOCFG" --skip-workflow-check
assert_eq "bypass -> 0" 0 "$TL_STATUS"
assert_contains "bypass message" "$TL_OUT" "Workflow check bypassed via --skip-workflow-check."

# --- trivial fast path -----------------------------------------------------------------
echo x >"$STATE"; echo t >"$TRIVIAL"
gate "$NOCFG"
assert_eq "trivial -> 0" 0 "$TL_STATUS"
assert_contains "trivial message" "$TL_OUT" "Trivial change detected"
assert_file_absent "trivial marker removed" "$TRIVIAL"
assert_file_absent "state removed with trivial" "$STATE"
# trivial without a state file
echo t >"$TRIVIAL"
gate "$NOCFG"
assert_eq "trivial without state -> 0" 0 "$TL_STATUS"
# symlinked trivial marker is ignored
rm -f "$STATE" "$TRIVIAL"; echo real >"$TL_TMP/real-trivial"; ln -s "$TL_TMP/real-trivial" "$TRIVIAL"
gate "$NOCFG"
assert_eq "symlink trivial ignored -> falls to state check" 1 "$TL_STATUS"
assert_file_exists "symlink target untouched" "$TL_TMP/real-trivial"
rm -f "$TRIVIAL"
# symlinked state file is not deleted by the trivial path
echo t >"$TRIVIAL"; echo s >"$TL_TMP/real-state"; ln -s "$TL_TMP/real-state" "$STATE"
gate "$NOCFG"
assert_eq "trivial with symlink state -> 0" 0 "$TL_STATUS"
assert_file_exists "symlinked state not removed" "$STATE"
rm -f "$STATE" "$TRIVIAL"

# --- project config discovered by walking up --------------------------------------------
PRJ="$TL_TMP/prj"; mkdir -p "$PRJ/.git" "$PRJ/a/b"
cat >"$PRJ/.silver-bullet.json" <<JSON
{"config_version":"$TVER","state":{"state_file":"~/.claude/.silver-bullet/custom-state","trivial_file":"~/.claude/.silver-bullet/custom/trivial"},
 "skills":{"required_deploy":["cfg-one","cfg-two"]}}
JSON
mkdir -p "$SB_RUNTIME_STATE_DIR/custom"
printf 'cfg-one\n' >"$SB_RUNTIME_STATE_DIR/custom-state"
gate "$PRJ/a/b"
assert_eq "config required_deploy enforced" 1 "$TL_STATUS"
assert_contains "config skill missing" "$TL_OUT" "    - cfg-two"
assert_contains "state path from config (~ expanded)" "$TL_OUT" "cfg-two"
printf 'cfg-one\ncfg-two\n' >"$SB_RUNTIME_STATE_DIR/custom-state"
gate "$PRJ/a/b"
assert_eq "config satisfied -> 0" 0 "$TL_STATUS"
assert_file_absent "custom state consumed" "$SB_RUNTIME_STATE_DIR/custom-state"
echo t >"$SB_RUNTIME_STATE_DIR/custom/trivial"
gate "$PRJ"
assert_contains "custom trivial honoured" "$TL_OUT" "Trivial change detected"
assert_file_absent "custom trivial removed" "$SB_RUNTIME_STATE_DIR/custom/trivial"
rm -f "$SB_RUNTIME_STATE_DIR/custom-state"
gate "$PRJ"
assert_contains "custom state path reported" "$TL_OUT" "No workflow state file found at $SB_RUNTIME_STATE_DIR/custom-state"

# empty config values keep defaults; empty required_deploy -> default list
echo '{"state":{},"skills":{}}' >"$PRJ/.silver-bullet.json"
echo silver-plan >"$STATE"
gate "$PRJ"
assert_eq "empty config uses defaults" 1 "$TL_STATUS"
assert_contains "default skill listed" "$TL_OUT" "    - silver-quality-gates"

# jq absent: config ignored, defaults apply
echo '{"skills":{"required_deploy":["only-this"]}}' >"$PRJ/.silver-bullet.json"
printf 'only-this\n' >"$STATE"
tl_run bash -c 'cd "$1" && PATH="$2" bash "$3"' _ "$PRJ" "$(tl_path_without jq)" "$SNIP"
assert_eq "no jq -> default list enforced" 1 "$TL_STATUS"
assert_contains "no jq default skill" "$TL_OUT" "    - silver-quality-gates"

# invalid JSON config: ERR trap fails open
echo '{not json' >"$PRJ/.silver-bullet.json"
rm -f "$STATE"
gate "$PRJ"
assert_eq "invalid config -> fail open exit 0" 0 "$TL_STATUS"
assert_eq "invalid config -> silent" "" "$TL_OUT"

# --- R1-24: a config stamped from the shipped template resolves its state paths ---------
TPLP="$TL_TMP/tplproj"; mkdir -p "$TPLP/.git"
cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$TPLP/.silver-bullet.json"
jq '.skills.required_deploy=["alpha"]' "$TPLP/.silver-bullet.json" >"$TPLP/c.json" && mv "$TPLP/c.json" "$TPLP/.silver-bullet.json"
printf 'alpha\n' >"$STATE"
gate "$TPLP"
assert_eq "template-stamped config (placeholders intact): gate passes with a full state file" 0 "$TL_STATUS"
assert_contains "template-stamped config: all clear" "$TL_OUT" "All required workflow skills completed"
printf 'x\n' >"$STATE"
gate "$TPLP"
assert_eq "template-stamped config: still blocks when a skill is missing" 1 "$TL_STATUS"
# the hook's rules: branch finishing does not apply on main/master, recorded skills may match through aliases
BR="$TL_TMP/brproj"; mkdir -p "$BR"; git -C "$BR" init -q -b main; git -C "$BR" -c user.email=a@b -c user.name=n commit -q --allow-empty -m i
jq -n --arg v "$TVER" '{config_version:$v,skills:{required_deploy:["alpha","silver-branch-finish","finishing-a-development-branch"]}}' >"$BR/.silver-bullet.json"
printf 'alpha\n' >"$STATE"
gate "$BR"
assert_eq "on main: branch-finishing skills are not required" 0 "$TL_STATUS"
git -C "$BR" checkout -q -b feature
printf 'alpha\n' >"$STATE"
gate "$BR"
assert_eq "on a feature branch: branch-finishing skills are required" 1 "$TL_STATUS"
assert_contains "feature branch: lists silver-branch-finish" "$TL_OUT" "    - silver-branch-finish"
# no required-skills library: the exact-line check still decides
SNIPC="$TL_TMP/snipcopy"; mkdir -p "$SNIPC/scripts" "$SNIPC/hooks/lib"
cp "$SNIP" "$SNIPC/scripts/"; cp "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$TL_REPO_ROOT/hooks/lib/trivial-bypass.sh" "$SNIPC/hooks/lib/"
printf 'alpha\n' >"$STATE"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$EXP" "$SNIPC/scripts/deploy-gate-snippet.sh"
assert_eq "without the required-skills library: exact state lines decide (alpha only -> beta missing)" 1 "$TL_STATUS"

# --- R1-25: config paths outside the state directory are ignored and never deleted ----------
EVIL="$TL_TMP/evil"; mkdir -p "$EVIL/.git"
echo precious >"$TL_TMP/victim-trivial"; echo precious >"$TL_TMP/victim-state"
jq -n --arg t "$TL_TMP/victim-trivial" --arg s "$TL_TMP/victim-state" '{state:{trivial_file:$t,state_file:$s},skills:{required_deploy:["alpha"]}}' >"$EVIL/.silver-bullet.json"
rm -f "$STATE" "$TRIVIAL"
gate "$EVIL"
assert_eq "config pointing at outside files: the gate still blocks (no state at the real path)" 1 "$TL_STATUS"
assert_contains "the real state path is used" "$TL_OUT" "No workflow state file found at $STATE"
assert_file_exists "outside trivial file untouched" "$TL_TMP/victim-trivial"
assert_file_exists "outside state file untouched" "$TL_TMP/victim-state"
# a state-scoped custom path is honoured (and consumed like the default)
CUS="$TL_TMP/custate"; mkdir -p "$CUS/.git"
jq -n --arg v "$TVER" --arg s "$SB_RUNTIME_STATE_DIR/custom-state2" '{config_version:$v,state:{state_file:$s},skills:{required_deploy:["alpha"]}}' >"$CUS/.silver-bullet.json"
printf 'alpha\n' >"$SB_RUNTIME_STATE_DIR/custom-state2"
gate "$CUS"
assert_eq "state-scoped custom state file is read" 0 "$TL_STATUS"
assert_file_absent "a validated state-scoped custom state file is consumed like the default" "$SB_RUNTIME_STATE_DIR/custom-state2"
# a trivial marker named in config must be the state directory's own `trivial`
mkdir -p "$SB_RUNTIME_STATE_DIR/sub"
jq -n --arg v "$TVER" --arg t "$SB_RUNTIME_STATE_DIR/sub/trivial" '{config_version:$v,state:{trivial_file:$t},skills:{required_deploy:["alpha"]}}' >"$CUS/.silver-bullet.json"
echo t >"$SB_RUNTIME_STATE_DIR/sub/trivial"
gate "$CUS"
assert_contains "state-scoped custom trivial file is honoured" "$TL_OUT" "Trivial change detected"
assert_file_absent "the validated trivial file is consumed" "$SB_RUNTIME_STATE_DIR/sub/trivial"
rm -f "$SB_RUNTIME_STATE_DIR/sub/trivial" "$STATE" "$TRIVIAL"

# --- legacy config: defaults + configured list, retired skills dropped (required-skills lib) ---
LEG="$TL_TMP/leg"; mkdir -p "$LEG/.git"
echo '{"skills":{"required_deploy":["legacy-extra","code-review"]}}' >"$LEG/.silver-bullet.json"
jq -r '.skills.required_deploy[]' "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" >"$STATE"
gate "$LEG"
assert_eq "legacy: configured extra still required" 1 "$TL_STATUS"
assert_contains "legacy: extra listed" "$TL_OUT" "    - legacy-extra"
assert_not_contains "legacy: retired skill dropped" "$TL_OUT" "    - code-review"
echo legacy-extra >>"$STATE"
gate "$LEG"
assert_eq "legacy: satisfied with defaults + extra" 0 "$TL_STATUS"

# --- sourced mode uses return, not exit -------------------------------------------------------
rm -f "$STATE"
tl_run bash -c 'cd "$1" && source "$2" --skip-workflow-check; echo "after-source rc=$?"' _ "$NOCFG" "$SNIP"
assert_contains "sourced bypass returns to caller" "$TL_OUT" "after-source rc=0"
# Sourcing must leave the caller's shell options alone: no errexit, no ERR trap, same umask,
# and a later failing command must not end the caller.
probe='cd "$1"; u0=$(umask); source "$2" "${@:3}"; rc=$?; echo "rc=$rc flags=$- umask_same=$([[ $(umask) == "$u0" ]] && echo yes || echo no) trap=[$(trap -p ERR)]"; false; echo after-false'
tl_run bash -c "$probe" _ "$NOCFG" "$SNIP"
assert_contains "sourced failing gate returns 1 to the caller" "$TL_OUT" "rc=1 "
assert_contains "sourced failure reports the block" "$TL_OUT" "No workflow state file found"
assert_contains "caller keeps running after a failing gate" "$TL_OUT" "after-false"
assert_not_contains "no errexit leaked (failing gate)" "$(grep -o 'flags=[a-zA-Z]*' <<<"$TL_OUT")" "e"
assert_contains "umask unchanged (failing gate)" "$TL_OUT" "umask_same=yes"
assert_contains "no ERR trap leaked (failing gate)" "$TL_OUT" "trap=[]"
tl_run bash -c "$probe" _ "$NOCFG" "$SNIP" --skip-workflow-check
assert_contains "sourced passing gate returns 0" "$TL_OUT" "rc=0 "
assert_not_contains "no errexit leaked (passing gate)" "$(grep -o 'flags=[a-zA-Z]*' <<<"$TL_OUT")" "e"
assert_contains "umask unchanged (passing gate)" "$TL_OUT" "umask_same=yes"
assert_contains "no ERR trap leaked (passing gate)" "$TL_OUT" "trap=[]"
assert_contains "caller keeps running after a passing gate" "$TL_OUT" "after-false"
tl_run bash -c 'cd "$1"; source "$2" || echo handled; false; echo after' _ "$NOCFG" "$SNIP"
assert_contains "failure is handleable with ||" "$TL_OUT" "handled"
assert_contains "caller continues after handled failure" "$TL_OUT" "after"
# executed directly the script still hardens itself (umask 0077 for files it deletes/creates)
echo x >"$STATE"; echo t >"$TRIVIAL"
gate "$NOCFG"
assert_eq "direct execution unaffected" 0 "$TL_STATUS"

# --- libraries absent in a copied tree ----------------------------------------------------------
CP="$TL_TMP/copytree"; mkdir -p "$CP/scripts" "$CP/hooks/lib"
cp "$SNIP" "$CP/scripts/"
cp "$TL_REPO_ROOT/hooks/lib/runtime-paths.sh" "$CP/hooks/lib/"
# runtime-paths present, required-skills absent: configured list is used verbatim
echo '{"skills":{"required_deploy":["verbatim-skill"]}}' >"$LEG/.silver-bullet.json"
printf 'verbatim-skill\n' >"$STATE"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$LEG" "$CP/scripts/deploy-gate-snippet.sh"
assert_eq "no required-skills lib: configured list verbatim" 0 "$TL_STATUS"
echo '{"skills":{"required_deploy":[]}}' >"$LEG/.silver-bullet.json"
printf 'silver-plan\n' >"$STATE"
tl_run bash -c 'cd "$1" && bash "$2"' _ "$LEG" "$CP/scripts/deploy-gate-snippet.sh"
assert_eq "no required-skills lib, empty list: built-in defaults" 1 "$TL_STATUS"
# runtime-paths absent: SB_RUNTIME_STATE_DIR from the environment is still honoured
rm "$CP/hooks/lib/runtime-paths.sh"
printf 'alpha\n' >"$STATE"
tl_run env DEFAULT_REQUIRED="alpha" bash -c 'cd "$1" && bash "$2"' _ "$NOCFG" "$CP/scripts/deploy-gate-snippet.sh"
assert_eq "no runtime-paths lib, env state dir" 0 "$TL_STATUS"

# the script directory cannot be entered (cd fails): libraries are skipped, the environment's state dir is used
printf 'alpha\n' >"$STATE"
tl_run bash -c 'cd() { return 1; }; source "$1" --skip-workflow-check; echo "rc=$?"' _ "$SNIP"
assert_contains "cd failure: bypass still works" "$TL_OUT" "Workflow check bypassed"
assert_file_exists "cd failure: state untouched by bypass" "$STATE"
tl_run bash -c 'builtin cd "$2"; cd() { return 1; }; source "$1" 2>&1' _ "$SNIP" "$NOCFG"
assert_contains "cd failure: gate still enforces with env state dir" "$TL_OUT" "Missing required workflow skills"

tl_results
