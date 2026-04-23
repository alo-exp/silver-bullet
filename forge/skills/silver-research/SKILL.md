---
id: silver-research
title: Silver — Research/Spike Workflow
description: Technology decision, architecture research, and spike workflow
trigger:
  - "silver research"
  - "research workflow"
  - "spike"
  - "architecture decision"
  - "technology decision"
---

# Silver Research — Research and Spike Workflow

## When to Use
For technology decisions, architecture choices, research spikes, or "how should we" questions.

## Steps

### Step 1: DEFINE QUESTION
State clearly:
- What decision needs to be made?
- What are the constraints?
- What criteria matter?
- What's the timeline?

### Step 2: EXPLORE APPROACHES
Run brainstorming (trigger: "brainstorm"). Document:
- 2-4 candidate solutions
- Pros and cons of each
- Complexity estimates
- Risk assessments

### Step 3: RESEARCH
For each promising approach:
- Read documentation
- Check community consensus
- Look for case studies
- Assess maintainability

### Step 4: EVALUATE
Evaluate against criteria:
- Fit with existing architecture
- Learning curve
- Community support
- Long-term maintenance
- Cost (time and money)

### Step 5: RECOMMEND
Make a clear recommendation:
- State which approach
- Explain why
- Acknowledge trade-offs
- Suggest next steps

### Step 6: DOCUMENT
Write research doc to `docs/research/YYYY-MM-DD-<topic>-research.md`:
```
# Research: <Topic>

## Question
<what decision>

## Options Considered
### Option A: <Name>
- Description: <how it works>
- Pros: <benefits>
- Cons: <drawbacks>

### Option B: <Name>
...

## Evaluation

| Criteria | Option A | Option B |
|----------|----------|----------|
| <criterion> | <rating> | <rating> |

## Recommendation
**Option <X>**: <reasoning>

## Next Steps
<how to proceed>
```

## Exit Condition
Research documented with recommendation. User can make informed decision.
