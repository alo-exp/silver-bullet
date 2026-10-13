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
| R7g-F01 | HIGH | ACCEPT | yes | ba5636603368 | Migration record declared migrate-branch-only while Invariants supersede + Change History also write to it |
| R7g-F02 | MED | ACCEPT | yes | ba5636603368 | Step 7 `invariant-count` still pre-R7f-F12 sourced-bullet count; resulting-live post-compile |
| R7g-F03 | MED | ACCEPT | yes | ba5636603368 | Ordinal re-anchor unbound from Step 7 / Step 8 / Wave 3 |
| R7g-F04 | MED | ACCEPT | yes | ba5636603368 | Change History citable by `spec-version` cell but no `<line-or-id>` lexeme; clause (c) `v<integer>` |
| R7g-F05 | MED | ACCEPT | yes | ba5636603368 | Overview promised as SCAN target; ordinal grammar counts only `-` bullets; Invariants sole ID-less NF anchor |
| R7g-F06 | LOW | ACCEPT | yes | ba5636603368 | 1-based ordinal rule missed reviewer surfaces + QC-string list |
| R7g-F07 | LOW | ACCEPT | yes | ba5636603368 | Mixed Assumptions (`ASM-nn` / not) unclassified; per-entry exception |
| R7g-F08 | LOW | ACCEPT | yes | ba5636603368 | `decision-row-identity` FAIL/idempotence had no test-surface binding |
| R7g-F09 | NIT | ACCEPT | yes | ba5636603368 | REQUIREMENTS exhaustion still `REQ-00`–`REQ-99` shorthand; `-00`-absent primary fixture |
| R7g-F10 | NIT | ACCEPT | yes | ba5636603368 | Empty-delta trigger vs pinned fixture (`set` vs `set minus seed`); derived `<reason>` |
| R7h-F01 | MED | ACCEPT | yes | 892b263d530f | Ordinal stability scoped to "ID-less section"; mixed Assumptions `bNN`-citable yet exempt |
| R7h-F02 | MED | ACCEPT | yes | 892b263d530f | Re-anchor rewrite assigned to Step 7 (SPEC); ordinal lives in Step 8 Source; no owner |
| R7h-F03 | MED | ACCEPT | yes | 892b263d530f | Clause (c) `v<integer>` has no stability terminal across malformed-prior seed |
| R7h-F04 | MED | ACCEPT | yes | 892b263d530f | "Sole" ID-less NF SCAN anchor contradicted; universal MUST (b) without grammar |
| R7h-F05 | MED | ACCEPT | yes | 892b263d530f | Assumptions "entries" vs clause (b) "bullet"; counting unit undefined |
| R7h-F06 | MED | ACCEPT | yes | 892b263d530f | Per-entry MUST vs stable-base when cited entry later gains `ASM-nn` |
| R7h-F07 | LOW | ACCEPT | yes | 892b263d530f | Catalog-side `EX-00` present-or-tombstoned; `-00`-absent has no SPEC fixture |
| R7h-F08 | LOW | ACCEPT | yes | 892b263d530f | Wave 2 `rg` / Wave 3 `- contains` omit clause-(c) `version-cell` token |
| R7h-F09 | LOW | ACCEPT | yes | 892b263d530f | Assumptions per-entry MUST has PASS fixtures only; no `#b01` FAIL |
| R7h-F10 | NIT | ACCEPT | yes | 892b263d530f | `decision-log` Default class cell is not enum-only (R7c-F15 / R7d-F10) |
| R7h-F11 | NIT | ACCEPT | yes | 892b263d530f | QC-10 no-structural-change template unbound `N` + open `<reason>` |
| R7i-F01 | HIGH | ACCEPT | yes | 56cdd6988285 | Clause-(c) re-anchor deadlock: migration-record target unresolvable; L602 PASS fixture |
| R7i-F02 | MED | ACCEPT | yes | 56cdd6988285 | `ASM-nn` clause-(a) has no QC-13 shape/uniqueness/tombstone/minting producer |
| R7i-F03 | MED | ACCEPT | yes | 56cdd6988285 | QC-10 placeholder-only can FAIL mandated no-structural-change sentence |
| R7i-F04 | MED | ACCEPT | yes | 56cdd6988285 | QC-10 brief provenance vs QC-11 compiler-obligation caveat |
| R7i-F05 | LOW | ACCEPT | yes | 56cdd6988285 | XART SCAN omits `scan-section-slug` section normalization |
| R7i-F06 | LOW | ACCEPT | yes | 56cdd6988285 | L427 "ID-less sections" contradicts closed Invariants/Assumptions domain |
| R7i-F07 | LOW | ACCEPT | yes | 56cdd6988285 | Wave 2 `rg` omits `decision-row-identity` / Assumptions tokens |
| R7i-F08 | LOW | ACCEPT | yes | 56cdd6988285 | Wave 3 QC-10 `- contains` omits no-structural-change / `<reason>` / `N` |
| R7i-F09 | NIT | ACCEPT | yes | 56cdd6988285 | `decision-log` Default class cell still not enum-only (R7h-F10 residual) |
| R7i-F10 | NIT | ACCEPT | yes | 56cdd6988285 | Clause (c) `v<integer>` has no canonical decimal / dead-value rules |
| R7i-F11 | NIT | ACCEPT | yes | 56cdd6988285 | Assumptions entry-grammar exclusion half untested |
| KEEP-REJECT | HIGH | REJECT | n/a | 22187ebfa043 | Two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third canonical kind doc |

Do **not** re-file ledger IDs unless a residual defect remains in **this** freeze.
CLEAN only if the re-read finds nothing valid beyond the ledger.
