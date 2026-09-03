# Decision — Opus Extra High ladder-3 ACCEPT (round-12, 2026-08-16)

Locked into router_subagent_surfaces_85bf9f09 plan (clarify round-12). Stay on `main`. No commit. Max not started. No Fast.

## ACCEPT dispositions

- **B1:** Schema unchanged (`docs/apo-catalog.schema.json`). Exemption in `scripts/check-apo-invariants.py` **and** the generators (WS1). Stop surgical comment/flag. Required `v_loop` / `VL-AF-FAST-PATH` stay in JSON. Prune generated composition to `AF-FAST-PATH` only.
- **H-A:** Add `AF-EXECUTE` to every must-not-run list with `AF-PLAN` / `AF-VALIDATE` / `AF-VERIFY` / `AF-QUALITY-GATE`. Live composition remains `AF-FAST-PATH` only.
- **H-B:** Also do not emit/enforce `prerequisites`, `exit_condition`, `flow_steps` V-loops (`FS-SILVER_*` / `VL-FS-SILVER_FAST`; Leaf Step no V/Val wins), `execution.join_condition`, `artifacts`/`evidence_refs` as required V-evidence, `capability_class: bounded_fast_path` as a quality-order trigger.
- **M-A:** Rewrite `PP-SB-STARTUP-FAST` `override_rules[0]` to prefer `WF-SILVER-FEATURE`. Drop the unreachable WF-SILVER-FAST product-work alternative. Fail-closed reclassify if `WF-SILVER-FAST` is selected for durable edits.
- **M-B:** FAST operator surfaces include the thin-capture deny-all node (M3 terminal; required WBS content).
- **M-C:** Protected-`main` / no-push-rights `gst_stale` + Job-continues fixture owned by `VAL/TST-RFL-621`.
- **M-D:** Board of one: unifier leaf still launches (identity-preserving / no-op unify; not last-write-wins). Orchestrator does not implement unify.

## KEEP REJECT (untouched)

ESC-02 no A; Authorizer not Approver; `process_v_verified`; FAST not a Job / not GST / quality-order exempt; wrap at `/sb`; BOA parallel; no `AF-meta-six-role`; no synthesize on trivial; do not mint `AF-qa`; reuse IDs `sb:fast` / `WF-SILVER-FAST` / `AF-FAST-PATH`; AM-first `kl_write`; current-month load cap; team Graphify fan-out; AM buffer / K/L git SoT; H2 GST degrade.

Plan SHA-256 (both copies, byte-identical): `0289df0c7d8e8982ecef041d5e9da7092b5a6a67b94863297c74c276785ec2af`
Prior frozen SHA: `bebcfa9165afd7bbfef934ca8093bbd567f9c569d49c1f1d980298fb182d1b0d`
