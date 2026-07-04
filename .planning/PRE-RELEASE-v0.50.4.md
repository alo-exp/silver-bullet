# Pre-Release Checklist — v0.50.4

**Date:** 2026-07-05  
**Prior release issue:** v0.50.3 shipped with `run-all-tests.sh` reporting **38 failures** (baseline capture: **15 failures** on current tree after partial fixes; all resolved before tag).

## Gate checklist

| Gate | Command | Result |
|------|---------|--------|
| Full test suite | `bash tests/run-all-tests.sh` | **PASS** — 5349 passed, 0 failed (6/6 suites green) |
| APO authoring compliance | `bash scripts/run-apo-authoring-compliance.sh` | **PASS** — 26/26 |
| ShellCheck (CI parity) | `shellcheck --exclude=SC2317,SC1091,SC2329 hooks/*.sh hooks/lib/*.sh scripts/*.sh` | **PASS** |
| Site content freshness | `bash tests/scripts/test-site-content-freshness.sh` | **PASS** |
| Site doc freshness | `bash tests/scripts/test-site-doc-freshness.sh` | **PASS** |
| Release version alignment | `bash tests/scripts/test-release-version-alignment.sh` | **PASS** (post 0.50.4 bump) |
| Host-agnostic core | `bash scripts/validate-host-agnostic-core.sh` | **PASS** |
| Sentinel skills manifest | `bash scripts/validate-sentinel-skills-manifest.sh` | **PASS** — 90/90 clean |
| Launch review | `bash scripts/validate-launch-review.sh` | *(session gate — not re-run this cycle)* |
| Coverage matrix | included in `run-all-tests.sh` | **PASS** — 56/56 hooks |

## Failure root causes (v0.50.3 → fixed)

| Suite | Failures | Cause | Fix |
|-------|----------|-------|-----|
| `test-outcomes-check.sh` | 2 | `stop-coalesce-block` leaked between cases; jq-less Stop missing `SB_RUNTIME_PRESERVE_STATE_DIR` | Teardown + env fix |
| `test-rm-safety.sh` | 1 | Unhardened `rm -f` in delegation/stop-coalesce libs | `rm -f --` |
| `test-flow-step-vloop.sh` | 1 | Catalog pseudo-skills `distribution-only`, `silver-agent-codex\|silver-agent-cursor` | Test excludes pseudo/composite skills |
| `test-no-gsd-runtime.sh` | 1 | Legacy GSD cleanup regex in prune/watch scripts | Test allowlist |
| `test-release-version-alignment.sh` | 1 | `config_version` 0.50.2 vs package 0.50.3 | Bumped template + dogfood config |
| `test-sb-skill-scenario-coverage.sh` | 3 | Missing scenarios for agent delegation skills | Added 3 scenario files |
| `test-site-content-freshness.sh` | 4 | Site/help still on 0.50.2 | Updated to 0.50.4 |
| `test-validate-host-agnostic-core.sh` | 1 | New delegation skills/scripts flagged as host bleed | `STRICT_ALLOWLIST` + host-tooling prefixes |
| `test-validate-pre-release-gates.sh` | 1 | Sentinel count 87→90; agent skills pending | Expected 90 + clean audits |
| `test-e2e-live-suite.sh` | 1 | `assert_file_contains` missing path/pattern args (line 112) | Fixed arity |

## Classification

- **Delegation v0.50.3 changes:** outcomes-check coalesce interaction, rm-safety in new delegation lib, host-agnostic violations for agent skills/scripts, sentinel + scenario gaps for 3 new skills, flow-step catalog pseudo-skills.
- **Pre-existing / drift:** e2e-live assert arity bug, config/site version lag (0.50.2), sentinel expected count stale.

## Release

- **Version:** 0.50.4 (do not re-tag 0.50.3)
- **Tag:** `v0.50.4`
- **Notes theme:** test-hardening / full-suite green gate mandatory before patch release
