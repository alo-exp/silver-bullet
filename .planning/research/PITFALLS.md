# Pitfalls Research — Issue Capture & Retrospective Scan

**Milestone:** v0.25.0 — Issue Capture & Retrospective Scan
**Domain:** Adding issue-tracking integration, retrospective session scanning, and auto-capture enforcement to existing AI orchestrator (Silver Bullet)
**Researched:** 2026-04-24
**Confidence:** HIGH (GitHub API limits from official docs; enforcement failure modes from AGENTIF benchmark and SB architecture analysis; integration patterns from prior SB pitfalls file and milestone history)

---

## Pitfall 1: Auto-Capture Becomes a Noise Engine

**Risk:**
The coding agent is instructed to call `silver-add` on every deferred or skipped item it encounters during execution. In practice it over-triggers: every TODO comment, every "we could improve this later" throwaway in its own reasoning, every exploratory file it touched but did not commit — all become filed issues. Within a single milestone the tracker fills with 30-50 low-signal items. The signal-to-noise ratio collapses and users stop reading the captured list. The post-release summary that was meant to surface real tech debt instead presents a wall of junk.

**Why it happens in SB specifically:**
SB's enforcement model is invocation-based, not outcome-based (per `silver-bullet.md` §1: "record-skill.sh records that a skill was called; it cannot verify the skill produced a meaningful result"). An instruction to "call silver-add on all deferred items" will be followed literally: anything the agent decides is deferred will trigger a call, with no quality filter on what constitutes a filing-worthy item. SB has no prior art for output-quality gating on agent-initiated skill calls — all existing enforcement gates apply to human-triggered workflows.

**Prevention:**
- Define a strict classification rubric in the auto-capture instruction that the agent MUST evaluate before calling `silver-add`. Minimum bar: item has a distinct user-visible impact OR blocks future work. Transient exploration, comments without action, and sub-1-hour fixes do NOT qualify.
- Add a required `signal_level` field to `silver-add` (low/medium/high). Items filed as `low` during auto-capture must be aggregated and shown as a collapsed summary, not individual entries.
- Cap auto-capture to a maximum of 5 items per session phase. If the agent would exceed 5, it must bundle remaining items into a single "batch" entry rather than filing each individually.
- Test the auto-capture instruction in isolation with a session that has known noise before wiring it into the main enforcement path.

**Phase to address:** Auto-capture enforcement phase (before wiring into any workflow). Classification rubric must be written before the instruction is added to `silver-bullet.md`.

---

## Pitfall 2: silver-remove Silently Becomes silver-close on GitHub

**Risk:**
Users invoke `/silver-remove <id>` expecting the issue to disappear. GitHub's REST API does not support issue deletion. The `gh issue delete` CLI uses the GraphQL `deleteIssue` mutation — which requires the `delete_repo` scope, a highly privileged permission that most users will not have granted and that admins will refuse to add to a personal access token scoped for issue management. The skill either silently falls back to closing the issue (user doesn't know), errors with a cryptic permission message, or worse — succeeds for local-markdown items but fails for GitHub items with no clear error path.

**Why it happens in SB specifically:**
SB already has precedent for this: the `issue_tracker` field in `.silver-bullet.json` distinguishes GitHub vs. local-markdown backends (added in FEAT-01, v0.24.0). But `silver-remove` must implement a two-code-path removal, and the GitHub path has no clean "delete" primitive — it has a close with label. The skill design must acknowledge this from the start or it will be discovered at first user invocation.

**Prevention:**
- Define `silver-remove` behavior explicitly in the skill: for GitHub backend, "remove" means close with reason `not planned` plus label `sb-removed`. Document this in the skill's user-facing output so the user sees exactly what happened.
- Attempt `gh issue delete` first. If it fails with permission error (exit code non-zero with "scope" in stderr), fall back to close-with-label automatically, print: "GitHub does not allow deletion without admin scope — closed as not-planned instead."
- For local-markdown backend, deletion is a file-line removal — implement this fully rather than treating both backends identically.
- Never silently do something different from what the user requested. Always print what action was taken and what the ID resolves to post-remove.

**Phase to address:** silver-remove implementation phase. The GitHub permission model must be resolved in the skill design document before a single line of skill instructions is written.

---

## Pitfall 3: silver-scan False-Positives on Already-Resolved Items

**Risk:**
`silver-scan` reads all past session logs, identifies items mentioned as deferred/skipped/TODO, and calls `silver-add` on the relevant ones. But session logs record what was deferred at the time — not what was resolved later. A tech debt item mentioned in session 3 that was resolved in session 7 will appear as "unresolved" to a scanner that reads logs sequentially without cross-referencing the resolution record. The scan output includes items that have already shipped, creating a false backlog that erodes user trust in the scan's utility.

**Why it happens in SB specifically:**
SB session logs (in `docs/sessions/`) record deferred items in a `Needs human review` section and autonomous decisions in `Autonomous decisions`. There is no `Resolved in` field. The scan has no structured signal to determine whether an item found in an old log was addressed by a later session. The scanner must infer resolution from: git history (did a commit reference the item?), subsequent session logs (was it mentioned again with "fixed"), or the current state of the tracker (is an open issue still open?). Each inference is imperfect and prone to false negatives.

**Prevention:**
- Before `silver-scan` calls `silver-add` on any found item, it MUST run a resolution check: (1) search git log for the item's keyword, (2) check if an open GitHub issue or local-markdown entry with matching description already exists, (3) check if any later session log's `Files changed` or `Outcome` section mentions the item as resolved.
- Items that pass none of the three resolution checks are candidates for `silver-add`. Items that pass any one check are logged as "likely resolved — skipped" in the scan output.
- `silver-scan` must produce a human-readable candidate list BEFORE filing anything. The user approves the list (or a subset) before `silver-add` is called. Silver-scan is a reconnaissance tool, not an autonomous filer.
- Cap the scan to a single phase-window at a time (not all sessions from the beginning in one run) to keep the candidate list reviewable.

**Phase to address:** silver-scan design phase, before any session-reading logic is implemented. The resolution-check protocol must be defined as a precondition of the scan, not retrofitted after false positives are observed.

---

## Pitfall 4: GitHub API Secondary Rate Limit Hit During silver-scan Batch Filing

**Risk:**
`silver-scan` identifies 15-20 items across all historical sessions and calls `silver-add` for each. Each `silver-add` for a GitHub backend requires two API calls: `gh issue create` (REST, content-generating request) + `gh project item-add` (GraphQL). GitHub's secondary rate limit for content-generating requests is 80 per minute and 500 per hour. A batch of 20 items fired in rapid succession will hit the 80/minute content-creation secondary limit, causing 403/429 responses. If `silver-add` has no retry or throttle logic, the scan fails mid-batch, leaving partial results — some items filed, some not — with no record of which succeeded.

**Why it happens in SB specifically:**
SB's existing GitHub integrations (CI status check hook, pr-traceability hook) are single-call operations — they never batch. No existing SB skill has needed rate-limit retry logic. `silver-scan` introduces the first bulk-write scenario in SB's GitHub integration history. The `gh` CLI does not implement rate-limit handling by default; it surfaces the raw HTTP error.

**Prevention:**
- `silver-add` must be implemented with a minimum 2-second sleep between each call when invoked from `silver-scan` batch mode. For batches of 10+ items, use 4-second intervals to stay well below the 80/min content-creation limit.
- `silver-scan` must write a local manifest of each item's filing status (filed/pending/failed) before starting the batch. If interrupted by a rate limit, the manifest allows resuming from where it left off rather than re-scanning.
- Treat any 403 or 429 from the GitHub CLI as a retry signal, not an error. Back off with `Retry-After` header value (or 60 seconds if absent), retry up to 3 times, then mark the item as `pending-retry` in the manifest.
- Include the manifest file path in the scan output so the user can monitor progress on large batches.

**Phase to address:** silver-add implementation phase (before silver-scan is built on top of it). Rate-limit resilience must be in silver-add itself, not in silver-scan's orchestration layer.

---

## Pitfall 5: Local Markdown ID Collisions When Issue Tracker is "gsd"

**Risk:**
When `issue_tracker` is `"gsd"` (local markdown, no GitHub), `silver-add` assigns IDs to items stored in `docs/issues/` and `docs/backlog/`. If IDs are generated by counting existing files or by timestamp, two rapid-fire `silver-add` calls in the same second (which auto-capture can produce) generate the same ID. One file overwrites the other silently. Or, if issues and backlog items share an ID namespace, `ISSUE-007` and `BACKLOG-007` can both exist — `silver-remove 7` is ambiguous: remove from which namespace?

**Why it happens in SB specifically:**
SB has no prior local-markdown ID assignment logic. The risk is in the design: if ID is `count(ls docs/issues/) + 1`, two concurrent `silver-add` calls both see N files, both assign ID N+1, last write wins. SB's auto-capture enforcement fires during a single session, but the coding agent can invoke skills in parallel (wave-based execution is a GSD feature SB orchestrates). This makes collision a real risk, not a theoretical one.

**Prevention:**
- Assign IDs using a monotonically-incrementing counter stored in a dedicated file (`docs/issues/.next-id` and `docs/backlog/.next-id`), incremented with an atomic read-then-write. In shell: `flock` on the counter file before reading, increment, write back, release.
- Issue IDs and backlog IDs must share a single namespace (SB-001, SB-002...) rather than two separate namespaces. `silver-remove SB-007` is then unambiguous — look it up in the index.
- On init, `silver-add` must check that the target file does not exist before writing. If it does, increment the counter again and retry rather than overwriting.
- `silver-scan` batch mode must call `silver-add` sequentially (never in parallel) to avoid concurrent counter reads.

**Phase to address:** silver-add implementation phase. ID assignment scheme must be decided before the first file is written — changing it post-hoc requires migrating all existing IDs.

---

## Pitfall 6: Auto-Capture Instructions Not Honored Across All Skill Contexts

**Risk:**
The auto-capture enforcement is added to `silver-bullet.md` as a global instruction. It works in sessions that flow through the standard `full-dev-cycle` workflow because SB's hooks ensure `silver-bullet.md` is read at session startup. But sessions initiated via `/silver fast` (the fast-path), sessions using Forge delegation, and sub-agent spawned by `Agent teams dispatched` operate in their own context windows with no guarantee that `silver-bullet.md` is re-read in full. The auto-capture instruction is silently absent in those contexts.

**Why it happens in SB specifically:**
SB's `silver-bullet.md §0` requires reading the file at session startup, but sub-agents spawned via the `Agent` tool receive only the instructions passed in their invocation prompt. They do not automatically inherit the parent's `silver-bullet.md` context. The Forge delegation path (when `.forge-delegation-active` exists) routes work through a different context entirely. AGENTIF benchmarks show that even the best LLMs follow fewer than 30% of multi-constraint instructions perfectly in agentic scenarios — an instruction buried in §N of a long orchestration file has lower compliance than one surfaced in the immediate task prompt.

**Prevention:**
- Auto-capture instructions must be embedded directly in the skill files that generate deferred items (`silver-feature`, `silver-bugfix`, `silver-devops`, etc.) as an explicit step, not only in `silver-bullet.md`. A skill that produces deferred items must contain: "If this step produces a deferred item, call `silver-add` before proceeding to the next step."
- For Forge-delegated sessions, the Forge SKILL.md task prompt must include the auto-capture instruction in the `INJECTED SKILLS` field.
- The stop-check hook (`stop-check.sh`) is the enforcement backstop: if `silver-bullet.json` has `auto_capture: true` and the session produced deferred items (detectable from session log `Needs human review` entries) but no `silver-add` was recorded in the state file, stop-check must soft-warn (not hard-block — filing can happen post-session).
- Test auto-capture compliance in: (1) standard session, (2) `/silver fast` session, (3) a session with Agent-team dispatch.

**Phase to address:** Auto-capture enforcement phase. Instruction placement must be designed before any enforcement is tested — retrofitting multi-context enforcement after the fact requires modifying every skill file individually.

---

## Pitfall 7: silver-scan Scope Creep Produces Unmanageable Output

**Risk:**
`silver-scan` is instructed to scan ALL past sessions from the beginning of the project. Silver Bullet has sessions dating back through v0.9.0 — potentially 40+ session logs. Scanning all of them in a single run produces a candidate list of 80-120 items spanning years of context. The user cannot meaningfully review this list. If auto-filing is enabled, it becomes a noise engine (Pitfall 1 at scale). If it requires manual review, the review itself takes longer than just re-doing the work.

**Why it happens in SB specifically:**
SB projects are long-lived (SB itself is on its 20th milestone). Session logs accumulate without a pruning mechanism. The `silver-scan` specification says "ALL project sessions from beginning" — this instruction is correct for a new feature but catastrophic as a default for mature projects with long histories.

**Prevention:**
- `silver-scan` must default to scanning only the last N sessions (default: 10, configurable via `--sessions N` flag or `.silver-bullet.json` scan config). Full-history scan requires explicit `--all-history` flag with a warning.
- Provide a `--since <version>` or `--since <date>` filter so users can scope the scan to a specific milestone or time window.
- Cap the total candidate list at 20 items per scan run. If the scan finds more candidates than the cap, show the top 20 sorted by recency and signal-level, and tell the user how many were truncated and how to retrieve them.
- Write each scan run's full candidate list to a file (`docs/silver-scan/<date>-candidates.md`) so it persists for async review rather than requiring the user to act immediately during the session.

**Phase to address:** silver-scan design phase. Scope controls must be in the skill specification before implementation — adding a cap after a user runs a full-history scan on a large project and gets overwhelmed is too late.

---

## Pitfall 8: Post-Release Summary Breaks Enforcement Integrity on the Stop Hook

**Risk:**
The post-release summary is meant to fire automatically after `silver-create-release` completes. But `silver-create-release` is gated by `stop-check.sh` (via `required_deploy`). If the post-release summary calls `silver-add` (to ensure items are filed before summary) and those calls write to GitHub or local markdown after the completion gate fires, the hook's assumption that "all work is done when stop fires" is violated. Alternatively, if the summary is shown in the stop hook's output, it competes with the stop hook's block/allow decision, creating confusing UX.

**Why it happens in SB specifically:**
SB's stop-check hook has a strict invocation model: it fires on the `Stop` event and either blocks or allows. It cannot initiate new work (it is a read-only enforcer). Adding a post-release summary that shows items filed during the milestone requires reading state that was accumulated over the entire milestone — this is a reporting concern, not an enforcement concern. Wiring it into the stop hook would require the hook to read the session state file's filing history, which is new behavior not currently supported.

**Prevention:**
- Post-release summary is NOT a stop-hook concern. Implement it as an explicit step in `silver-create-release/SKILL.md` — the final step before the skill concludes. The skill reads the current session's state file for all `silver-add` invocations recorded during the milestone and formats them as a summary.
- The state file (`~/.claude/.silver-bullet/<project>/state`) must record each `silver-add` call with its ID and title, not just that the skill was called. This requires a small change to `record-skill.sh` (or a new `record-filing.sh` helper) to append filing metadata.
- The summary step in `silver-create-release` must be non-blocking: if no items were filed, print "No items filed this milestone." and continue. Never let an empty summary prevent the release from completing.

**Phase to address:** Post-release summary phase AND the silver-add implementation phase (state recording must be in place before the summary can read it). These two features are tightly coupled.

---

## Summary

**Top 3 most critical pitfalls to design against from the start:**

**1. Auto-Capture Noise Engine (Pitfall 1)**
If the classification rubric is not written before the auto-capture instruction is added to `silver-bullet.md`, the first real-world session will file 20+ junk items and users will disable the feature. The rubric is a prerequisite, not a refinement.

**2. silver-scan False-Positives on Resolved Items (Pitfall 3)**
Silver-scan's value proposition is that it surfaces real unresolved debt. If it surfaces already-shipped items, users will never trust its output again. The resolution-check protocol (git log cross-reference + open-issue check + later-session search) must be built into the scan before it touches any real session history. The human-approval gate before filing is mandatory, not optional.

**3. Auto-Capture Not Honored Across All Skill Contexts (Pitfall 6)**
The auto-capture instruction placed only in `silver-bullet.md` will be silently absent in `/silver fast` sessions, Forge-delegated sessions, and sub-agent spawned contexts. Unless the instruction is embedded directly in each producing skill file AND the stop-hook provides a soft-warn backstop, compliance will be inconsistent and the feature will appear to "work sometimes."

---

*Sources:*
- GitHub Docs: [Rate limits for the REST API](https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api) — 80 content-creating requests/min, 500/hour secondary limit
- GitHub Community: [GitHub API — Issue Deletion](https://github.com/orgs/community/discussions/46529) — REST API does not support deletion; GraphQL deleteIssue requires delete_repo scope
- GitHub Community: [Hitting secondary rate limit on issue creation](https://github.com/orgs/community/discussions/50326) — confirmed failure mode for batch issue creation
- AGENTIF benchmark (arxiv 2505.16944): LLMs follow fewer than 30% of multi-constraint agentic instructions perfectly — basis for Pitfall 6 enforcement placement strategy
- A Benchmark for Evaluating Outcome-Driven Constraint Violations (arxiv 2512.20798) — violation rates 11.5-66.7% across 12 state-of-the-art LLMs
- SB PROJECT.md: `issue_tracker` field, enforcement invocation-based model (§1), `silver-bullet.md` context read requirement
- SB REQUIREMENTS.md v0.24.0 FEAT-01: issue_tracker field established as the backend-switching primitive
- SB silver-bullet.md §1: "record-skill.sh records that a skill was called; it cannot verify the skill produced a meaningful result" — enforcement model analysis
- SB `.planning/research/PITFALLS.md` (prior milestone): enforcement gap analysis pattern, integration gotcha model
