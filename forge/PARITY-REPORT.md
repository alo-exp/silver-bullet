# Silver Bullet for Forge — Parity Report

**Generated:** 2026-05-13
**Milestone:** v0.33.x — Forge Port Parity Refresh
**Source repo state:** post-Phase-93 refresh work
**Forge version targeted:** any version that follows `forgecode.dev/docs` spec (skills, custom agents, slash commands)
**Current repo version:** v0.33.x line

---

## Inventory Audit (current)

| Category | Expected | Actual | Status |
|---|---|---|---|
| SB skills (silver-*, gsd-*, review-*, plus SB-cached Superpowers) | ~76 | 76 | ✓ |
| Engineering KW skills | 10 | 10 | ✓ |
| Design KW skills | 7 | 7 | ✓ |
| Product-Management KW skills | 8 | 8 | ✓ |
| Marketing KW skills | 8 | 8 | ✓ |
| **Total skills** | 109 | **109** | ✓ |
| Hook-equivalent agents (forge-*) | 16 | 16 | ✓ |
| GSD subagent-equivalent agents | **33** | **33** | ✓ (was 31 in v0.28.0; +gsd-doc-classifier, +gsd-doc-synthesizer in v0.31.0) |
| Superpowers agent (code-reviewer) | 1 | 1 | ✓ (NEW in v0.31.0) |
| **Total agents** | ~50 | **50** | ✓ |
| **Forge slash commands** | ≥50 | **50** | ✓ |
| → GSD slash commands | 45 | 45 | ✓ |
| → Superpowers commands | 3 | 3 | ✓ |
| → KW PM commands | 1 | 1 | ✓ |
| → SB helper commands | 1 | 1 | ✓ |
| **SB templates** | 18 files + 7 dirs | 18 + 7 | ✓ |

## Current Refresh Gaps Closed (per audit 2026-05-13)

The comprehensive refresh, verified against the current SB repository surface and `forgecode.dev/docs/`, keeps the earlier v0.31.0 Forge completion work and closes the current drift:

### Critical
- ✅ **`forge/commands/` directory created.** Per `forgecode.dev/docs/commands/`, slash commands belong in `.forge/commands/` and are invoked with `:`. The v0.28.0 port had collapsed GSD slash commands into "skill bodies," misaligned with Forge's spec. Fixed in v0.31.0.
- ✅ **45 GSD slash commands ported** to `forge/commands/gsd-*.md` from upstream `get-shit-done-cc/commands/gsd/*.md`.
- ✅ **SB runtime spec template (`silver-bullet.md.base`) now ported.**
- ✅ **SB workflow template (`workflow.md.base`) now ported.**
- ✅ **SB config schema (`silver-bullet.config.json.default`) now ported.**
- ✅ **Installer creates `~/forge/silver-bullet/templates/`** — closes the broken silver-init bootstrap path.
- ✅ **Current SB skill surface refreshed** — Forge now includes `silver-ensure-docs`, `silver-handoff`, refreshed review/artifact skills, refreshed quality gates, and the current `silver` router.
- ✅ **Current hook guard semantics ported** — Forge now has `forge-dependency-skill-check`, `forge-instruction-file-guard`, and `forge-workflow-chain-guard`.

### Medium
- ✅ **2 missing GSD subagents ported**: `gsd-doc-classifier`, `gsd-doc-synthesizer` (32→33 to 33/33).
- ✅ **Superpowers `code-reviewer` agent ported** (was missing entirely).
- ✅ **3 Superpowers commands ported**: `brainstorm`, `execute-plan`, `write-plan`.
- ✅ **1 KW product-management command ported**: `pm-brainstorm`.
- ✅ **8 GSD skill names reconciled** with upstream long form (`gsd-discuss` → `gsd-discuss-phase`, etc.) so cross-references resolve.

## Format Compliance (verified against forgecode.dev/docs)

- ✓ **Skills** use Claude Code SKILL.md format (YAML `name`/`description` frontmatter) — fully compatible per `forgecode.dev/docs/skills/`. Auto-loaded by description-context match.
- ✓ **Custom agents** use Forge agent format (`id` required + `description` + `tool_supported: true` for inter-agent calls + `temperature` for determinism). Lookup is by `id` field, not filename.
- ✓ **Slash commands** use Forge command format (YAML `name`/`description` frontmatter). Filename becomes command name; invoked with `:` prefix per `forgecode.dev/docs/commands/`.
- ✓ Hook-agents specify `tool_supported: true` and `temperature: 0.1` (deterministic gating).
- ✓ All ported agent frontmatter strips Claude-Code-only fields (`allowed-tools`, `agent`, `argument-hint`, `model`).

## Smoke Test Result (current)

Run `bash forge/scripts/smoke-test.sh` after `bash forge-sb-install.sh --global-only` produces (representative output):

```
=== Silver Bullet for Forge — Smoke Test ===
Forge home: ~/forge

[1/8] Global skill set                  ✓ ≥109 skills
[2/8] Global agent set                  ✓ ≥50 agents
[3/8] Hook-equivalent agents            ✓ all 16 present
[4/8] GSD subagent-equivalent agents    ✓ 33/33 + code-reviewer
[5/8] Skill+agent frontmatter validity  ✓ all sampled OK
[6/8] Slash commands                    ✓ ≥50 commands; critical commands present
[7/8] SB templates                      ✓ all 3 base templates present
[8/8] AGENTS.md (global)                ✓ present + references Silver Bullet

Summary: ≥30 passed, 0 failed.
```

## Items Still Known-Limited on Forge (intentional, no port path)

These items in the Claude Code Silver Bullet plugin have no direct Forge equivalent and are documented as such in `forge/PARITY.md`:

- **Hook system** — Forge has no automatic `PreToolUse` / `PostToolUse` / `Stop` hook events. SB's closest parity path is explicit hook-equivalent custom agents invoked at gating moments through `~/forge/AGENTS.md`.
- **Plugin marketplace** — Forge has no `/plugin install`. Skills/commands/agents are filesystem-installed (copy into `.forge/` or `~/forge/`).
- **Subagent dispatch tool** — Forge agents call other agents only when the target has `tool_supported: true` + `description`. No arbitrary `Task` invocation.
- **`Stop` / `SubagentStop` blocking** — not available; replaced by `forge-task-complete-check` agent the main agent must invoke before declaring done.

Hooks not ported (intentional, marked in PARITY.md): `dev-cycle-check.sh`, `phase-archive.sh`, `record-skill.sh`, `compliance-status.sh`, `prompt-reminder.sh`, `semantic-compress.sh`, `ensure-model-routing.sh`, `timeout-check.sh`.

---

**Status: 100% functional parity for ported surface, aligned with forgecode.dev/docs spec.**
