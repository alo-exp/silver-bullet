# Ladder/parallel any-workflow compose — freeze plan delta — 2026-08-25

Planning-only. No product code, tests, hooks, or YAML todo status changes. Both freeze copies stayed on `main` and byte-identical. No commit. No checkout/switch.

## Copies

| Path | SHA-256 | Bytes |
|------|---------|-------|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `ee19a0fbfb2dcfb0bac23605a4083a8ac9f316e7cf60c42fc62b2dff496fedd5` | 624061 |
| [`~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`](/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md) | same | same |

Pre-edit pair: `1f4dcdc54c4296e23d69cd79020ff04803587e64c1bb3273c7732576042d964d` / 620176 bytes.

## Locked grammar (Cursor MVP — one CLI, not three)

- `/sb:ladder <route>` — sequential, least-capable → most-capable, same inner Job WF/AF.
- `/sb:parallel <route>` — independent `{ runtime, model, effort }` (+ optional agent pin) members; Consolidator unifies.
- `<route>` examples: `clarify`, `sb:clarify`, `/sb:clarify` → `/sb:ladder clarify`, `/sb:parallel clarify`.
- Bare `/sb:clarify` stays the non-composed Job AF. Bare `/sb:ladder` / `/sb:parallel` stay the standalone Jobs (RFL absorb / Parallel consolidator).
- No per-WF `/sb:clarify-ladder` catalog explosion. No `/sb:multi-ai-task`.

## Product fork (fail-closed)

Nested `/sb:ladder /sb:parallel <route>` (or the reverse) is **not** allowed. One-level compose only: ladder XOR parallel.

## YAML

All **33** todos remain `status: pending` (23 original + 3 locked-clarify + 5 omni-agent-opt-in by-ref + 1 autonomous-e2e-order + 1 `sb-ladder-parallel-compose`). Named test pointer: `tests/scripts/test-sb-ladder-parallel-compose.sh` (create at execute). Extended `generalized-role-boards` and `sb-parallel` one-liners.

## KEEP REJECT (not reopened)

Authorizer not a board / not a preference key; public `/sb` only; catalog generated; FAST is not a Job and is not a legal compose `<route>`; `/sb:improve` always a Job; WBS projector exclusive; no `sb:agent-wrap`; no `/sb:multi-ai-task`; Consolidator unifies Parallel (review-only); Ladder least→most capable; standalone APPLY ACCEPT / inside quality-order preceding role fixes; evolution general; WS1 emit / WS4 Jobs / WS7 docs; E2E step 7 WBS after wrap.
