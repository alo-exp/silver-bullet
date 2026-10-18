# shellcheck shell=bash
# UserPromptSubmit additionalContext coalesce — fingerprint dedupe per turn (#262).
#
# Usage:
#   sb_ups_coalesce_reset                 # first UPS hook in the chain
#   sb_ups_coalesce_begin                 # emitters: continue turn or start if stale
#   if sb_ups_coalesce_claim "$content"; then emit; else noop; fi
#   # Or: sb_ups_emit_additional_context "$content" ["UserPromptSubmit"]

_sb_ups_coalesce_turn_ttl_seconds=5

sb_ups_coalesce_turn_file() {
  printf '%s/ups-coalesce-turn' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_ups_coalesce_seen_file() {
  printf '%s/ups-coalesce-seen' "${SB_RUNTIME_STATE_DIR:-/tmp}"
}

sb_ups_coalesce_fingerprint() {
  local content="${1:-}"
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$content" | shasum -a 256 2>/dev/null | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$content" | sha256sum 2>/dev/null | awk '{print $1}'
  else
    printf '%s' "$content" | cksum 2>/dev/null | awk '{print $1}'
  fi
}

# Hard reset — call from the first UPS hook in the chain (record-requested-skill).
sb_ups_coalesce_reset() {
  local state seen
  state="$(sb_ups_coalesce_turn_file)"
  seen="$(sb_ups_coalesce_seen_file)"
  mkdir -p "$(dirname "$state")" 2>/dev/null || true
  umask 0077
  date +%s >"$state" 2>/dev/null || true
  : >"$seen" 2>/dev/null || true
}

# Begin or continue a UPS turn. Resets when no turn is active or the prior turn is stale.
sb_ups_coalesce_begin() {
  local now prev age state seen
  now="$(date +%s)"
  state="$(sb_ups_coalesce_turn_file)"
  seen="$(sb_ups_coalesce_seen_file)"
  mkdir -p "$(dirname "$state")" 2>/dev/null || true
  umask 0077
  if [[ -f "$state" ]]; then
    prev="$(cat "$state" 2>/dev/null || true)"
    if [[ "$prev" =~ ^[0-9]+$ ]]; then
      age=$((now - prev))
      if [[ "$age" -ge 0 && "$age" -le "${_sb_ups_coalesce_turn_ttl_seconds}" ]]; then
        [[ -f "$seen" ]] || : >"$seen" 2>/dev/null || true
        return 0
      fi
    fi
  fi
  printf '%s' "$now" >"$state" 2>/dev/null || true
  : >"$seen" 2>/dev/null || true
}

# Returns 0 if this content is new for the turn (caller should emit); 1 if duplicate.
sb_ups_coalesce_claim() {
  local content="${1:-}"
  local fp seen
  [[ -n "$content" ]] || return 1
  fp="$(sb_ups_coalesce_fingerprint "$content")"
  [[ -n "$fp" ]] || return 0
  seen="$(sb_ups_coalesce_seen_file)"
  mkdir -p "$(dirname "$seen")" 2>/dev/null || true
  umask 0077
  if [[ -f "$seen" ]] && grep -qxF "$fp" "$seen" 2>/dev/null; then
    return 1
  fi
  printf '%s\n' "$fp" >>"$seen" 2>/dev/null || true
  return 0
}

# Emit UPS additionalContext only once per identical payload in the turn.
sb_ups_emit_additional_context() {
  local content="${1:-}"
  local event_name="${2:-UserPromptSubmit}"
  local ctx
  sb_ups_coalesce_begin
  if ! sb_ups_coalesce_claim "$content"; then
    printf '{"hookSpecificOutput":{"hookEventName":%s}}' "$(printf '%s' "$event_name" | jq -Rs '.')"
    return 0
  fi
  ctx="$(printf '%s' "$content" | jq -Rs '.')"
  printf '{"hookSpecificOutput":{"hookEventName":%s,"additionalContext":%s}}' \
    "$(printf '%s' "$event_name" | jq -Rs '.')" "$ctx"
}
