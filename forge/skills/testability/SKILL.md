---
name: testability
description: This skill should be used when designing, planning, implementing, or reviewing any non-trivial change, or when the user asks to "make this testable", "add dependency injection", "mock X" — enforces dependency injection, pure functions, observable state, and seam-based design so every component can be tested in isolation
user-invocable: false
version: 0.1.0
---

# /testability — Testable Design Enforcement

Every design, plan, and implementation MUST produce code that is easy to test in isolation. If it's hard to test, the design is wrong — not the test.

**Why this matters:** Untestable code is unverifiable code. When a simple test cannot be written for a component, it's because the component has too many hidden dependencies, side effects, or tightly coupled concerns. Testability is a direct measure of design quality.

**When to invoke:** During PLANNING (after `/gsd:discuss-phase`, before `/gsd:plan-phase`) and during REVIEW (as part of code review criteria). This skill applies to both new code and modifications to existing code.

---

## The Rules

### Rule 1: Dependency Injection Over Hard-Wiring

Every external dependency MUST be injectable — never hard-coded:

| Hard-wired (untestable) | Injected (testable) |
|--------------------------|---------------------|
| `import { db } from './database'` at module level | `function getUser(db, userId)` |
| `new PaymentProvider()` inside business logic | `function processPayment(provider, order)` |
| `Date.now()` called directly | `function isExpired(clock, token)` |
| `fetch('https://api.example.com')` inline | `function getPrice(httpClient, productId)` |

**The rule:** If a function calls something external (DB, API, clock, filesystem, random), that thing MUST be a parameter or constructor argument — not an import or global.

**Exception:** Pure utility libraries (lodash, date-fns) that are deterministic and side-effect-free can be imported directly.

### Rule 2: Pure Functions for Business Logic

Core business logic MUST be pure functions where possible:

- **Same input → same output.** No hidden state affecting the result.
- **No side effects.** No writes to DB, filesystem, or network.
- **No reading global state.** Everything the function needs comes through its parameters.

**Impure shell, pure core:** Push side effects to the edges. The core logic is pure and easy to test; the thin outer layer handles I/O.

```
WRONG: function calculateDiscount(userId) {
  const user = db.getUser(userId);       // side effect: DB read
  const tier = user.tier;
  sendAnalytics('discount_calc', tier);   // side effect: network
  return tier === 'gold' ? 0.2 : 0.1;
}

RIGHT: function calculateDiscount(tier) {
  return tier === 'gold' ? 0.2 : 0.1;    // pure: input → output
}
```

### Rule 3: Seams for Testing

Every module MUST have clear seams — points where behavior can be substituted for testing:

| Seam type | Example |
|-----------|---------|
| Constructor injection | `new OrderService(mockDb, mockMailer)` |
| Function parameters | `processOrder(order, { sendEmail, chargeCard })` |
| Configuration | `{ baseUrl: 'http://test-server' }` |
| Interface/protocol | `implements PaymentGateway` → swap real for mock |
| Environment variables | `process.env.API_URL = 'http://localhost:3001'` |

**Test:** Can you write a test for this component without starting a database, calling an API, or waiting for a timer? If not, add seams.

### Rule 4: Observable State

Every operation MUST produce observable results that tests can verify:

| Unobservable (untestable) | Observable (testable) |
|----------------------------|----------------------|
| Writes to a private field with no getter | Returns a result or updates observable state |
| Logs to console as the only output | Returns success/failure + logs (test the return value) |
| Fires and forgets an async operation | Returns a promise/future that resolves when done |
| Mutates a global in another module | Returns the new state, or emits an event |

**The rule:** If the only way to verify a function worked is to check a log file or database table, the function needs to return a result.

### Rule 5: Deterministic Behavior

Tests MUST produce the same result every time. Eliminate sources of non-determinism:

| Source of non-determinism | Fix |
|---------------------------|-----|
| Current time (`Date.now()`) | Inject a clock; use fixed timestamps in tests |
| Random numbers (`Math.random()`) | Inject a random source; use seeded generators in tests |
| UUIDs | Inject a generator; use predictable IDs in tests |
| Network responses | Mock HTTP clients; use recorded responses |
| File system state | Use in-memory filesystem or temp directories |
| Database auto-increment IDs | Don't assert on IDs; use deterministic test data |
| Parallel execution order | Design for order-independence |

### Rule 6: Small Test Surface

Every testable unit MUST have a small, focused interface:

- **Max 5 dependencies** injected into any single component. More = too complex.
- **Max 3 parameters** for any single function. More = extract an options object.
- **Max 1 responsibility** per testable unit. If the test setup is complex, the unit does too much.
- **Max 10 lines of test setup.** If setup is longer than the test itself, refactor the code.

**Test:** Count the mocks in the test. If more than 3 mocks are needed, the component is coupled to too many things — split it.

### Rule 7: Test Isolation

Every test MUST run independently:

- **No shared mutable state** between tests. Each test sets up its own state.
- **No test ordering.** Tests pass in any order, including random.
- **No external dependencies.** Tests don't need a running database, API, or service.
- **Clean up after yourself.** If a test creates files/data, it removes them.

**Test:** Run a single test in isolation. Does it pass? Run all tests in random order. Do they all pass? If not, fix the shared state.

---

## Applying This Skill

### During Planning (/gsd:discuss-phase → /gsd:plan-phase)

Before finalizing any design or plan, run the **Testability Checklist**:

- [ ] External dependencies are injectable (DB, APIs, clock, filesystem)
- [ ] Core business logic uses pure functions (same input → same output)
- [ ] Every module has clear seams for substituting behavior in tests
- [ ] Operations produce observable results (return values, not just side effects)
- [ ] Non-deterministic sources are injectable (time, random, UUIDs)
- [ ] Components have small test surfaces (max 5 dependencies, max 3 params)
- [ ] Tests can run in isolation without external services

If any item fails: **redesign before proceeding to implementation.**

### During Implementation (/gsd:execute-phase)

As you write code:
- Write the test FIRST (TDD). If the test is hard to write, redesign the interface.
- Pass dependencies as parameters, not imports.
- Extract pure functions for every calculation and business rule.
- Return results from functions instead of mutating external state.
- Use factory functions to create test fixtures (not copy-pasted object literals).

### During Review (code-review / receiving-code-review)

Verify these as part of every code review:
- Dependencies are injected, not hard-coded
- Business logic is in pure functions
- Tests don't require external services to run
- No shared mutable state between tests
- Test setup is concise (<10 lines)
- Non-deterministic sources are controlled in tests

### When Modifying Existing Code

If existing code violates these rules:
- Not required to refactor untestable code in unrelated files.
- Required: make all new code testable.
- If you're adding logic to an untestable function, extract the new logic into a testable helper.
- If touching a function that hard-wires a dependency, make it injectable as part of the change.

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Hard-coded `new Database()` | Can't test without real DB | Inject via constructor/parameter |
| `Date.now()` in business logic | Tests flake across time zones | Inject a clock |
| Global singletons | Tests pollute each other | Inject instances, no globals |
| Test setup > 20 lines | Component too complex | Split component, simplify interface |
| Sleep in tests | Flaky, slow | Use deterministic waits (event, callback) |
| Testing implementation details | Tests break on refactor | Test behavior, not internals |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "It's hard to test because it's complex" | It's complex because it's poorly designed. Simplify. |
| "Mocking is too much work" | If mocking is hard, the dependencies are too coupled. |
| "Integration tests cover it" | Integration tests are slow and don't isolate failures. |
| "This doesn't need tests" | If it's not tested, it's not verified. |
| "I'll add tests later" | Untested code is untestable code. Design for tests now. |
| "The test would just mirror the implementation" | Then the implementation has no logic worth testing — or your test is wrong. |
