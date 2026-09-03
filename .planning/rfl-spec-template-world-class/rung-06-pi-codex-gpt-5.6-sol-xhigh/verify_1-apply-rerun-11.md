# verify_1 — APPLY — Rung 06 Pi Codex GPT-5.6 Sol Extra High — pass 11

**Role:** verify_1 APPLY only (native Cursor Composer 2.5 / `composer-2.5` / `sb-composer-2-5-high`). No freeze mutation. No `--record-rung-review-outcome`. No pass 12. No Claude. No commit. No branch switch.

**APPLY under test:** [APPLY-rerun-11.md](APPLY-rerun-11.md)  
**Prior review:** [review-rerun-11.md](review-rerun-11.md) + [verify_1-rerun-11.md](verify_1-rerun-11.md) PASS (R6k-F01 MED sustained pre-APPLY; do not re-litigate residual — check **encoding**).

**Twins checked (read-only):**
- `.planning/spec_template_world_class.plan.md`
- `.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`

**Method:** `graphify query "coverage-matrix-req-cell-list QC-8 matrix Functional edge-set R6k-F01 APPLY-rerun-11"` first; independent SHA-256 + `diff` + native line reads of cited freeze sections; retrieve prior context via Graphify (not ad-hoc agentmemory dumps).

---

## Verdict

| Field | Value |
|-------|--------|
| **verify_1 APPLY verdict** | **PASS** |
| **Overturns?** | **n** |
| **APPLY landed** | **y** |
| **Pre-APPLY SHA** | `1b681ea74e5b606c52481e10d81377fbedffb5206074c860d0989c9e4cbe1fe3` |
| **Post-APPLY SHA (both twins)** | `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94` |
| **Twins byte-identical** | **y** (`diff` exit 0; identical SHA-256) |
| **SHA changed from pre-APPLY** | **y** |

---

## 1. SHA + twins (computed independently)

| Check | Result |
|-------|--------|
| Twin A SHA-256 | `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94` |
| Twin B SHA-256 | `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94` |
| Matches claimed post-APPLY pin | **yes** |
| Matches pre-APPLY pin | **no** (expected — APPLY changed bytes) |
| Twins byte-identical | **yes** (`diff` exit 0) |
| Line count | 697 each |

---

## 2. APPLY artifact authenticity

| Check | Result |
|-------|--------|
| Path | `.planning/rfl-spec-template-world-class/rung-06-pi-codex-gpt-5.6-sol-xhigh/APPLY-rerun-11.md` |
| Size | **3489 bytes** |
| Stub/truncated | **no** — pre/post SHA block, disposition table, 15+ freeze line cites, KEEP REJECT note |
| Claims R6k-F01 APPLIED | **yes** |
| Cited freeze lines exist at claimed content | **yes** — see §4 |

---

## 3. Must-confirm checklist (R6k-F01 encoding)

| # | Requirement | Result | Evidence |
|---|-------------|--------|----------|
| 1 | Post-APPLY SHA pin; twins identical; SHA ≠ pre-APPLY | **PASS** | §1 |
| 2 | Named `coverage-matrix-req-cell-list` (`, ` + exact `REQ-[0-9]{2}`) normative | **PASS** | **L76**, **L77**, **L206**, **L282**; 17 hits freeze-wide |
| 3 | Matrix `AC` cell **exactly one** `AC-[0-9]{2}` (no R6h/R6i regression) | **PASS** | **L76**, **L282**, **L412**, **L413**; R6j Functional exact-one still **L74** |
| 4 | Matrix ↔ Functional **edge-set equality** FAIL-closed | **PASS** | **L76**, **L77**, **L282**, **L412**, **L413**, **L443**, **L576** |
| 5 | Bound to **QC-8** / **Step 8** / **XART** / compiler fixtures (not prose-only) | **PASS** | **L77**, **L345**, **L346**, **L412**, **L413**, **L419**, **L422**, **L443**, **L451**, **L473**, **L576** |
| 6 | **R6j-F01/F02** + `nfr-source-cell-list` intact; KEEP REJECT | **PASS** | R6j-F01 **L74** (11 hits); R6j-F02 **L75** (10 hits); `nfr-source-cell-list` 17 hits; KEEP REJECT **L687** |
| 7 | APPLY notes authentic | **PASS** | §2 |

**Overturns?** **n** — [verify_1-rerun-11.md](verify_1-rerun-11.md) correctly sustained R6k-F01 MED on pre-APPLY pin (0 hits for `coverage-matrix-req-cell-list` at that SHA). APPLY added the missing contract; review/verify_1 are not overturned.

---

## 4. Freeze line cites (post-APPLY, native read)

| Surface | Line | Confirmed content (abridged) |
|---------|------|------------------------------|
| Locked-contract grammar | **L76** | Named `coverage-matrix-req-cell-list` (`, `; atoms `REQ-[0-9]{2}`); matrix AC-cell exact-one; matrix↔Functional edge-set equality FAIL closed; PASS/FAIL fixtures |
| Locked-contract Step 8/XART/QC-8 bind | **L77** | Bind same parser/equality to Step 8, QC-8, `review-cross-artifact`; malformed staged matrix cannot install |
| ID scheme | **L206** | Coverage Matrix named grammar + edge-set FAIL closed under R6k-F01 |
| Target `## Coverage Matrix` | **L282** | Column-level AC/REQ grammar + edge-set equality + fixtures (`REQ-01, REQ-02` PASS; `REQ-01,REQ-02` FAIL) |
| Wave 1 template assert | **L345** | Matrix `AC-01` + `coverage-matrix-req-cell-list` example `REQ-01, REQ-02`; `REQ-01,REQ-02` FAIL |
| Wave 1 parser fixture | **L346** | Parse `coverage-matrix-req-cell-list`; edge-set equality with Functional rows |
| Wave 2 inherited pins | **L401** | `R6k-F01` |
| QC-8 (`review-requirements`) | **L412** | Grammar + edge-set; `REQ-F70` mismatch **FAIL** (not advisory) |
| XART (`review-cross-artifact`) | **L413** | Same parser; edge-set before orphan/coverage; malformed matrix cannot install |
| Wave 2 string test | **L419**, **L422** | `coverage-matrix-req-cell-list` in `rg` + QC-string Name |
| Wave 3 inherited pins | **L433** | `R6k-F01` Step 8 / XART / QC-8 |
| Step 8 work | **L443** | Serialize+parse + edge-set FAIL before install |
| Compiler verify | **L451**, **L473** | Contains named grammar; mint/serialize/XART fixtures |
| Wave 6 inherited pins | **L550** | `R6k-F01` |
| Wave 6 behavioral | **L576** | Multi-REQ PASS; delimiter aliases FAIL; wrong-pair FAIL; no-install |
| Risks | **L627** | Coverage Matrix REQ list / edge-set underspecified → R6k-F01 closed |
| KEEP REJECT | **L687** | Two files; Clarify does not write SPEC; ingest stays |
| R6j-F01 (unchanged) | **L74** | Functional AC-cell cardinality Step 8/XART bind |
| R6j-F02 (unchanged) | **L75** | `nfr-source-cell-list` Step 8/XART bind |

---

## 5. Outcome

**PASS** — R6k-F01 APPLY landed as claimed on freeze twins SHA `bdb5c916f236875d8d046aaf506db2ec54347d42b4acc34080837f5f54bc6f94`.

- **Overturns?** **n**
- **APPLY landed:** **y**
- **Twins identical:** **y**
- Parent may record `--record-rung-review-outcome` after accepting this verify.
