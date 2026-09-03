---
name: silver-review-fix-ladder
description: Progressively review and fix scoped artifacts or user-confirmed repo-wide work by escalating through every rung of a host-aware model/reasoning ladder. Policy F: two consecutive CLEAN reviews (zero ACCEPT findings) at each rung before the next model. Policy G / pack-ledger: encoder --write-review-brief is the only legal hop brief. Canonical verify overlay: verify_2 required on CLEAN, skipped on already-triaged NOT CLEAN. Use for pre-ship confidence, launch-critical artifacts, and repo alignment checks against context-derived goals.
user-invocable: false
---

# /silver:review-fix-ladder — Progressive Review / Fix Ladder

Escalate review and fix work through a host-aware model/reasoning ladder. Each rung audits against a context-derived review charter — not generic “find issues” heuristics. The launcher applies ACCEPT fixes; the rung model does not implement. The launcher reports findings after every rung. Before launching rungs, the parent/launcher MUST present a concise bullet list of only the key tasks and instructions and get user approval — do not dump the entire prompt.

**Orchestrator role:** The parent agent (you) MUST personally orchestrate every rung. Subagents execute one phase at a time. You MUST NOT delegate the ladder loop itself to a single subagent.

**RFL session exception:** Inside a review-fix-ladder session, the launcher / parent of the ladder triages findings and applies ACCEPT fixes with Edit/Write. This is an explicit exception to any "parent orchestrator never implements" rule. Rung workers remain REVIEW ONLY.

## Triage and Fix Owner (HARD)

Applies to **both ladders, all rungs**.

**Policy map (A–G).** **F** (ladder completion) and **G** (hop review / pack-ledger) are orthogonal — do not smash F into G. A–E remain distinct launcher/process locks. KEEP REJECT is a **product lock**, not a sixth policy letter.

| Letter | Contract |
|--------|----------|
| **A** | Triage: wrong vs not wrong (not severity) |
| **B** | Who applies: launcher APPLY ACCEPT; leftover loop |
| **C** | Per-rung report artifacts (`POLICY-C.json` / `.md`) |
| **D** | Ladder-complete matrix |
| **E** | Rung-prompt user-approval (launch gate) |
| **F** | Ladder completion: 2 consecutive CLEAN on unchanged SHA; `accept-apply` resets that rung's streak; `--assert-rfl-advance` requires streak 2 + canonical verify filenames |
| **G** | Hop review / **pack-ledger**: `--write-review-brief` is the only legal review brief; do not re-report ledger rows; file all valid residuals at this SHA, all severities including nits; CLEAN only if none remain; ACCEPT → pack APPLY; invalid REJECT |

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

**APPLY ACCEPT completeness (HARD):** After review, APPLY ACCEPT / fix MUST land **every finding that is not wrong**, including **Low, deferred, nitpicks, and minor** items that are still applicable. Pack APPLY (all ACCEPTs including nits, ordered if dependent) is **Policy G / pack-ledger** — this section is **who** applies. Skip only: KEEP REJECT / user-locked rejects, factually wrong findings, superseded/stale claims, and items that are no longer true on the current freeze. Do **not** treat “CLEAN for ladder purposes” or “non-blocking nit” as a reason to skip a still-valid nit. Anti-churn for historical changelog / KEEP REJECT aliases still applies — do not reopen KEEP REJECT. The fix step is launcher APPLY ACCEPT, not a fixer rung.

**Anti-stall (Policy B leftover loop — HARD):** Do not idle waiting for the user between required state-machine steps. Policy C reports still happen; they do not pause the loop. **Exception:** Policy E rung-prompt user-approval is a **launch gate** — wait for approval before the first reviewer Task / Pi invoke (and again if the brief's key tasks materially change). After `approved: yes`, anti-stall still applies.

- After each verify **FAIL**, Policy B the leftovers in the **same** follow-up turn (launcher Edit/Write; still one subagent `Task` per turn), then launch re-verify as the next Task. Do not wait for the user.
- After **CLEAN** `verify_1` and clean orchestrator grep, immediately launch `verify_2`. On already-triaged **NOT CLEAN**, skip `verify_2` (`verify_1` still required). After required CLEAN verifies + greps, immediately start the next rung or same-model re-review.
- **Corpus sweep, not one-line cycles:** If the same defect class fails verify more than **twice**, the next Policy B pass MUST scan **all** in-scope plan/spec artifacts for that class and patch every live hit in one pass.
- **Cap residual loops:** After **5** leftover cycles on the same rung verify, STOP and escalate to the user with the remaining `file:line` list. Do not start a sixth one-line patch.
- **Launch/timeout retry then skip (HARD):** If a rung’s subagent **cannot be launched** or **times out** (timeout, empty/"Let" after re-spawn, OpenCode `Endpoint is unavailable`, OmniRoute/OpenCode `401` `Missing API key` / `invalid_api_key`, hung invoke with no `review.md`), retry **once immediately**. If that second attempt also fails to produce a verdict **and the failed host is OpenCode or Pi** (including Pi `PI_PROVIDER=omniroute` / `opencode-go/*` slugs): **do not skip** — substitute Cursor **Grok 4.6 High** (`cursor-grok-4.6-high` / `sb-grok-4-6-high`). Never Fast. Never Extra High as the unspecified default. Encoder: `python3 scripts/review-fix-ladder.py --launch-policy --host opencode|pi --attempts 2 --outcome cannot_launch` → `substitute_grok`. For other hosts, **skip** the rung and continue the ladder. After the **entire ladder** finishes, **retry skipped rungs once more**. Record skip/retry in the rung dir (`SKIPPED.md` plus launcher skip/retry JSON: reason, attempt count, timestamps, next rung, `post_ladder_retry_pending`). Encoder: `python3 scripts/review-fix-ladder.py --launch-policy` / `--skip-artifact`. Do **not** skip because of a CLEAN/NOT CLEAN review — only when the rung **failed to produce a verdict**. Mixed-host: skip does not change the next rung’s required model. Skipping a rung is **not** permission to use Fast or a different family as a silent substitute **on that skipped rung**. **Never Fast.**

### Policy C — launcher reports after every rung

These launcher steps are **mandatory**. **Artifact-first:** write/validate Policy C via the encoder, then paste encoder stdout to the user.

After each rung's review is in (CLEAN or NOT CLEAN), the launcher (the agent that started the RFL) must message the user with a severity-grouped update. Do this after every rung, not only at family or ladder end. Do not dump raw review.md.


Canonical files (both): `.planning/rfl-<id>/rung-NN-*/POLICY-C.json` and `POLICY-C.md`.

MUST include a **table grouped by severity** (empty groups still `"none"`), a **triage table**, and after APPLY a **Resolved** column:

1. Rung identity (family + High / Extra High / Max)
2. Verdict: CLEAN | NOT CLEAN | BLOCKED | SKIPPED
3. Issue table grouped HIGH / MED / LOW / NIT
4. Triage table: ACCEPT vs REJECT-as-wrong + reason (or n/a if no findings)
5. **Blockers / Highs / Mediums** (or none)
6. Disposition: ACCEPT-apply | REJECT-as-wrong | HOLD | SKIP
7. After APPLY: resolved table (`pending` only while `rung_N_fix_parallel`)

```bash
python3 scripts/review-fix-ladder.py --write-policy-c --rung-dir .planning/rfl-<id>/rung-NN-*/ --table-json-file POLICY-C.json
python3 scripts/review-fix-ladder.py --assert-policy-c --rung-dir .planning/rfl-<id>/rung-NN-*/
python3 scripts/review-fix-ladder.py --assert-rfl-advance --run-dir .planning/rfl-<id>/
python3 scripts/review-fix-ladder.py --issue-table|--triage-table|--resolved-table|--launcher-steps
python3 scripts/review-fix-ladder.py --issue-ledger|--write-review-brief --run-dir .planning/rfl-<id>/
```

`--write-review-brief` is **mandatory** for every review hop (the only legal review brief). Hand-written one-ID briefs are non-compliant.

CLEAN with no findings still gets the three **none** lines. FORBIDDEN: short verdict-only chat. FORBIDDEN: waiting until family/ladder end. FORBIDDEN: dumping raw review.md. Physical gate: `hooks/rfl-policy-c-gate.sh` + stop-check deny when `--assert-policy-c` / `--assert-rfl-advance` fail for an active `LADDER-STATUS.json`. New ladders MUST `--mark-ladder-status active` at start or the live run is invisible to the gate.

Sibling asserts (same encoder / gate; reuse `LADDER-STATUS.json` + `rfl_quota_retry.py`):

| Step | Artifact | Gate |
|------|----------|------|
| Policy C | `POLICY-C.json` + `.md` | before next phase |
| BLOCKED / quota | `BLOCKED.md` + `QUOTA-CLASSIFY.json` (`should_schedule`) | before next rung or substitute |
| Skip after retry-once | `SKIPPED.md` | before starting N+1 |
| STOP / compliance | `STOP.md` with which check failed | block advance |
| ACCEPT apply | `APPLY.md` or resolved table complete | before `rung_{N+1}_review` |
| Two verifies | `verify-1.md` required on NOT CLEAN and APPLY; `verify-2.md` required on CLEAN (APPLY-landed check); `verify_2` is skipped on already-triaged NOT CLEAN | before N+1 |
| Two consecutive CLEAN reviews | `LADDER-STATUS.json` `consecutive_clean_reviews` ≥ 2 | before `rung_{N+1}_review` (Policy F; SKIPPED.md path exempt) |
| Rung-prompt approval | `RUNG-PROMPT-APPROVAL.md` (`approved: yes`) | before first reviewer Task / Pi invoke; re-gate on material brief change |


### Policy D — ladder-complete matrix (HARD)

When the whole ladder completes, the launcher MUST present a summary matrix:

| Rung | Reviewer | HIGH | MED | LOW | NIT | Reported | Accepted |

Last row MUST be **TOTAL** summing HIGH, MED, LOW, NIT, Reported, and Accepted. Reviewer on TOTAL is `—`.

Severity columns = reported counts; **Accepted** = after launcher triage (rejects excluded). Footnote ID collisions / CLEAN rungs / skipped-then-retried rungs.

Encoder: `python3 scripts/review-fix-ladder.py --ladder-matrix`.
At ladder start (before rung 1 review), persist durable status so the Policy C gate can see the run: `python3 scripts/review-fix-ladder.py --mark-ladder-status active --run-dir .planning/rfl-<id>/ --rung-id <rung-dir-or-N> --current-phase <phase>`. New ladders MUST do this — a missing `LADDER-STATUS.json` makes an in-flight ladder invisible to `--assert-rfl-advance` auto-discovery.
When the ladder finishes or aborts, persist durable status so a later quota retry can detect “already over”: `python3 scripts/review-fix-ladder.py --mark-ladder-status completed --run-dir .planning/rfl-<id>/` (or `aborted`). Quota-retry activation uses `LADDER-STATUS.json` plus Policy D artifacts.

### Policy E — rung-prompt user-approval (HARD)

Before launching rungs, the **parent/launcher** MUST present a **concise bullet list of only the key tasks and instructions** that will go into the rung prompt(s), and **get user approval**. Do **not** dump the entire prompt.

**When:** Before the first rung of a ladder, and again if the rung brief's key tasks **materially change** (e.g. user retargets "review the plan" → "review SPEC template + kinds").

**What:** 5–12 bullets covering only what matters to the review:

- Artifact under review (path/kind — plan vs SPEC template; not a SHA dump of the freeze)
- KEEP REJECT / user-locked rejects (do not reopen)
- Findings format (raw findings, line refs, severity hints — no triage)
- Verify and APPLY ACCEPT are **out of scope for the reviewer**
- Model/access constraints that matter to this review (e.g. plan vs template; Cursor vs Pi)
- Scope lock and charter goals/non-goals in one line each when they affect the brief

**FORBIDDEN:** full Template A paste; SHA dump of the whole freeze; a 200-line brief; dumping the entire prompt.

**Until approved:** do not spawn reviewer Tasks / Pi invoke.

Persist a short record: `.planning/rfl-<id>/RUNG-PROMPT-APPROVAL.md` with the bullets plus `approved: pending|yes` and a timestamp. Write `approved: pending` before asking; set `approved: yes` only after the user approves. This wait is a **launch gate**, not a Policy B anti-stall violation — after approval, do not idle between required state-machine steps.

### Policy F — two consecutive CLEAN reviews per rung (HARD)

Per rung (**same model/effort**): the parent/launcher MUST keep launching that reviewer until **two consecutive review passes** produce **zero valid (ACCEPT-worthy) findings**. Do **not** launch the next ladder model until `consecutive_clean_reviews == 2`.

- **Valid** = would be ACCEPT (real template/kind/QC defects). Valid findings break the streak.
- **Wrong / REJECT / REJECT-as-wrong** findings do **not** break the streak (they are not valid feedback). A CLEAN pass with 0 findings, or a review whose triage is only REJECT, increments the streak.
- Any **ACCEPT** finding → APPLY after `verify_1` (and `verify_2` when CLEAN per overlay) → consecutive counter **resets to 0**. Then re-run **the same** model as review-only (not as a fixer). **FORBIDDEN** to ask that model to patch; the launcher applies ACCEPT.
- **CLEAN** with 0 findings counts as a streak increment. Two CLEANs in a row (or CLEAN + review with only REJECT) completes the rung for Policy F.
- **SKIPPED.md** after launch/timeout retry-once-then-skip is **not** a CLEAN streak; it is the existing skip path.
- Policy E key-task approval is unchanged: do not spawn reviewer Tasks / Pi invoke until `RUNG-PROMPT-APPROVAL.md` has `approved: yes`. Re-approval is only required when key tasks materially change — re-running the same rung for Policy F does not by itself require a new Policy E cycle.

Encoder (MUST run; parent MUST NOT launch next model while the gate fails):

```bash
python3 scripts/review-fix-ladder.py --record-rung-review-outcome clean --run-dir .planning/rfl-<id>/ --rung-id <rung-dir>
python3 scripts/review-fix-ladder.py --record-rung-review-outcome accept-apply --run-dir .planning/rfl-<id>/ --rung-id <rung-dir>
python3 scripts/review-fix-ladder.py --assert-rfl-advance --run-dir .planning/rfl-<id>/ --rung-dir <rung> --next-action next_rung_review
python3 scripts/review-fix-ladder.py --assert-consecutive-clean --run-dir .planning/rfl-<id>/ --rung-dir <rung>
```

`--assert-rfl-advance --next-action next_rung_review` and `--assert-consecutive-clean` **fail** when `LADDER-STATUS.json` `consecutive_clean_reviews` < 2 (unless SKIPPED.md). Track the counter per rung on `LADDER-STATUS.json` (`consecutive_clean_reviews` + `consecutive_clean_rung`). `--assert-rfl-advance` also requires **canonical verify filenames**: `verify-1.md` (or `verify_1.md`); `verify-2.md` (or `verify_2.md`) when the hop is CLEAN.

This is distinct from the **canonical verify overlay** below. Policy F is ladder completion (when the next **model** may start). Policy G is hop review / pack-ledger. Do not smash F into G.

### Canonical verify overlay (HARD)

Bake-in (not Extra High session-only):

- `verify_1` is **required** on already-triaged **NOT CLEAN** and after **APPLY**.
- `verify_2` is **required** on **CLEAN** (and the APPLY-landed check when ACCEPT was applied).
- `verify_2` is skipped on already-triaged **NOT CLEAN**.

### Policy G — hop review (pack-ledger) (HARD)

Stop **one-residual-per-round**. Each review hop MUST:

1. Use encoder `--write-review-brief` as the **only legal review brief**. Hand-written one-ID briefs are non-compliant. Receive an **issue ledger** of already identified findings: ID, severity, ACCEPT/REJECT, resolved y/n, SHA, one-line. **Residual-only** means **do not re-report ledger rows**, not “file only one new ID.”
2. File **all valid residuals at the current SHA**, **all severities** (HIGH / MED / LOW / nit). Valid nits must be filed. CLEAN only if nothing valid remains.
3. Triage still REJECTS invalid items (already encoded, false cite, KEEP REJECT collision). All **ACCEPT**ed items — including nits — are **APPLY’d as a pack** that pass (order-dependent findings together).
4. Orthogonal to Policy F (ladder completion). Do not restate F here.

Encoder (MUST run so launchers do not hand-maintain the ledger):

```bash
python3 scripts/review-fix-ladder.py --issue-ledger --run-dir .planning/rfl-<id>/
python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-<id>/
```

Paste the encoder stdout **Issue ledger** table into Template A / the rung brief. The encoder reads `ISSUE-LEDGER.md`, `POLICY-C*.json`, and freeze SHA from `LADDER-STATUS.json`. Canonical brief template: `templates/rfl-review-brief.md`.

FORBIDDEN: instructing the reviewer to file only one new ID, MED-only, or skip valid nits. FORBIDDEN: treating residual-only as a one-finding cap. FORBIDDEN: a hand-written one-ID brief in place of `--write-review-brief`.

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

Then run **Policy E**: present the 5–12 key-task bullets, persist `.planning/rfl-<id>/RUNG-PROMPT-APPROVAL.md`, and **get user approval** before executing. Do **not** dump the entire prompt. **Until approved:** do not spawn reviewer Tasks / Pi invoke.

## Step 3: Execute Ladder — State Machine (HARD)

### Compliance Gate (MUST run before every rung advance)

**Before starting rung N+1** (or before declaring the ladder complete), the orchestrator MUST self-check the rung just finished. If **any** check fails → **STOP immediately**. Do **not** start the next rung. Do **not** continue advancing while non-compliant.

| Check | Pass criterion |
|-------|----------------|
| Sequential rung | Previous rung completed all states in order: `review` → `triage` → `file_valid_issues` → `fix_parallel` → `verify_1` → orchestrator grep → (`verify_2` → orchestrator grep on **CLEAN**; `verify_2` is skipped on already-triaged **NOT CLEAN**) — **or** the previous rung was skipped after launch/timeout retry-once-then-skip with `SKIPPED.md` recorded |
| Review/triage separation | Review subagent did **not** triage or fix; launcher/parent triaged with Policy A (wrong vs not wrong), not the rung model |
| Per-rung user report | After review returned, `POLICY-C.json` + `POLICY-C.md` exist and `python3 scripts/review-fix-ladder.py --assert-policy-c --rung-dir <rung>` exits 0; launcher pasted encoder stdout (not a short verdict). Gate: `hooks/rfl-policy-c-gate.sh` |
| PM filing evidence | When PM tracking is in use, ACCEPT findings filed or deduped via `/silver:add`; triage table lists PM ids. Does not delay launcher ACCEPT application |
| Fix owner | Launcher/parent applied ACCEPT fixes (Edit/Write); the rung model did **not** implement; did not re-ask the same rung to patch after NOT CLEAN |
| Separate verify invocations | `verify_1` and `verify_2` were **separate** subagent `Task` calls — not one combined prompt |
| Orchestrator grep | Orchestrator ran **every** charter verification signal between verify passes and logged command + output + pass/fail |
| Scope | No reads, edits, or commands touched paths outside locked scope |
| Readonly verify | Both verify subagents used `readonly: true` (Task-capable hosts) or explicit verify-only directive |
| No parallel rungs | No other rung's audit-fix or verify was launched while this rung was incomplete |
| Advance gate | Advanced to next **model** **only** after Policy F (`consecutive_clean_reviews` ≥ 2: two consecutive reviews with zero ACCEPT findings; REJECT does not break the streak; ACCEPT-apply resets to 0) **and** canonical verify overlay (`verify_1` always; `verify_2` on CLEAN; `verify_2` is skipped on already-triaged NOT CLEAN) **and** ACCEPTs applied (or REJECT-as-wrong recorded) — **or** after launch/timeout retry-once-then-skip with `SKIPPED.md` (incomplete rung; not a CLEAN advance). After the whole ladder, skipped rungs are retried once more. Parent MUST NOT launch rung N+1 while `--assert-rfl-advance --next-action next_rung_review` or `--assert-consecutive-clean` fails. |
| Rung-prompt approval | Before the first reviewer Task / Pi invoke, `RUNG-PROMPT-APPROVAL.md` exists with the current 5–12 key-task bullets and `approved: yes`. Re-gated if those bullets materially changed. Did **not** dump the entire prompt. |

**On failure:** STOP. Report the violation. Fix the process, skill, or orchestrator prompt. Resume **only** after the fix is in place — re-run the failed phase on the **same** rung, not the next rung.

### Full-Ladder Requirement

- **Default:** Execute **every resolved rung** in order. A clean rung is not a completion condition; it is the gate that permits advancement to the next rung. **Timeout skip:** cannot-launch or timeout → retry once immediately → skip (`SKIPPED.md`) and continue; after the whole ladder, retry skipped rungs once more. This is not a CLEAN advance and not a Fast/family substitute.
- **Two consecutive CLEAN reviews per rung (Policy F):** Keep launching the **same** model/effort until two consecutive review passes have **zero valid (ACCEPT) findings**. REJECT does not break the streak. ACCEPT → APPLY (after verify overlay) → streak resets to 0 → re-review the same model. Parent MUST NOT launch the next ladder model until `consecutive_clean_reviews == 2`.
- **Canonical verify overlay:** `verify_1` required on NOT CLEAN and APPLY. `verify_2` required on CLEAN (and APPLY-landed check). `verify_2` is skipped on already-triaged NOT CLEAN.
- **Advance after clean rung:** After Policy F (two consecutive CLEAN reviews), the verify overlay, clean orchestrator signals, and launcher ACCEPT application (or REJECT-as-wrong), the orchestrator MUST advance to rung N+1 unless N is the final resolved rung.
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
8. **Final rung complete** — the last resolved rung completed `review` → `triage` → `file_valid_issues` → `fix_parallel` → `verify_1` → orchestrator signals → (`verify_2` → orchestrator signals on CLEAN; `verify_2` is skipped on already-triaged NOT CLEAN) with no gaps
9. **User stop** — user directs halt or scope change
10. **Unapplied ACCEPTs** — next rung started before the launcher applied ACCEPTs (or recorded REJECT-as-wrong)
11. **Skipped Policy C report** — review returned without `POLICY-C.json` / `POLICY-C.md`, or `--assert-policy-c` fails; write `STOP.md` with `check: policy_c` and do not advance
12. **Leftover-cycle cap** — five leftover Policy B cycles on the same rung verify without CLEAN; escalate the remaining `file:line` list instead of a sixth one-line patch
13. **Skipped Policy E approval** — reviewer Task / Pi invoke spawned before `RUNG-PROMPT-APPROVAL.md` shows `approved: yes` for the current key-task bullets, or the brief's key tasks materially changed without re-approval; write `STOP.md` with `check: rung_prompt_approval` and do not launch

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
rung_N_review → rung_N_triage → rung_N_file_valid_issues → rung_N_fix_parallel → rung_N_verify_1 → [orchestrator grep] → [rung_N_verify_2 → orchestrator grep on CLEAN; verify_2 is skipped on already-triaged NOT CLEAN] → rung_N+1_review
```

**STOP** if tempted to skip any state, combine verify passes, stop early because the charter is satisfied, or advance without orchestrator evidence.

### Anti-Skip Rules (MUST / FORBIDDEN)

1. **One rung at a time** — **FORBIDDEN** to launch multiple ladder rungs in parallel. **FORBIDDEN** to batch `Task` calls for different rungs in one turn. Exactly one subagent `Task` per turn. Anti-stall means **no user-wait** between phases (Policy B leftovers, then the next verify Task) — not parallel Tasks. After launch/timeout **retry once** with still no verdict, skip that rung (`SKIPPED.md`) and start the next rung in the **following** turn — still one Task per turn. After the whole ladder, retry skipped rungs **once more**.

2. **Two-pass gate** — Per rung:
   - (a) review-only subagent (raw findings, no triage/fix)
   - (b) launcher/parent posts Policy C user update (rung identity, verdict, HIGH/MED/LOW/NIT issue table, triage table, ACCEPT-apply vs REJECT-as-wrong; resolved table after fixes), then triages with Policy A (ACCEPT vs REJECT-as-wrong) — **not** the rung model
   - (c) orchestrator files ACCEPT items via `/silver:add` when PM tracking is in use (or confirms dedupe links)
   - (d) launcher/parent applies ACCEPT fixes with Edit/Write — **not** the rung model; **FORBIDDEN** to ask the same Composer/GLM/Kimi/Codex/Claude/OpenCode rung to patch after NOT CLEAN
   - (e) verify-only subagent pass 1 — required on NOT CLEAN and APPLY; if fail, return to (d) on **same** rung
   - (f) verify-only subagent pass 2 — required on CLEAN after pass 1 was clean; `verify_2` is skipped on already-triaged NOT CLEAN
   - Advance to rung N+1 **only** if Policy F is met (**two consecutive** reviews with zero ACCEPT findings; `--assert-consecutive-clean` / `--assert-rfl-advance --next-action next_rung_review` exit 0) **and** the verify overlay is met **and** ACCEPTs are applied (or REJECT-as-wrong recorded); after they are clean, advancement is mandatory unless N is the final resolved rung. After ACCEPT-apply, streak resets to 0 — re-launch the **same** model as review-only until Policy F is met. **FORBIDDEN** to ask that model to patch.
   - **FORBIDDEN** to combine passes into one subagent prompt (e.g. "do 2 passes" in a single Task).
   - **FORBIDDEN** to advance after only one clean verify pass when the hop is CLEAN (`verify_2` is skipped on already-triaged NOT CLEAN).
   - **FORBIDDEN** to advance to the next ladder model after only one CLEAN review (streak < 2).
   - **FORBIDDEN** for review subagent to triage or fix its own findings.
   - **FORBIDDEN** to reject a finding as "advisory", "doc-only", "documentation nit", "non-gating", "nice-to-have", "not a contract hole", "CLEAN so ignore mediums", "CLEAN for ladder purposes", or "non-blocking nit".
   - **FORBIDDEN** to skip the per-rung Policy C artifact (`--write-policy-c` / `--assert-policy-c`), to wait until family or ladder end, or to dump raw review.md / a short verdict in place of encoder stdout. The harness denies the next Task/Stop when the assert fails.

3. **Verify-only passes** — Subagents on verify passes MUST NOT edit files. Use `readonly: true` on the host `Task` tool or explicit "verify only, no edits" in the prompt. **FORBIDDEN** for verify subagents to apply fixes.

4. **Orchestrator evidence** — The orchestrator MUST run charter verification signals (grep/checks) between verify passes and record pass/fail with command output. **FORBIDDEN** to advance on subagent self-reported PASS alone. Subagent reports are input; orchestrator grep is the gate.

5. **Scope lock** — **FORBIDDEN** to read/edit/run tests outside locked scope paths.

6. **Model lock** — Each rung uses exactly the `model` + `reasoning` from resolver JSON. **FORBIDDEN** to substitute models unless the host rejects the slug — then document the rejection and use the nearest host-documented slug, one substitution per rung. Do not skip Extra High/Max when those slugs exist. Skipping a hung rung after launch/timeout retry-once-then-skip is **not** permission to run that skipped rung on Fast or a different family; leave it incomplete and continue at the **next** rung’s required model. Do **not** remap RFL GPT/Claude rungs onto Grok High.

7. **State machine** — Document current state in close-out (`rung_N_review`, `rung_N_triage`, `rung_N_file_valid_issues`, `rung_N_fix_parallel`, `rung_N_verify_1`, etc.). **STOP** if tempted to skip.

8. **No parallel rung launches** — **FORBIDDEN** to launch review for rung N+1 while rung N verify is incomplete or ACCEPTs remain unapplied.

9. **Launcher triage and apply** — Triage and ACCEPT application are done by the ladder launcher/parent, **not** the rung `model` + `reasoning` from resolver JSON. Only the **review** (and verify) subagent uses the rung model pair. Inside an RFL session this is an explicit exception to parent-orchestrator-never-implements.

10. **Rung-prompt user-approval** — **FORBIDDEN** to spawn reviewer Tasks / Pi invoke until Policy E is approved (`RUNG-PROMPT-APPROVAL.md` with `approved: yes`). **FORBIDDEN** to dump the entire prompt, paste full Template A, or SHA-dump the freeze in place of 5–12 key-task bullets. Re-run the gate if the brief's key tasks **materially change**. This launch-gate wait is **not** a Policy B anti-stall violation.

### Per-Rung Workflow (Orchestrator Checklist)

For rung `{n}/{total}` at `model={model}`, `reasoning={reasoning}`:

**Policy E (HARD):** Do not start step 1 until `.planning/rfl-<id>/RUNG-PROMPT-APPROVAL.md` has `approved: yes` for the current key-task bullets. Re-run the gate if those bullets **materially change**. **FORBIDDEN** to spawn reviewer Tasks / Pi invoke until approved. Do **not** dump the entire prompt.

| Step | State | Action |
|------|-------|--------|
| 1 | `rung_N_review` | Launch **one** review-only subagent at rung model (raw findings only). **Cursor:** subscription-first for GPT/Claude (see Host Delegation); otherwise `Task(subagent_type=<subagent_name>)` |
| 2 | `rung_N_triage` | **Policy C (mandatory, artifact-first):** `--write-policy-c` then `--assert-policy-c` (paste encoder stdout). Do **not** spawn the rung model to classify. Do not dump raw review.md or a short verdict. |
| 3 | `rung_N_file_valid_issues` | Orchestrator files ACCEPT items via `/silver:add` when PM tracking is in use; record PM ids in triage table |
| 4 | `rung_N_fix_parallel` | Launcher/parent applies ACCEPT fixes (Edit/Write), including every finding that is not wrong (**Low, deferred, nitpicks, and minor** if still applicable). **FORBIDDEN** to ask the same Composer/GLM/Kimi/Codex/Claude/OpenCode rung to patch; **FORBIDDEN** to skip a still-valid nit because the rung was CLEAN or the item is a "non-blocking nit" |
| 5 | `rung_N_verify_1` | Launch **one** verify-only subagent pass 1 at rung model. **Cursor:** same routing as review (subscription-first for GPT/Claude; else `Task`) |
| 6 | — | Orchestrator runs each charter verification signal; log pass/fail |
| 7 | `rung_N_verify_2` | On **CLEAN** (step 6 clean): launch **one** verify-only subagent pass 2 at rung model. On already-triaged **NOT CLEAN**, skip `verify_2`. **Cursor:** same routing as review (subscription-first for GPT/Claude; else `Task`) |
| 8 | — | If `verify_2` ran: orchestrator runs charter signals again; log pass/fail |
| 9 | advance | If Policy F streak is 2 **and** the verify overlay is met **and** ACCEPTs are applied (or REJECT-as-wrong recorded), advance to rung N+1 unless N is the final resolved rung. If this review had ACCEPT findings: APPLY, reset streak to 0, return to step 1 on the **same** model. If this review was CLEAN (or only REJECT) and streak < 2: `--record-rung-review-outcome clean`, return to step 1 on the **same** model. Else return to step 4 |

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
| **Secondary host agent** | `secondary host exec -m <model> -c model_reasoning_effort=<reasoning>` (native secondary host binary, not Kay shim) |

Model slug maps live in `scripts/review-fix-ladder.py` only — not in `silver-bullet.md`.

### OpenCode Go models (not Cursor `sb-*`)

OpenCode family rungs (DeepSeek, MiniMax, Qwen, and any other Go-listed model) **must** take model ids and display names from [OpenCode Go](http://opencode.ai/docs/go/) (live catalog also at `https://opencode.ai/zen/go/v1/models`). Re-fetch that page before naming a rung. **Do not** invent Cursor Task slugs such as `sb-opencode-max`, `sb-deepseek-*`, or treat “OpenCode Max” as a Cursor `subagent_type`.

Go lists **distinct model SKUs**, not High vs Max reasoning-effort tiers. “Max” / “Plus” / “Pro” / “Flash” in names such as Qwen3.8 Max, DeepSeek V4 Pro, and DeepSeek V4 Flash are product names, not Cursor-style High/Max effort. There is no `sb-opencode-max`.

**Quota windows (any model — not OpenCode-only):** Classify with `python3 scripts/review-fix-ladder.py --classify-quota-window --subscription-output '<blob>'`.

- **5-hour usage cap** (`5-hour usage limit reached`, including `Resets in 3hr 6min` / `reset after 59m 36s`) → persist a retry for the **same named model** after the window: `python3 scripts/review-fix-ladder.py --schedule-quota-retry --run-dir .planning/rfl-<id>/ --run-id <id> --rung-id <rung> --model <model> --subscription-output '<blob>'`. Do **not** Grok-substitute for this quota class. Jobs are idempotent per run+rung+model.
- **Weekly or monthly** exhaustion → do **not** auto-schedule unless the parsed reset is **≤ 5 hours**.
- **Unknown** quota class → same as weekly/monthly: schedule only if a reset ≤ 5 hours is parsed.
- **401 / insufficient balance** is billing, not a 5-hour window — do not schedule unless the message is clearly a 5-hour usage cap.

`--schedule-quota-retry` **arms a timer** (`at` on Linux; launchd user agent on macOS) that runs `--quota-retry-wake` at the parsed reset. JSON under the run dir stays the source of truth. Cursor/Claude **SessionStart** and **UserPromptSubmit** also run `hooks/rfl-quota-retry-due.sh`, which activates **due** jobs when a session starts or the user types again — do not wait for a human to remember the CLI.

When that scheduled worker fires (`--quota-retry-wake` / `--activate-quota-retry`): if the ladder run is **still active**, execute the deferred rung on the same named model (writes `QUOTA-RETRY-EXECUTE.md` and injects hook `additionalContext`). If the run is **already over** (completed / aborted / Policy D written / `LADDER-STATUS.json`), do **not** execute — write `QUOTA-RETRY-ASK.md`, print `[rfl] ASK: ...`, and inject the ask into hook context so the user sees it (not only stderr).

**Quota STOP (once):** Codex/Claude usage-limit → Cursor subagent fallback (`cursor_fallback` above). OpenCode billed quota / weekly limit **with no reset within 5 hours** (user must replenish keys) → report STOP once and wait for the user; do **not** spin short retries or invent Cursor `sb-*` stand-ins. **Unless** the failure is an unavailable/timeout/auth class (timeout, empty/"Let" after re-spawn, OpenCode `Endpoint is unavailable`, OmniRoute/OpenCode `401` `Missing API key`, hung invoke with no `review.md`): retry **once immediately**, then for OpenCode/Pi **substitute Grok 4.6 High** (`cursor-grok-4.6-high`) instead of skip; other hosts **skip the rung** and continue the ladder; after the whole ladder, retry skipped rungs once more. Do not skip because of CLEAN/NOT CLEAN. 5-hour caps use the schedule above instead of Grok substitute.


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

Issue ledger (already identified — do not re-report these rows):
{issue_ledger}

Residual-only means do not re-report ledger rows, not "file only one new ID."
File ALL valid residuals at the current SHA, ALL severities (HIGH / MED / LOW / nit).
Valid nits must be filed. CLEAN only if nothing valid remains.
The launcher MUST emit this brief via `--write-review-brief` (the only legal review brief). Hand-written one-ID briefs are non-compliant.

Tasks:
1. Audit scoped work against the charter goals.
2. Report every valid residual finding with ID, line references, and severity (HIGH|MED|LOW|NIT).
3. Do NOT classify ACCEPT/REJECT, PM-file issues, or apply fixes (launcher/parent does that).

FORBIDDEN behaviors:
- Do NOT triage findings (launcher/parent triages with Policy A after you return).
- Do NOT fix gaps — report only.
- Do NOT re-report ledger rows unless a residual defect remains in this freeze.
- Do NOT stop after one new ID; file the full pack of valid residuals.
- Do NOT edit plans, specs, tests, or docs — no "while I'm here" fixes.
- Do NOT read/edit/run commands outside locked scope.
- Do NOT claim PASS or recommend advancing — orchestrator verifies.
- Do NOT launch subagents or parallel work.
```

### Template A2 — Triage (`rung_N_triage`)

Launcher / parent of the ladder triages **in-session** (not the rung model). Do **not** spawn the same Composer/GLM/Kimi/Codex/Claude/OpenCode rung to classify findings. After review returns, write Policy C via `--write-policy-c`, `--assert-policy-c`, then paste encoder stdout (mandatory issue table → triage → triage table → fix → resolved table).

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
1. Apply every ACCEPT finding that is not wrong within scope (spec, and tests/docs if the finding is about those), including **Low, deferred, nitpicks, and minor** items that are still applicable. APPLY them as a **pack that pass** (order-dependent findings together), not one residual per round.
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
6. **Do not idle:** verify FAIL → Policy B leftovers then re-verify; CLEAN `verify_1` → grep then `verify_2`; already-triaged NOT CLEAN → `verify_1` only (`verify_2` is skipped); overlay-complete verifies + greps → next rung or same-model re-review. Same defect class failing verify more than twice → corpus sweep on the next Policy B. After 5 leftover cycles on this rung verify, escalate `file:line` leftovers instead of a sixth one-line patch. Launch/timeout: retry once immediately, then skip (`SKIPPED.md`) and start the next rung; after the whole ladder, retry skipped rungs once more.
