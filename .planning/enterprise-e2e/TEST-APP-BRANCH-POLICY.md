# Test-app branch isolation policy

**Authority:** Enterprise E2E parallel-host matrix runs share one fixture checkout (`enterprise-grade-test-app`). Each host track MUST use a dedicated fixture branch so row mutations (especially rows 21–22 via parents 3/4) do not collide across Codex, Cursor, and Claude sessions.

Canonical config: [`scripts/enterprise-e2e/config/hosts.json`](../../scripts/enterprise-e2e/config/hosts.json) (`git_branch`, `test_app_git_branch`, `test_app_git_baseline_sha`).

## Branch naming

Pattern: **`enterprise-e2e/round-{N}-{host}`** where `{host}` is `claude`, `codex`, or `cursor`.

| Host track | SB harness branch (`git_branch`) | Test-app branch (`test_app_git_branch`) | Test-app root (`test_app_root`) | Baseline SHA |
|------------|----------------------------------|----------------------------------------|--------------------------------|--------------|
| Claude Round 6 | `enterprise-e2e/round6` | `enterprise-e2e/round-6-claude` | *(shared default)* | `8482e60` |
| Codex Round 1 | `enterprise-e2e/codex` | `enterprise-e2e/round-1-codex` | *(shared default)* | `8482e60` |
| Cursor Round 1 | `enterprise-e2e/cursor` | `enterprise-e2e/round-1-cursor` | `/Users/shafqat/projects/enterprise-grade-test-app-cursor` | `8482e60` |

**Legacy aliases (do not reuse for new work):** `enterprise-e2e/round6` (test app, Claude), `enterprise-e2e/round-codex-1` (Codex).

**Do not** target `main` for live matrix rows. **Do not** checkout another host's fixture branch from a different track's session.

## Harness env

| Variable | Purpose |
|----------|---------|
| `SB_TEST_ENTERPRISE_APP_ROOT` | Fixture path (default: `~/projects/enterprise-grade-test-app`; Cursor: from `hosts.json` `test_app_root`) |
| `SB_E2E_TEST_APP_BRANCH` | Explicit fixture branch (overrides `hosts.json`) |
| `SB_E2E_TEST_APP_ROUND` | Round number → auto branch `enterprise-e2e/round-N-{host}` |
| `SB_E2E_TEST_APP_BASELINE_SHA` | Baseline when creating branch (default from `hosts.json`: `8482e60`) |
| `SB_E2E_TEST_APP_BRANCH_ENFORCE=0` | Skip branch gate (debug only) |
| `SB_E2E_TEST_APP_BRANCH_CREATE_ONLY=1` | Create branch without checkout when fixture is dirty (parallel batch safety) |
| `SB_E2E_TEST_APP_ALLOW_DIRTY=1` | Allow dirty tree on correct branch |
| `SB_E2E_BRANCH` | SB harness branch override (must match `hosts.json` `git_branch`) |

Implementation:

- SB harness assert: `enterprise_e2e_assert_host_git_branch` in [`scripts/enterprise-e2e/lib/host.sh`](../../scripts/enterprise-e2e/lib/host.sh)
- Test-app assert (fail-fast, no checkout): `enterprise_e2e_assert_test_app_branch` in [`scripts/enterprise-e2e/lib/test-app-branch.sh`](../../scripts/enterprise-e2e/lib/test-app-branch.sh)
- Test-app ensure (legacy checkout/create): `enterprise_e2e_ensure_test_app_branch` in the same module — manual bootstrap only
- Invoked from [`scripts/enterprise-e2e/live-test.sh`](../../scripts/enterprise-e2e/live-test.sh) and [`scripts/enterprise-e2e/matrix.sh`](../../scripts/enterprise-e2e/matrix.sh) before matrix rows

**Dirty + wrong branch:** preflight **fails** (assert refuses checkout that would stomp other agents). **Dirty + correct branch:** OK (matrix work in progress). **Wrong branch:** fail-fast — use a dedicated worktree instead of checking out on the shared clone.

## Cursor worktree isolation

When Codex (or another host) holds the shared clone (`~/projects/enterprise-grade-test-app`) on a different branch with a dirty tree, Cursor matrix rows MUST use a **git worktree** so preflight never touches the shared checkout.

| Item | Value |
|------|-------|
| Shared clone (do not checkout for Cursor) | `/Users/shafqat/projects/enterprise-grade-test-app` |
| Cursor worktree | `/Users/shafqat/projects/enterprise-grade-test-app-cursor` |
| Branch | `enterprise-e2e/round-1-cursor` |
| Baseline | `8482e60` |

Create once (from the shared clone — does not change its HEAD):

```bash
APP=/Users/shafqat/projects/enterprise-grade-test-app
WORKTREE=/Users/shafqat/projects/enterprise-grade-test-app-cursor
BRANCH=enterprise-e2e/round-1-cursor
BASELINE=8482e60

cd "$APP"
git fetch origin 2>/dev/null || true
if ! git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  git branch "${BRANCH}" "${BASELINE}"
fi
if [[ ! -d "$WORKTREE" ]]; then
  git worktree add "$WORKTREE" "$BRANCH"
fi
git -C "$WORKTREE" status -sb
```

Harness picks up `hosts.json` → `hosts.cursor.test_app_root` automatically when `SB_E2E_LIVE_RUNTIME=cursor` (or `--host cursor`).

## Create Cursor Round 1 branch (without disturbing in-flight batch)

```bash
APP=/Users/shafqat/projects/enterprise-grade-test-app
BASELINE=8482e60
BRANCH=enterprise-e2e/round-1-cursor

cd "$APP"
git fetch origin 2>/dev/null || true
if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
  echo "branch ${BRANCH} exists @ $(git rev-parse --short "${BRANCH}")"
else
  git branch "${BRANCH}" "${BASELINE}"
  echo "created ${BRANCH} @ ${BASELINE}"
fi
```

Harness create-only while another host batch is active:

```bash
export SB_E2E_LIVE_RUNTIME=cursor
export SB_E2E_TEST_APP_BRANCH_CREATE_ONLY=1
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --host cursor --preflight-only
```

## Operator rules

1. **SB harness commits** → host `git_branch` only (`enterprise-e2e/cursor` for Cursor track).
2. **Product / fixture commits** → test-app branch for the active host track only.
3. **No stomp:** never `git checkout -B` on another track's branch; never force-push fixture branches.
4. **Rows 21–22:** parent rows 3/4 artifacts live on the active fixture branch — parallel tracks require branch isolation (this policy).
5. **Session 0 / graphify:** run `graphify update .` in the test app on the pinned branch after init.

## Verification

```bash
export SB_E2E_LIVE_RUNTIME=cursor
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --host cursor --preflight-only
# Expect: Test-app branch preflight: want=enterprise-e2e/round-1-cursor …
```

Structural: `RTK_DISABLED=1 bash tests/scripts/test-enterprise-e2e-test-app-branch.sh`
