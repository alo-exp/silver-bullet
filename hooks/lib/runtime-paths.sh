# shellcheck shell=bash
# Silver Bullet runtime-aware host paths.
#
# Codex sessions should use the Codex runtime home root for SB state and
# plugin caches. Claude sessions should use the Claude runtime home root.
# Tests can force either host by exporting SILVER_BULLET_RUNTIME.

if [[ -z "${SILVER_BULLET_RUNTIME:-}" ]]; then
  if [[ -n "${CODEX_CI:-}" || -n "${CODEX_THREAD_ID:-}" || -n "${CODEX_INTERNAL_ORIGINATOR_OVERRIDE:-}" ]]; then
    SILVER_BULLET_RUNTIME="codex"
  else
    SILVER_BULLET_RUNTIME="claude"
  fi
fi

case "$SILVER_BULLET_RUNTIME" in
  claude|codex) ;;
  *) SILVER_BULLET_RUNTIME="claude" ;;
esac

SB_RUNTIME_NAME="$SILVER_BULLET_RUNTIME"
SB_RUNTIME_HOME_ROOT="${HOME}/.${SB_RUNTIME_NAME}"
SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
SB_RUNTIME_PLUGIN_CACHE_ROOT="${SB_RUNTIME_HOME_ROOT}/plugins/cache"

export SILVER_BULLET_RUNTIME SB_RUNTIME_NAME SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT
