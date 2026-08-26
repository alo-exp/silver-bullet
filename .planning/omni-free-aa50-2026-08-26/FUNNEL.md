# Omni free × AA Intelligence ≥ 50 funnel — 2026-08-26

Catalog report only. Not a Pi allowlist change. Intelligence Index scores are from [Artificial Analysis](https://artificialanalysis.ai/) (v4.1.1).

## Counts

| Step | Count |
|---|---|
| PROVIDER_REFERENCE providers | **353** |
| Recurring $0 / `:free` / `-free` / `contributor-free` kept (ingest-omni) | **152** models / **27** providers |
| Unique AA match with numeric Intelligence Index | **62** |
| Intelligence Index **≥ 50** (inclusive) | **8** models / **3** providers |

Join exclusions from the 152 (not kept):

| Reason | Count |
|---|---|
| 0 AA matches | 70 |
| Ambiguous (multiple AA slugs/names/prefixes) | 20 |
| Unique match, null Intelligence Index (unscored) | 0 |
| Unique match, score &lt; 50 | 54 |

## Live Omni extras

Ingest added 4 live `/v1/models` ids that were not in the budget tables:

| Omni slug | Join result |
|---|---|
| `opencode-zen/minimax-m2.5-free` | unique AA match `minimax-m2-5` **34.47** — below 50, dropped |
| `opencode-zen/qwen3.6-plus-free` | unique AA match `qwen3-6-plus` **40.49** — below 50, dropped |
| `opencode-go/ox-alpha-free` | 0 AA matches — excluded |
| `opencode-zen/muse-spark-1.2-contributor-free` | unique AA match `muse-spark-1-2` **56.76** — **kept** |

## AA source

- Index version: **v4.1.1**
- Snapshot: [\_ingest_aa.json](_ingest_aa.json) (`snapshot_time` 2026-08-25T15:07:41Z)
- Extraction: public leaderboard HTML (`source: browser`); unauthenticated `GET /api/v2/data/llms/models` returned 401
- Rows: 618 models (605 numeric Intelligence Index, 13 null)
- Advertised set size: 618

## Omni ingest (unchanged; not re-run)

- Runtime Omni 3.8.49; PROVIDER_REFERENCE 3.8.51 (353 providers)
- 152 kept free models already in [\_ingest_omni.json](_ingest_omni.json)
- Live extras included in that 152, as above

Ingest notes (not join failures): cloudflare-playground has no registry fill; local Omni 3.8.49 vs PROVIDER_REFERENCE 3.8.51; GitHub budgets newer than local catalog (unioned); theoldllm skipped as tos-avoid; subscription no-auth hosts excluded; mimocode no-auth table mismatch.

## Attribution

Data from [Artificial Analysis](https://artificialanalysis.ai/).
