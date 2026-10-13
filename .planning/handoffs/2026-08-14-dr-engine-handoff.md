# /silver:handoff — DR engine (fresh session on main)

Reusable handoff prompt for a **fresh session on `main`**. Task-detail mode included (user requested). Do **not** re-derive the locked multimarket report. Do **not** commit/push/release unless the user asks. Nested subagents: **Cursor Grok 4.6 High** (`cursor-grok-4.6-high`) only. Never Fast.

---

## Project Identity

- **Repo:** silver-bullet (`alo-exp/silver-bullet`)
- **Origin:** https://github.com/alo-exp/silver-bullet.git
- **Canonical start:** [`/Users/shafqat/projects/silver-bullet/repo`](/Users/shafqat/projects/silver-bullet/repo) on **`main`** at **`c055a3c8`** (`Fix DR landscape CI failures on script unit tests.`) matching `origin/main`
- **This worktree (abandoned for engine work):** [`/Users/shafqat/.cursor/worktrees/repo/3ht3`](/Users/shafqat/.cursor/worktrees/repo/3ht3) on `sync/3ht3-main` @ `c055a3c8`
- **Why 3ht3 exists / was abandoned:** git worktrees cannot check out `main` twice; primary already has `main`. 3ht3 therefore uses `sync/3ht3-main`. Prior session had a broken gitdir and a stale **v0.51.7** tree. Do **not** hack 3ht3 for the next slice — create a **feature branch from `c055a3c8` in the primary clone**.
- **Primary HEAD caveat (2026-08-14):** primary `main` was observed at `13a4f7b9` (`memory: auto-snapshot 2026-08-14T07:33:16Z`), **ahead 1** of `origin/main` (`c055a3c8`). Align to `c055a3c8` while staying on `main` (not a branch switch), then branch for engine work. Do not reset away untracked handoff files.
- **Plugin version on this SHA:** v0.52.0 (tags include `v0.52.0`, `v0.51.7`, …)
- **Working tree:** dirty with unrelated untracked junk (`.alumnium/logs`, `${SB_RUNTIME_HOME_ROOT}/`, research `_fix-*` dirs) — do not mix into engine commits

## Current Goal and Milestone

- Make Silver Bullet deep research **among the top-3 DR engines**: generalize APO landscape refinements into **engine + report generation**, then add a **shared search gateway**.
- Planning milestone marker still reads **v0.39.3 Zuvo Runtime Parity** (complete in [`.planning/STATE.md`](../STATE.md)); that is **not** the active work.
- Posture: **paused after locking the multimarket report + landing CI-green landscape unit-test fixes on `c055a3c8`**. Next slice is engine defaults + search MVP, not one-off HTML edits.

## Read First

1. [`research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/`](../../research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/) — locked run `run_id=run-57f38dfa25d83cc50d224e283d4692f3` (canonical view: `file://` HTML SPA)
2. [`research/2026-08-14-dr-must-search-channels/SEARCH-CHANNELS.md`](../../research/2026-08-14-dr-must-search-channels/SEARCH-CHANNELS.md) + [`SOCIAL-AND-GITLAB.md`](../../research/2026-08-14-dr-must-search-channels/SOCIAL-AND-GITLAB.md)
3. [`skills/silver-deep-research-multi-ai/`](../../skills/silver-deep-research-multi-ai/) — landscape engine (`synthesize_landscape.py`, `landscape_preview_render.py`, `landscape_critique_artifacts.py`, `landscape_independent_pdf.py`, `vendor_link_labels.py`)
4. [`skills/silver-deep-research/`](../../skills/silver-deep-research/) — search orchestrator + catalogs (`reference/catalogs/source_channels.json`, `scripts/search_orchestrator.py`)
5. [`README.md`](../../README.md) / [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) / [`docs/TESTING.md`](../../docs/TESTING.md)
6. [`docs/SEARCH-CLI.md`](../../docs/SEARCH-CLI.md) — existing `-p brave,serper` (do **not** invent `--providers` / `--no-fanout`)

## Constraints and Invariants

- Edit **`skills/`** then sync (`bash scripts/sync-codex-package.sh`, `bash scripts/sync-templates.sh`). Do not drift `agents/` / plugin mirrors alone.
- Graphify before codebase exploration; save via agentmemory, retrieve via Graphify.
- No silent git branch switches; no force-push to `main`; no plugin release unless the user asks; CI green before any later release.
- Do **not** re-derive run `run-57f38dfa25d83cc50d224e283d4692f3`. HTML+PDF from the same three files via `render_landscape_outputs()`.
- Ignore COI as a reason to demote Silver Bullet; still strip SB superlatives. Report voice must not call any vendor “most complete”.
- Subagents: `cursor-grok-4.6-high` only in this continuation (xhigh if the host accepts it). Never Fast.

## Verification and Release State

- **`origin/main`:** `c055a3c8` — CI green: https://github.com/alo-exp/silver-bullet/actions/runs/31777488690
- Locked landscape run: **`run_id=run-57f38dfa25d83cc50d224e283d4692f3`** (ultradeep; do not re-run).
- Latest tag: **v0.52.0**. No plugin release for this DR-engine slice.
- Full `tests/run-all-tests.sh` is **not** required for the next slice; run targeted landscape/DR script tests (see Task Details).

## Open Follow-ups

Only **STILL TODO** items are work. Landed items are “do not regress” (full audit in Task Details).

1. **Report-gen leftovers:** retarget `generate_landscape_report.py` (still shims `generate_spa_report.main`) to `render_landscape_outputs()`; `generate_spa_report.py` still lacks landscape hyperlink/PDF contracts.
2. **Analyst artifacts as engine-default tests:** keep `landscape_critique_artifacts.py` wired through `synthesize_landscape.py`; add/strengthen tests so a *new* run cannot omit exec summary / inclusion ledger / coverage matrix / consensus table.
3. **`features.json` rubric synthesis** (engine should synthesize, not stamp a canned 21-feature template).
4. **Search gateway MVP** (shared cache + one key ring + official JSON adapters). Catalog JSON is only partial; `must_search_channels.json` does not exist; `search_orchestrator.py` has no gateway.
5. **Resolve OCG Lite Kimi id:** tests on `c055a3c8` assert `ocg-kimi-k2.7-code`; registry still lists `ocg-kimi-k2.6`. Do not silently flip.
6. Paid X / LinkedIn later. Facebook stays **not** must-search.

## First 3 Actions for Next Session

1. In `/Users/shafqat/projects/silver-bullet/repo`, stay on **`main`**, align HEAD to **`c055a3c8`**, then **create a feature branch** for DR-engine work. Do not use 3ht3.
2. `graphify query "render_landscape_outputs landscape_critique_artifacts search gateway source_channels"` then implement remaining report-gen/analyst defaults + tests (order 1 below).
3. After that slice is green, start search-gateway MVP (SE + GH Discussions + HN Algolia + Discourse + GitLab + YouTube + Brave/Serper `site:` + query cache).

---

## Task Details (explicit)

### Why this worktree was abandoned

- Primary clone already has **`main`** checked out → this worktree is `sync/3ht3-main`.
- Prior gitdir was broken; tree was also **v0.51.7-stale**. Current 3ht3 gitdir pointer: `gitdir: /Users/shafqat/projects/silver-bullet/repo/.git/worktrees/3ht3` @ `c055a3c8`.
- Next session must **not** continue engine commits here.

### Locked landscape run (do not re-derive)

- Path: `research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/`
- `run_id=run-57f38dfa25d83cc50d224e283d4692f3`
- Canonical view: `file://` HTML SPA (no local HTTP server)
- HTML+PDF from `landscape/landscape-report.md` + `landscape/chart-data.json` + `comparison/comparison.json` via `render_landscape_outputs()` in [`skills/silver-deep-research-multi-ai/scripts/landscape_preview_render.py`](../../skills/silver-deep-research-multi-ai/scripts/landscape_preview_render.py)

### Suggested implementation order

1. Generalize remaining report-gen / analyst artifacts into **engine defaults + tests**
2. Search gateway MVP (SE + GH Discussions + HN Algolia + Discourse + GitLab + YouTube + Brave/Serper `site:` + cache)
3. Paid X / LinkedIn later

### Transferable items — already in engine (do not regress)

Audit date: 2026-08-14 against `skills/` on `c055a3c8`. Report-only HTML is **not** evidence the engine has it.

#### Report generation / SPA / PDF — mostly landed

| Item | Status | Pointers |
|------|--------|----------|
| One `render_landscape_outputs()` from md + chart-data + comparison.json | **already in engine** | `landscape_preview_render.py:997` |
| Never skip PDF except tests | **already in engine** | `_skip_landscape_pdf()` honors `SB_SKIP_LANDSCAPE_PDF` only under pytest / `SB_ALLOW_SKIP_LANDSCAPE_PDF` |
| Never `page.pdf` of SPA; sibling `landscape-report.pdf` | **already in engine** | `write_sibling_landscape_pdf()`; `landscape_independent_pdf.py` docstring |
| Create PDF = `window.open('landscape-report.pdf?v=' + Date.now())` | **already in engine** | `landscape_preview_render.py:867`; tests `test_pdf_export_opens_sibling_file_not_blob_or_print` |
| Independent PDF: Roboto Condensed ~300, full matrix not top-12 | **already in engine** | `landscape_independent_pdf.py` (`SPA_FONT_FAMILY`, `font-weight: 300`, `comparison_matrix_html` alias “full matrix, never a top-N summary”) |
| No visible `sb-independent-landscape-pdf` credit | **already in engine** | marker is an HTML assert constant; visible-credit stripped (do not put the string in PDF body text) |
| `file://` SPA; no local HTTP server | **already in engine** | `landscape_preview_render.py` module docstring |
| Links: hyperlinks, `target=_blank` + `noopener noreferrer`, no underlines | **already in engine** (preview path) | `landscape_preview_render.py` + `vendor_link_labels.py`; test `test_external_links_open_in_new_tab` |
| Card titles → homepages; 404 health; no invented URLs | **already in engine** | `vendor_link_labels.py` (`filter_healthy_vendor_urls`, `check_url_health`) |
| Section order Exec → 1 Problem → 2 Market → 3 Framework → 4 Findings → 5 Buying Guidance → 6 Future Outlook → 7 Source Reliability | **already in engine** | `synthesize_landscape.py` heading strings |
| HTML `#report-data` lockstep with `.md` | **already in engine** | `_inject_report_data()` in `landscape_preview_render.py` |

#### Analyst-grade artifacts — wired as synthesize defaults (do not regress)

| Item | Status | Pointers |
|------|--------|----------|
| 1-page Executive Summary (leader shortlist + buyer guidance) | **already in engine** | `landscape_critique_artifacts.executive_summary_lines` called from `synthesize_landscape.py:3224` |
| Vendor inclusion ledger C1–C7 P/F/U | **already in engine** | `inclusion_ledger_embed_lines`, `patch_inclusion_ledger` (`synthesize_landscape.py:30–31, 3187, 3302`) |
| Coverage completeness matrix + honest remediation | **already in engine** | `coverage_completeness_lines` (`synthesize_landscape.py:3305`) |
| Consensus Resolution Table with **Final analyst decision** | **already in engine** | `consensus_resolution_table_lines` (`landscape_critique_artifacts.py:579–585`, called `:3545`) |
| Notable divergences = inter-model only; Consensus Patterns envelope | **already in engine** | `select_notable_divergences`; `### Consensus Patterns` at `synthesize_landscape.py:3518` |
| Voice does not call any vendor “most complete”; feature-gate ≠ superlative | **already in engine** | methodology prose `synthesize_landscape.py:2975` |
| Multi-market membership documented; adjacent must not duplicate cores | **already in engine** | `adj_set = adjacent - core_set` (`synthesize_landscape.py:1994`) |
| Hard-excluded vendors out of comparison / MQ / Wave / seeds; envelope quotes labeled model-error | **already in engine** | `get_hard_exclusion_slugs` + `forbidden` filters; pack `hard_exclusions` includes `magic-dev`, `ateam`, … |
| Inclusion ledger matches charts/comparison.json | **already in engine** (logic) | `_load_inclusion_ledger_statuses` + membership filters — keep tests honest |

#### Scoring / charts — mostly landed

| Item | Status | Pointers |
|------|--------|----------|
| No `_slug_jitter` / `jitter_amp` | **already in engine** (absent) | neither symbol exists under `skills/silver-deep-research*` |
| Deterministic unique X **and** Y collision slotting | **already in engine** | `avoid_chart_coord_collisions`, `avoid_wave_coord_collisions`, `_enforce_axis_cap` |
| Interpretable rubric ticks × weights Critical=5…Low=1 | **already in engine** | methodology text `synthesize_landscape.py:2925–2928` |
| `_CHART_FEAT_EQUIV = {}` — Zero-infra ≠ Managed hosting | **already in engine** | `synthesize_landscape.py:335–336`; `test_realistic_chart_scoring.py` |
| `_wave_strategy_score()` weighted features + SCR | **already in engine** | `synthesize_landscape.py:639`, used at `:2128` |
| Per-market point sets; labels inside plot + clipPath | **already in engine** (PDF clipPath; per-market synthesize) | `landscape_independent_pdf.py:449`; synthesize per-market blocks — **do not put APO labels on plugins/SaaS charts** |
| Matrix = MultAI comparator not TopGun 55/20/15/10 | **already in engine** | `synthesize_landscape.py:2926` |

#### Do-not-regress membership / taxonomy

Pack: `skills/silver-deep-research/reference/landscape/category-packs/agentic-sdlc-process-orchestrator.json`

- Magic.dev **hard-exclude** as `coding_agent` (`magic-dev`)
- Zuvo **sdlc-plugins core** (not APO core)
- Conductor ≠ APO (SaaS adjacent)
- Claude Harness ≠ APO (plugins core)
- A.Team excluded (`ateam` in `hard_exclusions`)
- AgentHub adjacent/core per pack (do not silently recategorize)
- AI-DLC = AWS/awslabs, not IBM

### STILL TODO for the next session (only this is work)

#### Report generation leftovers

- **`generate_landscape_report.py` still shims `generate_spa_report.main`** (9-line wrapper). Canonical landscape path is `render_landscape_outputs()`. Retarget or delete the shim so a future run cannot emit the old SPA.
- **`generate_spa_report.py`** still lacks `target=_blank` / `noopener` / sibling-PDF button contracts. Either retire it for landscape or port contracts from `landscape_preview_render.py`.
- **Tests:** assert a fresh synthesize+render always emits exec summary, inclusion ledger, coverage matrix, consensus table, Consensus Patterns, sibling PDF, and `#report-data` byte-lockstep — not only that the locked APO HTML has them.
- **`features.json`:** engine **merges** per-solution `solutions/*/features.json` (`_merge_features_json_support`) but does **not synthesize** a run-level rubric. STILL TODO: synthesize the real rubric; do not stamp a canned 21-feature template when the run produced one.

#### Search / multi-AI (engine — largely TODO)

Research (not engine): [`research/2026-08-14-dr-must-search-channels/SEARCH-CHANNELS.md`](../../research/2026-08-14-dr-must-search-channels/SEARCH-CHANNELS.md), [`SOCIAL-AND-GITLAB.md`](../../research/2026-08-14-dr-must-search-channels/SOCIAL-AND-GITLAB.md).

| Item | Status | Notes |
|------|--------|-------|
| Shared search gateway (~10 concurrent agents): query cache, per-host buckets, **one key ring** | **STILL TODO** | `search_orchestrator.py` has no gateway/cache/Brave/Serper/SE/HN/GitLab/YouTube clients |
| search-cli stays opt-in; use existing `-p brave,serper` | **constraint** | Do **not** invent `--providers` / `--no-fanout` |
| Remaining CLI gap: `--cache-dir` + native SE/HN/Discourse providers | **STILL TODO** | Documented in SEARCH-CHANNELS.md only |
| Official JSON first: Stack Exchange, GitHub REST+GraphQL Discussions, HN Algolia, Discourse `/search.json`, package registries, GitLab `/api/v4/search`, YouTube Data API v3 `search.list` | **STILL TODO** (clients) | YouTube quota: **100/day at 1 unit each**, not old 100-units folklore |
| `site:` via Brave/Serper for Lobsters, InfoQ/talks, SourceHut, Hashnode, Indie Hackers, LinkedIn, X until paid X API | **STILL TODO** | |
| X: pay-per-usage v2 `search/recent` + `search/all` when credits exist | **STILL TODO** (later, order 3) | Catalog stub: `source_channels.json` `"x"` `mvp: false` |
| LinkedIn: no self-serve global post search; partner/CM or `site:` | **STILL TODO** (later) | Catalog stub `mvp: false` |
| Facebook: **exclude from must-search** | **cataloged, keep** | `source_channels.json` `"facebook": { "must_search": false, "provider": "sample_only" }` |
| Sample-only: Discord/Slack, G2/Peer Insights (ToS) | **STILL TODO** to encode in catalogs | |
| `must_search_channels.json` | **STILL TODO** | File **does not exist**. Partial overlap lives in `source_channels.json` v1.1.0 (`gitlab` official_api mvp, `youtube` official_api mvp, `linkedin`/`x` stubs, facebook not must-search). Still missing first-class SE / HN Algolia / Discourse / Reddit channels. gitlab.com is already primary in `code.domain_filter`. |
| Reddit OAuth or `site:reddit.com`; do not scrape old JSON | **STILL TODO** | Not in `source_channels.json` |
| Do not build Papers with Code client (HF redirect) | **constraint** | |

#### Host / model

- CI on `c055a3c8` asserts lite pool **`ocg-kimi-k2.7-code`** (`skills/silver-deep-research-multi-ai/tests/test_dr_live_pool_completeness.py:27`).
- Registry still maps **both** `ocg-kimi-k2.6` and `ocg-kimi-k2.7-code` (`skills/silver-multi-ai-task/reference/model-family-registry-v1.json`).
- Earlier product intent was OCG Lite Kimi **k2.6**. **Resolve which is canonical** — do not silently flip tests or the pool.

### Tests to run (targeted — not full release)

From repo root after engine edits:

```bash
python3 -m unittest skills.silver-deep-research-multi-ai.tests.test_landscape_report_builder
python3 -m unittest skills.silver-deep-research-multi-ai.tests.test_independent_landscape_pdf
python3 -m unittest skills.silver-deep-research-multi-ai.tests.test_realistic_chart_scoring
python3 -m unittest skills.silver-deep-research-multi-ai.tests.test_synthesis_membership
python3 -m unittest skills.silver-deep-research-multi-ai.tests.test_vendor_link_and_buckets
python3 -m unittest skills.silver-deep-research-multi-ai.tests.test_multi_market_landscape
python3 -m unittest skills.silver-deep-research-multi-ai.tests.test_validate_landscape_catalog_gates
python3 -m unittest skills.silver-deep-research-multi-ai.tests.test_dr_live_pool_completeness
python3 -m unittest skills.silver-deep-research.tests.test_search_orchestrator
bash tests/scripts/test-silver-deep-research-integration.sh
bash tests/scripts/test-multi-ai-deep-research-contract.sh
```

If unittest module paths fail, run the files via `PYTHONPATH=skills/silver-deep-research-multi-ai/scripts:skills/silver-deep-research/scripts python3 -m unittest discover -s skills/silver-deep-research-multi-ai/tests -v`. Do **not** run `bash tests/run-all-tests.sh` or `scripts/pre-release-gate.sh` unless cutting a release (user did not ask).

### Git / release

- Start: primary clone, `main` @ `c055a3c8`, then feature branch.
- No commit/push from the handoff authoring session.
- No plugin release unless the user asks. CI green before any later tag/`gh release`.
