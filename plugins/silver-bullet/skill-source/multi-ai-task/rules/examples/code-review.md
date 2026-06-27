# Example: Code Review using multi-ai-task

**This is an example use case for the multi-ai-task skill.** It shows how to use the skill for parallel code review by N models. The skill itself is task-agnostic — this is one example of many.

---

## The task

Get N independent code reviews of a pull request or a single file. Consolidate into one deduplicated finding list with conflict resolution for severity disagreements.

## The dispatch

```bash
# Output dir convention
OUT=./multi-ai-out/$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"

# The prompt references the file/PR to review.
# Use a heredoc / file to avoid shell-metacharacter injection ($ and backticks in the prompt).
cat > "$OUT/prompt.md" <<'PROMPT'
Review the file at /path/to/code.py. For each finding, return a markdown table with these columns:
- file (string)
- line (number)
- severity (one of: blocker, major, minor, nit)
- category (one of: bug, security, perf, style, design, test)
- description (1-2 sentences)
- suggestion (optional, 1 sentence)

For each finding, include a verbatim code quote in the description or a separate "evidence" field.
PROMPT

# Dispatch to N models
for model in opencode-go/minimax-m3 opencode-go/qwen3.7-max; do
  slug=$(echo "$model" | cut -d/ -f2)  # sanitize "opencode-go/minimax-m3" -> "minimax-m3"
  npx -y opencode-ai run \
    --model "$model" \
    --title "code-review-${slug}-$(date +%s)" \
    "$OUT/prompt.md" \
    > "$OUT/${slug}.md" 2> "$OUT/${slug}.err" &
done
wait
echo "Outputs in $OUT/"
```

**Security note (READ-ONLY ONLY):** code review is a read-only task — the models just read and report, they don't write. So the dispatch above does **NOT** pass `--dangerously-skip-permissions`. If you want a review-and-fix variant (where models can apply edits), pass the flag and accept the risk. Per `rules/dispatch-mechanics.md:56`, this flag is wrong for write tasks but correct for read-only review.

## The schema (passed as --schema)

```json
{
  "type": "table",
  "columns": [
    {"name": "file",        "type": "string", "dedup_key": true,  "required": true},
    {"name": "line",        "type": "number", "dedup_key": true,  "required": true},
    {"name": "severity",    "type": "enum",   "values": ["blocker", "major", "minor", "nit"]},
    {"name": "category",    "type": "enum",   "values": ["bug", "security", "perf", "style", "design", "test"]},
    {"name": "description", "type": "text",   "max_words": 50},
    {"name": "suggestion",  "type": "text",   "max_words": 30},
    {"name": "evidence",    "type": "string", "max_words": 50}
  ],
  "conflict_resolution": {
    "severity": "most-severe",
    "category": "majority"
  }
}
```

**Composite primary key:** `file` AND `line` both have `dedup_key: true`. This is the canonical way to express a composite key (per `SKILL.md:143`). Two rows with the same `(file, line)` tuple are merged.

**Why `"primary_key": "file:line"` is wrong for composite keys:** the top-level `primary_key` field names a single column as the dedup key. For composite keys (file + line together), list multiple columns with `dedup_key: true` instead of concatenating column names with `:`. The schema above is the correct form for a composite key.

**Conflict-resolution note:** the default `severity_order` for `most-severe` is `["blocker", "major", "minor", "nit"]` (most-severe first; see `rules/consolidation-rules.md`). If a reviewer adds a custom severity (e.g., `critical`), declare it in the schema:
```json
"conflict_resolution": {
  "severity_order": ["critical", "blocker", "major", "minor", "nit"],
  "severity": "most-severe"
}
```

## The output

After consolidation, `consolidated.md` contains:

- §1 Executive Summary (overall code health, severity distribution, consensus issues)
- §2 Findings Table (deduped by `file:line`, with severity as max of reviewers)
- §3 Per-Finding Details (which reviewers flagged it, how strongly, what they said)
- §4 Conflicts & Resolutions (where reviewers disagreed on severity/category)
- §5 Per-Reviewer Statistics (how many findings each reviewer produced)
- §6 Coverage Gaps (lines/areas no reviewer mentioned)
- §7 Open Questions (clarifications needed from the author)

## Custom strategies for code review

| Field | Recommended rule | Rationale |
|-------|-----------------|-----------|
| severity | `most-severe` | Safety: don't downgrade a blocker just because one reviewer missed it |
| category | `majority` | Most common classification is usually correct |
| description | `longest-with-quote` | Most detailed version + code quote is most useful |
| evidence | `concatenate-all` | Show all reviewers' quotes; duplicates are fine for verification |
| file + line (composite) | (handled by `dedup_key: true` on both) | Same `(file, line)` tuple = same finding; merge across reviewers |

## Variations

- **Deeper security review**: limit to `category: "security"` after consolidation; require `evidence` for every finding
- **Performance-only audit**: set `mode: "thorough"`, add `perf-budget-impact: optional` field to schema
- **Pre-commit hook**: combine with git diff to only review changed lines (NOT currently supported as a built-in dispatch; requires custom runner)
- **Multi-file batch**: extend prompt to `find issues across N files`, dedup by `(file, line)` as before

## Worked example

Not yet produced (deferred to v2.2.0). The pattern follows the prior-art research example — just swap the prompt, schema, and conflict rules.
