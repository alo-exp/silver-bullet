# APPLY — rung 07 Pi Claude Opus 5 High pass 2 (rerun-2)

**Worker:** Grok 4.6 High (Fix/APPLY). Not Fast. Not Composer.  
**Disposition:** ACCEPT-apply — ordered pack **R7b-F01–R7b-F16** (3 HIGH, 6 MED, 6 LOW, 1 nit). **R7b-F17 not encoded** (triage REJECT).  
**Pre-APPLY SHA-256:** `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc`  
**Post-APPLY SHA-256:** `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7`  
**Twins identical:** **y**

**Targets:** [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) and [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) (byte-identical).

**KEEP REJECT:** unchanged (two files; Clarify does not write SPEC.md; ingest stays; no third canonical doc; **one 9-turn interview for every kind** wording left intact — F17 not encoded; interview not reopened). **R7-F01–F13** and **R6\*** encodings retained. Spec-floor not tightened.

Did not implement templates/skills. Did not switch branches. Did not commit. Did not `--record-rung-review-outcome`. Did not launch pass 3 or Claude Extra High.

## Per-ID freeze cites (post-APPLY)

| ID | Sev | Ledger | Freeze cites | What changed |
|----|-----|--------|--------------|----------------|
| R7b-F01 | HIGH | APPLIED | L258, L313, L457, L474, L587, L596 | Migrate-path `.planning/.spec-kind-migration.md` is **retained after successful install** as operator-visible, non-canonical, non-plugin-mirrored, not-parsed-by-any-QC (not a consumer artifact; never compile/QC input). Snapshot-restore FAIL still deletes leftover staging copies (R6c). L596 fixture: user prose preserved via retained named path. **KEEP REJECT:** not a third canonical doc. |
| R7b-F02 | HIGH | APPLIED | L73, L293, L427 | `SCAN:<section>` normalization: strip `##`/`###`, lowercase, non-alphanumerics → `-`; unique normalized heading match. Keep no-comma/no-space atom + `, ` delimiter. Fixture PASS `SCAN:quality-attributes#QA-01`; FAIL `SCAN:x#1`; FAIL ambiguous duplicate slug. Unresolvable `SCAN:` = `REQ-F71`. |
| R7b-F03 | HIGH | APPLIED | L143, L172, L426, L457 | Invariants source-precedence: (1) brief `invariants`; else (2) preserve live prior `### Invariants` as sourced (augment 2/3/4b); else (3) ASK. Fabricate never. Path 1 still requires sourced non-empty block. Empty/scaffold FAIL `SPEC-F73` before install. |
| R7b-F04 | MED | APPLIED | L69, L143, L172, L359, L426, L457 | YAML `invariant-count` (not QC-6 required). QC-11 = presence + live MUST/MUST NOT count equals `invariant-count` ≥ 1 (`SPEC-F73`). Reviewers read SPEC YAML, not the brief. Provenance is compiler Step 7. |
| R7b-F05 | MED | APPLIED | L69, L142, L197, L426 | `decision-count` grammar: integer ≥ 0; `0`/`"0"` coerce; non-integer / negative / `v`-prefixed FAIL. Presence: ISSUE-new if missing on new compiles; INFO-legacy on predating augment. Absent key on **new** compile ⇒ QC-12 FAIL (do not skip). Same presence split for `invariant-count`. |
| R7b-F06 | MED | APPLIED | L142, L197, L457, L596, L666 | Augment `decision-count` = `max(brief decisions rows, live preserved `DEC-nn` rows)`. Wave 6 fixture: legacy SPEC with two `DEC-nn` + no brief ⇒ `decision-count: 2` and QC-12 PASS. |
| R7b-F07 | MED | APPLIED | L209, L395 | Kind catalog table is the **sole** machine source for `software-kinds.yaml`. Pack-table Notes are non-normative (MUST NOT derive YAML; MUST NOT contradict catalog). Wave 1b diffs YAML against the catalog table, not Notes. R2-F02/R2-F03 not weakened. |
| R7b-F08 | MED | APPLIED | L262, L293, L360, L427, L458, L596 | `None identified` reachable only when the kind yields zero live `QA-nn`/`SLO-nn`/`CTRL-nn` — in practice only `cli` with `nfr` and `security` both omitted. Wave 1 empty-NFR example pinned to that precondition. Wave 2/6 fixture: `web-ui` + `CTRL-01` + empty NFR + `None identified` ⇒ FAIL (neither-branch). |
| R7b-F09 | LOW | APPLIED | L159, L197, L426, L666 | Fifth ontology class **conditionally-required**. `decision-log` reclassed with predicate `decision-count` ≥ 1. Kind-catalog optionality unchanged. |
| R7b-F10 | LOW | APPLIED | L174, L426 | review-spec QC-8: every AC has `AC-nn` **and ≥1 live `AC-nn` exists** (`SPEC-F70`); zero live AC FAIL, not vacuous PASS. L174 floor citation disambiguated to SPEC QC-8 / REQUIREMENTS QC-8 / R6l / R6k / XART-F02. |
| R7b-F11 | LOW | APPLIED | L434 | Wave 2 `rg` alternation adds `decision-count\|invariant-count\|SCAN\|eligible\|spec-version` plus `REQ-F71\|REQ-F72\|XART-F03`. |
| R7b-F12 | LOW | APPLIED | L131, L283, L457, L579, L582 | **Seed:** no prior `spec-version` (path 1 greenfield or path 3 mint) writes `1`; Change History gets exactly one row for `1`; path 3 does **not** additionally bump on the same run. |
| R7b-F13 | LOW | APPLIED | L359 | Wave 1 SPEC core-template YAML asserts include `decision-count` and `invariant-count`. |
| R7b-F14 | LOW | APPLIED | L360, L361 | `QA-01, SLO-01` two-atom Source example **only** on a dedicated parser fixture (`infra-devops` or `headless-service`). `world-class-min` (`cli`) MUST NOT carry `SLO-nn`. |
| R7b-F15 | LOW | APPLIED | L288 | REQUIREMENTS headings retitled QC-1 lock + QC-8 Coverage Matrix. Four QC-1 headings; Coverage Matrix is QC-8 / `REQ-F70`, not QC-1. KEEP REJECT four-heading pin unchanged. |
| R7b-F16 | nit | APPLIED | L292–L295, L427–L428, L434, L458, L596 | Codes: unresolvable `SCAN:` → `REQ-F71`; OOS/OQ snapshot inequality → `REQ-F72`; empty-namespace floor → `REQ-F70` (QC-8) + `XART-F03` (XART); Step 8 unsourced Invariants → `SPEC-F73`. Codes added to L434 `rg`. |
| R7b-F17 | nit | **NOT ENCODED** (REJECT) | L47, L532, L710 | KEEP REJECT “one 9-turn interview for every kind” and Wave 4 “not as a universal 9-turn blob” left intact. Interview not reopened. |

**REJECT encoded:** none. **KEEP REJECT reopeners:** none. **F17:** confirmation — **not encoded**.

## SHA both twins

| Twin | Before | After |
|------|--------|-------|
| [`.planning/spec_template_world_class.plan.md`](../../spec_template_world_class.plan.md) | `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc` | `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc` | `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` |
