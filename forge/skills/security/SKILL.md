---
id: security
title: Security Quality Dimension
description: Enforces defense in depth, input validation, secure defaults, and OWASP best practices
trigger:
  - "security"
  - "harden"
  - "vulnerability"
  - "OWASP"
---

# Security Quality Dimension

Every design, plan, and implementation MUST treat security as a first-class constraint. **This dimension is NON-N/A** — security items cannot be marked N/A.

## Checklist

Mark each item ✅ Pass / ❌ Fail (NO N/A allowed):

### Input Validation
- [ ] All user input validated (type, length, format, range)
- [ ] Allowlist validation over denylist
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS prevention (output encoding)
- [ ] Command injection prevention

### Authentication & Authorization
- [ ] Every endpoint has explicit auth decision
- [ ] Authorization checked on every operation
- [ ] Least privilege principle applied
- [ ] Session tokens secure (HttpOnly, Secure, SameSite)

### Secrets Management
- [ ] No secrets in source code
- [ ] No secrets in logs or error messages
- [ ] Secrets in environment variables or secrets manager
- [ ] API keys scoped and rotatable

### Defense in Depth
- [ ] Multiple layers protect sensitive operations
- [ ] Secure defaults (deny by default)
- [ ] Security headers set (CSP, HSTS, X-Frame-Options)

### Dependency Security
- [ ] Dependencies audited for CVEs
- [ ] Pin versions in lockfile
- [ ] No unnecessary dependencies

### Data Protection
- [ ] Encryption in transit (TLS)
- [ ] Encryption at rest for sensitive data
- [ ] Sensitive data never in URLs or logs

## When to Check
- Design-time: verify security measures are in the plan
- Pre-ship: verify ALL items are implemented

## Fix if Failing
This is a hard stop. Any ❌ must be fixed before shipping. Security issues cannot be deferred.

## OWASP Top 10 Quick Reference
| # | Risk | Key Defense |
|---|------|-------------|
| A01 | Broken Access Control | Authz checks, deny by default |
| A02 | Cryptographic Failures | TLS, no plaintext secrets |
| A03 | Injection | Parameterized queries, input validation |
| A04 | Insecure Design | Threat modeling during planning |
| A05 | Security Misconfiguration | Secure defaults, no defaults credentials |
| A06 | Vulnerable Components | Dependency scanning, pinned versions |
| A07 | Auth Failures | MFA, rate limiting, secure sessions |
| A08 | Data Integrity Failures | Signed updates, CI/CD security |
| A09 | Logging Failures | Log security events, no secrets |
| A10 | SSRF | Allowlist URLs, block internal ranges |
