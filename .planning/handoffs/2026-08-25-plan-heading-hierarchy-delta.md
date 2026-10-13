# Plan heading-hierarchy delta — 2026-08-25

Planning-only. No product code, tests, hooks, skills, or YAML todo status changes. Both plan copies stayed on `main` and byte-identical.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `68422bc5ccd736d58898e118c59e2f5775eabd9ffddf8bbc0501d2352988aa70` | 645293 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Pre-edit pair: `2b47ee79ca398398cace753fad99764ae04bd77ccab938531fcfea93064d5251` / 618090 bytes.

## Long-line counts (body only, YAML excluded)

| Metric | Before | After |
|--------|--------|-------|
| Body lines | 2933 | 4169 |
| Body lines >1000 chars | **68** | **4** |
| Body lines >2000 chars | **24** | **1** |
| Headings | 102 | 319 (`##` 10 / `###` 91 / `####` 217) |
| YAML todos | 23 `pending` | 23 `pending` (none completed) |

The remaining `>2000` line is the appendix A SHA-lineage freeze cell (49239 chars) — kept as one block. The other three `>1000` lines are atomic freeze clauses (VAL/TST-RFL-626 LPS-01 extend, WS3 invert ownership, 5.4 YAML-todo coverage map), each already under its own `####`.

## What changed

Long undifferentiated bullets/paragraphs were split into nested `####` headings with shorter child bullets. KEEP REJECT stayed closed. No architecture invented. YAML `content:` blobs untouched.

### New heading examples

**§2.2 Goals and non-goals** — was one ~3KB paragraph:

- `#### Goals`
- `#### Global Status dashboard (GST-01)`
- `#### Non-goals`

**Shared-state layout** — was 2–7KB mega-bullets:

- `#### Code — may use overlap worktrees, and only for host_native`
- `#### WBS, packets, spawn-proxy jsonl, and admission CAS`
- `#### Hook-visible primary root`
- `#### Host Task cwd and env`

**Parent-proxy protocol** — was one flat list; now 12 `####` clusters including:

- `#### Spawn-proxy helper and jsonl path`
- `#### Proxy request record fields`
- `#### Remaining depth and refuse-then-proxy`
- `#### Two-helper consume transaction (ADM-01 / CORR-17 / WBS-01)`

**Ordinary-delivery procedure** — numbered hops are `#### Step N — …` (23 `####`).

**§5.4 Named tests** — each `VAL/TST-RFL-*` is its own `####` (29 `####`, including 613/615/616/617/625/626).

**Failure-mode table** — long rows expanded to `#### \`blocked_*\` (row N)` plus a short index.

TOC regenerated to match `##` / `###` / non-VAL `####` group titles.

## Completeness

**PASS**

- All 23 YAML todo `id:` values still present; all 23 `status: pending`
- Tokens present: `/sb:improve`, `/sb:contribute`, `/sb:ladder`, `/sb:parallel`, `/sb:new-workflow`, `WS0`, `WS0b`, `WS8`, `PUB-01`, `KLW-01`, `VAL/TST-RFL-625`, `additionalProperties: false`, `row 40`, `sb:agent-wrap`, `wbs-projector.sh`, `nested_executor`, `prompt_hash`, `context_refs_hash`, `GST-01`, `HNEST-01`, `HINST-01`, `WFM-01`, `test-sb-improve.sh`, `test-pre-impl-repo-hygiene.sh`
- All 27 `VAL/TST-RFL-*` ids present (same set as before this edit)
- KEEP REJECT remains closed (`KEEP REJECT items in §3.3 are **closed**`)

## Hierarchy sufficient?

**Yes for the parent-audit mega-bullet problem.** Body lines `>2000` dropped 24 → 1 (appendix freeze only). Named problem sections now have nested `####` instead of undifferentiated 2–7KB bullets. Residual 1.0–1.6KB atomic freeze clauses sit under their own headings and were not paraphrased.

No product implementation.
