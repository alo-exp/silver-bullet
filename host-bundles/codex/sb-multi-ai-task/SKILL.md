---
name: "sb:multi-ai-task"
title: "Multi AI Task"
description: >
  Reusable SB multi-model orchestration primitive (multi-ai-task-v2 spine). Parallel workers,
  pool algebra, manifests, dispatch ledger, agent and concurrency caps, and result index. Cursor host only in v1.
argument-hint: "--task-prompt <text> --output-root <dir> [--ocg-pool none|lite|regular] [--cursor-pool none|default] [--dry-run]"
version: 1.0.0
---

# /sb:multi-ai-task — Multi-Model Task Primitive

**Catalog:** workflow `WF-SILVER-MULTI-AI-TASK` · atomic flow `AF-MULTI-AI-TASK` ·
flow step `FS-SILVER_MULTI_AI_TASK` · spine `multi-ai-task-v2`.

Backend-neutral reusable primitive for parallel model lanes. DR-multi-AI and future
workflows compose this skill; it does **not** own DR phase state or consolidation.

## Host matrix (v1)

| Host | Status |
|------|--------|
| Cursor | **supported** |
| Claude Code | packaged-fail-closed (`SB_MULTI_AI_UNSUPPORTED_HOST`) |
| Codex | packaged-fail-closed (`SB_MULTI_AI_UNSUPPORTED_HOST`) |

Fail-closed hosts must error **before** preferences, caches, provisioning, writes, or dispatch.

## CLI contract

Plan a run first with `--dry-run` (no workers start, nothing is written):

```bash
python3 skills/silver-multi-ai-task/scripts/multi_ai_cli.py \
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
| `--cursor-pool none\|default` | `default` | Cursor-side pool |
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
- Cursor runs without `--force`/`--yolo`; OpenCode runs without `--auto`. Codex runs directly
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
4. `FS-MULTI-AI-DISPATCH` — adapter launch (Cursor / delegates / OCG)
5. `FS-MULTI-AI-RECONCILE` — ledger entries, authoritative attempt per agent
6. `FS-MULTI-AI-INDEX` — stable `multi-ai-result-index-v1`

## References

- [`reference/model-family-registry-v1.json`](reference/model-family-registry-v1.json)
- [`reference/host-matrix-v1.json`](reference/host-matrix-v1.json)
- [`schemas/`](schemas/)

## Composition

`/sb:deep-research-multi-ai` forwards neutral options only. No DR concepts leak into this skill.
