#!/usr/bin/env bash
# scripts/lib/cursor-sb-agents/probe-global-agents.sh and common.sh helpers,
# in a sandboxed HOME with hand-written managed agent files.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init claude

PROBE="$TL_REPO_ROOT/scripts/lib/cursor-sb-agents/probe-global-agents.sh"
CFGDIR="$HOME/.config/silver-bullet"
AGENTS="$HOME/.cursor/agents"
PROJ="$TL_TMP/proj"
mkdir -p "$CFGDIR" "$AGENTS" "$PROJ"
unset SB_CURSOR_SB_AGENTS_CONFIG SB_CURSOR_MODELS_CATALOG CSBA_REPO_ROOT
CFG='{"selected_models":["composer-2.5"],"effort_levels":["medium","high"],"agent_name_prefix":"sb"}'

agent_file() { # agent_file <dir> <file-stem> <frontmatter-name> [marker]
  printf -- '---\nname: %s\n---\n%s\nbody\n' "$3" "${4-<!-- sb-managed: cursor-sb-agents -->}" >"$1/$2.md"
}
agent_file "$AGENTS" sb-composer-2-5-medium sb-composer-2-5-medium
agent_file "$AGENTS" sb-composer-2-5-high sb-composer-2-5-high
printf '{"agents_install_status":"installed"}\n' >"$CFGDIR/cursor-sb-agents.json"

probe() { tl_run bash "$PROBE" "$@"; }

# ---- usage
probe --help
assert_eq "--help exits 0" 0 "$TL_STATUS"
assert_contains "--help usage" "$TL_OUT" "Usage: probe-global-agents.sh"
probe --bogus
assert_eq "unknown option exits 2" 2 "$TL_STATUS"
assert_contains "unknown option named" "$TL_ERR" "Unknown option: --bogus"

# ---- pass
probe --config-json "$CFG"
assert_eq "matching agents pass" 0 "$TL_STATUS"
assert_contains "pass message" "$TL_OUT" "PROBE PASS: 2 managed agents in $AGENTS"
probe --config-json "$CFG" --quiet
assert_eq "quiet pass exits 0" 0 "$TL_STATUS"
assert_eq "quiet pass prints nothing" "" "$TL_OUT"
probe --config-json "$CFG" --json
assert_eq "json pass exits 0" 0 "$TL_STATUS"
assert_eq "json ok" true "$(jq -r .ok <<<"$TL_OUT")"
assert_eq "json expected names" '["sb-composer-2-5-medium","sb-composer-2-5-high"]' "$(jq -c .expected_names <<<"$TL_OUT")"
assert_eq "json found names" '["sb-composer-2-5-medium","sb-composer-2-5-high"]' "$(jq -c '.found_names | sort | reverse' <<<"$TL_OUT")"
assert_eq "json reason null" null "$(jq -c .reason <<<"$TL_OUT")"
assert_eq "json counts" "2/2" "$(jq -r '"\(.actual_count)/\(.expected_count)"' <<<"$TL_OUT")"

# ---- config sources: project config via --repo-root, global config file, default config
printf '{"cursor_sb_agents":%s}\n' "$CFG" >"$PROJ/.silver-bullet.json"
probe --repo-root "$PROJ"
assert_eq "project cursor_sb_agents config used" 0 "$TL_STATUS"
rm -f "$PROJ/.silver-bullet.json"
printf '%s\n' "$CFG" | jq '. + {agents_install_status:"installed"}' >"$CFGDIR/cursor-sb-agents.json"
probe --repo-root "$PROJ"
assert_eq "global config used when no project config" 0 "$TL_STATUS"
rm -f "$CFGDIR/cursor-sb-agents.json"
probe --repo-root "$PROJ" --skip-status
assert_eq "default config (6 agents) mismatches the 2 present" 1 "$TL_STATUS"
assert_contains "default config count mismatch" "$TL_ERR" "count mismatch (actual=2, expected=6)"
printf '{"agents_install_status":"installed"}\n' >"$CFGDIR/cursor-sb-agents.json"

# SB_CURSOR_SB_AGENTS_CONFIG as a file and as inline JSON
printf '%s\n' "$CFG" | jq '. + {agents_install_status:"installed"}' >"$TL_TMP/alt-config.json"
tl_run env SB_CURSOR_SB_AGENTS_CONFIG="$TL_TMP/alt-config.json" bash "$PROBE"
assert_eq "config file via env passes (status read from it)" 0 "$TL_STATUS"
printf '%s\n' "$CFG" | jq '. + {agents_install_status:"pending"}' >"$TL_TMP/pending-config.json"
tl_run env SB_CURSOR_SB_AGENTS_CONFIG="$TL_TMP/pending-config.json" bash "$PROBE"
assert_eq "env config not installed fails" 1 "$TL_STATUS"
assert_contains "not installed reported" "$TL_ERR" "agents_install_status not installed"
tl_run env SB_CURSOR_SB_AGENTS_CONFIG="$CFG" bash "$PROBE" --skip-status
assert_eq "inline JSON via env with --skip-status passes" 0 "$TL_STATUS"
tl_run env SB_CURSOR_SB_AGENTS_CONFIG="$CFG" bash "$PROBE"
assert_eq "inline JSON has no status file" 1 "$TL_STATUS"
assert_contains "missing global config reported" "$TL_ERR" "missing global config"

# ---- status checks against the global config
rm -f "$CFGDIR/cursor-sb-agents.json"
probe --config-json "$CFG"
assert_eq "missing global config fails" 1 "$TL_STATUS"
assert_contains "missing global config explained" "$TL_ERR" "PROBE FAIL: missing global config $CFGDIR/cursor-sb-agents.json"
probe --config-json "$CFG" --quiet
assert_eq "quiet failure exits 1" 1 "$TL_STATUS"
assert_eq "quiet failure prints nothing" "" "$TL_ERR"
probe --config-json "$CFG" --json
assert_eq "json failure exits 1" 1 "$TL_STATUS"
assert_eq "json failure ok=false" false "$(jq -r .ok <<<"$TL_OUT")"
assert_contains "json failure carries the reason" "$(jq -r .reason <<<"$TL_OUT")" "missing global config"
printf '{"agents_install_status":"pending"}\n' >"$CFGDIR/cursor-sb-agents.json"
probe --config-json "$CFG"
assert_eq "pending status fails" 1 "$TL_STATUS"
assert_contains "pending status reported" "$TL_ERR" "agents_install_status not installed"
probe --config-json "$CFG" --skip-status
assert_eq "--skip-status ignores the status" 0 "$TL_STATUS"
printf '{"agents_install_status":"installed"}\n' >"$CFGDIR/cursor-sb-agents.json"

# ---- mismatches
rm -f "$AGENTS/sb-composer-2-5-high.md"
probe --config-json "$CFG"
assert_eq "missing agent fails" 1 "$TL_STATUS"
assert_contains "count mismatch reported" "$TL_ERR" "count mismatch (actual=1, expected=2)"
probe --config-json "$CFG" --json
assert_eq "json count mismatch ok=false" false "$(jq -r .ok <<<"$TL_OUT")"
assert_contains "json count mismatch reason" "$(jq -r .reason <<<"$TL_OUT")" "count mismatch"
agent_file "$AGENTS" sb-composer-2-5-high sb-renamed-high
probe --config-json "$CFG"
assert_eq "wrong name fails" 1 "$TL_STATUS"
assert_contains "name set mismatch reported" "$TL_ERR" "name set mismatch"
# unmanaged files and frontmatter without a name are not counted as names
agent_file "$AGENTS" sb-composer-2-5-high sb-composer-2-5-high
agent_file "$AGENTS" sb-user-custom sb-user-custom ""
printf -- '---\ndescription: x\n---\n<!-- sb-managed: cursor-sb-agents -->\n' >"$AGENTS/sb-nameless.md"
probe --config-json "$CFG"
assert_eq "nameless managed file counts but has no name" 1 "$TL_STATUS"
assert_contains "count includes the nameless managed file" "$TL_ERR" "actual=3"
rm -f "$AGENTS/sb-nameless.md"
probe --config-json "$CFG"
assert_eq "unmanaged sb-* files are ignored" 0 "$TL_STATUS"

# ---- agents dir missing
probe --config-json "$CFG" --agents-dir "$TL_TMP/nope"
assert_eq "missing agents dir fails" 1 "$TL_STATUS"
assert_contains "missing agents dir message" "$TL_ERR" "PROBE FAIL: agents dir missing $TL_TMP/nope"
probe --config-json "$CFG" --agents-dir "$TL_TMP/nope" --quiet
assert_eq "quiet missing dir prints nothing" "" "$TL_ERR"
probe --config-json "$CFG" --agents-dir "$TL_TMP/nope" --json
assert_eq "json missing dir ok=false" false "$(jq -r .ok <<<"$TL_OUT")"
assert_eq "json missing dir reason" "agents dir missing" "$(jq -r .reason <<<"$TL_OUT")"
EMPTY="$TL_TMP/empty-agents"
mkdir -p "$EMPTY"
probe --config-json "$CFG" --agents-dir "$EMPTY" --skip-status
assert_eq "empty agents dir is a count mismatch" 1 "$TL_STATUS"
assert_contains "empty dir counts zero" "$TL_ERR" "actual=0, expected=2"

# ---- common.sh helpers (sourced so they run in this shell)
export HOME
unset SB_CURSOR_SB_AGENTS_CONFIG
# shellcheck source=scripts/lib/cursor-sb-agents/common.sh
source "$TL_REPO_ROOT/scripts/lib/cursor-sb-agents/common.sh"
set +e
assert_eq "project config path" "$PROJ/.silver-bullet.json" "$(csba_project_config_path "$PROJ")"
assert_eq "project config path defaults to the repo root" "$CSBA_REPO_ROOT/.silver-bullet.json" "$(csba_project_config_path)"
assert_eq "default config has the default models" '["composer-2.5","grok-4.5"]' "$(csba_default_config_json | jq -c .selected_models)"
rm -f "$CSBA_GLOBAL_CONFIG"
assert_eq "merged config falls back to defaults" "pending" "$(csba_load_merged_config "$PROJ" | jq -r .agents_install_status)"
csba_write_global_config '{"marker":"global"}'
assert_eq "global config written" '{"marker":"global"}' "$(<"$CSBA_GLOBAL_CONFIG")"
assert_eq "merged config prefers the global file" global "$(csba_load_merged_config "$PROJ" | jq -r .marker)"
printf '{"other":1}\n' >"$PROJ/.silver-bullet.json"
assert_eq "project file without cursor_sb_agents is skipped" global "$(csba_load_merged_config "$PROJ" | jq -r .marker)"
printf '{"cursor_sb_agents":{"marker":"project"},"keep":1}\n' >"$PROJ/.silver-bullet.json"
assert_eq "merged config prefers the project block" project "$(csba_load_merged_config "$PROJ" | jq -r .marker)"
csba_merge_project_config "$PROJ" '{"marker":"merged"}'
assert_eq "project block replaced" merged "$(jq -r .cursor_sb_agents.marker "$PROJ/.silver-bullet.json")"
assert_eq "other project keys preserved" 1 "$(jq -r .keep "$PROJ/.silver-bullet.json")"
csba_merge_project_config "$TL_TMP/no-project" '{"x":1}'
assert_eq "merge without a project file is a no-op" 0 "$?"
assert_file_absent "no project file created" "$TL_TMP/no-project/.silver-bullet.json"
assert_eq "global agents dir" "$HOME/.cursor/agents" "$(csba_agents_dir_for_scope global "$PROJ")"
assert_eq "project agents dir" "$PROJ/.cursor/agents" "$(csba_agents_dir_for_scope project "$PROJ")"
csba_agents_dir_for_scope bogus "$PROJ" >/dev/null
assert_eq "unknown scope rejected" 1 "$?"
assert_eq "expected names" "sb-composer-2-5-medium
sb-composer-2-5-high" "$(csba_expected_names "$CFG")"
assert_eq "expected count" 2 "$(csba_expected_count "$CFG")"
assert_eq "frontmatter name" sb-composer-2-5-medium "$(csba_frontmatter_name "$AGENTS/sb-composer-2-5-medium.md")"
csba_file_has_managed_marker "$AGENTS/sb-composer-2-5-medium.md"
assert_eq "marker detected" 0 "$?"
csba_file_has_managed_marker "$AGENTS/sb-user-custom.md"
assert_eq "missing marker detected" 1 "$?"
rc=0; csba_file_has_managed_marker "$TL_TMP/absent.md" || rc=$?
assert_eq "absent file has no marker" 1 "$([[ $rc -ne 0 ]] && echo 1 || echo 0)"
assert_eq "no managed agents in an empty dir" "" "$(csba_collect_managed_agents "$EMPTY")"
mkdir -p "$AGENTS/sb-a-directory.md"
assert_eq "managed agents collected, unmanaged and directories skipped" "2" "$(csba_collect_managed_agents "$AGENTS" | wc -l | tr -d ' ')"
printf 'a\nb\n' >"$TL_TMP/n1"; printf 'b\na\n' >"$TL_TMP/n2"; printf 'a\nc\n' >"$TL_TMP/n3"
csba_names_match "$TL_TMP/n1" "$TL_TMP/n2"
assert_eq "same names in any order match" 0 "$?"
csba_names_match "$TL_TMP/n1" "$TL_TMP/n3"
assert_eq "different names do not match" 1 "$?"

# catalog refresh: offline mode with a cached catalog skips the fetch; otherwise the fetcher runs
FETCH_LOG="$TL_TMP/fetch.log"
printf '#!/usr/bin/env bash\necho "fetch $*" >>"%s"\n' "$FETCH_LOG" >"$TL_TMP/fake-python"
chmod +x "$TL_TMP/fake-python"
export CSBA_PYTHON="$TL_TMP/fake-python"
CSBA_GLOBAL_CATALOG="$TL_TMP/catalog.json"
echo '{}' >"$CSBA_GLOBAL_CATALOG"
SB_CURSOR_SB_AGENTS_OFFLINE=1 csba_refresh_catalog "$PROJ"
assert_file_absent "offline refresh with a global catalog does not fetch" "$FETCH_LOG"
rm -f "$CSBA_GLOBAL_CATALOG"
mkdir -p "$PROJ/.silver-bullet"
echo '{}' >"$PROJ/.silver-bullet/cursor-models-catalog.json"
SB_CURSOR_SB_AGENTS_OFFLINE=1 csba_refresh_catalog "$PROJ"
assert_file_absent "offline refresh with a project catalog does not fetch" "$FETCH_LOG"
rm -f "$PROJ/.silver-bullet/cursor-models-catalog.json"
SB_CURSOR_SB_AGENTS_OFFLINE=1 csba_refresh_catalog "$PROJ"
assert_contains "offline without any catalog still fetches" "$(<"$FETCH_LOG")" "--repo-root $PROJ"
: >"$FETCH_LOG"
csba_refresh_catalog "$PROJ"
assert_contains "online refresh fetches" "$(<"$FETCH_LOG")" "--repo-root $PROJ"
set -e

tl_results
