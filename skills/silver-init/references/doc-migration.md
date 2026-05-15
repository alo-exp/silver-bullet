# Documentation Migration — Detailed Reference

Used in Phase 3.5.5 of silver-init for existing projects with a `docs/` directory.

## Detection Scan (Step A)

```bash
echo "=== SCAN RESULTS ==="
for f in docs/Architecture*.md docs/architecture*.md docs/ARCHITECTURE*.md docs/design*.md docs/Design*.md docs/system-design*.md; do test -f "$f" && echo "ARCH: $f"; done
for f in docs/Testing*.md docs/testing*.md docs/TESTING*.md docs/test-plan*.md docs/test-strategy*.md; do test -f "$f" && echo "TEST: $f"; done
for f in docs/KNOWLEDGE*.md docs/knowledge*.md docs/decisions*.md docs/adr/*.md docs/ADR/*.md docs/learnings*.md docs/lessons*.md; do test -f "$f" && echo "KNOW: $f"; done
for f in docs/CHANGELOG*.md docs/changelog*.md docs/changes*.md; do test -f "$f" && echo "CLOG: $f"; done
for f in docs/CICD*.md docs/cicd*.md docs/CI*.md docs/ci-cd*.md docs/pipeline*.md docs/deploy*.md docs/deployment*.md; do test -f "$f" && echo "CICD: $f"; done
for f in docs/PRD*.md docs/prd*.md docs/requirements*.md docs/product*.md docs/spec*.md; do test -f "$f" && echo "PRD: $f"; done
for f in docs/API*.md docs/api*.md; do test -f "$f" && echo "API: $f"; done
for f in docs/SECURITY*.md docs/security*.md docs/threat-model*.md; do test -f "$f" && echo "SEC: $f"; done
echo "=== END SCAN ==="
```

## Migration Mapping Table (Step B)

| Detected Pattern | SB Target | Action |
|-----------------|-----------|--------|
| `Architecture-and-Design.md`, `architecture.md`, etc. | `docs/ARCHITECTURE.md` | Rename (preserve content) |
| `Testing-Strategy-and-Plan.md`, `test-plan.md`, etc. | `docs/TESTING.md` | Rename (preserve content) |
| `KNOWLEDGE.md` (single file) | `docs/knowledge/` directory | Split: project intelligence → `docs/knowledge/YYYY-MM.md`, portable lessons → `docs/lessons/YYYY-MM.md` |
| `changelog.md` (lowercase or variant) | `docs/CHANGELOG.md` | Rename (preserve content) |
| `cicd.md`, `pipeline.md`, `deploy.md` | `docs/CICD.md` | Rename (preserve content) |
| File already matches SB naming | — | Skip (no action needed) |
| Unrecognized doc | — | Leave in place (no action) |

## Executing Renames (Step D)

For each rename action:
1. Copy original to `<filename>.pre-sb-backup` using Bash (`cp`)
2. Rename using Bash (`mv <old> <new>`)
3. Confirm with user before proceeding to next step

## KNOWLEDGE.md Split Logic

1. Copy `docs/KNOWLEDGE.md` to `docs/KNOWLEDGE.md.pre-sb-backup`
2. Read full content and separate into two categories:
   - **Project-scoped intelligence** (architecture patterns, gotchas, decisions, project-specific recurring patterns, open questions) → `docs/knowledge/YYYY-MM.md`
   - **Portable lessons** (general lessons beyond this project — remove all project-specific file paths, feature names, and requirement IDs) → `docs/lessons/YYYY-MM.md`
3. Show user preview of split before writing
4. Create `docs/knowledge/INDEX.md` if it doesn't exist

## User Approval Flow

Present plan using AskUserQuestion:
- **A. Yes, proceed step by step** — execute and confirm each action individually
- **B. Show details first** — read each detected file (first 30 lines) and explain, then re-ask
- **C. Skip migration** — proceed to Step 3.6 without migration

## Migration Summary Output

```
✅ Documentation migration complete

Migrated:
- docs/Architecture-and-Design.md → docs/ARCHITECTURE.md
- docs/KNOWLEDGE.md → docs/knowledge/YYYY-MM.md + docs/lessons/YYYY-MM.md

Backups:
- docs/Architecture-and-Design.md.pre-sb-backup
- docs/KNOWLEDGE.md.pre-sb-backup

Untouched:
- docs/custom-guide.md (not part of SB scheme)
```
