# Policy C — Claude Opus 5 Extra High

- **Rung identity:** Claude Opus 5 Extra High (`claude` / `xhigh`)
- **Verdict:** NOT CLEAN
- **Disposition:** ACCEPT-apply

## Blockers / Highs / Mediums

- **Blockers:** none
- **Highs:** none
- **Mediums:**
  - M1
  - M2

## Reported issues (by severity)

### HIGH

| ID | Title |
|----|-------|
| — | **none** |

### MED

| ID | Title |
|----|-------|
| M1 | KR-panel-public-trio-only dangling Not a live command binds to /sb:panel-start |
| M2 | Named-test obligation is a denylist against an unnamable retired token |

### LOW

| ID | Title |
|----|-------|
| L1 | Verbatim duplicated normative sentence in WS7 |
| L2 | WS7 and Appendix E Doctor bullets have drifted apart |
| L3 | thinking-level used for two different value spaces (tiers vs effort) |
| L4 | In-flight one-off /sb:panel vs /sb:panel-end is not enumerated |
| L5 | WS7/Doctor route-set assertion is absence-only; trio+panel-end presence unchecked |

### NIT

| ID | Title |
|----|-------|
| N1 | Retired extra one-off occupies identifier column as italic prose |
| N2 | L1558 still labels the live mermaid Proposed-architecture |
| N3 | KR-kr-18 says kept so pointers resolve but has zero inbound anchors |
| N4 | Duplicate heading slugs beyond the F-2 HOLD (observation only) |

## Triage (launcher, not rung model)

| ID | Severity | Decision | Reason |
|----|----------|----------|--------|
| M1 | MED | ACCEPT | Canonical KEEP REJECT after the panel-purge left Not a live command bound to /sb:panel-start. Affirm the four live routes; keep retired extra aliases not-live. New residue, not a re-file of rung-10. Not a documentation nit. |
| M2 | MED | ACCEPT | Ship-blocking named test cannot grep an unnamed retired token. Restate as exact-route-set allowlist (one-off /sb:panel; trio /sb:panel\|/sb:panel-start\|/sb:panel-end plus /sb:ladder) plus named /sb:parallel\|/sb:council denylist. Do not reintroduce the retired name. Not a documentation nit. |
| L1 | LOW | ACCEPT | Byte-identical WS7 MUST duplicated by rung-10 APPLY. Collapse to one sentence. Editing artifact, still ACCEPT. |
| L2 | LOW | ACCEPT | Appendix E is the WS7 restatement but dropped the machine-checkable catalog/lock MUST and the AP-docs sentence. Sync E to WS7. Not a documentation nit. |
| L3 | LOW | ACCEPT | Regular/Complex collide with effort domain. Repair thinking-levels to tiers at both sites. Does not reopen rung-8 M1 product. |
| L4 | LOW | ACCEPT | In-flight one-off /sb:panel has no receipt yet so falls into fail-closed limb 1 unnamed. Enumerate as blocked_panel_end row 43 and add the fixture. Not a documentation nit. |
| L5 | LOW | ACCEPT | Absence-only Doctor would pass a regen that drops /sb:panel-end. Require presence of ladder+trio+terminator and exact one-off /sb:panel. Complements M2 allowlist. |
| N1 | NIT | ACCEPT | Surface column otherwise holds backtick ids. Put `(retired extra one-off)` in backticks without naming the retired route. Not rejected as a documentation nit. |
| N2 | NIT | ACCEPT | Live mermaid label still says Proposed-architecture; section is Process router. Rename the prose label. Appendix A SHA-lineage receipt out of scope. |
| N3 | NIT | ACCEPT | KR-kr-18 rationale is self-falsifying. Keep the heading; restate as stable catalog id with zero inbound anchors. Do not delete. |
| N4 | NIT | ACCEPT | Observation only as filed. F-2 HOLD duplicate blocked_advisor_state (row 14) stays. No heading deletion. |

## Resolved (after launcher ACCEPT fixes)

| ID | Severity | Title | Decision | Resolved |
|----|----------|-------|----------|----------|
| M1 | MED | KR-panel-public-trio-only dangling Not a live command binds to /sb:panel-start | ACCEPT | yes |
| M2 | MED | Named-test obligation is a denylist against an unnamable retired token | ACCEPT | yes |
| L1 | LOW | Verbatim duplicated normative sentence in WS7 | ACCEPT | yes |
| L2 | LOW | WS7 and Appendix E Doctor bullets have drifted apart | ACCEPT | yes |
| L3 | LOW | thinking-level used for two different value spaces (tiers vs effort) | ACCEPT | yes |
| L4 | LOW | In-flight one-off /sb:panel vs /sb:panel-end is not enumerated | ACCEPT | yes |
| L5 | LOW | WS7/Doctor route-set assertion is absence-only; trio+panel-end presence unchecked | ACCEPT | yes |
| N1 | NIT | Retired extra one-off occupies identifier column as italic prose | ACCEPT | yes |
| N2 | NIT | L1558 still labels the live mermaid Proposed-architecture | ACCEPT | yes |
| N3 | NIT | KR-kr-18 says kept so pointers resolve but has zero inbound anchors | ACCEPT | yes |
| N4 | NIT | Duplicate heading slugs beyond the F-2 HOLD (observation only) | ACCEPT | yes |

