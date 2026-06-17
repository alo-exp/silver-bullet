#!/usr/bin/env bash
# Mechanical project-surface migration for legacy SB-initiated projects.
# Complements silver:migrate Steps 1–4 (config, orchestrator, workflows helper, gitignore).
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEARCH_DIR="${1:-$PWD}"
CONFIG=""

while true; do
  if [[ -f "$SEARCH_DIR/.silver-bullet.json" ]]; then
    CONFIG="$SEARCH_DIR/.silver-bullet.json"
    break
  fi
  if [[ -d "$SEARCH_DIR/.git" ]] || [[ "$SEARCH_DIR" == "/" ]]; then
    break
  fi
  SEARCH_DIR=$(dirname "$SEARCH_DIR")
done

if [[ -z "$CONFIG" ]]; then
  echo "No .silver-bullet.json found under ${1:-$PWD}" >&2
  exit 1
fi

PROJ_ROOT="$(dirname "$CONFIG")"

bash "$PLUGIN_ROOT/scripts/sb-migrate-config.sh" "$PROJ_ROOT"
bash "$PLUGIN_ROOT/scripts/sb-migrate-orchestrator-parent.sh" "$PROJ_ROOT"

mkdir -p "$PROJ_ROOT/scripts"
if [[ ! -x "$PROJ_ROOT/scripts/workflows.sh" ]]; then
  cp "$PLUGIN_ROOT/scripts/workflows.sh" "$PROJ_ROOT/scripts/workflows.sh"
  chmod +x "$PROJ_ROOT/scripts/workflows.sh"
  echo "Installed scripts/workflows.sh"
else
  echo "scripts/workflows.sh already present"
fi

mkdir -p "$PROJ_ROOT/.planning/workflows/.archive"
mkdir -p "$PROJ_ROOT/docs/workflows"

for wf in full-dev-cycle.md devops-cycle.md; do
  src="$PLUGIN_ROOT/templates/workflows/$wf"
  dest="$PROJ_ROOT/docs/workflows/$wf"
  if [[ -f "$src" && ! -f "$dest" ]]; then
    cp "$src" "$dest"
    echo "Installed docs/workflows/$wf"
  fi
done

GITIGNORE="$PROJ_ROOT/.gitignore"
MARKER='.planning/workflows/'
if [[ -f "$GITIGNORE" ]]; then
  if ! grep -qF "$MARKER" "$GITIGNORE" 2>/dev/null; then
    {
      echo ""
      echo "# Composed-workflow tracker — local runtime state (Silver Bullet)"
      echo "$MARKER"
    } >>"$GITIGNORE"
    echo "Added $MARKER to .gitignore"
  fi
else
  cat >"$GITIGNORE" <<'EOF'
# Composed-workflow tracker — local runtime state (Silver Bullet)
.planning/workflows/
EOF
  echo "Created .gitignore with $MARKER"
fi

echo "Project surface migration complete for $PROJ_ROOT"
