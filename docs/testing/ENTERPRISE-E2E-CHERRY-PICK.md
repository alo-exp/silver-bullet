# Enterprise E2E — cherry-pick harness fixes to `main`

**Policy (2026-06-30):** Verified production/harness fixes land on `main` in the same session so the next patch release can ship them anytime. Long-running matrix work stays on `enterprise-e2e/round6`; round-specific ledgers, poll checkpoints, and runtime `.e2e-*` state remain on that branch only.

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
   - `bash tests/scripts/test-enterprise-e2e-matrix-routing.sh`
   - `bash tests/scripts/test-enterprise-e2e-matrix-evidence.sh`
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

### Skipped on 2026-06-30

| SHA | Reason |
|-----|--------|
| `da493429` | Already on `main` |
| `7559c255` | Round 6 ledger reset — round branch only |
| `7bb0ceac` | Round 6 operator poll checkpoint |
| `9e128707` | Ledger-only checkpoint (harness in `c5877bc7` / `5781e164`) |
| `2d08e423` | Site fix already on `main` as `b48eec67` |
| Poll docs (`81dd7ebd`, etc.) | Round-only checkpoints — not merged to `main` |

## Test app

Cherry-pick test-app commits only when they change matrix fixtures or docs the harness reads. On 2026-06-30, `8482e60` on round6 was docs-only for blocking criteria — optional follow-up if `main` needs parity.
