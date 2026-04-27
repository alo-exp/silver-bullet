# Phase 71 / Plan 01 — Summary

**Status:** Complete
**Plan:** `.planning/phases/071-claude-sb-lock-hooks/071-01-PLAN.md`
**Requirement:** HOOK-01 (path-resolver foundation)

## Files

- **Created:** `hooks/lib/phase-path.sh` (mode 644, sourced library)

## What changed

Added the tiny shared library `_resolve_phase_from_path` used by every Phase 71 hook (Plan 02 claim/heartbeat/release, Plan 03 informational peek). Centralises the `\.planning/phases/([0-9]{3})[-/]` regex so all hooks agree on what counts as a phase-locked path.

Returns 0 on both match and no-match — callers treat empty stdout as "not a phase-locked path" and proceed normally with `set -euo pipefail`.

## Verification

```
$ bash -n hooks/lib/phase-path.sh
$ bash -c 'source hooks/lib/phase-path.sh && _resolve_phase_from_path "/x/.planning/phases/071-foo/bar.md"' # → 071
$ bash -c 'source hooks/lib/phase-path.sh && _resolve_phase_from_path "/etc/passwd"' # → empty, exit 0
```

All four match cases (padded path, summary path, slash-only path, non-phase path) verified inline via the Plan 01 verify command — exit 0, expected stdout in each case.

## How HOOK-01 advances

HOOK-01 calls for a `PreToolUse` claim hook that determines `<NNN>` from the tool's `file_path`. Plan 01 ships the resolver function; Plan 02 wires it into `hooks/phase-lock-claim.sh`.
