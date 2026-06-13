# PLAN — Phase 056: Zuvo / AS1 Runtime Parity

**Phase:** `056-zuvo-runtime-parity`  
**Type:** Execute (runtime enforcement)  
**Status:** Plan-only — no implementation in this commit  
**Context:** [.planning/phases/056-zuvo-runtime-parity/CONTEXT.md](./CONTEXT.md)  
**Audit source:** Session `115077ee` (doc-vs-runtime gap review)

---

## 1. Goal

Close the gap between v0.39.2 **documented** AS1 structural parity and **runtime-enforced** parity so Zuvo migrators retain backlog deduplication, normalized evidence tables, durable UI design state, and install diagnostics without adopting excluded AS1 behaviors (multi-provider review, always-on auto-routing, or numeric scoring). This phase lands the scripts, hook gates, init wiring, and tests that make the parity ledger truthful — not new capability families.

---

## 2. Scope

| In scope | Out of scope |
|----------|--------------|
| `scripts/validate-evidence-findings.{py,sh}` + `hooks/lib/evidence-schema-gate.sh` + `completion-audit.sh` delivery integration | Multi-provider / Sidekick / Kay adversarial review routing |
| `scripts/lib/evidence_common.py` shared normalization + fingerprints | Always-on session-start auto-routing |
| `scripts/silver-add.sh` (`fingerprint`, `dedup`, `prioritize`) | Unified numeric grades / tiered scoring across audits |
| `scripts/silver-scan.py` import of `scan_fingerprint` from shared lib | New domain-audit packs or `silver:test` modes |
| `scripts/stamp-interface-state.sh` + `silver:init` step 3.2.1 | Marketplace packaging redesign |
| `scripts/sb-bootstrap.sh` install probe + migrator quickstart | GSD / Superpowers dependency changes |
| Hook + script unit tests; `completion-audit` delivery-gate regression | Strict evidence-schema blocking by default (warn-first only this phase) |
| Agent/skill-source mirrors + `sync-codex-package.sh` refresh | Modifying installed plugin cache |
| `docs/sb-vs-as1.md` honesty pass (runtime evidence column) | `silver-bullet.md` §8 plugin-boundary changes |

---

## 3. Requirements

| ID | Requirement | Verification |
|----|-------------|--------------|
| ZRP-01 | `scripts/lib/evidence_common.py` exports `normalize_text`, `audit_fingerprint`, `scan_fingerprint` with stable hashes | `tests/scripts/test-silver-add-fingerprint.sh` + Python import in `silver-scan.py` |
| ZRP-02 | `scripts/silver-add.sh fingerprint` returns identical output to `audit_fingerprint()` for the same inputs | `test-silver-add-fingerprint.sh` cross-check |
| ZRP-03 | `scripts/silver-add.sh dedup` detects fingerprints in `docs/issues/*.md` and `.silver-bullet/scan-state.json` | `test-silver-add-fingerprint.sh` dedup case |
| ZRP-04 | `scripts/silver-add.sh prioritize` computes `impact + risk + evidence_strength - effort` | `test-silver-add-fingerprint.sh` score case |
| ZRP-05 | `scripts/validate-evidence-findings.py` scans `.planning/**/{DOMAIN-AUDIT,REVIEW,QUALITY-GATES,SECURITY,VERIFICATION,UI-REVIEW,TEST-ENGINEERING}.md` finding tables | `test-validate-evidence-findings.sh` |
| ZRP-06 | Validator emits human + `--json` output; `--strict` exits non-zero on warnings | `test-validate-evidence-findings.sh` strict case |
| ZRP-07 | `hooks/lib/evidence-schema-gate.sh` calls validator on delivery; warn-first; blocks only when `SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1` | New/extended `tests/hooks/test-completion-audit.sh` cases |
| ZRP-08 | `completion-audit.sh` invokes evidence schema gate on final delivery alongside doc-scheme gate | Hook test + manual `gh pr create` dry-run JSON |
| ZRP-09 | `scripts/stamp-interface-state.sh` stamps `.planning/interface/STATE.md` from template for UI projects; skips when exists | `test-stamp-interface-state.sh` |
| ZRP-10 | `silver:init` step 3.2.1 calls `stamp-interface-state.sh` (plugin root fallback) | Skill text + init integration test or scaffold test |
| ZRP-11 | `scripts/sb-bootstrap.sh` checks `jq`, runs diagnostics, prints init/plugin next steps + migrator pointers | `test-sb-bootstrap.sh` |
| ZRP-12 | `skills/silver-add/SKILL.md` documents canonical `silver-add.sh` commands (not inline-only hash prose) | Grep + skill contract review |
| ZRP-13 | Quality surfaces reference validator in skill steps (`silver:domain-audit`, `silver:quality-gates`, `silver:review`) | Skill diff + grep `validate-evidence-findings` |
| ZRP-14 | `docs/sb-vs-as1.md` parity evidence table lists runtime paths only when scripts/tests exist on `main` | Doc review after merge |
| ZRP-15 | Full test suite passes with zero regressions | `bash tests/run-all-tests.sh` |
| ZRP-16 | Codex package surface includes new scripts after sync | `bash scripts/sync-codex-package.sh && bash tests/scripts/test-sync-codex-package.sh` |

---

## 4. Design

### 4.1 Files to add

| Path | Role |
|------|------|
| `scripts/lib/evidence_common.py` | Canonical `normalize_text`, `audit_fingerprint`, `scan_fingerprint` |
| `scripts/silver-add.sh` | CLI: `fingerprint`, `dedup`, `prioritize` |
| `scripts/validate-evidence-findings.py` | Markdown finding-table validator |
| `scripts/validate-evidence-findings.sh` | Thin bash wrapper → Python |
| `hooks/lib/evidence-schema-gate.sh` | `sb_evidence_schema_gate_enforce` helper |
| `scripts/stamp-interface-state.sh` | UI-project STATE.md stamper |
| `scripts/sb-bootstrap.sh` | One-command onboarding probe |
| `tests/scripts/test-silver-add-fingerprint.sh` | Fingerprint/dedup/prioritize tests |
| `tests/scripts/test-validate-evidence-findings.sh` | Validator tests |
| `tests/scripts/test-stamp-interface-state.sh` | Interface state tests |
| `tests/scripts/test-sb-bootstrap.sh` | Bootstrap smoke tests |

### 4.2 Files to modify

| Path | Change |
|------|--------|
| `hooks/completion-audit.sh` | Source `evidence-schema-gate.sh`; add `emit_warn`; call `run_evidence_schema_delivery_gate` on delivery tier |
| `scripts/silver-scan.py` | Import `scan_fingerprint` from `evidence_common` when available; retain inline fallback |
| `skills/silver-add/SKILL.md` | Wire `silver-add.sh` commands in Structured Audit Findings |
| `skills/silver-init/SKILL.md` | Add step 3.2.1 interface state stamping |
| `skills/silver-domain-audit/SKILL.md` | Add validator invocation in findings step |
| `skills/silver-quality-gates/SKILL.md` | Add validator reference for dimension finding tables |
| `skills/silver-review/SKILL.md` | Add validator reference for REVIEW.md findings |
| `agents/{claude,codex}/silver-*/SKILL.md` | Mirror skill changes via `render-agent-bundle.py` |
| `plugins/silver-bullet/skill-source/**` | Regenerated from agents/codex |
| `docs/sb-vs-as1.md` | Update Parity Closure Evidence + frontmatter status note |
| `docs/RUNTIME-COMPATIBILITY.md` | Mention `sb-bootstrap.sh` alongside diagnostics (optional one paragraph) |
| `tests/hooks/test-completion-audit.sh` | Delivery-gate cases for evidence schema warn/strict |

### 4.3 Hook integration points

```
Final delivery command (gh pr create | gh release create | deploy)
  └─ completion-audit.sh (delivery tier)
       ├─ run_workflow_strict_gate
       ├─ run_doc_scheme_delivery_gate
       └─ run_evidence_schema_delivery_gate  ← NEW
            └─ sb_evidence_schema_gate_enforce("delivery", repo_root, emit_warn, emit_block)
                 └─ scripts/validate-evidence-findings.sh [--strict] [--json]
```

- **Event:** `PreToolUse/Bash` and `PostToolUse/Bash` (existing `completion-audit.sh` matchers).
- **Tier:** Final delivery only (same as doc-scheme gate).
- **Failure mode:** Warn + JSON message by default; block when `SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1`.
- **Fail-open:** Missing validator, missing `python3`, or validator crash → warn and continue.

### 4.4 Fingerprint canonical formula (decision)

**Normalization** (`normalize_text`):

1. Lowercase
2. Replace em-dash `—` with `-`
3. Strip inline backticks (keep inner text)
4. Collapse whitespace to single spaces
5. Trim leading/trailing whitespace and `-.:;,`

**Audit finding fingerprint** (used by `silver:add`, domain-audit backlog handoff):

```text
sha256( normalize(domain) + "\n" + normalize(scope) + "\n" + normalize(finding) )
```

**Scan candidate fingerprint** (used by `silver:scan` dedup state):

```text
sha256( normalize(title) + "\n" + normalize(context) )
```

**Prioritization score** (advisory, not a ship gate):

```text
priority_score = impact + risk + evidence_strength - effort
```

Ranges: impact/risk/effort 1–5; evidence_strength 1–3 (per `silver:add` SKILL).

**Migration note:** Existing `scan-state.json` fingerprints computed with the pre-unification inline logic in `silver-scan.py` may change if normalization diverged. Wave 1 must add a regression vector from current `silver-scan.py` behavior; if hashes change, document one-time dedup reset in SUMMARY (no automatic migration script unless test proves breakage).

### 4.5 Init / install UX flow

```
/silver:init
  └─ step 3.2.1: stamp-interface-state.sh $PWD
       └─ skip:not-ui-project | skip:exists | stamped:.planning/interface/STATE.md

New user / migrator
  └─ bash scripts/sb-bootstrap.sh [project-root]
       ├─ jq check
       ├─ sb-diagnostics.sh (existing)
       └─ init vs already-initialized next steps + sb-vs-as1.md pointers
```

---

## 5. Tasks (ordered waves)

### Wave 0 — Reconcile WIP and baseline

| Task | Depends on | Deliverable |
|------|------------|-------------|
| 0.1 Inventory uncommitted parity WIP vs this plan | — | Checklist in `056-01-SUMMARY.md` (implementation wave) |
| 0.2 Run existing tests on WIP to establish baseline pass/fail | 0.1 | Baseline note before edits |

### Wave 1 — Shared evidence library + scan alignment

| Task | Depends on | Deliverable |
|------|------------|-------------|
| 1.1 Land `scripts/lib/evidence_common.py` | 0.2 | ZRP-01 |
| 1.2 Update `silver-scan.py` to prefer `evidence_common.scan_fingerprint` | 1.1 | ZRP-01 |
| 1.3 Add fingerprint stability tests | 1.1 | `test-silver-add-fingerprint.sh` (partial) |

### Wave 2 — silver-add CLI

| Task | Depends on | Deliverable |
|------|------------|-------------|
| 2.1 Land `scripts/silver-add.sh` | 1.1 | ZRP-02–04 |
| 2.2 Update `skills/silver-add/SKILL.md` + agent mirrors | 2.1 | ZRP-12 |
| 2.3 Complete `test-silver-add-fingerprint.sh` | 2.1 | ZRP-02–04 |

### Wave 3 — Evidence schema validator + hook gate

| Task | Depends on | Deliverable |
|------|------------|-------------|
| 3.1 Land `validate-evidence-findings.{py,sh}` | 1.1 | ZRP-05–06 |
| 3.2 Land `hooks/lib/evidence-schema-gate.sh` | 3.1 | ZRP-07 |
| 3.3 Wire `completion-audit.sh` delivery gate | 3.2 | ZRP-08 |
| 3.4 Extend `test-completion-audit.sh` + `test-validate-evidence-findings.sh` | 3.3 | ZRP-07–08 |
| 3.5 Update domain-audit / quality-gates / review skills | 3.1 | ZRP-13 |

### Wave 4 — Interface STATE init

| Task | Depends on | Deliverable |
|------|------------|-------------|
| 4.1 Land `stamp-interface-state.sh` | — | ZRP-09 |
| 4.2 Wire `silver:init` step 3.2.1 + agent mirrors | 4.1 | ZRP-10 |
| 4.3 `test-stamp-interface-state.sh` | 4.1 | ZRP-09 |

### Wave 5 — Install UX bootstrap

| Task | Depends on | Deliverable |
|------|------------|-------------|
| 5.1 Land `sb-bootstrap.sh` | — (uses existing `sb-diagnostics.sh`) | ZRP-11 |
| 5.2 `test-sb-bootstrap.sh`; optional RUNTIME-COMPATIBILITY.md mention | 5.1 | ZRP-11 |
| 5.3 Surface bootstrap in README or install docs (one line max) | 5.1 | Doc honesty |

### Wave 6 — Package sync + doc honesty

| Task | Depends on | Deliverable |
|------|------------|-------------|
| 6.1 `bash scripts/sync-codex-package.sh` | Waves 1–5 | ZRP-16 |
| 6.2 Update `docs/sb-vs-as1.md` evidence table + status frontmatter | Waves 1–5 | ZRP-14 |
| 6.3 `bash tests/scripts/test-sync-codex-package.sh` | 6.1 | ZRP-16 |

### Wave 7 — Verification + ship

| Task | Depends on | Deliverable |
|------|------------|-------------|
| 7.1 `bash tests/run-all-tests.sh` | 6.x | ZRP-15 |
| 7.2 Write `056-VERIFICATION.md` with command output | 7.1 | Acceptance evidence |
| 7.3 Patch release or changelog entry for runtime parity | 7.2 | Release note |

---

## 6. TDD policy

| Component | Test-first? | Test file | Notes |
|-----------|-------------|-----------|-------|
| `evidence_common.py` | Yes — write failing cross-check in `test-silver-add-fingerprint.sh` before finalizing API | `tests/scripts/test-silver-add-fingerprint.sh` | Shell vs Python hash equality is the contract test |
| `silver-add.sh` | Yes | `tests/scripts/test-silver-add-fingerprint.sh` | Red: missing script; green: CLI exists |
| `validate-evidence-findings.py` | Yes | `tests/scripts/test-validate-evidence-findings.sh` | Valid table pass + malformed warn + strict exit |
| `evidence-schema-gate.sh` | Partial — extend hook tests after validator green | `tests/hooks/test-completion-audit.sh` | Mock repo with DOMAIN-AUDIT.md fixtures |
| `stamp-interface-state.sh` | Yes | `tests/scripts/test-stamp-interface-state.sh` | UI detect + skip:exists |
| `sb-bootstrap.sh` | Yes (smoke) | `tests/scripts/test-sb-bootstrap.sh` | jq gate + diagnostics invocation |
| `silver-scan.py` fingerprint import | Regression after `evidence_common` | Existing `test-silver-scan.sh` | Run full scan suite in Wave 7 |
| Skill markdown | No TDD — verify via grep + review loop | Manual / `test-sync-codex-package.sh` | |

**Order:** Wave 1 tests → Wave 2 CLI → Wave 3 validator → hook tests → init/bootstrap tests → full suite.

---

## 7. Acceptance criteria

Zuvo migrators **lose nothing** (except excluded items) when:

1. **Backlog dedup works mechanically** — `bash scripts/silver-add.sh fingerprint` + `dedup` return stable IDs before filing; `silver:scan` uses the same normalization library.
2. **Evidence tables are machine-checkable** — `bash scripts/validate-evidence-findings.sh` passes on conformant DOMAIN-AUDIT/REVIEW artifacts; delivery emits warn (or block in strict mode) on drift.
3. **UI projects get durable design state** — `silver:init` stamps `.planning/interface/STATE.md` for frontend stacks without overwriting existing files.
4. **Install path is one command to orient** — `bash scripts/sb-bootstrap.sh` reports tier, missing deps, and next steps including `docs/sb-vs-as1.md`.
5. **Parity ledger is honest** — `docs/sb-vs-as1.md` "Parity Closure Evidence" rows cite scripts **and** tests that exist on the branch.
6. **Excluded AS1 behaviors stay excluded** — no new multi-provider router, no session-start auto-skill hijack, no numeric grade system added.
7. **SB enforceability preserved** — hooks still fail-open on missing deps; no hardcoded skill literals in hook scripts; plugin boundary unchanged.

---

## 8. Verification

```bash
# Per-wave (during implementation)
bash tests/scripts/test-silver-add-fingerprint.sh
bash tests/scripts/test-validate-evidence-findings.sh
bash tests/scripts/test-stamp-interface-state.sh
bash tests/scripts/test-sb-bootstrap.sh
bash tests/hooks/test-completion-audit.sh
bash tests/scripts/test-silver-scan.sh

# Package surface
bash scripts/sync-codex-package.sh
bash tests/scripts/test-sync-codex-package.sh

# Full gate
bash tests/run-all-tests.sh

# Manual smoke (optional)
bash scripts/silver-add.sh fingerprint --domain code-health --scope src/a.ts --finding 'test'
bash scripts/validate-evidence-findings.sh .
SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1 bash scripts/validate-evidence-findings.sh .  # on repo with known warnings
bash scripts/stamp-interface-state.sh /path/to/ui-fixture
bash scripts/sb-bootstrap.sh
```

**Evidence artifacts:** `056-VERIFICATION.md`, test stdout captures, updated `docs/sb-vs-as1.md` diff.

---

## 9. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| **Hook regression on delivery** — evidence gate blocks or confuses `gh pr create` | Medium | High | Warn-first default; strict mode opt-in; extend `test-completion-audit.sh` with fixture repos |
| **Fingerprint migration** — `scan-state.json` hashes change after normalization unification | Medium | Medium | Regression test against pre-change vectors; document one-time state reset in SUMMARY |
| **False-positive validator warnings** on legacy planning artifacts | High | Medium | Warn-only delivery gate; column alias map in validator; exclude archived phases if needed |
| **Doc/implementation drift recurs** — ledger marked done before tests land | Medium | High | ZRP-14 gate: no "Done" without test path; this plan supersedes v0.39.2 premature closure |
| **Plugin package missing new scripts** | Low | High | Wave 6 mandatory `sync-codex-package.sh` + `test-sync-codex-package.sh` |
| **python3 absent on user machine** | Low | Low | Fail-open warn in gate; bash bootstrap already requires jq only |
| **UI false-positive stamping** | Low | Low | `skip:not-ui-project` heuristic; `SILVER_BULLET_FORCE_INTERFACE_STATE=1` escape hatch |

---

## Dependencies

- Prior phases: `049-silver-add` (ID schema), `054-silver-scan` (scan state), `97cbce5` (contract docs)
- Blocks: honest v0.39.3+ parity release narrative; optional strict evidence gate enablement in a follow-up phase

## Rollback

Revert phase commits; remove hook source line for `evidence-schema-gate.sh`; parity ledger reverts to "contract docs only" wording. No database or schema migration — `scan-state.json` is regenerable.
