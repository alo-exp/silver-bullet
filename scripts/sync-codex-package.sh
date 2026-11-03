#!/usr/bin/env bash
# Regenerate every derived package surface from its source:
#   agents/claude/, host-bundles/codex/        host picker bundles of skills/
#   plugins/silver-bullet/skill-source/        Codex hidden skill sources (Codex render)
#   plugins/silver-bullet/templates/           byte-identical, host-neutral copy of templates/
# plugins/silver-bullet is the Codex package, so nothing in it is rewritten
# after rendering: the Codex installer applies its install-time sanitizer to
# the copy it installs. `bash scripts/validate-plugin-mirror.sh` checks that the
# committed surfaces equal a fresh run of this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
DEST_DIR="${REPO_ROOT}/plugins/silver-bullet"
AGENT_RENDERER="${SCRIPT_DIR}/render-agent-bundle.py"

# Preflight before anything destructive. This script prunes tracked trees
# (agents/codex, plugins/silver-bullet/templates) and repopulates them
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

# lock_is_stale: the lock dir records its owner's PID. A holder killed without
# its EXIT trap (SIGKILL, OOM, power loss) leaves the dir behind; its PID is
# then gone. A lock without a PID file is stale once it is a minute old (its
# owner writes the PID right after creating it).
lock_is_stale() {
  local owner
  owner="$(cat "${SYNC_LOCK_DIR}/pid" 2>/dev/null || true)"
  if [[ "$owner" =~ ^[0-9]+$ ]]; then
    if ps -p "$owner" >/dev/null 2>&1; then
      return 1
    fi
    return 0
  else
    [[ -n "$(find "$SYNC_LOCK_DIR" -maxdepth 0 -mmin +1 2>/dev/null)" ]]
  fi
}

_sync_lock_attempt=0
while ! mkdir "$SYNC_LOCK_DIR" 2>/dev/null; do
  if lock_is_stale; then
    printf '[codex-sync] removing stale lock %s\n' "$SYNC_LOCK_DIR" >&2
    rm -rf -- "$SYNC_LOCK_DIR"
    continue
  fi
  _sync_lock_attempt=$((_sync_lock_attempt + 1))
  if [[ "$_sync_lock_attempt" -ge "${SB_SYNC_LOCK_WAIT_SECONDS:-300}" ]]; then
    printf 'ERROR: timed out waiting for sync-codex-package lock %s (held by pid %s)\n' \
      "$SYNC_LOCK_DIR" "$(cat "${SYNC_LOCK_DIR}/pid" 2>/dev/null || echo unknown)" >&2
    exit 1
  fi
  sleep 1
done
printf '%s\n' "$$" >"${SYNC_LOCK_DIR}/pid"
STAGES=()
cleanup() {
  local stage
  for stage in "${STAGES[@]+"${STAGES[@]}"}"; do
    rm -rf -- "$stage"
  done
  rm -rf -- "$SYNC_LOCK_DIR"
}
trap cleanup EXIT

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
# mktemp creates 0600; keep the tracked manifest readable like the rest of the package.
chmod 644 "$DEST_DIR/.codex-plugin/plugin.json"

mkdir -p "${REPO_ROOT}/agents" "${REPO_ROOT}/host-bundles"
for host in claude codex; do
  python3 "$AGENT_RENDERER" render --agent "$host" --source-root "${REPO_ROOT}/skills" \
    --dest-root "$(sb_agent_bundle_root "$REPO_ROOT" "$host")"
done

# The legacy render path agents/codex must not remain in the checkout.
rm -rf "${REPO_ROOT}/agents/codex"

shopt -s dotglob nullglob
for entry in "${DEST_DIR}"/*; do
  base="$(basename "$entry")"
  case "$base" in
    .codex-plugin|skill-source|templates)
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

bash "${SCRIPT_DIR}/sync-templates.sh" >/dev/null

# Hidden skill sources: hosts discover picker entries from *SKILL.md files, so
# the packaged sources use an extensionless SILVER_SOURCE name and are read by
# path only. Each host gets its own render (paths, wording). Render outside
# the package so no render lock or staging tree is left inside it.
render_hidden_source() {
  local host="$1" name="$2" stage
  stage="$(mktemp -d "${TMPDIR:-/tmp}/sb-${name}.XXXXXX")"
  STAGES+=("$stage")
  python3 "$AGENT_RENDERER" render --agent "$host" --layout source \
    --source-root "${REPO_ROOT}/skills" --dest-root "${stage}/${name}"
  rm -rf -- "${DEST_DIR:?}/${name}"
  mv "${stage}/${name}" "${DEST_DIR}/${name}"
}
render_hidden_source codex skill-source

log "Codex package synchronized"
