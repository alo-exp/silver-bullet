# Plan delta — retire `/silver:multi-ai-task` (2026-08-25)

Plan-only. Both copies byte-identical.

| Copy | SHA-256 |
|---|---|
| `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `5c3c7c3939fff0a194b947a2868e359eaf221706dcb0ff46bc014f96ca67dbd9` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `5c3c7c3939fff0a194b947a2868e359eaf221706dcb0ff46bc014f96ca67dbd9` |

Prior: `fa922d7c…`. Bytes: 581914.

## MUST

Remove public `/silver:multi-ai-task` **with no transition** (no `/sb:multi-ai-task` alias). `/sb:ladder` and `/sb:parallel` replace it.

**Absorb then delete:** host-matrix fail-closed, model-family registry, pool/budget defaults only when member tuples are not explicit, output-root/consolidator spine → Parallel Consolidator, sequential passes → Ladder. Retarget `worker_template` off `MULTI-AI-TASK.md`. Leave `silver:deep-research-multi-ai` unless it is the same catalog record.

YAML `retire-multi-ai-task` pending. Named test `tests/scripts/test-multi-ai-task-retired.sh`. KEEP REJECT not reopened.
