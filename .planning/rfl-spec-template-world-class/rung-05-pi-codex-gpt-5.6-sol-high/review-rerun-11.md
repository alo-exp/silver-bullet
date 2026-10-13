# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 11

**Role:** review-only (Policy C)  
**Model/provider observed:** `codex/gpt-5.6-sol-high` via `omniroute`  
**Freeze reviewed:** `.planning/spec_template_world_class.plan.md`  
**Expected and observed SHA-256:** `8a2eb671bafcd8ee4e053c1c9a739e671972eaf64f438267a611ad603b63bf50`  
**Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`  
**Twin check:** byte-identical (`cmp` exit 0; both files hash to the pinned SHA)  
**Context read:** `.planning/spec-template-world-class/CONTEXT.md`  

## Verdict

**NOT CLEAN** — one new residual template-contract finding: `R5k-F01` (MED).

The post-R5j freeze does contain the intended true-greenfield and partial-pair repair. True greenfield requires both canonical artifacts to be absent; Wave 6 step 1b names `preserve-or-fail-closed`, reads the existing REQUIREMENTS ledger before writing, unions prior tombstones, verifies lineage, and fails before either write when lineage cannot be established. Step 8 applies the tombstone union to every replacement path, and the behavioral fixture forbids `[]` reset, retired-ID reissue, and partial output.

The independent re-hunt found a separate residual in the NFR forward/reverse relationship: the contract does not reject an eligible SPEC source that is simultaneously mapped to a live NFR and recorded as a non-requirement disposition.

## Finding

### R5k-F01 — MED — NFR Source and Source Dispositions are not mutually exclusive

**Location:**

- `ID scheme` — reverse NFR coverage
- `Target structure — REQUIREMENTS.md` → `## Non-Functional Requirements`
- Wave 2 → `review-requirements` and `review-cross-artifact`
- Wave 3 → compiler Step 8
- Wave 2 QC fixture specification

**Evidence quotes:**

The ID scheme defines the alternatives as:

> “every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` must appear in ≥1 REQUIREMENTS NFR `Source` **or** in exactly one `### Source Dispositions` row”

The REQUIREMENTS contract repeats:

> “every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` appears in ≥1 NFR Source **or** in exactly one `### Source Dispositions` row.”

It validates duplicate Source IDs inside the disposition table and unresolved sources, but its listed failure condition is only:

> “an eligible source that is neither in NFR Source nor in exactly one valid dispositions row FAIL.”

Wave 2 similarly says that every eligible source appears in an NFR Source “**or**” one disposition, while Step 8 asks the compiler to satisfy that same alternative. None of those clauses says that a source present in one or more NFR rows must appear **zero** times in Source Dispositions. The named negatives cover dropped sources, free prose, missing rationale, duplicate disposition rows, unknown sources, and illegal `None identified.`, but not overlap between the two branches.

A concrete artifact can therefore satisfy all stated cardinality checks while asserting contradictory states:

```markdown
| NFR-01 | Requests complete within budget | p95 < 200 ms | QA-01 | P1 |

### Source Dispositions
| Source | Disposition | Rationale | Owner |
| QA-01 | out-of-scope | Deferred from this delivery | team-a |
```

`QA-01` appears in ≥1 NFR Source and in exactly one syntactically valid disposition row. The freeze does not require a reviewer or compiler to reject that overlap.

**Why it matters for the template contract:**

`### Source Dispositions` is explicitly the ledger for a SPEC source that did **not** become a requirement. Allowing the same source to back a live `NFR-nn` while also being `deferred`, `duplicate`, `out-of-scope`, or `not-requirement` makes REQUIREMENTS internally contradictory. A planner or executor cannot determine whether the obligation is active, while the forward Source join and reverse-coverage QC can both report success. This is a deterministic integrity gap in the two-file contract, not a request for a third artifact or for Functional AC joins on NFR rows.

**Suggested freeze-text fix:**

1. Define the relationship as exclusive for every eligible `QA-nn` / `SLO-nn` / `CTRL-nn` source:
   - it appears in one or more NFR Source cells and in **zero** Source Dispositions rows; **or**
   - it appears in zero NFR Source cells and in **exactly one** valid Source Dispositions row.
2. Make any NFR/disposition overlap fail `review-requirements` and `review-cross-artifact` before reverse coverage passes. Preserve one-to-many and many-to-one NFR mappings; only the non-requirement-disposition branch is exclusive.
3. Make Step 8 remove/reject a stale disposition when that source becomes mapped, and remove/reject stale NFR mappings when the source receives a disposition; fail before replacing REQUIREMENTS if the conflict is unresolved.
4. Add a negative fixture where `QA-01` is both an `NFR-nn` Source and a valid `out-of-scope` (or `deferred`) disposition. Keep positive fixtures for one source feeding multiple NFR rows and multiple sources feeding one NFR row.

## R5j-F01 APPLY confirmation

| Required property | Evidence in this freeze |
|---|---|
| True greenfield means both files absent | Wave 6 step 1: “both `.planning/SPEC.md` and `.planning/REQUIREMENTS.md` absent”; ID scheme and REQUIREMENTS frontmatter repeat the rule. |
| SPEC absent alone is not greenfield | Wave 6 step 1 ends “Absence of SPEC alone is **not** greenfield”; step 1b handles that partial pair. |
| Step 1b is preserve-or-fail-closed | Step 1b names the behavior, reads prior tombstones and live IDs before any write, unions the ledger, verifies lineage, and fails before write if lineage cannot be established. |
| No silent `[]` initialization | Step 1b says never initialize `[]` because SPEC is absent; Step 8 says `[]` is valid only when there is no prior REQUIREMENTS ledger. |
| Every REQUIREMENTS replacement unions prior tombstones | Step 8 names Wave 6 paths 2/3/4b and partial-pair 1b. Wave 6 repeats persistence for all augment branches. |
| No partial output on the sharp path | Step 1b requires neither artifact to change on lineage failure; the partial-pair fixture explicitly requires no partial output if pair writes are not atomic. |
| Required fixture | Wave 2 and Wave 6 name no SPEC plus `id-tombstones: [REQ-03, NFR-02]`, forbidding reset and later `REQ-03` minting. |
| Namespace separation remains intact | SPEC tombstones stay core/catalog under QC-12/QC-13/Step 7; REQUIREMENTS tombstones admit only exact two-digit REQ/NFR IDs under QC-2/QC-3/Step 8. |

No residual `R5j-F01` defect was re-filed.

## Independent residual re-hunt notes

- **REQUIREMENTS tombstones:** exact two-digit REQ/NFR shape, missing-key ISSUE-new / INFO-legacy behavior, live/tombstone overlap failure, append-on-removal, next-free allocation, preserve-still-present, every-path union, and canonical ownership in REQUIREMENTS are present. The inverse partial pair (SPEC present / REQUIREMENTS absent) falls into the total SPEC-present tree and has no prior REQUIREMENTS ledger to wipe.
- **SPEC tombstones:** the frontmatter, ID scheme, QC-12/QC-13, Step 7, and Wave 6 augment branches cover core and all catalog pack prefixes, including `EX-nn`; live/tombstoned overlap and next-free behavior remain stated.
- **IDs and parsers:** QC-13 retains exact two-digit global integrity for core/catalog IDs; QC-2 retains exact `REQ-[0-9]{2}` / `NFR-[0-9]{2}`; Coverage Matrix and ROADMAP consume the same grammar; duplicate AC detection precedes coverage; no “one or more digits” baseline leak was found in the freeze.
- **Kind catalog and Clarify:** required-pack bodies and IDs, optional-present validation, `EX-nn`, QC-6b two-plus/distinct/atomic validation before union, required-wins, closed-world omission, `_TBD` failure, all named pack fields, and separate mandatory `nfr`/`ops` turns remain present.
- **Compiler / Wave 6:** kind reconciliation covers branches 2/3/4b and fails before write when unresolved; partial-pair 1b separately handles REQUIREMENTS preservation and lineage; branch 4 remains the intentional legacy lock.
- **Change History / GWT / invariants / packs:** QC-10 table/current-version/substantive-summary rules, QC-9 interactive vs non-interactive split, QC-11 invariants, conditional Decision Log, and security/telemetry/API/UX/data/errors packs remain coherent.
- **NFR graph:** forward Source resolution, reverse coverage, closed disposition enum, rationale/owner checks, and `None identified.` guard are present. `R5k-F01` is the residual exclusivity hole; it does not reopen the already-APPLYed Source-column or reverse-coverage findings.
- **KEEP REJECT:** still intact — two canonical files, Clarify does not write them, ingest stays, no third canonical kind artifact, and REQUIREMENTS remains the REQ/NFR index.

## Review boundaries

This pass did not implement or APPLY a fix, mutate either freeze twin, write `review.md`, overwrite prior rerun reviews, launch verification, record a rung outcome, change branches, commit, execute freeze YAML, or recommend ladder advancement.
