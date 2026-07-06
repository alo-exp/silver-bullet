## TC-02 Greenfield Implementation (claude)

Harden **observability-only** for the fixture API: structured JSON logging with request `correlation_id`, propagate through existing middleware, and a README runbook section — **no new API routes, UI, DB migrations, or Docker changes**. The harness records dynamic composition (substitute/prune) after your commit — do not invoke Silver Bullet skill chains.

### Phase 1 — implement and commit (required)

1. Confirm branch `feature/tri-claude-tc-02-20260706t035511z-tc-02` is checked out.
2. Implement the product delta described above in the fixture app.
3. Run tests (`npm test`, `bash scripts/verify-tests.sh`, or project equivalent) and fix failures.
4. **Git commit** all product files on `feature/tri-claude-tc-02-20260706t035511z-tc-02` with a clear message before any reporting.
5. Print the fixture commit SHA and a short file manifest.

### Phase 2 — report only (after commit)

- Test summary (pass/fail).
- Paths of key files created or changed.
- Do **not** run `silver-bullet invoke-skill` chains, lifecycle receipt loops, or PR creation unless trivial.

### Constraints

- Work directory: /Users/shafqat/projects/enterprise-grade-test-app
- Do not modify silver-bullet repo unless blocking harness fix
- Do not set SB_E2E_ENTERPRISE_MATRIX
- Blocking credentials only; harness proves orchestrator criteria post-agent
