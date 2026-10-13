# Solution Capability Report: Silver Bullet

Slug: `silver-bullet`

## Executive summary

Silver Bullet is an open-source Agentic Process Orchestrator — a process layer inside Cursor, Codex, and Claude Code that composes workflows, enforces hook gates, and records skills.

## Evidence-backed notes

- Silver Bullet self-positions as an orchestration layer that runs inside Claude Code, Codex, or Cursor sessions rather than replacing the host runtime — satisfying process layer above host runtime and plugin/skill/hook packaging.
- Silver Bullet ships 12 layers of hook-enforced gates (SessionStart reset, PreToolUse planning gates, completion audits, stop hooks, branch-finish readiness) that block progress before PR creation or release — a deterministic quality gates claim, not advisory.
- Silver Bullet exposes 22 pre-composed workflows built from 27 reusable atomic flows with 85 flow-step V-loops and evidence schemas, covering feature, bugfix, UI, DevOps, deploy, canary and release.
- Silver Bullet uses a two-tier delivery discipline: intermediate commits require only the planning floor, while final delivery (PR/release/deploy) requires full verification evidence.
- Silver Bullet is free and open-source (Ālo Labs alpha) with no telemetry or lock-in, placing it at price parity with OSS methodology packs rather than with SaaS peers.
- BMAD's enforcement is prompt/persona-level rather than hook-level; no machine-checkable stop-gate is documented, so it scores lower than Silver Bullet on deterministic quality gates.
- microsoft/conductor is MIT-licensed and provides deterministic YAML-defined routing with parallel groups and configurable failure modes (fail_fast, continue_on_error, all_or_nothing) over the Copilot SDK and Anthropic Agents SDK — the strongest deterministic quality gates evidence among APO peers besides Silver Bullet.
- Cosmos entered public preview around May–June 2026 and is gated to the MAX plan at $200/developer/month or custom Enterprise pricing — a ~$2,400/dev/year floor versus $0 for Silver Bullet and the OSS packs.
- The secondary market splits cleanly on enforcement mechanism: Silver Bullet and microsoft/conductor use machine-checkable blocking gates, while BMAD, Spec Kit, Superpowers and Ruflo rely on prompt-, artifact-, or persona-level discipline that an agent can in principle skip.
- Silver Bullet qualifies as APO across all 7 inclusion criteria: multi-phase lifecycle (router/discovery/plan/execute/verify/ship), plugin/skill/hook packaging, deterministic hooks (pre-commit, completion-audit, delivery-gate), cross-session memory (agentmemory + graphify + .planning), specialist agents, release-enforcement (CI-gated), process layer above Claude Code/Codex/Cursor.
- Startup-weighted comparison: in sdlc-plugins market, all entries are OSS/zero-cost → no commercial bias. In agentic-sdlc-saas, weight by adoption signals (Factory.ai/Devin/Cosmos dominant). In APO, Silver Bullet is the anchor; secondary seeds (AI-DLC, Conductor, cc10x) carry lower public footprint.
- Silver Bullet is the most comprehensive APO in the landscape: 85 canonical skills, hook-based deterministic gates, cross-session state via context-mode/agentmemory, plugin packaging for Claude/Codex/Cursor, and explicit multi-market positioning (APO primary, SDLC plugins secondary, agentic SDLC SaaS tertiary).
