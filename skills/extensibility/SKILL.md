---
name: extensibility
description: This skill should be used when designing, planning, implementing, or reviewing any non-trivial change — enforces open-closed design, plugin architectures, stable interfaces, and versioning so systems grow without breaking existing consumers
user-invocable: false
version: 0.1.0
---

# /extensibility — Extensible Design Enforcement

Every design, plan, and implementation MUST allow new functionality to be added without modifying existing code. The system should be open for extension but closed for modification.

**Why this matters:** Software that requires modifying core code for every new feature becomes brittle, risky, and slow to evolve. Extensible design lets you add capabilities by writing NEW code — not editing existing, tested, working code. This is the difference between systems that scale with the team and systems that bottleneck at every change.

**When to invoke:** During PLANNING (after `/gsd:discuss-phase`, before `/gsd:plan-phase`) and during REVIEW (as part of code review criteria). This skill applies to both new code and modifications to existing code.

---

## The Rules

### Rule 1: Open-Closed Principle

Modules MUST be open for extension but closed for modification:

| Closed for modification | Open for extension |
|-------------------------|--------------------|
| Core processing pipeline | New processors via registration |
| Validation engine | New validators via interface |
| Authentication system | New auth providers via adapter pattern |
| Report generator | New report formats via strategy pattern |
| Event system | New event handlers via subscription |

**The test:** Can you add a new [feature type] without editing any existing file? If yes, the design is extensible. If no, find the extension point and create it.

### Rule 2: Extension Points

Every system MUST define explicit extension points:

| Pattern | Use when |
|---------|----------|
| **Hooks/Events** | Others need to react to your system's actions |
| **Plugin interface** | Third parties add completely new capabilities |
| **Strategy pattern** | Multiple algorithms for the same operation |
| **Middleware chain** | Cross-cutting concerns (logging, auth, caching) |
| **Configuration** | Behavior changes without code changes |
| **Registry pattern** | New types registered at startup, discovered at runtime |

**Every extension point MUST have:**
- A documented interface/contract
- At least one reference implementation
- A way to discover available extensions
- Error handling for malformed extensions

### Rule 3: Stable Interfaces

Public interfaces MUST be stable. Once published, an interface is a promise:

| Rule | Implementation |
|------|---------------|
| Never remove a public method | Deprecate first, remove in next major version |
| Never change a method's signature | Add a new method with the new signature |
| Never change return types | Use generics or union types for flexibility |
| Never change error types | Add new error types, don't modify existing ones |
| Never change default behavior | New defaults only in major versions |

**Interface evolution rules:**
- **Adding** a new optional method/field — safe in any version.
- **Adding** a new required method/field — major version bump.
- **Removing** anything — deprecate for 1 major version, remove in the next.
- **Changing** behavior — major version bump with migration guide.

### Rule 4: Configuration Over Code

Behavior that might change MUST be configurable:

| Hard-coded (inflexible) | Configurable (extensible) |
|--------------------------|---------------------------|
| `if (country === 'US')` | `config.supportedCountries.includes(country)` |
| `const MAX_RETRIES = 3` | `config.maxRetries ?? 3` |
| `sendEmail(...)` hard-coded | `notificationChannels.forEach(ch => ch.send(...))` |
| `switch (type) { case 'pdf': ... }` | `formatters.get(type).render(data)` |

**Not everything should be configurable.** Only extract configuration for values that:
- Differ between environments (dev/staging/prod)
- Might change without a code deploy
- Vary by customer/tenant
- Are explicitly requested as configurable

### Rule 5: Versioned APIs

Every public API MUST be versioned from day one:

| Layer | Versioning strategy |
|-------|---------------------|
| REST APIs | URL path (`/v1/users`) or header (`Accept: application/vnd.api.v1+json`) |
| Libraries/packages | Semantic versioning (MAJOR.MINOR.PATCH) |
| Database schemas | Migration numbering with up/down |
| Configuration files | Version field + migration path |
| Message formats | Schema registry with compatibility checks |

**Semantic versioning rules:**
- PATCH: bug fixes only, no behavior changes
- MINOR: new features, backward compatible
- MAJOR: breaking changes, with migration guide

### Rule 6: Backward Compatibility

New versions MUST work with old clients:

| Principle | Implementation |
|-----------|---------------|
| Accept old input formats | Parse both old and new format, normalize internally |
| Return backward-compatible output | Add fields, never remove or rename |
| Support old configuration | Migration on startup, not manual conversion |
| Maintain old endpoints | Deprecation notice, proxy to new version |
| Default to old behavior | New behavior requires explicit opt-in |

**Breaking change budget:** Maximum 1 breaking change per quarter. Each breaking change needs a migration guide AND an automated migration tool where possible.

### Rule 7: Separation of Mechanism and Policy

Separate the HOW (mechanism) from the WHAT (policy):

| Mechanism (stable) | Policy (changes often) |
|--------------------|------------------------|
| Event dispatch system | Which events trigger which actions |
| Permission checking framework | Permission rules and role definitions |
| Validation engine | Validation rules per entity |
| Notification system | When and how to notify |
| Workflow engine | Workflow step definitions |

The mechanism is the extensible framework. The policy is the configuration/plugins that define behavior. When policy changes (it will), no mechanism code needs to change.

---

## Applying This Skill

### During Planning (/gsd:discuss-phase → /gsd:plan-phase)

Before finalizing any design or plan, run the **Extensibility Checklist**:

- [ ] New feature types can be added without modifying existing code (open-closed)
- [ ] Extension points are explicitly defined and documented
- [ ] Public interfaces are stable with a clear evolution strategy
- [ ] Variable behavior is configurable (not hard-coded)
- [ ] APIs are versioned from day one with semantic versioning
- [ ] New versions maintain backward compatibility
- [ ] Mechanism (framework) is separated from policy (rules/config)

If any item fails: **redesign before proceeding to implementation.**

### During Implementation (/gsd:execute-phase)

As you write code:
- When adding a new type/format/provider, use registry/strategy pattern — don't add `else if`.
- When exposing a public API, version it from the first release.
- When adding config options, provide sensible defaults so existing users aren't affected.
- When deprecating something, add a deprecation warning with a migration path.
- Use interfaces/protocols for dependencies — not concrete implementations.

### During Review (code-review / receiving-code-review)

Verify these as part of every code review:
- No `switch` or `if/else if` chains that will grow as new types are added
- Extension points exist for foreseeable variations
- Public interfaces haven't been broken
- New config options have defaults
- API versions are maintained
- Deprecation warnings include migration paths

### When Modifying Existing Code

If existing code violates these rules:
- Not required to add extension points to all existing code.
- Required: do not make extensibility worse.
- If you're adding a third `else if` for a new type, convert to a registry/strategy.
- If you're modifying a public interface, ensure backward compatibility.

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Giant switch/case for types | Every new type modifies the switch | Registry or strategy pattern |
| Hardcoded providers | Can't swap implementations | Interface + injection |
| Unversioned APIs | Can't evolve without breaking | Version from day one |
| Breaking changes without notice | Consumers break silently | Deprecation cycle |
| God config file | Everything in one place, impossible to extend | Split by concern, compose |
| Feature flags as architecture | Permanent conditionals in code | Plugin/extension points |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "We don't need plugins" | You need the pattern, not necessarily a plugin system. |
| "YAGNI — we don't need to extend this" | If 3+ types exist or are planned, you need an extension point. |
| "Breaking changes are fine, we control all consumers" | You won't forever. And you'll forget who consumes what. |
| "Versioning is overhead" | Versioning is cheap. Breaking consumers is expensive. |
| "We can just update everyone" | At 10 consumers, maybe. At 100, impossible. |
| "This is internal, we can change it" | Internal APIs have consumers too. Treat them with respect. |
