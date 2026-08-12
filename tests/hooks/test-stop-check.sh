#!/usr/bin/env bash
# Tests for hooks/stop-check.sh
# Verifies Stop hook block/allow behavior for missing/complete skills.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_TEST_HOOK_ENFORCED=1

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
HOOK="$REPO_ROOT/hooks/stop-check.sh"
CURRENT_CONFIG_VERSION="$(jq -r '.config_version' "$REPO_ROOT/templates/silver-bullet.config.json.default")"
PASS=0
FAIL=0

if [[ -f "$REPO_ROOT/hooks/lib/runtime-paths.sh" ]]; then
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "$REPO_ROOT/hooks/lib/runtime-paths.sh"
fi

export SILVER_BULLET_RUNTIME="${SILVER_BULLET_RUNTIME:-codex}"
export SB_RUNTIME_HOME_ROOT SB_RUNTIME_STATE_DIR SB_RUNTIME_PLUGIN_CACHE_ROOT SB_RUNTIME_NAME

# ── Test infrastructure ───────────────────────────────────────────────────────
# State files MUST be within ${SB_RUNTIME_HOME_ROOT}/ due to security path validation in hooks.
TEST_RUN_ID="$$"
export SB_RUNTIME_PRESERVE_STATE_DIR=1
export SB_RUNTIME_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/stop-check-${TEST_RUN_ID}"
SB_TEST_DIR="$SB_RUNTIME_STATE_DIR"
mkdir -p "$SB_TEST_DIR"
SESSION_START_FILE="${SB_TEST_DIR}/test-session-start-${TEST_RUN_ID}"

cleanup_all() {
  rm -f "${SB_TEST_DIR}/test-state-${TEST_RUN_ID}" "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" \
    "${SB_TEST_DIR}/test-branch-${TEST_RUN_ID}" "${SESSION_START_FILE}" \
    "${SB_TEST_DIR}/orchestrator.json" "${SB_TEST_DIR}/orchestrator-directive.json" \
    "${SB_TEST_DIR}/orchestrator-worker-active.json" 2>/dev/null || true
  rm -rf "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/stop-check-${TEST_RUN_ID}" 2>/dev/null || true
}
trap cleanup_all EXIT

write_cfg() {
  cat > "$TMPCFG" << EOF
{
  "config_version": "0.40.0",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["silver-quality-gates"],
    "required_deploy": [
      "silver-quality-gates",
      "code-review", "requesting-code-review", "receiving-code-review",
      "testing-strategy", "documentation",
      "finishing-a-development-branch", "deploy-checklist",
      "silver-create-release",
      "verification-before-completion",
      "test-driven-development", "tech-debt"
    ],
    "all_tracked": [
      "silver-quality-gates","code-review","requesting-code-review","receiving-code-review",
      "testing-strategy","documentation","finishing-a-development-branch","deploy-checklist",
      "silver-create-release","verification-before-completion","test-driven-development","tech-debt"
    ]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
}

# write_cfg_with_release is kept for backward compatibility; the full canonical list
# already includes silver-create-release via write_cfg.
write_cfg_with_release() { write_cfg; }

write_current_planning_state() {
  jq -r '.skills.required_planning[]' "$REPO_ROOT/templates/silver-bullet.config.json.default" > "$TMPSTATE"
}

setup() {
  TMPDIR_TEST=$(mktemp -d)
  TMPSTATE="${SB_TEST_DIR}/test-state-${TEST_RUN_ID}"
  TMPCFG="${TMPDIR_TEST}/.silver-bullet.json"
  TMPGIT="$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  git -C "$TMPGIT" init -q
  git -C "$TMPGIT" config user.email "test@test.com"
  git -C "$TMPGIT" config user.name "Test"
  cat > "$TMPDIR_TEST/silver-bullet.md" <<'EOF'
# Silver Bullet
EOF
  touch "$TMPGIT/.gitkeep"
  git -C "$TMPGIT" add .gitkeep silver-bullet.md
  write_cfg
  # Commit config on the default branch BEFORE forking feature/test so that
  # feature/test does not appear as 1-ahead of main. Tests that need a clean
  # working tree rely on `git status --porcelain` being empty (HOOK-14).
  [[ -f "$TMPCFG" ]] || { echo "setup: write_cfg failed to produce $TMPCFG" >&2; exit 1; }
  git -C "$TMPGIT" add .silver-bullet.json
  git -C "$TMPGIT" commit -q -m "init"
  git -C "$TMPGIT" checkout -q -b feature/test
  export SILVER_BULLET_STATE_FILE="$TMPSTATE"
  # Branch file: supply a test-local file matching the test's git branch so
  # branch-scope validation in stop-check.sh uses controlled input, not the
  # live ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/branch file from the user's current session.
  TMPBRANCH_FILE="${SB_TEST_DIR}/test-branch-${TEST_RUN_ID}"
  printf 'feature/test\n' > "$TMPBRANCH_FILE"
  export SILVER_BULLET_BRANCH_FILE="$TMPBRANCH_FILE"
  export SILVER_BULLET_SESSION_START_FILE="$SESSION_START_FILE"
  date +%s > "$SESSION_START_FILE"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
  rm -f "$TMPSTATE"
  rm -f "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
  rm -f "${SB_TEST_DIR}/test-branch-${TEST_RUN_ID}"
  rm -f "${SB_TEST_DIR}/stall-block"
  rm -f "${SESSION_START_FILE}"
  unset SILVER_BULLET_BRANCH_FILE
  unset SILVER_BULLET_SESSION_START_FILE
  unset SILVER_BULLET_STATE_FILE
}

run_hook() {
  local input='{"hook_event_name":"Stop"}'
  # Use subshell to set PWD to temp project dir (hook walks up from PWD)
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"'
}

assert_blocks() {
  local label="$1"
  local output="$2"
  if is_blocked "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1"
  local output="$2"
  if ! is_blocked "$output"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local label="$1"
  local output="$2"
  local needle="$3"
  if printf '%s' "$output" | grep -q "$needle"; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected '$needle' in: $output"
    FAIL=$((FAIL + 1))
  fi
}


assert_decoded_message_real_newlines() {
  # SB-BUG-B / #248: gate reason/message must decode to real newlines, not literal \n.
  local label="$1"
  local output="$2"
  local decoded
  decoded=$(printf '%s' "$output" | jq -r '
    .reason
    // .permissionDecisionReason
    // .hookSpecificOutput.permissionDecisionReason
    // .hookSpecificOutput.message
    // empty
  ' 2>/dev/null || true)
  if [[ -z "$decoded" ]]; then
    echo "  FAIL: $label — could not decode reason/message from: $output"
    FAIL=$((FAIL + 1))
    return
  fi
  if [[ "$decoded" != *$'\n'* ]]; then
    echo "  FAIL: $label — decoded text has no real newline characters"
    FAIL=$((FAIL + 1))
    return
  fi
  if printf '%s' "$decoded" | grep -qF '\n'; then
    echo "  FAIL: $label — decoded text still contains literal backslash-n"
    FAIL=$((FAIL + 1))
    return
  fi
  echo "  PASS: $label"
  PASS=$((PASS + 1))
}

assert_empty() {
  local label="$1"
  local output="$2"
  if [[ -z "$output" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected empty output, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

seed_doc_scheme_marker() {
  mkdir -p "$TMPDIR_TEST/docs"
  cat > "$TMPDIR_TEST/docs/doc-scheme.md" << 'EOF'
# Doc Scheme

## When docs get updated

| Event | What updates |
|---|---|
| Every task | CHANGELOG.md, knowledge/YYYY-MM.md, learnings/YYYY-MM.md |
EOF
  cat > "$TMPDIR_TEST/docs/doc-scheme.json" << 'EOF'
{
  "version": 1,
  "sync": {
    "doc_scheme_md_path": "docs/doc-scheme.md",
    "task_checklist_path": "docs/task-doc-checklist.json"
  },
  "enforcement": {
    "enabled": true,
    "granularity_levels": [2, 3]
  },
  "mandatory_updated_docs": [
    "docs/CHANGELOG.md",
    "docs/knowledge/YYYY-MM.md",
    "docs/learnings/YYYY-MM.md",
    "docs/task-doc-checklist.json"
  ],
  "required_docs": [
    { "key": "docs/CHANGELOG.md", "mandatory_updated": true, "required_sections": [] },
    { "key": "docs/knowledge/YYYY-MM.md", "mandatory_updated": true, "required_sections": [] },
    { "key": "docs/learnings/YYYY-MM.md", "mandatory_updated": true, "required_sections": [] },
    { "key": "docs/task-doc-checklist.json", "mandatory_updated": true, "required_sections": [] },
    { "key": "docs/doc-scheme.md", "mandatory_updated": false, "required_sections": [] },
    { "key": "docs/doc-scheme.json", "mandatory_updated": false, "required_sections": [] }
  ],
  "preserved_mappings": [],
  "archive_moves": []
}
EOF
}

seed_doc_scheme_targets_current_month() {
  local month="$1"
  mkdir -p "$TMPDIR_TEST/docs/knowledge" "$TMPDIR_TEST/docs/learnings"
  cat > "$TMPDIR_TEST/docs/CHANGELOG.md" << 'EOF'
# Changelog
EOF
  cat > "$TMPDIR_TEST/docs/knowledge/${month}.md" << EOF
# Knowledge ${month}
EOF
  cat > "$TMPDIR_TEST/docs/learnings/${month}.md" << EOF
# Learnings ${month}
EOF
}

seed_doc_scheme_checklist_current_month() {
  local month="$1"
  mkdir -p "$TMPDIR_TEST/docs"
  cat > "$TMPDIR_TEST/docs/task-doc-checklist.json" << EOF
{
  "task_id": "test-doc-scheme-gate",
  "task_granularity": 3,
  "docs": {
    "docs/CHANGELOG.md": "updated",
    "docs/knowledge/YYYY-MM.md": "updated",
    "docs/learnings/YYYY-MM.md": "updated",
    "docs/task-doc-checklist.json": "updated",
    "docs/doc-scheme.md": "not-needed: scheme unchanged for this task",
    "docs/doc-scheme.json": "not-needed: scheme contract unchanged for this task",
    "docs/ARCHITECTURE.md": "not-needed: no architecture changes in this task",
    "docs/TESTING.md": "not-needed: no testing-doc changes in this task",
    "docs/knowledge/INDEX.md": "not-needed: no docs added or removed in this task",
    "README.md": "not-needed: not a release task",
    "CHANGELOG.md": "n/a: root changelog not used in this project"
  }
}
EOF
}

add_contract_required_key() {
  local key="$1"
  python3 - "$TMPDIR_TEST/docs/doc-scheme.json" "$key" <<'PY'
import json
import sys
path = sys.argv[1]
key = sys.argv[2]
with open(path) as f:
    data = json.load(f)
required = data.setdefault("required_docs", [])
if not any(item.get("key") == key for item in required):
    required.append({"key": key, "mandatory_updated": False, "required_sections": []})
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

# ── Tests ─────────────────────────────────────────────────────────────────────
echo "=== stop-check.sh tests ==="

# Test 1: No config file -> exit 0, no output (project not using SB)
echo "--- Test 1: No config file ---"
setup
# Remove config file to simulate project not using SB
rm -f "$TMPCFG"
out=$(run_hook)
assert_empty "no config file -> silent exit, no output" "$out"
teardown

# Test 2: All required_deploy skills present -> exit 0, no block
echo "--- Test 2: All required skills present ---"
setup
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-context
silver-plan
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
finishing-a-development-branch
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
out=$(run_hook)
assert_passes "all required_deploy skills present -> no block" "$out"
teardown

# Test 3: Missing skills + dirty tree -> outputs block JSON with missing skill names
echo "--- Test 3: Missing skills + dirty tree -> block with skill names ---"
setup
# Only put one skill, leaving others missing
echo "code-review" > "$TMPSTATE"
# Dirty the working tree so HOOK-14 does not short-circuit enforcement
# (this test validates completion gate behaviour for an actual dev session).
printf 'work-in-progress\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
out=$(run_hook)
assert_blocks "missing skills -> decision:block" "$out"
assert_contains "block output contains 'silver-quality-gates'" "$out" "silver-quality-gates"
assert_decoded_message_real_newlines "NEWLINE: missing-skills reason uses real newlines not literal \\n" "$out"
teardown

# Test 3b: Uninstalled required skill -> warning only, no block
echo "--- Test 3b: Uninstalled required skill warns and allows ---"
setup
cat > "$TMPCFG" << EOF
{
  "config_version": "${CURRENT_CONFIG_VERSION}",
  "sb_initiated": true,
  "project": { "src_pattern": "/src/", "active_workflow": "full-dev-cycle" },
  "skills": {
    "required_planning": ["not-a-real-skill"],
    "required_deploy": ["not-a-real-skill"],
    "all_tracked": ["silver-quality-gates","code-review","requesting-code-review","receiving-code-review","testing-strategy","documentation","finishing-a-development-branch","deploy-checklist","silver-create-release","verification-before-completion","test-driven-development","tech-debt"]
  },
  "state": { "state_file": "${TMPSTATE}", "trivial_file": "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}" }
}
EOF
# Keep the state non-empty so the hook reaches the required-skill check.
echo "code-review" > "$TMPSTATE"
# Dirty the tree so HOOK-14 does not short-circuit enforcement.
printf 'work-in-progress\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
out=$(run_hook)
assert_passes "uninstalled required skill -> no block" "$out"
assert_contains "warning output mentions uninstalled skill" "$out" "not installed anywhere invocable"
assert_decoded_message_real_newlines "NEWLINE: uninstalled-skill warning uses real newlines not literal \\n" "$out"
teardown

# Test 4: Trivial file present -> exit 0, no block
echo "--- Test 4: Trivial bypass ---"
setup
# No skills recorded — would normally block
rm -f "$TMPSTATE"
# Create trivial file (not a symlink)
touch "${SB_TEST_DIR}/trivial-test-${TEST_RUN_ID}"
out=$(run_hook)
assert_passes "trivial file present -> no block" "$out"
teardown

# Test 5: On main branch -> finishing-a-development-branch not required
echo "--- Test 5: Main branch - finishing-a-development-branch not required ---"
setup
# Switch to main branch
git -C "$TMPDIR_TEST" checkout -q -b main 2>/dev/null || git -C "$TMPDIR_TEST" checkout -q main 2>/dev/null || true
# Sync the branch file so stop-check.sh sees the same branch as the git repo.
# Without this, the branch-scope mismatch guard exits 0 before the on-main
# filter is reached — test passes but for the wrong reason.
printf 'main\n' > "$TMPBRANCH_FILE"
# Stage an uncommitted file so HOOK-14's clean-tree exit (line 184 of stop-check.sh,
# the "no origin anchor + clean tree → read-only session" path) does NOT fire.
# Without a dirty tree, stop-check.sh exits 0 via HOOK-14 before ever reaching
# the on_main=true → finishing-a-development-branch filter at line 244.
printf 'main-work\n' > "$TMPDIR_TEST/main-work.txt"
git -C "$TMPDIR_TEST" add main-work.txt
# Put all required skills EXCEPT finishing-a-development-branch
cat > "$TMPSTATE" << 'EOF'
silver-quality-gates
silver-context
silver-plan
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
deploy-checklist
silver-create-release
verification-before-completion
test-driven-development
tech-debt
EOF
out=$(run_hook)
assert_passes "on main branch: all skills except finishing-a-development-branch -> no block" "$out"
teardown

# Test 6: Empty state file -> exit silently, no block (HOOK-04)
echo "--- Test 6: Empty state file -> non-dev session, no block ---"
setup
# Do NOT write anything to the state file — leave it empty/non-existent
out=$(run_hook)
assert_passes "empty state file -> non-dev session -> no block" "$out"
teardown

# Test 7: HOOK-14 — clean tree + no commits ahead + non-empty state -> no block
# Regression for issue #14: a conversational/read-only session on a branch that
# carries state from a prior wrap-up should not be gated by completion skills.
echo "--- Test 7: HOOK-14 clean tree + no ahead commits -> no block ---"
setup
# Non-empty state with only one skill — would normally block (missing many)
echo "silver-quality-gates" > "$TMPSTATE"
# Working tree is clean (setup already committed .gitkeep) and branch has no
# commits ahead of its origin: the test repo has no upstream, no origin/main,
# no main (we are on feature/test). HOOK-14 should still treat this as a
# conversational session since the tree is clean and there's no comparison ref
# → nothing to deploy → skip.
out=$(run_hook)
assert_passes "clean tree + non-empty state -> conversational session -> no block" "$out"
teardown

# Test 8: HOOK-14 — dirty working tree + non-empty state + missing skills -> block
# Guardrail: a session with uncommitted changes should still enforce completion.
echo "--- Test 8: HOOK-14 dirty tree -> still enforces ---"
setup
echo "code-review" > "$TMPSTATE"
# Introduce an uncommitted change so `git diff --quiet` fails
printf 'dirty\n' > "$TMPDIR_TEST/dirty.txt"
git -C "$TMPDIR_TEST" add dirty.txt
out=$(run_hook)
assert_blocks "dirty tree + missing skills -> still blocks" "$out"
teardown

# Test 9: HOOK-14 — clean tree + commits ahead of origin -> still enforces
echo "--- Test 9: HOOK-14 commits ahead of origin -> still enforces ---"
setup
# Create a fake origin/main pointing at the initial commit, then add a new
# commit on feature/test so it's 1 ahead.
git -C "$TMPDIR_TEST" branch main 2>/dev/null || true
git -C "$TMPDIR_TEST" update-ref refs/remotes/origin/main "$(git -C "$TMPDIR_TEST" rev-parse HEAD)"
printf 'more\n' > "$TMPDIR_TEST/more.txt"
git -C "$TMPDIR_TEST" add more.txt
git -C "$TMPDIR_TEST" commit -q -m "work" 2>/dev/null || true
echo "code-review" > "$TMPSTATE"
out=$(run_hook)
assert_blocks "clean tree but commits ahead -> still blocks" "$out"
teardown

# Test 7b: HOOK-14 — real origin/main present at HEAD, clean tree, non-empty
# state with missing skills -> no block. Exercises the rev-list-returns-zero
# happy path that Test 7 did not (Test 7 has no origin ref at all).
echo "--- Test 7b: HOOK-14 clean tree + real origin/main at HEAD -> no block ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"
git -C "$TMPDIR_TEST" update-ref refs/remotes/origin/main "$(git -C "$TMPDIR_TEST" rev-parse HEAD)"
out=$(run_hook)
assert_passes "origin/main at HEAD + clean tree + non-empty state -> no block" "$out"
teardown

# Test 10: HOOK-06 — hook invoked outside any git repository -> silent exit
# Walk-up finds no config, no .git → silent exit is correct.
echo "--- Test 10: HOOK-06 non-git-dir -> silent exit ---"
OUTSIDE_DIR=$(mktemp -d)
# Run hook with PWD set to a non-git dir; no config upstream either.
out=$( cd "$OUTSIDE_DIR" && printf '%s' '{"hook_event_name":"Stop"}' | bash "$HOOK" 2>/dev/null || true )
assert_empty "non-git dir + no config -> silent exit" "$out"
rm -rf "$OUTSIDE_DIR"

# Test 11: HOOK-06 — stale upstream ref (rev-list fails) + missing skills -> block
# Upstream is set but the ref does not resolve → rev-list fails → must
# fall through to enforcement, not silently skip.
echo "--- Test 11: HOOK-06 stale upstream -> fail-closed -> block ---"
setup
echo "code-review" > "$TMPSTATE"
# Point branch at a non-existent upstream ref.
git -C "$TMPDIR_TEST" config branch.feature/test.remote origin
git -C "$TMPDIR_TEST" config branch.feature/test.merge refs/heads/does-not-exist
out=$(run_hook)
assert_blocks "stale/unresolvable upstream + missing skills -> blocks (fail-closed)" "$out"
teardown

# Test 12: HOOK-06 — gitignored untracked file no longer blocks
# Ignored runtime artifacts should not trip the completion gate; the hook
# now lets read-only/runtime-only sessions proceed.
echo "--- Test 12: HOOK-06 gitignored untracked file -> allow ---"
setup
echo "code-review" > "$TMPSTATE"
# Add a gitignore entry and create an untracked file matching it.
printf 'wip-notes.txt\n' > "$TMPDIR_TEST/.gitignore"
git -C "$TMPDIR_TEST" add .gitignore
git -C "$TMPDIR_TEST" commit -q -m "add gitignore"
printf 'session work\n' > "$TMPDIR_TEST/wip-notes.txt"
out=$(run_hook)
assert_passes "gitignored untracked file + missing skills -> allows" "$out"
teardown

# Test 13: HOOK-06 — local main does NOT become a fallback anchor.
# Scenario: feature/test has local-only work not present on local `main`,
# no origin refs. Old code used local `main` as a fallback anchor, which
# (with main 1 behind HEAD) would CORRECTLY block — but with main reset
# AHEAD of HEAD would incorrectly pass. New code does not use local main
# at all; with no anchor and a clean tree we honor HOOK-14's read-only
# intent. Assert: HEAD ahead of local main + clean tree + no origin refs
# results in skip (since there's nowhere to deploy — no remote configured).
echo "--- Test 13: HOOK-06 local main not used as anchor -> skip on clean tree ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"
# Create a local main at the init commit, feature/test is 1 ahead.
git -C "$TMPDIR_TEST" branch main 2>/dev/null || true
printf 'feature-work\n' > "$TMPDIR_TEST/feat.txt"
git -C "$TMPDIR_TEST" add feat.txt
git -C "$TMPDIR_TEST" commit -q -m "feature work"
out=$(run_hook)
# Clean tree, no origin anchor, no upstream configured: HOOK-14 skip path.
# The commits-ahead-of-local-main are ignored because local main is not a
# trusted anchor (user may have reset it).
assert_passes "clean tree + no origin + local main exists -> skip (no anchor)" "$out"
teardown

# Test 14: Branch-scope validation — state recorded on a different branch -> no block
# Reproduces the worktree cross-project contamination bug: when session-start
# doesn't run (e.g. session resumed) the state file retains skills from another
# branch. stop-check must treat this as stale state and skip enforcement.
echo "--- Test 14: Cross-branch stale state -> no block ---"
setup
# Partial skills that would normally block (missing most required_deploy skills)
echo "silver-quality-gates" > "$TMPSTATE"
# Dirty the working tree so HOOK-14 doesn't short-circuit
printf 'work\n' > "$TMPDIR_TEST/work.txt"
git -C "$TMPDIR_TEST" add work.txt
# Overwrite the branch file with a DIFFERENT branch than feature/test (simulates
# stale state from a prior session on another branch/project)
printf 'phase/10-other-project\n' > "$TMPBRANCH_FILE"
out=$(run_hook)
# Restore correct branch so teardown is clean
printf 'feature/test\n' > "$TMPBRANCH_FILE"
assert_blocks "stale cross-branch state (branch file mismatch) -> blocks with warning (M-04)" "$out"
assert_contains "branch mismatch names stored branch" "$out" "phase/10-other-project"
teardown

# Test 15: S-06 regression — detached HEAD + clean tree -> no block
# git rev-parse --abbrev-ref HEAD returns "HEAD" (not empty) in detached HEAD
# state. "HEAD" passes the safety validation regex, so current_branch="HEAD"
# (non-empty). The elif branch in HOOK-14 fires and exits 0.
# Phase 63 audit: this test locks in the confirmed-correct exit-0 behaviour.
echo "--- Test 15: Detached HEAD + clean tree -> no block ---"
setup
git -C "$TMPDIR_TEST" checkout --detach HEAD 2>/dev/null
# Update branch file to match git's output for detached HEAD ("HEAD")
# so branch-scope validation passes and we exercise HOOK-14 directly.
printf 'HEAD\n' > "$TMPBRANCH_FILE"
echo "silver-quality-gates" > "$TMPSTATE"
out=$(run_hook)
assert_passes "detached HEAD + clean tree + no origin -> exit 0 (HOOK-14 elif branch)" "$out"
teardown

# Test 16: Absent branch file + non-empty state + dirty tree -> blocks
# Pins the fail-closed semantics of the branch-scope validation guard:
# when the branch file does not exist, stored_state_branch is empty,
# the [[ -n "$stored_state_branch" ]] condition is false, the guard
# does NOT exit 0, and enforcement proceeds to block (missing skills).
echo "--- Test 16: Absent branch file + dirty tree -> enforces (fail-closed) ---"
setup
# Remove the branch file — guard must NOT exit 0 in this case
rm -f "$TMPBRANCH_FILE"
# Partial skills that would normally block
echo "code-review" > "$TMPSTATE"
# Dirty working tree so HOOK-14 doesn't short-circuit
printf 'work\n' > "$TMPDIR_TEST/work.txt"
git -C "$TMPDIR_TEST" add work.txt
out=$(run_hook)
assert_blocks "absent branch file + dirty tree + partial skills -> blocks (fail-closed)" "$out"
teardown

# ── #88: HOOK-14 transient-artifact allowlist ────────────────────────────────
# `--ignored=traditional` previously over-caught routine session/runtime
# artifacts, defeating HOOK-14's intent on every release. v0.30.0 filters
# porcelain output through a transient-path allowlist before deciding
# `tree_clean`. Defaults: .codex/scheduled_tasks.lock,
# .codex/settings.local.json, .superpowers/, .planning/workflows/, REVIEW.md.

echo "--- Test #88-A: built-in transient artifacts ignored — HOOK-14 fires ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"
# Add gitignored runtime/session artifacts that previously blocked HOOK-14
mkdir -p "$TMPDIR_TEST/.claude" "$TMPDIR_TEST/.codex" "$TMPDIR_TEST/.superpowers/brainstorm" "$TMPDIR_TEST/.planning/workflows"
cat > "$TMPDIR_TEST/.gitignore" <<'GITIG'
.codex/
.superpowers/
.planning/workflows/
REVIEW.md
GITIG
git -C "$TMPDIR_TEST" add .gitignore
git -C "$TMPDIR_TEST" commit -q -m "gitignore"
# Now create the transient artifacts (untracked + ignored)
touch "$TMPDIR_TEST/.codex/scheduled_tasks.lock"
echo "{}" > "$TMPDIR_TEST/.codex/settings.local.json"
touch "$TMPDIR_TEST/.superpowers/brainstorm/notes.md"
touch "$TMPDIR_TEST/.planning/workflows/20260428T120000Z-abc123-silver-feature.md"
touch "$TMPDIR_TEST/REVIEW.md"
out=$(run_hook)
assert_passes "#88-A: built-in transient artifacts ignored -> HOOK-14 short-circuits" "$out"
teardown

echo "--- Test #88-B: real untracked file still triggers enforcement ---"
setup
echo "code-review" > "$TMPSTATE"
# A real (non-transient) untracked file must NOT be filtered
printf 'work\n' > "$TMPDIR_TEST/feature.txt"
out=$(run_hook)
assert_blocks "#88-B: non-transient untracked file -> still enforces" "$out"
teardown

echo "--- Test #88-C: configurable extra patterns honored ---"
setup
echo "silver-quality-gates" > "$TMPSTATE"
# Add a custom transient path via .silver-bullet.json
python3 -c "
import json
p='$TMPCFG'
d=json.load(open(p))
d.setdefault('hooks',{}).setdefault('stop_check',{})['transient_path_ignore_patterns']=['my\\\\.cache']
json.dump(d, open(p,'w'), indent=2)
"
git -C "$TMPDIR_TEST" add .silver-bullet.json
git -C "$TMPDIR_TEST" commit -q -m "configure transient patterns"
touch "$TMPDIR_TEST/my.cache"
out=$(run_hook)
assert_passes "#88-C: configured transient pattern ignored" "$out"
teardown

# ── #85: Stop hook applies planning floor, not full deploy list ──────────────
# The Stop hook is the conversation-end gate, NOT the delivery gate. Applying
# the full required_deploy list (deploy-checklist, create-release, etc.) on
# every conversation end blocks ad-hoc additions that don't warrant a
# milestone-ship checklist. Stop now requires only required_planning skills;
# completion-audit.sh continues to enforce required_deploy at actual delivery
# commands (gh release create / gh pr create / deploy).

echo "--- Test #85-A: planning skill present, deploy-only skills absent -> no block ---"
setup
# Only the planning skill — would have blocked under the old flat-list behavior
# because code-review / testing-strategy / deploy-checklist / create-release etc.
# were all required.
write_current_planning_state
# Dirty tree so HOOK-14 doesn't short-circuit before the skill check
printf 'work\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
out=$(run_hook)
assert_passes "#85-A: planning skill present + deploy gaps -> Stop allows" "$out"
teardown

echo "--- Test #85-B: missing planning skill -> still blocks ---"
setup
# State has deploy skills but is missing the planning floor.
# Confirms the new gate still enforces — it didn't simply weaken to nothing.
cat > "$TMPSTATE" <<'EOF'
code-review
requesting-code-review
receiving-code-review
testing-strategy
documentation
EOF
printf 'work\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
out=$(run_hook)
assert_blocks "#85-B: missing planning skill -> blocks" "$out"
assert_contains "#85-B: error names the missing planning skill" "$out" "silver-quality-gates"
teardown

echo "--- Test #85-C: deploy list NOT enforced by Stop hook ---"
setup
# Verify the precise old-behavior that #85 reported: a session with the
# planning skill but missing deploy-checklist / create-release MUST NOT
# be blocked by Stop. (completion-audit.sh handles those at delivery.)
write_current_planning_state
printf 'work\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
out=$(run_hook)
assert_passes "#85-C: missing deploy-checklist + create-release does NOT block Stop" "$out"
teardown

# ── Doc-scheme per-task gate (option 2) ──────────────────────────────────────
echo "--- DOC-2A: docs/doc-scheme.md present + missing checklist/docs -> blocks ---"
setup
write_current_planning_state
printf 'work\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
seed_doc_scheme_marker
out=$(run_hook)
assert_blocks "DOC-2A: missing checklist and required docs block completion" "$out"
assert_contains "DOC-2A: block mentions DOC-SCHEME GATE" "$out" "DOC-SCHEME GATE"
teardown

echo "--- DOC-2B: stale docs/checklist (pre-session) -> blocks ---"
setup
write_current_planning_state
printf 'work\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
seed_doc_scheme_marker
current_month=$(date '+%Y-%m')
seed_doc_scheme_targets_current_month "$current_month"
seed_doc_scheme_checklist_current_month "$current_month"
sleep 1
date +%s > "$SESSION_START_FILE"
out=$(run_hook)
assert_blocks "DOC-2B: stale docs/checklist block completion" "$out"
assert_contains "DOC-2B: block mentions stale docs" "$out" "Stale"
teardown

echo "--- DOC-2C: docs + checklist updated this session -> allows completion ---"
setup
write_current_planning_state
printf 'work\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
seed_doc_scheme_marker
date +%s > "$SESSION_START_FILE"
current_month=$(date '+%Y-%m')
mkdir -p "$TMPDIR_TEST/docs/knowledge" "$TMPDIR_TEST/docs/learnings"
cat > "$TMPDIR_TEST/docs/CHANGELOG.md" << 'EOF'
# Changelog
EOF
cat > "$TMPDIR_TEST/docs/knowledge/${current_month}-a.md" << EOF
# Knowledge ${current_month}
EOF
cat > "$TMPDIR_TEST/docs/learnings/${current_month}-b.md" << EOF
# Learnings ${current_month}
EOF
seed_doc_scheme_checklist_current_month "$current_month"
out=$(run_hook)
assert_passes "DOC-2C: docs/checklist current-session updates pass stop gate" "$out"
teardown

echo "--- DOC-2D: concrete docs file missing from checklist -> blocks ---"
setup
write_current_planning_state
printf 'work\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
seed_doc_scheme_marker
date +%s > "$SESSION_START_FILE"
current_month=$(date '+%Y-%m')
mkdir -p "$TMPDIR_TEST/docs/knowledge" "$TMPDIR_TEST/docs/learnings"
cat > "$TMPDIR_TEST/docs/CHANGELOG.md" << 'EOF'
# Changelog
EOF
cat > "$TMPDIR_TEST/docs/knowledge/${current_month}.md" << EOF
# Knowledge ${current_month}
EOF
cat > "$TMPDIR_TEST/docs/learnings/${current_month}.md" << EOF
# Learnings ${current_month}
EOF
cat > "$TMPDIR_TEST/docs/EXTRA.md" << 'EOF'
# Extra governed doc
EOF
add_contract_required_key "docs/EXTRA.md"
seed_doc_scheme_checklist_current_month "$current_month"
out=$(run_hook)
assert_blocks "DOC-2D: missing concrete doc key blocks completion" "$out"
assert_contains "DOC-2D: block names missing extra doc" "$out" "docs/EXTRA.md"
teardown

echo "--- ORCH-1: stale orchestrator state from another project does not block Stop ---"
setup
write_current_planning_state
printf 'work\n' > "$TMPDIR_TEST/wip.txt"
git -C "$TMPDIR_TEST" add wip.txt
jq -n \
  --arg repo "/other/project/root" \
  '{current_flow:"FLOW-QUALITY-GATE",workflow_id:"20260428T120000Z-abc123-silver-feature",repo_root:$repo}' \
  > "${SB_TEST_DIR}/orchestrator.json"
out=$(run_hook)
assert_passes "ORCH-1: foreign orchestrator state ignored for isolated test repo" "$out"
teardown

echo "--- ORCH-2: unscoped orchestrator state does not block Stop when workflows exist ---"
setup
write_current_planning_state
mkdir -p "$TMPDIR_TEST/.planning/workflows"
printf '# workflow\n' > "$TMPDIR_TEST/.planning/workflows/20260428T120000Z-abc123-silver-feature.md"
jq -n '{current_flow:"FLOW-QUALITY-GATE"}' > "${SB_TEST_DIR}/orchestrator.json"
out=$(run_hook)
assert_passes "ORCH-2: orchestrator without repo_root/workflow_id ignored despite local workflows" "$out"
teardown

echo "--- ORCH-3: enterprise matrix routing row marker exempts orchestrator Stop block ---"
setup
write_current_planning_state
jq -n \
  --arg repo "$TMPDIR_TEST" \
  '{current_flow:"FLOW-EXECUTE",repo_root:$repo,workflow_id:"20260428T120000Z-abc123-silver-feature"}' \
  > "${SB_TEST_DIR}/orchestrator.json"
jq -n '{next_skill:"silver-execute",next_worker_template:"EXECUTE"}' \
  > "${SB_TEST_DIR}/orchestrator-directive.json"
if [[ -f "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh"
  export SB_E2E_ENTERPRISE_MATRIX=1
  sb_e2e_matrix_set_routing_row_marker
  out=$(run_hook)
  assert_passes "ORCH-3: routing row marker allows Stop with pending silver-execute queue" "$out"
  sb_e2e_matrix_clear_routing_row_marker
  unset SB_E2E_ENTERPRISE_MATRIX
  out=$(run_hook)
  assert_blocks "ORCH-3b: without routing marker orchestrator queue still blocks Stop" "$out"
else
  echo "  SKIP: e2e-matrix-routing.sh missing"
fi
teardown

echo "--- ORCH-4: routing row marker alone exempts Stop (no SB_E2E_ENTERPRISE_MATRIX in hook env) ---"
setup
write_current_planning_state
jq -n \
  --arg repo "$TMPDIR_TEST" \
  '{current_flow:"FLOW-EXECUTE",repo_root:$repo,workflow_id:"20260428T120000Z-abc123-silver-feature"}' \
  > "${SB_TEST_DIR}/orchestrator.json"
jq -n '{next_skill:"silver-execute",next_worker_template:"EXECUTE"}' \
  > "${SB_TEST_DIR}/orchestrator-directive.json"
if [[ -f "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh"
  unset SB_E2E_ENTERPRISE_MATRIX
  unset SB_E2E_MATRIX_ROUTING_ROW
  sb_e2e_matrix_set_routing_row_marker
  out=$(run_hook)
  assert_passes "ORCH-4: marker alone allows Stop with pending orchestrator queue" "$out"
  sb_e2e_matrix_clear_routing_row_marker
else
  echo "  SKIP: e2e-matrix-routing.sh missing"
fi
teardown

echo "--- ORCH-5: subagent-stop exempt during routing row marker ---"
setup
write_current_planning_state
SUBAGENT_HOOK="$REPO_ROOT/hooks/subagent-stop-enforcement.sh"
if [[ -f "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh" && -x "$SUBAGENT_HOOK" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh"
  if [[ -f "$REPO_ROOT/hooks/lib/site-session.sh" ]]; then
    # shellcheck source=hooks/lib/site-session.sh
    source "$REPO_ROOT/hooks/lib/site-session.sh"
    sb_site_session_record_subagent_spawn '{"subagent_type":"generalPurpose"}' 2>/dev/null || true
  fi
  sb_e2e_matrix_set_routing_row_marker
  sub_out=$( cd "$TMPDIR_TEST" && printf '%s' '{"hook_event_name":"Stop"}' | bash "$SUBAGENT_HOOK" 2>/dev/null || true )
  assert_passes "ORCH-5: subagent-stop allows Stop during routing row" "$sub_out"
  sb_e2e_matrix_clear_routing_row_marker
  sub_out=$( cd "$TMPDIR_TEST" && printf '%s' '{"hook_event_name":"Stop"}' | bash "$SUBAGENT_HOOK" 2>/dev/null || true )
  assert_blocks "ORCH-5b: subagent-stop blocks without routing marker when workers ran" "$sub_out"
else
  echo "  SKIP: subagent-stop or e2e-matrix-routing missing"
fi
teardown

echo "--- ORCH-6: instruction-ledger exempt during routing row marker ---"
setup
LEDGER_HOOK="$REPO_ROOT/hooks/instruction-ledger-gate.sh"
if [[ -f "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh" && -x "$LEDGER_HOOK" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh"
  jq -n '{prompt_id:"abc",status:"pending",children:[{id:"c1",label:"item",status:"pending",evidence:"",children:[]}]}' \
    >"${SB_TEST_DIR}/instruction-ledger.json"
  ledger_out=$( cd "$TMPDIR_TEST" && printf '%s' '{"hook_event_name":"Stop"}' | bash "$LEDGER_HOOK" 2>/dev/null || true )
  assert_blocks "ORCH-6a: instruction-ledger blocks Stop with unresolved items" "$ledger_out"
  sb_e2e_matrix_set_routing_row_marker
  ledger_out=$( cd "$TMPDIR_TEST" && printf '%s' '{"hook_event_name":"Stop"}' | bash "$LEDGER_HOOK" 2>/dev/null || true )
  assert_passes "ORCH-6b: instruction-ledger allows Stop during routing row marker" "$ledger_out"
  sb_e2e_matrix_clear_routing_row_marker
else
  echo "  SKIP: instruction-ledger-gate or e2e-matrix-routing missing"
fi
teardown

echo "--- ORCH-7: site-regression exempt during routing row marker ---"
setup
SITE_REG_HOOK="$REPO_ROOT/hooks/site-regression-gate.sh"
if [[ -f "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh" && -x "$SITE_REG_HOOK" ]]; then
  # shellcheck source=hooks/lib/e2e-matrix-routing.sh
  source "$REPO_ROOT/hooks/lib/e2e-matrix-routing.sh"
  jq -n '{active:true,started_at:"2026-01-01T00:00:00Z",last_touch_at:"2026-06-28T12:00:00Z",touch_reason:"site-intent",regression_passed_at:null,push_intent:false}' \
    >"${SB_TEST_DIR}/site-session.json"
  site_out=$( cd "$TMPDIR_TEST" && printf '%s' '{"hook_event_name":"Stop"}' | bash "$SITE_REG_HOOK" 2>/dev/null || true )
  assert_blocks "ORCH-7a: site-regression blocks Stop with active session" "$site_out"
  sb_e2e_matrix_set_routing_row_marker
  site_out=$( cd "$TMPDIR_TEST" && printf '%s' '{"hook_event_name":"Stop"}' | bash "$SITE_REG_HOOK" 2>/dev/null || true )
  assert_passes "ORCH-7b: site-regression allows Stop during routing row marker" "$site_out"
  sb_e2e_matrix_clear_routing_row_marker
else
  echo "  SKIP: site-regression-gate or e2e-matrix-routing missing"
fi
teardown


# ── SKILLNORM: colon↔hyphen skill discovery (#247 / SB-BUG-A) ─────────────────
echo "--- SKILLNORM: colon install / hyphen require / absent (#247) ---"
# shellcheck source=hooks/lib/skill-discovery.sh
source "$REPO_ROOT/hooks/lib/skill-discovery.sh"

assert_skillnorm_rc() {
  local label="$1"
  local expected_rc="$2"
  local actual_rc="$3"
  if [[ "$actual_rc" -eq "$expected_rc" ]]; then
    echo "  PASS: $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $label — expected rc=$expected_rc got rc=$actual_rc"
    FAIL=$((FAIL + 1))
  fi
}

SKILLNORM_ROOT=$(mktemp -d)
mkdir -p "$SKILLNORM_ROOT/silver:quality-gates"
cat > "$SKILLNORM_ROOT/silver:quality-gates/SKILL.md" <<'EOF'
---
name: silver:quality-gates
description: SKILLNORM colon-path fixture
---
EOF
export SILVER_BULLET_SKILL_ROOTS="$SKILLNORM_ROOT"

_rc=0
sb_skill_is_installed "silver-quality-gates" || _rc=$?
assert_skillnorm_rc "SKILLNORM-A: colon-on-disk matches hyphen require" 0 "$_rc"

_rc=0
sb_skill_is_installed "silver:quality-gates" || _rc=$?
assert_skillnorm_rc "SKILLNORM-B: colon-on-disk matches colon require" 0 "$_rc"

_rc=0
sb_skill_is_installed "definitely-not-installed-skill-zzz" || _rc=$?
assert_skillnorm_rc "SKILLNORM-C: absent skill remains not installed" 1 "$_rc"

SKILLNORM_ROOT2=$(mktemp -d)
mkdir -p "$SKILLNORM_ROOT2/skills/other-dir"
cat > "$SKILLNORM_ROOT2/skills/other-dir/SKILL.md" <<'EOF'
---
name: silver:quality-gates
description: SKILLNORM frontmatter fixture
---
EOF
export SILVER_BULLET_SKILL_ROOTS="$SKILLNORM_ROOT2"
_rc=0
sb_skill_is_installed "silver-quality-gates" || _rc=$?
assert_skillnorm_rc "SKILLNORM-D: frontmatter colon name matches hyphen require" 0 "$_rc"

SKILLNORM_ROOT3=$(mktemp -d)
mkdir -p "$SKILLNORM_ROOT3/skills/silver-quality-gates"
cat > "$SKILLNORM_ROOT3/skills/silver-quality-gates/SKILL.md" <<'EOF'
---
name: silver-quality-gates
description: SKILLNORM hyphen-path fixture
---
EOF
export SILVER_BULLET_SKILL_ROOTS="$SKILLNORM_ROOT3"
_rc=0
sb_skill_is_installed "silver:quality-gates" || _rc=$?
assert_skillnorm_rc "SKILLNORM-E: hyphen-on-disk matches colon require" 0 "$_rc"

if declare -F sb_skill_name_variants >/dev/null 2>&1; then
  variant_list=$(sb_skill_name_variants "silver-quality-gates" | tr '\n' ' ')
  if printf '%s' "$variant_list" | grep -Fq 'silver-quality-gates' \
    && printf '%s' "$variant_list" | grep -Fq 'silver:quality-gates'; then
    echo "  PASS: SKILLNORM-F: sb_skill_name_variants emits hyphen and colon forms"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: SKILLNORM-F: variants missing expected forms: $variant_list"
    FAIL=$((FAIL + 1))
  fi
else
  echo "  FAIL: SKILLNORM-F: sb_skill_name_variants is not defined"
  FAIL=$((FAIL + 1))
fi

unset SILVER_BULLET_SKILL_ROOTS
rm -rf "$SKILLNORM_ROOT" "$SKILLNORM_ROOT2" "$SKILLNORM_ROOT3"
# ── Results ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
