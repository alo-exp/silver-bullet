# Category market packs

Pluggable **category market contracts** for `solution-landscape` and `solution-compare` research. Each pack replaces ad-hoc scope text and hardcoded product catalogs with analyst-grade inclusion rules, seeds, exclusions, and synthesis bounds.

## When packs apply

| Research type | Pack required? | Gate |
|---------------|----------------|------|
| `solution-landscape` | Yes | `phase_gate.py` fails closed without resolvable `category_pack_id` |
| `solution-compare` | Yes | Same |
| `default` | No | Pack fields ignored |

## Selecting a pack

1. **Interview** (`reference/need-profile-interview.md`) — confirm category and set `category_pack_id`.
2. **Auto / live demos** — `dr_live_runner.write_need_profile()` loads defaults from the APO pack when the category matches agentic SDLC orchestration.
3. **Runtime** — `category_pack.resolve_pack_from_need_profile(need_profile)` returns the merged contract (pack defaults + profile overrides).

Pack files live here: `category-packs/{category_pack_id}.json`.

## Pack anatomy

| Field | Purpose |
|-------|---------|
| `definition` / `jobs_to_be_done` | Market definition injected into retrieve/consolidate prompts |
| `inclusion_criteria` | Scorecard rule (e.g. ≥3 of 7) — classifier uses per-candidate pass/fail |
| `exclusion_classes` / `adjacent_classes` | Taxonomy for excluded vs adjacent-only coverage |
| `core_seeds` | Must-research in-scope comps (Top-N, MQ, Wave, matrix) |
| `adjacent_seeds` | Allowed only in **Adjacent Markets** section |
| `hard_exclusions` | Named products never in core charts or matrix |
| `product_aliases` / `parent_child_dedupe` | Canonical slug resolution |
| `sunset_registry` | Discontinued products — always excluded |
| `feature_axes` | Value-curve / KCF dimensions for this category |
| `min_core_count` / `max_core_count` | Bounds replacing rigid “20 commercial + 20 OSS” padding |

## Authoring a new pack

1. Copy `schema.json` constraints — validate with `test_category_pack.py` patterns.
2. Name file `{category_id}.json` where `category_id` matches the `category_id` field.
3. Lock **core_seeds** from prior analyst reports or stakeholder interviews — not from model suggestions.
4. List **hard_exclusions** explicitly (coding agents, PM tools, sunset products).
5. Set realistic `min_core_count` / `max_core_count` for the market size.
6. Document provenance in `notes`.

## Overrides from need_profile

`need_profile.json` may tighten (not loosen) market scope:

- `inclusion_criteria` — replace pack criteria list (must remain non-empty)
- `exclusion_classes` — append or replace exclusion class ids
- `must_research` — merge with pack `core_seeds` where `must_research: true`
- `hard_vetoes` — user-level slugs always excluded
- `allow_adjacent_section` — default `true`; set `false` to omit adjacent coverage

## Downstream consumers (Phase 2+)

| Module | Uses pack for |
|--------|----------------|
| `category_pack.py` | Load, resolve, expose seeds/exclusions/aliases |
| `solution_classifier.py` | core / adjacent / excluded / sunset classification |
| `synthesize_landscape.py` | Pack-driven Sections 5–6, charts, matrix |
| `validate_landscape_content.py` | Forbidden membership, must-research gaps |
| Prompt templates | Injected `[CATEGORY_PACK]` block at retrieve time |

## First pack

[`agentic-sdlc-process-orchestrator.json`](agentic-sdlc-process-orchestrator.json) — Agentic SDLC Process Orchestrators, seeded from the May 2026 Silver Bullet comparable-plugin prior report.
