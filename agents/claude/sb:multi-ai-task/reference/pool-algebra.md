# Pool selection algebra (`multi-ai-task-v2`)

## Pool dimensions

| Dimension | Values | Mutex |
|-----------|--------|-------|
| OCG pool | `none`, `lite`, `regular` | `lite` and `regular` are mutually exclusive |
| Cursor pool | `none`, `default` | — |

## Resolution order

1. Validate pool mutex (`regular` + `lite` → reject).
2. Expand pools to canonical logical IDs.
3. If `--include-only` is present, replace the candidate set.
4. Apply `--exclude` (exclusion wins over inclusion).
5. Run subscription routing for surviving `glm-5.2` slots.
6. Reject empty set, unknown IDs, and canonical+alias duplicates.

## Default dry-run (11 slots)

- OCG: `lite` → `ocg-mimo-v2.5`
- Cursor: `default` → six logical slots from `model-family-registry-v1.json`

## GLM-5.2 routing

| Subscription | `glm-5.2` backend |
|--------------|-------------------|
| `subscribed` | Cursor pool only |
| `unsubscribed` | OCG pool (`ocg-glm-5.2`) |
| `unknown` | Block dispatch; offer declare / exclude / abort |

## Budget defaults

| Field | Default | Precedence |
|-------|---------|------------|
| `max_cost_usd` | 25.00 | CLI > project > global > default |
| `max_total_tokens` | 2000000 | same |
| `max_agents` | 11 | same |
| `concurrency` | 6 | same |

`max_agents` counts unique resolved logical IDs once per run (phase repetitions and retries do not increment).
