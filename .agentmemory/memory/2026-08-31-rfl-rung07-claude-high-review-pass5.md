RFL rung-07 Pi Claude Opus 5 High review pass 5 on .planning/spec_template_world_class.plan.md at SHA 74b9acf23da1817834f35047c72bc1129fef4b2511ceac6c974fa5a8752fec33 (both twins verified, unmutated).

Verdict: NOT CLEAN. 10 residuals R7e-F01..R7e-F10 (1 HIGH, 2 MED, 4 LOW, 3 nit) written to .planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/review-rerun-5.md.

- R7e-F01 HIGH: R7d-F05 SCAN eligible-ID join landed only at L262/L293; review-requirements (L427), review-cross-artifact (L428), Step 8 (L458) reverse-coverage clauses unbound => pinned SCAN:quality-attributes#QA-01 sole-Source PASS fixture neither-branch FAILs. Same binding class as R6j-F02.
- R7e-F02 MED: R7c-F09 live-ID rule makes SCAN: unusable for its stated "no structured pack ID" purpose; ID-less sections (### Invariants per R7c-F03 no-INV-nn, Overview, optional ASM-nn Assumptions) have no resolvable Source.
- R7e-F03 MED: QC-10 non-placeholder Change History summary fail-closed (SPEC-F72) with no brief field (L516 schema), no precedence chain, no ASK/fail terminal on brief-less augment 2/3/4b. Same shape as R7-F01.
- R7e-F04 LOW: "-00 is allocatable" survives L217/284/457/458/489 contradicting R7d-F09 "never minted"; R6f exhaustion trigger ambiguous when EX-00 absent.
- R7e-F05 LOW: R7d-F01 union emission + R7c-F02 count-equality absent from L437 QC-string asserts, L474 Wave 3 verify, L599 Wave 6 fixtures (only degenerate R7b-F06 case present).
- R7e-F06 LOW: R7d-F04 branch-(1) supersede + migrate-or-ASK has Wave 3 string assert (L473 asserts branch-3 terminal) but no Wave 6 behavioral fixture.
- R7e-F07 LOW: L359 SPEC core-template asserts omit spec-version though L360 REQUIREMENTS list requires it (same class as R7-F10 / R7b-F13).
- R7e-F08 nit: union-emission row identity "matching decision text" undefined (needs scan-section-slug-style normalization; duplicate DEC-nn invisible to QC-12).
- R7e-F09 nit: "derived from the current catalog, non-normative" tag on nfr Notes only (L198); ten sibling pack rows untagged.
- R7e-F10 nit: Wave 1 does not pin core template invariant-count example value to its example Invariants bullet count (SPEC-F73 on copy); same class as R7c-F13.

Confirmed R7d APPLY landed F01-F04, F06-F08, F10-F12 fully; F05 contract-only (=> R7e-F01), F09 partial (=> R7e-F04). KEEP REJECT and R7b-F17 REJECT untouched. Review-only: no APPLY, no triage, no verify, no branch/commit.
