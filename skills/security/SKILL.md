---
name: security
description: This skill should be used when designing, planning, implementing, or reviewing any non-trivial change — enforces defense in depth, input validation, secure defaults, and OWASP best practices to prevent vulnerabilities before they ship
user-invocable: false
version: 0.1.0
---

# /security — Security-First Design Enforcement

Every design, plan, and implementation MUST treat security as a first-class constraint, not an afterthought. Vulnerabilities are bugs — the most expensive kind.

**Why this matters:** A single security vulnerability can compromise user data, destroy trust, and cost millions in breach response. Security cannot be "added later" — it must be designed in from the start. Every line of code is an attack surface.

**When to invoke:** During PLANNING (after `/gsd:discuss-phase`, before `/gsd:plan-phase`) and during REVIEW (as part of code review criteria). This skill applies to ALL code — there are no exceptions for "internal" or "low-risk" systems.

---

## The Rules

### Rule 1: Validate All Input at System Boundaries

Every piece of data entering the system MUST be validated before use:

| Boundary | What to validate |
|----------|-----------------|
| HTTP requests | Body, query params, headers, path params — type, length, format, range |
| File uploads | Type, size, content (not just extension), filename sanitization |
| Database reads | Assume data could be corrupted — validate on read if used in security decisions |
| Environment variables | Type, format, required vs optional — fail fast on invalid config |
| External API responses | Schema validation — don't trust upstream services blindly |
| User-generated content | Sanitize for XSS, SQL injection, path traversal, command injection |

**Allowlist over denylist.** Define what IS allowed, never what ISN'T. Attackers are creative; your denylist isn't.

### Rule 2: Authentication and Authorization

| Principle | Requirement |
|-----------|-------------|
| Authentication | Every endpoint must know who is calling. No anonymous access unless explicitly designed. |
| Authorization | Every operation must check if the caller is ALLOWED to do this. Auth ≠ authz. |
| Least privilege | Grant the minimum permissions needed. No admin-by-default. |
| Session management | Secure tokens (HttpOnly, Secure, SameSite), reasonable TTL, revocation support. |
| Password handling | bcrypt/scrypt/argon2 only. Never MD5/SHA for passwords. Never store plaintext. |
| API keys | Scoped, rotatable, revocable. Never embedded in client-side code. |

**Every endpoint MUST have an explicit auth decision** — either "this requires auth" or "this is intentionally public" (documented why).

### Rule 3: Secrets Management

Secrets MUST NEVER appear in:
- Source code (no hardcoded passwords, API keys, tokens)
- Git history (if committed accidentally, rotate immediately — don't just delete)
- Logs (mask/redact sensitive fields)
- Error messages (no stack traces with connection strings in production)
- Client-side code (no API keys in JavaScript bundles)

**Secrets MUST live in:**
- Environment variables (minimum)
- Secrets manager (AWS Secrets Manager, Vault, 1Password) for production
- `.env` files that are in `.gitignore` for local development

### Rule 4: Defense in Depth

No single security control is sufficient. Layer defenses:

```
Layer 1: Network — firewalls, VPN, TLS everywhere
Layer 2: Application — input validation, output encoding
Layer 3: Authentication — verify identity at every boundary
Layer 4: Authorization — check permissions for every operation
Layer 5: Data — encryption at rest and in transit
Layer 6: Monitoring — log security events, alert on anomalies
```

If any single layer fails, the remaining layers MUST still protect the system. Never rely on "the firewall will stop it" or "users won't do that."

### Rule 5: Secure Defaults

Every configuration, feature flag, and permission MUST default to the secure option:

- New users get minimum permissions, not admin.
- New endpoints require authentication, not allow anonymous.
- New features are disabled until explicitly enabled.
- CORS is restrictive until explicitly opened.
- CSP is strict until explicitly relaxed.
- TLS is required, not optional.

**"Opt into risk, never opt out of safety."**

### Rule 6: Dependency Security

| Practice | Frequency |
|----------|-----------|
| Audit dependencies for known CVEs | Every build (CI) |
| Pin dependency versions | Always (lockfile) |
| Review new dependencies before adding | Every time |
| Remove unused dependencies | Every release |
| Prefer well-maintained dependencies | >1000 stars, active maintainer, no critical CVEs |

**Before adding a dependency, ask:** "Does this dependency have access to our users' data? What happens if it's compromised?" If the answer is scary, vendor it or find an alternative.

### Rule 7: Output Encoding and Injection Prevention

| Attack | Prevention |
|--------|------------|
| SQL Injection | Parameterized queries ONLY. Never string concatenation. |
| XSS | Context-aware output encoding. CSP headers. |
| Command Injection | Never pass user input to shell commands. Use libraries. |
| Path Traversal | Validate and canonicalize file paths. Never use raw user input. |
| SSRF | Allowlist outbound URLs. Block internal network ranges. |
| Deserialization | Never deserialize untrusted data with native serializers. Use JSON. |
| CSRF | Anti-CSRF tokens for state-changing operations. SameSite cookies. |

**If user input touches a query, command, path, or URL — it MUST be parameterized or sanitized.**

---

## Applying This Skill

### During Planning (/gsd:discuss-phase → /gsd:plan-phase)

Before finalizing any design or plan, run the **Security Checklist**:

- [ ] All system boundaries have input validation (allowlist-based)
- [ ] Every endpoint has an explicit auth/authz decision
- [ ] No secrets in source code, logs, or error messages
- [ ] Defense in depth — at least 3 layers protect sensitive operations
- [ ] All defaults are secure (auth required, permissions minimal, features disabled)
- [ ] Dependencies are audited and pinned
- [ ] All user input that touches queries/commands/paths is parameterized

If any item fails: **redesign before proceeding to implementation.**

### During Implementation (/gsd:execute-phase)

As you write code:
- Use parameterized queries for ALL database access. No exceptions.
- Add input validation at every API endpoint before any business logic.
- Never log sensitive data (passwords, tokens, PII, credit cards).
- Set security headers on every response (CSP, HSTS, X-Frame-Options).
- Use crypto libraries, never roll your own encryption.
- Add rate limiting to authentication endpoints.

### During Review (code-review / receiving-code-review)

Verify these as part of every code review:
- No hardcoded secrets or credentials
- Input validation on all boundaries
- Parameterized queries (no string concatenation in SQL)
- Proper output encoding (no raw HTML insertion)
- Auth/authz checks on every endpoint
- No sensitive data in logs or error messages
- Security headers present

### When Modifying Existing Code

If existing code violates these rules:
- **Security violations ARE required to fix** if they're in code you're touching.
- If you discover a hardcoded secret, flag it immediately — even in unrelated code.
- If you're adding a new endpoint, it MUST have auth even if neighboring endpoints don't.
- Never make security worse. If existing code has validation, don't remove it.

---

## OWASP Top 10 Quick Reference

| # | Risk | Key Defense |
|---|------|-------------|
| A01 | Broken Access Control | Authz checks on every operation, deny by default |
| A02 | Cryptographic Failures | TLS everywhere, strong algorithms, no plaintext secrets |
| A03 | Injection | Parameterized queries, input validation |
| A04 | Insecure Design | Threat modeling during planning, not after |
| A05 | Security Misconfiguration | Secure defaults, no default credentials |
| A06 | Vulnerable Components | Dependency scanning, pinned versions |
| A07 | Auth Failures | MFA, rate limiting, secure session management |
| A08 | Data Integrity Failures | Signed updates, CI/CD security, input validation |
| A09 | Logging Failures | Log security events, don't log secrets, monitor |
| A10 | SSRF | Allowlist outbound URLs, block internal ranges |

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| "Security through obscurity" | Hiding ≠ protecting | Proper access controls |
| Trusting client-side validation | Trivially bypassed | Server-side validation always |
| Broad CORS (`*`) | Any origin can access API | Explicit origin allowlist |
| Admin-by-default | Over-privileged users | Least privilege, role-based access |
| Logging everything | Secrets in logs | Structured logging with redaction |
| Rolling your own crypto | Guaranteed vulnerabilities | Use vetted libraries (libsodium, etc.) |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "It's just an internal tool" | Internal tools get compromised. Insider threats are real. |
| "We'll add security later" | Later never comes. Vulnerabilities ship. |
| "Nobody would try that" | They will. And they have automated tools. |
| "It's behind a firewall" | Firewalls get bypassed. Defense in depth. |
| "We don't have sensitive data" | User emails, passwords, and usage patterns are sensitive. |
| "This is just a prototype" | Prototypes become production. Secure from day one. |

---

## Backlog Capture (mandatory)

After completing the security review, any low-priority or suggested findings that are not blocking must be **immediately added to the GSD backlog** using `/gsd-add-backlog`. Do NOT silently drop security suggestions — they must be captured or implemented.

If no items were deferred, output: "No backlog items from this security review."
