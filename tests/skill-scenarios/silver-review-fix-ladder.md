# Review Fix Ladder Skill Scenario

## Skill: silver-review-fix-ladder
## Context: Progressive review/fix against context-derived goals

### Scenario: Explicit Path Scope

**Trigger:** "Run sb:review-fix-ladder on `scripts/review-fix-ladder.py`"

**Workflow:**
1. Scope locks to the named file without prompting for repo-wide review
2. Derive review charter from `.planning/`, user request, and project docs
3. Resolve ladder via `python3 scripts/review-fix-ladder.py --json`
4. Execute sequential rungs with **review → launcher report → launcher triage → apply ACCEPT → two-pass verify** per rung:
   - review subagent (rung model, REVIEW ONLY) → launcher posts Policy C user update (rung identity, verdict, HIGH/MED/LOW/NIT issue table, triage table, resolved table after fixes, Blockers / Highs / Mediums or none, ACCEPT-apply vs REJECT-as-wrong) → launcher/parent triages (Policy A: wrong vs not wrong) → launcher applies ACCEPT fixes (Edit/Write) → verify-only pass 1 → orchestrator charter grep → verify-only pass 2 → orchestrator charter grep → advance
   - **FORBIDDEN:** parallel rung launches, combined verify passes, reviewer self-triage, asking the same rung to patch after NOT CLEAN, rejecting as “advisory”/“doc-only”, advancing on subagent self-reported PASS alone, advancing before ACCEPTs are applied, skipping the per-rung Policy C user update, dumping raw review.md instead of the severity-grouped list
5. Close out with per-rung verify_1/verify_2 evidence table, ladder-complete matrix (Rung / Reviewer / HIGH / MED / LOW / NIT / Reported / Accepted), charter coverage matrix, and residual risks

### Scenario: General Invocation Asks Scope

**Trigger:** "Run a review fix ladder on this change"

**Workflow:**
1. Orchestrator asks: whole repo, or specific artifact(s)/directory/directories?
2. Do not derive charter or start ladder until user answers
3. If user supplies paths, scope locks to those paths
4. If user confirms whole repo, scope becomes repo-wide with charter non-goals enforced

### Scenario: Repo-Wide Only After Confirmation

**Trigger:** General invocation → user replies "whole repo"

**Workflow:**
1. Charter emphasizes high-signal surfaces first (changed files, planning artifacts, tests)
2. Ladder escalates per host resolver output
3. Smallest safe fixes only; no scope expansion beyond charter non-goals
4. Report coverage matrix mapping charter goals to verification evidence

### Scenario: Two-Pass Gate Enforcement

**Trigger:** Any ladder execution

**Workflow:**
1. One review/verify `Task` per turn — never batch review and verify in one subagent call; launcher reports, triages, and applies ACCEPT in-session
2. Review → launcher Policy C user update → launcher triage (Policy A) → apply ACCEPT → verify sequence per rung
3. Launcher/parent posts Blockers / Highs / Mediums (or none) after every rung, then triages and applies ACCEPT; review and verify use rung model. The rung model does not implement
4. Verify subagents use `readonly: true` (Cursor) or explicit verify-only directive
5. Orchestrator runs charter verification signals between verify passes
6. Stay on rung until orchestrator confirms two consecutive clean verify passes
7. State machine: `rung_N_review` → `rung_N_triage` → `rung_N_file_valid_issues` → `rung_N_fix_parallel` → `rung_N_verify_1` → grep → `rung_N_verify_2` → grep → advance

### Scenario: Subscription-First GPT and Claude Launch

**Trigger:** Cursor RFL is about to launch a GPT or Claude/Opus review or verify rung (including re-verify and Max)

**Workflow:**
1. Run `python3 scripts/review-fix-ladder.py --decide-launch --model {model} --reasoning {reasoning}` before every launch — not once per family
2. GPT rungs invoke `/sb:agent-codex` (`scripts/agent-codex/invoke.sh`) first; Claude/Opus rungs invoke `/sb:agent-claude` (`scripts/agent-claude/invoke.sh`) first
3. Quota exhaustion (`429`, `rate limit`, `token plan`, `out of quota`, `quota retries exhausted`, `usage cap`/`usage limit`, `billed-quota`) → log host+signal, `--mark-quota-fallback`, then Cursor `Task`
4. Non-quota failure (missing CLI, HASH MISMATCH, network blip, brief bug, NOT CLEAN) → **no** Cursor fallback
5. Grok and Composer default to `/sb:agent-cursor`. Gemini defaults to Gemini CLI (if the user did not name an agent), else Pi, else OpenCode, else Cursor. Other models default to Pi or OpenCode, or the agent the user named. User override wins. Do not smash host `--mode`. Do not remap GPT/Claude onto Grok High. Grok, Composer, GLM, Gemini, Kimi, OpenCode rungs skip the GPT/Claude subscription-first quota gate

### Scenario: Review-Triage-Fix Separation

**Trigger:** Ladder rung after review subagent returns

**Workflow:**
1. Review subagent reports raw findings only — no classification, plan edits, spec patches, or “while I’m here” fixes
2. After the review is in (CLEAN or NOT CLEAN), the launcher (the agent that started the RFL) messages the user with a severity-grouped Policy C update: rung identity (family + High / Extra High / Max), verdict, HIGH/MED/LOW/NIT issue table, triage table (accepted vs rejected + reason), Blockers / Highs / Mediums (one line each finding, or none), and whether findings are being ACCEPT-applied before the next rung or REJECT-as-wrong (with why). After ACCEPT fixes, re-present the table with a Resolved column. Do this after every rung, not only at family or ladder end. Do not dump raw review.md. CLEAN with no findings still gets the three none lines
3. Launcher/parent triages in-session: incorporate every finding that is not wrong; REJECT only if wrong or mistaken
4. Forbidden reject reasons: advisory, doc-only, documentation nit, non-gating, nice-to-have, not a contract hole, CLEAN so ignore mediums, CLEAN for ladder purposes, non-blocking nit
5. Launcher/parent applies ACCEPT fixes with Edit/Write (RFL exception to parent-orchestrator-never-implements). APPLY ACCEPT completeness (HARD): land every finding that is not wrong, including Low, deferred, nitpicks, and minor items that are still applicable. APPLY all ACCEPTed items as a pack that pass (order-dependent findings together), not one residual per round. Skip only KEEP REJECT / user-locked rejects, factually wrong findings, superseded/stale claims, and items no longer true on the current freeze. Do not treat CLEAN for ladder purposes or non-blocking nit as a reason to skip a still-valid nit. Do not reopen KEEP REJECT. The fix step is launcher APPLY ACCEPT, not a fixer rung. Do not ask the same rung to patch after NOT CLEAN
6. If the rung returns CLEAN with findings that are not wrong, the launcher still applies them before the next rung
7. Next rung waits until ACCEPTs are applied (or REJECT-as-wrong recorded). Do not skip Extra High/Max when those slugs exist

### Scenario: Hop review / pack-ledger (Policy G)

**Trigger:** Any review hop after findings have already been identified (including Policy F re-reviews on the same model)

**Workflow:**
1. Launcher emits the only legal review brief via `python3 scripts/review-fix-ladder.py --write-review-brief --run-dir .planning/rfl-<id>/` (and `--issue-ledger`). Hand-written one-ID briefs are non-compliant. The hop receives ID, severity, ACCEPT/REJECT, resolved y/n, SHA, one-line
2. Residual-only means do not re-report ledger rows, not "file only one new ID." The reviewer files all valid residuals at the current SHA, all severities (HIGH / MED / LOW / nit). Valid nits must be filed. CLEAN only if nothing valid remains
3. Triage still REJECTS invalid items (already encoded, false cite, KEEP REJECT collision). All ACCEPTed items including nits are APPLY'd as a pack that pass
4. Orthogonal to Policy F (ladder completion). Canonical verify overlay: verify_2 required on CLEAN; verify_2 is skipped on already-triaged NOT CLEAN; verify_1 still required on NOT CLEAN and APPLY

### Scenario: Per-Rung Launcher Reporting (Policy C)

**Trigger:** Review subagent returns CLEAN or NOT CLEAN for any rung

**Workflow:**
1. The launcher (the agent that started the RFL) must message the user with a severity-grouped update after each rung's review is in
2. Include rung identity (family + High / Extra High / Max), verdict, HIGH/MED/LOW/NIT issue table, triage table (accepted vs rejected + reason), Blockers / Highs / Mediums (one line each finding, or none), and ACCEPT-apply vs REJECT-as-wrong (with why). After fixes, present the table with a Resolved column
3. Do this after every rung, not only at family or ladder end. Do not dump raw review.md
4. CLEAN with no findings still gets the three none lines

### Scenario: Rung-prompt user-approval (Policy E)

**Trigger:** Before the first rung of a ladder, or when the rung brief's key tasks materially change

**Workflow:**
1. The parent/launcher MUST present a concise bullet list of only the key tasks and instructions that will go into the rung prompt(s), and get user approval. Do not dump the entire prompt
2. 5–12 bullets: artifact under review, KEEP REJECT, findings format, verify/APPLY out of scope for the reviewer, model/access constraints that matter to the review (e.g. plan vs template). No full Template A paste, no SHA dump of the whole freeze, no 200-line brief
3. Persist `.planning/rfl-<id>/RUNG-PROMPT-APPROVAL.md` with the bullets plus `approved: pending|yes` and a timestamp. Write pending before asking; set yes only after the user approves
4. Until approved: do not spawn reviewer Tasks / Pi invoke
5. Re-run the gate if key tasks materially change (e.g. user retargets "review the plan" → "review SPEC template + kinds")

### Scenario: Anti-Stall leftover loop (Policy B)

**Trigger:** Verify FAIL leftovers, empty/Let Tasks, or OpenCode/Codex/Claude quota during an RFL

**Workflow:**
1. Do not idle. After verify FAIL, Policy B leftovers in the same follow-up turn, then re-verify. After CLEAN verify_1, immediately grep then verify_2. After two CLEAN verifies + greps, immediately start the next rung
2. Corpus sweep, not one-line cycles: if the same defect class fails verify more than twice, the next Policy B scans all in-scope plan/spec artifacts for that class and patches every live hit in one pass
3. Empty/Let nested Tasks: parent re-spawns immediately with explicit model so the child does not inherit the wrong wrapper. Nested GLM under Grok dies after Let; parent re-spawns with explicit GLM model. Do not wait for the user. Never Fast
4. Quota windows (any model): 5-hour usage cap → `--schedule-quota-retry` same named model after the window (arms `at`/launchd plus SessionStart/`rfl-quota-retry-due.sh` `--quota-retry-wake`); weekly/monthly/unknown schedule only if parsed reset ≤ 5 hours; 401 insufficient balance is not a 5-hour schedule. When the scheduled worker fires, if the ladder is already over, ASK the user (QUOTA-RETRY-ASK.md + hook context) and do not execute; if still active, retry the same model. Codex/Claude usage-limit still Cursor-fallback. OpenCode billed quota/weekly with reset > 5h → wait for the user; do not spin short retries. Timeout / Endpoint is unavailable / empty Let / hung invoke with no review.md: retry once immediately, then skip the rung (SKIPPED.md) and start the next rung. After the whole ladder, retry skipped rungs once more. Do not skip because of CLEAN/NOT CLEAN
5. Cap residual loops: after 5 leftover cycles on the same rung verify, escalate remaining file:line instead of a sixth one-line patch

### Scenario: Skip after launch/timeout retry-once-then-skip

**Trigger:** Same ladder rung cannot be launched or times out (timeout, empty/Let after re-spawn, OpenCode Endpoint is unavailable, hung invoke with no review.md)

**Workflow:**
1. Retry once immediately. If that fails and the host is OpenCode or Pi (including OmniRoute 401 Missing API key), substitute Cursor Grok 4.6 High (`cursor-grok-4.6-high`); never Fast; never Extra High as unspecified default. Other hosts: skip that rung and immediately start the next rung. After the entire ladder finishes, retry skipped rungs once more
2. Record SKIP/retry in the rung dir (SKIPPED.md: reason, attempt count, timestamps, next rung, post_ladder_retry_pending)
3. Do not skip because of a CLEAN/NOT CLEAN review — only when the rung failed to produce a verdict
4. Mixed-host: skip does not change the next rung's required model. Never Fast. Skipping is not permission to use Fast or a different family as a silent substitute on that skipped rung
5. Quota STOP once still applies for billed quota / weekly limit with no reset within 5 hours — report STOP and wait unless the failure is an unavailable/timeout class that already retried once; 5-hour caps schedule a same-model retry instead
6. Sequential rung advance is allowed if the previous rung has SKIPPED.md (incomplete, not a CLEAN advance). Empty/"Let" after re-spawn counts toward the launch/timeout retry-once-then-skip policy

### Scenario: Compliance Gate — Stop on Violation

**Trigger:** Orchestrator about to advance from rung N to rung N+1, or after any verify pass

**Workflow:**
1. Orchestrator self-checks: sequential states, separate verify invocations, orchestrator grep ran, scope held, no parallel rungs
2. If **any** check fails → **STOP immediately** — do not start next rung
3. Report violation, fix process/skill/prompt, re-run failed phase on **same** rung
4. Resume only after compliance gate passes on re-run
5. **No full-ladder obligation** — stop when charter satisfied at current rung or on first compliance failure

### Scenario: Early Stop — Charter Satisfied

**Trigger:** All charter goals met with orchestrator evidence at rung N

**Workflow:**
1. Run compliance gate for rung N
2. Close out with compliance log — do not escalate to rung N+1 unless findings remain
3. Report why stopped: charter satisfied at rung N

### Scenario: Smoke Demonstration (Rung 1 Only)

**Trigger:** Compliance validation or user requests process proof without full ladder

**Workflow:**
1. Lock scope, derive charter, resolve ladder
2. Execute rung 1 only: `review` → `triage` → `file_valid_issues` → `fix_parallel` → `verify_1` → orchestrator grep → `verify_2` → orchestrator grep
3. Run compliance gate before any rung 2 work
4. **STOP** — report compliance log; do not continue to higher rungs unless user explicitly requests and compliance passes
