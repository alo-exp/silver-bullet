# REVIEW — Phase 106 Session A: Doctor opt-in coverage

**Skills:** `/silver:review-request` → `/silver:review` → `/silver:review-triage`  
**Date:** 2026-08-30  
**Scope:** Session A waves 1–2 only (not the rest of dirty `main`)

---

## SILVER BULLET > REVIEW REQUEST

### What changed (intended)

- Live extra-tool `search_cli` (Alumnium consent/registry pattern; Cursor+Claude+Codex; `packages` only; `required_when_enabled: false`).
- Closed `--fix` swallow on empty/malformed/failed reconciler JSON.
- D10 honesty: `vendor_skip` ≠ Health, `min_version` FAIL (RTK 0.42.0, LeanCTX 3.9.9, CM node 22.5), Graphify `skill_package_skew` WARN, `unknown_key` WARN+nonzero, duplicate LeanCTX keys D10 FAIL.
- `--fix=local` host fence; `--fix=all` no first-match `break`; five-tool fixture + idempotent second apply.
- `/sb:doctor` alias + plugin stubs → `scripts/sb-doctor.sh`.
- Deleted stale `scripts/lib/sb-doctor/{checks,fix,core,summary}.sh`.
- SKILL F4 table + sync (`sync-codex-package.sh`, `generate-plugin-commands.sh`).

### Non-goals

Session B; Omni Phase 3 (footnote only); Phase 4 plugin; freeze-file; SPEC/REQUIREMENTS; GSD STATE restamp; merge/push/tag.

### High-risk areas

- `--fix` blast radius (local vs host vs packages vs all).
- Registry pin vs project `install_commands` tamper.
- Nested installer/reconcile on live trees in tests (`SB_DOCTOR_STUB_HOST_INSTALL`).
- Secrets: never dump `search config show`.

### Tests to inspect

- `bash tests/scripts/test-silver-doctor.sh` — 123/0
- `bash tests/scripts/test-reconcile-recommended-tools.sh` — 107/0

### What would block ship / merge of Session A

- Targeted tests red.
- Swallow reintroduced.
- Freeze-file included in the Session A commit.
- Opted-in missing `search_cli` not FAIL on cursor/claude/codex.
- Unknown `--fix` that mutates host under `--fix=local`.

---

## SILVER BULLET > REVIEW

Findings ordered by severity. File references are under `/Users/shafqat/projects/silver-bullet/repo`.

| ID | Sev | Finding | Evidence |
|----|-----|---------|----------|
| R1 | WARN | Agentmemory Health identity (`health_identity_unproven`) is documented in SKILL F4 but not enforced in the probe. A health URL on the wrong instance can still look green. | PLAN 2.1 row; SKILL agentmemory Health column; no probe implementation this wave (flaky `:3111`). |
| R2 | WARN | `bash scripts/sb-doctor.sh --dry-run` on this operator tree FAILs **D4** (Claude settings missing SB hooks). Not a Session A D10 defect; will confuse “green default tree” smoke if conflated. | JSON: fail=1, `FAIL: D4 — Claude settings.json missing SB hook entries`; `D10-search_cli` PASS N/A. |
| R3 | WARN | `main` working tree is dirty far beyond Session A, including `.planning/router_subagent_surfaces_85bf9f09.plan.md` (quality-order hop ledger). A naive `git add -A` would violate AC 10. | `git diff --stat` on freeze file: +187/−74; Session A did not author it. |
| R4 | INFO | Host-install branches still use `bash "$install_script" >&2 \|\| true` after listing a check as fixed. Distinct from reconciler-JSON swallow (closed). | `scripts/sb-doctor.sh` `doctor_apply_fixes` D4/D13/D21 arms. |
| R5 | INFO | Graphify skill 0.9.35 vs package 0.9.52 skew WARN is expected; `--fix` none. | PLAN assumption 9; `graphify update` warnings. |

No BLOCK. No security secret dump found (`probe-search_cli` must not dump `search config show` — tested).

## Deployment Risk

Tier: **MEDIUM** (2)  
Rationale: Additive doctor/reconciler honesty and a new optional extra-tool; `--fix` blast radius is real but fenced by scope tests; no auth/data-plane change.  
Recommended deploy steps:

- Commit **only** Session A paths (list in triage).
- Do not merge freeze-file or unrelated dirty files.
- After merge, operators below RTK/LeanCTX pins will see new FAILs (intended honesty).

---

## SILVER BULLET > REVIEW TRIAGE

Delegated classification (`silver-triage-v1` summary):

```json
{
  "schema": "silver-triage-v1",
  "charter": "106-doctor-opt-in-coverage-session-a",
  "blockers": [],
  "warn": ["R1", "R2", "R3"],
  "info": ["R4", "R5"],
  "fix_routing": {
    "R1": "defer Session B / follow-up — do not block merge",
    "R2": "operator host install; not product",
    "R3": "human commit hygiene — exclude freeze-file",
    "R4": "accept; swallow AC is reconciler JSON",
    "R5": "accept; documented WARN"
  }
}
```

| ID | Class | Action |
|----|-------|--------|
| R1 | WARN / defer | No code fix this chain (flaky identity). File as follow-up, not BLOCK. |
| R2 | WARN / ops | No product fix. |
| R3 | WARN / process | Human: path-scoped commit. Execute did not `git checkout` freeze file (would destroy other work). |
| R4–R5 | INFO | No fix. |

**Review exit gate:** all BLOCKs fixed or accepted — none open. REVIEW.md is final for this chain.
