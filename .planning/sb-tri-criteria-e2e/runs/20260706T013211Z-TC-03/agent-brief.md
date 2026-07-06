## TC-03 Net-New Workflow Validation (codex)

Produce an **SB posture audit bundle** for this fixture repo: a `scripts/` replay script that emits **hook manifest JSON** (installed hook versions, `recommended_tools` opt-in from `.silver-bullet.json`, last `graphify update` timestamp), a **one-page compliance markdown** under `.planning/compliance/`, and a **replay verification script** operators can re-run cold. **No existing Silver Bullet workflow** covers this exact posture-audit deliverable; compose a **new reusable workflow** for "SB posture audit bundles" and execute it once. Commit on `feature/tc03-posture-audit`. Autonomous mode; blocking credentials only.

### Host tasks (autonomous)

1. Confirm branch `feature/tc03-posture-audit`; verify posture audit bundle exists.
2. Run `bash scripts/sb-verify-posture-audit.sh` if present; report result.
3. Route via /silver:agent-codex or /silver and silver-new-workflow — document NEW-WORKFLOW dispatch and WF-POSTURE-AUDIT artifact.
4. Report: commit SHA, workflow artifact path, replay script output.

### Constraints

- Work directory: /Users/shafqat/projects/enterprise-grade-test-app
- Net-new workflow path (not tailoring existing WF only)
- Autonomous mode
