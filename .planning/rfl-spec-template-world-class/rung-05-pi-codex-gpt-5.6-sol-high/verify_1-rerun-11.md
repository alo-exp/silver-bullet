# verify_1 — Rung 05 Pi Codex GPT-5.6 Sol High — pass 11

**Role:** verify_1 only (native Cursor Grok 4.5 High). No APPLY. No `--record-rung-review-outcome`. No verify_2. No pass 12. No freeze mutation. No commit. No branch switch. Never Pi / OmniRoute / agent-pi / Grok 4.6 / Fast / Extra High.

**Freeze pin (brief):** `8a2eb671bafcd8ee4e053c1c9a739e671972eaf64f438267a611ad603b63bf50`

**Official review under test:** [review-rerun-11.md](review-rerun-11.md)  
**Brief:** [brief-review-rerun-11.md](brief-review-rerun-11.md)

**Graphify first:** `graphify query "RFL Policy F verify_1 review-rerun-11 R5k-F01 NFR Source Dispositions exclusive QC"` — surfaced `R5k-F01` node in `review-rerun-11.md` L21.

**agentmemory:** saved verify_1 start note (`mem_mtezqqv8_6c9a73568ebe`); retrieve via Graphify, not raw memory greps.

---

## Verdict

**PASS** — Pass 11’s **NOT CLEAN** claim is authentic and **R5k-F01** is sustained as a real ACCEPT-worthy residual on this freeze. Not a false positive. KEEP REJECT intact.

| Return field | Value |
|---|---|
| SHA | `8a2eb671bafcd8ee4e053c1c9a739e671972eaf64f438267a611ad603b63bf50` |
| Twins identical | **y** |
| NOT CLEAN confirmed | **y** |
| R5k-F01 sustained | **y** (NFR Source ↔ Source Dispositions overlap is not FAIL; reverse-coverage OR is satisfiable while contradictory) |
| verify_1 | **PASS** |
| Artifact | `.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/verify_1-rerun-11.md` |

---

## 1. Freeze SHA + twins

| Check | Result |
|------|--------|
| Twin A SHA-256 (`.planning/spec_template_world_class.plan.md`) | `8a2eb671bafcd8ee4e053c1c9a739e671972eaf64f438267a611ad603b63bf50` |
| Twin B SHA-256 (`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`) | `8a2eb671bafcd8ee4e053c1c9a739e671972eaf64f438267a611ad603b63bf50` |
| Match brief pin | **y** |
| Twins byte-identical (`Buffer.compare === 0`; both 83584 bytes) | **y** |
| Freeze mutated since pin | **n** (observed SHA equals pin on both twins; verify_1 did not mutate) |

---

## 2. review-rerun-11 authenticity (NOT CLEAN + R5k-F01)

| Check | Result |
|------|--------|
| File size | 9074 bytes / 101 lines |
| SHA-256 | `cbc74e48a86483b4c7634b3088ce5c0e283987cca1e90eaa2eeae504a1e11cfa` |
| Stub/truncated/placeholder | **n** (identity, Verdict, R5k-F01 body with quotes + concrete counterexample, R5j APPLY table, residual re-hunt notes, boundaries) |
| States NOT CLEAN | **y** |
| States R5k-F01 MED | **y** |

**Evidence quotes from [review-rerun-11.md](review-rerun-11.md):**

> Expected and observed SHA-256: `8a2eb671bafcd8ee4e053c1c9a739e671972eaf64f438267a611ad603b63bf50`

> **NOT CLEAN** — one new residual template-contract finding: `R5k-F01` (MED).

> ### R5k-F01 — MED — NFR Source and Source Dispositions are not mutually exclusive

> “every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` must appear in ≥1 REQUIREMENTS NFR `Source` **or** in exactly one `### Source Dispositions` row”

> “an eligible source that is neither in NFR Source nor in exactly one valid dispositions row FAIL.”

> `QA-01` appears in ≥1 NFR Source and in exactly one syntactically valid disposition row. The freeze does not require a reviewer or compiler to reject that overlap.

> `### Source Dispositions` is explicitly the ledger for a SPEC source that did **not** become a requirement. Allowing the same source to back a live `NFR-nn` while also being `deferred`, `duplicate`, `out-of-scope`, or `not-requirement` makes REQUIREMENTS internally contradictory.

---

## 3. Prior reviews not overwritten

| Pass | Bytes | Lines | SHA-256 | Notes |
|------|------:|------:|---------|-------|
| 1 | 11088 | 157 | `c3f0b030cf9a906f07984fc3a7439b0338557efd83b538f43eeb57aa18caec93` | intact |
| 2 | 10728 | 132 | `c931f7bcc120920e762f17ab947e35bdae4a208661da18cf405f5f8e0ccae5ac` | intact |
| 3 | 10937 | 138 | `0fbf1823adc3e5dc473393114b72e776866d467dd6acac972d04a36765595777` | intact |
| 4 | 5131 | 53 | `0d2d6a648f18a0af0db697e4c2a034f9791fc24340b599edb7fe541046ac981d` | intact |
| 5 | 7736 | 86 | `16b3a551c7fc5b6203496a8900d3ee439394de6d260d026f1b600e224c600963` | intact |
| 6 | 8147 | 85 | `4f77ad06ab8acb4280fdabe895103541a1a9c0db96fb1031312eadabd89f4892` | intact |
| 7 | 8288 | 68 | `b84aa4e702c343857f5b5a1b5d760099436ceb41b0cf77714b02852090877784` | intact |
| 8 | 10131 | 87 | `18cb5ee824039b07fcdb981226178f35d0c27986a3a9f06ff3839095d033a2e3` | intact |
| 9 | 10059 | 82 | `369c2f99a5ec68adead2f9d44be26bf4772398177bb0a5ff7b1bbf2682e3d999` | intact |
| 10 | 11941 | 93 | `adf608547e3d5372a93d0046aa098d1aa26000674a1a6f09fc0fcff6dd99e990` | intact |
| 11 | 9074 | 101 | `cbc74e48a86483b4c7634b3088ce5c0e283987cca1e90eaa2eeae504a1e11cfa` | under test |

All 11 files exist with **11 unique** content hashes. Pass 1–10 were not clobbered by pass 11. No live `review.md` was written by this verify.

---

## 4. R5k-F01 on freeze text — sustained (ACCEPT-worthy)

**Claim under test:** reverse-coverage is Source **or** one Source Dispositions row, but overlap (source backs live `NFR-nn` **and** sits in `out-of-scope` / `deferred` / etc.) is not a FAIL.

### Freeze quotes (pin SHA above)

**ID scheme (L201):**

> **Reverse NFR coverage (R5b-F03, R5c-F03):** every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` must appear in ≥1 REQUIREMENTS NFR `Source` **or** in exactly one `### Source Dispositions` row (the only recorded non-requirement disposition).

**Target structure — REQUIREMENTS.md (L274):**

> **Reverse coverage (R5b-F03, R5c-F03):** every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` appears in ≥1 NFR Source **or** in exactly one `### Source Dispositions` row. … Parser: … an eligible source that is neither in NFR Source nor in exactly one valid dispositions row FAIL.

**Wave 2 `review-requirements` (L405):**

> **NFR reverse coverage (R5b-F03, R5c-F03):** every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` appears in ≥1 NFR Source **or** in exactly one `### Source Dispositions` row …

**Wave 3 Step 8 (L436):**

> … reverse coverage so every eligible SPEC `QA-nn` / `SLO-nn` / `CTRL-nn` appears in ≥1 NFR Source **or** exactly one `### Source Dispositions` row …

### Why this is a real hole (not KEEP REJECT / not false positive)

1. **Logical OR, not XOR.** A source present in ≥1 NFR Source **and** in exactly one valid disposition row satisfies “appears in ≥1 NFR Source **or** …” because the left disjunct is true. The named FAIL is only the **neither** case.
2. **Named negatives omit overlap.** L274 lists FAIL for free prose, unknown enum, missing/placeholder rationale, missing owner, duplicate disposition Source IDs, unknown/unresolved sources, and “neither … nor …”. No clause fails “present in both branches.”
3. **Exclusivity language absent.** Repo-wide keyword scan on the freeze for `mutually exclusive`, `must not also`, `cannot also appear`, `zero Source Disposition`, `overlap FAIL`, `present in both`, `exclusive for every` → **0 hits**.
4. **Semantic contradiction.** Dispositions are the ledger for a source that did **not** become a requirement (`the only recorded non-requirement disposition` / L246). Mapping the same `QA-01` into a live `NFR-nn` Source while also marking it `out-of-scope` / `deferred` / `duplicate` / `not-requirement` leaves REQUIREMENTS internally contradictory; forward Source QC and reverse-coverage QC can both pass.
5. **Concrete counterexample (from review, reproduces under stated QC):**

```markdown
| NFR-01 | Requests complete within budget | p95 < 200 ms | QA-01 | P1 |

### Source Dispositions
| Source | Disposition | Rationale | Owner |
| QA-01 | out-of-scope | Deferred from this delivery | team-a |
```

6. **Not reopening APPLYed IDs.** Forward Source (R5-F03) and reverse-coverage existence (R5b/R5c-F03) remain present; R5k-F01 is the missing exclusivity / overlap-FAIL residual only. R5j-F01 greenfield/partial-pair text is present (Wave 6 1b preserve-or-fail-closed); no residual R5j re-file required for this verify.

**Disposition:** **SUSTAIN** — ACCEPT-worthy MED template-contract gap. **Not** a false positive. **Not** KEEP REJECT.

---

## 5. KEEP REJECT intact

| KEEP REJECT rule | Freeze evidence | Intact? |
|---|---|---|
| Two canonical files (SPEC + REQUIREMENTS) | L41–L45 KEEP REJECT table; L248 “do not merge kinds into a third canonical consumer doc”; L664 | **y** |
| Clarify does not write SPEC.md | L47 REJECT: “Clarify writing `.planning/SPEC.md`” | **y** |
| Ingest stays | L48 KEEP: “Ingest as MCP dump then clarify then compile” | **y** |
| No third kind canonical doc | L45 REJECT “compiled third canonical doc”; L246 “Do **not** create `NFR-SECURITY.md`”; L51 REJECT “splitting NFR into a third file” | **y** |
| REQUIREMENTS remains REQ/NFR index | L45–L46; L254 “index, not a second spec” | **y** |

R5k-F01’s suggested fix (exclusive XOR + overlap FAIL + fixture) stays inside the two-file REQUIREMENTS contract. It does not ask for a third artifact or Clarify writing SPEC.

---

## Boundaries observed by verify_1

Did not: APPLY, mutate freeze twins, overwrite `review-rerun-1.md`–`review-rerun-10.md`, write `review.md`, `--record-rung-review-outcome`, launch verify_2, launch pass 12, switch branches, commit, execute freeze YAML, or use Pi / OmniRoute / agent-pi / Grok 4.6 / Fast / Extra High.

---

## Return summary

- **SHA:** `8a2eb671bafcd8ee4e053c1c9a739e671972eaf64f438267a611ad603b63bf50`
- **Twins:** y
- **NOT CLEAN confirmed:** y
- **R5k-F01 sustained:** y — reverse-coverage OR allows NFR Source + disposition overlap; overlap is not FAIL; contradictory REQUIREMENTS can pass QC
- **verify_1:** **PASS**
- **Artifact:** [`.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/verify_1-rerun-11.md`](verify_1-rerun-11.md)
