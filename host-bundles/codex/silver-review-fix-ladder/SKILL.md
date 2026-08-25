---
name: "silver:review-fix-ladder"
title: "Review Fix Ladder"
description: Progressively review and fix scoped artifacts or user-confirmed repo-wide work by escalating through every rung of a host-aware model/reasoning ladder, requiring two consecutive clean passes at each rung before advancing. Use for pre-ship confidence, launch-critical artifacts, and repo alignment checks against context-derived goals.
user-invocable: false
---

# /silver:review-fix-ladder — Progressive Review / Fix Ladder

Escalate review and fix work through a host-aware model/reasoning ladder. Each rung audits against a context-derived review charter — not generic “find issues” heuristics. The launcher applies ACCEPT fixes; the rung model does not implement. The launcher reports findings after every rung.

**Orchestrator role:** The parent agent (you) MUST personally orchestrate every rung. Subagents execute one phase at a time. You MUST NOT delegate the ladder loop itself to a single subagent.

**RFL session exception:** Inside a review-fix-ladder session, the launcher / parent of the ladder triages findings and applies ACCEPT fixes with Edit/Write. This is an explicit exception to any "parent orchestrator never implements" rule. Rung workers remain REVIEW ONLY.

## Triage and Fix Owner (HARD)

Applies to **both ladders, all rungs**.

### Policy A — triage

Incorporate every finding that is not wrong. Reject only if the finding is wrong or mistaken.

**Forbidden reject reasons** (do not use these):

- "advisory", "doc-only", "documentation nit", "non-gating", "nice-to-have", "not a contract hole", "CLEAN so ignore mediums", "CLEAN for ladder purposes", "non-blocking nit"

**Allowed reject reasons** (must state why it is **wrong**):

- Contradicts a locked decision (example: putting A back on ESC-02 when the lock is I then V, no A)
- KEEP REJECT / user-locked reject (do not reopen KEEP REJECT)
- Mistaken about the spec vs shipped product
- Already fully specified (duplicate)
- Would rename/break a locked identifier (example: `process_v_two_clean` vs `process_v_verified`)
- Factually false on re-read of the current spec
- Superseded/stale claim, or no longer true on the current freeze
- Historical changelog / KEEP REJECT alias pointer churn (anti-churn; do not reopen KEEP REJECT)

Parent still triages (not every finding is automatically valid) — but the bar is **wrong vs not wrong**, not severity.

If a rung returns CLEAN with findings that are not wrong, the launcher still applies them before the next rung.

### Policy B — who applies fixes

After each rung's review, the agent that launched the RFL applies ACCEPT fixes. The rung model does not implement.

- Rung workers: REVIEW ONLY. No plan edits, no spec patches, no "while I'm here" fixes.
- Launcher / parent of the ladder: triage then Edit/Write the spec (and tests/docs if the finding is about those).
- Do not ask the same Composer/GLM/Kimi/Codex/Claude/OpenCode rung to patch the plan after NOT CLEAN.
- Next rung waits until the launcher has applied ACCEPTs (or recorded REJECT-as-wrong). Do not skip Extra High/Max when those slugs exist.

**APPLY ACCEPT completeness (HARD):** After review, APPLY ACCEPT / fix MUST land **every finding that is not wrong**, including **Low, deferred, nitpicks, and minor** items that are still applicable. Skip only: KEEP REJECT / user-locked rejects, factually wrong findings, superseded/stale claims, and items that are no longer true on the current freeze. Do **not** treat “CLEAN for ladder purposes” or “non-blocking nit” as a reason to skip a still-valid nit. Anti-churn for historical changelog / KEEP REJECT aliases still applies — do not reopen KEEP REJECT. The fix step is launcher APPLY ACCEPT, not a fixer rung.

**Anti-stall (Policy B leftover loop — HARD):** Do not idle waiting for the user between required state-machine steps. Policy C reports still happen; they do not pause the loop.

- After each verify **FAIL**, Policy B the leftovers in the **same** follow-up turn (launcher Edit/Write; still one subagent `Task` per turn), then launch re-verify as the next Task. Do not wait for the user.
- After **CLEAN** `verify_1` and clean orchestrator grep, immediately launch `verify_2`. After two **CLEAN** verifies + greps, immediately start the next rung.
- **Corpus sweep, not one-line cycles:** If the same defect class fails verify more than **twice**, the next Policy B pass MUST scan **all** in-scope plan/spec artifacts for that class and patch every live hit in one pass.
- **Cap residual loops:** After **5** leftover cycles on the same rung verify, STOP and escalate to the user with the remaining `file:line` list. Do not start a sixth one-line patch.
- **Launch/timeout retry then skip (HARD):** If a rung’s subagent **cannot be launched** or **times out** (timeout, empty/"Let" after re-spawn, OpenCode `Endpoint is unavailable`, hung invoke with no `review.md`), retry **once immediately**. If that second attempt also fails to produce a verdict, **skip** the rung and continue the ladder. After the **entire ladder** finishes, **retry skipped rungs once more**. Record skip/retry in the rung dir (`SKIPPED.md` plus launcher skip/retry JSON: reason, attempt count, timestamps, next rung, `post_ladder_retry_pending`). Encoder: `python3 scripts/review-fix-ladder.py --launch-policy` / `--skip-artifact`. Do **not** skip because of a CLEAN/NOT CLEAN review — only when the rung **failed to produce a verdict**. Mixed-host: skip does not change the next rung’s required model. Skipping a rung is **not** permission to use Fast or a different family as a silent substitute **on that skipped rung**. **Never Fast.**

### Policy C — launcher reports after every rung

After each rung's review is in (CLEAN or NOT CLEAN), the launcher (the agent that started the RFL) must message the user with a severity-grouped update. Do this after every rung, not only at family or ladder end. Do not dump raw review.md.

These launcher steps are **mandatory** (not optional prose). The **RFL launcher agent** (parent, not the rung model) MUST:

1. Present reported issues as a **table grouped by severity** (HIGH / MED / LOW / NIT). Empty groups still show **none**.
2. **Triage** the issues (Policy A: wrong vs not wrong). The rung model does not triage.
3. Present a **triage table** (accepted vs rejected/invalid + reason).
4. **Fix** accepted issues (Edit/Write). The rung model does not implement.
5. After fixes, present the table again with a **Resolved** column.

Encoder: `python3 scripts/review-fix-ladder.py --issue-table|--triage-table|--resolved-table|--launcher-steps`.

The update MUST also include:

- **Rung identity** — family + High / Extra High / Max
- **Verdict** — CLEAN or NOT CLEAN
- **Blockers / Highs / Mediums** — map onto HIGH / MED; LOW and NIT have their own groups — one line or table row each finding, or **none**
- **Disposition** — whether findings are being ACCEPT-applied before the next rung, or REJECT-as-wrong (with why)

CLEAN with no findings still gets the three **none** lines. Empty HIGH / MED / LOW / NIT groups still show **none**. The severity-grouped list is the update.

### Policy D — ladder-complete matrix (HARD)

When the whole ladder completes, the launcher MUST present a summary matrix:

| Rung | Reviewer | HIGH | MED | LOW | NIT | Reported | Accepted |

Severity columns = reported counts; **Accepted** = after launcher triage (rejects excluded). Footnote ID collisions / CLEAN rungs / skipped-then-retried rungs.

Encoder: `python3 scripts/review-fix-ladder.py --ladder-matrix`.

## When to Use

- Pre-ship confidence on launch-critical artifacts
- Bounded directories, files, or planning artifacts that need progressive review
- Repo-wide alignment checks **only after the user explicitly confirms repo-wide scope**

## Step 0: Resolve Scope

**Do not assume repo-wide scope.**

1. If `$ARGUMENTS` or the user message names explicit file path(s) or directory/directories, lock scope to those paths only.
2. Otherwise, stop and ask:

   > Review scope: whole repo, or specific artifact(s)/directory/directories?  
   > (If specific, provide path(s).)

3. Proceed only after scope is explicit from the initial request or the user's answer.
4. Do **not** derive the charter or resolve the ladder until scope is locked.

| Mode | Trigger | Scope |
|------|---------|-------|
| Explicit scope | User names paths in prompt or `$ARGUMENTS` | Only those paths |
| User-confirmed repo-wide | General invocation → user chooses whole repo | Entire project repo |
| User-provided scope | General invocation → user supplies paths when asked | User-provided paths |

### Scope Lock (HARD)

- **FORBIDDEN** to read, edit, or run commands against paths outside locked scope.
- If scope is two files, **zero** commands in other repos, directories, or test suites.
- Subagents MUST receive the exact locked path list; they MUST NOT expand scope.

## Step 1: Derive Review Charter

Build a short charter from available context. Use what exists; do not invent requirements.

**Primary sources (priority order):**

1. User's explicit request in the current turn
2. `.planning/` artifacts: `SPEC.md` acceptance criteria, `REQUIREMENTS.md`, active `PLAN.md`, `ROADMAP.md` phase goals, `DESIGN.md` constraints
3. `silver-bullet.md` and `.planning/workflows/*.md` exit conditions
4. Recent session logs or handoff notes under `docs/sessions/`

**Required charter output (show to user):**

1. **Scope** — confirmed paths or “whole repo”
2. **Goals** — intended outcomes to verify against
3. **Non-goals** — out of scope for this ladder pass
4. **Verification signals** — grep patterns, line checks, manual checks that prove a goal is met (list each signal with an exact command or search pattern the orchestrator will run)

If context is thin, state assumptions explicitly and keep the charter narrow.

## Step 2: Resolve Ladder

From the project root:

```bash
python3 scripts/review-fix-ladder.py --json
```

Add `--host <runtime> (from `SILVER_BULLET_RUNTIME`) when the host is known.

Print the resolved `host`, `source`, and ordered `rungs` (`model` + `reasoning`) before executing.

## Step 3: Execute Ladder — State Machine (HARD)

### Compliance Gate (MUST run before every rung advance)

**Before starting rung N+1** (or before declaring the ladder complete), the orchestrator MUST self-check the rung just finished. If **any** check fails → **STOP immediately**. Do **not** start the next rung. Do **not** continue advancing while non-compliant.

| Check | Pass criterion |
|-------|----------------|
| Sequential rung | Previous rung completed all states in order: `review` → `triage` → `file_valid_issues` → `fix_parallel` → `verify_1` → orchestrator grep → `verify_2` → orchestrator grep — **or** the previous rung was skipped after launch/timeout retry-once-then-skip with `SKIPPED.md` recorded |
| Review/triage separation | Review subagent did **not** triage or fix; launcher/parent triaged with Policy A (wrong vs not wrong), not the rung model |
| Per-rung user report | After review returned, launcher posted the mandatory Policy C tables (issue table by HIGH/MED/LOW/NIT, triage table, then resolved table after ACCEPT fixes) plus a severity-grouped Blockers / Highs / Mediums update (or **none**) to the user; did this after every rung, not only at family or ladder end; did not dump raw review.md |
| PM filing evidence | When PM tracking is in use, ACCEPT findings filed or deduped via `/silver:add`; triage table lists PM ids. Does not delay launcher ACCEPT application |
| Fix owner | Launcher/parent applied ACCEPT fixes (Edit/Write); the rung model did **not** implement; did not re-ask the same rung to patch after NOT CLEAN |
| Separate verify invocations | `verify_1` and `verify_2` were **separate** subagent `Task` calls — not one combined prompt |
| Orchestrator grep | Orchestrator ran **every** charter verification signal between verify passes and logged command + output + pass/fail |
| Scope | No reads, edits, or commands touched paths outside locked scope |
| Readonly verify | Both verify subagents used `readonly: true` (Task-capable hosts) or explicit verify-only directive |
| No parallel rungs | No other rung's audit-fix or verify was launched while this rung was incomplete |
| Advance gate | Advanced to next rung **only** after orchestrator confirmed **two consecutive clean** verify passes **and** ACCEPTs applied (or REJECT-as-wrong recorded) — **or** after launch/timeout retry-once-then-skip with `SKIPPED.md` (incomplete rung; not a CLEAN advance). After the whole ladder, skipped rungs are retried once more. |

**On failure:** STOP. Report the violation. Fix the process, skill, or orchestrator prompt. Resume **only** after the fix is in place — re-run the failed phase on the **same** rung, not the next rung.

### Full-Ladder Requirement

- **Default:** Execute **every resolved rung** in order. A clean rung is not a completion condition; it is the gate that permits advancement to the next rung. **Timeout skip:** cannot-launch or timeout → retry once immediately → skip (`SKIPPED.md`) and continue; after the whole ladder, retry skipped rungs once more. This is not a CLEAN advance and not a Fast/family substitute.
- **Two consecutive clean rounds per rung:** For each rung, `verify_1` and `verify_2` must both be clean, and the orchestrator verification signals after each pass must also be clean.
- **Advance after clean rung:** After two consecutive clean rounds, clean orchestrator signals, and launcher ACCEPT application (or REJECT-as-wrong), the orchestrator MUST advance to rung N+1 unless N is the final resolved rung.
- **CLEAN with leftover findings:** If a rung returns CLEAN with findings that are not wrong, the launcher still applies them before the next rung.
- **Stop after first compliance failure** — never "push through" remaining rungs while the process is broken.
- A smoke demonstration may be run only when the user explicitly asks for a smoke test; otherwise the ladder must continue through the final resolved rung.

### STOP Conditions (immediate halt)

STOP and do **not** advance when any of the following is true:

1. **Compliance gate failure** — any row in the compliance gate table fails
2. **Skipped state** — tempted to skip review, triage, PM filing, fix, either verify pass, or orchestrator grep — **except** Policy B launch/timeout retry-once-then-skip (`SKIPPED.md` then start the next rung; post-ladder retry of skipped rungs once more)
3. **Combined verify passes** — one subagent asked to "do 2 passes" or verify_1 and verify_2 merged
4. **Subagent-only gate** — advancing on subagent VERIFY_PASS without orchestrator grep evidence
5. **Scope violation** — any command or edit outside locked paths
6. **Parallel rungs** — multiple rung phases launched in one turn or overlapping
7. **Verify subagent edited files** — verify pass was not readonly
8. **Final rung complete** — the last resolved rung completed `review` → `triage` → `file_valid_issues` → `fix_parallel` → `verify_1` → orchestrator signals → `verify_2` → orchestrator signals with no gaps
9. **User stop** — user directs halt or scope change
10. **Unapplied ACCEPTs** — next rung started before the launcher applied ACCEPTs (or recorded REJECT-as-wrong)
11. **Skipped Policy C report** — review returned without the mandatory launcher tables (issue table by HIGH/MED/LOW/NIT, triage table, resolved table after fixes) and Blockers / Highs / Mediums (or **none**)
12. **Leftover-cycle cap** — five leftover Policy B cycles on the same rung verify without CLEAN; escalate the remaining `file:line` list instead of a sixth one-line patch

### Recovery Procedure (before resuming)

When STOP triggers for compliance (items 1–7):

1. **Report** — state which check failed, what was attempted, and what evidence is missing
2. **Fix root cause** — update orchestrator behavior, subagent prompt, or skill/process gap (not "try again blindly")
3. **Re-anchor state** — document current state machine position (`rung_N_verify_1`, etc.)
4. **Re-run failed phase** — on the **same** rung, from the first failed state (usually re-run verify or re-run audit-fix if verify found gaps)
5. **Re-run compliance gate** — only after a clean re-run may you advance, or close out if the final resolved rung is complete
6. **Do not skip ahead** — never compensate for a compliance failure by jumping to a higher rung

### Explicit States Per Rung

For rung N, the orchestrator MUST traverse these states in order:

```
rung_N_review → rung_N_triage → rung_N_file_valid_issues → rung_N_fix_parallel → rung_N_verify_1 → [orchestrator grep] → rung_N_verify_2 → [orchestrator grep] → rung_N+1_review
```

**STOP** if tempted to skip any state, combine verify passes, stop early because the charter is satisfied, or advance without orchestrator evidence.

### Anti-Skip Rules (MUST / FORBIDDEN)

1. **One rung at a time** — **FORBIDDEN** to launch multiple ladder rungs in parallel. **FORBIDDEN** to batch `Task` calls for different rungs in one turn. Exactly one subagent `Task` per turn. Anti-stall means **no user-wait** between phases (Policy B leftovers, then the next verify Task) — not parallel Tasks. After launch/timeout **retry once** with still no verdict, skip that rung (`SKIPPED.md`) and start the next rung in the **following** turn — still one Task per turn. After the whole ladder, retry skipped rungs **once more**.

2. **Two-pass gate** — Per rung:
   - (a) review-only subagent (raw findings, no triage/fix)
   - (b) launcher/parent posts Policy C user update (rung identity, verdict, HIGH/MED/LOW/NIT issue table, triage table, ACCEPT-apply vs REJECT-as-wrong; resolved table after fixes), then triages with Policy A (ACCEPT vs REJECT-as-wrong) — **not** the rung model
   - (c) orchestrator files ACCEPT items via `/silver:add` when PM tracking is in use (or confirms dedupe links)
   - (d) launcher/parent applies ACCEPT fixes with Edit/Write — **not** the rung model; **FORBIDDEN** to ask the same Composer/GLM/Kimi/Codex/Claude/OpenCode rung to patch after NOT CLEAN
   - (e) verify-only subagent pass 1 — if clean, proceed; if fail, return to (d) on **same** rung
   - (f) verify-only subagent pass 2 — only if pass 1 was clean
   - Advance to rung N+1 **only** if **both** verify passes are clean **and** ACCEPTs are applied (or REJECT-as-wrong recorded); after they are clean, advancement is mandatory unless N is the final resolved rung.
   - **FORBIDDEN** to combine passes into one subagent prompt (e.g. "do 2 passes" in a single Task).
   - **FORBIDDEN** to advance after only one clean verify pass.
   - **FORBIDDEN** for review subagent to triage or fix its own findings.
   - **FORBIDDEN** to reject a finding as "advisory", "doc-only", "documentation nit", "non-gating", "nice-to-have", "not a contract hole", "CLEAN so ignore mediums", "CLEAN for ladder purposes", or "non-blocking nit".
   - **FORBIDDEN** to skip the per-rung Policy C user update, to wait until family or ladder end, or to dump raw review.md in place of the severity-grouped list.

3. **Verify-only passes** — Subagents on verify passes MUST NOT edit files. Use `readonly: true` on the host `Task` tool or explicit "verify only, no edits" in the prompt. **FORBIDDEN** for verify subagents to apply fixes.

4. **Orchestrator evidence** — The orchestrator MUST run charter verification signals (grep/checks) between verify passes and record pass/fail with command output. **FORBIDDEN** to advance on subagent self-reported PASS alone. Subagent reports are input; orchestrator grep is the gate.

5. **Scope lock** — **FORBIDDEN** to read/edit/run tests outside locked scope paths.

6. **Model lock** — Each rung uses exactly the `model` + `reasoning` from resolver JSON. **FORBIDDEN** to substitute models unless the host rejects the slug — then document the rejection and use the nearest host-documented slug, one substitution per rung. Do not skip Extra High/Max when those slugs exist. Skipping a hung rung after launch/timeout retry-once-then-skip is **not** permission to run that skipped rung on Fast or a different family; leave it incomplete and continue at the **next** rung’s required model. Do **not** remap RFL GPT/Claude rungs onto Grok High.

7. **State machine** — Document current state in close-out (`rung_N_review`, `rung_N_triage`, `rung_N_file_valid_issues`, `rung_N_fix_parallel`, `rung_N_verify_1`, etc.). **STOP** if tempted to skip.

8. **No parallel rung launches** — **FORBIDDEN** to launch review for rung N+1 while rung N verify is incomplete or ACCEPTs remain unapplied.

9. **Launcher triage and apply** — Triage and ACCEPT application are done by the ladder launcher/parent, **not** the rung `model` + `reasoning` from resolver JSON. Only the **review** (and verify) subagent uses the rung model pair. Inside an RFL session this is an explicit exception to parent-orchestrator-never-implements.

### Per-Rung Workflow (Orchestrator Checklist)

For rung `{n}/{total}` at `model={model}`, `reasoning={reasoning}`:

| Step | State | Action |
|------|-------|--------|
| 1 | `rung_N_review` | Launch **one** review-only subagent at rung model (raw findings only). **Cursor:** subscription-first for GPT/Claude (see Host Delegation); otherwise `Task(subagent_type=<subagent_name>)` |
| 2 | `rung_N_triage` | **Policy C (mandatory):** launcher presents HIGH/MED/LOW/NIT issue table, triages, presents triage table (accepted vs rejected + reason), applies ACCEPT fixes, then presents the resolved table. Also message rung identity, verdict, Blockers / Highs / Mediums (or **none**), and ACCEPT-apply vs REJECT-as-wrong. Do **not** spawn the rung model to classify or reject as "advisory". Do this after every rung. Do not dump raw review.md. |
| 3 | `rung_N_file_valid_issues` | Orchestrator files ACCEPT items via `/silver:add` when PM tracking is in use; record PM ids in triage table |
| 4 | `rung_N_fix_parallel` | Launcher/parent applies ACCEPT fixes (Edit/Write), including every finding that is not wrong (**Low, deferred, nitpicks, and minor** if still applicable). **FORBIDDEN** to ask the same Composer/GLM/Kimi/Codex/Claude/OpenCode rung to patch; **FORBIDDEN** to skip a still-valid nit because the rung was CLEAN or the item is a "non-blocking nit" |
| 5 | `rung_N_verify_1` | Launch **one** verify-only subagent pass 1 at rung model. **Cursor:** same routing as review (subscription-first for GPT/Claude; else `Task`) |
| 6 | — | Orchestrator runs each charter verification signal; log pass/fail |
| 7 | `rung_N_verify_2` | If step 6 clean: launch **one** verify-only subagent pass 2 at rung model. **Cursor:** same routing as review (subscription-first for GPT/Claude; else `Task`) |
| 8 | — | Orchestrator runs charter signals again; log pass/fail |
| 9 | advance | If steps 6 **and** 8 are clean **and** ACCEPTs are applied (or REJECT-as-wrong recorded), advance to rung N+1 unless N is the final resolved rung; else return to step 4 |

### Repo-wide mode (only after user confirms)

- Walk systematically against charter goals; do not run a blind full-tree audit.
- Prefer high-signal surfaces first: changed files, planning artifacts, entrypoints, tests, configs tied to stated goals.
- Do not expand scope beyond charter non-goals.
- If charter goals are phase-specific, limit edits to that phase's blast radius unless a repo-wide invariant is broken.

## Step 4: Close Out

Report:

- **Per-rung Policy C updates** — already posted after each review (rung identity, verdict, HIGH/MED/LOW/NIT issue table, triage table, resolved table, Blockers / Highs / Mediums or **none**, ACCEPT-apply vs REJECT-as-wrong); do not replace those with a raw review.md dump at close-out
- **Ladder-complete matrix** — Rung / Reviewer / HIGH / MED / LOW / NIT / Reported / Accepted (Accepted = after launcher triage; footnote ID collisions / CLEAN / skipped-then-retried)
- **Compliance log** — per rung: compliance gate pass/fail, any STOP events, recovery actions taken
- Per-rung pass table: rung → verify_1 evidence → verify_2 evidence → advanced (yes/no)
- Triage table: ACCEPT vs REJECT-as-wrong (with why-wrong evidence)
- Charter coverage matrix (goal → evidence / status)
- Residual risks
- Files touched (scoped paths only)
- Final rung reached and **why stopped** (final resolved rung complete, compliance failure, or user stop)

## Host Delegation Notes

### Cursor rung routing (custom subagents)

Resolve the ladder first (`python3 scripts/review-fix-ladder.py --host cursor --json --project-root .`). Each Cursor rung includes:

| Field | Meaning |
|-------|---------|
| `delegation` | `custom-subagent` — Cursor `Task` fallback with `subagent_type` set to `subagent_name` |
| `subagent_name` | Installed `sb-*` custom subagent slug (e.g. `sb-composer-2-5-medium`) |
| `model_param` | Optional `Task` `model` override when required; Composer rungs use `composer-2.5` only |
| `subscription_first` | `true` for GPT and Claude/Opus rungs — try the subsidized host CLI before Cursor Task |
| `subscription_invoke` | `scripts/agent-codex/invoke.sh` (GPT) or `scripts/agent-claude/invoke.sh` (Claude/Opus) |

**Subscription-first (GPT / Claude) — every launch, including re-verify and Max:** Cursor GPT/Claude quota is far less subsidized than Codex/Claude subscriptions. Before every GPT or Claude/Opus **review** and **verify** launch:

1. Run `python3 scripts/review-fix-ladder.py --decide-launch --model {model} --reasoning {reasoning}`.
2. If `action` is `invoke_subscription`: invoke `/silver:agent-codex` (GPT) or `/silver:agent-claude` (Claude/Opus) via the existing `subscription_invoke` helper — do **not** invent a second spawn stack.
3. Re-run `--decide-launch` with `--subscription-exit` and `--subscription-output` / `--subscription-output-file` from that attempt.
4. `accept_subscription` (success, including a NOT CLEAN review) — **do not** also launch Cursor Task for that rung.
5. `cursor_fallback` (`reason: quota-exhaustion` only) — log host + matched signal, run `--mark-quota-fallback --quota-host <codex|claude> --quota-signal '<signal>'`, then spawn **one** `Task(subagent_type=<subagent_name>)`.
6. `fail` (`missing-cli`, `hash-mismatch`, or other non-quota failure) — **do not** fall back to Cursor. Missing CLI: install/fix or fail clearly. HASH MISMATCH: relaunch still goes through this gate (subscription first again).

Quota exhaustion signals (narrow): `429`, `rate limit`, `token plan`, `out of quota`, `quota retries exhausted` / `quota exhaust|exceed`, `usage cap` / `usage limit`, `billed-quota`, `over quota`, or in-repo bare `quota` after missing-CLI and HASH MISMATCH are ruled out.

**Not quota (no Cursor fallback):** brief bugs, HASH MISMATCH, missing CLI install, network blips, NOT CLEAN review results.

Grok and Composer default to Cursor (`/silver:agent-cursor`). Gemini defaults to Gemini CLI if the user did not name an agent, else Pi, else OpenCode, else Cursor. GPT defaults to Codex (`/silver:agent-codex`). Claude defaults to Claude (`/silver:agent-claude`). Other models default to Pi or OpenCode, or any other external agent the user named. User `--user-agent` / named host always wins. Do **not** smash host `--mode` permission flags. Do **not** remap RFL GPT/Claude rungs onto Grok High. Encoder: `python3 scripts/review-fix-ladder.py --default-host-route --model {model}`.

Grok, Composer, GLM, Gemini, and Kimi rungs still skip the GPT/Claude **subscription-first quota gate**. `--decide-launch` for those families does not invoke Codex/Claude. OpenCode family rungs are **not** Cursor `sb-*` Tasks — see **OpenCode Go models** below.

**Routing rule:** For **review** and **verify**, follow `--decide-launch` (GPT/Claude subscription-first) and `--default-host-route` (family → `/silver:agent-*` host; user override wins). Non-GPT/Claude on Cursor: spawn `Task(subagent_type=<subagent_name>)` when the default host is Cursor. **Omit `model`** when the custom subagent encodes the rung model — **except** empty/"Let" re-spawns below. **Never Fast.**

**Empty / "Let" nested Tasks:** If a nested `Task` returns empty or dies after "Let", the parent MUST re-spawn immediately with an explicit `model` so the child does not inherit the wrong wrapper. Do not wait for the user. Mixed-host ladders: nested GLM under Grok dies after "Let"; parent re-spawns with explicit GLM model (do not nest GLM under Grok). Never Fast. Empty/"Let" after re-spawn with still no review counts as a launch/timeout failure: retry **once immediately**, then skip (`SKIPPED.md`) — after the whole ladder, retry skipped rungs once more.

Phase routing detail:

```bash
python3 scripts/review-fix-ladder.py --host cursor --json --project-root . --rung 2 --phase verify_1
python3 scripts/review-fix-ladder.py --decide-launch --model gpt-5.6-sol --reasoning xhigh
```

For non-subscription `delegation: custom-subagent` (and GPT/Claude **after** quota fallback):

1. Read `subagent_name` from resolver JSON for the active rung.
2. Spawn **one** `Task` with `subagent_type: <subagent_name>` and the phase prompt (Template A or B).
3. On verify passes, also set `readonly: true`.
4. Do **not** pass `model` unless resolver emits `model_param` and host policy requires it — **except** when re-spawning after an empty/"Let" Task (then pass explicit `model`).

Install or refresh agents before the ladder: `bash scripts/install-cursor-sb-agents.sh` (see `scripts/lib/cursor-sb-agents/`).

| Host | Delegation |
|------|------------|
| **Cursor (custom subagent)** | GPT → `/silver:agent-codex` first; Claude/Opus → `/silver:agent-claude` first; Cursor `Task` **only** on quota exhaustion. Grok/Composer default host: `/silver:agent-cursor`. Gemini: Gemini CLI, else Pi, else OpenCode, else Cursor. Other families: Pi or OpenCode (or the agent the user named). User override wins. Do not smash host `--mode`. Do not remap GPT/Claude onto Grok High. Verify passes: `readonly: true`. **Forbidden:** Fast, `composer-2.5-fast`. Do not skip Extra High/Max when those slugs exist. Re-run the subscription gate on every GPT/Claude review/verify launch (not once per family). |
| **the active host agent** | Subagent with model `primary-model`, `primary host-opus-4-7`, or `primary host-opus-4-8` and thinking `medium`, `high`, or `xhigh` |
| **Secondary host agent** | `Codex exec -m <model> -c model_reasoning_effort=<reasoning>` (native Codex binary, not Kay shim) |

Model slug maps live in `scripts/review-fix-ladder.py` only — not in `silver-bullet.md`.

### OpenCode Go models (not Cursor `sb-*`)

OpenCode family rungs (DeepSeek, MiniMax, Qwen, and any other Go-listed model) **must** take model ids and display names from [OpenCode Go](http://opencode.ai/docs/go/) (live catalog also at `https://opencode.ai/zen/go/v1/models`). Re-fetch that page before naming a rung. **Do not** invent Cursor Task slugs such as `sb-opencode-max`, `sb-deepseek-*`, or treat “OpenCode Max” as a Cursor `subagent_type`.

Go lists **distinct model SKUs**, not High vs Max reasoning-effort tiers. “Max” / “Plus” / “Pro” / “Flash” in names such as Qwen3.8 Max, DeepSeek V4 Pro, and DeepSeek V4 Flash are product names, not Cursor-style High/Max effort. There is no `sb-opencode-max`.

**Quota STOP (once):** Codex/Claude usage-limit → Cursor subagent fallback (`cursor_fallback` above). OpenCode billed quota / weekly limit (user must replenish keys) → report STOP once and wait for the user; do **not** spin retries or invent Cursor `sb-*` stand-ins. **Unless** the failure is an unavailable/timeout class (timeout, empty/"Let" after re-spawn, OpenCode `Endpoint is unavailable`, hung invoke with no `review.md`): retry **once immediately**, then **skip the rung** and continue the ladder; after the whole ladder, retry skipped rungs once more. Do not skip because of CLEAN/NOT CLEAN.


## Subagent Prompt Templates

### Template A — Review-Only (`rung_N_review`)

Use for the review phase only. Subagent **must not** triage or fix — report raw findings only.

```
You are on rung {n}/{total}: model={model}, reasoning={reasoning}.
Phase: REVIEW-ONLY (rung_N_review)

Scope (do not exceed — FORBIDDEN to touch any other path):
{scope}

Review charter:
- Goals: {goals}
- Non-goals: {non_goals}
- Verification signals: {verification_signals}

Tasks:
1. Audit scoped work against the charter goals.
2. Report raw findings with line references and severity hints.
3. Do NOT classify, triage, file issues, or apply fixes.

FORBIDDEN behaviors:
- Do NOT triage findings (launcher/parent triages with Policy A after you return).
- Do NOT fix gaps — report only.
- Do NOT edit plans, specs, tests, or docs — no "while I'm here" fixes.
- Do NOT read/edit/run commands outside locked scope.
- Do NOT claim PASS or recommend advancing — orchestrator verifies.
- Do NOT launch subagents or parallel work.
```

### Template A2 — Triage (`rung_N_triage`)

Launcher / parent of the ladder triages **in-session** (not the rung model). Do **not** spawn the same Composer/GLM/Kimi/Codex/Claude/OpenCode rung to classify findings. After review returns, post the Policy C user update first (mandatory issue table → triage → triage table → fix → resolved table).

```
Phase: TRIAGE (rung_N_triage) — launcher/parent, NOT rung model

Scope: {scope}
Review charter: {goals}
Raw findings from review subagent:
{raw_findings}

Tasks:
1. Message the user with a severity-grouped Policy C update: rung identity (family + High / Extra High / Max), verdict, HIGH/MED/LOW/NIT issue table, triage table (accepted vs rejected + reason), Blockers / Highs / Mediums (one line each finding, or none), and whether findings are being ACCEPT-applied before the next rung or REJECT-as-wrong (with why). After ACCEPT fixes, re-present the table with a Resolved column. Do this after every rung. Do not dump raw review.md. CLEAN with no findings still gets the three none lines plus empty severity groups.
2. Incorporate every finding that is not wrong. Reject only if the finding is wrong or mistaken.
3. Classify each finding ACCEPT or REJECT-as-wrong (state why it is wrong).
4. Forbidden reject reasons: advisory, doc-only, documentation nit, non-gating, nice-to-have, not a contract hole, CLEAN so ignore mediums, CLEAN for ladder purposes, non-blocking nit.
5. Produce a triage table. Do not spawn a fix Task at the rung model.

FORBIDDEN: asking the rung model to patch; rejecting for severity or "advisory"; skipping the per-rung user update.
```

### Template A3 — Apply ACCEPT (`rung_N_fix_parallel`)

Launcher / parent applies ACCEPT fixes with Edit/Write after triage. This is an explicit exception to parent-orchestrator-never-implements **inside an RFL session**.

```
Phase: APPLY ACCEPT (rung_N_fix_parallel) — launcher/parent Edit/Write, NOT rung model

Scope: {scope}
Triage table: {triage_summary}

Tasks:
1. Apply every ACCEPT finding that is not wrong within scope (spec, and tests/docs if the finding is about those), including **Low, deferred, nitpicks, and minor** items that are still applicable.
2. Skip only KEEP REJECT / user-locked rejects, factually wrong findings, superseded/stale claims, and items that are no longer true on the current freeze. Do not reopen KEEP REJECT. Anti-churn for historical changelog / KEEP REJECT aliases still applies.
3. Do **not** treat “CLEAN for ladder purposes” or “non-blocking nit” as a reason to skip a still-valid nit.
4. Record REJECT-as-wrong with why-wrong evidence.
5. Smallest safe change.

FORBIDDEN: asking the same Composer/GLM/Kimi/Codex/Claude/OpenCode rung to patch the plan after NOT CLEAN.
FORBIDDEN: advancing to the next rung before ACCEPTs are applied (or REJECT-as-wrong recorded).
FORBIDDEN: skipping a still-valid Low, deferred, nitpick, or minor because the rung was CLEAN or the item is a "non-blocking nit".
```

### Template B — Verify-Only (`rung_N_verify_1` or `rung_N_verify_2`)

Use for verify pass 1 and pass 2 separately. Subagent **MUST NOT** edit files.

```
You are on rung {n}/{total}: model={model}, reasoning={reasoning}.
Phase: VERIFY-ONLY pass {pass_num}/2 (rung_N_verify_{pass_num})

Scope (read-only — FORBIDDEN to edit any file):
{scope}

Review charter:
- Goals: {goals}
- Non-goals: {non_goals}
- Verification signals: {verification_signals}

Tasks:
1. Re-read scoped files and audit against charter goals.
2. Report findings with line references. List any remaining gaps.
3. State VERIFY_PASS or VERIFY_FAIL with evidence — do not fix anything.

FORBIDDEN behaviors:
- Do NOT edit, write, or patch any file (verify only).
- Do NOT run fixes or suggest "I'll fix this" — report only.
- Do NOT combine this with pass 2 — this is exactly one verify pass.
- Do NOT read/edit/run commands outside locked scope.
- Do NOT launch subagents or parallel work.
```

### Orchestrator Between Verify Passes

After each verify-only subagent returns, the orchestrator MUST:

1. Run every charter verification signal (grep, line count, pattern checks).
2. Record command + output + pass/fail.
3. Only proceed to the next verify pass if signals are clean; after `verify_2`, proceed to the next rung if signals are clean, ACCEPTs are applied (or REJECT-as-wrong recorded), and another resolved rung remains.
4. **IGNORE** subagent VERIFY_PASS if orchestrator signals fail.
5. If verify returns CLEAN with findings that are not wrong, apply those ACCEPTs before the next rung.
6. **Do not idle:** verify FAIL → Policy B leftovers then re-verify; CLEAN `verify_1` → grep then `verify_2`; two CLEAN verifies + greps → next rung. Same defect class failing verify more than twice → corpus sweep on the next Policy B. After 5 leftover cycles on this rung verify, escalate `file:line` leftovers instead of a sixth one-line patch. Launch/timeout: retry once immediately, then skip (`SKIPPED.md`) and start the next rung; after the whole ladder, retry skipped rungs once more.
