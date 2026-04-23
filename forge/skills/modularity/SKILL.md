---
id: modularity
title: Modularity Quality Dimension
description: Enforces small, focused modules so any change fits in context without compaction
trigger:
  - "modularity"
  - "single responsibility"
  - "split file"
  - "decouple"
---

# Modularity Quality Dimension

Every design, plan, and implementation MUST produce small, focused modules where any single change touches the fewest files possible.

## Checklist

Mark each item ✅ Pass / ❌ Fail / ⚠️ N/A:

### File Size
- [ ] No source file exceeds 300 lines (soft: 150 lines)
- [ ] No test file exceeds 400 lines (soft: 200 lines)
- [ ] No config file exceeds 200 lines (soft: 100 lines)

### Single Responsibility
- [ ] Every file answers ONE question in one sentence
- [ ] No file name contains "and" (e.g., UserAndAuth.ts is wrong)
- [ ] Files changing for different reasons are separated

### Change Locality
- [ ] Any single change touches at most 5 files
- [ ] Related code lives together (feature-based, not layer-based)

### Dependency Direction
- [ ] Dependencies flow one direction (no circular imports)
- [ ] High-level modules depend on abstractions, not details

### Context Window
- [ ] Any task requires reading at most 7 files totaling <1500 lines
- [ ] Module interfaces are understandable without reading implementation

## When to Check
- Design-time: during planning, before finalizing design
- Pre-ship: during code review, before shipping

## Fix if Failing
Redesign before proceeding. Decompose large files. Extract shared abstractions. Reorganize by feature.
