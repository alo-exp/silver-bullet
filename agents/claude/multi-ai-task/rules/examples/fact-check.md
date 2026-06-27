# Example: Fact-Checking using multi-ai-task

**This is an example use case for the multi-ai-task skill.** It shows how to use the skill for parallel fact verification across N models with cross-source corroboration.

---

## The task

Take a list of factual claims and verify each one against multiple sources. Output a per-claim verdict with citation.

## The dispatch

```bash
# Output dir convention
OUT=./multi-ai-out/$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"

# The prompt with claims to verify.
# Use a heredoc with single-quoted EOF to avoid shell-metacharacter injection.
cat > "$OUT/prompt.md" <<'PROMPT'
Verify each of the following claims. For each, return a markdown table with these columns:
- claim_id (preserve the input ID)
- claim (the original text)
- verdict: true | false | partially-true | unverified
- confidence: high | medium | low
- sources (comma-separated URLs, prefer official/primary)
- evidence (verbatim quote from a source if available)
- counter_evidence (if verdict is false or partially-true)

Claims to verify:
1. [claim 1]
2. [claim 2]
3. [claim 3]
...
PROMPT

# Dispatch to N models (use 4-5 for fact-check; majority-with-uncertain needs N>=3)
for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max opencode-go/glm-5.2; do
  slug=$(echo "$model" | cut -d/ -f2)
  npx -y opencode-ai run \
    --model "$model" \
    --title "factcheck-${slug}-$(date +%s)" \
    "$OUT/prompt.md" \
    > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
done
wait
echo "Outputs in $OUT/"
```

**Security note:** fact-check is read-only — the models just look up sources and report. The dispatch above does **NOT** pass `--dangerously-skip-permissions`. Per `rules/dispatch-mechanics.md:56`, this is correct for read-only tasks.

## The schema (passed as --schema)

```json
{
  "type": "table",
  "columns": [
    {"name": "claim_id",        "type": "string", "dedup_key": true, "required": true},
    {"name": "claim",           "type": "text"},
    {"name": "verdict",         "type": "enum",   "values": ["true", "false", "partially-true", "unverified"]},
    {"name": "confidence",      "type": "enum",   "values": ["high", "medium", "low"]},
    {"name": "sources",         "type": "url_list"},
    {"name": "evidence",        "type": "text",   "max_words": 50},
    {"name": "counter_evidence","type": "text",   "max_words": 50}
  ],
  "conflict_resolution": {
    "verdict":    "majority-with-uncertain",
    "confidence": "lowest-of-majors"
  }
}
```

Key customization for fact-check:
- `verdict: "majority-with-uncertain"` — strict-majority rule: any dissent blocks consensus and returns `unverified`. For N=3, all 3 must agree; for N=5, at least 4 must agree; for N=7, at least 5 must agree. The algorithm is `> max(2, ceil(N/2))` — any disagreement means unverified.
- `confidence: "lowest-of-majors"` — when in doubt, downconfidence (use the lowest confidence among the majority verdict)
- `unverified` is a valid output (don't force a true/false judgment when evidence is insufficient)
- `sources: "url_list"` is now formally defined in the schema spec (was a v2.1.0 gap)

## The output

After consolidation, `consolidated.md` contains:

- §1 Executive Summary (overall credibility: X% of claims verified true, Y% false, Z% unverified)
- §2 Claims Table (one row per claim with final verdict, confidence, top source)
- §3 Per-Claim Details (each reviewer's verdict + their evidence quote)
- §4 Conflicts & Resolutions (where reviewers disagreed; what the tie-break was)
- §5 Source Quality (which sources were cited most often; which were primary vs secondary)
- §6 Unverified Claims (which claims couldn't be settled — need human review)
- §7 False Claims (the ones confidently debunked; include counter-evidence)

## Custom strategies for fact-check

| Field | Recommended rule | Rationale |
|-------|-----------------|-----------|
| verdict | `majority-with-uncertain` | High-stakes: better to flag unverified than to mis-judge |
| confidence | `lowest-of-majors` | When reviewers disagree on confidence, defer to the least confident |
| evidence | `all-collected` | Concatenate all reviewers' quotes; deduplicate by source |
| sources | `union-dedup` | All sources from all reviewers; unique URLs only |
| counter_evidence | `concatenate-all` | Show all counter-evidence; user decides weight |

## Consensus requirements

For high-stakes fact-checking, set thresholds:
- **All N models agree on `true` with high confidence + primary source** → confirmed
- **All N models agree on `false` with high confidence + primary counter-source** → debunked
- **mixed verdicts or low confidence** → flagged for human review
- **no model could verify** → `unverified` (do not guess)

The `majority-with-uncertain` rule is strict-majority: any single dissent blocks consensus. For N=3 this means all 3 must agree; for N=5, at least 4; for N=7, at least 5. The algorithm is `> max(2, ceil(N/2))` — use the `majority` rule (any agreement is consensus) if you want a looser threshold.

## Worked example

Not yet produced (deferred to v2.2.0). The pattern follows the prior-art research example.
