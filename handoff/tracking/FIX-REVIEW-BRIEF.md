# Adversarial review of a fix package: shared brief (read all of it first)

A fix author has committed fixes for a set of review findings on a package branch, in a git worktree.
Your job is to verify those fixes before they are merged into `claude/optimistic-ramanujan-tccfud`.
Approval means: every finding the package claims is fixed really is fixed, nothing regressed, the tests
mean something, and the repository invariants hold.

Inputs (your task message gives the exact values):
- the package name, branch and worktree path;
- the author's report: `/tmp/claude-0/-home-user-silver-bullet/a8e36ab4-d9e2-56b2-b366-31e100f031d9/scratchpad/review/fix-<package>.json`;
- the original findings, with evidence and probes: `.../review/R<n>.json`;
- the briefs the author worked from: `.../review/FIX-BRIEF.md` (read it) and `.../review/BRIEF.md`.

## Rules

- **Graphify first.** A project hook requires `graphify query "<question>"` before you grep or read
  raw files. Then read the diff (`git -C <worktree> diff <merge-base>..HEAD`) and the changed files
  in full.
- **Do not modify the package branch or worktree.**
  - No commits.
  - No edits.
  - No checkout, stash or reset.
  - You may run tests from the worktree. For probes, use a sandbox under your probe directory with a
    temporary HOME, as `BRIEF.md` describes.
- **Resources are shared** (4 CPUs).
  - Run only the relevant test files, at most two at a time, through `bash tests/run-all-tests.sh <file>`.
  - Run at most one scoped coverage run, and never the full suite.
  - No network.
  - No real AI CLIs.
- **Process safety.**
  - Kill only processes you started, by exact PID; use `kill -TERM -- -<pgid>` for groups.
  - Don't touch `/sess-1.json` or `/sb-*.json`.
  - Set `PYTHONDONTWRITEBYTECODE=1`.
  - Never switch branches silently.
  - No Fast mode.

## What to check

1. **Each "fixed" finding**
   - Re-run the original reviewer's probe (from the finding's `evidence`) against the fixed code. It
     must no longer reproduce.
   - Then attack the fix: try new variants of the same bypass or bug class (the obfuscation catalog in
     `BRIEF.md`) and adjacent inputs. A fix that closes only the literal example is incomplete.
2. **Regressions and false positives**
   - Do honest, everyday commands and edits still work?
   - Do other hooks, hosts (Claude/Codex/Cursor payload shapes) and runtimes still behave?
   - Is macOS Bash 3.2 and BSD userland safe? No Bash 4 features in `hooks/`, and no GNU-only flags
     without a fallback.
   - Is per-call latency acceptable?
   - Are error messages accurate and actionable?
3. **Tests**
   - Do the new tests assert behaviour, so that reverting the fix makes them fail? Check at least the
     most important ones yourself: temporarily apply the inverse change in a *copy* of the files in your
     sandbox, never in the worktree.
   - Is anything asserted vacuously?
   - Were tests changed to pin defective behaviour?
4. **Invariants**
   - 100% coverage of the changed files: run one scoped coverage run with `--only` over the changed
     files and their tests.
   - `tests/coverage/known-limits.json` still valid.
   - `bash scripts/lint-shell.sh --all --jobs 2` and `bash scripts/check-repo-invariants.sh` clean.
   - Generated files fresh: `python3 scripts/generate-hook-reference.py --check`,
     `python3 scripts/generate-apo-artifacts.py --check`, `bash scripts/validate-plugin-mirror.sh`, and
     `bash scripts/sync-codex-package.sh` producing no diff when skills changed.
   - Template parity (`silver-bullet.md` vs `templates/silver-bullet.md.base`), and `docs/workflows` vs
     `templates/workflows`.
   - Commit trailers exactly as `FIX-BRIEF.md` requires, and no model names elsewhere in commits.
5. **Rejected / needs-user / partial dispositions**: is the reasoning sound and backed by evidence? A
   rejection of a real issue is a defect.
6. **Scope**
   - Are changes outside the package's ownership minimal and justified?
   - Any unrelated churn?
   - Anything that would conflict badly with sibling packages?

## Output

Write `/tmp/claude-0/-home-user-silver-bullet/a8e36ab4-d9e2-56b2-b366-31e100f031d9/scratchpad/review/review-fix-<package>.json`:

```json
{
  "package": "<name>", "head_reviewed": "<sha>", "verdict": "APPROVE|CHANGES_REQUIRED",
  "per_finding": [{"id": "R1-01", "verdict": "fixed|incomplete|regressed|wrongly-rejected|ok", "notes": "evidence"}],
  "issues": [{"severity": "blocker|major|minor", "location": "path:line", "problem": "...",
              "evidence": "exact probe and output", "suggested_fix": "..."}],
  "validation": {"tests": "...", "coverage": "...", "lint": "...", "invariants": "..."}
}
```

`APPROVE` only if there are no blocker or major issues. Your final message must be at most 300 words:
the verdict, the issue counts, and the most important issues.

## Disk hygiene (added 2026-11-05)
The session disk allowance is small. Keep probe copies (git archive / clones / exports) as small as possible and DELETE every full repo copy under your probe dir before you finish. Never leave more than ~100 MB in your probe dir.
