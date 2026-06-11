# Legacy GSD And Silver Bullet

Silver Bullet used to be documented as an enforcement layer around GSD. That is
historical context, not the current contract.

SB now provides its own lifecycle skills for the work it explicitly depended on:
context, planning, execution, review request, review, review triage, security,
UI contract, UI review, verification, completion audit, branch finishing, ship,
debug, and release. The core SB lifecycle does not require GSD or Superpowers.

## Current Recommendation

Use SB by default:

```text
/silver:init
/silver
```

Install external lifecycle tooling only for an explicit legacy command, migration
audit, or user-directed comparison. Optional extension plugins are still welcome
when they add a domain capability such as cloud deployment, design-system access,
research retrieval, or issue-tracker integration.

## Artifact Compatibility

| Artifact or state | SB behavior |
|-------------------|-------------|
| `.planning/PROJECT.md`, `.planning/ROADMAP.md`, `.planning/STATE.md` | Preserved and read as project memory. |
| `.planning/REQUIREMENTS.md`, `.planning/SPEC.md` | Used as requirements evidence for planning and verification. |
| `.planning/phases/` | Preserved as historical or active phase evidence. |
| `.planning/workflows/<id>.md` | SB-owned composed-workflow tracking. |
| SB runtime state | Records SB markers and normalizes known historical aliases. |

SB does not clobber old project memory during initialization. It adds current
enforcement and continues with SB-owned lifecycle steps.

## Migration Notes

1. Run `/silver:init` in the project.
2. Let SB detect existing planning artifacts.
3. Continue work through `/silver`, `silver:context`, `silver:plan`,
   `silver:execute`, `silver:verify`, and `silver:ship`.
4. Keep external lifecycle plugins installed only when a specific old command or
   audit requires them.

## See Also

- `docs/sb-without-gsd.md`
- `docs/sb-vs-gsd.md`
- `docs/composable-flows-contracts.md`
