# Plan delta — ship sequence WS0 → WS0b → WS1–7 → WS8 → docs (2026-08-25)

Plan-only. Both copies byte-identical. **Do not execute YAML todos.**

| Copy | SHA-256 |
|---|---|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `8e2a78222d9ac1f72da11ff7e4498e0fd3e74a170ff689080f9531c1df73f58e` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `8e2a78222d9ac1f72da11ff7e4498e0fd3e74a170ff689080f9531c1df73f58e` |

Prior: `6993d520…`. Bytes: 589263. All 21 YAML todos remain `pending`.

## MUST

1. **WS0** — Before considering this freeze as an implementation input: remove junk and files already unused in the **current** SB version. Named inventory + `tests/scripts/test-pre-impl-repo-hygiene.sh`.
2. **WS0b** — Then create/update key spec, analysis, architecture, and design docs to match the freeze. Q-loop applies. `tests/scripts/test-pre-impl-key-docs.sh`. No product hooks/skills in this step.
3. **WS1–WS7** — Product implementation (unchanged numbering).
4. **WS8** — After implementation: sweep unnecessary files (including this ship’s retirements). `tests/scripts/test-post-impl-repo-hygiene.sh`.
5. **docs-release** — Second docs pass after WS8 (WS0b is the first).

Job post-Val Executor K/L + key-doc hop is **runtime** Job behavior; it does not replace WS0b/WS8.

## KEEP REJECT

WS0 must not delete freeze evidence, KEEP REJECT locks, catalog/generator SOT, or tests that still gate current SB. WS0/WS0b must not implement product hooks/skills. Do not start WS1 until WS0 and WS0b are done.

YAML: `pre-impl-repo-cleanup`, `pre-impl-key-docs`, `post-impl-repo-cleanup` (all pending).
