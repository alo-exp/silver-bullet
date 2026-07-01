# Round Cursor-1 — Gate checklist

**Updated:** 2026-07-01T10:55Z  
**SB HEAD:** `6554df80` (`enterprise-e2e/cursor`)  
**Ledger:** [ROUND-CURSOR-1-LEDGER.md](./ROUND-CURSOR-1-LEDGER.md)

## Status: **NOT STRICT-CLEAN**

| Metric | Value |
|--------|-------|
| Matrix ledger | **22 / 22** — reconcile **COMPLETE** |
| T1 FORCE×2 | **PASS** 2/2 |
| Phase A ladder | **PASS** 8/8 ×1; **r2 FAIL** 6/8 (3 in-session timeouts) |
| `run-all-tests` r3 | **FAIL** 4429 pass / 191 fail ([`/tmp/cursor-phasec-run-all-r3.log`](/tmp/cursor-phasec-run-all-r3.log)) |
| RCS | **90/100** (`SB_E2E_RCS_LADDER=8/8` + `SB_E2E_RCS_TRIHOST=full`) |

### Poll results (2026-07-01)

**run-all r3** completed `run_all_exit:0` but **191 assertion failures** — dominated by transient **host-bundles deletion** mid-run (branch checkout during tmux run destroyed generated bundles). Not representative of harness at `6554df80`.

**Targeted suite re-run** (post `sync-codex-package.sh`, current tree):

| Suite | Result |
|-------|--------|
| test-agent-bundle-composer-parity | **54/54** |
| test-claude-plugin-surface | **11/11** |
| test-codex-cli-isolation | **38/38** |
| test-install-codex | **299/301** (2 fail: `.cursor` path leak in Cursor IDE env) |
| test-kay-codex-isolation | **85/85** |
| test-render-agent-bundle-freshness | **348/348** |
| test-silver-doctor | pending / D6 local config drift |

**Phase A ladder r2** ([cursor-ladder-live.log](cursor-ladder-live.log)): **6 passed, 3 failed** — rungs 3/6/8 failed on `CURSOR_IN_SESSION_REQUEST` **300s timeout** (driver lag), not review findings. Rung 1× pass from 09:32Z still valid for RCS credit.

### Phase C

| Check | Status |
|-------|--------|
| Validation `--live` | **PASS** 6/6 |
| Pre-release `--live` | **PASS** 40/40 |
| `run-all-tests` | **FAIL** r3 — need clean **r4** |
| RCS | **90/100** (paper; run-all component 10/20) |

### Gates

| Gate | Status |
|------|--------|
| Matrix 22/22 live | **PASS** |
| Ledger reconcile | **COMPLETE** |
| T1 FORCE×2 | **PASS** |
| Phase A ladder 8/8 ×2 | **NO** (1× clean + r2 6/8) |
| `run-all-tests` green | **NO** |
| Strict-clean | **NO** |

### Strict-clean blockers

1. **run-all green** — r4 required on stable tree (no mid-run checkout); sync host-bundles before run
2. **Ladder 8/8 ×2** — r3 retry with persistent `cursor-ladder-r2-driver` tmux (in-session timeouts on r2)
3. **install-codex** — 2 fails are `.cursor` path pollution in local IDE env (may be CI-clean)

### Next

1. `bash scripts/sync-codex-package.sh` → commit bundle drift if needed
2. tmux `cursor-runall-r4` on quiescent tree
3. tmux ladder r3 with dedicated in-session driver
4. Re-assess strict-clean only when both green
