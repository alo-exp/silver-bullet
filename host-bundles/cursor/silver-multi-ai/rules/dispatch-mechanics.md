# Dispatch Mechanics — multi-ai-task (task-agnostic)

How to actually launch N parallel LLM processes. The mechanism depends on your harness, not the task type.

---

## The 4 dispatch mechanisms (in order of preference)

### Mechanism 1: Native `task` tool with pre-configured subagent types (preferred-if-available)

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

**Important constraint (as of 2026-06):** The `task` tool's `Parameters` schema (in `packages/opencode/src/tool/task.ts`) does **not** include a `model` field. The model is resolved as `next.model ?? { modelID: msg.info.modelID, providerID: msg.info.providerID }` — meaning each subagent_type's model is decided at *config time*, not at call time. To multi-model fan out, the user must pre-define one subagent_type per model in `opencode.json` (see example above). Dynamic per-call model selection is a 6-time-requested feature (issues #6651, #11215, #17595, #26925, #29984, #32730) with one open PR (#29447); not yet released.

**Host-config caveat:** Some OpenCode harnesses restrict the `task` tool's `subagent_type` enum to defaults like `["explore", "general"]`. If you see `Unknown agent type: ocg-minimax-m3`, your harness's `permission.task` allow-list is too narrow — widen it or use Mechanism 2.

### Mechanism 2: `opencode run --model <provider/model>` (default)

When the `task` tool rejects custom subagent types, or when you want a no-config-fan-out, dispatch each model as a primary `build` agent with a `--model` flag:

```bash
OUT=./out/$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"

# Timeout per model: adjust to your task. 10min for research, 5min for review.
TIMEOUT=600

# macOS doesn't ship `timeout` by default; use `gtimeout` from coreutils
# (install via `brew install coreutils`). Linux ships `timeout` in util-linux.
TIMEOUT_CMD="timeout"
if [ "$(uname)" = "Darwin" ] && command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
fi

for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max opencode-go/glm-5.2; do
  slug=$(echo "$model" | cut -d/ -f2)  # sanitize "opencode-go/minimax-m3" → "minimax-m3"
  "$TIMEOUT_CMD" "$TIMEOUT" npx -y opencode-ai run \
    --model "$model" \
    --title "multi-ai-task-${slug}-$(date +%s)" \
    --dangerously-skip-permissions \
    "$PROMPT" \
    > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
done
wait
echo "Outputs in $OUT/"
```

**This is what worked in the proven provenance run (2026-06-27).** Notes:
- `$slug` sanitizes the model name so filenames don't contain slashes (the `cut -d/ -f2` pattern is critical — without it, `out/$model.md` creates subdirectories or fails).
- `--y` in `npx -y opencode-ai run` skips the install prompt; without it, background subprocesses may hang.
- `--dangerously-skip-permissions` is fine for **read-only** tasks (research, code review, fact-check). For **write tasks** (writing a file to the user's repo, modifying configs), do NOT use this flag — let the agent prompt for permission. The skill is task-agnostic, so the user is responsible for choosing the right security posture.
- The `build` agent's `permission.task` must allow the subagents you want it to call (if any).
- Parallel is faster but risks MCP port collision; sequential is safer (see Parallel vs sequential below).
- **Timeout:** `timeout "$TIMEOUT"` enforces per-model timeout. On Linux, `timeout` is a coreutil; on macOS, use `gtimeout` from `brew install coreutils`. Adjust `TIMEOUT` to your task (600s = 10 min for research, 300s = 5 min for quick review). If a model hangs past `TIMEOUT`, the process is killed and stderr shows the timeout. This prevents the 2-min default bash tool timeout from silently killing long-running models.

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

**Known bug (2026-06):** [Issue #18615](https://github.com/anomalyco/opencode/issues/18615) reports that even with explicit `model` and `agent` in the body, OpenCode may override them with the agent's built-in fallback chain. Workaround: pass model on the server side via config, or use Mechanism 2.

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
| **Parallel** (concurrent processes) | Fastest wall-time = `max(per_model_time)` | MCP port collision if multiple share a port; harder to debug | Independent tasks; no shared state; sub-5-min per model |
| **Sequential** (one at a time) | Predictable; no port issues; clean logs | Slowest wall-time = `N × per_model_time` | Long-running tasks (10+ min each); shared MCPs |

**Recommended default:** choose parallel if `max(per_model_time) ≤ your latency budget`; otherwise sequential. The proven 6-model run took ~2-3 min/model, so parallel (with 10-min shell timeout) was the right call. For 30+ min per model, sequential is the only sane option.

**MCP port collision caveat:** "Sequential" alone doesn't fix port collision if the MCP binds a port on first start and holds it. The proven fix is to either (a) configure MCPs that support multiplexing, or (b) dispatch to a single model at a time AND restart the MCP between dispatches.

---

## Per-model output capture

The model may write its report to disk (via `write` tool) AND emit a CLI stream to stdout. Both are valuable:
- **CLI stdout** (the `<slug>.md` file in the output dir): the immediate response, often truncated if the shell wrapper times out
- **Disk write** (any file the model created in its CWD): the full report, including any late-stage synthesis

**Always check the model's CWD for stray `*.md` files after a dispatch.** If the shell wrapper was killed but the model already wrote its report, the report is still on disk. The output dir is the "expected" location; the CWD is the "fallback" location.

---

## Failure handling

The skill is **fail-soft**: a model failure is logged, the model is excluded from the consolidation, and the run continues with the models that did respond. The skill does **not retry** (retry policy lives in the calling agent's runner, not in the skill core — this avoids retry loops in shell wrappers with 2-min default timeouts).

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| `npx -y opencode-ai run` returns instantly with no output | Model unavailable, network error, or rate-limited | Check stderr; substitute or skip the model |
| Subprocess dies after 2 min with no report | Shell tool's 2-min default timeout | Set explicit `timeout` on bash tool, or run sequential |
| Report partial — only the planning phase | MCP rate-limit (9 calls/30s) blocked mid-task | Pass `queries: [array]` (batched) in prompt; instruct model to use `ctx_batch_execute` |
| 5/N models produce reports, 1 missing | One model in permanent rate-limit or API outage | Substitute or skip; flag in `run-manifest.json → models_failed` |
| All N models return same content (no diversity) | Prompt too narrow, or models from same provider family | Broaden the prompt; add adversarial framing; use models from different provider families |
| `task` tool returns "Unknown agent type" | Harness restricts `subagent_type` enum to defaults | Widen `permission.task` allow-list, or use Mechanism 2 |
| `task` tool doesn't accept `--model` | Static-config limitation (see Mechanism 1) | Use Mechanism 2 |
| Model's CWD contains a stray `*.md` after dispatch | Model wrote to its own CWD instead of the output dir | Copy the stray file to the output dir manually; the report is still usable |

---

## Auth / credentials

Each model needs API credentials. The auth model varies by harness:

| Harness | Auth mechanism |
|---------|----------------|
| OpenCode Go (`opencode-go/*`) | `opencode auth login` (cached locally on first use) |
| Anthropic (`anthropic/*`) | `ANTHROPIC_API_KEY` env var |
| OpenAI (`openai/*`) | `OPENAI_API_KEY` env var |
| Google (`google/*`) | `GOOGLE_API_KEY` env var |
| Local Ollama | no auth, just `http://localhost:11434/v1` |

Run `opencode providers` to see configured providers and their auth status.

**Missing credential handling:** if a model's auth is missing, the subprocess will fail at the API call. The skill flags this in `run-manifest.json → models_failed` with the stderr reason. The skill does **not** automatically skip to a fallback model — the user must explicitly omit the model from `--models` if they want to skip it.

---

## Model selection strategy

For maximum diversity, pick models from different provider families:

| Task type | Strategy |
|-----------|----------|
| **Reasoning-heavy** (research, fact-check) | ≥1 reasoning-focused model (e.g., `deepseek-v4-pro`) + ≥1 generalist (e.g., `qwen3.7-max`) |
| **Creative** (ideation, writing critique) | Maximize provider diversity; same-family models produce similar creative output |
| **Code-heavy** (code review, refactor planning) | ≥1 code-specialized model if available; code-review benefits from models trained on different code corpora |

**Avoid:** dispatching >2 models from the same provider family (diminishing diversity returns). **Minimum viable:** 2 models from different families. Below 2, the skill adds no value (no cross-model dedup/conflict possible).

**Default model set** (when `--models` is omitted): the skill queries the local OpenCode config for available models and picks a balanced set of 4-6 models across providers. "Balanced" = at least 2 different provider families, no more than 2 models from the same family, with at least one reasoning-capable model if the task is research-like.

---

## Choosing the right mechanism

| If you have... | Use... |
|----------------|--------|
| OpenCode harness with `task` tool that accepts custom subagent_types AND you've pre-defined them in `opencode.json` | Mechanism 1 |
| OpenCode harness but `task` tool rejects custom types OR you want zero-config fan-out | Mechanism 2 |
| An OpenCode server running (`opencode serve`) | Mechanism 3 |
| A different harness entirely (supported hosts with no OpenCode) | Mechanism 4 |
| Multiple MCPs that share ports (e.g., agentmemory on 3111) | Mechanism 2 sequential |
| Time-critical interactive session (<5 min budget for total run) | Mechanism 2 parallel |
| Models from different providers (e.g., OpenAI + Anthropic + local) | Mechanism 4 for cross-provider coverage |
