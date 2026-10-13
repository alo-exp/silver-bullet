# Solution Capability Report: conductor

Slug: `conductor`

## Executive summary

'Conductor' is an ambiguous name across at least four distinct products (conductor.build Mac app, microsoft/conductor CLI, ryanmac/code-conductor, Conductor OSS); solution cards must disambiguate by vendor and URL.

## Evidence-backed notes

- 'Conductor' is an ambiguous name across at least four distinct products (conductor.build Mac app, microsoft/conductor CLI, ryanmac/code-conductor, Conductor OSS); solution cards must disambiguate by vendor and URL.
- Conductor (conductor.build) runs multiple Claude Code and Codex agents in parallel, each in its own git worktree, with a visual dashboard and diff-first review; it is free with BYO API cost and targets 3–8 parallel features per repo.
- microsoft/conductor is MIT-licensed and provides deterministic YAML-defined routing with parallel groups and configurable failure modes (fail_fast, continue_on_error, all_or_nothing) over the Copilot SDK and Anthropic Agents SDK — the strongest deterministic quality gates evidence among APO peers besides Silver Bullet.
- The secondary market splits cleanly on enforcement mechanism: Silver Bullet and microsoft/conductor use machine-checkable blocking gates, while BMAD, Spec Kit, Superpowers and Ruflo rely on prompt-, artifact-, or persona-level discipline that an agent can in principle skip.
- Conductor.build and AI-DLC (AWS / awslabs) are the most credible non-SB APO entrants in the primary market; AI-DLC carries the methodology/AWS Labs pedigree, Conductor carries explicit workflow-orchestration branding for coding agents.
- Startup-weighted comparison: in sdlc-plugins market, all entries are OSS/zero-cost → no commercial bias. In agentic-sdlc-saas, weight by adoption signals (Factory/Devin/Cosmos dominant). In APO, Silver Bullet is the anchor; secondary seeds (AI-DLC, Conductor, cc10x) carry lower public footprint.
- Conductor (Netflix OSS) is adjacent-only — durable workflow execution engine, not APO-native. Lacks SDLC-specific enforcement, specialist agents, and host-integrated packaging for coding agents.
- Conductor occupies a distinct sub-position — parallel-worker orchestration and workspace isolation for coding agents — making it complementary rather than substitutive to gate-enforcement APOs like Silver Bullet.
- The Agentic Process Orchestrator (APO) primary market is thinly populated, with Silver Bullet, Conductor, AI-DLC, and cc10x as the leading verifiable solutions. Conductor provides active workflow-orchestration positioning, AI-DLC represents an enterprise-lifecycle methodology, and cc10x provides host-integrated packing for Claude Code.
- The APO market is thinly populated by self-labeled vendors; only Silver Bullet, AI-DLC, Conductor, and cc10x reliably evidence host-integrated process-layer packaging plus deterministic gates plus cross-session state. Most adjacent 'agentic workflow' tools collapse into single-SDLC-step or generic-agent-framework exclusion classes.
- The APO market is nascent and fragmented; most seeds (Conductor, cc10x, Director, Claude Harness, AgentHub, ATeam) are community packs or thin wrappers, while Silver Bullet and AI-DLC are the only seeds with documented multi-phase lifecycle enforcement and host-integrated packaging.
