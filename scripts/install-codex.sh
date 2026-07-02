#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
_LIB="${SCRIPT_DIR}/lib/install-codex"
AGENT_RENDERER="${SCRIPT_DIR}/render-agent-bundle.py"
# shellcheck source=scripts/lib/agent-bundle-paths.sh
source "${REPO_ROOT}/scripts/lib/agent-bundle-paths.sh"
PURGE_LEGACY_SKILLS=0
PUBLIC_RELEASE_ONLY=0
HOOK_TRUST_SEED_ONLY=0
# Native Codex loads plugin-declared hooks directly, so merging the same SB
# hook bundle into ~/.codex/hooks.json duplicates delivery. Kay still relies on
# the merged user-hook surface, so keep merge enabled there unless explicitly
# overridden.
if [[ -n "${SB_CODEX_MERGE_USER_HOOKS:-}" ]]; then
  MERGE_USER_HOOKS="${SB_CODEX_MERGE_USER_HOOKS}"
elif [[ -n "${KAY_HOME:-}" ]]; then
  MERGE_USER_HOOKS=1
else
  MERGE_USER_HOOKS=0
fi
CODEX_BIN="${CODEX_BIN:-codex}"
CODEX_MARKETPLACE_SOURCE="${CODEX_MARKETPLACE_SOURCE:-https://github.com/alo-labs/codex-plugins}"
CODEX_MARKETPLACE_LEGACY_NAME="${CODEX_MARKETPLACE_LEGACY_NAME:-silver-bullet-local}"
CODEX_HOME_ROOT="${KAY_HOME:-${HOME}}"

for _mod in config marketplace package cache legacy skill-mirror plugin registry hooks path-rewrite; do
  # shellcheck source=/dev/null
  source "${_LIB}/${_mod}.sh"
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-legacy-skills) PURGE_LEGACY_SKILLS=1; shift ;;
    --hook-trust-seed-only) HOOK_TRUST_SEED_ONLY=1; shift ;;
    --public-release) PUBLIC_RELEASE_ONLY=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$HOOK_TRUST_SEED_ONLY" -eq 1 ]]; then
  SB_PROJECT_ROOT=""
  if SB_PROJECT_ROOT="$(find_silver_bullet_project_root)"; then
    seed_silver_bullet_hook_trust_state
  fi
  exit 0
fi

if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  "${SCRIPT_DIR}/sync-codex-package.sh"
fi

if ! command -v "${CODEX_BIN}" >/dev/null 2>&1; then
  printf 'ERROR: codex CLI not found in PATH\n' >&2
  exit 1
fi

remove_marketplace_if_present "${CODEX_MARKETPLACE_LEGACY_NAME}"
ensure_marketplace_registered "${CODEX_MARKETPLACE_SOURCE}"
if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  seed_marketplace_snapshot_if_missing
fi
refresh_marketplace "alo-labs-codex"
cleanup_legacy_marketplace_picker_surfaces
purge_legacy_silver_bullet_codex_alias
if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  render_agent_bundle "claude"
  render_agent_bundle "codex"
  sync_marketplace_package_surface
  sync_marketplace_package_snapshot
fi
materialize_silver_bullet_package
if [[ "$PUBLIC_RELEASE_ONLY" -eq 0 ]]; then
  sync_materialized_package_surface
fi
sanitize_codex_package_surface
sync_codex_cache_package_surface
prune_stale_silver_bullet_cache_versions
refresh_silver_bullet_current_alias
prune_legacy_silver_bullet_picker_surfaces
if [[ "$PURGE_LEGACY_SKILLS" -eq 1 ]]; then
  purge_legacy_silver_bullet_standalone_skills
fi
sync_silver_bullet_native_codex_skill_mirror
install_silver_bullet_codex_cli
rewrite_codex_bundle_host_paths
sync_codex_installed_plugin_registry_paths
normalize_codex_hook_async_flags
ensure_feature_enabled "plugin_hooks"
remove_plugin_enabled "silver@alo-labs-codex"
purge_legacy_silver_bullet_hooks_from_user_config

SB_PROJECT_ROOT=""
if SB_PROJECT_ROOT="$(find_silver_bullet_project_root)"; then
  ensure_plugin_enabled "silver-bullet@alo-labs-codex"
  ensure_silver_bullet_registry_entry
  validate_silver_bullet_skill_surface "installed package alias" "${CODEX_HOME_ROOT}/.codex/plugins/cache/alo-labs-codex/silver-bullet/current"
  if [[ "$MERGE_USER_HOOKS" == "1" ]]; then
    merge_silver_bullet_hooks_into_user_config
  fi
else
  remove_plugin_enabled "silver-bullet@alo-labs-codex"
  printf 'Skipping Silver Bullet plugin auto-enable outside a Silver Bullet project root.\n'
fi

if [[ -n "$SB_PROJECT_ROOT" ]]; then
  seed_silver_bullet_hook_trust_state
fi

sync_silver_bullet_skill_cache
scrub_legacy_silver_bullet_traces

if [[ "$PUBLIC_RELEASE_ONLY" -eq 1 ]]; then
  printf 'Codex marketplace refreshed from published source %s\n' "${CODEX_MARKETPLACE_SOURCE}"
else
  printf 'Codex marketplace registered from %s\n' "${REPO_ROOT}"
fi
