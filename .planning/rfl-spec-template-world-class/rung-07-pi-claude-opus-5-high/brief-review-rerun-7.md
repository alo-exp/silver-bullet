# Brief — Rung 07 review pass 7 (Pi Claude Opus 5 High)

**Rung:** 7 of 8 — **seventh review pass** on Claude Opus 5 High (Policy F: this rung's streak is **0** after pass 6 pack APPLY + launcher `--record-rung-review-outcome accept-apply`). Do **not** remap this Claude High hop onto Grok, Extra High, Cursor, Fast, or GPT. Do **not** launch Claude Extra High.
**Model:** Claude Opus 5 High — CHARTER slug `claude-opus-5-high` via Pi OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`). You **are** this named Claude High. Never remap Claude onto Grok. Never remap High onto Extra High. Never substitute Cursor models. Never Cursor via Pi. Never Fast.
**Host:** Pi (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast. Not Cursor via Pi. Not GPT Extra High.
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not `--assert-rfl-advance`. Do not launch verify. Do not advance to Claude Extra High.

**Session policy (this hop):**
- **Verify + Triage = Composer 2.5**; **Fix/APPLY = Grok 4.6 High**.
- **verify_2** is skipped on already-triaged NOT CLEAN; **verify_2 is still required on CLEAN**.
- **Reviewer is this Claude High Pi hop** (`claude/claude-opus-5-high` / OmniRoute). Do not remap onto Extra High, Grok, Cursor, Fast, or GPT.
- Fresh Claude High invoke. Do **not** `--continue`. Idle-timeout env for this hop: `PI_RUN_TIMEOUT=7200`, `PI_NI_ZERO_BYTE_IDLE_SEC=7200`, `PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC=7200`, `PI_RUN_TAIL_IDLE_TIMEOUT=7200`. EXIT 124: stop. Do not `--continue`. EXIT 1 (DNS/502): stop. Do not `--continue`.

Pass 1 history is **`review.md`** (NOT CLEAN, `R7-F01`–`R7-F13`). Pass 2 history is **`review-rerun-2.md`** (NOT CLEAN, `R7b-F01`–`R7b-F17`; F01–F16 ACCEPT-applied; F17 REJECT). Pass 3 history is **`review-rerun-3.md`** (NOT CLEAN, `R7c-F01`–`R7c-F16`; all 16 ACCEPT-applied). Pass 4 history is **`review-rerun-4.md`** (NOT CLEAN, `R7d-F01`–`R7d-F12`; all 12 ACCEPT-applied). Pass 5 history is **`review-rerun-5.md`** (NOT CLEAN, `R7e-F01`–`R7e-F10`; all 10 ACCEPT-applied). Pass 6 history is **`review-rerun-6.md`** (NOT CLEAN, `R7f-F01`–`R7f-F14`; all 14 ACCEPT-applied). Do **not** overwrite `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, or `review-rerun-6.md`. Write **`review-rerun-7.md`** only.

Issue ledger provided below (encoder `--write-review-brief` / Policy G pack); **do not re-report** those rows **including REJECT F17**. File **all valid residuals at this SHA, all severities including nits** (HIGH/MED/LOW/nit). New IDs **R7g-F01+** (no collision with `R7-F01`–`R7-F13`, `R7b-F01`–`R7b-F17`, `R7c-F01`–`R7c-F16`, `R7d-F01`–`R7d-F12`, `R7e-F01`–`R7e-F10`, or `R7f-F01`–`R7f-F14`). **CLEAN** only if nothing valid remains. ACCEPT items will APPLY as a pack. Reviewer is Claude High Pi (`claude/claude-opus-5-high`); Verify/Triage Composer 2.5; Fix Grok 4.6 High.

## Hop review (Policy G / pack-ledger)

- `--write-review-brief` is the **only legal review brief**. Hand-written one-ID briefs are non-compliant.
- Residual-only means **do not re-report ledger rows**, not "file only one new ID."
- File **all** valid residuals at the current SHA, **all severities** (HIGH / MED / LOW / nit). Valid nits must be filed. CLEAN only if nothing valid remains.
- Triage still REJECTS invalid items (already encoded, false cite, KEEP REJECT collision). All **ACCEPT**ed items — including nits — are **APPLY'd as a pack** that pass (order-dependent findings together).
- Orthogonal to Policy F (ladder completion): 2 consecutive CLEAN on unchanged SHA; `accept-apply` still resets that rung's streak to 0.

## Issue ledger (already identified)

| ID | Severity | Decision | Resolved | SHA | One-line |
|----|----------|----------|----------|-----|----------|
| R1-F01 | HIGH | ACCEPT | yes | 0b9a17713c7c | QC-1 heading count vs QC-10 Change History (7 vs 8) is ambiguous |
| R1-F02 | HIGH | ACCEPT | yes | 0b9a17713c7c | Wave 3 updates silver-spec Step 3 kind-aware required-sections (no universal UX Flows) |
| R1-F03 | HIGH | ACCEPT | yes | 0b9a17713c7c | Clarify skip-turn map names Security/Telemetry/API/CLI/Mobile/Pipeline turns that do not exist |
| R1-F04 | MED | ACCEPT | yes | 0b9a17713c7c | `multi` required-wins + INFO; forbid only if all forbid and none require |
| R1-F05 | MED | ACCEPT | yes | 0b9a17713c7c | Clarify capture schema `decisions` field; Decision Log iff ≥1 row |
| R1-F06 | MED | ACCEPT | yes | 0b9a17713c7c | security optional for headless-service / data-ml / library-sdk is contradictory |
| R1-F07 | MED | ACCEPT | yes | 0b9a17713c7c | Behavioral `kind-multi` fixture + required-wins case |
| R1-F08 | LOW | ACCEPT | yes | 0b9a17713c7c | ### Invariants is core-required but no QC enforces presence |
| R1-F09 | LOW | ACCEPT | yes | 0b9a17713c7c | Pack-local IDs: DATA-nn, SIG-nn, SLO-nn, CTRL-nn, QA-nn |
| R1-F10 | NIT | ACCEPT | yes | 0b9a17713c7c | software-kinds presence-iff-multi is not a stated QC |
| R1b-F01 | MED | ACCEPT | yes | bb06eb8cf944 | QC-7 SPEC-F61 exemption is a six-kind enum; multi with ux forbidden still deadlocks vs catalog QC-1 / figma-url |
| R1b-F02 | MED | ACCEPT | yes | bb06eb8cf944 | Wave 4 capture schema does not name brief fields for kind-gated packs the compiler concatenates from non-empty brief fields |
| R1b-F03 | LOW | ACCEPT | yes | bb06eb8cf944 | Blast radius still lists Clarify optional quality prompt after R2-F01 made nfr a real turn |
| R2-F01 | HIGH | ACCEPT | yes | d05755cb838f | nfr kind-required but sourced only by optional QA prompt; skip cites a nonexistent nfr turn |
| R2-F02 | MED | ACCEPT | yes | d05755cb838f | Pack-table Notes contradict kind catalog (security/infra-devops, data/mobile+infra+cli, decision-log/mobile) |
| R2-F03 | MED | ACCEPT | yes | d05755cb838f | 17 unclassified kind×pack cells; no closed-world default for unlisted packs |
| R2-F04 | LOW | ACCEPT | yes | d05755cb838f | Pack-local IDs: SCR-nn (mobile), STG-nn (pipeline) |
| R2-F05 | NIT | ACCEPT | yes | d05755cb838f | Omit-do-not-stub: forbidden present = ISSUE on new compiles (incl. `_N/A`); legacy N/A = INFO |
| R2-F06 | NIT | ACCEPT | yes | d05755cb838f | Freeze-copy relative links, NFR thresholds only in discontinued folder, stale parent-launches-GLM |
| R3-F01 | HIGH | ACCEPT | yes | edf2c256dcf9 | Kind-aware QC-7: no UX Flows / SPEC-F61 when ux is forbidden, even if figma-url is present |
| R3-F02 | MED | ACCEPT | yes | edf2c256dcf9 | XART-F02 Step 4 scopes to Functional REQ-nn; NFR-nn exempt from AC join |
| R3-F03 | MED | ACCEPT | yes | edf2c256dcf9 | silver-spec Step 1 domain mapping is kind-blind; Wave 3 omits Step 1 |
| R3-F04 | LOW | ACCEPT | yes | edf2c256dcf9 | Wave 2 verify rg omits QC-9 / QC-10 / SPEC-F71 / SPEC-F72 / REQ-F70 |
| R3-F05 | LOW | ACCEPT | yes | edf2c256dcf9 | kind-aware QC-1 present forbidden heading has no explicit SPEC-F* code |
| R5-F01 | HIGH | ACCEPT | yes | acaae5f796c9 | Wave 3 Step 7 + Wave 6 augment kind-reconciliation so preserve-body cannot keep forbidden pack headings after minting software-kind |
| R5-F02 | MED | ACCEPT | yes | acaae5f796c9 | QC-6 required set = feature-slug + software-kind only (plus software-kinds iff multi); clarify-brief / derived-requirements not QC-6 required |
| R5-F03 | MED | ACCEPT | yes | acaae5f796c9 | REQUIREMENTS NFR Source column joins QA-nn / SLO-nn / CTRL-nn (Functional AC join unchanged) |
| R5b-F01 | HIGH | ACCEPT | yes | 4a99ea1e75bf | Kind-aware QC-1 + QC-12 require required-pack bodies and pack-local IDs; `_TBD — Clarify skipped illegally_` does not satisfy a required pack |
| R5b-F02 | MED | ACCEPT | yes | 4a99ea1e75bf | QC-6b software-kinds = two+ distinct atomic catalog kinds (not `[cli]`, not `[multi, web-ui]`, not `[cli, cli]`, not unknown members) |
| R5b-F03 | MED | ACCEPT | yes | 4a99ea1e75bf | NFR Source stays; reverse coverage so dropped QA-nn / SLO-nn / CTRL-nn are visible even if remaining NFR rows have valid Source |
| R5c-F01 | HIGH | ACCEPT | yes | 506eca57afb3 | The stable-ID contract has no global uniqueness/shape check, allowing duplicate AC IDs to collapse traceability |
| R5c-F02 | MED | ACCEPT | yes | 506eca57afb3 | QC-10 / SPEC-F72 requires Change History table, current spec-version row, non-placeholder summary |
| R5c-F03 | MED | ACCEPT | yes | 506eca57afb3 | Reverse-NFR disposition = ### Source Dispositions table + closed enum + parser; dropped QA/SLO/CTRL cannot slip FAIL |
| R5e-F01 | MED | ACCEPT | yes | 0844eb0fbf94 | Wave 2 review-requirements QC-2 exact two-digit REQ-[0-9]{2} / NFR-[0-9]{2}; Step 8 mint/preserve; malformed-width negatives REQ-1, REQ-001, NFR-2 |
| R5f-F01 | MED | ACCEPT | yes | e056076257a4 | Catalog pack-local ID for required examples pack: EX-nn exact two-digit; pack table + ID scheme + QC-12/QC-13; Step 7 mint; fixtures missing/malformed EX-nn |
| R5h-F01 | MED | ACCEPT | yes | 0ec9824d6c57 | Cross-version ID non-reuse is promised but has no persisted state or retirement contract |
| R5i-F01 | MED | ACCEPT | yes | b04c6123138a | REQ/NFR IDs remain reusable across augment versions despite the canonical tombstone mechanism |
| R5j-F01 | MED | ACCEPT | yes | 8a2eb671bafc | SPEC-only greenfield detection can overwrite an existing REQUIREMENTS tombstone ledger |
| R5k-F01 | MED | ACCEPT | yes | d45ccf6b6862 | NFR Source and Source Dispositions are not mutually exclusive |
| R6b-F01 | HIGH | ACCEPT | yes | 878301866ecb | Wave 3 Steps 7–8 / Wave 6 writing branches: cross-artifact failure can commit only the new SPEC |
| R6c-F01 | HIGH | ACCEPT | yes | 7a6bfc5d66e9 | Wave 3 Steps 7a/8a and final pair installation: staged candidates are not carried through the review gates or committed with a recoverable two-file protocol |
| R6d-F01 | HIGH | ACCEPT | yes | 1f11eacc5052 | Wave 3 Step 8a/final install gate: fixes can mutate the staged pair after its cross-artifact validation without a mandatory final fixed-point revalidation |
| R6f-F01 | MED | ACCEPT | yes | f7c632b85ae3 | Global ID scheme and Wave 3 Steps 7/8: finite exact-width namespaces have no exhaustion behavior |
| R6h-F01 | MED | ACCEPT | yes | 4d0d3684ccd0 | Wave 1 REQUIREMENTS template and Wave 2 `review-requirements` QC-4: Functional AC cells must be exact AC-nn |
| R6i-F01 | MED | ACCEPT | yes | f20dd7b1f1c0 | Functional AC-cell cardinality remains contradictory after R6h |
| R6i-F02 | MED | ACCEPT | yes | f20dd7b1f1c0 | NFR `Source` permits many-to-one but defines no cell-list grammar or behavioral parser fixture |
| R6j-F01 | MED | ACCEPT | yes | 1b681ea74e5b | Functional AC-cell cardinality is not carried into the compiler and cross-artifact consumer contract |
| R6j-F02 | MED | ACCEPT | yes | 1b681ea74e5b | `nfr-source-cell-list` is not bound to Step 8 or `review-cross-artifact` despite both performing reverse/exclusive coverage |
| R6k-F01 | MED | ACCEPT | yes | bdb5c916f236 | Coverage Matrix cells and edge consistency still lack a normative machine contract |
| R6l-F01 | MED | ACCEPT | yes | 916528459561 | Coverage equality is not closed against the live SPEC AC namespace |
| R6m-F01 | MED | ACCEPT | yes | 364594469c19 | Wave 2 drops the inherited exact-ID QC-7 mode and NFR-metric branch while retargeting QC-4 |
| R6n-F01 | MED | ACCEPT | yes | 397020ce6adc | The derived REQUIREMENTS pair identity is emitted but never fail-closed against the staged SPEC |
| R7-F01 | HIGH | ACCEPT | yes | 22187ebfa043 | `### Invariants` is core-required (QC-11) but no turn, no brief field, and no compiler rule ever sources it |
| R7-F02 | HIGH | ACCEPT | yes | 22187ebfa043 | Zero-AC SPEC installs: every coverage/closure gate is vacuously satisfied and nothing requires ≥1 `AC-nn` or ≥1 Functional row |
| R7-F03 | MED | ACCEPT | yes | 22187ebfa043 | "eligible" is the quantifier for every NFR reverse-coverage branch and is never defined |
| R7-F04 | MED | ACCEPT | yes | 22187ebfa043 | `SCAN:<section>#<line-or-id>` has a grammar but no resolution contract, so a Source can cite nothing and pass |
| R7-F05 | MED | ACCEPT | yes | 22187ebfa043 | REQUIREMENTS `## Out of Scope` / `## Open Items` snapshots have no namespace closure against the live SPEC |
| R7-F06 | MED | ACCEPT | yes | 22187ebfa043 | `decision-log` "required if the brief recorded ≥1 decision" is unenforceable: no QC can see the brief |
| R7-F07 | MED | ACCEPT | yes | 22187ebfa043 | `spec-version` has no value grammar or ordering semantics, yet QC-10 ordering and R6n exact equality both depend on one |
| R7-F08 | MED | ACCEPT | yes | 22187ebfa043 | kind-reconciliation's "migration record/backup" is an undefined artifact in a freeze that bans undefined artifacts |
| R7-F09 | LOW | ACCEPT | yes | 22187ebfa043 | Wave 2 verify `rg` omits `nfr-source-cell-list`, `id-tombstones`, `QC-6b`, `QC-4`, `REQ-F30` |
| R7-F10 | LOW | ACCEPT | yes | 22187ebfa043 | Wave 1 SPEC core-template asserts omit `id-tombstones` while the REQUIREMENTS asserts include it |
| R7-F11 | LOW | ACCEPT | yes | 22187ebfa043 | Wave 1's `world-class-min` fixture is kind-tagged `cli` or `library-sdk`, both of which require three packs the fixture is not required to carry |
| R7-F12 | NIT | ACCEPT | yes | 22187ebfa043 | Unbalanced parenthesis in Wave 3 Step 8 leaves the fail-before-replace precondition list without a closing bound |
| R7-F13 | NIT | ACCEPT | yes | 22187ebfa043 | Pack table Notes use non-enum shorthand kind names while the tables are declared the machine source of truth |
| R7b-F01 | HIGH | ACCEPT | yes | 4c229f5d873b | Migrate-path `.planning/.spec-kind-migration.md` was deleted on install success, voiding the preserve-via-migration fixture |
| R7b-F02 | HIGH | ACCEPT | yes | 4c229f5d873b | `SCAN:<section>` forbids spaces but R7-F04 requires `<section>` equal a live heading — multi-word sections unreachable |
| R7b-F03 | HIGH | ACCEPT | yes | 4c229f5d873b | Invariants sourced only from brief while L140 allows empty brief and Wave 6 paths 2/3/4b are brief-less |
| R7b-F04 | MED | ACCEPT | yes | 4c229f5d873b | QC-11 “sourced from brief invariants” has no SPEC YAML projection unlike `decision-count` |
| R7b-F05 | MED | ACCEPT | yes | 4c229f5d873b | QC-12 iff depends on `decision-count` but missing/malformed YAML key has no defined reviewer or fail-before-install behavior |
| R7b-F06 | MED | ACCEPT | yes | 4c229f5d873b | Augment `decision-count` derived only from brief `decisions`; brief-less augment yields 0 and forces legacy Decision Log delete |
| R7b-F07 | MED | ACCEPT | yes | 4c229f5d873b | Pack-table Notes omit optional/forbidden classes present in the catalog, contradicting “Notes must match the catalog” |
| R7b-F08 | MED | ACCEPT | yes | 4c229f5d873b | `eligible` includes required-pack `CTRL-nn` while empty-NFR `None identified` was still asserted unconditionally |
| R7b-F09 | LOW | ACCEPT | yes | 4c229f5d873b | Ontology `optional` = “Absent = PASS” contradicts QC-12 iff requiring `## Decision Log` when `decision-count` ≥ 1 |
| R7b-F10 | LOW | ACCEPT | yes | 4c229f5d873b | ≥1-live-AC floor binds QC-8/XART but review-spec QC-8 stayed ID-shape-only |
| R7b-F11 | LOW | ACCEPT | yes | 4c229f5d873b | Wave 2 `rg` alternation omitted landed tokens `decision-count`, `SCAN`, `eligible`, and `spec-version` |
| R7b-F12 | LOW | ACCEPT | yes | 4c229f5d873b | `spec-version` grammar/comparator/bump defined but no normative seed `1` for greenfield path 1 or path-3 mint |
| R7b-F13 | LOW | ACCEPT | yes | 4c229f5d873b | Wave 1 core-template YAML asserts include `id-tombstones` but omit `decision-count` though Step 7 always writes it |
| R7b-F14 | LOW | ACCEPT | yes | 4c229f5d873b | `world-class-min` is `cli` but `QA-01, SLO-01` example requires forbidden `ops` pack `SLO-nn` |
| R7b-F15 | LOW | ACCEPT | yes | 4c229f5d873b | REQUIREMENTS “Headings (QC-1 lock)” listed five headings including Coverage Matrix while QC-1 pins four |
| R7b-F16 | NIT | ACCEPT | yes | 4c229f5d873b | Fail-before-install gates lacked `SPEC-F*`/`REQ-F*`/`XART-F*` codes |
| R7b-F17 | NIT | REJECT | n/a | 4c229f5d873b | Nine always-on turns vs “9-turn interview” is numeric-only; already disambiguated — resolved-as-rejected, not encoded |
| R7c-F01 | HIGH | ACCEPT | yes | fce83948e0c8 | Invariants precedence branch (3) `ASK` has no non-interactive terminal (`fail-before-write` unlike kind-reconciliation ASK), blocking two pinned brief-less Wave 6 fixtures that assert PASS install |
| R7c-F02 | MED | ACCEPT | yes | fce83948e0c8 | `decision-count` is QC-visible count language but QC-12 only gates heading presence iff ≥ 1 — no live-`DEC-nn` equality unlike `invariant-count` |
| R7c-F03 | MED | ACCEPT | yes | fce83948e0c8 | `invariant-count` exact equality (`SPEC-F73`) gates on undefined MUST/MUST NOT bullet grammar — no per-line rule or `INV-nn` anchor |
| R7c-F04 | MED | ACCEPT | yes | fce83948e0c8 | R7b-F14 `QA-01, SLO-01` parser fixture on `infra-devops`/`headless-service` necessarily carries required-pack `CTRL-nn`, making the pinned positive fixture fail its own neither-branch rule |
| R7c-F05 | MED | ACCEPT | yes | fce83948e0c8 | R7b-F12 seeds absent `spec-version` only; present-but-malformed prior values on augment paths 2/4b have no seed, bump, or fail-before-write branch |
| R7c-F06 | MED | ACCEPT | yes | fce83948e0c8 | Fifth ontology class `conditionally-required` (`decision-log` predicate) cannot be expressed in `software-kinds.yaml`, the sole machine source declared at L212 |
| R7c-F07 | MED | ACCEPT | yes | fce83948e0c8 | Retained `.planning/.spec-kind-migration.md` is a fixed path with default overwrite semantics — second migration destroys first preserved prose; no append/rotate rule |
| R7c-F08 | MED | ACCEPT | yes | fce83948e0c8 | `SCAN:` normalization ("collapse non-alphanumerics to `-`") is ambiguous on runs, edges, and trim — legitimate citations can hit fail-closed `REQ-F71` |
| R7c-F09 | LOW | ACCEPT | yes | fce83948e0c8 | `SCAN:<line-or-id>` bare line half has no base, stability, or revalidation rule — contradicts stable-ID contract at L217 |
| R7c-F10 | LOW | ACCEPT | yes | fce83948e0c8 | L437 named QC-string test assert list omits `SPEC-F70`, `REQ-F71`, `REQ-F72`, `XART-F03`, and conditionally-required/`decision-count: 0` direction though L435 `rg` alternation includes them |
| R7c-F11 | LOW | ACCEPT | yes | fce83948e0c8 | L361 `world-class-min` fixture assert list not updated with `decision-count` / `invariant-count` keys added to L359 template asserts by R7b-F13 |
| R7c-F12 | LOW | ACCEPT | yes | fce83948e0c8 | Wave 4 verify asserts mandatory `nfr` turn for nfr-required kinds but has no equivalent always-on assert for the Invariants turn (L515) |
| R7c-F13 | LOW | ACCEPT | yes | fce83948e0c8 | L360 requires the REQUIREMENTS template to contain both a live measurable `Metric` row and `None identified` empty-NFR example — mutually exclusive states on one artifact |
| R7c-F14 | NIT | ACCEPT | yes | fce83948e0c8 | L159 `conditionally-required` ontology row emits bare "ISSUE" with no `SPEC-F*` code, violating L260/L426 bare-ISSUE rule |
| R7c-F15 | NIT | ACCEPT | yes | fce83948e0c8 | Pack table Default class column uses non-enum vocabulary (`kind-gated`, `always required`) while R7b-F07 de-normativized only Notes |
| R7c-F16 | NIT | ACCEPT | yes | fce83948e0c8 | R7b-F08 catalog-derived "in practice only `cli`" conclusion restated as normative prose in six places — second-source-of-truth hazard R7b-F07 removed from Notes |
| R7d-F01 | HIGH | ACCEPT | yes | 74b9acf23da1 | `decision-count = max(brief, preserved)` is arithmetically incompatible with R7c-F02 live-`DEC-nn` count-equality; augment Decision Log is union emission (not max) |
| R7d-F02 | HIGH | ACCEPT | yes | 74b9acf23da1 | R7c-F01 live-`### Invariants` precondition enumerated only 2 fixtures; R7c-F05 / R6n / R6c PASS-on-augment fixtures still hit ASK fail-before-write |
| R7d-F03 | MED | ACCEPT | yes | 74b9acf23da1 | brief `decisions` has no sourcing turn — 12 gated turns vs 13 packs; `decision-log` unreachable on greenfield |
| R7d-F04 | MED | ACCEPT | yes | 74b9acf23da1 | Invariants branch (1) silently destroys preserved live bullets; superseding write must migrate-or-ASK |
| R7d-F05 | MED | ACCEPT | yes | 74b9acf23da1 | R7c-F09 live-ID rule makes `SCAN:…#QA-01` an eligible source, colliding with "SCAN atoms are not in this set" |
| R7d-F06 | LOW | ACCEPT | yes | 74b9acf23da1 | Wave 2 `rg` alternation omits `scan-section-slug` and `conditionally-required` |
| R7d-F07 | LOW | ACCEPT | yes | 74b9acf23da1 | Wave 3 verify list omits R7/R7b/R7c Step 7 obligations except the bare Invariants mapping |
| R7d-F08 | LOW | ACCEPT | yes | 74b9acf23da1 | `multi` catalog row is a computation, not a set — YAML set-equality and R7c-F06 predicate undefined for it |
| R7d-F09 | LOW | ACCEPT | yes | 74b9acf23da1 | allocator has no defined seed; `-00` is allocatable yet unreachable, making R6f exhaustion fixture non-behavioral |
| R7d-F10 | NIT | ACCEPT | yes | 74b9acf23da1 | `nfr` Default class cell embeds a catalog-derived kind list without the R7c-F16 non-normative tag |
| R7d-F11 | NIT | ACCEPT | yes | 74b9acf23da1 | `invariant-count` grammar admits `0`, which QC-11 (`≥ 1`) makes permanently non-installable |
| R7d-F12 | NIT | ACCEPT | yes | 74b9acf23da1 | SCAN atom permits `#` in both halves with no split rule — `SCAN:a#b#c` undefined under fail-closed `REQ-F71` |
| R7e-F01 | HIGH | ACCEPT | yes | f5fda2aed2ee | R7d-F05 SCAN eligible-ID join never reaches reverse-coverage surfaces (L427/L428/L458); pinned PASS fixture fail-closes |
| R7e-F02 | MED | ACCEPT | yes | f5fda2aed2ee | After R7c-F09, SCAN cannot cite ID-less core prose (Invariants have no INV-nn); section-anchored ordinal `bNN` |
| R7e-F03 | MED | ACCEPT | yes | f5fda2aed2ee | QC-10 non-placeholder Change History summary has no provenance on brief-less augment; `change-summary` field / deterministic delta / ASK |
| R7e-F04 | LOW | ACCEPT | yes | f5fda2aed2ee | "`-00` is allocatable" survived in five places vs R7d-F09 never-minted; exhaustion FAIL includes absent `-00` |
| R7e-F05 | LOW | ACCEPT | yes | f5fda2aed2ee | Union emission and count-equality had no test-surface binding; QC-string / Wave 3 / Wave 6 now bind |
| R7e-F06 | LOW | ACCEPT | yes | f5fda2aed2ee | R7d-F04 superseding-write had no behavioral fixture; Wave 6 invariants-supersede migrate-or-fail |
| R7e-F07 | LOW | ACCEPT | yes | f5fda2aed2ee | Wave 1 SPEC core-template assert list omitted `spec-version` while REQUIREMENTS requires it |
| R7e-F08 | NIT | ACCEPT | yes | f5fda2aed2ee | Union-emission "matching decision text" had no normalization; named `decision-row-identity` |
| R7e-F09 | NIT | ACCEPT | yes | f5fda2aed2ee | Non-normative catalog tag lived on `nfr` only; remaining pack Notes tagged consistently |
| R7e-F10 | NIT | ACCEPT | yes | f5fda2aed2ee | Core template `invariant-count` vs example Invariants bullets unpinned; must be ≥ 1 and equal |
| R7f-F01 | HIGH | ACCEPT | yes | e48177804e91 | Change History branch (2) not total; seed-only augment ⇒ empty delta ⇒ ASK; named no-structural-change sentence |
| R7f-F02 | MED | ACCEPT | yes | e48177804e91 | `review-requirements` SCAN still live-ID-only; ordinals fail REQ-F71 at reviewer surface |
| R7f-F03 | MED | ACCEPT | yes | e48177804e91 | Two exhaustion predicates; `00–99` shorthand vs never-mint `-00`; fail-closed unreachable |
| R7f-F04 | MED | ACCEPT | yes | e48177804e91 | Ordinal SCAN citations silently repoint across supersede; re-anchor or fail-before-write |
| R7f-F05 | MED | ACCEPT | yes | e48177804e91 | Malformed-prior `spec-version` seed wipes history; migrate-or-ASK into retained migration record |
| R7f-F06 | LOW | ACCEPT | yes | e48177804e91 | Union-emission identity undefined on DEC-nn + divergent text; identity is `decision` cell only |
| R7f-F07 | LOW | ACCEPT | yes | e48177804e91 | `change-summary` declared but missing from Wave 4 assert list and Clarify blast-radius |
| R7f-F08 | LOW | ACCEPT | yes | e48177804e91 | Wave 2 `rg` alternation omitted `change-summary` and ordinal token |
| R7f-F09 | LOW | ACCEPT | yes | e48177804e91 | No ordinal-SCAN PASS fixture and no QC-10 summary-provenance `- contains` |
| R7f-F10 | LOW | ACCEPT | yes | e48177804e91 | Ordinal enum named table-only Change History; Overview nesting / Assumptions shape unresolved |
| R7f-F11 | NIT | ACCEPT | yes | e48177804e91 | `nfr` pack Notes emphasis malformed (`R7d-F10:*`); derived/non-normative tag broken |
| R7f-F12 | NIT | ACCEPT | yes | e48177804e91 | `invariant-count` two-branch source count vs three-branch ASK; need resulting live count |
| R7f-F13 | NIT | ACCEPT | yes | e48177804e91 | `b[0-9]{2}` admits unreachable `b00`; no >99 FAIL rule |
| R7f-F14 | NIT | ACCEPT | yes | e48177804e91 | `invariant-count` / `decision-count` equality pinned on core template only; `world-class-min` presence-only |
| KEEP-REJECT | HIGH | REJECT | n/a | 22187ebfa043 | Two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third canonical kind doc |

Do **not** re-file ledger IDs unless a residual defect remains in **this** freeze.
CLEAN only if the re-read finds nothing valid beyond the ledger.


Ledger now includes **R7f-F01–R7f-F14** (ACCEPT / resolved yes / SHA `e4817780…`), **R7e-F01–R7e-F10** (ACCEPT / resolved yes / SHA `f5fda2ae…`), **R7d-F01–R7d-F12** (ACCEPT / resolved yes / SHA `74b9acf2…`), **R7c-F01–R7c-F16** (ACCEPT / resolved yes / SHA `fce83948…`), **R7b-F01–R7b-F16** (ACCEPT / resolved yes / SHA `4c229f5d…`), **R7b-F17** (REJECT / resolved-as-rejected / not encoded), plus R7-F01–F13, R6b–R6n, and earlier. Pass 6 `review-rerun-6.md` is history on the **pre-APPLY** pin `f5fda2ae…`. This pass is on the **post-APPLY** pin `e4817780…`. Do **not** overwrite Extra High files. Do **not** overwrite `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, or `review-rerun-6.md`. Write **`review-rerun-7.md`** only in this Claude High work dir. Do **not** re-report REJECT F17.

## Why this pass exists

Claude High pass 6 (`review-rerun-6.md`) was **NOT CLEAN** (`R7f-F01`–`R7f-F14`). TRIAGE ACCEPT 14/14; REJECT none. APPLY packed F01–F14 into the freeze. `verify_1-apply-rerun-6.md` **PASS**. Launcher recorded `--record-rung-review-outcome accept-apply` → `consecutive_clean_reviews: 0` (required 2) for `rung-id` `rung-07-pi-claude-opus-5-high`. Policy F streak reset. This is **pass 7** — a fresh residual re-hunt on the **new** pin. REJECT does not break the streak; any new ACCEPT resets it after APPLY.

**Independent residual re-hunt is mandatory.** Do **not** rubber-stamp pass 1–6. Do **not** copy `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, or `review-rerun-6.md`. Re-read the pinned freeze from scratch. Pass 1–6 are history, not authority. Residual only: do not re-file APPLYed / ledger IDs (including REJECT F17) unless a residual defect remains in **this** freeze text. File **all** valid residuals at this SHA, **all severities including nits** (HIGH/MED/LOW/nit). New IDs: `R7g-F01+`. If you find none, say **CLEAN** with evidence from **this** pass’s freeze read. CLEAN only if nothing valid remains. ACCEPT items will APPLY as a pack.

## Freeze (do not mutate)

- **File:** `.planning/spec_template_world_class.plan.md`
- **SHA-256:** `e48177804e917588603962385ecd76fab0440debc233c38e0cee047f35ccd2f1`
- **Byte-identical twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- **Also read:** `.planning/spec-template-world-class/CONTEXT.md` (metadata SHA may be stale — hash the freeze files yourself)

Hash both twins at start. They must still equal `e4817780…`. If they do not, stop and report. Do not edit them.

## Confirm R7f APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R7f-F01 HIGH | Branch (2) delta list includes `spec-version` **seed**, Invariants add/remove/migrate, and `DEC-nn` append. Empty delta ⇒ named no-structural-change sentence (`version seeded to 1 (prior spec-version malformed); no structural changes`) so brief-less augment 2/3/4b never drops to ASK solely for ∅ delta. L599 malformed-prior PASS uses (2) including seed. Fabricate never. |
| R7f-F02 MED | `review-requirements` SCAN resolution mirrors L73/L293: `<line-or-id>` is (a) live ID **or** (b) section-anchored ordinal `b[0-9]{2}` for ID-less sections; ID-bearing MUST use (a); ID-less MUST use (b). `review-cross-artifact` same two-clause rule. Bare line numbers still FAIL `REQ-F71`. |
| R7f-F03 MED | All `00–99`-live-or-tombstoned shorthand sites use the single L217/L457 predicate: every `01–99` live or tombstoned **and** (`-00` live, tombstoned, or absent — never mint it). Parseable domain stays `00–99` at L217. Do not weaken R6f fail-closed, R7d-F09, or R7e-F04. |
| R7f-F04 MED | Ordinal stability: mutate an ID-less section cited by live `SCAN:…#bNN` ⇒ re-anchor by `decision-row-identity`-style bullet-text match **or** fail-before-write / ASK. Wave 6 fixture: prior `SCAN:invariants#b03` + insert at position 1 ⇒ `b04` or fail; silent repoint FAIL. |
| R7f-F05 MED | Malformed-prior seed still writes exactly one canonical SPEC Change History row for version `1`, but prior human-authored rows MUST append to retained `.planning/.spec-kind-migration.md` **or** ASK; fail before write if unresolved. L599 PASS requires the `0.35` row in the migration record. KEEP REJECT: not a third canonical doc. |
| R7f-F06 LOW | `decision-row-identity` is the **`decision` cell only** (not `date` / `why`). Live `DEC-nn` match with non-identical normalized `decision` text ⇒ fail before write (or ASK). Same-brief-twice idempotence kept; divergent-text fixture FAIL. |
| R7f-F07 LOW | `change-summary` is in Clarify blast-radius capture parenthetical and the Wave 4 brief-field string-assert list. Not a turn (KEEP: interview not reopened). |
| R7f-F08 LOW | Wave 2 `rg` alternation includes `change-summary` and `section-anchored ordinal`. |
| R7f-F09 LOW | QC-string SCAN: `SCAN:invariants#b03` PASS (≥ 3 counted bullets); ordinal on ID-bearing section FAIL. Wave 3 `- contains` QC-10 names summary provenance (brief `change-summary`; else structural-delta sentence; else ASK fail-before-write). |
| R7f-F10 LOW | Ordinal enumeration: Overview top-level bullets excluding nested subsections; Change History is a table (cite `spec-version` cell, not `bNN`); Assumptions with `ASM-nn` = clause (a), without = counted bullets. |
| R7f-F11 nit | `nfr` pack Notes: `R7d-F10:` (not `R7d-F10:*`) so the derived/non-normative tag and kind list render. |
| R7f-F12 nit | `invariant-count` is the **resulting live** post-compile MUST/MUST NOT count: (1) brief supersede; else (2) preserved live; else (3) ASK / fail-before-write. Not a brief-only or preserved-only source count. |
| R7f-F13 nit | Ordinals are **1-based**: `b00` parses but FAILs `REQ-F71`; index > 99 FAILs (no `b100`, no wrap). |
| R7f-F14 nit | `world-class-min` asserts R7e-F10 equalities: `invariant-count` = counted R7c-F03 bullets and ≥ 1; `decision-count` = live `DEC-nn` and Decision Log present iff ≥ 1 (`cli` with no decisions ⇒ `decision-count: 0`, heading absent). |

## Confirm R7e APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R7e-F01 HIGH | Reverse-coverage surfaces (`review-requirements`, `review-cross-artifact`, Step 8) **resolve `SCAN:` atoms before the eligible-set join** (same parser as Wave 1). Eligible `QA-nn` / `SLO-nn` / `CTRL-nn` targets count as in ≥1 NFR Source; non-eligible SCAN remains carve-out-only. Fixture: `SCAN:quality-attributes#QA-01` sole Source ⇒ `QA-01` reverse-covered, PASS. Do not weaken R5k. |
| R7e-F02 MED | `<line-or-id>` is live ID **or** section-anchored ordinal `b[0-9]{2}` for ID-less sections (`SCAN:invariants#b03` = third R7c-F03 counted bullet). Bare line numbers still FAIL `REQ-F71`. Do not mint `INV-nn`. Omitted-`nfr` kinds scan Invariants via ordinal, not a fabricated pack ID. |
| R7e-F03 MED | Change History summary provenance: (1) operator-supplied brief `change-summary` (not a turn — KEEP: interview not reopened); else (2) deterministic structural-delta sentence; else (3) ASK / fail-before-write. Fabricate never. Brief-less augment 2/3/4b MUST take (2) or (3). |
| R7e-F04 LOW | Parseable domain stays `00–99`; `-00` counts toward exhaustion but is **never minted**. Exhaustion FAIL when `01–99` are live or tombstoned **and** `-00` is live, tombstoned, **or absent** (never mint it). All five "`-00` is allocatable" sites retired. R6f fail-closed kept. |
| R7e-F05 LOW | QC-string tests bind union emission + count-equality (count-mismatch FAIL `SPEC-F74`). Wave 3 verify names union emission (retain / append by identity / next-free). Wave 6: 2 preserved + 3 distinct brief + live Invariants ⇒ 5 live, `decision-count: 5`. |
| R7e-F06 LOW | Wave 6 invariants-supersede fixture: path 2 with prior bullets B1, B2 and brief carrying only B1 PASSes only if B2 appends to retained `.planning/.spec-kind-migration.md` (R7c-F07); unresolved ⇒ fail before write; `invariant-count` = resulting live count. KEEP REJECT: not a third canonical doc. |
| R7e-F07 LOW | Wave 1 SPEC core-template YAML assert list includes `spec-version` (R7-F07 grammar: integer ≥ 1; not `v1`, not `1.0`). |
| R7e-F08 nit | Named `decision-row-identity`: trim; collapse whitespace runs; case-fold; strip surrounding emphasis and trailing punctuation; apply identically to brief and live rows. Fixture: same brief twice ⇒ `decision-count` unchanged. |
| R7e-F09 nit | Catalog-derived kind lists in pack-table Notes (`ux`, `examples`, `security`, `telemetry`, `api`, `data`, `errors`, `cli`, `mobile`, `pipeline`, `ops`) carry the same *derived from the current catalog, non-normative* tag as `nfr`. `decision-log` Notes left as enforcement prose. |
| R7e-F10 nit | Core template example `invariant-count` MUST equal counted example `### Invariants` MUST/MUST NOT bullets (R7c-F03) and MUST be ≥ 1; example `decision-count` vs `## Decision Log` present iff ≥ 1 (R7c-F02). Assert in `test-spec-requirements-templates.sh`. |

## Confirm R7d APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R7d-F01 HIGH | Augment Decision Log is **union emission** (preserved `DEC-nn` retained; new brief rows appended by ID-or-text identity with next-free `DEC-nn`). YAML `decision-count` = resulting live count, **not** `max`. Keep R7b-F06 non-deletion (≥ preserved). Fixture: 2 preserved + 3 distinct brief ⇒ 5 live, `decision-count: 5`, QC-12 PASS. |
| R7d-F02 HIGH | **Every** Wave 6 PASS-install fixture supplies Invariants via branch (1) brief or branch (2) live prior `### Invariants` (no ASK). Includes R7c-F05 malformed-`spec-version`, R6n lineage PASS-on-augment, and R6c commit-boundary augment — not only the two R7c-F01 fixtures. |
| R7d-F03 MED | `decisions` is operator-supplied brief field only, never interview-sourced. “all 13 packs” is **12 kind-gated packs** (+ `decision-log` via brief field). **Did not** add a Decision Log turn (KEEP: interview not reopened). |
| R7d-F04 MED | Branch (1) is a **superseding** write with no-silent-delete: prior live Invariants not carried forward append to retained `.planning/.spec-kind-migration.md` (R7c-F07) **or** ASK; fail before write if unresolved. KEEP REJECT: not a third canonical doc. |
| R7d-F05 MED | `SCAN:` whose `<line-or-id>` resolves to eligible `QA-nn` / `SLO-nn` / `CTRL-nn` **counts as forward coverage** of that ID (resolve atoms before eligible-set join). Carve-out reserved for non-eligible SCAN targets. Fixture: `SCAN:quality-attributes#QA-01` sole Source ⇒ `QA-01` reverse-covered, no dispositions row. Do not weaken R5k. |
| R7d-F06 LOW | Wave 2 `rg` alternation includes `scan-section-slug\|conditionally-required`. |
| R7d-F07 LOW | Wave 3 `test-clarify-spec-compiler.sh` `- contains` bullets for Step 7 source-precedence + ASK fail-before-write, `invariant-count`/`decision-count` writes, `spec-version` seed + malformed-prior seed; migrate bullet asserts **append** (R7c-F07). |
| R7d-F08 LOW | `software-kinds.yaml` = **nine atomic** kinds only; `multi` is compile-time union / required-wins, excluded from Wave 1b set diff. `conditionally-required` predicate applies to the resolved kind (no `multi` YAML row). |
| R7d-F09 LOW | Sequential next-free **starts at `-01`**; `-00` is legal/parseable (legacy/hand-authored) and counts toward exhaustion but is **never minted**. Exhaustion fixtures restated as `EX-01`–`EX-99` plus `EX-00` present-or-tombstoned. R6f fail-closed kept. |
| R7d-F10 nit | Pack-table `nfr` **Default class** cell is enum-only `**optional**`; catalog kind list lives in Notes as *derived from the current catalog, non-normative* (R7c-F15 / R7c-F16 pattern). |
| R7d-F11 nit | `invariant-count` grammar: ≥ 1 on any installed SPEC; `0` parses but FAILs QC-11 / `SPEC-F73` (dead install state). No QC change. |
| R7d-F12 nit | `SCAN:` atom: `<section>` / `<line-or-id>` contain no `#`; exactly one U+0023 `#` separates them; zero or ≥2 `#` FAIL `REQ-F71`. Fixture FAIL: `SCAN:a#b#c`. |

## Confirm R7c APPLY still landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R7c-F01 HIGH | Invariants ASK branch (3) **fail before write** if unresolved (same terminal as kind-reconciliation). Wave 6 brief-less PASS fixtures MUST include live `### Invariants` in the *input* so they take branch (2) preserve and remain PASS-install. |
| R7c-F02 MED | QC-12 is live `DEC-nn` **count-equality** against YAML `decision-count` **and** heading present iff that value ≥ 1. |
| R7c-F03 MED | Named invariant bullet grammar: count only top-level `-` bullets whose first keyword is uppercase `MUST` or `MUST NOT`. QC-11 equality is over this grammar (no `INV-nn`). |
| R7c-F04 MED | Dedicated `QA-01, SLO-01` parser fixture (`infra-devops` / `headless-service`) MUST also cover eligible `CTRL-nn` so it does not FAIL neither-branch. |
| R7c-F05 MED | Present-but-malformed prior `spec-version` on paths 2/4b is treated as **no prior version** — seed `1` with exactly one Change History row. |
| R7c-F06 MED | `software-kinds.yaml` MUST carry `conditionally-required: {decision-log: "decision-count >= 1"}`. Catalog three-set remains sole source for pack membership. |
| R7c-F07 MED | Subsequent migrate **appends** a timestamped section (never truncate/overwrite prior preserved prose). |
| R7c-F08 MED | Named `scan-section-slug`: run-collapse non-alphanumerics to a single `-`; trim leading/trailing `-`; apply identically to cell and heading. |
| R7c-F09 LOW | `<line-or-id>` MUST be a live ID inside the section. Bare line numbers FAIL `REQ-F71`. |
| R7c-F10 LOW | Named QC-string test assert list includes `SPEC-F70`, `REQ-F71` + SCAN fixtures, `REQ-F72`, `XART-F03`, and conditionally-required / `decision-count: 0` FAIL. |
| R7c-F11 LOW | `world-class-min` asserts YAML `decision-count` / `invariant-count` plus live `### Invariants`. |
| R7c-F12 LOW | Wave 4 verify asserts the Invariants turn is **always-on** (every kind; not in the skip map). Universal 9-turn blob wording untouched. |
| R7c-F13 LOW | REQUIREMENTS **template** carries the measurable NFR `Metric` example; `None identified` empty-NFR example lives on `world-class-min` (or a dedicated empty-NFR fixture) — not both states on one artifact. |
| R7c-F14 NIT | `conditionally-required` ontology row emits `SPEC-F74` (no bare ISSUE). |
| R7c-F15 NIT | Pack-table Default class uses only the five-class ontology enum. Notes remain non-normative (R7b-F07). |
| R7c-F16 NIT | Keep the zero-live-IDs rule; the “in practice only `cli`” clause is one *derived from the current catalog, non-normative* parenthetical only. |

## Confirm R7b APPLY still landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R7b-F01 HIGH | Migrate-path `.planning/.spec-kind-migration.md` is **retained after successful install** as operator-visible, non-canonical, non-plugin-mirrored, not-parsed-by-any-QC. Snapshot-restore FAIL still deletes leftover staging copies (R6c). **KEEP REJECT:** not a third canonical doc. |
| R7b-F02 HIGH | `SCAN:<section>` normalization: strip `##`/`###`, lowercase, non-alphanumerics → `-`; unique normalized heading match. Keep no-comma/no-space atom + `, ` delimiter. Unresolvable `SCAN:` = `REQ-F71`. |
| R7b-F03 HIGH | Invariants source-precedence: (1) brief `invariants`; else (2) preserve live prior `### Invariants` as sourced (augment 2/3/4b); else (3) ASK. Fabricate never. Path 1 still requires sourced non-empty block. Empty/scaffold FAIL `SPEC-F73` before install. |
| R7b-F04 MED | YAML `invariant-count` (not QC-6 required). QC-11 = presence + live MUST/MUST NOT count equals `invariant-count` ≥ 1 (`SPEC-F73`). Reviewers read SPEC YAML, not the brief. |
| R7b-F05 MED | `decision-count` grammar: integer ≥ 0; `0`/`"0"` coerce; non-integer / negative / `v`-prefixed FAIL. Absent key on **new** compile ⇒ QC-12 FAIL. Same presence split for `invariant-count`. |
| R7b-F06 MED | Augment Decision Log union-emission + live count (R7d-F01 supersedes `max`). Wave 6 fixture: legacy SPEC with two `DEC-nn` + no brief ⇒ `decision-count: 2` and QC-12 PASS. |
| R7b-F07 MED | Kind catalog table is the **sole** machine source for `software-kinds.yaml`. Pack-table Notes are non-normative (MUST NOT derive YAML; MUST NOT contradict catalog). |
| R7b-F08 MED | `None identified` reachable only when the kind yields zero live `QA-nn`/`SLO-nn`/`CTRL-nn`. |
| R7b-F09 LOW | Fifth ontology class **conditionally-required**. `decision-log` reclassed with predicate `decision-count` ≥ 1. |
| R7b-F10 LOW | review-spec QC-8: every AC has `AC-nn` **and ≥1 live `AC-nn` exists** (`SPEC-F70`); zero live AC FAIL, not vacuous PASS. |
| R7b-F11 LOW | Wave 2 `rg` alternation adds `decision-count\|invariant-count\|SCAN\|eligible\|spec-version` plus `REQ-F71\|REQ-F72\|XART-F03`. |
| R7b-F12 LOW | **Seed:** no prior `spec-version` (path 1 greenfield or path 3 mint) writes `1`; Change History gets exactly one row for `1`; path 3 does **not** additionally bump on the same run. |
| R7b-F13 LOW | Wave 1 SPEC core-template YAML asserts include `decision-count` and `invariant-count`. |
| R7b-F14 LOW | `QA-01, SLO-01` two-atom Source example **only** on a dedicated parser fixture (`infra-devops` or `headless-service`). `world-class-min` (`cli`) MUST NOT carry `SLO-nn`. |
| R7b-F15 LOW | REQUIREMENTS headings retitled QC-1 lock + QC-8 Coverage Matrix. Four QC-1 headings; Coverage Matrix is QC-8 / `REQ-F70`, not QC-1. |
| R7b-F16 NIT | Codes: unresolvable `SCAN:` → `REQ-F71`; OOS/OQ snapshot inequality → `REQ-F72`; empty-namespace floor → `REQ-F70` + `XART-F03`; Step 8 unsourced Invariants → `SPEC-F73`. |
| R7b-F17 NIT | **NOT ENCODED** (REJECT / resolved-as-rejected). KEEP REJECT “one 9-turn interview for every kind” left intact. Do **not** re-file. |

R7-F01–F13 and R6b–R6n encodings retained. Do **not** weaken them (lineage, namespace, edge-set, grammars, staging/snapshot/fixed-point, exhaustion, 1b preserve-or-fail-closed). Spec-floor not tightened.

## Scope

Review the freeze template contract + kind catalog + Clarify skip-turns + implementation waves. Findings that improve the template contract are in scope. Charter KEEP REJECT: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third canonical kind doc. **R7b-F17 REJECT** — do not reopen.

Write only:
`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/review-rerun-7.md`

## Mandatory tools

1. `graphify query` first (CLI if MCP fails). Retrieve via Graphify, not ad-hoc greps.
2. agentmemory `memory_save` of decisions/findings.
3. After writing `review-rerun-7.md`, `graphify update .`.

## FORBIDDEN

- Do NOT triage, APPLY, fix, or edit the freeze / twins / SPEC compiler.
- Do NOT claim PASS or advance the ladder.
- Do NOT launch verify, Claude Extra High, or GPT Extra High.
- Do NOT `git checkout` / `git switch` / commit.
- Do NOT use Fast. Do NOT remap to Grok. Do NOT remap to Extra High.
- Do NOT `--continue` after EXIT 124 or EXIT 1 (DNS/502).
- Do NOT re-report ledger rows (including R7-F01–R7-F13, R7b-F01–F17, R7c-F01–F16, R7d-F01–F12, R7e-F01–F10, R7f-F01–F14, REJECT F17, and R6b–R6n).
- Do NOT overwrite `review.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, or `review-rerun-6.md`.
