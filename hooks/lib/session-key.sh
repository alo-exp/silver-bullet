# shellcheck shell=bash
# shellcheck disable=SC2034  # SB_SESSION_KEY is an output read by outcomes-gate.sh / instruction-ledger.sh
# Per-session key for the gate files that hold one prompt's checklist or ledger (R2-22).
#
#   sb_session_key_set PAYLOAD   SB_SESSION_KEY = the host's session_id when it is a safe file-name
#                                component ([A-Za-z0-9_-], 1-64 characters), else empty (the global file).
#
# Two sessions of one host share a state directory, so a second session's prompt used to overwrite
# the first session's checklist and ledger. With a key, outcomes-session-<key>.json and
# instruction-ledger-<key>.json are per session.
sb_session_key_set() {
  local sid
  SB_SESSION_KEY=""
  sid="$(printf '%s' "${1:-}" | jq -r '.session_id // ""' 2>/dev/null)" \
    || sid="$(printf '%s' "${1:-}" | grep -oE '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*:[[:space:]]*"([^"]*)"$/\1/')" \
    || sid=""
  if [[ "$sid" =~ ^[A-Za-z0-9_-]{1,64}$ ]]; then
    SB_SESSION_KEY="$sid"
  fi
  return 0
}
