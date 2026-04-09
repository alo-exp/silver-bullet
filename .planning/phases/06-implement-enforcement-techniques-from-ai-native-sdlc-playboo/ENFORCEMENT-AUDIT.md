# Silver Bullet Enforcement Audit Report

**Audited:** 2026-04-06
**Auditor:** Adversarial review — systematic gap analysis across all rules and mechanisms
**Scope:** silver-bullet.md §§0–9, hooks/hooks.json, all 11 hook scripts

---

## ENFORCEMENT AUDIT REPORT

---

### Summary Table

| Rule / Section | Hook Enforcement | Soft Only | Gap Severity | Notes |
|----------------|-----------------|-----------|--------------|-------|
| §0 — Switch to Opus 4.6 | None | Yes (silver-bullet.md) | HIGH | Zero mechanical enforcement; model choice is invisible to hooks |
| §0 — Read all project docs | None | Yes (Anti-Skip text) | HIGH | No Read-tool verification; hook cannot observe LLM reading |
| §0 — Run /compact | None | Yes (Anti-Skip text) | MEDIUM | SessionStart matcher covers "compact" but fires ON compact, not before |
| §1 — Invocation-based tracking | record-skill.sh PostToolUse/Skill | No | LOW | Well-covered; vacuous invocation acknowledged |
| §1 — Subagent HEREDOC format | None | Yes (silver-bullet.md) | MEDIUM | No hook inspects git commit message content |
| §2 — Read active workflow file | None | Yes (Anti-Skip text) | HIGH | No Read-tool verification enforced mechanically |
| §3 — No step skipping | dev-cycle-check.sh (partial) | Yes | MEDIUM | Hooks only block code edits and commits; other work proceeds freely |
| §3a — Review loop: 2 consecutive ✅ | None | Yes (silver-bullet.md) | CRITICAL | Zero hook enforcement; Claude can declare one pass sufficient |
| §3b — GSD command tracking | record-skill.sh | No | LOW | Well-covered |
| §4 — Session mode write | session-log-init.sh (trigger only) | Yes | MEDIUM | Mode file not required to exist before work; display only |
| §4 — Work blocked if mode unset | None | Yes (Anti-Skip text) | HIGH | compliance-status.sh shows "interactive" default but never blocks |
| §5 — Offer Opus before DISCUSS | None | Yes (silver-bullet.md) | HIGH | Zero mechanical enforcement |
| §5 — Offer Opus before Design | None | Yes (silver-bullet.md) | HIGH | Zero mechanical enforcement |
| §6 — Never use superpowers:executing-plans | None | Yes (silver-bullet.md) | HIGH | No hook intercepts Skill tool calls for forbidden skill names |
| §6 — Never use superpowers:subagent-driven-development | None | Yes (silver-bullet.md) | HIGH | Same gap — no blocklist on Skill tool use |
| §6 — GSD owns planning | None | Yes (silver-bullet.md) | MEDIUM | No hook detects Superpowers brainstorming handoff to writing-plans |
| §7 — Never overwrite/rename/delete without permission | None | Yes (silver-bullet.md) | HIGH | No hook enforces file safety for mv/cp/rm on project files |
| §8 — Plugin cache boundary | dev-cycle-check.sh (file_path only) | Partial | HIGH | Bash mv/cp with plugin cache as destination is partially caught but not fully |
| §8 — Hook self-protection | dev-cycle-check.sh | Partial | MEDIUM | Indirect paths and temp-file+mv bypass documented below |
| §9 — quality-gate-stage ordering vs. workflow skills | completion-audit.sh | Partial | MEDIUM | Stages not checked AFTER workflow skills; race condition exists |
| §9 — verification-before-completion in each stage | None beyond stage marker | Yes | HIGH | Stage marker can be written without verification-before-completion being recorded |
| Stop — SubagentStop event | stop-check.sh (Stop only) | No | HIGH | SubagentStop not registered; subagent can declare done without gate |
| Branch switch mid-session | session-start only | Yes | MEDIUM | Mid-session branch switch not detected; stale state persists |
| CI: no-status-yet case | ci-status-check.sh (silent exit) | Yes | LOW | Silent exit is correct; no false positives |
| Timeout: interactive mode | timeout-check.sh (autonomous only) | Yes | LOW | Intentional scope; non-issue |

---

### Findings

---

**[F-01] Review Loop "Two Consecutive Approvals" — Documentation Only**

- **Rule:** §3a — "MUST iterate until the reviewer returns ✅ Approved TWICE IN A ROW"
- **Current enforcement:** None. silver-bullet.md states the rule; no hook can observe skill output content.
- **Gap:** The `record-skill.sh` hook records that `/code-review`, `/requesting-code-review`, and `/receiving-code-review` were invoked. It does not record how many times, whether the output contained "✅ Approved", or whether two consecutive approvals occurred. Claude can invoke each skill once and declare the loop complete.
- **Feasibility:** Hard (output-content detection is architecturally difficult in the current model). Medium alternative: require each skill to appear at least twice in the state file (a count-based proxy). This is an imperfect proxy but adds friction.
- **Recommended fix:** Add a `review-loop-pass-1` / `review-loop-pass-2` pair of tracked markers to the state file. Require both to be present before `gh release create`. Document that these are manually written by Claude after each clean pass, and block if only one is present. This converts a purely documentation-only rule to a partially mechanical one. The `completion-audit.sh` release check would require `review-loop-pass-1` and `review-loop-pass-2` in the state file in addition to the existing skill list.

---

**[F-02] Session Startup Checklist — No Mechanical Enforcement**

- **Rule:** §0 — Switch to Opus 4.6, Read all docs, Run /compact
- **Current enforcement:** Anti-Skip text in silver-bullet.md. SessionStart hook fires but only injects context; it does not verify that docs/ was read or /compact was invoked.
- **Gap:** Claude can begin work immediately after a new session without reading docs/ or running /compact. The only check is whether Read tool calls for docs/ files appear in the conversation before other work — the Anti-Skip text names this as the violation signal, but nothing blocks work if they are absent.
- **Feasibility:** Medium. A SessionStart hook could write a "startup-required" flag to the state file, then a PreToolUse hook (on Edit/Write/Bash) could check whether the flag was cleared. The flag would be cleared when specific conditions are met. However, verifying "read docs/" is impossible without observing Read tool calls, which SessionStart cannot do.
- **Recommended fix (partial):** At minimum, extend `session-start` to write a `startup-pending` marker to the state file. `dev-cycle-check.sh` could then check for this marker and block code edits until the marker is cleared. Clearing the marker requires explicit `/compact` invocation (tracked via SessionStart on "compact" matcher). This enforces /compact mechanically. The docs-reading requirement remains soft-only.

---

**[F-03] Forbidden Skill Invocations (§6) — No Blocklist on Skill Tool**

- **Rule:** §6 — "NEVER use superpowers:executing-plans or superpowers:subagent-driven-development"
- **Current enforcement:** Documentation only. dev-cycle-check.sh fires on Edit/Write/Bash, not on Skill tool use.
- **Gap:** Claude can invoke `superpowers:executing-plans` or `superpowers:subagent-driven-development` freely. No hook intercepts Skill tool calls to check the skill name against a blocklist. The state file tracks which skills were used, but `record-skill.sh` records them after the fact — it does not block them before execution.
- **Feasibility:** Easy. A PreToolUse hook on the Skill tool matcher could read the skill name from `.tool_input.skill` and block if it matches the forbidden list.
- **Recommended fix:** Add a new PreToolUse hook on `Skill` matcher (or extend `dev-cycle-check.sh` to handle Skill events) that reads `.tool_input.skill` and emits a deny decision if the value is `superpowers:executing-plans` or `superpowers:subagent-driven-development`. This converts a CRITICAL documentation-only rule to hard enforcement.

---

**[F-04] File Safety Rules (§7) — Zero Hook Enforcement**

- **Rule:** §7 — "Never overwrite, rename, move, or delete any existing project file without explicit permission"
- **Current enforcement:** Documentation only.
- **Gap:** Claude can run `mv`, `cp -f`, `rm`, or `Write` targeting any project file without any hook blocking. The only protection is the LLM's adherence to the documented rule. In autonomous mode with bypass-permissions enabled, this is particularly dangerous — no confirmation dialog and no hook block.
- **Feasibility:** Medium. A PreToolUse hook on Bash could pattern-match for `rm`, `mv`, `cp`, and `git rm` targeting files outside the plugin cache and state directory, then require explicit confirmation or emit a warning. The Write tool already fires dev-cycle-check.sh, but that hook only checks planning stage — it does not gate on "has user approved this file deletion."
- **Recommended fix:** Add a Bash PreToolUse check in `dev-cycle-check.sh` (or a dedicated hook) that matches `\brm\b`, `\bmv\b`, `\bcp\b` commands not targeting plugin cache or state files, and emits an informational warning requiring confirmation. In autonomous mode, log each destructive file operation as an autonomous decision. This is not a hard block (which would be too restrictive) but converts zero-enforcement to at-minimum-one-warning enforcement.

---

**[F-05] §9 Stage Markers — Falsifiable via Whitelist in State Tamper Protection**

- **Rule:** §9 — Stages 1–4 require invoking `/superpowers:verification-before-completion` before recording the stage marker
- **Current enforcement:** `dev-cycle-check.sh` (SB-008) whitelists `echo "quality-gate-stage-[1-4]" >> state` in its Bash tamper detection. This means the stage markers can be written at any time, without verification-before-completion being recorded.
- **Gap:** The whitelisted command `echo "quality-gate-stage-1" >> ~/.claude/.silver-bullet/state` can be run by Claude without having ever invoked `/superpowers:verification-before-completion`. The completion-audit.sh only checks that the four stage markers are present — it does not check whether `verification-before-completion` was recorded after each stage marker was written. Claude could write all four stage markers in sequence and then proceed to `gh release create` without any verification skill invocations.
- **Feasibility:** Medium. Options: (a) require `verification-before-completion` to appear in the state file at least 4 times (once per stage) — but the state file records skills without duplication (grep -qx prevents duplicate lines). (b) Require a `verification-before-completion-stage-N` pattern instead of or in addition to the stage marker. (c) Require the stage markers to appear AFTER verification-before-completion in the state file (line-number ordering check, similar to the code-review triad ordering check).
- **Recommended fix:** Change the §9 stage recording instruction from `echo "quality-gate-stage-1"` to two sequential writes: first `echo "verification-before-completion-stage-1"` then `echo "quality-gate-stage-1"`. Update `completion-audit.sh` to check that each `verification-before-completion-stage-N` marker precedes the corresponding `quality-gate-stage-N` marker in the state file (using the existing `skill_line` ordering logic). Add these four new marker names to the allowed whitelist in `dev-cycle-check.sh`.

---

**[F-06] Stop Hook Does Not Fire on SubagentStop**

- **Rule:** §3 — Subagents must complete workflow; §6 — GSD execute-phase spawns subagents
- **Current enforcement:** `stop-check.sh` registered for `Stop` event only. `SubagentStop` event (fired when a subagent terminates) is not registered in `hooks.json`.
- **Gap:** When `/gsd:execute-phase` spawns subagents that complete individual tasks, each subagent fires a `SubagentStop` event when it finishes. `stop-check.sh` does not intercept this event. A subagent that completes work and declares itself done is not blocked by the stop gate. This matters because subagents may commit, push, and exit before the outer session's stop gate fires.
- **Feasibility:** Easy. Add a `SubagentStop` registration in `hooks.json` pointing to `stop-check.sh` (or a lighter variant that checks only intermediate-commit prerequisites rather than the full required_deploy list, since subagents are not expected to complete the full workflow).
- **Recommended fix:** Add a `SubagentStop` block to `hooks.json` with matcher `.*` pointing to a new `subagent-stop-check.sh` that validates only that the subagent did not push to remote without CI being green, and did not create a PR. Full workflow validation is not appropriate for individual subagents, but the CI and PR gates should apply.

---

**[F-07] Plugin Cache Boundary — Bash Destination Not Fully Blocked**

- **Rule:** §8 — "Edit any file under ~/.claude/plugins/cache/ is forbidden"
- **Current enforcement:** `dev-cycle-check.sh` checks `file_path` for Edit/Write tools (line 48). For Bash commands, it checks if the command string contains the plugin cache path AND one of the write operators (`>>`, `>`, `tee`, `cp`, `mv`, `rm`, `chmod`, `sed`). The check appears as: `printf '%s' "$command_str" | grep -qE "(${sb_hooks_dir}/|${CLAUDE_PLUGIN_ROOT}/hooks\.json)" && printf '%s' "$command_str" | grep -qE '(>>|...)'` — but this check targets the HOOKS directory specifically, not the plugin cache generally.
- **Gap (critical):** Looking at the code, the plugin cache boundary check for Bash commands (lines 48–59) only checks `file_path` against `plugin_cache`:
  ```
  if [[ -n "$file_path" ]] && [[ "$file_path" == "$plugin_cache"/* ]]; then
  ```
  The variable `file_path` for a Bash tool call is always empty (line 37–44: `file_path` is extracted from `.tool_input.file_path`, which is absent in Bash commands). So for Bash commands, `file_path` is empty and this check is NEVER triggered. A Bash command like `cp /tmp/evil.sh ~/.claude/plugins/cache/superpowers/current/skills/code-review/SKILL.md` would not be caught.
- **Feasibility:** Easy. The existing pattern for catching Bash writes to the hooks directory (lines 73–79) already shows the correct approach: check `command_str` against the target path AND a write operator. The same pattern needs to be applied for the plugin cache path.
- **Recommended fix:** After the `file_path` check for plugin cache (lines 48–59), add a parallel `command_str` check:
  ```bash
  if [[ -n "$command_str" ]] && \
     printf '%s' "$command_str" | grep -qE "$plugin_cache" && \
     printf '%s' "$command_str" | grep -qE '(>>|\s>[^>&=]|\btee\b|\bcp\b|\bmv\b|\brm\b|\bchmod\b|\bsed\b)'; then
    emit_block "PLUGIN BOUNDARY VIOLATION via Bash"
  fi
  ```

---

**[F-08] Hook Self-Protection — Temp File + mv Bypass**

- **Rule:** §8 / hook self-protection — "Silver Bullet NEVER modifies its own enforcement hooks"
- **Current enforcement:** `dev-cycle-check.sh` blocks Bash commands that write to the hooks path using `>>`, `>`, `tee`, `cp`, `mv`, `rm`, `chmod`, `sed`. Pattern checked on line 76.
- **Gap:** Claude could use a two-step approach: (1) Write a modified hook to `/tmp/evil-hook.sh` (not blocked — `/tmp` is not hooks dir), then (2) run `cp /tmp/evil-hook.sh /path/to/hooks/completion-audit.sh`. Step 1 would not be blocked by any hook. Step 2 involves `cp` targeting the hooks path — this IS caught by the pattern on line 76 which checks for `\bcp\b` and the hooks path in the same command. However, it requires both to appear in the same command string. A split across two Bash calls bypasses the check for step 1 entirely, but step 2 would be caught.

  A harder bypass: `cat /tmp/evil.sh | tee ${CLAUDE_PLUGIN_ROOT}/hooks/completion-audit.sh` — this is caught. But `python3 -c "open('/path/to/hooks/...', 'w').write(open('/tmp/evil.sh').read())"` is NOT caught because `python3` is not in the write-operator list. Similarly, `node -e "require('fs').writeFileSync(...)"` or any scripting language's file write is not detected.
- **Feasibility:** Medium. A general solution requires either: (a) blocking all Bash that mentions the hooks path regardless of subsequent operators (too broad — would block reading hooks for legitimate purposes), or (b) adding common scripting language patterns to the detection regex. The most targeted fix is to add `python`, `python3`, `node`, `ruby`, `perl`, `awk` with common file-write patterns to the command detection.
- **Recommended fix:** Extend the Bash write-operator detection regex to include: `\bpython3?\b`, `\bnode\b`, `\bruby\b`, `\bperl\b` when the hooks path appears in the same command string. Also add `install\b` (GNU install command, which copies files). Accept that this is arms-race territory — determined bypass is always possible via multi-step operations, but the friction is valuable.

---

**[F-09] Mid-Session Branch Switch — Stale State Not Detected**

- **Rule:** Branch-scoped state (§4.15 of enforcement doc) — state is scoped to a branch
- **Current enforcement:** `session-start` checks the branch at session start only. No hook fires on branch switches during an active session.
- **Gap:** If Claude runs `git checkout hotfix-branch` mid-session (or the user opens the same Claude session and manually switches branches in the terminal), the state file still reflects the original branch's completed skills. Any subsequent `git commit` or `gh pr create` would be evaluated against the wrong branch's skill history.
- **Feasibility:** Easy (partially). `dev-cycle-check.sh` already calls `git rev-parse --abbrev-ref HEAD` on every invocation (lines 139–147). It could compare the current branch against the branch stored in `~/.claude/.silver-bullet/branch` and emit a warning (or clear state) if they differ. This is not a full fix (clearing state mid-session would disrupt in-progress work) but a warning is better than silent stale state.
- **Recommended fix:** In `dev-cycle-check.sh`, after detecting `current_branch`, compare it to `stored_branch` from the branch file. If they differ, emit a prominent warning: "Branch mismatch detected — state was recorded for [stored_branch] but current branch is [current_branch]. Run /compact to reset state for the new branch." This gives Claude and the user immediate visibility without hard-blocking.

---

**[F-10] Model Routing Rules (§5) — Zero Mechanical Enforcement**

- **Rule:** §5 — "Ask about Opus before Planning begins (before DISCUSS step)" and "Before Design sub-steps apply"
- **Current enforcement:** Documentation only. No hook can observe whether a model switch prompt was offered.
- **Gap:** Claude can proceed directly to `/gsd:discuss-phase` without offering the Opus upgrade. The rule is stated in silver-bullet.md and re-injected via prompt-reminder.sh, but the reminder does not specifically flag "you have not offered Opus today." The Anti-Skip text calls this a violation but cannot detect it.
- **Feasibility:** Medium. A state-based proxy is possible: add `offered-opus-for-planning` and `offered-opus-for-design` to the tracked markers. Require Claude to write these markers (via Bash, protected from tamper as a legitimate write) before `/gsd:discuss-phase` and design skills are recorded. The `dev-cycle-check.sh` could check for the corresponding marker before allowing the relevant skill recording. This is partially gameable (Claude writes the marker without asking) but adds friction.
- **Recommended fix (partial):** At minimum, extend `compliance-status.sh` to detect when `gsd-discuss-phase` is recorded but `offered-opus-for-planning` is not, and display a specific warning. This is informational only but makes the violation visible on every subsequent tool call.

---

**[F-11] §9 Stage Ordering vs. Workflow Skills — No Cross-Check**

- **Rule:** §9 — "This gate runs AFTER the normal workflow finalization steps ... and BEFORE /create-release"
- **Current enforcement:** `completion-audit.sh` checks (a) all required_deploy skills are present AND (b) all four quality-gate-stage-N markers are present. It does not check that the stage markers were written AFTER the workflow skills.
- **Gap:** Claude could technically run the §9 quality gate stages first (before testing-strategy, documentation, etc.), write the stage markers, then run the finalization skills, and `completion-audit.sh` would not detect the wrong ordering. The workflow intent is that quality gate stages are a pre-release sweep AFTER all other work is done.
- **Feasibility:** Easy. The existing `skill_line` ordering infrastructure in `completion-audit.sh` could be extended to verify that `quality-gate-stage-1` line number > last workflow skill line number.
- **Recommended fix:** In `completion-audit.sh`, after checking that all stage markers are present, verify that the minimum line number of any `quality-gate-stage-*` marker is greater than the maximum line number of any required_deploy skill. If not, emit a warning: "§9 quality gate stages were recorded before workflow finalization — stages must run after all required skills are complete."

---

**[F-12] SessionStart Matcher — Bypass via Compact Timing**

- **Rule:** §0 — "/compact the context" required at session start
- **Current enforcement:** SessionStart fires with matcher `startup|clear|compact`. This means the hook fires both at session start AND when /compact is run. The session-start script uses this to inject context after compaction (desirable) but does NOT verify that /compact was run at session start.
- **Gap:** The matcher being `startup|clear|compact` means the SessionStart hook fires when the session starts (matching "startup"), separately from when /compact is run (matching "compact"). Claude can start a new session, have the hook fire (injecting context), and then begin work without ever running /compact. The hook has no way to distinguish "fired because of startup" from "fired because of compact."
- **Feasibility:** Low. The SessionStart event payload does not reliably distinguish trigger reason. The cleanest approach is to write a `compact-pending` flag in the state file on the "startup" event and clear it on the "compact" event, then block code edits while `compact-pending` exists. However, this relies on being able to detect which trigger fired, which is not available in the hook.
- **Recommended fix:** Write a `compact-required` marker to the state file in `session-start` unconditionally on every startup. Add a second SessionStart hook (or extend session-start) to clear this marker only when it detects the "/compact" trigger. `dev-cycle-check.sh` blocks code edits if `compact-required` is present. This is imperfect (the distinction between startup and compact triggers may not be available) but creates a state-based enforcement path for the requirement.

---

**[F-13] CI Status Check — Pre-Push Only, Not Pre-PR**

- **Rule:** §3 — "CI must be green before deployment"
- **Current enforcement:** `ci-status-check.sh` fires on `git commit` and `git push` commands. It fetches `gh run list --limit 1` to get the last CI run status.
- **Gap (nuanced):** The CI check fires on Bash commands containing `git commit` or `git push`. It does NOT explicitly fire on `gh pr create`. The `gh pr create` command is caught by `completion-audit.sh` (which requires all required_deploy skills) but NOT by `ci-status-check.sh` (which only matches `git (commit|push)`). If CI was failing at the time of the last push and has not been re-checked, a PR could still be created — `completion-audit.sh` would allow it if required skills are present, and `ci-status-check.sh` would not intercept the `gh pr create` command.
- **Feasibility:** Easy. Add `gh pr create` and `gh release create` to the pattern in `ci-status-check.sh` (line 37: `grep -qE '\bgit (commit|push)\b'`).
- **Recommended fix:** Change the pattern in `ci-status-check.sh` from `\bgit (commit|push)\b` to `\bgit (commit|push)\b|\bgh pr create\b|\bgh release create\b`. This ensures CI is verified green at every delivery gate, not only at push time.

---

**[F-14] record-skill.sh — Namespace Stripping Allows Untracked Skill Invocations**

- **Rule:** §1 — "Each Silver Bullet skill MUST be explicitly invoked via the Skill tool"
- **Current enforcement:** `record-skill.sh` strips namespace prefixes (line 29: `sed 's/^[a-zA-Z0-9_-]*://'`). This means `superpowers:code-review` maps to `code-review` and satisfies the `code-review` requirement.
- **Gap:** The namespace stripping also means Claude can invoke `ANY:code-review` (any namespace) and it would satisfy the `code-review` requirement. If a user has custom plugins with a `code-review` skill that is a no-op, invoking it would satisfy the Silver Bullet enforcement gate. This is a weak point in the invocation-based model.
- **Feasibility:** Medium. Require specific skill namespaces for each required skill (e.g., `engineering:code-review`, `superpowers:requesting-code-review`). The namespace allowlist would be in `.silver-bullet.json`. This is a significant configuration complexity increase.
- **Recommended fix (minimal):** Add an allowlist of valid namespaces per skill type in the config. `record-skill.sh` would check that the namespace is valid before recording the skill. Low priority vs. other findings, as this requires a malicious custom plugin to exploit.

---

**[F-15] Compliance-Status Config Cache — Stale After Config Change**

- **Rule:** §1 — Compliance status reflects current required skill list
- **Current enforcement:** `compliance-status.sh` caches the config file path in `~/.claude/.silver-bullet/config-cache-{pwd_hash}`. The cache is validated by checking if `config_file` still exists, but NOT by checking if its contents have changed.
- **Gap:** If `.silver-bullet.json` is updated (required_deploy list changed), the compliance-status.sh cache will still point to the old config path, which will now return the old required_deploy list. The cache has no TTL or content-hash invalidation. The compliance display will show stale requirements until the cache file is manually deleted or the directory changes.
- **Feasibility:** Easy. Cache the config file's mtime alongside the path. If current mtime != cached mtime, invalidate the cache.
- **Recommended fix:** In `compliance-status.sh`, when reading from cache, also store and compare the mtime of the config file. If mtime has changed, invalidate the cache and re-walk.

---

**[F-16] stop-check.sh — Missing quality-gate-stage-N Enforcement**

- **Rule:** §9 — Quality gate stages must be complete before release
- **Current enforcement:** `stop-check.sh` (Stop hook) checks required_deploy skills. It does NOT check for `quality-gate-stage-1` through `quality-gate-stage-4` in the state file.
- **Gap:** The Stop hook fires when Claude declares work complete ("task done"). If Claude declares "task complete" after creating a release, the Stop hook would not catch missing stage markers. The stage marker check only exists in `completion-audit.sh` (which fires on Bash commands). If Claude declares task complete without running `gh release create` (e.g., declares the work "done" with everything committed but before tagging), the Stage gate is never checked.
- **Feasibility:** Easy. Add the same quality-gate-stage check that exists in completion-audit.sh (lines 283–291) to stop-check.sh.
- **Recommended fix:** In `stop-check.sh`, after the required_deploy skill check, also check whether `gsd-ship` is in the state file (indicating a release was intended) and if so, verify all four quality-gate-stage-N markers. If `is_release` markers are not tracked at stop time, a conservative fallback is to always require the stage markers if `create-release` is in the required_deploy list.

---

**[F-17] Session-Log-Init Trigger — Mode File Grep Is Fragile**

- **Rule:** §4 — Mode is written to mode file; session log is created on mode write
- **Current enforcement:** `session-log-init.sh` fires when a Bash command contains `.silver-bullet(/mode|-mode)` (line 28). Mode detection from the command string checks for the word "autonomous" (line 113).
- **Gap:** If Claude writes the mode file using a method that doesn't match the grep (e.g., `printf 'autonomous' > ~/.claude/.silver-bullet/mode` — note: no trailing newline, or using `tee`, or using Python), the session log init may not fire OR may fire but detect the wrong mode. More specifically: `printf '%s' "$cmd" | grep -qE '\.silver-bullet(/mode|-mode)'` would match `tee ~/.claude/.silver-bullet/mode` but mode detection `grep -q "autonomous"` checks the whole command string, not just the value being written — so `echo interactive > ~/.claude/.silver-bullet/mode` would NOT trigger the "autonomous" path but `echo "set autonomous mode" > ... ` would falsely trigger it because "autonomous" appears in the command.
- **Feasibility:** Easy. Change mode detection to parse the value being written rather than pattern-matching the entire command. A more robust approach: after the trigger fires, read the actual mode file to determine mode rather than parsing the command string.
- **Recommended fix:** In `session-log-init.sh` (line 113), replace `printf '%s' "$cmd" | grep -q "autonomous"` with `mode_check=$(cat "$SB_DIR/mode" 2>/dev/null || echo "interactive"); [[ "$mode_check" == "autonomous" ]] && mode="autonomous"`. This reads the ground truth from the mode file rather than parsing the command.

---

**[F-18] dev-cycle-check.sh — src_pattern Only Catches /src/ by Default**

- **Rule:** §3 — Planning must be complete before any source edit
- **Current enforcement:** `dev-cycle-check.sh` checks if `file_path` matches `src_pattern` (default: `/src/`). Files outside `/src/` skip enforcement.
- **Gap:** Many projects (including Silver Bullet itself, which is a plugin) store source code in `/hooks/`, `/skills/`, or other non-`/src/` directories. For Silver Bullet's own development, `.silver-bullet.json` sets `src_pattern: "/src/"`. This means edits to `hooks/*.sh`, `skills/**`, `templates/**` during Silver Bullet development are NOT subject to the planning gate — they don't match `/src/`. Claude can edit the enforcement hooks themselves without planning being complete (the hook self-protection would still block writes to `hooks/`, but the planning gate itself would not trigger).
- **Feasibility:** Easy. The `src_pattern` is configurable. Silver Bullet's own `.silver-bullet.json` should set `src_pattern` to match the actual source directories: `"/hooks/|/skills/|/templates/"`.
- **Recommended fix:** Update `.silver-bullet.json` `src_pattern` to `"/hooks/|/skills/|/templates/"` so that edits to Silver Bullet's own source code trigger the planning gate. Also update the config template comment to note that multi-directory projects should use `|` to join patterns.

---

**[F-19] completion-audit.sh — `gh pr merge` Not in Tier 2 Delivery Patterns**

- **Rule:** §3 — Full workflow required before merging a PR
- **Current enforcement:** `completion-audit.sh` Tier 2 detects: `gh pr create`, `deploy`, `gh release create`. `gh pr merge` is NOT in the pattern list.
- **Gap:** Claude could run `gh pr merge` to merge an already-created PR without the full workflow having been completed. This is a separate action from `gh pr create` and bypasses the Tier 2 gate entirely. A PR created in a prior session (when skills were satisfied) could be merged in a new session (when state is reset and skills are 0) without any gate firing.
- **Feasibility:** Easy. Add `gh pr merge` to the Tier 2 pattern detection in `completion-audit.sh` (line 63: add `elif printf '%s' "$cmd" | grep -qE '\bgh pr merge\b'`).
- **Recommended fix:** Add `gh pr merge` to the completion detection block. Note: on `main` branch where `finishing-a-development-branch` is already dropped, the remaining required skills still apply.

---

**[F-20] Trivial Bypass — Created by Claude, Not Just by User**

- **Rule:** §4.14 — Trivial bypass is "intended for quick fixes the developer has manually verified"
- **Current enforcement:** `dev-cycle-check.sh` blocks Edit/Write to the state directory (SB-008). However, Bash writes to `~/.claude/.silver-bullet/trivial` are blocked by the same tamper protection. BUT: the trivial file path is configurable via `.silver-bullet.json`. If a project sets a custom `trivial_file` path outside `~/.claude/.silver-bullet/`, the tamper protection logic still validates the path must stay within `~/.claude/` (lines 127–130 in dev-cycle-check.sh) — so a custom path like `~/.claude/myproject/trivial` would pass the security check and writes to it would NOT be blocked by the state tamper detection.
- **Gap:** A custom `trivial_file` path within `~/.claude/` but outside `.silver-bullet/` would not be protected by the Bash write tamper detection regex (which matches `.silver-bullet/(state|branch|trivial)` specifically). Claude could potentially write to a custom trivial path via Bash and bypass enforcement.
- **Feasibility:** Easy. Generalize the tamper detection regex to match any file ending in `/trivial` within `~/.claude/`, not just the default path.
- **Recommended fix:** Change the Bash tamper detection pattern in `dev-cycle-check.sh` (line 117) from `\.silver-bullet/(state|branch|trivial)` to `\.claude/[^/]*/(state|branch|trivial)` to cover custom paths within `~/.claude/`.

---

### Bypass Paths

The following complete bypass paths exist through the enforcement system:

**BP-01: Forbidden Skill Invocation (Section 6)**
Claude invokes `superpowers:executing-plans` via the Skill tool. No hook fires on PreToolUse for Skill events. `record-skill.sh` records it after the fact but does not block it. The violation is soft-enforcement only.

**BP-02: Review Loop Single Pass (Section 3a)**
Claude invokes `code-review`, `requesting-code-review`, `receiving-code-review` once each. `record-skill.sh` records all three. `completion-audit.sh` sees all three present and satisfied. The "two consecutive approvals" requirement is not tracked anywhere. Claude declares the review loop complete after one pass.

**BP-03: Quality Gate Stage Markers Without Verification**
Claude invokes the whitelisted write pattern: `echo "quality-gate-stage-1" >> ~/.claude/.silver-bullet/state` (4 times for all stages) without having invoked `verification-before-completion`. The tamper detection whitelist explicitly allows these writes. `completion-audit.sh` sees all four stage markers present and allows `gh release create`.

**BP-04: Plugin Cache Write via Bash**
Claude runs `cp /tmp/modified-skill.md ~/.claude/plugins/cache/superpowers/.../SKILL.md`. The `file_path` check in `dev-cycle-check.sh` is empty for Bash commands. No blocking occurs. The plugin cache is modified.

**BP-05: Work Before Mode File Exists**
Claude begins editing source files without ever writing the mode file. `compliance-status.sh` displays mode as "interactive" (default fallback) but never blocks. No hook requires the mode file to exist before work starts.

**BP-06: Session Startup Skip**
Claude does not read `docs/` at session start. No hook detects this. The Anti-Skip text in silver-bullet.md states this is a violation, but `dev-cycle-check.sh` only gates on planning skills being recorded, not on docs/ being read.

**BP-07: Mid-Session Branch Switch**
Claude switches branches mid-session via Bash (`git checkout other-branch`). The state file retains the old branch's skill records. Subsequent commits on the new branch are evaluated against the old branch's workflow state. No hook detects the branch mismatch during the session.

**BP-08: gh pr merge Without Full Workflow**
Claude merges a PR via `gh pr merge` in a new session (state reset). `completion-audit.sh` only gates `gh pr create`, `deploy`, and `gh release create`. `gh pr merge` is unchecked.

**BP-09: Scripting Language Writes to Hooks Directory**
Claude runs `python3 -c "open('/path/to/hooks/completion-audit.sh','w').write('exit 0')"`. The hook self-protection regex checks for shell write operators (`>>`, `>`, `tee`, `cp`, `mv`, `rm`, `chmod`, `sed`) but not for Python/Node/Ruby file-write APIs. The hooks directory is modified, disabling enforcement.

---

### Priority Ranking

Ranked by (Impact if bypassed) × (Likelihood of bypass) × (Ease of fix):

| Priority | Finding | Impact | Likelihood | Ease of Fix | Score |
|----------|---------|--------|------------|-------------|-------|
| 1 | F-03: Forbidden Skill Invocation — no PreToolUse/Skill blocklist | Critical | High | Easy | 9/9 |
| 2 | F-07: Plugin Cache — Bash commands not checked | High | Medium | Easy | 6/9 |
| 3 | F-01: Review Loop — single pass accepted as complete | High | High | Hard | 6/9 |
| 4 | F-05: Quality Gate Stage Markers — falsifiable via whitelist | High | Medium | Medium | 5/9 |
| 5 | F-06: SubagentStop not registered | High | Low | Easy | 4/9 |
| 6 | F-16: stop-check missing quality-gate-stage check | Medium | Medium | Easy | 4/9 |
| 7 | F-19: gh pr merge not in Tier 2 patterns | Medium | Medium | Easy | 4/9 |
| 8 | F-13: CI check not applied to gh pr create | Medium | Low | Easy | 3/9 |
| 9 | F-04: File safety rules — no hook enforcement | Medium | Low | Medium | 3/9 |
| 10 | F-09: Mid-session branch switch not detected | Medium | Low | Easy | 3/9 |
| 11 | F-11: §9 stage ordering vs. workflow skills | Low | Low | Easy | 2/9 |
| 12 | F-18: src_pattern doesn't cover SB's own source dirs | Low | Medium | Easy | 2/9 |
| 13 | F-08: Hook self-protection — scripting language bypass | Medium | Low | Medium | 2/9 |
| 14 | F-02: Session startup — no mechanical enforcement | Medium | High | Hard | 2/9 |
| 15 | F-15: Compliance-status config cache — stale after update | Low | Low | Easy | 1/9 |
| 16 | F-17: Session-log-init mode detection fragile | Low | Low | Easy | 1/9 |
| 17 | F-12: Compact timing bypass | Low | Low | Hard | 1/9 |
| 18 | F-10: Model routing — no enforcement | Low | Medium | Hard | 1/9 |
| 19 | F-20: Custom trivial path write bypass | Low | Low | Easy | 1/9 |
| 20 | F-14: Namespace stripping allows wrong-namespace skills | Low | Low | Medium | 1/9 |

---

### Cross-Check Answers

**A. Session Startup (§0):**
- "Switch to Opus 4.6" — Not enforced anywhere. Documentation only. No hook can observe model selection.
- "Read all project docs" — Not enforced. Anti-Skip text names the violation but nothing blocks if docs/ is not read.
- "/compact the context" — Not enforced mechanically. SessionStart fires on "compact" matcher but only re-injects context; it does not verify /compact was run as a prerequisite to starting work.

**B. Review Loop (§3a):**
- "Must iterate until reviewer returns ✅ Approved TWICE IN A ROW" — ZERO hook enforcement. Documentation only. This is the highest-severity purely soft-enforced rule in the system.

**C. Mode File (§4):**
- compliance-status.sh reads mode and displays it. Nothing BLOCKS work if mode is unset. Default of "interactive" is returned but no gate requires the mode file to exist.

**D. Model Routing (§5):**
- "Offer Opus before Planning begins" — Documentation only. No hook detects whether the offer was made.

**E. GSD Ownership (§6):**
- `dev-cycle-check.sh` does NOT detect `superpowers:executing-plans` or `superpowers:subagent-driven-development`. These are mentioned only in documentation. No PreToolUse/Skill hook exists to block forbidden skill names.

**F. File Safety (§7):**
- No hook enforces file safety. mv/cp/rm on project files proceeds without any gate.

**G. Plugin Boundary Bash (§8):**
- dev-cycle-check.sh blocks Edit/Write targeting plugin cache via `file_path` check. For Bash commands, `file_path` is always empty — the Bash vector for plugin cache writes is NOT blocked. This is Finding F-07.

**H. Quality Gate (§9):**
- Stage markers are writable via whitelisted echo commands without verification-before-completion having been invoked. This is Finding F-05.
- Stage ordering vs. workflow skills is not enforced. This is Finding F-11.

**I. Stop Hook / SubagentStop:**
- `stop-check.sh` is registered for `Stop` only. `SubagentStop` is NOT registered. Subagents can terminate without the stop gate firing. This is Finding F-06.

**J. core-rules.md injection:**
- `prompt-reminder.sh` resolves `script_dir` via `cd "$(dirname "${BASH_SOURCE[0]}")" && pwd`. If `BASH_SOURCE[0]` is unavailable (e.g., script sourced rather than executed), `script_dir` could be wrong. The fallback to `CLAUDE_PLUGIN_ROOT` is correct but depends on the env var being set. If both fail, `core_rules_file` does not exist and the hook silently omits the core rules — emitting only the skill status line. The failure is non-blocking and non-visible to the user. This is acceptable degradation but the silent omission means enforcement rules are not re-injected.

**K. Completion Audit Ordering:**
- `completion-audit.sh` enforces code-review → requesting-code-review → receiving-code-review ordering (lines 251–264). It does NOT enforce that quality-gate stages happen AFTER workflow skills. This is Finding F-11.

**L. Branch-Scoped State / Mid-Session Switch:**
- session-start resets state on branch change at session start. Mid-session branch switches are not detected. This is Finding F-09.

**M. Vacuous Invocation:**
- record-skill.sh records invocation, not outcome. Artifact check in completion-audit.sh (lines 266–279) partially covers this for gsd-execute-phase and gsd-verify-work. Other skills (code-review, testing-strategy, etc.) have no artifact check. The hook explicitly acknowledges this limitation.

**N. CI Status — No-Status Case:**
- `ci-status-check.sh` line 51: `[[ -z "${run_json:-}" ]] && exit 0` — if CI hasn't run yet (empty response from gh run list), the hook exits silently. This is correct behavior (no false positives on new repos), not a gap.

**O. Timeout / Stall Detection:**
- `timeout-check.sh` covers all three stall conditions from §4 via Tier 1 (10-minute wall clock) and Tier 2 (30/60/100 call-count thresholds). Interactive mode is explicitly excluded (line 25: `[[ "$mode_file_content" != "autonomous" ]] && exit 0`). The stall thresholds align with §4's definition. No significant gap found here. The session-start-time file being absent causes early exit (line 38: `[[ -z "$session_start" ]] && exit 0`) which means the timeout check is disabled for the first tool call after a fresh session-start — a minor race condition but not exploitable.

---

*Report generated: 2026-04-06*
*Files audited: hooks/hooks.json, hooks/session-start, hooks/completion-audit.sh, hooks/dev-cycle-check.sh, hooks/ci-status-check.sh, hooks/record-skill.sh, hooks/compliance-status.sh, hooks/timeout-check.sh, hooks/session-log-init.sh, hooks/stop-check.sh, hooks/prompt-reminder.sh, hooks/core-rules.md, silver-bullet.md, templates/silver-bullet.md.base, templates/silver-bullet.config.json.default, .silver-bullet.json, docs/enforcement-techniques/claude.md*
