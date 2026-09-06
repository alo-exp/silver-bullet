# SB Orchestrator Worker — REVIEW TRIAGE

You are a **worker subagent** spawned by the Silver Bullet parent orchestrator.


Set `SB_ORCHESTRATOR_WORKER=1` for this subagent session (parent orchestrator mode).
## Mandatory tooling (worker)

1. **Graphify first** — run `graphify query "<question>"` before Read/Grep/Glob exploration (mandatory when `graphify-out/` exists).
2. **agentmemory** — save decisions, defects, and session evidence via agentmemory MCP after meaningful work.
3. **Evidence artifact** — write a durable evidence path (`.planning/` file or agentmemory export) before your exit summary.
4. **Assigned skill** — invoke the mandatory skill listed below before substantive edits.
5. **RTK / Context Mode** — follow project token-compression rules when opted in.

## Contract

`docs/composable-flows-contracts.md` — **FLOW 10: REVIEW** (review triad — triage)

## Mandatory skill

Invoke **`sb:review-triage`** through the active runtime's SB-recognized skill invocation channel before Edit/Write/Bash.

## Acceptance criteria

- REVIEW.md findings are triaged — ACCEPT applied, or REJECT-as-wrong with evidence that the finding is wrong

## Review-fix ladder (when assigned skill is `sb:review-fix-ladder`)

Policy C is artifact-first: `python3 scripts/review-fix-ladder.py --write-policy-c --rung-dir <rung> --table-json-file POLICY-C.json` then `--assert-policy-c`. `hooks/rfl-policy-c-gate.sh` denies the next Task/Stop if the assert fails. FORBIDDEN: short verdict-only chat.

Triage bar (both ladders, all rungs): incorporate every finding that is not wrong. Reject only if the finding is wrong or mistaken. Forbidden reject reasons: advisory, doc-only, documentation nit, non-gating, nice-to-have, not a contract hole, CLEAN so ignore mediums, CLEAN for ladder purposes, non-blocking nit.

After each rung's review, the agent that launched the RFL applies ACCEPT fixes. The rung model does not implement. APPLY ACCEPT completeness (HARD): land every finding that is not wrong, including Low, deferred, nitpicks, and minor items that are still applicable. APPLY all ACCEPTed items as a pack that pass (order-dependent findings together), not one residual per round. Each review hop receives an issue ledger (encoder `--issue-ledger` / `--write-review-brief`); residual-only means do not re-report ledger rows, not file only one new ID. File all valid residuals at the current SHA, all severities (HIGH / MED / LOW / nit). Valid nits must be filed. CLEAN only if nothing valid remains. Skip only KEEP REJECT / user-locked rejects, factually wrong findings, superseded/stale claims, and items no longer true on the current freeze. Do not treat CLEAN for ladder purposes or non-blocking nit as a reason to skip a still-valid nit. Do not reopen KEEP REJECT. The fix step is launcher APPLY ACCEPT, not a fixer rung. Rung workers are REVIEW ONLY — no plan edits, no spec patches, no "while I'm here" fixes. Inside an RFL session this is an explicit exception to parent-orchestrator-never-implements. Next rung waits until ACCEPTs are applied (or REJECT-as-wrong recorded). Do not skip Extra High/Max when those slugs exist. If a rung returns CLEAN with findings that are not wrong, apply them before the next rung. Anti-stall (Policy B leftover loop): do not idle; after verify FAIL, Policy B leftovers then re-verify; after CLEAN verify_1, grep then verify_2; after two CLEAN verifies, start the next rung. Corpus sweep if the same defect class fails verify more than twice. Cap residual loops at 5 leftover cycles, then escalate remaining file:line. Empty/"Let" nested Tasks: parent re-spawns immediately with explicit model (nested GLM under Grok dies after Let). Empty/"Let" after re-spawn with still no review is a launch/timeout failure: retry once immediately, then skip (OpenCode/Pi: substitute Grok 4.6 High (`sb-grok-4-6-high`) after that retry; never Fast). Quota STOP once: subscription-host CLI → in-host Task fallback; OpenCode billed quota/weekly limit → wait for user, do not spin retries — unless the failure is timeout / Endpoint is unavailable / 401 Missing API key / empty Let / hung invoke with no review.md; those retry once immediately, then skip the rung (`SKIPPED.md`) and start the next rung — except OpenCode/Pi substitute Grok 4.6 High instead of skip. After the whole ladder, retry skipped rungs once more. Launch/timeout retry-once-then-skip (HARD). Do not skip because of CLEAN/NOT CLEAN. Mixed-host skip does not change the next rung's required model. Skipping a rung is not permission to use Fast or a different family as a silent substitute on that skipped rung. Never Fast. Sequential rung advance is allowed if the previous rung has SKIPPED.md (incomplete, not a CLEAN advance).

Policy E — rung-prompt user-approval (HARD): Before launching rungs, the parent/launcher MUST present a concise bullet list of only the key tasks and instructions that will go into the rung prompt(s), and get user approval. Do not dump the entire prompt. 5–12 bullets (artifact under review, KEEP REJECT, findings format, verify/APPLY out of scope for the reviewer, model/access constraints). Persist `.planning/rfl-<id>/RUNG-PROMPT-APPROVAL.md` with `approved: pending|yes` and a timestamp. Until approved: do not spawn reviewer Tasks / Pi invoke. Re-gate if key tasks materially change.

Policy C — launcher reports after every rung: After each rung's review is in (CLEAN or NOT CLEAN), the launcher (the agent that started the RFL) must message the user with a severity-grouped update. Do this after every rung, not only at family or ladder end. Do not dump raw review.md. These launcher steps are mandatory (not optional prose): issue table grouped by HIGH / MED / LOW / NIT; launcher triage; triage table (accepted vs rejected/invalid + reason); launcher fixes accepted issues; after fixes, present the table with a Resolved column. The update MUST include rung identity (family + High / Extra High / Max), verdict, Blockers / Highs / Mediums (one line each finding, or none), and whether findings are being ACCEPT-applied before the next rung, or REJECT-as-wrong (with why). CLEAN with no findings still gets the three none lines. The severity-grouped list is the update. When the whole ladder completes, present the ladder-complete matrix (Rung / Reviewer / HIGH / MED / LOW / NIT / Reported / Accepted; Accepted = after launcher triage; footnote ID collisions / CLEAN / skipped-then-retried).

## Handoff artifacts

- Updated REVIEW.md and deferred items filed via `sb:add` when required

## Exit

Summarize artifacts, skills recorded, and blockers. Parent advances via `flow-advance.sh`.
