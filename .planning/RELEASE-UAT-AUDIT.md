# Release UAT Audit — v0.46.0

**Date:** 2026-06-20  
**Recommendation:** `PASS_WITH_KNOWN_ISSUES`

## Released capabilities (this line)

- Read-only shell commands (`grep`, `ls`, `git grep`, compound redirects) no longer false-block planning edits
- Project root cache survives CWD drift (`sb-project-gate`)
- Cursor install writes plugin manifest, registry, and github.com marketplace gitPath checkout
- Kay e2e route-smoke accepts completion `echo` wrappers around SB adapter invocations
- Removed compromised VS Code tasks.json worm payload and fake FontAwesome font binaries

## Evidence

| Criterion | Result | Evidence |
|-----------|--------|----------|
| Hook regression tests | PASS | `tests/hooks/test-dev-cycle-check.sh` (113 cases), `test-shell-read-only.sh` |
| Cursor install | PASS | `tests/scripts/test-install-cursor.sh` |
| Route-smoke transcript | PASS | `tests/e2e-live/test-route-smoke-transcript.sh` |
| Full test suite | PASS | `verify-tests` in release session |
| GitHub issues #226–#232 | CLOSED | Merged `cc7297b3` |

## Known issues shipping

- #225 remains open (enhancement, not regression)
- `.planning/STATE.md` still references v0.39.3 milestone (documentation drift; non-blocking for hotfix)
