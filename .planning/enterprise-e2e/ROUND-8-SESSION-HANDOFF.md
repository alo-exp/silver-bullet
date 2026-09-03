# Round 8 Enterprise E2E — Session Handoff

**Updated:** 2026-07-01T06:22Z (cursor handoff: cherry-pick SHAs, driver 32939)  
**Gates:** [ROUND-8-GATES.md](./ROUND-8-GATES.md)  
**Prior round:** [ROUND-7-GATES.md](./ROUND-7-GATES.md) — 22/22, strict-clean **NO** (`OUT-SURFACE-01` skipped)

## SB HEAD (multi-host ledger baseline)

`156630f6` on `enterprise-e2e/multi-host` (prep); harness tip on multi-host now `00d2ff30` — see cherry-pick table below.

**Cursor session SB:** `264fefbb` on `enterprise-e2e/cursor` (TEST-APP-BRANCH-POLICY + matrix wiring).

**Test app HEAD:** `565e825` @ `/Users/shafqat/projects/enterprise-grade-test-app`

## Round 8 launched?

**YES (cursor track)** — live driver PID **32939** resumed @ 2026-07-01; see driver table below. Multi-host ledger may still show pre-launch prep until cherry-pick `264fefbb`.

## Surface test result

```bash
RTK_DISABLED=1 bash tests/scripts/test-claude-agent-surface-isolation.sh
# @ 156630f6 pristine checkout:
# Results: 6 passed, 0 failed — EXIT 0
# No SKIP flags in test harness
```

| Check | Result |
|-------|--------|
| `validate-host-install-surface --host claude` | **PASS** (pristine tree) |
| `agents/` only `claude` | **PASS** |
| No `silver-bullet:codex:/cursor:` in Claude manifests | **PASS** |
| Token budget ≤ 14k | **PASS** |
| Bleed fixture rejects `agents/codex` | **PASS** |

**Caveat:** test run on **clean git tree** before matrix `install-claude.sh`. Post-install surface must be re-verified after other session merges host-bundles fix from `main`.

## Blocker

| Blocker | Detail |
|---------|--------|
| **host-bundles install fix not on multi-host from `main`** | Commits `4ccea894`, `f99eae52`, `95c50892`, `33e9523d` are on `main` only — **not** in `enterprise-e2e/multi-host` ancestry @ `156630f6`. Other session owns merge. **Do not implement install fix here.** |
| **`OUT-SURFACE-01` blocking for strict-clean** | Round 8 requires `SB_E2E_SURFACE_SKIP=0`. Round 7 used `SB_E2E_SURFACE_SKIP=1` — not repeatable for strict-clean. |
| **Claude lock** | **CLEAR** — `.e2e-live-test.lock` absent |

**Unblock sequence:**

1. Other session merges host-bundles install fix onto `enterprise-e2e/multi-host` (cherry-pick from `main` or `fix/claude-agent-surface-cross-env`).
2. `RTK_DISABLED=1 bash scripts/install-claude.sh` then re-run `test-claude-agent-surface-isolation.sh` — must stay **PASS** 6/6.
3. Copy [ROUND-7-LEDGER.md](./ROUND-7-LEDGER.md) → `ROUND-8-LEDGER.md`; reset matrix table to **0/22** live.
4. Launch full matrix with `SB_E2E_SURFACE_SKIP=0` and `SB_E2E_MATRIX_FORCE=1` (all 22 rows live TUI preferred for strict-clean).

## Env (when unblocked)

```bash
export SB_E2E_LEDGER_FILE=/Users/shafqat/projects/silver-bullet/repo/.planning/enterprise-e2e/ROUND-8-LEDGER.md
export SB_ROOT=/Users/shafqat/projects/silver-bullet/repo
export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app
export SB_E2E_SURFACE_SKIP=0
export SB_E2E_MONITOR_AUTO_RESTART=0
export SB_E2E_MATRIX_LOG="$SB_ROOT/.e2e-matrix-round8-live.log"
export RTK_DISABLED=1
cd "$SB_ROOT"
git checkout enterprise-e2e/multi-host
```

## Matrix launch command (when unblocked)

```bash
# Phase A: ladder 8/8 first
# Phase B: full 22-row matrix
SB_E2E_SURFACE_SKIP=0 SB_E2E_MATRIX_FORCE=1 \
  RTK_DISABLED=1 bash scripts/run-enterprise-e2e-matrix.sh \
  1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
# Rows 21–22: internal gates via parent rows 3/4 logs (harness)
```

## Policies

- **Branch pin:** `enterprise-e2e/multi-host` only — **no commits to `main`**
- Subagent model: **composer-2.5** only (never Fast)
- Never `claude auth login/logout`
- Poll-only when healthy driver alive; no duplicate FORCE

## 2× consecutive strict-clean goal

| Milestone | Status |
|-----------|--------|
| Round 8 strict-clean | **PENDING** — blocked |
| Round 9 strict-clean | **PENDING** |
| Pair (R8+R9) | **0 / 2** |

---

**CHECKPOINT:** Round 8 prep docs committed @ `156630f6`; surface test **PASS** 6/6 on pristine tree; matrix **not launched** pending host-bundles install merge.

## Cursor track (enterprise-e2e/cursor) — TEST-APP-BRANCH-POLICY

**SB branch (this session):** `enterprise-e2e/cursor` @ `264fefbb` — **do not checkout** `enterprise-e2e/multi-host` here.

| Artifact | SHA | Subject |
|----------|-----|---------|
| Policy + preflight | `00d2ff30` (`00d2ff30c371659a037923e86dcece22d97aa9bf`) | `feat(e2e): test-app branch isolation policy and harness preflight` |
| Matrix wiring | `264fefbb` (`264fefbbe26ba2020eba298aa8e73bbb525e4bdf`) | `fix(e2e): wire matrix branch preflight and hosts.json test_app_git_branch` |

**Test app branch (Cursor row):** `enterprise-e2e/round-1-cursor` per [`config/hosts.json`](../../config/hosts.json) (`hosts.cursor.test_app_git_branch`). Harness preflight must checkout/create that branch — **never** reset `main` or reuse another host’s round branch (e.g. do not stomp `enterprise-e2e/round-codex-1` / codex track).

**Test app observed @ handoff:** `/Users/shafqat/projects/enterprise-grade-test-app` on `enterprise-e2e/round-codex-1` @ `565e825` (codex track) — Cursor matrix rows must still target `enterprise-e2e/round-1-cursor` only.

## Multi-host operator — cherry-pick (other session)

Apply onto `enterprise-e2e/multi-host` **from that session’s checkout of multi-host** — fetch cursor tip if needed; **do not** checkout `enterprise-e2e/cursor` on the multi-host machine unless debugging.

```bash
cd "$SB_ROOT"
git fetch origin enterprise-e2e/cursor enterprise-e2e/multi-host
git checkout enterprise-e2e/multi-host
# If multi-host lacks 00d2ff30 (verify: git merge-base --is-ancestor 00d2ff30 HEAD):
git cherry-pick 00d2ff30 264fefbb
# If multi-host already @ 00d2ff30 (as of 2026-07-01):
git cherry-pick 264fefbb
```

**Exact SHAs (copy/paste):** `00d2ff30` then `264fefbb` (older → newer). Range equivalent: `00d2ff30^..264fefbb` on cursor ancestry.

**Status @ 2026-07-01T06:20Z:** `enterprise-e2e/multi-host` tip `00d2ff30` — **only `264fefbb` remains** to cherry-pick for parity with cursor.

## Round 8 live driver (cursor session)

| Field | Value |
|-------|--------|
| Driver PID | **32939** — **ALIVE** (~12m+ elapsed @ poll) |
| Command | `bash scripts/run-enterprise-e2e-live-test.sh --skip-code-intel-preflight --resume` |
| Log | `.e2e-matrix-round8-live.log` |
| Env | `SB_E2E_SURFACE_SKIP=0`, `SB_E2E_MATRIX_FORCE=1`, `SB_ENTERPRISE_E2E_LIVE=1` |
| Monitor | batch PID **7549** RUNNING; monitor PID **99179**; poll ~300s |

**Policy:** poll-only while driver **32939** healthy — no duplicate `SB_E2E_MATRIX_FORCE` launch.

---

**CHECKPOINT (cursor):** TEST-APP-BRANCH-POLICY on `enterprise-e2e/cursor` @ `264fefbb`; multi-host needs `264fefbb` cherry-pick; Cursor test-app pin `enterprise-e2e/round-1-cursor`; R8 driver **32939** running.
