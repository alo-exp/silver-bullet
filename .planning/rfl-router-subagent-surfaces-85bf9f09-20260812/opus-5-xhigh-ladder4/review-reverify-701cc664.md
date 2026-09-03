# RFL Ladder 4 — Opus Extra High — RE-VERIFY on `701cc664…` — PARENT ACCEPT

**Reviewer:** Opus Extra High (`sb-opus-5-xhigh` / [`74e66df1-00b5-4c83-9555-6c5e9b5b9575`](74e66df1-00b5-4c83-9555-6c5e9b5b9575)). Review-only at review time. No Fast. No Max.
**Branch:** `main`
**Frozen SHA-256 at re-verify:** `701cc66466830161476597af35606168377acb2437088fb86787eec0f6fcc884`
**Parent ACCEPT (round-26):** B-1 / H-1 / H-2 / M-1 incorporated (with GPT Max re-verify B-1 / H-1 / M-1 / M-2). Max **not** re-launched. No commit.

**Hash gate: PASS.** Both plan copies hashed to `701cc66466830161476597af35606168377acb2437088fb86787eec0f6fcc884` at review time. Branch `main`, untouched during review.

**Round-25 landed check: PASS (all six).** Generated-catalog + parity gate, `SKILL_TO_FLOW`/`ROUTERS` accepting `sb` tokens, `WF-SILVER-ROUTER` public trigger `/sb`, one hyphen `ART-AGENT-DELEGATE`, OpenCode/Pi `artifact_refs`, and WS1 ownership of both catalog libs. KEEP REJECT is intact.

The reviewer **ran the generator** — measurements treated as fact. The committed catalog and its generator disagree.

## VERDICT: NOT CLEAN

### Blocker B-1 — the mandated first regen turns a currently-green named invariant red (accepted)

`AF-MULTI-AI-TASK.execution.worker_template` is `templates/orchestrator-workers/MULTI-AI-TASK.md` in the committed catalog, but [`ATOMIC_SPECS` line 61](scripts/generate-apo-catalog.py) declares `skills/silver-multi-ai-task/SKILL.md`, and [`merge_multi_ai_catalog()`](scripts/lib/apo_multi_ai_catalog.py) sets `owning_skills`/`flow_steps`/`artifacts`/`parallelizable` but never `worker_template`. Measured, not inferred:

```
BASELINE   (committed):  PASS  one source worker template per atomic flow  missing=[] extra=[]
AFTER REGEN (generator): FAIL  one source worker template per atomic flow  missing=['SKILL.md'] extra=['MULTI-AI-TASK.md']
```

`worker_template_parity` compares basenames against `templates/orchestrator-workers/*.md`, so `SKILL.md` is unmatched and `MULTI-AI-TASK.md` becomes orphaned. WS1 is told to regen the catalog, add a `--check` parity gate, and keep [`check-apo-invariants.py`](scripts/check-apo-invariants.py) plus `tests/run-all-tests.sh` (the named release gate) green — those cannot all hold. It also cascades: [`generate-apo-artifacts.py:254`](scripts/generate-apo-artifacts.py) reads that field, so the round-24 H-3 mandated regen rewrites [`docs/generated/atomic-flow-index.json:454`](docs/generated/atomic-flow-index.json) and [`docs/composable-flows-contracts.md:84`](docs/composable-flows-contracts.md), which both currently record the `templates/` path. The plan and clarify contained zero mentions of `worker_template`, `AF-MULTI-AI-TASK`, or `worker-template-parity`.

### High H-1 — stop stripping OpenCode/Pi from the delegate AF (accepted)

The plan justifies attaching `FS-SILVER_AGENT_OPENCODE`/`FS-SILVER_AGENT_PI` to `AF-AGENT-DELEGATE.flow_steps` with "they already claim to belong there." That claim exists only in the committed JSON, which B-1 just declared non-authoritative. [`apo_delegate_catalog.py:213-215`](scripts/lib/apo_delegate_catalog.py) does the opposite — it explicitly strips `AF-AGENT-DELEGATE` from those two steps' `reusable_by_flows`, so regen emits `[]` where the committed catalog has `["AF-AGENT-DELEGATE"]`. `DELEGATE_FLOW_STEP_ORDER` omits both steps, and lines 186 and 212 overwrite `flow_to_steps` and `flow["flow_steps"]` from that constant, so any attach WS1 makes elsewhere is silently discarded. `SKILL_TO_FLOW` (lines 168-169) maps both skills to the AF and then the merge detaches them, so the source contradicts itself. Round-24 M-3's mandated `flow_steps ⇄ reusable_by_flows` invariant is unsatisfiable until the strip is removed. Neither `DELEGATE_FLOW_STEP_ORDER` nor `build_flow_steps` appeared in the plan or clarify.

### High H-2 — the parity gate is red on arrival with no reconcile step (accepted)

The committed catalog is not reproducible from its generator: 439,666 vs 439,615 bytes, with exactly three semantic divergences (the `worker_template` above plus the two `reusable_by_flows`). Record counts are otherwise identical, so nothing is structurally lost. B-1 says "uncommitted generator output is not authority after regen; the source is the Python builders," but never says the committed catalog carries un-regenerable state that must be back-ported into generator source *before* `--check` can pass. M-1's "heal on regen" framing is backwards for these fields — the first regen deletes committed state rather than healing it.

### Medium M-1 — patch the inline AF V-loop, not a fictional sibling family (accepted)

H-1 tells WS1 to set `VL-AF-AGENT-DELEGATE.verification.artifact_refs` to `ART-AGENT-DELEGATE`, "same as sibling `VL-FS-DELEGATE-*`." There are zero `VL-FS-DELEGATE-*` records — the catalog's 29 top-level `v_loops` are all AF-level, and step V-loops live inline on flow_steps. The target is also ambiguous: the real underscore collision is on the **inline** `AF-AGENT-DELEGATE.v_loop.verification.artifact_refs = ["ART-AGENT_DELEGATE"]`, whereas the **top-level** `v_loops[]` stub has `{"methods":["inspection"]}` and no `artifact_refs` at all, so WS1 could patch the wrong record and leave the collision standing. The surfaces H-1 names are viable, though — `id_slug` is `^[A-Z][A-Z0-9_-]*$` so an `AGENT-DELEGATE` slug is legal, and `verification_block` already permits `artifact_refs`. This is a precision defect, not an impossibility.

Parent ACCEPT 2026-08-16 (round-26): B-1 / H-1 / H-2 / M-1 incorporated. Max not re-launched.
