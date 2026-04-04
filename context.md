# Session Context — Silver Bullet

**Date:** 2026-04-02
**Repo:** https://github.com/alo-exp/silver-bullet
**Site:** https://sb.alolabs.dev

---

## What Silver Bullet Is

Silver Bullet is an agentic process orchestrator for AI-native software engineering and DevOps, built for Claude Code. It combines:

- **GSD v1** (`npx get-shit-done-cc@^1.30.0`) — execution engine: wave-based parallel execution, fresh 200K context per agent, atomic commits, context rot prevention
- **Superpowers** (`/plugin marketplace add obra/superpowers`) — community skills: code review, branch management, testing strategy, cross-session memory
- **Engineering plugin** (`/plugin marketplace add knowledge-work-plugins/engineering`) — incident response, systematic debugging
- **Design plugin** (`/plugin marketplace add knowledge-work-plugins/design`) — design system audits, UX copy review
- **5 optional DevOps plugins**: HashiCorp, AWS Labs, Pulumi, DevOps Skills (ahmedasmar), wshobson/agents

Two enforced workflows:
- `full-dev-cycle` — 20-step app development workflow with 8 quality dimensions
- `devops-cycle` — 24-step IaC/DevOps workflow with blast radius assessment and 7 IaC-adapted quality gates

7 enforcement layers: 4 PostToolUse hooks + GSD workflow guard + GSD context monitor + redundant CLAUDE.md instructions

**Current version:** v0.6.1

---

## Work Done This Session

### Site (https://sb.alolabs.dev)

- Added DevOps plugin cards (5-column grid): HashiCorp, AWS Labs, Pulumi, DevOps Skills, wshobson/agents
- Added workflow tab switcher showing both 20-step and 24-step cycles with full step tables
- Added ALPHA superscript badge on the Silver Bullet h1 title (styled to match MultAI site)
- Title-cased all headings site-wide
- Added Compare nav link and standalone `/compare` page

**Comparator work:**
- Built comparison matrix (Silver Bullet vs GSD vs Superpowers) using `multai:comparator` skill
- 85 features / 11 categories / weighted scores: Silver Bullet 265, Superpowers 58, GSD 52
- Added homepage comparison section (3-column cards with score bars)
- Built `/compare.html` with full 85-feature matrix, 11 tables with fixed column alignment
- Fixed Silver Bullet bar visibility (missing background gradient)
- Left-aligned Priority column

**Mobile responsiveness:**
- Comprehensive fix for both `index.html` and `compare.html`
- Breakpoints: 900px (grid collapse), 768px, 600px
- Increased section padding: 56px→72px (768px), 48px→60px (600px)
- Hero pills gap: 12px→14px when stacked
- `.mt-4/.mt-6/.mb-4` bumped on 600px screens
- All feature tables get `overflow-x:auto` on mobile
- Removed "Primary Workflow" star badge from GSD ecosystem card

**Tag pills:**
- Increased `.tag` padding from `4px 12px` to `7px 16px`

### Docs

- **`docs/sdlc-gap-analysis.md`** — Thorough analysis of Silver Bullet's 12 critical gaps as an end-to-end SE process orchestrator. Covers 4 Critical / 4 High / 4 Medium gaps across a 12-phase SDLC model. Key finding: SB covers phases 3–8; both ends (discovery and production monitoring) are absent or unenforced.

- **`docs/gsd2-vs-sb-gap-analysis.md`** — Analysis of 10 capability categories where GSD-2 (`gsd-pi` v2.58.0) achieves outcomes impossible with GSD v1 + Silver Bullet. Core thesis: SB enforces the right workflow *on* Claude; GSD-2 *is* the runtime. Key gaps: unattended autonomy, mechanical shell verification, cost tracking/budgets, dynamic model routing, true OS-level parallel workers, headless/CI JSON API, 20+ provider support, async Slack/Discord unblocking, HTML reports + forensics, KNOWLEDGE.md cross-session learning.

---

## Key Files

| File | Purpose |
|------|---------|
| `site/index.html` | Main site |
| `site/compare.html` | Standalone comparison page |
| `site/fred-brooks.jpg` | Brooks photo in hero |
| `docs/sdlc-gap-analysis.md` | SDLC coverage gaps |
| `docs/gsd2-vs-sb-gap-analysis.md` | GSD-2 vs SB capability gap |
| `docs/Architecture-and-Design.md` | Architecture docs |
| `docs/Master-PRD.md` | Product requirements |
| `templates/workflows/full-dev-cycle.md` | 20-step dev workflow |
| `templates/workflows/devops-cycle.md` | 24-step DevOps workflow |
| `skills/using-silver-bullet/SKILL.md` | Onboarding skill |
| `CLAUDE.md.template` | Template for generated CLAUDE.md |

---

## Comparison Scores (Silver Bullet vs GSD vs Superpowers)

Weighted scoring: Critical×5, High×3, Medium×2, Low×1

| Platform | Score | Features (85 total) | Bar |
|----------|-------|---------------------|-----|
| Silver Bullet | 265 | 82/85 (96.5%) | ████████████████████ |
| Superpowers | 58 | 18/85 (21.2%) | ████ |
| GSD | 52 | 15/85 (17.6%) | ███ |

Matrix file: `docs/sb-vs-gsd-vs-superpowers.xlsx`

---

## SDLC Gap Summary (from sdlc-gap-analysis.md)

| Phase Coverage | Status |
|----------------|--------|
| Discovery & Requirements | ⚠️ Partial |
| Architecture & Design | ⚠️ Partial |
| Development | ✅ Strong |
| Code Review | ✅ Strong |
| Security | ⚠️ Partial |
| Testing | ⚠️ Partial |
| Quality Gates | ✅ Strong |
| Release & Deployment | ✅ Good |
| Post-Deployment Monitoring | ❌ Absent |
| Incident Response | ❌ Absent |
| Feedback & Iteration | ❌ Absent |
| Compliance & Governance | ❌ Absent |

Critical gaps to close: post-deployment observability, security testing (SAST/SCA vs design-time checklist), test execution gate, requirements/discovery structure.

---

## GSD-2 Gaps Summary (from gsd2-vs-sb-gap-analysis.md)

GSD-2 (`gsd-pi`) is a standalone TypeScript CLI built on the Pi SDK. The 10 capability gaps vs SB:

1. **Walk-away autonomy** — GSD-2 runs as a real OS process; SB requires Claude Code open
2. **Mechanical verification** — GSD-2 runs `lint`/`test`/`typecheck` as shell commands; SB uses LLM self-assessment
3. **Cost tracking** — GSD-2 has per-task token/USD ledger + budget ceiling; SB has none
4. **Dynamic model routing** — GSD-2 auto-routes Haiku/Sonnet/Opus by task complexity; SB uses one model for all
5. **True parallel execution** — GSD-2 spawns separate OS processes with worktree isolation; SB uses subagents in shared session
6. **Headless/CI API** — GSD-2 has `gsd headless` with JSON output + exit codes; SB is interactive only
7. **Multi-provider** — GSD-2 supports 20+ providers (Google, AWS Bedrock, OpenAI, etc.); SB is Anthropic-only
8. **Async collaboration** — GSD-2 routes blockers to Slack/Discord/Telegram; SB requires you watching terminal
9. **Observability** — GSD-2 has TUI visualizer, HTML reports, forensics; SB has none
10. **Cross-session learning** — GSD-2 accumulates KNOWLEDGE.md across tasks; SB starts fresh each session

---

## Positioning

Silver Bullet's positioning: **GSD Executes. Superpowers Plans. Silver Bullet Enforces Both.**

Silver Bullet does not compete with GSD or Superpowers — it orchestrates them. It adds the enforcement layer (PostToolUse hooks, quality gates, phase sequencing) that neither provides on its own.

GSD-2 is the natural successor/replacement for GSD v1, not for Silver Bullet. SB's enforcement architecture would sit on top of GSD-2 the same way it sits on top of GSD v1 — but GSD-2 integration has not been implemented yet.
