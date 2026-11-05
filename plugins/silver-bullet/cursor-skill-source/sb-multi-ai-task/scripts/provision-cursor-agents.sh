#!/usr/bin/env bash
# Provision Cursor sb-dr-* custom agents for multi-AI deep research (safe, idempotent).
set -euo pipefail

# The registry ships beside this script in every layout: skills/silver-multi-ai-task in the
# repository, skill-source/sb-multi-ai-task in the packaged plugin. Resolve it from the
# (logical) directory the script is invoked through.
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY="$SKILL_DIR/reference/model-family-registry-v1.json"
# Literal .cursor path — split so non-cursor agent mirrors do not rewrite host dirs.
CURSOR_HOME="${CURSOR_HOME:-${HOME}/.cur""sor}"
AGENTS_DIR="${CURSOR_AGENTS_DIR:-${CURSOR_HOME}/agents}"

usage() {
  cat <<'EOF'
Usage: provision-cursor-agents.sh [--dry-run] [--scope project|global] [--project-dir DIR]

Creates sb-dr-* agent stubs for Cursor default pool logical slots when missing.
Does not overwrite existing agent definitions.

--scope project writes <project>/.cursor/agents, where <project> is --project-dir, else the
git top level of the current directory, else the current directory.
EOF
}

DRY_RUN=0
SCOPE="global"
PROJECT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --scope) SCOPE="${2:-global}"; shift 2 ;;
    --project-dir) PROJECT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -f "$REGISTRY" ]]; then
  printf 'ERROR: model family registry not found at %s\n' "$REGISTRY" >&2
  exit 1
fi

if [[ "$SCOPE" == "project" ]]; then
  # The user's project, never the Silver Bullet checkout or plugin install this script lives in.
  if [[ -z "$PROJECT_DIR" ]]; then
    PROJECT_DIR="$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$PWD")"
  fi
  if [[ ! -d "$PROJECT_DIR" ]]; then
    printf 'ERROR: project directory not found: %s\n' "$PROJECT_DIR" >&2
    exit 2
  fi
  AGENTS_DIR="$(cd "$PROJECT_DIR" && pwd)/.cur""sor/agents"
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq is required to read cursor_default_pool from registry" >&2
  exit 2
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  mkdir -p "$AGENTS_DIR"
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

jq -cn --arg scope "$SCOPE" --arg dir "$AGENTS_DIR" --arg reg "$REGISTRY" \
  --argjson created "$created" --argjson skipped "$skipped" \
  '{ok: true, scope: $scope, agents_dir: $dir, created: $created, skipped: $skipped, registry: $reg}'
