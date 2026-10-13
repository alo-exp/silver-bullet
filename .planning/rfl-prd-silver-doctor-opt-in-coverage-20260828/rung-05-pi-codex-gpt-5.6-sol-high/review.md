# Rung 05 review — Pi Codex GPT-5.6 Sol High

**Phase:** REVIEW-ONLY (`rung_5_review`)  
**Target:** `.planning/PRD-silver-doctor-opt-in-coverage.md`  
**Prior-findings guard:** I-1…I-33 were treated as locked and were not re-filed.

## Review summary

The PRD has a strong Session A / Session B boundary, correctly isolates Omni from the five-tool probes, and carries the locked `search_cli`, host, N/A, mutex, docs-pin, and `--fix=packages` decisions. The remaining new gaps are concentrated in executable trust boundaries, observability of apply failures, proof depth for “every tool,” and the conditional Omni phase.

## Raw findings

### F-5-1 — HIGH — A known component id is treated as sufficient authorization to execute mutable `install_commands`

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:46-49` — Session A is allowlisted and unknown tools fail closed.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:58` — “Names, URLs, or `install_commands` not on the allowlist do not execute.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:200` — Setup may use “`install_commands` from **allowlisted** config only.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:250` — forbids arbitrary names, URLs, or `install_commands` from untrusted JSON.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:288,311,405,408,451` — permits config `install_commands` for `--fix=packages` and the `search_cli` proof.

The PRD never defines whether “allowlisted” authenticates only the component id (`search_cli`) or the exact command payload. If a project-local `.silver-bullet.json` keeps the known key but replaces its `install_commands`, an implementation can satisfy the literal component allowlist while executing arbitrary shell. This is the same generic-installer hazard under a recognized id. The contract needs an immutable trusted source and exact validation rule (for example, repository-owned registry/script or exact pinned argv/digest), plus a tampered-known-key test that refuses execution. Merely checking `RT_COMPONENT_IDS` is not a command allowlist.

### F-5-2 — HIGH — Secret-safety acceptance omits newly exposed stderr and receipts

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:57` — secrets must never appear in doctor stdout or JSON reports.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:242-245` — reconciler stderr must no longer be swallowed; stdout and JSON must contain no secrets.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:321-326` — preserve stderr and issue receipts.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:456` — the test plan checks only “JSON report | no secrets.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:488` — forbids secrets in reports **or receipts**.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:511` — AC 3 again tests only JSON reports.

Removing `2>/dev/null` deliberately exposes a channel that may contain failed installer/vendor output, while receipts are another persisted channel. No acceptance test covers human stdout, stderr, combined captured output, or receipt content. The PRD also does not state how to retain actionable reconciler diagnostics while redacting them, especially in `SB_DOCTOR_FORMAT=json` mode. An implementation can pass AC 3 while leaking a token on stderr or into a receipt. The no-secret fixture needs sentinel values across stdout, stderr, JSON, and receipts, with JSON stdout remaining parseable when diagnostics are emitted.

### F-5-3 — MED — “Every key has `--fix`” is not proved for the existing allowlist

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:27` — four surfaces are required on every opt-in tool.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:46` — every `recommended_tools` key has Setup / Health / Diagnosis / `--fix`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:54` — every in-scope tool receives a coverage row including a `--fix` action.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:417` — Phase 2 proves `--fix` for “at least one five-tool component.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:443` — per-tool tests apply to newly covered tools, then only one existing five-tool fixture.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:512` — AC 4 requires only one existing allowlisted tool.

A textual table for Graphify, agentmemory, RTK, Context Mode, LeanCTX, and Alumnium plus one representative repair fixture does not prove that each advertised existing-tool `--fix` action is wired to the right scope or converges. Session A can therefore be declared done while several table rows describe dead, skipped, or wrong-scope repair paths. If exhaustive install tests are too expensive, the PRD still needs a per-component repair-dispatch/plan contract test and at least class-level mutation fixtures sufficient to cover every advertised action, rather than one arbitrary five-tool example.

### F-5-4 — MED — `search_cli` provider-missing WARN has no defined reconciler state or doctor mapping

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:98-102` — the complete stated mapping is `ready`→PASS, `disabled|pending|unsupported`→PASS N/A, `suspended|reload_required`→WARN, and `repairable|failed`→FAIL.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:406` — provider-missing must be WARN/Diagnosis text only.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:454` — provider-missing must produce WARN/Diagnosis, not FAIL.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:530` — repeats the locked WARN outcome.

None of the mapped states represents “core CLI Health is ready, optional provider is missing.” Returning `ready` makes `doctor_record_reconciler_d10()` emit PASS; returning `reload_required` or `suspended` lies about the reason; returning `repairable` makes it FAIL. The PRD needs to define the probe-result representation and doctor mapping for advisory evidence (for example, a warning state or warning evidence that upgrades a ready component to WARN) and assert the final D10 status, not just probe text.

### F-5-5 — MED — Non-TTY mutation behavior without `SB_DOCTOR_ASSUME_YES=1` is ambiguous

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:246` — confirmation is required “when stdin is a TTY”; CI “must” set `SB_DOCTOR_ASSUME_YES=1`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:325` — packages/network/daemon restart require confirmation.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:464` — without assume-yes, “confirm/skip — never hang tests.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:531` — humans confirm on a TTY.

The contract does not choose behavior for a real non-interactive invocation with no assume-yes flag: silently apply because confirmation is TTY-only, skip successfully, or fail closed with a nonzero result. “confirm/skip” cannot be implemented deterministically when no TTY exists. This is security-relevant for automation invoking `--fix=packages` or daemon restart. The PRD needs one exit/status/report contract for that case and tests both with and without the override.

### F-5-6 — MED — Failed or malformed reconciler apply has no observable outcome contract

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:32` — current failure is swallowed and empty output is marked applied.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:242` — do not swallow stderr or mark applied on empty JSON.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:321-323` — do not discard stderr, `|| true`, or mark an empty/failed apply successful.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:409` — Phase 1 closes swallowed/empty success.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:511` — AC 3 checks only that false success marking is gone.

The negative rule does not say what doctor must do on reconciler nonzero exit, empty output, malformed JSON, or JSON missing the expected apply fields: whether it records a FAIL check, exits nonzero, continues legacy D13+ repairs, retries checks, or emits which machine-readable error. Thus the bug can be “fixed” by merely leaving `DOCTOR_FIX_APPLIED=0` while the command still exits successfully and gives no actionable result. Add explicit failure semantics and fixtures for nonzero+stderr, empty stdout, and malformed/schema-invalid JSON.

### F-5-7 — HIGH — Phase 3 depends on a WS6-owned installer that does not exist, but no prerequisite or safe deferral rule is specified

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:25` — `scripts/install-omniroute-sb.sh` does not exist today.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:262` — install/init runtime stays WS6.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:317` — Omni `--fix` may install and restart.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:426-428` — Phase 3 adds the component; its install script is “owned by WS6,” while WS7 must provide install/restart.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:515,537` — Omni may be included or deferred, but deferral is framed only as timeboxing.

A Session A/WS7 implementer cannot deliver the required install action without either crossing the stated WS6 ownership boundary or calling a missing script. The PRD does not state that Phase 3 is gated on a landed, versioned WS6 installer, what doctor reports if that dependency is absent, or whether an absent dependency mandates deferral rather than a partial component. This creates a scope/ownership deadlock and invites either an unauthorized duplicate installer or an advertised `--fix` that cannot run.

### F-5-8 — MED — Omni’s five-CLI host matrix is not operationally defined

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:59` — Omni includes five host CLIs.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:175-182` — host table maps Cursor, Claude, Codex, and the combined OpenCode/Goose/Hermes row to CLI names.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:234` — Omni host support is deferred as “freeze later.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:256,270` — names the five CLIs as `claude`, `codex`, `cursor-agent`/`agent`, `opencode`, and `pi`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:428` — Setup requires “host CLIs present for opted hosts.”

It is unclear whether an Omni opt-in requires all five CLIs, only the CLI corresponding to the current doctor host, or a configurable subset. The combined OpenCode/Goose/Hermes row cannot determine whether to inspect `opencode` or `pi`; Pi is not a listed `RT_VALID_HOST`; and `cursor-agent` versus generic `agent` has no precedence/identity rule. There are no per-host N/A/FAIL or repair-scope cases for these CLIs. Phase 3 needs a component-specific host/CLI matrix and tests before “missing host CLI” can have deterministic status or `--fix` behavior.

### F-5-9 — MED — Deferred Omni simultaneously must and must not have a coverage-table row

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:223` — table tests include Omni only “when the WS7 phase lands.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:509` — “Omni rows exist only after phase 3.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:515` — if phase 3 is deferred, the coverage table explicitly lists Omni as “planned WS7, not D10 Graphify.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:537` — repeats the mandatory planned row on deferral.

A planned Omni entry is still a row under the F4 schema, but AC 1 says Omni rows exist only after Phase 3 and F4 tests only include it after WS7 lands. This leaves the implementer and freshness test unable to tell whether a deferred planned row is required, forbidden, or excluded from the schema. Define a distinct pre-Phase-3 planning note/placeholder representation, or explicitly allow a row with sentinel fields and state whether coverage tests count it.

### F-5-10 — LOW — The mandatory `cross_tool` `docs_pin` has no satisfiable pin semantics

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:54,219` — every in-scope tool needs an official URL plus commit/tag/ref from version-matched official docs.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:223-235` — derived `cross_tool` is mandatory and every row has `docs_pin`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:335-352` — upstream-pin starting points exist for each named external tool, but none for `cross_tool`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:420,509` — backfill and AC require a pin on the `cross_tool` row.

`cross_tool` is an SB-derived routing/mutex component, not an upstream package with an installed version. The official-docs procedure therefore cannot be followed literally for that row, and the pin starting-points table omits it. Specify whether its `docs_pin` is an SB-owned contract at a Silver Bullet commit/ref, a collection of the five tools’ pins, or an explicit internal/N/A form. Otherwise implementers must invent a value to satisfy AC 1.
