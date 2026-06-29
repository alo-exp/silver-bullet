#!/usr/bin/env bash
# Silver Bullet — installed vs GitHub latest release check (session-start §0.5.1).
# Fail-soft: unreachable GitHub or missing registry must not block sessions.

# Test overrides:
#   SILVER_BULLET_UPDATE_CHECK_LATEST — mock latest semver (skip network)
#   SILVER_BULLET_UPDATE_CHECK_DISABLED=1 — skip check entirely
#   SILVER_BULLET_INSTALLED_PLUGINS_FILE — override registry path

sb_update_version_to_int() {
  local v="${1%%-*}"
  local maj min patch
  IFS='.' read -r maj min patch <<<"$v"
  maj="${maj:-0}"; min="${min:-0}"; patch="${patch:-0}"
  printf '%d' $((10#$maj * 1000000 + 10#$min * 1000 + 10#$patch))
}

sb_update_version_lt() {
  [[ "$(sb_update_version_to_int "$1")" -lt "$(sb_update_version_to_int "$2")" ]]
}

sb_update_version_valid() {
  local v="${1:-}"
  [[ -n "$v" && "$v" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

sb_update_registry_path() {
  printf '%s' "${SILVER_BULLET_INSTALLED_PLUGINS_FILE:-${SB_RUNTIME_HOME_ROOT}/plugins/installed_plugins.json}"
}

# Claude v2 registry stores plugin entries as arrays; Cursor/Codex may use objects.
sb_update_resolve_installed_version() {
  local reg="$1" plugin_id="" plugin_ver=""
  if [[ ! -f "$reg" ]] || ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  for plugin_id in "silver-bullet@alo-labs" "silver-bullet@alo-labs-codex" "silver-bullet@silver-bullet"; do
    plugin_ver="$(jq -r --arg id "$plugin_id" '
      .plugins[$id] as $entry
      | if $entry == null then empty
        elif ($entry | type) == "array" then ($entry[0].version // empty)
        else ($entry.version // empty)
        end
    ' "$reg" 2>/dev/null || true)"
    if [[ -n "$plugin_ver" && "$plugin_ver" != "null" ]]; then
      printf '%s' "$plugin_ver"
      return 0
    fi
  done
  return 1
}

sb_update_fetch_latest_version() {
  local latest=""
  if [[ -n "${SILVER_BULLET_UPDATE_CHECK_LATEST:-}" ]]; then
    printf '%s' "$SILVER_BULLET_UPDATE_CHECK_LATEST"
    return 0
  fi
  if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    return 1
  fi
  latest="$(curl -fsSL --connect-timeout 3 --max-time 8 \
    https://api.github.com/repos/alo-exp/silver-bullet/releases/latest 2>/dev/null \
    | jq -r '.tag_name // empty' 2>/dev/null \
    | sed 's/^v//' || true)"
  if sb_update_version_valid "$latest"; then
    printf '%s' "$latest"
    return 0
  fi
  return 1
}

# Sets SB_UPDATE_CHECK_RESULT: up_to_date | update_available | check_failed | dev_ahead
# Sets SB_UPDATE_INSTALLED and SB_UPDATE_LATEST when known. Always returns 0.
sb_check_sb_update() {
  SB_UPDATE_CHECK_RESULT="check_failed"
  SB_UPDATE_INSTALLED=""
  SB_UPDATE_LATEST=""

  if [[ "${SILVER_BULLET_UPDATE_CHECK_DISABLED:-}" == "1" ]]; then
    SB_UPDATE_CHECK_RESULT="disabled"
    return 0
  fi

  local reg installed latest
  reg="$(sb_update_registry_path)"
  installed="$(sb_update_resolve_installed_version "$reg" 2>/dev/null || true)"
  if [[ -z "$installed" ]]; then
    installed="0.0.0"
  fi
  SB_UPDATE_INSTALLED="$installed"

  latest="$(sb_update_fetch_latest_version 2>/dev/null || true)"
  if ! sb_update_version_valid "$latest"; then
    SB_UPDATE_CHECK_RESULT="check_failed"
    return 0
  fi
  SB_UPDATE_LATEST="$latest"

  if sb_update_version_lt "$installed" "$latest"; then
    SB_UPDATE_CHECK_RESULT="update_available"
  elif sb_update_version_lt "$latest" "$installed"; then
    SB_UPDATE_CHECK_RESULT="dev_ahead"
  else
    SB_UPDATE_CHECK_RESULT="up_to_date"
  fi
  return 0
}

# Emits prompt block for additionalContext when an update is available; empty otherwise.
sb_check_sb_update_prompt_block() {
  sb_check_sb_update || true
  case "${SB_UPDATE_CHECK_RESULT:-check_failed}" in
    update_available)
      cat <<EOF
SB UPDATE AVAILABLE — Silver Bullet v${SB_UPDATE_INSTALLED} (installed) < v${SB_UPDATE_LATEST} (GitHub latest)

ASK THE USER NOW before other project work (§0 step 5.1):
"Silver Bullet v${SB_UPDATE_INSTALLED} is outdated (latest: v${SB_UPDATE_LATEST}). Update now?"

Options:
- A. Yes, update now — invoke \`/silver:update\` through the active runtime's SB-recognized skill invocation channel, then continue session startup.
- B. Skip — output "Skipping SB update." and continue with the current version.

Do not auto-update without explicit user selection of A.
EOF
      ;;
    *)
      ;;
  esac
}
