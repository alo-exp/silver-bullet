# Review-fix-ladder triage — GitHub PM E2E

Enterprise E2E can file **real GitHub issues** on [`alo-exp/enterprise-grade-test-app`](https://github.com/alo-exp/enterprise-grade-test-app) during the triage ladder scenario.

## Run locally

```bash
cd /path/to/silver-bullet/repo

export SB_TEST_ENTERPRISE_APP_ROOT=/Users/shafqat/projects/enterprise-grade-test-app-cursor
export SB_RFL_GITHUB_E2E=1   # optional — auto-enabled when gh auth or token present

bash tests/enterprise-e2e-live/test-enterprise-e2e-triage-ladder-scenario.sh
```

Or the planning driver:

```bash
bash .planning/enterprise-e2e/cursor-triage-ladder-driver.sh
```

## Required secrets / env

| Variable | Required | Purpose |
|----------|----------|---------|
| `GITHUB_TOKEN` or `GH_TOKEN` | CI / headless | `gh` API auth when keyring unavailable |
| `gh auth login` | Local dev | Alternative to token |
| `SB_TEST_ENTERPRISE_APP_ROOT` | Yes (GitHub path) | Cursor worktree clone with `origin` → test app |
| `SB_RFL_GITHUB_E2E` | Opt-in | Force GitHub filing segment (else skip) |
| `SB_RFL_GITHUB_ISSUE_LABEL` | Optional | Default `rfl-triage-e2e` |

## CI-friendly behavior

- Mock adapter tests always run (temp workdir, no network).
- GitHub segment **skips** when `gh` is missing or neither token nor `gh auth status` succeeds.
- Created issues are closed with reason `not planned` after assertion.

## Hook enforcement

`hooks/review-fix-ladder-guard.sh` enforces the ladder state machine when active (skill invoke or test harness). Disable with `SB_REVIEW_FIX_LADDER_GUARD=0`.

Violations set `compliance_stop` and deny further Task spawns until the session state is cleared.
