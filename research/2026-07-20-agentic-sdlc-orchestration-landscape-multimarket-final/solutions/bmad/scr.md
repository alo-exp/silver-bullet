# Solution Capability Report: bmad

Slug: `bmad`

## Executive summary

BMAD-METHOD is MIT-licensed, bring-your-own-model, and had approached ~49k GitHub stars — the highest-distribution OSS substitute in the secondary market.

## Evidence-backed notes

- BMAD-METHOD is MIT-licensed, bring-your-own-model, and had approached ~49k GitHub stars — the highest-distribution OSS substitute in the secondary market.
- BMAD structures delivery around 12–21 specialist agent personas (Analyst, PM, Architect, Scrum Master, Dev, QA/Test Architect, UX) with explicit deliverables and structured handoffs — strong specialist agent orchestration score.
- BMAD's two-phase model (agentic planning, then context-engineered implementation) produces complete specs before code, spanning plan→build→test — satisfies multi-phase lifecycle coverage.
- BMAD installs into Claude Code and Cursor via a single command (npx bmad-method install), meeting plugin/skill/hook packaging.
- BMAD's enforcement is prompt/persona-level rather than hook-level; no machine-checkable stop-gate is documented, so it scores lower than Silver Bullet on deterministic quality gates.
- The secondary market splits cleanly on enforcement mechanism: Silver Bullet and microsoft/conductor use machine-checkable blocking gates, while BMAD, Spec Kit, Superpowers and Ruflo rely on prompt-, artifact-, or persona-level discipline that an agent can in principle skip.
- BMAD-METHOD is a methodology pack (analyst/PM/architect/dev/QA roles) packaged as host skills; passes multi-phase lifecycle coverage, specialist agent orchestration, plugin/skill/hook packaging. Functions as formidable SB substitute even if not self-labeled APO.
- Oh My Pi (OMP) is a host-integrated plugin pack; satisfies plugin/skill/hook packaging + process layer above host runtime. Lifecycle coverage narrower than BMAD/Superpowers.
- APO secondary market (SDLC plugins) is formidable substitutes territory: BMAD, GSD, Superpowers, Spec Kit, SuperClaude, Ruflo, OMP, Zuvo collectively cover plan→spec→build→test→review→ship with varying gate depth. Solution cards must include them, not demote to Adjacent.
