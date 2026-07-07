# Handoff — v2 Landscape Replay

## Downstream workflows

| Workflow | Action |
|----------|--------|
| AF-DOCUMENT | Archive delta-vs-july-baseline.md in research dir |
| AF-VALIDATE | Run validate_structure + verify_claim_support on replay artifacts |
| silver:ensure-docs | Update site/help if benchmark methodology changes |

## Human checkpoints

None required — all claims within documented-feature scope.

## Artifacts

- `run_manifest.json` — v3.0.0 manifest with retrieval block
- `portal-skills_sh.json` — 88 semantic results
- `feature-matrix.md` — updated rankings
- `delta-vs-july-baseline.md` — behavioral comparison

## Next owner

SB maintainers — commit v2 engine + benchmark replay.
