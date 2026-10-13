---
approved: yes
date: 2026-08-29
---

# Rung-prompt approval — world-class SPEC template

Policy E launch gate. Do not spawn reviewer Tasks or Pi invoke until `approved: yes`.

- Review both the implementation plan and the SPEC.md template contract (world-class for humans and AI).
- Review software-kind packs: required / optional / N/A sections for web, HTTP API, CLI, library/SDK, mobile, data/ML, infra/DevOps, plugin/extension, headless service — and how Clarify `--spec` asks only relevant turns.
- File findings that change the freeze’s template headings, frontmatter, IDs, GWT, and QCs — not plan-hygiene unless it breaks the template.
- KEEP REJECT: SPEC + REQUIREMENTS stay two files; Clarify does not write SPEC.md; ingest stays; no third kind canonical doc.
- **Policy G:** each review hop receives the **issue ledger** (`ISSUE-LEDGER.md` via `--issue-ledger` / `--write-review-brief`). Residual-only means do not re-report ledger rows, not “file only one new ID.”
- **Policy G:** file **all** valid residuals at the current SHA, **all severities** including nits (HIGH / MED / LOW / nit). CLEAN only if nothing valid remains.
- **Policy G:** triage REJECTS invalid items (already encoded, false cite, KEEP REJECT collision). All **ACCEPT**ed items — including nits — are **APPLY’d as a pack** that pass.
- Reviewer is review-only: no implement, no branch switch, no commit.
- Pin freeze `.planning/spec_template_world_class.plan.md` (do not dump SHA in this file as a freeze dump; one line path is enough).
- Ladder: Cursor GLM / Kimi / Gemini / Grok 4.6 High, then Pi GPT Sol High + Extra High, then Pi Claude Opus 5 High + Extra High. Verify = Grok 4.5 High native Cursor. Out of scope for reviewer: triage, APPLY, verify.
