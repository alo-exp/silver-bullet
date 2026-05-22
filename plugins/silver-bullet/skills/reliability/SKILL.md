---
name: reliability
description: This skill should be used when designing, planning, implementing, or reviewing any non-trivial change, or when the user asks to "add retries", "add error handling", "add circuit breaker", "handle failures" — enforces graceful degradation, proper error handling, retry strategies, and fault-tolerant patterns so systems stay up when things go wrong
user-invocable: false
version: 0.1.0
---

# /reliability — Reliable Design Enforcement

Every design, plan, and implementation MUST handle failure gracefully. Things WILL go wrong — networks fail, disks fill up, dependencies go down, inputs are invalid. The question is not "will it fail?" but "what happens when it does?"

**Why this matters:** Unreliable systems erode user trust faster than any other quality issue. A system that crashes on bad input, hangs when a dependency is slow, or loses data on failure is not production-ready — no matter how many features it has.

**When to invoke:** During PLANNING (after `/gsd:discuss-phase`, before `/gsd:plan-phase`) and during REVIEW (as part of code review criteria). This skill applies to both new code and modifications to existing code.

---

## The Rules

### Rule 1: Every External Call Can Fail

Every network call, database query, file operation, and external service invocation MUST handle failure:

| Failure mode | Required handling |
|-------------|-------------------|
| Timeout | Explicit timeout set. Don't wait forever. |
| Connection refused | Retry with backoff, then degrade gracefully. |
| 5xx response | Retry with backoff (idempotent ops only). |
| 4xx response | Don't retry. Log and handle based on status code. |
| Malformed response | Validate schema. Don't crash on unexpected shapes. |
| Partial failure | Handle incomplete writes. Don't leave data half-updated. |

**No external call without a timeout.** Default: 5s for API calls, 30s for long operations (with documentation for why).

### Rule 2: Retry with Exponential Backoff

Retries MUST use exponential backoff with jitter:

```
attempt 1: immediate
attempt 2: 1s + random(0-500ms)
attempt 3: 2s + random(0-500ms)
attempt 4: 4s + random(0-500ms)
(max 3-5 retries, max backoff 30s)
```

**Only retry idempotent operations.** A retry on a non-idempotent POST can create duplicates.

**Never retry:**
- 400 Bad Request (fix the input)
- 401/403 Unauthorized (fix the auth)
- 404 Not Found (it's not there)
- 409 Conflict (resolve the conflict)

### Rule 3: Circuit Breaker Pattern

When a dependency fails repeatedly, STOP calling it:

| State | Behavior |
|-------|----------|
| **Closed** (normal) | Requests pass through. Track failure rate. |
| **Open** (failing) | Requests fail fast. Return cached/default/error. Don't call dependency. |
| **Half-open** (testing) | Allow 1 request through. If it succeeds, close. If it fails, reopen. |

**Thresholds:** Open after 5 consecutive failures or >50% failure rate in 60s window. Half-open after 30s.

This prevents cascading failures — one down service shouldn't take down everything.

### Rule 4: Graceful Degradation

When a dependency fails, the system MUST continue operating with reduced functionality — not crash:

| Scenario | Degraded behavior |
|----------|-------------------|
| Cache down | Serve from database (slower, but working) |
| Search service down | Show recent/popular items instead |
| Email service down | Queue emails for later delivery |
| Analytics down | Drop analytics events (non-critical) |
| Payment provider slow | Extend timeout, show "processing" state |

**Define degradation behavior during design, not during the outage.** Every external dependency needs a "what if it's down?" answer.

### Rule 5: Idempotent Operations

Every write operation MUST be safe to retry:

- Use idempotency keys for payment and state-changing operations.
- Use upserts instead of insert-then-update.
- Use database transactions for multi-step mutations.
- Use `IF NOT EXISTS` / `ON CONFLICT` for creates.

**Test:** Call the operation twice with the same input. Does it produce the same result? If not, it's not idempotent — fix it.

### Rule 6: Health Checks and Observability

Every service MUST expose:

| Endpoint | Purpose |
|----------|---------|
| `/health` (liveness) | "Am I running?" Returns 200 if process is alive. |
| `/ready` (readiness) | "Can I serve traffic?" Checks dependencies (DB, cache, etc.) |

Every failure MUST be observable:

- **Structured logging** for all errors (not just `console.log("error")`).
- **Metrics** for error rates, latency percentiles, queue depths.
- **Alerts** for error rate spikes, latency degradation, queue buildup.

If it fails silently, it might as well not exist.

### Rule 7: Data Integrity

Data MUST survive failures:

| Principle | Implementation |
|-----------|---------------|
| Atomic operations | Database transactions for multi-step writes |
| Write-ahead logging | Log intent before executing (for recovery) |
| Checksums | Verify data integrity after transfer/storage |
| Backup and recovery | Automated backups with tested restore procedures |
| Eventual consistency | Document which operations are eventually consistent and the convergence window |

**Never lose acknowledged data.** If you told the user "saved," it must be saved — even if the server crashes 1ms later.

---

## Applying This Skill

### During Planning (/gsd:discuss-phase → /gsd:plan-phase)

Before finalizing any design or plan, run the **Reliability Checklist**:

- [ ] Every external call has a timeout and failure handling strategy
- [ ] Retries use exponential backoff with jitter (idempotent ops only)
- [ ] Circuit breakers protect against cascading failures
- [ ] Graceful degradation is defined for every external dependency
- [ ] Write operations are idempotent (safe to retry)
- [ ] Health check endpoints are defined (liveness + readiness)
- [ ] Data integrity is maintained through failures (transactions, WAL, backups)

If any item fails: **redesign before proceeding to implementation.**

### During Implementation (/gsd:execute-phase)

As you write code:
- Set explicit timeouts on every HTTP client, DB connection, and external call.
- Wrap external calls in try/catch with specific error handling (not bare catch-all).
- Add circuit breakers for any dependency called >10 times per minute.
- Return meaningful error responses — status code, error code, human message.
- Never swallow errors silently. Log, metric, or propagate.

### During Review (code-review / receiving-code-review)

Verify these as part of every code review:
- Every external call has timeout and error handling
- No bare `catch` blocks that swallow errors
- Retry logic uses backoff (not immediate retry loops)
- Write operations are idempotent
- Health check endpoints exist and check real dependencies
- Error responses are structured and meaningful

### When Modifying Existing Code

If existing code violates these rules:
- Not required to add circuit breakers to all existing external calls.
- Required: do not make reliability worse.
- If adding a new external call, it MUST have timeout, retry, and error handling.
- If you find a silent error swallowing in code you're touching, fix it.

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Empty catch blocks | Errors silently disappear | Log, metric, or propagate |
| No timeouts | Requests hang forever | Explicit timeout on every call |
| Retry storms | Retries overwhelm failing service | Exponential backoff + circuit breaker |
| Cascading failures | One failure takes everything down | Circuit breakers + degradation |
| Optimistic updates | Assume success, discover failure later | Verify writes, use transactions |
| "It works on my machine" | Local env doesn't simulate failures | Chaos testing, fault injection |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "That service never goes down" | It will. And you won't be ready. |
| "We'll add error handling later" | Later = after the first outage. |
| "It's just a timeout, it'll recover" | Without backoff, your retries will make it worse. |
| "The database is reliable" | Networks between you and the DB are not. |
| "We don't need health checks yet" | You need them the moment you deploy. |
| "This is a simple operation" | Simple operations fail in complex ways. Handle it. |
