# Solution Capability Report: claude-code

Slug: `claude-code`

## Executive summary

Silver Bullet self-positions as an orchestration layer that runs inside Claude Code, Codex, or Cursor sessions rather than replacing the host runtime — satisfying process layer above host runtime and plugin/skill/hook packaging.

## Evidence-backed notes

- Silver Bullet self-positions as an orchestration layer that runs inside Claude Code, Codex, or Cursor sessions rather than replacing the host runtime — satisfying process layer above host runtime and plugin/skill/hook packaging.
- BMAD installs into Claude Code and Cursor via a single command (npx bmad-method install), meeting plugin/skill/hook packaging.
- Spec Kit supports 29+ named agent integrations plus a generic adapter (Claude Code, Copilot, Gemini CLI, Cursor, Codex CLI, Windsurf, Goose, Roo Code and others) — the broadest host portability in the comparison set.
- Superpowers (Jesse Vincent / obra) installs a composable skills framework into Claude Code covering brainstorming, design, plan-writing, TDD, systematic debugging, subagent-driven development with built-in code review, and skill authoring — multi-phase multi-phase lifecycle coverage in plugin packaging.
- Reported Superpowers star counts in secondary sources (~248k) are implausible for a Claude Code plugin and should be treated as unverified; use the GitHub repo as the authoritative counter before publishing any adoption figure.
- Ruflo (formerly Claude Flow, by ruvnet) packages the SPARC methodology — Specification, Pseudocode, Architecture, Refinement, Completion — as a test-driven process layer over Claude Code.
- Conductor (conductor.build) runs multiple Claude Code and Codex agents in parallel, each in its own git worktree, with a visual dashboard and diff-first review; it is free with BYO API cost and targets 3–8 parallel features per repo.
- Tembo delegates work to Claude Code, Cursor and Codex across repos, triggered from Slack, Linear, GitHub and Sentry — a managed orchestration layer above host runtimes, qualifying it as a tertiary-market APO substitute despite no APO self-label.
- Silver Bullet qualifies as APO across all 7 inclusion criteria: multi-phase lifecycle (router/discovery/plan/execute/verify/ship), plugin/skill/hook packaging, deterministic hooks (pre-commit, completion-audit, delivery-gate), cross-session memory (agentmemory + graphify + .planning), specialist agents, release-enforcement (CI-gated), process layer above Claude Code/Codex/Cursor.
- GSD (Get Shit Done) ships as a Claude Code skill/command pack with phase-based execution and verification; satisfies plugin/skill/hook packaging + multi-phase lifecycle coverage + deterministic quality gates.
- Superpowers (obra) is a skill pack layered above Claude Code with TDD/verification specialists; satisfies process layer above host runtime + specialist agent orchestration + deterministic quality gates.
- SuperClaude provides config + skill layers (flags, modes, agent personas) for Claude Code; satisfies plugin/skill/hook packaging + process layer above host runtime. Mostly configuration rather than enforced gates — partial on deterministic quality gates.
