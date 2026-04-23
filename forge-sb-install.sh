#!/usr/bin/env bash
set -euo pipefail

# Silver Bullet for Forge — Idempotent Installer
# Usage: curl -sL https://.../forge-sb-install.sh | bash
#   Or:   ./forge-sb-install.sh [--dry-run] [--project-only]
# Installs Silver Bullet skills and AGENTS.md for use with Forge AI

REPO="alo-exp/silver-bullet"
RAW_BASE="https://raw.githubusercontent.com/$REPO/main"
DRY_RUN=false
PROJECT_ONLY=false
FORGE_HOME="${FORGE_HOME:-$HOME/forge}"

# Detect if run via pipe (curl | bash)
# Use ${BASH_SOURCE[0]:-} with fallback; check if it's unset or "-"
_bs="${BASH_SOURCE[0]:-}"
if [[ -z "$_bs" || "$_bs" == "-" ]]; then
  INSTALL_MODE="remote"
  SCRIPT_TMP=$(mktemp -d)
  SKILLS_BASE="$SCRIPT_TMP/forge/skills"
  AGENTS_BASE="$SCRIPT_TMP/forge"
  REMOTE_FETCH=true
else
  INSTALL_MODE="local"
  SCRIPT_DIR="$(cd "$(dirname "$_bs")" && pwd)"
  SKILLS_BASE="$SCRIPT_DIR/forge/skills"
  AGENTS_BASE="$SCRIPT_DIR/forge"
  REMOTE_FETCH=false
fi

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --project-only) PROJECT_ONLY=true ;;
    -h|--help) echo "Usage: $0 [--dry-run] [--project-only]"; exit 0 ;;
  esac
done

log() { echo "[forge-sb] $*"; }

cleanup() {
  if [[ "$REMOTE_FETCH" == "true" ]]; then
    rm -rf "$SCRIPT_TMP"
  fi
}

maybe_mkdir() {
  log "  mkdir -p $1"
  $DRY_RUN || mkdir -p "$1"
}

fetch_skill() {
  local skill="$1" dst="$2"
  if [[ -f "$dst" ]]; then
    log "  skip (exists): $dst"
  else
    local src="$SKILLS_BASE/$skill/SKILL.md"
    if [[ "$REMOTE_FETCH" == "true" ]]; then
      log "  fetch: $RAW_BASE/forge/skills/$skill/SKILL.md → $dst"
      $DRY_RUN || mkdir -p "$(dirname "$dst")" && curl -sL "$RAW_BASE/forge/skills/$skill/SKILL.md" -o "$dst"
    else
      log "  copy: $src → $dst"
      $DRY_RUN || cp "$src" "$dst"
    fi
  fi
}

fetch_template() {
  local src_file="$1" dst="$2"
  if [[ -f "$dst" ]]; then
    log "  skip (exists — will NOT overwrite): $dst"
  else
    if [[ "$REMOTE_FETCH" == "true" ]]; then
      log "  fetch: $RAW_BASE/forge/$src_file → $dst"
      $DRY_RUN || curl -sL "$RAW_BASE/forge/$src_file" -o "$dst"
    else
      log "  create from template: $dst"
      $DRY_RUN || cp "$AGENTS_BASE/$src_file" "$dst"
    fi
  fi
}

echo "Silver Bullet for Forge — Installer"
echo "====================================="
[[ "$REMOTE_FETCH" == "true" ]] && log "Running in remote mode (curl | bash detected)"
$DRY_RUN && echo "DRY RUN MODE — no files will be written"
echo ""

# Skills to install (both global and project-level)
ALL_SKILLS=(
  ai-llm-safety
  brainstorming
  extensibility
  finishing-branch
  gsd-brainstorm
  gsd-discuss
  gsd-execute
  gsd-intel
  gsd-plan
  gsd-progress
  gsd-review
  gsd-review-fix
  gsd-secure
  gsd-ship
  gsd-validate
  gsd-verify
  modularity
  quality-gates
  receiving-code-review
  reliability
  requesting-code-review
  reusability
  scalability
  security
  silver
  silver-bugfix
  silver-devops
  silver-feature
  silver-research
  silver-ui
  tdd
  testability
  usability
  writing-plans
)

PROJECT_SKILLS=(gsd-brainstorm gsd-discuss gsd-execute gsd-intel gsd-plan gsd-progress gsd-review gsd-review-fix gsd-secure gsd-ship gsd-validate gsd-verify)

# Phase 1: Global skills (~/forge/)
if ! $PROJECT_ONLY; then
  log "Installing global skills to $FORGE_HOME/skills/"
  maybe_mkdir "$FORGE_HOME/skills"
  for skill in "${ALL_SKILLS[@]}"; do
    maybe_mkdir "$FORGE_HOME/skills/$skill"
    fetch_skill "$skill" "$FORGE_HOME/skills/$skill/SKILL.md"
  done
  log ""
  log "Installing global AGENTS.md"
  fetch_template "AGENTS.md.template" "$FORGE_HOME/AGENTS.md"
  log ""
fi

# Phase 2: Project-level setup
log "Installing project skills to .forge/skills/"
maybe_mkdir ".forge/skills"
for skill in "${PROJECT_SKILLS[@]}"; do
  maybe_mkdir ".forge/skills/$skill"
  fetch_skill "$skill" ".forge/skills/$skill/SKILL.md"
done
log ""
log "Installing project AGENTS.md"
fetch_template "AGENTS.project.template" "AGENTS.md"

echo ""
if $DRY_RUN; then
  log "DRY RUN complete — no files written. Remove --dry-run to install."
else
  [[ "$REMOTE_FETCH" == "true" ]] && cleanup
  log "Installation complete!"
  log "  Global skills: $FORGE_HOME/skills/"
  log "  Project skills: .forge/skills/"
  log "  Review AGENTS.md and customize for your project."
  log "  Run tests/smoke-test.sh to verify installation."
fi