# shellcheck shell=bash
# Post-release SB-only uninstall per host — preserves non-SB hooks (rtk, context-mode, etc.).
# Only what Silver Bullet added is removed: its caches and plugin surfaces, its registry
# records, and the hook entries whose program lives in a Silver Bullet hooks directory.

if [[ -n "${_SB_POST_RELEASE_UNINSTALL_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_SB_POST_RELEASE_UNINSTALL_LOADED=1

_sb_post_release_rm_dir() {
  local path="$1"
  [[ -e "$path" ]] || return 0
  rm -rf "$path" 2>/dev/null || true
}

# _sb_post_release_forget <settings-or-registry json> <plugin id>...: remove Silver Bullet's
# own records from a host JSON file: the named plugin ids under "plugins" (a registry) and
# "enabledPlugins" (Claude settings), and the hook entries Silver Bullet owns under "hooks".
# Everything else is kept; an unparseable file is reported and left untouched.
_sb_post_release_forget() {
  local file="$1"
  shift
  [[ -f "$file" ]] || return 0
  python3 - "$file" "${SB_POST_RELEASE_REPO_ROOT:?}" "$@" <<'PY'
import sys

path, repo_root, plugin_ids = sys.argv[1], sys.argv[2], sys.argv[3:]
sys.path.insert(0, repo_root + "/scripts/lib")
from sb_host_config import ConfigError, is_sb_hook_command, read_json, remove_hooks, sb_hook_names, write_json  # noqa: E402

try:
    data = read_json(path)
except ConfigError as exc:
    sys.exit(f"ERROR: {exc}")
changed = 0
for key in ("plugins", "enabledPlugins"):
    records = data.get(key)
    if isinstance(records, dict):
        for plugin_id in plugin_ids:
            changed += records.pop(plugin_id, None) is not None
hooks = data.get("hooks")
if isinstance(hooks, dict):
    names = sb_hook_names(repo_root + "/hooks")
    changed += remove_hooks(hooks, lambda hook: is_sb_hook_command(hook.get("command"), hook_names=names))
if changed:
    write_json(path, data)
PY
}

sb_post_release_uninstall_codex() {
  local codex_home="${CODEX_HOME_ROOT:-${HOME}}"
  local lib="${SB_POST_RELEASE_REPO_ROOT}/scripts/lib/install-codex"
  export CODEX_HOME_ROOT="$codex_home"
  # One run start for every config.toml write below (repair, then purge), so .sb-backup keeps the pre-run original.
  export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"
  # shellcheck source=scripts/lib/install-codex/legacy.sh
  source "${lib}/legacy.sh"
  # shellcheck source=scripts/lib/install-codex/hooks.sh
  source "${lib}/hooks.sh"
  purge_legacy_silver_bullet_standalone_skills
  # SB's own duplicated trust tables make config.toml invalid TOML; repair them first so the purge can read it.
  repair_silver_bullet_duplicate_trust_tables
  purge_legacy_silver_bullet_hooks_from_user_config --all
  _sb_post_release_rm_dir "${codex_home}/.codex/plugins/cache/alo-labs-codex/silver-bullet"
  _sb_post_release_rm_dir "${codex_home}/.codex/plugins/cache/silver-bullet-local/silver-bullet"
  if command -v codex >/dev/null 2>&1; then
    codex plugin remove silver-bullet@alo-labs-codex >/dev/null 2>&1 || \
      codex plugin uninstall silver-bullet@alo-labs-codex >/dev/null 2>&1 || true
  fi
  printf 'uninstall: codex SB cache, skills, hooks stripped\n'
}

sb_post_release_uninstall_claude() {
  local claude_home="${CLAUDE_HOME:-${HOME}/.claude}"
  local claude_bin="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"
  local plugin_id scope
  for plugin_id in "silver-bullet@alo-labs" "silver-bullet@alo-labs-claude"; do
    if [[ -n "$claude_bin" && -x "$claude_bin" ]]; then
      for scope in user project local; do
        "$claude_bin" plugin uninstall "$plugin_id" --scope "$scope" >/dev/null 2>&1 || true
      done
    fi
    _sb_post_release_rm_dir "${claude_home}/plugins/cache/${plugin_id#*@}/${plugin_id%@*}"
  done
  _sb_post_release_rm_dir "${claude_home}/plugins/cache/alo-labs/silver-bullet"
  # Hooks an earlier /sb:init merged into settings.json, and SB's own registry and
  # enablement records, would otherwise point at the deleted cache (R7-23).
  _sb_post_release_forget "${claude_home}/settings.json" silver-bullet@alo-labs silver-bullet@alo-labs-claude || return 1
  _sb_post_release_forget "${claude_home}/plugins/installed_plugins.json" silver-bullet@alo-labs silver-bullet@alo-labs-claude || return 1
  printf 'uninstall: claude SB plugin + cache removed\n'
}

sb_post_release_uninstall_host() {
  case "$1" in
    codex) sb_post_release_uninstall_codex ;;
    claude) sb_post_release_uninstall_claude ;;
    *) printf 'ERROR: unknown host %s\n' "$1" >&2; return 2 ;;
  esac
}
