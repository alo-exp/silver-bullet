# SB IF Reduction Plan — execution complete

**Date:** 2026-06-29  
**Branch:** `main` (gap-closure commit on this branch; `git log -1 --oneline`)  
**Plan:** `.cursor/plans/sb_if_reduction_plan_71f2493c.plan.md`

---

## Phase 0 exit criteria (E0–E8)

| # | Criterion | Status | Evidence |
|---|-----------|--------|----------|
| E0 | No imported Claude-native SB | **PASS** | [PHASE0-PREFLIGHT-EVIDENCE.md](./PHASE0-PREFLIGHT-EVIDENCE.md) |
| E1 | Host plugin 0.48.6 | **PASS** | doctor D2 |
| E2 | `current` symlink → 0.48.6 | **PASS** | doctor D3 |
| E3 | Repo `config_version` 0.48.6 | **PASS** | `.silver-bullet.json` |
| E4 | Orchestrator rule present | **PASS** | `.cursor/rules/silver-orchestrator.mdc` |
| E5 | Template parity | **PASS** | `test-silver-bullet-template-parity.sh` 2/2 |
| E6 | `sb:doctor` PASS | **PASS** | `sb-doctor.sh` 16/16 |
| E7 | Hooks visibly active | **PASS** | `test-site-session-gates.sh` 27/27 |
| E8 | Friction log started | **PASS** | `~/.cursor/.silver-bullet/sb-friction-log.md` |

---

## Plan todos

| Todo | Status |
|------|--------|
| phase0-preflight | **DONE** |
| silver-doctor | **DONE** |
| silver-update-migrate | **DONE** |
| wave1-hooks | **DONE** |
| wave1-skills | **DONE** |
| template-parity | **DONE** |
| cursor-display-name | **DONE** |
| vloop-analysis-impl | **DONE** — `v-loop-rollup-gate.sh`, [VLOOP-CATALOG-RUNTIME-GAP.md](./VLOOP-CATALOG-RUNTIME-GAP.md) |
| wave2-visual | **DONE** — `site-visual-evidence-gate.sh`, `record-site-visual-evidence.sh` |
| wave3-chrome-tokens | **DONE** — `site-preview-preflight.sh`, `site-chrome-guard.sh`, `record-recommended-mcp.sh` |
| hook-tests | **DONE** — `test-site-session-gates.sh` 27/27; hook coverage matrix 55/55 |
| friction-protocol | **DONE** — friction log maintained (F-011 added) |

---

## Audit gaps ([SB-SUBAGENT-ENGAGEMENT-AUDIT.md](./SB-SUBAGENT-ENGAGEMENT-AUDIT.md))

| Priority | Gap | Status | Files |
|----------|-----|--------|-------|
| P0 | Commit Wave 1 | **CLOSED** | prior feat commit |
| P1 | `subagentStart` hook | **CLOSED** | `hooks/subagent-start.sh`, `hooks/cursor-hooks.json`, `hooks/hooks.json` |
| P1 | Skip outcomes-check on worker SubagentStop | **CLOSED** | `hooks/outcomes-check.sh` |
| P2 | Completion-audit per Task return | **CLOSED** | `hooks/subagent-stop-enforcement.sh` |
| P2 | Record ALL Task spawns | **CLOSED** | PreToolUse spawn log in `subagent-stop-enforcement.sh` |
| — | Worker template tooling | **CLOSED** | `templates/orchestrator-workers/*.md`, `.silver-bullet/orchestrator-workers/*.md` |
| Wave 2 | Visual + v-loop gates | **CLOSED** | Wave 2 hooks + tests in `test-site-session-gates.sh` |
| Wave 3 | Preview / chrome / MCP recorders | **CLOSED** | Wave 3 hooks + tests in `test-site-session-gates.sh` |
| Wave 4 | Alpha Honesty dedupe | **CLOSED** | `site/index.html`, `test-site-chrome-regression.sh` |

---

## Test summary (2026-06-29)

```text
bash tests/run-all-tests.sh                          # 4818 passed, 0 failed, exit 0
bash tests/integration/coverage-matrix.sh            # 55/55 hooks covered
bash tests/hooks/test-site-session-gates.sh          # 27 passed, 0 failed
bash scripts/validate-launch-review.sh               # OK (status=clean, streak=2)
bash scripts/validate-sentinel-skills-manifest.sh    # OK (87/87 clean rows)
bash scripts/verify-tests.sh                         # OK (marker written)
bash tests/scripts/test-silver-bullet-template-parity.sh  # 2 passed, 0 failed
bash scripts/sb-doctor.sh                            # 16 PASS, OVERALL PASS
bash tests/scripts/test-site-chrome-regression.sh    # 14 passed, 0 failed
```

---

## Procedural gates (human / release session only)

These are **not** automatable in-repo; they require live Cursor hosts or release workflow:

| Gate | Why release-session only |
|------|--------------------------|
| Cursor window reload after `install-cursor.sh` | Host must reload to register `subagentStart` + Wave 2–3 hooks |
| Enterprise E2E matrix (live Multitask / subagent runs) | Requires live Cursor tier-2 sessions across host matrix |
| Plugin marketplace manifest bump (`--public-release` parity) | See friction F-007; marketplace ref still pins older release |
| Post-reload UI verification (Imported badge, plugin list) | See friction F-006/F-010 operational notes |

---

## User action

**Reload Cursor window** after commit so host hooks pick up `subagentStart` and Wave 2–3 gate registrations from plugin cache (`bash scripts/install-cursor.sh` if dev-syncing).
