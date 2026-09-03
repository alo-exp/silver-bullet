# verify_2 — Rung 05 Pi Codex GPT-5.6 Sol High — pass 9

**Role:** verify_2 only (native Cursor Grok 4.5 High). Independent of verify_1. No APPLY. No `--record-rung-review-outcome`. No pass 10. No freeze mutation. No commit. No branch switch. Never Pi / OmniRoute / agent-pi / Grok 4.6 / Fast / Extra High.

**Freeze pin (brief):** `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f`

**Official review under test:** [review-rerun-9.md](review-rerun-9.md)  
**verify_1 under challenge:** [verify_1-rerun-9.md](verify_1-rerun-9.md)

**Graphify first:** `graphify query "RFL Policy F verify_2 review-rerun-9 R5i-F01 REQ NFR tombstone QC-2"` (CLI; surfaced R5i-F01 + verify_1 authenticity nodes).

---

## 1. Freeze SHA + twins (recomputed)

| Check | Result |
|------|--------|
| Twin A `.planning/spec_template_world_class.plan.md` | `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f` (76689 bytes) |
| Twin B `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md` | `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f` (76689 bytes) |
| Match brief pin | **y** |
| Twins identical to each other | **y** |
| Freeze mutated since pin | **n** |

---

## 2. review-rerun-9 authenticity (NOT CLEAN + R5i-F01)

| Check | Result |
|------|--------|
| Bytes / lines | 10059 / 81 |
| SHA-256 | `369c2f99a5ec68adead2f9d44be26bf4772398177bb0a5ff7b1bbf2682e3d999` |
| Stub / truncated / placeholder | **n** (identity, Result, full R5i-F01 body + fix list, prior APPLY table, residual-hunt notes, Verdict) |
| States **NOT CLEAN** | **y** |
| States **R5i-F01 MED** | **y** |

Re-read quotes:

> Expected and observed SHA-256: `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f`

> ## R5i-F01 — MED — REQ/NFR IDs remain reusable across augment versions despite the canonical tombstone mechanism

> One residual stable-ID gap remains outside the SPEC-side prefix set. REQUIREMENTS is expressly the canonical REQ/NFR ID index and Step 8 preserves currently present IDs, but the R5h tombstone mechanism is limited to SPEC core/pack IDs.

> # Verdict: NOT CLEAN

**NOT CLEAN confirmed: y**

---

## 3. Prior reviews exist and are distinct

| Pass | Bytes | SHA-256 |
|------|------:|---------|
| 1 | 11088 | `c3f0b030cf9a906f07984fc3a7439b0338557efd83b538f43eeb57aa18caec93` |
| 2 | 10728 | `c931f7bcc120920e762f17ab947e35bdae4a208661da18cf405f5f8e0ccae5ac` |
| 3 | 10937 | `0fbf1823adc3e5dc473393114b72e776866d467dd6acac972d04a36765595777` |
| 4 | 5131 | `0d2d6a648f18a0af0db697e4c2a034f9791fc24340b599edb7fe541046ac981d` |
| 5 | 7736 | `16b3a551c7fc5b6203496a8900d3ee439394de6d260d026f1b600e224c600963` |
| 6 | 8147 | `4f77ad06ab8acb4280fdabe895103541a1a9c0db96fb1031312eadabd89f4892` |
| 7 | 8288 | `b84aa4e702c343857f5b5a1b5d760099436ceb41b0cf77714b02852090877784` |
| 8 | 10131 | `18cb5ee824039b07fcdb981226178f35d0c27986a3a9f06ff3839095d033a2e3` |
| 9 | 10059 | `369c2f99a5ec68adead2f9d44be26bf4772398177bb0a5ff7b1bbf2682e3d999` |

**unique_shas = 9 of 9** — `review-rerun-1.md`–`review-rerun-8.md` present and distinct; pass 9 is a new file.

---

## 4. R5i-F01 — independent sustain / falsify on freeze

### SPEC tombstone scope (R5h closed)

Freeze L131:

> `id-tombstones` | YAML list of retired full IDs (`AC-03`, `EX-02`, …). **Named mechanism: tombstone list** (R5h-F01). Compiler Step 7 always writes it (`[]` if none). **Not QC-6 required** — QC-13 / QC-12 own presence and reissue. Never drop entries. Canonical allocator state lives in SPEC.md (not Git history, not a sidecar).

Freeze L195:

> Pack-local IDs in this table (`EX-nn`, `FLOW-nn`, `DEC-nn`, `QA-nn`, `CTRL-nn`, `SIG-nn`, `EP-nn`, `DATA-nn`, `ERR-nn`, `CMD-nn`, `SCR-nn`, `STG-nn`, `SLO-nn`) join the SPEC **tombstone list** (`id-tombstones`) with core IDs (R5h-F01) …

Freeze L201 (prefix set + mechanism; REQ/NFR called out as *separate* QC):

> `US-nn`, `FLOW-nn`, `AC-nn`, `OQ-nn`, `OOS-nn`, `DEC-nn`, plus pack-local IDs (`EX-nn` … `STG-nn`) — … **Named mechanism: tombstone list (`id-tombstones`) (R5h-F01).** … **REQUIREMENTS ID-shape QC-2 / `REQ-F10` (R5e-F01):** exact two-digit `REQ-[0-9]{2}` / `NFR-[0-9]{2}` on the index …; QC-3 uniqueness unchanged. **Distinct from SPEC QC-13.**

Wave 6 behavioral fixtures (freeze L555) are SPEC-only:

> Behavioral tombstone fixtures (R5h-F01): … retire `AC-03` … mint `AC-04` not `AC-03`; retired `AC-03` reissued FAIL QC-13; retired `EX-02` reissued FAIL QC-12/QC-13 …

**No freeze clause admits `REQ-nn` / `NFR-nn` into `id-tombstones`.** Enumerated tombstone prefixes are SPEC core + pack IDs only.

### REQ/NFR remain current-file-only

REQUIREMENTS frontmatter (freeze L258–L264) — no retirement key:

```yaml
derived-from: .planning/SPEC.md
spec-version: 1
generated: YYYY-MM-DD
feature-slug: <slug>
software-kind: <kind>
```

Step 8 (freeze L433) — preserve *still-present* IDs; no tombstone append:

> Step 8: one REQ per AC by default; mint sequential two-digit `REQ-nn` / `NFR-nn` (`REQ-[0-9]{2}` / `NFR-[0-9]{2}`) and preserve existing valid two-digit IDs during augment (R5e-F01); …

review-requirements QC-2 / QC-3 (freeze L402):

> **QC-2 (R5e-F01):** Functional IDs must match exact `REQ-[0-9]{2}` and Non-functional exact `NFR-[0-9]{2}` (two digits; **not** one-or-more digits). … QC-3 continues document-wide uniqueness (not width).

KEEP L45 strengthens ACCEPT-worthiness (stable index, not disposable labels):

> Two files; SPEC = story + kind-selected packs; **REQUIREMENTS = REQ/NFR index** | …

### Counterexample (ACCEPT-worthy MED)

v1: `AC-01`→`REQ-01`, `AC-02`→`REQ-02`. Retire `AC-02` into SPEC `id-tombstones`; REQUIREMENTS drops `REQ-02`. Later augment mints a new AC → Step 8 next-free can reissue `REQ-02` for different prose. Files stay QC-2/QC-3 clean (exact width + current-document uniqueness). Same pattern for retired `NFR-02`. SPEC `AC-nn` tombstones do not bind REQ ordinals (distinct namespaces).

**Falsification attempts that fail:**
- L201 “Do not reuse IDs across augment versions” is scoped to the SPEC prefix enumeration immediately preceding it; REQ/NFR are handled via distinct QC-2/QC-3.
- R5e-F01 “preserve existing” only protects IDs still in the current REQUIREMENTS snapshot — not retired holes.
- Admitting REQ/NFR into SPEC `id-tombstones` (review suggested fix) stays inside the two-file KEEP model.

| Question | Answer |
|----------|--------|
| R5h closed SPEC pack/core tombstones on this pin? | **Yes** |
| `id-tombstones` / QC-13 / Wave 6 cover REQ/NFR? | **No** |
| QC-2 / QC-3 / Step 8 encode cross-version REQ/NFR retirement? | **No** — current-file only |
| False positive / already encoded / KEEP REJECT conflict? | **No** |
| ACCEPT-worthy MED? | **Yes — sustained** |

**R5i-F01 sustained: y**

---

## 5. KEEP REJECT intact

Freeze `## KEEP REJECT` (L41–L55) still contains:

| KEEP | Observed |
|------|----------|
| Two files; SPEC + REQUIREMENTS index | **y** (L45) |
| Clarify does not write SPEC | **y** (L47 REJECT) |
| Ingest stays | **y** (L48; Wave 4 L490: “KEEP ingest: clarify may *read* ingest dumps; it still does not write SPEC.”) |
| No third kind canonical doc / no NFR third file | **y** (L45 REJECT; L51 REJECT) |

Review-9 residual notes and suggested fix stay inside the two-file model. **KEEP REJECT intact: y**

---

## 6. Challenges to verify_1 (non-rubber-stamp)

| Claim / gap | Challenge | Overturns? |
|-------------|-----------|------------|
| Frontmatter “L256–L263” | Section header is L256; YAML block is **L258–L264**. Off-by-range citation; substance correct. | **No** |
| Wave 6 AC/EX fixture quote without L555 | “mint after retire / AC-04” also lives in L201; Wave 6 behavioral fixtures are specifically **L555**. Attribution loose. | **No** |
| Omits KEEP L45 “REQUIREMENTS = REQ/NFR index” | Strengthens ACCEPT-worthiness; verify_1 under-cited it. | **No** (omission, not error) |
| Possible over-read of L201 “Do not reuse IDs…” | Independent read: clause binds SPEC catalog prefixes; QC-2 is explicitly “Distinct from SPEC QC-13.” Does **not** close R5i-F01. | **No** |

verify_1’s **PASS** and **R5i-F01 sustained** hold under independent re-check. No contradiction.

---

## verify_2 verdict

**PASS** — pin/twins hold; review-9 authentic NOT CLEAN + R5i-F01; prior reviews 1–8 intact and distinct; **R5i-F01 sustained** as ACCEPT-worthy MED (REQ/NFR outside SPEC `id-tombstones`; Step 8 / QC-2 / QC-3 current-file-only); KEEP REJECT intact; verify_1 weak citation gaps noted but non-fatal.

| Field | Value |
|-------|-------|
| SHA | `0ec9824d6c57462fe27fd8944f65ee78ad98a4fa5aca969dad971e3abcfb142f` |
| Twins y/n | **y** |
| NOT CLEAN confirmed y/n | **y** |
| R5i-F01 sustained y/n | **y** |
| verify_2 | **PASS** |
| Artifact | `.planning/rfl-spec-template-world-class/rung-05-pi-codex-gpt-5.6-sol-high/verify_2-rerun-9.md` |
