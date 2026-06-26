# Example: Code Review using multi-ai-task

**This is an example use case for the multi-ai-task skill.** It shows how to use the skill for parallel code review by N models. The skill itself is task-agnostic — this is one example of many.

---

## The task

Get N independent code reviews of a pull request or a single file. Consolidate into one deduplicated finding list with conflict resolution for severity disagreements.

## The dispatch

```bash
# The prompt references the file/PR to review
PROMPT="Review the file at /path/to/code.py. For each finding, return:
- file:line
- severity: blocker | major | minor | nit
- category: bug | security | perf | style | design | test
- description (1-2 sentences)
- suggestion (optional, 1 sentence)
Return as a markdown table with these columns. Include EVIDENCE blocks with verbatim code quotes for each finding."

# Dispatch to N models
for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max; do
  npx -y opencode-ai run \
    --model "$model" \
    --title "code-review-$(date +%s)" \
    --dangerously-skip-permissions \
    "$PROMPT" \
    > "code-review-${model}.md" 2> "code-review-${model}.err" &
done
wait
```

## The schema (passed as --schema)

```json
{
  "type": "table",
  "primary_key": "file:line",
  "columns": [
    {"name": "file", "type": "string", "required": true},
    {"name": "line", "type": "number", "required": true},
    {"name": "severity", "type": "enum", "values": ["blocker", "major", "minor", "nit"]},
    {"name": "category", "type": "enum", "values": ["bug", "security", "perf", "style", "design", "test"]},
    {"name": "description", "type": "text", "max_words": 50},
    {"name": "suggestion", "type": "text", "max_words": 30},
    {"name": "evidence", "type": "string", "max_words": 50}
  ],
  "conflict_resolution": {
    "severity": "most-severe",
    "category": "majority"
  }
}
```

Key customization for code review:
- `dedup_key: "file:line"` — same line, same finding
- `severity: "most-severe"` — if any reviewer says "blocker", the consolidated finding is "blocker" (conservative)
- `category: "majority"` — most common category across reviewers

## The output

After consolidation, `consolidated.md` contains:

- §1 Executive Summary (overall code health, severity distribution, consensus issues)
- §2 Findings Table (deduped by `file:line`, with severity as max of reviewers)
- §3 Per-Finding Details (which reviewers flagged it, how strongly, what they said)
- §4 Conflicts & Resolutions (where reviewers disagreed on severity/category)
- §5 Per-Reviewer Statistics (how many findings each reviewer produced, false-positive rate if measurable)
- §6 Coverage Gaps (lines/areas no reviewer mentioned)
- §7 Open Questions (clarifications needed from the author)

## Custom strategies for code review

| Field | Recommended rule | Rationale |
|-------|-----------------|-----------|
| severity | `most-severe` | Safety: don't downgrade a blocker just because one reviewer missed it |
| category | `majority` | Most common classification is usually correct |
| description | `longest-with-quote` | Most detailed version + code quote is most useful |
| evidence | `concatenate-all` | Show all reviewers' quotes; duplicates are fine for verification |
| file:line | `merge-exact` | Same line = same finding; merge across reviewers |

## Variations

- **Deeper security review**: limit to `category: "security"` after consolidation; require `evidence` for every finding
- **Performance-only audit**: set `mode: "thorough"`, add `perf-budget-impact: optional` field to schema
- **Pre-commit hook**: combine with git diff to only review changed lines
- **Multi-file batch**: extend prompt to `find issues across N files`, dedup by `file:line` as before

## Worked example

Not yet produced. The pattern is identical to the prior-art research example — just swap the prompt, schema, and conflict rules.
