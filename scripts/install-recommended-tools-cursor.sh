#!/usr/bin/env bash
# Install Cursor always-on rules for all SB recommended tools.
# Delegates host/project reconciliation to scripts/reconcile-recommended-tools.sh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
INSTALL_GLOBAL=0
PROJECT_ROOT=""
# One backup per run: the first write keeps the user's file as it was before this run.
export SB_INSTALL_RUN_START="${SB_INSTALL_RUN_START:-$(date +%s)}"
# Rule sources bundled with Silver Bullet (absent from some installed bundles); the project and
# global rule directories are where the files are installed.
RULES_SRC="${REPO_ROOT}/.cursor/rules"
RULES_DIR=""

usage() {
  cat <<'EOF'
Usage: bash scripts/install-recommended-tools-cursor.sh [--global] [--project-root PATH]

Installs always-on Cursor rules for SB recommended tools under the project
.cursor/rules/ directory. Host MCP/hook merges and five-tool reconciliation
are delegated to scripts/reconcile-recommended-tools.sh.

With --global, also syncs rules to ~/.cursor/rules/ and runs host-scope
reconciler apply (installer entry point). A machine-wide rule is installed
only for a tool whose user granted "wire" consent (docs/CONSENT.md); a tool
without it is skipped, and --global alone never grants anything.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --global) INSTALL_GLOBAL=1; shift ;;
    --project-root) PROJECT_ROOT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "$PROJECT_ROOT" ]]; then
  PROJECT_ROOT="$(pwd)"
  if git -C "$PROJECT_ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
    PROJECT_ROOT="$(git -C "$PROJECT_ROOT" rev-parse --show-toplevel)"
  fi
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd -P)"
RULES_DIR="${PROJECT_ROOT}/.cursor/rules"

# keep_rule_backup SRC DEST: before DEST is replaced by a different SRC, keep its content once in DEST.sb-backup.
keep_rule_backup() {
  [[ -f "$2" ]] && ! cmp -s "$1" "$2" && [[ ! -f "${2}.sb-backup" ]] || return 0
  cp -p "$2" "${2}.sb-backup"
}

# install_rule NAME DEST_DIR: copy a bundled rule into DEST_DIR. A missing bundled rule or an
# uninstallable destination is a warning, never an abort (the status is always 0).
install_rule() {
  local name="$1"
  local dest_dir="$2"
  local src="${RULES_SRC}/${name}" dest="${dest_dir}/${name}"
  if [[ ! -f "$src" ]]; then
    printf 'WARN: missing rule file %s\n' "$src" >&2
    return 0
  fi
  if mkdir -p "$dest_dir" && keep_rule_backup "$src" "$dest" && cp -f "$src" "$dest"; then
    printf 'OK: %s\n' "$dest"
  else
    printf 'WARN: could not install %s\n' "$dest" >&2
  fi
}

# Project rules (the user's project, not the Silver Bullet bundle)
for rule in graphify.mdc agentmemory.mdc recommended-tools.mdc leanctx.mdc; do
  install_rule "$rule" "$RULES_DIR" 2>/dev/null
done

TOKEN_ENFORCE_TPL="${REPO_ROOT}/scripts/lib/install-cursor/templates/cursor/token-compression-enforcement.mdc"
if [[ ! -f "${RULES_DIR}/token-compression-enforcement.mdc" ]] && [[ -f "$TOKEN_ENFORCE_TPL" ]]; then
  if mkdir -p "$RULES_DIR" && cp "$TOKEN_ENFORCE_TPL" "${RULES_DIR}/token-compression-enforcement.mdc"; then :; fi
fi

GLOBAL_RULES_DIR="${HOME}/.cursor/rules"
# global_rule_wired TOOL...: the user consented to wiring at least one of TOOLs.
global_rule_wired() {
  local t
  for t in "$@"; do sb_consent_granted "$t" wire && return 0; done
  return 1
}
# install_global_rule RULE SRC_FILE TOOL...: install SRC_FILE as ~/.cursor/rules/RULE only when a TOOL
# is wired; the previous different content is kept once in RULE.sb-backup.
install_global_rule() {
  local rule="$1" src="$2" dest
  shift 2
  if ! global_rule_wired "$@"; then
    printf 'SKIP: global rule %s - no wire consent for %s\n' "$rule" "$*"
    return 0
  fi
  [[ -f "$src" ]] || return 0
  dest="${GLOBAL_RULES_DIR}/${rule}"
  if mkdir -p "$GLOBAL_RULES_DIR" && keep_rule_backup "$src" "$dest" && cp -f "$src" "$dest"; then
    printf 'OK: %s\n' "$dest"
  else
    printf 'WARN: could not install %s\n' "$dest" >&2
  fi
}
if [[ "$INSTALL_GLOBAL" -eq 1 ]]; then
  # shellcheck source=../hooks/lib/user-consent.sh
  source "${REPO_ROOT}/hooks/lib/user-consent.sh"
  for rule_spec in context-mode.mdc:context_mode token-compression-enforcement.mdc:rtk,context_mode \
    graphify.mdc:graphify agentmemory.mdc:agentmemory leanctx.mdc:leanctx; do
    rule="${rule_spec%%:*}"
    IFS=, read -r -a rule_tools <<<"${rule_spec#*:}"
    if [[ -f "${RULES_SRC}/${rule}" ]]; then
      install_global_rule "$rule" "${RULES_SRC}/${rule}" "${rule_tools[@]}"
    else
      install_global_rule "$rule" "${RULES_DIR}/${rule}" "${rule_tools[@]}"
    fi
  done
  if [[ -f "${REPO_ROOT}/scripts/lib/global-toolstack/global-recommended-tools.mdc" ]]; then
    install_global_rule recommended-tools.mdc "${REPO_ROOT}/scripts/lib/global-toolstack/global-recommended-tools.mdc" graphify agentmemory rtk context_mode leanctx
  elif [[ -f "${RULES_SRC}/recommended-tools.mdc" ]]; then
    install_global_rule recommended-tools.mdc "${RULES_SRC}/recommended-tools.mdc" graphify agentmemory rtk context_mode leanctx
  fi
fi

# shellcheck source=lib/recommended-tools/installer.sh
source "${REPO_ROOT}/scripts/lib/recommended-tools/installer.sh"
if [[ -f "${PROJECT_ROOT}/.silver-bullet.json" ]]; then
  rt_installer_post_install "$REPO_ROOT" "$PROJECT_ROOT" || \
    printf 'WARN: reconciler post-install exited nonzero (host infra may still be usable)\n' >&2
elif [[ "$INSTALL_GLOBAL" -eq 1 ]]; then
  rt_installer_post_install "$REPO_ROOT" "" || \
    printf 'WARN: reconciler post-install exited nonzero (host infra may still be usable)\n' >&2
fi

if [[ -x "${HOME}/.cursor/hooks/toolstack/parity-verify.sh" ]]; then
  bash "${HOME}/.cursor/hooks/toolstack/parity-verify.sh" || true
fi

printf '\nCursor recommended-tool rules installed under %s\n' "$RULES_DIR"
if [[ "$INSTALL_GLOBAL" -eq 0 ]]; then
  printf 'Tip: run with --global to sync global rules and host-scope reconciliation\n'
fi
