#!/usr/bin/env bash
# install-recommended-tools-global.sh — global RTK + Context Mode instruction artifacts per host.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/rtk-cm-global.sh"
# One backup per run: the first write keeps the user's file as it was before this run.
export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"

HOST=""
INSTALL_GLOBAL=0

usage() {
  cat <<'EOF'
Usage: bash scripts/install-recommended-tools-global.sh --host HOST [--global]

Syncs global instruction artifacts (rules, AGENTS.md routing) for RTK + Context Mode.
Does NOT require Silver Bullet. RTK/Codex hooks are applied by optimize-rtk-context-mode.sh.

Hosts: claude | codex | cursor | opencode | pi | hermes | goose | all

Options:
  --host HOST   Target agent (required)
  --global      Alias for global-only install (default behavior)
  -h, --help    Show help
EOF
}

# shellcheck source=../hooks/lib/rtk-cm-global.sh
source "$LIB"
# shellcheck source=../hooks/lib/user-consent.sh
source "${REPO_ROOT}/hooks/lib/user-consent.sh"

# install_agents_file SRC DEST: DEST is the user's global instruction file (~/.codex/AGENTS.md ...).
# Written only with Context Mode "wire" consent, atomically through a symlink, mode kept, and the
# previous content kept in DEST.sb-backup.
install_agents_file() {
  local src="$1" dest="$2"
  if ! sb_consent_granted context_mode wire; then
    printf 'SKIP: %s - no Context Mode wire consent (bash %s/sb-consent.sh grant context_mode --all-projects --capabilities wire)\n' \
      "$dest" "$SCRIPT_DIR" >&2
    return 0
  fi
  if python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import sb_host_config as c; c.write_atomic(sys.argv[2], open(sys.argv[3], "rb").read())' \
    "${SCRIPT_DIR}/lib" "$dest" "$src"; then
    printf 'OK: %s\n' "$dest"
  else
    printf 'WARN: could not write %s\n' "$dest" >&2
    return 1
  fi
}

install_cursor_global() {
  bash "${SCRIPT_DIR}/install-recommended-tools-cursor.sh" --global
}

install_opencode_agents() {
  local dest="${HOME}/.config/opencode/AGENTS.md"
  local cm_pkg=""
  if command -v npm >/dev/null 2>&1; then
    cm_pkg="$(npm root -g 2>/dev/null)/context-mode/configs/opencode/AGENTS.md"
  fi
  if [[ -f "$cm_pkg" ]]; then
    install_agents_file "$cm_pkg" "$dest"
  else
    printf 'WARN: context-mode opencode AGENTS.md not found — run npm install -g context-mode\n' >&2
  fi
}

install_codex_agents() {
  local dest="${HOME}/.codex/AGENTS.md"
  local cm_pkg=""
  if command -v npm >/dev/null 2>&1; then
    cm_pkg="$(npm root -g 2>/dev/null)/context-mode/configs/codex/AGENTS.md"
  fi
  if [[ -f "$cm_pkg" ]]; then
    install_agents_file "$cm_pkg" "$dest"
  else
    printf 'WARN: context-mode codex AGENTS.md not found\n' >&2
  fi
}

install_claude_hint() {
  if [[ -f "${HOME}/.claude/RTK.md" ]]; then
    printf 'OK: ~/.claude/RTK.md present (from rtk init -g)\n'
  else
    printf 'WARN: run rtk init -g for Claude RTK wiring\n' >&2
  fi
}

install_pi_global() {
  local installer="${SCRIPT_DIR}/lib/global-toolstack/install-pi.py"
  [[ -f "$installer" ]] || {
    printf 'ERROR: Pi five-tool installer missing: %s\n' "$installer" >&2
    return 1
  }
  # The adapter, its config and ~/.pi/agent/settings.json are host configuration: written only with
  # wire consent, and only the consented tools are switched on (docs/CONSENT.md).
  local -a pi_args=(--repo-root "$REPO_ROOT") enable_words=()
  read -r -a enable_words <<<"$(sb_consent_pi_enable_words)"
  if [[ "${#enable_words[@]}" -eq 0 ]]; then
    printf 'SKIP: Pi adapter - no wire consent for any tool (bash %s/sb-consent.sh grant <tool> --all-projects --capabilities wire)\n' \
      "$SCRIPT_DIR" >&2
    return 0
  fi
  python3 "$installer" "${pi_args[@]}" "${enable_words[@]}"
}

install_hermes_note() {
  printf 'Hermes: enable rtk-rewrite in ~/.hermes/config.yaml plugins.enabled\n'
  printf 'See docs/rtk-cm/verification/hermes-verify-rtk-cm.md\n'
}

install_goose_skip() {
  rtcm_log_unsupported "goose"
}

install_host() {
  local h="${1:-}"
  case "$h" in
    cursor) install_cursor_global ;;
    opencode) install_opencode_agents ;;
    pi) install_pi_global ;;
    codex) install_codex_agents ;;
    claude) install_claude_hint ;;
    hermes) install_hermes_note ;;
    goose) install_goose_skip ;;
    *) printf 'Unsupported host: %s\n' "$h" >&2; return 2 ;;
  esac
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HOST="${2:-}"; shift 2 ;;
    --global) INSTALL_GLOBAL=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$HOST" ]] || { usage >&2; exit 2; }
: "${INSTALL_GLOBAL:?}" # reserved for future --global wiring

if [[ "$HOST" == "all" ]]; then
  for h in $RTCM_SUPPORTED_HOSTS; do
    install_host "$h"
  done
  exit 0
fi

rtcm_validate_host "$HOST" || {
  echo "Invalid --host: $HOST" >&2
  exit 2
}
install_host "$HOST"
