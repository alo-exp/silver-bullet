# Pre-Release Checklist — v0.50.5

**Date:** 2026-07-05  
**Prior release:** [v0.50.4](https://github.com/alo-exp/silver-bullet/releases/tag/v0.50.4) — full `run-all-tests.sh` green; **tri-host host smoke not run before tag** (gap this cycle closes).

**Release status:** **SHIPPED** — v0.50.5 tagged after 12/12 tri-host smoke and full gate bundle green.

## Tri-host pre-release host smoke

**Command:** `RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh`  
**Credential:** operator file `~/.silver-bullet/cursor-api-key` (gitignored; not committed)

| Host / stage | Check | Result |
|--------------|-------|--------|
| Structural | `validate-host-agnostic-core.sh` | **PASS** |
| Structural | `validate-host-install-surface.sh` | **PASS** |
| Structural | `validate-host-skill-surface.sh` | **PASS** |
| **Codex** | invoke-skill `silver:verify` | **PASS** |
| **Codex** | `install-codex.sh` (isolated) | **PASS** |
| **Codex** | `sb-diagnostics.sh` (isolated) | **PASS** |
| **Cursor** | invoke-skill `silver:verify` | **PASS** |
| **Cursor** | `release-live-matrix-cursor-smoke.sh` | **PASS** |
| **Cursor** | `pre-release-cursor-cli-smoke.sh` | **PASS** (300s timeout; operator API key) |
| **Claude** | invoke-skill `silver:verify` | **PASS** |
| **Claude** | `install-claude.sh` (isolated) | **PASS** |
| **Claude** | `sb-diagnostics.sh` (isolated) | **PASS** |

**Smoke tally:** **12 passed, 0 failed, 0 skipped**

## Full gate checklist

| Gate | Command | Result |
|------|---------|--------|
| Full test suite | `bash tests/run-all-tests.sh` | **PASS** — 5375 passed, 0 failed (6/6 suites green) |
| APO authoring compliance | `bash scripts/run-apo-authoring-compliance.sh` | **PASS** — 26/26 |
| Host-agnostic core | `bash scripts/validate-host-agnostic-core.sh` | **PASS** |
| Sentinel skills manifest | `bash scripts/validate-sentinel-skills-manifest.sh` | **PASS** — 90/90 |
| Launch review (adversarial) | `bash scripts/validate-launch-review.sh` | **PASS** — status=clean, streak=2 |
| Site content freshness | `bash tests/scripts/test-site-content-freshness.sh` | **PASS** — 14/14 |
| Site doc freshness | `bash tests/scripts/test-site-doc-freshness.sh` | **PASS** — 67/67 |
| Release version alignment | `bash tests/scripts/test-release-version-alignment.sh` | **PASS** — 7/7 (0.50.5) |

## Fixes applied this cycle (repo)

| Area | Change |
|------|--------|
| `scripts/lib/pre-release-host-isolation.sh` | `HOST_API_KEY` alias; operator fallback `~/.silver-bullet/cursor-api-key` |
| `scripts/pre-release-cursor-cli-smoke.sh` | Default timeout 120s → 300s; clearer API key error |
| `scripts/run-pre-release-host-smoke.sh` | Document `HOST_API_KEY` alias in header |
| `tests/scripts/test-pre-release-host-smoke.sh` | Assert HOST_API_KEY + operator key-file wiring |

## Release artifact

- **Version:** 0.50.5
- **Commit:** [349f8400](https://github.com/alo-exp/silver-bullet/commit/349f84009e612c5627bbbd4c871f6b8196b535eb)
- **Tag:** [`v0.50.5`](https://github.com/alo-exp/silver-bullet/releases/tag/v0.50.5)
- **Status:** **RELEASED** 2026-07-05
