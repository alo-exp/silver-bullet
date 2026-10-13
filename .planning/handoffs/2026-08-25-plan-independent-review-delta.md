# Independent review delta — freeze plan `router_subagent_surfaces_85bf9f09`

Planning-only. No product code, tests, hooks, skills, WS0, or YAML-todo execution. Git stayed on `main`. Both plan copies remain byte-identical.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `31406f106e131c39cb86fa788819353671a31b5b69966d08cae87038c3d995e1` | 580674 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Start pair (confirmed before edits): `c4950cbd0a4e657ac5aee2921e3fd514f54a397c7662ab767f5194e61acfb75e` / 598581 bytes.

YAML frontmatter stayed compact (`fm_end` line 84, 4965 bytes). All 23 todos remain `pending`. KEEP REJECT stayed **closed**.

## Completeness (after Phase 1)

**PASS** — all required tokens still present: 23 todo ids; `/sb:improve`; `/sb:contribute`; `/sb:ladder`; `/sb:parallel`; `/sb:new-workflow`; `WS0`; `WS0b`; `WS8`; `PUB-01`; `KLW-01`; `VAL/TST-RFL-625`; `additionalProperties: false`; `row 40`; `sb:agent-wrap`; `wbs-projector.sh`; `nested_executor`; `prompt_hash`; `context_refs_hash`; `GST-01`; `HNEST-01`; `HINST-01`; `WFM-01`; `test-sb-improve.sh`; `test-pre-impl-repo-hygiene.sh`; all 27 `VAL/TST-RFL-*` ids that were present before Phase 1 (`001` + `601`–`626`).

## Issues found (by severity)

### High (6)

1. **KEEP REJECT catalog headings did not match lock bodies.** After the heading-hierarchy split, `KR-catalog-generated` / `KR-fast-overlay` contained YAML-todo bleed (`status: pending - id: …`), `KR-authorizer-not-pref` held ladder text, `KR-cursor-mvp-first` held evolution text, `KR-kr-17`/`KR-kr-18` duplicated WS0b/WS1 procedures. Names vs locks were unusable as KR-* pointers.
2. **`sb:agent-wrap` listed as a public/catalog surface** in the PRD inventory and Appendix D, while glossary + LS-agent-pin + FR-07 forbid it. Architecture still called it an alias for `WF-AGENT-DELEGATE-ENTRY`.
3. **`/sb:multi-ai-task` listed as a public surface** while LS-retire-multi-ai retires it with **no** `/sb` alias.
4. **LS-* vs KR-* pointer clash:** WS0 KEEP REJECT linked to `[KR-kr-17]` (unclosed markdown) instead of `KR-ws0-preserve-evidence`.
5. **Duplicate YAML todo → test → WS maps** in §5.4 and Appendix B (drift hazard).
6. **`WF-SILVER-DEEP-RESEARCH-MULTI-AI` still references `AF-MULTI-AI-TASK`** in `apo_multi_ai_catalog.py` while this ship retires that AF as a public route. Could not close without a user product decision (left as open fork #3).

### Medium (8)

7. **§6 heading jump** `##` → `#### Shared WBS` (skipped H3).
8. **Empty `#### FAST carve-out` heading** immediately followed by `#### FAST vs Job` (duplicate title, no body).
9. **`/sb:improve` contract heading** owned the `new-workflow` / `VAL/TST-RFL-625` named-test bullet.
10. **Goose/Hermes listed as public `/sb:agent-*` surfaces** this ship; body only adds them to the runtime enum **when skills exist**.
11. **`sb:iterate-ladder` listed as public MVP** while Iterate is post-MVP.
12. **`sb:review-fix-ladder` listed as public** while LS-ladder-parallel absorbs `/silver:review-fix-ladder` into `/sb:ladder`.
13. **Broken `#testing-and-acceptance` links** (no such heading; coverage lives in §5.4).
14. **Post-Val K/L vs WS0b vs docs-release** were specified in several places but not in the glossary, so implementers could still treat the runtime hop as a substitute for ship-sequence docs.

### Low (5)

15. TOC still has truncated `####` titles from the hierarchy pass (underscores / long invert headings). Not a lock clash; left as residual TOC noise where GitHub-style slugs already match.
16. Workstream `### 6. Models…` vs document `## 6. Risks…` numbering collision. Mitigated by the new §6 H3; workstream titles left (YAML compact pointers cite `§5.3 ### 6`).
17. KR-kr-13/15/16/17/18 kept as **pointers** so existing links resolve.
18. `/sb:improve` “Job / not FAST” vs “quality order applies unless classified-trivial” is a true fork (open decision #1).
19. YAML map `WS4 / WS7` dual-owner for improve/contribute vs WS1 generator emit (open decision #2).

## What changed

- Rebuilt [§3.3](../router_subagent_surfaces_85bf9f09.plan.md) KR-* bodies to match named KEEP REJECT themes. YAML-todo bleed removed (same procedures remain in §5.3). KR-kr-* ids retained as pointers.
- PRD + Appendix D surface inventories annotated: wrap **forbidden**, multi-ai-task **retired**, iterate-ladder **post-MVP**, goose/hermes **enum-when-exists**, review-fix-ladder **absorbed**.
- Struck `sb:agent-wrap` alias language in Architecture and WS1.
- Glossary: **WS0b** / **post-Val K/L hop** / **docs-release** rows.
- §5.4 duplicate map → pointer to Appendix B (table kept once).
- §6 H3 `Specified risks (closed)`; WS0 pointer retargeted to `KR-ws0-preserve-evidence`.
- Split WS1 `/sb:new-workflow` named tests vs improve/contribute catalog emit.
- Recorded three **true open forks** in §6 (not decided).
- Frontmatter YAML todos untouched (still compact, all `pending`).

## Left as clarify questions (Phase 2)

See §6 Open decisions. Not answered here:

1. `/sb:improve` always-Job vs classified-trivial skip of quality order.
2. Improve/contribute implementation owner (WS1 catalog emit vs WS4 Job vs WS7 docs).
3. How `WF-SILVER-DEEP-RESEARCH-MULTI-AI` survives retiring `AF-MULTI-AI-TASK` as a public route.

## SHA after Phase 1

`31406f106e131c39cb86fa788819353671a31b5b69966d08cae87038c3d995e1` (580674 bytes). Both copies identical.

## SHA after Phase 2 (clarify question list written into §6)

`eb9c7bb0d9f584c199cd4a2e157129c21cb7b609d28ecd5d63eec8647944caba` (583052 bytes). Both copies identical. Clarify brief: [`.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260825-20260825T024506Z.md`](../router_subagent_surfaces_85bf9f09-CLARIFY-260825-20260825T024506Z.md). YAML todos still 23 `pending`. No product implementation.
