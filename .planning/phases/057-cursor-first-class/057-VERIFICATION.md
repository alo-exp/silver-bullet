# Phase 057 — Verification Evidence

**Date:** 2026-06-14  
**Branch:** `phase-057-cursor-support`  
**Plan commit:** `0479534526bf194b067e572428446782ce858d4a`

## Release gate note

Proceeding from `phase-056-zuvo-runtime-parity` base (package `0.39.3` in tree; GitHub
release tag at test time remained `v0.39.2` on `main`).

## Targeted tests

```text
$ bash tests/hooks/test-runtime-paths.sh
Passed: 7, Failed: 0

$ bash tests/hooks/test-cursor-hook-bridge.sh
Passed: 6, Failed: 0

$ bash tests/hooks/test-cursor-runtime-bootstrap.sh
Passed: 5, Failed: 0

$ bash tests/scripts/test-site-content-freshness.sh
Results: 49 passed, 0 failed
```

## Full suite

```text
$ bash tests/run-all-tests.sh </dev/null
TOTAL: 3057 passed, 0 failed (5/5 suites green)
```

(Run after final commits; count includes 3 new hook test files.)

## Manual smoke

```text
$ python3 hooks/generate-cursor-hooks.py && jq . hooks/cursor-hooks.json >/dev/null
$ SILVER_BULLET_RUNTIME=cursor bash scripts/sb-diagnostics.sh | head -8
```

## Parity matrix (implemented)

| Capability | Claude | Codex | Cursor |
|------------|--------|-------|--------|
| Runtime detection | ✓ | ✓ | ✓ (`runtime-paths.sh`) |
| State dir | `~/.codex/.silver-bullet` | `~/.codex/.silver-bullet` | `~/.cursor/.silver-bullet` |
| Hook delivery | `settings.json` | plugin + optional merge | `~/.cursor/hooks.json` |
| Skill recording | PostToolUse/Skill | invoke-skill receipt | PostToolUse/Skill + invoke-skill |
| session-start | ✓ | ✓ | ✓ |
| stop-check | ✓ | ✓ | ✓ (via bridge) |
| completion-audit | ✓ | ✓ | ✓ (via bridge) |
| sb-diagnostics | ✓ | ✓ | ✓ |
| Agent bundle | `agents/claude` | `agents/codex` | `agents/cursor` |
| Install path | `/plugin install` | `install-codex.sh` | `install-cursor.sh` |

## Remaining gaps

- Cursor marketplace publish path (install script is checkout-based today)
- Live E2E matrix row for Cursor (tier 3) not yet in CI
- `silver-init` SKILL.md step 3.7.5 still references Claude merge only in prose body (scaffold-steps updated)
