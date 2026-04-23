---
id: reusability
title: Reusability Quality Dimension
description: Enforces DRY, well-defined abstractions, and composable components
trigger:
  - "reusability"
  - "DRY"
  - "dry principle"
  - "abstraction"
---

# Reusability Quality Dimension

Code should be written once and used many times. Avoid duplication, create clear abstractions.

## Checklist

Mark each item ✅ Pass / ❌ Fail / ⚠️ N/A:

### DRY Principle
- [ ] No code block appears more than once (copy-paste detection)
- [ ] Shared logic extracted to helpers/utilities
- [ ] Constants defined once, referenced everywhere

### Abstractions
- [ ] Common patterns abstracted into reusable functions/components
- [ ] Abstractions have clear, single-purpose interfaces
- [ ] No premature abstraction (3+ similar blocks before abstracting)

### Composability
- [ ] Components can be combined freely
- [ ] No tight coupling between unrelated modules
- [ ] Configuration over hardcoding

### Extensibility
- [ ] New use cases accommodated via extension, not modification
- [ ] Open/Closed principle: open for extension, closed for modification
- [ ] Plugin-friendly architecture where applicable

## When to Check
- Design-time: verify abstractions make sense for the problem
- Pre-ship: verify no duplication was introduced

## Fix if Failing
Extract shared logic. Create abstractions. Consolidate constants. Replace duplication with references.
