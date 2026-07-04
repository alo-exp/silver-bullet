# Pre-Release Checklist — v0.50.5

**Date:** 2026-07-05  
**Prior release:** [v0.50.4](https://github.com/alo-exp/silver-bullet/releases/tag/v0.50.4) — full `run-all-tests.sh` green; **tri-host host smoke not run before tag** (gap this cycle closes).

## Tri-host pre-release host smoke

**Command:** `RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh`  
**Companion:** `bash scripts/validate-host-skill-surface.sh` (included in smoke script)

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
| **Cursor** | `pre-release-cursor-cli-smoke.sh` | **FAIL** — `CURSOR_API_KEY` / `HOST_API_KEY` unset; Keychain OAuth token invalid as `--api-key` |
| **Claude** | invoke-skill `silver:verify` | **PASS** |
| **Claude** | `install-claude.sh` (isolated) | **PASS** |
| **Claude** | `sb-diagnostics.sh` (isolated) | **PASS** |

**Smoke tally:** 11 passed, **1 failed**, 0 skipped (12 checks)

### Cursor CLI smoke blocker (release gate)

Isolated fake-`HOME` smoke requires a **user API key** (`cursor_...` from [Cursor Dashboard → Integrations](https://cursor.com/dashboard/integrations)), passed via:

```bash
export CURSOR_API_KEY='cursor_...'   # or HOST_API_KEY (alias)
# optional persistent operator file (gitignored): ~/.silver-bullet/cursor-api-key
RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh
```

- `cursor-agent login` / Keychain auth works for live matrix drivers but **not** for isolated pre-release CLI smoke (by design).
- OAuth `cursor-access-token` from Keychain is **not** accepted as `--api-key`.

**Release status:** **BLOCKED** — do not tag v0.50.5 until Cursor CLI smoke passes.

## Full gate checklist (non-smoke)

| Gate | Command | Result |
|------|---------|--------|
| Full test suite | `bash tests/run-all-tests.sh` | **PASS** — 5349 passed, 0 failed (6/6 suites green) |
| APO authoring compliance | `bash scripts/run-apo-authoring-compliance.sh` | **PASS** — 26/26 |
| Host-agnostic core | `bash scripts/validate-host-agnostic-core.sh` | **PASS** |
| Sentinel skills manifest | `bash scripts/validate-sentinel-skills-manifest.sh` | **PASS** — 90/90 |
| Site content freshness | `bash tests/scripts/test-site-content-freshness.sh` | **PASS** — 14/14 |
| Site doc freshness | `bash tests/scripts/test-site-doc-freshness.sh` | **PASS** — 67/67 |
| Release version alignment | `bash tests/scripts/test-release-version-alignment.sh` | **PASS** — 7/7 (still 0.50.4) |

## Fixes applied this cycle (repo)

| Area | Change |
|------|--------|
| `scripts/lib/pre-release-host-isolation.sh` | `HOST_API_KEY` alias; operator fallback `~/.silver-bullet/cursor-api-key` |
| `scripts/pre-release-cursor-cli-smoke.sh` | Clearer error + dashboard link for API key minting |
| `scripts/run-pre-release-host-smoke.sh` | Document `HOST_API_KEY` alias in header |
| `tests/scripts/test-pre-release-host-smoke.sh` | Assert HOST_API_KEY + operator key-file wiring |

## Next steps to ship v0.50.5

1. Operator: mint/copy `cursor_...` API key → `export CURSOR_API_KEY=...` or `~/.silver-bullet/cursor-api-key`
2. Re-run tri-host smoke until **12/12 PASS** + marker written
3. Complete remaining quality-gate markers (adversarial, stage-3 site bump, live matrix, CI wait)
4. Bump 0.50.4 → 0.50.5, sync bundles, commit, tag, `gh release create`
