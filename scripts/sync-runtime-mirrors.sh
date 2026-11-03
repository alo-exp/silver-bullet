#!/usr/bin/env bash
# Keep plugins/silver-bullet/{scripts,hooks} linked to the canonical runtime trees.
#
# The plugin package does not copy scripts/ or hooks/: it carries relative
# symlinks (../../scripts, ../../hooks, committed as git symlinks), so the
# package always runs the current sources and there is nothing to copy. This
# script verifies and repairs those links; a physical copy or a link to any
# other tree is drift. (Installers that need real files dereference the links
# when they copy the package.)
#
# Usage:
#   bash scripts/sync-runtime-mirrors.sh          # repair the links
#   bash scripts/sync-runtime-mirrors.sh --check  # verify (exit 1 on drift)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE_ROOT="${REPO_ROOT}/plugins/silver-bullet"
CHECK=false
case "${1:-}" in
  "") ;;
  --check) CHECK=true ;;
  *)
    printf 'Usage: %s [--check]\n' "${0##*/}" >&2
    exit 2
    ;;
esac

MIRRORS=(scripts hooks)
drift=0

for name in "${MIRRORS[@]}"; do
  link="${PACKAGE_ROOT}/${name}"
  want="../../${name}"
  rel="plugins/silver-bullet/${name}"
  if [[ ! -d "${REPO_ROOT}/${name}" ]]; then
    printf 'ERROR: missing canonical tree %s\n' "${REPO_ROOT}/${name}" >&2
    exit 1
  fi
  if [[ -L "$link" && "$(readlink "$link")" == "$want" ]]; then
    continue
  fi
  if [[ "$CHECK" == true ]]; then
    if [[ -L "$link" ]]; then
      printf 'DRIFT: %s -> %s (expected %s)\n' "$rel" "$(readlink "$link")" "$want"
    elif [[ -e "$link" ]]; then
      printf 'DRIFT: %s is a directory, not a link to %s\n' "$rel" "$want"
    else
      printf 'DRIFT: %s is missing\n' "$rel"
    fi
    drift=$((drift + 1))
    continue
  fi
  # A generated copy or a wrong link: replace it with the canonical link. rm
  # removes a symlink itself, never the tree it points to.
  rm -rf -- "$link"
  mkdir -p "$PACKAGE_ROOT"
  ln -s "$want" "$link"
done

if [[ "$CHECK" == true ]]; then
  if [[ "$drift" -gt 0 ]]; then
    printf 'Runtime mirror drift: %d path(s) — run: bash scripts/sync-runtime-mirrors.sh\n' "$drift" >&2
    exit 1
  fi
  printf 'Runtime mirrors fresh (%d links)\n' "${#MIRRORS[@]}"
else
  printf 'Runtime mirrors linked (%d links)\n' "${#MIRRORS[@]}"
fi
