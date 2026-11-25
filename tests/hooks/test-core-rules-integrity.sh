#!/usr/bin/env bash
# hooks/lib/core-rules-integrity.sh: pin verification and the SessionStart digest.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
# shellcheck source=../../hooks/lib/core-rules-integrity.sh
source "$TL_REPO_ROOT/hooks/lib/core-rules-integrity.sh"

D="$TL_TMP/hooks"
mkdir -p "$D"
RULES="$D/core-rules.md"
cat >"$RULES" <<'EOF'
# Rules

## Non-Negotiable Rules (Section 3)

You MUST NOT skip things.

## Enforcement Model

Layers.
EOF

# pin file
if sb_core_rules_pin_file "" >/dev/null; then tl_fail "pin file needs a dir"; else tl_pass "pin file needs a dir"; fi
assert_eq "pin file path" "$D/core-rules.sha256" "$(sb_core_rules_pin_file "$D")"

# hashing
if sb_core_rules_compute_hash "$D/missing.md" >/dev/null; then tl_fail "hash of a missing file fails"; else tl_pass "hash of a missing file fails"; fi
EXPECT="$(sha256sum "$RULES" | awk '{print $1}')"
assert_eq "hash via shasum or sha256sum" "$EXPECT" "$(sb_core_rules_compute_hash "$RULES")"
NOSHA="$(tl_path_without shasum)"
assert_eq "hash via sha256sum when shasum is missing" "$EXPECT" "$(PATH="$NOSHA" sb_core_rules_compute_hash "$RULES")"
NOBOTH="$(tl_path_without shasum sha256sum)"
if PATH="$NOBOTH" sb_core_rules_compute_hash "$RULES" >/dev/null; then tl_fail "no hashing tool fails"; else tl_pass "no hashing tool fails"; fi

# expected hash and integrity
if sb_core_rules_expected_hash "$D" >/dev/null; then tl_fail "no pin file: no expected hash"; else tl_pass "no pin file: no expected hash"; fi
if sb_core_rules_integrity_ok "$RULES" "$D"; then tl_fail "no pin: not ok"; else tl_pass "no pin: not ok"; fi
printf '  %s  \n' "$EXPECT" >"$D/core-rules.sha256"
assert_eq "expected hash is whitespace-trimmed" "$EXPECT" "$(sb_core_rules_expected_hash "$D")"
if sb_core_rules_integrity_ok "$RULES" "$D"; then tl_pass "matching pin: ok"; else tl_fail "matching pin: ok"; fi
if sb_core_rules_integrity_ok "$D/missing.md" "$D"; then tl_fail "missing rules file: not ok"; else tl_pass "missing rules file: not ok"; fi
if sb_core_rules_integrity_ok "$RULES" ""; then tl_fail "no hooks dir: not ok"; else tl_pass "no hooks dir: not ok"; fi
: >"$D/core-rules.sha256"
if sb_core_rules_integrity_ok "$RULES" "$D"; then tl_fail "empty pin: not ok"; else tl_pass "empty pin: not ok"; fi
printf '%s\n' "$EXPECT" >"$D/core-rules.sha256"
if PATH="$NOBOTH" sb_core_rules_integrity_ok "$RULES" "$D"; then tl_fail "no hashing tool: not ok"; else tl_pass "no hashing tool: not ok"; fi
printf 'tampered\n' >>"$RULES"
if sb_core_rules_integrity_ok "$RULES" "$D"; then tl_fail "tampered rules: not ok"; else tl_pass "tampered rules: not ok"; fi

# verified read
if sb_core_rules_read_verified "$D/missing.md" "$D" >/dev/null; then tl_fail "read of a missing file fails"; else tl_pass "read of a missing file fails"; fi
if sb_core_rules_read_verified "$RULES" "$D" >/dev/null; then tl_fail "tampered rules are not read"; else tl_pass "tampered rules are not read"; fi
sha256sum "$RULES" | awk '{print $1}' >"$D/core-rules.sha256"
assert_contains "verified rules are printed" "$(sb_core_rules_read_verified "$RULES" "$D")" "You MUST NOT skip things."
assert_contains "warning text" "$(sb_core_rules_integrity_warning)" "integrity check failed or is missing a pin"

# digest
if sb_core_rules_compact_digest "" "$RULES" >/dev/null; then tl_fail "digest needs content"; else tl_pass "digest needs content"; fi
digest="$(sb_core_rules_compact_digest "$(cat "$RULES")" "$RULES")"
assert_contains "digest keeps the non-negotiable section" "$digest" "You MUST NOT skip things."
assert_not_contains "digest stops at the next section" "$digest" "Layers."
assert_contains "digest points at the full file" "$digest" "$RULES"
digest="$(sb_core_rules_compact_digest "plain text without sections" "")"
assert_contains "no section: head slice used" "$digest" "plain text without sections"
assert_contains "no path: default path note" "$digest" "hooks/core-rules.md"

big="$(printf '## Non-Negotiable Rules\n'; for i in $(seq 1 200); do printf 'rule line %d with some padding text to grow the section\n' "$i"; done)"
digest="$(SB_CORE_RULES_DIGEST_MAX_BYTES=1000 sb_core_rules_compact_digest "$big" "$RULES")"
bytes="$(printf '%s' "$digest" | wc -c | tr -d ' ')"
if [[ "$bytes" -le 1000 ]]; then tl_pass "oversize digest is capped ($bytes bytes)"; else tl_fail "oversize digest is capped ($bytes bytes)"; fi
assert_contains "capped digest keeps the header" "$digest" "SessionStart digest"
assert_contains "capped digest keeps the path footer" "$digest" "Read full rules at"
assert_contains "capped digest keeps the first rule line" "$digest" "rule line 1 "
digest="$(SB_CORE_RULES_DIGEST_MAX_BYTES=100 sb_core_rules_compact_digest "$big" "$RULES")"
bytes="$(printf '%s' "$digest" | wc -c | tr -d ' ')"
if [[ "$bytes" -le 100 && "$bytes" -ge 90 ]]; then tl_pass "tiny budget: hard byte cap ($bytes bytes)"; else tl_fail "tiny budget: hard byte cap ($bytes bytes)"; fi

# verified digest
assert_contains "verified digest" "$(sb_core_rules_read_verified_digest "$RULES" "$D")" "You MUST NOT skip things."
printf 'x\n' >>"$RULES"
if sb_core_rules_read_verified_digest "$RULES" "$D" >/dev/null; then tl_fail "tampered rules give no digest"; else tl_pass "tampered rules give no digest"; fi

# ---- the shipped hooks/core-rules.md (pre-existing regression checks) -------
REAL_HOOKS="$TL_REPO_ROOT/hooks"
REAL_RULES="$REAL_HOOKS/core-rules.md"
assert_eq "pin matches core-rules.md" "$(sb_core_rules_expected_hash "$REAL_HOOKS")" "$(sb_core_rules_compute_hash "$REAL_RULES")"
if sb_core_rules_integrity_ok "$REAL_RULES" "$REAL_HOOKS"; then tl_pass "integrity ok for canonical file"; else tl_fail "integrity ok for canonical file"; fi
assert_eq "read verified returns content" "# Silver Bullet — Core Enforcement Rules" "$(sb_core_rules_read_verified "$REAL_RULES" "$REAL_HOOKS" | head -1)"
real_verified="$(sb_core_rules_read_verified "$REAL_RULES" "$REAL_HOOKS")"
real_digest="$(sb_core_rules_compact_digest "$real_verified" "$REAL_RULES")"
real_bytes=$(printf '%s' "$real_digest" | wc -c | tr -d ' ')
if [[ "$real_bytes" -le 3072 ]]; then tl_pass "compact digest size ${real_bytes}B <= 3072B"; else tl_fail "compact digest size ${real_bytes}B > 3072B"; fi
assert_contains "digest keeps non-negotiable markers" "$real_digest" "on-negotiable"
assert_contains "digest points to full core-rules path" "$real_digest" "core-rules.md"
if [[ -n "$(sb_core_rules_read_verified_digest "$REAL_RULES" "$REAL_HOOKS" || true)" ]]; then tl_pass "read_verified_digest returns content"; else tl_fail "read_verified_digest empty"; fi
# the shipped file with one appended line no longer matches its pin
cp "$REAL_RULES" "$TL_TMP/real-tamper.md"
echo "# tamper" >>"$TL_TMP/real-tamper.md"
if sb_core_rules_integrity_ok "$TL_TMP/real-tamper.md" "$REAL_HOOKS"; then tl_fail "tampered file fails integrity"; else tl_pass "tampered file fails integrity"; fi
# a pin-less copy neither verifies nor reads
mkdir -p "$TL_TMP/nopin"
cp "$REAL_RULES" "$TL_TMP/nopin/core-rules.md"
if sb_core_rules_integrity_ok "$TL_TMP/nopin/core-rules.md" "$TL_TMP/nopin"; then tl_fail "missing pin fails integrity"; else tl_pass "missing pin fails integrity"; fi
assert_eq "missing pin does not read core rules" "" "$(sb_core_rules_read_verified "$TL_TMP/nopin/core-rules.md" "$TL_TMP/nopin" 2>/dev/null || true)"

tl_results
