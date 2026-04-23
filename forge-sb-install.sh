#!/usr/bin/env bash
set -euo pipefail

# Silver Bullet for Forge — Idempotent Installer
# Usage: ./forge-sb-install.sh [--dry-run] [--project-only]
# Installs Silver Bullet skills and AGENTS.md for use with Forge AI

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRY_RUN=false
PROJECT_ONLY=false
FORGE_HOME="${FORGE_HOME:-$HOME/forge}"
SKILLS_SRC="$SCRIPT_DIR/forge/skills"

for arg in "$@"; do
  case $arg in
    --dry-run) DRY_RUN=true ;;
    --project-only) PROJECT_ONLY=true ;;
    -h|--help) echo "Usage: $0 [--dry-run] [--project-only]"; exit 0 ;;
  esac
done

log() { echo "[forge-sb] $*"; }

maybe_mkdir() {
  log "  mkdir -p $1"
  $DRY_RUN || mkdir -p "$1"
}

maybe_cp_skill() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    log "  skip (exists): $dst"
  else
    log "  copy: $src → $dst"
    $DRY_RUN || cp "$src" "$dst"
  fi
}

maybe_cp_template() {
  local src="$1" dst="$2"
  if [ -f "$dst" ]; then
    log "  skip (exists — will NOT overwrite): $dst"
  else
    log "  create from template: $dst"
    $DRY_RUN || cp "$src" "$dst"
  fi
}

echo "Silver Bullet for Forge — Installer"
echo "====================================="
$DRY_RUN && echo "DRY RUN MODE — no files will be written"
echo ""

# Phase 1: Global skills (~/forge/)
if ! $PROJECT_ONLY; then
  log "Installing global skills to $FORGE_HOME/skills/"
  maybe_mkdir "$FORGE_HOME/skills"
  for skill_dir in "$SKILLS_SRC"/*/; do
    skill_name=$(basename "$skill_dir")
    maybe_mkdir "$FORGE_HOME/skills/$skill_name"
    maybe_cp_skill "$skill_dir/SKILL.md" "$FORGE_HOME/skills/$skill_name/SKILL.md"
  done
  log ""
  log "Installing global AGENTS.md"
  maybe_cp_template "$SCRIPT_DIR/forge/AGENTS.md.template" "$FORGE_HOME/AGENTS.md"
  log ""
fi

# Phase 2: Project-level setup
log "Installing project skills to .forge/skills/"
maybe_mkdir ".forge/skills"
for skill_dir in "$SKILLS_SRC"/gsd-*/; do
  skill_name=$(basename "$skill_dir")
  maybe_mkdir ".forge/skills/$skill_name"
  maybe_cp_skill "$skill_dir/SKILL.md" ".forge/skills/$skill_name/SKILL.md"
done
log ""
log "Installing project AGENTS.md"
maybe_cp_template "$SCRIPT_DIR/forge/AGENTS.project.template" "AGENTS.md"

echo ""
if $DRY_RUN; then
  log "DRY RUN complete — no files written. Remove --dry-run to install."
else
  log "Installation complete!"
  log "  Global skills: $FORGE_HOME/skills/"
  log "  Project skills: .forge/skills/"
  log "  Review AGENTS.md and customize for your project."
  log "  Run tests/smoke-test.sh to verify installation."
fi
