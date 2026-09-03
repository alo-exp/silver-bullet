# Policy C — Claude Opus 5 High

- **Rung identity:** Claude Opus 5 High (`claude` / `high`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - M1
  - M2
  - M3

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| M1 | KR-no-public-fusion has no named test / coverage row while coverage MUST maps every KEEP REJECT lock |
| M2 | Panel-start is both admitted and excluded as an in-quality-order hop mode; hop-level panel-start has no termination rule |
| M3 | /sb:panel-end fail-closed has no canonical blocked_* row, contradicting the ordered-table MUST |

### LOW

| ID | Title |
|----|-------|
| L1 | Broken TOC anchor at §4.6: GFM strips slashes but the href inserted hyphens (not the rejected -- class) |
| L2 | Panel-end state has no named writer or store for panel_session_id, last-panel receipt, or recovery receipt |
| L3 | Doctor must state fusion retirement but is never required to verify route absence |
| L4 | Appendix C named-tests inventory omits tests/scripts/test-ap10-plugin-emit.sh |

### NIT

| ID | Title |
|----|-------|
| N1 | PANEL.md; formerly FUSION.md cites a worker template that never existed in-repo |
| N2 | Public inventory row order is unsorted after the F-5-1 rename (both catalogs) |
| N3 | Rows 27 and 42 drop the Blocker/Trigger/Resume triple used by the other 39 rows |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| M1 | MED | ACCEPT | Lock L979–981 was added by the prior substitute APPLY with no named-test MUST. LS-plan-executed-coverage and KR-coverage-plan-executed require every KEEP REJECT lock to map to a named test. New gap, not a re-litigation of substitute M1 catalog-row work. |
| M2 | MED | ACCEPT | L1293 hop modes are Ladder or Panel; L2412 added Panel-start as a hop mode in the F-5-1 rename. Locked product: quality-order default Ladder; panel-start is the sitting Job, not a hop mode. Restore hop-mode set and bind /sb:panel-end to the live panel-start Job only. |
| M3 | MED | ACCEPT | Ordered-table MUST: every failure classifies to exactly one blocked_*. Panel-end fail-closed is specified but unnamed. Precedent: blocked_fast_leaf is FAST-scoped / not a Job. Add scoped blocked_panel_end (row 43). Not a documentation nit. |
| L1 | LOW | ACCEPT | New evidence: TOC href converts slashes to hyphens; GFM lock strips punctuation so the heading slug is ladderpanelpanel-start. Not the rejected -- double-hyphen class. Only unresolved TOC anchor. |
| L2 | LOW | ACCEPT | Fail-closed vs no-op fork depends on last-panel receipt existence. KR-projector-exclusive stays: receipts are non-packet session-store, WS4 writer, not wbs-projector.sh. |
| L3 | LOW | ACCEPT | Help-text-only retirement is unproven. Doctor / test-router-doctor-report.sh must assert catalog/lock contains no /sb:fusion, /sb:parallel, or /sb:council. Complements M1. |
| L4 | LOW | ACCEPT | Appendix C is the inventory §5.4 dereferences. Body cites test-ap10-plugin-emit.sh at L122/L3366/L4255; inventory omitted it. Add the row. |
| N1 | NIT | ACCEPT | Implementer reading formerly FUSION.md will look for a file to rename. No in-repo FUSION.md. Clarify create PANEL.md; do not imply a disk rename. Not rejected as a documentation nit. |
| N2 | NIT | ACCEPT | panel-start/panel-end sit between contribute and deep-research while panel sits after new-workflow. Reorder both catalogs. Not rejected as a documentation nit. |
| N3 | NIT | ACCEPT | Rows 27 and 42 use compressed dash form vs the Blocker/Trigger/Resume triple. Expand those two rows. Data already present; format must match the table contract. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| M1 | MED | KR-no-public-fusion has no named test / coverage row while coverage MUST maps every KEEP REJECT lock | ACCEPT | yes |
| M2 | MED | Panel-start is both admitted and excluded as an in-quality-order hop mode; hop-level panel-start has no termination rule | ACCEPT | yes |
| M3 | MED | /sb:panel-end fail-closed has no canonical blocked_* row, contradicting the ordered-table MUST | ACCEPT | yes |
| L1 | LOW | Broken TOC anchor at §4.6: GFM strips slashes but the href inserted hyphens (not the rejected -- class) | ACCEPT | yes |
| L2 | LOW | Panel-end state has no named writer or store for panel_session_id, last-panel receipt, or recovery receipt | ACCEPT | yes |
| L3 | LOW | Doctor must state fusion retirement but is never required to verify route absence | ACCEPT | yes |
| L4 | LOW | Appendix C named-tests inventory omits tests/scripts/test-ap10-plugin-emit.sh | ACCEPT | yes |
| N1 | NIT | PANEL.md; formerly FUSION.md cites a worker template that never existed in-repo | ACCEPT | yes |
| N2 | NIT | Public inventory row order is unsorted after the F-5-1 rename (both catalogs) | ACCEPT | yes |
| N3 | NIT | Rows 27 and 42 drop the Blocker/Trigger/Resume triple used by the other 39 rows | ACCEPT | yes |

