# Silver Bullet v0.35.0 SB/GSD Alignment Spec

## Overview

Release v0.35.0 realigns Silver Bullet around GSD as the lifecycle authority and positions SB as the Agentic Process Orchestrator that composes task-shaped workflows, enforcement hooks, quality gates, release gates, and contextual helper-plugin boundaries around GSD.

## Acceptance Criteria

- SB must not require post-execution/final-delivery markers before GSD implementation edits can begin.
- GSD-owned lifecycle artifacts and commands must remain authoritative for discuss, plan, execute, review, verify, ship, and milestone completion.
- Superpowers must be described and invoked only at explicit SB-selected helper boundaries.
- The pre-release gate must be configurable so plugin-runtime live matrix checks remain SB-plugin-specific until generalized.
- Public site, Help Center, README, config, templates, and package manifests must reflect v0.35.0 positioning and version surfaces.
- Security scans must find no active dangerous shell execution patterns or committed secrets.
- The full local test suite must pass before release.
