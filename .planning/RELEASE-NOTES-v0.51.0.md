## Summary

Minor release: **tri-criteria E2E validation harness** — live/cold matrix across Cursor, Claude, and Codex; multi-workflow orchestrator scheduler; greenfield 6/6 PASS with harness drain fix.

## Features

- `feat(tri-criteria)`: live/cold validation harness and multi-WF orchestrator scheduler
- `feat(tri-criteria)`: Claude/Codex host live harness and PASS evidence
- `feat(tri-criteria)`: complete tri-host live matrix (cursor+claude+codex)
- `feat(tri-criteria)`: greenfield 6/6 matrix PASS with harness drain fix
- `feat(autonomous-enterprise)`: agent-claude track and orchestrator scheduler
- `feat(audit)`: AF/FS compliance script and full catalog audit report
- `feat(new-workflow)`: Audit mode for catalog compliance checks
- `feat(skills)`: silver-deep-research replaces silver-research/multi-ai
- `test(tri-criteria)`: sb-tri-criteria E2E framework scaffold for three orthogonal SB proof criteria

## Fixes

- `fix(tri-criteria)`: E2E scorer false fails and runtime composition wiring
- `fix(agent-codex)`: preflight graphify and agentmemory before delegate
- `fix(agent-claude)`: preflight graphify and agentmemory before delegate; folder trust seeding and plugin cache alias
- `fix(codex)`: valid PostToolUse JSON on end-user plugin install
- `fix(hooks)`: include hookEventName in dev-cycle-check advisories
- `fix(catalog)`: remediate 13 WF/AF audit failures to 157/157 PASS
- `fix(minimal-intent-e2e)`: score cmd passes work_dir and evidence to orchestrator

## Documentation

- `docs(tri-criteria)`: exhaustive raw log sweep with zero remaining findings
- `docs(proof)`: integrate MI-01 minimal-intent E2E PASS at live_e2e_proven
- `docs`: require complex multi-workflow goals for autonomous proof

## Verification

- Tri-criteria greenfield matrix — **6/6 PASS** (cursor+claude+codex)
- Release version alignment, template parity, render freshness — PASS
- Site content and doc freshness — PASS
