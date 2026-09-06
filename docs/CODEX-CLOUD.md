# Silver Bullet in Codex Cloud

How to run Silver Bullet workflows in **Codex Cloud** (the container-backed
cloud task runner) alongside the **desktop agent** (Codex CLI / IDE extension,
Claude Code, Cursor), what the cloud runtime can and cannot do, and how to
split work between the two.

> Scope note: everything below about Silver Bullet is verified against this
> repo. Everything about Codex Cloud platform behavior reflects OpenAI's
> published cloud documentation as of this writing — re-check
> `developers.openai.com/codex/cloud` before relying on a capability claim,
> since the cloud surface moves faster than the local CLI.

---

## 1. Cloud vs desktop: what actually differs

| Capability | Desktop agent (Codex CLI / IDE, Claude Code, Cursor) | Codex Cloud |
|---|---|---|
| Plugin install (`codex plugin add`, `/plugin install`) | Yes — `scripts/install-codex.sh`, marketplace `alo-labs-codex` | No plugin/marketplace surface in the task container |
| Host hook events (PreToolUse / PostToolUse / Stop) | Yes — Silver Bullet **tier 2** | Not delivered; treat as **tier 0–1** |
| `~/.codex/config.toml`, MCP servers | Yes | Not applied to cloud tasks |
| Filesystem persistence between runs | Yes (your machine) | Ephemeral container; only the branch/PR survives |
| Network | Your machine's network | Setup script has internet; **agent phase internet is off by default**, opt into limited/unrestricted per environment |
| `AGENTS.md` | Read | Read — this is the main instruction channel in cloud |
| Long unattended runs / parallel fan-out | Limited by your machine | Strong — many tasks in parallel, each isolated |

The practical consequence: **Silver Bullet's enforcement engine is a host-hook
feature, and Codex Cloud does not give it hooks.** The workflows, skills,
artifact templates, and ordering all still apply — they just run as
*instruction-enforced* rather than *hook-enforced*. That is exactly the
tier 0–1 mode already specified in `docs/RUNTIME-COMPATIBILITY.md`.

---

## 2. Running Silver Bullet workflows in Codex Cloud

### 2.1 Make the skills reachable without a plugin install

Cloud has no plugin cache, so the workflow text has to come from the repo
itself. Two supported shapes:

**A. Vendored skills (recommended, deterministic).** Commit the rendered Codex
bundle into the project so the cloud container sees it on checkout:

```bash
# in the downstream project, from a desktop session
mkdir -p .silver-bullet/skills
cp -R "$(codex plugin path silver-bullet)/skill-source/." .silver-bullet/skills/
git add .silver-bullet/skills && git commit -m "chore: vendor Silver Bullet skills for cloud runs"
```

**B. Fetch in the environment setup script.** Setup scripts run *with*
internet even when the agent phase is sandboxed, so clone there:

```bash
# Codex Cloud → environment → setup script
git clone --depth 1 https://github.com/alo-exp/silver-bullet /opt/silver-bullet
```

Prefer (A) when you want the cloud run pinned to the same SB version your
desktop sessions use; prefer (B) when you want cloud runs to track `main`.

### 2.2 Point `AGENTS.md` at the workflow

`AGENTS.md` is the one instruction file Codex Cloud reliably reads. Add a
Silver Bullet section that names the canonical doc and the route:

```markdown
## Silver Bullet

- Canonical rules: `silver-bullet.md` (read it before planning).
- Skills: `.silver-bullet/skills/<name>/SKILL.md`.
- Route every non-trivial task through a composable flow — `silver-feature`,
  `silver-ui`, `silver-bugfix`, `silver-release`, `silver-devops`.
- Post-execute order is mandatory:
  REVIEW → VERIFY → SECURE → VALIDATE → pre-ship QUALITY GATE → SHIP.
- Run `bash tests/run-all-tests.sh` before opening a PR.
```

Keep this short. Cloud tasks start from a cold context and a 200-line
`AGENTS.md` crowds out the actual task.

### 2.3 Follow the tier 0–1 playbook

From `docs/RUNTIME-COMPATIBILITY.md`, unchanged for cloud:

1. `sb_initiated: true` and workflow docs must already exist in the repo
   (run `/sb:init` **on the desktop** — it is not a cloud operation).
2. Route via the composer skill rather than improvising a plan.
3. **Read each `SKILL.md` explicitly and follow it in order.** In cloud there
   is no `PostToolUse/Skill` event, so nothing records state for you — the
   ordering is only as good as the agent's adherence.
4. Follow the post-execute order above even though nothing blocks you.
5. Run the verification commands before pushing; no `completion-audit.sh`
   will stop a premature `gh pr create`.
6. Parent-only orchestrator directive blocks are **inactive** — the cloud
   agent may implement inline.

### 2.4 Recover the enforcement you lost

Cloud cannot run hooks, but it can run **CI**. That is the durable fix: move
the gates you care about into GitHub Actions on the PR, so a cloud-authored
branch is checked by the same rules a desktop session would have hit at
`PreToolUse`. Test suite, `bash tests/run-all-tests.sh`, planning-artifact
freshness, and PR traceability all translate into workflow steps. Treat
CI as the cloud tier-2 substitute and require it on the branch.

---

## 3. MCP in Codex Cloud (Figma, Google Drive)

**Short answer: no — not in the cloud task container.**

MCP configuration for Codex lives in `~/.codex/config.toml` (global) or a
trusted project's `.codex/config.toml`, and it is consumed by the **local**
CLI, IDE extension, and desktop app. Codex Cloud environments expose setup
scripts, secrets, container caching, and an internet-access toggle — not an
MCP server surface. Cloud MCP support has been an open feature request rather
than a shipped capability; verify current status before designing around it.

Two further blockers even if a server were configurable: cloud agent internet
access is **off by default**, so a remote MCP endpoint is unreachable until
you opt into limited/unrestricted access and allowlist the host; and OAuth
flows (which both Figma and Google Drive use) need an interactive browser
consent step that a headless task container cannot perform.

### Working pattern instead

Do the MCP-dependent step on the desktop, commit its **output**, then let
cloud consume the artifact:

| Need | Desktop step (MCP) | Committed artifact | Cloud step |
|---|---|---|---|
| Figma design → code | `get_design_context`, `get_variable_defs`, `download_assets` | `design-system/tokens.json`, spec markdown, exported assets | Implement components against the committed spec |
| Figma screenshot review | `get_screenshot` | `.planning/design/<id>.png` | Reference in review notes |
| Google Drive requirements doc | `read_file_content` / `download_file_content` | `.planning/requirements/<id>.md` | Build the plan/spec from the committed copy |

This is not a workaround so much as good hygiene: it puts the design and
requirements source of truth under version control, where a review can see it
and a later run can reproduce it.

---

## 4. Combining desktop and cloud

Split on **where the friction is**. Desktop wins where a task needs
credentials, live tools, hooks, or your judgment in the loop. Cloud wins where
a task is well-specified, long, parallelizable, and its output is a diff.

### Keep on the desktop

- `/sb:init`, `/sb:migrate`, `/sb:doctor` — they write host state
  that an ephemeral container throws away.
- Anything touching MCP: Figma extraction, Drive/Docs ingestion, connector-
  backed research.
- Planning-phase skills where you want the tier-2 gates to actually bite:
  clarify → research → plan → spec.
- The final release flow (`silver-release`), where cross-artifact review and
  the deploy checklist deserve a human at the terminal.

### Push to the cloud

- Execution of an **already-approved** spec — the plan is written, the
  acceptance criteria are explicit, the work is mechanical.
- Wide, boring changes: dependency bumps, API migrations, lint/type sweeps,
  test backfill across many files.
- Fan-out: three candidate implementations of the same spec as three cloud
  tasks, then compare diffs on the desktop and keep one.
- CI-failure triage on an existing PR.

### The handoff loop

```
desktop:  /sb → clarify → research → plan → spec        (hooks enforce, MCP available)
          commit .planning/ artifacts + spec  ──────────────┐
                                                            ▼
cloud:    task prompt = "implement .planning/specs/<id>.md, follow AGENTS.md"
          agent implements, runs tests, opens PR            │
                                                            ▼
desktop:  review the PR  → REVIEW → VERIFY → SECURE → VALIDATE → QUALITY GATE → SHIP
```

The committed spec is the contract. A cloud task with a thin prompt and no
spec produces exactly the kind of unreviewable diff Silver Bullet exists to
prevent — so the rule is: **cloud implements, it does not decide.**

### Practical guardrails

- **One task, one branch, one PR.** Cloud containers are ephemeral; anything
  not pushed is gone.
- **Pin the SB version** in vendored skills so cloud and desktop enforce the
  same ordering.
- **Require CI on cloud-authored branches.** It is the only gate the cloud run
  cannot skip.
- **Never let cloud run `silver-release`.** Shipping needs the tier-2 gates.
- **Re-verify on the desktop before merge.** Read the diff in a hook-enforced
  session; that session's `completion-audit` is your real backstop.

---

## Related docs

- `docs/RUNTIME-COMPATIBILITY.md` — capability tiers, host detection, install surfaces
- `docs/ORCHESTRATOR.md` — parent-only orchestration and directive guard
- `docs/ENFORCEMENT.md` — what the hooks actually block
- `silver-bullet.md` — canonical workflow rules
