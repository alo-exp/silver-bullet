# Pre-Release Run — 2026-07-06

**Baseline release:** [v0.51.1](https://github.com/alo-exp/silver-bullet/releases/tag/v0.51.1) @ `2cb457e7`  
**HEAD at run start:** `1315ceed` (site Stage 4a scan landed during run)  
**Scope:** 100% pre-release gates **excluding live** agent/browser/matrix sessions.

## Gate checklist

| Gate / stage | Command or criterion | Ran? | Result | Notes |
|--------------|----------------------|------|--------|-------|
| **Pre-release gate (CI + site)** | `bash scripts/pre-release-gate.sh` | Yes | **PASS** | 5731 passed, 0 failed (6/6 suites green) after test fix |
| **Stage 1 — ENHANCED adversarial** | `bash scripts/validate-launch-review.sh` | Yes | **PASS** | status=clean, streak=2, manifest=1177/1177 |
| **Stage 2 — SENTINEL per-skill** | `bash scripts/validate-sentinel-skills-manifest.sh` | Yes | **PASS** | 91/91 clean rows |
| **Stage 3 — Code security** | `security` skill on hooks/scripts | Skipped (live) | **N/A** | Structural manifest validators green; no new hook edits this cycle |
| **Stage 4a — Site content freshness** | `test-site-content-freshness.sh` | Yes | **PASS** | 78 assertions (incl. chrome regression) |
| **Stage 4a — Site doc freshness** | `test-site-doc-freshness.sh` | Yes | **PASS** | 4/4 |
| **Stage 4a — 100% site scan** | Manual + [`SITE-RELEASE-AUDIT-20260706.md`](sb-tri-criteria-e2e/SITE-RELEASE-AUDIT-20260706.md) | Yes | **PASS** | Completed in `1315ceed` — changelog, release workflow, orchestrator, enterprise status |
| **Stage 4b — Verification bundle** | `/verify-tests`, `/silver:verify`, host smoke, overlay | Partial | **Structural only** | See rows below; live host smoke skipped |
| **Release version alignment** | `test-release-version-alignment.sh` | Yes | **PASS** | 7/7 @ 0.51.1 |
| **Template parity** | `test-silver-bullet-template-parity.sh` | Yes | **PASS** | 2/2 |
| **Bundle freshness** | `test-render-agent-bundle-freshness.sh` | Yes | **PASS** | 364/364 after `sync-codex-package.sh` |
| **APO authoring compliance** | `run-apo-authoring-compliance.sh` | Yes | **PASS** | 26/26 |
| **APO catalog schema** | `test-apo-catalog-schema.sh` | Yes | **PASS** | 45/45 |
| **Dynamic composition audit** | `test-dynamic-composition-audit.sh` | Yes | **PASS** | 7/7 |
| **Host-agnostic core** | `validate-host-agnostic-core.sh` | Yes | **PASS** | OK |
| **Tri-criteria structural** | `test-sb-tri-criteria-e2e.sh` | Yes | **PASS** | 33/33 (no greenfield live re-run) |
| **E2E validation overlay** | `run-enterprise-e2e-validation-overlay.sh --dry-run` | Yes | **PASS** | 6/6 |
| **Tri-host host smoke** | `run-pre-release-host-smoke.sh` | Skipped (live) | **N/A** | Requires HOST_API_KEY + live CLIs |
| **Live matrix** | `run-release-live-matrix.sh` | Skipped (live) | **N/A** | Per scope exclusion |
| **E2E live harness** | `tests/e2e-live/run-e2e-live-tests.sh` | Skipped (live) | **N/A** | Structural e2e-live suite ran inside `run-all-tests.sh` |
| **Enterprise E2E live** | `SB_ENTERPRISE_E2E_LIVE=1` | Skipped (live) | **N/A** | tmux agent-claude excluded |

## Failures found and fixed

| Failure | Fix |
|---------|-----|
| `test-semantic-compress-hook.sh` — 6 failures (repo `.planning/` polluted hook isolation) | Isolated hook tests to temp SB fixture without phase files |
| `test-render-agent-bundle-freshness.sh` — 4 drift rows (`silver-create-release` mirrors) | `bash scripts/sync-codex-package.sh` |

## Release decision

| Change class | Action |
|--------------|--------|
| Site-only (`certification-status.json` timestamp) | Site publish commit — **no version bump** |
| Runtime (`test-semantic-compress-hook.sh`, bundle sync, template base doc) | **v0.51.2 patch** warranted |

## pre-release-gate.sh wiring

`scripts/pre-release-gate.sh` already runs Stage 4a site freshness tests before `run-all-tests.sh` (landed `1315ceed`). No additional wiring required this cycle.

## Release artifact

- **Version:** 0.51.2
- **Commit:** [8cfb66db](https://github.com/alo-exp/silver-bullet/commit/8cfb66db85f46e8369c6a58b424bef254d2515b9)
- **Tag:** [`v0.51.2`](https://github.com/alo-exp/silver-bullet/releases/tag/v0.51.2)
- **Remote CI:** **GREEN** on `8cfb66db` (CI + Secret Scan)
- **Status:** **RELEASED** 2026-07-06
