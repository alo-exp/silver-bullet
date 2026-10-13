# Brief — Rung 07 review pass 2 (Pi Claude Opus 5 High)

**Rung:** 7 of 8 — **second review pass** on Claude Opus 5 High (Policy F: this rung's streak is **0** after pass 1 pack APPLY + launcher `--record-rung-review-outcome accept-apply`). Do **not** remap this Claude High hop onto Grok, Extra High, Cursor, Fast, or GPT. Do **not** launch Claude Extra High.
**Model:** Claude Opus 5 High — CHARTER slug `claude-opus-5-high` via Pi OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`). You **are** this named Claude High. Never remap Claude onto Grok. Never remap High onto Extra High. Never substitute Cursor models. Never Cursor via Pi. Never Fast.
**Host:** Pi (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast. Not Cursor via Pi. Not GPT Extra High.
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not `--assert-rfl-advance`. Do not launch verify. Do not advance to Claude Extra High.

**Session policy (this hop):**
- **Verify + Triage = Composer 2.5**; **Fix/APPLY = Grok 4.6 High**.
- **verify_2** is skipped on already-triaged NOT CLEAN; **verify_2 is still required on CLEAN**.
- **Reviewer is this Claude High Pi hop** (`claude/claude-opus-5-high` / OmniRoute). Do not remap onto Extra High, Grok, Cursor, Fast, or GPT.
- Fresh Claude High invoke. Do **not** `--continue`. Idle-timeout env for this hop: `PI_RUN_TIMEOUT=7200`, `PI_NI_ZERO_BYTE_IDLE_SEC=7200`, `PI_NI_ZERO_BYTE_IDLE_NON_QWEN_SEC=7200`, `PI_RUN_TAIL_IDLE_TIMEOUT=7200`. EXIT 124: stop. Do not `--continue`.

Pass 1 history is **`review.md`** (NOT CLEAN, `R7-F01`–`R7-F13`). Do **not** overwrite `review.md`. Write **`review-rerun-2.md`** only.

Issue ledger provided below (encoder `--write-review-brief` / Policy G pack); **do not re-report** those rows. File **all valid residuals at this SHA, all severities including nits** (HIGH/MED/LOW/nit). New IDs **R7b-F01+** (or **R7-F14+** if the encoder is sequential — **no collision** with `R7-F01`–`R7-F13`). **CLEAN** only if nothing valid remains. ACCEPT items will APPLY as a pack. Reviewer is Claude High Pi (`claude/claude-opus-5-high`); Verify/Triage Composer 2.5; Fix Grok 4.6 High.

## Residual-only review (Policy G)

- Residual-only means **do not re-report ledger rows**, not "file only one new ID."
- File **all** valid residuals at the current SHA, **all severities** (HIGH / MED / LOW / nit). Valid nits must be filed. CLEAN only if nothing valid remains.
- Triage still REJECTS invalid items (already encoded, false cite, KEEP REJECT collision). All **ACCEPT**ed items — including nits — are **APPLY'd as a pack** that pass (order-dependent findings together).
- Policy F unchanged: 2 consecutive CLEAN on unchanged SHA; `accept-apply` still resets that rung's streak to 0.

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
| KEEP-REJECT | HIGH | REJECT | n/a | 22187ebfa043 | Two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third canonical kind doc |

Do **not** re-file ledger IDs unless a residual defect remains in **this** freeze.
CLEAN only if the re-read finds nothing valid beyond the ledger.

Ledger now includes **R7-F01–R7-F13** (ACCEPT / resolved yes / SHA `22187ebf…`) plus R6b–R6n and earlier. Pass 1 `review.md` is history on the **pre-APPLY** pin `397020ce…`. This pass is on the **post-APPLY** pin. Do **not** overwrite Extra High files. Do **not** overwrite `review.md`. Write **`review-rerun-2.md`** only in this Claude High work dir.

## Why this pass exists

Claude High pass 1 (`review.md`) was **NOT CLEAN** (`R7-F01`–`R7-F13`). TRIAGE ACCEPT 13/13. APPLY packed all 13 into the freeze. `verify_1-apply.md` **PASS**. Launcher recorded `--record-rung-review-outcome accept-apply` → `consecutive_clean_reviews: 0` (required 2) for `rung-id` `rung-07-pi-claude-opus-5-high`. Policy F streak reset. This is **pass 2** — a fresh residual re-hunt on the **new** pin. REJECT does not break the streak; any new ACCEPT resets it after APPLY.

**Independent residual re-hunt is mandatory.** Do **not** rubber-stamp pass 1. Do **not** copy `review.md`. Re-read the pinned freeze from scratch. Pass 1 is history, not authority. Residual only: do not re-file APPLYed / ledger IDs unless a residual defect remains in **this** freeze text. File **all** valid residuals at this SHA, **all severities including nits** (HIGH/MED/LOW/nit). New IDs: `R7b-F01+` (or `R7-F14+` if sequential — no collision with `R7-F01`–`R7-F13`). If you find none, say **CLEAN** with evidence from **this** pass’s freeze read. CLEAN only if nothing valid remains. ACCEPT items will APPLY as a pack.

## Freeze (do not mutate)

- **File:** `.planning/spec_template_world_class.plan.md`
- **SHA-256:** `22187ebfa0431cec6f5b3a6a3125c7befd0cdff401992b5a46df0b0e447c71cc`
- **Byte-identical twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- **Also read:** `.planning/spec-template-world-class/CONTEXT.md` (metadata SHA may be stale — hash the freeze files yourself)

Hash both twins at start. They must still equal `22187ebf…`. If they do not, stop and report. Do not edit them.

## Confirm R7 APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R7-F01 HIGH | Always-on Clarify Invariants turn + brief `invariants`; Step 1 maps to `### Invariants`; Step 7 writes sourced MUST/MUST NOT (no fabricate); empty/scaffold FAIL QC-11 / `SPEC-F73` before install. |
| R7-F02 HIGH | ≥1 live `AC-nn` and ≥1 Functional row on any installing pair; empty set is **not** vacuous QC-8 / R6l / R6k / XART-F02 PASS. True greenfield (both files absent) may still create a first pair; that pair must satisfy the floor. R5j 1b unchanged. Spec-floor KEEP intact. |
| R7-F03 MED | Named **eligible NFR source**: live, non-tombstoned `QA-nn` / `SLO-nn` / `CTRL-nn` on required **and** optional-present packs. Tombstones excluded. `SCAN:` not in this set. |
| R7-F04 MED | `SCAN:<section>#<line-or-id>` resolution: live staged-SPEC heading + live line/id. Lexical grammar (R6i) necessary but not sufficient. Unresolvable `SCAN:` FAIL before install. |
| R7-F05 MED | REQUIREMENTS OOS / Open Items snapshots MUST equal live non-tombstoned SPEC `OOS-nn` / `OQ-nn` (unknown/tombstoned/invented/missing FAIL). Bound to QC-8 / XART / Step 8. |
| R7-F06 MED | YAML `decision-count` (not QC-6 required) is the QC-visible iff: `## Decision Log` present iff count ≥ 1. Reviewers read SPEC YAML, not the brief. |
| R7-F07 MED | `spec-version` = positive integer ≥ 1; `1`/`"1"` coerce equal; YAML `v1`/`1.0` FAIL. Table cell = decimal string; human line = `v`+decimal. Ordered = strictly ascending; bump = +1; QC-10/R6n use integer comparator. |
| R7-F08 MED | Named **non-canonical** `.planning/.spec-kind-migration.md` (dotfile; not SPEC/REQUIREMENTS/KIND). Staging sibling; deleted after install or snapshot-restore FAIL. **KEEP REJECT:** not a third canonical doc. |
| R7-F09 LOW | Wave 2 `rg` includes `nfr-source-cell-list\|id-tombstones\|QC-6b\|QC-4\|REQ-F30`. |
| R7-F10 LOW | Wave 1 SPEC core-template asserts include `id-tombstones` (with REQUIREMENTS). |
| R7-F11 LOW | `world-class-min` is `software-kind: cli` **core-only exempt** from kind-required packs; Wave 1b `kind-*` owns pack obligations. |
| R7-F12 NIT | Fail-before-replace parenthetical closed after lineage inequality (+ R7 floors); emit duties are a new sentence. |
| R7-F13 NIT | Pack-table Notes use catalog enum: `plugin-extension`, `infra-devops`, `headless-service`. |

Do **not** weaken R6b–R6n encodings (lineage, namespace, edge-set, grammars, staging/snapshot/fixed-point, exhaustion, 1b preserve-or-fail-closed).

## Scope

Review the freeze template contract + kind catalog + Clarify skip-turns + implementation waves. Findings that improve the template contract are in scope. Charter KEEP REJECT: two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third canonical kind doc.

Write only:
`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/review-rerun-2.md`

## Mandatory tools

1. `graphify query` first (CLI if MCP fails). Retrieve via Graphify, not ad-hoc greps.
2. agentmemory `memory_save` of decisions/findings.
3. After writing `review-rerun-2.md`, `graphify update .`.

## FORBIDDEN

- Do NOT triage, APPLY, fix, or edit the freeze / twins / SPEC compiler.
- Do NOT claim PASS or advance the ladder.
- Do NOT launch verify, Claude Extra High, or GPT Extra High.
- Do NOT `git checkout` / `git switch` / commit.
- Do NOT use Fast. Do NOT remap to Grok. Do NOT remap to Extra High.
- Do NOT `--continue` after EXIT 124.
- Do NOT re-report ledger rows (including R7-F01–R7-F13 and R6b–R6n).
- Do NOT overwrite `review.md`.