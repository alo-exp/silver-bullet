# E2E WBS creation — freeze plan delta — 2026-08-25

Planning-only. No product code, tests, hooks, skills, or YAML todo status changes. Both freeze copies stayed on `main` and byte-identical. No commit.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `1f4dcdc54c4296e23d69cd79020ff04803587e64c1bb3273c7732576042d964d` | 620176 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Pre-edit pair: `ff5f224ac6bf4c22e42d4a50421a77f37db8e9fa990189ee8d68bd51dec42654` / 618275 bytes.

Omni companion plan unchanged: [`omni_agent_opt-in_67f2f73a.plan.md`](/Users/shafqat/.cursor/plans/omni_agent_opt-in_67f2f73a.plan.md) SHA-256 `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26`.

## Critical gap addressed

The 28-step Job spine named GST-01 at wrap/ops but **did not number WBS creation**. A reader of `### LS-autonomous-e2e-order` could miss mint entirely (it lived only as a §4.3 projector footnote: “WBS is created from user intent at Process resolve”).

## Spine (after this delta)

| Step | Hop | Notes |
|------|-----|-------|
| 5 | FAST branch | **No Job WBS.** No GST Job row. Thin-capture / thin wrap is not a Job WBS. |
| 6 | Job wrap | work-spec + GST-01 + Advisor compose + composition-Val + K/L. Points to step 7. |
| **7** | **Job WBS mint / live packets** | **Trigger:** work-spec exists and wrapping WF is composed (step 6). Projector-only. Same WBS as §4.3 Process resolve (composition-Val remint may rewrite) — **not** a second WBS. Before AF-ORIENT (step 8) and before Executor I (`plan_val_verified`). Packets / live WBS continue as AFs schedule (also restated on step 17). GST ≠ WBS. |
| 8–29 | former 7–28 | Renumbered. Improve/contribute is step 28. OmniRoute remains “not a spine step” as item 29. |

Process overlay vs AF distinction unchanged. YAML todos remain **32**, all `pending`. No new todo.

## 6-line MUST

1. Job WBS mint is **LS-autonomous-e2e-order step 7** (Process, not an AF), after step-6 wrap/compose and **before** Executor I.
2. Exclusive writer is `hooks/lib/wbs-projector.sh`; `primary_checkout` is the sole write root (packets/work-spec/plan too).
3. That hop is the **same** §4.3 Process-resolve WBS; composition-Val remint may rewrite it — do not invent a second WBS.
4. Packet mint and live WBS updates continue as AFs/NWs are scheduled (DFS / two-limb KEEP REJECT unchanged).
5. **GST-01** is the team Jobs dashboard; **WBS** is the Job decomposition artifact — do not conflate.
6. FAST is not a Job and **must not** mint a Job WBS or GST Job row (thin-capture is not a Job WBS). `/sb:improve` remains a Job.

## KEEP REJECT (un-reopened)

Exclusive `hooks/lib/wbs-projector.sh`; `primary_checkout` sole write root; packets/work-spec/plan projector-only; extra worktrees `host_native` only; FAST is not a Job; no dual `/silver`; no `sb:agent-wrap`; OmniRoute by reference; WS1 emit / WS4 Jobs / WS7 docs.

## Also patched (pointers only)

- Glossary: **WBS** row (distinct from **GST** / **WBS projector**).
- `LS-fast-short-order` + §4.3 FAST thin-wrap: no Job WBS.
- YAML `autonomous-e2e-order` one-liner mentions WBS.
- `VAL/TST-RFL-617` + WS4 autonomous-order sentence + this-ship completeness name the numbered hop.
