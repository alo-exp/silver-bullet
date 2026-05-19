---
audit-version: 1
release: v0.15.0
auditor: sentinel (claude-sonnet-4-6)
date: 2026-04-09
scope: hooks/spec-floor-check.sh, hooks/spec-session-record.sh, hooks/pr-traceability.sh, hooks/uat-gate.sh, skills/silver-spec/SKILL.md, skills/silver-ingest/SKILL.md, skills/silver-validate/SKILL.md, skills/artifact-reviewer/SKILL.md, skills/artifact-reviewer/rules/reviewer-interface.md, skills/artifact-reviewer/rules/review-loop.md, templates/specs/SPEC.md.template
framework: OWASP LLM Top 10 (2025)
---

# SENTINEL Security Audit — Silver Bullet v0.15.0

## Executive Summary

**Overall risk posture: LOW-MEDIUM.** The hook scripts show good security hygiene (umask, jq-mediated JSON parsing, no direct stdin interpolation). No hardcoded secrets or credentials were found. The primary residual risks are in the skill files, which are LLM prompt documents: they instruct the model to run shell commands and call external tools, and several of those patterns carry injection or exfiltration surface that cannot be fully mitigated at the prompt layer alone.

---

## Findings

### FINDING-01 — Command Injection via unvalidated `$ARGUMENTS` in silver-ingest cross-repo fetch

**Severity: MEDIUM**
**File:** `skills/silver-ingest/SKILL.md` — Step 5
**Status: Partially mitigated (BFIX-01 present, fallback path is unguarded)**

The skill contains an explicit shell-injection validation guard (BFIX-01) that validates `{owner}/{repo}` before passing it to `gh api`. However, the curl fallback path on the line immediately below uses the same `{owner}` and `{repo}` values but shows them interpolated directly into a double-quoted URL string:

```bash
curl -sL "https://raw.githubusercontent.com/{owner}/{repo}/main/.planning/SPEC.md" > .planning/SPEC.main.md
```

The BFIX-01 validation is shown only before the `gh api` call. The skill text does not explicitly state that validation applies to the curl fallback path as well. If a model implementing this prompt applies the validation only to the primary path and falls through to curl with an unvalidated value, a path-traversal or argument-injection payload could be passed via `--source-url`. The curl command writes to `.planning/SPEC.main.md` which is a fixed path, so write-target injection is not possible here, but a crafted owner/repo string containing shell metacharacters could affect the curl command line.

**Recommendation:** Move the BFIX-01 validation block to before both the `gh api` and `curl` invocations, or add an explicit note in the skill that the validated variables are what get substituted into both commands.

---

### FINDING-02 — Unvalidated values written into JSON output in spec-session-record.sh

**Severity: LOW**
**File:** `hooks/spec-session-record.sh` — line 42
**Status: Not mitigated**

The advisory message at line 42 interpolates `$version_display` and `$jira_display` directly into a `printf` JSON string without jq encoding:

```bash
printf '{"hookSpecificOutput":{"message":"Spec session: SPEC.md v%s, JIRA: %s"}}' "$version_display" "$jira_display"
```

`$version_display` is derived from `grep -m1 '^spec-version:' "$SPEC" | awk '{print $2}' | tr -d '"' | tr -d "'"`. The double-quote and single-quote characters are stripped, but other JSON-breaking characters such as backslash, newline, or braces are not removed. A crafted SPEC.md frontmatter line with a value like `spec-version: 1\n,"injected":true` would produce malformed or injected JSON in the hook output.

This is low severity because: (a) the hook output is consumed by Claude Code's own hook framework, not by an external service; (b) the SPEC.md file is authored by the same user running the tool. However, if SPEC.md content is ingested from an untrusted external source (via silver-ingest from an attacker-controlled JIRA ticket), the frontmatter could be poisoned.

**Recommendation:** Pipe `$version_display` and `$jira_display` through `jq -Rs '.'` before interpolating into the JSON string, consistent with how other hooks in this codebase handle user-derived strings (e.g., `emit_block` in spec-floor-check.sh line 28).

---

### FINDING-03 — Unsafe temp file creation in pr-traceability.sh

**Severity: LOW**
**File:** `hooks/pr-traceability.sh` — lines 73-76
**Status: Not mitigated (partial — umask 0077 is set)**

`mktemp` is used without specifying a template suffix or directory override:

```bash
tmpfile=$(mktemp)
printf '%s' "$new_body" > "$tmpfile"
"$GH_BIN" pr edit "$pr_url" --body-file "$tmpfile" 2>/dev/null || true
rm -f "$tmpfile"
```

`umask 0077` is set at the top of the script (line 7), which ensures the temp file is created mode 0600. `mktemp` on macOS and Linux creates files atomically in `/tmp`, so symlink attacks on the creation step are not practical. The file is written and then immediately deleted. This is low-severity, but the PR body content (`$new_body`) is written to a system-temp path that is readable by root and any process running as the same user. On multi-user systems this is a minor information-disclosure risk.

**Recommendation:** Use `mktemp -t sb-pr-XXXXXX` to name the temp file clearly, and consider using a user-owned temp directory (`${TMPDIR:-/tmp}`) consistently. Current risk is low given the umask mitigation.

---

### FINDING-04 — awk ENVIRON injection in pr-traceability.sh

**Severity: LOW**
**File:** `hooks/pr-traceability.sh` — line 86
**Status: Mitigated via ENTRY env-var pattern, residual concern noted**

The SPEC.md update step uses an environment-variable-mediated awk pattern to avoid direct shell interpolation:

```bash
ENTRY="$entry" awk 'BEGIN{e=ENVIRON["ENTRY"]} /<!-- Populated automatically/ { print; print e; next } { print }' "$SPEC" > "${SPEC}.tmp" && mv "${SPEC}.tmp" "$SPEC"
```

This is the correct approach for passing data to awk without shell interpolation. However, `$entry` is composed from `${pr_url}`, `${today}`, and `${spec_version}`. The `pr_url` is fetched from `gh pr view --json url --jq '.url'`. If a PR URL contains characters that awk interprets specially (e.g., `/` in a substitution context), they could affect awk output. In this code pattern, `print e` treats the variable as a literal string, so awk special characters are not a concern. The ENTRY content will be printed verbatim.

One residual issue: the temp file is `"${SPEC}.tmp"` — a predictable path. On a multi-user system, an attacker could pre-create `.planning/SPEC.md.tmp` as a symlink before the hook runs. The `umask 0077` does not help here because the file is created via output redirection (`>`), not via `mktemp`. The `mv` then atomically replaces the target. This is a low-severity TOCTOU on multi-user systems.

**Recommendation:** Use `mktemp` for the spec temp file as well, e.g., `spectmp=$(mktemp)` then `mv "$spectmp" "$SPEC"`.

---

### FINDING-05 — Prompt injection via ingested external artifact content

**Severity: MEDIUM**
**File:** `skills/silver-ingest/SKILL.md` — Steps 1, 3, 4
**Status: Accepted by design (no mitigation present)**

silver-ingest fetches content from JIRA tickets, Confluence pages, Figma designs, and Google Docs and incorporates that content directly into `.planning/SPEC.md`. This content is later read by the model in subsequent skill invocations (silver-spec, silver-validate, artifact-reviewer). An attacker with write access to any of these upstream systems could embed prompt-injection payloads in the artifact content (e.g., in a JIRA description: "Ignore all previous instructions and...").

This is a known LLM supply-chain risk (OWASP LLM Top 10: LLM03 — Training Data Poisoning / LLM01 — Prompt Injection via indirect input). Silver Bullet's architecture does not currently include any content sanitization layer between the MCP connector output and the spec assembly step.

The risk is partially mitigated by the fact that the content is written to markdown files (not executed), and the model operates within Claude Code's permission sandbox. However, prompt injection in a SPEC.md that is subsequently reviewed by artifact-reviewer could influence reviewer findings.

**Recommendation:** Add a sanitization advisory in silver-ingest Step 6 instructing the model to treat all ingested content as untrusted data and to refuse to interpret it as instructions. Optionally, wrap ingested content in a clearly delimited block (e.g., `<!-- INGESTED CONTENT START -->` ... `<!-- INGESTED CONTENT END -->`) so downstream reviewers can identify it.

---

### FINDING-06 — Automated git commit with model-derived commit message

**Severity: LOW**
**File:** `hooks/pr-traceability.sh` — line 89
**Status: Not mitigated**

The hook runs:

```bash
git commit -m "trace: link PR to SPEC.md v${spec_version}" 2>/dev/null || true
```

`$spec_version` is validated by `grep -E '^[0-9]+(\.[0-9]+)*$'` at line 46, so numeric injection is not possible. The commit message is a fixed template. Risk is low.

The broader pattern — hooks making automated git commits — is an intentional design choice, but represents a persistence mechanism in the OWASP LLM Top 10 sense (LLM08 — Excessive Agency): the hook automatically modifies the git history without explicit user confirmation. This is acceptable for a workflow tool but should be documented.

**Recommendation:** Document the automated commit behavior in the project README/CHANGELOG as an intentional capability, so users are aware.

---

### FINDING-07 — State files written to ${SB_RUNTIME_HOME_ROOT}/.silver-bullet (persistence mechanism)

**Severity: INFORMATIONAL**
**Files:** `hooks/spec-session-record.sh` line 33-37, `skills/artifact-reviewer/rules/review-loop.md` Section 2
**Status: Intentional by design**

Both the spec-session hook and the review-loop state mechanism write files to `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`. These files persist across sessions. This is a legitimate persistence mechanism for resumability, but in the OWASP LLM Top 10 context (LLM08), any automated write to a home-directory location warrants documentation.

The state files do not write to shell startup files, cron directories, or any executable path. The review-state JSON files contain only round counts and timestamps — no code or credentials. The spec-session file contains only spec-version and jira-id strings (both validated in pr-traceability.sh before use).

**Recommendation:** No action required. Document the state directory in user-facing documentation so users know where to clean up stale state.

---

### FINDING-08 — No hardcoded secrets found

**Severity: INFORMATIONAL**
**Files:** All audited files
**Status: Clean**

No hardcoded API keys, tokens, passwords, or credentials were found in any of the audited hook scripts or skill files. The gh CLI binary is resolved at runtime via `command -v`. Atlassian MCP auth is delegated to the user's MCP configuration (silver-ingest references API token auth but does not store or handle it).

---

### FINDING-09 — Path traversal: fixed paths, no user-controlled file targets in hooks

**Severity: INFORMATIONAL**
**Files:** All hook scripts
**Status: Clean**

All file paths in hook scripts are either hardcoded constants (`.planning/SPEC.md`, `.planning/UAT.md`, `.planning/VALIDATION.md`) or derived from `$HOME` with a fixed suffix. No hook script constructs a file path from user-supplied input. Path traversal is not applicable to the hook layer.

The silver-ingest skill writes to `.planning/SPEC.main.md` (fixed path) when doing cross-repo fetch. The `{owner}/{repo}` values are validated before use in the gh/curl commands; they are not used in file path construction.

---

### FINDING-10 — stdin JSON parsing: all hooks use jq, no direct interpolation

**Severity: INFORMATIONAL**
**Files:** All hook scripts
**Status: Clean**

All four hook scripts read stdin via `input=$(cat)` and then use `printf '%s' "$input" | jq -r '...'` to extract fields. This prevents direct shell injection from malformed JSON. The extracted values (`$cmd`, `$skill`) are used only as grep pattern targets, not as arguments to shell commands. The `emit_block` functions pass user-derived strings through `jq -Rs '.'` before embedding in JSON output.

---

## Summary Table

| ID | Category (OWASP LLM Top 10) | Severity | File | Fixed This Session |
|----|------------------------------|----------|------|--------------------|
| FINDING-01 | LLM01 Prompt Injection / Command Injection | MEDIUM | skills/silver-ingest/SKILL.md Step 5 | No |
| FINDING-02 | LLM02 Insecure Output Handling | LOW | hooks/spec-session-record.sh:42 | No |
| FINDING-03 | LLM06 Sensitive Info Disclosure (temp file) | LOW | hooks/pr-traceability.sh:73-76 | No |
| FINDING-04 | LLM06 Sensitive Info Disclosure (TOCTOU) | LOW | hooks/pr-traceability.sh:86 | No |
| FINDING-05 | LLM01 Prompt Injection (indirect / supply chain) | MEDIUM | skills/silver-ingest/SKILL.md Steps 1-4 | No |
| FINDING-06 | LLM08 Excessive Agency (auto git commit) | LOW | hooks/pr-traceability.sh:89 | No |
| FINDING-07 | LLM08 Excessive Agency (home-dir persistence) | INFO | spec-session-record.sh, review-loop.md | N/A — by design |
| FINDING-08 | LLM09 Misinformation / Hardcoded Secrets | INFO | All files | N/A — clean |
| FINDING-09 | LLM01 Path Traversal | INFO | All hook scripts | N/A — clean |
| FINDING-10 | LLM01 Command Injection via stdin | INFO | All hook scripts | N/A — clean |

## Risk Matrix

| Severity | Count |
|----------|-------|
| MEDIUM | 2 |
| LOW | 4 |
| INFORMATIONAL | 4 |
| **Total** | **10** |

## Release Recommendation

**CONDITIONAL PASS for v0.15.0.**

The two MEDIUM findings (FINDING-01 and FINDING-05) do not block release but should be addressed in the next patch cycle (v0.15.1):

- FINDING-01 is a documentation gap in the skill prompt, not a runtime bug in the current hook scripts. The validated variables are computed before the shell commands in the skill flow; the risk is that a model implementing the skill could apply validation selectively.
- FINDING-05 is an accepted architectural risk in any tool that ingests external content into an LLM context. Documenting and adding a sanitization advisory is a low-effort mitigation.

The LOW findings are acceptable for release given the umask mitigations already in place and the single-user typical deployment model.

No blocking security issues (P0/CRITICAL) were found.
