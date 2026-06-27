# Example: Prior-Art Research using multi-ai-task

**This is an example use case for the multi-ai-task skill.** It shows how to set up a structured research dispatch and what the consolidation output looks like. The skill itself is task-agnostic — this is one example of many.

---

## The task

Find existing tools, frameworks, methodologies, papers, and products that overlap with or inform the architecture of "subject X" (e.g., a specific framework, methodology, or product). The output is a dedup table, scoring matrix, conflict resolutions, and a positioning memo.

## The dispatch

```bash
OUT=./multi-ai-out/$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
cd "$OUT"

# Same prompt to all 6 models, in parallel via opencode run
# Substitute the path to the user's research prompt file
PROMPT="$(cat /path/to/research-prompt.md)"

for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max opencode-go/deepseek-v4-pro opencode-go/glm-5.2 opencode-go/kimi-k2.6 opencode-go/mimo-v2.5-pro; do
  slug=$(echo "$model" | cut -d/ -f2)
  npx -y opencode-ai run \
    --model "$model" \
    --title "prior-art-${slug}-$(date +%s)" \
    --dangerously-skip-permissions \
    "$PROMPT" \
    > "${slug}.md" 2> "${slug}.err" &
done
wait
echo "Outputs in $OUT/"
```

The `research-prompt.md` would contain the user's verbatim task description — section by section:

```
You are conducting prior-art and adjacent-landscape research — not building anything.
Your job is to find existing tools, frameworks, methodologies, papers, and products
that overlap with or inform the architectural approach described below.

## 1. Executive Framing — What SUBJECT Built
[subject description, table of layers, differentiators, architecture]

## 2. Research Questions
[2A direct prior art, 2B adjacent categories, 2C dimension-specific probes, 2D gap analysis]

## 3. Disambiguation Rules
[exclude unless criteria met]

## 4. Required Output Schema
[name, url, category, composition_model, v_loop_support, enforcement_mechanism, ...]

## 5. Citation Requirements
[primary sources only, with version/date, prefer quotes]

## 6. Search Strategy Hints
[query families to use]

## 7. Constraints
[do NOT propose implementing subject, flag duplicates, etc.]

## 8. Cross-AI Dedup Instructions
[normalize names, resolve conflicts, scoring rubric]

## 9. Reference Context
[subject catalog snapshot for calibration]
```

## The schema (passed as --schema)

```json
{
  "type": "table",
  "primary_key": "name",
  "columns": [
    {"name": "name", "type": "string", "dedup_key": true},
    {"name": "url", "type": "url"},
    {"name": "category", "type": "enum", "values": ["direct", "adjacent", "tangential", "negative-result"]},
    {"name": "composition_model", "type": "string", "max_words": 50},
    {"name": "v_loop_support", "type": "enum", "values": ["none", "end-only", "per-phase", "per-step+rollup", "v-model-explicit"]},
    {"name": "enforcement_mechanism", "type": "enum", "values": ["honor-system", "prompt-only", "ci-gate", "ide-hook", "policy-engine", "mixed"]},
    {"name": "se_fit", "type": "enum", "values": ["none", "partial", "strong"]},
    {"name": "devops_fit", "type": "enum", "values": ["none", "partial", "strong"]},
    {"name": "parent_worker_split", "type": "enum", "values": ["yes", "partial", "no"]},
    {"name": "evidence_model", "type": "enum", "values": ["none", "informal", "artifact-based", "tiered-sufficiency"]},
    {"name": "dynamic_composition", "type": "enum", "values": ["no", "replanner-only", "catalog-backed-audited"]},
    {"name": "maturity", "type": "string"},
    {"name": "gaps_vs_sb", "type": "text"},
    {"name": "sb_gaps_vs_them", "type": "text"},
    {"name": "confidence", "type": "enum", "values": ["high", "medium", "low"]},
    {"name": "last_verified", "type": "date"}
  ],
  "conflict_resolution": {
    "category": "prefer-with-evidence-then-newer-then-strict",
    "maturity": "newer",
    "confidence": "majority"
  }
}
```

## The scoring rubric (optional, for "closest match" section)

```json
{
  "dimensions": [
    {"name": "catalog",     "levels": ["none", "informal roles", "machine-readable catalog"]},
    {"name": "dynamic",     "levels": ["none", "replanner", "catalog-backed + audit log"]},
    {"name": "v_loop",      "levels": ["none", "end tests", "per-step rollup + intent gate"]},
    {"name": "enforce",     "levels": ["honor system", "CI only", "IDE hooks + delivery blockers"]},
    {"name": "parent_worker","levels": ["no", "partial", "explicit orchestrator/worker"]},
    {"name": "evidence",    "levels": ["none", "informal", "tiered sufficiency + staleness"]},
    {"name": "se_devops",   "levels": ["one domain", "partial", "both in one model"]},
    {"name": "customization","levels": ["none", "fork required", "overlay packs"]}
  ],
  "aggregate": "sum",
  "max_total": 16
}
```

## Alias map (research-specific)

The default behavior (no aliases) catches `AutoGen` vs `autogen` and `BMAD Method` vs `BMAD-Method`, but not semantic equivalences like `AutoGen` vs `AG2` or `MAF` vs `Microsoft Agent Framework`. For research, you need this alias map. Save it in your run's `run-manifest.json → aliases` field and apply in the `normalize()` step.

| Alias | Canonical |
|-------|-----------|
| AutoGen/AG2, AutoGen (maintenance) | **AutoGen** |
| MAF, Microsoft Agent Framework (MAF) | **Microsoft Agent Framework** |
| Camunda, Camunda 8 | **Camunda 8** |
| Conductor OSS, Conductor-OSS, Conductor (Netflix) | **Conductor** |
| GitHub Spec Kit | **Spec Kit** |
| GSD (Get Shit Done) | **GSD** |
| BMAD Method | **BMAD** |
| gh-aw, GitHub Agentic Workflows (gh-aw) | **GitHub Agentic Workflows** |
| OPA, Open Policy Agent, OPM | **OPA** |
| Claude Code Skills, Claude Code Hooks | **Claude Code** |
| Lunar | **Earthly Lunar** |
| Qodo, PR-Agent, Qodo / PR-Agent | **Qodo/PR-Agent** |
| Windsurf, Devin Desktop | **Windsurf** |
| Devin (Cognition), Devin (closed) | **Devin** |

Add new aliases to this map as they surface in your runs. After consolidation, audit `consolidated.md` for "missed alias" cases (two near-identical names that should have been merged) and update the map.

## Skip rules (research-specific)

Beyond the generic skip rules in `consolidation-rules.md`, also drop:
- The reference subject's own name (e.g., "Silver Bullet") if the task compares candidates against it — it's the comparison anchor, not a candidate
- Pure scoring-matrix header rows if they leak into the items table (e.g., a model writes "Catalog of composable units" as a row)

---

## The output

After consolidation, `consolidated.md` contains:

- §1 Executive Summary (cross-model consensus on what exists in the landscape)
- §2 Items Table (15-30 rows, one per distinct tool/framework/paper)
- §3 Per-Item Details (compact gap analysis per item)
- §4 Conflicts & Resolutions (the model disagreements and how they were resolved)
- §5 Aggregated Scores (median + range across models)
- §6 Negative Results (categories searched with no credible finds)
- §7 Open Questions (carry-forward for next research pass)
- §8 Synthesized Verdict (in research case: "where does SUBJECT sit in the landscape")
- Appendix A: Cross-AI Source Map (which model found which unique item)
- Appendix B: Coverage Scoreboard (bucket → found / target / gap)

Plus `consolidated.html` for browser viewing, `conflicts.md` for tooling, and `run-manifest.json` for reproducibility.

## Worked example

See the actual run on 2026-06-27:
- Inputs: `docs/research-260624/SB_PRIOR_ART_USER_PROMPT.md` (the verbatim research prompt)
- Schema + scoring rubric: passed via `--schema` as a JSON file (the prompt did NOT embed the schema; the skill auto-injected it because `--no-auto-inject` was not passed)
- Per-model outputs: `docs/research-260624/prior-art-landscape-*.md` (6 files)
- Consolidated output: `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.md`
- HTML render: `docs/research-260624/SB_CONSOLIDATED_PRIOR_ART_REPORT.html`
- Conflicts: documented in §4 of the report
- Alias map: 14 entries (now lives in this file under "Alias map" above)

## Variations to try

- **Add more models** — 8-10 models captures more unique finds but diminishing returns past 6 (this is an empirical observation, not a measured curve — run your own benchmark if you want a hard number)
- **Use a research methodology per model** — for the per-model prompt, you can either inline an 8-phase research methodology or invoke a host-side skill if available. The skill itself doesn't care which.
- **Use structured mode with custom conflict rules** — for research, `prefer-with-evidence-then-newer-then-strict` is appropriate; for other tasks, customize
- **Run the skill in `thorough` mode** — adds cross-source verification (a verifier model checks each cited source URL against the claim) and per-claim evidence ledger (`evidence-ledger.md`)
