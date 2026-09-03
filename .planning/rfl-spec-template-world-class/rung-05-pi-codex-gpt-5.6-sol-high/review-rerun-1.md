# Rung 05 — Pi Codex GPT-5.6 Sol High — Review pass 1

## Review identity

- **Role:** review-only; no APPLY, triage, verification launch, outcome recording, branch change, commit, or live template/skill edit.
- **Freeze:** `.planning/spec_template_world_class.plan.md`
- **Expected and observed SHA-256:** `bb06eb8cf9448899e73ed072079cf4c8a0365c2e9a6144ea93f219b215cbfaf8`
- **Twin:** `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` — byte-identical (`cmp` clean; same SHA).
- **Context read:** `.planning/spec-template-world-class/CONTEXT.md`.
- **Graphify first:** ran the mandated scoped `graphify query` before source exploration.
- **Scope:** template contract and kind packs first; implementation waves second; hygiene last.

## Result

The freeze preserves the prior APPLY work named in the brief: kind-aware/catalog-derived QC-7 and `SPEC-F61` (including `multi` and optional-omitted `plugin-extension`), Functional-only `XART-F02`, Wave 3 Step 1 kind-aware mapping, the expanded Wave 2 `rg`/test contract, `SPEC-F08` for a present forbidden heading, all kind-gated brief fields plus `decisions`, and a real kind-gated `nfr` turn. KEEP REJECT remains intact.

This pass nevertheless found three new contract gaps. The first can make the compiler generate a spec that its own kind-aware reviewer must reject. The second leaves declared-required metadata outside the compiler/reviewer contract. The third discards the stable source IDs introduced specifically to make NFR packs addressable.

---

## R5-F01 — HIGH — Augment preservation conflicts with forbidden-pack omission and can deterministically emit an invalid compiled SPEC

**Location:** section ontology / compiler; Wave 3 Step 7; Wave 6 augment branches.

**Evidence:**

> “Default compile rule: **omit forbidden headings** (no N/A stubs).”

> “Present forbidden heading = ISSUE (`SPEC-F08`) on new compiles … present-but-unlisted uses the R2-F03 closed-world forbidden rule.”

> “Step 7: … **concatenate kind-required packs** (and optional packs with brief content).”

> “Augment (template-shaped) … preserve `created` and extra sections … If `software-kind` missing, mint from brief or ASK.”

> “Augment (stories without frontmatter) … mint frontmatter, **preserve body** …”

> “Augment (frontmatter without stories/slug) … **preserve body**, mint missing structure …”

**Why it matters for the template contract:**

The contract defines every present pack heading as required, optional-with-content, or forbidden under the resolved kind, but the augment algorithm only says to concatenate selected packs and preserve existing body/extra sections. It never reconciles existing pack headings against the newly resolved catalog classification. A sharp supported path is an old generic SPEC containing `## UX Flows`, `## User Stories`, and no frontmatter. Wave 6 classifies it as augment (not legacy lock), asks/mints `software-kind: cli`, and preserves the body. `ux` is forbidden for `cli`, so the compiler has just produced a compiled SPEC containing `## UX Flows`; review-spec must emit `SPEC-F08`. The same defect occurs when an existing kind is deliberately changed, or when stale unlisted pack headings survive an augment. This is not the already-fixed “present forbidden heading needs an ID” issue; `SPEC-F08` is present. The residual is that the compiler is instructed to create the condition without a migration rule.

**Suggested freeze-text fix:**

Add a kind-reconciliation step to Wave 3 Step 7 and every Wave 6 augment branch, before writing:

1. resolve/confirm the target `software-kind` (and `software-kinds` for `multi`);
2. classify every existing recognized pack heading with the target catalog;
3. preserve required packs and optional packs only when they contain substantive content;
4. for a formerly present pack that is forbidden/unlisted under the target kind, do not silently keep it and do not silently delete user prose — move its contents to an explicitly presented migration record/backup or require operator confirmation to omit/reclassify/change kind;
5. fail before write if unresolved, so Step 7 cannot knowingly emit a `SPEC-F08` artifact.

Add behavioral legacy-augment fixtures, at minimum generic-old-spec-with-UX → `cli`, and a kind-change case. Assert the output does not contain forbidden headings, preserves user content through the documented migration path, and passes the kind-aware heading check.

---

## R5-F02 — MED — Required frontmatter is declared more broadly than the compiler, QC, and tests enforce

**Location:** `Frontmatter (YAML) — core template`; Wave 1; Wave 2 QC-6; Wave 3 Step 7.

**Evidence:**

> “Add (**required non-empty except as noted**):”
>
> `feature-slug` — “kebab-case; required”
>
> `software-kind` — “**required.** Closed enum”
>
> `clarify-brief` — “path or `""`”
>
> `derived-requirements` — “relative path, default `.planning/REQUIREMENTS.md`”

But Wave 2 says:

> “Extend QC-6: `feature-slug` **and** `software-kind` required.”

Wave 3 Step 7 says only:

> “set frontmatter including `software-kind` (and `software-kinds` iff `multi`)”

And Wave 1 tests only presence strings for:

> “YAML keys `feature-slug`, `software-kind`, `derived-requirements`”

There is no corresponding compiler write requirement or reviewer rule for `clarify-brief` / `derived-requirements`; no QC validates `feature-slug` kebab-case, `software-kind` membership in the closed enum, or `derived-requirements` as a relative path. The catalog paragraph says an unknown kind is a “compiler ISSUE,” but Wave 2 QC does not protect a manually edited or stale compiled artifact.

**Why it matters for the template contract:**

These keys are not decorative: `feature-slug` identifies the feature, `software-kind` selects the section ontology, `clarify-brief` records source provenance, and `derived-requirements` locates the second canonical artifact. A template can satisfy the planned QC with `feature-slug: "Not A Slug"`, `software-kind: spaceship`, no `clarify-brief`, and no `derived-requirements`, even though the declared contract rejects that shape. Compiler and reviewer would therefore disagree with the core template’s own required metadata.

**Suggested freeze-text fix:**

Make the contract explicit and consistent:

- mark `clarify-brief` **required but allowed-empty** (or explicitly optional; choose one), and `derived-requirements` required/non-empty with its default;
- require Wave 3 Step 7 to write `feature-slug`, resolved closed-enum `software-kind`, `clarify-brief`, and `derived-requirements`, in addition to `software-kinds` iff `multi`;
- extend review-spec QC-6/6b (or add a named QC) to validate presence plus shape: kebab-case slug, known atomic kind or valid `multi`, relative requirements path, and the chosen `clarify-brief` rule;
- preserve the ISSUE-new / INFO-legacy policy for genuinely legacy augments, while new compiled output must conform;
- add positive and negative tests rather than only grepping that key names appear in the template.

---

## R5-F03 — MED — REQUIREMENTS NFR rows have no source-ID join back to the ID-addressable SPEC packs

**Location:** REQUIREMENTS `## Non-Functional Requirements`; ID scheme; review-cross-artifact; Wave 3 Step 8.

**Evidence:**

> “Every structured pack is ID-addressable … `QA-nn` maps to REQUIREMENTS `NFR-nn`.”

> “`## Non-Functional Requirements` — `| ID | Requirement | Metric | Priority |` — from Quality Attributes / kind NFR packs / scanned NF concerns.”

> “`NFR-nn` derive from SPEC `## Quality Attributes` (`QA-nn`), kind NFR packs (`SLO-nn`, `CTRL-nn`), or scanned NF concerns.”

> “Step 8: … NFR from Quality Attributes / kind NFR packs / scan …”

**Why it matters for the template contract:**

The plan correctly exempted NFR rows from the Functional AC join, but it did not replace that join with NFR provenance. The NFR table has no source column, and no QC verifies `NFR-03` came from `QA-02`, `SLO-01`, `CTRL-04`, or a clearly labeled compiler scan. Consequently, a compiler can drop, duplicate, or mutate a quality/security/operations item while all planned cross-artifact checks pass. This undercuts the stated model-facing value of stable pack-local IDs: the IDs stop at the SPEC boundary instead of making the REQUIREMENTS index auditable.

**Suggested freeze-text fix:**

Keep REQUIREMENTS as the same single ID-index file, but add a `Source` column to its Non-Functional table, for example:

`| ID | Requirement | Metric | Source | Priority |`

Require each row to cite one or more SPEC IDs (`QA-nn`, `SLO-nn`, `CTRL-nn`, and any other explicitly approved NF-producing pack ID). Define a stable sentinel such as `SCAN:<section>#<line-or-id>` for compiler-discovered concerns that genuinely lack a structured source. Extend Step 8, review-requirements, review-cross-artifact, the template fixture, and tests to enforce that every `NFR-nn` has a resolvable source and every required NF-producing source is represented exactly once unless an explicit many-to-one source list is used. This adds rows/one column, not a third file, and keeps `NFR-nn` exempt from the Functional AC matrix.

---

## Prior APPLY residual check

| Pin requested by brief | Result in this freeze |
|---|---|
| QC-7 / `SPEC-F61` catalog-derived for forbidden or optional-omitted `ux`, including `multi` and `plugin-extension` | Present |
| `XART-F02` Functional `REQ-nn` only; `NFR-nn` exempt | Present |
| Wave 3 Step 1 kind-aware domain mapping | Present |
| Wave 2 `rg` includes QC-9/QC-10 and `SPEC-F71`/`SPEC-F72`/`REQ-F70` | Present |
| Present forbidden heading emits `SPEC-F08` | Present |
| Wave 4 names all kind-gated fields plus `decisions` | Present |
| Blast-radius Clarify row is a real `nfr` turn | Present |

No prior finding ID was re-filed. R5-F01 is a residual interaction between the preserved augment algorithm and the now-correct forbidden-heading contract, not a reopening of R2-F05/R3-F05.

## Secondary checks

- Two canonical outputs remain SPEC.md + REQUIREMENTS.md; no finding proposes a third consumer artifact.
- Clarify remains capture-only and does not write SPEC.md.
- Ingest remains a compiler input.
- REQUIREMENTS remains the ID index with NFRs as rows.
- Kind catalog, `multi` required-wins, real `nfr` turn, pack field coverage, IDs, GWT, invariants, Change History, examples, decision log, API/UX/data/errors/security/telemetry packs, Waves 1–7, named tests, and v0.35 lock trigger are otherwise coherent.
- CONTEXT’s stale freeze metadata and Wave 6 numbering are plan-hygiene/sibling-metadata issues; they do not drive this verdict.

# Verdict: NOT CLEAN

R5-F01 is a HIGH compiler/template-contract contradiction on a supported augment path. R5-F02 and R5-F03 leave required metadata and NFR traceability materially weaker than the declared world-class, ID-addressable contract. This is this model’s first pass on the pinned freeze; no ladder PASS or advancement claim is made.
