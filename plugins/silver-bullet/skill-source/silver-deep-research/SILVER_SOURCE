---
name: "silver:deep-research"
title: "Deep Research"
description: >
  SB catalog-backed AF-DECIDE flow step (FS-SILVER_DEEP_RESEARCH) and `/silver:deep-research` workflow engine: rigorous multi-source research with phase-level evidence, nested V-loops, citation tracking, claim verification, optional search-cli retrieval, and `.planning/research/` artifacts.
argument-hint: "<research question or technology decision> [--mode quick|standard|deep|ultradeep]"
version: 1.0.0
---

# /silver:deep-research — Deep Research Workflow

SB research workflow and **AF-DECIDE** flow-step implementation for decisions that
need evidence before planning or execution. This skill absorbs the upstream
`deep-research` methodology into Silver Bullet as `FS-SILVER_DEEP_RESEARCH`.

**Catalog:** workflow `WF-SILVER-DEEP-RESEARCH` · flow step
`FS-SILVER_DEEP_RESEARCH` · atomic flow `AF-DECIDE` · evidence
`EV-FS-SILVER_DEEP_RESEARCH` · V-loop `VL-FS-SILVER_DEEP_RESEARCH`.

**Canonical contracts:** `docs/composable-flows-contracts.md`,
`docs/apo-catalog.json`, `docs/APO-AUTHORING-COMPLIANCE.md`.

## Purpose

Turn a bounded research question into a durable, citation-backed decision record:

- recommendations and alternatives
- tradeoffs, risks, and confidence
- source registry and evidence ledger
- claim-support verification
- implementation handoff for downstream SB workflows

This is not a general chat answer and not an implementation step. It exists so
SB can decide before it builds.

## Standard composition chain

Canonical label: Standard Composition Chain.

```text
AF-CLARIFY -> AF-DECIDE -> AF-DOCUMENT -> AF-VALIDATE
```

**Pre-execution**: `silver:clarify` -> `silver:deep-research`

**Post-execution**: `silver:ensure-docs` -> `silver:validate`

Runtime queue:

```text
silver-clarify -> silver-deep-research -> silver-ensure-docs -> silver-validate
```

`/silver:deep-research` is removed. `/silver:deep-research` is the only SB research
route.

## Research Session (HARD)

Before retrieval or synthesis:

1. Get the current date from the host runtime; do not assume a year from model
   memory.
2. Select mode: `quick`, `standard`, `deep`, or `ultradeep`.
3. Create output directory:

```bash
export SB_RESEARCH_OUT_DIR=".planning/research/$(date -u +%Y-%m-%d)-<slug>"
mkdir -p "$SB_RESEARCH_OUT_DIR/validation"
```

4. Write `run_manifest.json` with:
   - `workflow_id`
   - `atomic_flow: "AF-DECIDE"`
   - `flow_step: "FS-SILVER_DEEP_RESEARCH"`
   - `question`
   - `mode`
   - `started_at`
   - `search_cli.status`
   - `search_cli.providers_available`
   - `fallback_reason`
5. FORBIDDEN: writing research output to `~/Documents`.

## Mode Selection

AF-DECIDE selects depth by need:

| Mode | Use when | Internal phases |
|------|----------|-----------------|
| `quick` | Initial exploration, low-risk known topic, user asks for a scan | `DR-SCOPE`, `DR-RETRIEVE`, `DR-PACKAGE` |
| `standard` | Default for implementation-gating research | `DR-SCOPE`, `DR-PLAN`, `DR-RETRIEVE`, `DR-TRIANGULATE`, `DR-OUTLINE`, `DR-SYNTHESIZE`, `DR-PACKAGE` |
| `deep` | Critical architecture, new dependency, public API/data model, security-sensitive, or conflicting evidence | All phases through `DR-REFINE`, then `DR-PACKAGE` |
| `ultradeep` | User asks for comprehensive/state-of-the-art research, strategic decision, high blast radius, or serious contradictions | All phases with critique-driven loopback until gap thresholds pass or blocker is recorded |

Escalate one level when evidence is thin, source credibility is weak, or the
decision is hard to reverse.

## Nested SB Flow Discipline

Although `FS-SILVER_DEEP_RESEARCH` is a flow step, it runs a nested workflow.
Every required phase has a local V-loop and must roll up before AF-DECIDE passes.

| Internal step | Deep-research phase | Work product | V-loop check |
|---------------|---------------------|--------------|--------------|
| `DR-SCOPE` | Scope | `scope.md` | Bounded question, assumptions, in/out scope |
| `DR-PLAN` | Plan | `research-plan.md` | Source classes, search strategy, mode rationale |
| `DR-RETRIEVE` | Retrieve | `sources.jsonl`, `evidence.jsonl` | Provider manifest, source diversity, evidence spans |
| `DR-TRIANGULATE` | Triangulate | `triangulation.md` | Claims cross-checked across independent sources |
| `DR-OUTLINE` | Outline refinement | `outline.md` | Findings map tied to evidence ids |
| `DR-SYNTHESIZE` | Synthesize | `research_report.md` draft | Major claims extracted to `claims.jsonl` |
| `DR-CRITIQUE` | Critique | `critique.md` | Gaps, contradictions, and loopback decision |
| `DR-REFINE` | Refine | `research_report.md` final | Unsupported claims repaired or escalated |
| `DR-PACKAGE` | Package | `decision-record.md`, `handoff.md` | ART-DECIDE rollup and validation logs |

Each phase records `input_contract`, `work_product`, `evidence_refs`,
`verification`, `validation`, `repair`, and `status` in:

```text
$SB_RESEARCH_OUT_DIR/vloop-rollup.json
```

## Search-Cli Policy

`search-cli` is optional and primary when available.

1. Probe:

```bash
command -v search >/dev/null && search --version
```

2. If configured, use `search "query" --json -c 10` for retrieval batches.
3. If partially configured, use available providers and record missing provider
   classes.
4. If unavailable, fall back to host search/fetch tools and record the fallback.

Only recommend sign-up or provider setup when selected depth actually needs it:

- `quick` and ordinary `standard`: degrade with a manifest note.
- `deep` or `ultradeep`: if no provider can satisfy breadth/recency/semantic
  coverage, recommend the relevant service class (Brave/Serper for web breadth,
  Exa for semantic search, Jina/Firecrawl for extraction).
- Block only when the user requested maximum rigor and fallback sources cannot
  meet the evidence threshold.

## Methodology

Load these references as needed:

- `reference/methodology.md` for phases 1-7
- `reference/report-assembly.md` for packaging
- `reference/quality-gates.md` for validation loops
- `reference/html-generation.md` for optional HTML
- `reference/continuation.md` for long reports

Phases 3-5 operate as an evidence loop per section:

```text
retrieve -> evidence store -> outline refinement -> draft -> verify claims -> delta-retrieve
```

## Output Contract

All files are under:

```text
.planning/research/<date>-<slug>/
```

Required:

```text
run_manifest.json
scope.md
research-plan.md
sources.jsonl
evidence.jsonl
triangulation.md
outline.md
research_report.md
claims.jsonl
critique.md
decision-record.md
handoff.md
vloop-rollup.json
validation/validate_report.log
validation/verify_citations.log
validation/verify_claim_support.log
```

Compatibility report names may also be emitted when useful:

```text
landscape-report.md
comparison-report.md
competitive-intelligence-report.md
```

`decision-record.md` is the AF-DECIDE rollup. It must include:

- chosen recommendation or decision
- alternatives considered
- evidence summary
- tradeoffs and risks
- confidence and remaining gaps
- downstream handoff route

## Validation

Run validation before exit:

```bash
python3 skills/silver-deep-research/scripts/validate_report.py --report "$SB_RESEARCH_OUT_DIR/research_report.md"
python3 skills/silver-deep-research/scripts/verify_citations.py --report "$SB_RESEARCH_OUT_DIR/research_report.md"
python3 skills/silver-deep-research/scripts/verify_claim_support.py --report "$SB_RESEARCH_OUT_DIR/research_report.md" --dir "$SB_RESEARCH_OUT_DIR"
```

Maximum repair loops: 3 inside the flow step. If still failing, write blocker
evidence to `.planning/BLOCKERS.md` and return a blocked AF-DECIDE V-gate.

## What This Skill Does Not Do

- It does not implement code.
- It does not call `/silver:multi-ai`; MultAI is not part of this flow step.
- It does not write to `~/Documents`.
- It does not skip evidence because a topic seems familiar.
