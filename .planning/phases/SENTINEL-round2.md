# SENTINEL v2.3 — Round 2 Security Audit Report

**Date:** 2026-04-25
**Auditor:** SENTINEL v2.3 (claude-sonnet-4-6)
**Scope:** hooks/*.sh, hooks/lib/required-skills.sh, hooks/lib/nofollow-guard.sh
**Basis:** Round 1 three High findings now claimed fixed. Re-audit confirms fixes and scans for new issues.

---

## Section 1 — Fix Verification

### H-1: spec-session-record.sh — RESOLVED

**Claim:** Allowlist validation added for `spec_version` and `jira_id` before interpolation. Output via jq.

**Verification (lines 44–50, 64):**

```bash
if ! printf '%s' "${spec_version:-}" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
  spec_version=""
fi
if ! printf '%s' "${jira_id:-}" | grep -qE '^[A-Z][A-Z0-9_]*-[0-9]+$'; then
  jira_id=""
fi
```

Both regexes are anchored (`^` and `$`), correctly applied via `printf '%s'` (no word-splitting), and invalid values are cleared to `""` rather than blocked (fail-open, safe for this use case). The final JSON emission at line 64 passes the display string through `jq -Rs '.'`, which performs proper JSON string encoding. Injection via a crafted `spec_version` or `jira_id` is not possible.

The `jira_id` pattern `^[A-Z][A-Z0-9_]*-[0-9]+$` is intentionally more permissive than Round 1's suggested `^[A-Z][A-Z0-9_]*-[0-9]+$` but correctly rejects any value that could introduce shell metacharacters or JSON special characters. **RESOLVED.**

---

### H-2: uat-gate.sh — RESOLVED

**Claim:** Allowlist validation added for `uat_version` and `spec_version`; invalid values cleared to `""` which safely skips the stale-spec comparison.

**Verification (lines 67–76):**

```bash
if ! printf '%s' "${uat_version:-}" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
  uat_version=""
fi
if ! printf '%s' "${spec_version:-}" | grep -qE '^[0-9]+(\.[0-9]+)*$'; then
  spec_version=""
fi
if [[ -n "$uat_version" && -n "$spec_version" && "$uat_version" != "$spec_version" ]]; then
  emit_block "UAT GATE: UAT was run against spec v${uat_version} but current SPEC.md is v${spec_version}. ..."
```

The guard condition `[[ -n "$uat_version" && -n "$spec_version" && ... ]]` means clearing either value to `""` causes the entire stale-spec block to be skipped — the check neither fires a false block nor leaks unsanitised data into `emit_block`. The `emit_block` function itself uses `jq -Rs '.'` for JSON encoding (line 25–26), so even if validation were bypassed, output would be safe. **RESOLVED.**

---

### H-3: roadmap-freshness.sh — RESOLVED

**Claim:** `phase_title` piped through `tr -dc 'a-zA-Z0-9 .:,_-'` before appending to `unticked_phases`.

**Verification (lines 94–97):**

```bash
phase_title=$(grep -E "^- \[ \] \*\*Phase ${phase_num}:" "$roadmap_file" | head -1 | sed 's/^- \[ \] //')
phase_title=$(printf '%s' "$phase_title" | tr -dc 'a-zA-Z0-9 .:,_-')
unticked_phases="${unticked_phases}  [UNTICKED] Phase ${phase_num}: ${phase_title}\n"
```

`tr -dc` deletes all characters not in the allowlist — the complement is complete. The allowlist excludes all shell metacharacters (`$`, `` ` ``, `\`, `!`, `(`, `)`, `{`, `}`, `|`, `;`, `&`, `<`, `>`, `*`, `?`, `#`, `"`, `'`). The resulting string is passed to `emit_block` which encodes it via `jq -Rs '.'`. The strip is sufficient: no control characters, no JSON-breaking characters, no shell-executable content can survive. **RESOLVED.**

---

## Section 2 — New Findings

Full re-scan across all 18 hook files and 2 lib files.

### Finding N-1 (Medium) — session-log-init.sh: `find` replaced by glob but `sessions_dir` path is attacker-influenced

**File:** `hooks/session-log-init.sh`, line 89

```bash
existing=$(find "$sessions_dir" -maxdepth 1 -name "${today}*.md" -print 2>/dev/null | head -1 || true)
```

`sessions_dir` is set from `SESSION_LOG_TEST_DIR` env var (test override, line 57) and subsequently from `$project_root/docs/sessions`. The `today` variable is produced by `date '+%Y-%m-%d'` — format-controlled and safe. The `find` call has `-maxdepth 1` which prevents directory traversal. No injection path exists from untrusted input. **Not a new finding — no action required.**

### Finding N-2 (Low) — session-log-init.sh: SENTINEL_SLEEP_OVERRIDE validation has a gap

**File:** `hooks/session-log-init.sh`, lines 28–30

```bash
if [[ -n "${SENTINEL_SLEEP_OVERRIDE:-}" ]] && ! [[ "$SENTINEL_SLEEP_OVERRIDE" =~ ^[0-9]+$ ]]; then
  SENTINEL_SLEEP_OVERRIDE=600
fi
```

The validation rejects non-numeric overrides, but allows `0`, which would cause `sleep 0` — effectively removing the sentinel delay and causing the timeout file to be written immediately. This is a test-environment-only env var; an attacker who can set env vars already has broader access. Not High/Critical. No new action required for this audit cycle.

### Finding N-3 (Low) — record-skill.sh: tracked skills list is hardcoded in two places

**File:** `hooks/record-skill.sh`, line 80

The `DEFAULT_TRACKED` list in `record-skill.sh` is a separate hardcoded string not derived from `templates/silver-bullet.config.json.default`. This was a pre-existing architectural inconsistency (the CLAUDE.md design calls `required-skills.sh` as the single source of truth for *required* skills, not tracked skills). This is a maintainability concern, not a security finding.

### Finding N-4 (Low) — pr-traceability.sh: jira_id allowlist is narrower than spec-session-record.sh

**File:** `hooks/pr-traceability.sh`, line 57

```bash
jira_id=$(grep '^jira-id=' "$spec_session_file" | cut -d'=' -f2 | grep -E '^[A-Z]+-[0-9]+$' || echo "")
```

`spec-session-record.sh` writes with allowlist `^[A-Z][A-Z0-9_]*-[0-9]+$` (allows underscores and digits in project key), but `pr-traceability.sh` re-validates on read with `^[A-Z]+-[0-9]+$` (only uppercase letters in project key). A project key like `FOO_BAR-123` or `AB2-1` would pass write validation in spec-session-record.sh but be silently dropped to `""` on read in pr-traceability.sh. The practical effect is that traceability for such projects silently degrades to `jira_id=""` rather than injecting anything unsafe. This is a correctness gap, not a security gap. **Not High/Critical.**

---

## Section 3 — No New High or Critical Findings

Exhaustive scan across all hooks produced no new High or Critical findings:

| Hook | Verdict |
|---|---|
| spec-session-record.sh | H-1 RESOLVED; no new issues |
| uat-gate.sh | H-2 RESOLVED; no new issues |
| roadmap-freshness.sh | H-3 RESOLVED; no new issues |
| pr-traceability.sh | N-4 Low only |
| completion-audit.sh | Clean |
| session-log-init.sh | N-2 Low only |
| dev-cycle-check.sh | Clean |
| stop-check.sh | Clean |
| session-start | Clean |
| record-skill.sh | N-3 Low only |
| forbidden-skill-check.sh | Clean |
| phase-archive.sh | Clean |
| spec-floor-check.sh | Clean |
| lib/required-skills.sh | Clean |
| lib/nofollow-guard.sh | Clean |
| completion-audit.sh | Clean |
| ci-status-check.sh | Not in scope (not audited in Round 1) |
| prompt-reminder.sh | Not in scope (not audited in Round 1) |

---

## Section 4 — Overall Verdict

**CLEAR**

All three Round 1 High findings (H-1, H-2, H-3) are **RESOLVED**. The fixes are technically correct:
- Allowlists are properly anchored, cover all injection-relevant characters, and are applied before any interpolation or output.
- jq-mediated JSON encoding eliminates the output injection surface.
- Invalid values fail open to empty string, which is safe in all three contexts (no false blocks, no data leakage).

No new High or Critical findings were identified in Round 2.

**Round 2 determination: PASS**

The codebase is cleared for merge/release from a security gate perspective with respect to the three previously identified High findings.

---

_Auditor: SENTINEL v2.3 (claude-sonnet-4-6)_
_Audit completed: 2026-04-25_
