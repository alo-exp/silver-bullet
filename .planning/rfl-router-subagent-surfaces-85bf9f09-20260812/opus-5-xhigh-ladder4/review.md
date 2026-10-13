# RFL Ladder 4 — Opus 5 Extra High — REVIEW ONLY

**Reviewer:** Opus 5 Extra High (`sb-opus-5-xhigh` / [`053395ca-1db5-45b2-9aab-a9769c550a80`](053395ca-1db5-45b2-9aab-a9769c550a80)). No nested Task. No Fast. No edits, commit, or checkout.
**Branch:** `main`
**Frozen SHA-256 (both copies byte-identical at review time):** `67eff63eb035db3586cb0b0faeb55088b05dd86ea71651773b488b47c23efd75`

**Hash gate: PASS.** Both copies were byte-identical (462,897 bytes) and matched the frozen SHA. Branch: `main`, untouched at review time.

**Round-22 landed check: PASS.** `WF-AGENT-DELEGATE-ENTRY` / `AF-AGENT-DELEGATE` / `VL-AF-AGENT-DELEGATE` present; WS1 completeness scoped to this ship; `nested_executor` stated as leaf class not record type; `router-coverage` keep with `WF-SILVER-ROUTER` / `AF-ROUTE` retained; `prompt_hash` inner-only; Codex `unbounded` never compared as integer 0; Pi in the runtime enum and picker; HINST-01 three-install + two instruction-only; both mermaids carry the skip-promote edge. KEEP REJECT not reopened.

## Blocker

**B-1 — The ship-wide `silver`→`sb` skill rename has no owner for the catalog alias map, and WS1 pins the one check that hardcodes the old names.**

The plan mandates renaming skill *directories*, not just public routes. `scripts/check-apo-invariants.py` derives its skill set from directory names and requires every one to be a key in `migration_map.skill_to_entity`. `agent_delegation_contract` hardcodes four `silver-agent-*` lookups. WS1 “keep agent-delegation-contract” + “do not bulk-rewrite the whole catalog” cannot both hold once the rename lands. The plan never mentioned `migration_map`, `skill_to_entity`, `canonical-alias-mapping`, `runtime_queue_tokens`, or `workflow-chain-guard`. These are live tests under `tests/run-all-tests.sh`.

## Highs

**H-1 — `/sb:agent-opencode` and `/sb:agent-pi` cannot reach `AF-AGENT-DELEGATE` as shipped, and WS1 forbids the fix without naming it.**

`WF-AGENT-DELEGATE-ENTRY.triggers` omits OpenCode/Pi. `AF-AGENT-DELEGATE.owning_skills` omits those agent skills. `AF-AGENT-DELEGATE.flow_steps` has no OpenCode or Pi equivalents. `FS-SILVER_AGENT_OPENCODE` and `FS-SILVER_AGENT_PI` exist as orphans. Named field changes on existing records are required. HINST-01 still: no SB plugin on OpenCode/Pi.

**H-2 — `nested_executor` has no legal home in the catalog, and the schema is frozen.**

“still catalog `nested_executor`” cannot be stored in catalog JSON (`additionalProperties: false`). The class lives in `contracts/apo-hierarchy.lock.json` / `public-workflow-routes.lock.json` only. Leaves `/sb:agent-*` are lock class `nested_executor`; `WF-AGENT-DELEGATE-ENTRY` / `AF-AGENT-DELEGATE` stay Workflow/AF types.

## Mediums

**M-1 — Row 19's depth-mismatch trigger is vacuous where it is defined and undefined where it would matter.**

Declare-then-stamp without an independent computed source is a tautology. **Actual** post-spawn `remaining_depth` must be computed from host nesting. Consume (and nested-Task launch with no consume) must **compare computed vs declared**; mismatch → row 19.

**M-2 — The one dangling `owning_skill` in the catalog sits on a record this ship changes.**

`WF-AGENT-DELEGATE-ENTRY.owning_skill` is `silver-agent`; no backing skill directory and no `skill_to_entity` key. In-scope this ship.

---

`VERDICT: NOT CLEAN`

Parent ACCEPT 2026-08-16 (round-23): all five incorporated. Schema unchanged. No second agent-delegate AF/WF. Public `/sb:agent-*` in-plan Executor mint stays. HINST 3+2 stays. `prompt_hash` inner-only.
