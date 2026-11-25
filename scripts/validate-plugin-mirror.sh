#!/usr/bin/env bash
# Validate that every generated package surface equals a fresh regeneration.
#
# Copies the generator inputs (skills/, templates/, scripts/, hooks/ and the
# manifests) into a scratch checkout, runs
# scripts/sync-codex-package.sh there, and compares each generated root with
# the committed tree in both directions: a stale, missing or extra file is
# drift. It also checks the package's symlinked entries, that the package root
# holds nothing the sync would prune, and that no generated path uses a
# character native Windows cannot check out, apart from the colon route
# directories of agents/claude (see docs/ARCHITECTURE.md).
#
# Usage: bash scripts/validate-plugin-mirror.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PKG="plugins/silver-bullet"

GENERATED=(
  agents/claude
  host-bundles/codex
  "${PKG}/skill-source"
  "${PKG}/templates"
  "${PKG}/.codex-plugin/plugin.json"
)
LINKED=(AGENTS.md CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md LICENSE README.md SECURITY.md .silver-bullet.json docs hooks scripts)
MAX_REPORT=50

work="$(mktemp -d "${TMPDIR:-/tmp}/sb-mirror-check.XXXXXX")"
trap 'rm -rf "$work"' EXIT
scratch="${work}/repo"
mkdir -p "${scratch}/${PKG}"

# Inputs. Package entries the sync only links get empty stand-ins.
rsync -a --exclude='__pycache__/' --exclude='*.render.lock' \
  "${REPO_ROOT}/skills" "${REPO_ROOT}/templates" "${REPO_ROOT}/scripts" "${REPO_ROOT}/hooks" \
  "${REPO_ROOT}/package.json" "${scratch}/"
rsync -a "${REPO_ROOT}/${PKG}/.codex-plugin" "${scratch}/${PKG}/"
for entry in AGENTS.md CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md LICENSE README.md SECURITY.md .silver-bullet.json; do
  : >"${scratch}/${entry}"
done
mkdir -p "${scratch}/docs"

if ! (cd "$scratch" && bash scripts/sync-codex-package.sh) >"${work}/sync.log" 2>&1; then
  cat "${work}/sync.log"
  echo "::error::Plugin mirror check could not regenerate the package (scripts/sync-codex-package.sh failed)"
  exit 1
fi

drift=0
report() {
  drift=$((drift + 1))
  [[ "$drift" -le "$MAX_REPORT" ]] && printf 'DRIFT: %s\n' "$1"
  return 0
}

# same_entry <a> <b>: identical regular files. The renderers write no symlinks, so
# a symlink on either side (one smuggled into a generated tree) is drift.
same_entry() {
  if [[ -L "$1" || -L "$2" ]]; then
    return 1
  fi
  cmp -s "$1" "$2"
}

# list_files <dir>: relative paths of the files and symlinks below <dir>.
list_files() {
  if [[ -d "$1" ]]; then
    (cd "$1" && find . ! -type d ! -name '*.render.lock' ! -path '*/__pycache__/*' | sed 's|^\./||')
  fi
}

echo "Checking generated package surfaces against a fresh regeneration..."
for rel in "${GENERATED[@]}"; do
  committed="${REPO_ROOT}/${rel}"
  fresh="${scratch}/${rel}"
  if [[ -f "$fresh" || -f "$committed" ]]; then
    cmp -s "$committed" "$fresh" || report "$rel"
    continue
  fi
  while IFS= read -r file; do
    same_entry "${committed}/${file}" "${fresh}/${file}" || report "${rel}/${file}"
  done < <({ list_files "$committed"; list_files "$fresh"; } | sort -u)
done

echo "Checking package links and top-level entries..."
for entry in "${LINKED[@]}"; do
  path="${REPO_ROOT}/${PKG}/${entry}"
  if [[ ! -L "$path" || "$(readlink "$path")" != "../../${entry}" ]]; then
    report "${PKG}/${entry} must be a symlink to ../../${entry}"
  fi
done
while IFS= read -r entry; do
  report "${PKG}/${entry} (the sync would remove or create it)"
done < <(comm -3 \
  <(cd "${REPO_ROOT}/${PKG}" && find . -mindepth 1 -maxdepth 1 | sed 's|^\./||' | sort) \
  <(cd "${scratch}/${PKG}" && find . -mindepth 1 -maxdepth 1 | sed 's|^\./||' | sort) |
  sed 's/^[[:space:]]*//')

echo "Checking generated paths for characters Windows cannot check out..."
# Scan the fresh regeneration: what the current sources produce.
unsafe="$(python3 - "$scratch" "${GENERATED[@]}" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
bad = re.compile(r'[:*?"<>|\\]|[. ]$')
route_dir = re.compile(r"^sb:[a-z0-9][a-z0-9-]*$")
for rel in sys.argv[2:]:
    base = root / rel
    for path in (sorted(base.rglob("*")) if base.is_dir() else []):
        parts = path.relative_to(root).parts
        for depth, part in enumerate(parts):
            # Documented exception: the Claude picker bundle names
            # its top-level route directories sb:<route>.
            if depth == 2 and parts[:2] == ("agents", "claude") and route_dir.match(part):
                continue
            if bad.search(part):
                print("/".join(parts))
                break
PY
)"
while IFS= read -r path; do
  [[ -n "$path" ]] && report "${path} (Windows-unsafe path)"
done <<<"$unsafe"

if [[ "$drift" -gt 0 ]]; then
  [[ "$drift" -gt "$MAX_REPORT" ]] && printf '... and %d more\n' "$((drift - MAX_REPORT))"
  echo "::error::Plugin mirror drift detected (${drift} path(s)) — run: bash scripts/sync-codex-package.sh"
  exit 1
fi
echo "Plugin mirror OK"
