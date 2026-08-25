# Plan delta — Q-loop, thermos-unified review, `/sb:ladder` (2026-08-25)

Plan-only. No product source. Both copies byte-identical.

| Copy | SHA-256 |
|---|---|
| `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `3cf1845c73b1212ff52202a4d7eed5076a358e4cacec63f809e32a43c56b29b2` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `3cf1845c73b1212ff52202a4d7eed5076a358e4cacec63f809e32a43c56b29b2` |

Bytes: 575748. Prior home freeze (skill-extract): `2a0fc1c7…`. Repo `main` had drifted back to Round-41 `a96045f9…` after merge `aff95759`; this write **restored** the skill-extract MUST and added the three new MUSTs so the copies match again.

## YAML todos added (`pending`)

- `q-loop`
- `unified-code-review`
- `generalized-role-boards`

Skill-extract todo `new-workflow-skill-extract` retained.

## MUSTs

1. **Q-loop** — nine Design Quality Gates (modularity, reusability, scalability, security, reliability, usability, testability, extensibility, + ai-llm-safety when AI/LLM) on generated work spec / analysis / design / plan / code; **not** docs/technical writing. Generating role fixes. Checker defaults to Advisor tuple. FAST skips.
2. **Unified code review** — after A-loop on Executor **code**, one SB review workflow absorbs `/thermos` (parallel thermo-nuclear-review + thermo-nuclear-code-quality-review, then synthesize). No second Cursor `/thermos`. Review defaults to Advisor tuple. Executor fixes. APPLY ACCEPT completeness.
3. **Ladder / Parallel boards** — any quality-order LLM role may be multi-model. Default **Ladder**. Parallel uses a **Consolidator**. `/sb:ladder` absorbs RFL at 100% (standalone launcher APPLY ACCEPT; quality-order preceding-role fixes). Least→most capable reorder. Authorizer still not a preference key.

KEEP REJECT not reopened.
