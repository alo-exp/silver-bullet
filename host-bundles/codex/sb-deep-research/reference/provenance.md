# SB Deep Research — Provenance Ledger

External ideas and artifacts adapted into `silver-deep-research` v2. Every adopted
item must appear here **before** the milestone that ships it is accepted.

## Legend

| Field | Meaning |
|-------|---------|
| **Copied** | Substantial text/code reused (license reviewed) |
| **Idea-derived** | Pattern or structure adapted; SB-authored implementation |
| **SB-original** | No external source |

## Milestone 1 — Core Contract

| Artifact | Source | License | Type | SB adaptation |
|----------|--------|---------|------|---------------|
| `phases.yaml` / `phases.json` | Socialpranker/claude-deep-research `phases.yaml` + SB SKILL nested V-loop table | MIT (upstream SB absorption) | Idea-derived | 9-phase DR-* ids, mode budgets, V-loop gates |
| `scripts/phase_gate.py` | lingzhi227 deep-research file-gate pattern | Unknown — idea only | Idea-derived | JSONL + markdown artifact checks per phase |
| Admiralty grading in `source_evaluator.py` | hashbulla/deep-research NATO source grading | Unknown — idea only | Idea-derived | A1–F6 codes, authority_tier, bias_flags |
| `reference/source-grading.md` | hashbulla/deep-research + NATO Admiralty Code | Public domain concept | Idea-derived | Escalation rules for SB evidence gates |

## Milestone 2 — Retrieval

| Artifact | Source | License | Type | SB adaptation |
|----------|--------|---------|------|---------------|
| `reference/search-orchestration.md` | blessonism/openclaw-search-skills | Unknown — idea only | Idea-derived | Intent route, fan-out, relevance_gate |
| `reference/catalogs/*.yaml` + `.json` | Socialpranker channel catalog + blessonism intent classes | Idea-derived | Curated subset, JSON fallback |
| `scripts/search_orchestrator.py` | blessonism + hoolulu layered retrieval | Idea-derived | SB-owned, no TopGun |
| `scripts/chain_tracker.py` | blessonism openclaw chain_tracker | Idea-derived | Simplified reference-following |
| `skill_portals.yaml` | skills.sh API (`GET /api/search?q=`), GitHub search | Public APIs | Idea-derived | Landscape-only portal descriptors |
| `domain-source-matrices/*` | Weizhena web-search-modules + daizedong/market-intel | Idea-derived | Starter matrices only |

## Milestone 3 — Reporting

| Artifact | Source | License | Type | SB adaptation |
|----------|--------|---------|------|---------------|
| `report_profiles.yaml` | hoolulu `lang_config.py` pattern | Idea-derived | en/zh production first |
| `reference/report-blocks/*` | Socialpranker block library (~30 of 103) | Idea-derived | Curated blocks, SB paths |
| `reference/prompts/*` | hoolulu chapter-agent prompts | Idea-derived | `.planning/research/` artifact paths |
| `validate_report.py` extensions | hoolulu `dr_check` | Idea-derived | TOC, tail, forecast wording, en/zh |
| `adversarial-review.md` | Socialpranker `adversarial_pass.md` | Idea-derived | Multi-angle critique protocol |
| `refresh-protocol.md` | Socialpranker `refresh_targets.md` | Idea-derived | Entity/number re-verify list |
| `human-checkpoints.md` | Weizhena checkpoint prompts | Idea-derived | Narrow pause conditions only |

## Milestone 4 — Eval

| Artifact | Source | License | Type | SB adaptation |
|----------|--------|---------|------|---------------|
| `eval/rubric.md` | Socialpranker eval rubric | Idea-derived | 11 SB capability dimensions |
| `eval/score_capability.py` | Socialpranker `score_run.py` | Idea-derived | No popularity/install signals |
| `scripts/capability_score.py` | SB ranking run rubric | SB-original | External SKILL.md scoring |

## Explicit non-dependencies

- **TopGun** / `.agents/skills/find-skills/adapters/` — never used
- **MultiAI** / FS-SILVER_MULTI_AI — removed
- Socialpranker full 103 blocks / 460 stat sources — not copied
