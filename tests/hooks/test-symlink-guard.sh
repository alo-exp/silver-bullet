#!/usr/bin/env bash
# Tests for hooks/lib/nofollow-guard.sh + end-to-end symlink refusal
# SEC-02: ensure hooks refuse to write through pre-planted symlinks.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LIB="${REPO_ROOT}/hooks/lib/nofollow-guard.sh"
PASS=0
FAIL=0

SB_TEST_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
mkdir -p "$SB_TEST_DIR"
TEST_RUN_ID="$$"
# Symlink targets and fixtures live in a private temp dir, never a shared /tmp name.
SYMLINK_TMP="$(mktemp -d "${TMPDIR:-/tmp}/sb-symlink-guard.XXXXXX")"

cleanup_all() {
  rm -f "${SB_TEST_DIR}/test-symlink-${TEST_RUN_ID}" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/test-symlink-target-${TEST_RUN_ID}" 2>/dev/null || true
  rm -f "${SB_TEST_DIR}/test-state-symlink-${TEST_RUN_ID}" 2>/dev/null || true
  rm -rf "$SYMLINK_TMP" 2>/dev/null || true
}
trap cleanup_all EXIT

pass() { PASS=$((PASS+1)); printf '  PASS: %s\n' "$1"; }
fail() { FAIL=$((FAIL+1)); printf '  FAIL: %s\n' "$1"; }

# ── Unit tests: sb_guard_nofollow ─────────────────────────────────────────────

# Test 1: symlink path causes exit 1 with stderr error
test_guard_rejects_symlink() {
  local target="${SYMLINK_TMP}/attacker-target"
  local link="${SB_TEST_DIR}/test-symlink-${TEST_RUN_ID}"
  : > "$target"
  ln -sf "$target" "$link"
  local out rc=0
  out=$(bash -c "source '$LIB'; sb_guard_nofollow '$link'" 2>&1) || rc=$?
  rm -f "$link" "$target"
  if [[ $rc -eq 1 ]] && printf '%s' "$out" | grep -q 'refusing to write through symlink'; then
    pass "sb_guard_nofollow rejects symlink (exit 1 + stderr)"
  else
    fail "sb_guard_nofollow rejects symlink — got rc=$rc out='$out'"
  fi
}

# Test 2: regular file path passes
test_guard_passes_regular_file() {
  local f="${SB_TEST_DIR}/test-symlink-target-${TEST_RUN_ID}"
  : > "$f"
  local rc=0
  bash -c "source '$LIB'; sb_guard_nofollow '$f'" 2>/dev/null || rc=$?
  rm -f "$f"
  if [[ $rc -eq 0 ]]; then
    pass "sb_guard_nofollow passes regular file"
  else
    fail "sb_guard_nofollow passes regular file — got rc=$rc"
  fi
}

# Test 3: nonexistent path passes
test_guard_passes_nonexistent() {
  local f="${SB_TEST_DIR}/test-symlink-nonexistent-${TEST_RUN_ID}"
  rm -f "$f"
  local rc=0
  bash -c "source '$LIB'; sb_guard_nofollow '$f'" 2>/dev/null || rc=$?
  if [[ $rc -eq 0 ]]; then
    pass "sb_guard_nofollow passes nonexistent path"
  else
    fail "sb_guard_nofollow passes nonexistent path — got rc=$rc"
  fi
}

# Test 4: sb_safe_write unlinks symlink but leaves regular file alone
test_safe_write_unlinks_symlink() {
  local target="${SYMLINK_TMP}/attacker-target"
  local link="${SB_TEST_DIR}/test-symlink-${TEST_RUN_ID}"
  printf 'original' > "$target"
  ln -sf "$target" "$link"
  bash -c "source '$LIB'; sb_safe_write '$link'" 2>/dev/null || true
  local target_content
  target_content=$(cat "$target" 2>/dev/null || echo MISSING)
  if [[ ! -e "$link" && "$target_content" == "original" ]]; then
    pass "sb_safe_write unlinks symlink without touching target"
  else
    fail "sb_safe_write symlink — link_exists=$([[ -e $link ]] && echo yes || echo no), target=$target_content"
  fi
  rm -f "$link" "$target"
}

# ── End-to-end: record-skill.sh refuses to write through symlink STATE_FILE ──

test_record_skill_rejects_symlink_state() {
  local HOOK="${REPO_ROOT}/hooks/record-skill.sh"
  local target="${SYMLINK_TMP}/attacker-target"
  local state_link="${SB_TEST_DIR}/test-state-symlink-${TEST_RUN_ID}"
  printf 'canary\n' > "$target"
  ln -sf "$target" "$state_link"

  # Invoke hook with a tracked skill; state file is a symlink
  local input='{"tool_input":{"skill":"silver-quality-gates"}}'
  SILVER_BULLET_STATE_FILE="$state_link" \
    bash -c "printf '%s' '$input' | '$HOOK' >/dev/null 2>&1 || true"

  # Target must still contain only 'canary\n' — no append through the symlink
  local target_content
  target_content=$(cat "$target")
  if [[ "$target_content" == "canary" ]]; then
    pass "record-skill.sh refuses to write through symlink STATE_FILE"
  else
    fail "record-skill.sh wrote through symlink — target now: $target_content"
  fi
  rm -f "$state_link" "$target"
}

# ── End-to-end: session-start refuses to write through symlink branch file ──
# The branch-scope write in session-start must be symlink-guarded. The hook only
# gets that far inside an SB project on a named branch and once its prerequisite
# probe finds a Silver Bullet plugin cache, so stage both: run from the checkout
# with no cache, the hook returned early (exit 0) and this check passed without
# ever reaching the write.

test_session_start_rejects_symlink_branch() {
  local HOOK="${REPO_ROOT}/hooks/session-start"
  local target="${SYMLINK_TMP}/attacker-target-session-start"
  local branch_link="${SB_TEST_DIR}/branch"
  local project="${SYMLINK_TMP}/sb-project"
  local cache_stub="${SB_RUNTIME_PLUGIN_CACHE_ROOT}/alo-labs/silver-bullet/test-symlink-${TEST_RUN_ID}"
  mkdir -p "$project" "$cache_stub"
  cp "${REPO_ROOT}/templates/silver-bullet.config.json.default" "$project/.silver-bullet.json"
  printf '# SB\n' >"$project/silver-bullet.md"
  git -C "$project" init -q
  git -C "$project" checkout -q -b feature/symlink-guard
  git -C "$project" -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m init
  # Back up any existing branch file
  local backup=""
  if [[ -f "$branch_link" && ! -L "$branch_link" ]]; then
    backup="${branch_link}.bak-${TEST_RUN_ID}"
    mv "$branch_link" "$backup"
  fi
  printf 'canary' > "$target"
  ln -sfn "$target" "$branch_link"

  # The stored branch ("canary") differs from feature/symlink-guard, so the hook
  # rewrites the branch file; the nofollow guard must stop it there with exit 1.
  local rc=0
  (cd "$project" && printf '{"source":"startup"}' | \
    env -u SILVER_BULLET_BRANCH_FILE "$HOOK" >/dev/null 2>&1) || rc=$?

  local target_content
  target_content=$(cat "$target" 2>/dev/null || echo MISSING)

  # Restore
  rm -f "$branch_link"
  [[ -n "$backup" ]] && mv "$backup" "$branch_link"
  rm -rf "$cache_stub"

  if [[ "$rc" -eq 1 ]]; then
    pass "session-start reaches the guarded branch-file write (exit 1)"
  else
    fail "session-start did not stop at the symlinked branch file — rc=$rc"
  fi
  if [[ "$target_content" == "canary" ]]; then
    pass "session-start refuses to write through symlink branch file"
  else
    fail "session-start wrote through symlink branch — target now: $target_content"
  fi
  rm -f "$target"
}

# Run tests
test_guard_rejects_symlink
test_guard_passes_regular_file
test_guard_passes_nonexistent
test_safe_write_unlinks_symlink
test_record_skill_rejects_symlink_state
test_session_start_rejects_symlink_branch

printf '\nResults: %d passed, %d failed\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]]
