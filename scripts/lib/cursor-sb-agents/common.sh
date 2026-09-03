#!/usr/bin/env bash
# Shared helpers for Cursor SB custom subagents installer and probe.
set -euo pipefail

CSBA_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSBA_REPO_ROOT="${CSBA_REPO_ROOT:-$(cd "${CSBA_LIB_DIR}/../../.." && pwd)}"
CSBA_PYTHON="${CSBA_PYTHON:-python3}"
CSBA_FETCH="${CSBA_LIB_DIR}/fetch-cursor-models.py"
CSBA_PY_LIB="${CSBA_LIB_DIR}/cursor_sb_agents_lib.py"
CSBA_MANAGED_MARKER='<!-- sb-managed: cursor-sb-agents -->'
CSBA_GLOBAL_CONFIG="${SB_CURSOR_SB_AGENTS_CONFIG:-${HOME}/.config/silver-bullet/cursor-sb-agents.json}"
CSBA_GLOBAL_CATALOG="${SB_CURSOR_MODELS_CATALOG:-${HOME}/.config/silver-bullet/cursor-models-catalog.json}"
CSBA_TEMPLATE="${CSBA_LIB_DIR}/../install-cursor/templates/cursor-agents/sb-agent.md.template"

csba_default_config_json() {
  "${CSBA_PYTHON}" -c "import sys, json; sys.path.insert(0, '${CSBA_LIB_DIR}'); from cursor_sb_agents_lib import default_config; print(json.dumps(default_config()))"
}

csba_project_config_path() {
  local root="${1:-${CSBA_REPO_ROOT}}"
  printf '%s/.silver-bullet.json' "$root"
}

csba_load_merged_config() {
  local project_root="${1:-${CSBA_REPO_ROOT}}"
  local project_cfg global_cfg
  project_cfg="$(csba_project_config_path "$project_root")"
  if [[ -f "$project_cfg" ]] && jq -e '.cursor_sb_agents' "$project_cfg" >/dev/null 2>&1; then
    jq -c '.cursor_sb_agents' "$project_cfg"
    return 0
  fi
  if [[ -f "$CSBA_GLOBAL_CONFIG" ]]; then
    cat "$CSBA_GLOBAL_CONFIG"
    return 0
  fi
  csba_default_config_json
}

csba_write_global_config() {
  local config_json="$1"
  mkdir -p "$(dirname "$CSBA_GLOBAL_CONFIG")"
  printf '%s\n' "$config_json" >"$CSBA_GLOBAL_CONFIG"
}

csba_merge_project_config() {
  local project_root="$1"
  local config_json="$2"
  local project_cfg
  project_cfg="$(csba_project_config_path "$project_root")"
  [[ -f "$project_cfg" ]] || return 0
  local tmp
  tmp="$(mktemp)"
  jq --argjson cfg "$config_json" '.cursor_sb_agents = $cfg' "$project_cfg" >"$tmp"
  mv "$tmp" "$project_cfg"
}

csba_agents_dir_for_scope() {
  local scope="$1"
  local project_root="${2:-${CSBA_REPO_ROOT}}"
  case "$scope" in
    global) printf '%s/.cursor/agents\n' "$HOME" ;;
    project) printf '%s/.cursor/agents\n' "$project_root" ;;
    *) return 1 ;;
  esac
}

csba_refresh_catalog() {
  local repo_root="${1:-${CSBA_REPO_ROOT}}"
  if [[ "${SB_CURSOR_SB_AGENTS_OFFLINE:-}" == "1" ]]; then if [[ -f "$CSBA_GLOBAL_CATALOG" ]] || [[ -f "${repo_root}/.silver-bullet/cursor-models-catalog.json" ]]; then return 0; fi; fi
  "${CSBA_PYTHON}" "$CSBA_FETCH" --repo-root "$repo_root"
}

csba_expected_names() {
  local config_json="$1"
  local catalog_path="${2:-$CSBA_GLOBAL_CATALOG}"
  CONFIG_JSON="$config_json" CATALOG_PATH="$catalog_path" CSBA_LIB_DIR="$CSBA_LIB_DIR" \
    "${CSBA_PYTHON}" - <<'PY'
import json, os, sys
sys.path.insert(0, os.environ["CSBA_LIB_DIR"])
from cursor_sb_agents_lib import expected_agent_names, load_json
cfg = json.loads(os.environ["CONFIG_JSON"])
print("\n".join(expected_agent_names(cfg)))
PY
}

csba_expected_count() {
  local config_json="$1"
  CONFIG_JSON="$config_json" CSBA_LIB_DIR="$CSBA_LIB_DIR" \
    "${CSBA_PYTHON}" - <<'PY'
import json, os, sys
sys.path.insert(0, os.environ["CSBA_LIB_DIR"])
from cursor_sb_agents_lib import expected_agent_names
cfg = json.loads(os.environ["CONFIG_JSON"])
print(len(expected_agent_names(cfg)))
PY
}

csba_file_has_managed_marker() {
  local file="$1"
  grep -qF "$CSBA_MANAGED_MARKER" "$file" 2>/dev/null
}

csba_frontmatter_name() {
  local file="$1"
  awk 'BEGIN{in_fm=0} /^---$/ {in_fm++; next} in_fm==1 && /^name:/ {sub(/^name:[[:space:]]*/,""); print; exit}' "$file"
}

csba_collect_managed_agents() {
  local agents_dir="$1"
  local -a files=()
  shopt -s nullglob
  for f in "${agents_dir}"/sb-*.md; do
    [[ -f "$f" ]] || continue
    csba_file_has_managed_marker "$f" || continue
    files+=("$f")
  done
  shopt -u nullglob
  if ((${#files[@]})); then
    printf '%s\n' "${files[@]}"
  fi
}

csba_names_match() {
  local expected_file="$1"
  local actual_file="$2"
  sort "$expected_file" | cmp -s - <(sort "$actual_file")
}

