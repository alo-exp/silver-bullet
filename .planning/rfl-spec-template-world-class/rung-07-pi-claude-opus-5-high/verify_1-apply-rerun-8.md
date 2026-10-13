---
verdict: PASS
overturns: n
sha: 892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4
role: apply_verify
pass: 8
model: composer-2.5
pre_apply_sha: ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085
twins_identical: y
f17_encoded: n
---

# verify_1-apply — Rung 07 Pi Claude Opus 5 High — pass 8 (rerun-8)

**Role:** apply_verify (Composer 2.5) — verify-only; no APPLY, triage, commit, or freeze mutation.  
**APPLY:** [`APPLY-rerun-8.md`](./APPLY-rerun-8.md) — pack **R7h-F01–R7h-F11** (5 MED, 4 LOW, 2 nit); **R7b-F17 not encoded**  
**Pre-APPLY SHA:** `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085`  
**Claimed post-APPLY SHA:** `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4`

## SHA and twin verification (independent)

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4` |
| Twin B SHA-256 | `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4` |
| Claimed post-APPLY match | **MATCH** |
| Pin diverges from `ba563660…` | **y** (expected post-APPLY advance) |
| Pin still equals `ba563660…` | **n** (hop not stale) |
| Pin still equals `ba563660336894ffa204a68c49b475b582859bdec714a48c5a45b1a963b79085` | **n** |
| Twin byte identity | **MATCH** (`shasum -a 256` + `diff -q` silent) |
| Freeze line count | 726 (+1 from pre-APPLY 725) |

Twins:

- [`.planning/spec_template_world_class.plan.md`](../../../spec_template_world_class.plan.md)
- [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../../../spec-template-world-class/phases/01-world-class-spec/PLAN.md)

## R6 / R7-F01–F13 / KEEP REJECT regression check

| Check | Result |
|-------|--------|
| KEEP REJECT block (L47) | Present — two files; Clarify does not write SPEC; ingest stays; **"one 9-turn interview for every kind"** remains in REJECT column |
| `R7b-F17` tag in freeze | **0** occurrences — not encoded |
| Wave 4 KEEP | `not as a universal 9-turn blob` — interview skip-map intact |
| No third canonical doc | Migration record explicitly non-canonical, not-parsed-by-any-QC (R7g-F01 preserved-prose record retained) |
| R6 / R7g / R7f / R7e / R7d / R7c / R7b / R7 prior encodings | Retained (spot-check: R7g-F01 preserved-prose L313 area, R7g-F04 clause (c) L73, R7f-F04 ordinal re-anchor, R7e-F02 eligible-ID join, R7d-F04 invariants supersede, R7c-F03 invariant grammar, R7b-F06 non-deletion) |
| `ID-less heading slug + ordinal` escape hatch | **0** hits — deleted per R7h-F04 |
| Bad exhaustion shorthand `all \`00–99\` live or tombstoned` | **0** hits (R7f-F03 / R7g-F09 fix retained) |

No R6, R7-F01–F13, or KEEP REJECT regression observed.

## R7b-F17 not encoded

| Check | Result |
|-------|--------|
| `R7b-F17` tag in freeze | **0** occurrences |
| KEEP REJECT "one 9-turn interview for every kind" | Still in REJECT column (L47) — not reopened |
| `change-summary` provenance | L182/L516: operator-supplied brief field only — never interview-sourced (KEEP: do not reopen the interview) |
| Turn-count / interview structure | Not altered to resolve numeric collision |

**F17 encoded:** **n** (triage REJECT upheld)

## Per-ID landed (independent native read)

Independent verification on post-APPLY twins at SHA `892b263d…` against APPLY-rerun-8 cites.

| ID | Sev | Verdict | Heading / contractual sentence (freeze quote) |
|----|-----|---------|-----------------------------------------------|
| R7h-F01 | MED | **LANDED** | **Ordinal stability (R7h-F01, L73):** "on any compile that mutates **any section cited by a live `SCAN:…#bNN`** (not only an ID-less section — mixed `## Assumptions` is `bNN`-citable)" — re-anchor or fail-before-write / ASK; no silent repoint. Wave 6 / L437 mixed-Assumptions insert-at-position-1 fixture: prior live `SCAN:assumptions#b02` ⇒ re-anchor or fail-before-write (R7h-F01). L457 Step 7 / L458 Step 8 preconditions restate. |
| R7h-F02 | MED | **LANDED** | **Step 7/8 rewrite ownership (R7h-F02, L73/L457/L475):** "Step 7 records the SPEC-side delta; Step 8 serialize **rewrites** the REQUIREMENTS Source ordinal — R7h-F02" — Source-cell rewrite is 8a-class; R6d fixed-point restated ("A Source-cell rewrite after a pair PASS is stale until R6d revalidation (R7h-F02)"). L475 Wave 3 `- contains` names Step 7 bullet-text delta + Step 8 Source rewrite. |
| R7h-F03 | MED | **LANDED** | **Version-cell stability (R7h-F03, L73):** "on a compile that removes or renumbers a cited `spec-version` row (including malformed-prior seed — R7c-F05/R7f-F05), either re-anchor the citation to the surviving canonical row (or the retained migration-record entry, deterministically) **or** fail-before-write / ASK — no silent `REQ-F71` dead-end." L131 malformed-prior seed retained. L458 Step 8: "unre-anchorable live `SCAN:…#v<integer>`". L602 malformed-prior fixture references clause (c) re-anchor. KEEP REJECT: migration record not canonical / not QC-parsed. |
| R7h-F04 | MED | **LANDED** | **Clause (b) scope (R7h-F04, L73/L198):** Deleted nfr Notes "(or the matching ID-less heading slug + ordinal)" — **0** hits remain. L198: "`### Invariants` is the sole ID-less NF SCAN anchor — R7g-F05; Overview prose is not SCAN-addressable". L73: "clause (b) is legal **only** for `### Invariants` and unprefixed `## Assumptions` entries"; "Other sections (including `## Overview`) cited with `bNN` FAIL `REQ-F71`". No `INV-nn`. |
| R7h-F05 | MED | **LANDED** | **Assumptions entry grammar (R7h-F05, L73/L175/L437):** "**Entry grammar (R7h-F05):** count only top-level `-` bullets under `## Assumptions` whose first non-marker token is `[ASSUMPTION:` or an `ASM-nn` label; continuation, nested, and non-conforming lines do not count; apply identically at Step 7/8, `review-requirements`, and `review-cross-artifact`." L175 restates per-entry SCAN + entry grammar. L437 mixed-section PASS fixtures retained. |
| R7h-F06 | MED | **LANDED** | **Prefix migration (R7h-F06, L73/L175/L457):** "**Prefix migration (R7h-F06):** when a cited unprefixed entry gains `ASM-nn` in the same compile, rewrite the citation to clause (a) (`decision-row-identity`-style entry-text match) or fail-before-write / ASK — reviewers then enforce the per-entry MUST unconditionally." Bound with F01/F02 rewrite ownership at L457. |
| R7h-F07 | LOW | **LANDED** | **Catalog `-00` absent primary (R7h-F07, L217/L457/L492/L602):** "`EX-01`–`EX-99` live or tombstoned **and** `EX-00` live, tombstoned, **or absent** (never mint it; `-00`-absent is the primary catalog fixture — R7h-F07)" at four catalog-side fixture sites. L217 parseable `00–99` domain unchanged. Do not weaken R6f / R7d-F09 / R7e-F04 / R7g-F09. |
| R7h-F08 | LOW | **LANDED** | **Wave 2/3 clause (c) tokens (R7h-F08, L434/L476):** L434 Wave 2 `rg` alternation adds `version-cell\|v<integer>`. L476 Wave 3 `- contains`: "clause (c) version-cell `v<integer>` as a legal `<line-or-id>` form at Step 8 serialize/parse (R7g-F04/R7h-F08)". L427/L428 reviewer surfaces retain clause (c). |
| R7h-F09 | LOW | **LANDED** | **Assumptions negative fixture (R7h-F09, L437):** "`SCAN:assumptions#b01` naming the `ASM-01` entry FAIL `REQ-F71` (R7h-F09)" beside the two PASS cases (`#ASM-01`, `#b02`). Per-entry MUST at L73 enforced. |
| R7h-F10 | nit | **LANDED** | **`decision-log` Default class enum-only (R7h-F10, L197/L209):** L197 Default class: "**conditionally-required** (R7c-F15/R7h-F10)" — enum-only in the Default class cell; scope + predicate remain in Notes / L159 / L204. L209 five-class ontology rule retained. |
| R7h-F11 | nit | **LANDED** | **No-structural-change template binding (R7h-F11, L182/L602):** "`version bumped to N (<reason>); no structural changes`) where `N` is the post-bump YAML `spec-version` decimal and `<reason>` is exactly one of `prior spec-version malformed` / `seed-only` / `bump-only` (R7h-F11)". L602 malformed-prior fixture references closed `<reason>` + bump `N` = post-bump YAML integer. Fabricate-never and ASK terminal unchanged. |

**LANDED:** 11/11  
**PARTIAL:** 0/11  
**MISSING:** 0/11  
**F17 encoded:** n  
**Overturned:** 0/11

## Verdict

**PASS** — Post-APPLY SHA `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4` matches claimed pin; twins byte-identical; freeze advanced from `ba563660…`; all 11 R7h encodings independently confirmed on native freeze read; R7b-F17 not encoded; R6/R7/KEEP REJECT encodings retained; no overturns. **verify_2 skipped** (APPLY-after-NOT-CLEAN hop; overlay applies only on CLEAN).

## Return summary

| Field | Value |
|-------|--------|
| SHA | `892b263d530f867b21c36426e6b1e7917690aafd1d95bef2d3d92cb951addde4` |
| verify_1-apply | **PASS** |
| LANDED / PARTIAL / MISSING | **11 / 0 / 0** |
| Freeze hashes | **MATCH** (both twins at pin) |
| F17 encoded | **n** |
| KEEP REJECT collisions | **none** |
| Artifact | [`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-apply-rerun-8.md`](./verify_1-apply-rerun-8.md) |
| Parent next step | **Record accept-apply**, then `--write-review-brief` for Claude High **pass 9** |
