---
id: reliability
title: Reliability Quality Dimension
description: Enforces graceful degradation, proper error handling, retry strategies, and fault-tolerant patterns
trigger:
  - "reliability"
  - "error handling"
  - "resilience"
  - "fault tolerance"
---

# Reliability Quality Dimension

Systems must stay up when things go wrong. Graceful degradation and proper error handling are non-negotiable.

## Checklist

Mark each item ✅ Pass / ❌ Fail / ⚠️ N/A:

### Error Handling
- [ ] All errors caught and handled appropriately
- [ ] No裸露 exceptions to users
- [ ] Error messages don't leak sensitive info
- [ ] Errors logged with context for debugging

### Graceful Degradation
- [ ] Non-critical failures don't crash the system
- [ ] Cached responses used when services unavailable
- [ ] Circuit breakers on external dependencies
- [ ] Fallback behavior defined for each dependency

### Retry Strategies
- [ ] Transient failures retried with backoff
- [ ] Retry limits prevent infinite loops
- [ ] Idempotent operations for safe retries
- [ ] Dead letter queues for failed messages

### Timeouts & Limits
- [ ] All external calls have timeouts
- [ ] Resource limits prevent exhaustion
- [ ] Rate limiting protects against overload

### Observability
- [ ] Health check endpoints defined
- [ ] Metrics emitted for key operations
- [ ] Distributed tracing where applicable
- [ ] Alert thresholds configured

### Data Integrity
- [ ] Transactions used for multi-step operations
- [ ] Compensating actions for failed operations
- [ ] No partial state on failure

## When to Check
- Design-time: verify error handling is part of the plan
- Pre-ship: verify all error paths handled

## Fix if Failing
Add error handling. Implement circuit breakers. Add timeouts. Create fallback paths.
