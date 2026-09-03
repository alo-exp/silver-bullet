# Rung 07 — Review pass 10 (Pi Claude Opus 5 High)

**Rung:** rung-07-pi-claude-opus-5-high (7 of 8) — **tenth** review pass
**Reviewer model:** Claude Opus 5 High — CHARTER slug `claude-opus-5-high` via Pi OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`)
**Host:** Pi (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast. Not GPT.
**Role:** review-only (Policy C). No triage, no APPLY, no fix, no commit, no branch switch, no verify launch, no ladder advance.
**Session policy:** Verify + Triage = Composer 2.5; Fix/APPLY = Grok 4.6 High. verify_2 skipped on already-triaged NOT CLEAN; required on CLEAN.

## Freeze integrity (hashed this pass)

```
56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed  .planning/spec_template_world_class.plan.md
56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both twins byte-identical and equal to the pinned SHA `56cdd698…`. 726 lines. Freeze not mutated by this pass.

## Method

`graphify query` first (CLI; MCP skill-version warning only), then a full independent re-read of the freeze (L1–L726) with targeted line-level cross-checks of every mechanism R7i touched. Pass 1–9 review files were **not** re-read as authority. Residual-only: no ledger ID re-filed, including REJECT `R7b-F17` and `KEEP-REJECT`.

## R7i APPLY confirmation (pack from pass 9)

| ID | Confirmed in this freeze | Residual |
|----|--------------------------|----------|
| R7i-F01 | `change-row-identity` named at L73, L131, L293, L427, L428, L476, L602; identity-match-only re-anchor; silent `vN`→`v1` FAIL; migration-record re-anchor target deleted (KEEP REJECT) | **partial** — see R7j-F03, R7j-F04, R7j-F05, R7j-F06 |
| R7i-F02 | `ASM-nn` optional-to-emit, QC-13 exact `ASM-[0-9]{2}` + file-unique (`SPEC-F75`) + `id-tombstones` join (L73, L175, L217, L426); compiler does not mint; duplicate `ASM-01` FAIL at L437 | **partial** — see R7j-F01, R7j-F02 |
| R7i-F03 | L426 named empty-delta form explicitly non-placeholder, closed `<reason>`, `N`; L437 PASS/FAIL fixtures | landed |
| R7i-F04 | L426 provenance = compiler obligation at Step 7; QC-10 shape/current-row/ordering/non-placeholder only; no `change-summary` YAML key | landed |
| R7i-F05 | L428 XART SCAN two-part (`scan-section-slug` + three-clause `<line-or-id>`); L437 XART ambiguous-slug FAIL | landed |
| R7i-F06 | L427 closed Invariants / unprefixed-Assumptions domain; other-section `bNN` incl. `## Overview` FAIL `REQ-F71` | landed |
| R7i-F07 | L434 alternation carries `decision-row-identity\|ASM-nn\|per-entry` and retains `version-cell\|v<integer>` | **partial** — see R7j-F05 |
| R7i-F08 | L476 QC-10 `- contains` binds named empty-delta sentence, closed `<reason>`, `N` = post-bump YAML decimal | landed |
| R7i-F09 | L197 `decision-log` Default class cell is enum-only `**conditionally-required**`; tag moved into Notes | **partial** — see R7j-F09 |
| R7i-F10 | Clause (c) canonical decimal, `v01` FAIL, `v0` dead at L73, L293, L602 | **partial** — see R7j-F06 |
| R7i-F11 | L437 Assumptions exclusion-half negative: `#b02` resolves to second **conforming** entry | landed |

R7h / R7g / R7f / R7e / R7d / R7c / R7b / R7 / R6b–R6n encodings spot-checked and retained (staging/snapshot/fixed-point L457–L459, exhaustion `01–99` + `-00`-absent L217/L293/L457/L458/L607, ordinal 1-based L73/L293/L427/L428, lineage equality L282/L427/L428/L458, KEEP REJECT two-file / no third canonical doc at L40–L54, L457, L593, L602). Spec-floor not tightened.

## Verdict

**NOT CLEAN** — 9 residual findings: **0 HIGH / 4 MED / 3 LOW / 2 nit**. New IDs `R7j-F01`–`R7j-F09`. No ledger ID re-filed.

---

## R7j-F01 — MED — SPEC `id-tombstones` entry grammar is "exact two-digit **catalog** ID", which rejects the `ASM-nn` entries R7i-F02 requires it to hold

**Where:** L142 (frontmatter key table), L217 (ID scheme), L426 (`review-spec` QC-13 tombstone parse).

**Evidence.** R7i-F02 landed the join in three places, e.g. L217 / L426:

> `ASM-nn` remains optional to *emit*, but when present binds QC-13: exact `ASM-[0-9]{2}`, file-unique (duplicate `ASM-01` FAIL `SPEC-F75`), and **joins SPEC `id-tombstones` under the same never-reissue rule** — compiler does **not** mint `ASM-nn`

But the tombstone-list entry grammar was not widened with it:

- L217: "Persist retired/tombstoned full IDs in SPEC YAML `id-tombstones` (**exact two-digit catalog IDs**; `[]` if none)."
- L426 QC-13: "parse YAML `id-tombstones`; … **each entry exact two-digit catalog ID**."
- L142 key table: "YAML list of retired full IDs (`AC-03`, `EX-02`, …) … this key does not admit `REQ-nn` / `NFR-nn`."

`ASM-nn` is not a catalog pack-local ID: the L217 enumeration of core IDs is `US-nn`, `FLOW-nn`, `AC-nn`, `OQ-nn`, `OOS-nn`, `DEC-nn` and the pack-local list is `EX/ERR/EP/CMD/DATA/SIG/SLO/CTRL/QA/SCR/STG` — `ASM-nn` appears in neither, and the L189 pack-table pack-local ID list likewise omits it.

**Defect.** A conforming implementation of QC-13's tombstone parser must FAIL (or reject as out-of-namespace) an `id-tombstones: [ASM-03]` entry, so the only mechanism that makes clause (a)'s "not tombstoned" test decidable for `ASM-nn` is un-writable. Two normative rules in the same paragraph contradict.

**Fix direction.** State the tombstone entry grammar as "exact two-digit catalog **or core** ID, including `ASM-nn`" at L142 / L217 / L426, and add `ASM-nn` to the L217 core-ID enumeration (still: never minted by the compiler). Do not admit `REQ-nn` / `NFR-nn` (R5h/R5i split unchanged).

---

## R7j-F02 — MED — No producer ever appends `ASM-nn` to `id-tombstones`, so R7i-F02's never-reissue rule is unenforceable

**Where:** L217 (allocator/tombstone obligations), L457 (Step 7), L593 / L602 (Wave 6 augment obligations).

**Evidence.** The only tombstone-write obligations in the freeze are minting-side:

- L217: "Compiler Step 7 always writes the key on new compiles; never drops a tombstone entry; **append when an ID-bearing entry is removed**. Sequential next-free … skips tombstones."
- L457 Step 7: "**Tombstone list (R5h-F01):** always write YAML `id-tombstones` (`[]` if none); when an ID-bearing entry is removed, append that full ID … Sequential next-free for `AC-nn` / `EX-nn` / **every catalog prefix** skips tombstones."
- L593 Wave 6: "steps 2, 3, and 4b also persist SPEC `id-tombstones` and **skip retired catalog IDs when minting**."

Every one of these is scoped to *catalog* prefixes and to the *allocator* (mint/skip). R7i-F02 simultaneously pins "compiler does **not** mint `ASM-nn`" (L73, L175, L217, L426, L457). So:

1. `ASM-nn` is operator-authored and never minted ⇒ the "skip tombstones when minting" half is a no-op for `ASM-nn`.
2. Removal of an operator-authored `ASM-nn` Assumptions entry on augment is not covered by any stated append obligation, because L457's clause is anchored to the catalog/core IDs the compiler owns.

**Defect.** `ASM-nn` can never legitimately enter `id-tombstones`, so clause (a)'s not-tombstoned precondition (L73, L293, L427, L428) is vacuously true forever and the "same never-reissue rule" is decorative. This also makes the R7i-F02 duplicate/never-reissue contract untestable beyond the duplicate-`ASM-01` fixture already at L437.

**Fix direction.** Give the obligation an owner: Step 7 (L457) MUST append a removed live `ASM-nn` to SPEC `id-tombstones` on augment (preserve-body paths 2/3/4b), exactly as it does for catalog IDs — while keeping "never mint". Mirror in L593 Wave 6 and add one behavioral fixture (retire `ASM-02`; reissuing `ASM-02` FAIL `SPEC-F75`).

---

## R7j-F03 — MED — Step 7 records no version-cell delta, so Step 8's `v<integer>` re-anchor and R7i-F01 `change-row-identity` have no producer

**Where:** L457 (Step 7 delta recording), L458 (Step 8 serialize rewrite).

**Evidence.** R7h-F02 split the re-anchor into producer (Step 7 records) and consumer (Step 8 rewrites). Step 7 at L457 enumerates exactly two recorded deltas:

> **Ordinal re-anchor (R7f-F04/R7g-F03/R7h-F01/R7h-F02):** after any mutation of a section cited by a live `SCAN:…#bNN`, **Step 7 records the SPEC-side bullet-text delta** (`decision-row-identity`-style); Step 7 does **not** rewrite REQUIREMENTS Source … **Prefix migration (R7h-F06/R7i-F02):** when a cited unprefixed Assumptions entry gains `ASM-nn` …, **record the clause-(a) rewrite delta the same way**.

Step 8 at L458 consumes **three**:

> **Ordinal / version-cell / prefix rewrite (R7h-F02/R7h-F03/R7h-F06):** Step 8 serialize applies **the Step 7 delta** to staged Source cells (`bNN` re-anchor, **`v<integer>` re-anchor**, Assumptions `bNN`→`ASM-nn`) or fail-before-replace

`change-row-identity` is absent from both L457 and L458 (it exists only at L73, L131, L293, L427, L428, L476, L602 — grammar, reviewer, verify-list and fixture surfaces). Step 7's Change History write clause at L457 covers table shape and summary provenance only; it never says "record the prior cited row's `change-row-identity` and the surviving canonical row's integer."

**Defect.** The Step 8 `v<integer>` re-anchor is defined as "apply the Step 7 delta", but no Step 7 obligation produces a version-cell delta and no compiler-side step computes `change-row-identity`. A compliant implementation therefore has nothing to apply and must fall through to fail-before-replace on every malformed-prior seed with a live `SCAN:change-history#vN` — which contradicts the L602 fixture that pins a **PASS install** when identity still matches.

**Fix direction.** Add the third producer to L457: on any compile that removes/renumbers a `spec-version` row cited by a live `SCAN:…#v<integer>` (including the R7c-F05/R7f-F05 seed), Step 7 records the cited row's `change-row-identity` (summary cell under `decision-row-identity` normalization + original integer) and the surviving canonical row's integer, or fail-before-write / ASK. Then L458 can legitimately "apply the Step 7 delta".

---

## R7j-F04 — MED — The re-anchor `ASK` terminal has no legal answer space; every reachable operator answer violates another MUST

**Where:** L73 (version-cell stability + ordinal stability), L293, L427, L428, L457, L458, L602.

**Evidence.** All three re-anchor branches offer the same disjunction, e.g. L73:

> re-anchor the citation to the surviving canonical row **only** when that row carries the same `change-row-identity`; **else fail-before-write / ASK**

and for ordinals: "(b) **fail before write / ASK** when the cited bullet/entry cannot be matched — no silent repoint."

Unlike the two ASK branches that *do* define an answer space — Invariants ASK ("**record the answer as the source**", L167/L457) and kind-reconciliation ASK ("ASK the operator to **omit/reclassify/change kind**", L457) — the re-anchor ASK states no admissible answer. Enumerating the candidate answers against the rest of the freeze:

1. *Repoint to a named row/bullet* — forbidden: re-anchor is legal "**only** when that row carries the same `change-row-identity`" (L73); an operator instruction cannot satisfy an identity MUST, and doing so anyway is the pinned "silent repoint FAIL" / "Repointing `vN` → `v1` without an identity match is a silent-repoint FAIL" (L73).
2. *Drop the Source atom* — forbidden downstream: "every `NFR-nn` row has a **resolvable Source**" (L427) and an empty/unresolved Source is a Step 8 fail-before-replace precondition (L458, "malformed/unresolved Source"); if it was the row's sole atom the row also loses reverse coverage (L293 neither-branch FAIL).
3. *Keep the stale citation* — forbidden: unresolvable `SCAN:` is `REQ-F71` fail-before-install (L293, L427, L428, L458).

**Defect.** `ASK` is a dead alternative: it is offered as a co-equal terminal on a **mandatory** tree cell (malformed-prior seed is "a defined cell of that tree", L592) but no answer exists that yields an install, so the branch collapses to fail-before-write. This is the same dead-value class the ladder already fixed for `invariant-count: 0` (R7d-F11) and `b00`/`v0` (R7f-F13/R7i-F10), except here it disguises a hard stop as an operator-resolvable ASK.

**Fix direction.** Either (a) delete `/ ASK` from the three re-anchor clauses and state fail-before-write as the sole terminal, or (b) define the answer space explicitly — e.g. the operator may supply the identity-bearing target (which then *is* an identity match of record) or authorize replacing the atom with another eligible Source ID, with the answer recorded like the Invariants ASK. Do not weaken the no-silent-repoint rule or the resolvable-Source MUST.

---

## R7j-F05 — LOW — Wave 2 `rg` alternation omits `change-row-identity`

**Where:** L434.

**Evidence.** The alternation ends `…|version-cell|v<integer>|decision-row-identity|ASM-nn|per-entry|REQ-\[0-9\]\{2\}|\\| REQ-nn` — `change-row-identity` is not present, although R7i-F01 made it a normative requirement of **both** reviewer skills the `rg` targets:

- L427 `review-requirements`: "`change-row-identity` re-anchor — R7i-F01"
- L428 `review-cross-artifact`: "version-cell stability R7h-F03/R7i-F01 (`change-row-identity`; canonical `v<integer>` — R7i-F10)"

Every comparable named mechanism (`scan-section-slug`, `decision-row-identity`, `nfr-source-cell-list`, `coverage-matrix-req-cell-list`, `version-cell`) is in the alternation; this is the same residual class as R7i-F07 and R7h-F08.

**Fix direction.** Add `change-row-identity` to the L434 alternation. Keep existing tokens.

---

## R7j-F06 — LOW — The named QC-string assert list omits every clause-(c) negative and the `change-row-identity` re-anchor fixtures

**Where:** L437 (`tests/scripts/test-review-spec-req-xart-qc-strings.sh` assert list).

**Evidence.** L437 carries the clause-(c) **positive** only: "`SCAN:change-history#v1` PASS against a table whose `spec-version` cell is `1` (R7g-F04)". It has no:

- `v01` FAIL `REQ-F71` (canonical decimal, R7i-F10) — `v01` occurs only at L73, L293, L602;
- `v0` / non-positive dead-value FAIL (R7i-F10);
- `change-row-identity` re-anchor PASS or silent `vN`→`v1`-without-identity FAIL (R7i-F01) — `change-row-identity` never appears at L437.

By contrast the ordinal clause has both its dead-value and overflow negatives pinned here ("`SCAN:invariants#b00` FAIL (1-based; R7g-F06); counted-bullet index > 99 FAIL"), and R7i-F03/F05/F11 all landed their fixtures on this same list. The reviewer-surface test therefore cannot detect a clause-(c) implementation that accepts leading zeros or repoints without identity.

**Fix direction.** Add to L437: `SCAN:change-history#v01` FAIL `REQ-F71`; `SCAN:change-history#v0` FAIL (dead value, never minted); `change-row-identity`-match re-anchor PASS and identity-mismatch `vN`→`v1` repoint FAIL.

---

## R7j-F07 — LOW — Wave 3 `- contains` verify list never asserts the Assumptions prefix-migration obligation

**Where:** L475–L477 (Wave 3 `test-clarify-spec-compiler.sh` `- contains` bullets).

**Evidence.** Prefix migration is normative in four places — L73 and L175 (grammar), L428 (`review-cross-artifact`), L457 (Step 7 records the clause-(a) rewrite delta) — and Step 8 applies it at L458 ("Assumptions `bNN`→`ASM-nn`"). The Wave 3 verify list binds its two siblings but not this one:

- L475: "contains ordinal re-anchor (R7f-F04/R7g-F03/R7h-F01/R7h-F02): mutate any `bNN`-cited section ⇒ Step 7 records bullet-text delta; Step 8 serialize rewrites Source or fail-before-write…"
- L476: "contains clause (c) version-cell `v<integer>` as a legal `<line-or-id>` form at Step 8 serialize/parse…"

No bullet names the `bNN`→`ASM-nn` rewrite, so the compiler-side string contract for R7h-F06/R7i-F02 is unasserted at the surface that R7h-F08 / R7i-F08 used for exactly this purpose.

**Fix direction.** Add a `- contains` bullet: prefix migration (R7h-F06/R7i-F02) — cited unprefixed Assumptions entry gains operator-authored `ASM-nn` ⇒ Step 7 records the clause-(a) rewrite delta, Step 8 serialize rewrites the Source atom to clause (a) or fail-before-write; compiler never mints `ASM-nn`.

---

## R7j-F08 — nit — The Assumptions entry-grammar `ASM-nn` label token has no shape, so a malformed prefix silently shifts every ordinal base

**Where:** L73 and L175 (entry grammar).

**Evidence.** L175: "count only top-level `-` bullets whose first non-marker token is `[ASSUMPTION:` or an **`ASM-nn` label**; continuation, nested, and non-conforming lines do not count." The shape of "an `ASM-nn` label" is unstated at the counting site; the exact `ASM-[0-9]{2}` grammar is stated only where QC-13 binds it "**when present**" (L217, L426).

A prior body carrying `- ASM-1 Legacy assumption …` is therefore ambiguous at the counting step used by Step 7/Step 8 and by both reviewer surfaces: if it counts, every later `#bNN` shifts by one relative to an implementation that excludes it; if it does not count, it is a "non-conforming line" under R7i-F11 and is skipped. QC-13 fail-closes an ID-bearing new compile, but the ordinal base is also consumed on the INFO-legacy/augment side and by the R7h-F01 re-anchor comparison, where a divergent base is a silent repoint rather than a FAIL.

**Fix direction.** Pin the counting token to exact `ASM-[0-9]{2}` at L73/L175 and state that a malformed-width prefix (`ASM-1`, `ASM-001`) is a **non-conforming** line for entry counting (already `SPEC-F75` when live under QC-13). One-line disambiguation; no new mechanism.

---

## R7j-F09 — nit — `decision-log` Notes carry a dangling, untagged catalog-derived fragment

**Where:** L197 (pack table, `decision-log` row, Notes cell).

**Evidence.** After R7i-F09 moved the class tag into Notes, the cell reads:

> Kind-catalog optionality unchanged (R7c-F15/R7h-F10). **(optional pack for every kind).** Required if `decision-count` ≥ 1; else omit (R1-F05). …

"(optional pack for every kind)" is (a) an orphaned parenthetical sentence fragment left by the R7i-F09 edit, and (b) a **catalog-derived** claim — it asserts that all nine atomic kind rows list `decision-log` under Optional, which is true today but is exactly the second-source-of-truth hazard R7c-F16 / R7e-F09 closed by tagging every other catalog-derived Notes clause *derived from the current catalog, non-normative* (see `ux`, `examples`, `nfr`, `security`, `telemetry`, `api`, `data`, `errors`, `cli`, `mobile`, `pipeline`, `ops` at L196–L207). Adding a tenth kind that requires `decision-log` would silently falsify this cell while the catalog stays correct.

**Fix direction.** Fold the fragment into the preceding sentence and tag it, e.g. "Kind-catalog optionality unchanged (R7c-F15/R7h-F10) — *derived from the current catalog, non-normative:* today `decision-log` is optional for every atomic kind." Keep the rest of the Notes as enforcement prose (R7e-F09).

---

## Not re-filed (checked, no residual at this SHA)

- **R7i-F03 / R7i-F04 / R7i-F08** — named empty-delta sentence is explicitly non-placeholder with closed `<reason>` and bound `N` at L182, L426, L476; provenance is a Step 7 compiler obligation with reviewers reading SPEC YAML; no `change-summary` YAML key anywhere.
- **R7i-F05 / R7i-F06** — L428 XART SCAN is two-part; L427 states the closed Invariants/unprefixed-Assumptions domain with other-section (incl. `## Overview`) `bNN` FAIL `REQ-F71`.
- **R7i-F11 / R7h-F05 / R7h-F09** — conforming-entry counting and the `#b01`-naming-`ASM-01` FAIL are both at L437.
- **R7h-F07 / R7g-F09 / R7f-F03 / R7e-F04 / R6f-F01** — the single `01–99` live-or-tombstoned **and** `-00` live/tombstoned/absent predicate is uniform at L217, L282, L293, L426, L427, L448, L457, L458, L588–L593, L607; `-00`-absent is the primary fixture on both the catalog and REQUIREMENTS sides.
- **R7g-F01 / R7b-F01 / R7c-F07 / R7f-F05 / R7d-F04** — the preserved-prose record names all three producers with timestamped append-never-truncate and the R6c staging lifecycle at L313 and L457, retained-after-install, not QC-parsed, not plugin-mirrored, not a third canonical doc.
- **R7b-F17 / KEEP-REJECT** — untouched; two files, Clarify does not write SPEC, ingest stays, no third canonical kind doc, one 9-turn-per-kind rejection intact (L40–L54, L520–L536).

## Handoff

- Triage (Composer 2.5): 9 residuals, `R7j-F01`–`R7j-F09`. F01+F02 are order-dependent (both touch the `ASM-nn` tombstone contract); F03+F04 are order-dependent (both touch the version-cell re-anchor producer/terminal); F05/F06/F07 are test-surface bindings for F03/F04 and R7i-F01/F10 and should land in the same pack.
- Fix/APPLY (Grok 4.6 High) as a single pack, order-dependent findings together.
- Freeze SHA at review time: `56cdd69882857aba35cf3f34bd2bc9333d68abb12e5b066a64dfb4720dc80aed` (both twins).
- Policy F: this rung's `consecutive_clean_reviews` remains 0; this pass is **NOT CLEAN**, so no CLEAN increment is claimed and no advance is asserted.
