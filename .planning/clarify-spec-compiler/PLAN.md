# PLAN — Clarify/Spec compiler factoring

Skill factoring only. Do not invent `/sb:fusion`.

## KEEP

- Ingest as MCP dump → SPEC ± DESIGN + `INGESTION_MANIFEST.md`
- Light FLOW 3 on clarify default (research / content / new-workflow / decide-compare)
- Need-profile interview on AF-DECIDE paths only
- Spec version bump / augment detection
- Conditional DESIGN.md + review-design
- review-spec / review-requirements after compile
- REQUIREMENTS.md derived from **SPEC AC**, not from the brief
- Timestamped `.planning/{plan-basename}-CLARIFY-*.md` path helper
- Chain-guard: feature/UI without SPEC.md still requires `silver-spec` marker
- Root v0.35 SPEC and `.planning/rfl-plan-review-prompt/` untouched

## REJECT

- Spec running Turns 1–9 or a min-4 live turn-counter
- Clarify `next=spec` writing SPEC.md / REQUIREMENTS.md
- Light clarify attaching the 9 spec turns
- Ingest writing REQUIREMENTS.md
- Ingest next-step “run `/silver:spec` to Socratic refine”
- Folding ingest into spec
- A second 9-turn tour in spec after a complete brief
- `/sb:fusion` or a new top-level skill

## Waves

### Wave 0 — Plan artifacts (this directory)

- [CONTEXT.md](CONTEXT.md) (locked Ds)
- This PLAN

### Wave 1 — Clarify skill (`skills/silver-clarify/SKILL.md`)

- Document `--spec` and `--next spec` / `--next=spec`
- Auto-detect `next=spec` when:
  - `.planning/INGESTION_MANIFEST.md` exists, or
  - composition is heading to AF-SPECIFY, or
  - user asked for a spec
- `next=spec`: own Step 1 context + Turns 1–9 + assumption protocol; write **only** the timestamped brief with the capture schema
- Default: keep light FLOW 3; explicit “do not attach 9 spec turns”
- Second pass: skip Frame if already converged; fill remaining spec domains
- Need-profile remains DECIDE-only

### Wave 2 — Spec skill (`skills/silver-spec/SKILL.md`)

- Rebrand: compiler, not elicitation
- Step 0: discover newest `*-CLARIFY-*.md` + ingest SPEC draft
- If no brief and no ingest draft: stop and route to `/silver:clarify --spec`
- Compile; gap-fill **only** empty required SPEC sections
- Kill min-4 live turn-counter; brief-domain completeness (problem, scope, stories, AC)
- Write SPEC.md then REQUIREMENTS.md from SPEC AC
- Keep reviews, DESIGN conditional, commit, summary

### Wave 3 — Ingest skill (`skills/silver-ingest/SKILL.md`)

- Next-step copy: `/silver:clarify` (`next=spec`) then `/silver:spec`
- Do not mention Socratic refine as the next step
- Still do not write REQUIREMENTS.md

### Wave 4 — Workers, live instructions, help

- `templates/orchestrator-workers/SPECIFY.md` and `CLARIFY.md` (then `sync-templates.sh`)
- `silver-bullet.md` Spec Lifecycle + review-loop table row “Spec elicitation” → compile
- `templates/silver-bullet.md.base` parity
- Help: `site/help/workflows/silver-spec.html`, `silver-clarify.html`, `silver-ingest.html`
- Catalog/search copy if it still claims Socratic-in-spec

### Wave 5 — Tests

- New `tests/scripts/test-clarify-spec-compiler.sh` (skill-text contract):
  - spec does not require 9 live turns / min-4 counter when brief is complete
  - spec reads newest clarify brief
  - ingest next-step copy
  - clarify `next=spec` capture vs light mode
- Update `tests/skill-scenarios/silver-{spec,clarify,ingest}.md`
- Chain-guard: no behavior change; targeted test still covers spec marker

### Wave 6 — Sync + verify

- Copy-back PathJail-denied `skills/` from `_work/`
- `bash scripts/sync-codex-package.sh`
- `bash scripts/sync-templates.sh` if workers changed
- Targeted tests (not full `run-all-tests.sh`)
- `graphify update .` + agentmemory save

## Acceptance

1. Clarify `--spec` / `--next spec` interviews and writes only `*-CLARIFY-*.md` with review-spec-satisfying capture fields.
2. Clarify default does not include Turns 1–9.
3. Spec compiles from newest brief (+ ingest draft); no min-4 live counter; gap-fill only for empty required sections.
4. REQUIREMENTS.md derived from SPEC AC.
5. Ingest next step is clarify `next=spec` then spec.
6. Help + Spec Lifecycle no longer claim spec does Socratic elicitation.
7. Targeted tests PASS.
8. No commit, no branch switch, no freeze YAML.

## Files (implementation target)

| Path | Change |
|------|--------|
| `skills/silver-clarify/SKILL.md` | next=spec vs light |
| `skills/silver-spec/SKILL.md` | compiler |
| `skills/silver-ingest/SKILL.md` | next-step copy |
| `templates/orchestrator-workers/{SPECIFY,CLARIFY}.md` | compiler / interview |
| `silver-bullet.md` + `templates/silver-bullet.md.base` | Spec Lifecycle |
| `site/help/workflows/silver-{spec,clarify,ingest}.html` | copy |
| `tests/scripts/test-clarify-spec-compiler.sh` | new |
| `tests/skill-scenarios/silver-{spec,clarify,ingest}.md` | scenarios |
