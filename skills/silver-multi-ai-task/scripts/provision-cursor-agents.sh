#!/usr/bin/env bash
# Provision Cursor sb-dr-* custom agents for multi-AI deep research (safe, idempotent).
set -euo pipefail

provision_cursor_agents_repo_root() {
  local dir
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/skills/silver-multi-ai-task/reference/model-family-registry-v1.json" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  printf 'ERROR: cannot locate Silver Bullet repo root from %s\n' "${BASH_SOURCE[0]}" >&2
  return 1
}

REPO_ROOT="$(provision_cursor_agents_repo_root)"
# Literal .cursor path — split so non-cursor agent mirrors do not rewrite host dirs.
CURSOR_HOME="${CURSOR_HOME:-${HOME}/.cur""sor}"
AGENTS_DIR="${CURSOR_AGENTS_DIR:-${CURSOR_HOME}/agents}"
REGISTRY="$REPO_ROOT/skills/silver-multi-ai-task/reference/model-family-registry-v1.json"

usage() {
  cat <<'EOF'
Usage: provision-cursor-agents.sh [--dry-run] [--scope project|global]

Creates sb-dr-* agent stubs for Cursor default pool logical slots when missing.
Does not overwrite existing agent definitions.
EOF
}

DRY_RUN=0
SCOPE="global"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --scope) SCOPE="${2:-global}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ "$SCOPE" == "project" ]]; then
  AGENTS_DIR="$REPO_ROOT/.cur""sor/agents"
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$AGENTS_DIR"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to read cursor_default_pool from registry" >&2
  exit 2
fi

logical_ids=()
while IFS= read -r lid; do
  [[ -n "$lid" ]] && logical_ids+=("$lid")
done < <(jq -r '.cursor_default_pool[]' "$REGISTRY")

if [[ ${#logical_ids[@]} -eq 0 ]]; then
  echo "ERROR: cursor_default_pool is empty in $REGISTRY" >&2
  exit 2
fi

created=0
skipped=0
for lid in "${logical_ids[@]}"; do
  slug="sb-dr-${lid//./-}"
  path="$AGENTS_DIR/${slug}.md"
  if [[ -f "$path" ]]; then
    skipped=$((skipped + 1))
    continue
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "would create: $path"
    created=$((created + 1))
    continue
  fi
  cat >"$path" <<EOF
---
name: ${slug}
description: Silver Bullet DR multi-AI worker for logical slot ${lid}
model: ${lid}
---

# sb-dr worker (${lid})

Provisioned by \`provision-cursor-agents.sh\` for \`/sb:multi-ai-task\` v2.
Return phase-scoped contribution envelopes only; do not synthesize reports or mutate DR state.
EOF
  created=$((created + 1))
done

echo "{\"ok\":true,\"scope\":\"$SCOPE\",\"agents_dir\":\"$AGENTS_DIR\",\"created\":$created,\"skipped\":$skipped,\"registry\":\"$REGISTRY\"}"
