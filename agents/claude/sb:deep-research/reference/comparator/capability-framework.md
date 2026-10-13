# Comparator capability framework (MultAI parity)

Ported from MultAI `comparator` skill — use for **solution-landscape** and **solution-compare**
matrix builds only. SB multi-AI engine supplies evidence via SCR `features.json` and envelopes;
do **not** use MultAI browser automation.

## Phase 0 — operation

| Operation | Trigger | Inputs |
|-----------|---------|--------|
| compare | head-to-head, which is better | Two+ solution names or SCR paths |
| build | new matrix for domain | Domain + solution list |
| add-platform | add X to matrix | CIR/context + matrix path |

## Phase 2 — capability framework (compare / build)

1. Identify **5–12 capability categories** for the domain
2. Per category, **3–10 differentiating features** (user-facing, observable)
3. Number categories: `1. Category Name`, `2. …`

## Tick judgment

| Symbol | Meaning |
|--------|---------|
| ✔ | Strong native support with evidence |
| ◐ | Partial / workaround / beta |
| — | Not supported or no evidence |

Evidence priority: SCR `features.json` → landscape narrative → envelope claims → inferred (label confidence).

## Scoring weights (SB `matrix_core`)

| Priority | Weight |
|----------|--------|
| Critical | 5 |
| Very High | 4 |
| High | 3 |
| Medium | 2 |
| Low | 1 |

`need_profile.json` `must_haves` map to **Critical**. Optional `persona_id` (`startup` | `enterprise` | `regulated`) boosts persona-aligned features.

## Outputs

- `comparison/comparison.json` — SPA + gates
- `comparison/comparison-matrix.md` — human-readable
- `comparison/comparison-matrix.xlsx` — MultAI-weighted COUNTIFS row

## Scripts

```bash
python3 skills/silver-deep-research/scripts/compare_solutions.py --dir "$SB_RESEARCH_OUT_DIR"
python3 skills/silver-deep-research/scripts/matrix_ops.py info --src comparison/comparison-matrix.xlsx
```
