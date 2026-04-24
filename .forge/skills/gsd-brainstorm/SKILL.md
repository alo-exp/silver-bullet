---
id: gsd-brainstorm
title: GSD — Brainstorm Phase
description: Explore multiple approaches before committing to a design
trigger:
  - "brainstorm"
  - "explore approaches"
  - "ideate"
  - "think through options"
---

# GSD — Brainstorm Phase

## When to Use
Before planning any non-trivial feature. Generate and evaluate multiple approaches.

## Steps

### Step 1: Define the Problem
State clearly:
- What problem are we solving?
- Who benefits?
- What are the constraints?

### Step 2: Generate Approaches
List 2-4 distinct approaches. For each:
- Name it clearly
- Describe how it works
- List pros and cons
- Estimate complexity (1-5)

### Step 3: Evaluate Trade-offs
For each approach, assess against quality dimensions:
- Modularity: Does it decompose well?
- Scalability: Will it handle growth?
- Security: Any risks introduced?
- Complexity: How hard to implement/maintain?

### Step 4: Recommend
Pick a recommendation with clear reasoning. Be decisive.

### Step 5: Document
Write to `.planning/phases/<N>/BRAINSTORM.md`:
```
# Brainstorm: <Feature>

## Problem
<statement>

## Approaches

### Approach A: <Name>
- How: <description>
- Pros: <list>
- Cons: <list>
- Complexity: <1-5>

### Approach B: <Name>
...

## Recommendation
**Approach <X>**: <reasoning>
```

## Exit Condition
BRAINSTORM.md exists with at least 2 approaches and a recommendation.
