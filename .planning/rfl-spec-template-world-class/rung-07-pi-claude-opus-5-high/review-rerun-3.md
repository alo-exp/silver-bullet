# RFL rung 07 — Pi Claude Opus 5 High — review pass 3 (residual-only)

**Rung:** 7 of 8 — third review pass (Policy F streak = 0 after pass-2 `accept-apply`)
**Reviewer:** Claude Opus 5 High via Pi OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`)
**Role:** review-only (Policy C). No triage, no APPLY, no fix, no branch/commit, no verify launch.
**Mode:** residual-only (Policy G). All severities filed. New IDs `R7c-F01+`.
**Session policy:** Verify+Triage = Composer 2.5; Fix/APPLY = Grok 4.6 High.

## Freeze identity (hashed this pass)

```
4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7  .planning/spec_template_world_class.plan.md
4c229f5d873b24fa45e94e5710195a991034abd15a98203aa716eacd6e23abe7  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both twins match the briefed pin `4c229f5d…`. 720 lines. `CONTEXT.md` metadata SHA is stale (`edf2c256…`, rung-03 era) — expected; hashed the freeze files directly, did not mutate.

Graphify was queried first (`graphify query`, CLI path; MCP skill version warnings only). Freeze re-read in full from scratch (L1–L720). Pass 1 (`review.md`) and pass 2 (`review-rerun-2.md`) were **not** consulted as authority; ledger used only to avoid re-filing.

## Verdict

**NOT CLEAN** — 16 residual findings: **1 HIGH, 7 MED, 5 LOW, 3 nit**.

## R7b APPLY spot-check (landed; not re-filed)

| ID | Landed? | Evidence in this freeze |
|----|---------|-------------------------|
| R7b-F01 | yes | L258/L313/L457/L474/L587/L596 — `.planning/.spec-kind-migration.md` "retained after successful install", non-canonical, not-parsed-by-any-QC; R6c leftover deletion on FAIL preserved |
| R7b-F02 | yes | L73, L293, L427 — strip `##`/`###`, lowercase, non-alphanumerics → `-`, unique normalized match; `, ` delimiter + no-space atom kept; `REQ-F71` |
| R7b-F03 | yes | L172, L457 — precedence brief → preserve-live → ASK; "Fabricate never"; `SPEC-F73` fail-closed |
| R7b-F04 | yes | L143 `invariant-count`; L426 "live MUST/MUST NOT bullet count equals YAML `invariant-count`"; reviewers read SPEC YAML |
| R7b-F05 | yes | L141/L143 grammar + presence split; L426 "Missing `invariant-count` on a new compile FAIL" |
| R7b-F06 | yes | L141, L197, L457, L596 `max(brief decisions rows, live preserved DEC-nn rows)` + Wave 6 fixture |
| R7b-F07 | yes | L212 "sole machine source"; Notes non-normative; Wave 1b L406 diffs YAML against the catalog table |
| R7b-F08 | yes | L262/L293/L427/L458/L596 precondition + `web-ui`+`CTRL-01` neither-branch FAIL fixture |
| R7b-F09 | yes | L159 fifth ontology class; L197 decision-log reclassed |
| R7b-F10 | yes | L426 QC-8 "≥1 live `AC-nn` exists (`SPEC-F70`); zero live AC is FAIL, not vacuous PASS" |
| R7b-F11 | yes | L435 alternation now carries `decision-count\|invariant-count\|SCAN\|eligible\|spec-version\|REQ-F71\|REQ-F72\|XART-F03` |
| R7b-F12 | yes | L131 seed; L282; Wave 6 L579/L582 |
| R7b-F13 | yes | L359 core-template asserts include `decision-count`, `invariant-count` |
| R7b-F14 | yes | L360/L361 `QA-01, SLO-01` restricted to a dedicated `infra-devops`/`headless-service` parser fixture; `world-class-min` MUST NOT carry `SLO-nn` |
| R7b-F15 | yes | L288 "Four of these are QC-1 … Coverage Matrix presence is QC-8 / `REQ-F70`, not QC-1" |
| R7b-F16 | yes | `REQ-F71` L293/L427/L458; `REQ-F72` L294/L295; `XART-F03` L292/L428/L458; `SPEC-F73` L457 |
| R7b-F17 | n/a | REJECT, not encoded. Not re-filed. |

Earlier pins (R7-F01–F13, R6b–R6n, R5*, R1–R4) spot-checked as intact; nothing below weakens lineage, namespace closure, edge-set equality, grammars, staging/snapshot/fixed-point, exhaustion, or 1b preserve-or-fail-closed, and none tightens spec-floor.

---

## Findings

### R7c-F01 — HIGH — Invariants precedence branch (3) "ASK" has no non-interactive outcome, and it makes two *pinned* brief-less Wave 6 fixtures unpassable

**Where:** L172 (core-required §1), L457 (Wave 3 Step 7), L596 (Wave 6 behavioral fixtures).

L172 pins the R7b-F03 chain: "(1) brief `invariants` if present; else (2) **preserve** existing live `### Invariants` bullets … (augment paths 2/3/4b) …; else (3) **ASK** the operator (same shape as kind-reconciliation ASK) and record the answer as the source. Fabricate never. Empty/scaffold Invariants FAIL QC-11 / `SPEC-F73` (fail-closed before install)."

Two problems, both new at this SHA:

1. **The ASK branch has no defined outcome when no operator is present.** The freeze's other ASK (kind-reconciliation, L258/L457) is explicit: "**fail before write** if unresolved". The Invariants ASK says only "record the answer as the source" — it never states what happens when the ASK cannot be answered (batch compile, CI, `test-spec-legacy-lock.sh`). By L172's last sentence the implicit result is empty ⇒ `SPEC-F73` FAIL, i.e. **every** brief-less augment of a pre-Invariants SPEC is fail-closed. That is a migration-blocking behavior that the freeze never states and never fixtures.

2. **It contradicts two fixtures the freeze already pins as PASS-installing.** L596: (a) R5-F01 migrate fixture — "generic-old-spec-with-UX → `cli` (output has no `## UX Flows`; user prose preserved via … `.planning/.spec-kind-migration.md`; kind-aware heading check PASS)". A generic old spec (per the L108–L114 evidence table, today's 52-line template has no Invariants) has **no** `### Invariants` and the fixture supplies **no** brief ⇒ branch (3) ⇒ no install ⇒ the asserted PASS is unreachable. (b) R7b-F06 fixture — "legacy SPEC with two live `DEC-nn` rows + **no brief** ⇒ augment **installs** with `decision-count: 2` and QC-12 PASS" — same trap: an install is asserted on a brief-less legacy SPEC that has no live Invariants.

Note the asymmetry the pass-2 pack introduced: `decision-count` got an explicit non-fatal brief-less rule (`max(…)`, R7b-F06) while `invariant-count` got a blocking one. The freeze needs an equivalent stated terminal for branch (3): either a named `fail-before-write (unresolved ASK)` rule carrying `SPEC-F73` **plus** amending both L596 fixtures to seed `### Invariants` (or to assert the FAIL), or an explicit brief-less-augment allowance. As written, Wave 6 cannot be implemented as specified.

---

### R7c-F02 — MED — `decision-count` has no live-`DEC-nn` equality check, so the installed value can be factually false and nothing FAILs

**Where:** L141 (YAML key table), L197 (pack table), L426 (QC-12), L457 (Step 7).

R7b-F04 made `invariant-count` **exact**: "live MUST/MUST NOT bullet count **equals** `invariant-count`" (L143, L426). Its sibling `decision-count` is only ever used as a boolean: "`## Decision Log` present iff this value ≥ 1" (L141, L197, L426). There is no rule that `decision-count` equals the number of live `DEC-nn` rows.

Consequence with the new R7b-F06 augment rule `max(brief decisions rows, live preserved DEC-nn rows)`: an augment with 3 brief decisions plus 2 *distinct* preserved `DEC-nn` rows emits `decision-count: 3` while the installed `## Decision Log` carries 5 rows. `decision-count: 97` with one row also installs. The key is declared "Non-negative integer ≥ 0" and is described in count language, is written by Step 7 on every compile, and is read by reviewers as the QC-visible source of truth (L141 "Reviewers read SPEC YAML, not the brief") — but no gate can detect a wrong one. Either make QC-12 count-equality (matching R7b-F04) or restate the key as a presence predicate (e.g. `decision-log-required: true|false`) so the freeze stops promising a count it never checks.

---

### R7c-F03 — MED — `invariant-count` equality is an exact fail-closed integer gate over an undefined "MUST/MUST NOT bullet" grammar

**Where:** L143, L172, L426, L437.

QC-11 now FAILs unless "live MUST/MUST NOT bullet count **equals** `invariant-count`" (`SPEC-F73`). Everywhere else the freeze specifies exact machine grammars down to code points (`nfr-source-cell-list` "U+002C COMMA + exactly one U+0020 SPACE", L73; `coverage-matrix-req-cell-list`, L74; exact `AC-[0-9]{2}`). The invariant bullet has none:

- Is a bullet containing **both** "MUST" and "MUST NOT" one invariant or two?
- Are nested/continuation sub-bullets counted?
- Must "MUST" be uppercase at bullet start, or does any occurrence inside prose count (e.g. "the cache MUST NOT be primed, though callers must not assume …")?
- Do non-bullet lines under `### Invariants` (a lead-in sentence, a table) count?
- Invariants are the only structured core content with **no** ID (`US-nn`/`AC-nn`/`OQ-nn`/`OOS-nn`/`DEC-nn` all have one; L217 ID scheme omits invariants), so there is no anchor to count.

Two implementations will disagree on the integer, and disagreement is a hard install block, not an advisory. Give invariants either a per-line grammar (one MUST/MUST NOT statement per top-level bullet, uppercase keyword leading) or an ID (`INV-nn`) so QC-11's equality is decidable.

---

### R7c-F04 — MED — the R7b-F14 dedicated `QA-01, SLO-01` parser fixture, as pinned, FAILs its own reverse-coverage neither-branch rule

**Where:** L360, L361 (Wave 1), against L262/L293 (eligible + exclusive branches) and the catalog L246/L249.

R7b-F14 pinned the two-atom Source example to "a dedicated parser fixture pinned to a kind where both `nfr` and `ops` are legal (`infra-devops` or `headless-service`)". Both of those kinds **require** `security` (catalog L246 `infra-devops`: `ops`, `nfr`, `telemetry`, `security`; L249 `headless-service`: `ops`, `telemetry`, `errors`, `nfr`, `security`), and QC-12 requires required-pack bodies with pack-local IDs (L426), so the fixture SPEC necessarily carries a live `CTRL-nn`.

`eligible` (R7-F03, L262) = every live non-tombstoned `QA-nn`/`SLO-nn`/`CTRL-nn` on required **and** optional-present packs — so `CTRL-01` is eligible. The exclusive-branch rule (L293) FAILs any eligible source that is in "neither" branch. A fixture whose only NFR Source cell is `QA-01, SLO-01` leaves `CTRL-01` in neither branch ⇒ FAIL — the very same shape the freeze itself pins as a FAIL fixture at L427/L596 ("`web-ui` with live `CTRL-01` and empty NFR table + `None identified` ⇒ FAIL (neither-branch)").

The pinned positive parser fixture is therefore unbuildable as described. It must additionally carry a `CTRL-01` NFR row **or** a valid `### Source Dispositions` row for `CTRL-01` (and likewise for any other required-pack eligible source). Say so, or the Wave 1 positive and the Wave 2 negative collide.

---

### R7c-F05 — MED — a legacy `spec-version` that violates the R7-F07 grammar has neither a seed nor a bump rule, so augment paths 2 / 4b are undefined

**Where:** L131 (grammar + seed), L579/L581/L582/L585 (Wave 6 tree).

R7-F07 fixed the grammar ("positive integer ≥ 1 … not semver, not date-string, not `v1` … Fixture FAIL: YAML `v1` or `1.0`"). R7b-F12 added the seed for the *absent* case ("a SPEC that has **no prior** `spec-version` … is written as `1`"). Neither covers a **present but malformed** prior value — `spec-version: 0.35`, `v3`, `2026-08-29` — which is exactly what pre-freeze files in this repo family look like.

The lock tree keys on presence, not validity: path 4 (legacy lock) fires only when `spec-version` frontmatter is **missing** and no `## User Stories` and no `feature-slug` (L585). A file with `spec-version: 0.35` is "frontmatter present", so it routes to path 2 or 4b, both of which say only "bump `spec-version`" (L581, L586). Bumping a non-integer is undefined; writing it through unchanged FAILs QC-10 (`SPEC-F72`) at review; coercing it silently would break R6n integer equality against REQUIREMENTS. The tree is claimed total ("Tree is total (SPEC-absent: 1 vs 1b; SPEC-present: 2/3/4/4b)", L586) but this cell has no behavior.

Name the branch: malformed prior `spec-version` on augment ⇒ either treat as no-prior-version and **seed `1`** with a single Change History row (R7b-F12 shape), or fail-before-write with a named code. Do not leave it to the implementer.

---

### R7c-F06 — MED — the fifth ontology class `conditionally-required` cannot be expressed in `software-kinds.yaml`, which R7b-F07 just declared the sole machine source

**Where:** L159 (ontology), L197 (pack table), L212 (sole machine source), L406 (Wave 1b).

R7b-F07: "the kind catalog table (required / optional / forbidden columns) is the **sole** machine source for `software-kinds.yaml` … YAML per-kind sets MUST equal the catalog table." R7b-F09 simultaneously reclassed `decision-log` as **conditionally-required** with predicate `decision-count ≥ 1`, while stating "Kind-catalog optionality of the pack is unchanged (optional pack for every kind)" (L159, L197).

So the machine form carries exactly three sets, and `decision-log` sits in `optional` for all nine kinds. The ontology says `optional` means "Absent = PASS" (L158) — precisely the contradiction R7b-F09 was meant to remove — and the predicate that overrides it exists only in PLAN prose. A compiler that reads YAML (the declared machine source) has no representation of the new class; a QC that reads YAML sees `optional`. Wave 1b's assertion (L406, "generated YAML is diffed against the catalog table") cannot detect the omission because the catalog table cannot express it either.

Either add a fourth machine-readable class/predicate to the catalog table and `software-kinds.yaml` (e.g. `conditionally-required: {decision-log: "decision-count >= 1"}`), or state explicitly that class membership for `decision-log` is carried by QC-12 alone and that the YAML `optional` entry is not authoritative for it — currently the freeze asserts both.

---

### R7c-F07 — MED — the now-retained migration record is a single fixed path with no accumulation rule, so a second migration silently destroys the first one's preserved prose

**Where:** L258, L313, L457, L587, L596.

R7b-F01 flipped `.planning/.spec-kind-migration.md` from delete-on-success to "**retained** after successful canonical install as an operator-visible … record". The path is a fixed constant everywhere it appears. The freeze never says whether a subsequent migrate branch **appends** to it, rotates it, or overwrites it.

The default file-write semantics ("markdown dump of forbidden/unlisted heading prose", L457) is overwrite — which means the second kind change silently deletes the prose rescued by the first. That is the exact harm the migrate branch exists to prevent: "must **not** be silently deleted — move its prose to the named non-canonical migration record" (L457) and Wave 6's "do not silently delete user prose" (L587). It also interacts badly with R6c leftover deletion (L457: "snapshot-restore deletes leftover **staging** copies on FAIL"): a FAIL after a prior successful migration must not delete the retained record from the earlier run, and the freeze does not distinguish the retained installed record from the staging sibling by path.

Pin one of: append-with-timestamped-section (never truncate), or per-run distinct paths (`.planning/.spec-kind-migration-<spec-version>.md`), plus an explicit statement that R6c leftover deletion targets only the current run's staging copy. Keep KEEP REJECT: still not a third canonical doc.

---

### R7c-F08 — MED — `SCAN:` normalization ("collapse non-alphanumerics to `-`") is ambiguous on runs and edges, so a legitimate citation can be a fail-closed `REQ-F71`

**Where:** L73, L293, L427.

R7b-F02 defined normalization as "strip `##`/`###` markers; lowercase; collapse non-alphanumerics to `-`" with a **unique** normalized match required and unresolvable ⇒ `REQ-F71` FAIL before install. Three under-specifications remain, each of which turns a correct Source cell into a blocked install:

- **Run collapsing.** "collapse non-alphanumerics to `-`" does not say whether a *run* becomes one `-` or one `-` per character. `## Quality Attributes (SLOs)` → `quality-attributes-slos` (run-collapsing) vs `quality-attributes--slos-` (per-character). Author and validator can disagree; the mismatch is `REQ-F71`.
- **Leading/trailing trim.** No rule strips a trailing `-` produced by a heading ending in punctuation (`## Data.`, `## Errors:`).
- **Whitespace.** Space is non-alphanumeric, so it becomes `-` — but the atom grammar forbids spaces *in the cell*, meaning the author must pre-normalize by hand with no stated canonicalization function name.

Everywhere else the freeze specifies code points exactly. Specify this one the same way: named function (`scan-section-slug`), run-collapse to a single `-`, trim leading/trailing `-`, applied identically to cell and heading, with a fixture pair (`## Quality Attributes (SLOs)` ↔ `quality-attributes-slos` PASS).

---

### R7c-F09 — LOW — `SCAN:<line-or-id>` still permits a bare line reference with no base, no stability rule, and no revalidation across versions

**Where:** L73, L217, L293, L427.

The atom is `SCAN:<section>#<line-or-id>` and resolution requires that "`<line-or-id>` identifies a live line or ID inside that section (not tombstoned, not invented)" (L293). The **ID** half is well-defined (it joins the live namespace). The **line** half is not: there is no statement of whether the number is file-relative or section-relative, 0- or 1-based, or what "live line" means after the section is edited.

A persisted line number is the only non-stable citation the freeze admits, and it directly contradicts the freeze's own stable-ID contract ("Do not reuse IDs across augment versions (append; never renumber cited IDs)", L217). After any augment that inserts a bullet, `SCAN:overview#12` silently points at different content and still resolves ⇒ PASS. Either drop the line alternative (require an ID or a heading-anchored ID), or define the base and require re-resolution on every augment.

---

### R7c-F10 — LOW — the named Wave 2 QC-string test's assert list omits the fault codes and checks R7b just landed (the `rg` alternation has them; the test does not)

**Where:** L437 (`tests/scripts/test-review-spec-req-xart-qc-strings.sh` assert enumeration) vs L435 (`rg` alternation).

R7b-F11 correctly extended the L435 `rg` alternation (`REQ-F71|REQ-F72|XART-F03|SPEC-F70|decision-count|invariant-count|SCAN|eligible|spec-version`). The **named test** at L437 — the artifact that actually enumerates required asserts — was not extended in step. Scanning L437, it asserts `REQ-F70`, `SPEC-F71`, `SPEC-F72`, `SPEC-F73`, `SPEC-F74`, `SPEC-F75`, `XART-F02`, `decision-count`, `invariant-count`, but it does **not** assert:

- `SPEC-F70` (review-spec QC-8 zero-live-AC FAIL, R7b-F10)
- `REQ-F71` (unresolvable `SCAN:`) or the R7b-F02 normalization fixtures (`SCAN:x#1` no-match FAIL; ambiguous-slug FAIL; `SCAN:quality-attributes#QA-01` PASS)
- `REQ-F72` (OOS/OQ snapshot closure, R7-F05)
- `XART-F03` (empty-namespace cross-artifact branch)
- the `conditionally-required` class / present-heading-with-`decision-count: 0` FAIL direction

This is the same class of gap R3-F04 and R7-F09 fixed for the `rg` line; here it is the test contract. Since the QC-string test is the freeze's enforcement surface for skill prose, list them.

---

### R7c-F11 — LOW — Wave 1's `world-class-min` fixture assert list was not updated with the keys R7b-F13 added to the template asserts

**Where:** L359 (template asserts, updated), L361 (fixture asserts, not updated).

R7b-F13 added `decision-count` and `invariant-count` to the **core template** assert list (L359). The **fixture** assert list (L361, "Fixture pair is a filled min spec…") enumerates AC/REQ extraction, Functional AC cells, `nfr-source-cell-list`, Coverage Matrix cells, and AC namespace — but never `### Invariants`, `invariant-count`, `decision-count`, or `id-tombstones` on the fixture itself.

`world-class-min` is a *compiled-shaped* pair (unlike the template) and is reused as the positive case on the Wave 2 QC surface. Under QC-11 (`invariant-count` equality ≥ 1) and QC-12 (`decision-count` presence on new compiles) a fixture lacking those keys FAILs — which would make the freeze's own positive fixture red. Note R7-F11 exempts it only from *kind-required packs*, not from core YAML. Add the core keys to L361.

---

### R7c-F12 — LOW — Wave 4 verify never asserts that the Invariants turn is always-on / not kind-gated

**Where:** L515 (turn sequence), L519 (Wave 4 Verify).

L515 pins Invariants as an always-on turn, and the Wave 4 verify line string-asserts the brief **field** names including `invariants` (R1b-F02). But the verify list only asserts turn *skippability* for the kind-gated turns and explicitly asserts mandatory-ness for one turn — "Assert the QA/`nfr` turn is **mandatory** for nfr-required kinds (`infra-devops`, `data-ml`, `headless-service`)" — with no equivalent assert that Invariants fires for **every** kind.

Given R7c-F01 (the Invariants source chain now blocks installs when the field is absent), the always-on property is load-bearing: an implementer who lists Invariants among the kind-gated turns passes every stated Wave 4 assert and silently forces branch (2)/(3) on every greenfield compile. Mirror the `nfr` phrasing: assert the Invariants turn is always-on and not in the skip map.

---

### R7c-F13 — LOW — Wave 1 requires the REQUIREMENTS *template* to contain both a live measurable NFR `Metric` row and an empty-NFR `None identified` example; one artifact cannot carry both

**Where:** L360 (Wave 1 item 2 — "Assert REQUIREMENTS template contains:").

Inside one assert list, the template must contain "NFR column header `Metric` with a measurable cell example" **and** "example `None identified` for empty NFR pinned to the R7b-F08 precondition (`software-kind: cli` with `nfr` and `security` both omitted — `world-class-min` may carry this example…)". `None identified` is the **zero-data-row** state of the NFR table (L293), so a template with a live measurable `Metric` example row cannot also be in the `None identified` state.

Compounding it: the R7b-F08 precondition is evaluated against a resolved `software-kind`, and the *template* has a placeholder kind, so the precondition is not decidable on the template at all; the parenthetical hedges with "`world-class-min` **may** carry this example" without pinning the artifact. R7b-F14 solved the analogous ambiguity for the `Source` example by naming a dedicated fixture — do the same here: `Metric` example on the template, `None identified` on `world-class-min` (or a dedicated empty-NFR fixture), stated as such.

---

### R7c-F14 — nit — the new `conditionally-required` ontology row emits a bare "ISSUE" with no `SPEC-F*` code

**Where:** L159 vs L163 and L426.

The ontology row added by R7b-F09 reads "Absent-when-required = ISSUE; present-when-not = ISSUE (R7b-F09)". The neighbouring `forbidden` row names `SPEC-F08`, and the freeze states the rule twice: "Do not emit a bare ISSUE without a `SPEC-F*` code" (L260, L426). R7b-F16 was specifically about closing bare-code gaps; this row was introduced in the same pack and left uncoded. The operative code is QC-12 / `SPEC-F74` (L197, L426) — cite it in the ontology row so the table matches its own rule.

---

### R7c-F15 — nit — the pack table's "Default class" column uses vocabulary outside the five-class ontology enum, and R7b-F07 de-normativized only the Notes column

**Where:** L192–L207 (pack table) vs L155–L163 (ontology).

The ontology defines exactly five classes: `core-required`, `kind-required`, `optional`, `conditionally-required`, `forbidden`. The pack table's Default class column uses `always required` (core), `kind-gated` (eleven packs), `optional core; kind-required for infra-devops, data-ml, headless-service` (nfr), and only `decision-log` uses an enum value verbatim. `kind-gated` is not a class at all — it is a statement that the class is per-kind.

R7b-F07 declared the **Notes** column non-normative but said nothing about Default class, leaving a third surface that carries class-like information in non-enum words while "the tables are declared the machine source of truth" (the R7-F13 concern, resolved for Notes only). Either restate Default class in enum terms (`kind-gated` → "per-kind: see catalog") or declare it non-normative alongside Notes.

---

### R7c-F16 — nit — R7b-F08's catalog-derived conclusion is restated as normative prose in six places, recreating the second-source-of-truth hazard R7b-F07 just removed

**Where:** L262, L293 (×2), L360, L427, L458 — "in practice only `software-kind: cli` with `nfr` and `security` both omitted".

The claim is correct today (I re-derived it from the catalog L240–L250: every other kind requires `security` or `nfr`/`ops`, so every other kind has a live eligible `QA-nn`/`SLO-nn`/`CTRL-nn`). But it is a **consequence** of the catalog, restated six times as freeze text, on the same page where R7b-F07 established "the kind catalog table … is the **sole** machine source" precisely to stop derived prose from drifting.

OQ-07 explicitly contemplates catalog extension (`desktop-app`, `embedded`, `docs-only`) — a `docs-only` kind with no `security`/`nfr` would immediately falsify all six sentences while the normative rule ("reachable only when the resolved kind yields zero live `QA-nn`/`SLO-nn`/`CTRL-nn`") stays correct. Keep the rule; demote the "in practice only cli" clause to a single parenthetical marked *derived from the current catalog, non-normative*, or drop it.

---

## Scope / KEEP REJECT check

Nothing above proposes: merging SPEC + REQUIREMENTS; a third canonical doc (R7c-F07 explicitly keeps `.spec-kind-migration.md` non-canonical); Clarify writing SPEC.md; folding ingest; tightening spec-floor beyond Overview + AC; or unwinding R1–R4 / R5* / R6* / R7* pins. R7c-F01, F04, F05 are internal contradictions in this freeze's own fixtures/tree; F02, F03, F06, F08, F09 are missing machine contracts for keys/grammars the freeze already gates fail-closed on; the rest are test-surface and vocabulary residuals.

## Not re-filed (ledger)

R1-F01–F10, R1b-F01–F03, R2-F01–F06, R3-F01–F05, R5-F01–F03, R5b/R5c/R5e/R5f/R5h/R5i/R5j/R5k, R6b–R6n, R7-F01–F13, R7b-F01–F16, plus REJECT **R7b-F17** (nine always-on turns vs "9-turn interview" — resolved-as-rejected; the L515 sequence still reads as pass-2 left it) and KEEP-REJECT. Verified present/unweakened in this read; not re-reported.

## Handoff

- **Triage:** Composer 2.5 (this pass filed 16; expect REJECTs on anything Triage finds already encoded).
- **Fix/APPLY:** Grok 4.6 High, as a pack — R7c-F01/F04/F05 and F11/F13 are order-dependent with the Wave 1/Wave 6 fixture text; F02/F03/F06 touch the YAML key table and ontology together.
- **verify_2:** skipped on this NOT CLEAN per session policy.
- Reviewer did not triage, APPLY, edit the freeze/twins, switch branches, commit, or record any rung outcome.
