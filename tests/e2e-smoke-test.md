# Silver Bullet E2E Smoke Test Protocol

Run this before any Silver Bullet release to validate the full workflow works end-to-end on a real project.

**Duration:** ~30-60 minutes (one full-dev-cycle run)
**Requires:** Claude Code with Silver Bullet, GSD, Superpowers, Engineering, and Design plugins installed

---

## 1. SETUP

```bash
cd tests/test-app/
npm install
npm test                    # Verify: 27 tests pass
node src/server.js &        # Verify: "Todo app running at http://localhost:3456"
curl localhost:3456/api/todos   # Verify: returns []
kill %1                     # Stop server
```

If this app has been tested before, clean up SB artifacts first:
```bash
rm -rf .planning .silver-bullet.json silver-bullet.md CLAUDE.md docs/workflows docs/sessions docs/forensics docs/CHANGELOG.md docs/KNOWLEDGE.md docs/PRD-Overview.md docs/Architecture-and-Design.md docs/Testing-Strategy-and-Plan.md docs/CICD.md
```

Initialize git (if not already):
```bash
git init && git add -A && git commit -m "initial: todo app baseline"
```

---

## 2. INITIALIZE SILVER BULLET

In Claude Code (with CWD = `tests/test-app/`):

```
/using-silver-bullet
```

**Verify these artifacts are created:**
- [ ] `.silver-bullet.json` with `src_pattern: "/src/"`
- [ ] `silver-bullet.md` with enforcement sections §0-§9
- [ ] `CLAUDE.md` referencing silver-bullet.md
- [ ] `docs/workflows/full-dev-cycle.md` (688+ lines)

---

## 3. FEATURE REQUEST

Tell Claude:

> Add due dates to todos. Users should be able to set an optional due date when creating or editing a todo, see the due date in the list, and overdue items should be visually highlighted in red.

---

## 4. WORKFLOW VALIDATION

As SB drives the workflow, check off each step:

### Session Setup
- [ ] Step 0 — Session mode question asked (interactive/autonomous)

### Project Initialization
- [ ] `/gsd:new-project` invoked (questioning, requirements, roadmap)
- [ ] `.planning/PROJECT.md` created
- [ ] `.planning/ROADMAP.md` created with phases

### Per-Phase Loop
- [ ] `/gsd:discuss-phase` invoked with what/expect/fail explanations shown to user
- [ ] `/quality-gates` invoked (8 quality dimensions checked)
- [ ] `/gsd:plan-phase` invoked (PLAN.md created)
- [ ] `/test-driven-development` invoked BEFORE implementation code
- [ ] `/gsd:execute-phase` invoked (commits produced)
- [ ] `/gsd:verify-work` invoked (UAT tests presented)
- [ ] `/code-review` invoked
- [ ] `superpowers:code-reviewer` ran with 2 consecutive approvals
- [ ] `/requesting-code-review` invoked
- [ ] `/receiving-code-review` invoked

### Finalization
- [ ] `/testing-strategy` invoked
- [ ] `/tech-debt` invoked
- [ ] `/documentation` invoked (README updated)
- [ ] `/finishing-a-development-branch` invoked

### Deployment
- [ ] CI/CD verification step ran
- [ ] `/deploy-checklist` invoked

### Ship & Release
- [ ] `/gsd:ship` invoked (or equivalent for direct-to-main)
- [ ] `/create-release` invoked

---

## 5. FEATURE VALIDATION

After the workflow completes:

```bash
npm test                    # All tests pass (including new due date tests)
node src/server.js &

# Create todo with due date
curl -X POST localhost:3456/api/todos \
  -H 'Content-Type: application/json' \
  -d '{"title":"Test due date","due_date":"2025-01-01"}'

# Verify due_date in response
curl localhost:3456/api/todos

kill %1
```

- [ ] `npm test` passes with new due date test cases
- [ ] POST with `due_date` field works
- [ ] GET returns `due_date` field on todos
- [ ] UI shows date input in the add form
- [ ] Overdue items display with red/highlighted styling

---

## 6. ENFORCEMENT VALIDATION

```bash
# Check state file has all required skills
cat ~/.claude/.silver-bullet/state | sort -u
```

**Required skills in state file:**
- [ ] `quality-gates`
- [ ] `code-review`
- [ ] `requesting-code-review`
- [ ] `receiving-code-review`
- [ ] `testing-strategy`
- [ ] `documentation`
- [ ] `finishing-a-development-branch`
- [ ] `deploy-checklist`
- [ ] `create-release`
- [ ] `verification-before-completion`
- [ ] `test-driven-development`
- [ ] `tech-debt`

**Compliance status should show all phases complete:**
```
Silver Bullet: N steps | PLANNING 1/1 | REVIEW 3/3 | FINALIZATION 4/4 | RELEASE 1/1
```

---

## 7. CLEANUP

```bash
cd ../..    # Back to Silver Bullet root
```

The SB-generated artifacts (`.planning/`, `.silver-bullet.json`, `silver-bullet.md`, `docs/workflows/`, etc.) are gitignored at the SB project level, so they won't pollute the SB repo.

To fully reset the test app for another run:
```bash
cd tests/test-app
rm -rf .planning .silver-bullet.json silver-bullet.md CLAUDE.md docs/ node_modules
git checkout -- .    # Restore original files
git clean -fd        # Remove untracked files
```

---

## Result

| Outcome | Action |
|---------|--------|
| All checkboxes checked | Release is validated -- proceed |
| Any step was skipped by SB | Bug -- enforcement failed. Investigate which hook/workflow rule was bypassed |
| Feature doesn't work | Bug -- execution quality issue. Check SUMMARY.md for deviations |
| Tests fail | Bug -- TDD enforcement may not have caught the issue |
