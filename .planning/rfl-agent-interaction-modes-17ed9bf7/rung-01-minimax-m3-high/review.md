# Rung 1 review — MiniMax M3 High style (OpenCode)

**Plan:** [agent_interaction_modes_17ed9bf7.plan.md](/Users/shafqat/projects/silver-bullet/repo/.cursor/plans/agent_interaction_modes_17ed9bf7.plan.md)

**Method:** `/silver:agent-opencode` via `scripts/agent-opencode/invoke.sh` first; harness refused non-`mimo-v2.5`. Native fallback `opencode run -m opencode-go/minimax-m3 --variant high --auto` (exit 0) ADDed I-12–I-17.

**STATUS:** review-complete

## Method evidence

```
ERROR: OPENCODE_MODEL must be mimo-v2.5 (got minimax-m3)
invoke_exit=2
```

Source: `scripts/lib/opencode-cli.sh` `agent_opencode_pin_mimo_model_env` (from `main`).
`--mode non-interactive` is **accepted** by today's parser and stored in existing permission `MODE` (not rejected).

Native MiniMax log: `opencode-run-minimax-m3-high.log`.

## ISSUES

### I-1 HIGH — `--mode` collides with live `permissive|strict`

Plan D2 makes `--mode auto|interactive|non-interactive` the canonical flag on every `invoke.sh` + `*-delegate.sh`.

Current `main` already uses `--mode permissive|strict` on Claude/Codex/Cursor/OpenCode delegates and passes it to `agent_invoke "$MODE"`. OpenCode live adapter only special-cases `permissive` (adds `--auto`). `--mode non-interactive` and `--mode auto` parse today and silently smash permission mode.

Plan never mentions `permissive|strict`, never aliases it, never adds `--interaction-mode`. Shipping D2 as written is a breaking collision.

**Fix:** keep `--mode permissive|strict`; add `--interaction-mode auto|interactive|non-interactive` (or `--agent-mode`). Update D2/§6.2/skills.

### I-2 HIGH — D3 “test-fix loops in the same brain” vs NI-prefer

D3 force-interactive includes “test-fix loops in the same brain.”
§4.1 prefer-NI requires “acceptance checkable from git/tests” and “single bounded deliverable.”

Those are the same default coding brief. Classifier will force interactive for almost every implement+test task, contradicting D7 “classifier prefers NI when cheaper.”

**Fix:** drop test-fix-loop from D3 unless a live session or explicit continue/coach signal exists. First implement+test wave stays NI; D4 covers a real miss.

### I-3 HIGH — `events.jsonl` interactive-only vs required in NI

Todo `ctl-and-events`: “Control dir/events.jsonl/ctl.sh only for interactive.”
§5.1 NI outputs include `events.jsonl`. §9 requires `mode_resolved` in both modes.

**Fix:** `events.jsonl` at task root for both modes; `control/` fifos + `ctl.sh` + snapshots interactive-only.

### I-4 HIGH — prior-wave rule sticks `task-id` on interactive forever

§4.1 prior wave (including failed NI about to escalate) force-interactive. After success or escalate, every later invoke on the same id is interactive. No TTL / new-wave reset.

**Fix:** prior-wave forces interactive only for in-progress escalate or alive `session.json`. Successful completion resets.

### I-5 MEDIUM — D1 pin vs D3 “requires interactive”

D1: pin wins. D3: session continuity requires interactive (absolute). Pin + live session is unspecified.

**Fix:** pin always wins; D3 applies only when requested mode is `auto`.

### I-6 MEDIUM — Cursor “interactive” is not §5.2 parent-as-user

§5.2 coaching without a new process vs §7 Cursor conversation-id follow-ups (new process). Current adapter is stream-json + IDE in-session files.

**Fix:** define Cursor as `session` transport (new processes allowed) or `mode-unavailable` until a long-lived CLI exists.

### I-7 MEDIUM — Pi/Cursor `mode-unavailable` skips a working NI path

Classifier can pick interactive first; D6 fail-closed never tries NI. Pi is `pi -p` only.

**Fix:** classified interactive + no TUI → NI with `reason=tui-unavailable` unless interactive was pinned/mandatory.

### I-8 MEDIUM — D7 vs live reliability wrappers

Live NI is invoke → preflight → quota loop → python tail-idle around `opencode run`, not `invoke → delegate → exec`.

**Fix:** D7 forbids interaction wrappers (PTY/fifo/expect/tmux). Allow quota retry, tail-idle, secret scan, log header, optional `monitor.sh`.

### I-9 MEDIUM — classifier signals are not testable

“Likely pickers”, “ambiguous Q&A” have no closed signal list.

**Fix:** regex/phrases + `session.json` fields only; else NI tie-break.

### I-10 LOW — three owners of the interactive loop

Worker may run driver; parent owns fifo; `auto_policy` also waits. Deadlock named, waiter not assigned.

**Fix:** worker owns driver+fifo; parent is the only `send`/`key` client.

### I-11 LOW — precedence vs `--delegation-mode`

CLI vs `SB_AGENT_MODE` vs AF `interaction_mode` vs existing `--delegation-mode` not ordered. `--control-dir` on NI unspecified.

**Fix:** CLI > env > AF > classifier. `--delegation-mode` orthogonal. `--control-dir` on NI = `mode-conflict`.

### I-12 MEDIUM — conflict pairs not enumerated

D2/§12 say conflicts fail but do not list `--mode auto --use-print`, `--mode non-interactive --use-interactive`, `--mode interactive --use-print`.

### I-13 MEDIUM — `--no-escalate` does not unstick prior-wave

`--no-escalate` disables D4 only; §4.1 still force-interactive on reused `task-id`.

### I-14 LOW — event/escalation schemas missing

Event names listed; required fields, log-tail length, `escalation.md` shape not specified.

### I-15 LOW — `monitor.sh` vs D7

§5.1 optional monitor is a second process. Allow as read-only log tail or drop from NI.

### I-16 MEDIUM — `events.jsonl` unredacted

Snapshots redacted; `assistant`/`tool_use` payloads are not. Brief secret-scan does not cover the stream.

### I-17 LOW — `--control-dir` on NI

Fail `mode-conflict` (D6 fail-closed); do not ignore.

## Non-issues (do not fix)

- Two modes, auto default, one NI→interactive escalate, no silent IX→NI, honest `mode-unavailable`, AF field, implementation deferred — sound.
- Keeping Claude expect / Codex Python as the single existing PTY driver — correct.
- OpenCode NI = `opencode run` — matches current default.
- MiMo pin remaining on OpenCode adapters — out of scope for this spec.

## Gate

Parent (coordinator) decides accept/fix. This rung did not edit the plan.


---

# rung-01-minimax-m3-high — additional raw findings (this submission, 2026-08-23)

**Author:** MiniMax M3, reasoning=high
**Method:** Plan re-read + filesystem verification of every path the plan claims exists or will create.

## Scope note

Prior review (I-1 through I-17) above is retained. Findings below are **additive** — they fill gaps the prior review did not surface, with a focus on the plan's verifiable file references and surface completeness. Some overlap is acknowledged at the bottom.

## New findings

### BLOCKER

#### B1 — §1 "Problem" cites scripts/files that do NOT exist in the repo (false premise)
**Sections:** §1 Problem (lines 32-44); §3 D9; §5.1 outputs; §6.3 control dir; §7 adapter matrix; §8 orchestrator/worker; §10 implementation plan.

**Issue:** §1 claims "the five host skills already mix TUI and headless execution, but as asymmetric fallbacks" and cites specific existing files:

| Cited path | Status |
|------------|--------|
| scripts/claude-interactive-invoke.expect | MISSING |
| scripts/codex-interactive-invoke.py | MISSING |
| scripts/agent-cursor-delegate.sh | MISSING |
| scripts/lib/agent-delegate-common.sh | MISSING |
| skills/silver-agent-worker/SKILL.md | MISSING |
| templates/orchestrator-workers/AGENT-DELEGATE.md | MISSING (no templates/ dir) |
| docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md | MISSING (no docs/skills/) |
| scripts/sync-codex-package.sh | MISSING |

Repo-wide scan confirmed:
- **0** SKILL.md files in skills/, agents/, host-bundles/, plugins/.
- **0** .py source files outside __pycache__/ and .planning/ (only 3 probe scripts).
- scripts/lib/ contains only cursor-sb-agents/ with **compiled .pyc only**, no source — closest equivalent to a Cursor adapter, but under a different path with no source.
- host-bundles/ has only codex/ and cursor/ subdirs (no claude/, opencode/, pi/ host bundles).
- No templates/ directory at repo root; no docs/specs/ directory.

**Impact:** The §1 framing ("promote asymmetric fallbacks to first-class modes") is **unverifiable in the current repo state** — the asymmetric fallbacks the plan names do not exist. The spec is greenfield work framed as refactor. §10 "implementation plan" therefore either (a) creates these files from scratch (changing the spec's narrative) or (b) leaves §1 factually wrong. Without resolution, the spec is internally incoherent — D7/D9 cannot reference files that don't exist.

**Note for triage:** this is independent of I-1 (which addresses *flag* collision); B1 is about *file* existence. Both are needed for the spec to ship.

### MAJOR (additive)

#### M-A1 — auto_policy defined in §8 but no parent-set surface
**Sections:** §8 (lines 296-299); cf. §6.1, §6.2, §10.
§8 defines auto_policy ∈ {parent, brief_only, supervised}, default supervised. §6.1 (slash args), §6.2 (CLI + env), and §8's own directive-gain list (interaction_mode, max_turns, attach, no_escalate) do **not** enumerate how a parent passes it. Decision needed: CLI flag, env var, AF directive field, or hardcoded default.

#### M-A2 — hook-trust failure_class in §7 Codex absent from §9 catalog
**Sections:** §7 Codex (line 285); §9 (line 310).
§7 Codex declares "Extra fail class hook-trust." §9's new failure_class set is mode-unavailable | mode-conflict | max-turns | escalate-unavailable — hook-trust is missing. State whether new or pre-existing; if new, §9 is incomplete.

#### M-A3 — Per-host auth + log-floor values not enumerated for 4 of 5 hosts
**Section:** §7 adapter matrix.
Auth listed only for Claude (OAuth/Keychain) and Cursor (Keychain only); Codex and Pi omit. Log floor 2048 B given only for Cursor; §9 generic "log floor" has no per-host value for the other four. §12 acceptance criteria reference "log floor" without per-host values — tests cannot assert uniformly.

#### M-A4 — Pi "Same model pin" reference is dangling
**Sections:** §7 Pi (line 288); cf. §5.1, §7 OpenCode.
§7 Pi ends "Same model pin." §5.1 names Pi as --provider opencode-go --model mimo-v2.5; §7 OpenCode says "Model pin opencode-go/mimo-v2.5." Ambiguous whether "Same model pin" refers to §5.1's mimo-v2.5 or back-references the previous host.

#### M-A5 — --allow-mode-fallback semantics + audit trail undefined
**Sections:** §3 D6 (line 78); §6.2 (line 251); §12 acceptance.
D6 says "FAIL failure_class=mode-unavailable unless --allow-mode-fallback is set (audited)." §6.2 lists the flag but does not specify: (a) what "audited" means (where? what fields?), (b) target mode (the originally-requested mode or auto-resolved?), (c) whether the fallback is itself pinned (no second loop). §12 has no acceptance row for this path.

#### M-A6 — reply.fifo purpose vs events.jsonl event stream unclear
**Sections:** §6.3 (line 271); §5.2 sequence diagram.
§6.3 lists both cmd.fifo and reply.fifo while events go to events.jsonl. Plan never says what flows through reply.fifo vs events.jsonl. ctl.sh send|key|snapshot implies snapshot is request/response, but this is not stated. Driver implementer will either dual-write or leave one unused.

#### M-A7 — Directive-field parity gap: AF lacks allow_mode_fallback, control_dir, auto_policy
**Sections:** §6.2 vs §8.
§6.2 lists --allow-mode-fallback, --control-dir as CLI flags. §8 directive-gain fields list only interaction_mode, max_turns, attach, no_escalate. AF-AGENT-DELEGATE seed cannot carry the full parent CLI intent.

#### M-A8 — Env-var surface incomplete in §6.2
**Sections:** §6.2 (line 256); cf. D8 (line 85), §4.2 step 5 (line 149).
§6.2 env list says only SB_AGENT_MODE=auto|interactive|non-interactive. SB_AGENT_MODE_ATTACH (D8) and SB_AGENT_NO_ESCALATE (§4.2 step 5) are referenced in prose but not enumerated in §6.2.

#### M-A9 — SB_AGENT_MODE env var pin status unspecified
**Sections:** §6.2; cf. D1, D2.
D1 pins --mode interactive|non-interactive (or legacy flags) to skip classify/escalate. §6.2 says "Env: SB_AGENT_MODE=... (CLI wins)" — does **not** say whether env var alone counts as a pin. If env is a pin, SB_AGENT_MODE=non-interactive suppresses classify/escalate. If not, env is just a hint. Plan does not pick.

### MINOR (additive)

#### m-A1 — Resolver mermaid omits legacy-flag and --allow-mode-fallback branches
**Section:** §4 flowchart. Mermaid shows only the --mode three-way pin; D2 legacy flags (pins) and D6 --allow-mode-fallback are off-graph.

#### m-A2 — §5.2 step 7 phrasing: "child must not tell the user done"
**Section:** §5.2 Parent interaction loop (line 216). In parent-as-user model, parent IS the user. Likely intended "parent must not accept child 'done' claims without artifact verification."

#### m-A3 — §11 risks "CPTY" looks like a typo
**Section:** §11 Risks (line 334). "**CPTY vs Cursor Task:** parent must hold the driver subprocess..." Likely intended "PTY" or "Cursor PTY."

#### m-A4 — §5.2 idle-sec references "existing quiet/idle env" without naming it
**Section:** §5.2 Hard limits (line 224). Plan should name the env var so implementer/tester can find it.

#### m-A5 — §7 routes asymmetry /silver:* vs $silver:* not explained
**Section:** §7 Claude (line 284) vs Codex (line 285). Claude "Routes: /silver:*"; Codex "Routes: $silver:*". Difference (slash command style vs dollar-prefixed variable) unexplained.

#### m-A6 — §5.1 outputs session.json ambiguous for NI re-use
**Section:** §5.1 (line 183). Two open questions: (a) does classifier (§4.1 force-interactive bullet 1) inspect session.json from a prior NI run and treat its reusable id as live-session signal? (b) should NI itself write session.json when it returns an id, or only interactive runs?

#### m-A7 — §10 step 9 lists "five SKILL.md (auto default, session rule, escalation, lightweight)" without naming them
**Section:** §10 implementation plan (line 324). Five host skill files (Claude/Codex/Cursor/OpenCode/Pi) not enumerated.

#### m-A8 — §3 D3 "attach later" wording may be misread as forbidding escalation
**Sections:** §3 D3 (line 76); §4.2 (line 147). "Starting NI and hoping to 'attach later' is forbidden." D4 escalation is *not* "attach later" (interactive retry with NI artifacts as context), but a quick reader could lump them together. A clarifying sentence ("escalation under §4.2 is the only legitimate way to follow an auto-NI run") would help.

### NIT (additive)

#### n-A1 — §7 Pi/OpenCode share same model namespace; relationship not documented
**Section:** §7 Pi + OpenCode (lines 287-288). Pi uses --provider opencode-go --model mimo-v2.5; OpenCode uses opencode-go/mimo-v2.5. Worth a one-line note that opencode-go/mimo-v2.5 is the delegated route, not the native mimo namespace.

#### n-A2 — §10 step 9 "catalog AF-AGENT-DELEGATE" without file path
**Section:** §10 (line 324). Where does the AF catalog live? Step 10 names the durable spec (docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md); the catalog is left ambiguous.

## Overlap with prior review (informational, not new)

The following items I considered are already covered by prior I-1 through I-17:
- M-A9 overlaps I-11 precedence vs --delegation-mode
- M-A8 overlaps I-11 env-var surface
- m-A6 overlaps I-4 prior-wave sticky
- m-A1 overlaps I-12 conflict-pairs / surface completeness

Retained here because they reinforce the same surface-completeness theme from a different angle. No new substance.

## Summary counts (this submission, additive)

| Severity | New | Already in I-1..I-17 |
|----------|-----|----------------------|
| BLOCKER  | 1   | 0 (B1 independent of I-1) |
| MAJOR    | 9   | ~3 reinforce prior   |
| MINOR    | 8   | ~2 reinforce prior   |
| NIT      | 2   | 0                    |
| Total new | 20 |                       |

Single BLOCKER (B1) is the highest-impact: it invalidates the plan's §1 narrative and §10 file references. All other findings are clarifications / surface-completeness.

**Status:** review-only, no plan edits, no triage applied.
