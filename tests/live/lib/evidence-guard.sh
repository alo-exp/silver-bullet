#!/usr/bin/env bash
# Snapshot and restore of the release-evidence files in the operator's runtime state dir
# (R14-03, R14-06, R14-07).
#
# The live suites run real agent sessions whose SessionStart hook resets branch-scoped state:
# it removes release-live-matrix and e2e-live-matrix, and a scenario may rewrite
# quality-gate-state or verify-tests-state. Without a guard an operator who ran the release
# matrix and then a live suite would lose evidence they had earned, and a failed or aborted
# run could leave evidence it never earned. A runner snapshots every evidence file first, and
# its EXIT trap calls sb_evidence_restore: files the runner does not own come back exactly as
# they were, and files it owns are removed (the runner then writes them only on a full pass).
#
# Usage: sb_evidence_snapshot <state-dir>; sb_evidence_restore <owned-file>...; sb_evidence_discard

SB_EVIDENCE_FILES=(release-live-matrix e2e-live-matrix inline-e2e-matrix quality-gate-state verify-tests-state)
SB_EVIDENCE_DIR=""
SB_EVIDENCE_STATE_DIR=""

# Put back every evidence file of snapshot dir $1 that is ABSENT from the state dir; a file that exists
# now is never overwritten (another session may have earned newer evidence) and nothing is deleted.
_sb_evidence_put_back_missing() {
  local snap="$1" name
  for name in "${SB_EVIDENCE_FILES[@]}"; do
    if [[ -f "${snap}/${name}" && ! -e "${SB_EVIDENCE_STATE_DIR}/${name}" ]]; then
      mkdir -p "$SB_EVIDENCE_STATE_DIR"
      cp -p "${snap}/${name}" "${SB_EVIDENCE_STATE_DIR}/${name}"
    fi
  done
}

# A runner killed with SIGKILL leaves its snapshot (kept inside the state dir, with the runner's pid):
# the next start puts back what is still missing, then removes the dead runner's snapshot.
sb_evidence_recover() {
  local snap owner
  for snap in "${SB_EVIDENCE_STATE_DIR}"/.sb-evidence-snapshot.*; do
    [[ -d "$snap" && ! -L "$snap" ]] || continue
    owner="$(cat "${snap}/owner.pid" 2>/dev/null)"
    if [[ "$owner" =~ ^[0-9]+$ ]] && kill -0 "$owner" 2>/dev/null; then
      continue
    fi
    _sb_evidence_put_back_missing "$snap"
    rm -rf -- "$snap"
  done
}

sb_evidence_snapshot() {
  SB_EVIDENCE_STATE_DIR="$1"
  mkdir -p "$SB_EVIDENCE_STATE_DIR"
  sb_evidence_recover
  SB_EVIDENCE_DIR="$(mktemp -d "${SB_EVIDENCE_STATE_DIR}/.sb-evidence-snapshot.XXXXXX")"
  chmod 700 "$SB_EVIDENCE_DIR"
  printf '%s\n' "$$" >"${SB_EVIDENCE_DIR}/owner.pid"
  local name
  for name in "${SB_EVIDENCE_FILES[@]}"; do
    if [[ -f "${SB_EVIDENCE_STATE_DIR}/${name}" && ! -L "${SB_EVIDENCE_STATE_DIR}/${name}" ]]; then
      cp -p "${SB_EVIDENCE_STATE_DIR}/${name}" "${SB_EVIDENCE_DIR}/${name}"
    fi
  done
}

# sb_evidence_restore <owned-file>...: owned files are removed (the runner rewrites them only on a full
# pass); every other file is put back only when a live session's reset removed it. Evidence that exists
# now, earned by this run's session or a concurrent one, is left exactly as it is.
sb_evidence_restore() {
  [[ -n "$SB_EVIDENCE_DIR" ]] || return 0
  local name o
  for name in "$@"; do
    rm -f -- "${SB_EVIDENCE_STATE_DIR}/${name}"
  done
  for name in "${SB_EVIDENCE_FILES[@]}"; do
    for o in "$@"; do
      [[ "$o" == "$name" ]] && rm -f -- "${SB_EVIDENCE_DIR}/${name}"
    done
  done
  _sb_evidence_put_back_missing "$SB_EVIDENCE_DIR"
  return 0
}

sb_evidence_discard() {
  if [[ -n "$SB_EVIDENCE_DIR" ]]; then
    rm -rf -- "$SB_EVIDENCE_DIR"
  fi
  SB_EVIDENCE_DIR=""
}

# sb_evidence_write_marker <file> <matrix-value> <repo-root>: the release marker. The first line is
# the `matrix=` value the release gate reads; `commit=` (the repository HEAD the evidence was earned
# at) and `written_at=` let a gate or an operator reject evidence from another commit (R14-16).
sb_evidence_write_marker() {
  local file="$1" value="$2" root="$3" head
  head="$(git -C "$root" rev-parse HEAD 2>/dev/null || true)"
  mkdir -p "$(dirname "$file")"
  printf 'matrix=%s\ncommit=%s\nwritten_at=%s\n' "$value" "${head:-unknown}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$file"
}
