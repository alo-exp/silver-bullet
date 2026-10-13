# RFL rung-07 Pi Claude Opus 5 High — review pass 7 (2026-08-12)

RFL rung-07 Pi Claude Opus 5 High review pass 7 on .planning/spec_template_world_class.plan.md.
SHA e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1 verified on BOTH twins (freeze + phases/01-world-class-spec/PLAN.md), 723 lines.
Verdict NOT CLEAN. 10 residuals R7g-F01..R7g-F10 (1 HIGH / 4 MED / 3 LOW / 2 nit). Written to review-rerun-7.md only.
R7g-F01 HIGH: .spec-kind-migration.md declared "kind-reconciliation migrate branch only" (L313/L457) + "markdown dump of forbidden/unlisted heading prose" but R7d-F04 Invariants supersede (L172) and R7f-F05 prior Change History rows (L131/L584/L587) both write to it from non-migrate branches; L599 pins both as PASS-install. Ask: named multi-producer preserved-prose record, shared R6c lifecycle + R7c-F07 append. KEEP REJECT intact.
R7g-F02 MED: L457 Step 7 still "write YAML invariant-count from the sourced bullet count" — contradicts R7f-F12 resulting-live-post-compile at L143 and L599 supersede fixture.
R7g-F03 MED: R7f-F04 ordinal re-anchor absent from Wave 3 (Step 7, Step 8 precondition list L458, verify contains-list L473-498); only L73/L293/L599.
R7g-F04 MED: R7f-F10 says cite Change History by spec-version cell, but two-clause <line-or-id> grammar admits only live ID or b[0-9]{2}; decimal cell = bare line = REQ-F71. Unreachable.
R7g-F05 MED: L198 promises Overview-prose SCAN for omitted nfr, but R7f-F10 Overview ordinal counts top-level "-" bullets and L172 Overview is 2-4 sentences => zero bullets => always REQ-F71.
R7g-F06 LOW: R7f-F13 1-based b00/>99 rule missing at L427 review-requirements, L428 review-cross-artifact, and L437 QC-string fixtures.
R7g-F07 LOW: mixed ## Assumptions (some ASM-nn, some not) unclassified under section-level "ID-bearing MUST use (a)"; ordinal base ambiguous.
R7g-F08 LOW: decision-row-identity idempotence + R7f-F06 divergent-text FAIL only at L142; no Wave 3 contains bullet, no L437 fixture, not in Step 8 precondition list.
R7g-F09 nit: REQUIREMENTS exhaustion fixture still REQ-00..REQ-99 shorthand at L284/L458/L489/L599; never exercises the -00-absent disjunct.
R7g-F10 nit: R7f-F01 trigger "if that set is empty" includes seed => unreachable; L599 says "empty remaining delta" (set minus seed). Also named sentence hard-codes "prior spec-version malformed".
R7f-F01..F14 APPLY confirmed landed (spot-check table in review). Reviewer Claude High Pi; Verify/Triage Composer 2.5; Fix Grok 4.6 High. Policy F streak was 0 entering pass 7; ACCEPT+APPLY would reset again.
