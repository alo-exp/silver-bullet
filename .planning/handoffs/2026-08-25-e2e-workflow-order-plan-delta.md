# E2E workflow order — freeze plan delta — 2026-08-25

Planning-only. No product code, tests, hooks, or YAML todo status changes. Both freeze copies stayed on `main` and byte-identical. No commit.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `ff5f224ac6bf4c22e42d4a50421a77f37db8e9fa990189ee8d68bd51dec42654` | 618275 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Pre-edit pair: `dde658d822848f38466384ce081df7c6e3070fc0393b083ea208322c7a8b5960` / 608795 bytes.

Omni companion plan unchanged: [`omni_agent_opt-in_67f2f73a.plan.md`](/Users/shafqat/.cursor/plans/omni_agent_opt-in_67f2f73a.plan.md) SHA-256 `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26`.

## Critical gap addressed (this ship)

The catalog already had the idea→operational hops (clarify, spec, research, UI, security, verify/UAT, deploy with staging/rollback-readiness, canary, incident, doctor, GST). The freeze had Job quality-order and FAST short-order, but **no live-spec MUST for canonical autonomous runtime utilization order**.

Added:

- YAML todo `autonomous-e2e-order` (compact one-line, `pending`)
- `### LS-autonomous-e2e-order` in §2.7 (spine + branches; Process overlay is not an AF; FAST is not a Job)
- WS4 runtime pointer + WS7 docs pointer (runtime vs AGENTS.md presentation SDLC)
- Named test pointer `tests/scripts/test-sb-autonomous-e2e-order.sh`
- Completeness tokens: YAML todos **32** (was 31); Appendix B map row; §5.4 coverage map; integrity checklist

## Post-MVP (non-blocking — §6 deferred)

Not this-ship MUSTs; KEEP REJECT un-reopened:

- Dedicated product observability/SRE WF (deploy already records monitoring links; GST-01 is Jobs dashboard)
- Dedicated production-rollback WF (deploy already requires rollback owner)
- Dedicated staging-environment WF (staging is a `/sb:deploy` target)
- Iterate Ladder, Levels 0–3, host adapters, MIG-01 reverse-bridge, PROD-01 freeze/drain (already deferred)

## Catalog vs presentation

Runtime order is LS-autonomous-e2e-order (quality-order overlay + feature spine). AGENTS.md Help Center SDLC listing remains **presentation-only**.
