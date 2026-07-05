---
phase: quick
plan: 260408-tfp
type: execute
wave: 1
depends_on: []
files_modified:
  - silver-bullet.md
  - templates/silver-bullet.md.base
autonomous: true
must_haves:
  truths:
    - "§2h SB Orchestrated Workflows section exists in silver-bullet.md"
    - "§2h SB Orchestrated Workflows section exists in templates/silver-bullet.md.base"
    - "Both files contain identical §2h content"
    - "§2h appears between the §2g closing --- and ## 3. NON-NEGOTIABLE RULES"
  artifacts:
    - path: "silver-bullet.md"
      contains: "2h. SB Orchestrated Workflows"
    - path: "templates/silver-bullet.md.base"
      contains: "2h. SB Orchestrated Workflows"
---

<objective>
Insert the §2h SB Orchestrated Workflows section into both silver-bullet.md and
templates/silver-bullet.md.base at the correct position: after the closing --- of §2g
and before ## 3. NON-NEGOTIABLE RULES.

Purpose: Document the seven pre-designed orchestration workflows that SB routes tasks through.
Output: Both files updated identically with the new §2h section.
</objective>

<execution_context>
@${SB_RUNTIME_HOME_ROOT}/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@/Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md
@/Users/shafqat/Documents/Projects/silver-bullet/templates/silver-bullet.md.base
</context>

<tasks>

<task type="auto">
  <name>Task 1: Insert §2h into silver-bullet.md</name>
  <files>/Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md</files>
  <action>
Read silver-bullet.md. Find the line containing only `---` that immediately precedes
`## 3. NON-NEGOTIABLE RULES` (around line 282). Insert the following block between
that `---` line and the `## 3. NON-NEGOTIABLE RULES` heading:

```
### 2h. SB Orchestrated Workflows

SB provides seven pre-designed orchestration workflows for all common development tasks.
When a bare instruction is intercepted (§2g) or the user invokes `/silver`, the router
classifies intent and dispatches to the appropriate workflow.

**The seven workflows:**

| Workflow | Entry triggers | First step |
|----------|---------------|------------|
| `silver:feature` | "add X", "build X", "implement X", "new feature", "enhance X", "extend X" | silver:intel → product-brainstorming → silver:brainstorm |
| `silver:bugfix` | "bug", "broken", "crash", "error", "regression", "failing test" | SB triage → systematic-debugging → gsd-debug |
| `silver:ui` | "UI", "frontend", "component", "screen", "design", "interface" | silver:intel → product-brainstorming → silver:brainstorm → gsd-ui-phase |
| `silver:devops` | "infra", "CI/CD", "deploy", "pipeline", "terraform", "IaC", "cloud" | silver:intel → silver:blast-radius → silver:devops-skill-router |
| `silver:research` | "how should we", "which technology", "compare X vs Y", "spike" | silver:explore → MultAI research → silver:brainstorm |
| `silver:release` | "release", "publish", "version", "go live", "cut a release", "tag v" | silver:quality-gates → gsd-audit-uat → gsd-audit-milestone |
| `silver:fast` | "trivial", "quick fix", "typo", "one-liner", "config value" | Complexity triage confirms ≤3 files → gsd-fast |

**Workflow enforcement rules:**
- Quality gates run twice per workflow: pre-planning (full 9 dimensions) and pre-ship (full 9 dimensions)
- `silver:security` is always mandatory — cannot be skipped via §10
- `silver:devops` uses 7 IaC-adapted dimensions (silver:devops-quality-gates) instead of the standard 9
- TDD enforcement (`silver:tdd`) applies to implementation plans only; config/infra/doc plans skip TDD
- `/testing-strategy` runs after spec approval and before `silver:writing-plans` so test requirements are baked into the plan
- Code review always uses the Superpowers framing pair: `silver:request-review` before and `silver:receive-review` after
- Cross-AI review (`gsd-review --multi-ai`) triggers automatically for architecturally significant changes
- `gsd-ship` inside any workflow = phase-level merge (push → PR). `silver:release` = milestone-level publish. These are different levels — SB disambiguates at routing time.
- When user selects Autonomous mode at session start, `gsd-autonomous` drives all remaining phases

**Step-skip protocol:**
When the user requests skipping a workflow step, SB:
1. Explains why the step exists (one sentence)
2. Offers lettered options: A. Accept skip  B. Lightweight alternative  C. Show me what you have
3. Records the decision in §10 if user chooses A permanently

Non-skippable gates: `silver:security`, `silver:quality-gates` pre-ship, `gsd-verify-work`.

---
```

The blank line before `### 2h.` and the closing `---` line plus a blank line before
`## 3. NON-NEGOTIABLE RULES` must be preserved so document structure stays intact.
  </action>
  <verify>
    <automated>grep -c "2h\. SB Orchestrated Workflows" /Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md</automated>
  </verify>
  <done>Output of verify command is 1. The §2h heading appears after the §2g closing --- and before ## 3. NON-NEGOTIABLE RULES.</done>
</task>

<task type="auto">
  <name>Task 2: Insert identical §2h into templates/silver-bullet.md.base</name>
  <files>/Users/shafqat/Documents/Projects/silver-bullet/templates/silver-bullet.md.base</files>
  <action>
Read templates/silver-bullet.md.base. Find the line containing only `---` that
immediately precedes `## 3. NON-NEGOTIABLE RULES` (around line 212). Insert the
identical §2h block from Task 1 at that position, preserving the same structure:
closing `---` of §2g, blank line, §2h content, closing `---`, blank line, then
`## 3. NON-NEGOTIABLE RULES`.

The inserted content must be byte-for-byte identical to what was inserted in Task 1.
  </action>
  <verify>
    <automated>grep -c "2h\. SB Orchestrated Workflows" /Users/shafqat/Documents/Projects/silver-bullet/templates/silver-bullet.md.base</automated>
  </verify>
  <done>Output of verify command is 1. The §2h heading appears in the correct position in the base template.</done>
</task>

<task type="auto">
  <name>Task 3: Confirm both files match and section is positioned correctly</name>
  <files></files>
  <action>
Run the combined verification command to confirm both files have exactly one occurrence
of the §2h heading. Then verify structural positioning in each file by checking the
lines before and after the §2h section:

1. In silver-bullet.md: confirm lines near §2h show `---` before and `## 3.` after.
2. In templates/silver-bullet.md.base: same check.
3. Extract the §2h block from each file and diff them to confirm identical content.
  </action>
  <verify>
    <automated>grep -c "2h\. SB Orchestrated Workflows" /Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md /Users/shafqat/Documents/Projects/silver-bullet/templates/silver-bullet.md.base</automated>
  </verify>
  <done>Both files report count of 1. Diff of extracted §2h blocks between both files shows no differences.</done>
</task>

</tasks>

<verification>
```bash
grep -c "2h\. SB Orchestrated Workflows" \
  /Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md \
  /Users/shafqat/Documents/Projects/silver-bullet/templates/silver-bullet.md.base
```
Expected output:
```
/Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md:1
/Users/shafqat/Documents/Projects/silver-bullet/templates/silver-bullet.md.base:1
```

Additional structural check:
```bash
grep -n "2h\. SB Orchestrated Workflows\|NON-NEGOTIABLE RULES" \
  /Users/shafqat/Documents/Projects/silver-bullet/silver-bullet.md \
  /Users/shafqat/Documents/Projects/silver-bullet/templates/silver-bullet.md.base
```
§2h line number must be lower than NON-NEGOTIABLE RULES line number in each file.
</verification>

<success_criteria>
- silver-bullet.md contains exactly one occurrence of "2h. SB Orchestrated Workflows"
- templates/silver-bullet.md.base contains exactly one occurrence of "2h. SB Orchestrated Workflows"
- §2h appears between the §2g closing --- and ## 3. NON-NEGOTIABLE RULES in both files
- Content in both files is identical
</success_criteria>

<output>
No SUMMARY.md required for quick tasks.
</output>
