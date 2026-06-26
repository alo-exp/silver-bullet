# Example: Fact-Checking using multi-ai-task

**This is an example use case for the multi-ai-task skill.** It shows how to use the skill for parallel fact verification across N models with cross-source corroboration.

---

## The task

Take a list of factual claims and verify each one against multiple sources. Output a per-claim verdict with citation.

## The dispatch

```bash
PROMPT="Verify each of the following claims. For each, return:
- claim_id (preserve the input ID)
- claim (the original text)
- verdict: true | false | partially-true | unverified
- confidence: high | medium | low
- sources (list URLs, prefer official/primary)
- evidence (verbatim quote from a source if available)
- counter_evidence (if verdict is false or partially-true)

Claims to verify:
1. [claim 1]
2. [claim 2]
3. [claim 3]
..."

for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max opencode-go/glm-5.2; do
  npx -y opencode-ai run \
    --model "$model" \
    --title "factcheck-$(date +%s)" \
    --dangerously-skip-permissions \
    "$PROMPT" \
    > "factcheck-${model}.md" 2> "factcheck-${model}.err" &
done
wait
```

## The schema (passed as --schema)

```json
{
  "type": "table",
  "primary_key": "claim_id",
  "columns": [
    {"name": "claim_id", "type": "string", "dedup_key": true},
    {"name": "claim", "type": "text"},
    {"name": "verdict", "type": "enum", "values": ["true", "false", "partially-true", "unverified"]},
    {"name": "confidence", "type": "enum", "values": ["high", "medium", "low"]},
    {"name": "sources", "type": "url_list"},
    {"name": "evidence", "type": "text", "max_words": 50},
    {"name": "counter_evidence", "type": "text", "max_words": 50}
  ],
  "conflict_resolution": {
    "verdict": "majority-with-uncertain",
    "confidence": "lowest-of-majors"
  }
}
```

Key customization for fact-check:
- `verdict: "majority-with-uncertain"` — if 2 say true and 1 says false, default to `partially-true` (uncertain) rather than `true`; require ≥3 votes for a clean verdict
- `confidence: "lowest-of-majors"` — when in doubt, downconfidence (use the lowest confidence among the majority verdict)
- `unverified` is a valid output (don't force a true/false judgment when evidence is insufficient)

## The output

After consolidation, `consolidated.md` contains:

- §1 Executive Summary (overall credibility: X% of claims verified true, Y% false, Z% uncertain)
- §2 Claims Table (one row per claim with final verdict, confidence, top source)
- §3 Per-Claim Details (each reviewer's verdict + their evidence quote)
- §4 Conflicts & Resolutions (where reviewers disagreed; what the tie-break was)
- §5 Source Quality (which sources were cited most often; which were primary vs secondary)
- §6 Unverified Claims (which claims couldn't be settled — need human review)
- §7 False Claims (the ones confidently debunked; include counter-evidence)

## Custom strategies for fact-check

| Field | Recommended rule | Rationale |
|-------|-----------------|-----------|
| verdict | `majority-with-uncertain` | High-stakes: better to flag uncertain than to mis-judge |
| confidence | `lowest-of-majors` | When reviewers disagree on confidence, defer to the least confident |
| evidence | `all-collected` | Concatenate all reviewers' quotes; deduplicate by source |
| sources | `union-dedup` | All sources from all reviewers; unique URLs only |
| counter_evidence | `concatenate-all` | Show all counter-evidence; user decides weight |

## Consensus requirements

For high-stakes fact-checking, set thresholds:
- **3+ models agree on `true` with high confidence + primary source** → confirmed
- **3+ models agree on `false` with high confidence + primary counter-source** → debunked
- **mixed verdicts or low confidence** → flagged for human review
- **no model could verify** → `unverified` (do not guess)

## Worked example

Not yet produced. The pattern is identical to the prior-art research example.
