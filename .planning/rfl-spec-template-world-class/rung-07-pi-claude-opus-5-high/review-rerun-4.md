# RFL review — rung-07 Pi Claude Opus 5 High — pass 4 (residual-only)

**Rung:** 7 of 8 — fourth review pass.
**Reviewer:** Claude Opus 5 High via Pi OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`), CHARTER slug `claude-opus-5-high`. Host: Pi (`scripts/agent-pi/invoke.sh`). Not Cursor. Not Fast. Not Extra High. Not GPT.
**Role:** review-only (Policy C). No triage, no APPLY, no fix, no commit, no branch switch, no freeze mutation, no verify launch, no `--record-rung-review-outcome`.
**Mode:** residual-only (Policy G) — all severities filed, ledger rows not re-reported.

## Freeze pin (hashed this pass)

```
fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e  .planning/spec_template_world_class.plan.md
fce83948e0c8b7ef74af2cbc74facad9744a1baea1e1d0aa32810c21702ac48e  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Twins byte-identical and equal to the briefed pin `fce83948…`. 720 lines. Freeze not mutated by this pass.

## Verdict

**NOT CLEAN** — 12 residuals: **2 HIGH**, **3 MED**, **4 LOW**, **3 nit**. New IDs `R7d-F01`–`R7d-F12` (no collision with `R7-F01`–`R7-F13`, `R7b-F01`–`R7b-F17`, `R7c-F01`–`R7c-F16`, or R6b–R6n).

## R7c APPLY confirmation (spot-verified; not re-filed)

| ID | Evidence at this SHA | Landed |
|----|----------------------|--------|
| R7c-F01 | L172 branch (3) `ASK` + "**fail before write** if unresolved (batch / CI / `test-spec-legacy-lock.sh` / no operator — same terminal as kind-reconciliation ASK)"; L172 pins generic-old-spec-with-UX + R7b-F06 DEC fixture to carry live `### Invariants` in input; L596 restates | yes (residual F02 below) |
| R7c-F02 | L142 / L197 / L426 "live `DEC-nn` row count **equals** `decision-count` **and** `## Decision Log` present iff that value ≥ 1" | yes (residual F01 below) |
| R7c-F03 | L143 "count only top-level `-` bullets … first keyword after the list marker is uppercase `MUST` or `MUST NOT`"; L426 mirrors | yes |
| R7c-F04 | L360/L361 dedicated `infra-devops`/`headless-service` parser fixture "MUST also cover every eligible required-pack source (including live `CTRL-nn` …)" | yes |
| R7c-F05 | L131 "**Malformed prior (R7c-F05):** … treated as **no prior version** — seed `1`"; L581/L584 branches; L596 fixture | yes (residual F02 below) |
| R7c-F06 | L159 + L197 + L262-block + L395 `conditionally-required: {decision-log: "decision-count >= 1"}`; Wave 1b diffs the predicate map | yes (residual F08 below) |
| R7c-F07 | L258 / L313 / L587 / L596 "subsequent migrate **appends** a timestamped section (never truncate/overwrite prior preserved prose)" | yes |
| R7c-F08 | L73 / L293 / L427 named `scan-section-slug`: strip `##`/`###`, lowercase, run-collapse to single `-`, trim | yes (residual F06 below) |
| R7c-F09 | L73 / L293 "`<line-or-id>` MUST be a live ID inside that section … Bare line numbers … FAIL `REQ-F71`" | yes (residual F05 below) |
| R7c-F10 | L437 now names `SPEC-F70`, `REQ-F71` + SCAN fixtures, `REQ-F72`, `XART-F03`, conditionally-required / `decision-count: 0` FAIL | yes |
| R7c-F11 | L361 "`world-class-min` asserts YAML `decision-count` and `invariant-count` plus live `### Invariants`" | yes |
| R7c-F12 | L532 "Assert the Invariants turn is **always-on** (fires for every kind; not in the skip map) (R7c-F12)" | yes |
| R7c-F13 | L360 Metric example on template; `None identified` on `world-class-min` / dedicated empty-NFR fixture — "**not** both states on the template" | yes |
| R7c-F14 | L159 `SPEC-F74` on both directions of the conditionally-required row (no bare ISSUE) | yes |
| R7c-F15 | L262-block "Pack-table **Default class** uses only the five-class ontology enum" | yes (residual F10 below) |
| R7c-F16 | L262 "*derived from the current catalog, non-normative:* today that is `software-kind: cli` …"; zero-live-IDs rule kept; string "in practice only" now absent (0 hits) | yes |

R7b-F01–F16, R7-F01–F13, R6b–R6n encodings re-checked present and unweakened. REJECT `R7b-F17` and `KEEP-REJECT` not re-filed.

---

## Findings (new this pass)

### R7d-F01 — HIGH — `decision-count = max(brief, preserved)` is arithmetically incompatible with QC-12 live-`DEC-nn` count-equality

**Cite:** L142 (`decision-count` YAML row), L197 (`decision-log` pack row), L426 (review-spec QC-12), L457 (Step 7), L513 (Wave 4 capture schema).

L142: `**augment (R7b-F06)** = max(brief decisions rows, live preserved DEC-nn rows in the prior SPEC)`.
L142 / L197 / L426 (R7c-F02): `live DEC-nn row count **equals** this value` and `count mismatch FAIL`.

`max()` was correct while QC-12 was presence-only (R7b-F06 pre-dates R7c-F02). It is wrong under count-**equality**, because the freeze never states how the brief's `decisions` rows and the preserved `DEC-nn` rows combine into the emitted `## Decision Log`:

- Prior SPEC has live `DEC-01`, `DEC-02`; brief carries 3 **new** decisions. L513: "Compiler promotes any recorded decision into `## Decision Log`"; L581 augment: "preserve … extra sections", "do not renumber existing `AC-nn`" (preserve semantics). Emitted log = 2 preserved + 3 minted = **5** live `DEC-nn`. Written `decision-count` = `max(3, 2)` = **3**. QC-12 count mismatch → FAIL before install on a wholly legitimate augment.
- Only if the brief's `decisions` are guaranteed to be a superset containing the preserved rows does `max` equal the live count — and no dedup / union / identity rule for `DEC-nn` rows exists anywhere in the freeze (grep: no `dedup` / `merge` / `union` language for `decisions`; L264 and L623 `merge` hits are the KEEP-REJECT third-doc rule).

Note the asymmetry that makes this unambiguous: `invariant-count` (L143) uses **exclusive precedence** ("brief `invariants` … **if present**; else preserved live `### Invariants` bullet count"), so its written count always equals its emitted count. `decision-count` alone uses `max`, i.e. a two-source formula with no corresponding two-source emission rule.

**Expected:** define the augment Decision Log emission as a named union with a stated row-identity rule (e.g. preserved `DEC-nn` retained; brief rows not already present appended with next-free `DEC-nn`), and set `decision-count` = the resulting **live** `DEC-nn` count (not `max`). Keep R7b-F06's non-deletion intent (`decision-count` ≥ live preserved count). Pin a fixture: 2 preserved `DEC-nn` + brief with 3 distinct decisions ⇒ 5 live rows, `decision-count: 5`, QC-12 PASS.

---

### R7d-F02 — HIGH — R7c-F01's live-`### Invariants` precondition was pinned to only two fixtures; the other brief-less PASS-install fixtures (including one added by the same APPLY) still terminate at ASK / fail-before-write

**Cite:** L172 (R7c-F01 remedy), L457 (Step 7 precedence), L596 (Wave 6 behavioral fixtures).

L172 names exactly two: "**Wave 6 brief-less PASS fixtures (R7c-F01):** generic-old-spec-with-UX and the R7b-F06 DEC augment fixture MUST include live `### Invariants` … so they take branch (2) preserve and remain PASS-install — they MUST NOT depend on ASK."

But L596 pins further fixtures that assert a **successful canonical pair install** on augment paths, with no brief and no live-`### Invariants` precondition stated:

1. `Behavioral malformed spec-version fixture (R7c-F05): augment path 2/4b with YAML spec-version: 0.35 (or v1) seeds 1 … **pair installs**.` — added by the *same* R7c APPLY as R7c-F01, and not covered by R7c-F01's two-fixture enumeration.
2. `Behavioral staged-pair lineage equality fixtures (R6n-F01): fully matching pair PASS … Cover Wave 6 paths 1/1b/2/3/4b.` — the PASS half on paths 2/3/4b.
3. `Behavioral recoverable-pair-install fixtures (R6c-F01)` case (2) commit-boundary, which must reach the install boundary (i.e. Step 7/8 must succeed) on "at least one augment branch (2/3/4b)".
4. `Behavioral decision-count augment fixture` is pinned (L596 lists `R7c-F01` there) — correct; contrast highlights the gap in 1–3.

Step 7 (L457) hard-fails these: `write '### Invariants' … using R7b-F03 source-precedence (brief if present; else preserve live prior '### Invariants' as sourced; else ASK and **fail before write** if unresolved — R7c-F01 …)`. Under `test-spec-legacy-lock.sh` / CI there is no operator, so any brief-less augment fixture whose input lacks `### Invariants` deterministically fails **before** it can exercise the behavior it is pinned to prove.

**Expected:** generalize instead of enumerating — state once that **every** Wave 6 fixture asserting a PASS install must supply Invariants via branch (1) brief or branch (2) live prior `### Invariants`, and explicitly add that precondition to the R7c-F05 malformed-`spec-version` fixture, the R6n lineage PASS-on-augment fixtures, and the R6c commit-boundary augment fixture. (Sibling to R7c-F01, not a re-report: those three fixtures are outside R7c-F01's named pair.)

---

### R7d-F03 — MED — the `decisions` brief field is sourced by no turn, so `decision-count` is structurally `0` on greenfield and the conditionally-required `decision-log` pack is unreachable on new compiles

**Cite:** L513 (capture schema), L515 (pinned turn sequence), L197 / L159 (conditionally-required class).

L515: "**Pinned turn sequence (R1-F03 option A — add missing domain turns so all **13** packs are sourced …)**. Always-on: Turn 0 kind, Turns 1–6 …, **Invariants** …, last turn Open Questions. **Kind-gated domain turns** …" — the list that follows enumerates exactly **12** gated turns (`ux`, `errors`, `data`, `nfr`, `security`, `telemetry`, `api`, `cli`, `mobile`, `pipeline`, `ops`, `examples`). The pack table (L193–L207) has **13** non-`core` packs. The missing one is `decision-log`.

L513 then closes the door explicitly: "Do not add a 13th Decision Log **turn**." Yet the same line requires a `decisions` capture field ("`DEC-nn | date | decision | why` rows"), and L513's binding rule is "one brief field … **bound to the turn of the same name**". `decisions` has no such turn and is not in the always-on list either.

This is exactly the R7-F01 defect class (a required brief field with no sourcing turn), which was fixed for `invariants` by adding an always-on Invariants turn — and left unfixed for `decisions`. Consequence chain at this SHA:

- Greenfield: brief `decisions` is always empty ⇒ L142 "true greenfield = brief `decisions` row count" ⇒ `decision-count: 0` ⇒ L197 heading omitted ⇒ the `conditionally-required` class (R7b-F09) and its YAML predicate (R7c-F06) are vacuous for every new compile.
- The claim "all 13 packs are sourced" (L515) is false at this SHA — a numeric contradiction with the 12 listed turns, on a line whose whole purpose is R1-F03 ("skip map names **only turns that exist**").

**Expected:** either (a) add an always-on (or `decision-count`-gated) Decisions capture prompt, mirroring the always-on Invariants turn, and correct "13th Decision Log turn" / "all 13 packs are sourced"; or (b) name the non-turn provenance for `decisions` explicitly (e.g. operator-supplied brief field only, never interview-sourced) and change L515 to "all 12 kind-gated packs are sourced (+ `decision-log` via brief field only)". Do not leave a pack that no path can populate.

---

### R7d-F04 — MED — Invariants branch (1) silently destroys preserved live `### Invariants` prose, contradicting the freeze's own no-silent-delete rule

**Cite:** L172, L457 (Step 7 precedence), L457/L587 (kind-reconciliation no-silent-delete).

R7b-F03 precedence is exclusive: "(1) brief `invariants` if present; else (2) **preserve** existing live `### Invariants` bullets". So on any augment where a brief carries `invariants`, the prior SPEC's live Invariants bullets are **overwritten and lost**, with no migrate/ASK/record.

The freeze elsewhere treats exactly this loss as unacceptable, for less load-bearing prose: L457 / L587 kind-reconciliation — "must **not** be silently kept … and must **not** be silently deleted — move its prose to the named **non-canonical** migration record `.planning/.spec-kind-migration.md` … **or** ASK the operator … **fail before write** if unresolved." Invariants are the highest-value model-quotable content in the whole contract (L120: "Model … can quote MUST/MUST NOT"), and they are the one preserved body the compiler is allowed to drop without trace.

Note this also silently changes `invariant-count` (L143) with no Change History obligation beyond a generic summary, so the loss is not even reconstructable from the SPEC.

**Expected:** make branch (1) a **superseding** write with the same no-silent-delete discipline: brief `invariants` win, but prior live bullets that are not carried forward are appended to the retained `.planning/.spec-kind-migration.md` record (or an equivalently named non-canonical record with the R7c-F07 append rule), **or** ASK; fail before write if unresolved. Alternatively pin brief-wins as intentional with an explicit "prior Invariants are replaced, not merged" statement plus a Change History summary obligation. Do not create a third canonical doc (KEEP REJECT).

---

### R7d-F05 — MED — R7c-F09 makes `SCAN:<section>#<live-id>` able to name an eligible `QA-nn` / `SLO-nn` / `CTRL-nn`, colliding with the "SCAN atoms are not in the eligible set" carve-out

**Cite:** L262 (eligible definition + carve-out), L293 / L73 (SCAN grammar + R7c-F09 live-ID rule), L262 / L293 / L427 / L428 (exclusive reverse-coverage branches).

L262: "`SCAN:` atoms are **not** in this set (forward Source only; R7-F04)."
L293 (post-R7c-F09): "`<line-or-id>` … MUST be a live ID inside that section (not tombstoned, not invented; **not** a bare line number)." Fixture pinned at L293/L437: "Fixture PASS: `SCAN:quality-attributes#QA-01` against live `## Quality Attributes` containing `QA-01`."

That pinned PASS fixture is the collision. `QA-01` is an eligible source by L262's own definition (live, non-tombstoned, on a required-or-optional-present pack). After R7c-F09, the *only* legal `<line-or-id>` values inside `## Quality Attributes` / `## Operations` / `## Security` are precisely `QA-nn` / `SLO-nn` / `CTRL-nn`. So the reverse-coverage evaluation of `QA-01` is now undefined:

- Literal read (atom-level): the NFR `Source` cell contains the atom `SCAN:quality-attributes#QA-01`, not the atom `QA-01`. So `QA-01` appears in **zero** NFR Source cells and, absent a `### Source Dispositions` row, hits **"Neither FAIL"** (L262, L293, L427, L428) — even though it is demonstrably mapped to an `NFR-nn`.
- Add a dispositions row to satisfy the neither-branch and it is arguably in both branches → the freeze's **overlap FAIL** is at least contestable ("the only recorded non-requirement disposition" vs. a live mapping).

Either way a correct pair cannot install, and the freeze's own R7c-F08/F09 positive fixture is the trigger.

**Expected:** state that a `SCAN:` atom whose `<line-or-id>` resolves to an eligible `QA-nn` / `SLO-nn` / `CTRL-nn` **counts as forward coverage of that ID** for reverse-coverage/exclusivity (i.e. resolve atoms to source IDs before the eligible-set join), and reserve the L262 carve-out for `SCAN:` atoms resolving to non-eligible IDs (`AC-nn`, `US-nn`, …). Add a fixture: `SCAN:quality-attributes#QA-01` as the sole Source for `NFR-01` ⇒ `QA-01` reverse-covered, no dispositions row required, PASS. Do not weaken R5k exclusivity.

---

### R7d-F06 — LOW — Wave 2 verify `rg` alternation omits the two named tokens R7c added (`scan-section-slug`, `conditionally-required`)

**Cite:** L434 (`rg -n "QC-2|QC-7|…"`), vs L73 / L293 / L427 (`scan-section-slug`) and L159 / L197 / L395 / L426 / L437 (`conditionally-required`).

Verified by field split of L434: 49 alternates, including `decision-count`, `invariant-count`, `SCAN`, `eligible`, `spec-version` (R7b-F11's additions) and `SPEC-F74`. Neither `scan-section-slug` nor `conditionally-required` is present (grep of L434: 0 hits each). Both are **named** contract objects landed by R7c-F08 / R7c-F06 whose whole point is that the skill prose must carry the name; `SCAN` alone matches `SCAN:` atoms without proving the normalization function was written, and `QC-12` alone does not prove the fifth ontology class landed.

Same class as R7-F09 / R7b-F11 / R7c-F10, on tokens that post-date them.

**Expected:** extend the L434 alternation with `scan-section-slug|conditionally-required`.

---

### R7d-F07 — LOW — Wave 3's `test-clarify-spec-compiler.sh` verify list omits every R7 / R7b / R7c Step 7 obligation except the bare Invariants mapping

**Cite:** L490–L520 (the 31 `- contains …` bullets), vs L457 (Step 7) and L579–L584 (Wave 6 seeds).

The Wave 3 verify list is exhaustive for R5h/R5i/R5j/R6b/R6c/R6d/R6f/R6h/R6i/R6j/R6k/R6l/R6m/R6n — one dedicated bullet each. For the R7-family Step 7 obligations it carries exactly one: "- contains kind-aware Step 1 domain mapping … **and** brief `invariants` → `### Invariants` (R7-F01)". Not asserted anywhere in that list (verified by grep of the bullet block for `invariant|decision-count|spec-version|append|precedence|ASK`):

- Step 7 Invariants **source-precedence** and the branch-(3) ASK **fail-before-write** terminal (R7b-F03 / R7c-F01) — the strongest fail-closed rule added in the last two passes;
- Step 7 always writes YAML `invariant-count` / `decision-count` (R7b-F04 / R7b-F06 / R7-F06);
- `spec-version` **seed `1`** on greenfield / path-3 mint with exactly one Change History row (R7b-F12) and the malformed-prior seed (R7c-F05) — the list has only the generic QC-10 Change History bullet;
- the migration-record **append** retention rule (R7c-F07) — the existing bullet asserts only "retained after successful install (R7b-F01)".

**Expected:** add `- contains` bullets for Step 7 invariants source-precedence + ASK fail-before-write, `invariant-count` / `decision-count` writes, `spec-version` seed + malformed-prior seed, and the migrate-append rule.

---

### R7d-F08 — LOW — the `multi` catalog row is a computation, not a set, so "YAML per-kind sets MUST equal the catalog table" is unsatisfiable for `multi` (and so is its `conditionally-required` entry)

**Cite:** L252 (`multi` row), L262-block (R7b-F07 sole-machine-source), L395 (Wave 1b diff obligation), L159 (R7c-F06 "same for every kind").

L252's cells are rules — "union of listed `software-kinds` required packs; **required-wins** …", "union of optionals", "forbidden only if **all** listed kinds forbid it **and** none require it" — not pack-ID sets. But L262-block asserts "the kind catalog table … is the **sole** machine source for `software-kinds.yaml` **pack membership** … YAML per-kind sets MUST equal the catalog table", and L395 pins Wave 1b to "assert generated YAML is diffed against the catalog table". `multi` is a valid `software-kind` enum value (L134, QC-6), so a naive implementation of that diff either fabricates a `multi` YAML entry or reports a spurious diff.

R7c-F06 compounds it: "`software-kinds.yaml` MUST carry `conditionally-required: {decision-log: "decision-count >= 1"}` (same for every kind)" — undefined for `multi`, which has no YAML kind entry to carry it.

**Expected:** state that `software-kinds.yaml` carries entries for the **nine atomic** kinds only; `multi` is resolved at compile time by the L252 union / required-wins rules and is excluded from the Wave 1b set diff, with the `conditionally-required` predicate applying to the resolved kind. One clause; no catalog change.

---

### R7d-F09 — LOW — the exact-two-digit allocator has no defined first value, so `-00` is simultaneously "allocatable" (R6f) and unreachable by every minting example

**Cite:** L217 / L284 (R6f-F01 "`00–99` inclusive (`-00` is allocatable)"), L217 ("Compiler assigns sequentially at write time"), L437 / L457 / L596 (all mint/preserve fixtures).

Every ID example and every behavioral fixture in the freeze starts at `-01`: `AC-01`, `EX-01`, `REQ-01`, `US-01`, `DEC-01`, `CTRL-01`, `QA-01`, `SLO-01`; the tombstone fixtures are "start `AC-01`–`AC-03`" / "start `REQ-01`–`REQ-03`". No rule says where next-free begins. Consequences:

- If the allocator seeds at `01` (as all examples imply), the effective domain is 99 IDs and the pinned exhaustion fixture "`EX-00`–`EX-99` all live or tombstoned" (L217, L596) is **not reachable through the compiler's own mint path** — it can only be hand-authored, which weakens R6f's behavioral guarantee.
- If the allocator seeds at `00`, every `EX-01`/`AC-01`/`REQ-01` example in the templates and fixtures is a first-mint the compiler would never produce, so Wave 1/1b template asserts and Step 7/8 serialization disagree.

**Expected:** pin the seed explicitly — e.g. "sequential next-free starts at `-01`; `-00` is a legal, parseable value (legacy/hand-authored) and counts toward exhaustion but is never minted" — and restate the exhaustion fixture as `EX-01`–`EX-99` live/tombstoned plus `EX-00` present-or-tombstoned. Do not weaken R6f fail-closed.

---

### R7d-F10 — nit — pack-table `nfr` **Default class** cell embeds a catalog-derived kind list, against R7c-F15 enum-only and the R7c-F16 second-source hazard

**Cite:** L198, vs L262-block (R7c-F15) and L262 (R7c-F16 parenthetical pattern).

L262-block: "Pack-table **Default class** uses only the five-class ontology enum (`core-required` / `kind-required` / `optional` / `conditionally-required` / `forbidden`) (R7c-F15)."
L198 Default class cell: "**optional** (kind-required for infra-devops, data-ml, headless-service per catalog)".

That parenthetical is a **derived restatement of catalog membership inside a column the freeze declares normative** — precisely the drift surface R7b-F07 removed from Notes and R7c-F16 neutralized elsewhere with an explicit *"derived from the current catalog, non-normative"* tag (L262 does this correctly). The `nfr` cell carries no such tag, so a future catalog edit silently creates a second source of truth in a normative column. (Today it is accurate: catalog L246/L250/L251 do list `nfr` required for `data-ml`, `infra-devops`, `headless-service`.)

For contrast, the `decision-log` cell (L197) is compliant: enum + the *predicate*, which is genuinely not derivable from the three-set catalog.

**Expected:** reduce L198's Default class cell to `**optional**` and move the kind list to Notes (non-normative), or tag it exactly as R7c-F16 did: "*(derived from the current catalog, non-normative)*".

---

### R7d-F11 — nit — `invariant-count` grammar admits `0`, a value QC-11 makes permanently non-installable

**Cite:** L143 vs L143 / L426 (QC-11) and L142 (`decision-count`, where `0` is legitimate).

L143 opens "Non-negative integer ≥ 0" and closes "QC-11: live MUST/MUST NOT bullet count **equals** `invariant-count` **and** that count **≥ 1** (`SPEC-F73`)". `### Invariants` is core-required for every kind (L172, L100 pin row). So `invariant-count: 0` is grammatically valid, ISSUE-new/INFO-legacy-classified (L69), and yet can never appear on any SPEC that installs — a dead cell in the state space.

`decision-count: 0` is by contrast a real, reachable, fixture-pinned state (L437 "`decision-count: 0` FAIL" for the present-heading direction; count 0 + absent heading PASS), so the shared "Non-negative integer ≥ 0" phrasing is copied from a key where it is correct.

**Expected:** L143 grammar reads "positive integer ≥ 1 on any installed SPEC (`0` parses but FAILs QC-11 / `SPEC-F73`)". No QC change.

---

### R7d-F12 — nit — `SCAN:` atom permits `#` inside both halves with no split rule, so `SCAN:a#b#c` has no defined parse

**Cite:** L73 / L293 (atom grammar), L293 (`scan-section-slug`).

Grammar: "`SCAN:<section>#<line-or-id>` (`<section>` and `<line-or-id>` non-empty, no comma, no space)". `#` is excluded from neither half, but `#` is the delimiter. `SCAN:quality-attributes#QA-01#note` therefore parses as `<section>=quality-attributes`, `<line-or-id>=QA-01#note` (last-`#` split) or `<section>=quality-attributes#QA-01`, `<line-or-id>=note` (first-`#` split) with equal warrant, and the two disagree about whether the citation resolves — under a rule (`REQ-F71`) that is explicitly fail-closed.

Every other cell grammar in this freeze pins its separator to the codepoint (`, ` = U+002C + exactly one U+0020 in `nfr-source-cell-list` and `coverage-matrix-req-cell-list`); the SCAN atom is the one that does not.

**Expected:** add "`<section>` and `<line-or-id>` contain no `#`; exactly one U+0023 `#` separates them; zero or ≥2 `#` FAIL `REQ-F71`" to the atom grammar at L73 and L293, plus a negative fixture `SCAN:a#b#c` FAIL.

---

## Not re-filed (checked, still correct at this SHA)

- **`R7b-F17`** (nine always-on turns vs "9-turn interview") — REJECT / resolved-as-rejected. KEEP REJECT "one 9-turn interview for every kind" intact at L46; L532 "not as a universal 9-turn blob" untouched. Not re-filed.
- **`KEEP-REJECT`** — two files only; L46 Clarify does not write SPEC; L47 ingest stays; `.planning/.spec-kind-migration.md` still tagged non-canonical / not-parsed-by-any-QC / not-plugin-mirrored at L258, L313, L457, L587, L596; L714 third-file-creep rollback row intact.
- **R7-F02 floor** — L174 (≥1 live `AC-nn`), L297 (≥1 Functional row), `REQ-F70` / `XART-F03` on both branches; spec-floor still Overview+AC only (L38, L697 NFR-03).
- **R6b/R6c/R6d/R6f** — staging, snapshot-restore, fixed-point, exhaustion all present on Wave 3 Steps 7/8, Wave 6 paths 1/1b/2/3/4b, and the risk table (L706–L710). Not weakened by R7c.
- **R6h–R6n grammars** — `AC` exact-one, `nfr-source-cell-list`, `coverage-matrix-req-cell-list`, AC namespace closure, QC-7 two-mode, staged-pair lineage equality: all still bound to Wave 1 / Wave 2 / Step 8 / XART / Wave 6. Not weakened.
- **R7b-F15 heading lock** — L296 "five headings total, four in QC-1" intact.
- Wave 6 decision tree totality (L579–L584): 1 / 1b / 2 / 3 / 4 / 4b, with the malformed-`spec-version` cell now explicitly named as a defined cell (L584).

## Method

1. Hashed both freeze twins before reading; re-hash unchanged at end of pass (`fce83948…`). No writes to the freeze, twins, `CONTEXT.md`, `review.md`, `review-rerun-2.md`, or `review-rerun-3.md`.
2. Read all 720 lines of `.planning/spec_template_world_class.plan.md` in three passes (L1–250, L251–427, L428–720) plus targeted line/field re-reads for every claim above.
3. `graphify query` run first (graph resolved from `graphify-out/graph.json`, 43644 nodes; seed nodes `spec_template_world_class.plan.md`, `01-world-class-spec/PLAN.md`, `spec-template-world-class/CONTEXT.md`, `templates/rfl-review-brief.md`).
4. Independent re-hunt: pass 1/2/3 review files were **not** opened during finding derivation. Ledger used only as a do-not-re-report filter and as the R7b/R7c landed-checklist.

## Handoff

- **Triage/Verify:** Composer 2.5. **Fix/APPLY:** Grok 4.6 High. Reviewer (this hop): Claude Opus 5 High via Pi.
- NOT CLEAN ⇒ `verify_2` skipped per session policy (already-triaged NOT CLEAN).
- ACCEPTed items APPLY as one ordered pack. Suggested order (order-dependent): **F01** (decision-count formula) → **F03** (decisions sourcing; F01's union rule references the brief field) → **F02** (fixture preconditions) → **F04** → **F05** (eligible/SCAN join) → **F08** → **F09** → **F12** (grammar, feeds F05's parser) → **F06**, **F07** (verify surfaces, last so they can name the final tokens) → **F10**, **F11**.
- Policy F: this rung's streak is 0 after pass 3 `accept-apply`; this NOT CLEAN pass does not advance it. Do not advance to Claude Extra High from this hop.
