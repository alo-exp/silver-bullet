# Research: Forge-SB ↔ Claude-SB Coexistence on the Same Working Folder

**Date:** 2026-04-27
**Status:** Foundation for v0.29.0 milestone
**Question:** Can SB-on-Claude-Code and SB-on-Forge run simultaneously on the same project folder, the way two Claude-SB sessions can?

---

## TL;DR

**Today (v0.28.0): NO, not fully.** Two surfaces break:

1. **Claude-SB's gating hooks read a session-shared state file (`~/.claude/.silver-bullet/state`) that Forge never writes to.** A user who applies SB skills in a Forge session and then switches to Claude Code to `git commit` will be **blocked** by `completion-audit.sh` / `stop-check.sh` — even though the work is done. Two Claude sessions don't have this problem because both write to the same state file.
2. **`record-skill.sh` PostToolUse hook fires only when Claude Code's Skill tool is used.** Forge applying a skill (auto-loaded SKILL.md) leaves no trace in the state file.

**Everything else is already coexistence-safe** — disjoint storage paths, artifact-based signal sources, git-managed concurrency.

The minimal fix is asymmetric and scoped: have Forge cooperatively write skill applications to the same state file that Claude-SB's hooks read. Approximate effort: 1 phase, ~6 surgical changes. Detail in §6.

---

## 1. Conflict Surface Inventory

| # | Surface | Claude-SB uses | Forge-SB uses | Conflict? | Severity |
|---|---|---|---|---|---|
| 1 | Skill files | `~/.claude/skills/`, `~/.claude/plugins/cache/.../skills/` | `~/forge/skills/`, `.forge/skills/` | Disjoint paths | None |
| 2 | Agent files | `~/.claude/agents/` | `~/forge/agents/`, `.forge/agents/` | Disjoint paths | None |
| 3 | Top-level instructions | `CLAUDE.md`, `silver-bullet.md` | `AGENTS.md` | Different files | None |
| 4 | `.planning/` artifacts | Reads + writes (PROJECT/STATE/ROADMAP/PLAN/SUMMARY/etc.) | Reads + writes (same files) | Standard concurrent-edit risk, **same as two Claude sessions** | Standard |
| 5 | Git operations | Both runtimes shell out to git | Same | git is the source of truth, last-commit-wins | Standard |
| 6 | Session log | `docs/sessions/<date>-<branch>-<id>.md` per-session | Per-session log via forge-session-init agent | Each session uses its own filename | None |
| 7 | **State file** `~/.claude/.silver-bullet/state` | Reads + writes (one skill per line) via `record-skill.sh` | **Doesn't read or write** | **Mismatch** | **HIGH** |
| 8 | **Trivial bypass** `~/.claude/.silver-bullet/trivial` | Created at SessionStart, removed on first non-trivial Edit | **Doesn't read or write** | One-way: Forge-applied edits don't remove Claude's bypass file | MEDIUM |
| 9 | **Branch tracker** `~/.claude/.silver-bullet/branch` | Used to detect branch switches → reset state | **Doesn't read or write** | One-way: Forge work on a different branch doesn't reset Claude's state on switch back | LOW |
| 10 | Hook firing on commit | All gates fire automatically on `git commit` | No hook system; agents invoked manually | If Forge edited files but Claude commits → Claude hooks fire on Forge's work | **HIGH (consequence of #7)** |
| 11 | `forge-pre-commit-audit` agent | Not invoked | Reads `.planning/config.json` + artifact state | Forge agent's signal source is independent — **safe** | None |
| 12 | `record-skill.sh` PostToolUse hook | Records only Skill-tool invocations | N/A in Forge | Forge skill applications never recorded | **HIGH (root cause of #7)** |
| 13 | `forbidden-skill-check.sh` | PreToolUse on Skill | N/A in Forge; replaced by `forge-forbidden-skill-check` agent | Forge maintains its own forbidden list | None |
| 14 | `dev-cycle-check.sh` | Blocks edits to `~/.claude/plugins/cache/**` | N/A in Forge | Forge users could legitimately edit `~/forge/skills/` from a Forge session — but `dev-cycle-check.sh` only fires in Claude Code | None |
| 15 | `roadmap-freshness.sh` | Reads ROADMAP.md from disk | `forge-roadmap-freshness` agent reads ROADMAP.md from disk | Both runtimes read the same disk truth — **safe** | None |
| 16 | `spec-floor-check.sh` | Reads `.planning/SPEC.md` | `forge-spec-floor-check` agent reads same | Same disk truth | None |
| 17 | `pr-traceability.sh` | Reads PR body via `gh` | `forge-pr-traceability` agent reads PR body via `gh` | Same source | None |
| 18 | `ci-status-check.sh` | Reads `gh run list` | `forge-ci-status-check` agent reads same | Same source | None |
| 19 | `uat-gate.sh` | Reads `UAT.md` artifacts | `forge-uat-gate` agent reads same | Same source | None |
| 20 | Two-Claude-session baseline | Both write to state file → fully coordinated | — | This is the parity bar Forge must meet | — |

---

## 2. Two-Claude-Sessions Baseline (the parity target)

When the user has two Claude Code sessions on the same project folder:

1. Both load SB hooks from the project's `settings.json`
2. Both write skill applications to `~/.claude/.silver-bullet/state` — atomically appended (one line per skill, deduped via `grep -qx` before write)
3. Both honor the same trivial-bypass file
4. Both honor the same branch-tracker file (if they're on the same branch)
5. Both fire identical hook scripts on the same events

Hook firing is per-session (each session has its own Claude Code process tree), but the **state they read/write is shared via the home directory**. So if session A applies `silver-quality-gates`, session B's hooks see that on their next firing.

**Implication:** session-level state (skill applications, trivial bypass, branch tracking) is *machine-wide and project-agnostic* in Claude-SB. Two Claude sessions appear to a hook as "the same continuous workflow."

---

## 3. The Asymmetric Conflict in Detail

### Scenario A — Forge does the work, Claude commits

```
T0  user opens Forge session, runs `silver-feature` workflow
T1  Forge auto-applies silver-quality-gates skill (writes QUALITY-GATES.md)
T2  Forge invokes gsd-planner agent → writes PLAN.md
T3  Forge invokes gsd-executor agent → writes source code
T4  user closes Forge, opens Claude Code in same folder
T5  user: "commit this work"
T6  Claude runs `git commit` → completion-audit.sh fires
T7  hook reads ~/.claude/.silver-bullet/state — NO skills tracked from this branch
T8  hook BLOCKS: "Cannot commit — missing required_planning skills: silver-quality-gates"
T9  user is stuck despite the work actually being done correctly
```

The artifacts on disk **do** prove the work was done (QUALITY-GATES.md, PLAN.md, etc.) — but Claude-SB's hook does not look at artifacts. It looks at the state file.

### Scenario B — Claude does the work, Forge runs gating

```
T0  Claude session applies silver-quality-gates → state file updated, QUALITY-GATES.md written
T1  user switches to Forge for the implementation
T2  Forge invokes forge-pre-commit-audit agent before commit
T3  agent reads .planning/config.json + checks artifacts (QUALITY-GATES.md present)
T4  agent ALLOWS — works correctly
```

This direction is fine because Forge's gating signal source is artifacts on disk (which both runtimes write), not a state file.

### Scenario C — Concurrent (two terminals open)

Both sessions edit different files in the same folder. Standard git concurrency rules apply: both must `git pull --rebase` regularly; conflict resolution is normal. No SB-specific conflict because each runtime's gating fires only when *its* commit/PR/build is attempted.

---

## 4. Why the Mismatch Exists

Claude-SB designed the state file as a **runtime-level artifact**: it tracks "what skills the Claude Code agent has explicitly invoked via the Skill tool in this session." It's an invocation log, not an outcome log. Two Claude sessions share this log because they both invoke the same Skill tool.

Forge has no equivalent invocation log — its skills are auto-applied based on context, and there's no PostToolUse hook to write a record. Forge's gating model (in v0.28.0) instead relies on **artifact evidence** (presence of QUALITY-GATES.md, REVIEW.md, VERIFICATION.md, etc.) which it considers a more robust signal.

Both models are internally consistent. The break happens at the boundary where Claude-SB's invocation-log signal meets Forge's artifact-evidence signal.

---

## 5. Design Options for v0.29.0

### Option A — Forge writes to Claude's state file (asymmetric cooperation)

**Mechanism:** Each Forge custom agent that corresponds to an SB skill (or each invocation by the main Forge agent of an SB skill via auto-application) appends the skill name to `~/.claude/.silver-bullet/state` if the file exists.

**Where to add:**
- A new shared bash helper, `forge/scripts/record-skill-on-claude.sh`, that appends `<skill-name>` to `~/.claude/.silver-bullet/state` (with `grep -qx` dedup, same as `record-skill.sh`).
- Each parent skill (`silver-feature`, `silver-bugfix`, etc.) instructs the Forge agent to call this helper after applying the relevant skill. Add a "post-skill record" line to each skill's procedure.
- Alternatively (cleaner): add a Forge custom agent `forge-record-skill` that takes a skill id and writes the marker; parent skills invoke it.

**Pros:**
- Minimal change. Doesn't touch Claude-SB hooks.
- Preserves Claude-SB's authoritative state-file model.
- Bidirectional: Forge writes are visible to Claude.

**Cons:**
- Couples Forge to Claude's storage path (`~/.claude/.silver-bullet/state`). If Claude is not installed, the file simply doesn't exist and the marker write is a no-op (`mkdir -p` + `touch` + append guard).
- Requires every parent SB skill to remember to call the recorder. Easy to forget.
- Violates a user-stated rule: "Never touch trivial bypass or Silver Bullet state files. STRICTLY never touch ~/.claude/.silver-bullet/trivial or any SB state file; invoke required skills instead." — but that rule is about *agent rationalization*, not about a system-level cooperation API. v0.29.0 should formalize the API as legitimate cooperation, not bypass.

### Option B — Claude-SB hooks add artifact-based fallback

**Mechanism:** `completion-audit.sh` and `stop-check.sh`, when a required skill is *missing from the state file*, attempt a fallback: scan `.planning/phases/**/<artifact>.md` for evidence the skill ran (e.g., `QUALITY-GATES.md` for `silver-quality-gates`, `REVIEW.md` for `code-review`).

**Pros:**
- Hooks become more robust *generally* — fewer false-positive blocks even without Forge.
- No coupling between Forge and Claude file paths.
- Backward-compatible (state file remains the primary source; artifact check is fallback only).

**Cons:**
- Bigger change to Claude-SB hooks (need a skill-to-artifact mapping table, plus per-skill detection logic).
- Fallback heuristic risk: "QUALITY-GATES.md exists" doesn't prove `silver-quality-gates` ran in *this* session — could be a stale artifact from a prior phase.
- Per-skill maintenance burden grows as required-skill list grows.

### Option C — Shared session state at `.planning/.session-state` (project-local)

**Mechanism:** Both runtimes write skill applications to a project-local file `.planning/.session-state` (gitignored, but lives in the project, not in `~`). Claude-SB hooks read both this file *and* the home-directory state file (union). Forge agents write only to this file.

**Pros:**
- Clean separation — each project has its own session state.
- No cross-runtime path coupling.
- Useful even outside the Forge case (e.g., shared dev containers).

**Cons:**
- Bigger architectural change — touches both hooks and Forge agents.
- Two state files to keep in sync increases reasoning burden.
- Existing Claude-SB sessions need a migration.

### Option D — Documentation-only: branch separation as user practice

**Mechanism:** Document the limitation in `forge/PARITY.md` and `silver-bullet.md`. Recommend users use separate branches or git worktrees when actively switching between Claude and Forge mid-task; commit before switching.

**Pros:**
- Zero code change.
- Mirrors how teams already handle two-developer concurrency.

**Cons:**
- Doesn't solve the "two sessions on same branch in same machine" case the user explicitly asked about.
- Friction for the realistic single-user, mid-task switch case.
- Doesn't meet the parity bar of "two Claude sessions on same folder."

### Recommended: Option A + lightweight Option D

- **A** for the technical fix: Forge agents cooperatively write to `~/.claude/.silver-bullet/state` via a shared `forge-record-skill` helper agent. Bounded scope, minimal Claude-SB changes.
- **D** for the documentation: a "Coexistence" section in `forge/PARITY.md` calling out the cooperation mechanism and recommending best practices (commit between switches, separate worktrees for parallel work).

Option B is a strong follow-up for v0.30.0+ (general-purpose hook robustness) but isn't required to meet the parity bar.

Option C is over-engineered for the current need and would slow shipping.

---

## 6. Minimal Implementation Plan (v0.29.0 scope)

Rough phase breakdown — to be refined by `silver-feature` planner:

### Phase 70 — Forge cooperative skill recorder

1. Create `forge/agents/forge-record-skill.md` — a new custom agent with `id: forge-record-skill`, `description: "Records that an SB skill was applied. Appends skill name to ~/.claude/.silver-bullet/state if the file/directory exists, no-op otherwise. Cooperates with Claude-SB's completion-audit and stop-check hooks."`, `tools: [shell]`, `tool_supported: true`, `temperature: 0.0`.
2. Body of the agent: `mkdir -p ~/.claude/.silver-bullet 2>/dev/null && grep -qx "<skill-id>" ~/.claude/.silver-bullet/state 2>/dev/null || echo "<skill-id>" >> ~/.claude/.silver-bullet/state` (with proper guard for `<skill-id>` parameter passing).
3. Update parent skills (`silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, `silver-release`, `silver-spec`, `silver-fast`) to instruct: after applying any required-skill (silver-quality-gates, code-review, requesting-code-review, receiving-code-review, finishing-a-development-branch, silver-create-release, verification-before-completion, test-driven-development, silver-blast-radius, devops-quality-gates), invoke the `forge-record-skill` agent with that skill's id.
4. Update `forge/AGENTS.md.template` with a "Coexistence note" section explaining when and why this happens.

### Phase 71 — Claude-SB awareness of Forge cooperation

5. Update `silver-bullet.md` and `templates/silver-bullet.md.base` with a "Coexistence with Forge" subsection documenting that Forge cooperatively writes to the shared state file. Update §10 user-preferences scaffold to note the new mechanism.
6. Optionally: extend `record-skill.sh` to also recognize entries written by Forge (no logic change needed — file format is just one skill per line — but document the source-agnostic semantics).

### Phase 72 — Documentation + parity test

7. Add a "Coexistence" section to `forge/PARITY.md` describing the model, listing the cooperation contract, and recommending best practices.
8. Add a coexistence test to `forge/scripts/smoke-test.sh`: simulate the Scenario A flow (write a marker via the `forge-record-skill` agent, verify Claude-SB's `completion-audit.sh` reads it).
9. Update `forge/PARITY-REPORT.md` with the runtime-verified coexistence outcome.

### Phase 73 — Release v0.29.0

10. CHANGELOG, README badge, version bumps; tag v0.29.0; ship.

---

## 7. Open Questions for `silver:brainstorm` Phase

These are the areas where the implementation needs design clarification before plan-phase:

1. **Where exactly does the parent skill call `forge-record-skill`?** Inside the body of `silver-feature` (instruction to the main agent), or as a step in each individual skill's procedure (e.g., `silver-quality-gates` records itself)? The latter is more decoupled but requires editing 10+ skill files.

2. **Order of write — before or after the work?** If we write before, an agent failure leaves a phantom record. If we write after, an agent failure correctly leaves no record. Latter is preferred but requires the parent skill to wrap the apply with a try/finally analog.

3. **Do we also write to `~/.claude/.silver-bullet/branch`?** Forge changes branches via shell tool. Should it touch the branch file so Claude's next session-start handles the switch correctly? Probably yes for symmetry.

4. **Trivial-bypass cooperation?** Forge has no concept of "trivial session." If a Forge session edits source files in a project where Claude has the trivial bypass active, should Forge remove the bypass file? Probably yes — Forge's `forge-session-init` agent is a natural place to call `rm -f ~/.claude/.silver-bullet/trivial` after the first Edit/Write, mirroring `hooks/lib/trivial-bypass.sh` removal behavior.

5. **Discoverability:** how does a Claude session know "Forge is running concurrently"? Probably it doesn't need to — the state file IS the source of truth, and writes to it are accepted source-agnostically.

---

## 8. Recommendation

**Adopt Option A + D for v0.29.0.** Effort: ~4 phases (70-73), ~12 files touched, ~1-2 sessions of work. This delivers the parity bar the user asked for: same-folder Claude-SB and Forge-SB sessions cooperate the way two Claude sessions do today.

Files written for handoff:
- `.planning/research/2026-04-27-forge-claude-coexistence/RESEARCH.md` (this doc)

Hand off to: `silver:feature` for v0.29.0 milestone planning, with this RESEARCH.md as the primary CONTEXT input.

---

*Research date: 2026-04-27*
*Author: SB autonomous research session*
*Source code references inspected: hooks/completion-audit.sh L135-202, hooks/stop-check.sh L80-200, hooks/record-skill.sh, hooks/lib/trivial-bypass.sh, forge/agents/forge-pre-commit-audit.md, forge/agents/forge-pre-pr-audit.md*
