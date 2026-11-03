# shellcheck shell=bash
# Pre-release host smoke isolation — shared helpers.
#
# Policy: never read or write the operator's regular host runtime homes
# (~/.claude, ~/.codex). Each smoke host gets a dedicated temp root
# under SB_PRE_RELEASE_SMOKE_ROOT (default: mktemp under ${TMPDIR}/sb-pre-release-smoke.*).
#
# Smoke root ownership: entry points pin the root once in their own shell
# (sb_smoke_init_root, or SB_PRE_RELEASE_SMOKE_ROOT="$(sb_smoke_root)"), so
# helpers that run in $(...) all share it. A root that was already set in the
# environment when this library was sourced belongs to the caller (an operator
# directory, or a parent smoke run) and sb_smoke_cleanup never removes it; a
# root this process created is removed. Each sb_smoke_begin_* also clears the
# variables that would point a host install at the operator's real config.
#
if [[ -n "${_SB_PRE_RELEASE_ISOLATION_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
_SB_PRE_RELEASE_ISOLATION_LOADED=1
_SB_SMOKE_ROOT_INHERITED="${SB_PRE_RELEASE_SMOKE_ROOT:-}"

sb_smoke_roots=()

# sb_smoke_init_root: pin the smoke root in the current shell. Call it directly
# (not in $(...)), before any helper runs.
sb_smoke_init_root() {
  if [[ -z "${SB_PRE_RELEASE_SMOKE_ROOT:-}" ]]; then
    SB_PRE_RELEASE_SMOKE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/sb-pre-release-smoke.XXXXXX")"
  fi
  export SB_PRE_RELEASE_SMOKE_ROOT
}

# sb_smoke_root: print the smoke root, creating one when none is pinned, so a
# caller can pin it with SB_PRE_RELEASE_SMOKE_ROOT="$(sb_smoke_root)".
sb_smoke_root() {
  sb_smoke_init_root
  printf '%s\n' "$SB_PRE_RELEASE_SMOKE_ROOT"
}

# _sb_smoke_pinned_root: the root for helpers that run in $(...). They cannot
# pin a root for their caller, so an unpinned root is an error, not a new dir.
_sb_smoke_pinned_root() {
  if [[ -z "${SB_PRE_RELEASE_SMOKE_ROOT:-}" ]]; then
    printf 'pre-release-host-isolation: smoke root not pinned — call sb_smoke_init_root first\n' >&2
    return 1
  fi
  printf '%s\n' "$SB_PRE_RELEASE_SMOKE_ROOT"
}

sb_smoke_host_root() {
  local host="$1"
  local root
  root="$(_sb_smoke_pinned_root)/${host}" || return 1
  mkdir -p "$root"
  printf '%s\n' "$root"
}

# sb_smoke_clear_host_env: drop the variables that redirect a host CLI or
# installer to real configuration or SB state outside the isolated HOME
# (Kay's home, Claude's config dir, Codex's home, SB state dir/files, XDG
# roots). The begin_* helpers then set what the smoke needs.
sb_smoke_clear_host_env() {
  unset KAY_HOME CLAUDE_CONFIG_DIR CODEX_HOME \
    SILVER_BULLET_STATE_FILE SILVER_BULLET_BRANCH_FILE \
    SB_RUNTIME_HOME_ROOT SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PRESERVE_STATE_DIR \
    XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME
}

sb_smoke_track_root() {
  local root="$1"
  local existing
  if ((${#sb_smoke_roots[@]} > 0)); then
    for existing in "${sb_smoke_roots[@]}"; do
      [[ "$existing" == "$root" ]] && return 0
    done
  fi
  sb_smoke_roots+=("$root")
}

sb_smoke_begin_codex() {
  local root
  root="$(sb_smoke_host_root codex)" || return 1
  sb_smoke_track_root "$root"
  sb_smoke_clear_host_env

  export HOME="$root"
  export CODEX_HOME_ROOT="$root"
  export SILVER_BULLET_RUNTIME=codex
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${root}/.silver-bullet"

  if [[ -f "${SB_PRE_RELEASE_REPO_ROOT:-}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_PRE_RELEASE_REPO_ROOT}/hooks/lib/runtime-paths.sh"
  fi
}

sb_smoke_begin_claude() {
  local root
  root="$(sb_smoke_host_root claude)" || return 1
  sb_smoke_track_root "$root"
  sb_smoke_clear_host_env

  export HOME="$root"
  export SILVER_BULLET_RUNTIME=claude
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${root}/.silver-bullet"

  if [[ -f "${SB_PRE_RELEASE_REPO_ROOT:-}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_PRE_RELEASE_REPO_ROOT}/hooks/lib/runtime-paths.sh"
  fi
}

# sb_smoke_cleanup: remove the smoke root when this process created it (the
# per-host roots live inside it). An inherited root is the caller's and stays,
# with everything in it, and stays pinned.
sb_smoke_cleanup() {
  if [[ -n "${SB_PRE_RELEASE_SMOKE_ROOT:-}" && "$SB_PRE_RELEASE_SMOKE_ROOT" != "$_SB_SMOKE_ROOT_INHERITED" ]]; then
    rm -rf -- "$SB_PRE_RELEASE_SMOKE_ROOT" 2>/dev/null || true
  fi
  sb_smoke_roots=()
  if [[ -n "$_SB_SMOKE_ROOT_INHERITED" ]]; then
    SB_PRE_RELEASE_SMOKE_ROOT="$_SB_SMOKE_ROOT_INHERITED"
  else
    unset SB_PRE_RELEASE_SMOKE_ROOT
  fi
}

# sb_smoke_resolve_previous_tag: the release the RC upgrade cells start from.
# The matrix runs before the new version is tagged, so this is the newest
# release tag (vMAJOR.MINOR.PATCH) strictly older than package.json's version;
# without a readable package.json, the newest release tag not at HEAD.
# SB_RC_PREVIOUS_TAG overrides.
sb_smoke_resolve_previous_tag() {
  [[ -n "${SB_RC_PREVIOUS_TAG:-}" ]] && { printf '%s\n' "$SB_RC_PREVIOUS_TAG"; return 0; }
  local repo="${SB_PRE_RELEASE_REPO_ROOT:-}" tag tags head_tags
  [[ -d "${repo}/.git" ]] || return 1
  tags="$(git -C "$repo" tag --list 2>/dev/null || true)"
  head_tags="$(git -C "$repo" tag --points-at HEAD 2>/dev/null || true)"
  tag="$(
    python3 - "${repo}/package.json" "$tags" "$head_tags" <<'PY'
import json
import re
import sys

RELEASE = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")
VERSION = re.compile(r"^v?(\d+)\.(\d+)\.(\d+)(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$")
releases = {}
for tag in sys.argv[2].split():
    match = RELEASE.match(tag)
    if match:
        releases[tag] = tuple(int(part) for part in match.groups()) + (1,)
try:
    version = str(json.load(open(sys.argv[1], encoding="utf-8")).get("version", ""))
except (OSError, ValueError, AttributeError):
    version = ""
match = VERSION.match(version)
if match:
    # A pre-release package version ranks below its own release tag.
    current = tuple(int(part) for part in match.groups()[:3]) + (0 if match.group(4) else 1,)
    candidates = [tag for tag, key in releases.items() if key < current]
else:
    head = set(sys.argv[3].split())
    candidates = [tag for tag in releases if tag not in head]
if not candidates:
    sys.exit(1)
print(max(candidates, key=releases.get))
PY
  )" || return 1
  printf '%s\n' "$tag"
}

sb_smoke_checkout_at_tag() {
  local tag="$1" dest="$2" repo="${SB_PRE_RELEASE_REPO_ROOT:-}"
  [[ -d "${repo}/.git" ]] || return 1
  mkdir -p "$dest" && git -C "$repo" archive "$tag" | tar -x -C "$dest"
}

sb_smoke_rc_marker_dir() { printf '%s/rc-validation\n' "${SB_RUNTIME_STATE_DIR:-${HOME}/.silver-bullet}"; }

sb_smoke_write_rc_marker() {
  local host="$1" mode="$2" status="${3:-pass}" artifact="${4:-}" dir file
  dir="$(sb_smoke_rc_marker_dir)"; mkdir -p "$dir"; file="${dir}/${host}-${mode}"
  { printf 'host=%s\nmode=%s\nstatus=%s\n' "$host" "$mode" "$status"
    printf 'timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    [[ -n "$artifact" ]] && printf 'artifact=%s\n' "$artifact"; } >"$file"
  printf '%s\n' "$file"
}

sb_smoke_rc_markers_complete() {
  local host mode dir file
  dir="$(sb_smoke_rc_marker_dir)"
  for host in codex claude; do for mode in fresh upgrade; do
    file="${dir}/${host}-${mode}"
    [[ -f "$file" ]] && grep -qE '^status=(pass|skip)$' "$file" || return 1
  done; done
}
