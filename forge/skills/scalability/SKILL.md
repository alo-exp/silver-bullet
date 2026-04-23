---
id: scalability
title: Scalability Quality Dimension
description: Enforces stateless design, efficient resource usage, and patterns that handle 10x-100x growth
trigger:
  - "scalability"
  - "scale"
  - "performance"
  - "growth"
---

# Scalability Quality Dimension

Systems must be designed to handle 10x-100x growth without redesign.

## Checklist

Mark each item ✅ Pass / ❌ Fail / ⚠️ N/A:

### Stateless Design
- [ ] Business logic is stateless (no in-memory state)
- [ ] State stored in databases, not memory
- [ ] Multiple instances can run concurrently

### Resource Efficiency
- [ ] No N+1 query patterns
- [ ] Connections pooled appropriately
- [ ] Memory usage bounded (no unbounded arrays/caches)

### Caching Strategy
- [ ] Expensive operations cached appropriately
- [ ] Cache invalidation strategy defined
- [ ] CDN-appropriate static assets separated

### Async Processing
- [ ] Long-running tasks queued, not blocking
- [ ] Background jobs for heavy computation
- [ ] Rate limiting on external calls

### Database
- [ ] Indexes on queried columns
- [ ] Query complexity appropriate (no full table scans in hot paths)
- [ ] Partitioning strategy for large tables

### API Design
- [ ] Pagination on all list endpoints
- [ ] Cursor-based pagination for large datasets
- [ ] Response compression enabled

## When to Check
- Design-time: verify architecture supports scale
- Pre-ship: verify no obvious performance bottlenecks

## Fix if Failing
Add caching. Implement pagination. Fix N+1 queries. Move state to persistence. Add rate limiting.
