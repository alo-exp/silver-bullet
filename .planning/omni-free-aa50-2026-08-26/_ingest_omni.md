# Omni free-model ingest funnel — 2026-08-26

Ingest-only snapshot (`ingest-omni`). No Artificial Analysis scores. No `MODELS.md` / `FUNNEL.md` / `models.json` finals.

**Runtime Omni:** 3.8.49 at `http://127.0.0.1:20128`  
**PROVIDER_REFERENCE:** 3.8.51 (generated 2026-08-25) — **353** providers  
**Budgets:** local `FREE_CATALOG_CURATED_AT=2026-07-22` (523 rows / 81 providers) union GitHub HEAD `2026-08-20` (456 rows / 79 providers) → **534 merged rows / 82 providers**

## Funnel

| Step | Count |
|---|---|
| PROVIDER_REFERENCE providers | **353** |
| Local FREE_MODEL_BUDGETS rows | 523 |
| GitHub FREE_MODEL_BUDGETS rows (newer) | 456 |
| Merged unique budget rows | **534** |
| Unique budget providers | **82** |
| Drop one-time | 114 |
| Drop discontinued | 7 |
| Drop tos-avoid (budget) | 85 |
| Drop paid-API complimentary tier | 177 |
| Drop not-$0 (`recurring-credit` without `:free`/`-free`) | 5 |
| Drop subscription (budget) | 0 |
| Drop video (budget) | 0 |
| **Kept from budgets** | **146** |
| Registry no-auth fills (`chipotle/pepper-1`, `mimocode/mimo-auto`) | +2 |
| Live `/v1/models` ids with `:free` / `-free` / `contributor-free` | 15 seen |
| Live extras added | **+4** |
| Live extras dropped | subscription 2, tos-avoid (`oc/*`) 5, video (`veo-free/*`) 2, already-kept 2 |
| **Kept total** | **152** |
| Unique kept providers | **27** |

## Keep rules applied

- Keep `recurring-uncapped`.
- Keep `keyless` unless `tos: avoid`.
- Keep `recurring-daily` / `recurring-monthly` only if model id is `:free` / `-free` / `contributor-free` **or** provider is no-auth / keyless-public.
- Drop one-time, discontinued, paid-API free tiers (Gemini / Groq / Mistral Experiment and similar complimentary billed quotas), `tos: avoid` wrappers (e.g. `agy`), video-only (`veoaifree-web`), subscription hosts (Cursor / Claude / Codex / Auggie / `auto` combos).
- ToS `caution` / `ok` / `ambiguous` / `unknown` retained.

## Live Omni extras added

- `opencode-zen/minimax-m2.5-free`
- `opencode-zen/qwen3.6-plus-free`
- `opencode-go/ox-alpha-free`
- `opencode-zen/muse-spark-1.2-contributor-free`

Machine-readable copy: [`_ingest_omni.json`](_ingest_omni.json)
