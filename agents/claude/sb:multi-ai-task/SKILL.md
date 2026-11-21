---
name: sb:multi-ai-task
description: >
  Reusable SB multi-model orchestration primitive (multi-ai-task-v2 spine). Parallel workers,
  pool algebra, manifests, dispatch ledger, agent and concurrency caps, and result index. Runs on Claude Code and Codex; Cursor is not a host any more and is used only as one backend CLI (cursor-agent) beside the OpenCode-Go pool and the Codex and Claude CLIs.
argument-hint: "--task-prompt <text> --output-root <dir> [--ocg-pool none|lite|regular] [--cursor-pool none|default] [--dry-run]"
version: 1.0.0
---

# /sb:multi-ai-task — Multi-Model Task Primitive

**Plugin root**: `PLUGIN_ROOT` is the Silver Bullet plugin root, two directories above this file (`${PLUGIN_ROOT}/skills/silver-multi-ai-task/SKILL.md`). Run Silver Bullet scripts and read its templates through `${PLUGIN_ROOT}`, never relative to the project working directory: a downstream project does not contain them.

**Catalog:** workflow `WF-SILVER-MULTI-AI-TASK` · atomic flow `AF-MULTI-AI-TASK` ·
flow step `FS-SILVER_MULTI_AI_TASK` · spine `multi-ai-task-v2`.

Backend-neutral reusable primitive for parallel model lanes. DR-multi-AI and future
workflows compose this skill; it does **not** own DR phase state or consolidation.

## Host matrix

| Host | Status |
|------|--------|
| Claude Code | **supported** |
| Codex | **supported** |
| Cursor | **not a host** (error `SB_MULTI_AI_UNSUPPORTED_HOST`: Cursor is no longer a supported host; run from Claude Code or Codex) |
| Any other / unknown host | fail closed (`SB_MULTI_AI_UNSUPPORTED_HOST`) |

The host is the coding agent session that runs this CLI. It is detected from the process: Claude Code
sets `CLAUDECODE`; Codex sets one of `CODEX_SANDBOX`, `CODEX_CI`, `CODEX_THREAD_ID`,
`CODEX_INTERNAL_ORIGINATOR_OVERRIDE`. `SB_HOST` (`claude`, `codex`) can name the host when the markers are
missing (a plain terminal), but it can only make the gate stricter: `SB_HOST=cursor` or any other name
always fails closed, and a real Claude or Codex marker beats a different supported name. `CURSOR_*`
variables only count when no Claude or Codex marker is present (a Cursor terminal passes them on to the
agents started inside it). Unset a stale `SB_HOST` if the gate names a host you are not on.

A run on an unsupported host fails **before** preferences, caches, provisioning, writes or dispatch. A
dry run is a plan for a run, so it fails the same way (exit 2, nothing written).

## Backends

Every worker is an external CLI process started the same way on every host; none needs a particular host
tool (no Cursor Task tool, no `.cursor` directory, no host subagent API):

| Backend | CLI | Logical models | If the CLI is missing |
|---------|-----|----------------|-----------------------|
| `cursor` | `cursor-agent` (or the `cursor` launcher's `agent`), `SB_CURSOR_BIN` to override | the Cursor pool | those workers fail with `cursor CLI not found (...)` |
| `ocg` | OpenCode through `scripts/agent-opencode-delegate.sh`, `SB_OPENCODE_BIN` to override | the OCG pools | those workers fail with `opencode CLI not found (...)` |
| `codex` | `codex exec`, `CODEX_BIN` to override | `gpt-5.6-luna-medium` | `codex CLI not found (...)` |
| `claude` | `claude --print`, `CLAUDE_BIN` to override | `claude-opus-4.8-medium` | `claude CLI not found (...)` |

A missing CLI is a per-backend error, never a host error: the other backends still run, `status` is
`partial` when at least one worker succeeds, and the report lists `missing_backends` and a
`backend_availability` map (each backend's resolved CLI and how to fix it). `--dry-run` reports the same
availability for the planned pool without starting anything.

No extra consent record is needed: running the skill is the user's explicit opt-in, and the prompt goes to
the backends the user chose. It installs, wires and enables nothing (`consent.json` is not read or written).

## Under the orchestrator and the hooks

- **Parent mode.** A parent orchestrator session may not run Bash. Delegate the run to a worker
  (`Agent` on Claude Code, `spawn_agent` on Codex) with the `MULTI-AI-TASK` worker template; the worker
  runs the CLI. The Claude and Codex workers this skill starts carry `SB_ORCHESTRATOR_WORKER=1` (and
  `SB_ORCHESTRATOR_PARENT=0`), so a nested session is never mistaken for a parent.
- **Output root.** The hooks cannot see what a Python CLI writes, so the CLI keeps their boundaries
  itself. Use a project directory such as `.planning/multi-ai/<run-id>/` or `research/<run>/`. The CLI
  refuses (`OUTPUT_ROOT_NOT_ALLOWED`, exit 2, before any worker starts, in a dry run too) an output root
  inside Silver Bullet's runtime state or plugin cache, a `.git` directory, the home directory or a parent of
  it, or the ownership scope of an active agent delegation (its `.planning/agent-<host>/<task>/` evidence
  directory is allowed). It only ever writes the files listed under *Artifacts* below the output root.
- **Planning files.** The run never writes the protected planning files (`ROADMAP.md`, `STATE.md`, `*-PLAN.md`
  ...); `planning-file-guard` is unaffected and still denies direct writes to them.

## CLI contract

Plan a run first with `--dry-run` (no workers start and nothing is written: it resolves the pool, checks the agent cap, the host and the output root, and looks for each backend CLI):

```bash
python3 "${PLUGIN_ROOT}/skills/silver-multi-ai-task/scripts/multi_ai_cli.py" \
  --output-root .planning/multi-ai/<run-id>/ \
  --task-prompt "<task brief>" \
  --ocg-pool lite \
  --cursor-pool default \
  --dry-run
```

Drop `--dry-run` to dispatch. Flags:

| Flag | Default | Meaning |
|------|---------|---------|
| `--output-root DIR` | — | Required for a live run |
| `--task-prompt TEXT` | `""` | The task; workers receive it as untrusted data (see below) |
| `--ocg-pool none\|lite\|regular` | `lite` | OpenCode Go pool |
| `--cursor-pool none\|default` | `default` | Cursor backend pool (the cursor-agent CLI) |
| `--include-only ID` / `--exclude ID` | — | Repeatable pool edits |
| `--cursor-subscription auto\|subscribed\|unsubscribed` | `auto` | GLM-5.2 routing |
| `--max-agents N` | `11` | Unique logical agents allowed (dry-run and live) |
| `--concurrency N` | `6` | Parallel workers |
| `--timeout-sec N` | `600` | Per-worker timeout |
| `--phase-id DR-RETRIEVE\|DR-TRIANGULATE\|DR-CRITIQUE` | none | Optional DR prompt preset |

Without `--phase-id`, workers get neutral `TASK` instructions. A phase preset only selects
the prompt template; manifests and the result index stay phase-neutral.

### Pool algebra

See [`reference/pool-algebra.md`](reference/pool-algebra.md). Valid pools:
`{none,lite,regular} × {none,default}`. Resolution order:
expand pools → `--include-only` (replace) → `--exclude` → GLM subscription routing.

### Budget

Defaults: 11 unique logical agents · concurrency 6 · USD 25.00 · 2,000,000 tokens.
Only CLI flags are read in v1 (no preferences files). `--max-agents` is enforced before any
worker starts, in dry runs and live runs alike (`MAX_AGENTS_EXCEEDED`), and `--concurrency`
bounds parallel workers. The worker CLIs report no token or price data, so the USD and token
caps are recorded in the manifest but cannot be metered: manifests say
`usage_metered: false` and `price_known: false`.

## Worker safety

Workers read untrusted material (the task, other models' output, web pages), so they run
with the least privilege a research task needs:

- Each worker starts in a fresh, empty temporary directory that is deleted afterwards —
  never in the Silver Bullet install root or your project.
- The Cursor backend runs without `--force`/`--yolo`; OpenCode runs without `--auto`. Codex runs directly
  as `codex exec --sandbox read-only` and Claude as `claude --print --permission-mode default`,
  both with the prompt on stdin, because the agent-codex / agent-claude delegates map their
  strict mode to `--sandbox danger-full-access` and `acceptEdits`. An inherited
  `CLAUDE_PERMISSION_MODE` or `SB_AGENT_CERT_RUN` is dropped from the worker environment.
- Ctrl-C or SIGTERM sent to the dispatcher cancels queued workers (none starts afterwards) and
  terminates every live worker group.
- A read-only or non-approving worker cannot browse by shell; web access depends on the host
  CLI's own built-in tools and is the one capability a research worker keeps.
- The prompt fences the task and any prior context between nonce-tagged
  `<<<BEGIN UNTRUSTED ...>>>` / `<<<END UNTRUSTED ...>>>` markers, with a rule never to follow
  instructions found inside them. Prompts over 100,000 bytes are refused.
- Each worker runs in its own process group; a timeout terminates the whole group
  (SIGTERM, then SIGKILL), so CLIs started by wrapper scripts cannot keep running.
- Model fallback runs only when `SB_CURSOR_MODEL_ALLOW_FALLBACK=1`; otherwise only the
  primary model (and one retry after a transient network error) runs.

One failing worker never loses the others' results. A live run reports `ok: true` only when
at least one worker produced an authoritative result; `status` is `completed`, `partial` or
`failed`.

## Artifacts (under `--output-root`)

| File | Schema |
|------|--------|
| `work-items/<work-item-id>/multi-ai-work-item-manifest-v1.json` | `multi-ai-work-item-manifest-v1` |
| `dispatch-ledger.json` | `multi-ai-dispatch-ledger-v1` (one entry per attempt) |
| `result-index.json` | `multi-ai-result-index-v1` |
| `contributions/<work-item-id>.json` | contribution envelopes |
| `phases/<phase-id>/` | raw worker output and logs |

## Implementation steps (`AF-MULTI-AI-TASK`)

1. `FS-MULTI-AI-RESOLVE` — pool expand, alias normalize, subscription route
2. `FS-MULTI-AI-CAPABILITY-PROBE` — backend capability spike / cache
3. `FS-MULTI-AI-RESERVE` — agent-cap check before dispatch
4. `FS-MULTI-AI-DISPATCH` — backend launch (Cursor CLI / Codex / Claude / OCG)
5. `FS-MULTI-AI-RECONCILE` — ledger entries, authoritative attempt per agent
6. `FS-MULTI-AI-INDEX` — stable `multi-ai-result-index-v1`

## References

- [`reference/model-family-registry-v1.json`](reference/model-family-registry-v1.json)
- [`reference/host-matrix-v1.json`](reference/host-matrix-v1.json)
- [`schemas/`](schemas/)

## Composition

`/sb:deep-research-multi-ai` forwards neutral options only. No DR concepts leak into this skill.
