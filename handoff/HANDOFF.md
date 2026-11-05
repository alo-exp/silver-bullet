# HANDOFF: Silver Bullet exhaustive adversarial review and fixes

You are taking over an in-progress, multi-agent review-and-fix project for `alo-exp/silver-bullet`.
Read this file first, then `handoff/tracking/DECISIONS.md` (every decision the user made) and `handoff/tracking/AGENTS.tsv`
(the agent log). The tracking copies are in this folder tree (`handoff/tracking/`). They were copied from the previous session's scratchpad.

## 0. Prompt to paste into the new session

> Take over the Silver Bullet review-and-fix project. Check out branch `claude/optimistic-ramanujan-tccfud` of
> `alo-exp/silver-bullet` (PR #291). Fetch branch `handoff/review-fixes-2026-11-05` and read `handoff/HANDOFF.md`
> in full, then `handoff/tracking/DECISIONS.md`. Re-create the package worktrees from the `fix/*` branches
> listed there (they are pushed to origin). Continue the work from section 5, following the rules in section 2 exactly.
> Do not stop until the goal in section 1 is met.

## 1. Goal

Original request: run an exhaustive adversarial review of Silver Bullet and address ALL issues, through the normal
commit/review workflow. Do not stop until done. Develop and push ONLY to `claude/optimistic-ramanujan-tccfud`
(PR alo-exp/silver-bullet#291, already open; do not open a second PR). The review phase is complete: 17 areas, 491
findings (24 critical, 96 high, 209 medium, 162 low), grouped into fix packages (`handoff/tracking/packages.json`).

## 2. Standing rules (from the user; they override defaults)

- Use the /forge:delegate skill for tasks on session start.
- Do NOT bypass any Silver Bullet process enforcement (hooks). Do NOT touch the trivial marker or edit any
  quality-gate state file. SB OVERRIDE is only for a genuinely unsatisfiable directive.
- Do not stop until the goal is achieved.
- Any answer or decision from the user: use only the questions UI (AskUserQuestion).
- Do not use the Workflow tool. Never put secrets in the repo or logs.
- Kill processes only by exact PID or PGID. Never `pkill -f`. Do not touch `/sess-1.json` or `/sb-*.json`.
- `.planning/` is not editable by agents (the user approved it only for the private-data scrub).
- Graphify first: run `graphify query` before grepping; run `graphify update .` after code changes.
- No silent branch switches. No Fast mode. TDD with red-then-green evidence. The orchestrator delegates the work.
- Model policy (latest): reviews = Opus 5.5 Medium (`model: opus, effort: medium`); fixes = Sonnet 5.5 Medium;
  critical design decisions = an Opus 5.5 subagent at High or Medium depending on complexity. Never XHigh, never Max,
  no Opus for fixes.
- Push only to the PR branch. The previous session pushed the unmerged `fix/*` package branches and the handoff
  branch to origin under their own names, with the user's approval, as a backup only. Do not open PRs for them.
- The user pre-authorised nothing else outward-facing. Ask before anything irreversible.

## 3. Process per package

Sonnet author in a worktree -> Opus review (writes `review-fix-<pkg>-rN.json`) -> repair -> re-review ->
`git merge --no-ff` into the PR branch with trailers
(`Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>` and `Claude-Session: ...`) -> batch push -> CI.
Briefs for the agents: `handoff/tracking/FIX-BRIEF.md` (author), `handoff/tracking/FIX-REVIEW-BRIEF.md` (reviewer).
CI gates: validate, test (claude), test (codex), coverage with `--fail-under 100` (about 2 h; one run, never
combined runs), gitleaks. A push cancels the in-flight run. The stop hook forces a push of unpushed commits.

## 4. User decisions (full list in `handoff/tracking/DECISIONS.md`; key ones)

- Cursor is NOT supported as a host any more: remove it fully; one strip-only legacy cleanup script plus a CHANGELOG
  note for existing users. The multi-AI skills (silver-multi-ai-task, silver-deep-research-multi-ai) KEEP Cursor as a
  backend.
- Review-fix ladder (G6a): redesign now on native subagents, Claude-only (disabled on Codex; Codex defaults are only
  documented). Default Claude rungs, latest version of each tier, never Fable: `haiku:xhigh`, `sonnet:high`,
  `sonnet:xhigh`, `opus:low`, `opus:medium`, `opus:high`; the user may include or exclude rungs in the prompt.
  `RFL ABORT <run-id>` is accepted. Design: `handoff/tracking/DESIGN-G6-rfl-native.md` plus the orchestrator addendum in
  `handoff/tracking/DECISIONS.md`.
- The release is Claude-only. After the release, give the user a prompt for a later local Codex end-to-end test.
  Claude end-to-end must be tested before release.
- Private data: scrub the tree, no history rewrite; delete tracked `*-stdout.txt` / `*-stderr.txt` captures.
- Pin marketplace entries to release tags. Public install goes through alo-labs/agent-plugins (`plugins/silver-bullet`,
  ref+sha pinned). Keep the CDN scripts and add SRI hashes. Rename colon paths to `sb-<x>`. Remove
  `SB_DOCTOR_ASSUME_YES` after H4a and H5 merge. Add the graphify skill dirs to the hash lock.
  R1-22: strict everywhere for pushes to the default branch.
- Claim checker (H8a): strict whole-quote rule; low supported rate accepted. Vendor identity (H8b): precision first;
  prose URLs credit nothing; a URL credits only as the whole value of a source field. Devin is not an accepted residual.

## 5. State at handoff (2026-11-05)

PR branch `claude/optimistic-ramanujan-tccfud` is pushed at `b654bc1` (CI red: see H4b below).

### Merged into the PR branch
F1, F2, H2, H3, H3b, H5, H8a, H8b (+follow-up, merged `b654bc1`), H4a, coverage batches A, B, C1, D, E, F.

### CI is red on `b654bc1` for ONE known reason
95 "CLI missing" tests fail (stack-optimize, synergy-audit, silver-doctor D10/D20): H4a is merged but its companion
H4b (CLI scripts and test helpers) is not. Cherry-picking only H4b's helpers does not fix it. Merge H4b as soon as it is
approved. A PR comment already explains this.

### Packages not yet merged (branch, head at handoff, status)

| Pkg | Branch | Head | Status |
|---|---|---|---|
| H4b | fix/H4b-toolstack-scripts | 05922a6 | Round-5 review: CHANGES_REQUIRED, 1 major + 1 minor, and it is the FIRST thing to finish (it turns CI green): see `handoff/tracking/review-fix-H4b-toolstack-scripts-r5.json`. Major: `tests/scripts/test-global-five-tool-instances.sh` was not updated for the new `RT_LEANCTX_ALLOW_INSTALL` switch; it fails on HEAD and on HEAD merged with the base (0 passed, 1 failed). Fix: pass the switch in its `run_patch` for pi, and add a Pi run without it that asserts no package. Minor: the optimizer and receipts.sh still switch leanctx on in the Pi adapter config on wire alone (the package is withheld), while docs/CONSENT.md says Pi LeanCTX needs both wire and install. Everything else verified: the source gate (108 runs), the 18 CLI-missing tests pass on the merged tree, Bash coverage 100%, merge-tree clean. Next: a small Sonnet repair, then a quick round-6 review, then merge. Drop `scripts/install-recommended-tools-cursor.sh` and `scripts/lib/cursor-cli-allowlist.json` in favour of HC's deletion. |
| G1 | fix/G1-delivery-gates | 52cbef5 | Round-3 review: CHANGES_REQUIRED (6 major, 2 minor); see `handoff/tracking/review-fix-G1-delivery-gates-r3.json`. Majors: (1) `git checkout main && git push origin HEAD` counts as intermediate (HEAD read before the command runs); (2) an unresolvable `cd` target (`cd "$(cat f)"`, `read D<f; cd "$D"`, `cd "$OLDPWD"`, `cd` inside a function) falls back to the hook's own directory; (3) git config is ignored (stored and `git -c`): `remote.origin.push`, `push.default`, `push.followTags`, `remote.*.mirror`; (4) destinations checked only against local refs (`feat/x:heads/main`, `+feat/x:rtag`; default branch of a non-origin remote never checked); (5) MCP writes check the local checkout's default branch only, not the target owner/repo; (6) gh api release commit wrong for `-p/--preview` before the endpoint, two releases in one command, repeated `target_commitish`. Minor: `git checkout -b feat/n && git push -u origin feat/n` over-gated; six files under 100% only because the author's test list omitted their tests. Next: Sonnet repair (consider an Opus design pass for the push classifier: the lexical approach keeps leaking; the strictest-tier-for-unresolvable rule applies), then round-4 review. Merge-tree vs G2 conflicts in docs/HOOKS.md, hooks/hooks.json, both cursor-hooks.json files, scripts/deploy-gate-snippet.sh, tests/integration/test-session-scenarios.sh. |
| G2 | fix/G2-planning-floor | f0141ac | Round-2 repair DONE (globs, patch/git apply, keyed HMAC seal + recorder origin check, inline code refusal, minors); coverage 100% incl. `dev-cycle-check.sh` 550/550. Needs the round-3 Opus review (not yet run); see `handoff/tracking/fix-G2-planning-floor.json` `review_repair_r2` and `handoff/tracking/review-fix-G2-planning-floor-r2.json`. G1 trial-merge conflicts and how to resolve: `hooks/hooks.json` split the groups (`completion-audit` and `ci-status-check` in `Bash|exec_command|mcp__.*`; `spec-floor-check`, `forbidden-skill-check`, `uat-gate` in a following `Bash|Skill|exec_command` group); `scripts/deploy-gate-snippet.sh` keep G1's comment and add `.seal` and `.hwm` to the rm; `tests/integration/test-session-scenarios.sh` keep G2's S5.0 assertion then G1's touch; regenerate `docs/HOOKS.md` and both cursor-hooks.json files. |
| G3 | fix/G3-stop-prompt-override | ac28384 | Round-2 review: CHANGES_REQUIRED (2 major, 6 minor). Repair HELD until G1 and G2 merge: the branch carries stale G1/G2 tips; merge them in, and for `hooks/lib/recommended-tools.sh` take the base's file (H4a's per-user consent API). Fix the minors: see `handoff/tracking/review-fix-G3-stop-prompt-override-r2.json`. |
| G4 | fix/G4-session-state | f2e99ed | APPROVED in round 3 (`handoff/tracking/review-fix-G4-session-state-r3.json`), not yet merged. Merge the current base first: conflicts only in CLAUDE.md (hook count) and docs/HOOKS.md (3 hunks); hooks.json and hooks-purpose.json merge cleanly. Follow-up minor in `handoff/tracking/FOLLOWUPS.md` (future-dated heartbeat in a committed `.phase-locks.json`). |
| G5 | fix/G5-orchestrator | dc0ee05 | Round-2 review is in `handoff/tracking/`; check its verdict and whether a repair is pending. |
| G6b | fix/G6b-delegation-scripts | 66f9c70 | Round-3 review: CHANGES_REQUIRED (1 major, 3 minor); see `handoff/tracking/review-fix-G6b-delegation-scripts-r3.json`. Major: the brief scanner (`agent_redact.py`) misses `Authorization: Basic/token` headers, `--token`/`--password` flags with a space, UUID-shaped API keys, `TOKEN=AB12_CD34_...`, `admin:admin@` URLs on any host, `*_KEY` names and PGP private key blocks. The Codex transcript dir, fingerprint, exit-race and docs findings from round 2 are fixed. Next: launch a Sonnet repair, then round-4 review. Merge-tree vs b654bc1 is clean. |
| HC | fix/HC-remove-cursor | bf9e3a3 | Round-3 review: CHANGES_REQUIRED (1 major, 2 minor); see `handoff/tracking/review-fix-HC-remove-cursor-r3.json`. Major (regressed by the r2 narrowing of the toolstack move): after the cleanup, 24 Silver Bullet files remain under `~/.cursor/hooks/toolstack` (lib/recommended-tools/*, lib/five_tool_runtime/*.py, reconcile-recommended-tools.sh, two .ts files), each reported as 'not a Silver Bullet toolstack file'; `graphify.mdc` and `context-mode.mdc` (synced by install-body.sh into ~/.cursor/rules) are left with no note while the CHANGELOG says the global toolstack is removed. Seed a temp HOME with the base installer's own deploy step (`rt_deploy_reconciler_snapshots`) to reproduce. Minors: `--dry-run` prints 'would move' then 'kept: not Silver Bullet' for the same file; the backup folder itself can be a symlink, so moved items land outside ~/.cursor. Merge-tree vs b654bc1: 59 conflicts (29 modify/delete = keep the deletion; 30 content conflicts in H4a/H4b files needing a real merge: hook gate libs, record hooks, their tests, core-rules.md and .sha256, docs), so HC is merged LAST. The list is in the review JSON. |

Review verdict files are `handoff/tracking/review-fix-<pkg>-rN.json`; author reports are `handoff/tracking/fix-<pkg>.json`
(sections `review_repair_rN`). If a review was running when the previous session stopped, its result is lost:
relaunch it (Opus Medium) with the brief, the head above and the prior review file.

### Merge order and expected conflicts
H4b -> G1 -> G2 -> G3 -> G4 -> G5 -> G6b -> HC. Expected conflicts:
- `hooks/hooks.json` (G1, G2, G3, G5); `docs/HOOKS.md` and the CLAUDE.md hook count: final expected 99 hook commands and
  64 scripts; regenerate with `python3 scripts/generate-hook-reference.py`.
- G3/G5: `orchestrator-state.sh`, `orchestrator-directive-guard.sh`.
- HC: keep the deletion; keep H3b's scrubbed sibling-prompt doc; re-pin the core-rules sha; grep for Cursor after merging.
- After any merge: `bash scripts/sync-codex-package.sh`, then lint, invariants, generators, mirrors.

### Still to launch (in order)
1. G6a: the native review-fix ladder, after HC merges. Needs Claude Agent-tool parameter and post-spawn payload fixtures
   first; say exactly what the user must provide if they cannot be captured. Also clean up what HC left to it: the ladder
   SKILL's Cursor/Grok-substitute text and mirrors, the `composer-2.5` defaults in the review-fix-ladder state hook, the
   Grok/Composer routing in `tests/skill-scenarios/silver-review-fix-ladder.md`.
2. FU1: the minor follow-ups (`handoff/tracking/FOLLOWUPS.md`; includes H8b SKILL.md:179,192 wording for the five source fields and
   an upper-case-host test).
3. H1, H6, H7, H9, H10, H11 (docs last): see `handoff/tracking/packages.json`.

### Finish
Fresh full CI run on the final head, all green including coverage at 100% in ONE run. Then: `graphify update .`; fold
`handoff/tracking/scores-pending.csv` rows into `subagent-model-scores.csv`; update the PR description; send the user a final report
with every finding's disposition and the residual risks (lexical limits; GitHub Actions SHA pinning for the user; unchanged
history; the agent-plugins repo needs a Claude entry bump and has a stale Cursor manifest); give the user the Codex
end-to-end test prompt; tell the user `/t-multiai-claude.log` (repo root `/`) must be deleted by hand (the safety check blocked `rm`).

## 6. Environment notes
- Disk is tight: delete full repo copies in probe dirs; never copy the whole repo.
- Tests: `bash tests/run-all-tests.sh [--jobs 4] [--suite X]`; coverage: `tests/coverage/run-coverage.sh --only ...`
  (one run). Lint: `bash scripts/lint-shell.sh --all`. Invariants: `bash scripts/check-repo-invariants.sh`.
- Set `PYTHONDONTWRITEBYTECODE=1` for probes. Worktrees live under `.claude/worktrees/`.
- Record one score row per agent run in `scores-pending.csv`.
