# Decision Record — v2 Landscape Replay

## Decision

**Adopt** SB `silver-deep-research` v2 engine for landscape benchmarks; use July 2026 feature matrix as stable ranking reference with v2 behavioral improvements in discovery orchestration.

## Rationale

1. skills.sh portal API now functional via `search_orchestrator` (88 results vs July failure)
2. `capability_score.py` provides reproducible behavioral metrics without popularity bias
3. Feature rankings stable — Socialpranker #1, SB #2 — confirming July baseline validity

## Alternatives considered

| Alternative | Rejected because |
|-------------|------------------|
| Re-rank by skills.sh installs | Install count ≠ capability depth |
| Use TopGun discovery | Forbidden per SB policy |
| Skip replay, ship v2 untested | User requested behavioral before/after |

## Confidence

**High** for discovery improvements; **Medium** for ranking stability (limited new SKILL.md reads).

## Evidence refs

E003, E004, E010

## Date

2026-07-08
