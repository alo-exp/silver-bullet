---
id: usability
title: Usability Quality Dimension
description: Enforces intuitive APIs, clear error messages, and developer/user experience
trigger:
  - "usability"
  - "UX"
  - "developer experience"
  - "DX"
---

# Usability Quality Dimension

Systems must be intuitive to use. Good developer experience prevents bugs.

## Checklist

Mark each item ✅ Pass / ❌ Fail / ⚠️ N/A:

### API Design
- [ ] APIs are intuitive and self-documenting
- [ ] Consistent naming conventions across codebase
- [ ] REST conventions followed (verbs, status codes)
- [ ] Pagination on list endpoints

### Error Messages
- [ ] Errors tell user what went wrong
- [ ] Errors tell user how to fix it
- [ ] Errors don't expose internal implementation
- [ ] Errors are actionable

### Documentation
- [ ] Public APIs documented
- [ ] README explains how to use the project
- [ ] Inline comments explain WHY, not WHAT
- [ ] Examples provided for complex APIs

### Developer Experience
- [ ] Build/run instructions clear
- [ ] Dependencies listed and versioned
- [ ] Common tasks are straightforward
- [ ] Debugging is straightforward

### User Experience (for user-facing features)
- [ ] Clear labels and instructions
- [ ] Consistent interaction patterns
- [ ] Progressive disclosure for complexity
- [ ] Accessible (keyboard nav, screen reader)

## When to Check
- Design-time: verify DX considerations in the plan
- Pre-ship: verify docs and error messages are helpful

## Fix if Failing
Improve error messages. Add documentation. Refactor confusing APIs. Add examples.
