# APPLY — rung 8 Pi Claude Opus 5 Extra High

**Disposition:** ACCEPT-apply (all 12 findings).  
**PRD SHA-256 after apply:** `9391e9dc3120685335743782a0d8b67119af226126936a76faaa46d87e4d0728`  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)

| Finding | Ledger | What changed |
|---------|--------|----------------|
| F-8-1 | I-65 | Severity→exit: FAIL nonzero; WARN zero except `unknown_key`; PASS/N/A zero |
| F-8-2 | I-66 | Graphify skew WARN expected/advisory; `--fix` none; green = no FAIL |
| F-8-3 | I-67 | `required_when_enabled` is hook enforcement, not audit honesty |
| F-8-4 | I-68 | Older-than-pin repairable; newer-than-pin WARN, no downgrade |
| F-8-5 | I-69 | Test rows: `duplicate_key` FAIL; `no_five_tool_consent` PASS |
| F-8-6 | I-70 | Confirmation gate is plan-triggered |
| F-8-7 | I-71 | Host-install set is D13/D14/D16/D18/D19 (not D13–D19) |
| F-8-8 | I-72 | Omni D10 = current doctor host CLI only |
| F-8-9 | I-73 | `unsupported_package_manager` skip: `DOCTOR_FIX_APPLIED=0`, WARN-class exit |
| F-8-10 | I-74 | Omni PASS N/A only after Phase 3 |
| F-8-11 | I-75 | Origin review `759a2827` as inline code |
| F-8-12 | I-76 | Status: ready for Session A implementation |
