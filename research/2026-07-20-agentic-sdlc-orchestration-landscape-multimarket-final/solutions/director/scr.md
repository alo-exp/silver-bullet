# Solution Capability Report: director

Slug: `director`

## Executive summary

Director is a primary-market APO candidate — agent orchestration, workflow composition, deterministic gates, and specialist agent routing. Canonical product URL was not independently verified in this pass (prior candidate repo returned 404); treat identity as seed-level until a primary source is confirmed.

## Evidence-backed notes

- Director SCR previously leaked Superpowers install-path prose; corrected to Director-only identity (P0 card corruption fix).
- Director is a primary-market APO candidate — agent orchestration, workflow composition, deterministic gates, specialist agent routing.
- Silver Bullet ships as a plugin/skill/hook layer with directories hooks/, skills/, templates/, scripts/, and .claude-plugin/.cursor-plugin/.agents/plugins/ packaging, not as a standalone host runtime.
- The primary APO market is structurally immature: most named seeds (Turboshovel, Cavekit v3.1, Barkain Workflow Orchestrator, cc10x, Director, AgentHub, ATeam, Claude Harness) are single-maintainer OSS packs without pricing, SLAs, or enterprise governance, meaning competition is on process depth and host-compatibility rather than commercial moat.
- The APO market is nascent and fragmented; most seeds (Conductor, cc10x, Director, Claude Harness, AgentHub, ATeam) are community packs or thin wrappers, while Silver Bullet and AI-DLC are the only seeds with documented multi-phase lifecycle enforcement and host-integrated packaging.
- No APO competitor matches Silver Bullet's plugin-host triad (Claude Code + Codex + Cursor). Most APOs (Conductor, cc10x, Director, AgentHub, ATeam) target a single host — typically Claude Code only — making SB the only cross-host process orchestration layer in the primary market.
- Must-research core seeds (Barkain, Conductor, cc10x, Director, Claude Harness, Claude Code Expert, AgentHub, ATeam) are either unmentioned or dismissed as 'community packs or thin wrappers' without linked evidence. The fragmentation conclusion is therefore under-determined.
