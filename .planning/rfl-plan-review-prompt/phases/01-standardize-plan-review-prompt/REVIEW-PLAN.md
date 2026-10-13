# review-plan — `phases/01-standardize-plan-review-prompt/PLAN.md`

Invoked as `review-plan` with source inputs SPEC, REQUIREMENTS, CONTEXT.

## Pass 1 (ISSUES_FOUND — applied)

```
status: "ISSUES_FOUND"
findings:
  - id: "PLAN-F01"
    severity: "ISSUE"
    description: "Wave 1 verification used a placeholder test path ('path TBD' / 'implementation chooses')."
    location: "Wave 1 Expected files / Wave 5 verify commands"
    suggestion: "Name tests/scripts/test-rfl-plan-document-detection.sh and use it in verify commands."
```

Fix applied: concrete test path in Wave 1 and Wave 5.

## Pass 2

```
status: "PASS"
findings:
  - id: "PLAN-F02"
    severity: "INFO"
    description: "KEEP REJECT stays RFL-only by default in Wave 3; standalone review-plan may omit it."
    location: "Wave 3 Risks"
    suggestion: "Keep the RFL-only default."
```

QC: scope/non-goals/blast radius explicit; dependencies named; waves sequenced; ACs mapped to REQ-*; verify commands listed; risks/rollback present; optional script emitter is Follow-up-required not a silent blocker.

## Pass 3 (consecutive clean)

```
status: "PASS"
findings: []
```

Two consecutive clean passes after the PLAN-F01 fix.
