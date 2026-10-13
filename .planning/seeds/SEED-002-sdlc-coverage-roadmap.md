---
seed_id: SEED-002
title: SDLC coverage expansion roadmap (v0.11–v0.17 enforcement milestones)
github_issue: 67
priority: low
planted_during: v0.30.0 Open-Issue Sweep
planted_at: 2026-04-28
trigger_when:
  - Starting a v0.40+ planning session focused on enforcement-coverage breadth
  - User asks "what parts of SDLC does Silver Bullet not yet enforce?"
  - A real project hits a gap (e.g. observability, on-call handoff, data-migration) that SB has no path or hook for
---

# SEED-002: SDLC coverage expansion roadmap (v0.11–v0.17 enforcement milestones)

## Idea

Catalog every SDLC stage Silver Bullet currently enforces vs. the stages it's silent on, then sequence enforcement milestones (provisionally v0.11.x–v0.17.x in the issue body, but version numbers should be assigned at the time of execution). Stages mentioned in the original issue: data-model migrations, observability/telemetry instrumentation, runbook/on-call handoff, secrets rotation, capacity/load testing, accessibility audits beyond UI quality, regulatory/compliance evidence collection.

Each stage becomes its own milestone:

- Stage spec & exemplar artifacts
- New required skills (where missing)
- New hooks (where automated enforcement is feasible)
- Templates / scaffolding additions

## Why This Matters

SB today is opinionated about the build-test-review-ship loop; everything around that loop (operate, observe, recover, retire) is unenforced. As SB goes upstream into mid-size teams, the silent stages become the failure modes.

## When to Surface

- A v0.40+ planning conversation touches "what should SB cover next."
- A downstream project files an issue that the symptom is "SB didn't make me X" where X is one of the silent stages.
- Engineering leadership asks for an SB-coverage matrix vs. their internal SDLC checklist.

## Implementation Sketch (when triggered)

1. Survey: write `docs/internal/sdlc-coverage-matrix.md` listing every SDLC stage on rows, current SB artifact (skill/hook/path) on columns, with cells marked covered/partial/missing.
2. For each missing/partial stage with high impact, file a tracking issue against the next major version.
3. Sequence the issues into 1-stage-per-milestone (or pair small-stages where natural).
4. Each milestone follows the standard SB workflow: spec → discuss → plan → execute → review → ship.

## Why Deferred

This is a meta-roadmap exercise that needs a strategic decision on which stages to prioritize, which downstream signal to weight (user feedback vs. risk vs. parity-with-competitors). Doing this correctly probably wants a discuss-milestone conversation with project stakeholders. v0.30.0's "minimize deferrals" autonomy bound stops short of strategic roadmap decisions.

## References

- GitHub issue: https://github.com/alo-exp/silver-bullet/issues/67
