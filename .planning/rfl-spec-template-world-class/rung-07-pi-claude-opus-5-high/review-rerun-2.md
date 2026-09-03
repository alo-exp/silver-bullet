# Rung 07 — Review pass 2 (Pi Claude Opus 5 High) — residual-only

**Rung:** 7 of 8 — second review pass (Policy F streak 0 after pass-1 `accept-apply`)
**Model / host:** Claude Opus 5 High via Pi OmniRoute (`claude/claude-opus-5-high`) — reviewer only (Policy C)
**Freeze:** `.planning/spec_template_world_class.plan.md`
**SHA-256 (hashed this pass, both twins):**

```
22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc  .planning/spec_template_world_class.plan.md
22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both twins byte-identical and equal to the pinned SHA. `CONTEXT.md` metadata `freeze-sha256: edf2c256…` is stale (expected; hashed the files directly).
Graphify queried first (`graphify query "spec template world class freeze QC invariants"` — graph 43,493 nodes, freeze + twin + CHARTER + review-brief template nodes returned), then the freeze was re-read end to end (714 lines) independently of `review.md`.

**Verdict: NOT CLEAN — 17 residual findings (3 HIGH / 5 MED / 7 LOW / 2 nit).**

---

## 0. R7 APPLY confirmation (pass-1 pack landed — not re-filed)

| ID | Confirmed in this text | Evidence |
|----|------------------------|----------|
| R7-F01 | yes (partial — see R7b-F03 / R7b-F04) | L170 always-on Invariants turn + brief `invariants`; L448 Step 1 map; L451 Step 7 no-fabricate; L420 QC-11 sourced |
| R7-F02 | yes (partial — see R7b-F10) | L172 AC floor; L286 Functional-row floor; L421 QC-8 "vacuous `∅ = ∅ = ∅` is **not** PASS"; L422 XART empty-namespace; L452 Step 8 precondition; L590 fixture |
| R7-F03 | yes (see interaction R7b-F08) | L258 "**Eligible NFR source (R7-F03)**… live, non-tombstoned… required **and** optional-present packs. Tombstoned IDs are not eligible. `SCAN:` atoms are not in this set" |
| R7-F04 | yes (but see R7b-F02) | L287 "**resolvable** iff `<section>` equals a live staged-SPEC `##` or `###` heading (unique match)" |
| R7-F05 | yes | L288/L289 OOS/OQ set equality; L421 bound to QC-8/XART; L452 Step 8 |
| R7-F06 | yes (see R7b-F05 / R7b-F06 / R7b-F09) | L142 `decision-count` key; L195 pack note; L420 QC-12 iff; L451 Step 7 write |
| R7-F07 | yes (see R7b-F12) | L131 integer grammar/comparator/bump; L180 QC-10 restatement; L279/L282 REQUIREMENTS side |
| R7-F08 | yes (but see R7b-F01) | L254/L307/L451/L581/L590 `.planning/.spec-kind-migration.md`, non-canonical dotfile |
| R7-F09 | yes (see residual R7b-F11) | L428 rg now contains `nfr-source-cell-list\|id-tombstones\|QC-6b\|QC-4\|REQ-F30` |
| R7-F10 | yes (see residual R7b-F13) | L353 core-template asserts include `id-tombstones` |
| R7-F11 | yes (see R7b-F14) | L346 "**Core-only exempt (R7-F11)**… Wave 1b `kind-*` fixtures own kind-pack heading+body+ID obligations" |
| R7-F12 | yes | Parenthesis audit across all 714 lines: **zero** unbalanced lines; L452 fail-before-replace list closes after `empty/unsourced Invariants (R7-F01))`, emit duties are a new sentence |
| R7-F13 | yes | L188–L205 Notes use `plugin-extension`, `infra-devops`, `headless-service` (but see R7b-F07 for the *omission* class) |

R6b–R6n encodings (lineage equality, AC namespace closure, edge-set equality, `nfr-source-cell-list`, `coverage-matrix-req-cell-list`, staging/snapshot/fixed-point, exhaustion, 1b preserve-or-fail-closed) are all still present and are **not** weakened by anything below. Charter KEEP REJECT (two files, Clarify never writes SPEC.md, ingest stays, no third canonical kind doc) is intact — R7b-F01 below *defends* that KEEP, it does not attack it.

Also verified this pass and **not** filed: the R2-F03 closed-world cell count is exactly right (17 unlisted kind×pack cells enumerated at L162 == 17 computed from the L239–L247 catalog); the `data`, `mobile`, `ux`, `examples`, `decision-log`, `nfr`, `security` pack Notes match the catalog; QC-1 = 7 everywhere (L167, L184, L256, L353, L420); `security` required for `headless-service` / `data-ml` / `library-sdk` / `infra-devops` (R1-F06/R2-F02) holds.

---

## Residual findings

### R7b-F01 — HIGH — The kind-migration record is deleted on every branch, so the "preserve user prose" migrate path preserves nothing (and Wave 6 asserts the opposite)

**Cite (L451, Wave 3 Step 7):**
> **Kind-reconciliation migration record (R7-F08):** written only on the migrate branch; markdown dump of forbidden/unlisted heading prose. Lifecycle: staging sibling of the staged pair; snapshot-restore deletes it on FAIL (R6c leftover); after successful canonical install, **delete deterministically — do not retain as a consumer artifact.**

**Cite (L581, Wave 6):**
> do **not** silently delete user prose — migrate to the named **non-canonical** `.planning/.spec-kind-migration.md` (… staging sibling; **deleted deterministically after successful install or on snapshot-restore FAIL**) or ASK.

**Cite (L590, Wave 6 behavioral fixture):**
> generic-old-spec-with-UX → `cli` (output has no `## UX Flows`; **user prose preserved via the documented non-canonical migration path** `.planning/.spec-kind-migration.md` …)

The lifecycle is total and terminal on **both** outcomes: install success ⇒ delete; snapshot-restore FAIL ⇒ delete. There is no third outcome. Therefore the migrated `## UX Flows` prose is destroyed in every case, which is *exactly* the "silently delete user prose" the migrate branch was introduced (R5-F01) to prevent, and the Wave 6 fixture at L590 asserts a property ("user prose preserved") that the L451 lifecycle makes unsatisfiable — the fixture is unimplementable as written.

Note the asymmetry that makes this a real defect and not a nit: the ASK branch preserves prose (the operator decides), the migrate branch does not. The migrate branch is currently a slower spelling of silent deletion.

**Why R7-F08 does not already cover it:** R7-F08 asked for the artifact to be *named and non-canonical*; the APPLY named it and then gave it a lifecycle that voids its purpose. This is a defect in the new text.

**Suggested fix (keeps the KEEP REJECT — no third canonical doc):** make the migrate branch's durability explicit and bounded. Either (a) the migrate branch is only legal when the prose is *relocated into a surviving destination* the operator chose (another live SPEC section, an existing planning doc, or the operator's clipboard/answer via ASK) and the dotfile is merely the transport, with **fail-before-install if no destination was accepted**; or (b) keep the dotfile but state it survives successful install as an operator-visible, non-canonical, non-plugin-mirrored, not-parsed-by-any-QC record with an explicit retention rule and an explicit statement that it is not a consumer artifact and never an input to compile/QC. Then align L581 and the L590 fixture assertion to whichever is chosen.

---

### R7b-F02 — HIGH — `SCAN:` can never resolve to a multi-word heading: the R6i-F02 no-space atom grammar and the new R7-F04 resolution rule are jointly unsatisfiable for most sections

**Cite (L287, REQUIREMENTS NFR Source):**
> Each atom is exact `QA-[0-9]{2}` or `SLO-[0-9]{2}` or `CTRL-[0-9]{2}` or `SCAN:<section>#<line-or-id>` (`<section>` and `<line-or-id>` **non-empty and contain neither comma nor space**). **SCAN resolution (R7-F04):** … `SCAN:<section>#<line-or-id>` is **resolvable** iff `<section>` **equals a live staged-SPEC `##` or `###` heading (unique match)** …

The same pairing is restated at L258, L421, L422 and bound to fail-before-install at L452 (`unresolvable SCAN: (R7-F04)`).

`<section>` may not contain a space, but the sections a scanned non-functional concern actually lives in are multi-word: `## Quality Attributes`, `## Acceptance Criteria`, `## User Stories`, `## Out of Scope`, `## Open Questions`, `## Change History`, `## Decision Log`, `## UX Flows`, `### Invariants` (single-word, fine) — of the core-required set only `## Overview` and `## Implementations` are single tokens. So:

- `SCAN:Quality Attributes#QA-01` — **lexically FAIL** (space in `<section>`).
- `SCAN:QualityAttributes#1` / `SCAN:quality-attributes#1` — **lexically PASS but unresolvable**, because no live heading *equals* that string and no normalization (slug, case-fold, whitespace-strip, `##` prefix handling) is defined anywhere in the freeze.

Result: the only reachable `SCAN:` targets are the single-token pack headings (`## Security`, `## Telemetry`, `## API`, `## CLI`, `## Data`, `## Errors`, `## Mobile`, `## Pipeline`, `## Examples`, `## Operations`, `## Overview`) — and those are precisely the sections that already have structured pack-local IDs (`CTRL-nn`, `SIG-nn`, `EP-nn`, …), i.e. the cases where `SCAN:` is *not* needed. `SCAN:` exists (L286) "for compiler-discovered concerns with no structured pack ID", which by construction live in unstructured multi-word sections. The escape hatch is closed on exactly its use case, and because unresolvable `SCAN:` is now fail-before-install (L452), a compiler that legitimately scans `## Acceptance Criteria` for an NF concern has **no legal Source value at all** and cannot install.

The freeze's own fixtures do not disambiguate: the FAIL fixture is `SCAN:x#1` (single token, no matching heading) and the PASS fixture is only described as "a live heading + id in the fixture" — no literal PASS string is given, so the contradiction is invisible to a string test.

**Suggested fix:** define a normalization for `<section>` explicitly (e.g. `<section>` is the heading text lowercased, non-alphanumerics collapsed to `-`, `##`/`###` markers stripped: `SCAN:quality-attributes#AC-03`), state that resolution compares the normalized forms, require the normalized form to match exactly one live staged-SPEC `##`/`###` heading, and add a literal PASS fixture (`SCAN:quality-attributes#QA-01`-style) plus a FAIL fixture for an ambiguous/duplicate normalized heading. Keep the no-comma/no-space atom rule (it protects `nfr-source-cell-list`); the normalization is what makes it satisfiable. Do not weaken R6i-F02's `, ` delimiter.

---

### R7b-F03 — HIGH — Sourced Invariants have no brief-absent and no preserve-on-augment branch, so brief-less augment (the whole point of Wave 6 paths 2/3/4b) is permanently fail-closed at QC-11

**Cite (L170):**
> **Sourced (R7-F01):** Clarify always-on Invariants turn writes brief field `invariants` … Step 7 writes those bullets and **MUST NOT fabricate unsourced MUST/MUST NOT lines**. **Empty/scaffold Invariants FAIL QC-11 / `SPEC-F73` (fail-closed before install).**

**Cite (L451, Step 7):** `write `### Invariants` from brief `invariants` … do **not** fabricate unsourced invariant bullets; empty/scaffold FAIL QC-11 / `SPEC-F73` before staging succeeds`
**Cite (L452):** fail-before-replace list includes `empty/unsourced Invariants (R7-F01)`.

But the brief is explicitly optional: L140 — `` `clarify-brief` | path or `""`. **Not QC-6 required** — optional, allowed-empty (R5-F02) ``. And Wave 6 augment paths presuppose brief-less runs (L575: "If `software-kind` missing, **mint from brief or ASK**"; path 3 at L576 augments a legacy file that never went through Clarify).

Three unhandled states, each of which is now a hard deadlock:

1. **Augment with no brief.** No `invariants` field exists ⇒ Step 7 has no sourced bullets ⇒ it must either fabricate (forbidden) or emit empty (FAIL QC-11, fail-before-install). The augment can never install. Compare Step 7's explicit preservation rules for everything else — `created` (L451), `AC-nn` (L451, "Preserve still-present valid IDs"), `EX-nn` ("preserve existing valid `EX-nn` on augment"), REQ/NFR (L452) — Invariants got no such rule.
2. **Augment with a brief that has no `invariants`** (operator declined / older brief predating the always-on turn): same deadlock.
3. **Legacy augment (path 3/4b) of a SPEC that already has good `### Invariants`:** the freeze never says "preserve existing `### Invariants` bullets and treat them as sourced". Under the current text they are unsourced ⇒ FAIL.

The ISSUE-new/INFO-legacy split (L69) lists QC-11 as sharing the split, which softens *reviewer* output on legacy files, but it does not help: L170/L451/L452 make empty/unsourced Invariants a **compiler-side fail-before-install** precondition, which is not an ISSUE/INFO gradient.

**Suggested fix:** add an explicit source-precedence rule to Step 7 and QC-11: (1) brief `invariants` if present; else (2) **preserve** existing live `### Invariants` bullets from the prior canonical SPEC (augment paths 2/3/4b) and treat preserved bullets as sourced; else (3) **ASK** the operator (same shape as the kind-reconciliation ASK) and record the answer as the source; fabricate never; empty only on true greenfield where the operator declined, which stays FAIL. State that path 1 (true greenfield, both files absent) still requires a sourced non-empty Invariants block per the R7-F01 floor.

---

### R7b-F04 — MED — QC-11's "sourced" predicate is not QC-visible: reviewers read the SPEC, not the brief — the exact defect `decision-count` was minted to fix

**Cite (L420, review-spec):**
> Add **QC-11:** `## Overview` contains `### Invariants` with ≥1 MUST or MUST NOT bullet (`SPEC-F73`) (R1-F08). **Sourced (R7-F01):** those bullets **MUST come from brief `invariants` / Step 7 write (unsourced/fabricated/scaffold FAIL)**.

**Cite (L195, the contrasting precedent):**
> **Enforcement (R7-F06):** Step 7 always writes YAML `decision-count` … QC-12: `## Decision Log` present iff `decision-count` ≥ 1 … **Reviewers read SPEC YAML, not the brief.**

R7-F06 established the freeze's own doctrine — a reviewer-visible YAML projection is required whenever a QC predicate depends on brief content — and the same APPLY pack then wrote a QC-11 predicate ("must come from brief `invariants`") that has no such projection. `review-spec` is given `.planning/SPEC.md` (or a staged candidate); it cannot open the brief (the brief path is optional and may be `""`), so it can only check *presence* and *shape* of the bullets, never provenance. "unsourced/fabricated FAIL" is therefore unimplementable as a QC, and a compiler that fabricates invariant bullets produces a SPEC that passes every check.

Note this is a strictly different defect from R7b-F03: F03 is "no branch exists for the missing-brief case", F04 is "even when a brief exists, no reviewer can tell whether the bullets came from it".

**Suggested fix:** mirror the `decision-count` pattern — Step 7 writes a reviewer-visible YAML projection, e.g. `invariant-count` (non-negative integer = brief `invariants` bullet count, or the preserved-bullet count under R7b-F03's precedence rule), and QC-11 becomes: `### Invariants` present **and** its live MUST/MUST NOT bullet count equals `invariant-count` **and** that count ≥ 1. Keep `SPEC-F73`. Alternatively state plainly that provenance is a *compiler* obligation (Step 7 fail-before-staging) and that QC-11 checks presence/shape/count only — but then delete "unsourced/fabricated FAIL" from the review-spec row so the reviewer contract is not describing a check it cannot perform.

---

### R7b-F05 — MED — A missing or malformed `decision-count` has no defined behavior, so omitting the key silently escapes the QC-12 decision-log iff

**Cite (L142):** `` | `decision-count` | Non-negative integer. **Not QC-6 required.** Step 7 always writes it from brief `decisions` row count (R7-F06). QC-12: `## Decision Log` present iff this value ≥ 1. |``
**Cite (L145):** "**QC-6 required set is only `feature-slug` + `software-kind`**"

`decision-count` is explicitly *not* QC-6 required, and — unlike `id-tombstones`, which got a presence rule (L420: "parse YAML `id-tombstones`; **ISSUE-new if the key is missing on new compiles (INFO-legacy if absent)**") — nothing in the freeze says what happens when `decision-count` is absent, non-integer, negative, or quoted. Consequences:

- On a **new compile** where the key is absent, QC-12's biconditional has no left-hand side. A reviewer must either skip the check (⇒ the R7-F06 enforcement is optional in practice) or invent a default (⇒ unstated behavior, and the two obvious defaults disagree: "absent ⇒ treat as 0" turns any present `## Decision Log` into a FAIL, while "absent ⇒ skip" restores the original unenforceable state).
- There is no coercion rule. `spec-version` got a precise one at L131 (`1` and `"1"` coerce equal; `v1` / `1.0` FAIL); `decision-count` got none, so `"2"`, `2.0`, `-1`, and `two` are all undefined.
- Because the key is not QC-6 required and has no presence rule, a compiler that simply never writes it is fully conformant while QC-12's decision-log branch is dead.

**Suggested fix:** give `decision-count` the same two rules its siblings have. Presence: ISSUE-new if missing on new compiles, INFO-legacy on augment of a file that predates the key (add `decision-count` to the L69 ISSUE-new/INFO-legacy pin row alongside `feature-slug`/`software-kind`). Grammar: integer ≥ 0, `0`/`"0"` coerce equal, non-integer / negative / `v`-prefixed FAIL — with the explicit statement that when the key is absent on a **new** compile QC-12 FAILs rather than skipping.

---

### R7b-F06 — MED — Brief-less augment forces a conformant compiler to delete a legacy `## Decision Log` (or fail), because `decision-count` is derived only from the brief

**Cite (L451, Step 7):** `write YAML `decision-count` from brief `decisions` length (R7-F06)`
**Cite (L420, QC-12):** `**Decision-log iff (R7-F06):** `## Decision Log` present iff YAML `decision-count` ≥ 1.`
**Cite (L195):** "absent heading with count ≥ 1 FAIL; **present heading with count 0 FAIL**"

On Wave 6 augment paths 2/3/4b with no brief (legal — L140 `clarify-brief` optional; L576 path 3 augments a legacy file), `brief decisions length` is 0 or undefined ⇒ `decision-count: 0` ⇒ QC-12 FAILs any preserved `## Decision Log`. But the same paths mandate preservation: L575 "preserve `created` and **extra sections**", L576 "preserve body". So Step 7 must simultaneously preserve the section (Wave 6) and produce a pair where its presence is a FAIL (QC-12) — the only escapes are to delete the operator's `DEC-nn` decision history or to never install.

This is the `decision-log` analogue of R7b-F03: the R7-F06 enforcement is defined only for the compile-from-brief path and was never carried onto the augment/preserve-body path.

**Suggested fix:** define `decision-count` on augment as `max(brief decisions rows, live preserved `DEC-nn` rows in the prior SPEC)` — i.e. Step 7 counts the live `## Decision Log` rows it preserves and writes that number — so the iff stays true by construction and preserved history is neither deleted nor fatal. Add a Wave 6 fixture: legacy SPEC with two `DEC-nn` rows + no brief ⇒ augment installs with `decision-count: 2` and QC-12 PASS.

---

### R7b-F07 — MED — Pack-table Notes still omit whole optional/forbidden classes the catalog assigns, so building the YAML from Notes + closed-world default contradicts the catalog

**Cite (Wave 1b work item 1, L389):**
> **Pack-table Notes must match the catalog** (R2-F02) … **YAML per-kind sets MUST equal the catalog table**; unlisted packs follow the R2-F03 closed-world default (omit / present = forbidden).

R2-F02/R7-F13 fixed the Notes that *contradicted* the catalog and the shorthand kind names. The residual class is Notes that are *incomplete*, which under the R2-F03 closed-world rule is not neutral — silence means forbidden. Cross-checking L188–L205 against the L239–L247 catalog:

| Pack | Notes say (L194–L205) | Catalog also says (L239–L247) | Effect of reading Notes as closed |
|------|------------------------|-------------------------------|-----------------------------------|
| `ops` | "required: infra-devops, headless-service" | **optional: http-api, data-ml**; forbidden: library-sdk | `## Operations` on a valid `http-api` SPEC ⇒ `SPEC-F08` |
| `api` | "required: http-api, library-sdk" | **optional: web-ui, plugin-extension, headless-service**; forbidden: cli | `## API` on a valid `web-ui` SPEC ⇒ `SPEC-F08` |
| `telemetry` | "required: http-api, headless-service, infra-devops" | **optional: web-ui, mobile, data-ml** | `## Telemetry` on a valid `mobile` SPEC ⇒ `SPEC-F08` |
| `errors` | "required: http-api, cli, headless-service" | **optional: web-ui, library-sdk, mobile, data-ml, infra-devops, plugin-extension** | `## Errors` on a valid `web-ui` SPEC ⇒ `SPEC-F08` |
| `pipeline` | "required: data-ml" | forbidden: web-ui, cli, mobile, plugin-extension | forbidden-set silently narrower/wider than catalog |

Compare `data` (L200: "required: data-ml; optional: web-ui, http-api, headless-service, mobile, infra-devops, cli") and `cli` (L202: required + optional + forbidden) — those rows *are* complete, which proves the Notes column is meant to carry the full classification and makes the omissions look like data, not style. The `ops` row is the most damaging because optional-present `ops` is what mints `SLO-nn`, and `SLO-nn` is an **eligible NFR source** under R7-F03 (L258) — so this omission propagates into reverse-coverage.

**Suggested fix:** either (a) complete the five Notes cells so every pack row lists required / optional / forbidden exactly as the catalog does, or (b) state once, normatively, that the **kind catalog table (L239–L247) is the sole machine source of truth** and the pack-table Notes column is non-normative prose that MUST NOT be used to derive `software-kinds.yaml` — and add a Wave 1b assertion that the generated YAML is diffed against the catalog table, not the Notes. Option (b) is cheaper and closes the class permanently. Do not weaken R2-F02 or R2-F03.

---

### R7b-F08 — MED — R7-F03 eligibility plus near-universal required `security` makes `None identified` unreachable for 9 of 10 kinds, while Wave 1 still asserts an unconditional empty-NFR PASS

**Cite (L258):** "**Eligible NFR source (R7-F03):** … every live, non-tombstoned `QA-nn` / `SLO-nn` / `CTRL-nn` present on the staged SPEC (kind-required packs **and** optional-present packs)."
**Cite (L286):** "Empty `None identified` remains **only for the no-eligible-sources case**." / L421: "`None identified.` **forbidden** while any eligible source lacks an NFR mapping or a valid disposition row."
**Cite (L354, Wave 1 REQUIREMENTS template asserts):** "example `None identified` for empty NFR (**empty-NFR PASS unchanged**)."

`security` is kind-**required** for `web-ui`, `http-api`, `mobile`, `plugin-extension`, `headless-service`, `data-ml`, `library-sdk`, `infra-devops` (L199, pinned by R1-F06/R2-F02) — 8 of 10 kinds, and `multi` inherits it by union, leaving only `cli` (security optional). A required `security` pack must carry ≥1 substantive `CTRL-nn` (L156 kind-required class, QC-12). Every `CTRL-nn` is by definition an eligible source. Therefore for effectively every kind, `no eligible sources` is unreachable, and `None identified` is a dead branch — yet Wave 1 asserts the template ships that example and that "empty-NFR PASS" is unchanged, and Wave 2/Wave 3 keep restating the empty branch as live (L258, L286, L421, L452).

Two concrete harms: (1) the Wave 1 assertion can be satisfied by a fixture that Wave 2 reverse-coverage would FAIL, so the two waves' fixtures disagree; (2) implementers reading "empty-NFR PASS unchanged" will build an empty-NFR happy path that no real compiled SPEC can take, and the first `web-ui` compile will fail reverse-coverage with no diagnostic explaining that every `CTRL-nn` needs an `NFR-nn` or a `### Source Dispositions` row.

**Suggested fix:** state the precondition explicitly wherever the empty branch appears: "`None identified` is reachable only when the resolved kind yields **zero** live `QA-nn` / `SLO-nn` / `CTRL-nn` — in practice only `software-kind: cli` with `nfr` and `security` both omitted." Pin the Wave 1 empty-NFR example/fixture to such a kind (or move it to a dedicated `kind-cli-min` parser fixture), and add the paired Wave 2 fixture: `web-ui` with one `CTRL-01` and an empty NFR table + `None identified` ⇒ **FAIL** (neither-branch), so the dead-branch trap is tested rather than documented.

---

### R7b-F09 — LOW — The four-class section ontology has no conditionally-required class: `optional`'s "Absent = PASS" contradicts the QC-12 decision-log iff

**Cite (L157):** `| **optional** | May be absent; if present must be well-formed | **Absent = PASS**; placeholder-only = ISSUE (Wave 2 QC-12, R5b-F01) |`
**Cite (L195):** `decision-log … | **optional all kinds** | … QC-12: `## Decision Log` present iff `decision-count` ≥ 1 (**absent heading with count ≥ 1 FAIL**…)`

L153 declares the classification total: "Every `##` heading in a compiled SPEC is **one of**" {core-required, kind-required, optional, forbidden}. `decision-log` is classed `optional` in the only column that assigns a class, yet its absence is a FAIL when `decision-count ≥ 1`. So either the ontology's `optional` row is wrong, or `decision-log`'s class is wrong; a reviewer implementing the ontology table literally will not fire the QC-12 absent-heading FAIL.

**Suggested fix:** add a fifth class row — **conditionally-required** ("required exactly when a stated YAML predicate holds; absent-when-required = ISSUE, present-when-not = ISSUE") — and reclass `decision-log` into it with predicate `decision-count ≥ 1`. This costs one table row, removes the contradiction, and gives future gated packs a home. Do not change `decision-log`'s kind-catalog optionality.

---

### R7b-F10 — LOW — The R7-F02 ≥1-live-AC floor was bound to REQUIREMENTS QC-8 / XART / Step 8 but not to `review-spec`, whose own QC-8 stays vacuous on a zero-AC SPEC

**Cite (L420, review-spec):** "Add **QC-8:** every AC has `AC-nn` (`SPEC-F70`)."
**Cite (L172, the floor):** "**Floor (R7-F02):** ≥1 live `AC-nn` on any staged SPEC that will install (empty AC set FAIL — not a vacuous **QC-8** / R6l / R6k / XART-F02 PASS)."

The floor landed at L421 (`review-requirements` QC-8 / `REQ-F70`), L422 (XART empty-namespace), and L452 (Step 8 precondition) — all three are on the REQUIREMENTS/pair side. `review-spec`'s QC-8 row was not amended, and `review-spec` QC-8 is a universally-quantified statement ("every AC has `AC-nn`") that is trivially true of a SPEC with zero AC entries. Two consequences: (1) `review-spec` run standalone on a zero-AC SPEC reports clean; (2) the "QC-8" token inside the L172 floor is ambiguous — SPEC QC-8 (`SPEC-F70`) and REQUIREMENTS QC-8 (`REQ-F70`) are different checks with different codes, and only the latter carries the floor.

Install is still fail-closed via Step 8/XART, so this is LOW, not a hole in the install gate — but the SPEC-side reviewer contract is incomplete and the citation is ambiguous.

**Suggested fix:** amend the review-spec QC-8 cell to "every AC has `AC-nn` **and ≥1 live `AC-nn` exists** (`SPEC-F70`); zero live AC is FAIL, not vacuous PASS (R7-F02)", and disambiguate L172's floor citation to "SPEC QC-8 / REQUIREMENTS QC-8 / R6l / R6k / XART-F02".

---

### R7b-F11 — LOW — The Wave 2 verify `rg` still omits the newest named contracts (`decision-count`, `SCAN`, `eligible`, `spec-version`)

**Cite (L428):**
```
rg -n "QC-2|QC-7|…|coverage-matrix-req-cell-list|nfr-source-cell-list|id-tombstones|QC-6b|QC-4|REQ-F30|live staged-SPEC|software-kind|…|staged-pair lineage equality|derived-from|…" skills/review-spec/SKILL.md skills/review-requirements/SKILL.md skills/review-cross-artifact/SKILL.md
```

R7-F09's five tokens are present (verified). But the same APPLY pack introduced four further named, reviewer-side contracts that the string harness does not cover: `decision-count` (the QC-12 iff key, L420/L421), `SCAN` (the R7-F04 resolution rule, L421/L422), `eligible` (the R7-F03 quantifier that gates every reverse-coverage branch, L421/L422), and `spec-version` (the R7-F07 grammar/comparator that QC-10 and R6n both depend on). A skill edit could silently drop any of the four and this verify stays green — exactly the regression class R7-F09 was filed to close.

**Suggested fix:** extend the alternation with `decision-count|SCAN|eligible|spec-version` (and, if the R7b-F04 fix adds one, `invariant-count`).

---

### R7b-F12 — LOW — `spec-version` has a grammar, a comparator, and a bump rule, but no initial value for greenfield or for path-3 frontmatter mint

**Cite (L131):** "positive integer ≥ 1 … **Comparator:** numeric integer order, strictly ascending … **Bump:** increment by 1."
**Cite (L576, path 3):** "existing SPEC has `## User Stories` … but **no** `spec-version` frontmatter → **mint frontmatter**, preserve body, then same as step 2"
**Cite (L573, path 1):** true greenfield "→ write `.planning/SPEC.md` + `.planning/REQUIREMENTS.md` as today"

Every rule is relative (bump = +1, ascending, "current YAML `spec-version`"); no rule is absolute. The two paths that create a `spec-version` from nothing — greenfield (path 1) and mint-frontmatter (path 3) — do not say what value to write. This interacts with two hard gates: QC-10 requires "a row whose `spec-version` equals current YAML `spec-version`" (L180), and R6n requires exact integer equality between the staged SPEC and REQUIREMENTS. Two independent implementations that seed differently (1 vs 0 — note `0` is excluded by "≥ 1" but a "count of prior versions" implementation would produce it) will produce pairs that disagree, and path 3's "then same as step 2" (which *bumps*) reads as though a freshly minted frontmatter should immediately become 2.

The `spec-version: 1` in the REQUIREMENTS YAML block at L272 is an example, not a normative seed, and it is on the REQUIREMENTS side.

**Suggested fix:** add one sentence to L131: "**Seed:** a SPEC that has no prior `spec-version` (true greenfield path 1, or path 3 frontmatter mint) is written as `1`; the Change History table gets exactly one row for version `1`; path 3 mints `1` and does **not** additionally bump on the same run."

---

### R7b-F13 — LOW — Wave 1 SPEC core-template asserts include `id-tombstones` but not `decision-count`

**Cite (L353):** "Tests assert SPEC **core** template contains: YAML keys `feature-slug`, `software-kind`, `id-tombstones`, `derived-requirements` …"

R7-F10 added `id-tombstones` here for exactly this reason: a key that Step 7 "always writes" and that a QC depends on must be present in the shipped core template so the template test locks it. `decision-count` is now in the same category — L142 "Step 7 **always writes it**", L420 QC-12 depends on it — but it is absent from the Wave 1 assert list, so `templates/specs/SPEC.md.template` can ship without the key and no Wave 1 test notices.

**Suggested fix:** add `decision-count` (and `invariant-count` if R7b-F04's fix mints one) to the L353 core-template YAML-key assert list, matching the R7-F10 treatment of `id-tombstones`.

---

### R7b-F14 — LOW — The `world-class-min` fixture (`software-kind: cli`) cannot legally carry the `QA-01, SLO-01` Source example that Wave 1 offers it

**Cite (L346):** "`tests/fixtures/specs/world-class-min/SPEC.md` … a **kind-tagged** min spec (`software-kind: cli` so UX Flows is omitted)"
**Cite (L354):** "a live NFR `Source` **cell** example `QA-01, SLO-01` **in the min fixture** or a dedicated parser fixture (header-only empty does not satisfy R6i-F02)"
**Cite (L355):** same option repeated for the id-parse test.

`SLO-nn` is minted only by the `ops` pack (L205). For `software-kind: cli` the catalog (L241) lists `ops` in **none** of required/optional/forbidden ⇒ it is an unlisted cell ⇒ R2-F03 closed-world: present `## Operations` on a `cli` SPEC is a forbidden heading (`SPEC-F08`). And every NFR row needs a **resolvable** Source (L421). So a `world-class-min` REQUIREMENTS carrying `QA-01, SLO-01` either cites an `SLO-01` that cannot exist on its paired SPEC (unresolvable Source ⇒ FAIL) or forces the paired SPEC to carry a forbidden `## Operations` (⇒ `SPEC-F08`). The "or a dedicated parser fixture" branch is the only satisfiable one, so the instruction as written offers an option that is dead.

R7-F11 exempted `world-class-min` from kind-**required** packs; it did not (and should not) exempt it from **forbidden**-heading rules, so the exemption does not rescue this.

**Suggested fix:** drop the "in the min fixture" option for the `QA-01, SLO-01` example and require the dedicated parser fixture (or pin that fixture's kind to one where both `nfr` and `ops` are legal — `infra-devops` or `headless-service`, where both are kind-required). Alternatively change the min-fixture example to a single-atom `QA-01` cell (legal on `cli`, since `nfr` is optional there) and keep the two-atom list only on the dedicated fixture, which is what R6i-F02's list-parsing fixture actually needs.

---

### R7b-F15 — LOW — The REQUIREMENTS "Headings (QC-1 lock)" section lists five headings while QC-1 is explicitly four — the R1-F01 ambiguity, unfixed on the REQUIREMENTS side

**Cite (L277, section title):** `### Headings (QC-1 lock)` — then items 1–5: Functional Requirements, Non-Functional Requirements, Out of Scope, Open Items, **Coverage Matrix**.
**Cite (L421, review-requirements):** "**Keep QC-1 four headings.**"
**Cite (KEEP REJECT, L46):** "review-requirements QC-1 headings: Functional, Non-Functional, Out of Scope, Open Items" (four).

Coverage Matrix presence is actually owned by QC-8 ("Coverage Matrix exists and every SPEC `AC-nn` appears (`REQ-F70`)", L421) — so the contract is complete, but the section that is supposed to be the normative heading list is titled "QC-1 lock" and contains an item QC-1 does not own. This is structurally identical to R1-F01 (SPEC-side "QC-1 heading count vs QC-10 Change History (7 vs 8)"), which was rated HIGH and fixed by stating the split explicitly at L167/L184 ("The universal floor is **seven QC-1 headings** plus **Change History enforced by QC-10** (eight core-required headings total). Implementers MUST NOT put Change History inside QC-1."). The REQUIREMENTS side never received the parallel sentence, so an implementer can reasonably lock five headings into QC-1 and break the KEEP REJECT pin.

**Suggested fix:** add the parallel sentence under L277: "Four of these are QC-1 (`Functional Requirements`, `Non-Functional Requirements`, `Out of Scope`, `Open Items`); **`## Coverage Matrix` presence is QC-8 / `REQ-F70`, not QC-1** — implementers MUST NOT add it to the QC-1 lock (five headings total, four in QC-1)." Retitle the section `### Headings (QC-1 lock + QC-8 Coverage Matrix)`.

---

### R7b-F16 — nit — Four of the new R7 fail-closed checks have no `SPEC-F*` / `REQ-F*` / `XART-F*` code, though the freeze forbids bare coded-less ISSUEs

**Cite (L256, R3-F05 pin):** "**Do not emit a bare ISSUE without a `SPEC-F*` code.**" (restated at L420.)

Every earlier gate has a code: QC-8 `SPEC-F70`, QC-9 `SPEC-F71`, QC-10 `SPEC-F72`, QC-11 `SPEC-F73`, QC-12 `SPEC-F74`, QC-13 `SPEC-F75`, forbidden heading `SPEC-F08`, `REQ-F10`, `REQ-F30`, `REQ-F70`, `XART-F02`; even R6n got "named XART/REQUIREMENTS fault". The R7 pack added four fail-before-install conditions with no code and no named fault:

- unresolvable `SCAN:` (L287, L421, L452) — described only as "same class as unknown `QA-nn`", and unknown `QA-nn` has no code either;
- OOS / Open Items snapshot inequality (L288, L289, L421, L452);
- empty live AC set / empty Functional table (L172, L286, L421, L422, L452) — L421 leans on `REQ-F70` for the QC-8 branch but the XART and Step 8 branches are uncoded;
- empty/unsourced Invariants at Step 8 (L452) — QC-11 has `SPEC-F73` but the Step 8 precondition is not tied to it.

Uncoded faults cannot be grepped by `test-review-spec-req-xart-qc-strings.sh` and cannot be cited by downstream RFL.

**Suggested fix:** assign codes (or explicitly reuse existing ones) for the four: e.g. `SCAN:` unresolvable ⇒ `REQ-F71`; OOS/OQ snapshot inequality ⇒ `REQ-F72`; empty-namespace floor ⇒ `REQ-F70` on the QC-8 branch and a named `XART-F03` on the cross-artifact branch; Step 8 unsourced-Invariants ⇒ explicitly `SPEC-F73`. Then add the new codes to the L428 `rg` alternation.

---

### R7b-F17 — nit — The always-on turn set is now exactly nine turns, colliding numerically with the KEEP REJECT phrase "one 9-turn interview for every kind"

**Cite (KEEP REJECT, L45):** "REJECT: … **one 9-turn interview for every kind**"
**Cite (L509):** "Always-on: Turn 0 kind, Turns 1–6 (Problem, User goal, Scope, User stories, AC, Edge), **Invariants** (always-on; brief `invariants` — R7-F01), last turn Open Questions."
**Cite (L526, Wave 4 verify):** "as skippable — **not as a universal 9-turn blob**."

Counting L509: Turn 0 + Turns 1–6 + Invariants + Open Questions = **9 always-on turns**. R7-F01's always-on Invariants turn is what pushed the floor from 8 to 9, so the freeze now mandates a universal nine-turn floor while two places reject "a 9-turn interview". The substance is fine — the rejection is about *kind-blindness*, not arithmetic, and the nine always-on turns are genuinely kind-independent — but the numeric collision is now exact and a Wave 4 implementer writing the string assert at L526 can read the freeze as self-contradictory.

**Suggested fix:** reword both to name the property rather than the count: KEEP REJECT ⇒ "one fixed kind-blind interview that asks every domain turn regardless of `software-kind`"; L526 ⇒ "not as a kind-blind blob where the domain turns are unconditional". Optionally state the floor explicitly at L509: "nine always-on turns plus kind-gated domain turns".

---

## Summary

| ID | Sev | One-line |
|----|-----|----------|
| R7b-F01 | HIGH | Kind-migration record is deleted on both branches, so the migrate path destroys the prose it exists to preserve; Wave 6 fixture asserts the opposite |
| R7b-F02 | HIGH | `SCAN:<section>` forbids spaces but must equal a live heading; multi-word headings unreachable, no normalization ⇒ unresolvable-by-construction, fail-before-install |
| R7b-F03 | HIGH | Sourced Invariants have no brief-absent / preserve-on-augment branch ⇒ brief-less augment (Wave 6 paths 2/3/4b) is permanently fail-closed at QC-11 |
| R7b-F04 | MED | QC-11 "sourced from brief" is not QC-visible; no YAML projection analogous to `decision-count` |
| R7b-F05 | MED | Missing/malformed `decision-count` undefined; omitting the non-required key escapes the QC-12 iff |
| R7b-F06 | MED | Brief-less augment derives `decision-count: 0`, forcing deletion or FAIL of a preserved legacy `## Decision Log` |
| R7b-F07 | MED | Pack-table Notes omit optional/forbidden classes (`ops`, `api`, `telemetry`, `errors`, `pipeline`); Notes + closed-world default contradict the catalog |
| R7b-F08 | MED | Required `security` (`CTRL-nn`) + R7-F03 eligibility makes `None identified` unreachable for 9/10 kinds while Wave 1 asserts empty-NFR PASS |
| R7b-F09 | LOW | Ontology `optional` "Absent = PASS" contradicts the QC-12 decision-log iff; no conditionally-required class |
| R7b-F10 | LOW | `review-spec` QC-8 not amended with the R7-F02 ≥1-live-AC floor; "QC-8" in the floor text is ambiguous SPEC vs REQUIREMENTS |
| R7b-F11 | LOW | Wave 2 verify `rg` omits `decision-count`, `SCAN`, `eligible`, `spec-version` |
| R7b-F12 | LOW | `spec-version` has no initial value for greenfield (path 1) or frontmatter mint (path 3) |
| R7b-F13 | LOW | Wave 1 SPEC core-template asserts omit `decision-count` (R7-F10 precedent) |
| R7b-F14 | LOW | `world-class-min` (`cli`) cannot legally carry the offered `QA-01, SLO-01` Source example (`ops` unlisted ⇒ forbidden) |
| R7b-F15 | LOW | REQUIREMENTS "Headings (QC-1 lock)" lists 5 while QC-1 is 4; R1-F01's SPEC-side clarification never mirrored |
| R7b-F16 | nit | Four new R7 fail-closed checks have no `SPEC-F*` / `REQ-F*` code despite the no-bare-ISSUE pin |
| R7b-F17 | nit | Always-on turn floor is now exactly 9, colliding with the KEEP REJECT "one 9-turn interview" phrasing |

**Not re-filed (ledger rows re-verified as landed in this text):** R1-F01–F10, R1b-F01–F03, R2-F01–F06, R3-F01–F05, R5-F01–F03, R5b/R5c/R5e/R5f/R5h/R5i/R5j/R5k, R6b–R6n, R7-F01–R7-F13. **KEEP REJECT respected:** no finding above proposes a third canonical doc, a merged SPEC+REQUIREMENTS, Clarify writing SPEC.md, dropping ingest, or tightening spec-floor; R7b-F01 explicitly preserves the non-canonical dotfile's non-canonical status.

**Reviewer:** Claude Opus 5 High (Pi / OmniRoute `claude/claude-opus-5-high`). Review-only — no triage, no APPLY, no freeze mutation, no branch/commit, no verify launch, no rung-outcome recording. Verify/Triage → Composer 2.5; Fix/APPLY → Grok 4.6 High.
