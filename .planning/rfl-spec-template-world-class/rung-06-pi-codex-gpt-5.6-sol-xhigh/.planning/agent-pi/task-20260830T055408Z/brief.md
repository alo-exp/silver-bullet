# Brief — Rung 06 review pass 8 (Pi Codex GPT-5.6 Sol Extra High)

**Rung:** 6 of 8 — **eighth review pass** on this Extra High model (Policy F: Extra High streak is now **1** after launcher `--record-rung-review-outcome clean` for pass 7 CLEAN; this is consecutive CLEAN attempt **2** on the **post-R6f** freeze). High’s streak of 2 is a **different** `rung-id` (`rung-05-pi-codex-gpt-5.6-sol-high`) and is complete — do **not** re-review High.
**Model:** GPT-5.6 Sol Extra High — CHARTER slug `gpt-5.6-sol-xhigh` via Pi Codex (`PI_PROVIDER=omniroute`, `PI_MODEL=gpt-5.6-sol-xhigh`). You **are** this named Extra High GPT. Never remap Extra High onto High. Never remap GPT onto Grok. Never substitute Cursor models. Claude via Pi is later rungs (07–08) and is **not** this pass.
**Host:** Pi Codex (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast. Not Cursor via Pi.
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not `--assert-rfl-advance --next-action next_rung_review`. Do not launch verify. Do not advance to Claude.

Pass 1 history is **`review.md`** (CLEAN on pre-R6b SHA `d45ccf6b…`, no `R6-F*`). Pass 2 history is **`review-rerun-2.md`** (NOT CLEAN; `R6b-F01` HIGH). Pass 3 history is **`review-rerun-3.md`** (NOT CLEAN; `R6c-F01` HIGH). Pass 4 history is **`review-rerun-4.md`** (NOT CLEAN; `R6d-F01` HIGH). Pass 5 history is **`review-rerun-5.md`** (CLEAN on post-R6d SHA `1f11eacc…`; no `R6e-F*`). Pass 6 history is **`review-rerun-6.md`** (NOT CLEAN; `R6f-F01` MED; ACCEPT-apply). Pass 7 history is **`review-rerun-7.md`** (CLEAN on post-R6f SHA `f7c632b8…`; no `R6g-F*`; `verify_1-rerun-7.md` PASS; `verify_2-rerun-7.md` PASS; launcher recorded streak **1**). Do **not** overwrite `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, `review-rerun-6.md`, or `review-rerun-7.md`. Write **`review-rerun-8.md`** only.

## Why this pass exists

Extra High pass 7 (`review-rerun-7.md`) was **CLEAN** (no `R6g-F*`) on pin **`f7c632b8…`**. `verify_1-rerun-7.md` PASS and `verify_2-rerun-7.md` PASS independently sustained that CLEAN. Launcher recorded `--record-rung-review-outcome clean` → Policy F Extra High streak **1** (required **2** consecutive CLEAN on this Extra High model on the **current** freeze before Claude). This is **pass 8** — second consecutive CLEAN attempt on the **same post-R6f pin**. **Same SHA; residual only.** Any new ACCEPT resets the streak after APPLY. Do **not** rubber-stamp pass 7.

**Independent residual re-hunt is mandatory.** Do **not** copy `review.md` or `review-rerun-2.md`–`review-rerun-7.md`. Re-read the pinned freeze from scratch. Passes 1–7 are history, not authority. Residual only: do not re-file APPLYed IDs unless a residual defect remains in **this** freeze text. If you find a residual template-contract gap, file it as `R6h-F01+`. If you find none, say **CLEAN** with evidence from **this** pass’s freeze read.

High APPLY history already in this freeze (do not unwind): R5-F01–F03, R5b-F01–F03, R5c-F01–F03, R5e-F01, R5f-F01, R5h-F01, R5i-F01, R5j-F01, R5k-F01. Earlier rungs: R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03. Extra High pass 2 APPLY: **R6b-F01**. Extra High pass 3 APPLY: **R6c-F01**. Extra High pass 4 APPLY: **R6d-F01**. Extra High pass 6 APPLY: **R6f-F01**. Extra High pass 1, pass 5, and pass 7 filed **no** new IDs.

Policy E: review the **world-class SPEC template + software-kind packs**. Not plan-hygiene unless hygiene breaks the template contract. Residual only — do not re-open APPLYed IDs unless a residual defect remains in **this** freeze text.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `f7c632b85ae324b4ee74414acc2b9db40564a7f7bce01ca29300d437e1a58892`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twins must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Do **not** mutate either twin. Do **not** patch live `templates/` or `skills/` as a substitute for freeze findings.

This SHA is **post R6f APPLY** (same pin as pass 7; pre-APPLY / pass 5–6 pin was `1f11eacc50529cb8bab062a37bc80b4b6c988d855b17833332159b32a46d53fa`; pre-R6d pin was `7a6bfc5d66e9acdbf782f15bbe724c51b586e39d1c9cac95e8c547017e6bdc91`; pre-R6c pin was `878301866ecbc51c2ee144d566fdfaa36fcb34b37d8fd88166723b32d92879f5`; pre-R6b pin was `d45ccf6b686250638ba22778618c4f31761919c5fd00ef692569049ac6526401`). Twins are byte-identical at this pin. Pass 8 reviews **this same pin only**.

CONTEXT.md frontmatter may still show an older freeze identity (`edf2c256…`). Treat CONTEXT metadata as stale; pin RFL to the freeze SHA above, not later CONTEXT metadata.

## KEEP REJECT (do not reopen as goals)

- Two files only: SPEC.md + REQUIREMENTS.md
- Clarify does **not** write SPEC.md
- Ingest stays
- Do not merge kinds into a third canonical kind doc
- REQUIREMENTS.md stays the ID index (kinds may add NFR packs as **rows**, not a third file)

## Policy E key tasks (from RUNG-PROMPT-APPROVAL.md)

Review **all three** (findings that change freeze template headings, frontmatter, IDs, GWT, and QCs — not plan-hygiene unless it breaks the template):

1. **The implementation plan** — waves, compiler, Clarify `--spec`, ingest, QCs, tests, v0.35 lock.
2. **The SPEC.md template itself as the primary product** — world-class for humans and AI: frontmatter, IDs, GWT, invariants, change history, examples, decision log, NFR/quality attributes, security, telemetry, API, UX, data, errors — what must exist vs optional.
3. **Software-kind tailoring** — `software-kind` frontmatter + section packs that compile in/out (web/UI, HTTP API, CLI, library/SDK, mobile, data/ML, infra/DevOps, plugin/extension, headless service, `multi`). Required / optional / forbidden headings per kind. How Clarify `--spec` asks only relevant turns. REQUIREMENTS.md stays the ID index; kinds may add NFR packs. No third canonical doc.

Out of scope for this reviewer: triage, APPLY, verify.

## Already APPLYed — do not re-open unless residual in THIS freeze

R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03, **R5-F01–F03**, **R5b-F01–F03**, **R5c-F01–F03**, **R5e-F01**, **R5f-F01**, **R5h-F01**, **R5i-F01**, **R5j-F01**, **R5k-F01**, **R6b-F01**, **R6c-F01**, **R6d-F01**, and **R6f-F01** are already in this freeze. Do **not** re-file those IDs unless a **residual defect remains in this freeze text**.

New finding IDs: **R6h-F01+** (Extra High pass 8). Do **not** reuse `R6g-F*` / `R6f-F*` / `R6e-F*` / `R6d-F*` / `R6c-F*` / `R6b-F*` / `R6-F*` / `R5*` / `R5m-F*` / `R5l-F*` / High rerun IDs.

### Confirm R6f APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R6f-F01 MED | **Named mechanism: ID-namespace exhaustion fail-closed.** Allocatable domain for every exact two-digit prefix the freeze already requires (`AC-nn`, `EX-nn`, every catalog prefix, `REQ-nn`, `NFR-nn`) is `00–99` inclusive (`-00` is allocatable). When next-free cannot mint an unused exact two-digit ID (all `00–99` live or tombstoned for that prefix), **FAIL closed** before any canonical pair replace — do not wrap, do not three-digit, do not reuse tombstones. Applies to **Step 7** and **Step 8**. Fixture: `EX-00`–`EX-99` all live or tombstoned → additional mint FAIL, no install; same for a full `REQ-00`–`REQ-99` (or `NFR-00`–`NFR-99`) REQUIREMENTS namespace. Do **not** weaken R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R5k exclusive NFR Source vs dispositions, R6b staged pair, R6c snapshot-restore, or R6d fixed-point. |

### Confirm R6d APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R6d-F01 HIGH | **Named mechanism: fixed-point** extending **staged pair commit (R6b-F01)** and **recoverable pair-install (snapshot-restore) (R6c-F01)**. After any successful 7a or 8a mutation of staged bytes, re-run Step 8 / 7a/8a / `review-cross-artifact` (as applicable) on the **exact** staged pair that will be installed. Install is allowed only when the last review/QC PASS was on those bytes with no further mutation. If 8a (or 7a) mutates after a PASS, that prior PASS is stale; fail-before-install until the pair is revalidated. Fixture: 8a mutates REQUIREMENTS after a pair PASS → install FAIL unless a subsequent full PASS on the new bytes. Distinct from R6c snapshot-restore. Do **not** weaken R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R5k exclusive NFR Source vs dispositions, R6b staged-until-Step-8-succeeds, R6c snapshot-restore, or R6f exhaustion fail-closed. |

### Confirm R6c APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R6c-F01 HIGH | **Named mechanism: recoverable pair-install (snapshot-restore)** extending R6b. Wave 3 Steps **7a/8a** and intervening review/QC (compiler-invoked Wave 2 `review-spec` / `review-requirements` / `review-cross-artifact`) run on **staged** SPEC/REQUIREMENTS candidates — **not** only on-disk canonical `.planning/SPEC.md` / `.planning/REQUIREMENTS.md`. Step 7a reviews and applies fixes to the staged SPEC only. Step 8a reviews/fixes staged REQUIREMENTS with the **staged SPEC path** as `source_inputs`. Snapshot prior bytes of **both** canonicals (including absence) **before mutating either**. Install from the staged pair only after Step 8 **and** 7a/8a (plus intervening QC) PASS on staged candidates. If the **second replace fails after the first**, restore prior bytes of both. Fixtures: (1) **7a/8a FAIL on staged candidate MUST NOT install**; (2) **commit-boundary** (second canonical write fails after first) leaves both canonical files at prior bytes. Applies on Wave 6 steps **1 / 1b / 2 / 3 / 4b**. Do **not** weaken R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R5k exclusive NFR Source vs dispositions, R6b staged-until-Step-8-succeeds, R6d fixed-point, or R6f exhaustion fail-closed. |

### Confirm R6b APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R6b-F01 HIGH | **Named mechanism: staged pair commit.** Pair-wide **no partial output** on true greenfield (Wave 6 step 1) and augment 2/3/4b as well as 1b. Step 7 MUST NOT durable-commit canonical `.planning/SPEC.md` (staging only) until Step 8 succeeds; both canonical files replace together only then. On Step 8 FAIL (NFR overlap, QC, tombstone, allocator, Coverage Matrix, unresolved Source, **ID-namespace exhaustion**, etc.), prior SPEC bytes unchanged (greenfield: both files unwritten). Fixture: Step 8 FAIL after a would-be Step 7 SPEC bump — at least (a) `QA-01` live NFR Source **and** `out-of-scope`/`deferred` overlap, and (b) a REQ/NFR tombstone collision — on true greenfield **and** an augment branch. Assert no lone SPEC, no version skew, prior hashes unchanged. Do **not** weaken R5h/R5i tombstones, Wave 6 1b preserve-or-fail-closed, R5k exclusive NFR Source vs dispositions, or R6f exhaustion fail-closed. |

### Confirm R5 APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5-F01 HIGH | Wave 3 Step 7 and every Wave 6 augment branch (2, 3, 4b) run kind-reconciliation before write: preserve-body cannot keep forbidden/unlisted headings (e.g. `## UX Flows` after minting `cli`); migrate or ASK; fail-before-write if unresolved so the compiler cannot emit a SPEC that must fail `SPEC-F08`. Behavioral fixtures: generic-old-spec-with-UX → `cli`, plus a kind-change case. |
| R5-F02 MED | QC-6 required set is only `feature-slug` (kebab-case) + `software-kind` (catalog enum or `multi`), plus QC-6b `software-kinds` iff `multi`. `clarify-brief` optional/allowed-empty; `derived-requirements` stays a template default key (Wave 1 string assert) but is **not** QC-6 required. Step 7 writes the QC-6 keys. |
| R5-F03 MED | REQUIREMENTS NFR table has a `Source` column joining each `NFR-nn` to pack-local `QA-nn` / `SLO-nn` / `CTRL-nn` (or `SCAN:<section>#<line-or-id>`). Functional AC join stays Functional-only (R3-F02). Step 8 + review-requirements + XART encode the join. |

### Confirm R5b APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5b-F01 HIGH | Kind-aware QC-1 + new QC-12 (`SPEC-F74`) require required-pack **bodies** and catalog pack-local IDs (`EP-nn` / `CTRL-nn` / `SLO-nn` / `EX-nn` / etc.), not headings-only. `_TBD — Clarify skipped illegally_` is an audit ISSUE marker and **does not** satisfy QC-1. Heading-only / empty stub required packs FAIL. |
| R5b-F02 MED | QC-6b: `software-kinds` must be two+ **distinct atomic** catalog kinds (not `[cli]`, not `[multi, web-ui]`, not `[cli, cli]`, not unknown members). Validate before pack union; Turn 0 / Wave 1b negatives encode the same shape. |
| R5b-F03 MED | NFR Source (R5-F03) stays. Added **reverse coverage**: dropped SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` FAIL even when remaining NFR rows have valid Source. One-to-many / many-to-one allowed. Empty `None identified` only when no eligible SPEC sources exist. |

### Confirm R5c APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5c-F01 HIGH | Named **QC-13 / `SPEC-F75`** global ID-integrity: file-unique + exact two-digit shape for `US-nn` / `AC-nn` / `OQ-nn` / `OOS-nn` and present pack-local IDs (`ASM-nn` still optional). Duplicate `AC-01` FAIL Coverage Matrix / AC→REQ before coverage. Unlabeled US/OQ/OOS FAIL. Fixtures: dup `AC-01`, malformed IDs, unlabeled US/OQ/OOS. |
| R5c-F02 MED | QC-10 / `SPEC-F72` requires Change History **table** (columns spec-version, date, summary), a current YAML `spec-version` row, unique/ordered versions, and a non-placeholder summary. Heading-only / placeholder-only / stale-latest-row FAIL. Still not QC-1. |
| R5c-F03 MED | Reverse-NFR “recorded non-requirement disposition” is now `### Source Dispositions` (`| Source | Disposition | Rationale | Owner |`) with closed enum `not-requirement` \| `deferred` \| `duplicate` \| `out-of-scope`. Free prose is not a disposition. Dropped `QA-nn` / `SLO-nn` / `CTRL-nn` without NFR Source **or** exactly one valid dispositions row FAIL. `None identified.` forbidden while any eligible source is unresolved. |

### Confirm R5e APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5e-F01 MED | Wave 2 `review-requirements` **QC-2 / `REQ-F10`** requires exact `REQ-[0-9]{2}` and `NFR-[0-9]{2}` (two digits; **not** one-or-more digits). QC-3 uniqueness unchanged (not width). Step 8 mints sequential two-digit `REQ-nn` / `NFR-nn` and preserves existing valid two-digit IDs during augment. Coverage Matrix / ROADMAP parsers consume the same exact grammar. Fixtures: positive `REQ-01` / `NFR-01`; malformed-width negatives `REQ-1`, `REQ-001`, `NFR-2`, `NFR-0003` (also `tests/scripts/test-spec-req-id-parse.sh`). Phrase “one or more digits” must be **absent**. Aligns with template `REQ-nn`/`NFR-nn` and SPEC QC-13. Exhaustion (R6f) is the terminal case when every exact two-digit slot is live or tombstoned — QC-2 still rejects three-digit **after** emit; allocator must FAIL closed **before** emit. |

### Confirm R5f APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5f-F01 MED | Catalog pack-local ID for required `examples` pack is exact two-digit `EX-nn`. Pack table, ID scheme, and QC-12/QC-13 prefix lists include `EX-nn`. Step 7 mints sequential `EX-[0-9]{2}` for present `## Examples` and preserves valid IDs. Wave 1b fixtures: `EX-01` on examples-required kinds (`library-sdk`, `http-api`, `cli`). QC fixtures: missing `EX-nn`, unlabeled Examples, malformed-width `EX-1`/`EX-001`, duplicate `EX-01`. Clarify brief `examples` may stay unnumbered; compiler mints at write time. Exhaustion fixture `EX-00`–`EX-99` full → mint FAIL (R6f) is additional, not a replacement. |

### Confirm R5h APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5h-F01 MED | **Named mechanism: tombstone list (`id-tombstones`).** YAML list of retired full IDs persists across augment versions in SPEC.md (`[]` if none; never drop). Not QC-6 required. Canonical allocator state lives in SPEC.md (not Git history, not a sidecar). Pack table, ID scheme, QC-12 / `SPEC-F74`, QC-13 / `SPEC-F75`, Wave 3 Step 7, and Wave 6 augment branches 2/3/4b honor it. QC-13 FAIL if a live ID is tombstoned (retired `AC-03` reissued). QC-12 and QC-13 FAIL on retired `EX-nn` reissued. Step 7 sequential next-free skips tombstones **and** live current-file IDs (mint after retire skips the hole → `AC-04`). Happy path: preserve-still-present. Current-file uniqueness and exact two-digit `AC-nn` / `EX-nn` schemes stay intact. Fixtures: retired `AC-03` reissued FAIL; retired `EX-02` reissued FAIL; preserve-still-present; mint after retire skips the hole. SPEC catalog `id-tombstones` / QC-12 / QC-13 / Step 7 stay **catalog/core only** — they must **not** be widened to REQ/NFR (that is R5i). Exhaustion (R6f) does **not** shrink tombstones or reuse retired slots. |

### Confirm R5i APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5i-F01 MED | **Named mechanism: tombstone list (`id-tombstones`) on REQUIREMENTS.** YAML list of retired exact two-digit `REQ-nn` / `NFR-nn` persists across augment versions in REQUIREMENTS.md (`[]` if none; never drop). Canonical **index** allocator state lives in REQUIREMENTS.md (not Git history, not a sidecar, not SPEC catalog tombstones). SPEC catalog `id-tombstones` / QC-12 / QC-13 / Step 7 stay catalog/core only (R5h-F01). Wave 2 `review-requirements` **QC-2 / QC-3 FAIL** if a live ID is tombstoned (retired `REQ-03` reissued; retired `NFR-nn` reissued). Step 8 sequential next-free skips tombstones **and** live current-file IDs (mint after retire skips the hole → `REQ-04`). Happy path: preserve-still-present. Exact two-digit `REQ-[0-9]{2}` / `NFR-[0-9]{2}` (R5e) stay intact. Fixtures: retired `REQ-03` reissued FAIL; retired `NFR-nn` reissued FAIL; preserve-still-present; mint after retire skips the hole. Do **not** reopen the two-file KEEP REJECT. Exhaustion (R6f) does **not** shrink tombstones or reuse retired slots. |

### Confirm R5j APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5j-F01 MED | **True greenfield = both** `.planning/SPEC.md` **and** `.planning/REQUIREMENTS.md` **absent** (`[]` only then). Absence of SPEC alone is **not** greenfield. Named behavior: **preserve-or-fail-closed**. Wave 6 step **1b** partial-pair (SPEC absent, REQUIREMENTS present) unions prior REQUIREMENTS `id-tombstones` or **fails before write** (no silent wipe, no partial output). Step 8 and Wave 6 REQUIREMENTS replace union prior tombstones on **every** path (2/3/4b **and** 1b) — never drop retired IDs; never initialize `[]` merely because SPEC was absent. Fixture: no SPEC + `id-tombstones: [REQ-03, NFR-02]` must not become `[]` / must not later reissue `REQ-03`; preserve those tombstones **or** fail before write with neither artifact changed. R5h SPEC `id-tombstones` / QC-12 / QC-13 / Step 7 and R5i REQUIREMENTS tombstones / QC-2 / QC-3 unchanged. Partial-pair 1b is **not** kind-reconciliation; it still unions prior REQUIREMENTS tombstones (or fail-before-write) before any REQUIREMENTS replace. |

### Confirm R5k APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5k-F01 MED | **Exclusive branches (not inclusive-or).** A given eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` is **either** a live NFR Source **or** exactly one `### Source Dispositions` row — **not both**. Live branch: ≥1 NFR Source **and zero** Source Dispositions rows. Disposition branch: zero NFR Source cells **and** exactly one valid Source Dispositions row. **Named overlap FAIL** on the NFR reverse-coverage check (not QC-3 uniqueness) in ID scheme, REQUIREMENTS NFR contract, Wave 2 `review-requirements` and `review-cross-artifact`, and Wave 3 Step 8 (fail before replacing REQUIREMENTS if overlap is unresolved — now also **fail before any canonical pair replace** per R6b). Neither FAIL stays (dropped / unresolved sources still FAIL). One-to-many and many-to-one NFR Source lists still allowed; only the disposition branch is exclusive per source. Closed enum + rationale/owner + free-prose FAIL stay (R5c-F03). **Negative fixture:** `QA-01` as live NFR Source **and** `out-of-scope` (or `deferred`) FAIL. Positive fixtures for one source feeding multiple NFR rows and multiple sources feeding one NFR row stay. Do **not** reopen R5-F03 Source column or R5b reverse coverage unless a residual hole remains **after** exclusivity is stated. |

Also still true from earlier APPLY: kind-aware QC-7 / `SPEC-F61` is catalog-derived `ux` forbidden (incl. `multi` / optional-omitted `plugin-extension`); XART-F02 Step 4 Functional-only (`NFR-nn` exempt); Wave 3 Step 1 kind-aware domain mapping; Wave 2 `rg` includes QC-9/10 and SPEC-F71/F72/REQ-F70; present forbidden heading emits `SPEC-F08`; Wave 4 names brief fields for kind-gated packs plus `decisions`; blast-radius Clarify row is a real `nfr` turn.

## Independent re-hunt (do not skip because pass 7 was CLEAN on this SHA)

Re-scan the pinned **post-R6f** freeze for **new** residual gaps that Extra High pass 7 could have missed, **and** for any **residual** hole in APPLYed contracts. Hunt these classes even if you expect none; file only if evidence is in **this** freeze text:

1. **ID-namespace exhaustion residual (R6f-F01 APPLY) — primary hunt.** Confirm the named **ID-namespace exhaustion fail-closed**: allocatable domain `00–99` inclusive (`-00` allocatable) for every exact two-digit prefix already required (`AC-nn`, `EX-nn`, every catalog prefix, `REQ-nn`, `NFR-nn`); when next-free cannot mint an unused exact two-digit ID (all `00–99` live **or** tombstoned for that prefix), **FAIL closed** before any canonical pair replace; do not wrap, do not three-digit, do not reuse tombstones. Confirm Step **7** and Step **8** both carry the rule. Confirm fixtures: `EX-00`–`EX-99` full → additional mint FAIL, no install; same for a full `REQ-00`–`REQ-99` (or `NFR-00`–`NFR-99`) REQUIREMENTS namespace. Hunt leaks: exhaustion named only in ID scheme but omitted from Step 7 or Step 8; fixture only for `EX` not REQUIREMENTS (or vice versa); `-00` still undefined or excluded without FAIL-closed coverage of the remaining 99 slots; wrap / three-digit / tombstone-reuse still authorized on some Wave 6 path (1 / 1b / 2 / 3 / 4b); QC-2/QC-13 treated as the *only* terminal case (rejects after emit) without allocator FAIL-before-emit; exhaustion FAIL that still installs a partial pair; operator-directed migration/split guessed at the boundary; tombstone lists shrunk to free slots. File a **new** `R6h-F*` only if a defect remains **after** the APPLY text above is present. Do **not** re-file R6f-F01.
2. **Fixed-point residual (R6d-F01 APPLY).** Confirm the named **fixed-point**: after a successful 7a/8a mutation, Step 8 / 7a/8a / `review-cross-artifact` must re-PASS on the **exact staged bytes** before install; mutate-after-PASS is stale until revalidated. Hunt leaks: 8a (or 7a) still allowed to mutate after a pair PASS with install proceeding on stale PASS evidence; “re-run reviews” that omit `review-cross-artifact` or Step 8 allocator/tombstone/lineage/coverage/Source/disposition/version/**exhaustion** checks; install bound to a prior hash while staged bytes drifted; fixture missing for 8a mutating REQUIREMENTS after a pair PASS (install FAIL unless a subsequent full PASS on the new bytes); Cycle-restart missing when any gate changes either candidate; Wave 6 1/1b/2/3/4b still installing on a PASS that predates the last staged mutation. File a **new** `R6h-F*` only if a defect remains **after** the APPLY text above is present. Do **not** re-file R6d-F01.
3. **Recoverable pair-install residual (R6c-F01 APPLY).** Confirm 7a/8a and intervening QC still consume **staged** candidates (`source_inputs` = staged SPEC), not only canonical paths; 7a/8a FAIL MUST NOT install; snapshot both canonicals (including absence) before mutating either; second-replace failure restores prior bytes of both. Hunt leaks: “7a/8a unchanged” still pointing at canonical paths; 7a reviewing live `.planning/SPEC.md` on greenfield (missing path) or mid-path durable-commit; 8a `source_inputs` still the canonical SPEC path; intervening Wave 2 QC still reading disk after mint; snapshot missing absence-as-prior on true greenfield; restore that only reverts one file; commit-boundary fixture missing or still only pre-install Step 8 FAIL (R6b); Wave 6 1/1b/2/3/4b still saying “write as today” without snapshot-restore. File a **new** `R6h-F*` only if a defect remains **after** R6c, R6d, **and** R6f APPLY text is present. Do **not** re-file R6c-F01.
4. **Staged pair commit residual (R6b-F01 APPLY).** Confirm Step 7 still MUST NOT durable-commit canonical SPEC (staging only) until Step 8 succeeds; both files replace together; Step 8 FAIL (including **exhaustion**) leaves prior SPEC unchanged (greenfield: both unwritten). Hunt leaks: Wave 6 step 1 still durable-committing SPEC first; inverse pair (REQUIREMENTS absent / SPEC present) silent wipe or lone-file commit; fixture missing on greenfield **or** augment 2/3/4b; 1b FAIL no longer preserve-or-fail-closed; “fail before replacing REQUIREMENTS” still the only guard on some path. File a **new** `R6h-F*` only if a defect remains **after** R6b, R6c, R6d, **and** R6f APPLY text is present. Do **not** re-file R6b-F01.
5. NFR exclusive-overlap residual (R5k-F01 APPLY): exclusive branches still stated as **either** live NFR Source **or** exactly one Source Dispositions row — **not both**; named overlap FAIL on review-requirements, review-cross-artifact, and Step 8 (now fail-before **canonical pair replace** if unresolved); QA-01 live Source **and** `out-of-scope`/`deferred` negative fixture still present; inclusive-or leak that would still accept overlap. File a **new** `R6h-F*` only if a defect remains **after** exclusivity, staged pair commit, recoverable pair-install, fixed-point, **and** exhaustion fail-closed are present.
6. Greenfield / partial-pair residual (R5j-F01): true greenfield still predicates on **both** files absent (not SPEC-only); Wave 6 step **1b** SPEC-absent / REQUIREMENTS-present is named **preserve-or-fail-closed** (union prior REQUIREMENTS `id-tombstones` **or** fail before write — no silent wipe, no `[]` init, no partial output); Step 8 unions prior tombstones on **every** replace including 1b **and** 2/3/4b; fixture no SPEC + `id-tombstones: [REQ-03, NFR-02]` must not become `[]` / must not later mint `REQ-03`; inverse pair if the freeze still treats it as silent greenfield or silent wipe. Do not re-file R5j unless **this** freeze text still has a hole.
7. REQUIREMENTS tombstone residual (R5i-F01): REQUIREMENTS YAML `id-tombstones` shape vs live `REQ-nn`/`NFR-nn`; QC-2/QC-3 reissue FAIL vs Step 8 next-free skipping holes; Wave 6 augment persistence/honor vs true-greenfield `[]`; never-drop vs silently shrinking list; canonical allocator in REQUIREMENTS vs SPEC catalog tombstones leaking REQ/NFR or vice versa. Exhaustion must **not** free slots by dropping tombstones. Do not re-file R5i unless **this** freeze text still has a hole.
8. SPEC tombstone residual (R5h-F01): catalog/core prefixes still covered; QC-13/QC-12 reissue FAIL vs Step 7 next-free; Wave 6 branches 2/3/4b persist/honor; prefixes beyond `AC`/`EX` (US/OQ/OOS/CTRL/SLO/etc.). Exhaustion must **not** free slots by dropping tombstones. Do not re-file R5h unless **this** freeze text still has a hole.
9. Template contract: required vs optional headings; ID uniqueness/shape beyond QC-13 **and** QC-2 two-digit REQ/NFR **and** the `EX-nn` grammar (parser holes, Coverage Matrix / ROADMAP vs compiler mint, `P1–P3` vs ID width, other required packs still missing prefixes); GWT; invariants; Change History beyond QC-10; decision log; NFR reverse+forward **after exclusivity**; Source Dispositions vs `SCAN:` sources; security/telemetry/API/UX/data/errors packs; whether other finite exact-width namespaces lack exhaustion fail-closed after R6f.
10. Kind catalog + Clarify skip-turns: required-pack bodies (QC-12) including `EX-nn` vs **optional**-present Examples; `multi` union completeness; QC-6b vs catalog membership; `_TBD` vs QC-1; Step 7 mint/preserve vs unlabeled/malformed/duplicate `EX-*`. How Clarify `--spec` asks only relevant turns per kind.
11. Compiler/QC/tests/v0.35 lock: Wave 3 Step 7 vs Wave 6 branches 1 / **1b** / 2 / 3 / 4b fail-before-write holes **after** staged pair commit, recoverable pair-install, fixed-point, **and** exhaustion fail-closed; named fault codes vs string-only asserts; Coverage Matrix vs unlabeled/dup AC; QC-2 exact-width vs any remaining “one or more digits” baseline leak; QC-12/QC-13 prefix lists vs pack table (any other required pack still without an ID); Step 8 vs review-requirements vs Coverage Matrix vs ROADMAP on REQ/NFR tombstones; overlap FAIL fixture still named in Wave 2 QC strings; 7a/8a FAIL + commit-boundary + mutate-after-PASS + **full-namespace mint FAIL** fixtures still named.
12. Plan-hygiene last — only if it breaks the template contract.

Findings that improve the template contract are in scope even when the wave text is tidy. Do **not** invent findings to avoid a CLEAN. Do **not** invent findings to force Claude either.

## Tools (mandatory)

1. `graphify query "agent-pi invoke gpt-5.6-sol-xhigh ID namespace exhaustion fail-closed R6f-F01 residual pass 8"` (or a scoped template/kind-pack query) before exploring. Retrieve prior notes via Graphify, not raw agentmemory dumps.
2. Save session notes via agentmemory MCP `memory_save` when available.
3. After any code/doc writes in this work dir only: `graphify update .`

## Finding format

For each: ID (`R6h-F01+`), severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested freeze-text fix. Then: **CLEAN** or **NOT CLEAN**.

If CLEAN with no new gaps, say so explicitly with freeze SHA + twin check + residual-hunt notes. Do not claim ladder PASS or recommend Claude. Do not `--record-rung-review-outcome` (parent records after verify). Do not `--assert-rfl-advance`.

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-06-pi-codex-gpt-5.6-sol-xhigh/review-rerun-8.md` only.
- Do **not** overwrite `review.md`. Do **not** overwrite `review-rerun-2.md`. Do **not** overwrite `review-rerun-3.md`. Do **not** overwrite `review-rerun-4.md`. Do **not** overwrite `review-rerun-5.md`. Do **not** overwrite `review-rerun-6.md`. Do **not** overwrite `review-rerun-7.md`. Do **not** overwrite High `rung-05-*` files.
- Do **not** write live `templates/` or `skills/` patches. Freeze-text suggestions belong in `review-rerun-8.md`.
- Do not create `review-rerun-1.md`. Do not launch verify. Do not APPLY. Do not `--record-rung-review-outcome`. Do not `--assert-rfl-advance --next-action next_rung_review`.
- Do not use Fast. Do not remap this Extra High GPT review onto High or onto Grok.

## FORBIDDEN

- Do NOT triage ACCEPT/REJECT, file issues, or apply fixes.
- Do NOT `git checkout` / `git switch` / change branches / commit.
- Do NOT mutate freeze twins.
- Do NOT claim ladder PASS or recommend advancing — parent verifies with Grok 4.5 High native Cursor (`verify_1` / `verify_2`) later.
- Do NOT launch subagents for Cursor-family models through Pi.
- Do NOT advance to Claude.
- EXIT 124 / timeout: stop. Do not `--continue`.