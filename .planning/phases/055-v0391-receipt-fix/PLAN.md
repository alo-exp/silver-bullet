# PLAN — v0.39.1 patch release

## Goal

Ship `#221` receipt-persistence fix and `ab12e86` scan discovery as `v0.39.1`.

## Wave 1 — Land fix

| Task | Files | Verification |
|------|-------|--------------|
| Commit cross-runtime receipt lookup | `hooks/lib/runtime-paths.sh`, `hooks/record-skill.sh`, `tests/hooks/test-record-skill.sh` | `bash tests/hooks/test-record-skill.sh` → 44 passed |
| Close `#221` with commit SHA + test evidence | GitHub issue | Issue closed |

## Wave 2 — Release gate

| Task | Verification |
|------|--------------|
| `bash scripts/verify-tests.sh` | Fresh verify-tests marker |
| Release live matrix (if required by profile) | `bash scripts/run-release-live-matrix.sh` |
| Update CHANGELOG + marketplace versions | `bash scripts/sync-release-marketplace-versions.sh v0.39.1` |
| Tag + GitHub Release | `gh release view v0.39.1` |

## TDD policy

Hook/bash changes covered by existing regression tests; no application code.

## Dependencies

- `ab12e86` already on `main`; CI green.
- User must approve git commit/push for release artifacts.

## Rollback

Revert tag and release if post-release smoke fails; patch is isolated to receipt lookup.
