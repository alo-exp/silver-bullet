#!/usr/bin/env bash
# scripts/silver-bullet (the invoke-skill adapter) against staged plugin trees.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

FX="$TL_TMP/plugin"          # full tree: scripts + hooks/lib
NL="$TL_TMP/plugin-nolib"    # scripts only (hook libraries absent)
mkdir -p "$FX/scripts" "$FX/templates" "$NL/scripts"
cp "$TL_REPO_ROOT/scripts/silver-bullet" "$FX/scripts/"
cp "$TL_REPO_ROOT/scripts/silver-bullet" "$NL/scripts/"
cp -R "$TL_REPO_ROOT/hooks" "$FX/hooks"
cp "$TL_REPO_ROOT/templates/silver-bullet.config.json.default" "$FX/templates/"
SB="$FX/scripts/silver-bullet"
SBN="$NL/scripts/silver-bullet"
RECEIPTS="$SB_RUNTIME_STATE_DIR/skill-invocations"

mkskill() { # mkskill ROOT DIR [file] [content]
  mkdir -p "$1/$2"
  printf '%s\n' "${4:-body of $2}" >"$1/$2/${3:-SKILL.md}"
}
run() { tl_run bash "$SB" "$@"; }

# --- usage / dispatch -----------------------------------------------------------
for a in "" -h --help help; do
  if [[ -z "$a" ]]; then run; else run "$a"; fi
  assert_eq "help '$a' exits 0" 0 "$TL_STATUS"
  assert_contains "help '$a' usage" "$TL_OUT" "Usage: silver-bullet invoke-skill <skill-name> [arguments...]"
done
run frobnicate
assert_eq "unknown command exits 2" 2 "$TL_STATUS"
assert_contains "unknown command message" "$TL_ERR" "ERROR: unknown command: frobnicate"
assert_contains "unknown command shows usage" "$TL_ERR" "Usage: silver-bullet invoke-skill"
run invoke-skill
assert_eq "invoke-skill without a name exits 2" 2 "$TL_STATUS"
assert_contains "invoke-skill without a name shows usage" "$TL_ERR" "Usage: silver-bullet invoke-skill"
run invoke-skill silver:feature
assert_eq "retired silver: namespace exits 2" 2 "$TL_STATUS"
assert_contains "retired namespace message" "$TL_ERR" "the retired silver: skill namespace is not supported; use sb:<route>"

# --- discovery order and naming ---------------------------------------------------
run invoke-skill sb:nothing-here
assert_eq "undiscoverable skill exits 1" 1 "$TL_STATUS"
assert_contains "undiscoverable skill message" "$TL_ERR" "ERROR: skill not installed or not discoverable: sb:nothing-here"
assert_file_absent "no receipt for a missing skill" "$RECEIPTS"

mkskill "$FX/skills" silver-feature SKILL.md "FEATURE BODY"
run invoke-skill sb:feature
assert_eq "sb:feature resolves" 0 "$TL_STATUS"
assert_contains "banner" "$TL_OUT" "Silver Bullet skill invocation adapter"
assert_contains "raw name shown" "$TL_OUT" "Skill: sb:feature"
assert_contains "canonical name shown" "$TL_OUT" "Canonical: silver-feature"
assert_contains "source path shown" "$TL_OUT" "Source: $FX/skills/silver-feature/SKILL.md"
assert_contains "body between markers" "$TL_OUT" $'----- BEGIN SKILL silver-feature -----\nFEATURE BODY'
assert_contains "end marker" "$TL_OUT" "----- END SKILL silver-feature -----"
assert_contains "closing instruction" "$TL_OUT" "Follow the skill instructions above."
assert_not_contains "no runtime-arguments section without args" "$TL_OUT" "Runtime arguments"

# arguments are surfaced
run invoke-skill sb:feature build the thing "now please"
assert_contains "arguments announced" "$TL_OUT" $'Runtime arguments for this skill ($ARGUMENTS):\nbuild the thing now please'
assert_contains "arguments reminder" "$TL_OUT" 'Use the runtime arguments above wherever the skill refers to `$ARGUMENTS`.'

# receipt
RC="$(find "$RECEIPTS" -name 'silver-feature.*.json' | head -1)"
assert_file_exists "receipt written" "$RC"
assert_eq "receipt channel" "silver-bullet.invoke-skill" "$(jq -r .channel "$RC")"
assert_eq "receipt status" "loaded" "$(jq -r .status "$RC")"
assert_eq "receipt raw skill" "sb:feature" "$(jq -r .raw_skill "$RC")"
assert_eq "receipt canonical skill" "silver-feature" "$(jq -r .canonical_skill "$RC")"
assert_eq "receipt skill file" "$FX/skills/silver-feature/SKILL.md" "$(jq -r .skill_file "$RC")"
assert_eq "receipt script path" "$SB" "$(jq -r .script "$RC")"
assert_eq "receipt cwd" "$(pwd -P)" "$(jq -r .cwd "$RC")"
assert_match "receipt timestamp" '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z$' "$(jq -r .timestamp "$RC")"
assert_match "receipt epoch is numeric" '^[0-9]+$' "$(jq -r .timestamp_epoch "$RC")"

# candidate names: silver-X also tries sb-X; SILVER_SOURCE files count
mkskill "$FX/skills" sb-widget SKILL.md "WIDGET"
run invoke-skill silver-widget
assert_eq "silver-widget finds sb-widget directory" 0 "$TL_STATUS"
assert_contains "sb-widget source used" "$TL_OUT" "Source: $FX/skills/sb-widget/SKILL.md"
mkskill "$FX/skill-source" silver-gadget SILVER_SOURCE "GADGET SRC"
run invoke-skill sb:gadget
assert_contains "SILVER_SOURCE file used" "$TL_OUT" "Source: $FX/skill-source/silver-gadget/SILVER_SOURCE"
assert_contains "SILVER_SOURCE content printed" "$TL_OUT" "GADGET SRC"

# short name (namespace stripped) and required-skill aliases
mkskill "$FX/skills" tooling SKILL.md "TOOLING"
run invoke-skill vendor:tooling
assert_contains "vendor:tooling resolves by its short name" "$TL_OUT" "Source: $FX/skills/tooling/SKILL.md"
mkskill "$FX/skills" writing-plans SKILL.md "PLANS ALIAS"
run invoke-skill sb:plan
assert_contains "silver-plan alias writing-plans is found" "$TL_OUT" "Source: $FX/skills/writing-plans/SKILL.md"

# root precedence: runtime skills dir beats the plugin skills dir
mkskill "$SB_RUNTIME_HOME_ROOT/skills" silver-feature SKILL.md "RUNTIME COPY"
run invoke-skill sb:feature
assert_contains "runtime skills dir wins" "$TL_OUT" "Source: $SB_RUNTIME_HOME_ROOT/skills/silver-feature/SKILL.md"
rm -rf "${SB_RUNTIME_HOME_ROOT:?}/skills"

# plugin-cache roots (several depths, plus upstream)
mkskill "$SB_RUNTIME_PLUGIN_CACHE_ROOT/vendor/1.0/skills" cached-one SKILL.md "CACHED"
run invoke-skill cached-one
assert_contains "cache skills dir searched" "$TL_OUT" "Source: $SB_RUNTIME_PLUGIN_CACHE_ROOT/vendor/1.0/skills/cached-one/SKILL.md"
mkskill "$SB_RUNTIME_PLUGIN_CACHE_ROOT/vendor/upstream/skills" cached-two SKILL.md "CACHED2"
run invoke-skill cached-two
assert_contains "cache upstream/skills searched" "$TL_OUT" "Source: $SB_RUNTIME_PLUGIN_CACHE_ROOT/vendor/upstream/skills/cached-two/SKILL.md"
mkskill "$HOME/.agents/skills" agent-skill SKILL.md "AGENTS"
run invoke-skill agent-skill
assert_contains "HOME agents skills dir searched" "$TL_OUT" "Source: $HOME/.agents/skills/agent-skill/SKILL.md"

# content search fallback: directory name differs from the frontmatter name
mkskill "$FX/skills" misnamed-dir SKILL.md $'---\nname: real.name+1\n---\nMISNAMED BODY'
PATH="$(tl_path_without rg)" run invoke-skill real.name+1
assert_eq "frontmatter name found by content search (find/grep)" 0 "$TL_STATUS"
assert_contains "content search result used" "$TL_OUT" "Source: $FX/skills/misnamed-dir/SKILL.md"
assert_contains "content search body printed" "$TL_OUT" "MISNAMED BODY"
mkskill "$FX/skills" misnamed-dir2 SKILL.md $'---\nname: "quoted-name"\n---\nQ'
PATH="$(tl_path_without rg)" run invoke-skill quoted-name
assert_contains "quoted frontmatter name matches" "$TL_OUT" "Source: $FX/skills/misnamed-dir2/SKILL.md"
PATH="$(tl_path_without rg)" run invoke-skill never-defined-anywhere
assert_eq "find/grep search finding nothing -> not discoverable" 1 "$TL_STATUS"
# with rg available the search goes through it
tl_stub rg 'echo "'"$FX"'/skills/misnamed-dir/SKILL.md"; echo "$@" >"'"$TL_TMP"'/rg.args"'
run invoke-skill real.name+1
assert_contains "rg result used" "$TL_OUT" "Source: $FX/skills/misnamed-dir/SKILL.md"
assert_contains "rg searches SKILL.md and SILVER_SOURCE" "$(cat "$TL_TMP/rg.args")" "-g SKILL.md -g SILVER_SOURCE"
tl_stub rg 'exit 1'
run invoke-skill totally-absent-skill
assert_eq "rg finding nothing -> not discoverable" 1 "$TL_STATUS"
rm -f "$TL_BIN/rg"

# --- receipts: refusal through a symlinked directory ---------------------------------
rm -rf "$RECEIPTS"
mkdir -p "$TL_TMP/elsewhere"; ln -s "$TL_TMP/elsewhere" "$RECEIPTS"
run invoke-skill sb:feature
assert_eq "symlinked receipt dir is refused" 1 "$TL_STATUS"
assert_contains "symlink refusal message" "$TL_ERR" "ERROR: refusing to write invocation receipt through symlinked directory: $RECEIPTS"
assert_not_contains "skill body not emitted when no receipt can be written" "$TL_OUT" "BEGIN SKILL"
assert_eq "nothing written through the symlink" "" "$(ls -A "$TL_TMP/elsewhere")"
rm -f "$RECEIPTS"

# state dir default when SB_RUNTIME_STATE_DIR is unset (and no runtime-paths library)
tl_run env -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_PLUGIN_CACHE_ROOT -u SB_RUNTIME_NAME -u SILVER_BULLET_RUNTIME \
  bash "$SBN" invoke-skill sb:feature
assert_eq "without hook libs and a skill root it is not discoverable" 1 "$TL_STATUS"
mkskill "$NL/skills" silver-feature SKILL.md "NOLIB FEATURE"
tl_run env -u SB_RUNTIME_STATE_DIR -u SB_RUNTIME_HOME_ROOT -u SB_RUNTIME_PLUGIN_CACHE_ROOT -u SB_RUNTIME_NAME -u SILVER_BULLET_RUNTIME \
  bash "$SBN" invoke-skill sb:feature
assert_eq "without hook libs the adapter still works" 0 "$TL_STATUS"
assert_contains "no-lib body" "$TL_OUT" "NOLIB FEATURE"
assert_eq "receipt goes to ~/.codex/.silver-bullet by default" 1 "$(find "$HOME/.codex/.silver-bullet/skill-invocations" -name 'silver-feature.*.json' | wc -l | tr -d ' ')"

# --- the built-in canonical-name fallback (hook libraries absent) -----------------------
canon() { # canon NAME -> prints canonical via sourcing the no-lib copy
  bash -c 'script="$1"; name="$2"; set --; source "$script" >/dev/null; canonical_skill_name "$name"' _ "$SBN" "$1"
}
assert_eq "sb:review" "silver-review" "$(canon sb:review)"
assert_eq "sb alone" "silver" "$(canon sb)"
assert_eq "sb-review" "silver-review" "$(canon sb-review)"
assert_eq "silver alone" "silver" "$(canon silver)"
assert_eq "silver:route keeps its namespace" "silver:route" "$(canon silver:route)"
assert_eq "foreign namespace is stripped" "tooling" "$(canon a:b:tooling)"
assert_eq "plain name unchanged" "plain-name" "$(canon plain-name)"

# the library implementation is preferred when present
assert_eq "library: sb:security maps to security" "security" "$(bash -c 'script="$1"; set --; source "$script" >/dev/null; canonical_skill_name sb:security' _ "$SB")"

tl_results
