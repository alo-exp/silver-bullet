# APPLY — rung 07 Pi Claude Opus 5 High pass 10 (rerun-10)

**Worker:** Grok 4.6 High (Fix/APPLY). Not Fast. Not Composer. Not Extra High. Not Pi. Not `--continue`.  
**Disposition:** ACCEPT-apply — ordered pack **R7j-F01–R7j-F09** (0 HIGH, 4 MED, 3 LOW, 2 nit). **0 REJECT in this pass.** **R7b-F17 not encoded** (prior REJECT; KEEP REJECT / 9-turn left intact).  
**Pre-APPLY SHA-256:** `56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed`  
**Post-APPLY SHA-256:** `fcf094919aeb37c13cc7125f52276052ea9b2777e44d842d02ec4242aaef06e2`  
**Twins identical:** **y**

**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical).

**KEEP REJECT:** unchanged (two files; Clarify does not write SPEC.md; ingest stays; no third canonical doc; **one 9-turn interview for every kind** wording left intact — F17 not encoded; interview not reopened). Migration record stays non-canonical / not QC-parsed / not a SCAN re-anchor target. **R7i-F01–F11**, **R7h-F01–F11**, **R7g-F01–F10**, **R7f-F01–F14**, **R7e-F01–F10**, **R7d-F01–F12**, **R7c-F01–F16**, **R7b-F01–F16**, **R7-F01–F13**, and **R6\*** encodings retained. Spec-floor not tightened. QC / Wave / KEEP REJECT intact.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not `--record-rung-review-outcome`. Did not `--write-review-brief`. Did not launch Pi. Did not launch verify_2.

## Per-ID freeze cites (post-APPLY)

| ID | Sev | Ledger | Freeze cites | What changed |
|----|-----|--------|--------------|----------------|
| R7j-F01 | MED | APPLIED | L144, L217, L426 | Tombstone entry grammar is exact two-digit catalog **or core** ID, including `ASM-nn`. L217 core-ID enum adds optional-to-emit never-minted `ASM-nn`. QC-13 parse accepts `ASM-nn` in SPEC `id-tombstones`. Bound with F02. |
| R7j-F02 | MED | APPLIED | L217, L457, L594 | Step 7 / Wave 6 append a removed live operator-authored `ASM-nn` to SPEC `id-tombstones` on augment (paths 2/3/4b). Compiler still does **not** mint `ASM-nn`. Bound with F01. |
| R7j-F03 | MED | APPLIED | L457, L458 | Step 7 records version-cell / `change-row-identity` delta when a cited `spec-version` row is removed/renumbered (incl. malformed-prior seed). Step 8 serialize applies that delta. KEEP REJECT: migration record is not a SCAN re-anchor target. Bound with F04. |
| R7j-F04 | MED | APPLIED | L73, L131, L427, L428, L457, L603 | ASK answer space: (1) name a surviving canonical Change History row with the same `change-row-identity` (re-anchor) **or** (2) confirm fail-before-write. Illegal: repoint without match; drop citation; keep stale Source; re-anchor to the migration record. Bound with F03. |
| R7j-F05 | LOW | APPLIED | L434 | Wave 2 `rg` alternation adds `change-row-identity`. Existing `decision-row-identity\|ASM-nn\|per-entry` kept (R7i-F07). |
| R7j-F06 | LOW | APPLIED | L437 | QC-string asserts: `SCAN:change-history#v01` FAIL `REQ-F71`; `#v0` FAIL (dead); `change-row-identity`-match re-anchor PASS and identity-mismatch silent `vN`→`v1` FAIL. Bound with F03/F04. |
| R7j-F07 | LOW | APPLIED | L477 | Wave 3 `- contains` prefix-migration: cited unprefixed Assumptions entry gains operator-authored `ASM-nn` ⇒ Step 7 records clause-(a) rewrite delta, Step 8 rewrites Source `bNN`→`ASM-nn` or fail-before-write. |
| R7j-F08 | nit | APPLIED | L73, L175 | Assumptions counting token is exact `ASM-[0-9]{2}`; `ASM-1` / `ASM-001` are non-conforming and do not count. |
| R7j-F09 | nit | APPLIED | L197 | Folded dangling "(optional pack for every kind)." into Notes with R7e-F09 tag: *derived from the current catalog, non-normative.* |

**REJECT encoded:** none. **KEEP REJECT reopeners:** none. **F17:** confirmation — **not encoded**. **R7i-F01–F11 / R7h-F01–F11 / R7g-F01–F10 / R7f-F01–F14 / R7e-F01–F10 / R7d-F01–F12 / R7c-F01–F16 / R7b-F01–F16 / R7-F01–F13 / R6\*:** not regressed.

**Skipped:** none of R7j-F01–F09 (all 9/9 ACCEPT residual at pin `56cdd698…`; prior-hop R7i rows not re-encoded).

## SHA both twins

| Twin | Before | After |
|------|--------|-------|
| [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) | `56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed` | `fcf094919aeb37c13cc7125f52276052ea9b2777e44d842d02ec4242aaef06e2` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed` | `fcf094919aeb37c13cc7125f52276052ea9b2777e44d842d02ec4242aaef06e2` |
