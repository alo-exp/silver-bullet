---
name: reusability
description: This skill should be used when designing, planning, implementing, or reviewing any non-trivial change, or when the user asks to "generalize this", "extract shared util", "deduplicate this" — enforces DRY, well-defined abstractions, and composable components so code is written once and used many times
user-invocable: false
version: 0.1.0
---

# /reusability — Reusable Design Enforcement

Every design, plan, and implementation MUST produce components that are written once and reused everywhere applicable. Duplication is a bug — not in logic, but in design.

**Why this matters:** Duplicated logic drifts over time. When the same concept lives in two places, one gets updated and the other doesn't — causing subtle bugs that are hard to trace. Reusable design prevents this by ensuring every concept has exactly one authoritative implementation.

**When to invoke:** During PLANNING (after `/gsd:discuss-phase`, before `/gsd:plan-phase`) and during REVIEW (as part of code review criteria). This skill applies to both new code and modifications to existing code.

---

## The Rules

### Rule 1: Single Source of Truth

Every piece of knowledge — business rule, algorithm, configuration value, validation logic — MUST have exactly ONE authoritative representation in the system.

| Violation | Fix |
|-----------|-----|
| Same validation in frontend and backend | Shared schema (JSON Schema, Zod, Protobuf) or single validation layer |
| Same constant in multiple files | Extract to a shared constants module |
| Same SQL query in multiple handlers | Extract to a repository/query module |
| Same error message in multiple places | Extract to an error catalog |

**Test:** Search the codebase for the concept. If it appears in more than one place with substantively identical logic, it violates this rule.

### Rule 2: Compose, Don't Inherit

Prefer composition over inheritance for code reuse. Inheritance creates tight coupling between parent and child — changes to the parent ripple unpredictably.

- Build small, focused functions that do one thing well.
- Combine them via composition (pipes, higher-order functions, middleware chains).
- Use inheritance ONLY for true "is-a" relationships with stable base classes.
- If a base class changes more than once per quarter, it's not stable enough for inheritance.

### Rule 3: Design for Consumers

Before writing a reusable component:

1. **Define the API from the consumer's perspective** — what do they need to pass in, and what do they get back?
2. **Minimize required parameters** — sensible defaults for everything non-essential.
3. **Return predictable types** — no union types that force consumers to check "which kind" they got.
4. **Make the common case easy** — if 80% of callers use the same options, make those the defaults.

If you can't explain how to use it in 3 lines of code, it's too complex for reuse — simplify.

### Rule 4: Appropriate Abstraction Level

Not everything should be reused. Premature abstraction is worse than duplication.

| Count | Action |
|-------|--------|
| 1 occurrence | Just write it inline. No abstraction. |
| 2 occurrences | Note the duplication. Consider extracting if the logic is identical. |
| 3+ occurrences | Extract to a shared module. The pattern is confirmed. |

**The Rule of Three:** Wait for the third occurrence before extracting. Two similar things might diverge; three similar things are a pattern.

### Rule 5: Parameterize, Don't Fork

When a variation of existing behavior is needed:

- **DO** add a parameter or configuration option to the existing component.
- **DO NOT** copy the component and modify the copy.
- **DO NOT** create a parallel implementation with slight differences.

If the variation is too different to parameterize cleanly (>30% different logic paths), it's a new component — not a variant.

### Rule 6: Package Boundaries

Reusable code must live at the right level:

| Scope | Location | Example |
|-------|----------|---------|
| Within a feature | Feature's `shared/` or `utils/` | Feature-specific helpers |
| Across features | Project-level `lib/` or `shared/` | Common business logic |
| Across projects | Published package/library | Generic utilities, SDK clients |

Never import from another feature's internals. If two features need the same thing, extract it to a shared location.

### Rule 7: Documentation for Reuse

Every reusable component MUST have:

- **Purpose** — one sentence explaining what it does and when to use it.
- **Interface** — parameters, return types, side effects.
- **Example** — at least one usage example showing the common case.

If it's not documented, it won't be reused — it will be reimplemented.

---

## Applying This Skill

### During Planning (/gsd:discuss-phase → /gsd:plan-phase)

Before finalizing any design or plan, run the **Reusability Checklist**:

- [ ] No planned component duplicates logic that already exists in the codebase
- [ ] Every shared concept has exactly one authoritative implementation
- [ ] Composition is preferred over inheritance for code reuse
- [ ] Reusable components are designed from the consumer's perspective
- [ ] No premature abstraction — only extract at 3+ occurrences (or obvious patterns)
- [ ] Package boundaries are respected — no cross-feature internal imports
- [ ] Every reusable component has purpose, interface, and example documentation

If any item fails: **redesign before proceeding to implementation.**

### During Implementation (/gsd:execute-phase)

As you write code:
- Before writing new logic, search for existing implementations of the same concept.
- If you find duplication at 3+ sites, extract before adding a 4th.
- If you're copying a function to modify it slightly, parameterize instead.
- Every new shared module gets a JSDoc/docstring with purpose, params, and example.

### During Review (code-review / receiving-code-review)

Verify these as part of every code review:
- No new duplication of existing logic
- Reusable components have clear, documented APIs
- No cross-feature internal imports
- Composition over inheritance where applicable
- Appropriate abstraction level (not premature, not overdue)

### When Modifying Existing Code

If existing code violates these rules:
- Not required to fix duplication in unrelated files.
- Required: do not introduce new duplication.
- If you're adding a 3rd+ copy of logic, extract to shared first.
- If modifying a duplicated section, consider unifying as part of the change.

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Copy-paste programming | Drift between copies, bugs fixed in one not others | Extract shared component |
| God utility file | Grabs bag of unrelated functions | Split by domain |
| Premature abstraction | Abstraction for 1 use case, overly generic | Wait for Rule of Three |
| Leaky abstraction | Consumer must know internals to use correctly | Redesign the interface |
| Not-invented-here | Rewriting what a dependency already provides | Use the dependency |
| Over-parameterization | 15 options where 3 suffice | Separate components for distinct use cases |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "It's faster to just copy it" | Faster now, 10x slower to debug drift later. |
| "They're almost the same but slightly different" | Parameterize the difference. |
| "I'll consolidate later" | You won't. Extract now. |
| "This is too specific to reuse" | If it exists 3+ times, it's not specific. |
| "Adding parameters makes it complex" | Complex is better than duplicated. |
| "The other team owns that code" | Extract to shared, or coordinate. Don't duplicate. |
