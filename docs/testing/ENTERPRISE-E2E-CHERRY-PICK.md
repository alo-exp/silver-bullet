# Enterprise E2E — cherry-pick harness fixes to `main`

**Policy (2026-06-30):** Verified production/harness fixes land on `main` in the same session so the next patch release can ship them anytime. Long-running matrix work stays on host branches: Claude `enterprise-e2e/round6`, Codex `enterprise-e2e/codex`, Cursor **`enterprise-e2e/cursor`**. Round-specific ledgers, poll checkpoints, and runtime `.e2e-*` state remain on those branches only.

## Repos

| Repo | Path |
|------|------|
| Silver Bullet | `silver-bullet/repo` |
| Test app | `enterprise-grade-test-app` (only when a harness-relevant commit exists there) |

## When to cherry-pick

After a harness fix is **verified on round6** (tests or live row evidence), cherry-pick the commit SHA to `main`, push `main`, and append one line to the log below.

**Include:** `scripts/`, `tests/`, shared registries under `docs/testing/`, generic templates (e.g. `ROUND-N-GATES.md`), outcome rubric updates.

**Exclude:** `ROUND-6-LEDGER.md` updates, `ROUND-6-POLL-*` checkpoints, `.e2e-*` logs/state, round gate status snapshots, experimental/failed commits.

If a round6 commit mixes harness code with ledger/poll files, cherry-pick **paths only** (`git checkout <sha> -- scripts/… tests/…`) or resolve conflicts keeping `main`'s round docs.

## Operator workflow

1. `git fetch origin` on SB (and test app if needed).
2. `git checkout main && git pull origin main`.
3. Compare: `git log origin/main..origin/enterprise-e2e/round6 --oneline` (and local round6 if ahead of origin).
4. Cherry-pick verified SHAs (oldest first), or path-checkout for mixed commits.
5. Run on `main`:
   - `bash tests/scripts/test-outcome-assessment.sh`
   - `bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh`
   - `bash tests/scripts/test-enterprise-e2e-test-app-branch.sh`
6. `git push origin main` (no force-push to `main`).
7. Record SHAs in **Cherry-pick log** (this file).
8. Periodically **rebase** `enterprise-e2e/round6` onto `origin/main` so round6 inherits `main` without duplicating fixes.

## Round 6 live drivers

FORCE monitor PIDs (e.g. 12948 / 9452) — **do not kill** if healthy. Cherry-pick work is **git-only**; relaunch matrix from round6 after `main` is updated.

## Cherry-pick log

| Date | Round6 source SHA | `main` commit | Notes |
|------|-------------------|---------------|-------|
| 2026-06-30 | `d3012330` | `1d1ab600` | TUI picker regex after UTF-8 restore |
| 2026-06-30 | `9f36ffcb` | `dfb451d8` | Autonomy outcome criteria + matrix enforcement |
| 2026-06-30 | `c5877bc7` | `e2864c78` | Matrix log guard, MCP auth mitigation (scripts only) |
| 2026-06-30 | `5781e164` | `e425865a` | MCP auth cache clear + expect banner ignore |
| 2026-06-30 | `9abbd8ee` | `94c82681` | UTF-8 + MCP dismiss (already on `main` via partial overlap `7a5d3b79`) |
| 2026-06-30 | `6bd2355f` | `59de6e30` | Delta: ❯ prompt, Submit regex, ASCII logs, MCP dismiss; `(?s)` omitted per `5f90a9ef` |
| 2026-06-30 | `e7eab44a` | `90572502` | MCP disable list from needs-auth `mcp list` only |
| 2026-06-30 | `9a21160a` | `e5a2bff5` | Site hover-only terminal shadows + hero tagline weight |
| 2026-06-30 | `2be1016e` | `2aeabad8` | Routing-row marker exempts subagent-stop §3c without `SB_E2E_ENTERPRISE_MATRIX` in TUI hook env (ORCH-4/5) |
| 2026-06-30 | `4db8e71d` | `70059a6b` | Pass `SB_E2E_ENTERPRISE_MATRIX` + `SB_E2E_MATRIX_ROUTING_ROW` into Claude TUI spawn env |
| 2026-06-30 | `7c89aa31` | `da1e7f08` | Routing-row marker exempts instruction-ledger + site-regression Stop gates (ORCH-6/7) |

### Cursor strict-clean 2/2 (2026-07-02)

Squashed logical groups from `enterprise-e2e/cursor` @ `5d56b2ca` (Cursor-2 Phase C strict-clean green). Path-checkout + conflict resolution kept `main` round docs; excluded `ROUND-CURSOR-*-LEDGER.md`, poll drivers, `.e2e-*` runtime state.

| Group | Source SHAs | Notes |
|-------|-------------|-------|
| E2E-086/089 log capture | `c6cae4e9`, `3d4ef10e`, `af9e6a6b` | `tests/live/agents/cursor/agent.sh` headless log streaming |
| E2E-087 timeouts | `2b197be9`, `5d56b2ca` | Cursor 1800s default; rows 8/11 per-row timeouts in `matrix.sh` |
| E2E-088/089 outcome | `8feda5fc`, `56c576d9`, `f208e213`, `098f48c6` | OUT-SKILL `state.requested`, KM graphify ref, reviews/ship-readiness evidence |
| Branch guard | `b96628a1` | `enterprise_e2e_assert_host_git_branch` wired in shared `matrix.sh` |
| Test-app isolation | `31ef1882`, `264fefbb`, `94ff696d` | `TEST-APP-BRANCH-POLICY.md`, `test-app-branch.sh`, structural test |
| Install-version skip | `23d201d7`, `9ae769be`, `26cf687f` | `core.sh` pass-at-version + `row-pass-registry_should_skip` (main registry path) |
| Shared harness layout | `da459749`, `5d56b2ca` | `scripts/enterprise-e2e/{matrix,live-test}.sh` + thin wrappers |
| Tests / preflight | `ee74f598`, `0cc001ad`, `43a01712` | silver-doctor BSD grep; e2e-live cursor host preflight |
| Monitor / consecutive | `5d56b2ca` | monitor detects `enterprise-e2e/matrix.sh`; consecutive-rounds check |

**Deferred (host-track only):** `ROUND-CURSOR-*-LEDGER.md`, `ROUND-CODEX-*`, `cursor-c2-*` drivers, `.planning/enterprise-e2e/cursor-*` poll state, `round8-matrix-driver.sh`, methodology-only docs already on `main` (`38102e26`, `0a3e0d3e`).

**Pre-existing on `main` (skipped):** install-version registry migrations `89e2ab8f`, `ee1c59b4`; matrix EXIT trap `6b016750`; host certification methodology merges.

### Skipped on 2026-06-30

| SHA | Reason |
|-----|--------|
| `da493429` | Already on `main` |
| `7559c255` | Round 6 ledger reset — round branch only |
| `7bb0ceac` | Round 6 operator poll checkpoint |
| `9e128707` | Ledger-only checkpoint (harness in `c5877bc7` / `5781e164`) |
| `2d08e423` | Site fix already on `main` as `b48eec67` |
| Poll docs (`81dd7ebd`, etc.) | Round-only checkpoints — not merged to `main` |

| 2026-07-03 | `enterprise-e2e/cursor` merge `c507f1c` | `c507f1c` | Cursor-3 REAL: E2E-091–100 harness, methodology void Cursor-1/2, ROUND-CURSOR-3-REAL-LEDGER 22/22 |

## Test app

Cherry-pick test-app commits only when they change matrix fixtures or docs the harness reads. On 2026-06-30, `8482e60` on round6 was docs-only for blocking criteria — optional follow-up if `main` needs parity.

## Merge + release (2026-07-02)

| Track | Branch | Merge commit on `main` | Notes |
|-------|--------|------------------------|-------|
| **Cursor** | `enterprise-e2e/cursor` | `62aa0de3` | Phase C strict-clean, row-pass registry, R8 orchestration scripts |
| **Codex** | `enterprise-e2e/codex` (cherry-picks) | `e9146308` | Matrix argv order, codex hook auto-trust, PTY watchdog, outcome scoring |
| **Claude** | `enterprise-e2e/round6` + local cherry-picks | `de1d2b1d`, `dca46dad`, `6f86e144`, `9e957a1c` | Routing env, UTF-8/MCP dismiss, methodology harness |

**Release:** [v0.50.0](https://github.com/alo-exp/silver-bullet/releases/tag/v0.50.0) — merge SHA `62aa0de3` on `main`.

Pre-release validation (2026-07-02): `test-outcome-assessment.sh` 60/60, `test-enterprise-e2e-live-suite.sh` 189/189, `test-enterprise-e2e-matrix-routing.sh` 11/11, `test-enterprise-e2e-row-pass-registry.sh` 13/13, `test-enterprise-e2e-test-app-branch.sh` 21/21, `test-silver-doctor.sh` 33/33.
