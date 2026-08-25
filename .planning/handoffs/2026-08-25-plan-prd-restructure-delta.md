# Plan PRD restructure delta — 2026-08-25

Planning-only rewrite of the Router Subagent Surfaces freeze into a PRD / Analysis / Architecture / Design document. **No product implementation.** No WS0/WS0b/WS1–WS8 execution. Git branch remained `main`. No commit.

## Copies (byte-identical)

- [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md)
- [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md)

## SHA-256 (hashlib)

| | SHA-256 | Bytes |
|---|---|---|
| **Pre-rewrite (Round-41 freeze)** | `15e7c4218797fd0014913ec9779db5dc5e991efc34fc07337c4df617a4a2a3a8` | 597215 |
| **Post-rewrite** | `2b47ee79ca398398cace753fad99764ae04bd77ccab938531fcfea93064d5251` | 618090 |
| Delta | — | **+20875** (TOC, glossary, FR/NFR indexes, catalogs, maps; growth allowed) |

Copies verified identical after rewrite. Not reverted to Round-41 `a96045f9`.

## Outline (new top-level)

1. How to read this document / Glossary / Table of contents
2. **1. Document control** — identity, SHA lineage pointer, MVP slice, Cursor-first, copies, freeze status (planning; not execute)
3. **2. PRD** — problem, goals/non-goals, users/jobs/`/sb` surfaces, FR table, NFR table, MVP vs post-MVP, **canonical live-spec MUST catalog** (LS-*)
4. **3. Analysis** — current system, gaps, **canonical KEEP REJECT** (KR-*)
5. **4. Architecture** — control plane, `/sb` + FAST vs Job, WBS/projector/worktrees, nested Task vs parent-proxy, quality order, Q-loop/thermos/ladder/pin, `/sb:improve` + `/sb:contribute`
6. **5. Design** — schemas/admission, ship sequence WS0 → WS0b → WS1–7 → WS8 → docs-release, workstreams 0/0b/1–8, named tests + todo map
7. **6. Risks, rollout, open decisions** — KEEP REJECT stays closed; post-MVP is deferred scope
8. **7. Appendix** — full prior Revised cell (SHA lineage / round receipts), inventories, traceability, document integrity

## Completeness gate

Script extracted required tokens from the **pre-rewrite** freeze (YAML todo ids; `/sb:improve`; `/sb:contribute`; `/sb:ladder`; `/sb:parallel`; `/sb:new-workflow`; `WS0`; `WS0b`; `WS8`; `PUB-01`; `KLW-01`; `VAL/TST-RFL-625`; `additionalProperties: false`; `row 40`; `sb:agent-wrap`; `wbs-projector.sh`; `nested_executor`; `prompt_hash`; `context_refs_hash`; `GST-01`; `HNEST-01`; `HINST-01`; `WFM-01`; `test-sb-improve.sh`; `test-pre-impl-repo-hygiene.sh`; and every `VAL/TST-RFL-*` id in the old file).

**Result: PASS. missing=0.** YAML todos = 23, none `completed`.

Token counts (old → new), all still ≥1:

```
pre-impl-repo-cleanup 2→4
pre-impl-key-docs 5→16
post-impl-repo-cleanup 2→6
capability-contract 2→6
execution-registry 3→8
model-preferences 9→14
nested-orchestration 1→3
nested-quality-loops 1→3
authorizer-trust 6→8
host-surfaces 4→7
new-workflow-skill-extract 7→10
universal-migration 1→3
q-loop 5→16
unified-code-review 5→9
generalized-role-boards 2→4
sb-parallel 6→11
agent-runtime-pin 2→4
retire-multi-ai-task 3→5
post-val-kl-docs 3→5
workflow-evolution-improve 3→5
workflow-evolution-contribute 3→6
validation-tests 6→13
docs-release 5→14
/sb:improve 13→20
/sb:contribute 14→23
/sb:ladder 14→21
/sb:parallel 14→20
/sb:new-workflow 28→35
WS0 22→56
WS0b 9→21
WS8 9→28
PUB-01 65→69
KLW-01 17→20
VAL/TST-RFL-625 20→22
additionalProperties: false 11→12
row 40 27→27
sb:agent-wrap 7→12
wbs-projector.sh 38→41
nested_executor 29→30
prompt_hash 24→25
context_refs_hash 25→26
GST-01 25→35
HNEST-01 15→15
HINST-01 34→34
WFM-01 27→30
test-sb-improve.sh 3→6
test-pre-impl-repo-hygiene.sh 3→6
VAL/TST-RFL-001 1→2
VAL/TST-RFL-601 4→9
VAL/TST-RFL-602..614,616..620,622 2→1 (still present)
VAL/TST-RFL-604 5→4
VAL/TST-RFL-615 13→11
VAL/TST-RFL-621 9→7
VAL/TST-RFL-623 8→7
VAL/TST-RFL-624 5→5
VAL/TST-RFL-626 12→11
```

Count drops are duplicate-MUST/KEEP REJECT collapse into canonical sections, not deletions. Every old `VAL/TST-RFL-*` id still appears.

## Streamlining notes

- One canonical live-spec MUST catalog (LS-plan-executed-coverage, LS-ship-sequence, LS-workflow-evolution, LS-skill-extract, LS-q-loop, LS-unified-review, LS-ladder-parallel, LS-retire-multi-ai, LS-post-val-kl, LS-agent-pin). Body uses short LS-* pointers.
- One canonical KEEP REJECT catalog (KR-*). Round-history “KEEP REJECT intact” remains in Appendix A (full prior Revised cell).
- KEEP REJECT not reopened. Open decisions section states post-MVP as deferred scope only.
- YAML frontmatter (`name`, `overview`, 23 `todos` all `pending`) copied unchanged.

## Confirmation

No hooks, skills, tests, product code, repo cleanup, or YAML todo status changes. Freeze status remains **planning; not execute**.
