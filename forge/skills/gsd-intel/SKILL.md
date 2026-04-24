---
id: gsd-intel
title: GSD — Codebase Intelligence
description: Orient in the existing codebase before planning or implementing changes
trigger:
  - "codebase intel"
  - "understand codebase"
  - "scan project"
  - "orient"
---

# GSD — Codebase Intelligence

## When to Use
At the start of any new feature or when working in unfamiliar code areas. Build mental model before planning.

## Steps

### Step 1: Identify Key Files
For the feature area:
1. Find entry points (main files, routes, handlers)
2. Find data models/schemas
3. Find configuration files
4. Find test files

### Step 2: Read Architecture
Map the codebase structure:
- Directory organization
- Key abstractions
- Dependency patterns
- Testing approach

### Step 3: Document Intel
Write or update `.planning/intel/<feature>-intel.md`:
```
# Intel: <Feature Area>

## Key Files
- entry-point: <path>
- models: <paths>
- config: <paths>

## Architecture
<brief description of how it works>

## Patterns
<coding patterns observed>

## Questions
<open questions that need answers>
```

## Exit Condition
Intel document exists. You can explain the codebase area in one paragraph.
