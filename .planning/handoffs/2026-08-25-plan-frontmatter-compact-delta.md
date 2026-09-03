# Plan frontmatter compact delta — 2026-08-25

Planning-only. No product code. Both plan copies stayed on `main` and byte-identical. YAML todos: same 23 ids, all `status: pending` (none completed, none dropped). KEEP REJECT not reopened.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `c4950cbd0a4e657ac5aee2921e3fd514f54a397c7662ab767f5194e61acfb75e` | 598581 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Pre-edit pair: `68422bc5ccd736d58898e118c59e2f5775eabd9ffddf8bbc0501d2352988aa70` / 645293 bytes.

## YAML block (inner, excluding wrapping `---`)

| Metric | Before | After |
|--------|--------|-------|
| Line count | **78** | **82** |
| Max line length | **11950** | **157** |
| YAML bytes | 51485 | ~5.6 KB |
| `overview:` | 2878-char freeze wall | 5 sentences, folded `>` |
| Todo `content:` | 23 blobs (290–11937 chars; several 3–12 KB) | 23 one-line pointers (max 142 chars of content; YAML line max 157) |

First heading after `---`: `# Router Subagent Surfaces — Architecture and Design Change` (unchanged). Immediately under it: one planning-not-execute sentence, then `## How to read this document`.

## What the unstructured opening was

Cursor YAML frontmatter, not leftover body sludge before the H1:

- Fat `overview:` (one ~2.9 KB freeze-lock paragraph).
- 23 YAML `todos[].content` fields left long so Cursor’s todo UI kept freeze text. The worst (`nested-orchestration`) was an **11950-character single line**.

Between H1 and `## How to read` there was also a 2-sentence previous-rewrite note. That was shortened to one planning-not-execute line. No unique lock lived only in YAML: required tokens and all `VAL/TST-RFL-*` ids were already in the body.

## Completeness (whole file)

Present after rewrite: all 23 todo ids; `/sb:improve`; `/sb:contribute`; `/sb:ladder`; `/sb:parallel`; `/sb:new-workflow`; `WS0`; `WS0b`; `WS8`; `PUB-01`; `KLW-01`; `VAL/TST-RFL-625`; `additionalProperties: false`; `row 40`; `sb:agent-wrap`; `wbs-projector.sh`; `nested_executor`; `prompt_hash`; `context_refs_hash`; `GST-01`; `HNEST-01`; `HINST-01`; `WFM-01`; `test-sb-improve.sh`; `test-pre-impl-repo-hygiene.sh`; every pre-existing `VAL/TST-RFL-*` id (27).
