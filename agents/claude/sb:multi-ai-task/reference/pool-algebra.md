# Pool selection algebra (`multi-ai-task-v2`)

## Pool dimensions

| Dimension | Values | Mutex |
|-----------|--------|-------|
| OCG pool | `none`, `lite`, `regular` | one value per run (`--ocg-pool` takes a single choice) |
| Cursor pool | `none`, `default` | — |

## Resolution order

1. Expand pools to canonical logical IDs.
2. If `--include-only` is present, replace the candidate set.
3. Normalise aliases to canonical IDs; a canonical ID and its alias count once (first
   occurrence wins).
4. Apply `--exclude` (exclusion wins over inclusion).
5. Run subscription routing for surviving `glm-5.2` slots.
6. Reject an empty set and unknown IDs.

## Default dry-run (11 slots)

- OCG: `lite` → the five `ocg_lite_pool` profiles in `model-family-registry-v1.json`
- Cursor: `default` → the six `cursor_default_pool` logical slots

## GLM-5.2 routing

| Subscription | `glm-5.2` backend |
|--------------|-------------------|
| `subscribed` | Cursor pool only |
| `unsubscribed` | OCG pool (`ocg-glm-5.2`) |
| `unknown` | Block dispatch; offer declare / exclude / abort |

## Budget defaults

| Field | Default | Enforced in v1 |
|-------|---------|----------------|
| `max_agents` | 11 | Yes — before any worker starts (`--max-agents`) |
| `concurrency` | 6 | Yes — parallel worker bound (`--concurrency`) |
| `max_cost_usd` | 25.00 | Recorded only; the CLIs report no usage |
| `max_total_tokens` | 2000000 | Recorded only; the CLIs report no usage |

v1 reads budget values from CLI flags only; preferences files are not consulted.

`max_agents` counts unique resolved logical IDs once per run (phase repetitions and retries do not increment).
