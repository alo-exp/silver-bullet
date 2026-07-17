# Need-profile interview — solution decisions

Mandatory **before DR-RETRIEVE** for `solution-landscape` and `solution-compare`.
Use `silver-clarify` discipline: one question at a time, multiple choice preferred.

## Question bank

1. **Decision goal** — What decision will this research unlock? (pick or describe)
2. **Audience** — Who consumes the output? (CTO, procurement, engineering lead, …)
3. **Category** — Primary solution category to evaluate
4. **Adjacent categories** — Related markets to scan (landscape only)
5. **Must-haves** — Non-negotiable capabilities (multi-select)
6. **Nice-to-haves** — Valuable but not blocking
7. **Constraints** — Vendor lock-in, budget, compliance, hosting
8. **License preference** — `oss` | `commercial` | `mixed`
9. **Success criteria** — How will you know the research succeeded?
10. **Hard vetoes** — Solutions or vendors to exclude
11. **Compare: solution list** — Confirm exact names (and URLs/repos if known)
12. **Compare: ambiguity** — Allow substitutes if a name is ambiguous? (yes/no)

## Persistence

Write `need_profile.json` with `"interview_complete": true` and valid
`license_preference`. Optional `persona_id`: `startup` | `enterprise` | `regulated`
(see `reference/need-profile-personas.json` for weighted matrix defaults).
For `--auto`, set `"auto_assumed": true` and document defaults —
never invent must-haves silently.

## Gate

`phase_gate.py` blocks `DR-RETRIEVE` until `interview_complete` is true for solution types.

