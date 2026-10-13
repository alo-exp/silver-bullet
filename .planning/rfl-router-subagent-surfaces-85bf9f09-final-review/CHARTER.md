# Review charter — freeze final RFL

**Skill:** `/silver:review-fix-ladder` only. Not `/silver:clarify`.

## Scope

- `.planning/router_subagent_surfaces_85bf9f09.plan.md`
- `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`

Byte-identical freeze. Starting SHA `07b986094e983d39fe3c7d2f1ac215ae730cbd28ccf3957655f5ec4c53d3280a` / 620985 bytes.

## Goals

1. Freeze is internally consistent, complete, and reviewable as a ship spec.
2. Closed locks stay closed: KEEP REJECT, Q1–Q3, Part A then Part B, no `/sb:multi-ai-task`, no `sb:agent-wrap` (not even as an alias), FAST is not a Job / not a legal compose `<route>`, OmniRoute routing-only / origin SHA `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26`.
3. YAML: exactly 33 todos, all `status: pending`. Do not mark product work done.
4. Broken refs, truncated headings, TOC/GFM integrity, producer locks (LS-post-val-kl Executor; FAST short-order E→Ver→Val + thin capture), single Process quality-order mermaid.
5. Editorial / consistency / missing-lock / completeness findings that are not wrong get owner-applied.

## Non-goals

- Product implementation or executing YAML todos
- Git checkout/switch/commit
- Clarify encode, AskQuestion forks, `clarifications.md` as a clarify product
- Reopening KEEP REJECT / Q1–Q3 / Part A–B inversion
- Remapping any family to Grok

## Verification signals (orchestrator)

1. `sha256` both copies identical
2. YAML frontmatter: 33 `- id:` and 33 `status: pending`
3. No live public `/sb:multi-ai-task` route (mentions are retire/forbid only)
4. No live `sb:agent-wrap` alias (mentions are forbid only)
5. FAST not a Job / `/sb:fast` not a legal `<route>`
6. Exactly one mermaid fence
7. KEEP REJECT / Q1–Q3 / Part A then Part B language still present as closed/decided
