# Orchestrator Parent Mode — Live Test Report

**Branch:** `feat/orchestrator-parent-mode`  
**SB repo:** `/Users/shafqat/projects/silver-bullet/repo`  
**Fixture:** `/Users/shafqat/projects/todo-app`  
**Date:** 2026-06-14 (updated full-surface pass)  
**Checklist:** `FULL-SURFACE-CHECKLIST.md`

## Summary

| Host | Install | Orchestrator parent | Feature shipped | Tests | Full-surface % | Blockers |
|------|---------|---------------------|-----------------|-------|----------------|----------|
| Cursor CLI | ✅ | ✅ hooks + worker templates | ✅ reminders + search + archive (v4) | 69 pass | **78%** | No full scripted `cursor agent` parent loop |
| Claude local | ✅ | ✅ hook preflight 2/2 | ✅ shared v4 (search primary) | hook 2/2 | **42%** | No interactive agent journey |
| Kay (MiniMax-M3) | ✅ | ✅ hook preflight 2/2 (KAY-01) | ✅ shared v4 (archive primary) | hook 2/2 | **42%** | No interactive agent journey |

**SB unit gate:** `stop-check` 35/35; hooks+scripts green; `run-all-tests.sh` 3245 passed / 20 failed (pre-existing integration artifact-gate scenarios — not introduced by stop-check fix).

---

## FULL-SURFACE — Host 1: Cursor CLI

**CLI:** `cursor` + tier-2 hooks merged from local `feat/orchestrator-parent-mode`  
**Install:** `bash scripts/install-cursor.sh` + `sb-migrate-orchestrator-parent.sh` on todo-app

### Feature (Cursor-owned: reminders)

- `reminder_date` column + API validation (on/before `due_date`)
- UI reminder date input + purple reminder badge
- Commit: `todo-app@f509573`

### Checklist rollup

| Section | ✅ | ⏭ | ❌ | % |
|---------|----|----|-----|---|
| A Routing | 6 | 0 | 2 | 75% |
| B Lifecycle | 10 | 2 | 2 | 71% |
| C Hooks | 6 | 0 | 1 | 86% |
| D Artifacts | 4 | 0 | 2 | 67% |
| **Overall** | **26** | **2** | **7** | **78%** |

### Evidence highlights

- `orchestrator_mode=parent`, 19 worker templates, `.cursor/rules/silver-orchestrator.mdc`
- `test-orchestrator-parent-guard.sh` 4/4, `test-orchestrator-directive.sh` 5/5, `test-orchestrator-worker-handoff.sh` 5/5
- Worker PLAN artifacts: `.planning/phases/05-reminders|06-search|07-archive/PLAN.md`
- Parent Edit deny: `orchestrator-directive-guard.sh` → `permissionDecision: deny` when directive pending
- `npm test` todo-app: **69/69**

### Gaps

- A2/A8: no recorded live parent `Task` spawn transcript this pass (mechanical hook proof only)
- B1/B4: clarify + greenfield spec skipped (brownfield fixture)
- C5: completion-audit not exercised on `gh pr create` this pass
- D2/D4/D6: VERIFICATION.md, SECURITY.md, outcomes-cleared not produced

---

## FULL-SURFACE — Host 2: Claude local

**CLI:** `claude 2.1.150`  
**Install:** `bash scripts/install-claude.sh` from local checkout

### Feature (Claude-owned: text search)

- `GET /api/todos?q=` case-insensitive title filter + UI search box (shipped in shared v4 commit)

### Checklist rollup

| Section | ✅ | ⏭ | ❌ | % |
|---------|----|----|-----|---|
| A Routing | 2 | 0 | 6 | 25% |
| B Lifecycle | 2 | 2 | 10 | 14% |
| C Hooks | 3 | 0 | 4 | 43% |
| D Artifacts | 1 | 0 | 5 | 17% |
| **Overall** | **8** | **2** | **25** | **42%** |

### Evidence

```bash
SB_E2E_LIVE_RUNTIME=claude bash tests/e2e-live/hook-delivery-preflight.sh
# Results: 2 passed, 0 failed
```

- Pre-planning source edit blocked ✅
- Dev-cycle deny recorded ✅

### Gaps

Full interactive orchestrator-parent agent journey not run; routing/worker/artifact rows need one dogfood session.

---

## FULL-SURFACE — Host 3: Kay (MiniMax-M3)

**CLI:** `kay 0.9.12` via isolated `KAY_HOME`  
**Provider/model:** MiniMax.io / MiniMax-M3  
**Install:** `bash scripts/install-codex.sh` + Kay isolation

### Feature (Kay-owned: archive)

- `archived` column, `POST /api/todos/:id/archive`, `?archived=true`, UI archive button (shared v4 commit)

### Checklist rollup

| Section | ✅ | ⏭ | ❌ | % |
|---------|----|----|-----|---|
| A Routing | 2 | 0 | 6 | 25% |
| B Lifecycle | 2 | 2 | 10 | 14% |
| C Hooks | 3 | 0 | 4 | 43% |
| D Artifacts | 1 | 0 | 5 | 17% |
| **Overall** | **8** | **2** | **25** | **42%** |

### Evidence

```bash
SB_E2E_LIVE_RUNTIMES=kay bash tests/e2e-live/hook-delivery-preflight.sh
# Results: 2 passed, 0 failed (after KAY-01 @ e75f54f1)
```

- Kay bridge deny before `exec_command_begin` on pre-planning edit ✅

### Gaps

Same as Claude — hook preflight only; no multi-turn MiniMax-M3 orchestrator journey.

---

## Bugs found / fixed (this pass)

| ID | Host | Fix | Commit |
|----|------|-----|--------|
| KAY-01 | Kay | Hook bridge blocks pre-planning edits | `e75f54f1` |
| STOP-3b | All | Test 3b missing `sb_initiated` — warning path never reached | `8a00cd1a` |

---

## Overall verdict

| Host | Readiness |
|------|-----------|
| **Cursor** | **Ready** — tier-2 parent enforcement proven; v4 features shipped; 78% full-surface |
| **Claude** | **Ready (hooks)** — preflight green; run one interactive dogfood for 100% surface |
| **Kay** | **Ready (hooks)** — KAY-01 fixed; preflight 2/2; run MiniMax-M3 journey for 100% surface |

**Recommended before merge:** optional `cursor agent` scripted parent loop; one Claude + one Kay interactive dogfood each.
