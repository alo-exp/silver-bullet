---
id: receiving-code-review
title: Receiving Code Review Feedback
description: Disciplined response to review findings; no blind agreement
trigger:
  - "receiving code review"
  - "address feedback"
  - "review response"
  - "fix review"
---

# Receiving Code Review Feedback

## Purpose
Process review feedback systematically. Agree where appropriate, push back where needed, but never ignore.

## Steps

### Step 1: Triage Findings
Read all review feedback. Classify each finding:
- **Accept**: You agree, will fix
- **Discuss**: You disagree, need to explain
- **Defer**: Valid but out of scope, add to backlog

### Step 2: Address Accept Findings
For each accepted finding:
1. Apply the fix
2. Verify the fix works
3. Mark as resolved in REVIEW.md

### Step 3: Respond to Discussions
For findings you disagree with:
- Explain your reasoning clearly
- Provide evidence (tests, specs, benchmarks)
- Be open to being wrong
- If you still disagree after discussion, escalate to a third opinion

### Step 4: Handle Deferrals
For valid but deferred findings:
- Add to `.planning/BACKLOG.md`
- Explain why it's deferred
- Commit backlog update

### Step 5: Document Response
```
# Code Review Response

## Findings Addressed
| Finding | Resolution | Status |
|---------|------------|--------|
| | | FIXED / DISCUSSED / DEFERRED |

## Deferred to Backlog
- <item>: <reason>

## Outstanding Discussions
- <item>: <your position>
```

## Key Principles
- **Never ignore feedback**: Even if you disagree, engage with it
- **Be specific**: "I think X is wrong because Y"
- **Provide evidence**: Tests, benchmarks, specs
- **Accept being wrong**: It's okay to change your mind

## Exit Condition
All findings addressed. REVIEW.md updated with resolutions.
