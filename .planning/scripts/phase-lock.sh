#!/usr/bin/env bash
# Silver Bullet — phase-ownership lock primitive (LOCK-01..LOCK-04).
# Shared by all SB-bearing runtimes (claude, forge, codex, opencode).
# Atomic via flock(1) on a sidecar lockfile.
#
# CLI:
#   phase-lock.sh claim     <phase> <runtime> <intent>
#   phase-lock.sh heartbeat <phase> <runtime>
#   phase-lock.sh release   <phase> <runtime>
#   phase-lock.sh peek      <phase>
#
# Env:
#   SB_PHASE_LOCK_FILE        — override lock file path (testability)
#   SB_PHASE_LOCK_INHERITED   — when "true", claim/heartbeat/release are no-ops
#   SB_DEFAULT_CONFIG         — override config template lookup (testability)
#
# Exit codes:
#   claim:     0 acquired/stolen-stale, 2 conflict, 3 unknown runtime, 4 usage, 1 unexpected
#   heartbeat: 0 updated, 2 not owned, 4 usage, 1 unexpected
#   release:   0 released or no-op, 2 owned by another, 4 usage, 1 unexpected
#   peek:      0 always; stdout empty=free, JSON=held, JSON+expired=stale
#
# This is NOT a hook — fail-fast on missing jq/flock; do NOT fail-open.

set -euo pipefail

# ---------------------------------------------------------------------------
# Early --help / -h dispatch (works without git/jq/flock)
# ---------------------------------------------------------------------------

case "${1:-}" in
  ""|-h|--help)
    cat <<'EOF'
Usage: phase-lock.sh <op> <phase> [args...]
  claim     <phase> <runtime> <intent>   Acquire phase lock (steals stale)
  heartbeat <phase> <runtime>            Refresh heartbeat (must own)
  release   <phase> <runtime>            Release phase lock (must own)
  peek      <phase>                      Print lock JSON or empty

Env:
  SB_PHASE_LOCK_FILE        Override lock file path (default: .planning/.phase-locks.json)
  SB_PHASE_LOCK_INHERITED   When "true", claim/heartbeat/release are no-ops
  SB_DEFAULT_CONFIG         Override config template lookup
EOF
    exit 0
    ;;
esac

# ---------------------------------------------------------------------------
# Preconditions
# ---------------------------------------------------------------------------

command -v jq >/dev/null 2>&1 || { echo "ERR: jq is required for phase-lock.sh" >&2; exit 1; }

# flock(1) is preferred (Linux); macOS usually lacks it. Fall back to a portable
# atomic-mkdir spin loop. Both paths provide exclusive mutex for the lock-file
# read-modify-write cycle.
_PL_HAVE_FLOCK=0
if command -v flock >/dev/null 2>&1; then
  _PL_HAVE_FLOCK=1
fi

# ---------------------------------------------------------------------------
# Resolve repo root and lock paths
# ---------------------------------------------------------------------------

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${REPO_ROOT}" ]]; then
  # Allow operation outside git when SB_PHASE_LOCK_FILE is fully specified
  if [[ -z "${SB_PHASE_LOCK_FILE:-}" ]]; then
    echo "ERR: phase-lock must be run inside a git repository (or set SB_PHASE_LOCK_FILE)" >&2
    exit 1
  fi
fi

LOCK_FILE="${SB_PHASE_LOCK_FILE:-${REPO_ROOT}/.planning/.phase-locks.json}"
LOCK_SIDECAR="${LOCK_FILE}.lock"
PLANNING_DIR="$(dirname "$LOCK_FILE")"

if [[ ! -d "$PLANNING_DIR" ]]; then
  echo "ERR: planning directory not found: $PLANNING_DIR — run /silver:init first" >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Config resolution (mirrors hooks/lib/required-skills.sh)
# ---------------------------------------------------------------------------

_pl_find_default_config() {
  if [[ -n "${SB_DEFAULT_CONFIG:-}" ]] && [[ -f "${SB_DEFAULT_CONFIG}" ]]; then
    printf '%s' "${SB_DEFAULT_CONFIG}"
    return 0
  fi
  if [[ -n "${REPO_ROOT}" ]] && [[ -f "${REPO_ROOT}/templates/silver-bullet.config.json.default" ]]; then
    printf '%s' "${REPO_ROOT}/templates/silver-bullet.config.json.default"
    return 0
  fi
  local self_dir
  self_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
  local candidate="${self_dir}/../../templates/silver-bullet.config.json.default"
  if [[ -f "${candidate}" ]]; then
    printf '%s' "${candidate}"
    return 0
  fi
  return 1
}

_pl_find_project_config() {
  if [[ -n "${REPO_ROOT}" ]] && [[ -f "${REPO_ROOT}/.silver-bullet.json" ]]; then
    printf '%s' "${REPO_ROOT}/.silver-bullet.json"
    return 0
  fi
  return 1
}

# Read .multi_agent.identity_tags (space-separated) — project override > template default > hard fallback
_pl_config_get_tags() {
  local out=""
  local proj
  if proj="$(_pl_find_project_config)"; then
    out="$(jq -r '.multi_agent.identity_tags // [] | .[]' "$proj" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
  fi
  if [[ -z "$out" ]]; then
    local def
    if def="$(_pl_find_default_config)"; then
      out="$(jq -r '.multi_agent.identity_tags // [] | .[]' "$def" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
    fi
  fi
  if [[ -z "$out" ]]; then
    out="claude forge codex opencode"
  fi
  printf '%s' "$out"
}

# Read .multi_agent.stale_lock_ttl_seconds — project override > template default > 1800
_pl_config_get_ttl() {
  local out=""
  local proj
  if proj="$(_pl_find_project_config)"; then
    out="$(jq -r '.multi_agent.stale_lock_ttl_seconds // empty' "$proj" 2>/dev/null)"
  fi
  if [[ -z "$out" || "$out" == "null" ]]; then
    local def
    if def="$(_pl_find_default_config)"; then
      out="$(jq -r '.multi_agent.stale_lock_ttl_seconds // empty' "$def" 2>/dev/null)"
    fi
  fi
  if [[ -z "$out" || "$out" == "null" ]]; then
    out="1800"
  fi
  printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# Time + identity helpers
# ---------------------------------------------------------------------------

_pl_now_iso() { date -u +%Y-%m-%dT%H:%M:%SZ; }
_pl_now_epoch() { date -u +%s; }

# Convert ISO 8601 UTC string to epoch seconds (GNU date first, BSD fallback)
_pl_iso_to_epoch() {
  local iso="$1"
  date -u -d "$iso" +%s 2>/dev/null \
    || date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$iso" +%s 2>/dev/null \
    || echo 0
}

# Normalize phase: zero-pad to 3 digits if purely numeric; otherwise leave as-is.
# Strip leading zeros before printf to avoid octal interpretation (e.g. "070" → 56).
_pl_normalize_phase() {
  local p="$1"
  if [[ "$p" =~ ^[0-9]+$ ]]; then
    # Force base-10 to avoid octal: strip leading zeros, default to 0 if empty.
    local stripped="${p#"${p%%[!0]*}"}"
    [[ -z "$stripped" ]] && stripped=0
    printf '%03d' "$stripped"
  else
    printf '%s' "$p"
  fi
}

_pl_owner_id() {
  local runtime="$1"
  local host
  host="$(hostname -s 2>/dev/null || hostname)"
  printf '%s-%s-%s' "$runtime" "$host" "$$"
}

_pl_validate_runtime() {
  local runtime="$1"
  local tags
  tags="$(_pl_config_get_tags)"
  local t
  for t in $tags; do
    if [[ "$t" == "$runtime" ]]; then
      return 0
    fi
  done
  echo "ERR: unknown runtime tag '$runtime' — allowed: $tags" >&2
  return 3
}

# ---------------------------------------------------------------------------
# JSON read/write
# ---------------------------------------------------------------------------

_pl_read_json() {
  if [[ ! -f "$LOCK_FILE" ]]; then
    printf '{}'
    return 0
  fi
  if ! jq empty "$LOCK_FILE" >/dev/null 2>&1; then
    echo "ERR: corrupt lock file at $LOCK_FILE" >&2
    return 1
  fi
  cat "$LOCK_FILE"
}

_pl_write_json() {
  local payload="$1"
  local tmp="${LOCK_FILE}.tmp.$$"
  printf '%s\n' "$payload" > "$tmp"
  mv "$tmp" "$LOCK_FILE"
}

# ---------------------------------------------------------------------------
# Mutex wrapper — flock(1) when available, atomic-mkdir spin loop fallback
# ---------------------------------------------------------------------------

# Spin-loop fallback uses LOCK_SIDECAR.d as an atomically-created mutex dir.
# Atomic mkdir is POSIX-guaranteed exclusive — only one mkdir succeeds when
# multiple processes race. Stale lockdir cleanup uses a 60s safety timeout.
_PL_LOCKDIR=""
_PL_RELEASE_LOCKDIR_ON_EXIT=0

_pl_acquire_mkdir_lock() {
  local lockdir="${LOCK_SIDECAR}.d"
  local i
  for (( i=0; i<6000; i++ )); do
    if mkdir "$lockdir" 2>/dev/null; then
      _PL_LOCKDIR="$lockdir"
      _PL_RELEASE_LOCKDIR_ON_EXIT=1
      # Record pid for stale detection (best-effort, not relied on for correctness)
      printf '%s\n' "$$" > "$lockdir/pid" 2>/dev/null || true
      return 0
    fi
    # Stale detection: if lockdir is older than 60s, force-clear it.
    if [[ -d "$lockdir" ]]; then
      local age_ok=0
      # mtime check (portable) — try GNU then BSD
      local mtime now
      mtime=$(stat -c %Y "$lockdir" 2>/dev/null || stat -f %m "$lockdir" 2>/dev/null || echo 0)
      now=$(date -u +%s)
      if (( mtime > 0 )) && (( now - mtime > 60 )); then
        rm -rf "$lockdir" 2>/dev/null || true
        age_ok=1
      fi
      [[ $age_ok -eq 1 ]] && continue
    fi
    # Sleep ~10ms between attempts (use perl/python if available, else simple sleep)
    sleep 0.01 2>/dev/null || sleep 1
  done
  echo "ERR: could not acquire mkdir lock at $lockdir after 60s" >&2
  return 1
}

_pl_release_mkdir_lock() {
  if [[ $_PL_RELEASE_LOCKDIR_ON_EXIT -eq 1 ]] && [[ -n "$_PL_LOCKDIR" ]]; then
    rm -rf "$_PL_LOCKDIR" 2>/dev/null || true
    _PL_RELEASE_LOCKDIR_ON_EXIT=0
    _PL_LOCKDIR=""
  fi
}

_pl_with_flock() {
  : > "$LOCK_SIDECAR" 2>/dev/null || true
  if [[ ! -f "$LOCK_SIDECAR" ]]; then
    echo "ERR: cannot create flock sidecar at $LOCK_SIDECAR" >&2
    return 1
  fi
  if [[ $_PL_HAVE_FLOCK -eq 1 ]]; then
    exec 9>"$LOCK_SIDECAR"
    flock -x 9
    set +e
    "$@"
    local rc=$?
    set -e
    exec 9>&-
    return $rc
  else
    _pl_acquire_mkdir_lock || return 1
    trap '_pl_release_mkdir_lock' EXIT INT TERM
    set +e
    "$@"
    local rc=$?
    set -e
    _pl_release_mkdir_lock
    trap - EXIT INT TERM
    return $rc
  fi
}

# ---------------------------------------------------------------------------
# Operations
# ---------------------------------------------------------------------------

cmd_claim() {
  local phase="$1" runtime="$2" intent="$3"
  local current
  current="$(_pl_read_json | jq --arg p "$phase" '.[$p] // empty')"

  local self_owner_id
  self_owner_id="$(_pl_owner_id "$runtime")"

  if [[ -z "$current" ]]; then
    : # no current lock; fall through to write
  else
    # Existing entry — check staleness
    local last_hb prior_owner prior_runtime prior_intent
    last_hb=$(printf '%s' "$current" | jq -r '.last_heartbeat_at // empty')
    prior_owner=$(printf '%s' "$current" | jq -r '.owner_id // empty')
    prior_runtime=$(printf '%s' "$current" | jq -r '.agent_runtime // empty')
    prior_intent=$(printf '%s' "$current" | jq -r '.intent // empty')

    local now_e hb_e ttl age
    now_e=$(_pl_now_epoch)
    hb_e=$(_pl_iso_to_epoch "$last_hb")
    ttl=$(_pl_config_get_ttl)
    age=$((now_e - hb_e))

    if (( age > ttl )); then
      echo "WARN: stealing stale lock from ${prior_owner} (heartbeat ${age}s ago, ttl ${ttl}s)" >&2
      # fall through to overwrite
    else
      # Same-process re-claim is idempotent (refresh heartbeat).
      if [[ "$prior_owner" == "$self_owner_id" ]]; then
        :  # we already own it; refresh heartbeat below
      else
        echo "ERR: phase $phase is locked by ${prior_owner} (runtime=${prior_runtime}, intent=${prior_intent})" >&2
        return 2
      fi
    fi
  fi

  local new_entry updated
  new_entry=$(jq -n \
    --arg owner_id "$self_owner_id" \
    --arg runtime "$runtime" \
    --arg ts "$(_pl_now_iso)" \
    --arg host "$(hostname -s 2>/dev/null || hostname)" \
    --argjson pid "$$" \
    --arg intent "$intent" \
    '{owner_id:$owner_id, agent_runtime:$runtime, claimed_at:$ts, last_heartbeat_at:$ts, host:$host, pid:$pid, intent:$intent}')
  updated=$(_pl_read_json | jq --arg p "$phase" --argjson v "$new_entry" '.[$p] = $v')
  _pl_write_json "$updated"
  return 0
}

# Ownership match for heartbeat/release: same runtime AND same host.
# (PID is recorded for diagnostics but not required to match — separate CLI
# invocations on the same host with the same agent runtime are treated as the
# same logical owner. Cross-runtime or cross-host attempts are rejected.)
_pl_owns_lock() {
  local lock_json="$1" runtime="$2"
  local lock_runtime lock_host self_host
  lock_runtime=$(printf '%s' "$lock_json" | jq -r '.agent_runtime // empty')
  lock_host=$(printf '%s' "$lock_json" | jq -r '.host // empty')
  self_host="$(hostname -s 2>/dev/null || hostname)"
  [[ "$lock_runtime" == "$runtime" && "$lock_host" == "$self_host" ]]
}

cmd_heartbeat() {
  local phase="$1" runtime="$2"
  local current
  current="$(_pl_read_json | jq --arg p "$phase" '.[$p] // empty')"
  if [[ -z "$current" ]]; then
    echo "ERR: cannot heartbeat — phase $phase has no active lock" >&2
    return 2
  fi
  if ! _pl_owns_lock "$current" "$runtime"; then
    local prior_owner
    prior_owner=$(printf '%s' "$current" | jq -r '.owner_id // empty')
    echo "ERR: cannot heartbeat — phase $phase not owned by runtime '$runtime' on this host (owned by ${prior_owner})" >&2
    return 2
  fi
  local updated
  updated=$(_pl_read_json | jq --arg p "$phase" --arg ts "$(_pl_now_iso)" '.[$p].last_heartbeat_at = $ts')
  _pl_write_json "$updated"
  return 0
}

cmd_release() {
  local phase="$1" runtime="$2"
  local current
  current="$(_pl_read_json | jq --arg p "$phase" '.[$p] // empty')"
  if [[ -z "$current" ]]; then
    return 0  # no-op
  fi
  if ! _pl_owns_lock "$current" "$runtime"; then
    local prior_owner
    prior_owner=$(printf '%s' "$current" | jq -r '.owner_id // empty')
    echo "ERR: cannot release — phase $phase owned by ${prior_owner}" >&2
    return 2
  fi
  local updated
  updated=$(_pl_read_json | jq --arg p "$phase" 'del(.[$p])')
  _pl_write_json "$updated"
  return 0
}

cmd_peek() {
  local phase="$1"
  local current
  current="$(_pl_read_json | jq --arg p "$phase" '.[$p] // empty')"
  if [[ -z "$current" ]]; then
    return 0
  fi
  local last_hb now_e hb_e ttl age
  last_hb=$(printf '%s' "$current" | jq -r '.last_heartbeat_at // empty')
  now_e=$(_pl_now_epoch)
  hb_e=$(_pl_iso_to_epoch "$last_hb")
  ttl=$(_pl_config_get_ttl)
  age=$((now_e - hb_e))
  if (( age > ttl )); then
    printf '%s' "$current" | jq -c '. + {expired: true}'
  else
    printf '%s' "$current" | jq -c '.'
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Inheritance no-op short-circuit (for claim/heartbeat/release; peek excluded)
# ---------------------------------------------------------------------------

_pl_inheritance_check() {
  local op="$1"
  if [[ "${SB_PHASE_LOCK_INHERITED:-}" == "true" ]]; then
    echo "INFO: phase-lock $op skipped — SB_PHASE_LOCK_INHERITED=true" >&2
    exit 0
  fi
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

OP="${1:-}"
shift || true

case "$OP" in
  claim)
    [[ $# -eq 3 ]] || { echo "Usage: phase-lock.sh claim <phase> <runtime> <intent>" >&2; exit 4; }
    _pl_inheritance_check claim
    phase=$(_pl_normalize_phase "$1")
    _pl_validate_runtime "$2" || exit 3
    _pl_with_flock cmd_claim "$phase" "$2" "$3"
    ;;
  heartbeat)
    [[ $# -eq 2 ]] || { echo "Usage: phase-lock.sh heartbeat <phase> <runtime>" >&2; exit 4; }
    _pl_inheritance_check heartbeat
    phase=$(_pl_normalize_phase "$1")
    _pl_with_flock cmd_heartbeat "$phase" "$2"
    ;;
  release)
    [[ $# -eq 2 ]] || { echo "Usage: phase-lock.sh release <phase> <runtime>" >&2; exit 4; }
    _pl_inheritance_check release
    phase=$(_pl_normalize_phase "$1")
    _pl_with_flock cmd_release "$phase" "$2"
    ;;
  peek)
    [[ $# -eq 1 ]] || { echo "Usage: phase-lock.sh peek <phase>" >&2; exit 4; }
    phase=$(_pl_normalize_phase "$1")
    cmd_peek "$phase"
    ;;
  ""|-h|--help)
    cat <<'EOF'
Usage: phase-lock.sh <op> <phase> [args...]
  claim     <phase> <runtime> <intent>   Acquire phase lock (steals stale)
  heartbeat <phase> <runtime>            Refresh heartbeat (must own)
  release   <phase> <runtime>            Release phase lock (must own)
  peek      <phase>                      Print lock JSON or empty

Env:
  SB_PHASE_LOCK_FILE        Override lock file path (default: .planning/.phase-locks.json)
  SB_PHASE_LOCK_INHERITED   When "true", claim/heartbeat/release are no-ops
  SB_DEFAULT_CONFIG         Override config template lookup
EOF
    exit 0
    ;;
  *)
    echo "ERR: unknown op '$OP'" >&2
    exit 4
    ;;
esac
