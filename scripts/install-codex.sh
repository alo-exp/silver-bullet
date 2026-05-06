#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PURGE_LEGACY_SKILLS=0
CODEX_BIN="${CODEX_BIN:-codex}"
NPM_BIN="${NPM_BIN:-npx}"
GSD_INSTALL_CMD="${GSD_INSTALL_CMD:-${NPM_BIN} get-shit-done-cc@latest}"
CODEX_MARKETPLACE_SOURCE="${CODEX_MARKETPLACE_SOURCE:-https://github.com/alo-labs/codex-plugins}"
CODEX_MARKETPLACE_LEGACY_NAME="${CODEX_MARKETPLACE_LEGACY_NAME:-silver-bullet-local}"
SUPERPOWERS_MARKETPLACE_SOURCE="${SUPERPOWERS_MARKETPLACE_SOURCE:-https://github.com/obra/superpowers-marketplace.git}"

usage() {
  cat <<'USAGE'
Usage: scripts/install-codex.sh [--purge-legacy-skills]

Synchronizes the local Codex plugin package and registers the shared
`alo-labs/codex-plugins` marketplace with Codex. Also ensures the official
dependency sources are present.

Options:
  --purge-legacy-skills  Remove SB skill directories already copied into ~/.agents/skills
USAGE
}

remove_marketplace_if_present() {
  local marketplace_name="$1"

  if grep -Fq "[marketplaces.${marketplace_name}]" "${HOME}/.Codex/config.toml" 2>/dev/null; then
    "${CODEX_BIN}" plugin marketplace remove "${marketplace_name}"
  fi
}

ensure_marketplace_registered() {
  local source_spec="$1"

  if grep -Fq "source = \"${source_spec}\"" "${HOME}/.Codex/config.toml" 2>/dev/null; then
    printf 'Codex marketplace already registered from %s\n' "${source_spec}"
    return 0
  fi

  "${CODEX_BIN}" plugin marketplace add "${source_spec}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-legacy-skills) PURGE_LEGACY_SKILLS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

"${SCRIPT_DIR}/sync-codex-package.sh"

if ! command -v "${CODEX_BIN}" >/dev/null 2>&1; then
  printf 'ERROR: codex CLI not found in PATH\n' >&2
  exit 1
fi

remove_marketplace_if_present "${CODEX_MARKETPLACE_LEGACY_NAME}"
ensure_marketplace_registered "${CODEX_MARKETPLACE_SOURCE}"

ensure_marketplace_registered "${SUPERPOWERS_MARKETPLACE_SOURCE}"

if [[ -f "${HOME}/.claude/get-shit-done/VERSION" ]]; then
  printf 'GSD already installed at %s\n' "${HOME}/.claude/get-shit-done/VERSION"
else
  if ! command -v "${NPM_BIN}" >/dev/null 2>&1; then
    printf 'ERROR: npm/npx not found in PATH; cannot install GSD\n' >&2
    exit 1
  fi
  printf 'Installing GSD from official source: %s\n' "${GSD_INSTALL_CMD}"
  # Avoid eval so the bootstrap path stays predictable and shell-safe.
  # The command is treated as a simple whitespace-delimited invocation.
  # Tests can override it with a tiny helper executable.
  read -r -a GSD_INSTALL_ARGS <<< "${GSD_INSTALL_CMD}"
  "${GSD_INSTALL_ARGS[@]}"
fi

if [[ "$PURGE_LEGACY_SKILLS" -eq 1 ]]; then
  LEGACY_SKILLS_HOME="${HOME}/.agents/skills"
  if [[ -d "${LEGACY_SKILLS_HOME}" ]]; then
    while IFS= read -r -d '' skill_dir; do
      skill_name="$(basename "${skill_dir}")"
      if [[ -e "${LEGACY_SKILLS_HOME}/${skill_name}" ]]; then
        rm -rf -- "${LEGACY_SKILLS_HOME:?}/${skill_name}"
        printf 'Removed legacy skill: %s\n' "${skill_name}"
      fi
    done < <(find "${REPO_ROOT}/skills" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
fi

printf 'Codex marketplace registered from %s\n' "${REPO_ROOT}"
