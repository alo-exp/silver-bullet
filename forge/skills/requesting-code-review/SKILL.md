---
id: requesting-code-review
title: Requesting Code Review
description: Frame review scope and criteria before spawning reviewer agents
trigger:
  - "requesting code review"
  - "request review"
  - "frame review"
  - "prepare for review"
---

# Requesting Code Review

## Purpose
Before code review begins, establish the scope, criteria, and focus areas to ensure reviewers have clear expectations.

## Steps

### Step 1: Identify Changed Files
List all files that changed in this branch:
```bash
git diff --name-only main...HEAD
```

### Step 2: Categorize Changes
Group files by type:
- **Core logic**: Business logic, algorithms
- **API changes**: Endpoints, contracts
- **Data models**: Schemas, migrations
- **Tests**: Unit, integration, e2e
- **Config**: Environment, settings
- **Dependencies**: Added/updated packages

### Step 3: Define Review Criteria
Based on change types, specify what reviewers should focus on:
- Correctness: Do the changes do what they're supposed to?
- Security: Any new vulnerabilities introduced?
- Performance: Any slow paths created?
- Tests: Is coverage adequate?
- Documentation: Are APIs/docs updated?

### Step 4: Set Review Context
Note for reviewers:
- What problem does this solve?
- Why was this approach chosen?
- What alternatives were considered?
- Any known limitations?

### Step 5: Document Review Request
Write the review request:
```
# Code Review Request

## Branch
<branch-name>

## Changes
<list of changed files grouped by category>

## Scope
<what's in scope>
<what's NOT in scope>

## Criteria
<list of specific things to check>

## Context
<background information for reviewers>

## Files Requiring Special Attention
<files with complex logic, security implications, etc.>
```

## Exit Condition
Review request documented. Reviewers know what to check and why.
