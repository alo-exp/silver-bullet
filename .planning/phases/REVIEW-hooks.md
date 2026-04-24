---
phase: hooks-review
reviewed: 2026-04-20T00:00:00Z
depth: deep
files_reviewed: 27
files_reviewed_list:
  - hooks/ci-status-check.sh
  - hooks/completion-audit.sh
  - hooks/compliance-status.sh
  - hooks/dev-cycle-check.sh
  - hooks/forbidden-skill-check.sh
  - hooks/phase-archive.sh
  - hooks/pr-traceability.sh
  - hooks/prompt-reminder.sh
  - hooks/record-skill.sh
  - hooks/roadmap-freshness.sh
  - hooks/semantic-compress.sh
  - hooks/session-log-init.sh
  - hooks/spec-floor-check.sh
  - hooks/spec-session-record.sh
  - hooks/stop-check.sh
  - hooks/timeout-check.sh
  - hooks/uat-gate.sh
  - hooks/lib/nofollow-guard.sh
  - hooks/lib/required-skills.sh
  - hooks/lib/trivial-bypass.sh
  - hooks/lib/workflow-utils.sh
  - hooks/hooks.json
  - scripts/deploy-gate-snippet.sh
  - scripts/extract-phase-goal.sh
  - scripts/semantic-compress.sh
  - scripts/sync-marketplace-version.sh
  - scripts/tfidf-rank.sh
findings:
  critical: 1
  warning: 6
  info: 5
  total: 12
status: issues_found
---

# Hooks Code Review Report

**Reviewed:** 2026-04-20
**Depth:** deep
**Files Reviewed:** 27
**Status:** issues_found

## Summary

All 27 files were reviewed at deep depth. Every hook script references real files — `hooks.json` is fully consistent with the files on disk. The shell safety invariants (`set -euo pipefail` + `trap 'exit 0' ERR`) are present in all hook scripts that require them. The `nofollow-guard`, `required-skills`, and `trivial-bypass` shared libraries are well-structured.

The single critical finding is a logic defect in `ci-status-check.sh`: the backward-compatibility deprecation notice (lines 73–78) is unreachable because `sb_trivial_bypass` exits unconditionally before the backward-compat block can execute. This silently drops the deprecation warning, making the scheduled v0.25 removal invisible to users who are relying on the old behaviour.

Six warnings cover: non-atomic cache writes in `compliance-status.sh`, an indentation anomaly in `timeout-check.sh` that may indicate a merge error, a `session-log-init.sh` heredoc that does not use `sb_guard_nofollow` before writing the log file, a `deploy-gate-snippet.sh` that is missing `trap 'exit 0' ERR`, an unvalidated `src_pattern` variable used unquoted in `grep -q` in `dev-cycle-check.sh`, and a `pr-traceability.sh` temp-file that applies `sb_guard_nofollow` after `mktemp` (on a freshly created regular file — harmless in practice, but logically inverted).

---

## Critical Issues

### CR-01: Backward-compat deprecation block in ci-status-check.sh is unreachable

**File:** `hooks/ci-status-check.sh:73-78`
**Issue:** `sb_trivial_bypass` is called at line 61 with no argument, defaulting to `${HOME}/.claude/.silver-bullet/trivial`. Its implementation calls `exit 0` immediately if that file exists as a real file. Therefore, control never reaches the backward-compat block at lines 73–78 that is supposed to emit the deprecation warning. Users who rely on the `trivial` file as a CI-red override will continue to be silently bypassed, receiving no deprecation notice, and will be surprised by the hard break planned for v0.25.

`sb_trivial_bypass` source (`lib/trivial-bypass.sh:5-10`):
```bash
sb_trivial_bypass() {
  local trivial_path="${1:-${HOME}/.claude/.silver-bullet/trivial}"
  if [[ -f "$trivial_path" && ! -L "$trivial_path" ]]; then
    exit 0   # <-- script exits here, before lines 73-78 are reached
  fi
}
```

The intent was: (1) trivial bypass exits, (2) backward-compat block shows deprecation warning for the trivial-as-ci-override use. But because the same trivial file path controls both, step 2 is never reached.

**Fix:** Move the backward-compat block BEFORE the `sb_trivial_bypass` call, so the deprecation message fires first:

```bash
# ── CI-red override bypass ──────────────────────────────────────────────
_sb_state_dir="${HOME}/.claude/.silver-bullet"
_ci_override_file="${_sb_state_dir}/ci-red-override"
_trivial_file="${_sb_state_dir}/trivial"

# Backward compat (v0.23.6 → v0.24): check trivial-as-CI-override BEFORE
# trivial-bypass so the deprecation warning is actually visible.
# Remove this block in v0.25.
if [[ -f "$_ci_override_file" && ! -L "$_ci_override_file" ]]; then
  exit 0
fi
if [[ -f "$_trivial_file" && ! -L "$_trivial_file" ]]; then
  printf '{"hookSpecificOutput":{"message":"[deprecation] ..."}}'
  exit 0
fi

# ── Trivial bypass (exits for all other trivial sessions) ────────────────
_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/lib" && pwd)"
[[ -f "$_lib_dir/trivial-bypass.sh" ]] && source "$_lib_dir/trivial-bypass.sh" && sb_trivial_bypass
```

---

## Warnings

### WR-01: Non-atomic cache write in compliance-status.sh risks partial-read corruption

**File:** `hooks/compliance-status.sh:87-88`
**Issue:** The config-path cache is written with a bare redirect (`printf ... > "$cache_file"`). If the process is interrupted mid-write (signal, timeout, kernel OOM), the cache file is left truncated. The next run reads a one-line file and interprets the path as both the config path and the mtime, which will silently bypass the mtime validation (`cached_mtime == current_mtime` may spuriously pass if mtime is empty/0).

```bash
# current (non-atomic)
printf '%s\n%s' "$config_file" "$config_mtime" > "$cache_file"
```

**Fix:** Write to a temp file and atomically rename:
```bash
_cache_tmp=$(mktemp "${cache_file}.XXXXXX")
printf '%s\n%s' "$config_file" "$config_mtime" > "$_cache_tmp"
mv -- "$_cache_tmp" "$cache_file"
```

---

### WR-02: Indentation anomaly in timeout-check.sh may indicate a dropped `if` body

**File:** `hooks/timeout-check.sh:107-111`
**Issue:** Three `echo` statements at lines 108, 110, and 128 are not indented, while the surrounding code inside `if` and `elif` blocks is consistently indented with two spaces. This strongly suggests the `echo` lines were accidentally dedented during an edit. At runtime this is harmless because `echo` is always valid bash, but the statements at 108 and 110 execute inside the `if [[ "$current_state_mtime" -gt "$last_state_mtime" ]]` block where `sb_guard_nofollow` is called immediately before them. If `sb_guard_nofollow` called `exit 1` (symlink detected), the `echo` would not execute. The current layout is correct in intent but the dedented style is a maintenance risk.

```bash
# lines 105-111 as they appear (echo lines not indented)
if [[ "$current_state_mtime" -gt "$last_state_mtime" ]] && ...; then
  sb_guard_nofollow "$last_state_mtime_file"
echo "$current_state_mtime" > "$last_state_mtime_file"   # line 108 — should be indented
  sb_guard_nofollow "$last_progress_file"
echo "$call_count" > "$last_progress_file"               # line 110 — should be indented
  last_progress_count=$call_count
fi
```

Similarly at line 128 inside the `if [[ "$tier1_triggered" == true ]]; then` block.

**Fix:** Indent the `echo` lines consistently with the surrounding block:
```bash
if [[ "$current_state_mtime" -gt "$last_state_mtime" ]] && ...; then
  sb_guard_nofollow "$last_state_mtime_file"
  echo "$current_state_mtime" > "$last_state_mtime_file"
  sb_guard_nofollow "$last_progress_file"
  echo "$call_count" > "$last_progress_file"
  last_progress_count=$call_count
fi
```

---

### WR-03: session-log-init.sh writes log file without symlink guard

**File:** `hooks/session-log-init.sh:158`
**Issue:** `nofollow-guard.sh` is sourced and `sb_guard_nofollow` is called for state files under `$SB_DIR` (lines 121–136, 218–229), but the session log file at `$log_file` (written at line 158 via `cat > "$log_file"`) has no symlink check. If an attacker pre-creates `docs/sessions/<today>-<timestamp>.md` as a symlink pointing to an arbitrary file (e.g., `~/.bashrc`), the heredoc write at line 158 overwrites the symlink target. The `docs/sessions/` path is under `$project_root` which is caller-controlled.

```bash
# line 156-158 — no guard before write
log_file="$sessions_dir/${today}-${timestamp}.md"
cat > "$log_file" << LOGEOF
```

**Fix:** Add a guard before the write:
```bash
log_file="$sessions_dir/${today}-${timestamp}.md"
sb_guard_nofollow "$log_file"
cat > "$log_file" << LOGEOF
```

---

### WR-04: deploy-gate-snippet.sh is missing trap 'exit 0' ERR

**File:** `scripts/deploy-gate-snippet.sh:1-10`
**Issue:** The script has `set -euo pipefail` but no `trap 'exit 0' ERR`. While the script is intended to fail with exit 1 on missing skills, any unexpected ERR (e.g., from `jq` on a malformed config, `stat` on a missing file, or a `grep` on an unreadable state file) will bubble up as a non-zero exit and block the CI deploy pipeline without a clear message. The project invariant in CLAUDE.md states every hook must fail-open with a visible warning; `deploy-gate-snippet.sh` is the primary CI integration point where silent exits are highest-risk.

Note: The existing `return 0 2>/dev/null || exit 0` patterns at the fast-path exits are correct, but unexpected paths do not have this safety net.

**Fix:** Add an ERR trap with a visible message above the gate logic:
```bash
trap 'echo "[deploy-gate] ERROR: unexpected failure in workflow check — skipping gate (fail-open)."; return 0 2>/dev/null || exit 0' ERR
```

---

### WR-05: src_pattern used unquoted in grep -q in dev-cycle-check.sh

**File:** `hooks/dev-cycle-check.sh:255,264`
**Issue:** `src_pattern` is validated against a safe-characters allowlist (line 181) and overly-permissive patterns are rejected (line 185). However, it is then used unquoted in `grep -q "$src_pattern"` at lines 255 and 264. For the standard default `/src/` this is safe, but any pattern containing characters like `[`, `]`, `.`, or `*` — which are permitted by the allowlist regex `^/[a-zA-Z0-9/_.|()-]*/?$` — will be interpreted as extended regex metacharacters, potentially matching unintended paths or causing `grep` to error. Specifically `|`, `(`, `)`, `.` are all in the allowlist and are regex-active.

```bash
# line 255 — $src_pattern unquoted, treated as ERE
if ! printf '%s' "$file_path" | grep -q "$src_pattern"; then
```

**Fix:** Use `grep -qF` (fixed-string) for the `src_pattern` match since it is a path-segment literal, not a regex:
```bash
if ! printf '%s' "$file_path" | grep -qF "$src_pattern"; then
```
And similarly at line 264 for the Bash-command check.

---

### WR-06: pr-traceability.sh applies sb_guard_nofollow to the mktemp output (logically inverted)

**File:** `hooks/pr-traceability.sh:91-94`
**Issue:** `mktemp` always creates a new regular file — it cannot return a path that is already a symlink. Calling `sb_guard_nofollow "$tmpfile"` immediately after `mktemp` will never trigger, giving a false sense of security. The real risk is if `$tmpfile` is somehow replaced between `mktemp` and the write (TOCTOU), but `sb_guard_nofollow` as implemented only checks the current state and does not provide TOCTOU protection. The guard call is thus a no-op that could mislead reviewers into thinking the write is hardened.

```bash
tmpfile=$(mktemp)
trap 'rm -f -- "$tmpfile"' EXIT INT TERM
sb_guard_nofollow "$tmpfile"          # always a no-op — mktemp returns regular files
printf '%s' "$new_body" > "$tmpfile"
```

**Fix:** Remove the `sb_guard_nofollow "$tmpfile"` call (it is dead) and add a comment explaining the TOCTOU limitation if needed. The real mitigation is `mktemp` itself, which creates the file with `O_EXCL`:
```bash
tmpfile=$(mktemp)
trap 'rm -f -- "$tmpfile"' EXIT INT TERM
# mktemp guarantees a new regular file; no symlink guard needed
printf '%s' "$new_body" > "$tmpfile"
```

---

## Info

### IN-01: scripts/ directory files missing trap 'exit 0' ERR

**File:** `scripts/semantic-compress.sh`, `scripts/tfidf-rank.sh`, `scripts/extract-phase-goal.sh`, `scripts/sync-marketplace-version.sh`
**Issue:** None of the four utility scripts under `scripts/` have `trap 'exit 0' ERR`. Unlike the hooks which are called by Claude Code's hook runner (where unexpected exits block the session), these scripts are called from hooks or standalone. `semantic-compress.sh` is called from `hooks/semantic-compress.sh` via `exec`, so its exit code propagates to the hook runner. An unexpected error in `scripts/semantic-compress.sh` or `scripts/tfidf-rank.sh` (e.g., `mktemp` failure, `awk` syntax error, `jq` parse error) will exit non-zero and be visible as a hook failure. The CLAUDE.md invariant of fail-open applies to this execution path.
**Fix:** Add `trap 'exit 0' ERR` after `set -euo pipefail` in each scripts/ file that is called from a hook execution path.

---

### IN-02: compliance-status.sh sources nofollow-guard twice under different _lib_dir assignments

**File:** `hooks/compliance-status.sh:5-9` and `hooks/compliance-status.sh:22-30`
**Issue:** `_lib_dir` is assigned at line 6 using `pwd 2>/dev/null || _lib_dir=""` to locate `workflow-utils.sh`. It is then reassigned at line 23 using the same pattern to locate `nofollow-guard.sh`. Both assignments use the same expression and will produce the same value (same dirname), so the double assignment is harmless but adds 4 lines of dead code and is confusing to read.
**Fix:** Consolidate into a single `_lib_dir` assignment at the top and use it for both sources.

---

### IN-03: hooks/lib/required-skills.sh fallback list is out of sync with the comment

**File:** `hooks/lib/required-skills.sh:46`
**Issue:** The fallback `__SB_RS_FALLBACK` is documented as "minimal safe list — hooks always enforce at least the planning/quality-gate floor" and is set to `"silver-quality-gates verification-before-completion"`. However, the hardcoded fallback list in the calling hooks (`completion-audit.sh:255`, `stop-check.sh:200`, `prompt-reminder.sh:97`) includes 14+ skills. If `jq` or the template config is missing, the fallback in `required-skills.sh` will enforce only 2 skills while callers expect ~14. This gap is narrowed by the callers' own inline fallbacks, but they form a second source of truth that may drift.
**Fix:** Document explicitly that the `required-skills.sh` fallback is intentionally minimal (last-resort) and that callers provide their own complete fallback. Add a comment to that effect.

---

### IN-04: session-start resets gsd- markers on same-branch sessions but this is not reflected in compliance-status.sh display

**File:** `hooks/session-start:71-73`
**Issue:** On same-branch re-entry, `session-start` removes all `gsd-*` lines from the state file (`sed -i.bak '/^gsd-/d'`). However, `compliance-status.sh` reports GSD progress as `GSD 0/5` after this reset. The compliance-status hook fires asynchronously on every tool use. If it fires before `session-start` completes writing the GSD-cleared state, it may briefly display stale GSD counts. While the race window is small (async vs. sync ordering), the visual inconsistency can confuse users into thinking GSD phases are complete when they have been reset. This is informational since compliance-status is non-blocking.
**Fix:** No code change required. Add a comment to `compliance-status.sh` noting that GSD counts reset on each session start and brief display of stale counts is expected.

---

### IN-05: deploy-gate-snippet.sh hardcodes a partial required_deploy list as default

**File:** `scripts/deploy-gate-snippet.sh:44`
**Issue:** The hardcoded default `REQUIRED_DEPLOY` at line 44 lists 6 skills: `"code-review receiving-code-review testing-strategy documentation finishing-a-development-branch deploy-checklist"`. This differs from the canonical list in `templates/silver-bullet.config.json.default` (which has 14+ skills including `silver-quality-gates`, `requesting-code-review`, `silver-create-release`, etc.). If `jq` is unavailable, the deploy gate will enforce a subset of required skills. The script is a standalone helper, not a hook, and has its own degradation path, but the gap is not documented.
**Fix:** Add a comment at line 44 documenting that this is an intentionally reduced fallback for the standalone script, or update the list to match `templates/silver-bullet.config.json.default`.

---

_Reviewed: 2026-04-20_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: deep_
