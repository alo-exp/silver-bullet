# OpenCode: Dynamically Launching Model-Specific Subagents

**Date:** 2026-06-27
**Mode:** Deep (single focused question, multi-source verification)
**Repository:** `anomalyco/opencode` (note: the project migrated from `sst/opencode` to `anomalyco/opencode`; the old org surfaces in stale search results but is no longer canonical)

---

## TL;DR

**No** — the `task` tool in OpenCode does **not** accept a per-call `model` parameter. A subagent's model is fully static and is decided at config time, falling back to the parent session's model at runtime. The model is **never** picked dynamically by the parent agent on a per-invocation basis.

However, **multi-model subagent orchestration is fully supported** — it just has to be expressed as a *static* mapping from `subagent_type` to `model` in `opencode.json`. Each named subagent (e.g. `code-reviewer`, `explore`, `general`) can be pinned to any model via `agent.<name>.model`, and the parent agent dispatches to them by `subagent_type`. The orchestrator pattern "fan out to model A for cheap work, model B for synthesis" is achievable today — it just requires the orchestrator to be a primary agent that decides *which subagent to call*, not *what model to use*.

**Status of the dynamic per-call model override:** it has been requested at least 8 times as issues (#6651, #11215, #11217, #11377, #17595, #26925, #32730, #29984) and implemented as PRs at least 6 times (#14961, #17577, #18528, #25881, #26535, #29447). **All PRs are either closed-without-merge or still open.** The latest forward-port (PR #29447) is open as of 2026-06-27. The maintainers have not rejected the design — the PRs are being closed by automated cleanup ("high volume of PRs from users and AI agents") rather than on technical grounds. The feature is *available in draft, unmerged* form, but **not in the released product**.

---

## Evidence

### 1. Official documentation (opencode.ai/docs/agents/)

The `agent.<name>.model` field exists at the **config level**:

> Use the `model` config to override the model for this agent. Useful for using different models optimized for different tasks. For example, a faster model for planning, a more capable model for implementation.
>
> **Tip:** If you don't specify a model, primary agents use the model globally configured while **subagents will use the model of the primary agent that invoked the subagent**.

Source: [opencode.ai/docs/agents/#model](https://opencode.ai/docs/agents/#model)

This is the single most important sentence: **subagents inherit the parent's model by default.** There is no override hook.

### 2. The actual source code (`packages/opencode/src/tool/task.ts` on `dev` branch)

Lines 44–58 of `task.ts` define the parameter schema for the `task` tool:

```ts
const BaseParameterFields = {
  description: Schema.String.annotate({ description: "A short (3-5 words) description of the task" }),
  prompt: Schema.String.annotate({ description: "The task for the agent to perform" }),
  subagent_type: Schema.String.annotate({ description: "The type of specialized agent to use for this task" }),
  task_id: Schema.optional(Schema.String).annotate({...}),
  command: Schema.optional(Schema.String).annotate({...}),
}

export const Parameters = Schema.Struct({
  ...BaseParameterFields,
  background: Schema.optional(Schema.Boolean).annotate({...}),
})
```

**There is no `model` field in the schema.** The full parameter set is: `description`, `prompt`, `subagent_type`, `task_id`, `command`, `background`.

Line 175–177 shows the model resolution logic:

```ts
const model = next.model ?? {
  modelID: msg.info.modelID,
  providerID: msg.info.providerID,
}
```

That `??` is the entire model-resolution story: if the subagent has its own config-time `model`, use it; otherwise inherit the parent's. **There is no third branch for per-call overrides.**

Source: `https://raw.githubusercontent.com/anomalyco/opencode/dev/packages/opencode/src/tool/task.ts` (346 lines, fetched 2026-06-27)

### 3. The "task" tool has no `model` field — confirmed by an explicit PR body

PR #29984, titled **"feat(task): allow model parameter in task()"**, is itself an issue body that documents the current state of the code:

> From `packages/opencode/src/tool/task.ts`:
> - `BaseParameterFields` has: `description`, `prompt`, `subagent_type`, `task_id`, `command` — **no `model` parameter**
> - Model is currently derived from `next.model ?? { modelID: msg.info.modelID, providerID: msg.info.providerID }`
> - Adding an optional `model` string parameter that overrides this derivation would enable the use case

Source: [anomalyco/opencode#29984](https://github.com/anomalyco/opencode/issues/29984), state: open

### 4. PR history — six attempts to add the model parameter, none merged

| PR | Title | Author | State | Merge |
|---|---|---|---|---|
| [#17577](https://github.com/anomalyco/opencode/pull/17577) | feat(opencode): add model override for task tool subagents | Quadina | closed (2026-03-21) | **not merged** |
| [#17570](https://github.com/anomalyco/opencode/pull/17570) | feat: add assign-model feature for subagent model selection | VenTheZone | closed (2026-05-15) | **not merged** (auto-cleanup) |
| [#18528](https://github.com/anomalyco/opencode/pull/18528) | feat(task): add model override for subagents | ziuus | closed (2026-05-15) | **not merged** (auto-cleanup) |
| [#24317](https://github.com/anomalyco/opencode/pull/24317) | feat(tui): assign model to specific agent via Ctrl+E | MrRobotoGit | closed (2026-05-25) | **not merged** (auto-cleanup) |
| [#25881](https://github.com/anomalyco/opencode/pull/25881) | feat(task-tool): Add model parameter for subagent LLM routing | ziuus | closed (2026-05-05) | **not merged** (author withdrew, redirected to #18528) |
| [#26535](https://github.com/anomalyco/opencode/pull/26535) | feat(opencode): add model parameter to task tool for subagent model override | funkybooboo | closed (2026-05-28) | **not merged** (author forward-ported to #29447) |
| [#29447](https://github.com/anomalyco/opencode/pull/29447) | feat(opencode): add task model override | kobicovaldev | **open (2026-06-26)** | not yet |

**Why they were closed:** the comment threads on the closed PRs are explicit. The closure messages are identical templates from user `rekram1-node`:

> "Automated PR Cleanup — Due to the high volume of PRs from users and AI agents, we periodically close older PRs using automated criteria so maintainers can focus review time on the most active and community-supported contributions."

In other words, the maintainers are **not rejecting the design**; they are **triaging the backlog**. At least one PR (#18528) had active users testing it locally and requesting merge. Another (#26535) had a community member volunteer a refreshed forward-port to help unblock the review queue.

**The merged PRs that touched `task.ts`** are unrelated to the model override:
- [#30630](https://github.com/anomalyco/opencode/pull/30630) "fix(opencode): preserve variant for delegated tasks" — 3-line patch, fixes variant (reasoning level) inheritance, not model.
- [#30786](https://github.com/anomalyco/opencode/pull/30786) "fix(opencode): attribute task child agent on creation" — 1-line patch, fixes session attribution, not model.

Neither of these adds a `model` parameter to the tool schema.

### 5. The feature-request issue trail — eight open issues, all asking for the same thing

| Issue | Title | State |
|---|---|---|
| [#6651](https://github.com/anomalyco/opencode/issues/6651) | [FEATURE]: Dynamic model selection for subagents via Task tool | open |
| [#11215](https://github.com/anomalyco/opencode/issues/11215) | (cited as duplicate) | — |
| [#11217](https://github.com/anomalyco/opencode/issues/11217) | UI-driven `@agent:provider/model` syntax | — |
| [#11377](https://github.com/anomalyco/opencode/issues/11377) | (tier abstraction variant) | — |
| [#17595](https://github.com/anomalyco/opencode/issues/17595) | [FEATURE]: Runtime model override for task tool subagents | open |
| [#26925](https://github.com/anomalyco/opencode/issues/26925) | [FEATURE]: Task tool should support `model` parameter for cost-optimized multi-agent orchestration | open |
| [#29984](https://github.com/anomalyco/opencode/issues/29984) | feat(task): allow model parameter in task() | open |
| [#32730](https://github.com/anomalyco/opencode/issues/32730) | [FEATURE]: Ability To Specify Model And Effort For Subagents in Prompt | open |

The bot comment on #17595 is candid:

> "This issue might be a duplicate of existing issues. Please check: #6651 (same core concept), #11215 (same goal of switching models at runtime without static config)."

The community has converged on the design. What is missing is maintainer bandwidth to merge it.

### 6. Real-world user pain — bug reports corroborate the static-only design

These are not feature requests — they are bug reports showing that the static-only model causes real user pain:

- [#30289](https://github.com/anomalyco/opencode/issues/30289) `github run: sub-agent inherits orchestrator model, ignores ref model from plugin` — explicit: "The `task` tool call has no `model` field — sub-agent inherits parent model."
- [#33043](https://github.com/anomalyco/opencode/issues/33043) `Subagent sessions created with model=undefined causing ProviderModelNotFoundError` — the model is undefined when the agent has no static config and parent resolution fails.
- [#18615](https://github.com/anomalyco/opencode/issues/18615) `[Bug] Model parameter ignored when launching subagent with agent name` — even when `model` is passed via SDK, it's overridden by the agent's fallback chain.
- [#17870](https://github.com/anomalyco/opencode/issues/17870) `[Bug] Subagent spawned via Task tool uses global config model instead of inheriting parent session's active model` — confirms no per-call control.
- [#20859](https://github.com/anomalyco/opencode/issues/20859) `Subagent models are ignored when using GitHub Copilot provider` — different bug, same root cause.
- [#24757](https://github.com/anomalyco/opencode/issues/24757) `Subtasks do not inherit the active model variant from the parent session` — variant (reasoning level) is *also* not passed; only partially addressed by PR #30630.
- [#34043](https://github.com/anomalyco/opencode/issues/34043) `Subagent fallback chain prepends incorrect opencode/ prefix to model names` — operational fallout from the static model approach.

### 7. The recommended (and supported) workaround: per-agent config

The docs and the issue thread converge on the same workaround — express the multi-model orchestration as a static mapping of `subagent_type → model`. From the docs example:

```jsonc
{
  "agent": {
    "build":          { "mode": "primary", "model": "anthropic/claude-sonnet-4-20250514" },
    "plan":           { "mode": "primary", "model": "anthropic/claude-haiku-4-20250514" },
    "code-reviewer":  { "mode": "subagent", "model": "anthropic/claude-sonnet-4-20250514" },
    "explore-quick":  { "mode": "subagent", "model": "anthropic/claude-haiku-4-20250514" },
    "explore-deep":   { "mode": "subagent", "model": "anthropic/claude-sonnet-4-20250514" },
    "synthesizer":    { "mode": "subagent", "model": "anthropic/claude-opus-4-20250514" }
  }
}
```

The orchestrator's `subagent_type` *is* the model selection. The agent that picks the model is the LLM in the parent session — but the choice it gets to make is "which subagent do I call?", not "what model does this subagent use?".

This is the only way to do multi-model orchestration in OpenCode today.

---

## Reddit / forum evidence

- `r/opencodeAI` returned no indexed threads matching "subagent model" or "task tool model" via either the official JSON endpoint or the HTML search.
- Hacker News via Algolia search (`hn.algolia.com`) returned 11 hits for `opencode subagent`, but none of them specifically discuss the per-call model override question. The closest matches (`Show HN: Semble`, `Lazyagent`) are about external tooling, not OpenCode's `task` tool.

The forum-level evidence is therefore **negative / null**, not corroborating. The signal lives almost entirely on GitHub.

---

## Methodology

1. **Phase 1 (Scope):** Single technical question, two sub-questions: (a) is it possible today? (b) what is the workaround?
2. **Phase 2 (Plan):** Sources to triangulate: official docs, repo source code, GitHub issues, GitHub PRs, Reddit, Hacker News. Required at least 3 independent sources per major claim.
3. **Phase 3 (Retrieve):** Fetched `opencode.ai/docs/agents/`, `opencode.ai/docs/config/`, `opencode.ai/docs/tools/`, `opencode.ai/docs/models/`. Pulled the actual `task.ts` source from the `dev` branch. Used the GitHub CLI to query issues and PRs.
4. **Phase 4 (Triangulate):** Cross-checked the model-resolution claim against (i) the docs, (ii) the source code, (iii) the PR body of #29984, (iv) the bug reports #30289 / #33043 / #18615, and (v) the closed PRs' own commit diffs. All five sources agree.
5. **Phase 5 (Synthesize):** Answer is unambiguous. The blocker is not the design but the maintainer review bandwidth.

### Caveats and limitations

- **Repository URL:** The repo was previously `sst/opencode` and is now `anomalyco/opencode`. Several search results still point to `sst/opencode` URLs (404 on fetch). All citations here use the canonical `anomalyco/opencode` path.
- **Branch state:** Source code was pulled from `dev` (the active development branch). The `main` branch does not exist in this fork. The `task.ts` on `dev` is the most current reference; a tagged release on `dev` will follow the same schema.
- **PR status volatility:** The PR list is hot — a PR being "open" today is not a guarantee of "open" tomorrow. PR #29447 was the most recent forward-port as of fetch time (2026-06-27).
- **Reddit/forum null result:** The subreddit is small and search-indexed poorly; absence of evidence is not evidence of absence. The community discussion of this feature is concentrated on GitHub, not forums.
- **Variants vs. models:** Several issues (#21632, #24757, #30630, #33960) are about the related question of whether variants (reasoning effort levels) are inherited. This is a **separate** problem from model selection. The model-resolution `??` and variant-resolution paths are distinct in `task.ts`. A reader of the open issues should not conflate the two.

---

## Sources (full bibliography)

### Official documentation

1. [OpenCode — Agents / Options / Model](https://opencode.ai/docs/agents/#model) — per-agent `model` config and inheritance rules
2. [OpenCode — Agents / Configure / JSON](https://opencode.ai/docs/agents/#json) — example config
3. [OpenCode — Config / Schema / Models](https://opencode.ai/docs/config/#models) — global `model` and `small_model` config
4. [OpenCode — Config / Schema / Default agent](https://opencode.ai/docs/config/#default-agent) — `default_agent` field
5. [OpenCode — Tools](https://opencode.ai/docs/tools/) — built-in tool reference

### Source code

6. `packages/opencode/src/tool/task.ts` — `anomalyco/opencode@dev` branch — fetched 2026-06-27 from `https://raw.githubusercontent.com/anomalyco/opencode/dev/packages/opencode/src/tool/task.ts` (346 lines, defines `BaseParameterFields` and `Parameters` schemas with no `model` field)

### GitHub issues (open feature requests)

7. [anomalyco/opencode#6651](https://github.com/anomalyco/opencode/issues/6651) — "[FEATURE]: Dynamic model selection for subagents via Task tool"
8. [anomalyco/opencode#17595](https://github.com/anomalyco/opencode/issues/17595) — "[FEATURE]: Runtime model override for task tool subagents"
9. [anomalyco/opencode#26925](https://github.com/anomalyco/opencode/issues/26925) — "[FEATURE]: Task tool should support `model` parameter for cost-optimized multi-agent orchestration"
10. [anomalyco/opencode#29984](https://github.com/anomalyco/opencode/issues/29984) — "feat(task): allow model parameter in task()"
11. [anomalyco/opencode#32730](https://github.com/anomalyco/opencode/issues/32730) — "[FEATURE]: Ability To Specify Model And Effort For Subagents in Prompt"

### GitHub issues (bug reports corroborating the static-only design)

12. [anomalyco/opencode#30289](https://github.com/anomalyco/opencode/issues/30289) — "github run: sub-agent inherits orchestrator model"
13. [anomalyco/opencode#33043](https://github.com/anomalyco/opencode/issues/33043) — "Subagent sessions created with model=undefined"
14. [anomalyco/opencode#18615](https://github.com/anomalyco/opencode/issues/18615) — "[Bug] Model parameter ignored when launching subagent with agent name"
15. [anomalyco/opencode#17870](https://github.com/anomalyco/opencode/issues/17870) — "[Bug] Subagent spawned via Task tool uses global config model"
16. [anomalyco/opencode#20859](https://github.com/anomalyco/opencode/issues/20859) — "Subagent models are ignored when using GitHub Copilot provider"
17. [anomalyco/opencode#34043](https://github.com/anomalyco/opencode/issues/34043) — "Subagent fallback chain prepends incorrect opencode/ prefix"
18. [anomalyco/opencode#33334](https://github.com/anomalyco/opencode/issues/33334) — "`task` tool advertises subagents outside active agent `permission.task` allow-list" (related: confirms the task tool schema is what the docs/source show)
19. [anomalyco/opencode#24757](https://github.com/anomalyco/opencode/issues/24757) — "Subtasks do not inherit the active model variant from the parent session"
20. [anomalyco/opencode#21632](https://github.com/anomalyco/opencode/issues/21632) — "subagent model variants are parsed but not applied at runtime in v1.4.0"

### GitHub pull requests

21. [anomalyco/opencode#18528](https://github.com/anomalyco/opencode/pull/18528) — `feat(task): add model override for subagents` (closed, not merged, auto-cleanup)
22. [anomalyco/opencode#25881](https://github.com/anomalyco/opencode/pull/25881) — `feat(task-tool): Add model parameter for subagent LLM routing` (closed, not merged, author-withdrawn)
23. [anomalyco/opencode#26535](https://github.com/anomalyco/opencode/pull/26535) — `feat(opencode): add model parameter to task tool for subagent model override` (closed, author-forwarded)
24. [anomalyco/opencode#17577](https://github.com/anomalyco/opencode/pull/17577) — `feat(opencode): add model override for task tool subagents` (closed, not merged)
25. [anomalyco/opencode#17570](https://github.com/anomalyco/opencode/pull/17570) — `feat: add assign-model feature for subagent model selection` (closed, not merged)
26. [anomalyco/opencode#24317](https://github.com/anomalyco/opencode/pull/24317) — `feat(tui): assign model to specific agent via Ctrl+E` (closed, not merged)
27. [anomalyco/opencode#29447](https://github.com/anomalyco/opencode/pull/29447) — `feat(opencode): add task model override` (open as of 2026-06-27)
28. [anomalyco/opencode#30630](https://github.com/anomalyco/opencode/pull/30630) — `fix(opencode): preserve variant for delegated tasks` (merged, variant only)
29. [anomalyco/opencode#30786](https://github.com/anomalyco/opencode/pull/30786) — `fix(opencode): attribute task child agent on creation` (merged, unrelated)

### Forum / social

30. Hacker News via Algolia — `query=opencode subagent model`, 11 hits, none discussing per-call model override specifically
31. `r/opencodeAI` search — null result (subreddit exists but no indexed threads on the specific question)

---

## What this means for the user's question

The original question was: *"Can I orchestrate a multi-model deep research using the deep-research skill, using one subagent for each model that is enabled under the OpenCode Go provider?"*

The answer is **not via per-call model dispatch** — that capability does not exist in the released product. It is **possible via per-agent model pinning** — the orchestrator's parent agent decides which subagent to call, and each subagent's `opencode.json` entry pins it to a specific model. To fan out across all models on the OpenCode Go provider today, the parent agent must:

1. Have a subagent_type defined in `opencode.json` for **each model** it wants to use.
2. Each subagent_type must declare its `model` field pointing to the desired `provider/model-id`.
3. The parent's prompt (or a custom skill) must dispatch work to the right `subagent_type` based on the work's complexity.

This is what the deep-research skill would have to do to multi-model fan out on this host — not a per-call `task(subagent_type="...", model="...")` call (which does not exist), but a static mapping in `opencode.json` plus orchestrator-level routing.
