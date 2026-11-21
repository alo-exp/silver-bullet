#!/usr/bin/env bash
# Post-release tri-host verification — clean uninstall, fresh install, smoke, marker.
#
# Mandatory after gh release create (see skills/silver-create-release, pre-release-quality-gate Stage 5).
#
# Usage:
#   bash scripts/post-release-host-verify.sh
#   bash scripts/post-release-host-verify.sh --version v0.51.3 --host codex
#   bash scripts/post-release-host-verify.sh --skip-smoke
#
# Writes per-host markers under ~/.{codex,claude}/.silver-bullet/post-release-verify/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
export SB_POST_RELEASE_REPO_ROOT="$REPO_ROOT"
export SB_PRE_RELEASE_REPO_ROOT="$REPO_ROOT"

# shellcheck source=scripts/lib/post-release-uninstall.sh
source "${SCRIPT_DIR}/lib/post-release-uninstall.sh"
# shellcheck source=scripts/lib/pre-release-host-isolation.sh
source "${SCRIPT_DIR}/lib/pre-release-host-isolation.sh"

if [[ -f "${REPO_ROOT}/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${REPO_ROOT}/hooks/lib/runtime-paths.sh"
fi

VERSION="${SB_POST_RELEASE_VERSION:-}"
HOST_FILTER=all
SKIP_SMOKE=0
PUBLIC_RELEASE=0
INSTALL_REPO=""
INSTALL_REPO_TMP=""
TAG_COMMIT=""

usage() {
  cat <<'USAGE'
Usage: scripts/post-release-host-verify.sh [--version TAG] [--host codex|claude|all] [--skip-smoke] [--public-release]

Per host on the operator machine:
  1. Uninstall SB only (preserve rtk, context-mode, and other non-SB hooks)
  2. Fresh install from a checkout of the release tag (never the working tree)
  3. Install smoke (sb-diagnostics) + RC fresh cell (isolated delegate smoke), both from that checkout
  4. Write marker under ${SB_RUNTIME_STATE_DIR}/post-release-verify/
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version) VERSION="$2"; shift 2 ;;
    --host) HOST_FILTER="$2"; shift 2 ;;
    --skip-smoke) SKIP_SMOKE=1; shift ;;
    --public-release) PUBLIC_RELEASE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$HOST_FILTER" in
  all|codex|claude) ;;
  *) printf 'Unknown host: %s\n' "$HOST_FILTER" >&2; usage >&2; exit 2 ;;
esac

if [[ -z "$VERSION" ]]; then
  VERSION="$(git -C "$REPO_ROOT" describe --tags --abbrev=0 2>/dev/null || true)"
fi
[[ -n "$VERSION" ]] || { printf 'ERROR: could not resolve release version\n' >&2; exit 1; }
VERSION="v${VERSION#v}"

# The release is the tag, not this checkout: package.json keeps the released version long
# after later commits, and the working tree may hold uncommitted edits. Every host is
# installed, diagnosed and smoke-tested from a detached clone of the tagged commit (a real
# git checkout, so installers that record the installed commit see the tag's).
resolve_install_repo() {
  TAG_COMMIT="$(git -C "$REPO_ROOT" rev-parse --verify --quiet "refs/tags/${VERSION}^{commit}" 2>/dev/null || true)"
  if [[ -z "$TAG_COMMIT" ]]; then
    printf 'ERROR: release tag %s not found in %s (git fetch --tags); post-release verification installs the released tag, never the working tree\n' "$VERSION" "$REPO_ROOT" >&2
    exit 1
  fi
  INSTALL_REPO_TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-post-release-install.XXXXXX")"
  INSTALL_REPO="${INSTALL_REPO_TMP}/silver-bullet"
  git clone -q --local --no-checkout "$REPO_ROOT" "$INSTALL_REPO"
  git -C "$INSTALL_REPO" -c advice.detachedHead=false checkout -q --detach "$TAG_COMMIT"
}

cleanup_install_repo() {
  if [[ -n "$INSTALL_REPO_TMP" && -d "$INSTALL_REPO_TMP" ]]; then
    rm -rf "$INSTALL_REPO_TMP"
  fi
}

# The trap is in place before the temporary directory exists, so a failing clone or
# checkout cannot leak it.
trap cleanup_install_repo EXIT
resolve_install_repo

marker_dir_for_host() {
  local host="$1" home_root
  case "$host" in
    codex) home_root="${HOME}/.codex" ;;
    claude) home_root="${HOME}/.claude" ;;
  esac
  printf '%s/post-release-verify\n' "${home_root}/.silver-bullet"
}

write_marker() {
  local host="$1" status="$2" detail="${3:-}"
  local dir file
  dir="$(marker_dir_for_host "$host")"
  mkdir -p "$dir"
  file="${dir}/${host}"
  {
    printf 'host=%s\nversion=%s\nstatus=%s\n' "$host" "$VERSION" "$status"
    printf 'commit=%s\n' "$TAG_COMMIT"
    printf 'timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    [[ -n "$detail" ]] && printf 'detail=%s\n' "$detail"
  } >"$file"
}

host_install_args() {
  local host="$1"
  case "$host" in
    claude) printf '%s\n' --purge-legacy-plugins ;;
    codex) printf '%s\n' --purge-legacy-skills ;;
  esac
  [[ "$PUBLIC_RELEASE" -eq 1 ]] && printf '%s\n' --public-release
}

run_fresh_install() {
  local host="$1" script arg
  script="${INSTALL_REPO}/scripts/install-${host}.sh"
  [[ -f "$script" ]] || { printf 'ERROR: missing %s\n' "$script" >&2; return 1; }
  local -a extra=()
  while IFS= read -r arg; do
    [[ -n "$arg" ]] && extra+=("$arg")
  done < <(host_install_args "$host")
  if ((${#extra[@]} > 0)); then
    RTK_DISABLED=1 bash "$script" "${extra[@]}"
  else
    RTK_DISABLED=1 bash "$script"
  fi
}

run_install_smoke() {
  local host="$1"
  export SILVER_BULLET_RUNTIME="$host"
  case "$host" in
    codex) export SILVER_BULLET_RUNTIME=codex ;;
    claude) export SILVER_BULLET_RUNTIME=claude ;;
  esac
  SB_DIAG_SMOKE=1 RTK_DISABLED=1 bash "${INSTALL_REPO}/scripts/sb-diagnostics.sh" >/dev/null
}

# The RC cell reinstalls from the tree it runs from (scripts/lib/host-smoke-cell.sh), so it
# runs from the tag checkout too.
run_rc_fresh_smoke() {
  local host="$1"
  RTK_DISABLED=1 bash "${INSTALL_REPO}/scripts/run-rc-validation-matrix.sh" --host "$host" --mode fresh
}

verify_host() {
  local host="$1"
  local uninstall_ok=FAIL install_ok=FAIL diag_ok=SKIP rc_ok=SKIP final=FAIL

  printf '\n[post-release-verify] === %s (%s) ===\n' "$host" "$VERSION"

  if sb_post_release_uninstall_host "$host"; then
    uninstall_ok=PASS
  else
    write_marker "$host" fail "uninstall"
    printf 'host=%s uninstall=%s install=%s diag=%s rc=%s result=%s\n' \
      "$host" "$uninstall_ok" "$install_ok" "$diag_ok" "$rc_ok" "$final"
    return 1
  fi

  local install_exit=0
  run_fresh_install "$host" || install_exit=$?
  if run_install_smoke "$host"; then
    install_ok=PASS
    if [[ "$install_exit" -ne 0 ]]; then
      printf 'WARN: install script exited %s; diagnostics passed (functional install OK)\n' "$install_exit"
    fi
  else
    install_ok=FAIL
    write_marker "$host" fail "install-or-diagnostics"
    printf 'host=%s uninstall=%s install=%s diag=%s rc=%s result=%s\n' \
      "$host" "$uninstall_ok" "$install_ok" "FAIL" "$rc_ok" "$final"
    return 1
  fi

  diag_ok=PASS

  if [[ "$SKIP_SMOKE" -eq 1 ]]; then
    rc_ok=SKIP
    final=PASS
    write_marker "$host" pass "skip-rc"
    printf 'host=%s uninstall=%s install=%s diag=%s rc=%s result=%s\n' \
      "$host" "$uninstall_ok" "$install_ok" "$diag_ok" "$rc_ok" "$final"
    return 0
  fi

  if run_rc_fresh_smoke "$host"; then
    rc_ok=PASS
    final=PASS
    write_marker "$host" pass "fresh-smoke"
  else
    rc_ok=FAIL
    final=FAIL
    write_marker "$host" fail "rc-fresh"
  fi

  printf 'host=%s uninstall=%s install=%s diag=%s rc=%s result=%s\n' \
    "$host" "$uninstall_ok" "$install_ok" "$diag_ok" "$rc_ok" "$final"
  [[ "$final" == PASS ]]
}

PASS=0
FAIL=0
for host in codex claude; do
  [[ "$HOST_FILTER" == all || "$HOST_FILTER" == "$host" ]] || continue
  if verify_host "$host"; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done

printf '\nPost-release host verify: %s passed, %s failed (version %s)\n' "$PASS" "$FAIL" "$VERSION"
[[ "$FAIL" -eq 0 ]]
