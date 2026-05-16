---
name: scalability
description: This skill should be used when designing, planning, implementing, or reviewing any non-trivial change, or when the user asks to "handle more load", "scale this out", "optimize for throughput" — enforces stateless design, efficient resource usage, and architectural patterns that handle 10x-100x growth without redesign
user-invocable: false
version: 0.1.0
---

# /scalability — Scalable Design Enforcement

Every design, plan, and implementation MUST handle current load efficiently AND accommodate 10x growth without architectural changes. Design for the load you expect in 18 months, not the load you have today.

**Why this matters:** Systems that aren't designed to scale hit walls — and those walls always appear at the worst time (launch day, viral moment, enterprise customer onboarding). Retrofitting scalability is 10-100x more expensive than building it in.

**When to invoke:** During PLANNING (after `/gsd:discuss-phase`, before `/gsd:plan-phase`) and during REVIEW (as part of code review criteria). This skill applies to both new code and modifications to existing code.

---

## The Rules

### Rule 1: Stateless by Default

Every service, function, and handler MUST be stateless unless there is an explicit, documented reason for state.

- **No in-memory state** that would break with multiple instances.
- **No local file system** for data that must survive restarts or be shared.
- **Session state** goes in a shared store (Redis, database), never in process memory.
- **Caches** must be external (Redis, Memcached) or have invalidation strategies for multi-instance.

**Test:** Can you run 5 instances of this service behind a load balancer with no shared state? If no, fix it.

### Rule 2: Efficient Data Access

Every database query and data access pattern MUST be designed for scale:

| Pattern | Requirement |
|---------|-------------|
| Queries | Must use indexes. No full table scans on tables that will grow. |
| Pagination | Required for any list endpoint. No unbounded `SELECT *`. |
| N+1 queries | Forbidden. Use joins, batch loading, or dataloader patterns. |
| Write amplification | Minimize. Don't update entire records when one field changes. |
| Connection pooling | Required. Never open/close connections per request. |
| Read replicas | Design for eventual consistency where appropriate. |

**Test:** Run an `EXPLAIN` on every query. If it says "full table scan" on a table with >10K rows, add an index.

### Rule 3: Async Where Possible

Any operation that doesn't need an immediate response MUST be asynchronous:

- **Email/SMS sending** — queue it.
- **Report generation** — queue it, notify on completion.
- **External API calls** — if the user doesn't need the result immediately, queue it.
- **Data processing** — stream or batch, never block the request.
- **File uploads** — accept, acknowledge, process asynchronously.

**Synchronous is acceptable** for: auth checks, data reads <100ms, input validation.

### Rule 4: Caching Strategy

Every read-heavy path MUST have a caching strategy:

| Cache layer | TTL | Use when |
|-------------|-----|----------|
| HTTP cache (CDN, browser) | Minutes to hours | Static assets, API responses that change infrequently |
| Application cache (Redis) | Seconds to minutes | Computed results, session data, frequent queries |
| Database query cache | Seconds | Identical queries hitting the DB frequently |
| No cache | — | Write paths, real-time data, personalized content |

**Every cache MUST have:**
- A defined TTL (no infinite caches).
- An invalidation strategy (time-based, event-based, or both).
- A cache-miss path that works correctly (no assumption that cache is always warm).

### Rule 5: Resource Limits

Every resource consumer MUST have explicit limits:

| Resource | Limit | What happens at limit |
|----------|-------|-----------------------|
| HTTP request body | Max size (e.g., 10MB) | 413 Payload Too Large |
| Query results | Max rows (e.g., 1000) | Pagination required |
| Batch operations | Max batch size (e.g., 100) | Split into chunks |
| Concurrent connections | Pool size (e.g., 20) | Queue or reject |
| Background jobs | Max concurrent (e.g., 10) | Queue with backpressure |
| File uploads | Max size + count | Reject with clear error |

**No unbounded anything.** Every loop, query, queue, and buffer has a maximum.

### Rule 6: Horizontal Scaling Design

Architecture MUST support horizontal scaling:

- **No singleton dependencies** — no "there can be only one instance" of any service.
- **Idempotent operations** — safe to retry, safe to run in parallel.
- **Distributed locking** only when absolutely necessary (and with TTL).
- **Event-driven** over request-driven for inter-service communication.
- **Partitionable data** — design schemas so data can be sharded by tenant, region, or time.

### Rule 7: Performance Budgets

Every user-facing operation MUST have a performance budget:

| Operation type | Budget |
|----------------|--------|
| API response (P95) | <200ms |
| Page load (LCP) | <2.5s |
| Database query | <50ms |
| Background job start | <1s from event |
| Search | <500ms |

If an operation exceeds its budget, it MUST be optimized before shipping. "It works" is not the same as "it scales."

---

## Applying This Skill

### During Planning (/gsd:discuss-phase → /gsd:plan-phase)

Before finalizing any design or plan, run the **Scalability Checklist**:

- [ ] All services are stateless (or state is externalized with justification)
- [ ] All database queries use indexes and pagination where appropriate
- [ ] Long-running operations are asynchronous
- [ ] Read-heavy paths have a caching strategy with TTL and invalidation
- [ ] All resource consumers have explicit limits
- [ ] Architecture supports horizontal scaling (no singletons, idempotent operations)
- [ ] Performance budgets are defined for user-facing operations

If any item fails: **redesign before proceeding to implementation.**

### During Implementation (/gsd:execute-phase)

As you write code:
- Run `EXPLAIN` on new queries. Add indexes proactively.
- Add pagination to every list endpoint from day one.
- Set explicit timeouts on every external call (HTTP, DB, cache).
- Add resource limits to every input (body size, array length, string length).
- Use connection pooling for every external resource.

### During Review (code-review / receiving-code-review)

Verify these as part of every code review:
- No unbounded queries or loops
- No in-process state that breaks with multiple instances
- Proper caching with TTL and invalidation
- Async processing for non-immediate operations
- Resource limits on all inputs
- Performance budgets documented and met

### When Modifying Existing Code

If existing code violates these rules:
- Not required to fix scalability issues in unrelated code.
- Required: do not make scalability worse.
- If adding a new query to an endpoint, ensure it's indexed and paginated.
- If adding a new external dependency, ensure it has timeouts and connection pooling.

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| In-memory sessions | Breaks with multiple instances | External session store |
| Unbounded queries | Memory explosion at scale | Pagination + limits |
| Synchronous emails | Request blocked for seconds | Queue + async worker |
| No connection pooling | Connection exhaustion under load | Pool with limits |
| Cache without TTL | Stale data forever | TTL + invalidation strategy |
| SELECT * | Transfers unnecessary data | Select only needed columns |
| Fat payloads | Network bottleneck | Paginate, compress, or stream |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "We only have 100 users" | You'll have 10,000 before you know it. Design now. |
| "We can optimize later" | Optimization is cheap. Redesigning architecture is not. |
| "Premature optimization" | Scalability design ≠ micro-optimization. These are architectural. |
| "It's fast enough on my machine" | Your machine has 1 user. Production has thousands. |
| "We'll add caching when we need it" | By then you'll need it urgently. Design the strategy now. |
| "This is just an internal tool" | Internal tools scale with the company. Design accordingly. |
