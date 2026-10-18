#!/usr/bin/env bash
# Install SB-managed Cursor custom subagents (sb-*) for review/verify ladders.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# REPO_ROOT locates this script's own assets and must stay pinned to the
# checkout. PROJECT_ROOT is the project whose .silver-bullet.json and agents
# dir get written; it follows CSBA_REPO_ROOT (already the override honored by
# common.sh) so callers and tests can target a sandbox instead of silently
# mutating the Silver Bullet checkout itself.
PROJECT_ROOT="${CSBA_REPO_ROOT:-$REPO_ROOT}"
# shellcheck source=lib/cursor-sb-agents/common.sh
source "${REPO_ROOT}/scripts/lib/cursor-sb-agents/common.sh"

SCOPE=""
NON_INTERACTIVE=0
FIX_MODE=0
INCLUDE_FAST=0
INCLUDE_MAX=0
SELECT_MODELS=""
EFFORT_LEVELS=""
CONFIG_JSON=""

usage() {
  cat <<'USAGE'
Usage: scripts/install-cursor-sb-agents.sh [options]

Generate SB-managed custom subagents under ~/.cursor/agents/ (global) or
project .cursor/agents/ with priced multi-select model catalog.

Options:
  --global              Install to ~/.cursor/agents/
  --project             Install to <repo>/.cursor/agents/
  --non-interactive     Defaults: composer-2.5 + grok-4.5 × medium,high,xhigh (6 agents)
  --fix                 Regenerate from persisted config (non-interactive)
  --include-fast        Include Fast model variants
  --include-max         Include Max / Max Mode models
  --select-models LIST  Comma-separated base models (non-interactive)
  --effort-levels LIST  Comma-separated efforts (default: medium,high,xhigh)
  -h, --help            Show this help

Cursor skill sessions may use AskQuestion multi-select when available; this
script provides a numbered CLI fallback with pricing columns.
USAGE
}

# flag_json 0|1 -> false|true (for jq --argjson)
flag_json() {
  if [[ "$1" -eq 1 ]]; then
    echo true
  else
    echo false
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global) SCOPE="global"; shift ;;
    --project) SCOPE="project"; shift ;;
    --non-interactive) NON_INTERACTIVE=1; shift ;;
    --fix) FIX_MODE=1; NON_INTERACTIVE=1; shift ;;
    --include-fast) INCLUDE_FAST=1; shift ;;
    --include-max) INCLUDE_MAX=1; shift ;;
    --select-models|--effort-levels)
      if [[ $# -lt 2 ]]; then
        echo "$1 requires a value" >&2
        usage >&2
        exit 2
      fi
      if [[ "$1" == "--select-models" ]]; then
        SELECT_MODELS="$2"
      else
        EFFORT_LEVELS="$2"
      fi
      shift 2
      ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$SCOPE" ]]; then
  SCOPE="global"
fi

if [[ "$FIX_MODE" -eq 1 ]]; then
  CONFIG_JSON="$(csba_load_merged_config "$PROJECT_ROOT")"
  SCOPE="$(printf '%s' "$CONFIG_JSON" | jq -r '.agents_install_scope // "global"')"
  INCLUDE_FAST="$(printf '%s' "$CONFIG_JSON" | jq -r '.include_fast // false')"
  INCLUDE_MAX="$(printf '%s' "$CONFIG_JSON" | jq -r '.include_max // false')"
  if [[ "$INCLUDE_FAST" == "true" ]]; then
    INCLUDE_FAST=1
  else
    INCLUDE_FAST=0
  fi
  if [[ "$INCLUDE_MAX" == "true" ]]; then
    INCLUDE_MAX=1
  else
    INCLUDE_MAX=0
  fi
fi

csba_refresh_catalog "$PROJECT_ROOT" >/dev/null

# Only called in interactive mode (see the guard below); the answer defaults to no.
prompt_yes_no() {
  local prompt="$1"
  read -r -p "${prompt} [y/N]: " ans || true
  ans="${ans:-}"
  [[ "$ans" =~ ^[Yy] ]]
}

if [[ "$FIX_MODE" -eq 0 && "$NON_INTERACTIVE" -eq 0 ]]; then
  if prompt_yes_no "Include Fast variants?"; then
    INCLUDE_FAST=1
  fi
  if prompt_yes_no "Include Max / Max Mode models?"; then
    INCLUDE_MAX=1
  fi
fi

if [[ -z "$CONFIG_JSON" ]]; then
  if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
    CONFIG_JSON="$(csba_default_config_json)"
    if [[ -n "$SELECT_MODELS" ]]; then
      CONFIG_JSON="$(printf '%s' "$CONFIG_JSON" | jq --arg m "$SELECT_MODELS" \
        '.selected_models = ($m | split(",") | map(gsub("^\\s+|\\s+$"; "")))')"
    fi
    if [[ -n "$EFFORT_LEVELS" ]]; then
      CONFIG_JSON="$(printf '%s' "$CONFIG_JSON" | jq --arg e "$EFFORT_LEVELS" \
        '.effort_levels = ($e | split(",") | map(gsub("^\\s+|\\s+$"; "")))')"
    fi
    CONFIG_JSON="$(printf '%s' "$CONFIG_JSON" | jq \
      --argjson fast "$(flag_json "$INCLUDE_FAST")" \
      --argjson max "$(flag_json "$INCLUDE_MAX")" \
      '.include_fast = $fast | .include_max = $max')"
  else
    echo ""
    echo "Eligible models (pricing per 1M tokens):"
    echo " #  Model ID              Display name                     Pricing"
    echo " -- --------------------- -------------------------------- --------------------------------"
    FAST_ARGS=()
    MAX_ARGS=()
    [[ "$INCLUDE_FAST" -eq 1 ]] && FAST_ARGS+=(--include-fast)
    [[ "$INCLUDE_MAX" -eq 1 ]] && MAX_ARGS+=(--include-max)
    OFFLINE_ARGS=()
    [[ "${SB_CURSOR_SB_AGENTS_OFFLINE:-}" == "1" ]] && OFFLINE_ARGS+=(--no-fetch)
    ROWS=()
    LISTING="$("${CSBA_PYTHON}" "$CSBA_FETCH" --list-selectable "${FAST_ARGS[@]}" "${MAX_ARGS[@]}" "${OFFLINE_ARGS[@]}" --repo-root "$PROJECT_ROOT" 2>/dev/null)" || LISTING=""
    while IFS= read -r row; do
      [[ -n "$row" ]] && ROWS+=("$row")
    done <<<"$LISTING"
    declare -a IDS=()
    local_i=1
    for row in "${ROWS[@]:-}"; do
      IFS=$'\t' read -r mid display pricing <<<"$row"
      IDS+=("$mid")
      printf " %2d %-21s %-32s %s\n" "$local_i" "$mid" "$display" "$pricing"
      local_i=$((local_i + 1))
    done
    echo ""
    echo "Select models (comma-separated numbers or ids; default: composer-2.5,grok-4.5):"
    read -r -p "> " selection || true
    selection="${selection:-composer-2.5,grok-4.5}"
    declare -a SELECTED=()
    IFS=',' read -ra PARTS <<<"$selection"
    for part in "${PARTS[@]}"; do
      part="$(echo "$part" | xargs)"
      if [[ "$part" =~ ^[0-9]+$ ]] && (( part >= 1 && part <= ${#IDS[@]} )); then
        SELECTED+=("${IDS[$((part - 1))]}")
      elif [[ -n "$part" ]]; then
        SELECTED+=("$part")
      fi
    done
    if ((${#SELECTED[@]} == 0)); then
      SELECTED=("composer-2.5" "grok-4.5")
    fi
    models_json="$(printf '%s\n' "${SELECTED[@]}" | jq -R . | jq -s .)"
    CONFIG_JSON="$(csba_default_config_json)"
    CONFIG_JSON="$(printf '%s' "$CONFIG_JSON" | jq --argjson m "$models_json" '.selected_models = $m')"
    read -r -p "Effort levels [medium,high,xhigh]: " effort_in || true
    effort_in="${effort_in:-medium,high,xhigh}"
    effort_json="$(printf '%s' "$effort_in" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | jq -R . | jq -s .)"
    CONFIG_JSON="$(printf '%s' "$CONFIG_JSON" | jq --argjson e "$effort_json" '.effort_levels = $e')"
    CONFIG_JSON="$(printf '%s' "$CONFIG_JSON" | jq \
      --argjson fast "$(flag_json "$INCLUDE_FAST")" \
      --argjson max "$(flag_json "$INCLUDE_MAX")" \
      '.include_fast = $fast | .include_max = $max')"
  fi
fi

CATALOG_JSON="$CSBA_GLOBAL_CATALOG"
FETCHED_AT="$(jq -r '.fetched_at // empty' "$CATALOG_JSON" 2>/dev/null || true)"
CONFIG_JSON="$(printf '%s' "$CONFIG_JSON" | jq \
  --arg scope "$SCOPE" \
  --arg fetched "${FETCHED_AT:-}" \
  '.agents_install_scope = $scope
   | .catalog_fetched_at = (if $fetched == "" then null else $fetched end)
   | .catalog_source = "agent-models+docs"
   | .enabled = true
   | .agents_install_status = "installed"')"

AGENTS_DIR="$(csba_agents_dir_for_scope "$SCOPE" "$PROJECT_ROOT")"
mkdir -p "$AGENTS_DIR"

TEMPLATE_TEXT="$(cat "$CSBA_TEMPLATE")"

GENERATE_OUT="$(
  CONFIG_JSON="$CONFIG_JSON" \
  CATALOG_PATH="$CATALOG_JSON" \
  AGENTS_DIR="$AGENTS_DIR" \
  TEMPLATE_TEXT="$TEMPLATE_TEXT" \
  CSBA_LIB_DIR="$CSBA_LIB_DIR" \
  "${CSBA_PYTHON}" - <<'PY'
import json, os, sys
from pathlib import Path

sys.path.insert(0, os.environ["CSBA_LIB_DIR"])
from sb_managed_agent import is_installer_managed_agent
from cursor_sb_agents_lib import (
    MANAGED_MARKER,
    agent_name,
    expected_agent_names,
    expected_model_params,
    load_json,
    render_agent_markdown,
)

cfg = json.loads(os.environ["CONFIG_JSON"])
catalog = load_json(Path(os.environ["CATALOG_PATH"]))
agents_dir = Path(os.environ["AGENTS_DIR"])
template = os.environ["TEMPLATE_TEXT"]

expected = set(expected_agent_names(cfg))
params = expected_model_params(cfg, catalog)

written = []
for model in cfg.get("selected_models", []):
    for effort in cfg.get("effort_levels", []):
        name = agent_name(model, effort, cfg.get("agent_name_prefix", "sb"))
        model_param = params[name]
        content = render_agent_markdown(name, model, effort, model_param, template)
        path = agents_dir / f"{name}.md"
        path.write_text(content, encoding="utf-8")
        written.append(str(path))

pruned = []
prefix = cfg.get("agent_name_prefix", "sb")
for path in sorted(agents_dir.glob(f"{prefix}-*.md")):
    # Only files this installer generated are ever pruned; a user file that merely
    # contains the marker text is left alone.
    if not is_installer_managed_agent(path, agents_dir):
        continue
    name = path.stem
    if name and name not in expected:
        path.unlink()
        pruned.append(str(path))

print(json.dumps({"written": written, "pruned": pruned, "expected": sorted(expected)}))
PY
)"

csba_write_global_config "$CONFIG_JSON"
csba_merge_project_config "$PROJECT_ROOT" "$CONFIG_JSON"

EXPECTED_COUNT="$(csba_expected_count "$CONFIG_JSON")"
WRITTEN_COUNT="$(printf '%s' "$GENERATE_OUT" | jq '.written | length')"
PRUNED_COUNT="$(printf '%s' "$GENERATE_OUT" | jq '.pruned | length')"

echo ""
echo "SB Cursor custom subagents installed (${SCOPE})"
echo "  Agents dir: ${AGENTS_DIR}"
echo "  Expected:   ${EXPECTED_COUNT} agents (${WRITTEN_COUNT} written/updated, ${PRUNED_COUNT} pruned)"
echo "  Config:     ${CSBA_GLOBAL_CONFIG}"
echo ""
echo "Rung preview (subagent_name → model_param):"
CONFIG_JSON="$CONFIG_JSON" CATALOG_PATH="$CATALOG_JSON" CSBA_LIB_DIR="$CSBA_LIB_DIR" \
  "${CSBA_PYTHON}" - <<'PY'
import json, os, sys
sys.path.insert(0, os.environ["CSBA_LIB_DIR"])
from cursor_sb_agents_lib import agent_name, expected_model_params, load_json
cfg = json.loads(os.environ["CONFIG_JSON"])
catalog = load_json(os.environ["CATALOG_PATH"])
params = expected_model_params(cfg, catalog)
for model in cfg.get("selected_models", []):
    for effort in cfg.get("effort_levels", []):
        name = agent_name(model, effort, cfg.get("agent_name_prefix", "sb"))
        print(f"  {name} → {params[name]}")
PY

exit 0
