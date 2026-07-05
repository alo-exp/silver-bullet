---
phase: quick-260409-trt
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - templates/silver-bullet.md.base
  - silver-bullet.md
autonomous: true
requirements: [step-non-skip-enforcement, iterative-artifact-review-rounds]
must_haves:
  truths:
    - "Section 3 explicitly lists mandatory post-execution artifacts (REVIEW.md, VERIFICATION.md) as non-skippable"
    - "Section 3a explicitly enumerates which artifact-producing steps require two-consecutive-clean-passes"
    - "A new subsection defines the artifact review checklist mapping step to required artifact"
  artifacts:
    - path: "templates/silver-bullet.md.base"
      provides: "Strengthened enforcement instructions"
      contains: "Post-Execution Artifact Requirements"
    - path: "silver-bullet.md"
      provides: "Live copy in sync with base"
      contains: "Post-Execution Artifact Requirements"
  key_links:
    - from: "templates/silver-bullet.md.base"
      to: "silver-bullet.md"
      via: "content sync"
      pattern: "Post-Execution Artifact Requirements"
---

<objective>
Strengthen silver-bullet.md.base sections 3 and 3a to close two enforcement gaps:
(1) Steps can be skipped when Claude manually drives execution instead of using skills
(2) The two-consecutive-clean-passes rule lacks explicit enumeration of which artifacts it applies to

Purpose: Prevent the orchestrator from bypassing post-execution review/verification steps
Output: Updated templates/silver-bullet.md.base and silver-bullet.md (kept in sync)
</objective>

<context>
@templates/silver-bullet.md.base (lines 362-476 — sections 3, 3a, 3b, 3c)
@silver-bullet.md (live copy — must mirror base after edits)
@hooks/completion-audit.sh (existing artifact existence checks at lines 278-297)
</context>

<tasks>

<task type="auto">
  <name>Task 1: Strengthen section 3 and 3a in silver-bullet.md.base</name>
  <files>templates/silver-bullet.md.base</files>
  <read_first>templates/silver-bullet.md.base (lines 362-476)</read_first>
  <action>
Make these edits to templates/silver-bullet.md.base:

**In section 3 (NON-NEGOTIABLE RULES), add to the "You MUST NOT" list after the existing bullets:**

```
- Execute a GSD phase (plan, execute, verify) without producing the phase's required artifacts — manually driving execution that bypasses skill-based workflows is a §3 violation
- Advance to the next GSD phase if the current phase is missing its required output artifacts (see §3d Post-Execution Artifact Requirements)
```

**In section 3a (Review Loop Enforcement), replace the opening paragraph with:**

```
Every review loop **MUST iterate until the reviewer returns Approved TWICE IN A ROW**. A single clean pass is not sufficient — the reviewer must find no issues on two consecutive passes. There are NO exceptions.

This rule applies to ALL artifact-producing review steps, specifically:

| Step | Artifact | Review Tool | Two-Pass Required |
|------|----------|-------------|-------------------|
| Plan creation | {phase}-NN-PLAN.md | /gsd:plan-checker | YES |
| Execution | Code changes + SUMMARY.md | /code-review | YES |
| Verification | VERIFICATION.md | /gsd:verify-work | YES (verify + re-verify) |
| Security check | Security findings | /silver:security | YES |

If ANY of these steps produces findings on the first pass, you MUST fix the findings and re-run the review. The step is complete ONLY after two consecutive clean passes.
```

**Add new section 3d after section 3c (Completion Claim Verification):**

```
## 3d. Post-Execution Artifact Requirements

Every GSD phase MUST produce its required artifacts. Advancing to the next phase
without these artifacts is a §3 violation regardless of how the phase was executed
(skill-based or manually driven).

| GSD Phase | Required Artifacts | Where |
|-----------|-------------------|-------|
| /gsd:discuss-phase | {phase}-CONTEXT.md | .planning/phases/{phase}/ |
| /gsd:plan-phase | {phase}-NN-PLAN.md (1+) | .planning/phases/{phase}/ |
| /gsd:execute-phase | {phase}-NN-SUMMARY.md per plan | .planning/phases/{phase}/ |
| /gsd:verify-work | VERIFICATION.md | .planning/phases/{phase}/ or project root |
| /code-review | REVIEW.md | .planning/phases/{phase}/ or project root |

**Pre-advance check:** Before invoking the NEXT phase's GSD command, verify the
PREVIOUS phase's artifacts exist. If they do not exist, STOP and either:
1. Run the missing step to produce the artifacts, OR
2. Explain to the user why the artifacts are missing and get explicit approval to skip

**Hook support:** The completion-audit hook (completion-audit.sh) performs artifact
existence checks at commit/PR/deploy time. But artifact checks at phase boundaries
are instruction-enforced because hooks cannot intercept GSD skill invocations
at the workflow level.

> **Anti-Skip:** You are violating this rule if you invoke /gsd:execute-phase
> without a PLAN.md existing, or invoke /gsd:verify-work without SUMMARY.md
> files from execution, or create a PR without VERIFICATION.md and REVIEW.md.
```
  </action>
  <verify>
    <automated>grep -c "Post-Execution Artifact Requirements" templates/silver-bullet.md.base | grep -q "^[1-9]" && grep -c "Two-Pass Required" templates/silver-bullet.md.base | grep -q "^[1-9]" && grep -c "Pre-advance check" templates/silver-bullet.md.base | grep -q "^[1-9]" && echo "PASS"</automated>
  </verify>
  <acceptance_criteria>
    - grep "Post-Execution Artifact Requirements" templates/silver-bullet.md.base returns matches
    - grep "Two-Pass Required" templates/silver-bullet.md.base returns matches
    - grep "Pre-advance check" templates/silver-bullet.md.base returns matches
    - grep "manually driving execution" templates/silver-bullet.md.base returns matches
    - Section numbering is consistent (3, 3a, 3b, 3c, 3d)
  </acceptance_criteria>
  <done>Section 3 has two new MUST NOT bullets, section 3a has explicit artifact-review table, new section 3d defines post-execution artifact requirements with pre-advance checks</done>
</task>

<task type="auto">
  <name>Task 2: Sync silver-bullet.md with updated base template</name>
  <files>silver-bullet.md</files>
  <read_first>silver-bullet.md (lines 362-476 equivalent — find §3 location), templates/silver-bullet.md.base (updated §3-§3d)</read_first>
  <action>
Apply the identical changes from Task 1 to silver-bullet.md. The live copy must mirror the base template for sections 3, 3a, and the new 3d.

Specifically:
1. Find section "## 3. NON-NEGOTIABLE RULES" in silver-bullet.md
2. Add the same two new MUST NOT bullets about executing without artifacts and advancing without artifacts
3. Replace section 3a opening with the same table-based enumeration
4. Add section 3d (Post-Execution Artifact Requirements) after 3c, identical content to base

Note: silver-bullet.md may have project-specific template variables resolved (e.g., project name). Preserve those — only change the §3/3a/3d content.
  </action>
  <verify>
    <automated>grep -c "Post-Execution Artifact Requirements" silver-bullet.md | grep -q "^[1-9]" && grep -c "Two-Pass Required" silver-bullet.md | grep -q "^[1-9]" && grep -c "Pre-advance check" silver-bullet.md | grep -q "^[1-9]" && echo "PASS"</automated>
  </verify>
  <acceptance_criteria>
    - grep "Post-Execution Artifact Requirements" silver-bullet.md returns matches
    - grep "Two-Pass Required" silver-bullet.md returns matches
    - grep "Pre-advance check" silver-bullet.md returns matches
    - grep "manually driving execution" silver-bullet.md returns matches
    - Sections 3, 3a, 3d content matches templates/silver-bullet.md.base (modulo template variables)
  </acceptance_criteria>
  <done>silver-bullet.md is in sync with templates/silver-bullet.md.base for all modified sections</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Instruction -> Behavior | Claude reads instructions but may rationalize skipping them |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-quick-01 | Tampering | silver-bullet.md | mitigate | dev-cycle-check.sh blocks edits to SB hooks; base template serves as source of truth |
| T-quick-02 | Elevation | §3 bypass via rationalization | mitigate | Explicit artifact table + anti-skip callouts reduce ambiguity that enables rationalization |
</threat_model>

<verification>
1. `grep "Post-Execution Artifact Requirements" templates/silver-bullet.md.base` returns match
2. `grep "Two-Pass Required" templates/silver-bullet.md.base` returns match
3. `diff <(sed -n '/## 3\. NON-NEGOTIABLE/,/## 4\./p' templates/silver-bullet.md.base) <(sed -n '/## 3\. NON-NEGOTIABLE/,/## 4\./p' silver-bullet.md)` shows only template variable differences
</verification>

<success_criteria>
- templates/silver-bullet.md.base contains strengthened §3, enumerated §3a, and new §3d
- silver-bullet.md mirrors the changes
- No existing section numbering or content is broken
</success_criteria>

<output>
After completion, create `.planning/quick/260409-trt-add-step-non-skip-enforcement-and-iterat/01-SUMMARY.md`
</output>
