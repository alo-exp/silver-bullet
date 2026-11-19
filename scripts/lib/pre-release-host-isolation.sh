# shellcheck shell=bash
# Pre-release host smoke isolation — shared helpers.
#
# Policy: never read or write the operator's regular host runtime homes
# (~/.claude, ~/.codex, ~/.cursor). Each smoke host gets a dedicated temp root
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
# Cursor CLI isolation (official mechanisms only):
#   - Fake HOME blocks global hooks/MCP/rules merge from operator profile
#   - CURSOR_CONFIG_DIR → isolated cli-config.json (permissions, approval mode)
#   - --plugin-dir loads plugin from repo disk (no install to ~/.cursor/plugins/)
#   - --workspace targets a throwaway checkout under the smoke root
# Do NOT use CURSOR_DATA_DIR, --config, or undocumented full ~/.cursor redirects.
#
# Cursor CLI auth: env-only CURSOR_API_KEY + AGENT_CLI_CREDENTIAL_STORE=memory.
# Never call cursor-agent login/status or macOS Keychain (cursor-user).

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
  unset KAY_HOME CLAUDE_CONFIG_DIR CODEX_HOME CURSOR_CONFIG_DIR \
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

sb_smoke_cursor_plugin_dir() {
  local repo="${SB_PRE_RELEASE_REPO_ROOT:-}"
  if [[ -z "$repo" || ! -d "${repo}/plugins/silver-bullet" ]]; then
    return 1
  fi
  printf '%s\n' "${repo}/plugins/silver-bullet"
}

sb_smoke_cursor_workspace() {
  local root
  root="$(sb_smoke_host_root cursor)" || return 1
  printf '%s\n' "${root}/workspace"
}

sb_smoke_cursor_config_dir() {
  local root
  root="$(sb_smoke_host_root cursor)" || return 1
  printf '%s\n' "${root}/fake-home/.cursor"
}

sb_smoke_cursor_write_cli_config() {
  local config_dir="$1"
  mkdir -p "$config_dir"
  cat >"${config_dir}/cli-config.json" <<'EOF'
{
  "version": 1,
  "permissions": {
    "allow": [
      "Shell(bash *)",
      "Shell(echo *)",
      "Shell(pwd)",
      "Shell(test *)"
    ]
  }
}
EOF
}

# Cursor pre-release isolation: fake HOME + CURSOR_CONFIG_DIR (official).
# install-cursor.sh still resolves ~/.cursor as ${HOME}/.cursor inside fake HOME.
sb_smoke_begin_cursor() {
  local root fake_home workspace config_dir plugin_dir
  root="$(sb_smoke_host_root cursor)" || return 1
  sb_smoke_track_root "$root"
  sb_smoke_clear_host_env

  fake_home="${root}/fake-home"
  workspace="${root}/workspace"
  config_dir="${fake_home}/.cursor"
  mkdir -p "$fake_home/.cursor" "$workspace"

  printf '%s\n' '{"version":1,"hooks":{}}' >"${config_dir}/hooks.json"
  printf '%s\n' '{"mcpServers":{}}' >"${config_dir}/mcp.json"
  sb_smoke_cursor_write_cli_config "$config_dir"

  export HOME="$fake_home"
  export CURSOR_CONFIG_DIR="$config_dir"
  unset CURSOR_HOME 2>/dev/null || true
  export SILVER_BULLET_RUNTIME=cursor
  export SB_RUNTIME_PRESERVE_STATE_DIR=1
  export SB_RUNTIME_STATE_DIR="${root}/.silver-bullet"

  plugin_dir="$(sb_smoke_cursor_plugin_dir)" || plugin_dir=""
  export SB_SMOKE_CURSOR_WORKSPACE="$workspace"
  export SB_SMOKE_CURSOR_PLUGIN_DIR="$plugin_dir"
  export SB_SMOKE_CURSOR_FAKE_HOME="$fake_home"

  if [[ -f "${SB_PRE_RELEASE_REPO_ROOT:-}/hooks/lib/runtime-paths.sh" ]]; then
    # shellcheck source=hooks/lib/runtime-paths.sh
    source "${SB_PRE_RELEASE_REPO_ROOT}/hooks/lib/runtime-paths.sh"
  fi
}

# Cursor CLI credential store: in-memory only — never Keychain / cursor-user.
# Auth resolution order: CURSOR_API_KEY → HOST_API_KEY (doc alias) → smoke-root
# file → operator file ~/.silver-bullet/cursor-api-key (gitignored, local only).
sb_smoke_cursor_cli_auth_env() {
  export AGENT_CLI_CREDENTIAL_STORE=memory

  if [[ -n "${CURSOR_API_KEY:-}" ]]; then
    return 0
  fi

  if [[ -n "${HOST_API_KEY:-}" ]]; then
    CURSOR_API_KEY="$HOST_API_KEY"
    export CURSOR_API_KEY
    return 0
  fi

  local key_file
  for key_file in \
    "${SB_PRE_RELEASE_SMOKE_ROOT:+${SB_PRE_RELEASE_SMOKE_ROOT}/.cursor-api-key}" \
    "${HOME}/.silver-bullet/cursor-api-key"; do
    if [[ -f "$key_file" ]]; then
      CURSOR_API_KEY="$(<"$key_file")"
      export CURSOR_API_KEY
      return 0
    fi
  done

  return 1
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

# sb_smoke_write_rc_marker HOST MODE [STATUS] [ARTIFACT]: record one RC cell. STATUS is pass|fail|skip|dry-run.
# The marker carries the commit it was written at (and the package version), so the release gate can
# tell a marker from this release from an old one (R13-09, R8-13).
sb_smoke_write_rc_marker() {
  local host="$1" mode="$2" status="${3:-pass}" artifact="${4:-}" dir file root
  root="${SB_PRE_RELEASE_REPO_ROOT:-$PWD}"
  dir="$(sb_smoke_rc_marker_dir)"; mkdir -p "$dir"; file="${dir}/${host}-${mode}"
  { printf 'host=%s\nmode=%s\nstatus=%s\n' "$host" "$mode" "$status"
    printf 'timestamp=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'commit=%s\n' "$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
    printf 'version=%s\n' "$(jq -r '.version // empty' "$root/package.json" 2>/dev/null || true)"
    [[ -n "$artifact" ]] && printf 'artifact=%s\n' "$artifact"; } >"$file"
  printf '%s\n' "$file"
}

# sb_smoke_rc_markers_complete: every host x mode cell has a live pass for the commit being released
# (SB_RC_RELEASE_COMMIT, else HEAD of the working directory). A dry-run, a skipped cell (no host CLI, CI
# mode) or a marker written at another commit does not count. A human can accept skips for one commit by
# writing `commit=<sha>` into `rc-validation/skip-waiver` in the state directory.
sb_smoke_rc_markers_complete() {
  local host mode dir file head waiver=false
  dir="$(sb_smoke_rc_marker_dir)"
  head="${SB_RC_RELEASE_COMMIT:-$(git rev-parse HEAD 2>/dev/null || true)}"
  [[ -n "$head" ]] || return 1
  [[ -f "$dir/skip-waiver" && ! -L "$dir/skip-waiver" ]] && grep -qxF "commit=${head}" "$dir/skip-waiver" && waiver=true
  for host in cursor codex claude; do for mode in fresh upgrade; do
    file="${dir}/${host}-${mode}"
    [[ -f "$file" && ! -L "$file" ]] || return 1
    grep -qxF "commit=${head}" "$file" || return 1
    if grep -qxF 'status=pass' "$file"; then
      continue
    fi
    [[ "$waiver" == true ]] && grep -qxF 'status=skip' "$file" || return 1
  done; done
}
