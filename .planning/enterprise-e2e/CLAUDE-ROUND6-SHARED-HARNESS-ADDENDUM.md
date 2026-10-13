# Claude Round 6 — Shared Harness Migration Addendum

**For:** The **active Claude Round 6 operator session** already running on legacy paths.

**Do not stop Round 6.** This addendum explains the harness reorg and how to pull shared fixes without breaking your session.

---

## What changed

Enterprise E2E harness code moved to a **host-agnostic shared tree**:

- Canonical: [`scripts/enterprise-e2e/`](../../scripts/enterprise-e2e/)
- Docs: [SHARED-HARNESS.md](./SHARED-HARNESS.md)
- Your entrypoints **unchanged**: `bash scripts/run-enterprise-e2e-live-test.sh` (thin wrapper)

**Your paths are unchanged** (`legacy_paths: true` in `config/hosts.json`):

- Lock: `.e2e-live-test.lock`
- Matrix log: `.e2e-matrix-live.log`
- Row logs: `.e2e-row{N}-attempt.log`
- Ledger: your active Round 6 ledger (e.g. `ROUND-6-LEDGER.md` or project default)
- Operational doc: [ROUND-6-OPERATIONAL-ADDENDUM.md](./ROUND-6-OPERATIONAL-ADDENDUM.md) — still authoritative for this session

---

## How to pull harness updates mid-Round-6

```bash
cd /Users/shafqat/projects/silver-bullet/repo
git fetch origin enterprise-e2e/multi-host
# Cherry-pick harness-only commits — do NOT reset your Round 6 branch
git cherry-pick <sha>   # see CHERRY-PICK.md
```

After pull:

1. `bash scripts/install-claude.sh` (same as before — adapter unchanged)
2. `RTK_DISABLED=1 bash tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh` (deterministic smoke)
3. Resume matrix with existing lock/log — **do not** delete `.e2e-live-test.lock` while driver alive

---

## Where to contribute fixes

| Change type | Location |
|-------------|----------|
| Resume, ledger, locks, preflight, dry-run | `scripts/enterprise-e2e/lib/core.sh` |
| Host paths, route translation | `scripts/enterprise-e2e/lib/host.sh` + `config/hosts.json` |
| Claude install/auth only | `scripts/enterprise-e2e/lib/adapters/claude.sh` |
| TUI invoke patterns | [CLAUDE-TUI-PROTOCOL.md](./CLAUDE-TUI-PROTOCOL.md) |

**Do not** fork Claude-only copies of deterministic logic (outcome scoring, consecutive rounds, ledger reconcile).

---

## Parallel Codex/Cursor tracks

Codex and Cursor use host-suffixed locks/logs. They will not steal `.e2e-live-test.lock`. See [HOST-CONFIG.md](./HOST-CONFIG.md).

---

## One-liner (paste into running Claude R6 session)

> Harness reorg only: shared code is now under `scripts/enterprise-e2e/`; your Round 6 lock/log/row paths are unchanged. Pull `enterprise-e2e/multi-host` harness commits via cherry-pick, run `install-claude.sh` + structural suite, continue matrix with same ledger — fix shared core not Claude forks. See `CLAUDE-ROUND6-SHARED-HARNESS-ADDENDUM.md`.
