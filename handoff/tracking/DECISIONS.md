# User decisions (2026-11-03, via questions UI)
- R13-11 private data: SCRUB TREE, NO HISTORY REWRITE. Delete quota plan (CLAUDE-QUOTA.md account data + LADDER-STATUS.json
  account fields), SETUP_REPORT.md, AI session transcripts (.planning/**/*.err|.log run transcripts); replace /Users/<name>/
  absolute paths with placeholders INCLUDING in .planning/ (user-approved exception to the no-.planning-edit rule); gitignore;
  CI check against new personal paths / non-allowlisted emails.
- R13-02 / R7-30: PIN Claude marketplace entry to release tags (ref/sha written by sync scripts).
- Worm advisory: NONE.
- R13-13: SHRINK plugin payload (exclude research/, .planning transcripts, graphify graph, .bak from what ships).
- Actions SHA pinning: leave tags; list exact actions for the user to pin later (needs-user list in report).
- R13-26: move skills/ and templates/workflows/ to .cursorindexingignore; update the 3 dependent scripts/tests.
=> implement as package H3b after H3 merges.
- R10b-02: keep CDN scripts, add SRI hashes (download exact versions via proxy to compute).
- R10b-04: RENAME colon dirs to sb-<x>, keep name in frontmatter (live loader check if possible).
- R8-25: REMOVE SB_DOCTOR_ASSUME_YES once per-user consent record exists (H4a API).
- Graphify-managed skill dirs: ADD to hash lock.
- Follow-up for H8a owner: live_dispatch PHASE_INSTRUCTIONS must allow optional matrix_entries key (H8b need).
- H4a needs: session-start must call sb_leanctx_clear_usage_state on branch change (G4). core-rules.md/silver-bullet.md wording 'consent' -> per-user consent (H7). R8-25 SB_DOCTOR_ASSUME_YES removal after H4a+H5 merge.
- G2 note: dev-cycle-check F-09 branch read should use sb_branch_scope_read "$(sb_branch_scope_file)" (R3-13).
- F2 consumer needs: dev-cycle-check.sh:447 and record-skill.sh:83 pass payload on argv (G2/G4 must move to stdin); consumers deny on helper_unavailable (R1-06); orchestrator parent adopt strict read_only (G5).
- R11-02 accepted as partial: lexical claim scorer limits documented (role swaps, out-of-table opposites/synonyms, idioms). Report to user as residual risk.
- H8a claim checker: user chose "Conservative + escalate" (supported / contradicted / needs-review; strict never silently passes ambiguous).
- R6-17 pins: orchestrator decision — pin to the min_version already in the template.
- Container restart: undelivered results recovered from scratchpad JSON files.
- 2026-11-03: User: no more Opus 5.5 XHigh subagents. Reviews now use Opus 5.5 High (model: opus, effort: high); fixes stay Sonnet 5.5 medium. Running Opus XHigh reviewers (REVF-H3b, REVF-H5-r2) may finish.
- 2026-11-03: R13-13 payload: user says "We have separate repos for the plugins. Look up in alo-labs org." Candidates: alo-labs/claude-plugins, agent-plugins, codex-plugins, alo-labs-cursor-marketplace.
- 2026-11-03: User: reviewer model changed further to Opus 5.5 MEDIUM (model: opus, effort: medium). Supersedes Opus High.
- 2026-11-03: User: "we will no longer support Cursor." Scope of removal pending (asked via questions UI).
- 2026-11-03: Cursor: REMOVE FULLY in this PR (installer, bridge, bundles, tests, CI step, docs); Cursor-only findings become "moot: Cursor dropped".
- 2026-11-03: H8a claim checker: STRICT near-quote only. 'supported' only when the claim nearly repeats a quote clause word for word; any rewording -> needs_review. Higher needs_review rate (~half of reworded honest claims) accepted by user.
Pending follow-up FU1: F1 r4 minors (printf -v guard scope: session-start + lib/completion-audit), H5 r2 minors (sb-diagnostics relative-path hang; installer skip-marker bypass R8-05 p4; doctor D16/D17 from codex cache pre-existing).
- 2026-11-03: R13-13 resolved: public installs go through alo-labs/agent-plugins (thin manifests; Claude github+path, Codex url+path+--sparse, path plugins/silver-bullet, ref+sha pinned). Payload-only tag not needed; build-plugin-payload.sh to be dropped. External follow-ups for user: agent-plugins Claude entry pins v0.51.5 while silver-bullet is 0.53.0; its .cursor-plugin manifest becomes obsolete with Cursor removal.
- 2026-11-03: R13-11: DELETE all tracked *-stdout.txt / *-stderr.txt AI CLI captures (~286) and gitignore the pattern (keep+scrub only what a test/doc truly needs).
- 2026-11-03: H8a: keep WHOLE-QUOTE match (0/380 fakes pass); research instructions must tell writers to quote exactly the one sentence backing each claim.
- F2 needs-user (reword b9e03fe merge trailer via rebase): orchestrator decision: skip (merge carries no code; branch history not rewritten).
- F2 r2 author used pkill -f on test-shell-analysis-corpus.sh (process-safety slip; reported).
- H8b-followup: orchestrator rule: precision first (false vendor ticks fabricate matrix evidence); unified FP+recall corpus pinned; FP sets must be 0.
- 2026-11-03 18:27: CI on 8c161a5: validate, test(claude), test(codex) ALL GREEN; coverage cancelled by push. Policy: hold pushes until coverage on 127e2f9 finishes (~20:15 UTC), batch merges locally meanwhile.
- 2026-11-03: Cursor removal scope refined by user:
  * Existing Cursor users: keep ONE strip-only legacy cleanup script (removes only SB-created entries in ~/.cursor, with backup; never installs) + changelog note.
  * Multi-AI skills (silver-multi-ai-task, silver-deep-research-multi-ai): Cursor REMAINS SUPPORTED as their backend. Do not remove the multi-AI Cursor backend (cursor-agent CLI etc.).
  * Review-fix ladder: REDESIGN NOW in this PR to use the host's NATIVE subagents (Claude Code Task/Agent, Codex subagents); no Cursor dependency. Fold into G6 (RFL & delegation).
  * MCP matcher `CallMcpTool|MCP`: technical; verify Claude/Codex MCP tool names, drop Cursor-only names if unused.
- G6 to include RFL ladder redesign to native subagents (launch when slots free).
- H3b: orchestrator direction: workflow invariant must parse YAML (PyYAML safe_load/compose), fail closed if unparsable; personal-data check uses committed SHA-256 hashes of identity tokens + token scan, allowlist file for public identity uses.
- H8b-followup: 'Devin' as a person's name = documented residual risk (orchestrator call, report to user).
- H3b: hash file provides no secrecy (identity public in author fields) — accepted, documented; base64/hex/concatenation identity encodings = documented residual.
- H8b-followup: orchestrator direction: ambiguous (common-word/surname) vendor names credited only with an explicit product cue (allowlist), recall loss accepted.
- 2026-11-05: User: CRITICAL DESIGN DECISIONS go to an Opus 5.5 subagent (High for complex, Medium for simpler). Reviews Opus Medium; fixes Sonnet Medium. R1-22 push-to-default-branch tier: user chose STRICT EVERYWHERE (default flips to completion for all projects).
- Disk: session allowance is tight; probe dirs must delete full repo copies when done (cleaned 14GB on 2026-11-05).
- 2026-11-05: CI on 94800f8: validate/test(claude)/test(codex) GREEN; coverage job CANCELLED at the 90-min timeout (no verdict). Pushed 7130467 (H8a merge + coverage timeout 90->180). HOLD further pushes until coverage on 7130467 completes (watch run for 7130467). Follow-up: trim coverage runtime (e.g. tests/hooks/test-shell-analysis-corpus.sh ~190s untraced).
- 2026-11-05 G6a (RFL native): user chose "Verify Codex first" (hold Codex ladder until probed live; do not ship relayed). User ACCEPTED `RFL ABORT <run-id>` (user-message-only, audited). Ladder rung defaults: user asked "Rungs for what purpose?" -> explain in plain English and re-ask.
- DESIGN docs ready: DESIGN-G6-rfl-native.md (G6a native ladder, G6b delegation-script hardening split), DESIGN-H8b-vendor-detection.md (vendor detection).
- 2026-11-05: Orchestrator decisions on DESIGN-H8b open questions: accept all 4 (acronyms ambiguous; Devin ambiguous; legacy source_ref signal with text condition; one-line live_dispatch.py vendors contract change inside the H8b package).
- 2026-11-05: Merge order for hooks.json: G1 first, then G2 (merges base). HC deletes many files; merge HC LAST among code packages and keep H3b's scrubbed docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md.
- G6 (RFL native): Codex = "Verify Codex first" (no codex CLI in this container; needs user's help or hold); RFL ABORT accepted; rung defaults pending user explanation.
- 2026-11-05 G6a RUNG RULES (user, verbatim): "by default, rungs will always use the latest versions of 3 model tiers: Haiku, Sonnet and Opus in Claude (excluding Fable), and Luna, Terra and Sol in Codex (excluding Astra). For Haiku and Luna, starting rung will be Extra High. In Sonnet's case, Max effort will not be used. In Opus, Extra High and Max will not be used. However, user may exclude or include any rung when prompting." -> ladder = latest version of each tier (resolved at run time, not pinned ids), per-rung exclusion/inclusion by the user in the prompt.
- 2026-11-05 Codex verify: user suggested a desktop session driving local Codex. list_computer_folders shows MacBookPro folders (tmp, JobReady, projects) but all 'cannot_be_used: not_available' (Claude app on that Mac needs update/does not serve to cloud sessions) -> cannot probe Codex from here. Pending user action.
- 2026-11-05 FINAL G6a LADDER (user): release is CLAUDE-ONLY (Codex later via a local end-to-end session; orchestrator must provide the user a Codex e2e prompt after the release; Claude end-to-end must be tested on Claude before release). Default Claude ladder (latest version of each tier, resolved at run time, Fable excluded): Haiku xhigh -> Sonnet high -> Sonnet xhigh -> Opus low -> Opus medium -> Opus high (Haiku: starts at xhigh; Sonnet: no max/low/medium; Opus: no xhigh/max). Codex tiers Luna/Terra/Sol (Astra excluded) with Luna starting at xhigh and Terra without low/medium are DOCUMENTED defaults only, ladder disabled on Codex with a clear message. User may exclude or include any rung when prompting.
- 2026-11-05 FIRST REAL COVERAGE VERDICT (run on 7130467, 85 min): validate/test(claude)/test(codex) GREEN (35575 tests); coverage FAIL: Bash 99.98% (44947/44954 stmts) — misses: hooks/dev-cycle-check.sh 4 stmts, hooks/lib/hook-audit.sh 2 stmts, scripts/check-repo-invariants.sh 1 stmt (line 127, fixed by H3b merge). Python 24859/24859 (100%), JS 100%. Pushed 5acae75 (H3b merge + 18 commits). A scoped coverage probe is finding the exact lines (scratchpad/cov-probe/out.txt); G2 owns dev-cycle-check.sh (tell G2 to cover remaining uncovered statements in its final scoped run).
- 2026-11-05 Coverage gap lines (from scoped probe on 5acae75): hooks/dev-cycle-check.sh uncovered 544 (branch-file `true`), 602 (exit), 627-629 (shell_target_scope_fallback grep) -> G2 must cover these in its final scoped run (CI said 4 of those 5 are uncovered in the full suite). hooks/lib/hook-audit.sh 40/42 fixed by orchestrator test commit (tests/hooks/test-hook-audit.sh Tests 4-5). check-repo-invariants.sh:127 fixed by H3b merge. Local commits 248fda5 (test-install-codex allowlist repo_invariants.py) + hook-audit tests: NOT pushed yet.
- 2026-11-05 G5 decision (orchestrator): Codex workers cannot be identified (Codex sets neither agent_id nor SB_ORCHESTRATOR_WORKER); since this release is Claude-only, orchestrator PARENT-MODE enforcement is inactive on hosts that cannot identify workers (documented), never a hard deny of all edits. R10-02 part B (templates/workflows vs required_deploy) is G5's to finish.
- 2026-11-05 G4: R3-16/R3-17 yes (helper under scripts/, plugin-root load); R3-14 per-project/worktree state scoping DEFERRED to a dedicated follow-up (G4b) after G1-G5 merge.
- ORDER: H4a lands first; then notify H4b author (ae2730b1ab868d1df) to merge H4a tip + base and finish items 5-6.
- 2026-11-05 13:01 CI on 2a65018 (full): tests 35735 passed, 0 failed (8/8 suites green); validate/test(claude)/test(codex) green. COVERAGE: ONLY gap = hooks/dev-cycle-check.sh 576/580 (4 statements) — G2 owns it (already told to cover). Bash 44940/44944, Python 100%, JS 100%. All other files 100%. After G2 merges, a coverage run must show dev-cycle-check at 100% (CI measures once; a full run takes ~2h).
- 2026-11-05 G6b decisions: coverage exclusion for scripts/lib/agent-adapters REJECTED (stub-CLI tests); strict default outside project accepted (+ close nested-repo/non-git gaps); quota gating accepted.
- MERGE ORDER (proposed): H4a -> H4b -> G1 -> G2 -> G3 -> G4 -> G5 -> G6b -> H8b-fu -> HC (last; keep-the-deletion for cursor files; core-rules pin re-check). Then G6a on top of HC.
- Expected final hook count after all merges: 99 hook commands, 64 scripts (per G4 reviewer); regenerate docs/HOOKS.md and CLAUDE.md count at the end.
- 2026-11-05 16:20: CI on 54f285f (H4a merged): test(codex) 94 failures (36430 passed) = "CLI missing -> verdict fails" tests (test-sb-small-scripts, test-silver-doctor, stack-optimizer tests). They depend on H4b's script+test-helper changes (H4a alone is not green; cherry-picking H4b's 4 tests/lib helpers alone does NOT fix). RESOLUTION: merge H4b immediately after approval; the PR branch is red until then. Do not push more before H4b merges unless forced by the stop hook.
- H8b-followup r10 verdict: URL parser tokenisation still leaks (131 false credits on fp12). ORCHESTRATOR DECISION: restrict the URL signal to STRUCTURED fields only (`source_ref` / explicit URL fields), parsed as ONE whole URL; never extract URLs from running prose. Whole-field parse, scheme or www, strict host.

- G3 r2 CHANGES_REQUIRED: first major is stale G1/G2 tips; repair G3 (r3) only after G1 and G2 merge into base, then merge base and fix H4a consent conflict + minors.
- G6b r2 CHANGES_REQUIRED -> repair launched.

## H8b-followup merged (b654bc1)
- APPROVED at b4c18ec. FU1 minors: SKILL.md:179,192 says only source_ref names vendors but code reads all five source fields; add upper-case host test.
