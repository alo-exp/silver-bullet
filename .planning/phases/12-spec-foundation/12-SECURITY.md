---
audit-date: 2026-04-09
asvs-level: 1
phases: 12-spec-foundation, 13-ingestion-multi-repo, 14-validation-traceability-uat
milestone: v0.14.0
auditor: gsd-secure-phase
---

# Security Audit — Phases 12, 13, 14 (v0.14.0 Milestone)

## Summary

| Metric | Value |
|--------|-------|
| Threats registered | 15 |
| Threats closed | 14 |
| Threats open | 1 |
| Unregistered flags | 1 |
| ASVS Level | 1 |
| Overall status | OPEN_THREATS |

---

## Threat Verification

### Phase 12 — Spec Foundation (Plans 01, 02, 03)

| Threat ID | Category | Disposition | Verification Result | Evidence |
|-----------|----------|-------------|---------------------|----------|
| T-12-01 | Tampering | mitigate | CLOSED | Hook self-protection via dev-cycle-check.sh is an existing control; spec-floor-check.sh is a new file (not modifying existing hooks). The plan cites an inherited mitigation — no gap in new code. |
| T-12-02 | Spoofing | accept | CLOSED | Accepted — spec is a draft artifact; no security-critical enforcement on content quality is required at ASVS L1. |
| T-12-03 | Denial of Service | mitigate | CLOSED | `trap 'exit 0' ERR` present at hooks/spec-floor-check.sh:3; no network calls in hook; script completes in bash-only operations. |
| T-12-04 | Elevation of Privilege | mitigate | CLOSED | `umask 0077` present at hooks/spec-floor-check.sh:11; no privileged operations in hook. |
| T-12-05 | Information Disclosure | accept | CLOSED | Accepted — WebFetch is read-only and URLs are user-provided voluntarily. |
| T-12-06 | Spoofing | mitigate | CLOSED | Skills invoked by hardcoded names (`product-management:write-spec`, `design:user-research`, `design:design-critique`) in skills/silver-spec/SKILL.md Steps 2, 4, 6. No user-controllable skill name path. |
| T-12-07 | Tampering | accept | CLOSED | Accepted — SPEC.md is a draft artifact reviewed before use; no security-critical content. |
| T-12-08 | Tampering | mitigate | CLOSED | Task 3 in 12-03-PLAN.md provides exact JSON block with jq validation instructions. hooks.json confirmed to contain spec-floor-check.sh entry (hooks/hooks.json:81). |
| T-12-09 | Repudiation | accept | CLOSED | Accepted — router shows routing decision to user before skill invocation. |

### Phase 13 — Ingestion & Multi-Repo (Plans 01, 02)

| Threat ID | Category | Disposition | Verification Result | Evidence |
|-----------|----------|-------------|---------------------|----------|
| T-13-01 | Spoofing | accept | CLOSED | Accepted — gh CLI manages its own OAuth/token auth; SB does not handle credentials. |
| T-13-02 | Tampering | mitigate | CLOSED | READ-ONLY header present in skills/silver-ingest/SKILL.md Step 5 (line: `<!-- READ-ONLY: fetched from {source-url} on {date}. Do not edit. Refresh by re-running /silver:ingest --source-url {source-url} -->`). Version validation present in templates/silver-bullet.md.base (line 81: `SPEC VERSION MISMATCH` block). |
| T-13-03 | Information Disclosure | accept | CLOSED | Accepted — SB skill does not echo credentials; MCP connectors handle auth lifecycle independently. |
| T-13-04 | Denial of Service | mitigate | CLOSED | Each connector failure produces `[ARTIFACT MISSING]` block and continues — confirmed in skills/silver-ingest/SKILL.md Step 0, Step 1, Step 3, Step 4, and the Failure Handling Summary table at end of file. |
| T-13-05 | Elevation of Privilege | accept | CLOSED | Accepted — $ARGUMENTS parsed by AI, not passed to eval/shell expansion; gh CLI commands use explicit parameter placement. |
| T-13-06 | Denial of Service | mitigate | CLOSED | templates/silver-bullet.md.base §0 version check is documented as best-effort with graceful degradation on network failure (line 68-89 region; MISMATCH block + silent skip pattern). |
| T-13-07 | Tampering | mitigate | CLOSED | READ-ONLY header documented in silver-ingest/SKILL.md Step 5; version validation in templates/silver-bullet.md.base §0 detects drift on next session start (line 68-89). |

### Phase 14 — Validation, Traceability & UAT Gate (Plans 01, 02, 03)

| Threat ID | Category | Disposition | Verification Result | Evidence |
|-----------|----------|-------------|---------------------|----------|
| T-14-01 | Tampering | accept | CLOSED | Accepted — VALIDATION.md is informational and regenerated on each validate run. |
| T-14-02 | Denial of Service | mitigate | CLOSED | skills/silver-validate/SKILL.md Step 0 checks file existence before parsing; missing SPEC.md produces single FINDING [BLOCK] VAL-000 and exits. No hang path. |
| T-14-03 | Tampering | mitigate | **OPEN** | `umask 0077` is present in hooks/spec-session-record.sh:9. However, the plan states "path validated to stay within ~/.claude/" — no path validation is implemented. The spec-session path is hardcoded (`${HOME}/.claude/.silver-bullet/spec-session`) which prevents traversal in practice, but the declared mitigation (explicit path validation) is not present in code. Gap is minor at ASVS L1; hardcoded path provides equivalent protection. |
| T-14-04 | Information Disclosure | accept | CLOSED | Accepted — spec metadata (version, JIRA ID) is intentionally public in PR description. |
| T-14-05 | Tampering | mitigate | CLOSED | hooks/pr-traceability.sh reads existing PR body first (line 57: `existing_body=$(...)`), then appends traceability block. Uses `--body-file` not `--body` (line 79). Never overwrites. |
| T-14-06 | Tampering | accept | CLOSED | Accepted — UAT is a process gate; falsifying results is self-defeating. |
| T-14-07 | Spoofing | mitigate | CLOSED | hooks/uat-gate.sh extracts skill name via jq from trusted hook input JSON (line 30: `skill=$(printf '%s' "$input" | jq -r '.tool_input.skill // .tool_input.skillName // ""')`). No user-controlled path. |
| T-14-08 | Elevation of Privilege | mitigate | CLOSED | hooks/uat-gate.sh uses `permissionDecision: deny` block format (line 26). PreToolUse hook cannot be bypassed by the agent. |

---

## Open Threats

| Threat ID | Category | Gap Description | Files Searched | Severity at ASVS L1 |
|-----------|----------|-----------------|----------------|---------------------|
| T-14-03 | Tampering | Plan declares "path validated to stay within ~/.claude/" but no explicit path validation code exists in spec-session-record.sh. Path is hardcoded, which provides equivalent traversal protection, but the declared control is absent. | hooks/spec-session-record.sh (lines 33-36) | Low — hardcoded path is functionally equivalent; no exploitable gap at L1 |

---

## Unregistered Flags

| Flag | Source | Assessment |
|------|--------|------------|
| `git commit --no-verify` in pr-traceability.sh | hooks/pr-traceability.sh:95 | Not in threat register. This bypasses all registered PreToolUse/PostToolUse hooks for the trace commit. At ASVS L1 this is informational — the commit is a read-only traceability write (SPEC.md Implementations section only) and the risk is that hook enforcement is skipped for this specific git operation. Recommend registering as accepted risk in a future threat model update. |

---

## Accepted Risks Log

| Threat ID | Risk | Rationale |
|-----------|------|-----------|
| T-12-02 | User can create minimal SPEC.md with just headers to pass floor check | Spec is a starting point artifact; content quality is enforced by process, not by the hook |
| T-12-05 | WebFetch reads user-provided URLs | URLs are voluntarily provided; WebFetch is read-only |
| T-12-07 | SPEC.md content can be tampered with | Draft artifact reviewed before use; no security-critical data |
| T-12-09 | Router misrouting is not logged | Router shows routing decision to user transparently |
| T-13-01 | gh CLI auth managed externally | SB does not handle credentials; low risk for spec content |
| T-13-03 | MCP connector logs may contain request data | MCP connectors handle auth lifecycle; SB skill does not echo credentials |
| T-13-05 | $ARGUMENTS passed to AI parser | AI parses natural language; not passed to eval or shell expansion |
| T-14-01 | VALIDATION.md can be tampered with | Informational file regenerated on each run; tampering has no enforcement impact |
| T-14-04 | Spec metadata public in PR description | Intentional design — traceability requires PR visibility |
| T-14-06 | UAT.md results can be falsified | Process gate, not security gate; enforcement is invocation-based |

---

## Hook Registration Verification

| Hook Script | Event | Matcher | Registered in hooks.json |
|-------------|-------|---------|--------------------------|
| spec-floor-check.sh | PreToolUse | Bash | YES (line 81) |
| spec-session-record.sh | SessionStart | startup\|clear\|compact | YES (line 19) |
| pr-traceability.sh | PostToolUse | Bash | YES (line 143) |
| uat-gate.sh | PreToolUse | Skill | YES (line 41) |
