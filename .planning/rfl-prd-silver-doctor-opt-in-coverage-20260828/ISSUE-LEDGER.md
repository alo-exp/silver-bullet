# ISSUE-LEDGER — PRD silver-doctor opt-in coverage

**Artifact:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../PRD-silver-doctor-opt-in-coverage.md)

IDs: `I-1` … sequential across rungs. Do not reuse numbers.

## Master inventory

| ID | Sev | Summary | First rung | ACCEPT | Applied |
|----|-----|---------|------------|--------|---------|
| I-1 | HIGH | Lock `SB_DOCTOR_ASSUME_YES=1` for non-interactive `--fix` tests (F-1) | rung-01 GLM 5.2 High | yes | yes |
| I-2 | HIGH | Lock Session A defaults for OQ1/OQ2/OQ5; AC 11 requires them (F-2) | rung-01 GLM 5.2 High | yes | yes |
| I-3 | MED | Unknown component id → PASS N/A `unsupported`; no installer (F-3) | rung-01 GLM 5.2 High | yes | yes |
| I-4 | MED | Test plan: false-green catalog + min_version + assume-yes rows (F-4) | rung-01 GLM 5.2 High | yes | yes |
| I-5 | MED | AC 8 includes `test-router-doctor-report.sh` when phase 3 lands (F-5) | rung-01 GLM 5.2 High | yes | yes |
| I-6 | MED | AC 9 reframed as positive unused-path fixture (F-6) | rung-01 GLM 5.2 High | yes | yes |
| I-7 | LOW | Remove Phase 1 `--fix` swallow hedge (F-7) | rung-01 GLM 5.2 High | yes | yes |
| I-8 | LOW | D10 FAIL is contract; D22 WARN is catalog label only (F-8) | rung-01 GLM 5.2 High | yes | yes |
| I-9 | LOW | OAuth fully manual; `--fix` install/restart only (F-9) | rung-01 GLM 5.2 High | yes | yes |
| I-10 | LOW | Lock `recommended_tools.omniroute` / `D10-omniroute` (F-10) | rung-01 GLM 5.2 High | yes | yes |
| I-11 | LOW | search_cli Health = PATH + version; provider-missing WARN (F-11) | rung-01 GLM 5.2 High | yes | yes |
| I-12 | NIT | Drop session-specific `3ht3` MUST NOT (F-12) | rung-01 GLM 5.2 High | yes | yes |
| I-13 | NIT | Gloss HNEST-01 / HINST-01 (F-13) | rung-01 GLM 5.2 High | yes | yes |
| I-14 | NIT | Cite freeze headings, not line numbers (F-14) | rung-01 GLM 5.2 High | yes | yes |
| I-15 | LOW | `D10-routes` no-consent is PASS not WARN (F-2-1) | rung-02 Kimi K3 High | yes | yes |
| I-16 | LOW | Lock vendor-doctor hermetic path (F-2-2 / OQ4) | rung-02 Kimi K3 High | yes | yes |
| I-17 | LOW | Unknown-id test asserts PASS N/A `unsupported` (F-2-3) | rung-02 Kimi K3 High | yes | yes |
| I-18 | LOW | Coverage table includes derived `cross_tool` (F-2-4) | rung-02 Kimi K3 High | yes | yes |
| I-19 | LOW | AC 9 canary vs fail phrasing (F-2-5) | rung-02 Kimi K3 High | yes | yes |
| I-20 | LOW | Phase 2 `docs_pin` backfill (F-2-6) | rung-02 Kimi K3 High | yes | yes |
| I-21 | NIT | Merge duplicate vendor-doctor test rows (F-2-7) | rung-02 Kimi K3 High | yes | yes |
| I-22 | NIT | Sequential OQ numbering 1–5 locked / 6–7 open (F-2-8) | rung-02 Kimi K3 High | yes | yes |
| I-23 | NIT | Implementer prompt `SB_DOCTOR_ASSUME_YES=1` (F-2-9) | rung-02 Kimi K3 High | yes | yes |
| I-24 | LOW | Phase 1 must update `rt_scope_includes_component` for `search_cli` packages (F-3-1) | rung-03 Gemini 3.7 Flash High | yes | yes |
| I-25 | NIT | Merge duplicate stale checks.sh test rows (F-3-2) | rung-03 Gemini 3.7 Flash High | yes | yes |
| I-26 | NIT | Sibling freeze links from PRD under `.planning/` (F-3-3) | rung-03 Gemini 3.7 Flash High | yes | yes |
| I-27 | MED | `search_cli` host = Cursor/Claude/Codex, not Alumnium Cursor-only (F-4-1) | rung-04 Grok 4.6 High | yes | yes |
| I-28 | LOW | Live `rt_scope_includes_component` is three-way including `cross_tool` (F-4-2) | rung-04 Grok 4.6 High | yes | yes |
| I-29 | LOW | Propagate `--fix=packages` / `rt_scope_includes_component` to test, SKILL examples, prompt (F-4-3) | rung-04 Grok 4.6 High | yes | yes |
| I-30 | LOW | PATH/`command -v` Health ban is “alone”; search_cli is PATH+version (F-4-4) | rung-04 Grok 4.6 High | yes | yes |
| I-31 | LOW | `D10-routes` no-consent is PASS not PASS N/A (F-4-5) | rung-04 Grok 4.6 High | yes | yes |
| I-32 | LOW | Test rows: provider-missing WARN, PATH-without-version; keep `required_when_enabled: false` (F-4-6) | rung-04 Grok 4.6 High | yes | yes |
| I-33 | NIT | Prompt names `omniroute` / hermetic vendor-doctor (F-4-7) | rung-04 Grok 4.6 High | yes | yes |
| I-34 | HIGH | Known-id `install_commands` must be registry-pinned; tampered payload refuses (F-5-1) | rung-05 Pi Codex Sol High | yes | yes |
| I-35 | HIGH | No-secret tests cover stdout, stderr, JSON, receipts (F-5-2) | rung-05 Pi Codex Sol High | yes | yes |
| I-36 | MED | Per-component `--fix` repair-dispatch tests (F-5-3) | rung-05 Pi Codex Sol High | yes | yes |
| I-37 | MED | Provider-missing WARN = ready + warning evidence (F-5-4) | rung-05 Pi Codex Sol High | yes | yes |
| I-38 | MED | Non-TTY without assume-yes skips mutations, nonzero (F-5-5) | rung-05 Pi Codex Sol High | yes | yes |
| I-39 | MED | Failed/malformed apply is observable, not success (F-5-6) | rung-05 Pi Codex Sol High | yes | yes |
| I-40 | HIGH | Phase 3 gated on WS6 installer; else defer (F-5-7) | rung-05 Pi Codex Sol High | yes | yes |
| I-41 | MED | Omni current-host CLI matrix (F-5-8) | rung-05 Pi Codex Sol High | yes | yes |
| I-42 | MED | Deferred Omni is a footnote, not an F4 row (F-5-9) | rung-05 Pi Codex Sol High | yes | yes |
| I-43 | LOW | `cross_tool` `docs_pin` is SB-owned contract pin (F-5-10) | rung-05 Pi Codex Sol High | yes | yes |
| I-44 | HIGH | Phase 3 Omni registry/`rt_run_component`/scopes (F-6-1) | rung-06 Pi Codex Sol Extra High | yes | yes |
| I-45 | MED | `--fix=all` one-invocation multi-failure convergence (F-6-2) | rung-06 Pi Codex Sol Extra High | yes | yes |
| I-46 | MED | Vendor-doctor skip is not Health evidence (F-6-3) | rung-06 Pi Codex Sol Extra High | yes | yes |
| I-47 | MED | `/sb:doctor` executable alias, not docs-only (F-6-4) | rung-06 Pi Codex Sol Extra High | yes | yes |
| I-48 | LOW | TTY decline/EOF: no writes, nonzero (F-6-5) | rung-06 Pi Codex Sol Extra High | yes | yes |
| I-49 | LOW | `search_cli` brew platform vs agent-host matrix (F-6-6) | rung-06 Pi Codex Sol Extra High | yes | yes |
| I-50 | MED | Omni busy WARN / expired WARN, no auto re-auth (F-6-7) | rung-06 Pi Codex Sol Extra High | yes | yes |
| I-51 | MED | Versioned `search_cli` formula pin vs `docs_pin` (F-6-8) | rung-06 Pi Codex Sol Extra High | yes | yes |
| I-52 | HIGH | Config↔allowlist↔SKILL parity test (F-7-1) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-53 | HIGH | `--fix=` scope → D-check eligibility map (F-7-2) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-54 | MED | Locked WARNs = ready Health + warning evidence (F-7-3) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-55 | MED | Confirmation unobtainable → no writes for whole `--fix` (F-7-4) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-56 | MED | Opted-in unknown JSON key WARN `unknown_key` + nonzero (F-7-5) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-57 | MED | Registry file is the authoritative `install_commands` pin (F-7-6) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-58 | MED | Absent key ≡ PASS N/A `pending`; no scaffold (F-7-7) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-59 | MED | AC 8: `generate-plugin-commands.sh` when doctor SKILL/command text changes (F-7-8) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-60 | LOW | Disjunctions: min_version FAIL; Graphify skew WARN; Health URL identity WARN (F-7-9) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-61 | LOW | One ordered pass; `DOCTOR_FIX_APPLIED` at end of invocation (F-7-10) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-62 | LOW | Canonical D10 evidence-id vocabulary (F-7-11) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-63 | NIT | `.planning/` `../` links; do not link missing TROUBLESHOOTING/probe files as live (F-7-12) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-64 | NIT | Test-plan rows tagged per-tool vs global (F-7-13) | rung-07 Pi Claude Opus 5 High | yes | yes |
| I-65 | HIGH | Severity→exit: FAIL nonzero; WARN zero except `unknown_key` (F-8-1) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-66 | MED | Graphify skew WARN expected; `--fix` none; green = no FAIL (F-8-2) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-67 | MED | `required_when_enabled` is hook enforcement, not D10 honesty (F-8-3) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-68 | MED | No downgrade newer-than-pin; older-than-pin repairable (F-8-4) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-69 | MED | Test rows for `duplicate_key` and `no_five_tool_consent` (F-8-5) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-70 | MED | Confirmation gate is plan-triggered (F-8-6) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-71 | LOW | Host-install set is D13/D14/D16/D18/D19 (F-8-7) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-72 | LOW | Omni D10 = current doctor host CLI only (F-8-8) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-73 | LOW | Unsupported PM skip: `DOCTOR_FIX_APPLIED=0`, WARN-class exit (F-8-9) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-74 | LOW | Omni PASS N/A only after Phase 3 (F-8-10) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-75 | NIT | Origin review `759a2827` as inline code (F-8-11) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |
| I-76 | NIT | Status ready for Session A implementation (F-8-12) | rung-08 Pi Claude Opus 5 Extra High | yes | yes |

## Counts

| HIGH | MED | LOW | NIT |
|------|-----|-----|-----|
| 9 | 27 | 27 | 13 |

## Residuals open

none (rung 1–8 ACCEPTs applied)
