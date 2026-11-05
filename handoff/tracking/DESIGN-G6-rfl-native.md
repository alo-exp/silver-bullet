# DESIGN G6: review-fix ladder on native host subagents

Reviewer: Opus design pass, 2026-11-05. Base read: `claude/optimistic-ramanujan-tccfud` at c591ebb. Cursor removal read from `fix/HC-remove-cursor` (7d62aa3).
Binding decisions (DECISIONS.md): Cursor is no longer a host (HC). The multi-AI skills keep `cursor-agent` as a backend. The RFL is redesigned now, in this PR, to use only the host's native subagents (Claude Code `Agent`/`Task`, Codex `spawn_agent`). The user chose this over "native + Cursor CLI optional" and over "multi-AI backends".

What "native only" means, in plain terms: on Claude Code every rung is a Claude model, and on Codex every rung is an OpenAI model. The ladder no longer sends a rung to another vendor's CLI (agent-codex from Claude, agent-claude from Codex, Pi, OpenCode, Gemini, Grok). Cross-vendor review stays available through `silver-multi-ai-task`.

Line references are to c591ebb unless marked "HC" (as they read on fix/HC-remove-cursor).

---

## 1. Current architecture

### 1.1 Pieces and size

| Layer | Files | Lines |
|---|---|---|
| Skill | `skills/silver-review-fix-ladder/SKILL.md` (+ `agents/openai.yaml`) | 619 |
| CLI entry | `scripts/review-fix-ladder.py` (wrapper), `scripts/_review_fix_ladder_impl.py` (resolver + quota/launch CLI), `scripts/rfl-assert-advance.sh` | 77 + 907 + 7 |
| Python libs | `scripts/lib/rfl_launcher_policy.py` (811), `rfl_policy_c.py` (852), `rfl_quota_retry.py` (852), `rfl_quota_claude5h.py` (250), `rfl_issue_ledger.py` (330) | 3095 |
| Hooks | `hooks/review-fix-ladder-guard.sh` (141), `hooks/lib/review-fix-ladder-state.sh` (470), `hooks/rfl-policy-c-gate.sh` (96), `hooks/lib/rfl-policy-c-assert.sh` (94), `hooks/rfl-quota-retry-due.sh` (105), RFL block in `hooks/stop-check.sh:172-188` | 906 |
| Templates | `templates/rfl-review-brief.md`, `templates/orchestrator-workers/REVIEW-TRIAGE.md:27-35` | |
| Tests | 15 python/hook/script files (~6,300 lines) + 3 live tests and 2 live libs (~1,500 lines) | ~7,800 |

External-delegation stack that the ladder calls: `scripts/agent-{claude,codex,opencode,pi}-delegate.sh`, `scripts/agent-*/{invoke,env,lib,monitor,preflight}.sh`, `scripts/lib/agent-delegate-common.sh`, `agent-host-exec.sh`, `agent-mode.sh`, `agent-pi-quota-retry.sh`, `hooks/agent-delegation-guard.sh` + `hooks/lib/agent-delegation-state.sh`. These scripts also serve the user-facing `/sb:agent-*` skills, AF-AGENT-DELEGATE, `silver-clarify --auto`, and the multi-AI OCG backend (`skills/silver-multi-ai-task/scripts/live_dispatch.py:62` calls `scripts/agent-opencode-delegate.sh`). They therefore **survive** the RFL redesign.

### 1.2 What a ladder run does today (skill contract)

1. **Scope lock** (`SKILL.md:211-234`), then a **charter** with verification signals (`:236-254`).
2. **Resolve the ladder**: `python3 scripts/review-fix-ladder.py --json [--host]` (`:256-266`).
   - Cursor: `resolve_cursor_ladder` (`_review_fix_ladder_impl.py:548-565`) builds `selected_models × effort_levels` (default `composer-2.5`, `grok-4.5` × medium/high/xhigh, `:25-57`), each rung enriched with an `sb-<model>-<effort>` custom-subagent name, a `model_param` and the subscription-first fields (`:369-402`). It also checks that the `sb-*` agent files exist in `~/.cursor/agents` (`:405-485`).
   - Codex: `codex_dynamic_rungs` from `$CODEX_HOME/models_cache.json` (`:506-537`), else `gpt-5.4`/`gpt-5.5` × low..xhigh (`:540-541`).
   - Claude: fixed fallback `claude-sonnet-4-6`, `claude-opus-4-7`, `claude-opus-4-8` × medium/high/xhigh, 9 rungs (`:61-65`, `:544-545`, `:585-591`).
   - Host detection `detect_host` (`:112-137`) still knows `cursor`.
3. **Policy E** approval: the parent writes `RUNG-PROMPT-APPROVAL.md` with `approved: yes` itself (`:132-151`).
4. **Per rung** (`:332-393`): `rung_N_review` (one review-only subagent) → `rung_N_triage` (parent, Policy C artifact via `--write-policy-c` / `--assert-policy-c`) → `rung_N_file_valid_issues` (`/sb:add`) → `rung_N_fix_parallel` (parent applies ACCEPTs with Edit/Write) → `rung_N_verify_1` (read-only subagent) → orchestrator grep of the charter signals → `rung_N_verify_2` on CLEAN → grep → advance.
5. **Policy F**: two consecutive CLEAN reviews per rung before the next model (`:153-175`), tracked as `consecutive_clean_reviews` in `.planning/rfl-<id>/LADDER-STATUS.json`, incremented by the parent running `--record-rung-review-outcome clean` (`rfl_policy_c.py:199-223`).
6. **Policy G**: the encoder-written brief (`--write-review-brief`, `rfl_issue_ledger.py:311-330`) is the only legal review brief.
7. **Launch failure**: retry once, then skip with `SKIPPED.md`; after the ladder, retry skipped rungs once (`rfl_launcher_policy.py:194-275`). For OpenCode/Pi hosts the second failure substitutes Cursor Grok 4.6 High (`:16-17`, `:236-253`).
8. **Policy D** ladder matrix and `--mark-ladder-status completed|aborted` (`rfl_quota_retry.py:231-267`).

### 1.3 Launcher policy: subscription-first, quota, retry

- **Subscription-first** (Cursor host only): GPT and Claude rungs must first run through the external CLIs `scripts/agent-codex/invoke.sh` / `scripts/agent-claude/invoke.sh` (`_review_fix_ladder_impl.py:69-82`, `:148-186`). `decide_launch` (`:228-273`) returns `invoke_subscription` → `accept_subscription` | `cursor_fallback` (quota only) | `fail`. The classifier `classify_subscription_attempt` (`:189-225`) uses `QUOTA_EXHAUSTION_RE`, which ends with a bare `\bquota\b` (`:87-99`). The wrapper `review-fix-ladder.py:42-61` bolts `default_agent_host_route` onto that payload.
- **Default host routing** (`rfl_launcher_policy.py:29-191`): Grok/Composer → Cursor, GPT → Codex CLI, Claude → Claude CLI, Gemini → gemini-cli/Pi/OpenCode/Cursor, others → Pi/OpenCode.
- **Quota fallback state**: `--mark-quota-fallback` writes `subscription_quota_fallback` into `${SB_RUNTIME_STATE_DIR:-/tmp}/review-fix-ladder-state.json` (`_review_fix_ladder_impl.py:276-297`); the guard then lets a GPT/Claude `sb-*` Cursor Task through (`review-fix-ladder-state.sh:258-290`).
- **Quota windows and scheduled retry**: `classify_quota_window` (`rfl_quota_retry.py:142-193`, monkey-patched by `rfl_quota_claude5h.py:127-138`, installed on import) decides `should_schedule`. `schedule_quota_retry` (`:290-367`, wrapped by `rfl_quota_claude5h.py:208-234`) writes `quota-retry-schedule.json` and **arms an OS timer**: `at` with a `subprocess.list2cmdline` command string (`:546-591`) or a launchd plist in `~/Library/LaunchAgents` with a `Year` key that is never unloaded (`:593-653`). The timer runs `--quota-retry-wake` (`wake_due_jobs`, `:762-839`), which writes `QUOTA-RETRY-EXECUTE.md` or `QUOTA-RETRY-ASK.md` and emits a `hook_context` that `hooks/rfl-quota-retry-due.sh` injects on every SessionStart and UserPromptSubmit (`:841-852`, hook `:69-104`).
- The same resolver is used outside the ladder: `agent-delegate-common.sh:80-90` (`--classify-quota-window` for short-retry veto) and `agent-pi-quota-retry.sh:104-145` (classify + `--schedule-quota-retry` for Pi 5-hour caps, run dir defaulting to the SB install root, R4-24).

### 1.4 The state machines and the hooks that enforce them

There are **two unlinked state machines**:

**(a) Session guard state** `${SB_RUNTIME_STATE_DIR:-/tmp}/review-fix-ladder-state.json` (`review-fix-ladder-state.sh:8-10`; note the world-shared `/tmp` default). Phases `review → triage → file_valid_issues → fix_parallel → verify_1 → orchestrator_grep_1 → verify_2 → orchestrator_grep_2 → next rung`.
- Activation: any Skill invoke of the ladder calls `sb_rfl_activate 1` and **resets** the run, including `compliance_stop` (`:463-470`; guard `:56-61`, `:80-87`).
- Activation runs the **project's** `scripts/review-fix-ladder.py --host cursor` (`:61-70`, R4-09).
- Spawn validation `sb_rfl_validate_task_spawn` (`:292-425`) infers the phase from **prompt keywords** (`:222-256`), requires `subagent_type == sb-*` name, denies GPT/Claude `sb-*` Tasks without the quota fallback, and requires `tool_input.readonly == true` for verify passes (`:384-387`, `:406-409`). `readonly` is a Cursor Task parameter; Claude Code's Agent tool has no such field, so **every verify spawn on Claude is denied and sets compliance_stop**.
- Advancement `sb_rfl_advance_after_task` (`:427-456`) moves phases on PostToolUse Task by prompt keywords. It needs a *Task* to leave `triage` and `fix_parallel`, while the skill says the parent triages and fixes in-session (`SKILL.md:13`, `:386-388`): the machine and the skill disagree.
- `orchestrator_grep_*` denies every Task (`:411-414`) until `sb_rfl_mark_orchestrator_grep` runs, which is only called from the PreToolUse **Bash** branch (`review-fix-ladder-guard.sh:109-118`); hooks.json never routes PreToolUse Bash to this hook (registrations at `hooks.json:121,138,384,418`). Ladders wedge at `orchestrator_grep_1` (R4-16). The Edit/Write verify-phase deny (`guard:119-127`) is unreachable for the same reason.
- PM filing is detected by any Bash containing `sb:add` (`:458-461`).
- Every deny sets `compliance_stop`, after which all Tasks are denied (`guard:91-94`, `:140-141`) until the skill is re-invoked, which resets the ladder to rung 1.

**(b) Durable run state** `.planning/rfl-<id>/LADDER-STATUS.json` (`rfl_policy_c.py:96-108`): `status`, `current_rung`, `current_phase`, per-rung `consecutive_clean_reviews`. Written by the parent through the encoder CLI. Read by:
- `hooks/rfl-policy-c-gate.sh` (PreToolUse Task|Subagent|Agent, Skill, Bash, and Stop; `hooks.json:127,144,348,566`). It activates when any `.planning/rfl-*/LADDER-STATUS.json` greps as `"status":"active"` (`rfl-policy-c-assert.sh:19-30`), filters Bash by a keyword regex on the raw command (`gate:56-61`, quoting defeats it, R4-15), infers the action from prompt text (`assert:32-49`), runs the resolver preferring the **project copy** (`assert:4-17`, R4-09) and **fails open** on empty output (`assert:55-67`, R4-15).
- `hooks/stop-check.sh:172-188` runs the same assert again on every Stop (duplicate of the gate's Stop registration).
- `assert_rfl_advance` (`rfl_policy_c.py:721-850`) checks Policy C artifacts, canonical verify filenames, BLOCKED/SKIPPED/STOP artifacts and the streak (`:234-267`). The streak is self-reported: two `--record-rung-review-outcome clean` calls satisfy it (R4-15). `_read_json` catches `OSError/ValueError` but not `RecursionError` (`:39-46`).

**Delegation state** `${SB_RUNTIME_STATE_DIR}/agent-delegation-active.json` (`agent-delegation-state.sh:4-6`) is written by the external delegates and makes `agent-delegation-guard.sh` deny parent edits to the delegated ownership paths (block on Claude/Codex, advise on Cursor; HC removes the advise tier). The ladder uses it only indirectly, when a rung runs through `/sb:agent-*`.

**Worker identity**: guards skip "worker sessions" via `sb_orchestrator_is_worker_session` (`orchestrator-parent.sh:20-50`), a single global marker with a TTL written by `subagent-start.sh`. While any subagent runs, the parent also looks like a worker (R4-02, owned by G5). The redesign must not rely on it.

**Audit**: denies go to `sb_hook_audit_record` (`review-fix-ladder-guard.sh:39-41`, `rfl-policy-c-gate.sh:76-78`). Run evidence is the per-rung artifacts.

### 1.5 Cursor-specific versus host-neutral

| Cursor- or external-CLI-specific (delete) | Host-neutral (keep, harden) |
|---|---|
| `resolve_cursor_ladder`, `CURSOR_SB_AGENTS_DEFAULTS`, Grok/Composer slugs, `resolve_model_param`, `enrich_cursor_sb_rung`, `sb-*` naming, agent-file probes (`_impl.py:25-57`, `:140-146`, `:310-485`, `:548-565`) | Codex dynamic rungs from `models_cache.json` (`:506-541`) |
| Subscription-first: `SUBSCRIPTION_PLANS`, `subscription_*`, `classify_subscription_attempt`, `decide_launch`, `mark_quota_cursor_fallback`, CLI flags `--decide-launch --classify-quota --mark-quota-fallback --subscription-* --check-agents` (`:69-109`, `:148-297`, `:674-717`, `:833-870`); wrapper shim `review-fix-ladder.py:42-61` | Policy C artifacts, validation and rendering (`rfl_policy_c.py`), issue ledger and review brief (`rfl_issue_ledger.py`), table renderers (`rfl_launcher_policy.py:327-466`) |
| Host routing `AGENT_HOST_CATALOG`, `USER_AGENT_ALIASES`, `model_family`, `default_agent_host_route`, `attach_default_host_route`, Grok substitution (`rfl_launcher_policy.py:15-191`, `:236-253`, `:469-476`) | Launch retry-once-then-skip and post-ladder retry (`next_launch_action` minus Grok, `skip_retry_artifact`) |
| Guard: `sb-*` subagent_type checks, subscription deny, `readonly` Task flag (`review-fix-ladder-state.sh:258-290`, `:320-409`) | Policy F streak, verify overlay, Policy D matrix, `LADDER-STATUS.json` |
| Skill "Host Delegation Notes" (`SKILL.md:416-493`): Cursor routing, subscription-first, OpenCode Go, Grok substitute, `install-cursor-sb-agents.sh` (already deleted on HC) | Skill Policies A-G, scope lock, charter, STOP conditions, Templates A/B |
| Live tests `tests/live/test-live-review-fix-ladder-*.sh`, `tests/live/lib/review-fix-ladder-common.sh` (call `cursor_task_slug`, which no longer exists) | Quota-window **classification** (`classify_quota_window`, `parse_reset_seconds`) |
| OS timers, wake jobs, ASK/EXECUTE injection (`rfl_quota_retry.py:290-852`, `rfl_quota_claude5h.py` scheduling, `rfl-quota-retry-due.sh`): not Cursor-specific, but designed for external CLIs whose quota differs from the parent's. A native subagent shares the parent's account, so they lose their purpose. | |

---

## 2. Findings in scope (package G6)

Legend: **R** = fixed by the redesign. **I** = fixed independently (the code survives the redesign). **M** = moot because Cursor is gone (only parts).

| Id | Sev | Subject | Disposition | Where it lands |
|---|---|---|---|---|
| R4-09 | crit | Hooks execute the project's `scripts/review-fix-ladder.py` on SessionStart, prompts, Task/Skill and Stop | **R**. Hooks only run the plugin's own copy, located relative to the hook file, with `python3 -I`. A run is "live" only when this session started or resumed it (runtime pointer), so a repo-shipped `.planning/rfl-*` is inert. The `orchestrator-state.sh:301-310,435-441` part (`scripts/workflows.sh`) is G5's file: hand it to G5 with a note. | G6a |
| R4-10 | med | Repo text (`QUOTA-RETRY-ASK.md`, job fields, project `docs/apo-catalog.json`) injected as SB instructions | **R** for the RFL half: ASK/EXECUTE and the UserPromptSubmit injection are deleted; the only SessionStart notice is a fixed template whose fields (run id, rung index, ISO time) are validated against `^[A-Za-z0-9._:-]{1,80}$`. The `orchestrator-scheduler.sh:27-43` catalog half is **I**, a one-line "plugin catalog unless the project is the plugin repo" change; take it in G6a with G5's agreement, since G5 owns that file. | G6a (+G5 coordination) |
| R4-15 | med | Policy C gate escapable (quoted Bash, `aborted` ungated, fail-open asserter, `RecursionError`, self-reported streak, self-declared skip) | **R**. No Bash keyword gate. All transitions go through the encoder, which checks ordering. Abort needs a user-typed `RFL ABORT <run-id>` token. Asserter errors fail closed while a run is live. JSON reads are size- and depth-bounded. The streak counts only **captured** CLEAN reviews at the current worktree fingerprint. A skip requires two recorded launch failures with captured error text. | G6a |
| R4-16 | high | Guard wedges at `orchestrator_grep_1`; re-invoke resets ladder and clears STOP; phases forgeable | **R**. Phases are driven by encoder commands (`--run-signals` runs the charter signals itself), not prompt or Bash keywords. Skill invoke never resets a live run. A STOP is cleared only by re-running the failed phase on the same rung. Tests replay only events that `hooks.json` registers. | G6a |
| R4-25 | low | `at` command built with `list2cmdline`; launchd plist with `Year`, never removed | **R** (deleted). Migration removes leftover `dev.alolabs.sb.rfl-quota-retry.*` plists. | G6a |
| R4-20 | med | Any failing run mentioning 429/quota/token plan is re-run up to 5 times | Split. **R/M**: the RFL `QUOTA_EXHAUSTION_RE` bare `quota` Cursor-fallback half is deleted. **I**: `agent_delegate_is_quota_error` (`agent-delegate-common.sh:74-77`) and the five delegate retry loops classify only provider error lines via the shared classifier; retries become opt-in for side-effecting tasks (`agent-cursor-delegate.sh` is gone on HC, **M**). | G6a (classifier contract) + G6b |
| R4-11 | high | Claude delegation rewrites global `~/.claude.json` non-atomically, wipes on parse error, grants persistent trust | **I**. Default `SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=0`; seed only in the ephemeral `CLAUDE_CONFIG_DIR`; if the global path is ever used: abort on parse error, temp file + `os.replace`, backup. | G6b |
| R8-15 | med | Same as R4-11, plus Codex `CODEX_BYPASS_HOOK_TRUST`/`CODEX_AUTO_TRUST_HOOKS=1` defaults | **I** (dedupe with R4-11 and R4-23). | G6b |
| R4-23 | med | Delegated children run with host safety off by default (Codex hook-trust bypass, full access) | **I** for Claude/Codex/OpenCode/Pi: hook-trust bypass default off; strict mode never adds bypass flags; strict is the default when the work dir is not the current project. Cursor `--trust --force --yolo`: **M** (HC removed it from `agent-host-exec.sh`). | G6b |
| R4-21 | med | PTY timeout SIGTERMs only the leader, waits forever | **I**. `killpg` TERM, bounded `WNOHANG` poll, `killpg` KILL, close master fd. | G6b |
| R4-22 | low | `agent-mode/ctl.sh` blocks on FIFO open forever | **I**. `O_WRONLY|O_NONBLOCK` retry on `ENXIO` with a deadline, then clear `O_NONBLOCK`; same in `agent-mode.sh:1062-1071` and `mock-interactive.py`. | G6b |
| R4-24 | low | Pi continue hops unbounded; `.pi-fresh-rewrite.*` left in repo; quota state written into SB install root; two `should_continue` definitions | Split. **R**: the Pi quota *scheduling* is deleted with the scheduler, so nothing is written to the install root (G6a, `agent-pi-quota-retry.sh`, which also keeps the single `should_continue`). **I**: continue hops through the zero-byte guard with a timeout, rewrite dir under `TMPDIR` with a trap (G6b, `agent-host-exec.sh`). | G6a + G6b |
| R4-31 | low | Redaction misses Bearer/github_pat_/xoxb-/AKIA; raw log on disk before redaction; Codex `auth.json` copy survives; brief in argv | **I**. | G6b |
| R4-32 | low | Delegation state/evidence JSON built by printf/heredoc | **I**. `jq -n --arg` / `json.dumps` everywhere; validate `task_id` `^[A-Za-z0-9._-]{1,64}$`; drop the no-jq writer in `agent-delegation-state.sh:57-60` (jq is a required prerequisite). | G6b |
| R8-14 | med | `SB_AGENT_PI_DELEGATE` is both flag and path override | **I**. Rename the override to `SB_AGENT_PI_DELEGATE_SCRIPT`, require an absolute executable path. | G6b |
| R8-26 | low | Four diverged monitor copies; bare `auth` signal | **I**. One `scripts/lib/agent-monitor.sh` with per-host pattern tables; the four `monitor.sh` files become 3-line shims (net deletion). | G6b |
| R10b-05 | med | Delegates need `tests/live/agents/<host>/agent.sh`, not shipped in the Codex package | **I**. Move the production half of each adapter into `scripts/lib/agent-adapters/<host>.sh` (shipped), leave test-only bits in `tests/live`. Cursor half: **M**. | G6b |
| R10b-06 | med | Brief secret scan case-sensitive, misses Bearer, rejects plain-language auth briefs; skill claims about trust are false | **I**. Case-insensitive, value-shaped patterns (prefix tokens, `Bearer\s+\S{16,}`, `KEY=…` with a high-entropy value), no bare-keyword rejection; skill Security tables corrected. RFL no longer sends briefs to external CLIs at all. | G6b |

Related findings owned elsewhere that the redesign touches or makes moot (tell those owners):
- **R4-29** (G5): quota jobs never pruned, ASK re-injected. Moot after G6a deletes the scheduler.
- **R4-02** (G5): global worker marker. G6a stops depending on it for RFL decisions.
- **R10b-08** (H7): RFL triage templates have no data boundary. The redesigned briefs and the result rendering fence reviewer output as untrusted data. Recommend moving R10b-08 into G6a (it edits the same skill text), or H7 rebasing after G6a.
- **R10b-07** (H7): the "on 401 re-route to Grok via Cursor" text in the RFL skill and `silver-clarify/SKILL.md:308`. G6a deletes the RFL text and the `substitute_grok` action; the clarify line must change in the same PR (G6a takes that one line).
- **R4-30 / R15-19** (G5 / H10): tests driving libraries instead of registered events. G6a's new tests follow the rule.

---

## 3. Native design

### 3.1 Principles

1. **One state machine, one writer.** `.planning/rfl-<id>/LADDER-STATUS.json` (schema `rfl.ladder.v2`) is the only run state. Only plugin code writes it: the encoder CLI that the parent runs through Bash, and the hook entry point, which is the same Python module. The session file `${SB_RUNTIME_STATE_DIR}/review-fix-ladder-state.json` is retired.
2. **Tickets, not keywords.** Every subagent launch is preceded by `review-fix-ladder.py --issue-ticket <phase>`. The ticket binds the run, rung, phase, attempt, the role, the model and effort, the exact brief (sha256) and the worktree fingerprint. Hooks and asserts compare against the ticket. They never infer anything from prompt wording.
3. **The subagent cannot write, and the parent cannot forge the result.** Reviewers and verifiers are read-only by construction (tool allowlist on Claude, read-only sandbox role on Codex). Their result is captured by the PostToolUse hook from the host's tool response, not typed by the parent.
4. **The encoder verifies what it can itself.** It runs the charter signals itself, compares worktree fingerprints itself, and checks that the files an ACCEPT row claims to have fixed did change.
5. **Integrity of the status file.** Status and captured results carry an HMAC with a per-project key kept outside the repository. A hand edit fails closed.
6. **Host-neutral core, thin host adapters.** Enforcement that needs only Bash and Stop hooks (both hosts) is the floor. Spawn-time and capture hooks add strength where the host fires them.

### 3.2 Ladder resolution (replaces subscription-first)

`resolve_ladder(host)` with `host ∈ {claude, codex}`. `detect_host` drops `cursor`; HC already coerces a stale `SILVER_BULLET_RUNTIME=cursor` to `claude`.

- **Claude Code**: rungs come from `.silver-bullet.json` → `review_fix_ladder.rungs.claude`. The template default is `[{"model":"sonnet","effort":"high"},{"model":"opus","effort":"high"},{"model":"opus","effort":"xhigh"}]`. It uses **aliases**, so the ladder does not rot as model versions change; full model ids are also accepted. If the host cannot set effort per spawn (see 3.3), rungs that differ only in effort are collapsed and the resolver says so (`effort_applied: false`).
- **Codex**: keep `codex_dynamic_rungs` from `models_cache.json` (host-native list, sorted by priority, mini excluded), else the fallback list. The `rungs.codex` config override wins.
- Payload per rung: `{index, model, effort, roles: {review: "sb-rfl-reviewer", verify: "sb-rfl-verifier"}, spawn: {tool, params}}`. No `subagent_name`, no `subscription_*`, no `delegation`.
- "Subscription-first" disappears: a native subagent always runs on the parent's own account. The only model-selection rule is *use the rung's model on this host*. If the host rejects the model (not on plan, unknown id), that is a launch failure (3.6), never a cross-vendor substitute.

### 3.3 Launching a rung subagent

Common flow for `review`, `verify_1`, `verify_2`:

```
parent (Bash): python3 <plugin>/scripts/review-fix-ladder.py --issue-ticket review --run-dir .planning/rfl-<id>
  -> checks: run live in this session, previous phase complete, Policy C/E/F gates for this step,
     no other open ticket, attempt count < 2
  -> writes tickets/<ticket>.json {ticket, run, rung, phase, attempt, role, model, effort,
     brief_sha256, fingerprint, issued_at, mac}
  -> prints JSON: {ticket, spawn: {...host params...}, brief: "<exact prompt text>"}
parent: spawns exactly one subagent with that prompt and those params
hook PreToolUse(spawn): validates the spawn against the open ticket (3.5)
subagent: reads scope, returns final message containing the result block
hook PostToolUse(spawn): captures the result into rung-NN/<phase>.capture.json (+ .md), closes the ticket
```

The brief is generated by the encoder (Template A or B plus the issue ledger, `--write-review-brief` content). It ends with a mandatory result contract:

```
Return your result as the last thing in your reply, exactly:
<rfl-result ticket="T-03-review-1-9f2c1a7e">
{ "verdict": "CLEAN" | "NOT CLEAN", "findings": [ {"id","severity":"HIGH|MED|LOW|NIT","file","line","summary"} ] }
</rfl-result>
```
For verify: `{ "verdict": "VERIFY_PASS" | "VERIFY_FAIL", "checks": [ {"finding_id","status":"resolved|open|n/a","evidence"} ], "gaps": [...] }`.

**Claude Code**
- Tool: `Agent` (alias `Task`). `subagent_type`: `sb-rfl-reviewer` or `sb-rfl-verifier`. Plugin agents may arrive namespaced (`silver-bullet:sb-rfl-reviewer`), and the guard accepts both forms. `model`: the rung alias or id. `prompt`: the exact brief. `description`: `RFL <ticket>`. `run_in_background` must be absent or false.
- Agent definitions shipped with the plugin: `subagents/claude/sb-rfl-reviewer.md` and `sb-rfl-verifier.md`, declared in `.claude-plugin/plugin.json` `"agents"`. They get their own folder because `agents/claude/` holds the rendered skills, and `plugin.json` points `skills` there. Frontmatter: `name`, `description`, `tools: Read, Grep, Glob`. No Bash, Edit, Write or Agent, so a reviewer can neither write nor spawn. The body holds the role rules: review only, scope lock, no triage, the result contract. Effort: if Claude Code honours an `effort` field per spawn or in agent frontmatter, ship one definition per effort (`sb-rfl-reviewer-high`, `-xhigh`, ...) or pass the parameter. Otherwise rungs collapse to models (3.2). This is verified in step 0 of the work (5.1). It is not a user question.

**Codex**
- Tool: the multi-agent `spawn_agent` (seen in hooks as `spawn_agent` or `multi_agent_v1.spawn_agent`, `orchestrator-parent.sh:250,260`). The result arrives through the follow-up wait tool.
- Roles: `install-codex.sh` writes two agent roles, `sb-rfl-reviewer` and `sb-rfl-verifier`, with `sandbox_mode = "read-only"` and the role instructions. Per-rung model and reasoning effort go either as spawn parameters, if this Codex build accepts them, or as one role per rung generated at `--start` (`sb-rfl-<role>-<model>-<effort>`). Step 0 decides which, and the exact config keys must be read from the installed Codex version, because this design session had no network.
- No `codex exec` fallback. If multi-agent is disabled, `--start` fails with an instruction to enable it. This honours "native subagents only" and keeps the code small (open question Q1 confirms).

### 3.4 How results come back, and why they cannot be faked

1. **Capture (primary).** The PostToolUse hook on the spawn and wait tools (Claude `Agent|Task`; Codex `spawn_agent|wait` and their `multi_agent_v1.` names) extracts text from `tool_response` (string, `{content:[{text}]}`, `{result}`, `{output}`). It finds the `<rfl-result ticket=…>` block whose ticket is **open**, validates the JSON schema (size cap 256 KB, depth cap 32, severities and verdicts enumerated), and writes `rung-NN/<phase>.capture.json` with `{ticket, captured_from: "hook", tool_name, response_sha256, result, mac}` plus a rendered `.md`. Then it closes the ticket. No block, or a malformed block, is recorded as `launch_outcome: no_verdict` and counts as a failed attempt (3.6). A response that matches the quota classifier is recorded as `blocked_quota` with the parsed reset time.
2. **Relay (fallback, Codex only until proven otherwise).** If the host fired no capture hook, the parent runs `--record-result --ticket T` with the subagent's reply on stdin. The record says `captured_from: "relayed"`, and Policy C and the Policy D matrix show that provenance to the user. On Claude, `--record-result` is refused, because a capture must exist: the PreToolUse spawn hook proved that hooks fire for this tool. Config `review_fix_ladder.require_captured_results` (default `true` on Claude, `false` on Codex until the live probe) controls this.
3. **The parent cannot steer the reviewer.** The PreToolUse spawn hook requires `sha256(prompt) == ticket.brief_sha256`. The parent cannot append "say CLEAN".
4. **The parent cannot fake a CLEAN streak.** `--record-rung-review-outcome` is removed as a free command. The streak is computed by the encoder from captured review results: a review counts as CLEAN when its captured verdict is CLEAN, or when triage (Policy C) marks every captured finding REJECT-as-wrong with a reason. Two consecutive such reviews, each with its own ticket and the **same** worktree fingerprint, are required. An ACCEPT-apply changes the fingerprint and resets the streak by construction. Triage honesty remains the parent's duty under Policy A and is visible to the user in Policy C. That is a documented residual.
5. **Fixes are verified by evidence, not by claims.**
   - `--record-apply --rung-dir R` checks that every ACCEPT row in `POLICY-C.json` names at least one in-scope file whose content hash differs from the hash recorded in the review ticket's fingerprint. Otherwise it fails with the row id.
   - verify_1 and verify_2 are independent read-only subagents with captured verdicts, and each must report `resolved` for every ACCEPT id.
   - `--run-signals --run-dir X` executes the charter's verification signals from `CHARTER.json` (approved under Policy E). It runs each with a timeout and without a shell where possible, then records exit code, a stdout hash and pass/fail in `rung-NN/signals-<n>.json`. This replaces "the orchestrator ran grep". The commands come from the user-approved charter and run in the parent's Bash call, under the host's normal permission prompts, never from a hook.
   - The worktree fingerprint is `HEAD` sha + sha256 of `git diff HEAD --binary` + sha256 of untracked in-scope files. It creates no git objects, so it never trips the commit-class gates (`write-tree` and `hash-object -w` are gated in completion-audit).

### 3.5 Guards, hooks and state mapping

One hook script, `hooks/review-fix-ladder-guard.sh`, is a thin bash wrapper. It resolves the plugin root from `BASH_SOURCE` and has a fast path: if there is no runtime pointer `${SB_RUNTIME_STATE_DIR}/rfl-live.json` and the event is not SessionStart or Skill, it exits 0. Otherwise it runs `python3 -I "$plugin/scripts/review-fix-ladder.py" --hook` with the payload on stdin (F2 rule: payload on stdin, not argv) under `hook-subproc-timeout`. Python errors while a run is live mean **deny / block** (fail closed). With no live run they mean allow.

| Event / matcher | Behaviour |
|---|---|
| SessionStart `startup\|clear\|compact` | Delete the legacy `review-fix-ladder-state.json`. For each `.planning/rfl-*/LADDER-STATUS.json` with status `active`, `paused_quota` or `legacy` and a valid run id, emit **one fixed-template line**: "RFL run `<id>` is `<status>` at rung `<n>` (resume after `<iso>`). Resume with /sb:review-fix-ladder --resume `<id>`." No other file text is ever injected. Does not make the run live. |
| PreToolUse `Skill` | Ladder skill: no-op. Start and resume happen through `--start` and `--resume` (Bash), and invoking the skill never resets a run. This replaces `sb_rfl_on_skill_invoke`. |
| PreToolUse `Task\|Subagent\|Agent\|spawn_agent\|multi_agent_v1.spawn_agent` | If a run is live, a spawn is allowed only when an open ticket exists for the current phase and: role (subagent_type or agent_type) matches; model matches when the host passes one; prompt hash matches; not background; no other open ticket. Otherwise deny with the exact reason and an audit record. Non-RFL spawns are denied while a ticket is open (no parallel rungs) and allowed otherwise. |
| PreToolUse `Edit\|Write\|MultiEdit\|apply_patch` | **New registration.** (1) While any ticket is open (review or verify in flight; this is real on Codex, where `spawn_agent` is asynchronous), deny parent edits to in-scope paths. (2) Always deny edits to `.planning/rfl-*/{LADDER-STATUS.json,tickets/**,*.capture.json,signals-*.json}`. (3) If the payload identifies a subagent (`agent_id`/`agent_type` when the host provides them) and it is an RFL role, deny every edit (defence in depth over the tool allowlist). |
| PostToolUse `Task\|Subagent\|Agent\|spawn_agent\|wait\|multi_agent_v1.*` | Capture (3.4). |
| UserPromptSubmit `.*` | Only when the prompt matches `^\s*RFL ABORT ([A-Za-z0-9._-]{1,64})\s*$`: write a signed, 30-minute abort token for that run. Uses G3's prompt-authenticity check (R4-07) once G3 lands; until then that is a documented residual. Bash fast path: one grep, no python otherwise. |
| Stop `.*` | If a run is live and status is `active`: run `assert_rfl_advance(action="stop")`. Fail closed on error or tamper (mac mismatch → "LADDER-STATUS.json was modified outside the encoder; run --resume to re-validate"). `paused_quota`, `completed` and `aborted` (with a valid token) pass. |

Removed registrations: `rfl-policy-c-gate.sh` (4 entries), `rfl-quota-retry-due.sh` (2), the guard's `PostToolUse Skill|Bash|exec_command` entry, and the RFL block in `stop-check.sh:172-188`. There is no PreToolUse Bash hook for RFL at all: ordering lives in the encoder, and tampering is caught by the MAC.

**Run lifecycle commands** (encoder; every one checks order and signs the status):
`--start --scope … --charter-file …` (creates the run dir, CHARTER.json, RUNG-PROMPT-APPROVAL.md pending, the live pointer, and refuses if another run is live) → Policy E approval (unchanged: parent records `approved: yes` after the user agrees; see residuals) → `--issue-ticket review` → capture → `--write-policy-c` (triage, existing encoder) → `--record-apply` (if ACCEPTs) → `--issue-ticket verify_1` → capture → `--run-signals` → [`--issue-ticket verify_2` → capture → `--run-signals`] → `--advance` (Policy F check, next rung or completion) … → `--mark-ladder-status completed` (Policy D) or `--abort` (needs the token).

**State fields** (`rfl.ladder.v2`): `schema, run_id, host, rungs[], current_rung, phase ∈ {review, triage, apply, verify_1, signals_1, verify_2, signals_2, advance}, open_ticket, attempts{phase: n}, streak{rung: [ticket…]}, fingerprint_at_review, skipped[], post_ladder_retry_pending[], status ∈ {active, paused_quota, completed, aborted, legacy}, resume_after, stop{check, reason}, updated_at, mac`.

**STOP and recovery.** A compliance failure writes `STOP.md` and `stop.check`. The only tickets the encoder will issue afterwards are for the **same rung's failed phase**, which is the skill's Recovery Procedure. The STOP clears when that phase completes. A STOP no longer turns into "deny every Task forever", and re-invoking the skill no longer resets the run.

**Quota and rate limits.** A native subagent shares the parent's account, so a usage limit stops the parent too. The redesign keeps only classification:
- The capture hook classifies an error response with `quota_window.classify` (single module; the Claude 5-hour parsing is folded in from `rfl_quota_claude5h.py`). A 5-hour or short window → status `paused_quota`, `resume_after = reset`, `BLOCKED.md` + `QUOTA-CLASSIFY.json`, and the attempt does **not** count toward skip. A weekly, monthly or billing window → `paused_quota` without `resume_after`, plus a user message. Stop is allowed for paused runs.
- Resume: SessionStart prints the fixed notice; the user or parent runs `--resume <id>`, which re-validates the MAC, re-reads the fingerprint (if the tree changed while paused, the current rung's streak resets) and makes the run live again.
- Deleted: `at`/launchd timers, wake jobs, ASK/EXECUTE files, UserPromptSubmit injection, `--schedule-quota-retry`, `--activate-quota-retry`, `--quota-retry-due`, `--quota-retry-wake`. `--classify-quota-window` keeps its JSON contract because `agent-delegate-common.sh` and the Pi lib still call it. G6b narrows the classifier's inputs (R4-20).

**Launch failures and escalation rungs.** These keep today's policy, minus the Grok substitute. `cannot_launch` (spawn denied by the host, unknown model), `timeout`, and `no_verdict` (no or invalid result block) count as attempts. After 2 failed attempts the phase is recorded as `SKIPPED.md`, with the captured error text as evidence, and the ladder moves to the next rung. After the last rung, each skipped rung is retried once (`post_ladder_retry_pending`). Escalation order is the resolver order. Policy F (2 consecutive captured CLEAN at an unchanged fingerprint) gates each step up. A skip is never a CLEAN advance.

**Delegation state mapping.** The RFL no longer uses `agent-delegation-state.sh` or the external delegates. "Parent must supervise, not edit" is provided by the open ticket (Edit guard, row 2 of the table). The external-delegation guard keeps serving `/sb:agent-*` (G6b).

**Worker identity.** RFL decisions never call `sb_orchestrator_is_worker_session`. They rely on the ticket state and, for subagent-originated tool calls, on the payload's subagent identity fields where present. This removes the R4-02 hole for the ladder without waiting for G5.

### 3.6 Guarantees that must not regress (acceptance list)

1. **No skipped rung or phase.** Tickets are issued only in order. Advance requires Policy F from captures plus the verify overlay (verify_1 always on NOT CLEAN or after APPLY; verify_2 on CLEAN) plus passing signals, or a recorded two-attempt skip.
2. **One subagent at a time.** There is one open ticket, and while it is open every other spawn is denied (no parallel rungs, no batched Tasks).
3. **Review-only and verify-only.** Read-only roles, an exact brief, and separate tickets for verify_1 and verify_2 (so the two verifies cannot be combined in one prompt).
4. **No parent edits while a review or verify is open.** RFL artifacts are never editable through edit tools.
5. **Policy C before the next phase.** `--issue-ticket` and `--advance` run `assert_policy_c`; Stop is blocked while a live, active run has unmet artifacts, and errors fail closed.
6. **Policy E** before the first review ticket, re-gated when the brief's key tasks change (the encoder compares a hash of the approved bullets).
7. **Policy G**: the brief always comes from the encoder.
8. **Audit**: every deny goes to `sb_hook_audit_record`; tickets, captures, signals, `POLICY-C.*`, `SKIPPED.md`, `STOP.md` and `BLOCKED.md` form the per-run trail. No new unbounded log (avoids the R4-29 pattern).
9. **Inert outside a live run**: no hook runs project code, injects project text, or blocks a session that did not start or resume a run.
10. **Scope lock**: carried in the brief, enforced for the parent's edits by the guard. Subagents are read-only.

Documented residuals (same class as other SB gates, report to the user): the parent can still write files through Bash. The MAC turns that into a fail-closed Stop, but a same-user agent could read the key. Triage honesty (Policy A) and the Policy E `approved: yes` marker remain parent-asserted. On Codex, until the live probe, results are relayed and labelled.

### 3.7 What gets deleted

| Delete | Approx. lines |
|---|---|
| Cursor resolver, subscription-first, quota fallback, agent probes, their CLI flags (`_review_fix_ladder_impl.py` keeps ~250 of 907) | −650 |
| Wrapper shim `review-fix-ladder.py:42-61` | −20 |
| Host routing, aliases, Grok substitute, `--default-host-route` (`rfl_launcher_policy.py`) | −250 |
| Scheduler, timers, wake, ASK/EXECUTE, notify (`rfl_quota_retry.py` keeps ~150 as `quota_window` classification plus pause/resume) | −700 |
| `rfl_quota_claude5h.py` (5-hour parsing folded into the classifier, monkey-patching removed) | −250 |
| `hooks/lib/review-fix-ladder-state.sh`, `hooks/rfl-policy-c-gate.sh`, `hooks/lib/rfl-policy-c-assert.sh`, `hooks/rfl-quota-retry-due.sh`, `stop-check.sh:172-188` | −780 |
| `scripts/rfl-assert-advance.sh` (callers use `review-fix-ladder.py --assert-rfl-advance`) | −7 |
| Pi quota scheduling in `scripts/lib/agent-pi-quota-retry.sh:95-155` and the duplicate `should_continue` | −80 |
| Skill "Host Delegation Notes" (`SKILL.md:416-493`), replaced by ~40 lines of native instructions | −40 net |
| Live ladder tests and libs (broken: `cursor_task_slug`), `test_rfl_quota_claude5h.py`, scheduler parts of `test_rfl_quota_retry.py`, `test-rfl-quota-retry-due-paths.sh`, `test-review-fix-ladder-state-lib.sh`, Cursor parts of `test_review_fix_ladder_impl.py`, `test-rfl-policy-c-gate.sh`/`-paths.sh` (merged into the new guard tests) | −3,000 |
| **Added**: `scripts/lib/rfl_native.py` (tickets, fingerprint, MAC, capture, spawn validation, hook dispatch) ~450; guard wrapper ~40; 2 agent definitions; Codex role templates; tests ~1,500 | +2,000 |

Net code (non-test) shrinks by roughly 2,300 lines. Every surviving and new line is covered by python unit tests and hook replay tests (100% statement and branch for `rfl_native.py`, `rfl_policy_c.py`, `quota_window` and the resolver).

---

## 4. Migration and compatibility

**Existing state files**
- `${SB_RUNTIME_STATE_DIR}/review-fix-ladder-state.json` (and the `/tmp` default copy): deleted by the SessionStart branch, then ignored.
- `.planning/rfl-*/LADDER-STATUS.json` without `schema: rfl.ladder.v2` is a **legacy** run. Gates are inert for it (it is never live), and SessionStart shows the fixed notice. `--resume <id>` on a legacy run migrates it: it keeps the rung dirs, `POLICY-C.*`, `ISSUE-LEDGER.md` and SKIPPED/STOP records as history; re-resolves the ladder for the current host; maps the old `current_rung` index to the new ladder by position (clamped); **resets the current rung's streak to 0**, because legacy streaks were self-reported; then signs the file. Rung dir names (`rung-NN-<cursor-slug>`) stay; new rung dirs use `rung-NN-<model>-<effort>`.
- `quota-retry-schedule.json`, `QUOTA-RETRY-ASK.md`, `QUOTA-RETRY-EXECUTE.md`: ignored, left in place (history).
- **Armed timers on users' machines**: a fired `at` job calls the removed `--quota-retry-wake`. argparse rejects it, which is harmless, and `at` jobs are one-shot. launchd plists `~/Library/LaunchAgents/dev.alolabs.sb.rfl-quota-retry.*.plist` persist, so `--cleanup-legacy-timers` unloads and removes exactly that label prefix (dry-run flag, list printed). It is called once by `--start`/`--resume` and documented in the CHANGELOG. It is never run from a hook.

**Config keys**
- `cursor_sb_agents` (project) and `~/.config/silver-bullet/cursor-sb-agents.json`, `cursor-models-catalog.json`: ignored (HC already drops them from the template). Doctor can mention them as obsolete; no deletion.
- New `review_fix_ladder: { rungs: {claude: [...], codex: "dynamic" | [...]}, require_captured_results: {claude: true, codex: false}, pm_tracking: false }` in `templates/silver-bullet.config.json.default` and the live `.silver-bullet.json`.
- Environment switches removed: `SB_RFL_POLICY_C_GATE`, `SB_RFL_QUOTA_RETRY_HOOK`, `SB_RFL_RESOLVER`, `SB_RFL_NOTIFY`, `SB_RFL_AT_BIN`, `SB_CURSOR_SB_AGENTS_SKIP_PROBE`, `SB_RFL_QUOTA_NOW`. Keep one documented test seam, `SB_RFL_NOW`, which injects time only. Recommend dropping `SB_REVIEW_FIX_LADDER_GUARD=0` (an undocumented gate-off switch, the R16-04 class), or else documenting it in the env table H11 is building.

**A project mid-ladder at upgrade.** The old session state is dropped and the run becomes `legacy`. Stop is not blocked (no live run). The user sees one notice and resumes, starting the current rung with a zero streak. Work already done is kept as history and is not re-reviewed unless the current rung requires it.

**Docs and skills to update**
- `skills/silver-review-fix-ladder/SKILL.md`: Steps 2-3 and the per-rung table become ticket-based; replace the Host Delegation Notes; Templates A and B gain the result contract; the triage template frames findings as untrusted data (R10b-08); delete every Cursor, Composer, Grok, OpenCode, Pi, `readonly: true` and subscription mention; fix the `SKILL.md:102` gate paths. Rendered mirrors via `bash scripts/sync-codex-package.sh`.
- `skills/silver-review-fix-ladder/agents/openai.yaml` (prompt wording), `templates/rfl-review-brief.md`, `templates/orchestrator-workers/REVIEW-TRIAGE.md:27-35`, `.silver-bullet/orchestrator-workers/` copy.
- `silver-bullet.md` and `templates/silver-bullet.md.base` EXRV-05 (`:658`): "2 consecutive CLEAN on unchanged SHA" is now enforced from captures. Keep both files identical (`test-silver-bullet-template-parity.sh`).
- `skills/silver-clarify/SKILL.md:308`: drop the Grok substitution, use skip.
- `docs/HOOKS.md` (regenerate), `CLAUDE.md` hook counts ("96 hook commands backed by 64 hook scripts", recount after HC + G6a), `docs/ORCHESTRATOR.md`, `docs/AGENT-PI-OMNIROUTE.md:57`, `docs/ENTERPRISE-E2E-LIVE-TEST.md:101,247`, `docs/testing/RFL-TRIAGE-GITHUB-E2E.md`, `docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md`, `scripts/README.md:21`, `scripts/validate-host-agnostic-core.sh:86,130,136,215` (file list), `docs/testing/coverage-campaign/packages.json`, `tests/skill-scenarios/silver-review-fix-ladder.md`, `CHANGELOG.md [Unreleased]` (breaking change: native ladder, legacy runs, timer cleanup).

**Test strategy** (no real AI CLI ever runs)
- **Fixtures** under `tests/fixtures/rfl/`: `claude-agent-pre.json`, `claude-agent-post.json` (`tool_response.content[].text` with a result block), `claude-agent-post-ratelimit.json`, `claude-agent-post-noverdict.json`, `codex-spawn-pre.json`, `codex-wait-post.json`, plus Bash and Edit payloads. Real captured payloads from step 0 replace the hand-written ones when available. A fixture header records its source (`captured <host> <version>` or `synthetic`).
- **Registered-events rule** (from R4-30): a helper reads `hooks/hooks.json` and asserts that each `(event, tool_name)` a test sends would actually route to the guard. A test cannot pass by driving an unregistered path.
- **Python unit tests** (`tests/python/test_rfl_native.py`, rewritten `test_review_fix_ladder_impl.py`, `test_rfl_policy_c.py`, `test_quota_window.py`): ticket issue and ordering, fingerprint, MAC, capture parsing for every response shape, schema caps (size, depth, `RecursionError`), streak from captures, apply-evidence check, signals runner (stub commands), resolver for claude and codex (dynamic and fallback), config override, effort collapse, legacy migration, timer cleanup (temp HOME, stub `launchctl`).
- **Hook replay tests** (`tests/hooks/test-review-fix-ladder-guard.sh`, rewritten): a full rung on Claude fixtures (start → approve → ticket → Pre spawn → Post capture → Policy C → apply → verify_1 → signals → verify_2 → signals → advance, twice for Policy F) and on Codex (spawn plus relayed record).
- **Negative tests**, one per finding:
  - R4-09: a project with a malicious `scripts/review-fix-ladder.py` plus `.planning/rfl-x/*`. SessionStart, prompt, spawn and Stop never execute it (marker file absent).
  - R4-10: an ASK file and hostile job fields are never injected; the notice equals the fixed template.
  - R4-15: quoted `--mark-ladder-status aborted` and `--abort` without a token are refused; a 200k-deep `POLICY-C.json` makes Stop **block**; two `clean` claims without captures do not advance.
  - R4-16: the original wedge replay passes; re-invoking the skill does not reset; STOP clears only by re-running the failed phase.
  - R4-25: no `at`/`launchctl` invocation anywhere (stub records calls).
  - Also: tampered status → Stop blocks; wrong role, model or brief hash, background spawn, or a second open ticket → deny; parent Edit while a ticket is open → deny; RFL artifact edit → deny.
- **Optional live smoke** `tests/live/test-live-review-fix-ladder-native.sh`: opt-in (`SB_LIVE=1`), skipped by default, not in CI.

---

## 5. Work breakdown

The whole G6 package is roughly 18 findings plus the redesign. That is too much for one Sonnet author in one pass: the redesign alone is the largest single change in this PR. **Split into two packages with disjoint file ownership that can run in parallel**, both based on the integration branch *after HC merges* (HC deletes `agent-cursor-delegate.sh`, the Cursor branches of `agent-host-exec.sh`, `cursor-sb-agents/` and the agent-cursor skill, and changes the guard state-dir default).

### 5.0 File ownership

**G6a, RFL native** (R4-09, R4-10 RFL half + catalog line, R4-15, R4-16, R4-25, R4-20 RFL half, R4-24 quota half; absorb R10b-08 if H7 agrees):
`scripts/review-fix-ladder.py`, `scripts/_review_fix_ladder_impl.py`, `scripts/lib/rfl_*.py`, new `scripts/lib/rfl_native.py` and `scripts/lib/quota_window.py`, `scripts/rfl-assert-advance.sh`, `scripts/lib/agent-pi-quota-retry.sh`, `hooks/review-fix-ladder-guard.sh`, `hooks/lib/review-fix-ladder-state.sh`, `hooks/rfl-policy-c-gate.sh`, `hooks/lib/rfl-policy-c-assert.sh`, `hooks/rfl-quota-retry-due.sh`, the RFL block of `hooks/stop-check.sh`, the RFL entries of `hooks/hooks.json`, `subagents/claude/*`, `.claude-plugin/plugin.json` (`agents`), Codex role templates and the role-writing lines in `scripts/lib/install-codex/config.sh`, `skills/silver-review-fix-ladder/**`, `skills/silver-clarify/SKILL.md:308`, RFL templates, EXRV-05 in `silver-bullet.md` + `templates/silver-bullet.md.base`, the config template key, the RFL docs listed in §4, and the RFL tests. Plus one line in `hooks/lib/orchestrator-scheduler.sh` (R4-10, coordinate with G5).

**G6b, external delegation hardening** (R4-11, R8-15, R4-20 delegate half, R4-21, R4-22, R4-23, R4-24 non-quota half, R4-31, R4-32, R8-14, R8-26, R10b-05, R10b-06):
`scripts/agent-{claude,codex,opencode,pi}-delegate.sh`, `scripts/agent-{claude,codex,opencode,pi}/**`, `scripts/lib/agent-delegate-common.sh`, `scripts/lib/agent-host-exec.sh`, `scripts/lib/agent-mode.sh`, `scripts/agent-mode/**`, new `scripts/lib/agent-monitor.sh` and `scripts/lib/agent-adapters/*`, `scripts/codex-interactive-invoke.expect`, `hooks/agent-delegation-guard.sh`, `hooks/lib/agent-delegation-state.sh`, `skills/silver-agent-{claude,codex,opencode,pi}/SKILL.md`, `templates/orchestrator-workers/AGENT-DELEGATE.md`, `docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md`, the delegation tests, and the production half of `tests/live/agents/*/agent.sh` (moved).

**Seam**: G6b calls only `review-fix-ladder.py --classify-quota-window`, whose JSON contract G6a keeps (`quota_class`, `should_schedule`, `should_short_retry`, `reset_seconds`). G6a deletes `--schedule-quota-retry` *and* its only non-RFL caller (the Pi lib, which G6a owns). Merge order does not matter. If both touch `hooks/hooks.json`, only G6a does: G6b changes no registrations.

### 5.1 G6a, ordered steps (one Sonnet author)

0. **Capability facts (orchestrator, before launch; ~15 min, no author time).** From the orchestrator's own Agent tool schema and one throw-away hook capture on Claude Code, record: Agent tool parameters (`model` values, whether `effort` exists, `run_in_background`); the PostToolUse `tool_response` shape for Agent; whether subagent tool calls carry `agent_id`/`agent_type`; whether plugin `agents` paths and namespaced `subagent_type` work. For Codex, see Q1. Save as fixtures for the author. Without this step the author uses synthetic fixtures and marks them so.
1. **Tests first (red)**: the negative tests for R4-09, R4-10, R4-15, R4-16, R4-25 and the registered-events helper. Expected to fail on the base.
2. `scripts/lib/quota_window.py`: move `classify_quota_window`/`parse_reset_seconds` and fold in the Claude 5-hour parsing; keep the `--classify-quota-window` output. Delete `rfl_quota_claude5h.py`; shrink `rfl_quota_retry.py` to `mark_ladder_status` (or move that into `rfl_policy_c`, then delete the file). Strip the scheduling from `agent-pi-quota-retry.sh` and remove its duplicate `should_continue`. Update `test-agent-pi-quota-retry*.sh`. Unit tests to 100%.
3. `scripts/lib/rfl_native.py` with unit tests first: tickets, fingerprint, MAC (key under `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/rfl-keys/<sha256(project_root)>`, 0600, outside the branch-scoped wipe), capture parser, spawn validation, apply evidence, signals runner, abort token, legacy migration, timer cleanup, the hook dispatcher (`--hook`).
4. **Resolver shrink** (`_review_fix_ladder_impl.py`, wrapper): claude and codex only, config rungs, effort collapse. Delete the Cursor and subscription code and flags. Rewrite `test_review_fix_ladder_impl.py` and `test_review_fix_ladder_wrapper.py`.
5. **Policy C / launcher edits**: `rfl_policy_c.py` streak from captures, fail-closed bounded reads, `assert_rfl_advance` taking ticket state; remove `--record-rung-review-outcome` as a free command (or make it a read-only report); `rfl_launcher_policy.py` minus host routing and Grok. Update tests.
6. **Hooks**: new guard wrapper; delete the four hook files, the `stop-check.sh` block and `rfl-assert-advance.sh`; edit `hooks.json` registrations (§3.5); `python3 scripts/generate-hook-reference.py`; update the `CLAUDE.md` counts, `validate-host-agnostic-core.sh` and `scripts/README.md`; rewrite the hook tests as fixture replays.
7. **Native agents**: `subagents/claude/sb-rfl-{reviewer,verifier}.md`, `plugin.json`; Codex role templates plus install lines (coordinate with the H2/H5 owners of the installer and sync scripts; add the paths to `sync-codex-package.sh` `PACKAGE_ENTRIES` if needed); `validate-plugin-mirror.sh` green.
8. **Skill, templates, docs** per §4; `bash scripts/sync-codex-package.sh`; template parity.
9. **Migration**: SessionStart legacy cleanup, `--resume` migration, `--cleanup-legacy-timers`; CHANGELOG.
10. **Delete obsolete tests** (live ladder tests and libs, quota scheduler tests); coverage to 100% on the touched modules (`make coverage FAIL_UNDER=100` scoped); `make check`; `graphify update .`.

**Risks (G6a)**
- **Host payload shapes are not verified in this session** (no network, no Codex). Step 0 and the fixture headers contain this; the parser accepts every known shape; capture failure degrades to `no_verdict` (retry, then skip), never to a false CLEAN.
- **Codex `spawn_agent` is asynchronous and may not fire Pre/PostToolUse.** The design's floor (encoder ordering, MAC, Stop gate, relayed provenance) works without them. The spawn-time checks are then weaker on Codex, and Policy C shows that.
- **Effort per spawn may be unavailable on Claude Code**, which shortens the Claude ladder to models only. The resolver reports it; there is no silent behaviour change.
- **Plugin agent discovery and namespacing.** If `plugin.json` `agents` does not load from `subagents/claude/`, fall back to the default `agents/` top level, which first needs a check that SKILL.md files under `agents/claude/` are not mis-loaded as agents.
- **`hooks/hooks.json` conflicts** with HC (already changed) and G2 (changed 87 lines): rebase on the integration branch and regenerate `docs/HOOKS.md` last.
- **Skill text conflicts with H7** (R10b-07/08): decide ownership before launch (recommendation: G6a takes them).
- **Cost**: each rung needs at least 2 reviews plus verifies. The default Claude ladder has 3 rungs (Q2).

### 5.2 G6b, ordered steps (one Sonnet author)

1. Tests first: the finding test ideas from R4-11, R4-20, R4-21, R4-22, R4-23, R4-24, R4-31, R4-32, R8-14, R8-26, R10b-05, R10b-06 (stub CLIs only; corrupt `~/.claude.json` must stay byte-identical; a stub printing `line 429` runs once; a TERM-ignoring stub returns within the deadline; a reader-less FIFO exits within ~9 s; strict argv has no bypass flags; redaction table; quoted task id gives parseable JSON).
2. Trust defaults (R4-11, R8-15, R4-23, R10b-06 part 2): `agent-claude/lib.sh`, `agent-codex/lib.sh`, `agent-codex-delegate.sh:121-122`, `agent-host-exec.sh` argv, `codex-interactive-invoke.expect` auto-answers gated on the explicit opt-in.
3. Quota retry narrowing (R4-20): one classifier call with error-context lines; opt-in retries; delete the per-delegate copies of the loop by moving it into `agent-delegate-common.sh`.
4. Process control (R4-21, R4-22, R4-24 non-quota): PTY `killpg`, FIFO non-blocking, Pi continue hops guarded, rewrite dir under `TMPDIR` with a trap.
5. Secrets (R4-31, R10b-06): redaction patterns, stream-through redaction, `CODEX_HOME` under a cleanup-on-start dir, briefs via a 0600 file or stdin.
6. JSON and inputs (R4-32, R8-14): `jq`/`json.dumps` writers, task-id validation, drop the no-jq writer, rename the Pi override.
7. Monitor consolidation (R8-26) and adapter relocation (R10b-05): `scripts/lib/agent-monitor.sh`, `scripts/lib/agent-adapters/<host>.sh`, delegates source the shipped path; update the `SB_ROOT` skill rows.
8. Skills' Security tables (`silver-agent-*`) corrected; sync; coverage 100% on the touched libs; `make check`.

**Risks (G6b)**: the OCG multi-AI backend (`live_dispatch.py:62`) depends on `agent-opencode-delegate.sh`, so its tests must stay green (run `skills/silver-multi-ai-task/tests`). H8a notes that it "must not edit agent-host-exec.sh: G6", so record any H8a needs before starting. The delegate retry loop is duplicated five times today, and consolidating it is the riskiest edit.

---

## 6. Open questions for the user

Keep to these three; everything else is resolved above.

1. **Codex live check.** There is no Codex CLI or network in this session, so it is unproven whether Codex fires hooks for `spawn_agent`/`wait` and how per-rung model and effort are set. Options: (a) ship the Codex ladder now, with results relayed by the parent and labelled "relayed" in every report (weaker than on Claude), and run a ~10-minute live probe later to switch on capture; (b) disable the ladder on Codex until a probe has been run. **Recommendation: (a).** It is also the reason for having no `codex exec` fallback: please confirm "spawn_agent only, no `codex exec`".
2. **Default Claude ladder and cost.** Proposed default rungs: Sonnet high → Opus high → Opus extra-high (3 rungs, each needing 2 clean reviews plus verifies), replacing today's 9-rung fallback. It can be overridden per project in `.silver-bullet.json`. **Recommendation: accept.**
3. **Abort needs your words.** Ending an unfinished ladder would require you to type `RFL ABORT <run-id>` (closing R4-15's "agent aborts to escape the gate"). Approval of the rung brief (Policy E) stays conversational as today. **Recommendation: accept.**

## ADDENDUM (orchestrator, 2026-11-05) — user decisions that override section 3.x defaults
1. Claude-only release. On Codex the ladder stops with a clear "not yet verified on Codex" message; a later local Codex end-to-end session will enable it. Do not ship the "relayed" Codex path.
2. Default Claude rungs (latest version of each tier, resolved at run time via aliases, Fable never used): `haiku:xhigh`, `sonnet:high`, `sonnet:xhigh`, `opus:low`, `opus:medium`, `opus:high`. Exclusions: Sonnet low/medium/max, Opus xhigh/max. The user may exclude or include any rung in the prompt (design the flag/override, e.g. `rungs: +opus:xhigh -haiku:xhigh`), and in `.silver-bullet.json`. Codex defaults to document, not enable: Luna xhigh; Terra high/xhigh (no low/medium); Sol (low..high assumed, mark unverified); Astra excluded.
3. `RFL ABORT <run-id>` accepted (user message only, audited).
4. Claude end-to-end test required before release: plan a live-or-recorded Claude test of the whole ladder (fixtures for the Agent-tool parameters and post-spawn payload shapes must be captured first; if they cannot be captured in this container, say exactly what the user must provide).
