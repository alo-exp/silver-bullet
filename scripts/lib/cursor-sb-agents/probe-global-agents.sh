#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"
CONFIG_JSON=""; JSON_OUT=0; AGENTS_DIR="${HOME}/.cursor/agents"; QUIET=0; REPO_ROOT="${CSBA_REPO_ROOT}"
while [[ $# -gt 0 ]]; do case $1 in --config-json) CONFIG_JSON="$2"; shift 2;; --agents-dir) AGENTS_DIR="$2"; shift 2;; --repo-root) REPO_ROOT="$2"; shift 2;; --quiet) QUIET=1; shift;; --json) JSON_OUT=1; shift;; *) shift;; esac; done
if [[ -n "${SB_CURSOR_SB_AGENTS_CONFIG:-}" ]]; then CONFIG_JSON="$SB_CURSOR_SB_AGENTS_CONFIG"; elif [[ -z "$CONFIG_JSON" ]]; then CONFIG_JSON="$(csba_load_merged_config "$REPO_ROOT")"; fi
EXPECTED_COUNT="$(csba_expected_count "$CONFIG_JSON")"; EN=$(mktemp); AN=$(mktemp); trap "rm -f $EN $AN" EXIT
csba_expected_names "$CONFIG_JSON" >"$EN"; MANAGED=(); while IFS= read -r f; do MANAGED+=("$f"); done < <(csba_collect_managed_agents "$AGENTS_DIR" || true)
AC=${#MANAGED[@]}; : >"$AN"; for f in "${MANAGED[@]:-}"; do n=$(csba_frontmatter_name "$f"); [[ -n "$n" ]] && echo "$n" >>"$AN"; done
emit_json(){ jq -n --argjson ok "$1" --argjson ec "$EXPECTED_COUNT" --argjson ac "$AC" --arg r "$2" --arg ad "$AGENTS_DIR" --rawfile er "$EN" --rawfile ar "$AN" "{ok:\$ok,expected_count:\$ec,actual_count:\$ac,expected_names:(\$er|split(\"\\n\")|map(select(length>0))),found_names:(\$ar|split(\"\\n\")|map(select(length>0))),agents_dir:\$ad,reason:(if \$r==\"\" then null else \$r end)}"; }
fail(){ [[ "$JSON_OUT" -eq 1 ]] && { emit_json false "$1"; exit 1; }; echo "FAIL $1" >&2; exit 1; }
[[ "$AC" -eq "$EXPECTED_COUNT" ]] || fail count; csba_names_match "$EN" "$AN" || fail names
[[ -f "$CSBA_GLOBAL_CONFIG" ]] && jq -e ".agents_install_status==\"installed\"" "$CSBA_GLOBAL_CONFIG" >/dev/null || fail status
[[ "$JSON_OUT" -eq 1 ]] && emit_json true "" || echo PASS; exit 0
