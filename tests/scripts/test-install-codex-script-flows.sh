#!/usr/bin/env bash
# scripts/install-codex.sh top-level flows in --public-release / seed-only
# modes: no local checkout sync, no network, a fabricated marketplace snapshot
# and a stub codex CLI, all under a sandboxed home.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

INSTALL="$TL_REPO_ROOT/scripts/install-codex.sh"
CH="$TL_TMP/codex-home"
CFG="$CH/.codex/config.toml"
MP="$CH/.codex/.tmp/marketplaces/alo-labs-codex"
CACHE="$CH/.codex/plugins/cache/alo-labs-codex/silver-bullet"
PROJ="$TL_TMP/proj"
mkdir -p "$PROJ" "$TL_TMP/outside"
printf '{}\n' >"$PROJ/.silver-bullet.json"; : >"$PROJ/silver-bullet.md"
tl_stub codex 'exit 0'

make_pkg() {
  local root="$1" s
  mkdir -p "$root/.codex-plugin" "$root/hooks" "$root/scripts"
  printf '{"name":"silver-bullet","version":"1.2.3"}\n' >"$root/.codex-plugin/plugin.json"
  for s in sb-init sb sb-feature; do
    mkdir -p "$root/skill-source/$s"
    printf -- '---\nname: %s\ndescription: d\n---\nbody\n' "$s" >"$root/skill-source/$s/SILVER_SOURCE"
  done
  printf 'rules\n' >"$root/hooks/core-rules.md"
  cat >"$root/hooks/hooks.json" <<'JSON'
{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"${CLAUDE_PLUGIN_ROOT}/hooks/a.sh","async":true}]}]}}
JSON
  printf '#!/usr/bin/env bash\necho sb\n' >"$root/scripts/silver-bullet"
}
fresh() { rm -rf "$CH"; mkdir -p "$CH/.codex"; make_pkg "$MP/plugins/silver-bullet"; }
# run_install <cwd> [env assignments...] -- <install args>
run_install() {
  local cwd="$1"; shift
  local -a envs=()
  while [[ "$1" != -- ]]; do envs+=("$1"); shift; done
  shift
  tl_run bash -c 'cd "$1"; shift; exec env "$@"' _ "$cwd" HOME="$HOME" CODEX_HOME_ROOT_UNUSED=1 "${envs[@]}" bash "$INSTALL" "$@"
}

# ---- argument handling
run_install "$TL_TMP/outside" -- --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help prints usage" "$TL_OUT" "Usage: scripts/install-codex.sh"
run_install "$TL_TMP/outside" -- --bogus
assert_eq "unknown argument exits 2" 2 "$TL_STATUS"
assert_contains "unknown argument named" "$TL_ERR" "Unknown argument: --bogus"

# ---- missing codex CLI
fresh
run_install "$TL_TMP/outside" PATH="$(tl_path_without codex)" HOME="$CH" -- --public-release
assert_eq "missing codex CLI exits 1" 1 "$TL_STATUS"
assert_contains "missing codex CLI explained" "$TL_ERR" "codex CLI not found in PATH"

# ---- hook trust seeding only
fresh
mkdir -p "$CACHE/1.2.3"
run_install "$PROJ" HOME="$CH" -- --hook-trust-seed-only
assert_eq "seed-only inside a project exits 0" 0 "$TL_STATUS"
assert_contains "trust state seeded in the config" "$(<"$CFG")" "hooks.state"
assert_contains "async flags normalized for the marketplace package" "false" "$(jq -r '.hooks.PreToolUse[0].hooks[0].async' "$MP/plugins/silver-bullet/hooks/hooks.json")"
fresh
run_install "$TL_TMP/outside" HOME="$CH" -- --hook-trust-seed-only
assert_eq "seed-only outside a project exits 0" 0 "$TL_STATUS"
assert_not_contains "no trust seeded outside a project" "$(cat "$CFG" 2>/dev/null || true)" "hooks.state"
rm -rf "$CH"; mkdir -p "$CH/.codex"
run_install "$PROJ" HOME="$CH" -- --hook-trust-seed-only
assert_eq "seed-only without any marketplace exits 0" 0 "$TL_STATUS"

# ---- full public-release install inside a Silver Bullet project
fresh
run_install "$PROJ" HOME="$CH" -- --public-release
assert_eq "public-release install exits 0" 0 "$TL_STATUS"
assert_contains "published source reported" "$TL_OUT" "Codex marketplace refreshed from published source https://github.com/alo-labs/agent-plugins"
CONFIG="$(<"$CFG")"
assert_contains "marketplace registered as git source" "$CONFIG" 'source_type = "git"'
assert_contains "plugin enabled in a project" "$CONFIG" '[plugins."silver-bullet@alo-labs-codex"]'
assert_contains "plugin_hooks feature enabled" "$CONFIG" 'plugin_hooks = true'
assert_file_exists "package cached" "$CACHE/1.2.3/.codex-plugin/plugin.json"
assert_eq "stable alias created" "$CACHE/1.2.3" "$(readlink "$CACHE/current")"
assert_file_exists "registry entry created" "$CH/.codex/plugins/installed_plugins.json"
assert_file_exists "CLI shim installed" "$CH/.codex/bin/silver-bullet"
assert_eq "SB hooks are not merged into the user hooks by default" "no" "$([[ -f "$CH/.codex/hooks.json" ]] && echo yes || echo no)"
# second run converges: one marketplace, one plugin entry, one registry entry, trust kept
run_install "$PROJ" HOME="$CH" -- --public-release
assert_eq "second install exits 0" 0 "$TL_STATUS"
SECOND="$(<"$CFG")"
assert_eq "one marketplace section after a second run" 1 "$(grep -c '^\[marketplaces.alo-labs-codex\]' <<<"$SECOND")"
assert_eq "one plugin section after a second run" 1 "$(grep -c '^\[plugins."silver-bullet@alo-labs-codex"\]' <<<"$SECOND")"
assert_eq "trusted hook hash kept after a second run" 1 "$(grep -c 'trusted_hash' <<<"$SECOND")"
assert_eq "one registry entry after a second run" 1 "$(jq '.plugins["silver-bullet@alo-labs-codex"] | length' "$CH/.codex/plugins/installed_plugins.json")"

# ---- explicit merge request merges the SB hook bundle into the user hooks
fresh
run_install "$PROJ" HOME="$CH" SB_CODEX_MERGE_USER_HOOKS=1 -- --public-release
assert_eq "install with user-hook merge exits 0" 0 "$TL_STATUS"
assert_contains "SB hook merged into ~/.codex/hooks.json" "$(jq -r '[.. | .command? // empty] | join(",")' "$CH/.codex/hooks.json")" "a.sh"
# KAY_HOME selects the home and enables the merge by default
fresh
KAY="$TL_TMP/kay"
rm -rf "$KAY"; mkdir -p "$KAY/.codex"
cp -R "$CH/.codex/.tmp" "$KAY/.codex/.tmp"
run_install "$PROJ" HOME="$TL_TMP/unused-home" KAY_HOME="$KAY" -- --public-release
assert_eq "KAY_HOME install exits 0" 0 "$TL_STATUS"
assert_file_exists "KAY_HOME receives the config" "$KAY/.codex/config.toml"
assert_file_exists "KAY_HOME gets merged user hooks by default" "$KAY/.codex/hooks.json"
assert_file_absent "HOME is not used when KAY_HOME is set" "$TL_TMP/unused-home/.codex"

# ---- outside a project: nothing is enabled, and an existing enablement is left alone (R7-10)
fresh
run_install "$TL_TMP/outside" HOME="$CH" -- --public-release
assert_eq "fresh install outside a project exits 0" 0 "$TL_STATUS"
assert_contains "auto-enable skipped outside a project" "$TL_OUT" "Skipping Silver Bullet plugin auto-enable outside a Silver Bullet project root"
assert_not_contains "a fresh install outside a project enables nothing" "$(<"$CFG")" 'silver-bullet@alo-labs-codex"]'
# installed and trusted from a project, then refreshed from the home directory
run_install "$PROJ" HOME="$CH" -- --public-release
BEFORE_PLUGIN="$(grep -A1 '^\[plugins."silver-bullet@alo-labs-codex"\]' "$CFG")"
BEFORE_TRUST="$(grep -c 'trusted_hash' "$CFG")"
run_install "$TL_TMP/outside" HOME="$CH" -- --public-release --purge-legacy-skills
assert_eq "refresh outside a project exits 0" 0 "$TL_STATUS"
assert_eq "existing enablement kept" "$BEFORE_PLUGIN" "$(grep -A1 '^\[plugins."silver-bullet@alo-labs-codex"\]' "$CFG")"
assert_eq "existing hook trust kept" "$BEFORE_TRUST" "$(grep -c 'trusted_hash' "$CFG")"
assert_eq "registry entry kept" 1 "$(jq '.plugins["silver-bullet@alo-labs-codex"] | length' "$CH/.codex/plugins/installed_plugins.json")"

# ---- foreign data survives install, re-install and the legacy-skill purge
fresh
mkdir -p "$CH/.agents/skills/security" "$CH/.codex/skills/security" "$CH/.codex/plugins/cache/thirdparty/other/abc"
printf -- '---\nname: security\n---\nteam checklist\n' >"$CH/.agents/skills/security/SKILL.md"
printf -- '---\nname: security\n---\nmine\n' >"$CH/.codex/skills/security/SKILL.md"
printf '{"plugins":{"other@thirdparty":[{"installPath":"%s","version":"abc"}]}}\n' "$CH/.codex/plugins/cache/thirdparty/other/abc" >"$CH/.codex/plugins/installed_plugins.json"
printf '# keep this comment\n[profiles.work]\nmodel = "o3"\n\n[plugins."other@thirdparty"]\nenabled = true\n' >"$CFG"
for pass in install re-install; do
  run_install "$PROJ" HOME="$CH" -- --public-release --purge-legacy-skills
  assert_eq "$pass with foreign data exits 0" 0 "$TL_STATUS"
  assert_contains "$pass keeps the user's ~/.agents skill" "$(<"$CH/.agents/skills/security/SKILL.md")" "team checklist"
  assert_contains "$pass keeps the user's ~/.codex skill" "$(<"$CH/.codex/skills/security/SKILL.md")" "mine"
  assert_eq "$pass keeps the foreign registry record" '[{"installPath":"'"$CH"'/.codex/plugins/cache/thirdparty/other/abc","version":"abc"}]' "$(jq -c '.plugins["other@thirdparty"]' "$CH/.codex/plugins/installed_plugins.json")"
  assert_contains "$pass keeps config comments" "$(<"$CFG")" "# keep this comment"
  assert_contains "$pass keeps foreign config tables" "$(<"$CFG")" '[plugins."other@thirdparty"]'
  assert_eq "$pass leaves valid TOML with one SB plugin table" 1 "$(python3 -c 'import sys
try:
    import tomllib
except ImportError:
    from pip._vendor import tomli as tomllib
d = tomllib.load(open(sys.argv[1], "rb"))
print(int(d["plugins"]["silver-bullet@alo-labs-codex"]["enabled"]) + 0 * len(d["profiles"]))' "$CFG")"
done

tl_results
