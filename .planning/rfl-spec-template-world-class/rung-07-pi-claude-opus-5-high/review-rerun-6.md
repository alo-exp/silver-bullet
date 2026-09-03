# Rung 07 — Pi Claude Opus 5 High — review pass 6 (residual re-hunt)

**Reviewer:** Claude Opus 5 High via Pi OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`) — CHARTER slug `claude-opus-5-high`.
**Role:** review-only (Policy C). No triage, no APPLY, no fix, no commit, no verify launch, no freeze mutation.
**Pass:** 6 of this rung (pass 5 = `review-rerun-5.md`, NOT CLEAN, `R7e-F01`–`R7e-F10`, all ACCEPT-applied; launcher recorded `accept-apply` ⇒ streak 0).

## Freeze pin (hashed this pass)

```
f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d  .planning/spec_template_world_class.plan.md
f5fda2aed2eeb32bd00c5ff2a30ce12c81db58067f63588403080ca8f6e5976d  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both twins byte-identical and equal to the briefed SHA `f5fda2ae…`. 723 lines. Freeze not mutated by this pass.

Tooling: `graphify query` run first (graph 43 813 nodes; freeze + twin + CONTEXT + `templates/rfl-review-brief.md` in the `01-world-class-spec/PLAN.md` community); freeze re-read end-to-end in this session (L1–L723). Pass 1–5 review files were **not** re-read or copied.

## Verdict

**NOT CLEAN** — 14 residual findings at this SHA: **1 HIGH, 4 MED, 5 LOW, 4 nit**. New IDs `R7f-F01`–`R7f-F14`. No ledger row (`R7-*`, `R7b-*` incl. REJECT `R7b-F17`, `R7c-*`, `R7d-*`, `R7e-*`, `R6b`–`R6n`, `R1`–`R5*`) is re-filed; every finding below is a defect in *this* freeze text, and each cites the line that produces it.

## R7e APPLY spot-check (landed; not re-filed)

| ID | Landed evidence at this SHA |
|----|------------------------------|
| R7e-F01 | L427 / L428 / L458 all carry "**SCAN eligible-ID join (R7d-F05, R7e-F01):** … resolve every `SCAN:` atom to its target ID **before** the eligible-set join"; `SCAN:quality-attributes#QA-01` sole-Source PASS fixture on all three surfaces. R5k exclusivity retained. |
| R7e-F02 | L73 / L143 / L198 / L293 carry section-anchored ordinal `b[0-9]{2}`; bare line numbers still `REQ-F71`; no `INV-nn`. (Residual binding gap → `R7f-F02`.) |
| R7e-F03 | L182 + L426 + L457 carry the three-branch summary provenance. (Residual totality gap → `R7f-F01`.) |
| R7e-F04 | L217 / L284 / L457 / L458 / L489 carry "`-00` … never minted" and the `01–99` + `-00`-absent predicate. (Residual: 10 stale shorthand sites → `R7f-F03`.) |
| R7e-F05 | L437 union-emission positive + count-mismatch `SPEC-F74`; L474 Wave 3 bullet; L607-area Wave 6 5-live fixture. |
| R7e-F06 | Wave 6 "Behavioral invariants-supersede fixture (R7d-F04, R7e-F06)" with append-to-`.spec-kind-migration.md` or fail-before-write. |
| R7e-F07 | L358-area Wave 1 SPEC core-template assert list includes `spec-version` with the R7-F07 grammar parenthetical. |
| R7e-F08 | L142 names `decision-row-identity` (trim / collapse / case-fold / strip emphasis + trailing punctuation) + idempotence fixture. (Residual → `R7f-F06`.) |
| R7e-F09 | `ux`, `examples`, `security`, `telemetry`, `api`, `data`, `errors`, `cli`, `mobile`, `pipeline`, `ops` Notes all carry the derived/non-normative tag. (`nfr` tag malformed → `R7f-F11`.) |
| R7e-F10 | L358-area: example `invariant-count` = counted example bullets, ≥ 1; example `decision-count` vs `## Decision Log` iff ≥ 1; asserted in `test-spec-requirements-templates.sh`. (Fixture-side gap → `R7f-F14`.) |

R7d / R7c / R7b / R7 / R6b–R6n encodings were re-checked in place and remain present; none is weakened by the findings below.

---

## Findings

### R7f-F01 — HIGH — Change History provenance branch (2) is not total: a seed-only augment yields an empty structural-delta set, dropping to ASK / fail-before-write and breaking pinned PASS-install fixtures

**Where:** L182 (`## Change History`, "Summary provenance (R7e-F03)"), L426 (review-spec QC-10), L457 (Step 7), L141 (`spec-version` malformed-prior seed), Wave 6 "Behavioral malformed spec-version fixture (R7c-F05)".

**Freeze text (L182):**
> (1) operator-supplied brief field `change-summary` if present …; else (2) deterministic derivation the reviewer can accept: **enumerated structural deltas this compile made (packs added/removed, IDs minted, IDs tombstoned, `spec-version` bump)** joined as one non-placeholder sentence; else (3) ASK; **fail before write** if unresolved. Fabricate never.

**Defect.** The branch-(2) enumeration is a closed four-item list, and every item can be empty on a legal compile:

1. The pinned R7c-F05 fixture is *augment path 2/4b with `spec-version: 0.35`* and a **brief-less** input (it is listed in the R7d-F02 brief-less Invariants precondition set, i.e. Invariants come from branch (2) preserve). On that path the freeze mandates **seed `1`**, explicitly "**do not bump a non-integer**" (L141). A *seed* is therefore **not** a "`spec-version` bump" — the only delta item that is otherwise guaranteed on augment.
2. The fixture's input is template-shaped (path 2 requires YAML `spec-version` + `## User Stories`), so live `AC-nn` / `REQ-nn` already exist ⇒ no IDs minted, none tombstoned; the kind is unchanged ⇒ no packs added/removed.
3. Result: delta set = ∅ ⇒ no sentence can be produced ⇒ branch (3) ASK ⇒ brief-less/non-interactive ⇒ **fail before write**. The freeze simultaneously pins that fixture as "pair installs".

This is the same fixture-vs-terminal collision class as R7c-F01 (Invariants ASK) and R7d-F02 (PASS-install precondition), and it is *not* covered by them: those pins were scoped to `### Invariants`, not to Change History summaries.

**Second defect in the same clause.** "else (3)" is undefined for an *empty* derivation. The text says branch (2) is a derivation "the reviewer can accept"; it never states whether an empty delta set means (2) is *unavailable* (fall through to ASK) or means (2) produced an empty/placeholder sentence (QC-10 `SPEC-F72` non-placeholder FAIL after write). Both readings are fail-closed but at different stages, and neither is legal for a pinned PASS fixture.

**Proposed direction (for triage, not applied here).** (a) Add `spec-version` **seed** (R7b-F12 / R7c-F05) to the enumerated delta list, and add invariants/decision-log changes (bullets added/removed, `DEC-nn` appended) as delta items; (b) state a **total terminal** for branch (2): when the delta set is empty, emit a named deterministic no-structural-change sentence that QC-10 accepts as non-placeholder (e.g. `version seeded to 1 (prior spec-version malformed); no structural changes`) — so brief-less augment 2/3/4b never reaches ASK; (c) restate the R7c-F05 / R7b-F06 / R6n / R6c brief-less PASS fixtures as also satisfying summary provenance via (1) or the total (2) — never ASK, mirroring the R7d-F02 precondition wording. Keep "Fabricate never" and KEEP: do not add a Change-Summary interview turn.

---

### R7f-F02 — MED — `review-requirements` SCAN resolution still pins `<line-or-id>` to a live ID, so R7e-F02 ordinals fail `REQ-F71` at the reviewer surface

**Where:** L427 (Wave 2 `review-requirements` row) vs L73 (pin table), L143 (`invariant-count`), L198 (`nfr` pack Notes), L293 (REQUIREMENTS §2).

**Freeze text (L427):**
> **SCAN resolution (R7-F04, R7b-F02, R7c-F08, R7c-F09):** `SCAN:<section>#<line-or-id>` resolves to a live staged-SPEC heading + live ID after **`scan-section-slug`** unique match (…; **`<line-or-id>` is a live ID, not a bare line number**)

**Freeze text (L73 / L293):**
> `<line-or-id>` MUST be either (a) a live ID inside that section **or** (b) a **section-anchored ordinal** `b[0-9]{2}` … `SCAN:invariants#b03` = third counted bullet.

**Defect.** The Wave 2 `review-requirements` contract — the surface that actually adjudicates every NFR `Source` cell — never gained clause (b). Under L427 as written, `SCAN:invariants#b03` is *not* "a live ID", so it is unresolvable ⇒ `REQ-F71` ⇒ fail before canonical install. That directly voids the R7e-F02 use case the freeze mandates at L198 ("when `nfr` is omitted, compiler-discovered NF concerns in `### Invariants` / Overview prose use `SCAN:invariants#bNN`"): the compiler is instructed to emit exactly the atom the reviewer must fail. `review-cross-artifact` (L428) is worse-off still — it restates only the *lexical* atom grammar (`no comma, no space, no #`) and carries **no** resolution clause at all, so it inherits nothing.

This is the same surface-binding class R7e-F01 fixed for the eligible-set join, one surface over; it is a residual of R7e-F02, not a re-report of it.

**Proposed direction.** Mirror the L73/L293 two-clause `<line-or-id>` rule verbatim into the L427 `review-requirements` SCAN-resolution sentence and into L428 `review-cross-artifact`; state that ID-bearing sections MUST use (a) and ID-less sections MUST use (b); keep bare line numbers `REQ-F71`.

---

### R7f-F03 — MED — Two incompatible exhaustion predicates coexist; the `00–99`-live-or-tombstoned shorthand survives at 10 binding sites and can never be true after `-00` became never-minted

**Where:** contradiction inside a single pin at **L217**; stale shorthand also at **L422, L427, L482, L484, L582, L583, L584, L590, L647**. Corrected predicate present at L217 (second sentence), L284, L457, L458, L489.

**Freeze text (L217, same paragraph):**
> Exhaustion FAIL when every value in `01–99` is live or tombstoned **and** (`-00` is live or tombstoned **or** `-00` is absent — never mint it). When next-free cannot mint an unused exact two-digit ID (**all `00–99` live or tombstoned** for that prefix), **FAIL closed** …

**Defect.** After R7d-F09/R7e-F04 made `-00` **never minted**, the normal exhausted state is `01`–`99` live-or-tombstoned with `-00` **absent**. The shorthand predicate "all `00–99` live or tombstoned" is then **false**, so on every surface that carries only the shorthand the R6f fail-closed gate does not fire and the allocator has no defined behavior (it cannot mint, and it is not told to FAIL). The shorthand survives on the surfaces that matter most:

- L422 Wave 2 preamble (reviewer-visible exhaustion rule),
- L427 `review-requirements` ("when **all `00–99` are live or tombstoned** for that prefix, next-free **FAIL closed**"),
- L482 / L484 Wave 3 `- contains` **string asserts** — an implementation that writes the corrected R7e-F04 predicate would fail these asserts, and one that writes the shorthand contradicts L217/L457/L458,
- L582 (path 1), L583 (path 1b), L584 (path 2), L590 (kind-reconciliation / every minting path) — i.e. every Wave 6 minting branch,
- L647 risk table (`Exact two-digit namespace full (`00–99` live or tombstoned)`).

**Proposed direction.** Replace all ten shorthand occurrences with the single normative predicate from L217/L457 ("every value in `01–99` live or tombstoned **and** `-00` live, tombstoned, or absent — never minted"), or define the shorthand once as an abbreviation of that predicate and cross-reference it. Do not weaken R6f fail-closed, R7d-F09 seed-at-`-01`, or R7e-F04.

---

### R7f-F04 — MED — Section-anchored ordinals are positionally unstable across augment: inserting/removing a bullet silently repoints a live `SCAN:` citation with no re-anchor or revalidation rule

**Where:** L73 (ordinal definition + "Do not contradict the stable-ID contract (never renumber cited IDs)"), L143, L198, L293.

**Defect.** `SCAN:invariants#b03` names "the third counted bullet". The counted set is defined by document order under the R7c-F03 grammar, and Invariants bullets are explicitly **mutable across augment**: R7d-F04 makes brief `invariants` a *superseding* write (bullets dropped, migrated, or added), R7b-F03 branch (2) preserves-then-augments, and R7e-F06 pins a fixture in which prior bullets B1/B2 change. After any such compile:

- a REQUIREMENTS `NFR-nn` whose `Source` is `SCAN:invariants#b03` **still resolves** (there is still a third bullet) but now cites a *different* obligation — a silent provenance change with **no** FAIL, no INFO, and no revalidation;
- the freeze's own guard is prose-only: L73 says "Do not contradict the stable-ID contract (never renumber cited IDs)" while ordinals are, by construction, renumbered by any insertion/deletion before the cited position. There is no mechanism (no ordinal ledger, no tombstone analogue, no "re-resolve and compare text" step) to make that prohibition machine-checkable.

R7c-F09 rejected bare line numbers for exactly this reason ("no base, stability, or revalidation rule"); R7e-F02 substituted section-anchored ordinals, which narrow the blast radius from file to section but do not remove the instability. This is a residual of R7e-F02, not a re-litigation of R7c-F09.

**Proposed direction.** Bind ordinal stability to the existing staged-pair machinery: on any compile that mutates an ID-less section cited by a live `SCAN:…#bNN`, either (a) re-anchor the citation deterministically (match the previously cited bullet text under `decision-row-identity`-style normalization and rewrite the ordinal), or (b) fail before write / ASK when the cited bullet cannot be matched — mirroring R7d-F04 no-silent-delete. Add a Wave 6 fixture: prior `SCAN:invariants#b03`, augment inserts a bullet at position 1 ⇒ citation re-anchored to `b04` **or** fail-before-write; silent repoint FAIL.

---

### R7f-F05 — MED — Malformed-prior `spec-version` seed mandates "exactly one Change History row", silently destroying prior human-authored history rows with no migrate-or-ASK

**Where:** L141 (`spec-version` "Malformed prior (R7c-F05)"), L584 (Wave 6 path 2), path 4b, Wave 6 "Behavioral malformed spec-version fixture (R7c-F05)".

**Freeze text (L141):**
> present-but-invalid `spec-version` (`v1`, `0.35`, `1.0`, date-string) on augment paths 2/4b is treated as **no prior version** — seed `1` with **exactly one Change History row** (R7b-F12 shape); do not bump a non-integer; do not leave the cell undefined.

**Defect.** A real path-2 input with `spec-version: 0.35` almost certainly carries a populated `## Change History` table (rows `0.35`, `0.34`, …). The freeze forces a post-state of **exactly one** row (version `1`), and keeping the prior rows is not an alternative: QC-10 requires the cell to be "the decimal string of that integer" with "unique/ordered" integer values, so a retained `0.35` row is itself a `SPEC-F72` FAIL. The only compliant behavior is therefore **deleting operator-authored history prose during an augment** — with no migrate branch, no ASK, and no fail-before-write, in a freeze that elsewhere pins exactly the opposite discipline for the same class of data:

- R7d-F04: prior live Invariants bullets not carried forward MUST append to retained `.planning/.spec-kind-migration.md` **or** ASK; fail before write if unresolved;
- R5-F01 / R7-F08: forbidden pack prose MUST migrate or ASK, never silent delete.

Change History is the one section whose entire purpose is historical retention, so silent truncation is the sharpest instance of the hazard the freeze already rejects twice.

**Proposed direction.** On the malformed-prior seed path, require prior Change History rows to be appended as a timestamped section of the retained non-canonical `.planning/.spec-kind-migration.md` (R7c-F07 append rule) **or** ASK; fail before write if unresolved. Keep "exactly one row for version `1`" as the *canonical SPEC* post-state. Extend the pinned R7c-F05 fixture: input has a `0.35` history row ⇒ install PASSes only if that row is preserved in the retained migration record. **KEEP REJECT:** not a third canonical doc.

---

### R7f-F06 — LOW — Union-emission row identity is undefined when a brief row matches a live `DEC-nn` ID but the text differs, and `decision-row-identity` names no column of the `DEC-nn | date | decision | why` row

**Where:** L142 (`decision-count` union emission + `decision-row-identity`), L199 (`decision-log` pack row shape).

**Freeze text (L142):**
> retain every live preserved `DEC-nn`; append brief `decisions` rows not already present (row-identity: **matching live `DEC-nn` ID, else matching decision text** under named `decision-row-identity` …)

**Defect (two parts).**
1. **ID match with divergent text has no resolution rule.** If the brief supplies `DEC-02 | 2026-01-02 | We will use X | …` and the live row is `DEC-02 | 2025-11-01 | We will use Y | …`, the row is "already present" by ID, so nothing is appended — but the freeze never says whether the live row's `date` / `decision` / `why` cells are retained, overwritten from the brief, or the conflict is an ASK/FAIL. `decision-count` is unaffected either way, so QC-12 cannot catch the divergence: two different compilers produce two different canonical SPECs from identical inputs, both QC-clean. That defeats the determinism the union-emission pin exists to provide.
2. **`decision-row-identity` has no field selector.** The pack row is four columns (`DEC-nn | date | decision | why`, L199). "matching decision text" does not say whether the normalized comparison runs over the `decision` cell alone, `decision` + `why`, or the whole serialized row. Two briefs differing only in `why` (or only in `date`) are the same decision under one reading and distinct under another — changing the resulting `decision-count` and hence QC-12.

**Proposed direction.** State that identity is computed over the **`decision` cell only** under `decision-row-identity`, and add an explicit ID-collision rule: on `DEC-nn` match with non-identical normalized `decision` text, fail before write (or ASK) rather than silently retaining or overwriting. Keep the R7e-F08 idempotence fixture; add a divergent-text fixture.

---

### R7f-F07 — LOW — `change-summary` is declared a capture-schema brief field but is absent from the Wave 4 brief-field string assert and from the Clarify blast-radius row

**Where:** L516 (capture schema declares it) vs **L535** (Wave 4 Verify, R1b-F02 field-name assert list) and **L314** (blast radius, Clarify row).

**Freeze text (L516):** "**`change-summary` provenance (R7e-F03):** operator-supplied brief field only (same pattern; **not** a turn)".
**Freeze text (L535):** "string-assert the capture-schema brief field names (`ux`, `errors`, `data`, `nfr`, `security`, `telemetry`, `api`, `cli`, `mobile`, `pipeline`, `ops`, `examples`, `invariants`, `decisions`)."
**Freeze text (L314):** "`invariants` + `decisions` capture".

**Defect.** R1b-F02 exists precisely so every brief field the compiler consumes is string-asserted in `test-clarify-spec-compiler.sh`. `change-summary` is now such a field (Step 7 reads it at L457; review-spec QC-10 names it at L426), yet the assert list and the blast-radius inventory were not extended — the same omission class as R7c-F11 (`world-class-min` keys) and R7e-F07 (`spec-version` in the core-template asserts). An implementation could ship `silver-clarify/SKILL.md` with no `change-summary` field and pass Wave 4.

**Proposed direction.** Add `change-summary` to the L535 field-name assert list and to the L314 Clarify blast-radius parenthetical (`invariants` + `decisions` + `change-summary` capture). Do not add a turn (KEEP: interview not reopened).

---

### R7f-F08 — LOW — Wave 2 verify `rg` alternation omits `change-summary` and the ordinal token, though both are now reviewer-skill contract strings

**Where:** L434 (`rg -n "QC-2|…|scan-section-slug|conditionally-required|…"`), vs L426 (review-spec QC-10 carries `change-summary`) and R7f-F02's fix target.

**Defect.** The alternation is the Wave 2 gate that proves the landed contract strings actually reached `skills/review-*/SKILL.md`. It was extended by R7b-F11 (`decision-count|invariant-count|SCAN|eligible|spec-version`) and R7d-F06 (`scan-section-slug|conditionally-required`), but the R7e-F03 token `change-summary` — which L426 now requires review-spec to carry — was not added. The section-anchored ordinal token (`b[0-9]{2}` / "section-anchored ordinal") is likewise absent, so once R7f-F02 lands there is again no grep proving it reached the skills.

**Proposed direction.** Extend the L434 alternation with `change-summary` and `section-anchored ordinal` (or `b\\[0-9\\]\\{2\\}`), preserving the existing escaping style.

---

### R7f-F09 — LOW — Test surfaces carry no ordinal-SCAN PASS fixture and no QC-10 summary-provenance assert

**Where:** **L437** (named QC-string test assert list) and **L497** / Wave 3 `- contains` list.

**Freeze text (L437), SCAN fixtures:** `SCAN:quality-attributes#QA-01` PASS; `SCAN:x#1` FAIL; ambiguous-slug FAIL; `## Quality Attributes (SLOs)` ↔ `quality-attributes-slos` PASS; bare-line `SCAN:quality-attributes#12` FAIL; `SCAN:a#b#c` FAIL.
**Freeze text (L497):** "contains QC-10 / `SPEC-F72` Change History **table** + current `spec-version` row + non-placeholder summary (heading-only FAIL) (R5c-F02)".

**Defect (two parts).**
1. Every SCAN fixture in the QC-string list is either an ID target or a negative. There is **no positive ordinal fixture** (`SCAN:invariants#b03` PASS) and no negative pinning the ordinal domain (e.g. ordinal against an ID-bearing section FAIL). R7e-F02 is therefore string-only on the reviewer test surface — exactly the "no test-surface binding" gap R7e-F05 closed for union emission.
2. The Wave 3 `- contains` list asserts the QC-10 *shape* (table / current-version row / non-placeholder) but never the R7e-F03 **provenance** chain (`change-summary` → deterministic structural delta → ASK / fail-before-write), even though R7d-F07 established that Step 7 obligations must appear as explicit `- contains` bullets. Step 7 at L457 carries the provenance text with nothing asserting it.

**Proposed direction.** Add to L437: `SCAN:invariants#b03` PASS against a live `### Invariants` with ≥ 3 counted bullets; ordinal-on-ID-bearing-section FAIL. Add a Wave 3 `- contains` bullet for Step 7 Change History summary provenance (brief `change-summary`; else deterministic structural-delta sentence; else ASK **fail-before-write**), alongside the existing `invariant-count` / `decision-count` / `spec-version` bullets.

---

### R7f-F10 — LOW — The ID-less-ordinal section enumeration names `## Change History` (a table, no bullets) and leaves `## Overview` / `### Invariants` nesting and `## Assumptions` entry shape unresolved

**Where:** L73 ordinal clause; L182 (Change History MUST be a table); L174 (`## Overview` … "Include `### Invariants`"); L175 (`## Assumptions` entry shape `[ASSUMPTION: … | Status: … | Owner: …]`).

**Freeze text (L73):**
> (`### Invariants` uses the R7c-F03 MUST/MUST NOT grammar; **`## Overview` / `## Assumptions` / `## Change History` use top-level `-` bullets**)

**Defect (three parts).**
1. **`## Change History` has no bullets by contract.** QC-10 / `SPEC-F72` requires a markdown **table** (L182) and FAILs heading-only. So `SCAN:change-history#bNN` is unresolvable for every conforming SPEC — the enumeration names a section that can never satisfy it, while offering no table-row addressing (`rNN` or the `spec-version` cell) instead.
2. **`## Overview` counting scope is ambiguous with respect to `### Invariants`.** Invariants is a *subsection of Overview* (R4-F03 pin). The rule says "top-level `-` bullets" under a section without saying whether the `## Overview` count includes bullets that live under its `### Invariants` child. Under the inclusive reading, one physical bullet is addressable as both `SCAN:overview#bNN` and `SCAN:invariants#bMM` with different ordinals, and adding an Invariants bullet shifts `## Overview` ordinals — compounding R7f-F04.
3. **`## Assumptions` is not a bullet list by contract.** Its pinned shape is `[ASSUMPTION: … | Status: … | Owner: …]` with an optional `ASM-nn` prefix (L175); whether those entries are `-` bullets is never stated, so ordinal resolvability there is undefined (and `ASM-nn`, when present, makes it ID-bearing, which clause (a) would then require).

**Proposed direction.** Restrict the ordinal enumeration to sections that are contractually bullet lists (`### Invariants`, and `## Overview` prose bullets **excluding** nested subsection bullets — state the exclusion); drop `## Change History` from the list (or define row addressing for it); state that `## Assumptions` entries with `ASM-nn` are ID-bearing (clause (a)) and without it are counted top-level bullets.

---

### R7f-F11 — nit — `nfr` pack Notes emphasis markers are malformed, so the derived/non-normative tag renders broken and swallows the kind list

**Where:** L198, pack table `nfr` Notes.

**Freeze text (L198, verbatim):**
> `*(derived from the current catalog, non-normative — R7d-F10:* kind-required for infra-devops, data-ml, headless-service)*`

**Compare L196 (`ux`, and the other ten R7e-F09 rows):**
> `*(derived from the current catalog, non-normative — R7e-F09)*`

**Defect.** The `nfr` row opens emphasis at `*(` and **closes it at `R7d-F10:*`**, so the rendered output is *«(derived from the current catalog, non-normative — R7d-F10:»* followed by unemphasised `kind-required for infra-devops, data-ml, headless-service)` and a dangling `*`. The kind list — the very thing the tag is supposed to mark non-normative — falls **outside** the tag, and the row no longer matches the eleven sibling rows R7e-F09 normalized. Since the pack table is repeatedly declared the machine-adjacent surface (R7b-F07 / R7c-F15), an inconsistently delimited non-normativity marker is a second-source-of-truth hazard of exactly the class R7c-F16 / R7e-F09 were filed to remove.

**Proposed direction.** Re-delimit as `*(derived from the current catalog, non-normative — R7d-F10: kind-required for infra-devops, data-ml, headless-service)*`, matching the eleven R7e-F09 rows. `Default class` cell stays enum-only `**optional**` (R7d-F10 unchanged).

---

### R7f-F12 — nit — The `invariant-count` source clause enumerates only branches (1) and (2), omitting branch (3) ASK, and states a *source* count rather than the *resulting live* count

**Where:** L143 (`invariant-count` row) vs L174 (three-branch precedence) and the R7e-F06 fixture ("`invariant-count` equals the resulting live bullet count").

**Freeze text (L143):**
> Step 7 always writes it: brief `invariants` MUST/MUST NOT bullet count **if present; else preserved live `### Invariants` bullet count** under R7b-F03 precedence.

**Defect.** R7b-F03 / R7c-F01 precedence has **three** branches; branch (3) (ASK, operator answer recorded as the source) is a legal PASS route when an operator *is* present, and the L143 clause gives it no count source. Separately, phrasing the value as the *brief* or *preserved* count rather than "the resulting live `### Invariants` bullet count" is exactly the arithmetic mismatch class R7d-F01 fixed for `decision-count` (`max` → live count): under R7d-F04's superseding write plus migration, the authoritative number is the count of bullets actually emitted, and QC-11 compares against live bullets (L426). The R7e-F06 fixture already says "resulting live count", so L143 is the only surface still phrased by source.

**Proposed direction.** Restate L143 as: "Step 7 always writes it as the **resulting live `### Invariants` MUST/MUST NOT bullet count** after applying R7b-F03 / R7c-F01 precedence (brief; else preserved; else ASK) and the R7d-F04 superseding-write rule." No QC change.

---

### R7f-F13 — nit — Ordinal grammar `b[0-9]{2}` admits `b00` (unreachable) and has no >99 behavior

**Where:** L73, L143, L198, L293.

**Defect.** Ordinals name "the Nth counted top-level bullet", and counting starts at the first bullet, so **`b00` parses but can never resolve** — a permanently dead lexical value inside a fail-closed check (`REQ-F71`), the same dead-value class as R7d-F11 (`invariant-count: 0` parses but always FAILs QC-11) and R7d-F09/R7e-F04 (`-00` parses but is never minted). Symmetrically, a section with more than 99 counted bullets has no addressable tail and no stated behavior (FAIL? truncate? widen?), where every other two-digit namespace in the freeze has an explicit exhaustion rule (R6f).

**Proposed direction.** State that ordinals are **1-based**: `b00` parses but always FAILs `REQ-F71` (dead value, no grammar change), and a cited section with > 99 counted bullets FAILs closed at `REQ-F71` (no widening, no wrap) — mirroring the R6f / R7d-F11 phrasing already used elsewhere.

---

### R7f-F14 — nit — `invariant-count` / `decision-count` equality is pinned on the core **template** example only; `world-class-min` asserts key presence but not equality

**Where:** Wave 1 Work item 1 (R7e-F10, template) vs Wave 1 Work item 3 ("**Core YAML keys (R7c-F11):** `world-class-min` asserts YAML `decision-count` and `invariant-count` plus live `### Invariants`").

**Defect.** R7e-F10 closed the unpinned-example gap for `templates/specs/SPEC.md.template`. `world-class-min` is the stronger artifact — it is a *filled* fixture standing in for an installed SPEC, parsed by `test-spec-req-id-parse.sh` and used as the empty-NFR / `None identified` positive (R7c-F13) — yet its assert list stops at key **presence**. A fixture with `invariant-count: 2` over one live bullet, or `decision-count: 1` with no `## Decision Log`, would satisfy Wave 1 while being an artifact that QC-11 / QC-12 must FAIL, seeding an invalid corpus for every downstream wave.

**Proposed direction.** Extend the `world-class-min` assert list with the R7e-F10 equalities: YAML `invariant-count` equals the counted R7c-F03 bullets and is ≥ 1; `decision-count` equals live `DEC-nn` rows and `## Decision Log` is present iff ≥ 1 (for `cli` with no decisions, `decision-count: 0` and heading absent).

---

## Summary table

| ID | Severity | One-line | Anchor |
|----|----------|----------|--------|
| R7f-F01 | HIGH | Change History provenance branch (2) is not total; seed-only augment → empty delta → ASK/fail-before-write breaks pinned PASS fixtures | L182, L141, L426, L457 |
| R7f-F02 | MED | `review-requirements` SCAN resolution omits the R7e-F02 ordinal; `SCAN:invariants#b03` fails `REQ-F71` at the reviewer surface | L427 (vs L73/L293), L428 |
| R7f-F03 | MED | Two exhaustion predicates; `00–99`-live-or-tombstoned shorthand at 10 sites is unreachable once `-00` is never minted | L217 + L422/427/482/484/582/583/584/590/647 |
| R7f-F04 | MED | Ordinal SCAN targets silently repoint across augment; no re-anchor/revalidation despite the stable-ID prohibition | L73, L143, L198, L293 |
| R7f-F05 | MED | Malformed-prior `spec-version` seed forces "exactly one" history row ⇒ silent deletion of prior Change History with no migrate-or-ASK | L141, L584, Wave 6 fixture |
| R7f-F06 | LOW | `DEC-nn` ID match with divergent text unresolved; `decision-row-identity` names no column of the 4-column row | L142, L199 |
| R7f-F07 | LOW | `change-summary` missing from the Wave 4 brief-field assert list and the Clarify blast-radius row | L516 vs L535, L314 |
| R7f-F08 | LOW | Wave 2 `rg` alternation omits `change-summary` and the ordinal token | L434 vs L426 |
| R7f-F09 | LOW | No ordinal-SCAN PASS fixture in the QC-string list; no Wave 3 `- contains` bullet for QC-10 summary provenance | L437, L497 |
| R7f-F10 | LOW | Ordinal section enumeration names table-only `## Change History`; Overview/Invariants nesting and Assumptions shape unresolved | L73 vs L182/L174/L175 |
| R7f-F11 | nit | `nfr` Notes emphasis malformed; kind list falls outside the non-normative tag | L198 vs L196 |
| R7f-F12 | nit | `invariant-count` source clause omits branch (3) ASK and reads as source count, not resulting live count | L143 vs L174 |
| R7f-F13 | nit | `b[0-9]{2}` admits unreachable `b00`; no >99-bullet behavior | L73, L293 |
| R7f-F14 | nit | `world-class-min` asserts count-key presence but not R7e-F10 equality | Wave 1 items 1 & 3 |

## Scope / charter compliance

- **KEEP REJECT honored:** every proposed direction keeps two canonical files (SPEC + REQUIREMENTS); none adds a third canonical doc (R7f-F05 routes preserved history to the existing **non-canonical** retained `.planning/.spec-kind-migration.md`); none has Clarify write SPEC.md; none folds in ingest; none adds an interview turn (R7f-F01 and R7f-F07 explicitly keep `change-summary` as an operator-supplied brief field, not a turn).
- **No pin weakened:** R6b/R6c/R6d staging-snapshot-fixed-point, R6f exhaustion fail-closed (R7f-F03 *strengthens* its reachability), R5h/R5i tombstones, R5j 1b preserve-or-fail-closed, R5k Source-vs-Dispositions exclusivity, R6h–R6n grammars/edge-sets/lineage, R7-F02 floor, R7b/R7c/R7d/R7e encodings all retained. Spec-floor untouched (Overview + AC only).
- **R7b-F17 not reopened** (REJECT, resolved-as-rejected): the "one 9-turn interview for every kind" KEEP REJECT and the universal-turn-count wording are untouched by every finding above.
- Review-only: no edit to the freeze or its twin, no triage/APPLY, no branch/commit operations, no verify launch, no ladder advance, no outcome recording.

**Reviewer:** `claude/claude-opus-5-high` (Pi / OmniRoute). **Verify + Triage:** Composer 2.5. **Fix/APPLY:** Grok 4.6 High.
