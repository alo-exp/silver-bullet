# verify_1 — Rung 01 re-run pass 1 (Cursor GLM 5.2 High)

**Verifier:** Grok 4.5 High (`cursor-grok-4.5-high` / `sb-grok-4-5-high`), native Cursor Task only.  
**Role:** RFL verify_1 (falsify/confirm reviewer findings). Not Reviewer. No APPLY. No branch switch. No commit.  
**Date:** 2026-08-29.  
**Review under test:** [`.planning/rfl-spec-template-world-class/rung-01-cursor-glm-5.2-high/review-rerun-1.md`](review-rerun-1.md)  
**Brief:** [`brief-review-rerun-1.md`](brief-review-rerun-1.md)  
**Claim:** **NOT CLEAN** (0 HIGH, 2 MED, 1 LOW).

## Freeze integrity

```
shasum -a 256 .planning/spec_template_world_class.plan.md
edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96
```

| Check | Result |
|-------|--------|
| Expected SHA-256 | `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96` |
| Live freeze | **MATCH** |
| Twin [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | **MATCH** same SHA; `diff -q` identical (652 lines) |
| Reviewer freeze SHA claim | Correct (not invented) |

**STOP condition:** not triggered. Branch: `main` (no switch). Original [`verify_1.md`](verify_1.md) left untouched.

## Method

- Graphify CLI first (`graphify query "spec_template_world_class QC-7 multi ux forbidden Wave 4 capture schema nfr blast radius"`).
- agentmemory `memory_save` at start + on verdict.
- Re-checked freeze Wave 2 QC-7 pin, catalog `multi` / `ux` forbid rule, Wave 4 capture schema vs kind-gated turns, compiler concat “non-empty brief fields,” blast-radius Clarify row vs R2-F01 `nfr` turn — against freeze SHA `edf2c256…` only.
- Did not rewrite freeze. Did not APPLY. Did not launch verify_2. Did not commit.

## Per-finding verdicts

### R1b-F01 — MED — QC-7 kind-awareness is a closed kind list; `multi` (and catalog computation) can still contradict QC-1 — **CONFIRMED**

| Claim | Evidence |
|-------|----------|
| QC-7 SPEC-F61 exemption is a six-kind parenthetical | Freeze **L398**: “Do **not** require `## UX Flows` or emit `SPEC-F61` when `ux` is forbidden for the kind (`cli`, `http-api`, `library-sdk`, `data-ml`, `infra-devops`, `headless-service`), even if `figma-url` is present.” |
| Positive QC-7 set also omits `multi` | Same **L398**: “For kinds where `ux` or `mobile` is present/required (`web-ui`, `mobile`, `plugin-extension` with `ux`)…” — no `multi` |
| Same sentence requires non-contradiction with catalog QC-1 | Freeze **L398**: “QC-7 must not contradict kind-aware QC-1.” |
| QC-1 is catalog-computed (incl. `multi` via `software-kinds`) | Freeze **L241**: “review-spec QC-1 checklist is **computed from the catalog** for the file’s `software-kind`…”; **L398** QC-1: “∪ kind-required packs for `software-kind` (and `software-kinds` if `multi`).” |
| `multi` forbids `ux` when all constituents forbid it | Freeze **L233**: “forbidden only if **all** listed kinds forbid it **and** none require it”; **L128** same rule |
| Concrete deadlock case | `software-kind: multi` + `software-kinds: [cli, http-api]` → catalog forbids `ux` (both forbid; neither requires) → QC-1 must not require `## UX Flows` / must ISSUE present UX (`SPEC-F08`). File’s kind value is `multi`, which is **not** in the L398 exemption list → enum-matching implementer still emits `SPEC-F61` when `figma-url` is set |

Residual R3-F01 APPLY hole (six atomic kinds only), not a re-open of “QC-7 is kind-blind.” MED correct — same impossible-pass class as R3-F01, now on first-class `multi`. Plugin optional-`ux`-declined is a related enum gap (optional ≠ forbidden list); primary claim stands on `multi` alone. Not invented.

### R1b-F02 — MED — Wave 4 capture schema does not name brief fields for eight kind-gated packs — **CONFIRMED**

| Claim | Evidence |
|-------|----------|
| Capture schema delta names only AC / `nfr` / `decisions` | Freeze **L461**: “Capture schema: AC as GWT-ready bullets; Quality Attributes (`QA-nn` seeds) from the kind-gated `nfr` turn (R2-F01); **`decisions` field** …” — no `security` / `telemetry` / `api` / `cli` / `mobile` / `pipeline` / `ops` / `examples` (nor `ux`/`errors`/`data` as named schema fields in this freeze sentence) |
| Kind-gated turns for those packs exist | Freeze **L463–L475**: UX, Errors, Data, Quality Attributes (`nfr`), Security, Telemetry, API, CLI, Mobile, Pipeline, Operations, Examples |
| Compiler concat depends on “non-empty brief fields” | Freeze **L239**: “Concatenate `core` + required packs + optional packs that have non-empty brief fields.” |
| `security` is required for eight kinds | Freeze **L184**: “required: web-ui, http-api, mobile, plugin-extension, headless-service, data-ml, library-sdk, infra-devops (R1-F06, R2-F02)” |
| Ontology still demands brief→section for kind-required | Kind-required headings must come from brief or `_TBD — Clarify skipped illegally_` ISSUE (freeze pack/ontology contract; Wave 4 Verify **L480** asserts turn *names* as skippable, not capture-field keys for concat) |

Turns without named capture fields leave required packs (esp. `security`) unsourced for concat — same class as R1-F05 (trigger/path without a field). MED correct. Not invented. Nuance: live clarify already has UX/Errors/Data historically; this freeze’s capture-schema bullet still fails to name keys for the eight new/required packs the compiler must read.

### R1b-F03 — LOW — Blast radius still lists Clarify “optional quality prompt” after R2-F01 — **CONFIRMED**

| Claim | Evidence |
|-------|----------|
| Blast-radius Clarify row still says optional quality prompt | Freeze **L288**: “Clarify \| `skills/silver-clarify/SKILL.md` (kind-first turn; kind-gated domain turns; skip map of existing turns only; `decisions` capture; Turn 5 GWT; **optional quality prompt**)” |
| Wave 4 body makes `nfr` a real (sometimes mandatory) turn | Freeze **L467**: “Quality Attributes (`nfr`) — … **Mandatory when the kind lists `nfr` as required** (`infra-devops`, `data-ml`, `headless-service`)… this is a real listed turn, not a skip citing a nonexistent nfr turn.” |
| Pinned sequence cites R2-F01 | Freeze **L463**: “R2-F01 adds `nfr` as a real turn” |

Checklist row contradicts the Wave 4 pin and can invite restoring the deleted optional-QA-prompt defect. LOW correct — residual leftover, not plan-hygiene-only. Not invented.

## Reviewer meta-checks

| Check | Result |
|-------|--------|
| Freeze SHA | Correct (`edf2c256…b54b96`) |
| Twin PLAN byte-identical | Correct |
| Finding IDs unique | R1b-F01…R1b-F03 unique; did not re-open R1/R2/R3 IDs except as residual text holes |
| Invented findings | None — all three grounded in freeze `edf2c256…` |
| Wrong severity dump | No — 0 HIGH / 2 MED / 1 LOW fit evidence; F01 correctly MED (residual enum vs catalog, not a new kind-blind QC-7) |
| NOT CLEAN verdict | **Sustained** — two MED contract holes block CLEAN; LOW reinforces |
| KEEP REJECT | Honored — two files; Clarify ≠ SPEC writer; ingest stays; no third kind doc; REQUIREMENTS OOS/Open Items kept. No KEEP REJECT violation |
| Review-only | No implement / branch / commit / freeze mutation in `review-rerun-1.md` |

## Parent triage cross-check

| ID | Parent disposition | verify_1 |
|----|--------------------|----------|
| R1b-F01 | ACCEPT if confirmed | **CONFIRMED** → ACCEPT-worthy |
| R1b-F02 | ACCEPT if confirmed | **CONFIRMED** → ACCEPT-worthy |
| R1b-F03 | ACCEPT if confirmed | **CONFIRMED** → ACCEPT-worthy |

No REJECT-as-wrong.

## Extra issues (verify)

None that change the verdict. Plugin optional-`ux` + filled `figma-url` is already noted under F01 as secondary enum gap; not a fourth finding.

## Overall verdict

**verify_1 PASS** (findings confirmed; reviewer’s **NOT CLEAN** stands)

All three claimed findings (R1b-F01…R1b-F03) are real against freeze SHA `edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96`. Reviewer did not invent issues, did not mis-hash the freeze, did not violate KEEP REJECT, and did not dump severity incorrectly. GLM consecutive CLEAN streak remains **0** (valid ACCEPT-worthy findings present; streak requires two consecutive zero-valid reviews).

## Appendix — SHA

```
edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96  .planning/spec_template_world_class.plan.md
edf2c256dcf987016c887555bb0a60fadd0c45b636fd101faf309f3729b54b96  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```
