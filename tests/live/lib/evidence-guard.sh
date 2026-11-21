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

sb_evidence_snapshot() {
  SB_EVIDENCE_STATE_DIR="$1"
  SB_EVIDENCE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sb-live-evidence.XXXXXX")"
  chmod 700 "$SB_EVIDENCE_DIR"
  local name
  for name in "${SB_EVIDENCE_FILES[@]}"; do
    if [[ -f "${SB_EVIDENCE_STATE_DIR}/${name}" && ! -L "${SB_EVIDENCE_STATE_DIR}/${name}" ]]; then
      cp -p "${SB_EVIDENCE_STATE_DIR}/${name}" "${SB_EVIDENCE_DIR}/${name}"
    fi
  done
}

sb_evidence_restore() {
  [[ -n "$SB_EVIDENCE_DIR" ]] || return 0
  local name o is_owned
  for name in "${SB_EVIDENCE_FILES[@]}"; do
    is_owned=false
    for o in "$@"; do
      [[ "$o" == "$name" ]] && is_owned=true
    done
    rm -f -- "${SB_EVIDENCE_STATE_DIR}/${name}"
    if [[ "$is_owned" == false && -f "${SB_EVIDENCE_DIR}/${name}" ]]; then
      mkdir -p "$SB_EVIDENCE_STATE_DIR"
      cp -p "${SB_EVIDENCE_DIR}/${name}" "${SB_EVIDENCE_STATE_DIR}/${name}"
    fi
  done
  return 0
}

sb_evidence_discard() {
  if [[ -n "$SB_EVIDENCE_DIR" ]]; then
    rm -rf -- "$SB_EVIDENCE_DIR"
  fi
  SB_EVIDENCE_DIR=""
}
