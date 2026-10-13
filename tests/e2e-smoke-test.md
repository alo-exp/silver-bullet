# Silver Bullet E2E Smoke Test Protocol

> **Automated enforcement tests now exist.** Run `bash tests/run-all-tests.sh` for full
> automated coverage of all hook enforcement behaviors (unit + integration scenarios).
> Coverage matrix (`tests/integration/coverage-matrix.sh`) verifies every hook in
> hooks.json has at least one test. This manual protocol remains for **full-feature
> workflow validation** -- testing that Claude actually invokes the right skills in the
> right order during a real session. Enforcement blocking/allowing is tested
> automatically; this protocol tests the orchestration experience.

Run this before any Silver Bullet release to validate the full workflow works end-to-end on a real project.

**Duration:** ~30-60 minutes (one full-dev-cycle run)
**Requires:** A host runtime with Silver Bullet installed (Claude Code, Codex, or Cursor)

---

## 1. SETUP

```bash
cd /Users/shafqat/projects/enterprise-grade-test-app
npm install
npm test                    # Verify: health test + ui-stub-ok
```

If this app has been tested before, clean up SB artifacts first:
```bash
rm -rf .planning .silver-bullet.json silver-bullet.md CLAUDE.md AGENTS.md docs/workflows docs/sessions docs/silver-forensics
```

Initialize git (if not already):
```bash
git init && git add -A && git commit -m "initial: enterprise test app baseline"
```

---

## 2. INITIALIZE SILVER BULLET

In Claude Code (with CWD = `/Users/shafqat/projects/enterprise-grade-test-app`):

```
/sb:init
```

**Verify these artifacts are created:**
- [ ] `.silver-bullet.json` with `src_pattern: "/src/"`
- [ ] `silver-bullet.md` with enforcement sections §0-§9
- [ ] No new `CLAUDE.md` is created for Codex init; if the project already had one, it is updated in place
- [ ] `docs/workflows/full-dev-cycle.md` (SB-owned workflow copy)

---

## 3. FEATURE REQUEST

Tell Claude:

> Add due dates to todos. Users should be able to set an optional due date when creating or editing a todo, see the due date in the list, and overdue items should be visually highlighted in red.

---

## 4. WORKFLOW VALIDATION

Run `/sb:feature` (or let SB route bare feature intent). As the orchestrator parent drives the composed workflow, check off each phase:

### Orchestrator parent mode
- [ ] Parent invokes `silver-orchestrator` / composer queue builder — does **not** implement features inline
- [ ] `orchestrator.json` seeded under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`
- [ ] `.planning/workflows/<workflow-id>.md` created with **Flow Log** CSV rows (not legacy `WORKFLOW.md`)
- [ ] `.planning/orchestrator-composition-log.jsonl` records composer + autonomous mode
- [ ] Task workers advance atoms; parent does not re-seed queue on worker re-read

### Pre-execution chain (FLOW 1–8 vocabulary)
- [ ] FLOW 2 ORIENT — `sb:scan` when brownfield
- [ ] FLOW 3 CLARIFY / FLOW 4 DECIDE — when intent is fuzzy or architectural
- [ ] FLOW 5 SPECIFY — when `.planning/SPEC.md` absent
- [ ] FLOW 13 QUALITY GATE (pre-plan) — `sb:quality-gates`
- [ ] FLOW 6 PLAN — `sb:plan` + `sb:validate`
- [ ] FLOW 8 EXECUTE — `sb:execute` (TDD before implementation)

### Post-execution chain (after FLOW 8)
- [ ] FLOW 10 REVIEW — `sb:review-request` → `sb:review` → `sb:review-triage`
- [ ] FLOW 12 VERIFY — `sb:verify` + verify-tests freshness
- [ ] FLOW 11 SECURE — `security` + `sb:secure`
- [ ] FLOW 13 QUALITY GATE (pre-ship)
- [ ] FLOW 14 SHIP — `sb:branch-finish` → `sb:completion-audit` → `sb:ship`

### Admission control
- [ ] Source edits blocked until `SB_WORKFLOW_ID` matches active `.planning/workflows/<id>.md`
- [ ] `dev-cycle-check.sh` references active workflow id (not legacy skill-count only)

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
cat ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/state | sort -u
```

**Required skills in state file (feature / full-dev-cycle):**
- [ ] `silver-quality-gates`
- [ ] `silver-review-request`
- [ ] `silver-review`
- [ ] `silver-review-triage`
- [ ] `silver-verify`
- [ ] `security`
- [ ] `silver-secure`
- [ ] `silver-validate`
- [ ] `silver-branch-finish`
- [ ] `silver-completion-audit`
- [ ] `silver-ship`
- [ ] `silver-create-release`
- [ ] `tdd` (or recorded via `silver-execute` chain)

**Compliance status should show FLOW progress when a workflow file is active:**
```
Silver Bullet: orchestrator active | workflow <id> | FLOW N/M
```

---

## 7. CLEANUP

```bash
cd /Users/shafqat/projects/silver-bullet/repo    # Back to Silver Bullet root
```

The SB-generated artifacts (`.planning/`, `.silver-bullet.json`, `silver-bullet.md`, `docs/workflows/`, etc.) are gitignored at the SB project level, so they won't pollute the SB repo.

To fully reset the test app for another run:
```bash
cd /Users/shafqat/projects/enterprise-grade-test-app
rm -rf .planning .silver-bullet.json silver-bullet.md CLAUDE.md docs/ node_modules
git checkout -- .    # Restore original files
git clean -fd        # Remove untracked files
```

---

## Composable Flows Verification (atomic FLOW-ID model)

After the standard smoke test, verify composer-specific behavior. Each checklist is abbreviated UAT for manual release validation.

### Shared orchestrator checks (all composers)
1. Composer skill seeds `orchestrator.json` + `.planning/workflows/<id>.md` Flow Log
2. Flow Log row labels match `hooks/lib/orchestrator-state.sh` CSV mapping (e.g. `QUALITY GATE`, `EXECUTE`)
3. `SB_WORKFLOW_ID` admission blocks stray source edits during active workflow
4. Worker sessions do not re-seed composer queue

### sb:feature
- [ ] Pre-chain: QUALITY GATE → CONTEXT → PLAN → VALIDATE → EXECUTE
- [ ] Post-chain: REVIEW → VERIFY → SECURE → VALIDATE → QUALITY GATE (pre-ship) → SHIP
- [ ] Conditional `sb:spec` when SPEC.md absent

### sb:ui
- [ ] Pre-chain includes `sb:ui-contract` before EXECUTE
- [ ] Post-chain opens with `sb:ui-review` before review triad

### sb:devops
- [ ] Pre-chain: BLAST RADIUS → DEVOPS SKILL ROUTER → devops quality gates → SECURE → … → EXECUTE
- [ ] Post-chain uses `FLOW-DEVOPS-QUALITY-GATE-PRESHIP` before ship prep

### sb:bugfix
- [ ] Diagnosis-first: DEBUG → PLAN → EXECUTE (no pre-plan quality-gates/context)
- [ ] Post-chain matches feature ship tail

### sb:deep-research
- [ ] Queue: `sb:clarify` → `sb:deep-research` → `sb:ensure-docs` → `sb:validate` (no EXECUTE atom)
- [ ] Default direct research; MultAI only when user explicitly requests in current task
- [ ] Handoff offers feature / devops / research-only paths

### sb:release
- [ ] Parent-driven audits before delivery tail: `RELEASE-UAT-AUDIT.md`, `RELEASE-MILESTONE-AUDIT.md`
- [ ] Delivery tail excludes `sb:execute`; ends with `sb:create-release`
- [ ] Gap-closure loop (max 2×) preserves release `SB_WORKFLOW_ID`

### sb:fast
- [ ] Tier 1 trivial → direct edit; Tier 3 → escalates to `sb:feature`
- [ ] Tier 2 queue: QUALITY GATE → PLAN → VALIDATE → EXECUTE → VERIFY

### sb:migrate (legacy projects)
1. Project has `.planning/` artifacts but stale workflow tracking
2. Run `/sb:migrate` — infers completed FLOW rows from artifacts
3. Generated `.planning/workflows/<id>.md` reflects inferred completion (not legacy `WORKFLOW.md`)

---

## Result

| Outcome | Action |
|---------|--------|
| All checkboxes checked | Release is validated -- proceed |
| Any step was skipped by SB | Bug -- enforcement failed. Investigate which hook/workflow rule was bypassed |
| Feature doesn't work | Bug -- execution quality issue. Check SUMMARY.md for deviations |
| Tests fail | Bug -- TDD enforcement may not have caught the issue |
