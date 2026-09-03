# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 9

## Review identity

- **Role:** review-only; no APPLY, triage, verification launch, outcome recording, branch change, commit, freeze execution, or live template/skill edit.
- **Model / host:** `gpt-5.6-sol-high` via Pi Codex / OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-high`); no model remap or substitution.
- **Freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` — byte-identical (`cmp` success; same SHA).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **Graphify first:** ran `graphify query "agent-pi invoke gpt-5.6-sol-high id-tombstones QC-13 R5h-F01"` before source exploration, followed by a scoped query for SPEC tombstones and REQUIREMENTS allocation.
- **Method:** independently reread all 668 lines of the pinned post-R5h freeze, then consulted pass 8 only for residual-ID discipline. Template contract and kind packs were reviewed before compiler/QC/tests and hygiene.

## Result

The R5h APPLY is present for the SPEC ID space: `id-tombstones` is a same-file YAML list; catalog/core prefixes are covered; current live/tombstoned overlap fails; Step 7 next-free allocation skips live and retired IDs; all supported augment branches persist and honor the list; missing-key severity follows ISSUE-new / INFO-legacy; and the named AC/EX behavioral cases exist. The prior kind-reconciliation, required-pack-body, exact-width, Change History, NFR provenance, Source Dispositions, and Clarify-kind contracts also remain represented.

One residual stable-ID gap remains outside the SPEC-side prefix set. REQUIREMENTS is expressly the canonical REQ/NFR ID index and Step 8 preserves currently present IDs, but the R5h tombstone mechanism is limited to SPEC core/pack IDs. Neither artifact retains retired `REQ-nn` or `NFR-nn`, so a later augment can legally reissue an index ID for a different requirement while passing every stated current-file REQUIREMENTS check.

## R5i-F01 — MED — REQ/NFR IDs remain reusable across augment versions despite the canonical tombstone mechanism

**Location:** `PRIMARY — SPEC.md template contract` → Frontmatter / ID scheme; `Target structure — REQUIREMENTS.md` → YAML and Functional/Non-Functional tables; Wave 2 `review-requirements`; Wave 3 Step 8; Wave 6 augment fixtures.

**Evidence quote:**

> “`id-tombstones` | YAML list of retired full IDs (`AC-03`, `EX-02`, …). … Canonical allocator state lives in SPEC.md”

> “Persist retired/tombstoned full IDs in SPEC YAML `id-tombstones` (**exact two-digit catalog IDs**; `[]` if none).”

> “Pack-local IDs in this table … join the SPEC tombstone list (`id-tombstones`) with core IDs.”

> “Step 8: one REQ per AC by default; mint sequential two-digit `REQ-nn` / `NFR-nn` … and preserve existing valid two-digit IDs during augment.”

> “QC-2 … Functional IDs must match exact `REQ-[0-9]{2}` and Non-functional exact `NFR-[0-9]{2}` … QC-3 continues document-wide uniqueness.”

The target REQUIREMENTS frontmatter contains `derived-from`, `spec-version`, `generated`, `feature-slug`, and `software-kind`; it has no retirement state. The tombstone grammar and QC-13 ownership explicitly cover catalog/core SPEC IDs, while Step 8 and review-requirements specify only current-file width, uniqueness, and preservation of IDs that still exist. Wave 6’s tombstone cases likewise cover only `AC` and `EX`.

**Why it matters for the template contract:**

REQUIREMENTS is kept specifically as the stable REQ/NFR ID index used by the Coverage Matrix, ROADMAP consumers, PR traceability, and NFR provenance. Consider v1 with `AC-01`/`AC-02` mapped to `REQ-01`/`REQ-02`. If the second obligation is removed, the current REQUIREMENTS snapshot can lose `REQ-02`; a later augment that adds a different AC can mint sequential next-free `REQ-02`. The resulting files have exact two-digit IDs, no current-file duplicates, a non-empty AC join, and complete coverage, yet historical references to the original `REQ-02` now resolve to a different obligation. The same counterexample applies to a retired `NFR-02` whose replacement has a valid `QA`/`SLO`/`CTRL`/`SCAN:` Source.

SPEC-side `AC-02` tombstoning does not prevent either reuse: REQ numbering is a distinct namespace, mappings need not retain the same ordinal, and the current freeze does not admit `REQ`/`NFR` into `id-tombstones`. Thus R5h closes cross-version identity only for SPEC entries, not for the canonical requirements index. This does not ask for a third file or reopen the two-file decision.

**Suggested freeze-text fix:**

1. Extend the named tombstone mechanism to the REQUIREMENTS namespaces. Prefer broadening canonical SPEC YAML `id-tombstones` to admit exact two-digit `REQ-nn` and `NFR-nn` as well as catalog/core SPEC IDs, preserving the existing “allocator state lives in SPEC.md” decision. Precompute retirement/allocation from the prior SPEC + REQUIREMENTS pair before writing either output.
2. Require Step 8 on every augment branch to append removed `REQ-nn`/`NFR-nn`, preserve still-present IDs, never shrink the accumulated list, and mint next-free IDs while skipping both current index IDs and tombstones.
3. Extend review-spec’s tombstone shape parser to recognize the two index prefixes, and extend review-requirements QC (named fault required) to fail when a live REQ/NFR ID is tombstoned. If implementation instead keeps index tombstones in REQUIREMENTS, explicitly make that same-name list canonical for only REQ/NFR and retain SPEC as canonical for SPEC IDs; do not rely on Git history or a sidecar.
4. Add behavioral fixtures: retire `REQ-02`, then add a new functional obligation and require `REQ-03`; retire `NFR-02`, then add a new NFR and require `NFR-03`; include live/tombstoned overlap failures and a no-op augment proving existing REQ/NFR tombstones never disappear.

## Prior APPLY residual check

| Pin requested by the brief | Result in this freeze |
|---|---|
| R5-F01 kind reconciliation in Wave 3 Step 7 and Wave 6 branches 2/3/4b, with migrate-or-ASK and fail-before-write | Present |
| R5-F02 QC-6 boundary and QC-6b `multi` shape | Present |
| R5-F03 NFR Source forward join | Present |
| R5b-F01 required-pack bodies, IDs, and `_TBD`/stub rejection | Present |
| R5b-F02 two-plus distinct atomic `software-kinds`, validated before union | Present |
| R5b-F03 reverse structured-NFR coverage | Present |
| R5c-F01 QC-13 exact-width/current-file uniqueness and unlabeled/duplicate failures | Present for SPEC core and pack IDs |
| R5c-F02 Change History table/current-version/substantive-summary contract | Present |
| R5c-F03 Source Dispositions closed enum, source resolution, owner/rationale, and guarded empty state | Present |
| R5e-F01 exact two-digit REQ/NFR grammar across compiler/reviewer/consumers | Present; R5i-F01 concerns cross-version retirement, not width |
| R5f-F01 exact `EX-nn` contract | Present |
| R5h-F01 named SPEC tombstone list, all catalog/core prefixes, reissue failures, next-free skipping, augment persistence, and AC/EX fixtures | Present for SPEC IDs; R5i-F01 is the residual REQ/NFR namespace boundary |

## Independent residual-hunt notes

- **Tombstone shape and live overlap:** QC-13 requires every list entry to be an exact two-digit catalog ID and fails a current live/tombstoned collision. `ASM-nn` remains optional and is not a required structured-entry prefix. No residual prefix hole was found among `US`, `AC`, `OQ`, `OOS`, `FLOW`, `EX`, `DEC`, `QA`, `CTRL`, `SIG`, `EP`, `DATA`, `ERR`, `CMD`, `SCR`, `STG`, and `SLO`.
- **Tombstone persistence and allocation:** Step 7 says always write the key, append on removal, never drop entries, and skip tombstones plus live IDs for every catalog prefix. Wave 6 applies that rule to branches 2, 3, and 4b. The normative no-shrink rule is explicit; the missing cross-artifact REQ/NFR retirement state is the filed residual.
- **Greenfield / legacy boundary:** `[]` is defined for greenfield; missing key is ISSUE-new / INFO-legacy; the legacy-lock branch remains unchanged. No unsupported demand to mutate a locked legacy root artifact was introduced.
- **Template/core:** rechecked the seven QC-1 headings, QC-10 Change History table, QC-11 Invariants, GWT/If-Then split, assumptions, decision-log trigger, OQ/OOS IDs, Implementations, and AC→REQ Coverage Matrix boundary. No additional required/optional-heading defect was supported.
- **Kinds and Clarify:** rechecked catalog membership, closed-world pack handling, `multi` two-plus/distinct/atomic shape, required-wins, optional decline, required pack bodies including Examples, and separate required `nfr`/`ops` turns. No new skip-turn or union defect was found.
- **Compiler and review gates:** kind reconciliation remains pre-write on Step 7 and all augment paths; malformed/unlabeled/duplicate SPEC IDs fail before coverage; exact-width REQ/NFR parsers align across Step 8, review-requirements, Coverage Matrix, and ROADMAP. R5i-F01 is not a parser-width reopening.
- **NFR provenance:** forward `QA`/`SLO`/`CTRL` or `SCAN:<section>#<line-or-id>` Sources, reverse eligible-source coverage, exactly-one Source Disposition, and guarded `None identified.` are coherent. `SCAN:` is a generated forward source, not an eligible structured SPEC ID requiring reverse disposition.
- **KEEP REJECT / hygiene:** outputs remain SPEC.md + REQUIREMENTS.md; Clarify remains capture-only; ingest stays separate; no third canonical kind document is proposed. CONTEXT’s historical freeze metadata is stale, but the explicitly pinned blob and twin match; this does not break the reviewed template contract and was not filed.

# Verdict: NOT CLEAN

One new residual finding, `R5i-F01`, is filed. No triage, APPLY, verification, outcome recording, ladder PASS, or advancement recommendation is made.
