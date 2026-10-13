# Rung 10 — `claude/claude-opus-5-high` — `/silver:clarify --auto` (READ-ONLY reporter)

**Freeze:** `.planning/router_subagent_surfaces_85bf9f09.plan.md`
**SHA-256 verified:** `70606c7b8a8ac729be0f80407d50dd0ac6e0945f10a827f520ac0b2aed9d13f8` — MATCH
**Bytes:** 620492 — MATCH · **Lines:** 4316
**Second freeze copy** `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`: same SHA — **byte-identical (§F.integrity satisfied)**
**Ladder mirror** `freeze-current.plan.md.bak`: same SHA — MATCH
**Branch:** `main` (no checkout/switch, no commit, no edits to either freeze copy)
**Method:** independent re-read of the freeze bytes. Prior rung `clarifications.md` files were **not** read for content beyond confirming R9-F4 is the owner-deferred TOC item named in the brief.

**Verdict:** **NOT CLEAN** — 0 Blockers / 1 High / 2 Mediums / 3 Nits.
All named constraints are **INTACT**. Every finding below is an internal-consistency / editorial defect introduced by prior splice-and-repair rounds, not a lock regression. All are **findings only**; owner applies.

---

## Part 1 — Constraint conformance (all INTACT)

| # | Constraint | Status | Evidence |
|---|---|---|---|
| 1 | YAML 33 todos, all `pending` | **INTACT** | 33 `- id:` entries in frontmatter; `status: pending` count = 33, no other status value. Arithmetic reconciles at three sites: overview L10–L11 (23 + 3 + 5 + 1 + 1 = 33), L4102, L4192. |
| 2 | FAST not a Job | **INTACT** | L386, L783–L798 (LS-fast-short-order), L838 (spine step 5), L1275, L2376, L4110, L4115. No surface treats FAST as a Job or mints a Job WBS/GST row on it. |
| 3 | FAST not a legal compose route | **INTACT** | L159 Glossary "`/sb:fast` is not a legal `<route>`"; L877 Branches; L750 one-level compose rule. |
| 4 | One-level compose | **INTACT** | L750 "ladder XOR parallel; nested `/sb:ladder /sb:parallel <route>` (or the reverse) **fail-closes**"; L474 and L4270 both state one-level compose identically. |
| 5 | Authorizer not a pref key | **INTACT** | L34, L82 (YAML); L156 Glossary "five preference keys … Authorizer excluded"; L447 non-goals; L724; L1080; L3692 "Authorizer not a key (inherits Verifier tuple)"; KR-authorizer-not-pref L956. |
| 6 | No `sb:agent-wrap` | **INTACT as a lock**, but one contradicting sentence survives | L142, L482 (`FORBIDDEN … Do not alias`), L586 FR-07, L819, L868, L970, L986, L1282, L2857 all forbid it. **However L1407 asserts "`sb:agent-wrap` is an alias, not a second WF"** — see **F1 (High)**. The lock itself is not reopened; the residue is a stale round-22 phrasing. |
| 7 | No `/sb:multi-ai-task` | **INTACT** | L477 retired, no alias; L750, L764, L806, L807, L849, L3486. `/silver:multi-ai-task` appears 13× and every occurrence is a retire/forbid/test-must-fail statement, never a live public route. |
| 8 | Omni absorbed; origin SHA `745c7f41…9d13f8`→`…425c2c26` | **INTACT** | Origin SHA `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26` present 22×, always provenance-only (L14–L15 YAML, L488, L824, L4133). No public `/sb:agent-omni` (L91, L100, L160, L447, L494, L868, L2857, L3302). Thin `scripts/agent-omni-delegate.sh`, does not require Pi. |
| 9 | KEEP REJECT closed | **INTACT** | §3.3 L906–L988: 18 `KR-*` subsections present; L986 enumerates the named themes; L4100 "KEEP REJECT items … are **closed**. Do not reopen them except the Q1 amendment to KR-fast-overlay". |
| 10 | Q1–Q3 locked | **INTACT** | L4104–L4129. Q1 FAST redefinition (user did not pick A/B/C); Q2 decided (A); Q3 decided. All three carry the `— **decided**` marker. |
| 11 | Part A then Part B locked | **INTACT** | §5.2 Part A (L3290–L3296) / Part B (L3298–L3300); WS1 L3473, WS2 L3479, WS4 L3587 / L3604 / L3613. Every YAML todo is tagged `Part A prereq` / `Part A` / `Part B`. Appendix B carries a `Part` column with A prereq / **A core** / B / hygiene / coverage / docs. |
| 12 | LS-post-val-kl: **Executor** produces post-Val K/L (not Advisor `knowledge_postwrite` as producer) | **INTACT on every normative producer surface** | Conformant: L775 (canonical), L1094 (Orchestrator must-not), L1102 (Advisor owns), L1112 (Executor must-not), L2115 (control-plane children), L2493 (Step 11 Owner), L3046 (row-9 blocker), L3597 (WS4), L3615, L3861 (VAL/TST-RFL-613), L862/L23 (spine step 23 "Executor produces; Advisor reviews; Verifier verifies"), L1494–L1504 (mermaid `KL[Post-Val Executor K/L + key-doc]` → `AdvR` → `VerK`). **Two non-producer residues remain** — see **F2 (Medium)**. |
| 13 | FAST short-order status path = Executor + Verifier + Validator + thin capture | **INTACT** | L409 (§2.2 Goals), L1626 (WBS required content, M3 terminal, omit → `blocked_progress_viz`), L2119 (Authorizer-admitted children), L2376 (FAST WBS enumeration), L1450–L1453 (mermaid FastI → FastVer → FastVal → FastCap). All four hops present on every status/WBS surface. |
| 14 | Public `/sb` only | **INTACT** | L1053 "Public identifiers are `sb` / `sb:` / `/sb` only"; KR-no-dual-silver L948. Residual `/silver:` tokens are historical/retire/provenance only, **except one** stale token — see **F5 (Nit)**. |

**Additional integrity assertions in §F (L4307–L4316), independently re-verified:**
exactly one YAML frontmatter block (2 `---` delimiters) ✓ · exactly 33 todos all `pending` ✓ · exactly one `#` title ✓ · exactly one `## How to read this document` ✓ · exactly one `## Table of contents` ✓ · no standalone Addendum headings ✓ · no duplicate migration subsection ✓ · no duplicate integrity checklist ✓ · **no duplicate mermaid block** ✓ (owner's rung-9 removal confirmed: exactly one ```` ```mermaid ```` fence, at L1447).

---

## Part 2 — Findings

### F1 — **HIGH** — L1407 still calls `sb:agent-wrap` an alias, directly contradicting the `FORBIDDEN … Do not alias` lock at L482

**Evidence**

L482 (§2.3 public surface inventory) and its Appendix D twin L4278:

> \| `sb:agent-wrap` \| **FORBIDDEN.** No public/catalog surface (KEEP REJECT). Do not alias; do not add `WF-SB-AGENT-WRAP`. \|

L142 (Glossary): "There is **no** `sb:agent-wrap`." · L586 (FR-07): "no `sb:agent-wrap`." · L819, L868, L970, L1282, L2857: all forbid, several explicitly citing KEEP REJECT.

L1407 (§4.2), however, reads:

> - **WS1 does not add those records** — it **dispatches shipped** `WF-AGENT-DELEGATE-ENTRY` / `AF-AGENT-DELEGATE` / `VL-AF-AGENT-DELEGATE` (public routes remain `/sb:agent-{cursor,codex,claude,opencode,pi}` as `nested_executor` leaves; **`sb:agent-wrap` is an alias, not a second WF**).

This is traceable to the round-22 Document-control cell (L4152), which recorded the finding as "do **not** add a second wrap; `sb:agent-wrap` is an alias" — phrasing that made sense only as "the *reason* we reject it is that it would merely alias the shipped wrap." The compressed restatement at L1407 inverts that into an affirmative statement that the alias **exists**, which is exactly what L482 forbids and what the brief lists as a hard constraint.

**Why this is High, not editorial**

L1407 is inside §4.2, the normative WS1 catalog-emit section. An implementer reading WS1 in isolation is told an alias is legitimate; an implementer reading §2.3/Appendix D is told aliasing is FORBIDDEN under KEEP REJECT. The two cannot both be executed. The lock is not reopened anywhere else, so this is a single-sentence repair, but it is a live normative contradiction rather than a presentation defect.

**Proposed patch (finding only — do not apply without owner accept)**

L1407, replace the parenthetical tail:

- from: `` `sb:agent-wrap` is an alias, not a second WF ``
- to: `` there is no `sb:agent-wrap` — neither a second WF nor an alias (KEEP REJECT; see §2.3 / Appendix D) ``

Leave the Document-control round-22 cell at L4152 untouched (append-only ledger; do not rewrite history — consistent with the round-33 n-1 lock on append-only logs).

---

### F2 — **MEDIUM** — two `knowledge_postwrite` surfaces still name the deny-all Advisor leaf as the K/L **producer**, contradicting the rung-9 LS-post-val-kl conformance pass

**Evidence**

Owner's rung-9 pass conformed the role table, admission, blocker row 9, VAL/TST-RFL-613, and the mermaid. Two surfaces in the §4.5 deny-all-leaf block were not swept:

**(a) L2554** — inside the deny-all leaf exemption block:

> - The KLW-01 post-write leaf **is this deny-all Advisor `knowledge_postwrite` spawn** (Jobs: AM-first `memory_save` then classify then promote AM → K/L with `am_id` provenance, or `kl_post_write_no_insights`; …)

This is a direct producer assignment to the Advisor leaf. It contradicts:
- L775 (canonical LS-post-val-kl): "**Both (1) and (2) are Executor work** … **not** the Advisor `knowledge_postwrite` leaf as the producer."
- L2493, only 61 lines earlier in the same §4.5 ordinary-delivery procedure: "**Owner:** Executor produces both artifacts … The deny-all Advisor `knowledge_postwrite` leaf is **not** the producer."
- L3046, L3597, L3861, L1094, L1102, L1112 — all state `knowledge_postwrite` is not the producer.

**(b) L2529** — in the "No direct K/L authorship" block:

> - Ordinary Executor must not own this write (would recurse another quality cycle).

Read against the conformed spec this is ambiguous-to-wrong. The lock is that the **Authorizer-admitted post-Val Executor hop** owns the write while the **ordinary delivery Executor** does not. L1112 states this precisely ("raw-Write K/L **outside** the Authorizer-admitted post-Val Executor hop") and L3862 likewise ("ordinary delivery Executor / Orchestrator / parent must not raw-Write K/L **except via** the admitted post-Val Executor hop"). L2529 as written, sitting two lines after L2527's "Orchestrator, ordinary Executor, and parent must not Write … except via this leaf", reads as a blanket Executor exclusion and supplies the stale rationale ("would recurse another quality cycle") that motivated the superseded Advisor-producer design.

**Note on L2551 (not a finding).** The deny-all *role* enumeration at L2551 legitimately lists `knowledge_postwrite` alongside `advisor` / `verifier` / `validator` / `defect_escalation`. Under the conformed spec the post-Val Executor hop is still Authorizer-admitted and still deny-all, and L775 confirms it carries the Executor tuple. The **role class** membership is fine; only the **producer identity** at L2554 is wrong. I flag this explicitly so the owner does not over-sweep L2551 and break the deny-all exemption.

**Proposed patch (finding only)**

L2554 — retarget producer identity while preserving the deny-all exemption and every effect ordering:

> - The KLW-01 post-write leaf is the **Authorizer-admitted post-Val Executor hop** ([LS-post-val-kl](#ls-post-val-kl); Executor `{ runtime, model, effort }` including `/sb:agent-*` pin; the deny-all Advisor `knowledge_postwrite` leaf is **not** the producer) — Jobs: AM-first `memory_save` then classify then promote AM → K/L with `am_id` provenance, or `kl_post_write_no_insights`; AM opted-in failure → `blocked_knowledge_postwrite`; AM not opted in → `kl_write_am_skipped`. It is deny-all and exempt from Advisor-plan handoff and recursive I/A/V/Val on its own output; ordinary Advisor review and Verifier verification of the hop product still apply per LS-post-val-kl. FAST thin capture is the same family after the FAST short-order Validator, not a second Job and not parent-authored insight text.

L2529 — narrow to the ordinary-delivery Executor:

> - The **ordinary delivery** Executor must not own this write outside the Authorizer-admitted post-Val Executor hop (a raw in-line K/L write would recurse another quality cycle); the admitted post-Val Executor hop **is** the producer ([LS-post-val-kl](#ls-post-val-kl)).

---

### F3 — **MEDIUM** — L1647 promises a second mermaid that no longer exists, and L2123 points the Job quality-order diagram at the wrong section

**Evidence**

The owner's rung-9 pass removed the duplicate Process quality-order sketch, leaving exactly one ```` ```mermaid ```` fence, at **L1447** (inside §4.2, which spans L1250–L1577). Two pointers were not updated:

**(a) L1647** (§4.3, immediately after the ```` ```text ```` ASCII WBS block that ends L1645):

> The following mermaid is the WBS/spawn sketch (complementary to the Proposed-architecture mermaid, not a duplicate of that quality-order diagram).

"The following mermaid" is followed by **no mermaid at all** — L1649 begins prose ("After Advisor plan and plan-time Validation-loop …"). This is the dangling half of the removal. It also re-asserts the "two complementary mermaids" claim from the round-37 n-4 ledger entry, which the rung-9 removal deliberately retired. Note L1507 was correctly updated and now reads "The Proposed-architecture mermaid is the **single** Process quality-order sketch. WBS, spawn-proxy, worktree, and live-ledger rules in this section are specified **in prose** (no second mermaid copy)" — so L1647 contradicts L1507 as well as the bytes.

**(b) L2123** (§4.5 Quality order):

> … **Implementing wave:** Part A ([§5.2](#52-ship-sequence-ws0-ws0b-ws17-ws8-docs-release)) — later workstreams invoke that runtime. **Diagram: mermaid in §4.2.**

The pointer target is technically correct (L1447 *is* in §4.2) but it is a bare prose reference with no anchor, unlike every other cross-reference in the document, and it was written when there were two diagrams and the reader needed disambiguation. With one diagram remaining it should be an anchored link so §4.5 readers land on it.

**Proposed patch (finding only)**

L1647 — replace the dangling promise with an accurate prose pointer:

> The ASCII block above is the WBS/spawn status sketch. WBS, spawn-proxy, worktree, and live-ledger rules in this section are specified in prose; the single Process quality-order mermaid lives in [§4.2](#42-process-router-sb-catalog-generation-fast-vs-job) and is not duplicated here.

L2123 — anchor the pointer:

> Diagram: the single Process quality-order mermaid in [§4.2](#42-process-router-sb-catalog-generation-fast-vs-job).

**Human fork — I am not guessing which the owner wants.** F3(a) admits two defensible resolutions and the choice is a content decision, not an editorial one:

- **A.** Repair the pointer only (patch above). The document keeps one diagram; §4.3 stays prose. Consistent with L1507 and with the rung-9 intent as stated in my brief ("removed duplicate mermaid (one Process quality-order sketch)").
- **B.** Author the genuinely complementary WBS/spawn diagram that L1647 promises (the round-37 n-4 "two complementary mermaids" position: Proposed architecture vs WBS live ledger), restoring a second, non-duplicate mermaid.
- **C.** Defer with R9-F4 (TOC regen) as one combined editorial pass, since both are presentation-layer and neither is a lock.

I recommend **A** on the evidence — L1507 was affirmatively rewritten to say "no second mermaid copy", which reads as a deliberate owner decision rather than an oversight — but this is an **AskQuestion A/B/C** for the owner, not a call I will make.

---

### F4 — **NIT** — L3589 is an empty-body duplicate heading shadowing L3592

**Evidence** (§5.3 WS4, L3587–L3594)

```
3589: #### MVP: red SM tests in `tests/hooks/test-orchestrator-quality-loops.sh` with a fake Executor
3590:
3591:
3592: #### MVP quality-loop red tests
3593:
3594: - MVP: red SM tests in `tests/hooks/test-orchestrator-quality-loops.sh` with a fake Executor proving …
```

L3589 has no body: the next non-blank line is another heading. It is a first-sentence-promoted-to-heading artifact of the splice rounds — the promoted text is verbatim the opening of the L3594 bullet that already sits under the correct heading L3592. L3592 is the intended section title.

This is one of a family. The same empty-body-heading shape appears at **L1963** (`blocked_launch_prompt_spec`, shadowing L1966 "Proxy request record fields"), **L2410** (`blocked_knowledge_preread`, shadowing L2413 "Knowledge/Learnings pre-read"), **L3524** (`VAL/TST-RFL-626`, shadowing L3527 "Admission/scheduler/callback implementation"), **L3686** (`blocked_plan_of_action_review`, shadowing L3689 "Five preference keys evidence"), and **L3700** (`Per-child SB_WORKTREE_CWD is not required in process env, if five-tool`, shadowing L3703 "Per-child worktree cwd vs primary bind").

The L1963 / L2410 / L3524 / L3686 cases are arguably deliberate — a bare blocker-id or test-id heading immediately preceding the section that specifies it is a usable index affordance, and several are TOC-referenced. **L3589 and L3700 are not** in that class: both are truncated mid-sentence prose, both duplicate the first bullet of the section they shadow, and neither is a stable id. I flag only those two as defects; the four id-style headings I record as observed-but-not-a-finding so the owner does not over-sweep.

**Proposed patch (finding only)** — delete L3589 and one of the two blank lines L3590/L3591; delete L3700 and one blank line, leaving L3703 as the section heading. No body text is lost in either case (both are verbatim duplicated in the following bullet).

---

### F5 — **NIT** — L774 cites `silver:ensure-docs` where the public route is `/sb:ensure-docs`

**Evidence**

L774, inside the canonical **LS-post-val-kl** MUST — i.e. inside live-spec normative text, not a historical note:

> (2) check whether any **key project doc** needs update/revision (the doc-scheme / **`silver:ensure-docs`** canonical set already in-repo — README, ARCHITECTURE, TESTING, CHANGELOG, and other governed docs as applicable) …

The same capability is cited correctly at L862 (LS-autonomous-e2e-order spine step 23) as **`/sb:ensure-docs`**:

> 23. **Post-Val K/L + key docs** (KLW-01; `/sb:ensure-docs` / `AF-DOCUMENT` as needed).

These are the only two occurrences in the file. L1053 locks "Public identifiers are `sb` / `sb:` / `/sb` only" and KR-no-dual-silver (L948) forbids dual `/silver`. Unlike `/silver:multi-ai-task` (13 occurrences, every one a retire/forbid statement), `/silver:new-workflow` (explicitly glosses as "historical only" per the round-21 lock), and `silver:review-fix-ladder` (L730/L1575/L2659, explicitly framed as "absorbs today's" / "a rename of"), the L774 token carries **no** historical marker and reads as a live route name.

Low severity: `ensure-docs` is not among the routes this ship renames or retires, and no test asserts on this string. But it is a `/silver`-prefixed public-route token inside a live-spec MUST, which is precisely the class L1053 forbids.

**Proposed patch (finding only)** — L774: `` `silver:ensure-docs` `` → `` `/sb:ensure-docs` ``, matching L862.

---

### F6 — **NIT** — §2.3 row `recommended_tools.omniroute` carries the omni origin SHA; the Appendix D twin does not

**Evidence**

The §2.3 public-surface table (L453–L573) and the Appendix D inventory (L4253–L4297) are twins: I diffed all 39 data rows by key. **38 of 39 are byte-identical.** The single divergence:

- **L488 (§2.3):** `Config key. Routing-only Omni proxy. Not a public /sb router. SHA 745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26.`
- **L4284 (App D):** `Config key. Routing-only Omni proxy. Not a public /sb router.`

No lock is violated — the origin SHA is provenance-only and is stated 22× elsewhere including the YAML overview (L14–L15) and L4133. This is a twin-table parity nit: Appendix D is described as the inventory of the §2.3 surfaces, and a reader diffing the two will find exactly one asymmetry with no stated reason.

**Proposed patch (finding only)** — either append the SHA sentence to L4284, or drop it from L488 (it is redundant with L4133 and the YAML overview). **Owner's call which direction**; I lean toward dropping from L488 since Appendix D is the terser inventory and the SHA already has a canonical home at L4133, but I will not guess.

---

## Part 3 — Observed, deliberately **not** raised as findings

Recorded so the owner can see they were examined and consciously excluded.

1. **R9-F4 (TOC fragment regen) — owner-deferred, confirmed still open, not re-litigated.** Per the brief this is deferred. For the owner's sizing when they pick it up: computing GitHub's heading-fragment algorithm over the body and diffing against the 174 TOC links yields **17 TOC anchors with no matching body heading**, and **16 distinct broken in-document anchors across 20 link sites** (the most-cited being `#52-ship-sequence-ws0-ws0b-ws17-ws8-docs-release`, referenced 4× at L134 / L288 / L649 / L2123). Two failure classes: (a) punctuation normalization — `2.5 Non-functional / quality attributes` slugs to `25-non-functional--quality-attributes` (double hyphen from ` / `), TOC has the single-hyphen form; (b) four TOC entries built from **truncated** promoted headings (L202, L205, L223, L327), which cannot resolve because the body headings they were derived from are themselves the truncation artifacts. Class (b) partially overlaps F4's family — repairing the truncated headings would change their fragments, so **R9-F4 should be sequenced after F4**, not before. Purely mechanical once the heading set is final.
2. **Truncated `####` headings at L1312, L2922, L3978, L4023.** All four are first-sentence promotions that cut mid-clause (e.g. L2922 ends "…the five-field wor"; L4023 has an unbalanced paren). Each is immediately followed by a body bullet restating the full text, so no content is lost and no lock is affected. Same family as F4 but **with** bodies, so lower value and higher churn to fix. Grouping them with R9-F4 as one editorial pass is the efficient path; raising them individually now would fragment that pass.
3. **L2551 deny-all role enumeration retains `knowledge_postwrite`.** Correct as-is — see the note inside F2. The role class is still deny-all and Authorizer-admitted; only the producer identity at L2554 is stale. Flagged defensively against over-sweep.
4. **`/silver:new-workflow` (6×) and `silver:review-fix-ladder` (3×).** Both carry explicit historical/absorption glosses per the round-21 and RFL-absorption locks (L730 "absorbs today's", L1575 "a rename of", L2659 "the rename of"). Not dual-`/silver` violations. Only L774 (F5) lacks such a marker.
5. **`/silver:clarify` at L4102.** Correct — it names the historical command that produced the Q1–Q3 answers. Provenance, not a live route.
6. **Empty-body `##` section headings** (L357 §2, L885 §3, L990 §4, L2728 §5, L3959 §6) and several `###` (L1708, L1935, L2125, L2191, L2730, L2732, L3756, L3961). These are normal section headers whose first child is a subsection heading — standard structure, not splice artifacts. Excluded from F4.
7. **Appendix B / C / D / E completeness.** Appendix B maps all 33 YAML todos to a named test + WS + Part with no gaps or duplicates; the L4192 arithmetic restatement matches the YAML. Appendix D twins §2.3 at 39/39 rows (sole divergence is F6). No finding.
8. **Mermaid content conformance.** L1447–L1505 was re-read line-by-line against the locks: FAST branch (L1450–L1456) shows Executor → Verifier → Validator → thin capture with the one-re-dispatch-then-`blocked_fast_leaf` path and the misclassify edge to `Spec`; the Job branch shows `comp_val_two_clean` skip-promote vs publisher-promote (round-22 lock), and the post-Val hop as `KL[Post-Val Executor K/L + key-doc]` → `AdvR[Advisor reviews hop]` → `VerK[Verifier verifies hop]` (LS-post-val-kl conformant). Clean.

---

## Part 4 — Summary

| ID | Severity | Surface | One line |
|---|---|---|---|
| F1 | **High** | L1407 | `sb:agent-wrap` called an alias; L482 says FORBIDDEN / do not alias |
| F2 | **Medium** | L2554, L2529 | Advisor `knowledge_postwrite` still named K/L producer; ordinary-Executor carve too broad |
| F3 | **Medium** | L1647, L2123 | Dangling "the following mermaid" after rung-9 removal; unanchored §4.2 diagram pointer |
| F4 | Nit | L3589, L3700 | Empty-body duplicate headings shadowing the real section titles |
| F5 | Nit | L774 | `silver:ensure-docs` in a live-spec MUST; should be `/sb:ensure-docs` |
| F6 | Nit | L488 vs L4284 | Twin-table parity: omni origin SHA on one side only |

**Locks:** all 14 named constraints **INTACT**. No KEEP REJECT reopened. No YAML todo mutated. No Q1–Q3 or Part A/B drift. Freeze copies byte-identical.

**Human fork requiring AskQuestion A/B/C:** **F3(a)** — repair-pointer (A) vs author-second-diagram (B) vs defer-with-R9-F4 (C). I recommend A on the L1507 evidence but did not decide it.

**Sequencing note for the owner:** F4 changes heading text, which changes heading fragments. **Apply F4 before R9-F4** or the TOC regen will need a second pass.

**Reporter compliance:** read-only. No Edit/Write to `.planning/router_subagent_surfaces_85bf9f09.plan.md` or `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (both re-verified at `70606c7b…d9d13f8` / 620492 bytes after this run). Stayed on `main`; no checkout, no commit, no product implementation. This file is the only artifact written.
