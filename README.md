# Dev Workflows

**Enforced development workflows for Claude Code**

Dev Workflows is a Claude Code plugin that enforces a structured development cycle through hooks and skills. Designed for teams with little or no AI-driven software engineering experience, it ensures that every change follows a rigorous plan-execute-review-ship pipeline — preventing the most common failure modes when working with AI coding agents.

## Install

```
/plugin install alo-exp/dev-workflows
```

## Prerequisites

- **[Superpowers](https://github.com/obra/superpowers)** plugin — required skills and planning primitives:
  ```
  /plugin install obra/superpowers
  ```
- **[Anthropic Engineering](https://github.com/anthropics/knowledge-work-plugins/tree/main/engineering)** plugin — code review, debugging, and deploy checklist skills:
  ```
  /plugin install anthropics/knowledge-work-plugins/tree/main/engineering
  ```
- **jq** for JSON parsing:
  ```
  brew install jq    # macOS
  apt install jq     # Linux
  ```

## Quick Start

1. Install the plugin and prerequisites above.
2. Run `/using-dev-workflows` in your project.
3. Done — hooks are active and the workflow is enforced.

## What It Does

Dev Workflows enforces compliance through six layers of defense:

| Layer | Mechanism | Purpose |
|-------|-----------|---------|
| 1 | **HARD STOP gate** | Blocks source-code edits until a plan exists |
| 2 | **Universal progress hook** | Reports a compliance score on every tool use |
| 3 | **Phase transition gates** | Enforces PLANNING -> EXECUTION -> REVIEW -> FINALIZATION order |
| 4 | **Completion audit** | Blocks `git commit`, `git push`, and deploy if the workflow is incomplete |
| 5 | **Redundant instructions** | Critical rules live in CLAUDE.md, the workflow template, and hooks simultaneously |
| 6 | **Anti-rationalization language** | Detects and blocks common excuses for skipping steps |

## The Full Dev Cycle

The default workflow contains **23 steps across 5 phases**:

1. **PLANNING** — brainstorming, spec writing, architecture, implementation plan
2. **EXECUTION** — plan execution, test-driven development, iterative coding
3. **REVIEW** — code review (request + receive), verification
4. **FINALIZATION** — documentation, tech-debt check, branch finishing
5. **DEPLOYMENT** — deploy checklist, final gates

See [`templates/workflows/full-dev-cycle.md`](templates/workflows/full-dev-cycle.md) for the complete step-by-step workflow.

## Customization

Create a `.dev-workflows.json` file in your project root to override defaults. Customizable fields:

| Field | Description |
|-------|-------------|
| `src_pattern` | Regex for source file paths (default: `/src/`) |
| `required_planning` | Skills that must run before code edits begin |
| `required_deploy` | Skills that must run before deploy is allowed |
| `active_workflow` | Which workflow template to enforce (default: `full-dev-cycle`) |

See [`templates/dev-workflows.config.json.default`](templates/dev-workflows.config.json.default) for the full schema.

## For Deploy Scripts

Copy the deploy gate snippet into your CI/CD pipeline before the build step:

```bash
cp scripts/deploy-gate-snippet.sh your-pipeline/
```

This script checks that the Dev Workflows completion audit has passed before allowing a deploy to proceed. See [`scripts/deploy-gate-snippet.sh`](scripts/deploy-gate-snippet.sh) for details.

## Trivial Changes

For typo fixes, copy edits, and other trivial changes that don't need the full workflow:

```bash
touch /tmp/.dev-workflows-trivial
```

This bypasses enforcement for the current session. The flag is cleared automatically on the next full session start.

## License

MIT — [Ālo Labs](https://alolabs.dev)
