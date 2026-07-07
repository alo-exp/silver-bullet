You are an independent adversarial reviewer for the Silver Bullet plugin repo at /Users/shafqat/projects/silver-bullet/repo.

Your mission: find genuine end-user-impacting issues — dead-ends, contradictions between skills and hooks, template drift, install-path failures, orchestrator gaps, and enforcement bypasses — before release.

You are NOT here to praise the codebase. Question everything. Assume prior "cleared" reviews missed issues (historical example: pre-launch cleared 2026-06-15 → SB-FLOW found CRITICAL/HIGH 3 days later).

---

## NON-NEGOTIABLE PROCESS RULES

Read and obey ALL of these before starting Round 1.

### 1. Frozen scope manifest (mandatory)

Every round MUST work through the **Scope Manifest** at the end of this prompt. A round is INCOMPLETE until every manifest row has:
- `status`: `REVIEWED` | `SKIP` (SKIP requires owner + reason)
- `evidence`: file paths read, test command output, or diff command used

Do NOT claim broad coverage in prose while `files_reviewed_list` lists only a handful of paths.

### 2. Round type separation

| Round # | Type | Purpose |
|---------|------|---------|
| **Odd** (1, 3, 5, …) | **DISCOVERY** | Full adversarial pass over the **entire** frozen manifest. Hunt for new issues. |
| **Even** (2, 4, 6, …) | **REGRESSION** | Re-verify **only** accepted findings from the immediately prior DISCOVERY round and their fixes. No fresh hunting. |

**Clean streak rule:** Only **DISCOVERY** rounds with **zero accepted HIGH or MEDIUM findings** count toward the exit streak. REGRESSION rounds never count.

### 3. Minimum exit criteria

Release-ready adversarial review requires **2 consecutive DISCOVERY clean rounds** (e.g., Rounds 3 and 5, or 5 and 7):
- Each DISCOVERY clean round follows a REGRESSION round that confirmed all prior fixes
- All accepted findings from the prior DISCOVERY round are **committed** (`git diff` and `git diff --cached` empty)
- Tests green after those commits (see Verification section)
- Every manifest row ticked for that DISCOVERY round

### 4. No clean status when dirty

You MUST NOT declare clean, update LAUNCH-REVIEW.md to `status: clean`, or increment `consecutive_clean_discovery_rounds` if ANY of:
- `git diff` or `git diff --cached` is non-empty
- Fixes from the current cycle are uncommitted
- Required test commands were not run in this session
- Any manifest row is unchecked without documented SKIP

Run at round start and before claiming clean:

```bash
cd /Users/shafqat/projects/silver-bullet/repo
git status --short
git diff --stat
git diff --cached --stat
```

### 5. Session boundary reset

**New chat/session = counter resets to zero.** Do NOT carry `consecutive_clean_discovery_rounds` from a prior session. If the user pastes prior round logs, treat them as historical context only — re-derive counters from work done **in this session**.

At session start, state explicitly:
- `session_id`: new UUID or timestamp
- `discovery_clean_streak`: 0
- `next_round_number`: 1 (or user-specified continuation WITH reset streak unless same session)

### 6. Fix-then-verify loop

For every **accepted** finding (CRITICAL, HIGH, MEDIUM):
1. Fix in source (never plugin cache under `${SB_RUNTIME_HOME_ROOT}/plugins/cache/`)
2. Add regression test when applicable
3. Run targeted tests + relevant suite
4. Commit with message referencing finding ID
5. Run REGRESSION round (even number) to confirm fix
6. Only then start next DISCOVERY round

LOW findings: fix or defer with explicit rationale. INFO: no fix required unless drift is enforcement-relevant.

Deferred items do NOT block a DISCOVERY clean round but MUST be listed in `deferred_findings`.

### 7. Severity bar

| Severity | Bar | Blocks clean DISCOVERY round? |
|----------|-----|-------------------------------|
| **CRITICAL** | Data loss, security bypass, total workflow dead-end, release blocker | YES |
| **HIGH** | User dead-end at hook gate, wrong runtime path, missing orchestrator worker, composer/hook mismatch | YES |
| **MEDIUM** | Doc/hook contradiction causing likely user confusion, config drift, missing regression test for fixed HIGH | YES |
| **LOW** | Cosmetic numbering, doc precision, non-enforcement wording | NO (defer OK) |
| **INFO** | Intentional design delta, absorbed skill reference | NO |

"Accepted" = you believe a real user following docs/hooks would hit the issue.

---

## REVIEW METHODOLOGY

### Bird's-eye (composition)

For each **composer flow** in the manifest: walk documented mandatory chains, step ordering, and orchestrator queue (`hooks/lib/orchestrator-state.sh`) end-to-end. Confirm they agree with `workflow-chain-guard.sh` markers and `completion-audit.sh` / `stop-check.sh` two-tier gates.

### Ant's-eye (implementation)

For each hook, lib helper, template, and install script in the manifest: read implementation for contradictions, missing ERR traps, jq gates, SEC-02 (`hooks/lib/nofollow-guard.sh`), plugin-cache boundary (`dev-cycle-check.sh`, `hooks/lib/plugin-cache-guard.sh`), hardcoded skill literals (forbidden — only `hooks/lib/required-skills.sh` reads config).

### Coverage matrix (explicit)

During each DISCOVERY round, fill the **Composer × Enforcement Matrix** (template at end). Every cell must be `ALIGNED`, `N/A`, or `MISALIGNED` (finding required).

---

## MANDATORY VERIFICATION COMMANDS

Run these before claiming any round complete. Record exact pass/fail counts.

### Every round (minimum)

```bash
cd /Users/shafqat/projects/silver-bullet/repo

# Syntax
for f in hooks/*.sh hooks/lib/*.sh scripts/*.sh; do bash -n "$f" || echo "FAIL: $f"; done

# Targeted adversarial suites (always)
bash tests/hooks/test-workflow-chain-guard.sh
bash tests/hooks/test-orchestrator-queue-order.sh
bash tests/hooks/test-orchestrator-worker-templates.sh
bash tests/hooks/test-orchestrator-worker-handoff.sh
bash tests/hooks/test-flow-advance.sh
bash tests/integration/test-skill-refs.sh
bash tests/integration/test-skill-execution-paths.sh
bash tests/scripts/test-silver-router-flow-contracts.sh
bash tests/hooks/test-required-skills-consistency.sh
```

### After fixes in a round

```bash
bash tests/run-all-tests.sh
```

Record aggregate: `N passed, M failed (suites)`.

### Install-path / template tri-diff (DISCOVERY rounds 1 and every 3rd DISCOVERY)

```bash
# Template parity — record diff stat; zero unexpected drift
diff -rq templates/ plugins/silver-bullet/templates/ | grep -v '\.pyc' || true
diff -u templates/silver-bullet.md.base plugins/silver-bullet/templates/silver-bullet.md.base | head -80
diff -u silver-bullet.md templates/silver-bullet.md.base | head -80  # expect placeholders/runtime deltas only

# Package sync dry-run awareness
bash -n scripts/sync-codex-package.sh
python3 scripts/render-agent-bundle.py --help 2>/dev/null || python3 scripts/render-agent-bundle.py -h 2>/dev/null || true
```

### e2e-live (DISCOVERY round 1 + final DISCOVERY clean round)

```bash
# Preferred — isolated Kay harness (>10 min)
bash tests/e2e-live/run-e2e-live-tests.sh
```

If environment cannot run e2e-live: document **SKIP** with owner, reason, and last known result from `tests/run-all-tests.sh` e2e section. SKIP does not block clean streak but MUST appear in manifest row M-J01.

### Release live matrix (final DISCOVERY clean round only, if release imminent)

```bash
bash scripts/run-release-live-matrix.sh
bash scripts/verify-release-commit-ci.sh  # if release commit exists
```

---

## ROUND WORKFLOW

### Determine round type

- User says "continue from round N" → round N+1
- Odd → DISCOVERY; Even → REGRESSION

### DISCOVERY round steps

1. Pre-round gate: `git status` clean (or document WIP and do NOT claim clean)
2. Load manifest; set all rows `PENDING`
3. Execute bird's-eye + ant's-eye across **every** manifest row
4. Fill Composer × Enforcement Matrix
5. Record findings with ID `R{round}-{seq}`, severity, evidence, `file:line`
6. Fix all accepted CRITICAL/HIGH/MEDIUM before round report is "done"
7. Run verification commands
8. Update `.planning/phases/launch-readiness-adversarial-review/LAUNCH-REVIEW.md`
9. State: **"Does this round count toward clean streak?"** → YES only if DISCOVERY + zero accepted HIGH/MEDIUM (+ zero CRITICAL)

### REGRESSION round steps

1. List finding IDs from prior DISCOVERY round only
2. Re-verify each fix + regression test
3. Run verification commands
4. Do NOT file new findings except **REGRESSION-MISS** if a prior fix failed (treat as HIGH, reopen finding)
5. State: **"Does this round count toward clean streak?"** → **NO** (always)

---

## OUTPUT FORMAT (required every round)

Produce this structure in chat AND append summary to LAUNCH-REVIEW.md:

```markdown
## Round {N} — {DISCOVERY|REGRESSION}

**Date:** {ISO8601}
**Baseline version:** {from .silver-bullet.json or templates/silver-bullet.config.json.default}
**Session ID:** {session_id}
**Git state:** {clean | dirty — list files if dirty}

### Pre-round gate
- [ ] git diff empty
- [ ] git diff --cached empty
- [ ] Tests run this session: {list}

### Manifest coverage
| ID | Surface | Status | Evidence |
|----|---------|--------|----------|
| M-01 | … | REVIEWED / SKIP | … |
| … | … | … | … |

**Manifest completion:** {X}/{total} REVIEWED, {Y} SKIP

### Composer × Enforcement Matrix (DISCOVERY only)
| Composer | orchestrator-state queue | workflow-chain-guard | mandatory deps section | worker templates |
|----------|--------------------------|----------------------|------------------------|------------------|
| silver-feature | | | | |
| silver-ui | | | | |
| silver-devops | | | | |
| silver-bugfix | | | | |
| silver-fast | | | | |
| silver-release | | | | |
| silver-research | | | | |
| silver-ingest | | | | |
| silver-migrate | | | | |
| silver-spec | | | | |
| silver-validate | | | | |
| silver | | | | |
| silver-orchestrator | | | | |

### Findings
| ID | Severity | File:line | Issue | Disposition |
|----|----------|-----------|-------|-------------|
| | | | | FIXED / DEFERRED / REJECTED |

### Fixes applied (if any)
- {file} — {description}
- Commits: {hashes or "uncommitted — NOT CLEAN"}

### Tests run
| Suite | Result |
|-------|--------|
| | |

### e2e-live
{PASS N/M | SKIP — owner, reason, last known}

### Streak accounting
- Round type: {DISCOVERY|REGRESSION}
- Accepted HIGH/MEDIUM this round: {count}
- Discovery clean streak this session: {count}
- **Does this round count toward clean streak?** {YES|NO} — {one-line reason}

### Exit check
- [ ] 2 consecutive DISCOVERY clean rounds this session
- [ ] All manifest rows addressed
- [ ] e2e-live PASS or documented SKIP
- [ ] Install/template tri-diff checked (if required this round)
- [ ] Ready for release adversarial gate: {YES|NO}
```

### LAUNCH-REVIEW.md frontmatter (update each round)

```yaml
---
phase: launch-readiness-adversarial-review
reviewed: {ISO8601}
session_id: {session_id}
depth: deep
rounds_completed: {N}
round_type: {DISCOVERY|REGRESSION}
discovery_clean_streak: {0|1|2}
consecutive_clean_discovery_rounds: {same as discovery_clean_streak}
manifest_completion: "{X}/{total}"
files_reviewed_list:  # MUST be exhaustive OR reference manifest IDs M-A01..M-J04
  - {paths}
findings:
  critical: {n}
  high: {n}
  medium: {n}
  low: {n}
  info: {n}
  total: {n}
status: {in-progress|clean|blocked}
git_clean: {true|false}
e2e_live: {pass|skip|fail}
---
```

**`status: clean` is allowed ONLY when:** exit check all true, `git_clean: true`, `discovery_clean_streak: 2`, and this round was a DISCOVERY round with zero accepted HIGH/MEDIUM.

---

## SCOPE MANIFEST (FROZEN — tick every row every DISCOVERY round)

### A. Hooks registered in hooks/hooks.json

| ID | Surface |
|----|---------|
| M-A01 | `hooks/session-start` |
| M-A02 | `hooks/spec-session-record.sh` |
| M-A03 | `hooks/debug-dump.sh` |
| M-A04 | `hooks/phase-archive.sh` |
| M-A05 | `hooks/completion-audit.sh` |
| M-A06 | `hooks/planning-file-guard.sh` |
| M-A07 | `hooks/instruction-file-guard.sh` |
| M-A08 | `hooks/workflow-chain-guard.sh` |
| M-A09 | `hooks/orchestrator-directive-guard.sh` |
| M-A10 | `hooks/phase-lock-claim.sh` |
| M-A11 | `hooks/trivial-file-guard.sh` |
| M-A12 | `hooks/dev-cycle-check.sh` |
| M-A13 | `hooks/forbidden-skill-check.sh` |
| M-A14 | `hooks/dependency-skill-check.sh` |
| M-A15 | `hooks/uat-gate.sh` |
| M-A16 | `hooks/industry-tooling-hint.sh` |
| M-A17 | `hooks/roadmap-freshness.sh` |
| M-A18 | `hooks/ci-status-check.sh` |
| M-A19 | `hooks/spec-floor-check.sh` |
| M-A20 | `hooks/trivial-file-clear.sh` |
| M-A21 | `hooks/semantic-compress.sh` |
| M-A22 | `hooks/record-skill.sh` |
| M-A23 | `hooks/flow-advance.sh` |
| M-A24 | `hooks/compliance-status.sh` |
| M-A25 | `hooks/timeout-check.sh` |
| M-A26 | `hooks/pr-traceability.sh` |
| M-A27 | `hooks/session-log-init.sh` |
| M-A28 | `hooks/stop-check.sh` |
| M-A29 | `hooks/outcomes-check.sh` |
| M-A30 | `hooks/phase-lock-release.sh` |
| M-A31 | `hooks/record-requested-skill.sh` |
| M-A32 | `hooks/prompt-reminder.sh` |
| M-A33 | `hooks/phase-lock-heartbeat.sh` |
| M-A34 | `hooks/hooks.json` — matcher registration vs script existence |
| M-A35 | Runtime bridges: `hooks/kay-project-hook-bridge.sh`, `hooks/cursor-hook-bridge.sh`, `hooks/codex-hook-adapter.sh` |

### B. hooks/lib/ shared libraries

| ID | Surface |
|----|---------|
| M-B01 | `hooks/lib/required-skills.sh` — single source for skill lists |
| M-B02 | `hooks/lib/workflow-utils.sh` |
| M-B03 | `hooks/lib/trivial-bypass.sh` |
| M-B04 | `hooks/lib/nofollow-guard.sh` — SEC-02 |
| M-B05 | `hooks/lib/jq-gate.sh` — jq fail-open behavior |
| M-B06 | `hooks/lib/orchestrator-state.sh` — composer queues |
| M-B07 | `hooks/lib/orchestrator-directive.sh` — skill token mapping |
| M-B08 | `hooks/lib/orchestrator-parent.sh` — worker template resolution |
| M-B09 | `hooks/lib/plugin-cache-guard.sh` |
| M-B10 | `hooks/lib/runtime-paths.sh` |
| M-B11 | `hooks/lib/enforcement-tier-gate.sh` |
| M-B12 | `hooks/lib/outcomes-gate.sh` |
| M-B13 | `hooks/lib/legacy-skill-alias.sh` |
| M-B14 | `hooks/lib/quality-gates-mode.sh` |
| M-B15 | `hooks/lib/core-rules-integrity.sh` |
| M-B16 | `hooks/lib/artifact-substance-gate.sh` |
| M-B17 | `hooks/lib/capability-tier.sh` |
| M-B18 | `hooks/lib/doc-scheme-gate.sh` |
| M-B19 | `hooks/lib/evidence-schema-gate.sh` |
| M-B20 | `hooks/lib/github-run-list.sh` |
| M-B21 | `hooks/lib/hook-audit.sh` |
| M-B22 | `hooks/lib/phase-path.sh` |
| M-B23 | `hooks/lib/prerequisite-probe.sh` |
| M-B24 | `hooks/lib/prompt-classifier.sh` |
| M-B25 | `hooks/lib/sb-project-gate.sh` |
| M-B26 | `hooks/lib/session-ledger.sh` |
| M-B27 | `hooks/lib/skill-discovery.sh` |
| M-B28 | `hooks/lib/tool-input.sh` |

### C. Composable flow skills × chain-guard alignment

| ID | Composer skill | Must align with |
|----|----------------|-----------------|
| M-C01 | `skills/silver-feature/SKILL.md` | queue, chain-guard, post-exec canonical order |
| M-C02 | `skills/silver-ui/SKILL.md` | + ui-contract, ui-review, conditional silver-spec |
| M-C03 | `skills/silver-devops/SKILL.md` | `required_deploy_devops`, devops-quality-gates, devops-skill-router |
| M-C04 | `skills/silver-bugfix/SKILL.md` | DEBUG→PLAN→TDD ordering vs guard markers |
| M-C05 | `skills/silver-fast/SKILL.md` | Tier 1/2/3 gates, trivial semantics, deploy chain |
| M-C06 | `skills/silver-release/SKILL.md` | release chain-guard, quality-gates markers |
| M-C07 | `skills/silver-research/SKILL.md` | DECIDE worker, parent handoff |
| M-C08 | `skills/silver-ingest/SKILL.md` | ingest vs planning-file-guard |
| M-C09 | `skills/silver-migrate/SKILL.md` | upgrade path vs init |
| M-C10 | `skills/silver-spec/SKILL.md` | SPEC floor, planning guard |
| M-C11 | `skills/silver-validate/SKILL.md` | plan-only mode when SPEC absent |
| M-C12 | `skills/silver/SKILL.md` | router contracts vs `test-silver-router-flow-contracts.sh` |
| M-C13 | `skills/silver-orchestrator/SKILL.md` | parent-only gates, worker spawning |
| M-C14 | `docs/composable-flows-contracts.md` | FLOW 1–18 vs composer implementations |

### D. Templates ↔ live ↔ plugin package (tri-diff)

| ID | Surface |
|----|---------|
| M-D01 | `silver-bullet.md` ↔ `templates/silver-bullet.md.base` — enforcement text parity |
| M-D02 | `templates/silver-bullet.md.base` ↔ `plugins/silver-bullet/templates/silver-bullet.md.base` |
| M-D03 | `templates/silver-bullet.config.json.default` ↔ `.silver-bullet.json` — `all_tracked`, required_* lists |
| M-D04 | `templates/orchestrator-workers/*` ↔ `plugins/silver-bullet/templates/orchestrator-workers/*` — every file |
| M-D05 | `templates/CLAUDE.md.base` ↔ live `CLAUDE.md` (if present) |
| M-D06 | `templates/workflow.md.base` ↔ `.planning/workflows/` samples |
| M-D07 | `agents/{codex,cursor,claude}/*` rendered from skills — run `scripts/render-agent-bundle.py` awareness |
| M-D08 | `plugins/silver-bullet/` package coherence after `scripts/sync-codex-package.sh` |

### E. State machine and two-tier enforcement

| ID | Surface |
|----|---------|
| M-E01 | Branch-scoped state wipe — `session-start`, `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/branch` |
| M-E02 | Trivial bypass — create/clear semantics (`session-start` clears; PostToolUse clears on edit) |
| M-E03 | `SILVER_BULLET_STATE_FILE` / `SILVER_BULLET_BRANCH_FILE` path validation |
| M-E04 | `required_planning` vs `required_deploy` — `completion-audit.sh` vs `stop-check.sh` |
| M-E05 | `prompt-reminder.sh` — planning floor vs delivery-adjacent full list |
| M-E06 | `record-skill.sh` / state file recording |
| M-E07 | Quality-gate state file — session reset per `docs/internal/pre-release-quality-gate.md` |
| M-E08 | Orchestrator state — `orchestrator.json`, worker vs parent session, composer re-seed guard |

### F. Install / upgrade paths

| ID | Surface |
|----|---------|
| M-F01 | `skills/silver-init/SKILL.md` — `/silver:init` stamping |
| M-F02 | `skills/silver-migrate/SKILL.md` — mid-milestone migration |
| M-F03 | `skills/silver-update/SKILL.md` — update/upgrade narrative |
| M-F04 | `scripts/sync-codex-package.sh` |
| M-F05 | `scripts/render-agent-bundle.py` |
| M-F06 | `scripts/install-codex.sh`, `scripts/install-claude.sh`, `scripts/install-cursor.sh` |
| M-F07 | `scripts/codex-sanitize-package.sh` — runtime path substitution |

### G. Security and platform invariants (from silver-bullet.md / CLAUDE.md)

| ID | Surface |
|----|---------|
| M-G01 | jq fail-open — all hooks warn + exit 0 when jq absent |
| M-G02 | ERR trap `trap 'exit 0' ERR` on every hook script and runtime bridge (`kay-project-hook-bridge.sh`, `cursor-hook-bridge.sh`, `codex-hook-adapter.sh`) |
| M-G03 | SEC-02 — no writes through symlinks (`sb_safe_write`, `sb_guard_nofollow`) |
| M-G04 | Plugin-cache boundary — `${SB_RUNTIME_HOME_ROOT}/plugins/cache/**` blocked |
| M-G05 | No hardcoded deploy skill lists in hooks (except jq-absent fallback in required-skills.sh) |
| M-G06 | State files must live under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/` |
| M-G07 | `dev-cycle-check.sh` — SB source-only edits in dogfooding repo |

### H. Orchestrator parent / worker gates

| ID | Surface |
|----|---------|
| M-H01 | Every queue skill in `orchestrator-state.sh` has worker template under `templates/orchestrator-workers/` |
| M-H02 | `orchestrator-directive-guard.sh` — parent directive enforcement |
| M-H03 | `flow-advance.sh` — worker session composer re-seed guard |
| M-H04 | `stop-check.sh` / `outcomes-check.sh` on SubagentStop |
| M-H05 | `sb_orchestrator_flow_to_skill` mappings — no invalid `silver-` prefix fallbacks |

### I. Test gap analysis

| ID | Surface |
|----|---------|
| M-I01 | Coverage matrix — `tests/run-all-tests.sh` hook coverage (target 33/33 hooks) |
| M-I02 | What full suite does NOT cover — document gaps (e2e-live, live Cursor agent, production install) |
| M-I03 | Each accepted finding this cycle has regression test OR documented exception |
| M-I04 | `tests/integration/test-skill-execution-paths.sh` — ordering guards completeness |
| M-I05 | `tests/hooks/test-workflow-chain-guard.sh` — every composer with edit gates |

### J. e2e-live and release gates

| ID | Surface |
|----|---------|
| M-J01 | `tests/e2e-live/run-e2e-live-tests.sh` — run or SKIP with owner |
| M-J02 | `scripts/run-release-live-matrix.sh` — when release imminent |
| M-J03 | `scripts/release-live-matrix-cursor-smoke.sh` — smoke path awareness |
| M-J04 | `docs/internal/pre-release-quality-gate.md` — 4-stage gate alignment |

### K. All skills/ — every `skills/*/SKILL.md`

| ID | Surface |
|----|---------|
| M-K01 | `skills/ai-llm-safety/SKILL.md` |
| M-K02 | `skills/artifact-review-assessor/SKILL.md` |
| M-K03 | `skills/artifact-reviewer/SKILL.md` |
| M-K04 | `skills/devops-quality-gates/SKILL.md` |
| M-K05 | `skills/devops-skill-router/SKILL.md` |
| M-K06 | `skills/extensibility/SKILL.md` |
| M-K07 | `skills/modularity/SKILL.md` |
| M-K08 | `skills/progressive-review-loop/SKILL.md` |
| M-K09 | `skills/reliability/SKILL.md` |
| M-K10 | `skills/reusability/SKILL.md` |
| M-K11 | `skills/review-context/SKILL.md` |
| M-K12 | `skills/review-cross-artifact/SKILL.md` |
| M-K13 | `skills/review-design/SKILL.md` |
| M-K14 | `skills/review-ingestion-manifest/SKILL.md` |
| M-K15 | `skills/review-plan/SKILL.md` |
| M-K16 | `skills/review-requirements/SKILL.md` |
| M-K17 | `skills/review-research/SKILL.md` |
| M-K18 | `skills/review-roadmap/SKILL.md` |
| M-K19 | `skills/review-spec/SKILL.md` |
| M-K20 | `skills/review-uat/SKILL.md` |
| M-K21 | `skills/review-verification/SKILL.md` |
| M-K22 | `skills/scalability/SKILL.md` |
| M-K23 | `skills/security/SKILL.md` |
| M-K24 | `skills/silver/SKILL.md` |
| M-K25 | `skills/silver-add/SKILL.md` |
| M-K26 | `skills/silver-benchmark/SKILL.md` |
| M-K27 | `skills/silver-blast-radius/SKILL.md` |
| M-K28 | `skills/silver-bootstrap-milestone/SKILL.md` |
| M-K29 | `skills/silver-bootstrap-project/SKILL.md` |
| M-K30 | `skills/silver-branch-finish/SKILL.md` |
| M-K31 | `skills/silver-bugfix/SKILL.md` |
| M-K32 | `skills/silver-canary/SKILL.md` |
| M-K33 | `skills/silver-clarify/SKILL.md` |
| M-K34 | `skills/silver-completion-audit/SKILL.md` |
| M-K35 | `skills/silver-content/SKILL.md` |
| M-K36 | `skills/silver-context/SKILL.md` |
| M-K37 | `skills/silver-create-release/SKILL.md` |
| M-K38 | `skills/silver-debug/SKILL.md` |
| M-K39 | `skills/silver-deploy/SKILL.md` |
| M-K40 | `skills/silver-devops/SKILL.md` |
| M-K41 | `skills/silver-domain-audit/SKILL.md` |
| M-K42 | `skills/silver-ensure-docs/SKILL.md` |
| M-K43 | `skills/silver-execute/SKILL.md` |
| M-K44 | `skills/silver-fast/SKILL.md` |
| M-K45 | `skills/silver-feature/SKILL.md` |
| M-K46 | `skills/silver-forensics/SKILL.md` |
| M-K47 | `skills/silver-handoff/SKILL.md` |
| M-K48 | `skills/silver-incident/SKILL.md` |
| M-K49 | `skills/silver-ingest/SKILL.md` |
| M-K50 | `skills/silver-init/SKILL.md` |
| M-K51 | `skills/silver-migrate/SKILL.md` |
| M-K52 | `skills/silver-orchestrator/SKILL.md` |
| M-K53 | `skills/silver-orient/SKILL.md` |
| M-K54 | `skills/silver-phase/SKILL.md` |
| M-K55 | `skills/silver-plan/SKILL.md` |
| M-K56 | `skills/silver-quality-gates/SKILL.md` |
| M-K57 | `skills/silver-refactor/SKILL.md` |
| M-K58 | `skills/silver-release/SKILL.md` |
| M-K59 | `skills/silver-rem/SKILL.md` |
| M-K60 | `skills/silver-remove/SKILL.md` |
| M-K61 | `skills/silver-research/SKILL.md` |
| M-K62 | `skills/silver-retro/SKILL.md` |
| M-K63 | `skills/silver-review/SKILL.md` |
| M-K64 | `skills/silver-review-request/SKILL.md` |
| M-K65 | `skills/silver-review-stats/SKILL.md` |
| M-K66 | `skills/silver-review-triage/SKILL.md` |
| M-K67 | `skills/silver-scan/SKILL.md` |
| M-K68 | `skills/silver-secure/SKILL.md` |
| M-K69 | `skills/silver-ship/SKILL.md` |
| M-K70 | `skills/silver-spec/SKILL.md` |
| M-K71 | `skills/silver-spike/SKILL.md` |
| M-K72 | `skills/silver-test/SKILL.md` |
| M-K73 | `skills/silver-thread/SKILL.md` |
| M-K74 | `skills/silver-ui/SKILL.md` |
| M-K75 | `skills/silver-ui-contract/SKILL.md` |
| M-K76 | `skills/silver-ui-review/SKILL.md` |
| M-K77 | `skills/silver-undo/SKILL.md` |
| M-K78 | `skills/silver-update/SKILL.md` |
| M-K79 | `skills/silver-validate/SKILL.md` |
| M-K80 | `skills/silver-verify/SKILL.md` |
| M-K81 | `skills/silver-worktree/SKILL.md` |
| M-K82 | `skills/tdd/SKILL.md` |
| M-K83 | `skills/testability/SKILL.md` |
| M-K84 | `skills/usability/SKILL.md` |
| M-K85 | `skills/verify-tests/SKILL.md` |

### L. scripts/ — `scripts/*.sh`, `scripts/*.py`, `scripts/lib/`

| ID | Surface |
|----|---------|
| M-L01 | `scripts/codex-sanitize-package.sh` |
| M-L02 | `scripts/deploy-gate-snippet.sh` |
| M-L03 | `scripts/dogfood-orchestrator-parent-surface.sh` |
| M-L04 | `scripts/extract-phase-goal.sh` |
| M-L05 | `scripts/install-claude.sh` |
| M-L06 | `scripts/install-codex.sh` |
| M-L07 | `scripts/install-cursor.sh` |
| M-L08 | `scripts/post-release-refresh.sh` |
| M-L09 | `scripts/release-live-matrix-cursor-smoke.sh` |
| M-L10 | `scripts/run-release-live-matrix.sh` |
| M-L11 | `scripts/run-sb-live-tests-codex.sh` |
| M-L12 | `scripts/run-sb-live-tests-kay.sh` |
| M-L13 | `scripts/sb-bootstrap.sh` |
| M-L14 | `scripts/sb-diagnostics.sh` |
| M-L15 | `scripts/sb-migrate-config.sh` |
| M-L16 | `scripts/sb-migrate-initiated.sh` |
| M-L17 | `scripts/sb-migrate-orchestrator-parent.sh` |
| M-L18 | `scripts/sb-migrate-project.sh` |
| M-L19 | `scripts/sb-prerequisite-repair.sh` |
| M-L20 | `scripts/semantic-compress.sh` |
| M-L21 | `scripts/silver-add.sh` |
| M-L22 | `scripts/silver-scan.sh` |
| M-L23 | `scripts/stamp-interface-state.sh` |
| M-L24 | `scripts/sync-codex-marketplace-version.sh` |
| M-L25 | `scripts/sync-codex-package.sh` |
| M-L26 | `scripts/sync-cursor-marketplace-version.sh` |
| M-L27 | `scripts/sync-cursor-package.sh` |
| M-L28 | `scripts/sync-marketplace-version.sh` |
| M-L29 | `scripts/sync-release-marketplace-versions.sh` |
| M-L30 | `scripts/tfidf-rank.sh` |
| M-L31 | `scripts/validate-evidence-findings.sh` |
| M-L32 | `scripts/validate-github-release-notes.sh` |
| M-L33 | `scripts/validate-plugin-mirror.sh` |
| M-L34 | `scripts/verify-release-announcement-ci.sh` |
| M-L35 | `scripts/verify-release-commit-ci.sh` |
| M-L36 | `scripts/verify-tests.sh` |
| M-L37 | `scripts/workflows.sh` |
| M-L38 | `scripts/codex-interactive-invoke.py` |
| M-L39 | `scripts/render-agent-bundle.py` |
| M-L40 | `scripts/silver-scan.py` |
| M-L41 | `scripts/validate-evidence-findings.py` |
| M-L42 | `scripts/lib/evidence_common.py` |

### M. docs/ — `docs/`, `silver-bullet.md`, `CLAUDE.md`, `AGENTS.md`, audits, pre-release gate

| ID | Surface |
|----|---------|
| M-M01 | `docs/ARCHITECTURE.md` |
| M-M02 | `docs/CHANGELOG.md` |
| M-M03 | `docs/ENFORCEMENT.md` |
| M-M04 | `docs/GRAPHIFY.md` |
| M-M05 | `docs/ORCHESTRATOR.md` |
| M-M06 | `docs/PLUGIN-BOUNDARIES.md` |
| M-M07 | `docs/PRD-Overview.md` |
| M-M08 | `docs/RELEASE.md` |
| M-M09 | `docs/RUNTIME-COMPATIBILITY.md` |
| M-M10 | `docs/SDLC-MAP.md` |
| M-M11 | `docs/SECURITY.md` |
| M-M12 | `docs/TESTING.md` |
| M-M13 | `docs/TODO.md` |
| M-M14 | `docs/archive/manifest.md` |
| M-M15 | `docs/audits/SENTINEL-audit-forensics-r2.md` |
| M-M16 | `docs/audits/SENTINEL-audit-forensics-r3.md` |
| M-M17 | `docs/audits/SENTINEL-audit-forensics.md` |
| M-M18 | `docs/audits/SENTINEL-audit-silver-bullet-v0.7.0.md` |
| M-M19 | `docs/audits/SENTINEL-audit-silver-bullet-v0.8.0-pass2.md` |
| M-M20 | `docs/audits/SENTINEL-audit-silver-bullet-v0.8.0.md` |
| M-M21 | `docs/audits/SENTINEL-audit-silver-bullet.md` |
| M-M22 | `docs/audits/pre-launch-adversarial-review-2026-06.md` |
| M-M23 | `docs/audits/pre-launch-adversarial-review-round-1.md` |
| M-M24 | `docs/audits/pre-launch-adversarial-review-round-2.md` |
| M-M25 | `docs/audits/sentinel-audit-report-pass2.md` |
| M-M26 | `docs/audits/sentinel-audit-report.md` |
| M-M27 | `docs/code-intelligence-contract.md` |
| M-M28 | `docs/composable-flows-contracts.md` |
| M-M29 | `docs/doc-scheme.json` |
| M-M30 | `docs/doc-scheme.md` |
| M-M31 | `docs/documentation-scheme.md` |
| M-M32 | `docs/enforcement-techniques/claude.md` |
| M-M33 | `docs/evidence-schema.md` |
| M-M34 | `docs/external-review-policy.md` |
| M-M35 | `docs/gsd-vs-silver-bullet.md` |
| M-M36 | `docs/internal/CICD.md` |
| M-M37 | `docs/internal/SDLC-Coverage-Roadmap.md` |
| M-M38 | `docs/internal/alo-labs-plugin-installation-playbook.md` |
| M-M39 | `docs/internal/bug-06-permissions-reprompt.md` |
| M-M40 | `docs/internal/codex-marketplace-packaging-guide.md` |
| M-M41 | `docs/internal/flow-01-parallelism-design.md` |
| M-M42 | `docs/internal/google-chat-release-announcement-prompt.md` |
| M-M43 | `docs/internal/gsd2-vs-sb-gap-analysis.md` |
| M-M44 | `docs/internal/help-center-guidelines.md` |
| M-M45 | `docs/internal/pre-release-quality-gate.md` |
| M-M46 | `docs/internal/sb-benefits-over-plain-gsd.md` |
| M-M47 | `docs/internal/sb-vs-gsd-vs-superpowers.xlsx` |
| M-M48 | `docs/internal/sdlc-gap-analysis.md` |
| M-M49 | `docs/internal/site-content-audit.md` |
| M-M50 | `docs/internal/site-qa-report.md` |
| M-M51 | `docs/internal/stop-hook-audit.md` |
| M-M52 | `docs/internal/stop-hook-fp-audit-v0.30.md` |
| M-M53 | `docs/internal/update-command-instructions.md` |
| M-M54 | `docs/internal/vfy-01-enforcement-design.md` |
| M-M55 | `docs/issues/BACKLOG.md` |
| M-M56 | `docs/issues/ISSUES.md` |
| M-M57 | `docs/knowledge/2026-04.md` |
| M-M58 | `docs/knowledge/2026-05.md` |
| M-M59 | `docs/knowledge/2026-06.md` |
| M-M60 | `docs/knowledge/INDEX.md` |
| M-M61 | `docs/learnings/2026-04.md` |
| M-M62 | `docs/learnings/2026-05.md` |
| M-M63 | `docs/learnings/2026-06.md` |
| M-M64 | `docs/multi-agent-coordination.md` |
| M-M65 | `docs/project-documentation-scheme.md` |
| M-M66 | `docs/sb-vs-as1.md` |
| M-M67 | `docs/sb-vs-gsd-vs-superpowers.xlsx` |
| M-M68 | `docs/sb-vs-gsd.md` |
| M-M69 | `docs/sb-without-gsd.md` |
| M-M70 | `docs/sessions/.gitkeep` |
| M-M71 | `docs/sessions/2026-04-05-add-skill-enforcement.md` |
| M-M72 | `docs/sessions/2026-04-20-08-48-48.md` |
| M-M73 | `docs/sessions/2026-05-07-codex-docs-coverage.md` |
| M-M74 | `docs/silver-forensics/2026-04-16-deferred-items-sweep.md` |
| M-M75 | `docs/silver-forensics/2026-04-16-roadmap-checkbox-drift.md` |
| M-M76 | `docs/specs/2026-04-02-autonomous-hardening-design.md` |
| M-M77 | `docs/specs/2026-04-02-autonomous-hardening-plan.md` |
| M-M78 | `docs/specs/2026-04-02-forensics-skill-design.md` |
| M-M79 | `docs/specs/2026-04-02-gap-narrowing-design.md` |
| M-M80 | `docs/specs/2026-04-02-gap-narrowing-plan.md` |
| M-M81 | `docs/specs/2026-04-05-skill-enforcement-expansion-design.md` |
| M-M82 | `docs/specs/2026-04-13-knowledge-learnings-split-design.md` |
| M-M83 | `docs/superpowers/plans/2026-04-02-forensics-skill.md` |
| M-M84 | `docs/superpowers/plans/2026-04-02-semantic-context-compression.md` |
| M-M85 | `docs/superpowers/plans/2026-04-08-sb-orchestrated-dev-workflows.md` |
| M-M86 | `docs/superpowers/plans/2026-05-07-pre-release-quality-gate-sidekick.md` |
| M-M87 | `docs/superpowers/plans/2026-05-08-inline-todo-app-full-surface-e2e.md` |
| M-M88 | `docs/superpowers/specs/2026-04-02-semantic-context-compression-design.md` |
| M-M89 | `docs/superpowers/specs/2026-04-08-sb-orchestrated-dev-workflows-design.md` |
| M-M90 | `docs/superpowers/specs/2026-05-08-inline-todo-app-full-surface-e2e-design.md` |
| M-M91 | `docs/task-doc-checklist.json` |
| M-M92 | `docs/tech-debt.md` |
| M-M93 | `docs/workflows/devops-cycle.md` |
| M-M94 | `docs/workflows/full-dev-cycle.md` |
| M-M95 | `silver-bullet.md` |
| M-M96 | `CLAUDE.md` |
| M-M97 | `AGENTS.md` |

### N. templates/ — full `templates/` tree

| ID | Surface |
|----|---------|
| M-N01 | `templates/CHANGELOG-project.md.base` |
| M-N02 | `templates/CLAUDE.md.base` |
| M-N03 | `templates/archive/manifest.md.base` |
| M-N04 | `templates/cursor-rules/silver-orchestrator.mdc` |
| M-N05 | `templates/doc-scheme.json.base` |
| M-N06 | `templates/doc-scheme.md.base` |
| M-N07 | `templates/interface/STATE.md.base` |
| M-N08 | `templates/knowledge/INDEX.md.base` |
| M-N09 | `templates/knowledge/YYYY-MM.md.base` |
| M-N10 | `templates/learnings/YYYY-MM.md.base` |
| M-N11 | `templates/orchestrator-workers/BLAST-RADIUS.md` |
| M-N12 | `templates/orchestrator-workers/BOOTSTRAP.md` |
| M-N13 | `templates/orchestrator-workers/BRANCH-FINISH.md` |
| M-N14 | `templates/orchestrator-workers/CLARIFY.md` |
| M-N15 | `templates/orchestrator-workers/COMPLETION-AUDIT.md` |
| M-N16 | `templates/orchestrator-workers/DEBUG.md` |
| M-N17 | `templates/orchestrator-workers/DECIDE.md` |
| M-N18 | `templates/orchestrator-workers/DESIGN-CONTRACT.md` |
| M-N19 | `templates/orchestrator-workers/DEVOPS-SKILL-ROUTER.md` |
| M-N20 | `templates/orchestrator-workers/DOCUMENT.md` |
| M-N21 | `templates/orchestrator-workers/EXECUTE.md` |
| M-N22 | `templates/orchestrator-workers/FAST.md` |
| M-N23 | `templates/orchestrator-workers/ORIENT.md` |
| M-N24 | `templates/orchestrator-workers/PHASE.md` |
| M-N25 | `templates/orchestrator-workers/PLAN.md` |
| M-N26 | `templates/orchestrator-workers/QUALITY-GATE.md` |
| M-N27 | `templates/orchestrator-workers/RELEASE.md` |
| M-N28 | `templates/orchestrator-workers/REVIEW-REQUEST.md` |
| M-N29 | `templates/orchestrator-workers/REVIEW-TRIAGE.md` |
| M-N30 | `templates/orchestrator-workers/REVIEW.md` |
| M-N31 | `templates/orchestrator-workers/ROUTER.md` |
| M-N32 | `templates/orchestrator-workers/SECURE.md` |
| M-N33 | `templates/orchestrator-workers/SHIP.md` |
| M-N34 | `templates/orchestrator-workers/SPECIFY.md` |
| M-N35 | `templates/orchestrator-workers/UI-QUALITY.md` |
| M-N36 | `templates/orchestrator-workers/VALIDATE.md` |
| M-N37 | `templates/orchestrator-workers/VERIFY.md` |
| M-N38 | `templates/sessions/session-log.md.base` |
| M-N39 | `templates/silver-bullet.config.json.default` |
| M-N40 | `templates/silver-bullet.md.base` |
| M-N41 | `templates/specs/DESIGN.md.template` |
| M-N42 | `templates/specs/REQUIREMENTS.md.template` |
| M-N43 | `templates/specs/SPEC.md.template` |
| M-N44 | `templates/task-doc-checklist.json.base` |
| M-N45 | `templates/workflow.md.base` |
| M-N46 | `templates/workflows/devops-cycle.md` |
| M-N47 | `templates/workflows/full-dev-cycle.md` |

### O. plugins/ + forge/ — install paths and package mirrors

| ID | Surface |
|----|---------|
| M-O01 | `plugins/silver-bullet/.codex-plugin/plugin.json` |
| M-O02 | `plugins/silver-bullet/.cursor-plugin/plugin.json` |
| M-O03 | `plugins/silver-bullet/.silver-bullet.json` |
| M-O04 | `plugins/silver-bullet/AGENTS.md` |
| M-O05 | `plugins/silver-bullet/CHANGELOG.md` |
| M-O06 | `plugins/silver-bullet/CODE_OF_CONDUCT.md` |
| M-O07 | `plugins/silver-bullet/CONTRIBUTING.md` |
| M-O08 | `plugins/silver-bullet/LICENSE` |
| M-O09 | `plugins/silver-bullet/README.md` |
| M-O10 | `plugins/silver-bullet/SECURITY.md` |
| M-O11 | `plugins/silver-bullet/SENTINEL-audit-silver-bullet-v0.15.1.md` |
| M-O12 | `plugins/silver-bullet/SENTINEL-audit-silver-init.md` |
| M-O13 | `plugins/silver-bullet/cursor-hooks.json` |
| M-O14 | `plugins/silver-bullet/skill-source/ai-llm-safety/SILVER_SOURCE` |
| M-O15 | `plugins/silver-bullet/skill-source/artifact-review-assessor/SILVER_SOURCE` |
| M-O16 | `plugins/silver-bullet/skill-source/artifact-reviewer/SILVER_SOURCE` |
| M-O17 | `plugins/silver-bullet/skill-source/artifact-reviewer/rules/review-loop.md` |
| M-O18 | `plugins/silver-bullet/skill-source/artifact-reviewer/rules/reviewer-interface.md` |
| M-O19 | `plugins/silver-bullet/skill-source/devops-quality-gates/SILVER_SOURCE` |
| M-O20 | `plugins/silver-bullet/skill-source/devops-skill-router/SILVER_SOURCE` |
| M-O21 | `plugins/silver-bullet/skill-source/extensibility/SILVER_SOURCE` |
| M-O22 | `plugins/silver-bullet/skill-source/modularity/SILVER_SOURCE` |
| M-O23 | `plugins/silver-bullet/skill-source/progressive-review-loop/SILVER_SOURCE` |
| M-O24 | `plugins/silver-bullet/skill-source/progressive-review-loop/agents/openai.yaml` |
| M-O25 | `plugins/silver-bullet/skill-source/reliability/SILVER_SOURCE` |
| M-O26 | `plugins/silver-bullet/skill-source/reusability/SILVER_SOURCE` |
| M-O27 | `plugins/silver-bullet/skill-source/review-context/SILVER_SOURCE` |
| M-O28 | `plugins/silver-bullet/skill-source/review-cross-artifact/SILVER_SOURCE` |
| M-O29 | `plugins/silver-bullet/skill-source/review-design/SILVER_SOURCE` |
| M-O30 | `plugins/silver-bullet/skill-source/review-ingestion-manifest/SILVER_SOURCE` |
| M-O31 | `plugins/silver-bullet/skill-source/review-plan/SILVER_SOURCE` |
| M-O32 | `plugins/silver-bullet/skill-source/review-requirements/SILVER_SOURCE` |
| M-O33 | `plugins/silver-bullet/skill-source/review-research/SILVER_SOURCE` |
| M-O34 | `plugins/silver-bullet/skill-source/review-roadmap/SILVER_SOURCE` |
| M-O35 | `plugins/silver-bullet/skill-source/review-spec/SILVER_SOURCE` |
| M-O36 | `plugins/silver-bullet/skill-source/review-uat/SILVER_SOURCE` |
| M-O37 | `plugins/silver-bullet/skill-source/review-verification/SILVER_SOURCE` |
| M-O38 | `plugins/silver-bullet/skill-source/scalability/SILVER_SOURCE` |
| M-O39 | `plugins/silver-bullet/skill-source/security/SILVER_SOURCE` |
| M-O40 | `plugins/silver-bullet/skill-source/silver/SILVER_SOURCE` |
| M-O41 | `plugins/silver-bullet/skill-source/silver-add/SILVER_SOURCE` |
| M-O42 | `plugins/silver-bullet/skill-source/silver-benchmark/SILVER_SOURCE` |
| M-O43 | `plugins/silver-bullet/skill-source/silver-blast-radius/SILVER_SOURCE` |
| M-O44 | `plugins/silver-bullet/skill-source/silver-bootstrap-milestone/SILVER_SOURCE` |
| M-O45 | `plugins/silver-bullet/skill-source/silver-bootstrap-project/SILVER_SOURCE` |
| M-O46 | `plugins/silver-bullet/skill-source/silver-branch-finish/SILVER_SOURCE` |
| M-O47 | `plugins/silver-bullet/skill-source/silver-bugfix/SILVER_SOURCE` |
| M-O48 | `plugins/silver-bullet/skill-source/silver-canary/SILVER_SOURCE` |
| M-O49 | `plugins/silver-bullet/skill-source/silver-clarify/SILVER_SOURCE` |
| M-O50 | `plugins/silver-bullet/skill-source/silver-completion-audit/SILVER_SOURCE` |
| M-O51 | `plugins/silver-bullet/skill-source/silver-content/SILVER_SOURCE` |
| M-O52 | `plugins/silver-bullet/skill-source/silver-context/SILVER_SOURCE` |
| M-O53 | `plugins/silver-bullet/skill-source/silver-create-release/SILVER_SOURCE` |
| M-O54 | `plugins/silver-bullet/skill-source/silver-debug/SILVER_SOURCE` |
| M-O55 | `plugins/silver-bullet/skill-source/silver-deploy/SILVER_SOURCE` |
| M-O56 | `plugins/silver-bullet/skill-source/silver-devops/SILVER_SOURCE` |
| M-O57 | `plugins/silver-bullet/skill-source/silver-domain-audit/SILVER_SOURCE` |
| M-O58 | `plugins/silver-bullet/skill-source/silver-ensure-docs/SILVER_SOURCE` |
| M-O59 | `plugins/silver-bullet/skill-source/silver-execute/SILVER_SOURCE` |
| M-O60 | `plugins/silver-bullet/skill-source/silver-fast/SILVER_SOURCE` |
| M-O61 | `plugins/silver-bullet/skill-source/silver-feature/SILVER_SOURCE` |
| M-O62 | `plugins/silver-bullet/skill-source/silver-feature/references/supervision-loop.md` |
| M-O63 | `plugins/silver-bullet/skill-source/silver-forensics/SILVER_SOURCE` |
| M-O64 | `plugins/silver-bullet/skill-source/silver-handoff/SILVER_SOURCE` |
| M-O65 | `plugins/silver-bullet/skill-source/silver-incident/SILVER_SOURCE` |
| M-O66 | `plugins/silver-bullet/skill-source/silver-ingest/SILVER_SOURCE` |
| M-O67 | `plugins/silver-bullet/skill-source/silver-init/SILVER_SOURCE` |
| M-O68 | `plugins/silver-bullet/skill-source/silver-init/references/ci-templates.md` |
| M-O69 | `plugins/silver-bullet/skill-source/silver-init/references/doc-migration.md` |
| M-O70 | `plugins/silver-bullet/skill-source/silver-init/references/scaffold-steps.md` |
| M-O71 | `plugins/silver-bullet/skill-source/silver-init/references/stack-detection.md` |
| M-O72 | `plugins/silver-bullet/skill-source/silver-init/scripts/merge-cursor-hooks.py` |
| M-O73 | `plugins/silver-bullet/skill-source/silver-init/scripts/merge-hooks.py` |
| M-O74 | `plugins/silver-bullet/skill-source/silver-migrate/SILVER_SOURCE` |
| M-O75 | `plugins/silver-bullet/skill-source/silver-orchestrator/SILVER_SOURCE` |
| M-O76 | `plugins/silver-bullet/skill-source/silver-orient/SILVER_SOURCE` |
| M-O77 | `plugins/silver-bullet/skill-source/silver-phase/SILVER_SOURCE` |
| M-O78 | `plugins/silver-bullet/skill-source/silver-plan/SILVER_SOURCE` |
| M-O79 | `plugins/silver-bullet/skill-source/silver-quality-gates/SILVER_SOURCE` |
| M-O80 | `plugins/silver-bullet/skill-source/silver-refactor/SILVER_SOURCE` |
| M-O81 | `plugins/silver-bullet/skill-source/silver-release/SILVER_SOURCE` |
| M-O82 | `plugins/silver-bullet/skill-source/silver-rem/SILVER_SOURCE` |
| M-O83 | `plugins/silver-bullet/skill-source/silver-remove/SILVER_SOURCE` |
| M-O84 | `plugins/silver-bullet/skill-source/silver-research/SILVER_SOURCE` |
| M-O85 | `plugins/silver-bullet/skill-source/silver-retro/SILVER_SOURCE` |
| M-O86 | `plugins/silver-bullet/skill-source/silver-review/SILVER_SOURCE` |
| M-O87 | `plugins/silver-bullet/skill-source/silver-review-request/SILVER_SOURCE` |
| M-O88 | `plugins/silver-bullet/skill-source/silver-review-stats/SILVER_SOURCE` |
| M-O89 | `plugins/silver-bullet/skill-source/silver-review-triage/SILVER_SOURCE` |
| M-O90 | `plugins/silver-bullet/skill-source/silver-scan/SILVER_SOURCE` |
| M-O91 | `plugins/silver-bullet/skill-source/silver-secure/SILVER_SOURCE` |
| M-O92 | `plugins/silver-bullet/skill-source/silver-ship/SILVER_SOURCE` |
| M-O93 | `plugins/silver-bullet/skill-source/silver-spec/SILVER_SOURCE` |
| M-O94 | `plugins/silver-bullet/skill-source/silver-spike/SILVER_SOURCE` |
| M-O95 | `plugins/silver-bullet/skill-source/silver-test/SILVER_SOURCE` |
| M-O96 | `plugins/silver-bullet/skill-source/silver-thread/SILVER_SOURCE` |
| M-O97 | `plugins/silver-bullet/skill-source/silver-ui/SILVER_SOURCE` |
| M-O98 | `plugins/silver-bullet/skill-source/silver-ui-contract/SILVER_SOURCE` |
| M-O99 | `plugins/silver-bullet/skill-source/silver-ui-review/SILVER_SOURCE` |
| M-O100 | `plugins/silver-bullet/skill-source/silver-undo/SILVER_SOURCE` |
| M-O101 | `plugins/silver-bullet/skill-source/silver-update/SILVER_SOURCE` |
| M-O102 | `plugins/silver-bullet/skill-source/silver-validate/SILVER_SOURCE` |
| M-O103 | `plugins/silver-bullet/skill-source/silver-verify/SILVER_SOURCE` |
| M-O104 | `plugins/silver-bullet/skill-source/silver-worktree/SILVER_SOURCE` |
| M-O105 | `plugins/silver-bullet/skill-source/tdd/SILVER_SOURCE` |
| M-O106 | `plugins/silver-bullet/skill-source/testability/SILVER_SOURCE` |
| M-O107 | `plugins/silver-bullet/skill-source/usability/SILVER_SOURCE` |
| M-O108 | `plugins/silver-bullet/skill-source/verify-tests/SILVER_SOURCE` |
| M-O109 | `plugins/silver-bullet/templates/CHANGELOG-project.md.base` |
| M-O110 | `plugins/silver-bullet/templates/CLAUDE.md.base` |
| M-O111 | `plugins/silver-bullet/templates/archive/manifest.md.base` |
| M-O112 | `plugins/silver-bullet/templates/cursor-rules/silver-orchestrator.mdc` |
| M-O113 | `plugins/silver-bullet/templates/doc-scheme.json.base` |
| M-O114 | `plugins/silver-bullet/templates/doc-scheme.md.base` |
| M-O115 | `plugins/silver-bullet/templates/interface/STATE.md.base` |
| M-O116 | `plugins/silver-bullet/templates/knowledge/INDEX.md.base` |
| M-O117 | `plugins/silver-bullet/templates/knowledge/YYYY-MM.md.base` |
| M-O118 | `plugins/silver-bullet/templates/learnings/YYYY-MM.md.base` |
| M-O119 | `plugins/silver-bullet/templates/orchestrator-workers/BLAST-RADIUS.md` |
| M-O120 | `plugins/silver-bullet/templates/orchestrator-workers/BOOTSTRAP.md` |
| M-O121 | `plugins/silver-bullet/templates/orchestrator-workers/BRANCH-FINISH.md` |
| M-O122 | `plugins/silver-bullet/templates/orchestrator-workers/CLARIFY.md` |
| M-O123 | `plugins/silver-bullet/templates/orchestrator-workers/COMPLETION-AUDIT.md` |
| M-O124 | `plugins/silver-bullet/templates/orchestrator-workers/DEBUG.md` |
| M-O125 | `plugins/silver-bullet/templates/orchestrator-workers/DECIDE.md` |
| M-O126 | `plugins/silver-bullet/templates/orchestrator-workers/DESIGN-CONTRACT.md` |
| M-O127 | `plugins/silver-bullet/templates/orchestrator-workers/DEVOPS-SKILL-ROUTER.md` |
| M-O128 | `plugins/silver-bullet/templates/orchestrator-workers/DOCUMENT.md` |
| M-O129 | `plugins/silver-bullet/templates/orchestrator-workers/EXECUTE.md` |
| M-O130 | `plugins/silver-bullet/templates/orchestrator-workers/FAST.md` |
| M-O131 | `plugins/silver-bullet/templates/orchestrator-workers/ORIENT.md` |
| M-O132 | `plugins/silver-bullet/templates/orchestrator-workers/PHASE.md` |
| M-O133 | `plugins/silver-bullet/templates/orchestrator-workers/PLAN.md` |
| M-O134 | `plugins/silver-bullet/templates/orchestrator-workers/QUALITY-GATE.md` |
| M-O135 | `plugins/silver-bullet/templates/orchestrator-workers/RELEASE.md` |
| M-O136 | `plugins/silver-bullet/templates/orchestrator-workers/REVIEW-REQUEST.md` |
| M-O137 | `plugins/silver-bullet/templates/orchestrator-workers/REVIEW-TRIAGE.md` |
| M-O138 | `plugins/silver-bullet/templates/orchestrator-workers/REVIEW.md` |
| M-O139 | `plugins/silver-bullet/templates/orchestrator-workers/ROUTER.md` |
| M-O140 | `plugins/silver-bullet/templates/orchestrator-workers/SECURE.md` |
| M-O141 | `plugins/silver-bullet/templates/orchestrator-workers/SHIP.md` |
| M-O142 | `plugins/silver-bullet/templates/orchestrator-workers/SPECIFY.md` |
| M-O143 | `plugins/silver-bullet/templates/orchestrator-workers/UI-QUALITY.md` |
| M-O144 | `plugins/silver-bullet/templates/orchestrator-workers/VALIDATE.md` |
| M-O145 | `plugins/silver-bullet/templates/orchestrator-workers/VERIFY.md` |
| M-O146 | `plugins/silver-bullet/templates/sessions/session-log.md.base` |
| M-O147 | `plugins/silver-bullet/templates/silver-bullet.config.json.default` |
| M-O148 | `plugins/silver-bullet/templates/silver-bullet.md.base` |
| M-O149 | `plugins/silver-bullet/templates/specs/DESIGN.md.template` |
| M-O150 | `plugins/silver-bullet/templates/specs/REQUIREMENTS.md.template` |
| M-O151 | `plugins/silver-bullet/templates/specs/SPEC.md.template` |
| M-O152 | `plugins/silver-bullet/templates/task-doc-checklist.json.base` |
| M-O153 | `plugins/silver-bullet/templates/workflow.md.base` |
| M-O154 | `plugins/silver-bullet/templates/workflows/devops-cycle.md` |
| M-O155 | `plugins/silver-bullet/templates/workflows/full-dev-cycle.md` |
| M-O156 | `forge/alo-labs-cursor-marketplace/.cursor-plugin/marketplace.json` |
| M-O157 | `forge/alo-labs-cursor-marketplace/README.md` |

### P. agents/ — `agents/codex/`, `agents/cursor/`, `agents/claude/` bundles

| ID | Surface |
|----|---------|
| M-P01 | `agents/codex/ai-llm-safety/SKILL.md` |
| M-P02 | `agents/codex/artifact-review-assessor/SKILL.md` |
| M-P03 | `agents/codex/artifact-reviewer/SKILL.md` |
| M-P04 | `agents/codex/artifact-reviewer/rules/review-loop.md` |
| M-P05 | `agents/codex/artifact-reviewer/rules/reviewer-interface.md` |
| M-P06 | `agents/codex/devops-quality-gates/SKILL.md` |
| M-P07 | `agents/codex/devops-skill-router/SKILL.md` |
| M-P08 | `agents/codex/extensibility/SKILL.md` |
| M-P09 | `agents/codex/modularity/SKILL.md` |
| M-P10 | `agents/codex/progressive-review-loop/SKILL.md` |
| M-P11 | `agents/codex/progressive-review-loop/agents/openai.yaml` |
| M-P12 | `agents/codex/reliability/SKILL.md` |
| M-P13 | `agents/codex/reusability/SKILL.md` |
| M-P14 | `agents/codex/review-context/SKILL.md` |
| M-P15 | `agents/codex/review-cross-artifact/SKILL.md` |
| M-P16 | `agents/codex/review-design/SKILL.md` |
| M-P17 | `agents/codex/review-ingestion-manifest/SKILL.md` |
| M-P18 | `agents/codex/review-plan/SKILL.md` |
| M-P19 | `agents/codex/review-requirements/SKILL.md` |
| M-P20 | `agents/codex/review-research/SKILL.md` |
| M-P21 | `agents/codex/review-roadmap/SKILL.md` |
| M-P22 | `agents/codex/review-spec/SKILL.md` |
| M-P23 | `agents/codex/review-uat/SKILL.md` |
| M-P24 | `agents/codex/review-verification/SKILL.md` |
| M-P25 | `agents/codex/scalability/SKILL.md` |
| M-P26 | `agents/codex/security/SKILL.md` |
| M-P27 | `agents/codex/silver/SKILL.md` |
| M-P28 | `agents/codex/silver-add/SKILL.md` |
| M-P29 | `agents/codex/silver-benchmark/SKILL.md` |
| M-P30 | `agents/codex/silver-blast-radius/SKILL.md` |
| M-P31 | `agents/codex/silver-bootstrap-milestone/SKILL.md` |
| M-P32 | `agents/codex/silver-bootstrap-project/SKILL.md` |
| M-P33 | `agents/codex/silver-branch-finish/SKILL.md` |
| M-P34 | `agents/codex/silver-bugfix/SKILL.md` |
| M-P35 | `agents/codex/silver-canary/SKILL.md` |
| M-P36 | `agents/codex/silver-clarify/SKILL.md` |
| M-P37 | `agents/codex/silver-completion-audit/SKILL.md` |
| M-P38 | `agents/codex/silver-content/SKILL.md` |
| M-P39 | `agents/codex/silver-context/SKILL.md` |
| M-P40 | `agents/codex/silver-create-release/SKILL.md` |
| M-P41 | `agents/codex/silver-debug/SKILL.md` |
| M-P42 | `agents/codex/silver-deploy/SKILL.md` |
| M-P43 | `agents/codex/silver-devops/SKILL.md` |
| M-P44 | `agents/codex/silver-domain-audit/SKILL.md` |
| M-P45 | `agents/codex/silver-ensure-docs/SKILL.md` |
| M-P46 | `agents/codex/silver-execute/SKILL.md` |
| M-P47 | `agents/codex/silver-fast/SKILL.md` |
| M-P48 | `agents/codex/silver-feature/SKILL.md` |
| M-P49 | `agents/codex/silver-feature/references/supervision-loop.md` |
| M-P50 | `agents/codex/silver-forensics/SKILL.md` |
| M-P51 | `agents/codex/silver-handoff/SKILL.md` |
| M-P52 | `agents/codex/silver-incident/SKILL.md` |
| M-P53 | `agents/codex/silver-ingest/SKILL.md` |
| M-P54 | `agents/codex/silver-init/SKILL.md` |
| M-P55 | `agents/codex/silver-init/references/ci-templates.md` |
| M-P56 | `agents/codex/silver-init/references/doc-migration.md` |
| M-P57 | `agents/codex/silver-init/references/scaffold-steps.md` |
| M-P58 | `agents/codex/silver-init/references/stack-detection.md` |
| M-P59 | `agents/codex/silver-init/scripts/merge-cursor-hooks.py` |
| M-P60 | `agents/codex/silver-init/scripts/merge-hooks.py` |
| M-P61 | `agents/codex/silver-migrate/SKILL.md` |
| M-P62 | `agents/codex/silver-orchestrator/SKILL.md` |
| M-P63 | `agents/codex/silver-orient/SKILL.md` |
| M-P64 | `agents/codex/silver-phase/SKILL.md` |
| M-P65 | `agents/codex/silver-plan/SKILL.md` |
| M-P66 | `agents/codex/silver-quality-gates/SKILL.md` |
| M-P67 | `agents/codex/silver-refactor/SKILL.md` |
| M-P68 | `agents/codex/silver-release/SKILL.md` |
| M-P69 | `agents/codex/silver-rem/SKILL.md` |
| M-P70 | `agents/codex/silver-remove/SKILL.md` |
| M-P71 | `agents/codex/silver-research/SKILL.md` |
| M-P72 | `agents/codex/silver-retro/SKILL.md` |
| M-P73 | `agents/codex/silver-review/SKILL.md` |
| M-P74 | `agents/codex/silver-review-request/SKILL.md` |
| M-P75 | `agents/codex/silver-review-stats/SKILL.md` |
| M-P76 | `agents/codex/silver-review-triage/SKILL.md` |
| M-P77 | `agents/codex/silver-scan/SKILL.md` |
| M-P78 | `agents/codex/silver-secure/SKILL.md` |
| M-P79 | `agents/codex/silver-ship/SKILL.md` |
| M-P80 | `agents/codex/silver-spec/SKILL.md` |
| M-P81 | `agents/codex/silver-spike/SKILL.md` |
| M-P82 | `agents/codex/silver-test/SKILL.md` |
| M-P83 | `agents/codex/silver-thread/SKILL.md` |
| M-P84 | `agents/codex/silver-ui/SKILL.md` |
| M-P85 | `agents/codex/silver-ui-contract/SKILL.md` |
| M-P86 | `agents/codex/silver-ui-review/SKILL.md` |
| M-P87 | `agents/codex/silver-undo/SKILL.md` |
| M-P88 | `agents/codex/silver-update/SKILL.md` |
| M-P89 | `agents/codex/silver-validate/SKILL.md` |
| M-P90 | `agents/codex/silver-verify/SKILL.md` |
| M-P91 | `agents/codex/silver-worktree/SKILL.md` |
| M-P92 | `agents/codex/tdd/SKILL.md` |
| M-P93 | `agents/codex/testability/SKILL.md` |
| M-P94 | `agents/codex/usability/SKILL.md` |
| M-P95 | `agents/codex/verify-tests/SKILL.md` |
| M-P96 | `agents/cursor/ai-llm-safety/SKILL.md` |
| M-P97 | `agents/cursor/artifact-review-assessor/SKILL.md` |
| M-P98 | `agents/cursor/artifact-reviewer/SKILL.md` |
| M-P99 | `agents/cursor/artifact-reviewer/rules/review-loop.md` |
| M-P100 | `agents/cursor/artifact-reviewer/rules/reviewer-interface.md` |
| M-P101 | `agents/cursor/devops-quality-gates/SKILL.md` |
| M-P102 | `agents/cursor/devops-skill-router/SKILL.md` |
| M-P103 | `agents/cursor/extensibility/SKILL.md` |
| M-P104 | `agents/cursor/modularity/SKILL.md` |
| M-P105 | `agents/cursor/progressive-review-loop/SKILL.md` |
| M-P106 | `agents/cursor/reliability/SKILL.md` |
| M-P107 | `agents/cursor/reusability/SKILL.md` |
| M-P108 | `agents/cursor/review-context/SKILL.md` |
| M-P109 | `agents/cursor/review-cross-artifact/SKILL.md` |
| M-P110 | `agents/cursor/review-design/SKILL.md` |
| M-P111 | `agents/cursor/review-ingestion-manifest/SKILL.md` |
| M-P112 | `agents/cursor/review-plan/SKILL.md` |
| M-P113 | `agents/cursor/review-requirements/SKILL.md` |
| M-P114 | `agents/cursor/review-research/SKILL.md` |
| M-P115 | `agents/cursor/review-roadmap/SKILL.md` |
| M-P116 | `agents/cursor/review-spec/SKILL.md` |
| M-P117 | `agents/cursor/review-uat/SKILL.md` |
| M-P118 | `agents/cursor/review-verification/SKILL.md` |
| M-P119 | `agents/cursor/scalability/SKILL.md` |
| M-P120 | `agents/cursor/security/SKILL.md` |
| M-P121 | `agents/cursor/silver/SKILL.md` |
| M-P122 | `agents/cursor/silver-add/SKILL.md` |
| M-P123 | `agents/cursor/silver-benchmark/SKILL.md` |
| M-P124 | `agents/cursor/silver-blast-radius/SKILL.md` |
| M-P125 | `agents/cursor/silver-bootstrap-milestone/SKILL.md` |
| M-P126 | `agents/cursor/silver-bootstrap-project/SKILL.md` |
| M-P127 | `agents/cursor/silver-branch-finish/SKILL.md` |
| M-P128 | `agents/cursor/silver-bugfix/SKILL.md` |
| M-P129 | `agents/cursor/silver-canary/SKILL.md` |
| M-P130 | `agents/cursor/silver-clarify/SKILL.md` |
| M-P131 | `agents/cursor/silver-completion-audit/SKILL.md` |
| M-P132 | `agents/cursor/silver-content/SKILL.md` |
| M-P133 | `agents/cursor/silver-context/SKILL.md` |
| M-P134 | `agents/cursor/silver-create-release/SKILL.md` |
| M-P135 | `agents/cursor/silver-debug/SKILL.md` |
| M-P136 | `agents/cursor/silver-deploy/SKILL.md` |
| M-P137 | `agents/cursor/silver-devops/SKILL.md` |
| M-P138 | `agents/cursor/silver-domain-audit/SKILL.md` |
| M-P139 | `agents/cursor/silver-ensure-docs/SKILL.md` |
| M-P140 | `agents/cursor/silver-execute/SKILL.md` |
| M-P141 | `agents/cursor/silver-fast/SKILL.md` |
| M-P142 | `agents/cursor/silver-feature/SKILL.md` |
| M-P143 | `agents/cursor/silver-feature/references/supervision-loop.md` |
| M-P144 | `agents/cursor/silver-forensics/SKILL.md` |
| M-P145 | `agents/cursor/silver-handoff/SKILL.md` |
| M-P146 | `agents/cursor/silver-incident/SKILL.md` |
| M-P147 | `agents/cursor/silver-ingest/SKILL.md` |
| M-P148 | `agents/cursor/silver-init/SKILL.md` |
| M-P149 | `agents/cursor/silver-init/references/ci-templates.md` |
| M-P150 | `agents/cursor/silver-init/references/doc-migration.md` |
| M-P151 | `agents/cursor/silver-init/references/scaffold-steps.md` |
| M-P152 | `agents/cursor/silver-init/references/stack-detection.md` |
| M-P153 | `agents/cursor/silver-init/scripts/merge-cursor-hooks.py` |
| M-P154 | `agents/cursor/silver-init/scripts/merge-hooks.py` |
| M-P155 | `agents/cursor/silver-migrate/SKILL.md` |
| M-P156 | `agents/cursor/silver-orchestrator/SKILL.md` |
| M-P157 | `agents/cursor/silver-orient/SKILL.md` |
| M-P158 | `agents/cursor/silver-phase/SKILL.md` |
| M-P159 | `agents/cursor/silver-plan/SKILL.md` |
| M-P160 | `agents/cursor/silver-quality-gates/SKILL.md` |
| M-P161 | `agents/cursor/silver-refactor/SKILL.md` |
| M-P162 | `agents/cursor/silver-release/SKILL.md` |
| M-P163 | `agents/cursor/silver-rem/SKILL.md` |
| M-P164 | `agents/cursor/silver-remove/SKILL.md` |
| M-P165 | `agents/cursor/silver-research/SKILL.md` |
| M-P166 | `agents/cursor/silver-retro/SKILL.md` |
| M-P167 | `agents/cursor/silver-review/SKILL.md` |
| M-P168 | `agents/cursor/silver-review-request/SKILL.md` |
| M-P169 | `agents/cursor/silver-review-stats/SKILL.md` |
| M-P170 | `agents/cursor/silver-review-triage/SKILL.md` |
| M-P171 | `agents/cursor/silver-scan/SKILL.md` |
| M-P172 | `agents/cursor/silver-secure/SKILL.md` |
| M-P173 | `agents/cursor/silver-ship/SKILL.md` |
| M-P174 | `agents/cursor/silver-spec/SKILL.md` |
| M-P175 | `agents/cursor/silver-spike/SKILL.md` |
| M-P176 | `agents/cursor/silver-test/SKILL.md` |
| M-P177 | `agents/cursor/silver-thread/SKILL.md` |
| M-P178 | `agents/cursor/silver-ui/SKILL.md` |
| M-P179 | `agents/cursor/silver-ui-contract/SKILL.md` |
| M-P180 | `agents/cursor/silver-ui-review/SKILL.md` |
| M-P181 | `agents/cursor/silver-undo/SKILL.md` |
| M-P182 | `agents/cursor/silver-update/SKILL.md` |
| M-P183 | `agents/cursor/silver-validate/SKILL.md` |
| M-P184 | `agents/cursor/silver-verify/SKILL.md` |
| M-P185 | `agents/cursor/silver-worktree/SKILL.md` |
| M-P186 | `agents/cursor/tdd/SKILL.md` |
| M-P187 | `agents/cursor/testability/SKILL.md` |
| M-P188 | `agents/cursor/usability/SKILL.md` |
| M-P189 | `agents/cursor/verify-tests/SKILL.md` |
| M-P190 | `agents/claude/ai-llm-safety/SKILL.md` |
| M-P191 | `agents/claude/artifact-review-assessor/SKILL.md` |
| M-P192 | `agents/claude/artifact-reviewer/SKILL.md` |
| M-P193 | `agents/claude/artifact-reviewer/rules/review-loop.md` |
| M-P194 | `agents/claude/artifact-reviewer/rules/reviewer-interface.md` |
| M-P195 | `agents/claude/devops-quality-gates/SKILL.md` |
| M-P196 | `agents/claude/devops-skill-router/SKILL.md` |
| M-P197 | `agents/claude/extensibility/SKILL.md` |
| M-P198 | `agents/claude/modularity/SKILL.md` |
| M-P199 | `agents/claude/progressive-review-loop/SKILL.md` |
| M-P200 | `agents/claude/reliability/SKILL.md` |
| M-P201 | `agents/claude/reusability/SKILL.md` |
| M-P202 | `agents/claude/review-context/SKILL.md` |
| M-P203 | `agents/claude/review-cross-artifact/SKILL.md` |
| M-P204 | `agents/claude/review-design/SKILL.md` |
| M-P205 | `agents/claude/review-ingestion-manifest/SKILL.md` |
| M-P206 | `agents/claude/review-plan/SKILL.md` |
| M-P207 | `agents/claude/review-requirements/SKILL.md` |
| M-P208 | `agents/claude/review-research/SKILL.md` |
| M-P209 | `agents/claude/review-roadmap/SKILL.md` |
| M-P210 | `agents/claude/review-spec/SKILL.md` |
| M-P211 | `agents/claude/review-uat/SKILL.md` |
| M-P212 | `agents/claude/review-verification/SKILL.md` |
| M-P213 | `agents/claude/scalability/SKILL.md` |
| M-P214 | `agents/claude/security/SKILL.md` |
| M-P215 | `agents/claude/silver/SKILL.md` |
| M-P216 | `agents/claude/silver-add/SKILL.md` |
| M-P217 | `agents/claude/silver-benchmark/SKILL.md` |
| M-P218 | `agents/claude/silver-blast-radius/SKILL.md` |
| M-P219 | `agents/claude/silver-bootstrap-milestone/SKILL.md` |
| M-P220 | `agents/claude/silver-bootstrap-project/SKILL.md` |
| M-P221 | `agents/claude/silver-branch-finish/SKILL.md` |
| M-P222 | `agents/claude/silver-bugfix/SKILL.md` |
| M-P223 | `agents/claude/silver-canary/SKILL.md` |
| M-P224 | `agents/claude/silver-clarify/SKILL.md` |
| M-P225 | `agents/claude/silver-completion-audit/SKILL.md` |
| M-P226 | `agents/claude/silver-content/SKILL.md` |
| M-P227 | `agents/claude/silver-context/SKILL.md` |
| M-P228 | `agents/claude/silver-create-release/SKILL.md` |
| M-P229 | `agents/claude/silver-debug/SKILL.md` |
| M-P230 | `agents/claude/silver-deploy/SKILL.md` |
| M-P231 | `agents/claude/silver-devops/SKILL.md` |
| M-P232 | `agents/claude/silver-domain-audit/SKILL.md` |
| M-P233 | `agents/claude/silver-ensure-docs/SKILL.md` |
| M-P234 | `agents/claude/silver-execute/SKILL.md` |
| M-P235 | `agents/claude/silver-fast/SKILL.md` |
| M-P236 | `agents/claude/silver-feature/SKILL.md` |
| M-P237 | `agents/claude/silver-feature/references/supervision-loop.md` |
| M-P238 | `agents/claude/silver-forensics/SKILL.md` |
| M-P239 | `agents/claude/silver-handoff/SKILL.md` |
| M-P240 | `agents/claude/silver-incident/SKILL.md` |
| M-P241 | `agents/claude/silver-ingest/SKILL.md` |
| M-P242 | `agents/claude/silver-init/SKILL.md` |
| M-P243 | `agents/claude/silver-init/references/ci-templates.md` |
| M-P244 | `agents/claude/silver-init/references/doc-migration.md` |
| M-P245 | `agents/claude/silver-init/references/scaffold-steps.md` |
| M-P246 | `agents/claude/silver-init/references/stack-detection.md` |
| M-P247 | `agents/claude/silver-init/scripts/merge-cursor-hooks.py` |
| M-P248 | `agents/claude/silver-init/scripts/merge-hooks.py` |
| M-P249 | `agents/claude/silver-migrate/SKILL.md` |
| M-P250 | `agents/claude/silver-orchestrator/SKILL.md` |
| M-P251 | `agents/claude/silver-orient/SKILL.md` |
| M-P252 | `agents/claude/silver-phase/SKILL.md` |
| M-P253 | `agents/claude/silver-plan/SKILL.md` |
| M-P254 | `agents/claude/silver-quality-gates/SKILL.md` |
| M-P255 | `agents/claude/silver-refactor/SKILL.md` |
| M-P256 | `agents/claude/silver-release/SKILL.md` |
| M-P257 | `agents/claude/silver-rem/SKILL.md` |
| M-P258 | `agents/claude/silver-remove/SKILL.md` |
| M-P259 | `agents/claude/silver-research/SKILL.md` |
| M-P260 | `agents/claude/silver-retro/SKILL.md` |
| M-P261 | `agents/claude/silver-review/SKILL.md` |
| M-P262 | `agents/claude/silver-review-request/SKILL.md` |
| M-P263 | `agents/claude/silver-review-stats/SKILL.md` |
| M-P264 | `agents/claude/silver-review-triage/SKILL.md` |
| M-P265 | `agents/claude/silver-scan/SKILL.md` |
| M-P266 | `agents/claude/silver-secure/SKILL.md` |
| M-P267 | `agents/claude/silver-ship/SKILL.md` |
| M-P268 | `agents/claude/silver-spec/SKILL.md` |
| M-P269 | `agents/claude/silver-spike/SKILL.md` |
| M-P270 | `agents/claude/silver-test/SKILL.md` |
| M-P271 | `agents/claude/silver-thread/SKILL.md` |
| M-P272 | `agents/claude/silver-ui/SKILL.md` |
| M-P273 | `agents/claude/silver-ui-contract/SKILL.md` |
| M-P274 | `agents/claude/silver-ui-review/SKILL.md` |
| M-P275 | `agents/claude/silver-undo/SKILL.md` |
| M-P276 | `agents/claude/silver-update/SKILL.md` |
| M-P277 | `agents/claude/silver-validate/SKILL.md` |
| M-P278 | `agents/claude/silver-verify/SKILL.md` |
| M-P279 | `agents/claude/silver-worktree/SKILL.md` |
| M-P280 | `agents/claude/tdd/SKILL.md` |
| M-P281 | `agents/claude/testability/SKILL.md` |
| M-P282 | `agents/claude/usability/SKILL.md` |
| M-P283 | `agents/claude/verify-tests/SKILL.md` |

### Q. site/ — public site

| ID | Surface |
|----|---------|
| M-Q01 | `site/.codex/launch.json` |
| M-Q02 | `site/CNAME` |
| M-Q03 | `site/brute/index.html` |
| M-Q04 | `site/bullet-grok2.jpg` |
| M-Q05 | `site/bullet-new.png` |
| M-Q06 | `site/bullet-v1.png` |
| M-Q07 | `site/bullet.jpg` |
| M-Q08 | `site/bullet.png` |
| M-Q09 | `site/cDioQ.jpg` |
| M-Q10 | `site/extract_bullet2.py` |
| M-Q11 | `site/favicon.ico` |
| M-Q12 | `site/favicon.png` |
| M-Q13 | `site/fred-brooks.jpg` |
| M-Q14 | `site/gen_bullet.py` |
| M-Q15 | `site/help/common.js` |
| M-Q16 | `site/help/concepts/artifact-review-assessor.html` |
| M-Q17 | `site/help/concepts/composable-workflow.html` |
| M-Q18 | `site/help/concepts/cost-optimization.html` |
| M-Q19 | `site/help/concepts/documentation.html` |
| M-Q20 | `site/help/concepts/index.html` |
| M-Q21 | `site/help/concepts/preferences.html` |
| M-Q22 | `site/help/concepts/routing-logic.html` |
| M-Q23 | `site/help/concepts/session-startup.html` |
| M-Q24 | `site/help/concepts/verification.html` |
| M-Q25 | `site/help/dev-workflow/index.html` |
| M-Q26 | `site/help/devops-workflow/index.html` |
| M-Q27 | `site/help/getting-started/index.html` |
| M-Q28 | `site/help/index.html` |
| M-Q29 | `site/help/reference/index.html` |
| M-Q30 | `site/help/search.js` |
| M-Q31 | `site/help/troubleshooting/index.html` |
| M-Q32 | `site/help/workflows/index.html` |
| M-Q33 | `site/help/workflows/silver-bugfix.html` |
| M-Q34 | `site/help/workflows/silver-clarify.html` |
| M-Q35 | `site/help/workflows/silver-devops.html` |
| M-Q36 | `site/help/workflows/silver-fast.html` |
| M-Q37 | `site/help/workflows/silver-feature.html` |
| M-Q38 | `site/help/workflows/silver-ingest.html` |
| M-Q39 | `site/help/workflows/silver-release.html` |
| M-Q40 | `site/help/workflows/silver-research.html` |
| M-Q41 | `site/help/workflows/silver-spec.html` |
| M-Q42 | `site/help/workflows/silver-ui.html` |
| M-Q43 | `site/help/workflows/silver-validate.html` |
| M-Q44 | `site/index.html` |
| M-Q45 | `site/logo.png` |
| M-Q46 | `site/neutral-variants.css` |
| M-Q47 | `site/og-card.html` |
| M-Q48 | `site/og-image.png` |
| M-Q49 | `site/silver-bullet.png` |
| M-Q50 | `site/tokens.css` |

### R. tests/ — coverage inventory and documented gaps

| ID | Surface |
|----|---------|
| M-R001 | `tests/docs/test-documentation-scheme.sh` |
| M-R002 | `tests/e2e-live/README.md` |
| M-R003 | `tests/e2e-live/SKIP.md` |
| M-R004 | `tests/e2e-live/dependency-access-preflight.sh` |
| M-R005 | `tests/e2e-live/helpers.sh` |
| M-R006 | `tests/e2e-live/hook-delivery-preflight.sh` |
| M-R007 | `tests/e2e-live/lib/coverage-ledger.sh` |
| M-R008 | `tests/e2e-live/lib/skill-prompt.sh` |
| M-R009 | `tests/e2e-live/lib/turn-driver.sh` |
| M-R010 | `tests/e2e-live/run-e2e-live-tests.sh` |
| M-R011 | `tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh` |
| M-R012 | `tests/e2e-live/scenarios/test-e2e-live-hook-failures.sh` |
| M-R013 | `tests/e2e-live/test-e2e-live-ledger.sh` |
| M-R014 | `tests/e2e-live/test-e2e-live-suite.sh` |
| M-R015 | `tests/e2e-smoke-test.md` |
| M-R016 | `tests/hooks/test-artifact-substance-gate.sh` |
| M-R017 | `tests/hooks/test-ci-status-check.sh` |
| M-R018 | `tests/hooks/test-codex-runtime-bootstrap.sh` |
| M-R019 | `tests/hooks/test-completion-audit.sh` |
| M-R020 | `tests/hooks/test-compliance-status.sh` |
| M-R021 | `tests/hooks/test-core-rules-integrity.sh` |
| M-R022 | `tests/hooks/test-cursor-hook-bridge.sh` |
| M-R023 | `tests/hooks/test-cursor-runtime-bootstrap.sh` |
| M-R024 | `tests/hooks/test-debug-dump.sh` |
| M-R025 | `tests/hooks/test-dependency-skill-check.sh` |
| M-R026 | `tests/hooks/test-dev-cycle-check.sh` |
| M-R027 | `tests/hooks/test-enforcement-tier.sh` |
| M-R028 | `tests/hooks/test-flow-advance.sh` |
| M-R029 | `tests/hooks/test-forbidden-skill-check.sh` |
| M-R030 | `tests/hooks/test-hook-audit.sh` |
| M-R031 | `tests/hooks/test-hook-bridge-err-trap.sh` |
| M-R032 | `tests/hooks/test-industry-tooling-hint.sh` |
| M-R033 | `tests/hooks/test-instruction-file-guard.sh` |
| M-R034 | `tests/hooks/test-kay-project-hook-bridge.sh` |
| M-R035 | `tests/hooks/test-legacy-skill-alias.sh` |
| M-R036 | `tests/hooks/test-orchestrator-directive.sh` |
| M-R037 | `tests/hooks/test-orchestrator-parent-guard.sh` |
| M-R038 | `tests/hooks/test-orchestrator-queue-order.sh` |
| M-R039 | `tests/hooks/test-orchestrator-worker-handoff.sh` |
| M-R040 | `tests/hooks/test-orchestrator-worker-templates.sh` |
| M-R041 | `tests/hooks/test-outcomes-check.sh` |
| M-R042 | `tests/hooks/test-phase-archive.sh` |
| M-R043 | `tests/hooks/test-phase-lock-claim.sh` |
| M-R044 | `tests/hooks/test-phase-lock-heartbeat.sh` |
| M-R045 | `tests/hooks/test-phase-lock-release.sh` |
| M-R046 | `tests/hooks/test-planning-file-guard.sh` |
| M-R047 | `tests/hooks/test-pr-traceability-jq.sh` |
| M-R048 | `tests/hooks/test-pr-traceability.sh` |
| M-R049 | `tests/hooks/test-prompt-reminder.sh` |
| M-R050 | `tests/hooks/test-quality-gates-mode.sh` |
| M-R051 | `tests/hooks/test-record-requested-skill.sh` |
| M-R052 | `tests/hooks/test-record-skill.sh` |
| M-R053 | `tests/hooks/test-required-skills-consistency.sh` |
| M-R054 | `tests/hooks/test-rm-safety.sh` |
| M-R055 | `tests/hooks/test-roadmap-freshness.sh` |
| M-R056 | `tests/hooks/test-runtime-paths.sh` |
| M-R057 | `tests/hooks/test-sb-project-gate.sh` |
| M-R058 | `tests/hooks/test-semantic-compress-hook.sh` |
| M-R059 | `tests/hooks/test-semantic-compress.sh` |
| M-R060 | `tests/hooks/test-session-log-init.sh` |
| M-R061 | `tests/hooks/test-session-start-path-validation.sh` |
| M-R062 | `tests/hooks/test-session-start.sh` |
| M-R063 | `tests/hooks/test-spec-floor-check.sh` |
| M-R064 | `tests/hooks/test-spec-session-record.sh` |
| M-R065 | `tests/hooks/test-stop-check.sh` |
| M-R066 | `tests/hooks/test-symlink-guard.sh` |
| M-R067 | `tests/hooks/test-timeout-check.sh` |
| M-R068 | `tests/hooks/test-trivial-file-clear.sh` |
| M-R069 | `tests/hooks/test-trivial-file-guard.sh` |
| M-R070 | `tests/hooks/test-uat-gate.sh` |
| M-R071 | `tests/hooks/test-verify-tests.sh` |
| M-R072 | `tests/hooks/test-workflow-chain-guard.sh` |
| M-R073 | `tests/integration/coverage-matrix.sh` |
| M-R074 | `tests/integration/helpers/common.sh` |
| M-R075 | `tests/integration/test-compliance-status-scenarios.sh` |
| M-R076 | `tests/integration/test-composable-flows-scenarios.sh` |
| M-R077 | `tests/integration/test-e2e-devops-cycle.sh` |
| M-R078 | `tests/integration/test-e2e-enforcement-gates.sh` |
| M-R079 | `tests/integration/test-e2e-full-lifecycle.sh` |
| M-R080 | `tests/integration/test-e2e-lifecycle-gaps.sh` |
| M-R081 | `tests/integration/test-e2e-session-lifecycle.sh` |
| M-R082 | `tests/integration/test-e2e-skill-coverage.sh` |
| M-R083 | `tests/integration/test-multi-agent-coexistence.sh` |
| M-R084 | `tests/integration/test-planning-gate-scenarios.sh` |
| M-R085 | `tests/integration/test-plugin-integrity.sh` |
| M-R086 | `tests/integration/test-semantic-compress-scenarios.sh` |
| M-R087 | `tests/integration/test-session-scenarios.sh` |
| M-R088 | `tests/integration/test-session-start-scenarios.sh` |
| M-R089 | `tests/integration/test-skill-execution-paths.sh` |
| M-R090 | `tests/integration/test-skill-integrity.sh` |
| M-R091 | `tests/integration/test-skill-refs.sh` |
| M-R092 | `tests/integration/test-skill-tracking-scenarios.sh` |
| M-R093 | `tests/integration/test-workflow-completion-scenarios.sh` |
| M-R094 | `tests/live/README.md` |
| M-R095 | `tests/live/agents/claude/agent.sh` |
| M-R096 | `tests/live/agents/codex/agent.sh` |
| M-R097 | `tests/live/agents/kay/agent.sh` |
| M-R098 | `tests/live/agents/kay/transcripts/6d300eda-443b-4f14-b2db-e18a108b984d.jsonl` |
| M-R099 | `tests/live/agents/kay/transcripts/880144d7-3ba2-4c7c-af8f-6cd86619cb18.jsonl` |
| M-R100 | `tests/live/agents/kay/transcripts/latest.jsonl` |
| M-R101 | `tests/live/agents/kay/transcripts/latest.meta.json` |
| M-R102 | `tests/live/helpers.sh` |
| M-R103 | `tests/live/lib/codex-cli-isolation.sh` |
| M-R104 | `tests/live/lib/codex-cli.sh` |
| M-R105 | `tests/live/lib/codex-hook-transplant.sh` |
| M-R106 | `tests/live/lib/kay-cli.sh` |
| M-R107 | `tests/live/lib/kay-codex-isolation.sh` |
| M-R108 | `tests/live/lib/kay-project-hooks.py` |
| M-R109 | `tests/live/run-live-tests.sh` |
| M-R110 | `tests/live/test-live-doc-scheme.sh` |
| M-R111 | `tests/live/test-live-enforcement.sh` |
| M-R112 | `tests/live/test-live-full-scenario.sh` |
| M-R113 | `tests/live/test-live-skill-recording.sh` |
| M-R114 | `tests/live/test-silver-init-migration.sh` |
| M-R115 | `tests/run-all-tests.sh` |
| M-R116 | `tests/scripts/test-announce-release-threading.sh` |
| M-R117 | `tests/scripts/test-codex-cli-isolation.sh` |
| M-R118 | `tests/scripts/test-codex-hook-transplant.sh` |
| M-R119 | `tests/scripts/test-codex-skill-frontmatter-yaml.sh` |
| M-R120 | `tests/scripts/test-e2e-live-mcp-auth-cache.sh` |
| M-R121 | `tests/scripts/test-extract-phase-goal.sh` |
| M-R122 | `tests/scripts/test-install-claude.sh` |
| M-R123 | `tests/scripts/test-install-codex.sh` |
| M-R124 | `tests/scripts/test-install-cursor.sh` |
| M-R125 | `tests/scripts/test-kay-codex-isolation.sh` |
| M-R126 | `tests/scripts/test-model-selection-boundary.sh` |
| M-R127 | `tests/scripts/test-no-agent-leaks.sh` |
| M-R128 | `tests/scripts/test-phase-lock.sh` |
| M-R129 | `tests/scripts/test-post-release-refresh.sh` |
| M-R130 | `tests/scripts/test-release-version-alignment.sh` |
| M-R131 | `tests/scripts/test-run-release-live-matrix.sh` |
| M-R132 | `tests/scripts/test-run-sb-live-tests-codex.sh` |
| M-R133 | `tests/scripts/test-run-sb-live-tests-kay.sh` |
| M-R134 | `tests/scripts/test-sb-bootstrap.sh` |
| M-R135 | `tests/scripts/test-sb-diagnostics.sh` |
| M-R136 | `tests/scripts/test-sb-migrate-config.sh` |
| M-R137 | `tests/scripts/test-sb-migrate-initiated.sh` |
| M-R138 | `tests/scripts/test-sb-migrate-project.sh` |
| M-R139 | `tests/scripts/test-sb-skill-scenario-coverage.sh` |
| M-R140 | `tests/scripts/test-semantic-compress.sh` |
| M-R141 | `tests/scripts/test-silver-add-fingerprint.sh` |
| M-R142 | `tests/scripts/test-silver-add-todo-app-tag.sh` |
| M-R143 | `tests/scripts/test-silver-init-merge-hooks.sh` |
| M-R144 | `tests/scripts/test-silver-migrate.sh` |
| M-R145 | `tests/scripts/test-silver-router-flow-contracts.sh` |
| M-R146 | `tests/scripts/test-silver-scan.sh` |
| M-R147 | `tests/scripts/test-site-content-freshness.sh` |
| M-R148 | `tests/scripts/test-stamp-interface-state.sh` |
| M-R149 | `tests/scripts/test-sync-codex-marketplace-version.sh` |
| M-R150 | `tests/scripts/test-sync-codex-package.sh` |
| M-R151 | `tests/scripts/test-sync-cursor-marketplace-version.sh` |
| M-R152 | `tests/scripts/test-sync-release-marketplace-versions.sh` |
| M-R153 | `tests/scripts/test-template-substitution-parity.sh` |
| M-R154 | `tests/scripts/test-tfidf-rank.sh` |
| M-R155 | `tests/scripts/test-validate-evidence-findings.sh` |
| M-R156 | `tests/scripts/test-validate-github-release-notes.sh` |
| M-R157 | `tests/scripts/test-verify-release-announcement-ci.sh` |
| M-R158 | `tests/scripts/test-verify-release-commit-ci.sh` |
| M-R159 | `tests/scripts/test-workflows.sh` |
| M-R160 | `tests/skill-scenarios/ai-llm-safety.md` |
| M-R161 | `tests/skill-scenarios/artifact-review-assessor.md` |
| M-R162 | `tests/skill-scenarios/artifact-reviewer.md` |
| M-R163 | `tests/skill-scenarios/devops-quality-gates.md` |
| M-R164 | `tests/skill-scenarios/devops-skill-router.md` |
| M-R165 | `tests/skill-scenarios/extensibility.md` |
| M-R166 | `tests/skill-scenarios/finishing-branch.md` |
| M-R167 | `tests/skill-scenarios/gsd-code-review-fix.md` |
| M-R168 | `tests/skill-scenarios/gsd-code-review.md` |
| M-R169 | `tests/skill-scenarios/gsd-discuss-phase.md` |
| M-R170 | `tests/skill-scenarios/gsd-discuss.md` |
| M-R171 | `tests/skill-scenarios/gsd-execute-phase.md` |
| M-R172 | `tests/skill-scenarios/gsd-execute.md` |
| M-R173 | `tests/skill-scenarios/gsd-intel.md` |
| M-R174 | `tests/skill-scenarios/gsd-plan-phase.md` |
| M-R175 | `tests/skill-scenarios/gsd-plan.md` |
| M-R176 | `tests/skill-scenarios/gsd-progress.md` |
| M-R177 | `tests/skill-scenarios/gsd-review-fix.md` |
| M-R178 | `tests/skill-scenarios/gsd-review.md` |
| M-R179 | `tests/skill-scenarios/gsd-secure-phase.md` |
| M-R180 | `tests/skill-scenarios/gsd-secure.md` |
| M-R181 | `tests/skill-scenarios/gsd-ship.md` |
| M-R182 | `tests/skill-scenarios/gsd-validate-phase.md` |
| M-R183 | `tests/skill-scenarios/gsd-validate.md` |
| M-R184 | `tests/skill-scenarios/gsd-verify-work.md` |
| M-R185 | `tests/skill-scenarios/gsd-verify.md` |
| M-R186 | `tests/skill-scenarios/modularity.md` |
| M-R187 | `tests/skill-scenarios/progressive-review-loop.md` |
| M-R188 | `tests/skill-scenarios/reliability.md` |
| M-R189 | `tests/skill-scenarios/reusability.md` |
| M-R190 | `tests/skill-scenarios/review-context.md` |
| M-R191 | `tests/skill-scenarios/review-cross-artifact.md` |
| M-R192 | `tests/skill-scenarios/review-design.md` |
| M-R193 | `tests/skill-scenarios/review-ingestion-manifest.md` |
| M-R194 | `tests/skill-scenarios/review-plan.md` |
| M-R195 | `tests/skill-scenarios/review-requirements.md` |
| M-R196 | `tests/skill-scenarios/review-research.md` |
| M-R197 | `tests/skill-scenarios/review-roadmap.md` |
| M-R198 | `tests/skill-scenarios/review-spec.md` |
| M-R199 | `tests/skill-scenarios/review-uat.md` |
| M-R200 | `tests/skill-scenarios/review-verification.md` |
| M-R201 | `tests/skill-scenarios/scalability.md` |
| M-R202 | `tests/skill-scenarios/security.md` |
| M-R203 | `tests/skill-scenarios/silver-add.md` |
| M-R204 | `tests/skill-scenarios/silver-benchmark.md` |
| M-R205 | `tests/skill-scenarios/silver-blast-radius.md` |
| M-R206 | `tests/skill-scenarios/silver-bootstrap-milestone.md` |
| M-R207 | `tests/skill-scenarios/silver-bootstrap-project.md` |
| M-R208 | `tests/skill-scenarios/silver-branch-finish.md` |
| M-R209 | `tests/skill-scenarios/silver-bugfix.md` |
| M-R210 | `tests/skill-scenarios/silver-canary.md` |
| M-R211 | `tests/skill-scenarios/silver-clarify.md` |
| M-R212 | `tests/skill-scenarios/silver-completion-audit.md` |
| M-R213 | `tests/skill-scenarios/silver-content.md` |
| M-R214 | `tests/skill-scenarios/silver-context.md` |
| M-R215 | `tests/skill-scenarios/silver-create-release.md` |
| M-R216 | `tests/skill-scenarios/silver-debug.md` |
| M-R217 | `tests/skill-scenarios/silver-deploy.md` |
| M-R218 | `tests/skill-scenarios/silver-devops.md` |
| M-R219 | `tests/skill-scenarios/silver-domain-audit.md` |
| M-R220 | `tests/skill-scenarios/silver-ensure-docs.md` |
| M-R221 | `tests/skill-scenarios/silver-execute.md` |
| M-R222 | `tests/skill-scenarios/silver-fast.md` |
| M-R223 | `tests/skill-scenarios/silver-feature.md` |
| M-R224 | `tests/skill-scenarios/silver-forensics.md` |
| M-R225 | `tests/skill-scenarios/silver-handoff.md` |
| M-R226 | `tests/skill-scenarios/silver-incident.md` |
| M-R227 | `tests/skill-scenarios/silver-ingest.md` |
| M-R228 | `tests/skill-scenarios/silver-init.md` |
| M-R229 | `tests/skill-scenarios/silver-migrate.md` |
| M-R230 | `tests/skill-scenarios/silver-orchestrator.md` |
| M-R231 | `tests/skill-scenarios/silver-orient.md` |
| M-R232 | `tests/skill-scenarios/silver-phase.md` |
| M-R233 | `tests/skill-scenarios/silver-plan.md` |
| M-R234 | `tests/skill-scenarios/silver-quality-gates.md` |
| M-R235 | `tests/skill-scenarios/silver-refactor.md` |
| M-R236 | `tests/skill-scenarios/silver-release.md` |
| M-R237 | `tests/skill-scenarios/silver-rem.md` |
| M-R238 | `tests/skill-scenarios/silver-remove.md` |
| M-R239 | `tests/skill-scenarios/silver-research.md` |
| M-R240 | `tests/skill-scenarios/silver-retro.md` |
| M-R241 | `tests/skill-scenarios/silver-review-request.md` |
| M-R242 | `tests/skill-scenarios/silver-review-stats.md` |
| M-R243 | `tests/skill-scenarios/silver-review-triage.md` |
| M-R244 | `tests/skill-scenarios/silver-review.md` |
| M-R245 | `tests/skill-scenarios/silver-scan.md` |
| M-R246 | `tests/skill-scenarios/silver-secure.md` |
| M-R247 | `tests/skill-scenarios/silver-ship.md` |
| M-R248 | `tests/skill-scenarios/silver-silver.md` |
| M-R249 | `tests/skill-scenarios/silver-spec.md` |
| M-R250 | `tests/skill-scenarios/silver-spike.md` |
| M-R251 | `tests/skill-scenarios/silver-test.md` |
| M-R252 | `tests/skill-scenarios/silver-thread.md` |
| M-R253 | `tests/skill-scenarios/silver-ui-contract.md` |
| M-R254 | `tests/skill-scenarios/silver-ui-review.md` |
| M-R255 | `tests/skill-scenarios/silver-ui.md` |
| M-R256 | `tests/skill-scenarios/silver-undo.md` |
| M-R257 | `tests/skill-scenarios/silver-update.md` |
| M-R258 | `tests/skill-scenarios/silver-validate.md` |
| M-R259 | `tests/skill-scenarios/silver-verify.md` |
| M-R260 | `tests/skill-scenarios/silver-worktree.md` |
| M-R261 | `tests/skill-scenarios/silver.md` |
| M-R262 | `tests/skill-scenarios/tdd.md` |
| M-R263 | `tests/skill-scenarios/testability.md` |
| M-R264 | `tests/skill-scenarios/usability.md` |
| M-R265 | `tests/skill-scenarios/verify-tests.md` |
| M-R266 | `tests/skill-scenarios/writing-plans.md` |
| M-R-GAP01 | `Coverage gap: live Cursor agent runtime (no automated suite)` |
| M-R-GAP02 | `Coverage gap: production install path on fresh host` |
| M-R-GAP03 | `Coverage gap: Claude runtime live agent harness` |
| M-R-GAP04 | `Coverage gap: OpenCode non-Kay runtime matrix` |

### S. `.github/` — CI workflows and release automation

| ID | Surface |
|----|---------|
| M-S01 | `.github/ISSUE_TEMPLATE/bug_report.md` |
| M-S02 | `.github/ISSUE_TEMPLATE/feature_request.md` |
| M-S03 | `.github/workflows/announce-release.yml` |
| M-S04 | `.github/workflows/ci.yml` |
| M-S05 | `.github/workflows/e2e-live.yml` |
| M-S06 | `.github/workflows/pages.yml` |
| M-S07 | `.github/workflows/secret-scan.yml` |

### T. Cross-artifact consistency — skills ↔ hooks ↔ templates ↔ docs ↔ tests

| ID | Surface |
|----|---------|
| M-T01 | `skills/*/SKILL.md frontmatter name ↔ hooks/lib/skill-discovery.sh refs` |
| M-T02 | `templates/silver-bullet.config.json.default required_* ↔ .silver-bullet.json` |
| M-T03 | `templates/silver-bullet.md.base ↔ silver-bullet.md enforcement sections` |
| M-T04 | `templates/silver-bullet.md.base ↔ plugins/silver-bullet/templates/silver-bullet.md.base` |
| M-T05 | `hooks/hooks.json registered scripts ↔ hooks/*.sh existence` |
| M-T06 | `composable flows ↔ hooks/lib/orchestrator-state.sh queues` |
| M-T07 | `composable flows ↔ hooks/workflow-chain-guard.sh markers` |
| M-T08 | `templates/orchestrator-workers/* ↔ hooks/lib/orchestrator-parent.sh resolution` |
| M-T09 | `agents/{codex,cursor,claude}/*/SKILL.md ↔ skills/*/SKILL.md source parity` |
| M-T10 | `scripts/sync-codex-package.sh output ↔ plugins/silver-bullet/ tree` |
| M-T11 | `docs/composable-flows-contracts.md ↔ skills/silver-*/SKILL.md step order` |
| M-T12 | `docs/internal/pre-release-quality-gate.md ↔ ENHANCED-REVIEW-PROMPT exit criteria` |
| M-T13 | `docs/RUNTIME-COMPATIBILITY.md ↔ hooks/lib/runtime-paths.sh host matrix` |
| M-T14 | `tests/integration/coverage-matrix.sh ↔ hooks/hooks.json 33/33 registration` |
| M-T15 | `tests/integration/test-skill-execution-paths.sh ↔ composable flow mandatory chains` |
| M-T16 | `site/help/**/*.html ↔ skills/silver-*/SKILL.md public workflow docs` |
| M-T17 | `.github/workflows/ci.yml ↔ tests/run-all-tests.sh suite list` |
| M-T18 | `forge/alo-labs-cursor-marketplace ↔ plugins/silver-bullet/.cursor-plugin metadata` |
---

## REFERENCE ARTIFACTS (read for context, do not mutate unless fixing)

- `.planning/review/SB-FLOW-ADVERSARIAL-REVIEW.md` — prior flow review pattern (odd=discovery, even=regression)
- `.planning/phases/launch-readiness-adversarial-review/LAUNCH-REVIEW.md` — current launch review state
- `docs/internal/pre-release-quality-gate.md` — formal 2 consecutive clean rounds language
- `docs/audits/pre-launch-adversarial-review-round-1.md` — scope examples
- `silver-bullet.md` — canonical invariants
- `CLAUDE.md` — repo architecture (secondary to silver-bullet.md)

---

## YOUR TASK THIS SESSION

1. Ask the user for **starting round number** only if unclear; default **Round 1 DISCOVERY**.
2. Reset streak counters for this session.
3. Execute the round per rules above.
4. Do NOT skip manifest rows in DISCOVERY rounds.
5. Update `LAUNCH-REVIEW.md` with frontmatter + round log.
6. If user asked to continue a prior review, treat prior "3 consecutive clean rounds" as **invalid** unless they were 2+ DISCOVERY cleans with frozen manifest — re-derive honestly.

Begin.
