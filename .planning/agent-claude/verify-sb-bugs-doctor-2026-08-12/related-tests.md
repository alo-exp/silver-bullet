# Related tests — doctor newline / printf JSON write

- **Worktree:** `/Users/shafqat/projects/silver-bullet/repo-doctor-newline`
- **Branch:** `fix/sb-bugs-doctor-newline`
- **bash -n:** PASS
- **Suites pass:** 19
- **Suites fail:** 1
- **Suites skip (preferred missing):** 4

| Status | Suite | Notes |
|--------|-------|-------|
| PASS | `tests/hooks/test-orchestrator-directive.sh` |  |
| SKIP | `tests/hooks/test-orchestrator-state.sh` | missing; no dedicated suite |
| SKIP | `tests/hooks/test-orchestrator-event-log.sh` | missing; closest tests/scripts/test-orchestrator-event-log.sh PASS |
| SKIP | `tests/hooks/test-orchestrator-parent.sh` | missing; closest tests/hooks/test-orchestrator-parent-guard.sh PASS |
| PASS | `tests/hooks/test-enforcement-tier.sh` |  |
| SKIP | `tests/scripts/test-recommended-tools-common.sh` | missing; closest recommended-tools + policy suites PASS |
| PASS | `tests/hooks/test-orchestrator-delegation-directive.sh` |  |
| PASS | `tests/hooks/test-orchestrator-non-sb-workspace-guard.sh` |  |
| PASS | `tests/hooks/test-orchestrator-parent-guard.sh` |  |
| PASS | `tests/hooks/test-orchestrator-queue-order.sh` |  |
| PASS | `tests/hooks/test-orchestrator-worker-handoff.sh` |  |
| PASS | `tests/hooks/test-orchestrator-worker-templates.sh` |  |
| PASS | `tests/hooks/test-orchestrator-workflow-csv.sh` |  |
| PASS | `tests/hooks/test-recommended-tools-registry.sh` |  |
| PASS | `tests/hooks/test-recommended-tools.sh` |  |
| PASS | `tests/hooks/test-session-start-recommended-tools.sh` |  |
| PASS | `tests/scripts/test-atomic-flow-dedup.sh` |  |
| PASS | `tests/scripts/test-atomic-flow-nonredundancy.sh` |  |
| PASS | `tests/scripts/test-atomic-flow-vloop.sh` |  |
| PASS | `tests/scripts/test-orchestrator-event-log.sh` |  |
| PASS | `tests/scripts/test-recommended-tools-policy.sh` |  |
| PASS | `tests/scripts/test-reconcile-recommended-tools.sh` |  |
| PASS | `tests/scripts/test-sb-doctor-host-surface.sh` |  |
| FAIL | `tests/scripts/test-silver-doctor.sh` | FAIL: doctor --dry-run dirtied .silver-bullet.json; before=60608079 84 /var/folders/d8/f43nf6b17p31q9qzj5c82_nw0000gn/T/tmp.kgamWsB6zj/.silver-bullet.json; after=2686554480 83 /var/folders/d8/f43nf6b17p31q9qzj5c82_nw0000gn/T/tmp.kgamWsB6zj/.silver-bullet.json; eof=7d |

## Failures (first error lines)

### `tests/scripts/test-silver-doctor.sh`
- FAIL: doctor --dry-run dirtied .silver-bullet.json
- `before=60608079 84 /var/folders/d8/f43nf6b17p31q9qzj5c82_nw0000gn/T/tmp.kgamWsB6zj/.silver-bullet.json`
- `after=2686554480 83 /var/folders/d8/f43nf6b17p31q9qzj5c82_nw0000gn/T/tmp.kgamWsB6zj/.silver-bullet.json`
- `eof=7d`

Full log: [`related-tests.log`](related-tests.log)
