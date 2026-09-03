I'll conduct this research systematically, starting with the working directory context, then launching parallel primary-source fetches across the candidate landscape.
There's existing prior research from 2 other models. I'll do independent primary-source research, not merge theirs. Let me first check what they produced and then run my own parallel research.
I have a clear scope. Now let me launch parallel primary-source research across the candidate landscape. The prior reports (0B agent outputs) suggest they didn't actually run, so I'll do my own.
Got first 8 sources indexed. Now batching searches to extract evidence, while fetching the next wave in parallel.
Excellent data on first wave. Continuing with batched searches on wave 2 sources.
Hit rate limit. Switching to batched operations. Let me fetch remaining sources and then do all remaining searches in one batch.
GSD/Superpowers repos 404 - confirming they don't exist as public standalone projects. Now doing comprehensive batched queries.
The batch scoped queries to my placeholder. Need global scope. Let me run targeted searches against specific sources.
Rate limited. Let me use batch_execute with global query scope to do a proper global search.
Excellent findings. Claude Code has hooks-in-skills (frontmatter-scoped), BMAD has 34+ workflows, Spec Kit has TDD structure, Conductor has Skills for AI Assistants. Let me grab a few more candidates and then start writing.
Critical finding: Conductor Skills for AI Coding Assistants - direct SB analog. Let me batch search the final candidates efficiently.
I have enough primary-source data. Let me write the structured report now.
Report written: `docs/research-260624/prior-art-landscape-minimax-m3.md` (28.9KB, 309 lines, 25 candidates)

**Key findings vs prior research (deepseek, qwen):**
- **New candidate surfaced:** **Microsoft Agent Framework** v1.11.1 (Jun 25, 2026) — the actual AutoGen + Semantic Kernel convergence; migration guides from both; 4 orchestration patterns (sequential/concurrent/handoff/group); checkpointing + time-travel. Replaces both in scoring.
- **Conductor reclassified upward to "strong-adjacent"** based on **Conductor Skills for AI Coding Assistants** (NEW finding) — closer to SB's catalog+plugin model than any other OSS tool.
- **Claude Code "hooks-in-frontmatter"** (NEW finding) — lifecycle-scoped hooks defined directly in skill/subagent files. Strongest enforcement-mechanism analog to SB's hook-enforced skill chains.
- **Negative results confirmed:** GSD and Superpowers GitHub repos 404 (unverifiable).
- **No "direct" match** — top score 9/16 (Conductor OSS), 8/16 (Camunda 8), 6/16 (Claude Code + Argo). SB's combination of catalog + V-loops + enforcement + SE+DevOps is unoccupied.
