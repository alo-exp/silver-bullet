## TC-01 Greenfield Implementation (claude)

Implement a **minimal waitlist SaaS slice** on the greenfield branch: tenant-scoped waitlist API (`POST /waitlist`, `GET /waitlist/stats`) with SQLite persistence, `docker-compose.yml` for local runtime, a minimal static landing page wired to the API, and a short canary deploy checklist in `.planning/`. The harness records the multi-workflow chain (FEATURE → DEVOPS → RELEASE) after your commit — you do not need to invoke Silver Bullet skill chains or lifecycle receipt loops.

### Phase 1 — implement and commit (required)

1. Confirm branch `feature/tri-claude-tc-01-20260706t031302z-tc-01` is checked out.
2. Implement the product delta described above in the fixture app.
3. Run tests (`npm test`, `bash scripts/verify-tests.sh`, or project equivalent) and fix failures.
4. **Git commit** all product files on `feature/tri-claude-tc-01-20260706t031302z-tc-01` with a clear message before any reporting.
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
