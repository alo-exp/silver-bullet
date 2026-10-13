#!/usr/bin/env bash
# Mirror canonical scripts/ and hooks/ runtime artifacts into plugins/silver-bullet/.
# Usage:
#   bash scripts/sync-runtime-mirrors.sh          # regenerate
#   bash scripts/sync-runtime-mirrors.sh --check  # verify freshness (exit 1 on drift)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CHECK=false
if [[ "${1:-}" == "--check" ]]; then
  CHECK=true
fi

DST_SCRIPTS="${REPO_ROOT}/plugins/silver-bullet/scripts"
DST_HOOKS="${REPO_ROOT}/plugins/silver-bullet/hooks"
SRC_SCRIPTS="${REPO_ROOT}/scripts"
SRC_HOOKS="${REPO_ROOT}/hooks"

# Explicit manifest — add entries when new runtime surfaces ship.
MIRROR_SCRIPTS=(
  reconcile-recommended-tools.sh
  sb-doctor.sh
  optimize-five-tool-stack.sh
  optimize-rtk-context-mode.sh
  install-leanctx-sb.sh
  install-cursor.sh
  install-global-toolstack.sh
  install-recommended-tools-cursor.sh
)

MIRROR_SCRIPT_DIRS=(
  lib/recommended-tools
  lib/global-toolstack
)

MIRROR_HOOKS=(
  session-start
  hooks.json
)

MIRROR_HOOK_DIRS=(
  lib
)

drift=0
copied=0

copy_file() {
  local src="$1" dst="$2"
  if [[ ! -f "$src" ]]; then
    printf 'WARN: missing source %s\n' "$src" >&2
    return 0
  fi
  if [[ "$CHECK" == true ]]; then
    if [[ ! -f "$dst" ]] || ! cmp -s "$src" "$dst"; then
      printf 'DRIFT: %s\n' "${dst#${REPO_ROOT}/}"
      drift=$((drift + 1))
    fi
    return 0
  fi
  mkdir -p "$(dirname "$dst")"
  cp -f "$src" "$dst"
  copied=$((copied + 1))
}

copy_tree() {
  local src_dir="$1" dst_dir="$2"
  [[ -d "$src_dir" ]] || return 0
  if [[ "$CHECK" == true ]]; then
    while IFS= read -r src; do
      rel="${src#${src_dir}/}"
      dst="${dst_dir}/${rel}"
      if [[ ! -f "$dst" ]] || ! cmp -s "$src" "$dst"; then
        printf 'DRIFT: %s\n' "${dst#${REPO_ROOT}/}"
        drift=$((drift + 1))
      fi
    done < <(find "$src_dir" -type f | sort)
    return 0
  fi
  mkdir -p "$dst_dir"
  rsync -a "${src_dir}/" "${dst_dir}/"
  copied=$((copied + 1))
}

for f in "${MIRROR_SCRIPTS[@]}"; do
  copy_file "${SRC_SCRIPTS}/${f}" "${DST_SCRIPTS}/${f}"
done
for d in "${MIRROR_SCRIPT_DIRS[@]}"; do
  copy_tree "${SRC_SCRIPTS}/${d}" "${DST_SCRIPTS}/${d}"
done
for f in "${MIRROR_HOOKS[@]}"; do
  copy_file "${SRC_HOOKS}/${f}" "${DST_HOOKS}/${f}"
done
for d in "${MIRROR_HOOK_DIRS[@]}"; do
  copy_tree "${SRC_HOOKS}/${d}" "${DST_HOOKS}/${d}"
done

if [[ "$CHECK" == true ]]; then
  if [[ "$drift" -gt 0 ]]; then
    printf 'Runtime mirror drift: %d file(s) — run: bash scripts/sync-runtime-mirrors.sh\n' "$drift" >&2
    exit 1
  fi
  printf 'Runtime mirrors fresh (%d paths checked)\n' \
    "$((${#MIRROR_SCRIPTS[@]} + ${#MIRROR_SCRIPT_DIRS[@]} + ${#MIRROR_HOOKS[@]} + ${#MIRROR_HOOK_DIRS[@]}))"
else
  chmod +x "${DST_SCRIPTS}/reconcile-recommended-tools.sh" 2>/dev/null || true
  printf 'Synced runtime mirrors (%d operations)\n' "$copied"
fi
