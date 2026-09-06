# Need-profile interview — solution decisions

Mandatory **before DR-RETRIEVE** for `solution-landscape` and `solution-compare`.
Use `silver-clarify` discipline: one question at a time, multiple choice preferred.

## Question bank

1. **Decision goal** — What decision will this research unlock? (pick or describe)
2. **Audience** — Who consumes the output? (CTO, procurement, engineering lead, …)
3. **Category** — Primary solution category to evaluate
4. **Category pack** — Which market contract applies? (required for landscape/compare)
   - `agentic-sdlc-process-orchestrator` — Agentic SDLC process orchestrators above coding agents
   - *(future packs under `reference/landscape/category-packs/`)*
5. **Adjacent categories** — Related markets to scan (landscape only); pack `adjacent_seeds` are defaults
6. **Must-haves** — Non-negotiable **capabilities** (multi-select)
7. **Must-research** — Named products that must appear in core coverage (merge with pack seeds)
8. **Nice-to-haves** — Valuable but not blocking
9. **Constraints** — Vendor lock-in, budget, compliance, hosting
10. **License preference** — `oss` | `commercial` | `mixed`
11. **Success criteria** — How will you know the research succeeded?
12. **Hard vetoes** — Solutions or vendors to exclude (merged with pack `hard_exclusions`)
13. **Adjacent section** — Include Adjacent Markets section? (default yes → `allow_adjacent_section: true`)
14. **Compare: solution list** — Confirm exact names (and URLs/repos if known)
15. **Compare: ambiguity** — Allow substitutes if a name is ambiguous? (yes/no)

## Category pack defaults

When `category_pack_id` is set, the engine loads `reference/landscape/category-packs/{id}.json`:

| Pack field | need_profile override |
|------------|----------------------|
| `inclusion_criteria` | Optional tighten via `inclusion_criteria` |
| `exclusion_classes` | Optional tighten via `exclusion_classes` |
| `core_seeds` (must_research) | Merged with `must_research` |
| `hard_exclusions` | Merged with `hard_vetoes` |
| `adjacent_seeds` | Controlled by `allow_adjacent_section` |

Interviewers should confirm the pack matches the buyer's market definition before retrieve.

## Persistence

Write `need_profile.json` with:

- `"interview_complete": true`
- Valid `license_preference`
- **`category_pack_id`** for `solution-landscape` and `solution-compare`
- Optional `persona_id`: `startup` | `enterprise` | `regulated`
  (see `reference/need-profile-personas.json` for weighted matrix defaults)

For `--auto`, set `"auto_assumed": true` and document defaults —
never invent must-haves or must-research silently.

## Gate

`phase_gate.py` blocks `DR-RETRIEVE` until:

1. `interview_complete` is true
2. `license_preference` is set
3. For solution types: resolvable `category_pack_id` with non-empty inclusion criteria
