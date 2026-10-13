---
name: topgun
description: >
  This skill should be used when the user asks to "find a skill",
  "find the best skill for", "search skill registries", "install a skill safely",
  or mentions /topgun. Orchestrates FindSkills, CompareSkills, SecureSkills,
  and InstallSkills sub-agents to discover, evaluate, audit, and install
  the best available skill for any job.
argument-hint: <job-description>
allowed-tools: [Read, Write, Bash, Grep, Glob, Task, WebFetch]
---

# TopGun Orchestrator

You are the TopGun orchestrator. You sequence four sub-agents to find, compare, secure, and install the best available skill for the user's job.

## Step 0: Initialize

**0.1 Resolve TOPGUN_BIN.** The skill must work whether or not a host plugin-root env var is set in the shell session. Resolve a stable path to `topgun-tools.cjs` once at the top, then use `$TOPGUN_BIN` everywhere below:

```bash
TOPGUN_TOOLS_REL="bin/topgun-tools.cjs"
if [ -n "$CODEX_PLUGIN_ROOT" ] && [ -f "$CODEX_PLUGIN_ROOT/$TOPGUN_TOOLS_REL" ]; then
  TOPGUN_BIN="$CODEX_PLUGIN_ROOT/$TOPGUN_TOOLS_REL"
else
  # Fallback: read installed_plugins.json to find any installed copy of topgun.
  TOPGUN_BIN=$(node -e '
    const fs=require("fs"), path=require("path"), home=process.env.HOME;
    const registries=[
      path.join(home,".codex/plugins/installed_plugins.json"),
    ];
    const keys=["topgun@alo-labs-codex","topgun@alo-labs-codex-local","topgun@alo-labs"];
    for (const reg of registries) {
      if (!fs.existsSync(reg)) continue;
      const r=JSON.parse(fs.readFileSync(reg,"utf8"));
      for (const k of keys) {
        const inst=r.plugins?.[k]?.[0];
        if (!inst?.installPath) continue;
        const p=path.join(inst.installPath,"bin/topgun-tools.cjs");
        if (fs.existsSync(p)) { console.log(p); process.exit(0); }
      }
    }
    console.error("no usable topgun install"); process.exit(1);
  ')
  if [ -z "$TOPGUN_BIN" ]; then
    echo "❌ TopGun is not installed. Run: codex plugin marketplace add https://github.com/alo-labs/codex-plugins.git"
    exit 1
  fi
  export CODEX_PLUGIN_ROOT="$(dirname "$(dirname "$TOPGUN_BIN")")"
fi
```

**0.2 Init storage:**
```bash
node "$TOPGUN_BIN" init
```

**0.3 Read current state:**
```bash
node "$TOPGUN_BIN" state-read
```

**0.4 Implicit reset (auto-clear stale state).** If `current_stage === "complete"` or `current_stage === "failed"` AND a NEW user prompt is starting (i.e. the user just typed a fresh `/topgun ...` command), all per-run fields from the prior pipeline are stale and would otherwise leak into Step 2 resume logic. Auto-clear them — no `--reset` required:

```bash
PRIOR_STAGE=$(node "$TOPGUN_BIN" state-read | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{console.log(JSON.parse(d).current_stage||'')}catch{console.log('')}})")
if [ "$PRIOR_STAGE" = "complete" ] || [ "$PRIOR_STAGE" = "failed" ]; then
  for f in current_stage last_completed_stage run_id found_skills_path comparison_path audit_path \
           registries task_description started_at \
           winner_name winner_registry content_sha skill_dangerous_tools skill_content_path \
           sentinel_pass_1_findings sentinel_pass_1_hash sentinel_pass_2_findings sentinel_pass_2_hash \
           sentinel_pass_3_findings sentinel_pass_3_hash sentinel_pass_4_findings sentinel_pass_4_hash \
           sentinel_total_passes sentinel_clean_passes secured_path approval approved_at \
           install_method install_path install_verified plugins_json_status test_invoke_status \
           audit_status findings_tracker enveloped_content_path skill_name skill_source \
           audit_rejection_reason audit_abort_reason; do
    node "$TOPGUN_BIN" state-write "$f" null >/dev/null
  done
  echo "(auto-cleared stale state from prior $PRIOR_STAGE pipeline)"
fi
```

This makes the prior-run-completed UX seamless: users don't have to remember `--reset` after every successful or failed pipeline.

## Step 1: Parse Input

Extract the job description from the user's message. This is everything after `/topgun `.

Check for the following flags and extract them before parsing the task description:

**`--reset` flag:** If present, clear state and start fresh BEFORE any other logic:
```bash
node "$TOPGUN_BIN" state-write current_stage null
node "$TOPGUN_BIN" state-write last_completed_stage null
node "$TOPGUN_BIN" state-write run_id null
node "$TOPGUN_BIN" state-write found_skills_path null
node "$TOPGUN_BIN" state-write comparison_path null
node "$TOPGUN_BIN" state-write audit_path null
```
Output: "State cleared. Starting fresh pipeline." Then proceed normally with the remaining flags and task description.

**`--offline` flag:** If present, set `offline=true`. All sub-agent dispatches must include "(offline mode — use only cached data, do not fetch from registries)" in their prompts. File existence checks during the offline flow are described in Step 1.5.

**`--force-audit` flag:** If present, set `force_audit=true`. Pass `--force` to the SecureSkills sub-agent prompt so it calls cache-lookup with `--force` and re-runs the audit even if a cached result exists.

**`--auto-approve` flag:** If present, set `auto_approve=true`. The interactive approval gate in Step 6 will be skipped and installation will proceed automatically. Only use in trusted automated pipelines (e.g., `codex exec`).

**`--registries` flag:** If present, extract the comma-separated registry list. Examples:
- `/topgun find a deployment skill` → task = "find a deployment skill", registries = null (all)
- `/topgun --registries skills.sh,github find a deployment skill` → task = "find a deployment skill", registries = ["skills.sh", "github"]

Write the parsed input to state:
```bash
node "$TOPGUN_BIN" state-write task_description "<extracted task>"
node "$TOPGUN_BIN" state-write run_id "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
node "$TOPGUN_BIN" state-write started_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

If `--registries` was provided:
```bash
node "$TOPGUN_BIN" state-write registries "<comma-separated list>"
```

## Step 1.5: Auth Token Check

**Skip this step entirely if `--offline` flag was set** (no network needed).

Check for registry auth tokens in the OS keychain:

```bash
node "$TOPGUN_BIN" keychain-get github_token
node "$TOPGUN_BIN" keychain-get smithery_token
```

For each token where the result is `{ "found": false }`:
- Prompt the user: "GitHub/Smithery API token not found. Some registries require authentication for higher rate limits (60 → 5000 req/hr). Enter your {service} token (or press Enter to skip):"
- If the user provides a token (non-empty input), store it:
  ```bash
  node "$TOPGUN_BIN" keychain-set {service} topgun {token}
  ```
- If the user presses Enter with no value, continue without the token — searches will still work but may hit rate limits.
- Tokens are stored in the OS keychain ONLY — never written to files, state.json, or any log.

## Step 1.6: Offline Cache Check

**Only execute this step if `--offline` flag was set.**

Check whether cached output files exist for this query before proceeding. Compute the query hash:
```bash
QUERY_HASH=$(node "$TOPGUN_BIN" sha256 "<task_description>" | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).hash))")
```

Check for cached FindSkills output:
```bash
node -e "process.exit(require('fs').existsSync(require('path').join(process.env.HOME, '.topgun', 'found-skills-' + process.argv[1] + '.json')) ? 0 : 1)" "$QUERY_HASH"
```

If the found-skills cache file does NOT exist:
- Output: "No cached results available for this query. Run without --offline to search registries."
- STOP. Do NOT proceed.

If the found-skills cache file exists, read `found_skills_path` from state. If state has no `found_skills_path`, set it to `~/.topgun/found-skills-{hash}.json`.

For SecureSkills, the cached audit is checked at Step 5 when `offline=true`: if no audit cache exists for the winning skill's SHA, output "No cached audit available. Cannot proceed offline." and STOP.

## Step 2: Resume Check

Read the state from Step 0. Check `last_completed_stage`.

For each stage, verify the expected output file ACTUALLY EXISTS on disk before trusting the state flag. If the state says a stage is complete but the output file is missing, log a warning and re-run from that stage.

**Stage verification rules:**

- If `null` or missing → start from FindSkills (Step 3)

- If `find`:
  ```bash
  node -e "process.exit(require('fs').existsSync(process.argv[1]) ? 0 : 1)" "<found_skills_path from state>"
  ```
  If file missing: output "WARNING: Found-skills output missing, re-running FindSkills." → start from Step 3.
  If file exists: skip to CompareSkills (Step 4).

- If `compare`:
  First verify `found_skills_path` exists (same check as `find` above). If missing: warn "WARNING: Found-skills output missing, re-running FindSkills." → start from Step 3.
  Then verify `comparison_path` exists:
  ```bash
  node -e "process.exit(require('fs').existsSync(process.argv[1]) ? 0 : 1)" "<comparison_path from state>"
  ```
  If comparison file missing: output "WARNING: Comparison output missing, re-running CompareSkills." → start from Step 4 (FindSkills output still valid).
  If both exist: skip to SecureSkills (Step 5).

- If `secure`:
  Verify `audit_path` exists:
  ```bash
  node -e "process.exit(require('fs').existsSync(process.argv[1]) ? 0 : 1)" "<audit_path from state>"
  ```
  If file missing: output "WARNING: Audit output missing, re-running SecureSkills." → start from Step 5.
  If file exists: go to approval gate (Step 6).

- If `approve`:
  Verify `audit_path` exists (same check as `secure` above).
  If file missing: output "WARNING: Audit output missing, cannot resume past approval. Re-running SecureSkills." → start from Step 5.
  If file exists: skip to InstallSkills (Step 7).

- If `install` or `complete` → inform user pipeline already completed for this run. Suggest `--reset` to start fresh.

**Threat model note (T-06-04):** Before trusting `last_completed_stage`, validate its value against the known enum: `find`, `compare`, `secure`, `approve`, `install`, `complete`. If the value is not in this set (e.g. due to manual state.json editing), output "WARNING: Invalid stage value in state.json. Restarting from scratch." and start from Step 3.

## Step 3: FindSkills

Update state:
```bash
node "$TOPGUN_BIN" state-write current_stage find
```

Dispatch the finder agent. If `offline=true`, include "(offline mode — use only cached data, do not fetch from registries)" in the prompt:

Task(
  subagent_type="topgun-finder",
  description="Search skill registries for skills matching the job description.",
  prompt="Find skills matching this job: <task_description>. Write results to ~/.topgun/found-skills-{hash}.json where {hash} is the SHA-256 of the query string. Return ## FIND COMPLETE when done."
)

Parse the sub-agent's output:
- If output contains `## FIND COMPLETE` → success, continue
- If output contains `## STAGE FAILED` → extract the line beginning with `Reason:` after the marker
  - Display to user: "FindSkills failed: {reason}"
  - Ask user: "Retry this stage or abort pipeline? (retry/abort)"
  - If retry: re-dispatch the same Task() once. If it fails again, treat as final abort.
  - If abort: write state `current_stage failed` and stop
- If output contains neither marker → treat as failure with reason "Sub-agent returned unexpected output"

Update state, including the output file path:
```bash
node "$TOPGUN_BIN" state-write last_completed_stage find
node "$TOPGUN_BIN" state-write found_skills_path "$HOME/.topgun/found-skills-{hash}.json"
```

## Step 4: CompareSkills

Update state:
```bash
node "$TOPGUN_BIN" state-write current_stage compare
```

Dispatch the comparator agent. If `offline=true`, include "(offline mode — use only cached data, do not fetch from registries)" in the prompt:

Task(
  subagent_type="topgun-comparator",
  description="Evaluate and rank skill candidates from FindSkills output.",
  prompt="Read the found-skills output and score candidates. Write results to ~/.topgun/comparison-{hash}.json. Return ## COMPARE COMPLETE when done."
)

Parse the sub-agent's output:
- If output contains `## COMPARE COMPLETE` → success, continue
- If output contains `## STAGE FAILED` → extract the line beginning with `Reason:` after the marker
  - Display to user: "CompareSkills failed: {reason}"
  - Ask user: "Retry this stage or abort pipeline? (retry/abort)"
  - If retry: re-dispatch the same Task() once. If it fails again, treat as final abort.
  - If abort: write state `current_stage failed` and stop
- If output contains neither marker → treat as failure with reason "Sub-agent returned unexpected output"

Update state, including the output file path:
```bash
node "$TOPGUN_BIN" state-write last_completed_stage compare
node "$TOPGUN_BIN" state-write comparison_path "$HOME/.topgun/comparison-{hash}.json"
```

## Step 5: SecureSkills

Update state:
```bash
node "$TOPGUN_BIN" state-write current_stage secure
```

**Offline check (T-06-05):** If `offline=true`, verify a cached audit exists for the winning skill's SHA before dispatching:
```bash
node "$TOPGUN_BIN" cache-lookup "<winning_skill_sha>"
```
If result is `{ "hit": false }`: output "No cached audit available. Cannot proceed offline." and STOP.

Dispatch the securer agent. If `force_audit=true`, include "--force" in the prompt so it bypasses the audit cache:

Task(
  subagent_type="topgun-securer",
  description="Security-audit the winning skill using Sentinel.",
  prompt="Audit the winning skill from comparison results. Write audit output to ~/.topgun/audit-{hash}.json. Return ## SECURE COMPLETE when done."
)

Parse the sub-agent's output:
- If output contains `## SECURE COMPLETE` → success, continue
- If output contains `## STAGE FAILED` → extract the line beginning with `Reason:` after the marker
  - Display to user: "SecureSkills failed: {reason}"
  - Ask user: "Retry this stage or abort pipeline? (retry/abort)"
  - If retry: re-dispatch the same Task() once. If it fails again, treat as final abort.
  - If abort: write state `current_stage failed` and stop
- If output contains `## SECURE REJECTED` → display "SecureSkills rejected the skill: {reason from state audit_rejection_reason}" and stop (no retry offered — rejection is final)
- If output contains `## SECURE ABORTED` → read `audit_abort_reason` from state, display "SecureSkills aborted: {reason}" (SHA-256 integrity failure between passes) and stop (no retry — content instability detected)
- If output contains `## SECURE ESCALATED` → the securer agent is handling user escalation for a Sentinel-resistant finding; wait for the agent to complete and re-parse its final output for one of the above markers
- If output contains neither expected marker → treat as failure with reason "Sub-agent returned unexpected output"

Update state, including the output file path:
```bash
node "$TOPGUN_BIN" state-write last_completed_stage secure
node "$TOPGUN_BIN" state-write audit_path "$HOME/.topgun/audit-{hash}.json"
```

## Step 6: User Approval Gate

Update state:
```bash
node "$TOPGUN_BIN" state-write current_stage approve
```

Read the audit results file written by SecureSkills:
```bash
cat ~/.topgun/audit-{hash}.json
```

Read the comparison results file written by CompareSkills:
```bash
cat ~/.topgun/comparison-{hash}.json
```

Extract from the audit JSON: `skill_name`, `source_registry`, scores (`capability`, `security`, `popularity`, `recency`), Sentinel summary (`pass_count`, `finding_count`), `allowed_tools` list, and `secured_path`.

Present the audit manifest to the user:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 TOPGUN ► APPROVAL REQUIRED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Skill:         {name} ({source_registry})
 Score:         capability={X} / security={X} / popularity={X} / recency={X}
 Sentinel:      {pass_count} passes, {finding_count} findings resolved
 Allowed-tools: {comma-separated list}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

**Auto-approve check:** Before prompting the user, check if `auto_approve=true` in state:

- If `auto_approve=true`:
  - Output: "⚠️  Auto-approve bypasses the interactive approval gate. Only use in trusted automated pipelines."
  - Output: "Auto-approve mode active — skipping interactive approval gate. Audit manifest:"
  - Print the full audit manifest (as formatted above).
  - Update state:
    ```bash
    node "$TOPGUN_BIN" state-write last_completed_stage approve
    node "$TOPGUN_BIN" state-write approval "approved"
    node "$TOPGUN_BIN" state-write approved_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    ```
  - Proceed directly to Step 7 (InstallSkills). Do NOT prompt the user.

- If `auto_approve` is not set: continue with the interactive prompt below.

**Permission warning check (REQ-18):** BEFORE asking for approval, inspect the `allowed_tools` list. If it contains `Bash`, `Computer`, or a wildcard (`*`), display this warning:

```
WARNING: This skill requests elevated permissions:
  - {list each dangerous tool found}
  These tools allow the skill to execute arbitrary commands on your system.
  Review the allowed-tools list carefully before approving.
```

Then ask the user: "Do you approve installation of this skill? (yes/no)"

**If user says "yes" or "y" (case-insensitive):**

Update state:
```bash
node "$TOPGUN_BIN" state-write last_completed_stage approve
node "$TOPGUN_BIN" state-write approval "approved"
node "$TOPGUN_BIN" state-write approved_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
```

Proceed to Step 7 (InstallSkills).

**If user says "no" or "n" (case-insensitive):**

Update state:
```bash
node "$TOPGUN_BIN" state-write last_completed_stage approve
node "$TOPGUN_BIN" state-write approval "rejected"
node "$TOPGUN_BIN" state-write current_stage complete
```

Output: "Installation rejected by user. Pipeline complete — no skill installed."

STOP. Do NOT proceed to Step 7.

## Step 7: InstallSkills

Update state:
```bash
node "$TOPGUN_BIN" state-write current_stage install
```

Dispatch the installer agent:

Task(
  subagent_type="topgun-installer",
  description="Install the secured skill.",
  prompt="Install the secured skill. Verify installation. Update ~/.topgun/installed.json. Return ## INSTALL COMPLETE when done."
)

Parse the sub-agent's output:
- If output contains `## INSTALL COMPLETE` → success, continue
- If output contains `## STAGE FAILED` → extract the line beginning with `Reason:` after the marker
  - Display to user: "InstallSkills failed: {reason}"
  - Ask user: "Retry this stage or abort pipeline? (retry/abort)"
  - If retry: re-dispatch the same Task() once. If it fails again, treat as final abort.
  - If abort: write state `current_stage failed` and stop
- If output contains neither marker → treat as failure with reason "Sub-agent returned unexpected output"

Update state:
```bash
node "$TOPGUN_BIN" state-write last_completed_stage install
node "$TOPGUN_BIN" state-write current_stage complete
```

## Step 8: Audit Trail Header

This step only executes if approval was "approved" (Step 6) and InstallSkills returned `## INSTALL COMPLETE`. If `approval = "rejected"`, do NOT display this header — the pipeline already stopped in Step 6.

Read current state to get install data:

```bash
node "$TOPGUN_BIN" state-read
```

Read the exact audit and comparison files for scores:

```bash
STATE_JSON=$(node "$TOPGUN_BIN" state-read)
AUDIT_PATH=$(printf '%s' "$STATE_JSON" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const s=JSON.parse(d);console.log(s.audit_path||"")})')
COMPARISON_PATH=$(printf '%s' "$STATE_JSON" | node -e 'let d="";process.stdin.on("data",c=>d+=c);process.stdin.on("end",()=>{const s=JSON.parse(d);console.log(s.comparison_path||"")})')
[ -n "$AUDIT_PATH" ] && cat "$AUDIT_PATH"
[ -n "$COMPARISON_PATH" ] && cat "$COMPARISON_PATH"
```

Extract: `skill_name`, `source_registry`, `install_method` (from state), `capability` / `security` / `popularity` / `recency` scores (from comparison JSON), `pass_count` and `finding_count` (from audit JSON).

Determine installed location label:
- If `install_method = "plugin"` → display `plugin`
- If `install_method = "local-copy"` → display `local ~/.codex/skills/`

Display the header with actual values:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 TOPGUN ► SKILL ACQUIRED
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Skill:    {skill_name} ({source_registry})
 Score:    capability={X} / security={X} / popularity={X} / recency={X}
 Secured:  2 clean Sentinel passes (bundled SENTINEL v2.3.0)
 Installed: {plugin | local ~/.codex/skills/}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Immediately after the header, display the disclaimer:

> 2 clean Sentinel passes = no automated findings. Not a guarantee of zero vulnerabilities.

Write the lock entry for pipeline reproducibility (REQ-23):

```bash
QUERY_HASH=$(node "$TOPGUN_BIN" sha256 "<task_description>" | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).hash))")

node "$TOPGUN_BIN" lock-write '{
  "query_hash": "'"$QUERY_HASH"'",
  "skill_name": "{skill_name}",
  "source_registry": "{source_registry}",
  "content_sha": "{content_sha from audit JSON}",
  "audit_hash": "{audit_hash from audit JSON}",
  "installed_at": "{approved_at from state}",
  "install_method": "{install_method from state}"
}'
```

This writes `~/.topgun/topgun-lock.json` so the exact skill version and audit result can be reproduced.
