#!/usr/bin/env bash
set -euo pipefail

# Silver Bullet for Forge — Idempotent Installer
# Installs ~106 skills and ~41 custom agents for use with the Forge coding agent.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/alo-exp/silver-bullet/main/forge-sb-install.sh | bash
#   ./forge-sb-install.sh [--dry-run] [--project-only] [--global-only] [--no-knowledge-work]
#
# Skills + agents are sourced from this repository's forge/ directory, OR fetched
# from raw.githubusercontent.com if executed via curl|bash. Anthropic
# knowledge-work-plugin skills are fetched from the upstream repo at install
# time unless --no-knowledge-work is passed (vendor a snapshot offline).

REPO="alo-exp/silver-bullet"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/main"
KW_REPO="https://github.com/anthropics/knowledge-work-plugins.git"
DRY_RUN=false
PROJECT_ONLY=false
GLOBAL_ONLY=false
SKIP_KW=false
FORGE_HOME="${FORGE_HOME:-$HOME/forge}"

# Detect run mode (curl | bash vs local script)
_bs="${BASH_SOURCE[0]:-}"
if [[ -z "$_bs" || "$_bs" == "-" ]]; then
  INSTALL_MODE="remote"
  REMOTE_FETCH=true
  WORK_TMP="$(mktemp -d)"
  trap 'rm -rf "${WORK_TMP}"' EXIT
else
  INSTALL_MODE="local"
  SCRIPT_DIR="$(cd "$(dirname "$_bs")" && pwd)"
  REMOTE_FETCH=false
fi

for arg in "$@"; do
  case "$arg" in
    --dry-run)           DRY_RUN=true ;;
    --project-only)      PROJECT_ONLY=true ;;
    --global-only)       GLOBAL_ONLY=true ;;
    --no-knowledge-work) SKIP_KW=true ;;
    -h|--help)
      cat <<USAGE
Usage: $0 [options]

Options:
  --dry-run             Show actions without writing files
  --global-only         Install only ~/forge/ (skip .forge/ project install)
  --project-only        Install only .forge/ (skip ~/forge/ global install)
  --no-knowledge-work   Skip Anthropic knowledge-work-plugin skill fetch

Default: install both global (~/forge/) and project-level (.forge/), and
fetch Anthropic engineering, design, product-management, marketing skills.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

log() { echo "[forge-sb] $*"; }
do_run() { if $DRY_RUN; then log "DRY: $*"; else eval "$@"; fi; }

# Resolve a source path: prefer local repo, else fetch from raw.githubusercontent.com
fetch_to() {
  local repo_relpath="$1"
  local dst="$2"
  if [[ "$REMOTE_FETCH" == "true" ]]; then
    do_run "mkdir -p \"$(dirname "$dst")\""
    do_run "curl -fsSL \"${RAW_BASE}/${repo_relpath}\" -o \"$dst\""
  else
    local src="${SCRIPT_DIR}/${repo_relpath}"
    if [[ ! -f "$src" ]]; then
      log "WARN: source missing: $src"
      return 1
    fi
    do_run "mkdir -p \"$(dirname "$dst")\""
    do_run "cp \"$src\" \"$dst\""
  fi
}

# List local skill or agent ids
list_local() {
  local kind="$1"  # skills or agents
  if [[ "$REMOTE_FETCH" == "true" ]]; then
    # Use git API to list directories
    KIND="${kind}" curl -fsSL "https://api.github.com/repos/${REPO}/contents/forge/${kind}?ref=main" \
      | KIND="${kind}" python3 -c "
import sys, json, os
kind = os.environ.get('KIND', '')
items = json.load(sys.stdin)
for it in items:
    if it.get('type') == 'dir' and kind == 'skills':
        print(it['name'])
    elif kind == 'agents' and it.get('type') == 'file' and it['name'].endswith('.md'):
        print(it['name'])
"
  else
    if [[ "$kind" == "skills" ]]; then
      ls -1 "${SCRIPT_DIR}/forge/skills" 2>/dev/null
    else
      ls -1 "${SCRIPT_DIR}/forge/agents" 2>/dev/null | grep '\.md$' || true
    fi
  fi
}

install_skills_to() {
  local target_dir="$1"
  log "  installing skills -> ${target_dir}"
  do_run "mkdir -p \"${target_dir}\""
  local count=0
  for skill in $(list_local skills); do
    if fetch_to "forge/skills/${skill}/SKILL.md" "${target_dir}/${skill}/SKILL.md"; then
      count=$((count + 1))
    fi
  done
  log "  ${count} skills installed."
}

install_agents_to() {
  local target_dir="$1"
  log "  installing agents -> ${target_dir}"
  do_run "mkdir -p \"${target_dir}\""
  local count=0
  for agent in $(list_local agents); do
    if fetch_to "forge/agents/${agent}" "${target_dir}/${agent}"; then
      count=$((count + 1))
    fi
  done
  log "  ${count} agents installed."
}

install_kw_skills_to() {
  local target_dir="$1"
  if $SKIP_KW; then
    log "  skipping Anthropic knowledge-work skills (--no-knowledge-work)"
    return 0
  fi
  log "  fetching Anthropic knowledge-work-plugins -> ${target_dir}"
  if ! command -v git >/dev/null 2>&1; then
    log "  WARN: git not found; cannot fetch knowledge-work skills"
    return 0
  fi
  local kw_tmp="${WORK_TMP:-$(mktemp -d)}/kw"
  do_run "rm -rf \"$kw_tmp\""
  do_run "git clone --depth 1 --quiet \"${KW_REPO}\" \"$kw_tmp\""
  local count=0
  for plugin in engineering design product-management marketing; do
    if [[ ! -d "${kw_tmp}/${plugin}/skills" ]]; then continue; fi
    for sd in "${kw_tmp}/${plugin}/skills/"*/; do
      local sname; sname="$(basename "$sd")"
      local target_name="${plugin}-${sname}"
      if [[ -f "${sd}/SKILL.md" ]]; then
        do_run "mkdir -p \"${target_dir}/${target_name}\""
        do_run "cp \"${sd}/SKILL.md\" \"${target_dir}/${target_name}/SKILL.md\""
        count=$((count + 1))
      fi
    done
  done
  log "  ${count} knowledge-work skills installed."
}

install_agents_md_to() {
  local target="$1"   # path to AGENTS.md file
  local source_relpath="$2"
  log "  installing AGENTS.md -> ${target}"
  if [[ -f "$target" ]]; then
    log "  skip (exists — will NOT overwrite): $target"
    return 0
  fi
  fetch_to "$source_relpath" "$target"
}

# ---------- Main ----------

echo "Silver Bullet for Forge — Installer"
echo "===================================="
log "Mode: ${INSTALL_MODE} | Forge home: ${FORGE_HOME}"
$DRY_RUN && log "DRY RUN — no files will be written"
echo ""

# Phase A: Global install (~/forge/skills + ~/forge/agents + ~/forge/AGENTS.md)
if ! $PROJECT_ONLY; then
  log "Phase A: Global install"
  install_skills_to "${FORGE_HOME}/skills"
  install_kw_skills_to "${FORGE_HOME}/skills"
  install_agents_to "${FORGE_HOME}/agents"
  install_agents_md_to "${FORGE_HOME}/AGENTS.md" "forge/AGENTS.md.template"
  echo ""
fi

# Phase B: Project install (.forge/ in cwd)
if ! $GLOBAL_ONLY; then
  log "Phase B: Project install (cwd: $(pwd))"
  # Project-level: install only the most-critical orchestration skills + all hook agents.
  # Per Forge precedence (project > agents > global), project files override global.
  # Default behavior: install ALL agents at project level too, so each repo gets its own
  # gating and subagent set (override-friendly). Skills stay global to avoid clutter.
  install_agents_to ".forge/agents"
  install_agents_md_to "./AGENTS.md" "forge/AGENTS.project.template"
  echo ""
fi

# ---------- Summary ----------
echo ""
if $DRY_RUN; then
  log "DRY RUN complete — no files written. Remove --dry-run to install."
else
  log "Installation complete."
  if ! $PROJECT_ONLY; then
    log "  Global skills:  ${FORGE_HOME}/skills/"
    log "  Global agents:  ${FORGE_HOME}/agents/"
    log "  Global AGENTS.md: ${FORGE_HOME}/AGENTS.md"
  fi
  if ! $GLOBAL_ONLY; then
    log "  Project agents: $(pwd)/.forge/agents/"
    log "  Project AGENTS.md: $(pwd)/AGENTS.md"
  fi
  log ""
  log "Next steps:"
  log "  1. Review ./AGENTS.md — customise project conventions"
  log "  2. Run \`silver-init\` skill to scaffold .planning/"
  log "  3. Use \`silver-feature\`, \`silver-bugfix\`, etc., to start work"
  log ""
  log "Verify install: run \`:skill\` and \`:agent\` in Forge to list loaded items."
fi
