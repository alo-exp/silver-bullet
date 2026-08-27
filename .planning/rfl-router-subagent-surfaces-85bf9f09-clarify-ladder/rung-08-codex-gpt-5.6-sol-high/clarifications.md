# Rung 8 Clarification Report — `codex/gpt-5.6-sol-high`

## Verification scope

- Read-only independent review of `.planning/router_subagent_surfaces_85bf9f09.plan.md`; no replay of rungs 1–7.
- Verified bytes: **622100**.
- Verified SHA-256: **`43d03cf12e39448b8a28e032110af7aa56e8924374fbe98cea175dfa4bc16192`**.
- Branch remained **`main`**. No checkout, commit, product implementation, or plan edit was performed.

## Findings

### CLARIFY-R8-F1 — BLOCKER — §5.4 coverage prose is still structurally corrupted

**Evidence:** The newly completed heading and TOC entry are present (`§5.4`, lines 3811–3815), but the first paragraph under `#### Plan-executed coverage (cite Goals live-spec MUST)` is not a complete coverage requirement. At line 3824, the sentence

> `every delta this plan executes MUST have tests covering 100% of those deltas (every new/changed branch, fail-closed path, KEEP REJECT — see [KR-kr-16](#kr-kr-16)`

is immediately spliced into an unrelated helper-root rule:

> `Both helpers take primary_checkout as the sole write root ...`

Lines 3825–3841 then continue spawn-proxy, envelope, primary-checkout, graphify-gate, and worktree-gate requirements rather than completing the parenthetical coverage statement. The same helper-root requirement already exists coherently elsewhere (for example lines 895, 1003, 1551, 1600, and 3596), so this is not merely concise cross-reference prose. The parenthesis opened at line 3824 is never closed in this section, and the required coverage sentence loses its intended named mapping/ship-blocking conclusion.

**Why this matters:** §5.4 is the implementation acceptance surface. As frozen, an implementer cannot tell where the coverage mandate ends and an unrelated primary-checkout test block begins; parsers/renderers also receive malformed inline structure.

**Proposed owner edit (do not apply here):** Restore the complete plan-executed-coverage paragraph after the heading, including the full scope and completion/green blocking rule, then move or retain the primary-checkout/helper test material under its proper existing subsection without duplicating it. At minimum, close the `KR-kr-16` reference/parenthetical and make the boundary explicit.

### CLARIFY-R8-F2 — BLOCKER — post-Val K/L producer ownership contradicts the canonical LS lock

**Canonical lock:** `LS-post-val-kl` (lines 770–781) explicitly says both K/L capture and key-doc revision are **Executor work**, “**not** the Advisor `knowledge_postwrite` leaf as the producer,” followed by Advisor review and Verifier verification. The YAML pointer (`post-val-kl-docs`, line 55), glossary (line 162), ship sequence (line 645), and WS4 material also call this the post-Val **Executor** hop.

**Contradictory design/runtime text:**

- Architecture role text at line 1102 assigns “Process-final K/L post-write” to the deny-all `knowledge_postwrite` Advisor leaf.
- Detailed procedure Step 11 at lines 2544–2549 says the owner is an Authorizer-admitted deny-all Advisor leaf and exempts that leaf from recursive I/A/V/Val.
- `VAL/TST-RFL-613` at lines 3915–3917 again says the post-verify owner is that Advisor leaf.

Those statements conflict with the canonical requirement that an Executor produce both artifacts and that the result receive ordinary Advisor + Verifier review. They would cause two incompatible implementations and tests.

**Proposed owner edit (do not apply here):** Make §4, §5.1 Step 11, and `VAL/TST-RFL-613` conform to `LS-post-val-kl`: Executor produces the K/L and key-doc artifacts through the named mechanical helper/projector path; Advisor reviews; Verifier verifies; no second Process-final Val. If `knowledge_postwrite` remains as a privileged mechanical persistence helper, explicitly distinguish it from the artifact-producing role and state that it cannot replace the Executor/A/V hop. Keep FAST's separate thin-capture exception unchanged.

### CLARIFY-R8-F3 — MAJOR — the five-tool/project-root TOC entry and heading are truncated

**Evidence:**

- TOC line 284 ends with `scripts/lib/reco` and links to a correspondingly truncated anchor.
- The source heading at line 2947 is also truncated: `#### Callers — every RT_PROJECT_ROOT assignment under scripts/ (including scripts/lib/reco`.

The following body starts with the intended full caller inventory, including `scripts/lib/recommended-tools/`, so the truncation is editorial rather than intentional terminology.

**Proposed owner edit (do not apply here):** Complete the source heading (for example, “Callers — every `RT_PROJECT_ROOT` assignment under `scripts/` (including `scripts/lib/recommended-tools/`)”) and regenerate/fix the matching TOC anchor.

### CLARIFY-R8-F4 — MAJOR — numbered procedure headings remain editorially truncated, including Step 11's acceptance contract

**Evidence:** Five §5.1 headings end in literal ellipses rather than complete labels:

- line 2480 — Step 2: `composition-ap…`
- line 2494 — Step 5: `A-clean ro…`
- line 2502 — Step 7: `V-clean eno…`
- line 2528 — Step 10: `entire output…`
- line 2544 — Step 11: ``kl_post_write_no_i…``

Step 11 is especially material because the cut occurs inside the durable receipt name; the next line identifies the full receipt as `kl_post_write_no_insights`. These are headings in the normative execution procedure, not historical receipts.

**Proposed owner edit (do not apply here):** Expand each heading from its immediately following body text and update the TOC if these headings are intended to appear there. In particular, spell out Step 11's `kl_post_write_no_insights` receipt.

### CLARIFY-R8-F5 — MINOR — four other normative headings are truncated

**Evidence:**

- line 4064: ERR-trap heading ends at ``hooks/agen``.
- line 4113: freeze Step 1 heading ends at `new sour`.
- line 4117: freeze Step 2 heading ends at ``committed_before_fen``.
- line 4064 also has an unmatched inline-code delimiter due to truncation.

The paragraphs beneath the headings contain enough information to restore full titles.

**Proposed owner edit (do not apply here):** Complete those headings and refresh any affected TOC anchors.

## Constraint audit

| Constraint | Status | Evidence / note |
|---|---|---|
| YAML has 33 todos, all `pending` | **INTACT** | Parsed 33 todo ids and 33 `status: pending`; Appendix B has a one-to-one 33-row todo map. |
| FAST is not a Job | **INTACT** | Repeated canonical lock; Q1 remains decided. |
| FAST is not legal `/sb:ladder\|parallel <route>` | **INTACT** | `LS-ladder-parallel` explicitly fail-closes `/sb:fast` as `<route>` (line 749). |
| One-level compose | **INTACT** | Ladder XOR Parallel; nesting in either direction fail-closes (line 750). |
| Authorizer is not a preference key | **INTACT** | Explicit in `LS-ladder-parallel`, Part A, WS6, and locked decisions. |
| No `sb:agent-wrap` | **INTACT, with wording cleanup advisable** | No public/defined `sb:agent-wrap`; locked decisions forbid it. One `/sb:new-workflow` sentence still says “agent-wrap family” descriptively (line 1357), but binds it to existing `WF-AGENT-DELEGATE-ENTRY` / `AF-AGENT-DELEGATE`; this is not a route creation. Prefer “agent-delegate family” to prevent implementation drift. |
| No `/sb:multi-ai-task` | **INTACT** | Explicit retirement with no alias; Ladder/Parallel absorb retained behavior. |
| Omni absorbed with origin SHA `745c…c26` | **INTACT** | Correct SHA and absorbed WS6/WS2/WS7 scope repeated; no new numbered WS or A/B/C. |
| KEEP REJECT closed | **INTACT** | §6 explicitly closes it except the already locked Q1 amendment. |
| Q1–Q3 locked | **INTACT** | §6 marks all three decided; no unresolved fork found. |
| Part A then Part B quality-order wave reorder | **INTACT** | YAML order and §5.2 both require Part A runtime before Part B consumers. |
| Public `/sb` only | **INTACT** | Remaining `/silver:` strings are historical/current-state migration, retirement, provenance, negative tests, or explicit conversion instructions—not retained public routes. |

## AskQuestion

None. The findings are internal consistency/editorial repairs whose intended direction is already determined by canonical locks; no human-required A/B/C product fork was found.
