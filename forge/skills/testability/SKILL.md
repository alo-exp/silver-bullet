---
id: testability
title: Testability Quality Dimension
description: Enforces dependency injection, pure functions, observable state, and seam-based design
trigger:
  - "testability"
  - "test"
  - "testing"
  - "unit test"
---

# Testability Quality Dimension

Every component must be testable in isolation. If it's hard to test, the design is wrong.

## Checklist

Mark each item ✅ Pass / ❌ Fail / ⚠️ N/A:

### Dependency Injection
- [ ] Dependencies passed in (not imported directly)
- [ ] Mocking is straightforward
- [ ] No static method abuse
- [ ] No global state in business logic

### Pure Functions
- [ ] Business logic is pure (same input = same output)
- [ ] Side effects isolated to boundaries
- [ ] No hidden dependencies
- [ ] Deterministic test results

### Seams
- [ ] Integration points clearly defined
- [ ] Easy to inject test doubles
- [ ] Unit tests don't need full system
- [ ] Boundary interfaces are thin

### Test Coverage
- [ ] All new functions have tests
- [ ] Edge cases covered (null, empty, error)
- [ ] Happy path AND error path tested
- [ ] No test-free zones in business logic

### Test Quality
- [ ] Tests are readable (describe intent)
- [ ] Tests are fast (no sleep, no real I/O)
- [ ] Tests are independent (no shared state)
- [ ] Tests are maintainable (no magic numbers)

## When to Check
- Design-time: verify testability in the design
- Pre-ship: verify all functions have tests

## Fix if Failing
Refactor to use dependency injection. Extract side effects. Add tests. Use test doubles at boundaries.
