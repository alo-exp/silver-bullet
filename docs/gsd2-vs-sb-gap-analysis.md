# GSD-2 vs GSD v1 + Silver Bullet — Gap Analysis

**Date:** 2026-04-02
**Scope:** Outcomes achievable only with GSD-2 that cannot be achieved with GSD v1 + Silver Bullet

---

## Architectural Premise

The fundamental difference is architectural: **GSD v1 + Silver Bullet enforces what Claude does inside Claude Code. GSD-2 IS the agent runtime — it runs Claude as a sub-tool.** This distinction drives every gap below.

GSD v1 + Silver Bullet is a prompt-enforcement system: PostToolUse hooks, CLAUDE.md instructions, and quality gate checks fire inside an active Claude Code session. GSD-2 is a standalone TypeScript CLI (`gsd-pi`) built on the Pi SDK — a real state machine that orchestrates Claude programmatically.

---

## Category 1 — Autonomy & Unattended Operation

**GSD v1 + SB:** You must keep Claude Code open and active. The enforcement is hooks firing inside a Claude Code session. If you close the terminal, everything stops. The "auto loop" is Claude Code self-directing based on CLAUDE.md instructions.

**GSD-2 only:**
- `gsd auto` — walks a real TypeScript state machine. You close the terminal. The process continues.
- Crash recovery: if the process dies, lock files + session forensics let it resume exactly where it left off
- Stuck detection: sliding-window analysis detects loops with no progress, stops with diagnostics rather than burning tokens indefinitely
- Timeout supervision: soft (20min) / idle (10min) / hard (30min) timeouts with recovery steering
- Provider error recovery: rate limits auto-resume, server errors auto-resume, permanent errors pause

**Outcome you cannot achieve with v1 + SB:** Start a build, walk away, come back to a completed project with clean git history and an HTML report. Literally impossible — v1 + SB requires you watching Claude Code.

---

## Category 2 — Verified Completion (Not LLM Self-Assessment)

**GSD v1 + SB:** `/gsd:verify-work` asks Claude to verify its own work by examining files and checking against requirements. The LLM judges whether it is done. Silver Bullet's quality gates are design-phase checklists — they fire before implementation, not after.

**GSD-2 only:**
- Verification is **mechanical shell commands** — `lint`, `typecheck`, `test` run after every task as actual processes
- If verification fails, GSD-2 auto-retries with the failure output injected as context
- The verification result is a process exit code, not an LLM opinion
- Verification commands are configurable per project in PREFERENCES.md

**Outcome you cannot achieve with v1 + SB:** A guaranteed green test suite on every commit. GSD-2's verification is a hard gate enforced by code. SB's verification is asking Claude if it is satisfied.

---

## Category 3 — Cost Visibility and Budget Control

**GSD v1 + SB:** Zero cost awareness. You find out how much you spent from the Claude.ai dashboard after the fact, with no per-task breakdown.

**GSD-2 only:**
- Per-unit token/cost ledger in `.gsd/metrics.json` — every task records input tokens, output tokens, cache reads, cache writes, USD cost
- Budget ceiling with three enforcement modes: `warn`, `pause`, `halt`
- Cost projections after 2+ slices complete (extrapolates remaining cost)
- Graduated budget pressure: at 50%/75%/90% of budget, automatically downgrades to cheaper models
- TUI dashboard with cumulative cost visible at all times
- HTML reports include full cost breakdown with per-task metrics

**Outcome you cannot achieve with v1 + SB:** "Don't spend more than $5 on this feature" as a hard constraint. Or: "Show me which tasks are most expensive." None of this is possible.

---

## Category 4 — Dynamic Model Routing

**GSD v1 + SB:** Uses whatever model Claude Code is configured with for every task. Simple grep and complex architecture design get the same model.

**GSD-2 only:**
- Complexity classifier analyzes task plans: step count, file count, signal words (research/architect/migrate/refactor/integrate)
- Routes to light (Haiku-class) / standard (Sonnet-class) / heavy (Opus-class) automatically
- Adaptive learning: routing history tracks outcomes, adjusts future classifications
- Cross-provider routing: can mix Anthropic / Google / AWS Bedrock in the same session
- `escalate_on_failure`: if a lighter model fails, automatically escalates to heavier

**Outcome you cannot achieve with v1 + SB:** A simple rename task uses Haiku at $0.001, a complex refactor uses Opus at $0.06. GSD-2 does this automatically. v1 + SB charges Sonnet/Opus rates for everything.

---

## Category 5 — True Parallel Execution

**GSD v1 + SB:** Wave-based parallel execution dispatches multiple subagents via Claude Code's Agent tool. These subagents share the same Claude Code session infrastructure, run within the same billing context, and do not have true filesystem isolation.

**GSD-2 only:**
- Parallel orchestration runs multiple actual `gsd` processes as separate OS processes
- Each worker gets its own filesystem worktree, git branch, state directory, metrics file, and context window
- Inter-process coordination via file-based IPC (`.gsd/parallel/<MID>.status.json`)
- Budget ceiling per worker prevents runaway costs
- Conflict-aware merge strategy detects file overlaps before assigning work
- Up to 4 simultaneous workers — each one fully crash-recoverable independently

**Outcome you cannot achieve with v1 + SB:** Two independent features building in true parallel with zero shared state. The SB/v1 subagents are children of the same session — not independent processes.

---

## Category 6 — Headless / CI / Programmatic Control

**GSD v1 + SB:** Interactive only. You interact through the Claude Code chat interface. No programmatic API, no CI integration, no exit codes.

**GSD-2 only:**
- `gsd headless --output-format json` — structured JSON result with status, exit codes, cost, commits, artifacts
- Exit codes: 0 = success, 1 = error, 10 = blocked (needs human), 11 = cancelled
- Event streaming: JSONL on stdout, consumable by any tool
- Answer injection: pre-supply responses to known questions to eliminate interactive prompts
- MCP server mode (`gsd --mode mcp`) — exposes GSD as an MCP tool set for other agents
- RPC protocol — full bidirectional JSON control from TypeScript SDK
- Docker integration — containerized GSD auto mode for isolated, reproducible builds

**Outcome you cannot achieve with v1 + SB:** `gsd headless ... && deploy.sh` — a CI/CD pipeline where GSD builds a feature, you check exit code 0, and trigger deployment. Or: an outer orchestrator that programmatically controls many GSD instances. Or: "if GSD returns exit code 10, route the blocker question to my Slack."

---

## Category 7 — Multi-Provider / Non-Anthropic Models

**GSD v1 + SB:** Locked to Anthropic Claude. Whatever `ANTHROPIC_API_KEY` Claude Code uses. Zero provider choice.

**GSD-2 only:**
- 20+ provider integrations: Anthropic, Google Gemini, Google Vertex, AWS Bedrock, OpenAI, Azure OpenAI, Mistral, GitHub Copilot, DashScope, and more
- Custom model definitions via `~/.gsd/agent/models.json`
- Same workflow runs on GPT-4o, Gemini 2.0, Claude, or Llama — swappable by config

**Outcome you cannot achieve with v1 + SB:** Run your engineering workflow on Gemini 2.0 Pro because your team has Google Cloud credits. Or benchmark the same feature build across 3 providers.

---

## Category 8 — Remote Collaboration & Async Interaction

**GSD v1 + SB:** Single user, synchronous. You must be watching Claude Code to respond to any ambiguity or decision point.

**GSD-2 only:**
- Discord/Slack/Telegram integration: blockers route to your chat app; you answer with emoji reactions or text
- Remote questions system: any `ask_user_questions` tool call in headless mode routes to configured chat platform
- Team mode: multiple developers run `gsd auto` simultaneously on different milestones, sharing planning artifacts via git, with proper state isolation

**Outcome you cannot achieve with v1 + SB:** Start a build before bed, get pinged on Slack when it hits a decision point, reply "2" to choose option 2, wake up to a merged PR. Or: 3-person team each running `gsd auto` on their own milestones from the same repo.

---

## Category 9 — Observability & Reporting

**GSD v1 + SB (v0.3.0 update):** v0.3.0 added two observability capabilities:
- **Session logging** (`session-log-init.sh`) — creates a structured `docs/sessions/YYYY-MM-DD-HH-MM-SS.md` skeleton on every session start, capturing task, approach, files changed, skills run, autonomous decisions, and outcome
- **`/forensics` skill** — structured post-mortem investigation for completed, abandoned, or stalled sessions; classifies root cause (pre-answer gap / anti-stall / genuine blocker / external kill); saves report to `docs/forensics/`

Still no runtime dashboards, no per-task cost metrics, no HTML build reports, no SQLite audit log.

**GSD-2 only:**
- Full-screen TUI visualizer with Progress / Dependencies (ASCII DAG) / Metrics (bar charts) / Timeline tabs
- HTML export — self-contained build report with dependency graph, per-task cost, verification results, commit log
- Health widget visible in terminal during auto mode
- Cost projections updated after each completed slice
- SQLite-backed state with audit log (actor, trigger reason, per-operation records)
- Forensics: runtime post-mortem investigation (`/gsd forensics`) with access to full execution state

**Outcome you cannot achieve with v1 + SB:** Share a build report with a client showing exactly what was built, how long it took, what it cost, and what tests passed. GSD-2 forensics can reconstruct failures from runtime state; SB's `/forensics` reconstructs from session logs and git history (instruction-based, not runtime).

---

## Category 10 — Adaptive Learning & Context Retention

**GSD v1 + SB:** Each session starts fresh. No structured accumulation of project knowledge across sessions beyond tech-debt.md.

**GSD-2 only:**
- `KNOWLEDGE.md` — structured knowledge base incrementally updated by every task; injected into future dispatch prompts
- Adaptive model routing that learns from outcomes (routing history)
- Skill auto-discovery: during research phase, detects relevant skills and installs them automatically
- TF-IDF semantic context selection: for files >3KB, relevance-ranked chunking rather than full-file injection
- Captures system: fire-and-forget thought capture mid-run, triaged between tasks into quick-tasks / inject / defer / replan / note

---

## Summary Table

| Outcome | GSD v1 + SB | GSD-2 |
|---------|-------------|-------|
| Walk-away autonomous execution | ❌ Requires Claude Code open | ✅ Standalone state machine |
| Crash recovery | ❌ None | ✅ Lock files + forensics |
| Mechanical test/lint verification | ❌ LLM self-assessment | ✅ Shell commands + auto-retry |
| Per-task cost tracking | ❌ None | ✅ Token/USD ledger |
| Budget ceiling enforcement | ❌ None | ✅ warn / pause / halt |
| Dynamic model routing | ❌ One model for all | ✅ Haiku→Sonnet→Opus by complexity |
| True OS-level parallel workers | ❌ Subagents in same session | ✅ Separate processes + worktrees |
| Headless / CI integration | ❌ Interactive only | ✅ JSON output + exit codes |
| MCP server mode | ❌ None | ✅ `gsd --mode mcp` |
| Non-Anthropic providers | ❌ Claude only | ✅ 20+ providers |
| Async Slack/Discord unblocking | ❌ Must watch terminal | ✅ Remote question routing |
| Team multi-developer mode | ❌ Single user | ✅ Concurrent milestone isolation |
| Build reports (HTML) | ❌ None | ✅ Per-task metrics + DAG |
| Post-mortem forensics | ✅ `/forensics` skill — session logs + git history (v0.3.0) | ✅ Runtime forensics — full execution state |
| Cross-session knowledge base | ⚠️ KNOWLEDGE.md template (manually updated at step 15) | ✅ Auto-updated after every task |
| Semantic context compression | ✅ TF-IDF ranked chunking (PostToolUse hook, pure shell, cache-backed, source-priority) | ✅ TF-IDF ranked chunking |

---

## One-Sentence Summary

GSD v1 + Silver Bullet **enforces** the right workflow on Claude. GSD-2 **is** the runtime — it controls Claude programmatically, walks a deterministic state machine, runs shell commands to verify outputs, tracks costs to the cent, runs unattended, recovers from crashes, routes to cheap models for cheap work, and pipes everything into CI/CD.

---

*Generated: 2026-04-02 | Based on GSD-2 v2.58.0 (gsd-pi) and Silver Bullet v0.4.0*
*v0.3.0 updates: `/forensics` closes the post-mortem forensics gap; session logging added to observability; KNOWLEDGE.md template partially closes the cross-session knowledge base gap.*
*v0.4.0 updates: Semantic context compression (TF-IDF PostToolUse hook, pure shell, cache-backed, source-priority) closes the semantic context compression gap.*
