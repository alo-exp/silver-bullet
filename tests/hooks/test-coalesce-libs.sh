#!/usr/bin/env bash
# hooks/lib/ups-coalesce.sh and hooks/lib/stop-coalesce.sh.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
SD="${SB_RUNTIME_STATE_DIR:?}"
# shellcheck source=../../hooks/lib/ups-coalesce.sh
source "$TL_REPO_ROOT/hooks/lib/ups-coalesce.sh"
# shellcheck source=../../hooks/lib/stop-coalesce.sh
source "$TL_REPO_ROOT/hooks/lib/stop-coalesce.sh"
TURN="$(sb_ups_coalesce_turn_file)"
SEEN="$(sb_ups_coalesce_seen_file)"
assert_eq "turn file path" "$SD/ups-coalesce-turn" "$TURN"
assert_eq "seen file path" "$SD/ups-coalesce-seen" "$SEEN"

# ---- fingerprints -----------------------------------------------------------
fp="$(sb_ups_coalesce_fingerprint "hello")"
assert_eq "fingerprint is the sha256" "$(printf hello | sha256sum | awk '{print $1}')" "$fp"
NOSHASUM="$(tl_path_without shasum)"
assert_eq "sha256sum fallback agrees" "$fp" "$(PATH="$NOSHASUM" bash -c 'source "$1"; sb_ups_coalesce_fingerprint hello' _ "$TL_REPO_ROOT/hooks/lib/ups-coalesce.sh")"
NOSHA="$(tl_path_without shasum sha256sum)"
cksum_fp="$(PATH="$NOSHA" bash -c 'source "$1"; sb_ups_coalesce_fingerprint hello' _ "$TL_REPO_ROOT/hooks/lib/ups-coalesce.sh")"
assert_match "cksum fallback is numeric" '^[0-9]+$' "$cksum_fp"
assert_eq "cksum fallback is deterministic" "$cksum_fp" "$(PATH="$NOSHA" bash -c 'source "$1"; sb_ups_coalesce_fingerprint hello' _ "$TL_REPO_ROOT/hooks/lib/ups-coalesce.sh")"

# ---- reset / begin ----------------------------------------------------------
sb_ups_coalesce_reset
assert_match "reset stamps the turn" '^[0-9]+$' "$(cat "$TURN")"
assert_eq "reset empties the seen list" "0" "$(wc -c <"$SEEN" | tr -d ' ')"

printf 'fp-old\n' >"$SEEN"
sb_ups_coalesce_begin
assert_eq "begin inside the TTL keeps the seen list" "fp-old" "$(cat "$SEEN")"
rm -f "$SEEN"
sb_ups_coalesce_begin
assert_file_exists "begin inside the TTL recreates a missing seen list" "$SEEN"

printf '%s' "$(( $(date +%s) - 600 ))" >"$TURN"
printf 'fp-old\n' >"$SEEN"
sb_ups_coalesce_begin
assert_eq "stale turn: seen list cleared" "0" "$(wc -c <"$SEEN" | tr -d ' ')"
assert_match "stale turn: new stamp" '^[0-9]+$' "$(cat "$TURN")"
printf 'junk' >"$TURN"
printf 'fp-old\n' >"$SEEN"
sb_ups_coalesce_begin
assert_eq "non-numeric stamp: treated as a new turn" "0" "$(wc -c <"$SEEN" | tr -d ' ')"
printf '%s' "$(( $(date +%s) + 600 ))" >"$TURN"
printf 'fp-old\n' >"$SEEN"
sb_ups_coalesce_begin
assert_eq "future stamp: treated as a new turn" "0" "$(wc -c <"$SEEN" | tr -d ' ')"
rm -f "$TURN" "$SEEN"
sb_ups_coalesce_begin
assert_file_exists "no turn file: created" "$TURN"

# ---- claim ------------------------------------------------------------------
sb_ups_coalesce_reset
if sb_ups_coalesce_claim ""; then tl_fail "empty content is not claimed"; else tl_pass "empty content is not claimed"; fi
if sb_ups_coalesce_claim "alpha"; then tl_pass "first claim wins"; else tl_fail "first claim wins"; fi
if sb_ups_coalesce_claim "alpha"; then tl_fail "duplicate claim loses"; else tl_pass "duplicate claim loses"; fi
if sb_ups_coalesce_claim "beta"; then tl_pass "different content wins"; else tl_fail "different content wins"; fi
if (sb_ups_coalesce_fingerprint() { :; }; sb_ups_coalesce_claim "anything"); then tl_pass "unfingerprintable content is let through"; else tl_fail "unfingerprintable content is let through"; fi

# ---- emit -------------------------------------------------------------------
sb_ups_coalesce_reset
out="$(sb_ups_emit_additional_context "ctx text")"
assert_eq "first emit carries the context" "ctx text" "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")"
assert_eq "default event name" "UserPromptSubmit" "$(jq -r .hookSpecificOutput.hookEventName <<<"$out")"
out="$(sb_ups_emit_additional_context "ctx text")"
assert_eq "duplicate emit has no context" "null" "$(jq -r .hookSpecificOutput.additionalContext <<<"$out")"
assert_eq "duplicate emit keeps the event name" "UserPromptSubmit" "$(jq -r .hookSpecificOutput.hookEventName <<<"$out")"
out="$(sb_ups_emit_additional_context "other" "CustomEvent")"
assert_eq "custom event name" "CustomEvent" "$(jq -r .hookSpecificOutput.hookEventName <<<"$out")"

# ---- stop coalesce ----------------------------------------------------------
F="$(sb_stop_coalesce_file)"
assert_eq "stop file path" "$SD/stop-coalesce-block" "$F"
sb_stop_coalesce_reset
if sb_stop_coalesce_suppress_secondary_block; then tl_fail "nothing recorded: no suppression"; else tl_pass "nothing recorded: no suppression"; fi
sb_stop_coalesce_record ""
assert_file_absent "empty reason is not recorded" "$F"
sb_stop_coalesce_record "first reason"
assert_eq "reason recorded" "first reason" "$(cat "$F")"
sb_stop_coalesce_record "second reason"
assert_eq "first reason wins" "first reason" "$(cat "$F")"
if sb_stop_coalesce_suppress_secondary_block; then tl_pass "secondary blocks suppressed"; else tl_fail "secondary blocks suppressed"; fi
sb_stop_coalesce_reset
assert_file_absent "reset clears the record" "$F"
assert_eq "default dir without a state dir" "/tmp/stop-coalesce-block" "$(env -u SB_RUNTIME_STATE_DIR bash -c 'source "$1"; sb_stop_coalesce_file' _ "$TL_REPO_ROOT/hooks/lib/stop-coalesce.sh")"

tl_results
