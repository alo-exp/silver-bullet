# verify_1 — Rung 05 Pi Codex GPT-5.6 Sol High — pass 9

**Role:** verify_1 only (native Cursor Grok 4.5 High). No APPLY. No `--record-rung-review-outcome`. No verify_2. No pass 10. No freeze mutation. No commit. No branch switch.

**Freeze pin (brief):** `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f`

**Official review under test:** [review-rerun-9.md](review-rerun-9.md)  
**Brief:** [brief-review-rerun-9.md](brief-review-rerun-9.md)

---

## 1. Freeze SHA + twins

| Check | Result |
|------|--------|
| Twin A SHA-256 (`.planning/spec_template_world_class.plan.md`) | `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f` |
| Twin B SHA-256 (`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`) | `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f` |
| Match brief pin | **y** |
| Twins byte-identical (same SHA-256; both 76689 bytes) | **y** |
| Freeze mutated since pin | **n** (observed SHA equals pin on both twins) |

---

## 2. review-rerun-9 authenticity (NOT CLEAN + R5i-F01)

| Check | Result |
|------|--------|
| File size | 10059 bytes / 81 lines |
| SHA-256 | `369c2f99a5ec68adead2f9d44be26bf4772398177bb0a5ff7b1bbf2682e3d999` |
| Stub/truncated/placeholder | **n** (full identity, Result, R5i-F01 body, prior APPLY residual table, residual-hunt notes, Verdict) |
| States NOT CLEAN | **y** |
| States R5i-F01 MED | **y** |

**Evidence quotes from [review-rerun-9.md](review-rerun-9.md):**

> Expected and observed SHA-256: `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f`

> ## R5i-F01 — MED — REQ/NFR IDs remain reusable across augment versions despite the canonical tombstone mechanism

> One residual stable-ID gap remains outside the SPEC-side prefix set. REQUIREMENTS is expressly the canonical REQ/NFR ID index and Step 8 preserves currently present IDs, but the R5h tombstone mechanism is limited to SPEC core/pack IDs. Neither artifact retains retired `REQ-nn` or `NFR-nn`, so a later augment can legally reissue an index ID for a different requirement while passing every stated current-file REQUIREMENTS check.

> # Verdict: NOT CLEAN  
> One new residual finding, `R5i-F01`, is filed. No triage, APPLY, verification, outcome recording, ladder PASS, or advancement recommendation is made.

---

## 3. Prior reviews not overwritten

| Pass | Bytes | SHA-256 | Notes |
|------|------:|---------|-------|
| 1 | 11088 | `c3f0b030cf9a906f07984fc3a7439b0338557efd83b538f43eeb57aa18caec93` | intact |
| 2 | 10728 | `c931f7bcc120920e762f17ab947e35bdae4a208661da18cf405f5f8e0ccae5ac` | intact |
| 3 | 10937 | `0fbf1823adc3e5dc473393114b72e776866d467dd6acac972d04a36765595777` | intact |
| 4 | 5131 | `0d2d6a648f18a0af0db697e4c2a034f9791fc24340b599edb7fe541046ac981d` | intact |
| 5 | 7736 | `16b3a551c7fc5b6203496a8900d3ee439394de6d260d026f1b600e224c600963` | intact |
| 6 | 8147 | `4f77ad06ab8acb4280fdabe895103541a1a9c0db96fb1031312eadabd89f4892` | intact |
| 7 | 8288 | `b84aa4e702c343857f5b5a1b5d760099436ceb41b0cf77714b02852090877784` | intact |
| 8 | 10131 | `18cb5ee824039b07fcdb981226178f35d0c27986a3a9f06ff3839095d033a2e3` | intact |
| 9 | 10059 | `369c2f99a5ec68adead2f9d44be26bf4772398177bb0a5ff7b1bbf2682e3d999` | new file |

**unique_shas = 9 of 9** — prior `review-rerun-1.md`–`review-rerun-8.md` intact; pass 9 is a new file, not an overwrite.

---

## 4. R5i-F01 — sustain or falsify against freeze text

### What R5h closed (present on this pin)

SPEC frontmatter / ID scheme (freeze L131 / L201):

> `id-tombstones` | YAML list of retired full IDs (`AC-03`, `EX-02`, …). **Named mechanism: tombstone list** (R5h-F01). … Canonical allocator state lives in SPEC.md

> `US-nn`, `FLOW-nn`, `AC-nn`, `OQ-nn`, `OOS-nn`, `DEC-nn`, plus pack-local IDs (`EX-nn` … `SLO-nn`) … **Named mechanism: tombstone list (`id-tombstones`) (R5h-F01).** Persist retired/tombstoned full IDs in SPEC YAML `id-tombstones` (**exact two-digit catalog IDs**; `[]` if none).

Wave 6 / QC fixtures name SPEC-only cases (`AC-03`, `EX-02`):

> QC-13/QC-12 tombstone fixtures (R5h-F01): retired `AC-03` reissued FAIL; retired `EX-02` reissued FAIL … mint after retire skips the hole (`AC-04` not `AC-03`)

Catalog/core prefix set enumerated for tombstones does **not** include `REQ` or `NFR`.

### What remains open (REQ/NFR namespace)

REQUIREMENTS frontmatter (freeze L256–L263) — no retirement key:

```yaml
derived-from: .planning/SPEC.md
spec-version: 1
generated: YYYY-MM-DD
feature-slug: <slug>
software-kind: <kind>
```

Step 8 (freeze L433) — current-file preserve only:

> Step 8: one REQ per AC by default; mint sequential two-digit `REQ-nn` / `NFR-nn` (`REQ-[0-9]{2}` / `NFR-[0-9]{2}`) and **preserve existing valid two-digit IDs during augment** (R5e-F01) …

review-requirements QC-2 / QC-3 (freeze L201 / L402) — width + current-document uniqueness:

> **REQUIREMENTS ID-shape QC-2 / `REQ-F10` (R5e-F01):** exact two-digit `REQ-[0-9]{2}` / `NFR-[0-9]{2}` on the index …; **QC-3 uniqueness unchanged. Distinct from SPEC QC-13.**

> **QC-2 (R5e-F01):** Functional IDs must match exact `REQ-[0-9]{2}` and Non-functional exact `NFR-[0-9]{2}` … **QC-3 continues document-wide uniqueness (not width).**

No freeze clause admits `REQ-nn` / `NFR-nn` into `id-tombstones`, nor defines a REQUIREMENTS-side retirement list. Step 8’s “preserve existing” only protects IDs still present in the current REQUIREMENTS snapshot; a removed `REQ-02` / `NFR-02` leaves no persisted hole, so a later augment can mint that ID for different prose while remaining QC-2/QC-3 clean. SPEC-side `AC-nn` tombstoning does not bind the REQ ordinal (distinct namespace; mapping need not share the digit).

### Counterexample (ACCEPT-worthy)

v1: `AC-01`→`REQ-01`, `AC-02`→`REQ-02`. Retire `AC-02` (SPEC tombstones `AC-02`); REQUIREMENTS drops `REQ-02`. Later augment adds a new AC → Step 8 next-free can reissue `REQ-02` for new obligation. Files pass exact-width, current-file uniqueness, coverage, and NFR Source checks. Same pattern for retired `NFR-02`. Historical consumers of the original index ID are silently retargeted.

### Verdict on the finding

| Question | Answer |
|----------|--------|
| Did R5h close SPEC pack/core tombstones on this pin? | **Yes** |
| Do `id-tombstones` / QC-13 / Wave 6 cover REQ/NFR? | **No** — catalog/core SPEC prefixes + AC/EX fixtures only |
| Do QC-2/QC-3 / Step 8 encode cross-version REQ/NFR retirement? | **No** — current-file width/uniqueness + preserve-still-present |
| False positive / already encoded / KEEP REJECT conflict? | **No** |
| ACCEPT-worthy MED contract hole? | **Yes — sustained** |

**R5i-F01 sustained: y** — real residual after R5h: REQUIREMENTS remains the stable REQ/NFR index without persisted retirement state, so index IDs stay reusable across augment versions despite the SPEC tombstone mechanism.

---

## 5. KEEP REJECT intact

Freeze `## KEEP REJECT` still has:

| KEEP | Observed |
|------|----------|
| Two files; SPEC + REQUIREMENTS | **y** |
| Clarify does not write SPEC | **y** (REJECT: Clarify writing `.planning/SPEC.md`; Wave 4: “KEEP ingest: clarify may *read* ingest dumps; it still does not write SPEC.”) |
| Ingest stays | **y** (KEEP: “Ingest as MCP dump then clarify then compile”) |
| No third kind canonical doc | **y** (REJECT: “compiled third canonical doc for kinds” / “splitting NFR into a third file”) |

Review-9 residual notes also reaffirm KEEP REJECT and do not propose a third canonical kind document. R5i-F01’s suggested fix (admit `REQ`/`NFR` into SPEC `id-tombstones` or equivalent) stays inside the two-file model.

---

## verify_1 verdict

**PASS** — review authentic; freeze pin/twins hold; prior reviews preserved; **R5i-F01 sustained** as an ACCEPT-worthy MED residual (REQ/NFR cross-version reuse after R5h SPEC-only tombstones). Not a false positive.

| Field | Value |
|-------|-------|
| SHA | `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f` |
| Twins y/n | **y** |
| NOT CLEAN confirmed y/n | **y** |
| R5i-F01 sustained y/n | **y** (REQ/NFR outside `id-tombstones`; QC-2/QC-3/Step 8 current-file only) |
| verify_1 | **PASS** |
| Artifact | `.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/verify_1-rerun-9.md` |
