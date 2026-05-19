# Milestone Summary — silver-bullet v0.20.11

**Date:** 2026-04-16
**Type:** Patch release
**Theme:** Trivial-session bypass for stop-check skill gate

---

## Overview

v0.20.11 eliminates false-positive stop-check blocks for read-only sessions. Before this release, the `stop-check.sh` skill gate fired on **every** session end — including sessions where no files were modified (e.g., version checks, queries, research). The gate then required a full set of `required_deploy` skills (code-review, testing-strategy, deploy-checklist, tech-debt, documentation) before the session could end, even though no production code was touched.

The fix wires the existing (but previously unused) trivial-bypass mechanism in `stop-check.sh` via two new hook entries in `hooks/hooks.json`.

---

## What Changed

### hooks/hooks.json — 2 new entries

| Hook event | Matcher | Command | Effect |
|------------|---------|---------|--------|
| `SessionStart` | (none — fires always) | `mkdir -p ${SB_RUNTIME_HOME_ROOT}/.silver-bullet && touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial` | Every session starts as trivial (bypass active) |
| `PostToolUse` | `Write\|Edit\|MultiEdit` | `rm -f ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial` | First file modification clears trivial flag |

### How it works

`stop-check.sh` already contained this bypass check (unchanged):
```bash
trivial_file="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial"
if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
  exit 0   # skill gate skipped
fi
```

Previously nothing created `trivial`. Now `SessionStart` creates it, and any Write/Edit/MultiEdit removes it. **Sessions that only read files remain trivial and exit cleanly. Sessions that write files become non-trivial and face the full skill gate.**

### Security properties preserved

- `stop-check.sh` validates path containment (`case "$trivial_file" in "${SB_RUNTIME_HOME_ROOT}/"*)`) — symlinks are rejected
- The hook commands are hardcoded strings — no user input reaches the shell
- No changes to `stop-check.sh` itself; the bypass logic was already reviewed and secured

### .claude-plugin/plugin.json

Version bumped from `0.20.8` → `0.20.11` to synchronize with README/CHANGELOG.

---

## Commits

| SHA | Message |
|-----|---------|
| `7848b92` | feat(hooks): add trivial-session bypass to stop-check |
| `f3aa71d` | docs: update README and CHANGELOG for v0.20.11 trivial-session bypass |
| `02d7eb2` | docs(architecture): document trivial-session bypass hooks in key hooks table |

---

## Impact

| Before | After |
|--------|-------|
| Stop gate fires on every session end | Stop gate fires only when files were modified |
| Read-only sessions require all `required_deploy` skills | Read-only sessions exit cleanly |
| No way to distinguish trivial sessions | SessionStart + PostToolUse hooks automate the distinction |

---

## Files Modified

- `hooks/hooks.json` — 2 new hook entries
- `.claude-plugin/plugin.json` — version bump to 0.20.11
- `README.md` — version line updated
- `docs/CHANGELOG.md` — new entry added
- `docs/ARCHITECTURE.md` — key hooks table updated

---

## Tech Debt / Known Issues

None introduced. This release reduces noise and false-positive blocks.

---

## Getting Started (for new contributors)

To understand the trivial-session mechanism:

1. Read `hooks/hooks.json` — look for the `SessionStart` entry with the `touch` command and the `PostToolUse` `Write|Edit|MultiEdit` entry with `rm -f`
2. Read `hooks/stop-check.sh` lines 75–85 — the bypass check reads `trivial_file`
3. Test: start a session, run only read operations, end session → gate bypassed. Start a session, edit a file, end session → gate fires.
