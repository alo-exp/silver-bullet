#!/usr/bin/env bash
# Tests for hooks/roadmap-freshness.sh
# Verifies that git commit is blocked when a phase SUMMARY.md is staged
# but the corresponding ROADMAP.md checkbox is not ticked.

set -euo pipefail

HOOK="$(cd "$(dirname "$0")/../.." && pwd)/hooks/roadmap-freshness.sh"
PASS=0
FAIL=0

# ── Test infrastructure ───────────────────────────────────────────────────────
setup() {
  TMPDIR_TEST=$(mktemp -d)
  # Init git repo
  git -C "$TMPDIR_TEST" init -q
  git -C "$TMPDIR_TEST" config user.email "test@test.com"
  git -C "$TMPDIR_TEST" config user.name "Test"
  # Initial commit so HEAD exists
  touch "$TMPDIR_TEST/.gitkeep"
  git -C "$TMPDIR_TEST" add .gitkeep
  git -C "$TMPDIR_TEST" commit -q -m "init" 2>/dev/null || true
  # Create .silver-bullet.json so hook recognises it as a SB project
  printf '{"project":{}}' > "$TMPDIR_TEST/.silver-bullet.json"
  # Create .planning structure
  mkdir -p "$TMPDIR_TEST/.planning/phases/27-silver-fast-redesign"
}

teardown() {
  rm -rf "$TMPDIR_TEST"
}

run_hook() {
  local event="$1"
  local cmd="$2"
  local input
  input=$(jq -n --arg e "$event" --arg c "$cmd" \
    '{hook_event_name: $e, tool_name: "Bash", tool_input: {command: $c}}')
  ( cd "$TMPDIR_TEST" && printf '%s' "$input" | bash "$HOOK" 2>/dev/null )
}

is_blocked() {
  local output="$1"
  [[ -z "$output" ]] && return 1
  printf '%s' "$output" | grep -qE '"decision"\s*:\s*"block"|"permissionDecision"\s*:\s*"deny"'
}

assert_blocks() {
  local label="$1" output="$2"
  if is_blocked "$output"; then
    echo "  PASS $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $label — expected block, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

assert_passes() {
  local label="$1" output="$2"
  if ! is_blocked "$output"; then
    echo "  PASS $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL $label — expected pass, got: $output"
    FAIL=$((FAIL + 1))
  fi
}

stage_summary() {
  local phase_dir="$1" plan="$2"
  local path="$TMPDIR_TEST/.planning/phases/${phase_dir}"
  mkdir -p "$path"
  printf 'status: complete\n' > "$path/${plan}-SUMMARY.md"
  git -C "$TMPDIR_TEST" add "$path/${plan}-SUMMARY.md"
}

write_roadmap() {
  local content="$1"
  printf '%s' "$content" > "$TMPDIR_TEST/.planning/ROADMAP.md"
  # Don't stage roadmap unless the test explicitly does so
}

# ── Tests ─────────────────────────────────────────────────────────────────────

echo "roadmap-freshness.sh"

# 1. Non-commit command — passes silently
echo "  group: non-commit commands"
setup
out=$(run_hook "PreToolUse" "git push origin main")
assert_passes "git push does not trigger check" "$out"
teardown

# 2. No .silver-bullet.json — passes silently (not a SB project)
echo "  group: non-SB project"
setup
rm "$TMPDIR_TEST/.silver-bullet.json"
stage_summary "27-silver-fast-redesign" "27-01"
out=$(run_hook "PreToolUse" "git commit -m 'phase 27 done'")
assert_passes "non-SB project: silent pass" "$out"
teardown

# 3. No SUMMARY.md staged — passes silently
echo "  group: no SUMMARY.md staged"
setup
write_roadmap "- [ ] **Phase 27: silver-fast Redesign** - desc\n"
printf 'some change\n' > "$TMPDIR_TEST/foo.txt"
git -C "$TMPDIR_TEST" add foo.txt
out=$(run_hook "PreToolUse" "git commit -m 'unrelated change'")
assert_passes "no SUMMARY.md staged: silent pass" "$out"
teardown

# 4. SUMMARY.md staged, ROADMAP checkbox unticked — BLOCK
echo "  group: SUMMARY staged, checkbox unticked"
setup
write_roadmap "- [ ] **Phase 27: silver-fast Redesign** - 3-tier complexity triage
"
stage_summary "27-silver-fast-redesign" "27-01"
out=$(run_hook "PreToolUse" "git commit -m 'Phase 27: complete'")
assert_blocks "unticked checkbox blocks commit" "$out"
teardown

# 5. SUMMARY.md staged, ROADMAP checkbox ticked [x] — passes
echo "  group: SUMMARY staged, checkbox ticked"
setup
write_roadmap "- [x] **Phase 27: silver-fast Redesign** - 3-tier complexity triage (completed 2026-04-15)
"
stage_summary "27-silver-fast-redesign" "27-01"
git -C "$TMPDIR_TEST" add "$TMPDIR_TEST/.planning/ROADMAP.md" 2>/dev/null || true
out=$(run_hook "PreToolUse" "git commit -m 'Phase 27: complete'")
assert_passes "ticked checkbox allows commit" "$out"
teardown

# 6. SUMMARY.md staged, phase not in ROADMAP at all — passes silently (sub-plan, no ROADMAP entry)
echo "  group: phase not in ROADMAP"
setup
write_roadmap "- [x] **Phase 21: Foundation** - desc
"
stage_summary "27-silver-fast-redesign" "27-01"
out=$(run_hook "PreToolUse" "git commit -m 'Phase 27: complete'")
assert_passes "phase absent from ROADMAP: silent pass" "$out"
teardown

# 7. Multiple SUMMARYs staged — one unticked — BLOCK
echo "  group: multiple SUMMARYs, one unticked"
setup
write_roadmap "- [x] **Phase 23: Specialized Paths** - desc (completed 2026-04-15)
- [ ] **Phase 24: Cross-Cutting Paths** - desc
"
mkdir -p "$TMPDIR_TEST/.planning/phases/23-specialized-paths"
mkdir -p "$TMPDIR_TEST/.planning/phases/24-cross-cutting-paths-quality-gate-dual-mode"
printf 'status: complete\n' > "$TMPDIR_TEST/.planning/phases/23-specialized-paths/23-01-SUMMARY.md"
printf 'status: complete\n' > "$TMPDIR_TEST/.planning/phases/24-cross-cutting-paths-quality-gate-dual-mode/24-01-SUMMARY.md"
git -C "$TMPDIR_TEST" add \
  "$TMPDIR_TEST/.planning/phases/23-specialized-paths/23-01-SUMMARY.md" \
  "$TMPDIR_TEST/.planning/phases/24-cross-cutting-paths-quality-gate-dual-mode/24-01-SUMMARY.md"
out=$(run_hook "PreToolUse" "git commit -m 'Phases 23+24 complete'")
assert_blocks "one unticked among multiple stages: blocks" "$out"
teardown

# 8. ROADMAP.md missing — passes silently (no roadmap to check against)
echo "  group: ROADMAP.md missing"
setup
# Don't write a ROADMAP.md — only stage a SUMMARY.md
stage_summary "27-silver-fast-redesign" "27-01"
out=$(run_hook "PreToolUse" "git commit -m 'Phase 27: complete'")
assert_passes "no ROADMAP.md: silent pass" "$out"
teardown

# 9. PostToolUse event — hook emits PreToolUse deny format unconditionally regardless of
#    the event type in stdin. Hook is registered PreToolUse-only in hooks.json; this test
#    verifies the hook's own output (deny) not a separate PostToolUse code path.
echo "  group: PostToolUse event"
setup
write_roadmap "- [ ] **Phase 27: silver-fast Redesign** - desc
"
stage_summary "27-silver-fast-redesign" "27-01"
out=$(run_hook "PostToolUse" "git commit -m 'Phase 27: complete'")
assert_blocks "PostToolUse: unticked checkbox blocks" "$out"
teardown

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
