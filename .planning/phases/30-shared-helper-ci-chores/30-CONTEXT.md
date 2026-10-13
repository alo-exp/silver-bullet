# Phase 30: Shared Helper & CI Chores - Context

**Gathered:** 2026-04-16
**Status:** Ready for planning
**Mode:** Auto-generated (infrastructure phase — discuss skipped)

<domain>
## Phase Boundary

Duplicated trivial-bypass logic is consolidated into a single shared helper (hooks/lib/trivial-bypass.sh), both stop-check.sh and ci-status-check.sh updated to source it. SessionStart hook command updated to use umask 0077. CI gains a non-blocking warning when plugin.json version drifts from the latest git tag.

Requirements: REF-01, CI-01, CI-02

</domain>

<decisions>
## Implementation Decisions

### Shared Helper Location
- File: `hooks/lib/trivial-bypass.sh`
- Both `stop-check.sh` and `ci-status-check.sh` source it via: `source "$(dirname "$0")/lib/trivial-bypass.sh"` or equivalent path resolution
- Helper defines a function `sb_trivial_bypass` that checks for the trivial file and exits 0 if found
- Callers invoke `sb_trivial_bypass` where the inline guard was previously

### SessionStart Umask
- Update `hooks/hooks.json` SessionStart command: `umask 0077 && mkdir -p ${SB_RUNTIME_HOME_ROOT}/.silver-bullet && touch ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/trivial`

### CI Version Drift Warning
- Add to `.github/workflows/ci.yml` a non-blocking step that compares `jq -r '.version' .claude-plugin/plugin.json` against `git describe --tags --abbrev=0`
- If mismatch and tag exists: `echo "WARNING: plugin.json version ($plugin_version) does not match latest tag ($latest_tag)"`
- Step must NOT fail the build (`continue-on-error: true` or use `||` to prevent non-zero exit)

### Claude's Discretion
- Path resolution for sourcing the shared helper (absolute vs relative) — use the same pattern as other scripts in the hooks/ directory
- Whether to use a function or inline code in the shared helper

</decisions>

<code_context>
## Existing Code Insights

### Files to Modify
- `hooks/stop-check.sh` — contains inline trivial-bypass guard (source → extract)
- `hooks/ci-status-check.sh` — contains identical inline trivial-bypass guard (source → extract)
- `hooks/hooks.json` — SessionStart command needs `umask 0077 &&` prefix
- `.github/workflows/ci.yml` — add version-drift warning step

### Established Patterns
- Silver Bullet hook scripts use `umask 0077` at the top of each script
- Trivial-bypass guard pattern (from both scripts):
  ```bash
  SB_STATE_DIR="${SB_RUNTIME_HOME_ROOT}/.silver-bullet"
  trivial_file="${SB_STATE_DIR}/trivial"
  if [[ -f "$trivial_file" && ! -L "$trivial_file" ]]; then
    exit 0
  fi
  ```
- CI uses GitHub Actions YAML in `.github/workflows/ci.yml`

</code_context>

<specifics>
## Specific Ideas

- The shared helper should be sourced, not executed — so it needs to define a function, not run inline
- The CI warning should be non-blocking (warning only, never fail the build)
- No behavior change to the trivial-bypass logic itself — extraction only

</specifics>

<deferred>
## Deferred Ideas

None — phase scope is well-defined by the three requirements.

</deferred>
