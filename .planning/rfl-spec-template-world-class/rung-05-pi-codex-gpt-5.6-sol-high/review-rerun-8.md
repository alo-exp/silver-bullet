# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 8

## Review identity

- **Role:** review-only; no APPLY, triage, verification launch, outcome recording, branch change, commit, freeze execution, or live template/skill edit.
- **Model / host:** `gpt-5.6-sol-high` via Pi Codex / OmniRoute (`PI_PROVIDER=omniroute`, `PI_MODEL=codex/gpt-5.6-sol-high`); no model remap or substitution.
- **Freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `e056076257a4ec1e7b6f85da3500d948feb1cf0551c58c6852aacaabff26cd10`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` — byte-identical (`cmp` exit 0; same SHA).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **History:** prior reruns were consulted only for residual-ID discipline after independently reading the pinned freeze; pass 7 was not treated as authority.
- **Graphify first:** ran `graphify query "agent-pi invoke gpt-5.6-sol-high EX-nn examples QC-12"` before source exploration.
- **Scope:** template contract and software-kind packs first; compiler/QC/tests and v0.35 augment behavior second; hygiene last.

## Result

The post-R5f freeze retains the previously applied kind reconciliation, metadata boundary, required-pack body checks, `multi` shape, forward/reverse NFR traceability, Source Dispositions grammar, global current-file ID integrity, Change History validation, exact two-digit REQUIREMENTS IDs, and `EX-nn` contract. The pack-prefix inventory is complete for the declared structured packs, and no residual `EX-nn`, QC-6/QC-6b, QC-10/QC-12/QC-13, NFR Source, Clarify skip-turn, or forbidden-heading write-path defect was found.

One new residual template-contract gap remains in the cross-version stable-ID promise. The freeze requires IDs never to be reused across augment versions, but its artifact shape and augment algorithm retain only IDs present in the current file. They provide no tombstone, registry, or persisted high-water mark from which the compiler or reviewer can detect an ID removed in an earlier version. Current-file QC-13 uniqueness and “preserve existing IDs” therefore cannot enforce the stated cross-version rule.

## R5h-F01 — MED — Cross-version ID non-reuse is promised but has no persisted state or retirement contract

**Location:** `PRIMARY — SPEC.md template contract` → `ID scheme`; Wave 3 Step 7; Wave 6 augment branches 2/3/4b; Wave 2 QC-13 / `SPEC-F75`.

**Evidence quote:**

> “Compiler assigns sequentially at write time. Do not reuse IDs across augment versions (append; never renumber cited IDs).”

> “Global ID-integrity QC-13 / `SPEC-F75` … file-unique + exact two-digit shape for every declared ID … Duplicate full IDs FAIL.”

> “Step 7 … Assign file-unique zero-padded IDs; do not emit duplicate `AC-nn` … preserve existing valid `EX-nn` on augment.”

> “Augment (template-shaped) … mint IDs for unlabeled AC without deleting their prose, do not renumber existing `AC-nn`.”

The required Change History records version/date/summary, but not retired IDs or per-prefix allocation watermarks. The target template likewise has no ID registry or retirement representation.

**Why it matters for the template contract:**

QC-13 proves uniqueness and shape only in the current snapshot. Preserving IDs that still exist also does not reveal identifiers that were removed before a later augment. For example, a v1 SPEC can contain `AC-01` through `AC-03`; after `AC-03` is removed, a later compiler that assigns sequentially from the current file can mint `AC-03` for an unrelated criterion. The resulting v3 file is file-unique, exact-width, and QC-13-clean, yet links, plans, PRs, or review records citing the original `AC-03` now resolve to a different contract. The same hole applies to `US`, `OQ`, `OOS`, and pack-local IDs such as `CTRL`, `SLO`, and `EX`.

“Append; never renumber” states the desired behavior but is not implementable or reviewable across snapshots unless the current canonical artifact persists enough allocation history. Neither current-file duplicate checks nor a prose Change History summary supplies that state. This is a stable-addressability defect in the SPEC template contract, not merely plan hygiene.

**Suggested freeze-text fix:**

Define one same-file ID lifecycle mechanism and test it. For example:

1. Add a compact persisted per-prefix high-water registry in SPEC frontmatter, or a core subordinate `### ID Registry`/retired-ID table, covering every prefix actually allocated in that SPEC.
2. Require Step 7 on all augment branches to mint only above the persisted prefix watermark, update the watermark atomically, and never lower it when an entry is removed. Preserve valid current IDs as today.
3. Alternatively, require deleted ID-bearing entries to remain as explicit tombstones carrying the original ID and retirement version; define how retired ACs are excluded from active AC→REQ/Coverage Matrix derivation while remaining visible to QC-13. Do not rely on Git history or an optional backup as the canonical allocator state.
4. Extend QC-13 (or a new named QC/fault) to validate registry/tombstone shape, prefix consistency, monotonic watermarks, and that no active ID is also retired.
5. Add an augment behavioral fixture: start with `AC-01`–`AC-03`, retire/remove `AC-03`, then add a criterion; the new criterion must become `AC-04`, never a new meaning for `AC-03`. Include at least one pack-local case such as retired `EX-02` followed by `EX-03`.

Keep this state inside SPEC.md so the two-file KEEP REJECT boundary remains intact.

## Prior APPLY residual check

| Pin requested by the brief | Result in this freeze |
|---|---|
| R5-F01 reconciliation in Wave 3 Step 7 and Wave 6 branches 2/3/4b; migrate-or-ASK; unresolved fails before write; behavioral cases | Present; R5h-F01 concerns historical ID allocation, not kind reconciliation |
| R5-F02 QC-6 only shaped `feature-slug` + catalog-valid `software-kind`; QC-6b iff `multi`; optional `clarify-brief`; non-QC-required template-default `derived-requirements`; Step 7 writes QC-6 keys | Present |
| R5-F03 NFR `Source` column and forward source join | Present |
| R5b-F01 QC-12 / `SPEC-F74` substantive required-pack bodies and catalog IDs; heading-only, `_TBD`, and empty stubs fail | Present |
| R5b-F02 two or more distinct atomic `software-kinds`, validated before pack union, with named negatives | Present |
| R5b-F03 reverse NFR coverage, allowed mapping cardinalities, and guarded empty state | Present |
| R5c-F01 QC-13 / `SPEC-F75` exact two-digit, file-unique current-file IDs; malformed/unlabeled/duplicate cases | Present for the current snapshot; R5h-F01 is the residual cross-version non-reuse boundary |
| R5c-F02 QC-10 / `SPEC-F72` Change History table, current YAML version row, ordered/unique versions, substantive summary | Present; its required columns do not retain ID allocation history |
| R5c-F03 canonical Source Dispositions table, closed enum, rationale/owner, source resolution/uniqueness, guarded `None identified.` | Present |
| R5e-F01 exact two-digit QC-2 / `REQ-F10`, Step 8 mint/preserve, exact consumer grammar, malformed-width negatives, no “one or more digits” leak | Present |
| R5f-F01 exact two-digit `EX-nn` across catalog, compiler, QC, and fixtures | Present; R5h-F01 also applies to reuse of a formerly allocated `EX-nn` |
| Catalog-derived QC-7 / `SPEC-F61`; Functional-only `XART-F02`; kind-aware Step 1; present forbidden heading `SPEC-F08`; all brief pack fields; real `nfr` turn | Present |

## Independent residual-hunt notes

- **Template/core:** rechecked the seven QC-1 headings, QC-10 Change History table, QC-11 Invariants, GWT/If-Then split, assumptions, decisions, OQ/OOS, Implementations, and AC→REQ/Coverage Matrix boundary. No new required/optional-heading defect was supported.
- **Pack identity:** cross-checked `FLOW`, `EX`, `DEC`, `QA`, `CTRL`, `SIG`, `EP`, `DATA`, `ERR`, `CMD`, `SCR`, `STG`, and `SLO` against the pack table and QC-12/QC-13 lists. Every declared structured pack has an exact two-digit prefix; `ASM-nn` remains intentionally optional.
- **Examples:** traced `EX-nn` through required/optional catalog selection, Wave 1b fixtures, compiler mint/preserve, and missing/unlabeled/malformed/duplicate negatives. No residual R5f contract gap remains apart from the newly identified generic cross-version reuse problem.
- **Kinds and Clarify:** re-evaluated atomic and representative `multi` unions, two-plus distinct atomic membership, required-wins, closed-world omission, optional decline, and separate required `nfr`/`ops` turns. No new union or skip-turn contradiction was found.
- **Compiler/augment:** traced Wave 3 Step 7 and Wave 6 branches 2, 3, and 4b. Kind reconciliation fails before a forbidden/unlisted pack can be written, but the augment path has no canonical memory of IDs absent from the current snapshot; this is the basis of R5h-F01.
- **REQ/NFR:** exact two-digit REQ/NFR parsing is consistent across Step 8, QC-2, Coverage Matrix/ROADMAP consumers, and fixtures. `P1`–`P3` remains an independent priority enum.
- **NFR provenance:** forward `QA`/`SLO`/`CTRL` or `SCAN:<section>#<line-or-id>` sources, reverse structured-source coverage, exactly-one Source Disposition, closed disposition enum, and guarded `None identified.` remain coherent. Source Dispositions apply to resolvable eligible structured sources; no supported `SCAN:` bypass was found.
- **KEEP REJECT / v0.35:** canonical outputs remain SPEC.md + REQUIREMENTS.md; Clarify remains capture-only; ingest remains separate; the legacy-lock total decision tree remains intact; no third canonical kind artifact is introduced.
- **Hygiene last:** CONTEXT retains stale historical freeze metadata, but the explicitly pinned review blob and twin match the expected SHA. That metadata drift does not cause R5h-F01 and is not filed separately.

# Verdict: NOT CLEAN

One new finding, `R5h-F01`, is filed. No triage, APPLY, verification, outcome recording, ladder PASS, or advancement recommendation is made.
