# Brief — Rung 05 review pass 10 (Pi Codex GPT-5.6 Sol High)

**Rung:** 5 of 8 — **tenth review pass** on this freeze (Policy F: GPT-5.6 Sol High streak is **0** after pass 9 R5i-F01 ACCEPT-apply; this is consecutive CLEAN attempt **1** on the post-R5i freeze)
**Model:** GPT-5.6 Sol High — CHARTER slug `gpt-5.6-sol-high` via Pi Codex (`PI_PROVIDER=omniroute`). You **are** this named GPT. Never remap GPT onto Grok. Never substitute Cursor models. Never Extra High (`gpt-5.6-sol-xhigh` is rung 06 only, after streak == 2). Claude via Pi is later rungs (07–08).
**Host:** Pi Codex (`scripts/agent-pi/invoke.sh` / OmniRoute). Not Cursor Task. Not Fast. Not Cursor via Pi.
**Role:** review-only (Policy C). Do not implement. Do not APPLY. Do not triage/fix. Do not switch branches. Do not commit. Do not execute freeze YAML. Do not mutate freeze twins. Do not `--record-rung-review-outcome`. Do not launch verify. Do not advance to GPT-5.6 Sol XHigh or Claude.

Pass 1 history is **`review-rerun-1.md`**. Pass 2 history is **`review-rerun-2.md`**. Pass 3 history is **`review-rerun-3.md`**. Pass 4 history is **`review-rerun-4.md`**. Pass 5 history is **`review-rerun-5.md`**. Pass 6 history is **`review-rerun-6.md`**. Pass 7 history is **`review-rerun-7.md`**. Pass 8 history is **`review-rerun-8.md`**. Pass 9 history is **`review-rerun-9.md`**. Do **not** overwrite any of those. Do **not** create or clobber live `review.md`. Write **`review-rerun-10.md`** only.

## Why this pass exists

Pass 9 (`review-rerun-9.md`) was **NOT CLEAN** (`R5i-F01` MED). `verify_1-rerun-9.md` PASS and `verify_2-rerun-9.md` PASS confirmed the finding. Launcher ACCEPT-applied R5i-F01 as **REQUIREMENTS YAML `id-tombstones`** for retired `REQ-nn` / `NFR-nn` → freeze SHA `b04c6123138a1edf641f3de31c9171341a28e0e7800a640d6bd929ff5a06ff6c`. Policy F: `--record-rung-review-outcome accept-apply` → `consecutive_clean_reviews: 0`. Policy F still requires **two consecutive** CLEAN reviews on the **same** model before Extra High. This is **pass 10** — consecutive CLEAN attempt **1** on the **new** post-R5i freeze. REJECT does not break the streak; any new ACCEPT resets it after APPLY.

**Independent residual re-hunt is mandatory.** Do **not** rubber-stamp pass 9. Do **not** copy `review-rerun-9.md`. Re-read the pinned freeze from scratch. Pass 9 is history (the gap it filed is now APPLYed). Residual only: do not re-file APPLYed IDs unless a residual defect remains in **this** freeze text. If you find a residual template-contract gap, file it as `R5j-F01+`. If you find none, say **CLEAN** with evidence from **this** pass’s freeze read.

Pass 1 (`review-rerun-1.md`) was NOT CLEAN (R5-F01–F03 ACCEPT-applied). Pass 2 (`review-rerun-2.md`) was NOT CLEAN (R5b-F01–F03 ACCEPT-applied). Pass 3 (`review-rerun-3.md`) was NOT CLEAN (R5c-F01–F03 ACCEPT-applied). Pass 4 (`review-rerun-4.md`) was CLEAN (zero `R5d-F*`) then broken by pass 5 ACCEPT. Pass 5 (`review-rerun-5.md`) was NOT CLEAN (R5e-F01 ACCEPT-applied). Pass 6 (`review-rerun-6.md`) was NOT CLEAN (R5f-F01 ACCEPT-applied). Pass 7 (`review-rerun-7.md`) was CLEAN (zero `R5g-F*`; streak was 1, then broken by pass 8). Pass 8 (`review-rerun-8.md`) was NOT CLEAN (R5h-F01 ACCEPT-applied). Pass 9 (`review-rerun-9.md`) was NOT CLEAN (R5i-F01 ACCEPT-applied). Those APPLYs (through R5i) are already in this freeze.

Policy E: review the **world-class SPEC template + software-kind packs**. Not plan-hygiene unless hygiene breaks the template contract. Residual only — do not re-open APPLYed IDs unless a residual defect remains in **this** freeze text.

## Freeze (pin this SHA)

- **File:** `.planning/spec_template_world_class.plan.md`
- **Expected SHA-256:** `b04c6123138a1edf641f3de31c9171341a28e0e7800a640d6bd929ff5a06ff6c`
- **STOP** if `shasum -a 256` does not match. Do not review a drifted blob.
- Twins must be byte-identical: `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`
- Also read: `.planning/spec-template-world-class/CONTEXT.md`

Do **not** mutate either twin. Do **not** patch live `templates/` or `skills/` as a substitute for freeze findings.

This SHA is **post R5i APPLY** (new pin vs pass 9’s `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f`). Twins are byte-identical at this pin. Review **this** blob, not the pre-APPLY text.

## KEEP REJECT (do not reopen as goals)

- Two files only: SPEC.md + REQUIREMENTS.md
- Clarify does **not** write SPEC.md
- Ingest stays
- Do not merge kinds into a third canonical kind doc
- REQUIREMENTS.md stays the ID index (kinds may add NFR packs as **rows**, not a third file)

## Already APPLYed — do not re-open unless residual in THIS freeze

R1-F01–F10, R2-F01–F06, R3-F01–F05, R1b-F01–F03, **R5-F01–F03**, **R5b-F01–F03**, **R5c-F01–F03**, **R5e-F01**, **R5f-F01**, **R5h-F01**, and **R5i-F01** are already in this freeze. Do **not** re-file those IDs unless a **residual defect remains in this freeze text**.

New finding IDs: **R5j-F01+** (pass 10 on this Pi model). Do **not** reuse `R5i-F*` or `R5h-F*` or `R5g-F*` or `R5f-F*` or `R5e-F*` or `R5d-F*`.

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
| R5e-F01 MED | Wave 2 `review-requirements` **QC-2 / `REQ-F10`** requires exact `REQ-[0-9]{2}` and `NFR-[0-9]{2}` (two digits; **not** one-or-more digits). QC-3 uniqueness unchanged (not width). Step 8 mints sequential two-digit `REQ-nn` / `NFR-nn` and preserves existing valid two-digit IDs during augment. Coverage Matrix / ROADMAP parsers consume the same exact grammar. Fixtures: positive `REQ-01` / `NFR-01`; malformed-width negatives `REQ-1`, `REQ-001`, `NFR-2`, `NFR-0003` (also `tests/scripts/test-spec-req-id-parse.sh`). Phrase “one or more digits” must be **absent**. Aligns with template `REQ-nn`/`NFR-nn` and SPEC QC-13. |

### Confirm R5f APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5f-F01 MED | Catalog pack-local ID for required `examples` pack is exact two-digit `EX-nn`. Pack table, ID scheme, and QC-12/QC-13 prefix lists include `EX-nn`. Step 7 mints sequential `EX-[0-9]{2}` for present `## Examples` and preserves valid IDs. Wave 1b fixtures: `EX-01` on examples-required kinds (`library-sdk`, `http-api`, `cli`). QC fixtures: missing `EX-nn`, unlabeled Examples, malformed-width `EX-1`/`EX-001`, duplicate `EX-01`. Clarify brief `examples` may stay unnumbered; compiler mints at write time. |

### Confirm R5h APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5h-F01 MED | **Named mechanism: tombstone list (`id-tombstones`).** YAML list of retired full IDs persists across augment versions in SPEC.md (`[]` if none; never drop). Not QC-6 required. Canonical allocator state lives in SPEC.md (not Git history, not a sidecar). Pack table, ID scheme, QC-12 / `SPEC-F74`, QC-13 / `SPEC-F75`, Wave 3 Step 7, and Wave 6 augment branches 2/3/4b honor it. QC-13 FAIL if a live ID is tombstoned (retired `AC-03` reissued). QC-12 and QC-13 FAIL on retired `EX-nn` reissued. Step 7 sequential next-free skips tombstones **and** live current-file IDs (mint after retire skips the hole → `AC-04`). Happy path: preserve-still-present. Current-file uniqueness and exact two-digit `AC-nn` / `EX-nn` schemes stay intact. Fixtures: retired `AC-03` reissued FAIL; retired `EX-02` reissued FAIL; preserve-still-present; mint after retire skips the hole. SPEC catalog `id-tombstones` / QC-12 / QC-13 / Step 7 stay **catalog/core only** — they must **not** be widened to REQ/NFR (that is R5i). |

### Confirm R5i APPLY landed (do not re-file unless residual)

| ID | What must still be true in this freeze |
|----|----------------------------------------|
| R5i-F01 MED | **Named mechanism: tombstone list (`id-tombstones`) on REQUIREMENTS.** YAML list of retired exact two-digit `REQ-nn` / `NFR-nn` persists across augment versions in REQUIREMENTS.md (`[]` if none; never drop). Canonical **index** allocator state lives in REQUIREMENTS.md (not Git history, not a sidecar, not SPEC catalog tombstones). SPEC catalog `id-tombstones` / QC-12 / QC-13 / Step 7 stay catalog/core only (R5h-F01). Wave 2 `review-requirements` **QC-2 / QC-3 FAIL** if a live ID is tombstoned (retired `REQ-03` reissued; retired `NFR-nn` reissued). Step 8 sequential next-free skips tombstones **and** live current-file IDs (mint after retire skips the hole → `REQ-04`). Happy path: preserve-still-present. Exact two-digit `REQ-[0-9]{2}` / `NFR-[0-9]{2}` (R5e) stay intact. Fixtures: retired `REQ-03` reissued FAIL; retired `NFR-nn` reissued FAIL; preserve-still-present; mint after retire skips the hole. Do **not** reopen the two-file KEEP REJECT. |

Also still true from earlier APPLY: kind-aware QC-7 / `SPEC-F61` is catalog-derived `ux` forbidden (incl. `multi` / optional-omitted `plugin-extension`); XART-F02 Step 4 Functional-only (`NFR-nn` exempt); Wave 3 Step 1 kind-aware domain mapping; Wave 2 `rg` includes QC-9/10 and SPEC-F71/F72/REQ-F70; present forbidden heading emits `SPEC-F08`; Wave 4 names brief fields for kind-gated packs plus `decisions`; blast-radius Clarify row is a real `nfr` turn.

## Independent re-hunt (do not skip because R5i-F01 is APPLYed)

Re-scan the pinned freeze for **new** residual gaps that pass 9 could have missed, **and** for any **residual** hole in the REQUIREMENTS tombstone APPLY itself. Hunt these classes even if you expect none; file only if evidence is in **this** freeze text:

1. REQUIREMENTS tombstone residual (R5i-F01 APPLY): REQUIREMENTS YAML `id-tombstones` shape vs live `REQ-nn`/`NFR-nn`; QC-2/QC-3 reissue FAIL vs Step 8 next-free skipping holes; Wave 6 augment persistence/honor vs greenfield write; never-drop vs silently shrinking list; missing-key ISSUE-new vs INFO-legacy; canonical allocator in REQUIREMENTS vs SPEC catalog tombstones leaking REQ/NFR or vice versa; QC-2 width vs QC-3 uniqueness vs live/tombstoned overlap. File a **new** `R5j-F*` only if a defect remains **after** the APPLY text above is present.
2. SPEC tombstone residual (R5h-F01): catalog/core prefixes still covered; QC-13/QC-12 reissue FAIL vs Step 7 next-free; Wave 6 branches 2/3/4b persist/honor; prefixes beyond `AC`/`EX` (US/OQ/OOS/CTRL/SLO/etc.). Do not re-file R5h unless **this** freeze text still has a hole.
3. Template contract: required vs optional headings; ID uniqueness/shape beyond QC-13 **and** QC-2 two-digit REQ/NFR **and** the `EX-nn` grammar (parser holes, Coverage Matrix / ROADMAP vs compiler mint, `P1–P3` vs ID width, other required packs still missing prefixes); GWT; invariants; Change History beyond QC-10; decision log; NFR reverse+forward; Source Dispositions vs `SCAN:` sources; security/telemetry/API/UX/data/errors packs.
4. Kind catalog + Clarify skip-turns: required-pack bodies (QC-12) including `EX-nn` vs **optional**-present Examples; `multi` union completeness; QC-6b vs catalog membership; `_TBD` vs QC-1; Step 7 mint/preserve vs unlabeled/malformed/duplicate `EX-*`.
5. Compiler/QC/tests/v0.35 lock: Wave 3 Step 7 vs Wave 6 branches 2/3/4b fail-before-write holes; named fault codes vs string-only asserts; Coverage Matrix vs unlabeled/dup AC; QC-2 exact-width vs any remaining “one or more digits” baseline leak; QC-12/QC-13 prefix lists vs pack table (any other required pack still without an ID); Step 8 vs review-requirements vs Coverage Matrix vs ROADMAP on REQ/NFR tombstones.
6. Plan-hygiene last — only if it breaks the template contract.

Findings that improve the template contract are in scope even when the wave text is tidy. Do **not** invent findings to avoid a first CLEAN. Do **not** invent findings to force Extra High either.

## Tools (mandatory)

1. `graphify query "agent-pi invoke gpt-5.6-sol-high REQUIREMENTS id-tombstones REQ NFR QC-2 R5i-F01"` (or a scoped template/kind-pack query) before exploring. Retrieve prior notes via Graphify, not raw agentmemory dumps.
2. Save session notes via agentmemory MCP `memory_save` when available.
3. After any code/doc writes in this work dir only: `graphify update .`

## Finding format

For each: ID (`R5j-F01+`), severity HIGH|MED|LOW|NIT, location (heading/wave/pack/kind), evidence quote, why it matters for the **template contract** (or plan, if secondary), suggested freeze-text fix. Then: **CLEAN** or **NOT CLEAN**.

If CLEAN with no new gaps, say so explicitly with freeze SHA + twin check + residual-hunt notes. Do not claim ladder PASS or recommend Extra High. Do not `--record-rung-review-outcome` (parent records after verify).

## Output

- Official review: `.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/review-rerun-10.md` only.
- Do **not** overwrite `review-rerun-1.md`, `review-rerun-2.md`, `review-rerun-3.md`, `review-rerun-4.md`, `review-rerun-5.md`, `review-rerun-6.md`, `review-rerun-7.md`, `review-rerun-8.md`, or `review-rerun-9.md`.
- Do **not** write live `templates/` or `skills/` patches. Freeze-text suggestions belong in `review-rerun-10.md`.
- Do not create `review.md`. Do not launch verify. Do not APPLY. Do not `--record-rung-review-outcome`.
- Do not use Fast. Do not remap this GPT review onto Grok. Do not Extra High.

## FORBIDDEN

- Do NOT triage ACCEPT/REJECT, file issues, or apply fixes.
- Do NOT `git checkout` / `git switch` / change branches / commit.
- Do NOT claim ladder PASS or recommend advancing — parent verifies with Grok 4.5 High native Cursor (`verify_1` / `verify_2`) later.
- Do NOT launch subagents for Cursor-family models through Pi.
- EXIT 124 / timeout: stop. Do not `--continue`.
