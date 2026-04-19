---
name: usability
description: This skill should be used when designing, planning, implementing, or reviewing any non-trivial change — enforces intuitive APIs, clear error messages, progressive disclosure, and developer/user experience so the system is a joy to use
user-invocable: false
version: 0.1.0
---

# /usability — Usability-First Design Enforcement

Every design, plan, and implementation MUST be intuitive, forgiving, and self-documenting. Whether the consumer is an end user clicking a button or a developer calling an API, the experience MUST minimize confusion, surprise, and frustration.

**Why this matters:** Systems that are hard to use don't get used — or they get used wrong. Poor usability causes support tickets, workarounds, data entry errors, and abandonment. The most technically correct system is worthless if nobody can figure out how to use it.

**When to invoke:** During PLANNING (after `/gsd:discuss-phase`, before `/gsd:plan-phase`) and during REVIEW (as part of code review criteria). This skill applies to user interfaces, APIs, CLIs, configuration files, error messages, and documentation.

---

## The Rules

### Rule 1: Principle of Least Surprise

Everything MUST behave as users expect. If a user predicts what will happen before they act, the design is working.

- **Name things by what they do**, not how they do it. `calculateTotal()` not `runAlgorithm3()`.
- **Follow platform conventions.** If every other CLI uses `--verbose`, don't use `--detailed-output`.
- **Be consistent.** If `getUser()` returns a user object, `getOrder()` returns an order object — not a tuple.
- **Side effects are surprises.** If a function does more than its name suggests, rename it or split it.

**Test:** Can a new team member predict what this function/button/endpoint does from its name alone? If not, rename it.

### Rule 2: Error Messages That Help

Every error MUST tell the user three things:

1. **What happened** — factual description of the error.
2. **Why it happened** — the condition that triggered it.
3. **What to do about it** — specific action to fix it.

| Bad | Good |
|-----|------|
| "Error 500" | "Failed to save your changes because the database is temporarily unavailable. Your changes are saved locally and will sync when the connection is restored." |
| "Invalid input" | "Email address must contain @ and a domain (e.g., name@example.com)." |
| "Permission denied" | "You need the 'editor' role to modify this document. Contact your workspace admin to request access." |
| "Something went wrong" | "We couldn't load your dashboard because the analytics service is slow. Retrying in 5 seconds..." |

**Never show raw exceptions, stack traces, or error codes to end users.** Log them for developers; show human-readable messages to users.

### Rule 3: Progressive Disclosure

Start simple. Reveal complexity only when needed.

- **Defaults first.** Every config option has a sensible default. The "zero-config" experience works.
- **Simple API, advanced API.** The common case takes 1-3 parameters. Advanced use cases take more.
- **Layered documentation.** Quick start → Usage guide → API reference → Advanced topics.
- **Guided workflows.** Multi-step processes show progress and allow going back.

| Layer | Content | When shown |
|-------|---------|------------|
| 1. Essential | Core functionality, required inputs | Always |
| 2. Common | Frequently used options | On request or contextually |
| 3. Advanced | Power user features, edge case config | Behind "Advanced" or docs |
| 4. Expert | Internal tuning, debugging, raw access | Documentation only |

### Rule 4: Forgiveness and Recovery

Users make mistakes. The system MUST make recovery easy:

- **Undo** for every destructive action (or confirmation before the action).
- **Autosave** for long-form input (drafts, forms, editors).
- **Graceful handling** of back button, refresh, duplicate submission.
- **Clear escape hatches** — users should always know how to cancel, go back, or start over.
- **No data loss** from navigation, timeout, or accidental action.

**"Are you sure?" dialogs** are a last resort, not a design pattern. Better: make the action reversible.

### Rule 5: Feedback and Responsiveness

Every user action MUST produce visible feedback:

| Action timing | Required feedback |
|---------------|-------------------|
| <100ms | Immediate state change (no loader needed) |
| 100ms - 1s | Loading indicator (spinner, skeleton, progress) |
| 1s - 10s | Progress bar with estimate |
| >10s | Background processing with notification on completion |

**No silent failures.** If an action fails, the user MUST know — immediately and clearly.

**No mystery states.** The user should always be able to answer: "What is the system doing right now? What do I do next?"

### Rule 6: Accessibility by Default

Usability includes EVERYONE:

| Requirement | Implementation |
|-------------|---------------|
| Keyboard navigation | All interactive elements reachable via Tab, usable via Enter/Space |
| Screen reader support | Semantic HTML, ARIA labels, alt text for images |
| Color contrast | WCAG AA minimum (4.5:1 text, 3:1 large text) |
| No color-only indicators | Use icons, patterns, or text alongside color |
| Responsive design | Works on mobile through desktop |
| Focus management | Visible focus indicators, logical tab order |

**Accessibility is not optional.** It's a legal requirement in many jurisdictions and a moral one everywhere.

### Rule 7: Consistent Patterns

The entire system MUST use consistent patterns:

- **Same action = same interaction** everywhere. If "delete" is a red button in one place, it's a red button everywhere.
- **Same data = same format** everywhere. If dates are "March 31, 2026" in one view, they're not "2026-03-31" in another.
- **Same terminology** everywhere. If it's a "workspace" in the UI, it's a "workspace" in the API and docs — not "organization" or "team."
- **Same layout** for similar pages. List views look alike. Detail views look alike. Forms look alike.

---

## Applying This Skill

### During Planning (/gsd:discuss-phase → /gsd:plan-phase)

Before finalizing any design or plan, run the **Usability Checklist**:

- [ ] Names follow the principle of least surprise (functions, endpoints, UI labels)
- [ ] Error messages include what happened, why, and what to do
- [ ] Progressive disclosure — simple by default, complexity available on demand
- [ ] Destructive actions are reversible or require confirmation
- [ ] Every user action produces visible, timely feedback
- [ ] Accessibility requirements met (keyboard, screen reader, contrast)
- [ ] Consistent patterns across the entire system

If any item fails: **redesign before proceeding to implementation.**

### During Implementation (/gsd:execute-phase)

As you write code:
- Write the error message BEFORE writing the happy path. If the error cannot be explained clearly, don't understand the requirement.
- Add loading states for every async operation.
- Test keyboard navigation after building any interactive component.
- Use semantic HTML (button for buttons, a for links, input for inputs).
- Follow the existing naming patterns in the codebase.

### During Review (code-review / receiving-code-review)

Verify these as part of every code review:
- Error messages are human-readable and actionable
- Loading/feedback states exist for async operations
- Naming is clear and consistent with the rest of the system
- Accessibility attributes present (ARIA, alt text, semantic elements)
- No silent failures or mystery states
- Destructive actions have undo or confirmation

### When Modifying Existing Code

If existing code violates these rules:
- Not required to fix usability issues in unrelated UI.
- Required: do not make usability worse.
- If adding a new error case, write a helpful message (not "Error occurred").
- If adding a new interactive element, ensure keyboard accessibility.

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| "Error: null" | User has no idea what happened | Structured error with action |
| Modals on modals | User trapped in dialog hell | Inline editing or single modal |
| Hidden functionality | Users can't find features | Progressive disclosure, not hiding |
| Jargon in UI | Users don't speak developer | Use domain language, not technical terms |
| Disabled buttons without explanation | User doesn't know why they can't proceed | Tooltip or inline text explaining the condition |
| Inconsistent terminology | "Save" vs "Submit" vs "Confirm" for same action | Pick one term, use it everywhere |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "Power users will figure it out" | Power users hate bad UX too. They just suffer silently. |
| "The docs explain it" | Nobody reads docs for something that should be intuitive. |
| "We'll improve UX in v2" | v2 UX debt is twice as expensive. Get it right now. |
| "It's technically correct" | Technically correct + unusable = useless. |
| "Accessibility is a nice-to-have" | It's a legal requirement and moral obligation. |
| "We're not designers" | Usability is engineering, not art. Follow the rules. |
