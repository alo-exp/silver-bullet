---
verdict: PASS
overturns: n
sha: 4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7
role: apply_verify
pass: 2
model: composer-2.5
pre_apply_sha: 22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc
twins_identical: y
f17_encoded: n
---

# verify_1-apply — Rung 07 Pi Claude Opus 5 High — pass 2 (rerun-2)

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY:** [`APPLY-rerun-2.md`](./APPLY-rerun-2.md) — pack **R7b-F01–R7b-F16**; **R7b-F17 not encoded**  
**Pre-APPLY SHA:** `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc`  
**Claimed post-APPLY SHA:** `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7`

## SHA and twin verification (independent)

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` |
| Twin B SHA-256 | `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` |
| Claimed post-APPLY match | **MATCH** |
| Twin byte identity | **MATCH** (`shasum -a 256` + `diff -q` silent) |
| Freeze line count | 720 (+6 from pre-APPLY 714) |

Twins:

- [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md)
- [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## R6 / R7-F01–F13 / KEEP REJECT regression check

| Check | Result |
|-------|--------|
| KEEP REJECT block (L41–L55) | Present — two files; Clarify does not write SPEC; ingest stays; **"one 9-turn interview for every kind"** remains in REJECT column |
| R6b-F01 staged pair commit | 15+ refs — retained in ID scheme, Step 7/8, Wave 2, Wave 6 |
| R6c-F01 snapshot-restore | Present — staging lifecycle; FAIL deletes leftover staging; successful install retains migration record per R7b-F01 |
| R6n-F01 staged-pair lineage equality | Present — parse-and-compare before install |
| R7-F01–F13 prior encodings | Retained (sourced Invariants, AC floor, eligible/SCAN, decision-count, spec-version, migration dotfile, etc.) |
| Spec-floor not tightened | R7-F02 KEEP: Overview + AC headings only |
| Wave 4 KEEP (L532) | `not as a universal 9-turn blob` — interview skip-map intact |
| No third canonical doc | Migration record explicitly non-canonical, not-parsed-by-any-QC |

No R6, R7-F01–F13, or KEEP REJECT regression observed.

## R7b-F17 not encoded

| Check | Result |
|-------|--------|
| `R7b-F17` tag in freeze | **0** occurrences |
| KEEP REJECT "one 9-turn interview for every kind" | Still in REJECT column (L47) — not reopened |
| Wave 4 universal 9-turn blob | Still rejected (L532) |
| Turn-count / interview structure | Not altered to resolve numeric collision |

**F17 encoded:** **n** (triage REJECT upheld)

## Per-ID landed (independent native read)

Independent verification on post-APPLY twins at SHA `4c229f5d…` against APPLY-rerun-2 cites and review-rerun-2 defects.

| ID | Sev | Landed | Independent check |
|----|-----|--------|-------------------|
| R7b-F01 | HIGH | **y** | L258/L596: `.planning/.spec-kind-migration.md` **retained after successful install** as operator-visible, non-canonical, not-parsed-by-any-QC; snapshot-restore FAIL still deletes leftover staging; L590 fixture asserts user prose preserved via retained named path |
| R7b-F02 | HIGH | **y** | L73/L287: SCAN `<section>` normalization (strip `##`/`###`, lowercase, non-alphanumerics → `-`); unique normalized heading match; fixtures PASS `SCAN:quality-attributes#QA-01`, FAIL `SCAN:x#1`, FAIL ambiguous duplicate slug; unresolvable → `REQ-F71` |
| R7b-F03 | HIGH | **y** | L170: Invariants source-precedence (1) brief `invariants`; else (2) preserve live prior `### Invariants` (augment 2/3/4b); else (3) ASK; fabricate never; path 1 still requires sourced non-empty block; empty/scaffold FAIL `SPEC-F73` |
| R7b-F04 | MED | **y** | L142/L170/L420: YAML `invariant-count`; QC-11 = presence + live MUST/MUST NOT count equals `invariant-count` ≥ 1; reviewers read SPEC YAML, not brief; provenance is compiler Step 7 |
| R7b-F05 | MED | **y** | L142: `decision-count` / `invariant-count` grammar (integer ≥ 0; `0`/`"0"` coerce; non-integer/negative/`v`-prefixed FAIL); absent key on **new** compile ⇒ QC-12 FAIL (do not skip); INFO-legacy on predating augment |
| R7b-F06 | MED | **y** | L142: augment `decision-count` = `max(brief decisions rows, live preserved DEC-nn rows)`; L596 Wave 6 fixture: legacy SPEC two `DEC-nn` + no brief ⇒ `decision-count: 2` and QC-12 PASS |
| R7b-F07 | MED | **y** | L209: catalog table is **sole machine source** for `software-kinds.yaml`; Notes non-normative (MUST NOT derive YAML; MUST NOT contradict catalog); Wave 1b diffs YAML against catalog table |
| R7b-F08 | MED | **y** | L258/L287/L354: `None identified` reachable only when zero live QA/SLO/CTRL — in practice only `cli` with `nfr` and `security` both omitted; L596 `web-ui` + `CTRL-01` + empty NFR + `None identified` ⇒ FAIL |
| R7b-F09 | LOW | **y** | L159: fifth class **conditionally-required**; `decision-log` reclassed with predicate `decision-count` ≥ 1; kind-catalog optionality unchanged |
| R7b-F10 | LOW | **y** | L172/L420: review-spec QC-8 requires every AC has `AC-nn` **and ≥1 live `AC-nn` exists** (`SPEC-F70`); zero live AC FAIL; L172 floor citation disambiguated to SPEC QC-8 / REQUIREMENTS QC-8 / R6l / R6k / XART-F02 |
| R7b-F11 | LOW | **y** | L434: Wave 2 `rg` alternation adds `decision-count\|invariant-count\|SCAN\|eligible\|spec-version` plus `REQ-F71\|REQ-F72\|XART-F03` |
| R7b-F12 | LOW | **y** | L131/L583: seed — no prior `spec-version` (path 1 greenfield or path 3 mint) writes `1`; Change History gets exactly one row for `1`; path 3 does **not** additionally bump on same run |
| R7b-F13 | LOW | **y** | L359: Wave 1 SPEC core-template YAML asserts include `decision-count` and `invariant-count` (with `id-tombstones`, `derived-requirements`) |
| R7b-F14 | LOW | **y** | L361/L350: `QA-01, SLO-01` two-atom Source example **only** on dedicated parser fixture (`infra-devops` or `headless-service`); `world-class-min` (`cli`) MUST NOT carry `SLO-nn` |
| R7b-F15 | LOW | **y** | L288: REQUIREMENTS headings retitled **"Headings (QC-1 lock + QC-8 Coverage Matrix)"**; four QC-1 headings; Coverage Matrix is QC-8 / `REQ-F70`, not QC-1; KEEP REJECT four-heading pin unchanged |
| R7b-F16 | nit | **y** | L452/L458: unresolvable `SCAN:` → `REQ-F71`; OOS/OQ snapshot inequality → `REQ-F72`; empty-namespace floor → `REQ-F70` + `XART-F03`; unsourced Invariants → `SPEC-F73`; codes in L434 `rg` |
| R7b-F17 | nit | **not encoded** | KEEP REJECT and Wave 4 wording intact; 0 `R7b-F17` tags; interview not reopened |

**Landed:** 16/16  
**Missing:** 0/16  
**F17 encoded:** n  
**Overturned:** 0/16

## Verdict

**PASS** — Post-APPLY SHA `4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7` matches claimed; twins byte-identical; all 16 R7b encodings independently confirmed on native freeze read; R7b-F17 not encoded; R6/R7-F01–F13/KEEP REJECT encodings retained; no overturns.
