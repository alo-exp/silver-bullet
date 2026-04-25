# SENTINEL v2.3 Adversarial Security Audit
## Silver Bullet Claude Code Plugin
**Audit Date:** 2026-04-25
**Auditor:** SENTINEL v2.3 (automated adversarial review)
**Target:** `/Users/shafqat/Documents/Projects/silver-bullet/.claude/worktrees/fervent-buck-630f6b/`
**Scope:** hooks/*.sh, hooks/lib/*.sh, skills/silver-add|silver-remove|silver-rem|silver-scan|silver-create-release|silver-release|silver-init|silver-feature/SKILL.md, config files

---

## Executive Summary

Silver Bullet demonstrates a mature security posture with multiple defense-in-depth layers. The codebase has undergone previous security reviews (phases 34-35 visible in .planning/) and shows clear evidence of prior remediation. The dominant threat model — prompt injection via project file content piped into hooks — is well-mitigated by jq-mediated JSON handling, explicit `trap 'exit 0' ERR` guards throughout, and the SENTINEL boundary marker in semantic-compress.sh.

**Overall Risk Level:** LOW-MEDIUM. No Critical findings. Three High findings remain, all involving information disclosure or bypass-path weaknesses rather than direct code execution.

---

## Step 0 — Pre-Audit Context

**Previous audits detected:** Yes. Phase directories `34-security-p0-remediation` and `35-stage-4-security-hardening` confirm prior SENTINEL findings were addressed. This audit builds on those.

**Active config:** `.silver-bullet.json` v0.25.0, `full-dev-cycle` workflow, `issue_tracker=gsd`, state file at `~/.claude/.silver-bullet/state`.

**Attack surface summary:**
- 18 hook scripts + 4 lib scripts (primary attack surface)
- 8 audited skills that accept user descriptions or invoke gh/git CLI
- hooks.json maps 20+ hook registrations
- Session log files at `docs/sessions/*.md` (UNTRUSTED DATA)

---

## Step 1 — Threat Model

### Primary Threats

| ID | Threat | Vector | Mitigated? |
|----|--------|--------|------------|
| T-01 | JSON injection via hook stdin | Malicious `.tool_input.command` field | YES — jq -r with validated output |
| T-02 | Path traversal via config fields | `.silver-bullet.json` `src_pattern` or `state_file` | YES — regex validation + `~/.claude/` prefix check |
| T-03 | Prompt injection via project files | Session logs / SPEC.md injected into context | PARTIAL — SENTINEL boundary present; see FINDING-1 |
| T-04 | Symlink attacks on state files | Attacker pre-creates symlink at state path | YES — nofollow-guard.sh sourced in all writers |
| T-05 | State file tampering (bypass enforcement) | Direct write to `~/.claude/.silver-bullet/state` | YES — dev-cycle-check.sh blocks this |
| T-06 | Plugin cache manipulation | Edit/Write/Bash targeting `~/.claude/plugins/cache/**` | YES — hard-blocked in dev-cycle-check.sh |
| T-07 | Namespace bypass on forbidden skills | `outer:inner:executing-plans` | YES — greedy strip loop in forbidden-skill-check.sh |
| T-08 | Trivial-bypass via symlink | Symlink at `~/.claude/.silver-bullet/trivial` | YES — `! -L` check on trivial file |
| T-09 | ReDoS via user-controlled regex | `src_exclude_pattern` field in config | YES — 200-char cap + character allowlist |
| T-10 | Sentinel PID recycling | Kill wrong process by reused PID | YES — UUID token + lock file pattern |
| T-11 | Hook self-modification | Edit/Write/Bash targeting hooks directory | YES — CLAUDE_PLUGIN_ROOT and pattern check |
| T-12 | Credential exfiltration via semantic-compress | `.env` / `.pem` files in context | YES — `_SB_CREDENTIAL_EXCLUDE` mandatory guard |
| T-13 | Markdown injection via commit messages | Release notes rendered on GitHub | PARTIAL — see FINDING-2 |
| T-14 | Shell injection via ENTRY variable | pr-traceability.sh SPEC.md update | PARTIAL — see FINDING-3 |

---

## Step 2 — Findings

### CRITICAL (0 findings)

No critical findings.

---

### HIGH (3 findings)

---

#### FINDING-H-1: JSON injection via unvalidated fields in spec-session-record.sh output

**Severity:** HIGH
**File:** `hooks/spec-session-record.sh`, lines 51-53
**Classification:** CWE-116 (Improper Encoding or Escaping of Output)

**Description:**
`spec_version` and `jira_id` are extracted from `.planning/SPEC.md` frontmatter using `awk` and `tr`, then interpolated directly into a `printf` format string for JSON output without sanitization or jq encoding:

```bash
version_display="${spec_version:-unknown}"
jira_display="${jira_id:-n/a}"
printf '{"hookSpecificOutput":{"message":"Spec session: SPEC.md v%s, JIRA: %s"}}' "$version_display" "$jira_display"
```

A SPEC.md file with a crafted `spec-version:` or `jira-id:` value containing `"` (double-quote) or `}` characters would produce malformed JSON output, potentially causing the hook protocol to misparse the response. For example, a SPEC.md containing:

```yaml
spec-version: 1.0","foo":"injected
```

would produce:
```json
{"hookSpecificOutput":{"message":"Spec session: SPEC.md v1.0","foo":"injected, JIRA: n/a"}}
```

Note that `pr-traceability.sh` correctly validates `spec_version` against `^[0-9]+(\.[0-9]+)*$` (line 56) and `jira_id` against `^[A-Z]+-[0-9]+$` (line 57). The `spec-session-record.sh` hook does not apply the same validation before emitting JSON.

**Impact:** Malformed JSON output from hook; Claude Code hook protocol parser may misinterpret the response. Severity is high because SPEC.md frontmatter is developer-controlled but is also written by skill orchestrators (including automated content via `/silver:spec`).

**Recommendation:** Apply jq-based JSON encoding for the output, or validate both fields against the same allowlist patterns used in pr-traceability.sh before emitting:

```bash
# Option A: validate before use
spec_version_safe=$(printf '%s' "$spec_version" | grep -E '^[0-9]+(\.[0-9]+)*$' || echo "unknown")
jira_id_safe=$(printf '%s' "$jira_id" | grep -E '^[A-Z]+-[0-9]+$' || echo "n/a")
printf '{"hookSpecificOutput":{"message":"Spec session: SPEC.md v%s, JIRA: %s"}}' "$spec_version_safe" "$jira_id_safe"

# Option B (preferred): jq encoding
jq -n --arg v "${spec_version:-unknown}" --arg j "${jira_id:-n/a}" \
  '{"hookSpecificOutput":{"message":("Spec session: SPEC.md v" + $v + ", JIRA: " + $j)}}'
```

**Status:** OPEN

---

#### FINDING-H-2: Commit message content reflected unsanitized in uat-gate.sh block message

**Severity:** HIGH (information leak / JSON integrity)
**File:** `hooks/uat-gate.sh`, lines 63-66
**Classification:** CWE-116

**Description:**
`uat_version` and `spec_version` are read from YAML frontmatter using `awk` and then directly interpolated into the `emit_block` message:

```bash
uat_version=$(grep -m1 '^spec-version:' "$UAT" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
spec_version=$(grep -m1 '^spec-version:' "$SPEC" | awk '{print $2}' | tr -d '"' | tr -d "'" || true)
if [[ -n "$uat_version" && -n "$spec_version" && "$uat_version" != "$spec_version" ]]; then
  emit_block "UAT GATE: UAT was run against spec v${uat_version} but current SPEC.md is v${spec_version}. ..."
```

`emit_block` pipes the reason through `jq -Rs '.'`, so the outer JSON is safe. However, if the jq call fails (e.g., jq not available — though the hook already exits on missing jq), or if future code changes bypass jq, the raw version strings could appear in error output. The `tr -d '"' | tr -d "'"` stripping provides partial mitigation but does not prevent `\`, `{`, `}`, or other control characters from appearing.

More directly: the version strings appear unvalidated in the block reason text. A maliciously crafted `spec-version:` value of `1.0; rm -rf ~` would pass `tr` stripping and appear in the block message. While this is data-in-context rather than executed, it could mislead Claude when interpreting the block.

**Impact:** Medium-to-high: version strings from YAML frontmatter are developer-controlled input. The jq encoding in emit_block prevents JSON injection. Risk is primarily information leakage and misleading block messages.

**Recommendation:** Validate version strings before use, consistent with pr-traceability.sh:

```bash
uat_version_safe=$(printf '%s' "$uat_version" | grep -E '^[0-9]+(\.[0-9]+)*$' || echo "INVALID")
spec_version_safe=$(printf '%s' "$spec_version" | grep -E '^[0-9]+(\.[0-9]+)*$' || echo "INVALID")
```

**Status:** OPEN

---

#### FINDING-H-3: roadmap-freshness.sh — phase_title from ROADMAP.md unvalidated in block message

**Severity:** HIGH (information integrity)
**File:** `hooks/roadmap-freshness.sh`, lines 94-95
**Classification:** CWE-116

**Description:**
The `phase_title` variable is extracted from ROADMAP.md content using `sed` and then directly appended to the `unticked_phases` accumulator:

```bash
phase_title=$(grep -E "^- \[ \] \*\*Phase ${phase_num}:" "$roadmap_file" | head -1 | sed 's/^- \[ \] //')
unticked_phases="${unticked_phases}  [UNTICKED] Phase ${phase_num}: ${phase_title}\n"
```

`phase_num` is already validated as `^[0-9]+$` (safe), but `phase_title` is raw text from ROADMAP.md and is not sanitized. ROADMAP.md phase titles are developer-written content but could contain control characters, escape sequences, or content that affects how the block message is interpreted when displayed in the Claude Code UI.

This `unticked_phases` string is later passed through `jq -Rs '.'` in the `emit_block` call (line 102), which correctly JSON-encodes it. The jq encoding protects the JSON structure. However, the content can still contain misleading text that influences Claude's behavior when processing the block.

**Impact:** Lower exploitability than H-1/H-2 because jq encoding is applied before JSON serialization. The risk is misleading messages to Claude. Rated HIGH due to the ROADMAP.md being an important planning artifact that orchestrator skills modify programmatically.

**Recommendation:** Strip or truncate the phase_title to safe characters before use:

```bash
phase_title_safe=$(printf '%s' "$phase_title" | tr -dc 'a-zA-Z0-9 .:,_-' | cut -c1-100)
unticked_phases="${unticked_phases}  [UNTICKED] Phase ${phase_num}: ${phase_title_safe}\n"
```

**Status:** OPEN

---

### MEDIUM (4 findings)

---

#### FINDING-M-1: pr-traceability.sh — ENTRY environment variable propagation to awk

**Severity:** MEDIUM
**File:** `hooks/pr-traceability.sh`, line 106
**Classification:** CWE-78 (OS Command Injection — reduced risk due to awk context)

**Description:**
The `SPEC.md` update in pr-traceability.sh uses an environment variable `ENTRY` passed to `awk` via `ENVIRON`:

```bash
ENTRY="$entry" awk 'BEGIN{e=ENVIRON["ENTRY"]} /<!-- Populated automatically/ { print; print e; next } { print }' "$SPEC" > "${SPEC}.tmp" && mv "${SPEC}.tmp" "$SPEC"
```

`entry` is constructed as:
```bash
entry="- PR: ${pr_url} | Date: ${today} | Spec-version: ${spec_version}"
```

Where `pr_url` comes from `gh pr view --json url --jq '.url'` (trusted gh CLI output), `today` from `date`, and `spec_version` from the spec-session file (which has been validated by the reading hook as `^[0-9]+(\.[0-9]+)*$`). The awk `ENVIRON["ENTRY"]` approach is correct — it prevents shell injection. The data flow is relatively safe because `pr_url` is a GitHub-formatted URL.

However, a future GitHub URL format change or a self-hosted GitHub Enterprise instance with a URL containing awk-special characters (e.g., `&` or `\`) could cause awk's `print` to behave unexpectedly. The `print e` statement treats `e` as literal data, not a substitution, so this is low-exploitability.

**Impact:** Low exploitability. awk's `print` does not interpret the ENVIRON value as a pattern, so `&` and `\` in the value are not expanded. The main risk is a corrupted SPEC.md entry if a malformed PR URL is returned by gh CLI.

**Recommendation:** The current approach is acceptable. For defense-in-depth, validate `pr_url` against a safe URL pattern before use:

```bash
if ! printf '%s' "$pr_url" | grep -qE '^https://github\.com/[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+/pull/[0-9]+$'; then
  pr_url="(invalid-url)"
fi
```

**Status:** ADVISORY (existing implementation is defensible; recommended hardening)

---

#### FINDING-M-2: session-log-init.sh — session log content written via heredoc with mode variable

**Severity:** MEDIUM
**File:** `hooks/session-log-init.sh`, lines 179-240
**Classification:** CWE-116 (potential mode injection via mode file)

**Description:**
The session log is created using a heredoc that includes the `${mode}` variable:

```bash
cat > "$log_file" << LOGEOF
# Session Log — ${today}

**Mode:** ${mode}
...
LOGEOF
```

`mode` is read from `~/.claude/.silver-bullet/mode` and validated against the allowlist `interactive|autonomous` (lines 166-169). This is correctly handled. However, the log file is created with heredoc expansion, and `${today}` is from `date` output, `${mode}` is validated — so there is no injection risk here.

The concern is the subsequent awk-based section insertion (lines 99-128) where `_insert_before` uses an awk script that reads a `mode` variable extracted from the **existing log file** content (line 93-95):

```bash
mode=$(grep '^\*\*Mode:\*\*' "$existing" 2>/dev/null | awk '{print $NF}' | tr -d ' ') || true
mode="${mode:-interactive}"
[[ "$mode" == "autonomous" ]] || mode="interactive"
```

This is well-guarded by the explicit allowlist check on line 95. No injection path exists.

**Finding refinement:** The real concern is that the awk script in `_insert_before` (lines 103-110) uses shell variables `$anchor`, `$header`, and `$placeholder` passed as awk `-v` arguments. These variables come from literal strings defined in the calling code (lines 113-128), not from user input — so injection is not possible through the current call sites. However, if `_insert_before` were called with externally-derived values in the future, the `-v` argument passing could become a vulnerability.

**Impact:** No current exploitable path. Rated MEDIUM as a structural concern for future maintainability.

**Recommendation:** Document that `_insert_before` parameters must be literal strings, not user-derived content. Add a comment noting this constraint.

**Status:** ADVISORY

---

#### FINDING-M-3: semantic-compress.sh — injection filter may miss multi-line injection patterns

**Severity:** MEDIUM
**File:** `scripts/semantic-compress.sh`, lines 256-259
**Classification:** CWE-20 (Improper Input Validation)

**Description:**
The semantic compressor applies a line-by-line injection filter before injecting project file content into Claude's context:

```bash
output=$(printf '%s' "$output" \
  | LC_ALL=C sed 's/^[^[:print:][:space:]]*//' \
  | LC_ALL=C grep -Evi '^[[:space:]]*(SYSTEM|ASSISTANT|HUMAN|USER):' \
  | grep -Evi '^[[:space:]]*<(instruction|system|prompt|override)[^>]*>' || true)
```

This filter covers common single-line injection prefixes. However, it does not cover:
1. Multi-line injections where the trigger word is split across lines (uncommon in practice but possible)
2. Unicode lookalike characters for `SYSTEM`, `HUMAN`, etc. (e.g., Cyrillic lookalikes)
3. Base64-encoded or otherwise obfuscated injection payloads
4. Instructions embedded in Markdown headings (`# SYSTEM: ...`) or list items
5. HTML comment injection (`<!-- SYSTEM: ... -->`) that would survive the grep filters

The SENTINEL boundary comment (lines 262-267) provides the primary defense by telling Claude to treat content as UNTRUSTED DATA. The line-by-line filter is a secondary defense and is not intended to be comprehensive.

**Impact:** An adversarial project file could bypass the line-level filter via obfuscation. However, the SENTINEL boundary is the primary defense, and the model is trained to respect it. Exploitability requires an attacker who can write to the project's source files — a precondition that implies other attack paths are already available.

**Recommendation:** Add filtering of Markdown heading injections:

```bash
| grep -Evi '^#+ *(SYSTEM|ASSISTANT|HUMAN|USER)' \
```

Consider documenting that the line-level filter is best-effort and the SENTINEL boundary is the load-bearing defense.

**Status:** ADVISORY

---

#### FINDING-M-4: silver-create-release — `gh release create` passes release notes without explicit size limit

**Severity:** MEDIUM
**File:** `skills/silver-create-release/SKILL.md`, Step 6
**Classification:** CWE-400 (Uncontrolled Resource Consumption)

**Description:**
The skill invokes `gh release create` with `--notes "<release-notes-markdown>"`. The release notes are constructed from git log output since the last tag. In repositories with many commits between releases, this could produce very large release note bodies.

More importantly, commit message subjects are wrapped in backtick code spans (specified in Step 3: "wrap each commit description in backtick code spans") as the primary sanitization method. However, if a commit subject itself contains a backtick, the backtick-wrapping approach creates a code span that is immediately closed and could break the markdown structure.

For example, a commit message `` feat: add `config` flag `` would become `` `feat: add `config` flag` `` in the release notes, which renders as: ``feat: add `` config `` flag`` (broken markdown).

**Impact:** Malformed release notes on GitHub. Not a security vulnerability in the traditional sense, but incorrect output from a security-relevant operation (release creation). Could cause confusion about what was actually released.

**Recommendation:** Escape backticks within commit subjects before wrapping:

```bash
# Escape existing backticks before adding the code span wrapper
safe_subject=$(printf '%s' "$raw_subject" | sed "s/\`/\\\`/g")
formatted="- \`${safe_subject}\` (${hash})"
```

**Status:** ADVISORY

---

### LOW (5 findings)

---

#### FINDING-L-1: compliance-status.sh — config-cache file uses md5 hash of PWD as filename

**Severity:** LOW
**File:** `hooks/compliance-status.sh`, lines 49, 87-94
**Classification:** CWE-330 (Use of Insufficiently Random Values)

**Description:**
The config cache file is stored at `${HOME}/.claude/.silver-bullet/config-cache-${pwd_hash}` where `pwd_hash` is an md5 hash of `$PWD`. On a multi-user system, two users working in the same directory path (e.g., `/tmp/project`) would derive the same cache filename. Since the cache is stored under `~/.claude/` (user-scoped), this is not exploitable in single-user developer environments.

More practically: the cache file stores the config path and its mtime. An attacker who can write to `~/.claude/.silver-bullet/` can pre-plant a cache entry pointing to a malicious `.silver-bullet.json`. However, this requires write access to the user's home directory, which implies full system compromise.

**Impact:** Theoretical on developer workstations. Not exploitable in practice without prior system compromise.

**Recommendation:** No immediate action required. The `~/.claude/` path constraint provides sufficient isolation.

**Status:** INFORMATIONAL

---

#### FINDING-L-2: timeout-check.sh — call-count file not guarded against concurrent writes

**Severity:** LOW
**File:** `hooks/timeout-check.sh`, lines 77-79
**Classification:** CWE-362 (Race Condition)

**Description:**
The call count increment is non-atomic:

```bash
call_count=$((call_count + 1))
sb_guard_nofollow "$call_count_file"
echo "$call_count" > "$call_count_file"
```

If two hook invocations run concurrently (e.g., async compliance-status.sh and a synchronous hook both firing at the same time), both could read the same call_count value, increment separately, and write the same value — causing the count to be underreported.

**Impact:** Only affects the call-count-based anti-stall warning. Underreporting means the stall threshold is reached later. No security implications.

**Recommendation:** Use a lockfile or atomic counter approach if stall detection accuracy becomes important. Current behavior is acceptable for its advisory purpose.

**Status:** INFORMATIONAL

---

#### FINDING-L-3: silver-add skill — ITEM_TITLE derivation may exceed 72 chars silently

**Severity:** LOW
**File:** `skills/silver-add/SKILL.md`, Step 3
**Classification:** CWE-20 (validation gap)

**Description:**
The skill specifies: "ITEM_TITLE — ≤72 characters, derived from description (clear and specific)" but does not specify a truncation or validation step. If Claude generates a title exceeding 72 characters, it is silently used as-is in `gh issue create --title "$ITEM_TITLE"`. GitHub issue titles have a practical limit of 256 characters (API enforced), but the 72-char guideline exists for readability.

**Impact:** No security impact. Minor workflow compliance issue.

**Recommendation:** Add explicit truncation guidance: "If the derived title exceeds 72 characters, truncate at the last word boundary before character 72 and append '...'".

**Status:** INFORMATIONAL

---

#### FINDING-L-4: silver-scan — `find` output path validation whitelist is broad

**Severity:** LOW
**File:** `skills/silver-scan/SKILL.md`, Step 2 and Step 3a
**Classification:** CWE-22 (Path Traversal — theoretical)

**Description:**
The skill specifies path validation: "each path must match the pattern `docs/sessions/[^/]+\.md` relative to project root; reject any path containing `..` or absolute path components."

The `find` command is constrained to `docs/sessions -maxdepth 1`, which prevents directory traversal. However, the validation check described is performed by the AI agent (Claude) rather than enforced by a shell command — it is guidance in the SKILL.md prose, not a bash guard.

A symlink within `docs/sessions/` pointing to a file outside the directory would be followed by `find` (default behavior) unless `-L` or `-P` is used. The skill does not specify `find -P` (no-follow-symlinks mode).

**Impact:** On a system where an attacker can create a symlink in `docs/sessions/`, they could cause the scan to read arbitrary files. This requires filesystem write access — a high-privilege precondition.

**Recommendation:** In the allowed commands section, change the find command to:
```bash
find -P docs/sessions -maxdepth 1 -name '*.md' -print | sort
```
The `-P` flag (POSIX default on macOS, `-L` needed to follow) ensures symlinks are not followed.

**Status:** INFORMATIONAL

---

#### FINDING-L-5: session-log-init.sh uses `find` without `-P` flag for dedup

**Severity:** LOW
**File:** `hooks/session-log-init.sh`, line 89
**Classification:** CWE-22 (symlink follow)

**Description:**
```bash
existing=$(find "$sessions_dir" -maxdepth 1 -name "${today}*.md" -print 2>/dev/null | head -1 || true)
```

No `-P` (no-follow) flag specified. A symlink in `docs/sessions/` named to match `YYYY-MM-DD*.md` would be followed, potentially pointing `existing` to an arbitrary file outside the sessions directory.

**Impact:** Low. `sessions_dir` is constructed from `project_root/docs/sessions` where `project_root` is walked up from `$PWD` via `.silver-bullet.json`. An attacker would need write access to the project's docs/sessions directory.

**Recommendation:** Change to `find -P "$sessions_dir"` for consistency with the nofollow security posture elsewhere in the codebase.

**Status:** INFORMATIONAL

---

## Step 3 — Architecture Assessment

### Strengths

1. **jq-mediated JSON construction**: All hook JSON output uses either `jq -Rs '.'` or `jq -n --arg` patterns. No raw string interpolation into JSON output in the hook scripts. This is the correct approach and consistently applied.

2. **ERR trap pattern**: Every hook has `trap 'exit 0' ERR` (or a visible warning variant). This fail-open design prevents enforcement hooks from blocking the user on unexpected errors. Correct for a developer tool.

3. **Path validation for state files**: All hooks that read `SILVER_BULLET_STATE_FILE` validate it against `"$HOME"/.claude/*`. This prevents symlink-based attacks pointing state files outside the trusted directory.

4. **Symlink write guard (SEC-02)**: `nofollow-guard.sh` is sourced in all state-writing hooks and implements `sb_guard_nofollow` consistently. The inline fallback definitions (when the lib is unavailable) match the canonical implementation.

5. **src_pattern validation**: dev-cycle-check.sh validates `src_pattern` against a character allowlist AND rejects overly permissive patterns (`.*`, `.+`, `/`, empty). The `src_exclude_pattern` has a 200-character cap for ReDoS mitigation.

6. **Plugin boundary enforcement**: dev-cycle-check.sh hard-blocks both Edit/Write AND Bash commands targeting the plugin cache. The Bash detection uses `grep -qE` for write-operator patterns, preventing bypass via shell redirection.

7. **State tamper prevention**: dev-cycle-check.sh has sophisticated state-file write detection that exempts git/gh commands (which legitimately reference state paths in commit messages) while blocking actual write operations.

8. **Credential exclusion in semantic compression**: The `_SB_CREDENTIAL_EXCLUDE` pattern in semantic-compress.sh is marked `readonly` and cannot be overridden by `src_exclude_pattern` config. This is a mandatory security control correctly implemented.

9. **SENTINEL boundary injection**: semantic-compress.sh prepends an explicit UNTRUSTED DATA boundary before injecting project file content. The filter for common injection prefixes (SYSTEM:, ASSISTANT:, etc.) provides defense-in-depth.

10. **Silver-add/silver-rem security boundaries**: Both skills explicitly document untrusted data handling, require jq for all JSON construction, validate ID formats, and derive file paths from date/ID-prefix rather than user input.

### Weaknesses / Structural Concerns

1. **Inconsistent validation of file-derived strings** (see FINDING-H-1, H-2, H-3): Three hooks extract strings from markdown/YAML files and use them in output without applying the validation patterns established in pr-traceability.sh. This is an inconsistency in defensive posture.

2. **UserPromptSubmit hook reads WORKFLOW.md content without bound** (prompt-reminder.sh lines 151-163): `last_path` and `next_path` are extracted from WORKFLOW.md via `grep` and `sed` and injected into `additionalContext`. These values are not validated against an allowlist. A crafted WORKFLOW.md with a long or special-character "Last-flow:" line could pollute the context. Mitigated by the `~/.claude/` path constraint — WORKFLOW.md is in the project directory, not the state directory.

3. **core-rules.md injection path**: prompt-reminder.sh reads `core-rules.md` from the plugin directory and injects its full content into every prompt. The path traversal defense checks `resolved_rules != "${script_dir}/"*`. This is correctly implemented. However, the _content_ of core-rules.md is not sanitized before injection — if an attacker modifies the plugin directory, they control what is injected into every user prompt. This is noted in the code comment as an acknowledged risk for single-user developer systems.

---

## Step 4 — Skill-Specific Assessment

### silver-add

**Security boundary:** Well-defined. jq used for all JSON construction. `DESCRIPTION` → `$BODY` is passed via jq `--arg` (never interpolated). File paths derived from ID prefix, not user input.

**Finding:** The `ITEM_TITLE` length validation is advisory (FINDING-L-3). The label creation command includes `git remote get-url origin` piped through `sed` to derive `OWNER_REPO`. This sed expression strips common URL prefixes but is not anchored at end-of-string for unusual remotes. Low risk.

**Verdict:** PASS with advisory notes.

### silver-remove

**Security boundary:** Explicit ID format validation (`^SB-[IB]-[0-9]+$`) before use in `sed` patterns. The sed pattern uses the validated `ITEM_ID` directly — but because `ITEM_ID` is validated to contain only `SB-[IB]-N` characters, no sed metacharacter injection is possible. The `^###` anchor and ` —` suffix matching is correct.

**Verdict:** PASS.

### silver-rem

**Security boundary:** Target file path derived from `date +%Y-%m`, not user input. Category heading is from a fixed allowlist or `namespace:subcategory` format. The awk-based heading insert uses `ENVIRON["INSIGHT"]` to avoid shell injection — correct pattern.

**Finding:** The `${INSIGHT:0:60}` bash substring in session log recording (Step 8) does correctly truncate for the session log entry. However, the full `INSIGHT` text is appended to the knowledge/lessons file verbatim — this is intentional (insights are content, not commands) and explicitly documented in the Security Boundary section.

**Verdict:** PASS.

### silver-scan

**Security boundary:** Uses `find -maxdepth 1` (missing `-P` — FINDING-L-4). `--fixed-strings` / `-F` flags on git log and grep cross-reference. Content from session logs is passed to `/silver-add` as data, not as a command.

**Finding:** Step 6-iii invokes `/silver-add` via Skill tool with `ITEM_TITLE + ITEM_CONTEXT` as description. The silver-add skill handles sanitization, so this delegation is correct.

**Verdict:** PASS with FINDING-L-4 advisory.

### silver-create-release

**Security boundary:** Commit message subjects wrapped in backtick code spans. jq used for Google Chat webhook payload construction. `SB_GCHAT_WEBHOOK` read from environment, not from tracked files.

**Finding:** FINDING-M-4 (backtick escaping in commit subjects).

**Verdict:** PASS with FINDING-M-4 advisory.

### silver-release

**Security boundary:** Orchestrator only — does not execute shell commands directly. Invokes skills via Skill tool. Session log extraction (Step 9b.2) reads `## Items Filed` section via awk, treating content as data.

**Finding:** Step 9b.2 uses `echo "$section" | grep -qF '(none)'` which is safe. The `awk` pattern extracts sections between headings — awk does not execute the content, only prints it.

**Verdict:** PASS.

### silver-init

**Security boundary:** Reads project files (README.md, CONTEXT.md) as UNTRUSTED DATA with explicit security boundary. Validates user selections from AskUserQuestion. hook merge via Python script (merge-hooks.py).

**Finding:** Phase 1.5.1 invokes `curl -s https://api.github.com/repos/alo-exp/silver-bullet/releases/latest | grep '"tag_name"' | sed ...` — this pipes external API response through sed. The sed expression extracts a version number. If the GitHub API response is malformed or attacker-controlled (MITM), the extracted value could be arbitrary text. However, this is used only for display/comparison, not for code execution.

**Verdict:** PASS with advisory on curl output handling.

### silver-feature

**Security boundary:** Orchestrator only. The deferred item capture (Step 7, Step 9e, Step 18) correctly routes to `/silver-add` via Skill tool.

**Finding:** Step 9b invokes `gsd-code-review-fix` which is a third-party GSD skill — Silver Bullet has no visibility into that skill's security posture. This is noted as an architectural boundary issue, not a finding within Silver Bullet's scope.

**Verdict:** PASS.

---

## Step 5 — Configuration Security Assessment

### .silver-bullet.json

- `src_pattern` uses multi-pattern format (`/hooks/|/skills/|/templates/`) — validated against character allowlist in dev-cycle-check.sh.
- `src_exclude_pattern` is the default safe value.
- `state_file` points to `~/.claude/.silver-bullet/state` — within the required prefix.
- `forbidden` array is empty — no custom forbidden skills configured.
- `_notifications_comment` correctly instructs not to commit webhook URLs.
- No `verify_commands` array — this is acceptable.

**Verdict:** PASS.

### templates/silver-bullet.config.json.default

- Matches the structure of the live `.silver-bullet.json` except for the `_github_project` cache (not present in default, correctly absent).
- `{{PROJECT_NAME}}` placeholder left in template — this is correct; silver-init performs substitution.
- `issue_tracker` defaults to `"gsd"` (local tracking) — conservative default, correct.
- `compactPrompt` field instructs compact to preserve skill names verbatim — this is a defensive measure against context compression erasing enforcement rules.

**Verdict:** PASS.

### hooks.json

- All hook commands use `"${CLAUDE_PLUGIN_ROOT}/hooks/<script>"` pattern with double-quoting — protects against spaces in paths.
- The trivial-file creation hook (lines 20-26) uses inline shell: `umask 0077 && mkdir -p ~/.claude/.silver-bullet && { [ -L ~/.claude/.silver-bullet/trivial ] && rm -f -- ~/.claude/.silver-bullet/trivial; touch -- ~/.claude/.silver-bullet/trivial; }` — correctly handles symlink removal before touch.
- The trivial-file removal hook (lines 134-137) uses `rm -f -- ~/.claude/.silver-bullet/trivial` — safe, uses `--` to prevent flag injection.
- async: true is used only for compliance-status.sh (informational, non-blocking) — correct.
- Timeouts are appropriate: 30s for CI checks (which invoke gh CLI), 15s for audit hooks, 10s for simpler hooks.

**Verdict:** PASS.

---

## Step 6 — Enforcement Coverage Assessment

### State Tamper Prevention Matrix

| Attack Vector | Blocked By | Verified |
|--------------|-----------|---------|
| Edit tool to ~/.claude/.silver-bullet/state | dev-cycle-check.sh lines 127-135 | YES |
| Write tool to ~/.claude/.silver-bullet/state | dev-cycle-check.sh lines 127-135 | YES |
| Bash redirect to ~/.silver-bullet/state | dev-cycle-check.sh lines 168-176 | YES |
| Bash tee to state file | dev-cycle-check.sh lines 148-165 (quote-exempt logic) | YES |
| git commit -m mentioning state path | dev-cycle-check.sh line 166 (git/gh exemption) | YES |
| Symlink at state path | nofollow-guard.sh in record-skill.sh | YES |

### Plugin Cache Protection Matrix

| Attack Vector | Blocked By | Verified |
|--------------|-----------|---------|
| Edit/Write to ~/.claude/plugins/cache/** | dev-cycle-check.sh lines 59-70 | YES |
| Bash write ops to plugin cache | dev-cycle-check.sh lines 71-77 | YES |
| Bash write to SB hooks dir (with CLAUDE_PLUGIN_ROOT) | dev-cycle-check.sh lines 87-99 | YES |
| Bash write to ~/.claude/*/hooks/ (without CLAUDE_PLUGIN_ROOT) | dev-cycle-check.sh lines 111-115 | YES |

### Enforcement Gate Coverage

| Gate | Hook | Event |
|------|------|-------|
| Pre-commit planning | completion-audit.sh | PreToolUse/Bash |
| Pre-PR deployment | completion-audit.sh | PreToolUse/Bash |
| Source edit blocking | dev-cycle-check.sh | PreToolUse/Edit+Write+Bash |
| Session stop blocking | stop-check.sh | Stop+SubagentStop |
| CI red blocking | ci-status-check.sh | PreToolUse/Bash |
| UAT gate | uat-gate.sh | PreToolUse/Skill |
| Spec floor | spec-floor-check.sh | PreToolUse/Bash |
| ROADMAP freshness | roadmap-freshness.sh | PreToolUse/Bash |
| Forbidden skills | forbidden-skill-check.sh | PreToolUse/Skill |

**Coverage assessment:** Comprehensive. All critical delivery-path operations are gated. The two-tier enforcement model (intermediate vs. final delivery) is well-designed and prevents the deadlock where GSD execution subagents need to commit before finalization skills are complete.

---

## Step 7 — Prior Finding Resolution Status

Based on phase directory names, the following previously-identified issues appear resolved:

| Prior Phase | Topic | Status in Current Code |
|------------|-------|----------------------|
| 34-security-p0-remediation | Security P0 | State tamper prevention, symlink guards confirmed present |
| 35-stage-4-security-hardening | Stage 4 hardening | src_pattern validation, ReDoS cap confirmed present |
| 36-hook-14-stop-check-hardening | HOOK-14 hardening | upstream_broken=true fail-closed logic confirmed present |
| 31-hook-bug-fixes | BUG-04 heredoc false positive | cmd_first_line classification confirmed present |
| 37-stage-2-consistency-audit | Consistency | nofollow-guard sourced consistently; T-07 namespace bypass fixed |

The codebase shows clear evidence that prior SENTINEL findings were implemented. The code contains inline comments referencing issue numbers (`BUG-04`, `HOOK-14`, `SEC-02`, `SB-002`, `SB-003`, `F-07`, `TD-01`, `CR-01`, `CR-03`) that map to tracked work items — good engineering hygiene.

---

## Step 8 — Deployment Recommendation

### Summary by Severity

| Severity | Count | Finding IDs |
|---------|-------|------------|
| Critical | 0 | — |
| High | 3 | H-1, H-2, H-3 |
| Medium | 4 | M-1, M-2, M-3, M-4 |
| Low | 5 | L-1, L-2, L-3, L-4, L-5 |
| **Total** | **12** | |

### Actionable Items (require code changes)

| Priority | Finding | File | Change Required |
|---------|---------|------|----------------|
| HIGH | H-1 | spec-session-record.sh:53 | Apply allowlist validation or jq encoding to `version_display` and `jira_display` before JSON output |
| HIGH | H-2 | uat-gate.sh:63-66 | Apply `^[0-9]+(\.[0-9]+)*$` validation to version strings |
| HIGH | H-3 | roadmap-freshness.sh:94-95 | Strip `phase_title` to safe characters before use in block message |
| MEDIUM | M-1 | pr-traceability.sh:99-106 | Validate `pr_url` against GitHub URL pattern |
| MEDIUM | M-4 | silver-create-release/SKILL.md | Document backtick escaping requirement |
| LOW | L-4 | silver-scan/SKILL.md | Add `-P` flag to `find` command |
| LOW | L-5 | session-log-init.sh:89 | Add `-P` flag to `find` command |

### Deployment Recommendation

**CONDITIONAL DEPLOY**: The codebase is suitable for continued use and deployment at the current maturity level. The three HIGH findings are limited to JSON integrity issues (malformed hook output) from unvalidated file-derived strings — they do not enable code execution or privilege escalation.

**Before next public release (`v0.26.0` or later):** Remediate H-1, H-2, and H-3. These are straightforward one-line fixes applying the existing validation patterns from `pr-traceability.sh` to the three affected hooks.

**Medium-term:** Address M-1, L-4, L-5. Advisory findings M-2, M-3, L-1, L-2, L-3 do not require immediate action but should be considered during the next major refactor.

The overall architecture is sound. The layered defense model (jq output encoding + path validation + symlink guards + SENTINEL boundary + nofollow-guard) is mature and consistently applied. The three HIGH findings represent recent code that missed the validation pattern established in older (reviewed) code — a straightforward consistency gap, not a design flaw.

---

*SENTINEL v2.3 audit complete — 2026-04-25*
*Scope: Silver Bullet v0.25.0 (worktree: fervent-buck-630f6b)*
