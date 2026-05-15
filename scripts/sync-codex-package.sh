#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEST_DIR="${REPO_ROOT}/plugins/silver-bullet"

log() {
  printf '[codex-sync] %s\n' "$*"
}

mkdir -p "$DEST_DIR/.codex-plugin"

if [[ ! -f "$DEST_DIR/.codex-plugin/plugin.json" ]]; then
  printf 'ERROR: missing Codex manifest at %s\n' "$DEST_DIR/.codex-plugin/plugin.json" >&2
  exit 1
fi

log "Refreshing generated package surface in ${DEST_DIR}"

shopt -s dotglob nullglob
for entry in "${DEST_DIR}"/*; do
  if [[ "$(basename "$entry")" == ".codex-plugin" ]]; then
    continue
  fi
  rm -rf -- "$entry"
done
shopt -u dotglob nullglob

# Codex gets the plugin-facing SB surface here. Project-instance artifacts
# like planning, Claude packaging, Forge packaging, and repo governance live
# outside this bundle. Third-party Codex wrappers are maintained in the shared
# marketplace repo, not in this SB package snapshot. The packaged skills tree is
# generated locally from the canonical repo skills and then frontmatter-rewritten
# so the Codex picker sees the `silver:` namespace while the source repo keeps
# hyphenated skills as the authoring source of truth.
PACKAGE_ENTRIES=(
  AGENTS.md
  CHANGELOG.md
  CODE_OF_CONDUCT.md
  CONTRIBUTING.md
  LICENSE
  README.md
  SECURITY.md
  SENTINEL-audit-silver-bullet-v0.15.1.md
  SENTINEL-audit-silver-init.md
  commands
  .silver-bullet.json
  docs
  hooks
  scripts
  templates
)

for entry in "${PACKAGE_ENTRIES[@]}"; do
  if [[ ! -e "${REPO_ROOT}/${entry}" && ! -L "${REPO_ROOT}/${entry}" ]]; then
    printf 'ERROR: package source missing: %s\n' "${entry}" >&2
    exit 1
  fi
  ln -sfn "../../${entry}" "${DEST_DIR}/${entry}"
done

if [[ -d "${REPO_ROOT}/templates" ]]; then
  rm -rf -- "${DEST_DIR}/templates"
  mkdir -p -- "${DEST_DIR}/templates"
  rsync -a --delete "${REPO_ROOT}/templates/" "${DEST_DIR}/templates/"
fi

PACKAGE_SKILLS_DIR="${DEST_DIR}/.generated-skills"
rm -rf -- "$PACKAGE_SKILLS_DIR"
mkdir -p -- "$PACKAGE_SKILLS_DIR"

python3 - "$REPO_ROOT/skills" "$PACKAGE_SKILLS_DIR" <<'PY'
import pathlib
import re
import shutil
import sys

source_root = pathlib.Path(sys.argv[1])
dest_root = pathlib.Path(sys.argv[2])

name_re = re.compile(r'^(name:\s*)(silver-)([A-Za-z0-9_-]+)\s*$', re.MULTILINE)

def rewrite_skill(text: str) -> str:
    def repl(match: re.Match[str]) -> str:
        return f"{match.group(1)}silver:{match.group(3)}"

    return name_re.sub(repl, text, count=1)

for item in sorted(source_root.iterdir(), key=lambda p: p.name):
    dest = dest_root / item.name
    if item.is_dir():
        shutil.copytree(item, dest, dirs_exist_ok=True)
        for skill_md in dest.rglob("SKILL.md"):
            text = skill_md.read_text()
            updated = rewrite_skill(text)
            if updated != text:
                skill_md.write_text(updated)
    elif item.is_file():
        shutil.copy2(item, dest)
PY

if [[ -x "${SCRIPT_DIR}/codex-sanitize-package.sh" ]]; then
  "${SCRIPT_DIR}/codex-sanitize-package.sh" "$DEST_DIR"
else
  printf 'ERROR: codex sanitizer helper missing at %s\n' "${SCRIPT_DIR}/codex-sanitize-package.sh" >&2
  exit 1
fi

ln -sfn ".generated-skills" "${DEST_DIR}/skills"

log "Codex package synchronized"
