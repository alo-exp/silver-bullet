# APO Authoring Compliance Audit — Silver Bullet

Audit date: 2026-07-05  
Authority: [`docs/apo-catalog.json`](../docs/apo-catalog.json) (source of truth) · [`scripts/check-apo-invariants.py`](../scripts/check-apo-invariants.py) · [`scripts/generate-apo-artifacts.py`](../scripts/generate-apo-artifacts.py) · compliance test suite under [`tests/scripts/`](../tests/scripts/)

## Summary

- Total checks in suite: **26**
- PASS: **26**
- FAIL (blocking): **0**

Last execution: `bash scripts/run-apo-authoring-compliance.sh` — all green (includes agent-delegation contract checks post Phase 4 flip).

## Requirement → Evidence table

Legend: `P` pass · `F` fail

### Catalog schema & source of truth

| # | Check | Script / command | Status | Evidence |
|---|-------|------------------|--------|----------|
| 1 | Catalog JSON validates against schema; required top-level keys; migration_map covers FLOW 1–18 | `test-apo-catalog-schema.sh` | P | 45 assertions on structure, V-loops, dispatch_mode |
| 2 | Single authoritative catalog; no parallel SOT files | `test-apo-catalog-sot.sh` | P | `docs/apo-catalog.json` only; meta.source_of_truth self-referential |
| 3 | Generated composition views match catalog | `test-apo-composition-sot.sh` | P | `composable-flows-contracts.md` fresh after `generate-apo-artifacts.py` |
| 4 | Derived index and contracts declare catalog SOT | `test-apo-derived-views.sh` | P | `docs/generated/atomic-flow-index.json` mirrors catalog version |

### Hierarchy, atomic flows & composition

| # | Check | Script / command | Status | Evidence |
|---|-------|------------------|--------|----------|
| 5 | Evidence registry, intent ledgers, V-loop rollups, composition logs | `test-apo-evidence-intent.sh` | P | Audit entities resolve to catalog V-loops |
| 6 | Each entity occupies one hierarchy level; no standalone nesting type | `test-apo-hierarchy-integrity.sh` | P | No orphan nesting entities |
| 7 | Atomic flow dedup gate (five-part promotion) | `test-atomic-flow-dedup.sh` | P | No duplicate capability classes |
| 8 | Atomic flow capability classes unique; workflows not duplicated | `test-atomic-flow-nonredundancy.sh` | P | Non-redundancy invariants |
| 9 | Per-flow V-loop, evidence refs, subagent dispatch, flow steps | `test-atomic-flow-vloop.sh` | P | Full V-loop on every AF |
| 10 | Composer trees reference only catalog flows/workflows | `test-composer-purity.sh` | P | No off-catalog composition refs |
| 11 | SKILL pre-exec == guard markers == orchestrator pre-execute | `test-composition-triple-alignment.sh` | P | 7 composer skills aligned |
| 12 | Dynamic composition rules (prune/insert/substitute/parallelize/loop) | `test-dynamic-composition-audit.sh` | P | Rule refs required in composition logs |
| 13 | Parallel scheduling safety and mutation scopes | `test-parallel-scheduling-safety.sh` | P | Parallelizable vs serialized atoms declared |
| 14 | Router workflow covers default public routes | `test-router-coverage.sh` | P | Starts with AF-ROUTE |
| 15 | Step V-loop rollup joins before flow rollup | `test-step-vloop-runtime-rollup.sh` | P | Runtime ordering invariant |

### Alias mapping & alignment

| # | Check | Script / command | Status | Evidence |
|---|-------|------------------|--------|----------|
| 16 | Every skill maps to one catalog entity via `migration_map.skill_to_entity` | `test-canonical-alias-mapping.sh` | P | `silver-agent-codex`, `silver-agent-cursor` → `AF-AGENT-DELEGATE`; `silver-agent-worker` → `AF-AGENT-DELEGATE` |
| 17 | Composer queue tokens, workflow-chain guard, orchestrator state | `test-triple-alignment.sh` | P | Queue tokens resolve to catalog entities |
| 18 | Flow steps have valid hierarchy classifications | `test-skill-hierarchy-classification.sh` | P | Step classification complete |
| 19 | Intent ledgers cover material claims | `test-user-intent-coverage.sh` | P | Completion/release consume ledger |
| 20 | One worker template per atomic flow; plugin mirror matches | `test-worker-template-parity.sh` | P | Source ↔ plugin parity |

### Tooling, site & artifact generation

| # | Check | Script / command | Status | Evidence |
|---|-------|------------------|--------|----------|
| 21 | Opted-in tool policies (warn/repair/block/degrade) | `test-opted-in-tool-enforcement.sh` | P | tool_policies semantics |
| 22 | Public docs reference APO catalog; no stale 18-flow count | `test-site-doc-freshness.sh` | P | Site/help aligned with catalog |
| 23 | Generated artifacts match catalog (`--check`) | `generate-apo-artifacts.py --check` | P | Contracts + matrix + index fresh |

### External agent delegation (`AF-AGENT-DELEGATE`)

| # | Check | Script / command | Status | Evidence |
|---|-------|------------------|--------|----------|
| 24 | Delegation catalog contract (AF, workflow ref, flow steps, map targets) | `test-agent-delegation-catalog-contract.sh` | P | Post-flip: host skills → `AF-AGENT-DELEGATE` |
| 25 | Delegation invariant (AF entity, worker skill/template, artifacts) | `check-apo-invariants.py agent-delegation-contract` | P | `AGENT-DELEGATE.md` + `silver-agent-worker` |
| 26 | Delegate wrapper parity (matrix env clear, redaction, log floor) | `test-agent-delegate-common.sh` | P | `scripts/lib/agent-delegate-common.sh` |

**Runtime flags (stage 5 default-on):**

| Flag | Default | Purpose |
|------|---------|---------|
| `SB_AGENT_DELEGATE_V2` | on (unset → worker path) | Set `0` to rollback worker path; host skills use `AF-AGENT-DELEGATE` → `AGENT-DELEGATE` worker when enabled |
| `SB_AGENT_DELEGATE_GUARD` | on when V2 active | Set `0` to disable active delegation guard hooks |
| `SB_AGENT_DELEGATE_DIRECT_FALLBACK` | unset | When `1`, allows degraded direct wrapper Bash from parent orchestrator (emits `EV-DELEGATE-DEGRADED-FALLBACK`) |

Rollback: set `SB_AGENT_DELEGATE_V2=0` for legacy worker-path routing; direct parent delegate Bash always requires `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` or audited `SB OVERRIDE:` (stage 6). Revert `migration_map` host skills to `AF-EXECUTE` only with full catalog revert. See `tests/scripts/test-agent-delegation-rollback.sh`.

## How to execute

Run the full suite (recommended):

```bash
bash scripts/run-apo-authoring-compliance.sh
```

One-liner equivalent:

```bash
for t in test-apo-catalog-schema test-apo-catalog-sot test-apo-composition-sot test-apo-derived-views test-apo-evidence-intent test-apo-hierarchy-integrity test-atomic-flow-dedup test-atomic-flow-nonredundancy test-atomic-flow-vloop test-canonical-alias-mapping test-composer-purity test-composition-triple-alignment test-dynamic-composition-audit test-opted-in-tool-enforcement test-parallel-scheduling-safety test-router-coverage test-site-doc-freshness test-skill-hierarchy-classification test-step-vloop-runtime-rollup test-triple-alignment test-user-intent-coverage test-worker-template-parity; do bash "tests/scripts/${t}.sh" || exit 1; done && python3 scripts/generate-apo-artifacts.py --check
```

Target a single invariant group:

```bash
python3 scripts/check-apo-invariants.py canonical-alias-mapping
bash tests/scripts/test-canonical-alias-mapping.sh
```

## Remediation guidance

### Missing `skill_to_entity` mapping

**Symptom:** `test-canonical-alias-mapping.sh` fails with `every skill maps to one catalog entity: <skill-names>`.

**Fix:**

1. Read the skill's `SKILL.md` to classify intent (route, execute, verify, etc.).
2. Confirm the target entity exists in `docs/apo-catalog.json` → `atomic_flows` or `workflows`.
3. Add `"<skill-name>": "<AF-…>"` under `migration_map.skill_to_entity`.
4. Cross-host delegation skills (`silver-agent-codex`, `silver-agent-cursor`) map to **`AF-AGENT-DELEGATE`** — canonical external-agent delegation AF (Phase 4 flip). `SB_AGENT_DELEGATE_V2` defaults on (stage 5); set `0` to rollback worker path. See [`docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md`](skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md).
5. Regenerate derived views: `python3 scripts/generate-apo-artifacts.py`
6. Re-run: `bash scripts/run-apo-authoring-compliance.sh`

### Stale generated views

**Symptom:** `test-apo-composition-sot.sh`, `test-apo-derived-views.sh`, or `generate-apo-artifacts.py --check` reports `STALE: docs/composable-flows-contracts.md` (or matrix/index).

**Fix:**

```bash
python3 scripts/generate-apo-artifacts.py
python3 scripts/generate-apo-artifacts.py --check
```

Commit both `docs/apo-catalog.json` and regenerated files under `docs/composable-flows-contracts.md`, `docs/workflow-composition-matrix.md`, and `docs/generated/`.

### Composition triple misalignment

**Symptom:** `test-composition-triple-alignment.sh` fails for a composer skill.

**Fix:** Align pre-exec markers in the skill's `SKILL.md`, workflow-chain guard in hooks, and orchestrator worker template pre-execute block. All three must reference the same catalog queue tokens.

### Worker template drift

**Symptom:** `test-worker-template-parity.sh` fails.

**Fix:** Edit source under `.silver-bullet/orchestrator-workers/`, then sync plugin mirror: `bash scripts/sync-templates.sh`.

## Release gate

**Can ship APO catalog changes?** **Yes** when `bash scripts/run-apo-authoring-compliance.sh` exits 0 and derived views are committed alongside catalog edits.

---

## Audit log

### 2026-07-05 — Stage 5/6 delegation default-on + whitelist tightening

- **Changed:** `SB_AGENT_DELEGATE_V2` default-on when unset (`agent-delegation-state.sh`); `SB_AGENT_DELEGATE_V2=0` documented as rollback.
- **Changed:** Stage 6 — removed unconditional parent delegate-wrapper allowlist; direct Bash only with `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` or audited `SB OVERRIDE:`.
- **Updated:** rollback test expectations + compliance flag docs.

### 2026-07-05 — Phase 4 delegation map flip

- **Changed:** `migration_map.skill_to_entity` — `silver-agent-codex`, `silver-agent-cursor` → `AF-AGENT-DELEGATE` (was `AF-EXECUTE`).
- **Added:** delegation contract rows (#24–26) to compliance suite.
- **Regenerated:** catalog + derived views via `generate-apo-catalog.py` + `generate-apo-artifacts.py`.

### 2026-07-04 — initial runbook + skill_to_entity fix

- **FAIL resolved:** `silver-agent-codex`, `silver-agent-cursor` missing from `migration_map.skill_to_entity` → added as `AF-EXECUTE`.
- **Regenerated:** `docs/composable-flows-contracts.md` (and related derived views) after catalog edit.
- **Created:** this runbook + `scripts/run-apo-authoring-compliance.sh`.
- **Verdict:** CLEAN PASS — 23/23 checks green.
