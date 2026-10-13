---
name: secure-skills
description: >
  Sub-skill of TopGun. Security-audits a skill via the bundled SENTINEL
  skill at $CODEX_PLUGIN_ROOT/skills/sentinel/SKILL.md, fixes findings,
  and produces a secured copy. Not normally invoked directly. The topgun
  orchestrator dispatches this via the topgun-securer agent.
---

# SecureSkills

**Status:** Phase 4 — Complete.

## Capabilities

- Wraps external SKILL.md content in `<structural-envelope>` tags with source attribution and SHA-256
- Pre-filters executable body sections for phone-home patterns (curl, wget, fetch) per REQ-15
- Inspects allowed-tools frontmatter for dangerous permissions (Bash, Computer, wildcard)
- Invokes **bundled SENTINEL v2.3.0** via `Read "$CODEX_PLUGIN_ROOT/skills/sentinel/SKILL.md"` and follows its workflow (no external dependency, version pinned with the plugin release) per REQ-10
- Runs fix loop until 2 consecutive clean Sentinel passes on identical content (REQ-12)
- SHA-256 integrity gating between passes — hash computed over the full SKILL.md content before each pass; if the hash differs between consecutive passes, the audit is aborted immediately (REQ-13)
- Per-finding fingerprint tracking with 3-attempt loop cap (REQ-14)
- User escalation on Sentinel-resistant findings — binary accept-risk/reject-skill
- Critical findings never silently downgraded
- Writes secured copy to `~/.topgun/secured/{sha}/SKILL.md` with 600 permissions (REQ-16)
- Writes `audit-{hash}.json` with full findings, resolution paths, and disclaimer (NFR-05)

## Dispatch

This skill is dispatched by the TopGun orchestrator via the `topgun-securer` agent. Not normally invoked directly.

## Completion Markers

- `## SECURE COMPLETE` — audit passed, secured copy written
- `## SECURE REJECTED` — pre-filter rejection or user rejected skill
- `## SECURE ABORTED` — SHA-256 integrity failure between passes
- `## SECURE ESCALATED` — finding requires user decision (intermediate state)
