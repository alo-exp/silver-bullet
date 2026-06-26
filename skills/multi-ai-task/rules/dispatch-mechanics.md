# Dispatch Mechanics — multi-ai-task (task-agnostic)

How to actually launch N parallel LLM processes. The mechanism depends on your harness, not the task type.

---

## The 4 dispatch mechanisms (in order of preference)

### Mechanism 1: Native `task` tool with custom subagent types (BEST, but rarely works)

If your harness supports custom subagent types via `task(subagent_type="my-agent", prompt="...")`, use it. Set up the agents in your config first:

```jsonc
// ~/.config/opencode/opencode.jsonc
{
  "agent": {
    "ocg-minimax-m3": { "mode": "subagent", "model": "opencode-go/minimax-m3" },
    "ocg-qwen3.7-max": { "mode": "subagent", "model": "opencode-go/qwen3.7-max" }
  },
  "permission": {
    "task": { "ocg-*": "allow" }
  }
}
```

Then in your session: `task(subagent_type="ocg-minimax-m3", description="...", prompt="...")`.

**Limitation (as of 2026-06):** Some OpenCode harnesses hardcode the `task` tool's `subagent_type` enum to default values like `["explore", "general"]`. Custom types are defined in config but unreachable from the tool surface. If you see `Unknown agent type: ...`, fall back to Mechanism 2.

### Mechanism 2: `opencode run --model <provider/model>` (WORKAROUND, recommended)

When the `task` tool rejects custom subagent types, dispatch each model as a primary `build` agent with a `--model` flag:

```bash
for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max; do
  npx opencode-ai run \
    --model "$model" \
    --title "multi-ai-task-$(date +%s)" \
    --dangerously-skip-permissions \
    "<task-prompt>" \
    > "out/$model.md" 2> "out/$model.err" &
done
wait
```

This is what worked in the proven provenance run (2026-06-27). Notes:
- The `build` agent's `permission.task` must allow the subagents you want it to call (if any)
- `--dangerously-skip-permissions` is fine for non-destructive research tasks
- Parallel is faster but risks MCP port collision; sequential is safer

### Mechanism 3: HTTP SDK with `client.session.promptAsync()`

If you have an OpenCode server running, use the SDK:

```javascript
const sessions = await Promise.all(models.map(async (m) => {
  const session = await client.session.create({ agent: "build" });
  await client.session.promptAsync({
    path: { id: session.id },
    body: { model: { providerID: m.provider, modelID: m.model }, parts: [{ type: "text", text: prompt }] }
  });
  return { model: m, session: session.id };
}));
```

**Known bug (2026-06):** Issue #18615 reports that even with explicit `model` and `agent` in the body, OpenCode may override them with the agent's built-in fallback chain. Workaround: pass model on the server side via config, or use mechanism 2.

### Mechanism 4: Direct HTTP to provider API

Skip the OpenCode layer entirely; call each provider's API directly with the same prompt. Highest control, but you lose MCP access and have to manage auth per provider.

```python
import asyncio, openai
async def dispatch(model, prompt):
    client = openai.AsyncOpenAI(base_url=ENDPOINTS[model.provider], api_key=KEYS[model.provider])
    return await client.chat.completions.create(
        model=model.id, messages=[{"role": "user", "content": prompt}]
    )
results = await asyncio.gather(*[dispatch(m, prompt) for m in models])
```

---

## Parallel vs sequential dispatch

| Mode | Pros | Cons | When to use |
|------|------|------|-------------|
| **Parallel** (concurrent processes) | Fastest wall-time | MCP port collision if multiple share a port; harder to debug | Independent tasks; no shared state; sub-2-min per model |
| **Sequential** (one at a time) | Predictable; no port issues; clean logs | Slowest wall-time = N × per-model time | Long-running tasks (10+ min each); shared MCPs |

**Recommended default:** sequential for tasks >5 min per model, parallel for short tasks. For the proven 6-model run, each took ~2-3 min, so parallel (with 10-min shell timeout) worked.

---

## Per-model output capture

The model may write its report to disk (via `write` tool) AND emit a CLI stream to stdout. Both are valuable:
- **CLI stdout** (the `agent-output/<model>.md` file): the immediate response, often truncated if the shell wrapper times out
- **Disk write** (any file the model created in the CWD): the full report, including any late-stage synthesis

**Always check the CWD for stray `*.md` files after a dispatch.** If the shell wrapper was killed but the model already wrote its report, the report is still on disk.

---

## Failure handling

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `npx opencode-ai run` returns instantly with no output | Model unavailable, network error, or rate-limited | Check stderr, retry, or substitute model |
| Subprocess dies after 2 min with no report | Shell tool's 2-min default timeout | Use `timeout` parameter on bash tool, or run sequential |
| Report partial — only the planning phase | MCP rate-limit blocked mid-task | Pass `queries: [array]` (batched) in prompt; instruct model to use `ctx_batch_execute` |
| 5/N models produce reports, 1 missing | One model in permanent rate-limit or API outage | Substitute or skip; flag in consolidated report's coverage scoreboard |
| All N models return same content (no diversity) | Prompt too narrow, or models too similar | Broaden the prompt; add adversarial framing; use diverse provider families |

---

## Auth / credentials

Each model needs API credentials. For OpenCode Go (`opencode-go/*`) and Anthropic (`anthropic/*`) and OpenAI (`openai/*`):
- OpenCode Go: implicit via `opencode auth login` (cached locally)
- Anthropic: `ANTHROPIC_API_KEY` env var
- OpenAI: `OPENAI_API_KEY` env var
- Google: `GOOGLE_API_KEY` env var
- Local Ollama: no auth, just `http://localhost:11434/v1`

Run `opencode providers` to see configured providers and their auth status.

---

## Choosing the right mechanism

| If you have... | Use... |
|----------------|--------|
| OpenCode harness with `task` tool that accepts custom subagent_types | Mechanism 1 |
| OpenCode harness but `task` tool rejects custom types | Mechanism 2 |
| An OpenCode server running (`opencode serve`) | Mechanism 3 |
| A different harness entirely (Claude, Codex, Cursor with no OpenCode) | Mechanism 4 |
| Multiple MCPs that share ports (e.g., agentmemory on 3111) | Mechanism 2 sequential |
| Time-critical interactive session | Mechanism 2 parallel with `--concurrency 4` |
| Models from different providers (e.g., OpenAI + Anthropic + local) | Mechanism 4 for cross-provider coverage |
