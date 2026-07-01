# Round Cursor-1 — Gate checklist

**Updated:** 2026-07-01T10:08Z  
**SB HEAD:** `e814b137` (`enterprise-e2e/cursor`)  
**Ledger:** [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md)

## Status: **NOT STRICT-CLEAN**

| Metric | Value |
|--------|-------|
| Matrix ledger | **22 / 22** — reconcile **COMPLETE** |
| T1 FORCE×2 | **PASS** 2/2 |
| Phase A ladder | **PASS** 8/8 ×1 ([cursor-ladder-live.log](cursor-ladder-live.log)); **2nd run IN FLIGHT** (tmux `cursor-ladder-r2`) |
| `run-all-tests` | **IN FLIGHT** (tmux `cursor-runall-r3` → `/tmp/cursor-phasec-run-all-r3.log`) |
| RCS trihost | **90/100** (`SB_E2E_RCS_LADDER=8/8`) |

### Harness fixes (`e814b137`)

- `completion-audit` lib present — hook suite **88/88**
- `workflow-completion-scenarios` delivery gates — **16/16**
- Matrix prompt/routing tests — **15/15**, **11/11** (`SB_RUNTIME_PRESERVE_STATE_DIR`, `grep \|\| true`)
- `recommended-tools-policy` — **35/35** (host install guides + inlined `silver-init`)
- `validate-host-agnostic-core` — **OK** (`scripts/enterprise-e2e/` excluded)
- `test-skill-execution-paths` — **281/281** (host-neutral release `git add` pattern)
- `config_version` template aligned to `package.json` **0.48.9**

Prior `run-all` r2 (`/tmp/cursor-phasec-run-all-r2.log`): **69 failed** (stale tree before fixes). r3 rerun started post-commit.

### Phase C

| Check | Status |
|-------|--------|
| Validation `--live` | **PASS** 6/6 |
| Pre-release `--live` | **PASS** 40/40 |
| `run-all-tests` | **IN FLIGHT** → `/tmp/cursor-phasec-run-all-r3.log` |
| RCS `SB_E2E_RCS_TRIHOST=full` | **90/100** (`SB_E2E_RCS_LADDER=8/8`) |

### Gates

| Gate | Status |
|------|--------|
| Matrix 22/22 live | **PASS** |
| Ledger reconcile | **COMPLETE** |
| T1 FORCE×2 | **PASS** |
| Phase A ladder 8/8 | **PASS** (1× clean; 2nd run **IN FLIGHT**) |
| `run-all-tests` | **PENDING** (r3) |
| Strict-clean | **NO** |

### Strict-clean blockers

1. `run-all-tests` green on `enterprise-e2e/cursor` (r3)
2. Phase A ladder **8/8 × 2** consecutive clean (r2 in flight)

### Next

1. Poll `cursor-runall-r3` → confirm 0 suite failures
2. Poll `cursor-ladder-r2` → confirm 2nd consecutive 8/8
3. Re-run RCS with `SB_E2E_RCS_LADDER=8/8` after run-all green
4. Declare strict-clean only when 1–2 are green
