# Rung 1/11 REVIEW — Router Subagent Surfaces freeze

| Field | Value |
|---|---|
| Phase | `rung_N_review` (REVIEW-ONLY) — `/silver:review-fix-ladder`, not clarify |
| Original launch | `opencode-go/minimax-m3` via Pi |
| Launch failure | OmniRoute **401 Missing API key** ×2 |
| Reviewer | **Cursor Grok 4.6 High** substitute (RFL launch-policy). Not Pi. Not Extra High. Not Fast. |
| Freeze | `.planning/router_subagent_surfaces_85bf9f09.plan.md` and `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` |
| SHA-256 seen | `495a30c1d89292581169cfc8651f44ace17f8d667f1c1ab6fe0fe16c93cb158d` |
| Size | 620856 bytes (both copies) |
| Copies | Byte-identical |
| Freeze edited? | **No** |
| Graphify | CLI `graphify query` (MCP namespace `user-graphify` unavailable at review time). Oriented on freeze node + prior RFL receipts. |

Line cites are from the SHA-pinned freeze bytes (not lean-ctx compressed outline). KEEP REJECT / Q1–Q3 were not reopened.

## Verdict

**NOT CLEAN**

| Severity | Count |
|---|---|
| HIGH | 1 |
| MED | 4 |
| LOW | 1 |
| NIT | 2 |

Part A (quality-order core) then Part B **sequencing** is locked and consistent. The freeze is **not** ready to treat as internally unique/canonical on the AM-first/K/L lock, coverage inventory, or GST YAML ownership.

---

## Part A — quality-order core

YAML Part A todos (all `pending`): `execution-registry`, `capability-contract`, `nested-orchestration`, `authorizer-trust`, `nested-quality-loops`, `fast-short-quality-order`.

**What holds**

- Frontmatter, [§5.2](#52-ship-sequence) (freeze L3287–L3297), WS2 (L3476), and WS4 (L3584) all say: Part A runtime lands first; Part B **invokes** it; do not stub the role loop / composition-Val / I/A/Verification / Process-final Val / FAST Executor → Verifier → Validator.
- Usable-after set is explicit (L3291): WS1 catalog emit + WS3 admission/spawn/Authorizer + WS4 `nested-quality-loops` + `fast-short-quality-order`. Named tests: `tests/hooks/test-orchestrator-quality-loops.sh`, `tests/scripts/test-sb-fast.sh`.
- FAST = classified-trivial, not a Job, short order Executor → Verifier → Validator is consistent across glossary (L141), LS-fast-short-order (L784–L793), KR-fast-overlay (L915), Q1 (L4095–L4106). Not reopened.
- Six roles / five preference keys / Authorizer-not-a-key is consistent (glossary L143/L156, FR-03, KR-authorizer-not-pref, LS-ladder-parallel).

**Part A gaps that leak into core runtime**

The AM-first/K/L lock (HIGH F-01) sits on the FAST thin-capture path **and** Job K/L. FAST short-order is Part A (`fast-short-quality-order`). Drifted copies can mis-implement Part A FAST after Validator. GST-01 (MED F-05) is in the MVP slice and Part A Job path (Jobs appear on GST; FAST must not) but has no YAML todo.

---

## Part B — remaining capabilities

YAML Part B todos match Appendix B (33/33 ids). WS2/WS4/WS6/WS7 banners that exist correctly say Part B must invoke Part A. No KEEP REJECT reopen. Omni absorbed under existing `/sb:agent-*` / five-tool / init; no public `/sb:agent-omni`; no `sb:agent-wrap`; no `/sb:multi-ai-task` alias — consistent where sampled.

Gaps: Appendix C inventory incomplete vs Appendix B (MED F-03); §5.4 “also map” sentence omits Part A todo ids (LOW F-06, mitigated by Appendix B).

---

## Findings

### F-01 HIGH — AM-first / K/L lock exists in four drifted copies

Appendix F (L4300) requires **exactly one occurrence** of each remaining TOC heading. The freeze has **four** AM-first headings, three of them identical titles:

| Line | Heading |
|---|---|
| 1384 | `#### Same leaf, ordered effects (AM-first, mechanical)` (catalog/FAST overlay) |
| 2276 | same title (ordinary-delivery) |
| 2380 | same title (FAST/K/L cluster) |
| 2496 | `#### Same leaf, ordered effects (AM-first, mechanical — not hoping the agent also saved AM)` |

TOC already points at GFM suffixes `-1` / `-2` (L250, L254) plus the unsuffixed and the long title (L207, L260).

The bodies have **drifted**, so this is not a harmless repeat:

1. **Promote path** — L1386 writes monthly files directly; L2278/L2382 add “via the K/L mechanism”; L2382 also forbids dual-write of the same insight as git-tracked AM markdown **and** a K/L file; L1386 lacks that dual-write sentence.
2. **Thin-capture vs FAST Ver/Val** — L1393: thin capture must not “run Advisor/Board/Val/Ver/A”. L2285: must not run Advisor/Board/A-loop because “short-order Verifier and Validator **already ran** on the FAST leaf product before this deny-all”. L1393 can be read as skipping FAST Ver/Val, which contradicts LS-fast-short-order (L788) and Q1 (L4103).
3. **Job synthesize mixed into FAST section** — L1396 requires Advisor to synthesize new AFs/WFs when static WFs cannot cover intent. Adjacent copy (L2286–L2288) stays on classified-trivial remint / fail-closed reclassify. Implementers cannot tell whether synthesize is in-scope for this leaf.
4. **Fourth copy** (L2498–L2514) restates AM-first as numbered (1)(2)(3) and splits fail-closed / not-opted-in into new headings, omitting the thin-capture GST / `original_intent_hash` bullets present at L1393 / L2285.

Canonical lock text is supposed to live once (How to read, L132: live-spec in §2.7, KEEP REJECT in §3.3; pointers elsewhere). These four `####` blocks are lock-shaped, not pointers.

**Why HIGH:** Part A FAST thin-capture and Job K/L provenance are implementable from the wrong copy. Appendix F self-check fails.

---

### F-02 MED — Broken TOC anchor for `/sb:agent-*` cwd heading

TOC L222:

`[#sbagent-runs-with-cwd-primary-project-root-nested-profile]`

Heading L1751:

`#### **`/sb:agent-*`** runs with cwd = primary project root. Nested profile`

GFM punctuation strip of that heading yields `sbagent--runs-with-cwd-primary-project-root-nested-profile` (hyphen retained from `agent-*`, then another hyphen before `runs`). The TOC target drops one hyphen. Internal-link scan: 269 anchors; this is the only non-suffix miss besides the intentional GFM `-1`/`-2` duplicates.

Shared-state cwd for `/sb:agent-*` is a real lock (nested_executor, primary root). Broken TOC is a freeze-nav defect, not a missing spec — the body at L1751–L1755 is present.

---

### F-03 MED — Appendix C inventory incomplete vs Appendix B / §5.4

LS-plan-executed-coverage (L630) requires every YAML todo + WS0–WS8 + live-spec MUST mapped to a named test. Appendix B (L4147–L4181) maps all **33** YAML ids.

Appendix C (L4185–L4240) **omits** three paths that Appendix B and/or §5.4 L3751 name:

- `tests/scripts/test-sb-autonomous-e2e-order.sh` (YAML `autonomous-e2e-order`)
- `tests/scripts/test-recommended-tools-policy.sh` (YAML `omni-agent-opt-in-schema`)
- `tests/scripts/test-silver-doctor.sh` (YAML `omni-agent-doctor`; also cited in L3751)

Appendix C is the freeze’s named-test inventory. A green App B row that is absent from App C is a completeness miss for the coverage MUST.

---

### F-04 MED — VAL/TST-RFL “preserve” ranges contradict IDs actually in this freeze

L3944:

> Preserve retained `VAL/TST-RFL-001..007`, `101..118`, `201..205`, `301..306`, `401..405`, `501..506`, `601..626`, and `900`.

Appendix C L4242:

> Historical RFL coverage IDs present in this freeze: `VAL/TST-RFL-001` and `VAL/TST-RFL-601` through `VAL/TST-RFL-626`

IDs actually occurring as `VAL/TST-RFL-N` in the freeze body: **001, 601–626** only (27 unique). Missing from body vs the preserve list: `002–007`, `101–118`, `201–205`, `301–306`, `401–405`, `501–506`, **`900`**.

`TST-RFL-900` / `VAL-RFL-900` appear once at L3785 as bootstrap pins (`BOOT-RFL-001`), not as `VAL/TST-RFL-900` in the preserve sense. L4242 does not mention 900.

Implementers cannot tell whether 001–007 / 101+ are in-scope retained tests or stale range prose. Conflicts with LS-plan-executed “do not invent a second coverage bar” (L634) if those IDs are still a ship gate with no freeze citations.

---

### F-05 MED — GST-01 helper has no YAML todo / workstream banner

Goals + MVP slice require GST-01 (L351, L433–L438). PRD names the writer (L514): `hooks/lib/global-status-projector.sh`, same helper class as `hooks/lib/wbs-projector.sh`. FAST must not hit GST (locked, consistent).

YAML `nested-orchestration` names spawn-proxy, extra worktrees, **WBS projector** — not GST. No YAML id contains GST / global-status. WS2/WS3/WS4 banners sampled do not own `global-status-projector.sh`. WS7 (L3721) lists GST-01 as an MVP **acceptance ID**, which is docs/Doctor/site WS, not the projector runtime.

WBS exclusivity is KEEP REJECT (KR-projector-exclusive). GST is specified as a sibling exclusive helper but is not in the YAML → WS → named-test spine that LS-plan-executed-coverage requires. VAL/TST-RFL-621 exists in PRD (L541) and §5.4 (L3905) but is not a YAML todo.

---

### F-06 LOW — WS1 and WS3 omit the Part A prereq banner

WS2 (L3476) and WS4 (L3584 / L3598 / L3607) label Part A vs Part B. WS1 (L3327) and WS3 (L3517) jump straight to red tests / helpers. Canonical order still lives in YAML + §5.2 + LS-ship-sequence (L3285–L3308). Risk is numbered-WS reading (WS2 before WS4) despite YAML Part A-then-B. Mitigated, not missing.

---

### F-07 NIT — GFM auto-suffix TOC links for duplicate headings

L250 / L254 `#same-leaf-ordered-effects-am-first-mechanical-1` and `-2` match GitHub duplicate-heading suffixes. Cursor plan preview may not. Root cause is F-01 (duplicates should not exist). Not a separate lock.

---

### F-08 NIT — Duplicate `#### VAL/TST-RFL-*` headings

Same test-id headings appear in PRD and §5.4 (e.g. VAL/TST-RFL-621 at L541 and L3905; also 601, 604, 615, 623–626). Bodies are related, not always identical (621 PRD vs coverage-map). Appendix F uniqueness fails here too, but these are coverage pointers more than competing MUSTs. Do not treat as a second HIGH.

---

## Consistency checks (no finding)

- Copies SHA-match; Appendix F L4307 copy rule holds **today**.
- YAML 33 pending = 23 + 3 clarify + 5 omni + 1 autonomous-e2e + 1 ladder-parallel-compose (frontmatter L9–L10, Q-block L4093). Appendix B ids match YAML 1:1.
- Public prefix `/sb` only; dual `/silver` forbidden (KR-no-dual-silver). Historical `silver-new-workflow` paths are labeled rename, not a dual window.
- Q1–Q3 marked **decided**; KEEP REJECT closed except the already-absorbed FAST short-order amendment in KR-fast-overlay. Not reopened.
- One mermaid block (L1444). No second integrity checklist.
- Heading hierarchy: no `hN` → `hN+2` jumps.

## Completeness / broken-ref summary

| Check | Result |
|---|---|
| Internal markdown links | 269; **1 real miss** (F-02); 2 GFM suffix links (F-07 / F-01) |
| YAML vs Appendix B | 33 = 33 |
| LS-* catalog | 13 headings LS-plan-executed-coverage … LS-autonomous-e2e-order |
| KR-* catalog | 18 headings KR-catalog-generated … KR-kr-18 |
| Part A then Part B order | Locked; WS1/WS3 banner gap only (F-06) |

## Out of scope (not scored)

Product implementation, YAML todo execution, reopening KEEP REJECT / Q1–Q3, clarify, repo-wide code, Omni origin file (provenance SHA `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26` only).

## Return

- Path: `.planning/rfl-router-subagent-surfaces-85bf9f09-final-review/rung-01-opencode-go-minimax-m3/review.md`
- **NOT CLEAN**
- HIGH **1** / MED **4** / LOW **1** / NIT **2**
- SHA `495a30c1d89292581169cfc8651f44ace17f8d667f1c1ab6fe0fe16c93cb158d`
