---
phase: quick
plan: 260406-anb
subsystem: agents, website
tags: [model-routing, cost-optimization, agents, site]
key-files:
  modified:
    - site/index.html
  not-committed:
    - ~/.claude/agents/gsd-planner.md
    - ~/.claude/agents/gsd-verifier.md
    - ~/.claude/agents/gsd-security-auditor.md
    - ~/.claude/agents/gsd-ui-checker.md
    - ~/.claude/agents/gsd-assumptions-analyzer.md
    - ~/.claude/agents/gsd-integration-checker.md
    - ~/.claude/agents/gsd-executor.md
    - ~/.claude/agents/gsd-phase-researcher.md
    - ~/.claude/agents/gsd-doc-writer.md
    - ~/.claude/agents/gsd-doc-verifier.md
    - ~/.claude/agents/gsd-codebase-mapper.md
    - ~/.claude/agents/gsd-roadmapper.md
    - ~/.claude/agents/gsd-research-synthesizer.md
    - ~/.claude/agents/gsd-project-researcher.md
    - ~/.claude/agents/gsd-ui-researcher.md
    - ~/.claude/agents/gsd-user-profiler.md
    - ~/.claude/agents/gsd-nyquist-auditor.md
    - ~/.claude/agents/gsd-debugger.md
    - ~/.claude/agents/gsd-advisor-researcher.md
    - ~/.claude/agents/gsd-plan-checker.md
    - ~/.claude/skills/quality-gates/SKILL.md
decisions:
  - Opus for planning/verification/security/analysis agents (6 agents) to maximize reasoning depth
  - Sonnet for execution/research/documentation/testing agents (14 agents) for high-throughput efficiency
  - SKILL.md advisory added outside frontmatter, before main heading, for immediate visibility
  - Agent files and SKILL.md are user-level config outside SB repo — not committed
  - Only site/index.html committed to SB repo
metrics:
  completed_date: "2026-04-06"
  tasks: 3
  files: 22
---

# Quick Task 260406-anb: Add Automatic Model Switching to Silver Bullet

**One-liner:** Added `model: opus/sonnet` directives to 20 GSD agent files, Opus advisory to quality-gates SKILL.md, and a Cost Optimization feature section to the Silver Bullet website highlighting 40-60% token cost reduction.

## What Was Done

### Task 1: Add model directives to all GSD agent files and SKILL.md

Updated 20 agent files in `~/.claude/agents/` with `model:` field in YAML frontmatter, inserted after `description:` and before `tools:`.

**Opus agents (6):** gsd-planner, gsd-verifier, gsd-security-auditor, gsd-ui-checker, gsd-assumptions-analyzer, gsd-integration-checker

**Sonnet agents (14):** gsd-executor, gsd-phase-researcher, gsd-doc-writer, gsd-doc-verifier, gsd-codebase-mapper, gsd-roadmapper, gsd-research-synthesizer, gsd-project-researcher, gsd-ui-researcher, gsd-user-profiler, gsd-nyquist-auditor, gsd-debugger, gsd-advisor-researcher, gsd-plan-checker

**gsd-ui-auditor.md** left unchanged (not in assignment list).

**quality-gates SKILL.md** updated with Opus advisory blockquote after the closing frontmatter `---`, before the `# /quality-gates` heading.

These files are user-level config outside the SB repo — not committed.

### Task 2: Add cost optimization section to website

`site/index.html` updated with:
- New `<section id="cost-optimization">` inserted between COMPARE and HOW IT WORKS sections
- 3 feature cards: "Opus: Deep Reasoning", "Sonnet: High Throughput", "40-60% Cost Reduction"
- Callout block explaining routing is automatic, baked into agent definitions
- Nav bar `<li><a href="#cost-optimization">Cost</a></li>` added after Enforcement link

All HTML uses existing CSS classes (`feature-card`, `grid-3`, `fade-in`, `callout`, `section-label`, `section-title`, `section-desc centered`) — no new styles.

### Task 3: Run tests and commit SB repo changes

All 28 Jest tests in `tests/test-app/` passed. Hook tests (21 assertions) also passed.

Committed only `site/index.html` to SB repo:
- Commit: `c1beda1` — `feat: automatic model switching -- route agents to optimal model tier`

## Deviations from Plan

None — plan executed exactly as written.

Note: `npm test` had no script defined in the root `package.json`. Tests were run via `tests/test-app/` (Jest, 28 tests) and shell hook tests, matching the established project test pattern from prior commits.

## Known Stubs

None — all feature cards display static copy (intentional; no data source needed). The cost reduction claim (40-60%) is marketing copy, not a computed figure.

## Self-Check: PASSED

- site/index.html modified: FOUND
- cost-optimization section: FOUND (grep confirmed)
- nav link: FOUND (grep confirmed)
- commit c1beda1: FOUND (git log confirmed)
- All 6 opus agents verified: FOUND
- All 14 sonnet agents verified: FOUND
- SKILL.md advisory: FOUND
- gsd-ui-auditor unchanged: CONFIRMED
