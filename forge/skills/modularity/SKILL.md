---
name: modularity
description: This skill should be used when designing, planning, implementing, or reviewing any non-trivial change, or when the user asks to "split this file", "decouple X from Y", "refactor into modules" — enforces small, focused modules so any change fits in context without compaction
user-invocable: false
version: 0.1.0
---

# /modularity — Modular Design Enforcement

Every design, plan, and implementation MUST produce small, focused modules where any single change touches the fewest files possible and every touched file fits comfortably in context.

**Why this matters:** When files are large or tightly coupled, Claude must compact context to fit them — risking loss of key details. Modular design prevents this by keeping each unit small enough to reason about completely.

**When to invoke:** During PLANNING (after `/gsd:discuss-phase`, before `/gsd:plan-phase`) and during REVIEW (as part of code review criteria). This skill applies to both new code and modifications to existing code.

---

## The Rules

### Rule 1: File Size Limits

| File type | Soft limit | Hard limit | Action at hard limit |
|-----------|-----------|------------|---------------------|
| Source code (logic) | 150 lines | 300 lines | MUST split before proceeding |
| Test files | 200 lines | 400 lines | MUST split into focused test suites |
| Config / data | 100 lines | 200 lines | MUST split into per-concern configs |
| Documentation | 300 lines | 500 lines | MUST split into linked pages |

**Soft limit:** Refactor soon. Flag in code review.
**Hard limit:** Do not proceed. Split first, then continue.

Line counts exclude blank lines and comments. If a file approaches the soft limit during implementation, split it before the next commit — not "later."

### Rule 2: Single Responsibility Per File

Every file answers ONE question:
- "What does this file do?" must have a one-sentence answer.
- If the answer contains "and," the file does too much — split it.
- If two developers could work on different parts of the file simultaneously on unrelated tasks, it should be two files.

### Rule 3: Change Locality

Design so that any single feature, fix, or change touches **at most 3-5 files** (excluding tests). If a change requires touching more than 5 source files:
- STOP. The design has a coupling problem.
- Identify which files are changing for the same reason — they should share an abstraction.
- Identify which files are changing for different reasons — they need a cleaner interface between them.

### Rule 4: Interface-First Design

Before writing any implementation:
1. Define the module's **public interface** — what it exposes to consumers.
2. Define its **dependencies** — what it imports/requires.
3. The interface should be understandable without reading the implementation.
4. Consumers should never need to know implementation details.

If you can't define the interface in <10 lines, the module is too complex — decompose further.

### Rule 5: Context-Window-Aware Decomposition

When designing a system, apply this test to every module:

> "Can Claude read this file, its tests, and the files it directly depends on — all at once — without exceeding context or needing to compact?"

If no: the module is too large or has too many dependencies. Decompose until the answer is yes.

**Practical guideline:** Any single task (implement, fix, review) should require reading **at most 5-7 files totaling under 1500 lines**. Design the system to make this true.

### Rule 6: Dependency Direction

- Dependencies flow ONE direction (no circular imports).
- High-level modules depend on abstractions, not low-level details.
- If module A imports module B and module B imports module A, extract the shared concern into module C.

### Rule 7: Co-location

Files that change together live together. Organize by **feature/domain**, not by **technical layer**.

```
WRONG (layer-based):
  controllers/user.ts
  controllers/order.ts
  services/user.ts
  services/order.ts
  models/user.ts
  models/order.ts

RIGHT (feature-based):
  user/controller.ts
  user/service.ts
  user/model.ts
  order/controller.ts
  order/service.ts
  order/model.ts
```

When a change to "users" only touches files in `user/`, modularity is working.

---

## Applying This Skill

### During Planning (/gsd:discuss-phase → /gsd:plan-phase)

Before finalizing any design or plan, run the **Modularity Checklist**:

- [ ] Every planned file has a one-sentence responsibility
- [ ] No planned file exceeds the soft line limit for its type
- [ ] The file structure is organized by feature/domain, not layer
- [ ] Any single task in the plan touches at most 3-5 source files
- [ ] Every module's public interface is defined before its implementation
- [ ] Dependencies flow in one direction — no circular imports
- [ ] The context test passes: any task requires reading <1500 lines total

If any item fails: **redesign before proceeding to implementation.** Do not defer modularity to refactoring — it is far cheaper to decompose correctly upfront.

### During Implementation (/gsd:execute-phase)

As you write code:
- Check file size after each commit. If approaching the soft limit, split NOW.
- If a function grows beyond 30 lines, extract sub-functions or a helper module.
- If you're adding a new feature and touching >5 files, stop and ask: "Is there a missing abstraction?"

### During Review (code-review / receiving-code-review)

Verify these as part of every code review:
- No file exceeds the hard limit
- Each file's responsibility is clear and singular
- Change locality: the PR touches a reasonable number of files
- No circular dependencies introduced
- New modules have well-defined interfaces

**Adversarial mode rule: No future credit.** When reviewing, reject any reasoning that defers a current violation to a future action (backlog item, next phase, open issue). The review grades the code as it exists now. A planned fix is not a fix; a GitHub issue is not code. If a file violates the limits today, the review outcome is ❌ Fail — regardless of intent, roadmap, or tracking.

### When Modifying Existing Code

If existing code violates these rules:
- Not required to fix violations in unrelated files.
- Required: do not make violations worse.
- If the file being modified already exceeds the hard limit, include a split as part of the change.
- If the change would push a file past the soft limit, split first.

---

## Splitting Strategies

When a file needs to be split, use these patterns:

**By sub-feature:** `auth.ts` → `auth/login.ts`, `auth/register.ts`, `auth/token.ts`

**By abstraction level:** `api.ts` → `api/routes.ts`, `api/middleware.ts`, `api/validation.ts`

**By data type:** `utils.ts` → `string-utils.ts`, `date-utils.ts`, `array-utils.ts`

**Extract shared logic:** If two files share helper functions, extract to a shared module rather than duplicating.

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| "God file" — one file does everything | Impossible to change safely | Split by responsibility |
| "Shotgun surgery" — one change touches 10+ files | Missing abstraction | Extract shared concern |
| "Barrel files" re-exporting everything | Hides dependency structure | Import directly from source |
| Premature abstraction for one use case | Unnecessary complexity | Three similar blocks > one premature abstraction |
| Layer-based organization | Unrelated files change together | Reorganize by feature |
| "Utils" or "helpers" grab-bag | No clear responsibility | Split by domain or delete |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "It's just one more function" | That's how 800-line files happen. Split now. |
| "Splitting will create too many files" | Many small files > few large files. Always. |
| "I'll refactor later" | You won't. The soft limit exists to prevent this. |
| "This file is the natural home for this" | If it exceeds the limit, it's not. Find a better home. |
| "It's all related" | Related is not the same as same-responsibility. |
| "The framework forces this structure" | Most frameworks work fine with smaller modules. Check. |
| "It's tracked in the backlog / GitHub issue #N" | A planned fix is not a fix. The violation exists now. ❌ Fail. Fix it or accept the block. |
| "The current milestone plan addresses this" | Planning intent ≠ code compliance. The gate evaluates actual structure, not intent. ❌ Fail until the code is changed. |
| "We'll fix this in the next phase / sprint" | Future tense is not present tense. Rate the current state. ❌ Fail if the rule is violated today. |
