# Semantic Context Compression — Design Spec

## Problem

Silver Bullet currently loads entire files into Claude's context window. For projects with large source files or extensive documentation, this wastes context budget on irrelevant content. GSD-2 solves this with TF-IDF ranked chunking — Silver Bullet has no equivalent.

## Solution

A PostToolUse hook that fires on GSD phase transitions. It extracts the phase goal from `.planning/` files, scores source and doc file chunks against that goal using TF-IDF, and injects the most relevant chunks into Claude's context via `hookSpecificOutput.additionalContext`.

## Architecture

### Components

#### 1. Hook registration (`hooks.json`)

A new PostToolUse entry matching the `Skill` tool. The hook script checks whether the invoked skill is a GSD phase command (`gsd:execute-phase`, `gsd:plan-phase`, `gsd:discuss-phase`, `gsd:research-phase`). If not, it exits immediately as a cheap no-op.

#### 2. Phase goal extractor (`scripts/extract-phase-goal.sh`)

Reads `.planning/` to find the current phase's context, research, or plan files. Extracts the phase goal text — typically the first heading or description block. Falls back to the roadmap phase entry if no planning files exist yet. Returns the goal as plain text to stdout.

**Input:** None (reads `.planning/` directory directly)
**Output:** Phase goal text to stdout, or empty string if no phase is active

#### 3. TF-IDF scoring engine (`scripts/tfidf-rank.sh`)

Pure shell implementation using `awk` and `sort` — no external dependencies beyond standard Unix tools.

**Input:** A query string (phase goal) via argument, file paths via stdin (one per line)
**Output:** Ranked chunks as tab-separated lines: `score\tfile_path\tstart_line\tend_line\tchunk_text`

**Algorithm:**
1. For each file >3KB, split into ~1KB chunks at blank-line boundaries. If a chunk exceeds 2KB with no blank-line break, force-split at 40-line intervals. No syntax-aware parsing — this is a text-level operation.
2. Compute term frequency (TF) for each chunk: count of each query term / total terms in chunk
3. Compute inverse document frequency (IDF) across all chunks: log(total_chunks / chunks_containing_term)
4. Score each chunk: sum of (TF × IDF) for each query term
5. Sort chunks by score descending

Files ≤3KB are not chunked — they pass through at maximum score.

#### 4. Context assembler (`scripts/semantic-compress.sh`)

Main orchestrator script called by the hook.

**Input:** None (reads config and `.planning/` directly)
**Output:** JSON to stdout for `hookSpecificOutput.additionalContext`

**Flow:**
1. Call `extract-phase-goal.sh` to get the query. If empty, exit 0 (no output).
2. Read `src_pattern` from `.silver-bullet.json` (default: `/src/`). Glob matching source files.
3. Glob `docs/**/*.md` for documentation files.
4. Partition files into ≤3KB (include in full) and >3KB (pass to `tfidf-rank.sh`).
5. Select top chunks within the context budget (default 50KB).
6. When budget is exceeded, prioritize source files over docs, then rank by TF-IDF score across all chunks.
7. Assemble output as a single text block with file/line annotations.
8. Write cache. Output JSON.

#### 5. Cache layer

Results cached at `.planning/.context-cache/{phase-name}.json`. Cache key is a hash of: concatenated input file mtimes + phase goal text. Uses `md5` on macOS, `md5sum` on Linux — the script detects which is available and normalizes the output. If cache is fresh, the hook returns cached output immediately. Cache invalidated when any source file changes or the phase goal changes.

**Staleness tolerance:** The cache is best-effort. If a file is modified between the mtime check and file read, the cache may store slightly stale content. This is acceptable — the context is supplementary, not authoritative, and the cache is invalidated on the next run when mtimes differ.

### Data Flow

```
Skill tool use (GSD phase command)
  → PostToolUse hook fires
    → hooks/semantic-compress.sh (gate: is this a GSD phase command?)
      → scripts/semantic-compress.sh
      → extract-phase-goal.sh → phase goal text
      → glob source files (src_pattern) + docs/**/*.md
      → partition by size (≤3KB full, >3KB chunked)
      → tfidf-rank.sh (query=phase goal, files=large files)
      → select top chunks within budget
      → write cache to .planning/.context-cache/
      → output additionalContext JSON
  → Claude receives compressed context
```

### Hook Output Format

```json
{
  "hookSpecificOutput": {
    "additionalContext": "## Semantic Context (auto-compressed)\n\n### src/auth/login.js (lines 45-82)\n```js\nfunction validateCredentials(user, pass) {\n  ...\n```\n\n### docs/Architecture-and-Design.md (lines 1-30)\n...\n"
  }
}
```

## Configuration

New section in `.silver-bullet.json`:

```json
{
  "semantic_compression": {
    "enabled": true,
    "context_budget_kb": 50,
    "min_file_size_bytes": 3072,
    "chunk_size_bytes": 1024,
    "top_chunks_per_file": 3
  }
}
```

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `enabled` | boolean | `true` | Master toggle for semantic compression |
| `context_budget_kb` | number | `50` | Maximum total output size in KB |
| `min_file_size_bytes` | number | `3072` | Files below this size are included in full |
| `chunk_size_bytes` | number | `1024` | Target chunk size for splitting large files |
| `top_chunks_per_file` | number | `3` | Maximum chunks to select per file (applied before budget trimming — keeps candidate set manageable) |
| `debug` | boolean | `false` | When true, writes detailed scoring log to `.planning/.context-cache/debug.log` |

**Note:** `src_pattern` is read from the top-level `project.src_pattern` field in `.silver-bullet.json`, not from the `semantic_compression` section.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| No `.planning/` files exist | Exit cleanly, no output |
| No files exceed 3KB | Include everything in full, no TF-IDF needed |
| Phase goal is empty or generic | Fall back to including the first 30 lines of each file (typically imports, module docstrings, top-level declarations) |
| Budget exceeded | Prioritize source over docs, then rank by score across all chunks |
| Binary files in source tree | Skip files that fail `file --mime-type` text check |
| `.silver-bullet.json` missing compression config | Use defaults |
| Compression disabled (`enabled: false`) | Exit cleanly, no output |

## File Inventory

| File | Type | Purpose |
|------|------|---------|
| `hooks/hooks.json` | Modified | Add PostToolUse entry for semantic compression |
| `hooks/semantic-compress.sh` | New | Thin hook wrapper — checks if skill is a GSD phase command, delegates to `scripts/semantic-compress.sh` |
| `scripts/semantic-compress.sh` | New | Main orchestrator — globs files, partitions, assembles output |
| `scripts/extract-phase-goal.sh` | New | Reads `.planning/` for current phase goal |
| `scripts/tfidf-rank.sh` | New | TF-IDF scoring engine (awk + sort) |
| `templates/silver-bullet.config.json.default` | Modified | Add `semantic_compression` defaults |

## What This Does NOT Do

- Does not replace Claude's own file reading — supplements context at phase transitions
- Does not modify source files
- Does not persist beyond the session — cache is ephemeral
- Does not run on every tool use — only on GSD phase command invocations
- Does not require any dependencies beyond standard Unix tools (awk, sort, find, jq) and either `md5` (macOS) or `md5sum` (Linux)

## Success Criteria

- Files >3KB are chunked and ranked; top chunks injected into context
- Files ≤3KB are included in full
- Total injected context stays within configured budget
- Cache prevents redundant computation within the same phase
- Hook is a no-op for non-GSD-phase skill invocations (< 10ms overhead)
- No external dependencies — runs on macOS and Linux with standard tools
