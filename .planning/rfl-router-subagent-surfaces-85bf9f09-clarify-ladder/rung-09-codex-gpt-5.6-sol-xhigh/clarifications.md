# Rung 09 Clarifications — `codex/gpt-5.6-sol-xhigh`

## Read-only verification

- Independently re-read the canonical freeze at `.planning/router_subagent_surfaces_85bf9f09.plan.md`.
- SHA-256: `babfc2d55bdce116cbd4ddda9ee0d265ad71bf38de5aecf0e0b0186e65dfed41`; size: `622457` bytes.
- The repo freeze and `/Users/shafqat/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` are byte-identical.
- Branch remained `main`. No freeze copy was edited. No checkout/switch, commit, or product implementation was performed.

## Findings

### R9-F1 — BLOCKER — LS-post-val-kl producer lock is still contradicted by executable role/admission/test text

**Evidence**

- Canonical `LS-post-val-kl` says both K/L capture and key-doc revision are **Executor work**, explicitly “not the Advisor `knowledge_postwrite` leaf as the producer” (lines 772–779, especially 775).
- The concise role summary agrees: Advisor says `knowledge_postwrite` is not the producer (line 1102); WS4 agrees (line 3670).
- But executable role/admission/blocker/acceptance text still assigns that work to an Advisor leaf and forbids the Executor:
  - Orchestrator role text calls KLW-01 post-write “the deny-all Advisor `knowledge_postwrite` leaf” (line 1094).
  - Executor “Must not” says it must not own KLW-01 and that the write belongs to that Advisor leaf (line 1112).
  - Mandatory Job children still include “the deny-all Advisor `knowledge_postwrite` leaf” (line 2170).
  - `blocked_knowledge_postwrite` requires direct K/L writes to go through that Advisor leaf and says an ordinary Executor must not author K/L (line 3101).
  - `VAL/TST-RFL-613` still defines the post-verify owner as that Advisor leaf and forbids the ordinary Executor (lines 3916–3918).
- The architecture mermaid also ends `Val -> K/L post-write -> projector` (lines 1493–1502), omitting the locked post-Val **Executor → Advisor review → Verifier verification** hop and its key-doc branch. The identical second mermaid repeats that stale path (lines 1749–1758).

**Why this blocks implementation**

An implementer cannot satisfy the canonical producer lock and simultaneously satisfy the stated Executor deny, mandatory-child topology, blocker predicate, and named acceptance text. This is a direct contradiction in enforcement surfaces, not merely stale terminology.

**Proposed finding-only repair**

Conform every downstream surface to `LS-post-val-kl`: make the Authorizer-admitted **Executor** the producer of both K/L/no-insight and key-doc outputs, then ordinary Advisor review and Verifier verification; retain named-helper/no-raw-write/AM provenance fencing as mechanical constraints without making Advisor the producer. Update the mermaid and `VAL/TST-RFL-613`/KLW-01 assertions to cover producer identity, A/V, key-doc checking, no second Process-final Val, and `scope_complete` only after the hop passes.

No human fork is needed: the user supplied the canonical answer.

### R9-F2 — HIGH — FAST WBS/ledger topology contradicts the locked short order

**Evidence**

- Canonical `LS-fast-short-order` requires **Executor → Verifier → Validator → thin capture** (lines 787–795).
- The FAST mermaid and admission text agree (lines 1450–1456 and 2174).
- But FAST status topology omits Verifier and Validator:
  - “required WBS content” is only classify + dispatch + FAST Executor/Q&A leaf + thin capture and simultaneously says “no quality-order roles” (line 1624).
  - “FAST WBS” is again defined as classify + dispatch + FAST leaf + thin-capture only (line 2431).
  - The classified-trivial terminal says “FAST leaf complete plus thin-capture receipt” rather than FAST Executor, Verifier, and Validator complete plus capture (line 1583).
- Therefore the required short-order hops can execute without appearing in the required status artifact, and the ledger can reach `scope_complete` without explicitly requiring their receipts.

**Why this matters**

This under-specifies and contradicts enforcement of the locked Q1 answer. It can produce a WBS/terminal implementation that silently skips the very FAST Verifier/Validator gates the freeze says are mandatory.

**Proposed finding-only repair**

Define the non-Job FAST status path consistently as classify → catalog dispatch → FAST Executor → FAST Verifier → FAST Validator → thin capture. Keep it a thin/non-Job ledger (no Job WBS, GST, Advisor, Process-final Val, or `original_intent_hash`), but require all three short-order completion receipts before capture/`scope_complete`. Replace “no quality-order roles” with the intended “no six-role Job order / no Job-only roles.”

### R9-F3 — HIGH — the freeze violates its own no-duplicate-mermaid integrity invariant

**Evidence**

- The document-integrity contract says there must be “No ... duplicate mermaid block” (line 4369).
- There are two `mermaid` blocks, at lines 1447–1503 and 1703–1759.
- Their bodies are byte-identical (same SHA-256 `dc99676be03ed61ba28dabbdeaa55c5aaa28d95347a9aea3b0de0809b6b04507`).
- The prose claims the second diagram is a complementary WBS/spawn sketch, not a copy (lines 1505 and 1701), but the second is exactly the Process quality-order diagram.

**Why this matters**

The freeze fails its explicit self-integrity condition and lacks the promised WBS/spawn visualization at the location implementers are told to consult.

**Proposed finding-only repair**

Replace the second copy with the promised WBS/spawn/worktree diagram, or remove it and correct every claim that a complementary second diagram exists. Preserve the first Process quality-order diagram, updated for R9-F1.

### R9-F4 — MEDIUM — the generated Table of Contents contains broken or orphaned fragment links

**Evidence**

The TOC appears to have normalized punctuation/underscores in ways GitHub heading fragments do not. Representative broken links include:

- `#25-non-functional-quality-attributes` vs heading `2.5 Non-functional / quality attributes` (TOC line 181; heading 598).
- `#26-success-metrics-mvp-vs-post-mvp` vs heading `2.6 Success metrics / MVP vs post-MVP` (TOC 182; heading 612).
- `#host-built-in-defaults-codex-claude-cursor` vs heading containing `Codex / Claude / Cursor` (TOC 199; heading 1240).
- `#classified-trivial-sbfast` vs heading `Classified-trivial / sb:fast` (TOC 210; heading 1540).
- `#43-wbs-projector-spawn-proxy-primary_checkout-extra-worktrees` and `#primary_checkout-write-root` retain underscores that heading slugs remove (TOC 211/213; headings 1576/1589).
- `#52-ship-sequence-ws0-ws0b-ws17-ws8-docs-release` does not preserve the multiple hyphens produced by spaces around arrows (TOC 288 and body links 134/649/2178; heading 3339).
- `#b-yaml-todo-test-ws-map` similarly differs from the arrow-bearing Appendix-B heading (TOC 336; heading 4209).
- `FAST carve-out ...` is a TOC entry (line 202) but is only an inline bullet at line 1275, not a heading, so no target exists.

A GitHub-style slug check found at least 22 broken entries inside the TOC and additional repeated broken body links to §5.2/§2.6.

**Why this matters**

The 622 KB freeze explicitly presents the TOC as the navigation surface. Broken fragments make canonical locks and implementation sections harder to reach and undermine the document-integrity claim.

**Proposed finding-only repair**

Regenerate the TOC with the renderer’s exact fragment algorithm (preserving duplicate-heading suffixes), turn intended inline TOC targets into actual headings or remove those entries, and add an automated local-fragment checker to the document-integrity test.

## Constraint audit

| Constraint | Status | Evidence / note |
|---|---|---|
| YAML: exactly 33 todos, all `pending` | **INTACT** | 33 `id` entries; 33 `status: pending`; no other status. |
| FAST not a Job | **INTACT** | Canonical/glossary/KEEP REJECT consistently preserve this. R9-F2 concerns omitted short-order status hops, not Job classification. |
| FAST not a legal compose route | **INTACT** | LS-ladder-parallel excludes FAST; one-level grammar rejects it. |
| One-level compose | **INTACT** | `/sb:ladder|parallel <route>` is one-level XOR and rejects nesting. |
| Authorizer not a preference key | **INTACT** | Exactly five role keys; Authorizer excluded and inherits Verifier weights. |
| No `sb:agent-wrap` | **INTACT** | Occurrences are prohibition/history/test assertions only; no legal alias/surface. |
| No `/sb:multi-ai-task` | **INTACT** | Occurrences require retirement/absence and no alias. |
| Omni absorbed with origin SHA `745c…c26` | **INTACT** | Same-ship WS6/WS2/WS7 slice is repeatedly bound to the supplied origin SHA. |
| KEEP REJECT closed | **INTACT** | §3.3 is canonical and §6 keeps it closed except locked Q1 amendment. |
| Q1–Q3 locked | **INTACT** | §6 labels all three decided and supplies no A/B/C fork. |
| Part A then Part B | **INTACT** | LS-ship-sequence, §5.2, YAML order, and workstream gate all enforce it. |
| LS-post-val-kl Executor producer | **BROKEN** | Canonical lock is correct, but role/admission/blocker/acceptance text still assigns production to Advisor; see R9-F1. |
| Public `/sb` only | **INTACT** | Public-prefix section and FR-11 forbid dual `/silver`; historical `/silver` references are migration/provenance/retirement text. |

## AskQuestion

None. The four findings are contradictions/editorial-integrity defects with answers already fixed by canonical locks. No A/B/C human fork is required.
