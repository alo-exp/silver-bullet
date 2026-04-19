---
name: silver-review-stats
description: "Reads .planning/review-analytics.jsonl and produces summary reports showing pass rates, average rounds, and common findings by artifact type"
argument-hint: "[--since YYYY-MM-DD] [--type artifact-type]"
version: 0.1.0
---

# silver-review-stats

Produces summary reports from review analytics data. Reads `.planning/review-analytics.jsonl` (and archived files in `.planning/archive/review-analytics-*.jsonl` if `--since` spans archived data) and aggregates metrics by artifact type.

## Usage

```
/silver-review-stats
/silver-review-stats --since 2026-04-01
/silver-review-stats --type SPEC.md
```

## Orchestration Steps

1. Locate `.planning/review-analytics.jsonl` — if missing, display "No review analytics data found. Run artifact reviews to generate data." and stop
2. If `--since` provided, also scan `.planning/archive/review-analytics-*.jsonl` for records after the date
3. Parse each line as JSON, filter by `--since` and/or `--type` if provided
4. Aggregate metrics and display the three report tables below
5. Display total record count and date range at the bottom

## Report Tables

### Table 1: Pass Rates by Artifact Type

| Artifact Type | Total Rounds | Pass | Fail | Pass Rate |
|---------------|-------------|------|------|-----------|
| SPEC.md | 12 | 8 | 4 | 66.7% |
| PLAN.md | 20 | 18 | 2 | 90.0% |

- Group by `artifact_type` field
- Pass = records where `status == "PASS"`, Fail = `status == "ISSUES_FOUND"`
- Pass Rate = Pass / Total Rounds * 100, formatted to 1 decimal

### Table 2: Rounds to Clean Pass by Artifact Type

| Artifact Type | Reviews | Avg Rounds | Min | Max |
|---------------|---------|------------|-----|-----|
| SPEC.md | 4 | 3.0 | 2 | 5 |
| PLAN.md | 8 | 1.5 | 1 | 3 |

- A "review" is a sequence of rounds for the same `artifact_path` (group by artifact_path, then count rounds per review session)
- Avg Rounds = average number of rounds per review session to reach clean pass
- Min/Max = minimum and maximum rounds across sessions

### Table 3: Common Finding Categories by Artifact Type

| Artifact Type | Avg Findings/Round | Total Findings | Most Active Reviewer |
|---------------|-------------------|----------------|---------------------|
| SPEC.md | 2.5 | 30 | review-spec |
| PLAN.md | 0.8 | 16 | gsd-plan-checker |

- Avg Findings/Round = sum(finding_count) / total rounds for that type
- Total Findings = sum(finding_count) for that type
- Most Active Reviewer = reviewer with the most rounds for that artifact type

### Footer

```
---
Total records: {N} | Date range: {earliest timestamp} to {latest timestamp}
Analytics file: .planning/review-analytics.jsonl ({line_count} lines)
```

## Edge Cases

- Empty analytics file: display "No review data recorded yet."
- All PASS: Tables still display with 100% pass rates
- Single round reviews: Avg Rounds = 1.0
- `--type` with no matches: display "No records found for artifact type '{type}'."
