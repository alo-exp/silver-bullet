# Pre-Release Quality Gate Sidekick Enforcement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the 4-stage pre-release quality gate mandatory for releases, add the required full-test-suite rerun marker, and record both in `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state`.

**Architecture:** Keep the core SB skill log in `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state`, but move pre-release gate markers plus the full-suite rerun marker into a separate sidekick-owned file so release-gate progress is isolated from general skill tracking. Enforce the gate in `hooks/completion-audit.sh`, clear the Silver Bullet quality-gate state in `hooks/session-start`, and update the release docs so the gate instructions and enforcement match.

**Tech Stack:** Bash hooks, shell tests, Markdown docs.

---

### Task 1: Add release-gate Silver Bullet quality-gate state enforcement

**Files:**
- Modify: `hooks/completion-audit.sh`
- Modify: `hooks/session-start`
- Test: `tests/hooks/test-completion-audit.sh`
- Test: `tests/hooks/test-session-start.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/hooks/test-completion-audit.sh
mkdir -p "$SB_TEST_DIR/.sidekick"
cat > "$SB_TEST_DIR/.sidekick/quality-gate-state" <<'EOF'
quality-gate-stage-1
quality-gate-stage-2
quality-gate-stage-3
quality-gate-stage-4
EOF
out=$(run_hook "PreToolUse" "gh release create v1.0.0")
assert_blocks "release blocked without sidekick gate markers in live state" "$out"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash /Users/shafqat/projects/silver-bullet/repo/tests/hooks/test-completion-audit.sh`
Expected: FAIL on the new sidekick marker case because the hook still reads `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state`.

- [ ] **Step 3: Write minimal implementation**

```bash
sidekick_gate_file="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state"
if [[ -f "$sidekick_gate_file" && ! -L "$sidekick_gate_file" ]] && \
   grep -qx 'quality-gate-stage-1' "$sidekick_gate_file" && \
   grep -qx 'quality-gate-stage-2' "$sidekick_gate_file" && \
   grep -qx 'quality-gate-stage-3' "$sidekick_gate_file" && \
   grep -qx 'quality-gate-stage-4' "$sidekick_gate_file"; then
  : # gate passes
else
  emit_block "🛑 RELEASE BLOCKED — The 4-stage pre-release quality gate has not been completed in this session."
  exit 0
fi
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash /Users/shafqat/projects/silver-bullet/repo/tests/hooks/test-completion-audit.sh`
Expected: PASS with the new Silver Bullet quality-gate state case and existing live-matrix cases.

- [ ] **Step 5: Commit**

```bash
git add hooks/completion-audit.sh hooks/session-start tests/hooks/test-completion-audit.sh tests/hooks/test-session-start.sh
git commit -m "fix(release): enforce pre-release gate via Silver Bullet quality-gate state"
```

### Task 2: Update gate documentation and release guidance

**Files:**
- Modify: `docs/internal/pre-release-quality-gate.md`
- Modify: `skills/silver-release/SKILL.md`
- Modify: `silver-bullet.md`
- Modify: `tests/test-app/silver-bullet.md`
- Modify: `docs/SECURITY.md`

- [ ] **Step 1: Write the failing test**

```bash
grep -R "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state" \
  /Users/shafqat/projects/silver-bullet/repo/docs/internal/pre-release-quality-gate.md \
  /Users/shafqat/projects/silver-bullet/repo/skills/silver-release/SKILL.md \
  /Users/shafqat/projects/silver-bullet/repo/silver-bullet.md \
  /Users/shafqat/projects/silver-bullet/repo/templates/silver-bullet.md.base \
  /Users/shafqat/projects/silver-bullet/repo/tests/test-app/silver-bullet.md
```

- [ ] **Step 2: Run test to verify it fails**

Run: `grep -R "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state" ...`
Expected: HITs remain until the docs are updated.

- [ ] **Step 3: Write minimal implementation**

```markdown
Replace stage-marker instructions with `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state` and add the `full-test-suite-rerun` requirement.
Add a note that the 4-stage gate must record two consecutive clean passes before the marker is written.
```

- [ ] **Step 4: Run test to verify it passes**

Run: `grep -R "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state" ...`
Expected: no hits in the updated gate docs; remaining hits only in general skill/state docs where the runtime skill log is still correct.

- [ ] **Step 5: Commit**

```bash
git add docs/internal/pre-release-quality-gate.md skills/silver-release/SKILL.md silver-bullet.md templates/silver-bullet.md.base tests/test-app/silver-bullet.md docs/SECURITY.md
git commit -m "docs: move pre-release gate markers to Silver Bullet quality-gate state"
```

### Task 3: Verify the release path end to end

**Files:**
- Test: `tests/hooks/test-completion-audit.sh`
- Test: `tests/hooks/test-session-start.sh`

- [ ] **Step 1: Write the failing test**

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/hooks/test-session-start.sh
```

- [ ] **Step 2: Run test to verify it fails**

Expected: the session-start suite should fail until it clears `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state`.

- [ ] **Step 3: Write minimal implementation**

```bash
rm -f -- "${SB_RUNTIME_HOME_ROOT}/.silver-bullet/quality-gate-state" 2>/dev/null
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash /Users/shafqat/projects/silver-bullet/repo/tests/hooks/test-session-start.sh`
Expected: PASS and the new sidekick file is cleared on session start.

- [ ] **Step 5: Commit**

```bash
git add tests/hooks/test-session-start.sh tests/hooks/test-completion-audit.sh
git commit -m "test: cover pre-release gate Silver Bullet quality-gate state cleanup"
```
