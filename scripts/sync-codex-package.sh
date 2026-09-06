#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
DEST_DIR="${REPO_ROOT}/plugins/silver-bullet"
AGENT_RENDERER="${SCRIPT_DIR}/render-agent-bundle.py"

# Preflight before anything destructive. This script prunes tracked trees
# (agents/{codex,cursor}, plugins/silver-bullet/templates) and repopulates them
# with rsync. Discovering rsync is missing at that point leaves the checkout
# with the deletions applied and nothing copied back.
for _req in rsync python3; do
  if ! command -v "$_req" >/dev/null 2>&1; then
    printf 'ERROR: %s is required by sync-codex-package.sh but is not in PATH.\n' "$_req" >&2
    printf '       Install it and re-run — this script prunes tracked trees before repopulating them.\n' >&2
    exit 1
  fi
done
unset _req

SYNC_LOCK_DIR="${REPO_ROOT}/.planning/sb-sync-codex-package.lock.d"
mkdir -p "$(dirname "$SYNC_LOCK_DIR")" 2>/dev/null || SYNC_LOCK_DIR="${TMPDIR:-/tmp}/sb-sync-codex-package.lock.d"
mkdir -p "$(dirname "$SYNC_LOCK_DIR")"
_sync_lock_attempt=0
while ! mkdir "$SYNC_LOCK_DIR" 2>/dev/null; do
  _sync_lock_attempt=$((_sync_lock_attempt + 1))
  if [[ "$_sync_lock_attempt" -ge 300 ]]; then
    printf 'ERROR: timed out waiting for sync-codex-package lock\n' >&2
    exit 1
  fi
  sleep 1
done
skill_stage=""
trap 'rm -rf "$skill_stage" 2>/dev/null || true; rmdir "$SYNC_LOCK_DIR" 2>/dev/null || true' EXIT

log() {
  printf '[codex-sync] %s\n' "$*"
}

mkdir -p "$DEST_DIR/.codex-plugin"
# Never carry Codex's legacy command-to-skill migration artifacts into the
# generated package; those source-command-* directories are not SB skills.
rm -rf -- "$DEST_DIR/.codex-plugin/migrated-command-skills"

if [[ ! -f "$DEST_DIR/.codex-plugin/plugin.json" ]]; then
  printf 'ERROR: missing Codex manifest at %s\n' "$DEST_DIR/.codex-plugin/plugin.json" >&2
  exit 1
fi

log "Refreshing generated package surface in ${DEST_DIR}"

plugin_version="$(jq -r '.version' "${REPO_ROOT}/package.json")"
tmp="$(mktemp)"
jq --arg v "$plugin_version" '.version = $v' "$DEST_DIR/.codex-plugin/plugin.json" > "$tmp"
mv "$tmp" "$DEST_DIR/.codex-plugin/plugin.json"

mkdir -p "${REPO_ROOT}/agents" "${REPO_ROOT}/host-bundles"
python3 "$AGENT_RENDERER" render --agent claude --source-root "${REPO_ROOT}/skills" --dest-root "$(sb_agent_bundle_root "$REPO_ROOT" claude)"
python3 "$AGENT_RENDERER" render --agent codex --source-root "${REPO_ROOT}/skills" --dest-root "$(sb_agent_bundle_root "$REPO_ROOT" codex)"
python3 "$AGENT_RENDERER" render --agent cursor --source-root "${REPO_ROOT}/skills" --dest-root "$(sb_agent_bundle_root "$REPO_ROOT" cursor)"

# Legacy render paths under agents/{codex,cursor} must not remain in the checkout.
rm -rf "${REPO_ROOT}/agents/codex" "${REPO_ROOT}/agents/cursor"

shopt -s dotglob nullglob
for entry in "${DEST_DIR}"/*; do
  base="$(basename "$entry")"
  case "$base" in
    .codex-plugin|.cursor-plugin|commands|skill-source|cursor-hooks.json|templates)
      continue
      ;;
  esac
  rm -rf -- "$entry"
done
shopt -u dotglob nullglob

# Codex gets the plugin-facing SB surface here. Project-instance artifacts
# like planning, Claude packaging, and repo governance live
# outside this bundle. Third-party Codex wrappers are maintained in the shared
# marketplace repo, not in this SB package snapshot. The packaged skills tree is
# generated under agents/ so the repo keeps agent-specific variants while the
# source skills remain the authoring source of truth.
PACKAGE_ENTRIES=(
  AGENTS.md
  CHANGELOG.md
  CODE_OF_CONDUCT.md
  CONTRIBUTING.md
  LICENSE
  README.md
  SECURITY.md
  SENTINEL-audit-silver-bullet-v0.15.1.md
  SENTINEL-audit-silver-init.md
  .silver-bullet.json
  docs
  hooks
  scripts
)

for entry in "${PACKAGE_ENTRIES[@]}"; do
  if [[ ! -e "${REPO_ROOT}/${entry}" && ! -L "${REPO_ROOT}/${entry}" ]]; then
    printf 'ERROR: package source missing: %s\n' "${entry}" >&2
    exit 1
  fi
  ln -sfn "../../${entry}" "${DEST_DIR}/${entry}"
done

if [[ -d "${REPO_ROOT}/templates" ]]; then
  rm -rf -- "${DEST_DIR}/templates"
  mkdir -p -- "${DEST_DIR}/templates"
  rsync -a --delete "${REPO_ROOT}/templates/" "${DEST_DIR}/templates/"
fi

# Codex can discover plugin-owned picker entries from cached Markdown files
# under the plugin package. Keep SB's packaged skill sources available for the
# installer, but store them under an extensionless filename so the only
# user-facing picker surface is the native ~/.codex/skills mirror.
python3 - "$DEST_DIR" <<'PY'
import pathlib
import shutil
import sys

dest = pathlib.Path(sys.argv[1])
for name in ("skills", "skill-source", ".generated-skills", "agents"):
    path = dest / name
    if path.exists() or path.is_symlink():
        shutil.rmtree(path)
PY
find "${DEST_DIR}" -maxdepth 1 -type d -name '.skill-source.staging.*' -exec rm -rf {} + 2>/dev/null || true
skill_stage="$(mktemp -d "${TMPDIR:-/tmp}/sb-skill-source.staging.XXXXXX")"
rsync -a "$(sb_agent_bundle_root "$REPO_ROOT" codex)/" "${skill_stage}/"
find "${skill_stage}" -name SKILL.md -type f -exec sh -c '
  for path do
    dest="$(dirname "$path")/SILVER_SOURCE"
    if [[ -e "$dest" ]]; then
      rm -f "$path"
    else
      mv "$path" "$dest"
    fi
  done
' sh {} +
mv "${skill_stage}" "${DEST_DIR}/skill-source"
skill_stage=""

if [[ -x "${SCRIPT_DIR}/codex-sanitize-package.sh" ]]; then
  "${SCRIPT_DIR}/codex-sanitize-package.sh" "$DEST_DIR"
else
  printf 'ERROR: codex sanitizer helper missing at %s\n' "${SCRIPT_DIR}/codex-sanitize-package.sh" >&2
  exit 1
fi

cursor_package_sync_script="${SCRIPT_DIR}/sync-cursor-package.sh"
if [[ -x "$cursor_package_sync_script" ]]; then
  "$cursor_package_sync_script"
else
  printf 'ERROR: Cursor package sync script not found or not executable: %s\n' "$cursor_package_sync_script" >&2
  exit 1
fi

log "Codex package synchronized"

