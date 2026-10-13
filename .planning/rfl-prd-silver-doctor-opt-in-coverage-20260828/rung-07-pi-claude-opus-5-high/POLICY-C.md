# Policy C — Pi Claude Opus 5 High

- **Rung identity:** Pi Claude Opus 5 High (`claude` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:**
  - F-7-1
  - F-7-2
- **Mediums:**
  - F-7-3
  - F-7-4
  - F-7-5
  - F-7-6
  - F-7-7
  - F-7-8

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| F-7-1 | Config↔allowlist↔SKILL parity test is never required |
| F-7-2 | Closing --fix first-match break widens blast radius without a scope map |

### MED

| ID | Title |
|----|-------|
| F-7-3 | Locked WARNs missing a path through the D10 state mapping |
| F-7-4 | Non-TTY and TTY-decline give contradictory partial-write contracts |
| F-7-5 | Unrecognised opted-in key produces a silently green tree |
| F-7-6 | Registry never resolved to a single source-controlled pin file |
| F-7-7 | Absent keys and reconciler-state migration are undefined |
| F-7-8 | AC 8 conflicts with NF4 and omits plugin-command regeneration |

### LOW

| ID | Title |
|----|-------|
| F-7-9 | FAIL or WARN test-plan rows are not assertable |
| F-7-10 | DOCTOR_FIX_APPLIED early-return vs one-pass convergence |
| F-7-11 | Tests assert evidence id with no vocabulary |

### NIT

| ID | Title |
|----|-------|
| F-7-12 | Repo-root links from .planning/ and dead file targets |
| F-7-13 | Test-plan preamble scopes per-tool but most rows are global |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| F-7-1 | HIGH | ACCEPT | Session A must ship an enumeration/parity test: every recommended_tools key + derived cross_tool (+ omniroute in Phase 3) appears in RT_COMPONENT_IDS/extra-tool, registry, rt_run_component, and SKILL D10 table |
| F-7-2 | HIGH | ACCEPT | Legacy D* mutations gated by --fix= keyword; D4/D13-D19/D21 are --fix=host; D20 export scaffold local; mutex clear host; --fix=local must not run host mutations |
| F-7-3 | MED | ACCEPT | Generalize I-37: every locked WARN is core Health ready + named warning evidence |
| F-7-4 | MED | ACCEPT | Confirmation unobtainable (non-TTY without SB_DOCTOR_ASSUME_YES=1 or TTY decline/EOF) means no writes for the whole --fix invocation |
| F-7-5 | MED | ACCEPT | Opted-in unknown JSON key WARNs with key name (unknown_key); no installer; doctor exit nonzero; other components not FAIL-poisoned |
| F-7-6 | MED | ACCEPT | hooks/lib/recommended-tools-registry.sh is the authoritative source-controlled command/version pin; never merged from project .silver-bullet.json |
| F-7-7 | MED | ACCEPT | Absent key ≡ opted-out PASS N/A pending; do not scaffold keys; new RT_COMPONENT_IDS id with no prior state is first-run pending |
| F-7-8 | MED | ACCEPT | AC 8 inherits NF4: generate-plugin-commands.sh when doctor-facing SKILL/command text changes; do not require run-all-tests.sh |
| F-7-9 | LOW | ACCEPT | RTK/CM/LeanCTX min_version below pin is FAIL; Graphify skill/package skew stays WARN; Health URL without instance identity is WARN |
| F-7-10 | LOW | ACCEPT | Convergence is one ordered pass in one invocation; DOCTOR_FIX_APPLIED set at end; no unbounded fixpoint |
| F-7-11 | LOW | ACCEPT | Canonical evidence ids D10-<component>.<reason> including missing_cli, provider_missing, version_drift, vendor_skip, unsupported_package_manager, busy, provider_expired, unknown_key, no_five_tool_consent |
| F-7-12 | NIT | ACCEPT | Prefix repo-root links with ../ from .planning/; do not link missing docs/TROUBLESHOOTING.md or probe-search_cli.sh as live files |
| F-7-13 | NIT | ACCEPT | Tag test-plan rows per-tool vs global; global rows are not multiplied per tool |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| F-7-1 | HIGH | parity test | ACCEPT | yes |
| F-7-2 | HIGH | scope map | ACCEPT | yes |
| F-7-3 | MED | WARN mapping | ACCEPT | yes |
| F-7-4 | MED | confirmation unobtainable | ACCEPT | yes |
| F-7-5 | MED | unknown_key WARN | ACCEPT | yes |
| F-7-6 | MED | registry file pin | ACCEPT | yes |
| F-7-7 | MED | absent key pending | ACCEPT | yes |
| F-7-8 | MED | plugin command regen | ACCEPT | yes |
| F-7-9 | LOW | assertable FAIL vs WARN | ACCEPT | yes |
| F-7-10 | LOW | ordered-pass DOCTOR_FIX_APPLIED | ACCEPT | yes |
| F-7-11 | LOW | evidence-id vocabulary | ACCEPT | yes |
| F-7-12 | NIT | .planning/ link prefix | ACCEPT | yes |
| F-7-13 | NIT | per-tool vs global tests | ACCEPT | yes |

