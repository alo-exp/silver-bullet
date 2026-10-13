#!/usr/bin/env bash
# Shared helpers for the unified alo-labs/agent-plugins marketplace repo.
set -euo pipefail

agent_plugins_repo_url() {
  printf '%s\n' "${AGENT_PLUGINS_REPO_URL:-https://github.com/alo-labs/agent-plugins.git}"
}

agent_plugins_legacy_repo_url() {
  local host="$1"
  case "$host" in
    claude) printf '%s\n' "${MARKETPLACE_REPO_URL:-}" ;;
    codex) printf '%s\n' "${CODEX_MARKETPLACE_REPO_URL:-}" ;;
    cursor) printf '%s\n' "${CURSOR_MARKETPLACE_REPO_URL:-}" ;;
    *) printf '%s\n' "" ;;
  esac
}

resolve_agent_plugins_repo_url() {
  local host="${1:-}"
  local legacy
  legacy="$(agent_plugins_legacy_repo_url "$host")"
  if [[ -n "$legacy" ]]; then
    printf '%s\n' "$legacy"
    return 0
  fi
  agent_plugins_repo_url
}

agent_plugins_commit_push_if_dirty() {
  local root="$1"
  local message="$2"
  local skip_push="${AGENT_PLUGINS_SKIP_PUSH:-0}"

  if git -C "$root" diff --quiet && git -C "$root" diff --cached --quiet; then
    return 0
  fi

  git -C "$root" add -A
  git -C "$root" commit -m "$message"

  if [[ "$skip_push" == "1" ]]; then
    return 0
  fi

  local upstream_ref
  upstream_ref="$(git -C "$root" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null || true)"
  if [[ "$upstream_ref" == */* ]]; then
    git -C "$root" push "${upstream_ref%%/*}" "HEAD:${upstream_ref#*/}"
  else
    git -C "$root" push
  fi
}

agent_plugins_catalog_path() {
  local repo_root="${1:-}"
  if [[ -n "$repo_root" && -f "${repo_root}/scripts/lib/agent-plugins-catalog.json" ]]; then
    printf '%s\n' "${repo_root}/scripts/lib/agent-plugins-catalog.json"
    return 0
  fi
  printf '%s\n' "${AGENT_PLUGINS_CATALOG:-scripts/lib/agent-plugins-catalog.json}"
}
