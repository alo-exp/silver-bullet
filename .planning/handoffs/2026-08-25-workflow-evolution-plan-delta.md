# Plan delta — workflow evolution `/sb:improve` + `/sb:contribute` (2026-08-25)

Plan-only. No product source, tests, hooks, skills, or YAML-todo execution. Both copies byte-identical. Branch `main` unchanged.

| Copy | SHA-256 |
|---|---|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `15e7c4218797fd0014913ec9779db5dc5e991efc34fc07337c4df617a4a2a3a8` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `15e7c4218797fd0014913ec9779db5dc5e991efc34fc07337c4df617a4a2a3a8` |

Prior: `8e2a78222d9ac1f72da11ff7e4498e0fd3e74a170ff689080f9531c1df73f58e`. Bytes: 597215 (was 589263).

## YAML todos added (`pending`)

- `workflow-evolution-improve`
- `workflow-evolution-contribute`

All existing YAML todos remain `pending`. Named tests (`tests/scripts/test-sb-improve.sh`, `tests/scripts/test-sb-contribute.sh`) are specified for execute time — not created now.

## MUST summary

1. Shared WF / AF / Flow Step / Skill evolution from improvement-tagged Learnings for **all** users.
2. Custom/per-user needs mint a **new** workflow (`/sb:new-workflow` / WFM-01 / PUB-01) — no in-place fork of a shared catalog item.
3. Tag during existing K/L (KLW-01 / post-Val Executor hop). FAST skip tags unless a durable learning is still captured.
4. Installed edits only on explicit `/sb:improve` (Job, not FAST; all tagged workflows; PUB-01 publisher/generator).
5. Subsequent `/sb` runs use the latest evolved installed versions.
6. `/sb:init` stores optional GitHub PR opt-in; `/sb:contribute` is an explicit Job to `alo-exp/silver-bullet`.
7. Opt-out/unset → `/sb:contribute` **fail-closes** (no auto-PR).
8. Public `/sb` only; Cursor MVP; Authorizer-admitted mutations; not a new role.

## KEEP REJECT

Not reopened. Addendum only: this is **general-improvement** of the shared catalog, not per-user customization. Exclusive projector, DFS tri-color, two-limb mint, mid-I new PUB-01 = row 40, remint `launch_id`, no dual `/silver`, catalog generated, FAST overlay generator, `nested_executor` lock-only, B1 `additionalProperties: false`, Authorizer not Approver / not a preference key, ESC-02 no A, `prompt_hash` inner-only, launcher may omit `context_refs_hash`, L598 no abandonment-by-silence, OFF-01 post-MVP, FAST is not a Job, Wrap is Advisor-composed, no `sb:agent-wrap`, WS0 freeze-evidence lock, ship sequence WS0 → WS0b → WS1–7 → WS8 → docs-release all stay.
