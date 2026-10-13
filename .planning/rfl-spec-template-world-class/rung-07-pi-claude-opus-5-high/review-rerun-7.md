# Rung 07 — Pi Claude Opus 5 High — review pass 7 (residual re-hunt)

**Rung:** rung-07-pi-claude-opus-5-high (pass 7 of this rung; Policy F streak 0 after pass-6 `accept-apply`)
**Reviewer:** Claude Opus 5 High via Pi OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`) — review-only (Policy C)
**Verify/Triage:** Composer 2.5 · **Fix/APPLY:** Grok 4.6 High
**Freeze:** `.planning/spec_template_world_class.plan.md`
**Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`

## SHA verification (both twins, hashed this pass)

```
e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1  .planning/spec_template_world_class.plan.md
e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
```

Both equal the pinned `e4817780…`. 723 lines. Freeze not mutated by this pass. Graphify queried first (`graphify query` CLI, MCP skill-version warning only); freeze re-read from scratch (L1–L723) — pass 1–6 reviews **not** consulted as authority.

## Verdict

**NOT CLEAN** — 10 residual findings at this SHA: **1 HIGH / 4 MED / 3 LOW / 2 nit**. New IDs `R7g-F01`–`R7g-F10`. No ledger row re-reported; REJECT `R7b-F17` and KEEP REJECT untouched.

## R7f APPLY confirmation (spot-checked; not re-filed)

| ID | Landed | Evidence |
|----|--------|----------|
| R7f-F01 | yes (see R7g-F10 residual) | L182 delta list carries `spec-version` bump **or seed**, Invariants add/remove/migrate, `DEC-nn` appended; named sentence `version seeded to 1 (prior spec-version malformed); no structural changes` |
| R7f-F02 | yes | L427 `review-requirements` and L428 `review-cross-artifact` both carry the two-clause `<line-or-id>` rule + bare-line `REQ-F71` |
| R7f-F03 | yes (see R7g-F09 residual) | L217/L457/L458/L583/L588 predicate `01–99` live-or-tombstoned **and** (`-00` live, tombstoned, or absent — never mint it) |
| R7f-F04 | yes (see R7g-F03 residual) | L73 / L293 re-anchor-or-fail; L599 `b03`→`b04` fixture |
| R7f-F05 | yes (see R7g-F01 residual) | L131 / L584 / L587 / L599 prior history rows migrate-or-ASK, `0.35` row in migration record |
| R7f-F06 | yes (see R7g-F08 residual) | L142 identity = `decision` cell only; ID-collision divergent text ⇒ fail before write |
| R7f-F07 | yes | L314 Clarify blast-radius `change-summary` capture; L515 Wave 4 brief-field assert list |
| R7f-F08 | yes | L434 `rg` alternation contains `change-summary` and `section-anchored ordinal` |
| R7f-F09 | yes | L437 `SCAN:invariants#b03` PASS ≥3 bullets / ordinal-on-ID-bearing FAIL; L497 QC-10 provenance `- contains` |
| R7f-F10 | yes (see R7g-F04, R7g-F05, R7g-F07 residuals) | L73 Overview / Change History / Assumptions enumeration clause |
| R7f-F11 | yes | L198 renders `*(derived from the current catalog, non-normative — R7d-F10: kind-required for infra-devops, data-ml, headless-service)*` |
| R7f-F12 | yes at L143 only (see R7g-F02 residual) | L143 "resulting live … after the compile … not brief-only or preserved-only source count" |
| R7f-F13 | yes at L73/L293 only (see R7g-F06 residual) | L73 "`b00` parses but always FAILs `REQ-F71` … index > 99 FAILs … no wrap" |
| R7f-F14 | yes | L361 `world-class-min` asserts `invariant-count` = counted bullets ≥ 1; `decision-count` = live `DEC-nn`; `cli` ⇒ `decision-count: 0`, heading absent |

R7e / R7d / R7c / R7b / R7 / R6b–R6n encodings re-checked present at their cited surfaces; not re-filed.

---

## Findings

### R7g-F01 — HIGH — Migration record is declared "kind-reconciliation migrate branch only" while three landed obligations write to it

**Cite:** L313 (blast radius), L457 (Step 7 "Kind-reconciliation migration record"), L172 (R7d-F04 Invariants supersede), L131 / L584 / L587 (R7f-F05 prior Change History rows), L599 (fixtures).

The retained record `.planning/.spec-kind-migration.md` has exactly one normative definition of *who writes it and what it contains*:

- L313: "`.planning/.spec-kind-migration.md` (… **kind-reconciliation migrate branch only** …)"
- L457: "**Kind-reconciliation migration record (R7-F08, R7b-F01, R7c-F07):** written only on the migrate branch; **markdown dump of forbidden/unlisted heading prose.**"

Three other landed rules now write into that same file from branches that are **not** kind-reconciliation and whose payloads are **not** forbidden/unlisted heading prose:

1. **R7d-F04 / R7e-F06** (L172, L457, L599): Invariants superseding write — "prior live bullets not carried forward are appended to the retained non-canonical `.planning/.spec-kind-migration.md`". Payload = MUST/MUST NOT bullets from a **core-required** section, on a path where no pack heading was reclassified at all.
2. **R7f-F05** (L131, L584, L587, L599): malformed-prior `spec-version` — "Prior human-authored Change History rows MUST append to retained `.planning/.spec-kind-migration.md`". Payload = table rows from a **core-required** section (QC-10), again with no kind change.
3. L599 pins both as PASS-install fixtures ("install PASSes only if B2 is appended…", "install PASSes only if that `0.35` row is preserved in the retained migration record").

So the freeze simultaneously asserts (a) the record is written **only** on the migrate branch and contains **only** forbidden/unlisted heading prose, and (b) two non-migrate branches must write non-heading-prose payloads into it as an install precondition. An implementer following L313/L457 literally will not emit the record on paths 2/3/4b without a kind change, and the two pinned PASS fixtures become unsatisfiable — which silently re-opens the exact no-silent-delete guarantees R7d-F04 and R7f-F05 were APPLYed to close.

Secondary gap in the same defect: the record's **lifecycle** (staging sibling → snapshot-restore deletes leftover staging copies → retain after install → subsequent migrate appends a timestamped section) is stated only for the kind-reconciliation producer. The Invariants and Change-History producers inherit no stated staging/restore/append semantics, so on a Step 8 FAIL after an Invariants supersede it is undefined whether the appended bullets are rolled back with the staged pair (R6c) or leaked to the installed record.

**Ask:** generalize the record to a named multi-producer artifact — e.g. "**preserved-prose record**: written by (1) kind-reconciliation migrate, (2) Invariants supersede (R7d-F04), (3) malformed-`spec-version` prior Change History rows (R7f-F05); each producer appends a timestamped section labelled with its producer and payload kind; all producers share the R6c staging/snapshot-restore lifecycle and the R7c-F07 append-never-truncate rule". Fix L313 and L457 so "migrate branch only" / "markdown dump of forbidden/unlisted heading prose" no longer contradict the three landed producers. KEEP REJECT: still not a third canonical doc; still not parsed by any QC; still not plugin-mirrored.

---

### R7g-F02 — MED — Step 7's `invariant-count` write is still the pre-R7f-F12 "sourced bullet count"

**Cite:** L143 vs L457 (and L474 verify bullet).

R7f-F12 redefined the key at L143: "Step 7 always writes it as the **resulting live `### Invariants` MUST/MUST NOT bullet count after the compile** … Count is post-supersede live count, **not brief-only or preserved-only source count**."

The compiler's actual write instruction was not updated. L457 still says:

> "write YAML `invariant-count` **from the sourced bullet count** (R7b-F04)"

"Sourced bullet count" is precisely the brief-only / preserved-only source count R7f-F12 rejects. On the R7e-F06 supersede fixture (prior B1, B2; brief carries only B1) the two rules disagree: L457 yields `invariant-count: 1` from the brief source, L143 yields the resulting live count — and L599 pins "`invariant-count` equals the resulting live bullet count (not the prior count)". A compiler built from Step 7 fails QC-11 count-equality (`SPEC-F73`) on a fixture the freeze pins as PASS.

The Wave 3 verify list is equally stale: L474 asserts only "Step 7 always writes YAML `invariant-count` / `decision-count`" with the resulting-live semantics named for `decision-count` (union emission, "YAML count = live count, not `max`") but **not** for `invariant-count`. So there is no test surface that would catch the divergence either.

**Ask:** replace L457's "from the sourced bullet count" with the R7f-F12 resulting-live post-compile count (branch (1) supersede result, else (2) preserved live, else (3) ASK / fail-before-write), and extend the L474 `- contains` bullet to name "`invariant-count` = resulting live MUST/MUST NOT count after supersede, not the source count".

---

### R7g-F03 — MED — R7f-F04 ordinal re-anchor has no compiler-side binding (Step 7, Step 8 precondition list, Wave 3 verify)

**Cite:** L73, L293, L599; absent at L457, L458, L473–L498.

R7f-F04 is a **compile-time** obligation: "on any compile that mutates an ID-less section cited by a live `SCAN:…#bNN`, either (a) re-anchor the citation deterministically … **or** (b) fail before write / ASK". It landed at three places only: the L73 inherited pin, the L293 REQUIREMENTS NFR-Source contract, and the L599 Wave 6 fixture. `R7f-F04` appears zero times in the Wave 3 compiler section.

Consequences:
- **Step 7** (L457) mutates `### Invariants` (supersede / preserve) and never mentions checking live `SCAN:…#bNN` citations against the new bullet order.
- **Step 8's** fail-before-replace precondition enumeration (L458) lists NFR overlap, tombstone collision, allocator, matrix edge-set mismatch, unknown AC, QC-7 mismatch, non-measurable Metric, unresolvable `SCAN:` (`REQ-F71`), lineage inequality, empty AC set, OOS/OQ inequality, empty/unsourced Invariants — but **not** "live ordinal citation that cannot be re-anchored". A silently repointed `bNN` is still lexically resolvable, so the existing `REQ-F71` precondition does not catch it.
- The Wave 3 `- contains` verify list (L473–L498) has no re-anchor bullet, so `test-clarify-spec-compiler.sh` cannot detect the omission.

This is the same bind-to-Step-8 class the ladder already closed for R6i→R6j, R6k, R6l, R6n: a parser/consistency rule stated at the contract layer but never carried into the write path silently degrades to advisory.

**Ask:** add ordinal re-anchor to Step 7 (after any mutation of an ID-less cited section, re-anchor by `decision-row-identity`-style bullet-text match or fail-before-write / ASK), add "unre-anchorable live `SCAN:…#bNN` ordinal" to the Step 8 fail-before-replace precondition list, and add a Wave 3 `- contains` bullet naming the L599 `b03`→`b04`-or-fail fixture.

---

### R7g-F04 — MED — `## Change History` is declared citable "by the `spec-version` cell" but no `<line-or-id>` lexeme admits that

**Cite:** L73 (R7f-F10 enumeration) vs L73 / L293 (two-clause `<line-or-id>` grammar).

R7f-F10 resolved Change-History addressability as: "`## Change History` is a markdown **table**, not ordinal-addressable — **cite the `spec-version` cell, not `bNN`**."

But `<line-or-id>` is a **closed two-clause** grammar: "(a) a live ID inside that section … **or** (b) a section-anchored ordinal `b[0-9]{2}`", with "ID-bearing sections MUST use (a); ID-less sections MUST use (b)" and "bare line numbers still FAIL `REQ-F71`".

A `spec-version` cell value is the decimal string of a positive integer (L131: "table cell is that integer's decimal string"). It is:
- not a live ID (no `XXX-nn` catalog/core prefix, not in QC-13's declared-ID set), so clause (a) rejects it;
- not `b[0-9]{2}`, so clause (b) rejects it;
- lexically identical to a bare line number, so `SCAN:change-history#1` hits the explicit "bare line" fail-closed and emits `REQ-F71` (the L437 negative fixture `SCAN:quality-attributes#12` is the same shape).

Net: the one addressing form R7f-F10 prescribes for Change History is the one form the grammar guarantees will FAIL. Change History is therefore unreachable for `SCAN:` while the freeze says how to reach it — a fail-closed trap for any compiler-discovered NF concern anchored to a version row.

**Ask:** either (i) add a third named clause `(c) version-cell anchor` with an unambiguous lexeme (e.g. `v<integer>`, so `SCAN:change-history#v1`, disjoint from `b[0-9]{2}` and from bare digits, resolving iff exactly one row's `spec-version` cell equals that integer), and mirror it at L73 / L293 / L427 / L428 plus one L437 PASS fixture; **or** (ii) declare `## Change History` not SCAN-addressable at all and delete the "cite the `spec-version` cell" clause. Do not weaken the bare-line `REQ-F71` rule either way.

---

### R7g-F05 — MED — `## Overview` prose is promised as a SCAN target but the Overview ordinal grammar counts only `-` bullets

**Cite:** L198 (`nfr` pack Notes) vs L73 (ordinal enumeration) and L172 (Overview contract).

L198 (R7e-F02) states the fallback for omitted `nfr`: "compiler-discovered NF concerns in `### Invariants` / **Overview prose** use `SCAN:invariants#bNN` (**or the matching ID-less heading slug + ordinal**) — not a fabricated pack ID."

R7f-F10 then defined the Overview ordinal as: "`## Overview` uses top-level `-` bullets **excluding nested subsection bullets** — nested `### Invariants` counted only under that heading."

But the Overview contract at L172 is **prose, not bullets**: "`## Overview` — 2–4 sentences: who, problem, outcome. Include `### Invariants`". A conforming Overview has **zero** top-level `-` bullets (its only list content is the nested `### Invariants`, explicitly excluded). So for every conforming SPEC the Overview counted-bullet set is empty, every `SCAN:overview#bNN` is unresolvable, and clause (b) is mandatory for ID-less sections — meaning the L198-promised "Overview prose" citation path is fail-closed `REQ-F71` by construction.

This matters where it was introduced: kinds that omit `nfr` (e.g. `cli`, `plugin-extension`) must still cite compiler-discovered NF concerns through `SCAN:`, and the freeze offers Overview prose as one of exactly two ID-less anchors. One of the two is unreachable.

**Ask:** pick one — (i) drop "Overview prose" from L198 and pin `### Invariants` as the sole ID-less NF anchor; or (ii) define an Overview prose ordinal that actually exists (e.g. counted top-level **sentences** or top-level block elements excluding nested subsections) and add a matching L437 PASS fixture. Do not mint `INV-nn` and do not weaken the bare-line `REQ-F71` rule.

---

### R7g-F06 — LOW — R7f-F13 1-based-ordinal rule did not reach the two reviewer surfaces R7f-F02 retargeted, nor the QC-string list

**Cite:** L73 and L293 carry R7f-F13; L427, L428, L437 do not.

R7f-F13 pinned: "Ordinals are **1-based**: `b00` parses but always FAILs `REQ-F71` (dead value, never minted); counted-bullet index > 99 FAILs `REQ-F71` (no `b100`, no wrap)." That text exists only at L73 (inherited pin) and L293 (NFR Source grammar).

R7f-F02's whole purpose was that the reviewer surfaces mirror the Wave 1 parser. Both retargeted surfaces state only the two-clause rule and the bare-line FAIL:

- L427 `review-requirements`: "`<line-or-id>` is (a) a live ID **or** (b) a **section-anchored ordinal** `b[0-9]{2}` … ID-bearing sections MUST use (a); ID-less sections MUST use (b); not a bare line number"
- L428 `review-cross-artifact`: same wording, no `b00` / >99 clause.

Since `b00` is lexically valid `b[0-9]{2}`, a reviewer implemented from L427/L428 accepts `SCAN:invariants#b00` while the Wave 1 parser fails it — reintroducing exactly the parser-divergence R7f-F02 closed. The L437 QC-string assert list also has no `b00` or `b100` negative fixture (its SCAN fixtures are `#b03` PASS, ordinal-on-ID-bearing FAIL, `#12` bare-line FAIL, `#x#y#z` FAIL), so nothing tests the rule anywhere.

**Ask:** add "ordinals 1-based — `b00` FAIL `REQ-F71`; index > 99 FAIL, no wrap" to L427 and L428, and add `SCAN:invariants#b00` FAIL plus an index-overflow FAIL to the L437 `REQ-F71` fixture set.

---

### R7g-F07 — LOW — Mixed `## Assumptions` (some entries `ASM-nn`, some not) has no rule under the section-level ID-bearing/ID-less MUST

**Cite:** L73 (R7f-F10 Assumptions clause + section-level MUST) vs L175 (`ASM-nn` optional).

R7f-F10: "`## Assumptions` entries with `ASM-nn` are ID-bearing clause (a), without `ASM-nn` are counted top-level bullets".

The enclosing rule is stated at **section** granularity: "**ID-bearing sections MUST use (a); ID-less sections MUST use (b).**" L175 makes the prefix per-entry optional: "Optional `ASM-nn` prefix." QC-13 (L217/L426) explicitly exempts it: "`ASM-nn` remains optional".

So a legal Assumptions section may be **mixed**, and the freeze gives no classification for it:
- Is the section "ID-bearing" (forcing clause (a), making the un-prefixed entries permanently uncitable)?
- Or "ID-less" (forcing clause (b), which contradicts R7f-F10's own per-entry split and makes `SCAN:assumptions#ASM-01` FAIL despite `ASM-01` being live)?
- If clause (b) applies to the un-prefixed entries only, is the ordinal counted over **all** Assumptions entries or only the un-prefixed ones? The two give different `bNN` for the same bullet, and there is no tie-break.

Because `<line-or-id>` resolution is fail-closed (`REQ-F71`) and `scan-section-slug` requires a unique match, either reading silently breaks the other. Everywhere else the freeze pinned an unambiguous ordinal base (Invariants = R7c-F03 counted bullets; Overview = top-level `-` excluding nested).

**Ask:** state the Assumptions rule at the granularity R7f-F10 actually intends — e.g. "Assumptions is per-entry: an entry with `ASM-nn` MUST be cited by clause (a); an entry without MUST be cited by clause (b), where the ordinal counts **all** top-level Assumptions entries in document order (prefixed and un-prefixed alike) so the base is stable when `ASM-nn` is later added" — and note that this is the one section exempt from the section-level MUST. One L437 fixture on a mixed section.

---

### R7g-F08 — LOW — `decision-row-identity` divergent-text FAIL and same-brief-twice idempotence have no test-surface binding

**Cite:** L142 only (grep: `decision-row-identity` appears at L73 and L142; "divergent" only at L142; "re-applied twice" only at L142).

R7e-F08 named the normalization and R7f-F06 narrowed identity to the `decision` cell and added the ID-collision terminal, both encoded at L142:

> "fixture: same brief re-applied twice ⇒ `decision-count` unchanged. **ID-collision (R7f-F06):** live `DEC-nn` match with non-identical normalized `decision` text ⇒ fail before write (or ASK) … **Divergent-text fixture FAIL**"

Both "fixtures" are named inside the frontmatter key table and nowhere else:
- Wave 3 `- contains` (L474) names union emission and count-mismatch FAIL but not identity normalization, idempotence, or divergent-text fail-before-write.
- L437 QC-string list names the count-mismatch FAIL (`decision-count: 2` vs 3 live) and the union-emission positive (2+3⇒5) but no identity fixture.
- Wave 6 behavioral fixtures (L599) name the DEC augment fixture and the union-emission fixture — neither exercises re-application or divergent text.
- Step 8's fail-before-replace precondition list (L458) does not include "divergent `decision` text on a matching live `DEC-nn`".

This is the same defect class R7e-F05 already closed for union emission + count-equality ("no test-surface binding"); the R7f-F06 refinement landed without repeating that binding, so an implementer can ship a `date`/`why`-inclusive identity (or silent overwrite on collision) with every named test still green.

**Ask:** add a Wave 3 `- contains` bullet for `decision-row-identity` (identity = `decision` cell only; trim / collapse / case-fold / strip emphasis+trailing punctuation; same-brief-twice ⇒ `decision-count` unchanged; divergent-text on matching `DEC-nn` ⇒ fail before write), add both fixtures to the L437 assert list, and add "divergent `decision` text on a live `DEC-nn`" to the Step 8 precondition list.

---

### R7g-F09 — nit — REQUIREMENTS exhaustion fixture still uses the pre-R7e-F04 `REQ-00`–`REQ-99` shorthand at four sites

**Cite:** L284, L458, L489, L599 vs the SPEC-side restatement at L217, L457, L489, L599.

R7e-F04 / R7d-F09 restated the SPEC-side fixture in the predicate's own terms: "fixture `EX-01`–`EX-99` live or tombstoned **plus** `EX-00` present-or-tombstoned → mint FAIL". The REQUIREMENTS-side fixture was not restated and still reads, at all four sites:

- L284: "Fixture: `REQ-00`–`REQ-99` (or `NFR-00`–`NFR-99`) all live or tombstoned"
- L458: "fixture full `REQ-00`–`REQ-99` (or `NFR-00`–`NFR-99`)"
- L489: "same for a full REQUIREMENTS `REQ-00`–`REQ-99` (or `NFR-00`–`NFR-99`) namespace"
- L599: "(2) REQUIREMENTS namespace full (`REQ-00`–`REQ-99` all live or tombstoned, or `NFR-00`–`NFR-99`)"

Two consequences, both minor but asymmetric with the SPEC side:
1. "All live or tombstoned" including `-00` requires a **live-or-tombstoned `REQ-00`**, which the allocator can never mint (next-free starts at `-01`, `-00` "never minted"). For REQUIREMENTS — a wholly compiler-generated index — a live `REQ-00` can only arrive by hand-authoring, so the fixture is harder to justify than the SPEC-side (legacy/hand-authored) case.
2. The fixture never exercises the **`-00`-absent** disjunct of the R7f-F03 predicate, which is the branch that actually matters for compiler-produced files. The SPEC side at least pins `EX-00` "present-**or**-tombstoned" explicitly.

**Ask:** restate all four REQUIREMENTS sites in the single predicate's terms — "`REQ-01`–`REQ-99` live or tombstoned **and** `REQ-00` live, tombstoned, **or absent** (never mint it)" — and pin the `-00`-absent disjunct as the primary REQUIREMENTS fixture. Do not weaken R6f fail-closed, R7d-F09, or R7e-F04.

---

### R7g-F10 — nit — R7f-F01's empty-delta trigger disagrees with its own pinned fixture (`set` vs `set minus seed`)

**Cite:** L182 vs L599.

L182 defines the trigger over the **whole** delta set: "enumerated structural deltas this compile made (packs added/removed, IDs minted, IDs tombstoned, `spec-version` bump **or seed** (R7c-F05/R7b-F12), Invariants bullets added/removed/migrated, `DEC-nn` appended) joined as one non-placeholder sentence; **if that set is empty**, emit a named deterministic no-structural-change sentence".

Because R7f-F01 also added **seed** to that set, and every Change-History-writing path bumps or seeds (paths 1, 2, 3, 4b all do — L131, L582, L584, L586, L587), the set is **never** empty. Under L182 as written the fallback branch is unreachable and every brief-less augment gets the ordinary structural-delta sentence.

L599 pins the opposite for the R7c-F05 fixture: "brief-less summary provenance uses branch (2) including seed (**empty remaining delta** ⇒ named no-structural-change sentence — R7f-F01)". "Empty **remaining** delta" is the set **minus** the seed — a different predicate. So the rule and its own pinned fixture expect different emitted summaries for the same input: L182 ⇒ `version seeded to 1`; L599 ⇒ `version seeded to 1 (prior spec-version malformed); no structural changes`. QC-10 accepts both as non-placeholder, so nothing FAILs — but the fixture's expected string is not the string the rule produces, and a string-asserting harness will flip on implementer choice.

Secondary: the named sentence's literal text hard-codes malformed-prior facts ("prior spec-version malformed"), so if the branch is ever reached from a non-malformed path it asserts something false. It is tagged "e.g.", but every other named artifact in this freeze (`scan-section-slug`, `decision-row-identity`, `nfr-source-cell-list`) is pinned exactly.

**Ask:** align the two — state the trigger once as "if the delta set **excluding the `spec-version` bump/seed entry** is empty, append the named no-structural-change clause to the version clause" — and template the sentence so the parenthetical reason is derived (`version seeded to 1 (<reason>); no structural changes`) rather than hard-coded to the malformed case. Fabricate-never and the ASK terminal stay unchanged.

---

## Scope discipline

- Review-only. No triage, no APPLY, no fixes, no freeze/twin mutation, no branch change, no commit, no verify launch, no `--record-rung-review-outcome`, no `--assert-rfl-advance`, no ladder advance.
- Only `review-rerun-7.md` written in this work dir. `review.md`, `review-rerun-2.md` … `review-rerun-6.md` untouched; no Extra High file touched.
- No ledger row re-reported. `R7b-F17` REJECT not reopened ("one 9-turn interview for every kind" KEEP REJECT left intact).
- KEEP REJECT honored throughout: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; **no third canonical kind doc** — R7g-F01 generalizes an existing non-canonical, not-parsed-by-any-QC operator record and explicitly does not promote it; R7g-F04/F05 add addressing grammar, not artifacts.
- Spec-floor not tightened (Overview + AC only). No interview turn added (R7g findings touch brief fields / compiler / reviewer surfaces only).
- All 10 findings are residual at `e4817780…`, each with a line cite and a bounded ask. ACCEPTed items are order-independent except R7g-F02 (L457) and R7g-F03 (L457/L458), which touch the same Step 7/8 block and should be applied together.
