# review-requirements — `.planning/rfl-plan-review-prompt/REQUIREMENTS.md`

Invoked as `/artifact-reviewer` → `review-requirements` with source_inputs[0] = `.planning/rfl-plan-review-prompt/SPEC.md`.

## Pass 1

```
status: "PASS"
findings:
  - id: "REQ-F00"
    severity: "INFO"
    description: "Derived-from points at scoped SPEC.md v1, not repo-root .planning/SPEC.md."
    location: "header"
    suggestion: "Keep scoped traceability."
```

QC-1 sections present.  
QC-2 REQ-nn / NFR-nn format.  
QC-3 IDs unique (REQ-01–09, NFR-01–05).  
QC-4 measurable ACs/metrics (grep headings, fixture counts, byte/line caps, 100% detection).  
QC-5 Priority P1/P2/P3 on every row.  
QC-6 Derived from field present.  
QC-7 SPEC ACs map to REQ-01–09.

## Pass 2 (consecutive)

```
status: "PASS"
findings: []
```

Two consecutive clean passes.
