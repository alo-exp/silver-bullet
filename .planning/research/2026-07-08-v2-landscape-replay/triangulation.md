# DR-TRIANGULATE — Cross-Source Verification

## Claim: skills.sh API functional in v2

| Source | Evidence |
|--------|----------|
| portal-skills_sh.json | 88 semantic results, 683ms response |
| July baseline run_manifest | "skills.sh JSON API returned empty/HTML" |
| search_orchestrator retrieval | `portals_succeeded: ["skills_sh"]` |

**Status:** Triangulated — v2 portal catalog resolves July gap.

## Claim: Socialpranker leads feature depth

| Source | Evidence |
|--------|----------|
| S001 repo description | 9-phase, 103 blocks, 29 channels |
| July baseline feature-matrix | Rank #1, score 58.5 |
| gh search | Repo surfaced in claude-deep-research batch |

**Status:** Triangulated — consistent across sessions.

## Claim: SB v2 improves discovery orchestration

| Source | Evidence |
|--------|----------|
| search_orchestrator.py | 5 portals attempted, structured manifest |
| July baseline | Ad-hoc portal search, no orchestrator |
| capability_score.py | Behavioral metrics without popularity signals |

**Status:** Triangulated — architectural improvement confirmed.

## Claim: parallel-web leads portal installs

| Source | Evidence |
|--------|----------|
| skills.sh API | 11,200 installs for parallel-deep-research |
| GitHub repo | parallel-web/parallel-agent-skills exists |
| Feature matrix (pending) | Validation automation unverified |

**Status:** Partial — install count confirmed; capability depth needs SKILL.md read.
