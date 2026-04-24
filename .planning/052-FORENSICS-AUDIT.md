# Forensics Audit Report — Phase 052

**Audit date:** 2026-04-24
**Auditor:** Claude (automated)
**Subject:** skills/silver-forensics/SKILL.md
**Reference:** ~/.claude/skills/gsd-forensics/SKILL.md + ~/.claude/get-shit-done/workflows/forensics.md
**Requirement:** FORN-01

---

## Dimension 1 — Session Classification Paths

**silver-forensics:** Step 2c defines three classification paths in a table:
- **Session-level** — triggered when: timeout flag present; session log shows incomplete outcome; stall/timeout/hang described
- **Task-level** — triggered when: specific task or phase named; commits present but output is wrong; tests failing after recent commits
- **General** — triggered when: does not fit neatly into the above; open-ended

These three paths correspond to dedicated investigation sections: Path 1 (Session-level), Path 2 (Task-level), and Path 3 (General). Path 3 acts as a funnel that re-classifies into Path 1 or Path 2 based on evidence.

**gsd-forensics:** The forensics.md workflow (Step 3) uses six named anomaly detection patterns rather than up-front path classification:
- **Stuck Loop** — same file in 3+ consecutive commits within a short time window (HIGH confidence if messages similar, MEDIUM if varied)
- **Missing Artifact** — phase is past in roadmap but PLAN.md, SUMMARY.md, or VERIFICATION.md absent
- **Abandoned Work** — large gap between last commit and current time with STATE.md showing mid-execution
- **Crash/Interruption** — uncommitted changes + active STATE.md entry + orphaned worktrees
- **Scope Drift** — recent commits touch files outside the current phase's expected scope (per PLAN.md)
- **Test Regression** — commit messages containing "fix test", "revert", "broken", "regression", "fail"

**Mapping analysis:**
- Path 1 (Session-level) maps to: Abandoned Work + Crash/Interruption + Missing Artifact (all are session-integrity failure modes)
- Path 2 (Task-level) maps to: Stuck Loop + Scope Drift + Test Regression (all are task-execution failure modes)
- Path 3 (General) is a disambiguation funnel, not an anomaly type — it terminates in Path 1 or Path 2

**Gap assessment:**
- **Scope Drift detection:** gsd-forensics Step 3 explicitly instructs reading the current phase PLAN.md and comparing its expected file paths against actual recent commits. silver-forensics has no equivalent scope-drift detection step in any path. Path 2 (Task-level) compares plan intent vs. actual diff but only for a named task — it does not scan recent commits for files outside the phase domain.
- **Test Regression detection:** gsd-forensics Step 3 runs `git log --oneline -20 | grep -iE "fix test|revert|broken|regression|fail"` as a dedicated anomaly check. silver-forensics Path 2 runs the test suite and reads the session log, but has no commit-message grep pattern for regression signals.
- **Stuck Loop detection:** gsd-forensics uses `git log --name-only --format="---COMMIT---" -20` to detect repeated edits to the same file across consecutive commits. silver-forensics has no equivalent.

**Verdict:** Gap — silver-forensics classification paths are semantically present (Session-level/Task-level/General map to the gsd-forensics anomaly groupings), but silver-forensics is missing three specific detection sub-procedures: (1) scope-drift file comparison, (2) commit-message grep for regression signals, and (3) stuck-loop repeated-edit detection.

---

## Dimension 2 — Evidence-Gathering Steps

**silver-forensics:** Step 2b specifies four parallel quick-scan items:
1. Most recent session log in `<project-root>/docs/sessions/` — glob `docs/sessions/*.md`, sort by name descending, take first
2. `git log --oneline -10`
3. Presence of `~/.claude/.silver-bullet/timeout` (was sentinel triggered?)
4. `.planning/` directory — any incomplete phase markers

**gsd-forensics:** The forensics.md workflow Step 2 specifies five sub-steps with more granular commands:
- **2a. Git History** — `git log --oneline -30`; `git log --format="%H %ai %s" -30` (timestamped for gap analysis); `git log --name-only --format="" -20 | sort | uniq -c | sort -rn | head -20` (files-changed uniq-count for stuck-loop detection); `git status --short`; `git diff --stat`
- **2b. Planning State** — Read `.planning/STATE.md` (current milestone, phase, progress, blockers, last session), `.planning/ROADMAP.md` (phase list with status), `.planning/config.json` (workflow configuration)
- **2c. Phase Artifact Completeness** — For each `.planning/phases/*/`, check which of PLAN.md, SUMMARY.md, VERIFICATION.md, CONTEXT.md, RESEARCH.md are present; track which phases have complete vs. gapped artifact sets
- **2d. Session Reports** — Read `.planning/reports/SESSION_REPORT.md` if it exists; extract last session outcomes, work completed, token estimates
- **2e. Git Worktree State** — `git worktree list`; check for orphaned worktrees from crashed agents

**Gap assessment — missing in silver-forensics:**

1. **Timestamped git log (`git log --format="%H %ai %s" -30`):** silver-forensics only runs `git log --oneline -10`. No timestamp-based gap analysis is performed. The gsd-forensics timestamped format enables detecting time gaps between commits (abandoned work signal).

2. **Files-changed uniq-count (`git log --name-only ... | sort | uniq -c`):** silver-forensics has no equivalent. This command is the foundation of gsd-forensics's stuck-loop detection (Dimension 1 gap).

3. **`git status --short` and `git diff --stat` in evidence gathering:** silver-forensics does run `git log` and `git show` in Path 2 and `git status` in Path 3, but the initial evidence-gathering step (Step 2b) does not include `git status --short` or `git diff --stat`. These are the signals for crash/interruption detection (uncommitted changes).

4. **`.planning/STATE.md` and `config.json` in evidence gathering:** silver-forensics Step 2b reads `.planning/` directory generically for "incomplete phase markers". It does not explicitly read STATE.md, ROADMAP.md, and config.json as separate structured evidence items. Path 1 Step 4 reads ROADMAP.md, but it is not part of the initial parallel scan.

5. **Phase artifact completeness matrix:** gsd-forensics Step 2c explicitly checks each phase directory for all five artifact types (PLAN, SUMMARY, VERIFICATION, CONTEXT, RESEARCH) and produces a completeness matrix. silver-forensics has no equivalent — Path 1 Step 4 checks only VERIFICATION.md presence per ROADMAP.md entries, not a full artifact matrix across all phases.

6. **SESSION_REPORT.md (Step 2d):** silver-forensics reads session logs from `docs/sessions/` but has no reference to `.planning/reports/SESSION_REPORT.md`. This is a GSD-specific artifact that silver-forensics's Step 2b does not include.

7. **`git worktree list` (Step 2e):** silver-forensics has no worktree state check. The absence of this command means crashed parallel agents leaving orphaned worktrees are invisible to the investigation.

**Verdict:** Gap — silver-forensics covers 2 of 7 evidence sub-items (recent session log + basic git log). Missing: timestamped git log, files-changed uniq-count, git status/diff in initial scan, STATE.md + ROADMAP.md + config.json as structured evidence, phase artifact completeness matrix, SESSION_REPORT.md, and git worktree list.

---

## Dimension 3 — GSD-Awareness Routing Table

**silver-forensics:** Step 1b provides a GSD-awareness routing table that classifies incoming issues and routes GSD-specific ones to `/gsd-forensics`. The quick-check runs three checks in parallel:
1. Does `.planning/` exist with phase directories?
2. Does the user description mention GSD-specific terms (plan drift, execution failure, stuck loop, missing artifacts, scope drift, worktree issues, specific phase/plan number)?
3. Are there `.planning/phases/*/SUMMARY.md` files indicating GSD execution happened?

The routing table maps evidence to routes: GSD execution anomalies → `/gsd-forensics`; session timeout/stall/SB enforcement failures → SB silver-forensics (continue Step 2); general investigation → SB silver-forensics; unclear → SB silver-forensics (Path 3 can further delegate).

**gsd-forensics:** N/A — gsd-forensics is itself the route destination. It has no equivalent routing table; it assumes all invocations are GSD-specific workflow investigations.

**Verdict:** Equivalent (dimension not applicable to reference skill). silver-forensics has this dimension; gsd-forensics does not require it because it is the endpoint. No gap.

---

## Dimension 4 — Root-Cause Statement Format

**silver-forensics:** The section "Root cause statement format (all paths)" mandates:
```
ROOT CAUSE: <one sentence> — <path taken> — <confidence: high/medium/low>
```
This structured one-liner appears as a dedicated section between the path sections and the post-mortem report section, and is described as required at the end of every investigation ("End every investigation with:"). The post-mortem report schema's `## Root Cause` section instructs: "\<one-sentence root cause statement\>".

**gsd-forensics:** The forensics.md workflow Step 4 (Generate Report) uses a "Root Cause Hypothesis" section in the report with a prose format:
```
## Root Cause Hypothesis

Based on the evidence above, the most likely explanation is:

{1-3 sentence hypothesis grounded in the anomalies}
```
There is no structured one-liner with explicit path and confidence fields. The confidence level (HIGH/MEDIUM/LOW) appears only in the `## Anomalies Detected` section headers, not in the root cause statement itself.

**Gap assessment:** Both skills require a root cause statement. silver-forensics enforces a more structured one-liner format with explicit path and confidence fields, which is more rigorous than gsd-forensics's prose hypothesis. However, silver-forensics's post-mortem report schema places the root cause inside a `## Root Cause` section with just a one-sentence statement — it does not carry the structured `ROOT CAUSE: ... — ... — confidence: ...` format into the report markdown itself. The format is required at investigation end but not enforced in the written report section.

**Verdict:** Equivalent — silver-forensics's root-cause statement format is at least as structured as gsd-forensics's and adds explicit path and confidence tracking. No gap requiring a fix.

---

## Dimension 5 — Post-Mortem Report Schema

**silver-forensics:** Writes to `<project-root>/docs/silver-forensics/YYYY-MM-DD-<slug>.md`. Report sections:
- Header (Date, Session log, Path taken, Confidence)
- `## Symptom` — user's original description
- `## Evidence Gathered` — bullet list: Session log, Git history, Planning artifacts, Test output, Sentinel/timeout flags
- `## Root Cause` — one-sentence root cause statement
- `## Contributing Factors` — bullet list
- `## Recommended Next Steps` — classification-to-action routing table + checkbox action list
- `## Prevention` — one sentence

**gsd-forensics:** Writes to `.planning/forensics/report-{timestamp}.md`. Report sections:
- Header (Generated timestamp, Problem)
- `## Evidence Summary` containing three sub-sections:
  - `### Git Activity` — structured fields: Last commit, Commits count, Time span, Uncommitted changes, Active worktrees
  - `### Planning State` — structured fields: Current milestone, Current phase, Last session, Blockers
  - `### Artifact Completeness` — markdown table with rows for each phase and columns for PLAN/CONTEXT/RESEARCH/SUMMARY/VERIFICATION (checkmarks)
- `## Anomalies Detected` — one `### {Anomaly Type} — {Confidence: HIGH/MEDIUM/LOW}` sub-section per anomaly with Evidence and Interpretation fields
- `## Root Cause Hypothesis` — 1-3 sentence prose hypothesis
- `## Recommended Actions` — numbered list with recovery commands (e.g., `/gsd-resume-work`)
- Footer: redaction note

**Gap assessment:**

1. **Artifact completeness matrix table:** gsd-forensics includes a structured table (`| Phase | PLAN | CONTEXT | RESEARCH | SUMMARY | VERIFICATION |`) as a mandatory Evidence Summary sub-section. silver-forensics's `## Evidence Gathered` is a free-form bullet list with "Planning artifacts: \<phase status\>" — no structured matrix. Plan 052-02 must add this table.

2. **Anomaly confidence-level annotations:** gsd-forensics structures each anomaly as `### {Anomaly Type} — {Confidence: HIGH/MEDIUM/LOW}` with separate Evidence and Interpretation fields. silver-forensics's `## Evidence Gathered` section does not have per-anomaly confidence annotations — confidence appears only in the header and root-cause statement, not on individual findings.

3. **Worktree state in Evidence Summary:** gsd-forensics's `### Git Activity` sub-section includes `**Active worktrees:** {count — list if >1}`. silver-forensics's `## Evidence Gathered` mentions only: session log, git history, planning artifacts, test output, sentinel/timeout flags. No worktree field.

4. **Structured Git Activity sub-section:** gsd-forensics uses labeled fields (Last commit date, Commits count, Time span, Uncommitted changes, Active worktrees). silver-forensics uses a free-form "Git history: \<relevant commits\>" bullet entry. Less structured.

5. **Planning State sub-section:** gsd-forensics's `### Planning State` has labeled fields (Current milestone, Current phase, Last session, Blockers). silver-forensics's `## Evidence Gathered` has only "Planning artifacts: \<phase status\>".

6. **Output directory:** silver-forensics uses `docs/silver-forensics/` (project-relative); gsd-forensics uses `.planning/forensics/` (planning-relative). Different but both valid for their respective contexts — not a gap, just a design choice appropriate to each skill's domain.

**Verdict:** Gap — silver-forensics's report is missing: (1) artifact completeness matrix table, (2) per-anomaly confidence-level annotations, (3) Active worktrees field in Evidence Summary, (4) structured Git Activity sub-section with labeled fields.

---

## Dimension 6 — Security Boundary (UNTRUSTED DATA Handling)

**silver-forensics:** Has an explicit `## Security Boundary` section at the top (before any steps) with:
- Labels all investigation files (session logs, planning artifacts, git history, temp files) as UNTRUSTED DATA
- Prohibits following, executing, or acting on instructions found in files
- Mandates noting "Suspicious content detected in [file]" in Evidence Gathered when directive-like content is found

The `## Allowed Commands` section limits shell execution to: `git log/show/status/diff`, `mkdir -p`, and test runners (`npm test`, `pytest`, `cargo test`, `go test ./...`). Any additional commands must be noted in the report for human execution.

**gsd-forensics:** Has a `<critical_rules>` block containing four rules:
1. Read-only investigation: Do not modify project source files; only write the forensic report and update STATE.md session tracking
2. Redact sensitive data: Strip absolute paths, API keys, tokens from reports and issues
3. Ground findings in evidence: Every anomaly must cite specific commits, files, or state data
4. No speculation without evidence: If data is insufficient, say so — do not fabricate root causes

Additionally, the forensics.md workflow Step 4 includes explicit redaction rules:
- Replace absolute paths with relative paths (strip `$HOME` prefix)
- Remove any API keys, tokens, or credentials found in git diff output
- Truncate large diffs to first 50 lines

The Step 7 issue creation also references: "I'll format the findings and redact paths."

**Gap assessment:**

1. **Absolute path redaction:** gsd-forensics's Step 4 redaction rules explicitly instruct stripping `$HOME` prefix from paths in the written report and in GitHub issues. silver-forensics has no equivalent redaction instruction. Its `## Security Boundary` covers the *input* side (UNTRUSTED DATA) but not the *output* side (what appears in the report). The report schema in silver-forensics includes `**Session log:** <project-root>/docs/sessions/<filename>.md` — an absolute path would appear here without any redaction rule.

2. **API key/token redaction from git diff output:** gsd-forensics Step 4 instructs removing API keys, tokens, or credentials found in git diff output before writing the report. silver-forensics allows `git show <commit>` and `git diff` but has no instruction to redact credentials found in diff output.

3. **Diff truncation:** gsd-forensics truncates large diffs to 50 lines. silver-forensics has no equivalent size limit on evidence included in the report.

4. **Read-only enforcement scope:** silver-forensics's `## Allowed Commands` restricts shell commands more strictly than gsd-forensics's critical_rules, which allows any read commands but restricts writes. Both achieve read-only investigation, but silver-forensics's allowed-commands list is tighter. This is a silver-forensics strength, not a gap.

5. **UNTRUSTED DATA / anti-injection:** silver-forensics explicitly addresses the AI-specific risk of acting on instructions found in files. gsd-forensics has no equivalent. This is a silver-forensics strength, not a gap.

**Verdict:** Gap — silver-forensics's security boundary covers UNTRUSTED DATA (input) and instruction injection (AI-specific risk) well, but is missing output-side redaction rules: (1) no instruction to strip absolute paths from the written report, (2) no instruction to redact API keys/tokens found in git diff output, (3) no diff truncation limit.

---

## Gaps Found

| ID | Dimension | Description | Fix Required |
|----|-----------|-------------|--------------|
| G-01 | 1 | No scope-drift detection step | Add a scope-drift check to Path 2 (and/or Step 2b): read current phase PLAN.md, compare its expected file paths against files modified in recent commits (`git log --name-only -20`), flag any out-of-scope files |
| G-02 | 1 | No test-regression commit-message grep | Add to Path 2 Step 5 (or Step 2b): `git log --oneline -20 \| grep -iE "fix test\|revert\|broken\|regression\|fail"` as a dedicated regression-signal check before running the test suite |
| G-03 | 1 | No stuck-loop repeated-edit detection | Add to Step 2b (or as a new sub-step): `git log --name-only --format="---COMMIT---" -20` with logic to flag any file appearing in 3+ consecutive commits; confidence HIGH if commit messages similar |
| G-04 | 2 | git log only fetches 10 commits, no timestamps | Expand Step 2b item 2 to: `git log --oneline -30` AND `git log --format="%H %ai %s" -30` for time-gap analysis |
| G-05 | 2 | No `git status --short` or `git diff --stat` in initial scan | Add `git status --short` and `git diff --stat` to Step 2b as parallel evidence items (crash/interruption signal: uncommitted changes) |
| G-06 | 2 | No phase artifact completeness matrix | Add Step 2b item: for each `.planning/phases/*/`, check presence of PLAN.md, SUMMARY.md, VERIFICATION.md, CONTEXT.md, RESEARCH.md; record completeness per phase |
| G-07 | 2 | SESSION_REPORT.md not in evidence scope | Add Step 2b item: read `.planning/reports/SESSION_REPORT.md` if it exists; extract last session outcomes |
| G-08 | 2 | No `git worktree list` check | Add Step 2b item: `git worktree list` — check for orphaned worktrees from crashed agents |
| G-09 | 5 | Report missing artifact completeness matrix table | Add `### Artifact Completeness` sub-section to `## Evidence Gathered` in the post-mortem report schema: markdown table with Phase | PLAN | CONTEXT | RESEARCH | SUMMARY | VERIFICATION columns |
| G-10 | 5 | No per-anomaly confidence annotations in report | Add per-finding confidence level to `## Evidence Gathered` entries (e.g., `- Git history [MEDIUM]: <finding>`) or add a dedicated `## Anomalies Detected` section with per-anomaly confidence headings |
| G-11 | 5 | Worktree state missing from report Evidence Gathered | Add `- Worktrees: <count — list if >1>` to the `## Evidence Gathered` bullet list in the post-mortem report schema |
| G-12 | 6 | No output-side path redaction rule | Add a redaction instruction to the post-mortem report section: strip absolute paths (replace `$HOME` with `~`) in all report fields; this applies to session log paths, planning artifact paths, and git diff output |
| G-13 | 6 | No API key/token redaction from diff output | Add to the post-mortem report section: before writing evidence from `git show` or `git diff` output, scan for and remove API keys, tokens, or credentials; truncate large diffs to 50 lines |

---

## Summary

- Dimensions with gaps: 4 of 6 (Dimensions 1, 2, 5, 6)
- Total gaps: 13
- Gaps requiring SKILL.md edits: 13 (all)
- Dimensions equivalent: Dimension 3 (GSD-awareness routing, N/A to reference), Dimension 4 (root-cause statement format)

---

## Fix Log

Applied fixes from the ## Gaps Found table to `skills/silver-forensics/SKILL.md` (commit 0673b3a).

| Gap ID | Dimension | Change Made | Status |
|--------|-----------|-------------|--------|
| G-01 | 1 | Added scope-drift check to Path 2 Step 4: read PLAN.md `files_modified`, compare against `git log --name-only -20` output, flag out-of-scope files | FIXED |
| G-02 | 1 | Added regression signal step to Path 2 Step 6: `git log --oneline -20 \| grep -iE "fix test\|revert\|broken\|regression\|fail"` before test execution | FIXED |
| G-03 | 1 | Added file-frequency analysis to Step 2b item 3: `git log --name-only --format="" -20 \| sort \| uniq -c \| sort -rn \| head -20`; flag 3+ consecutive edits to same file | FIXED |
| G-04 | 2 | Expanded Step 2b git log from `-10` to `-30`; added parallel timestamped call `git log --format="%H %ai %s" -30` for gap analysis | FIXED |
| G-05 | 2 | Added `git status --short` and `git diff --stat` to Step 2b item 4 as crash/interruption detection signals | FIXED |
| G-06 | 2 | Added phase artifact completeness check to Step 2b item 6: enumerate `.planning/phases/*/`, record presence of PLAN.md, SUMMARY.md, VERIFICATION.md, CONTEXT.md, RESEARCH.md per phase | FIXED |
| G-07 | 2 | Added SESSION_REPORT.md to Step 2b item 7: read `.planning/reports/SESSION_REPORT.md` if present, extract last session outcomes | FIXED |
| G-08 | 2 | Added `git worktree list` to Step 2b item 8; >1 worktree flagged as orphaned/crash signal | FIXED |
| G-09 | 5 | Added `### Artifact Completeness` sub-section with Phase/PLAN/CONTEXT/RESEARCH/SUMMARY/VERIFICATION matrix table to post-mortem report Evidence Gathered | FIXED |
| G-10 | 5 | Added per-finding `— Confidence: HIGH \| MEDIUM \| LOW` annotation to all Evidence Gathered bullet entries in report schema | FIXED |
| G-11 | 5 | Added `- Worktrees: <count — list if >1>` field to Evidence Gathered section in report schema | FIXED |
| G-12 | 6 | Added output-side path redaction rule to Security Boundary: strip `$HOME` prefix, use `~` or project-relative form in all report fields | FIXED |
| G-13 | 6 | Added API key/token redaction + 50-line diff truncation rule to Security Boundary; applies before writing Evidence Gathered excerpts from `git show`/`git diff` | FIXED |

**Invariants preserved:**
- GSD-awareness routing table (Step 1b): intact
- Three-path classification model (Session-level / Task-level / General): intact
- ROOT CAUSE one-liner format (`ROOT CAUSE: <sentence> — <path> — <confidence>`): intact
- Slug-based collision-safe naming (`YYYY-MM-DD-<slug>.md`): intact
- Allowed Commands security section: intact
- Output directory (`docs/silver-forensics/`): intact

**FORN-02 status:** All 13 gaps fixed. `skills/silver-forensics/SKILL.md` is now functionally equivalent to `gsd-forensics` across all six dimensions.
