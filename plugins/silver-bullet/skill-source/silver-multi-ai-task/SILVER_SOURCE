---
name: "silver:multi-ai-task"
title: "Multi AI Task"
description: >
  Reusable SB multi-model orchestration primitive (multi-ai-task-v2 spine). Parallel workers,
  pool algebra, manifests, dispatch ledger, cost caps, and result index. Cursor host only in v1.
argument-hint: "<task brief> --output-root <dir> [--ocg-pool none|lite|regular] [--cursor-pool none|default] [--dry-run]"
version: 1.0.0
user-invocable: false
---

# /silver:multi-ai-task — Multi-Model Task Primitive

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

```bash
python3 skills/silver-multi-ai-task/scripts/multi_ai_cli.py \
  --task-brief task.json \
  --input-schema schemas/task-input-v1.schema.json \
  --output-schema schemas/task-output-v1.schema.json \
  --output-root .planning/multi-ai/<run-id>/ \
  --ocg-pool lite \
  --cursor-pool default \
  --dry-run
```

### Pool algebra

See [`reference/pool-algebra.md`](reference/pool-algebra.md). Valid pools:
`{none,lite,regular} × {none,default}`. Resolution order:
expand pools → `--include-only` (replace) → `--exclude` → GLM subscription routing.

### Budget defaults

USD 25.00 · 2,000,000 tokens · 11 unique logical agents · concurrency 6.
Precedence: CLI > project `.silver-bullet/preferences.json` > global preferences > defaults.

### Does **not** accept

- `--mode`
- `--research-type`
- DR `phase_id` (neutral work-item manifests only)

## Artifacts (under `--output-root`)

| File | Schema |
|------|--------|
| `work-item-manifest.json` | `multi-ai-work-item-manifest-v1` |
| `dispatch-ledger.json` | `multi-ai-dispatch-ledger-v1` |
| `result-index.json` | `multi-ai-result-index-v1` |
| `run-snapshot.json` | host/capability provenance |

## Implementation steps (`AF-MULTI-AI-TASK`)

1. `FS-MULTI-AI-RESOLVE` — pool expand, alias normalize, subscription route
2. `FS-MULTI-AI-CAPABILITY-PROBE` — backend capability spike / cache
3. `FS-MULTI-AI-RESERVE` — identity reservation + budget reserve
4. `FS-MULTI-AI-DISPATCH` — adapter launch (Cursor / OCG)
5. `FS-MULTI-AI-RECONCILE` — usage reconcile, CAS authoritative attempt
6. `FS-MULTI-AI-INDEX` — stable `multi-ai-result-index-v1`

## References

- [`reference/model-family-registry-v1.json`](reference/model-family-registry-v1.json)
- [`reference/host-matrix-v1.json`](reference/host-matrix-v1.json)
- [`schemas/`](schemas/)

## Composition

`/silver:deep-research-multi-ai` forwards neutral options only. No DR concepts leak into this skill.
