# review-spec — `.planning/rfl-plan-review-prompt/SPEC.md`

Invoked as `/artifact-reviewer` → `review-spec` (in-session; no nested Task). Depth: full. Source inputs: none.

## Pass 1

```
status: "PASS"
findings:
  - id: "SPEC-F00"
    severity: "INFO"
    description: "Scoped path used instead of repo-root .planning/SPEC.md to avoid clobbering v0.35.0 SB/GSD alignment spec."
    location: "frontmatter planning-root"
    suggestion: "Keep scoped path; documented in CONTEXT.md."
```

QC-1 sections: Overview, User Stories, UX Flows, Acceptance Criteria, Assumptions, Open Questions, Out of Scope, Implementations — present.  
QC-2 Overview names launchers/rungs and the inconsistent-prompt problem.  
QC-3 ≥1 story with As a / I want to / so that.  
QC-4 measurable ACs (named template, grep markers, detection rule, tests).  
QC-5 every ASSUMPTION has Status.  
QC-6 frontmatter spec-version, status, created, last-updated set.  
QC-7 skipped (no JIRA/Figma).

## Pass 2 (consecutive)

```
status: "PASS"
findings: []
```

Two consecutive clean passes. Proceed to REQUIREMENTS.
