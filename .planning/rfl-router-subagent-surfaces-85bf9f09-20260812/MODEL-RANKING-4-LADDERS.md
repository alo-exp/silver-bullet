# Model ranking — four RFL ladders (`router_subagent_surfaces_85bf9f09`)

**Date:** 2026-08-18  
**Branch:** `main` (no checkout; this file only — frozen plan and Policy B harness untouched)  
**Method:** codebook locked first; numbers recomputed from artifacts (not patched from prior tables).  
**Plan (do not edit here):** [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md)

## Codebook (locked — do not change mid-count)

**Universe:** all rungs of plan `85bf9f09` across ladders 1–4. Roots:

- `.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/`
- `.planning/rfl-router-subagent-surfaces-85bf9f09/` (if present)
- any sibling `*85bf9f09*` RFL folders

**Artifacts that count** (must glob all of these per slug): `review.md`, `review-*.md`, `reverify-*.md`, `verify_*.md`, `triage.md`, `rung-*-task-c*.md`, `rung-*-c*.md`, `*.log`, `*.out`. Skip launch wrappers / argv / nohup unless they contain a finding list.

**Issue:** a distinct claimed defect, inconsistency, missing lock, wrong cite, hygiene note, unlabeled nit, or “material” item the model asserted against the plan/brief/clarify. Not: “CLEAN”, “no findings”, restating KEEP REJECT as praise, or duplicate restatement of the same claim on re-verify.

**Unique-across-rounds:** same claim on a later re-verify of a newer SHA ≠ a second Issue. A *new* claim on a later freeze = new Issue. Later CLEAN does **not** delete earlier Issues.

**B+H / M+L:** only if the review **names** Blocker/High or Medium/Low (or equivalent explicit severity). Unlabeled material/nit/Q18 hygiene → Issues yes, B+H/M+L no.

**Accepted:** the finding was **landed in the live spec** (named parent ACCEPT **or** later incorporated, including nits/lows from R37–R41: document-control recency, `(row 1)` phrasing, UUID backticks, CORR-11 order/cites, FAST order, mermaid cite, writes-cite retargets, cycle-resume VALP cites, coverage MUST, mermaid complementary, grok High Mediums if live, KH1/2/3/5, KM2/3/4/7, GH5, GM1, etc.). KEEP REJECT / parent REJECT / in-cycle-only / wrong findings = not Accepted. **Accepted ≤ Issues** always.

**Acceptance %:** `Accepted / Issues * 100` to 1 decimal. Issues=0 → `—` and rank last.

**Rank:** Accepted desc, then Acceptance % desc, then B+H desc, then Issues desc.

**Qwen3.8-max:** **omitted from the table** — skipped / not run (no `review.md`; `qwen-high-ladder4/opencode-run.log` has no finding list). This is **not** a 0-issue finder. Do not invent OpenCode Max.

**Slug aliases:** `cursor-grok-4.6-high` = `grok-4.6-high`; `cursor-grok-4.6-xhigh` = `grok-4.6-xhigh`. Do not double-count.

## Scoring locks applied after codebook (not codebook edits)

- **Q18 historical-chain hygiene** (brief round-2 row still shows pre-`advisor_planning`): counted once per slug that asserted it. **Accepted = 0** — the historical row is retained by design; KH1/KM4 (missing `p_*` parenthetical) is a different claim.
- **In-cycle L1 material** closed before ladder advance: Issue yes, Accepted no.
- **Same claim on a later SHA** (cite-only drift, leftover residue, cycle re-verify): not a second Issue. **New claim on a later freeze** = new Issue.
- **Later incorporated beats an earlier parent REJECT** when the live spec now contains the fix (document-control recency, CORR-11 after Advisor compose, parent-proxy at remaining depth > 0, etc.).
- **`.planning/rfl-router-subagent-surfaces-85bf9f09-20260814/`**: no matching review artifacts (`DEFS-INVENTORY.md` / `*-triage.md` / `*-fixes.md` are not in the glob).
- Percentages and rank sort computed in `ctx_execute` (`Accepted/Issues*100` to 1 decimal; Accepted desc, then `%` desc, then B+H desc, then Issues desc; 23 ranked slugs; full-tie → slug alpha). `qwen3.8-max` omitted (skipped/not run), not ranked.

## Ranking

| Rank | Model Slug | Issues | B+H | M+L | Accepted | Acceptance % | Notes |
|---:|---|---:|---:|---:|---:|---:|---|
| 1 | `opus-5-xhigh` | 89 | 39 | 33 | 85 | 95.5 | OX1–9 + L3/L4 unique freezes; Acc misses OX-c1868-H2, OX-a8e7-M1, OX-3af-n1, OX-ebd-n1 |
| 2 | `gpt-5.6-sol-max` | 17 | 13 | 4 | 17 | 100.0 | Unique Parent-ACCEPT freezes; skip ac500 residue of r26; all 17 unique claims landed; CLEAN reverifies add none |
| 3 | `kimi-k3-high` | 14 | 0 | 7 | 11 | 78.6 | KH-F1 in-cycle Acc=0; KH1/2/3/5 Acc; KH4/KH6 Acc=0; L2 M1–M5 Acc; L3 M1/M2 Acc |
| 4 | `opus-5-high` | 16 | 5 | 7 | 10 | 62.5 | OH1–4 Acc; L3 H1/H2/M1–M4 Acc; L4 B1/B2/H1/M1–M3 Acc=0 (later CLEAN does not erase) |
| 5 | `opus-5-max` | 7 | 1 | 5 | 7 | 100.0 | OM-L3-M1/M2/L1 + OM-L4-H1/M1/M2/n1; all landed |
| 6 | `gpt-5.6-sol-xhigh` | 12 | 5 | 4 | 5 | 41.7 | L1 7 in-cycle Acc=0; L4 H-1/H-1-nested/H-2/M-1 GST Acc; 9c9aa M-1 CORR-11 later Acc |
| 7 | `gpt-5.6-sol-high` | 16 | 1 | 4 | 5 | 31.3 | L1 11 unique in-cycle Acc=0; L4 Blocker+3 Mediums Acc; 9c9aa M-1 document-control later Acc |
| 8 | `grok-4.6-xhigh` | 5 | 1 | 0 | 4 | 80.0 | GX-L2-H1 consult spawn Acc; Q18 Acc=0; R37-n1 + R38-n1/n2 Acc; R39–R41 cite drift not +Issues |
| 9 | `kimi-k3-xhigh` | 6 | 1 | 4 | 4 | 66.7 | KX-Q18 Acc=0; H1/M1/M2/M3 Acc; L4 M-1 Val-column sentence not in live Acc=0 |
| 10 | `kimi-k3-max` | 7 | 0 | 0 | 4 | 57.1 | O1–O4,O6–O8; skip O5 carry-over of KH2–KH5; Acc KM2/3/4/7 |
| 11 | `grok-4.6-high` | 6 | 0 | 3 | 3 | 50.0 | GH-Q18 + L3 skim Acc=0; L4 M1–M3 Acc if live; unlabeled B1 letter-reuse Acc=0 |
| 12 | `deepseek-v4-pro` | 3 | 0 | 3 | 2 | 66.7 | DS-L1 tree vs DAG Acc=0; L2 SessionStart unproven Acc; L3 remaining_depth non-integer Acc |
| 13 | `minimax-m3` | 1 | 0 | 1 | 1 | 100.0 | MM-L1: “Two mermaid blocks share overall structure but cover different flows” (complementary; landed) |
| 14 | `composer-2.5-xhigh` | 2 | 0 | 1 | 1 | 50.0 | CX-M optimize-five-tool-stack.sh Acc; CX-Q18 Acc=0 |
| 15 | `composer-2.5-high` | 3 | 0 | 2 | 1 | 33.3 | CH-M1 Val row label Acc; CH-M2 coordinator-not-in-table Acc=0; CH-Q18 Acc=0 |
| 16 | `glm-5.2-max` | 3 | 0 | 0 | 1 | 33.3 | GM1 Acc; GM2/GM3 declined Acc=0; L4 `review.md` incomplete — no invented findings; `review-9c9aa7d9.md` CLEAN |
| 17 | `glm-5.2-high` | 9 | 0 | 2 | 1 | 11.1 | F1/F2 in-cycle Acc=0; GH1–6 unlabeled; GH5 Acc; L2 Q18 Acc=0 |
| 18 | `gemini-3.6-flash-high` | 15 | 5 | 10 | 0 | 0.0 | L1 specified in `ledger.json` (CLI `--model gemini-3.6-flash-high`). **Unspecified / extra vs L3–L4 matrix** (those specify 3.7). c1 6 + c3 9 in-cycle; restart task-c1/c2 CLEAN does not erase |
| 19 | `cursor-grok-4.5-low` | 11 | 3 | 0 | 0 | 0.0 | F-1..F-10 + c2 baseline V-only; in-cycle |
| 20 | `cursor-grok-4.5-medium` | 10 | 0 | 0 | 0 | 0.0 | F-1..F-10; C2-F1 = F-7 re-verify not +1 |
| 21 | `cursor-grok-4.5-high` | 5 | 0 | 2 | 0 | 0.0 | 3 unlabeled MATERIAL + 2 named LOW; c2 CLEAN does not erase |
| 22 | `gemini-3.7-flash-high` | 1 | 0 | 0 | 0 | 0.0 | G37-Q18: “Clarify Brief Historical Row Q18: Line 120 … retains historical round-2 text” |
| 23 | `glm-5.2-xhigh` | 1 | 0 | 0 | 0 | 0.0 | GX-Q18: “Clarify brief round-2 Q18 historical row … still shows a pre-`advisor_planning` chain” |
| | TOTAL | 259 | 74 | 92 | 162 | 62.5 | Not ranked. Overall rate = 162/259 (23 slugs). `qwen3.8-max` omitted (skipped/not run; was 0/0/0/0 so totals unchanged). Unlabeled findings = Issues−(B+H+M+L) = 93. |

## Corrections this pass

Removed `qwen3.8-max` rank-24 row (skipped/not run; not a 0-issue finder). Other slug cells unchanged. `gemini-3.6-flash-high` 15/5/10/0 confirmed from L1 CLI artifacts (not a mislabeled 3.7). TOTAL recomputed in `ctx_execute` without qwen: still **259 / 74 / 92 / 162 / 62.5** (`162/259*100` to 1 decimal); slug count **23**. Volatile slugs spot-checked against source artifacts (`gpt-5.6-sol-max`, `opus-5-xhigh`, `grok-4.6-xhigh`, `kimi-k3-high`, `gpt-5.6-sol-high`, `gemini-3.6-flash-high`, `gemini-3.7-flash-high`).

## Integrity checks

Computed in `ctx_execute` on the score vectors (not by hand).

| Check | Result |
|---|---|
| Every slug: Accepted ≤ Issues | **PASS** |
| Sum of inventory headlines = Issues (per slug, Appendix A) | **PASS** (259 Issues across 23 ranked slugs) |
| B+H + M+L ≤ Issues | **PASS** |
| No ranked slug with review artifacts is Issues=0 unless files contain zero finding claims | **PASS** (`qwen3.8-max` omitted: skipped/not run, not a 0-issue finder) |
| Acceptance % = `Accepted/Issues*100` to 1 decimal in `ctx_execute` | **PASS** |
| Rank keys: Accepted desc, `%` desc, B+H desc, Issues desc; ranks 1–23 | **PASS** |

## Appendix A — per-slug inventories

Headline count **must** equal Issues. Acc tags: **A** = Accepted, **N** = not Accepted. Severity in `[B][H][M][L]` only when the review named it.

### `composer-2.5-high` — Issues 3 / Acc 1

**Files:** `composer-2.5-high-ladder2/review.md`, `composer-2.5-high-ladder3/review.md`, `composer-2.5-high-ladder4/review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| CH-M1 | M | A | Five-tool summary table row labeled `I / A / V / Val` (live: `I / A / V (AF/Workflow); Process-final Val`) |
| CH-M2 | M | N | `stack-compression-coordinator.sh` absent from five-tool summary table (parent REJECT; prose carries bind) |
| CH-Q18 | — | N | Clarify round-2 Q18 historical row still shows pre-`advisor_planning` chain |

L3/L4 CLEAN + KEEP REJECT checklists are not Issues. L3 Q18 restatement ≠ +1.

### `composer-2.5-xhigh` — Issues 2 / Acc 1

**Files:** `composer-2.5-xhigh-ladder2/review.md`, `composer-2.5-xhigh-ladder3/review.md`, `composer-2.5-xhigh-ladder4/review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| CX-M1 | M | A | Plan names `optimize-rtk-context-mode.sh` 16× and never `optimize-five-tool-stack.sh` (parent ACCEPT; 17 live hits) |
| CX-Q18 | — | N | Q18 historical-chain hygiene |

### `cursor-grok-4.5-low` — Issues 11 / Acc 0

**Files:** `.planning/rfl-router-subagent-surfaces-85bf9f09/rung-low-cycle1.out`, `rung-low-cycle2.out`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| L-F1 | B | N | Migration mapping drops A-loop vs locked I/A/V |
| L-F2 | B | N | Revalidation admits V without re-proving A |
| L-F3 | B | N | §5 I/A/V bullet order / V-loop body ambiguity |
| L-F4 | — | N | Traceability / Doctor / VAL orphans for A-loop and K/L |
| L-F5 | — | N | Authorizer rename incomplete (`broker_*`) |
| L-F6 | — | N | Toolstack notes thinner than locked Clarify table |
| L-F7 | — | N | Route catalog executability without pinned membership |
| L-F8 | — | N | “plan/CLARIFY parity” risks wrong authority file |
| L-F9 | — | N | Ordinary delivery quality loop lacks SM vs Iterate |
| L-F10 | — | N | OpenCode deferred vs capability-gated OpenCode routes |
| L-C2 | — | N | Baseline admission still binds V-only |

### `cursor-grok-4.5-medium` — Issues 10 / Acc 0

**Files:** `rung-medium-cycle1.out`, `rung-medium-cycle2.out`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| M-F1 | — | N | `a_loop_not_applicable` reopens a live A-loop skip |
| M-F2 | — | N | Ordinary-delivery SM vs Iterate authority axis |
| M-F3 | — | N | A-loop scope granularity unlocked |
| M-F4 | — | N | Six migration ingress states never canonically listed |
| M-F5 | — | N | Typed blocker catalog orphans |
| M-F6 | — | N | K/L “must” gates lack fail-closed typed outcomes |
| M-F7 | — | N | Toolstack “five-tool” vs clarify four-column table |
| M-F8 | — | N | `blocked_advisor_state` vs strictly stronger Advisor |
| M-F9 | — | N | Authorizer rename / Broker leftovers |
| M-F10 | — | N | Q11 single coordinated release vs site/help policy |

C2-F1 is F-7 re-verify (not +1).

### `cursor-grok-4.5-high` — Issues 5 / Acc 0

**Files:** `rung-high-cycle1.out`, `rung-high-cycle2.out` (CLEAN-only; does not erase)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| H-MAT1 | — | N | Ordinary SM token vs locked V two-clean |
| H-MAT2 | — | N | Step-as-AF-leaf-executor A-loop exception underspecified |
| H-MAT3 | — | N | Traceability: I/A named, V not |
| H-LOW1 | L | N | `awaiting_revalidation` vs `awaiting_baseline_revalidation` |
| H-LOW2 | L | N | `terminated_iterate_ceiling_reconciled` not in blocker catalog |

Q12–Q20 MISSING_CLARIFY table is not extra Issues.

### `deepseek-v4-pro` — Issues 3 / Acc 2

**Files:** `deepseek-v4-pro-high-ladder4/review.md` (examined `opencode-run.log`: CLEAN echo only, no extra list)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| DS-L1 | L | N | “tree” vs shared-DAG wording |
| DS-L2 | L | A | `SB_PRIMARY_CHECKOUT` SessionStart env-export unproven on Cursor (live flags unproven) |
| DS-L3 | L | A | `remaining_depth` non-integer token / Codex `unbounded` (later consumer semantics) |

### `gemini-3.6-flash-high` — Issues 15 / Acc 0

**Stay in ranking:** yes — L1 actually ran this SKU (`agent --print --mode ask --model gemini-3.6-flash-high`). Specified on the original 20260812 ladder (`ledger.json` / `RFL-SUMMARY.md`). **Unspecified / extra vs the L3–L4 matrix** (those launch `sb-gemini-3-7-flash-high`). Not a mislabeled 3.7.

**Files:** `rung-gemini-3.6-flash-high-c1.log`, `c3.log`, `rung-gemini-3.6-flash-high-task-c1.md`, `task-c2.md` (CLEAN restart; does not erase)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| G36-c1-1 | H | N | Missing P-loop exemption for deny-all leaf roles |
| G36-c1-2 | H | N | Legacy migration omits Validation-loop receipt generation |
| G36-c1-3 | M | N | Levels 0–3 defect escalation vs mandatory A-loop re-run |
| G36-c1-4 | M | N | Authorizer storage path missing local-repo fallback |
| G36-c1-5 | M | N | Post-verify K/L gate lacks zero-insight handling |
| G36-c1-6 | L | N | Omitted paragraphs for requirements 612–618 / missing schema file |
| G36-c3-F1 | H | N | Work-spec immutability vs mid-execution mutation |
| G36-c3-F2 | H | N | Control-plane leaf roles missing explicit quality-loop exemption |
| G36-c3-F3 | H | N | Launch prompt + work-spec delimitation gap for Cursor Task |
| G36-c3-F4 | M | N | Omission of P-loop `p_*` states in §5 ordinary SM |
| G36-c3-F5 | M | N | ASCII WBS example gap for P-loop and on-demand consults |
| G36-c3-F6 | M | N | Undocumented 9 `fitness_charter` fields |
| G36-c3-F7 | M | N | Step-level vs AF-level quality-loop handoff & terminal |
| G36-c3-F8 | L | N | §8 matrix path missing `hooks/` |
| G36-c3-F9 | L | N | Validator column syntax inconsistency in §9 |

### `gemini-3.7-flash-high` — Issues 1 / Acc 0

**Files:** `gemini-3.7-flash-high-ladder2/review.md`, `ladder3/review.md` (CLEAN), `ladder4/review-reverify-9c9aa7d9.md` (CLEAN)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| G37-Q18 | — | N | Clarify Brief Historical Row Q18: Line 120 retains historical round-2 text |

### `glm-5.2-high` — Issues 9 / Acc 1

**Files:** `rung-glm-5.2-high-task-c1.md`, `c2.md`, `c3.md`, `glm-5.2-high-ladder2/review.md`, `ladder3/review.md`, `ladder4/review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| GLM-F1 | M | N | `blocked_validation_state` missing from canonical enum (Low–Medium; in-cycle closed) |
| GLM-F2 | L | N | Four canonical blockers listed with no trigger predicate (in-cycle closed) |
| GH1 | — | N | Traceability `VAL-RFL-N` vs `VAL/TST-RFL-N` notation |
| GH2 | — | N | SM terminal asymmetry `i_two_clean`/`a_two_clean` vs `v_verified`/`val_validated` |
| GH3 | — | N | `migration_not_activated` non-blocker carve-out observation |
| GH4 | — | N | Dense em-dash predicate bullet style |
| GH5 | — | A | `blocked_callback_gap` vs `blocked_callback_unresolved` overlap (prefer-gap landed) |
| GH6 | — | N | Canonical list non-exhaustive “include” phrasing |
| GLM-Q18 | — | N | L2 Q18 historical-chain hygiene |

### `glm-5.2-max` — Issues 3 / Acc 1

**Files:** `rung-glm-5.2-max-task-c1.md`, `c2.md` (CLEAN re-verify), `glm-5.2-max-ladder4/review.md` (incomplete transcript — **no invented findings**), `review-9c9aa7d9.md` (CLEAN)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| GM1 | — | A | “Minimum A/Val boundaries” vs mandatory floor |
| GM2 | — | N | §9 dep matrix row 6 `review-fix-ladder.py` legacy note |
| GM3 | — | N | Traceability split vs pair IDs |

### `glm-5.2-xhigh` — Issues 1 / Acc 0

**Files:** `glm-5.2-xhigh-ladder2/review.md`, `ladder3/review.md`, `ladder4/review-reverify-9c9aa7d9.md` (CLEAN 0 nits)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| GLX-Q18 | — | N | Clarify brief round-2 Q18 historical row still shows a pre-`advisor_planning` chain |

### `gpt-5.6-sol-high` — Issues 16 / Acc 5

**Files:** `rung-gpt-5.6-sol-high-task-c1.md` … `c12.md`, `gpt-5.6-sol-high-ladder4/review.md`, `review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| GH-c1-1 | — | N | Callback/channel contract requires Iterate-only identities |
| GH-c1-2 | — | N | Process-final P/I/A/V/Val has no legal Process-scope executor |
| GH-c1-3 | — | N | Launch graph omits executor/Step request edge for P-loop Advisors |
| GH-c1-4 | — | N | Active legacy RFL migration has no deterministic ordinary target |
| GH-c1-5 | — | N | Authorizer trust-root path not injective |
| GH-c3-1 | — | N | Ordinary Levels 0–3 repair forced through Iterate-only baseline-revalidation |
| GH-c3-2 | — | N | Iterate rung implementers have no P-loop path (c4/c5 restatement ≠ +1) |
| GH-c3-3 | — | N | Active ordinary RFL migration can re-admit without pre-read/P-loop gates |
| GH-c9-1 | — | N | Ordinary callback ack drops generic callback fence |
| GH-c9-2 | — | N | Early-callback logical key aliases same-kind callbacks |
| GH-c10 | — | N | Required Cursor mirror is stale (c11/c12 CLEAN ≠ erase) |
| GH-L4-B | B | A | Proxy prompt/depth integrity (`prompt_hash` inner-only later landed) |
| GH-L4-M1 | M | A | Codex numeric rules copied without `unbounded` qualification |
| GH-L4-M2 | M | A | Runtime picker omits Pi (live has `agent-pi`) |
| GH-L4-M3 | M | A | External-agent install vs HINST instruction-only |
| GH-9c9aa-M1 | M | A | Document-control omits Round-36 freeze (later recency landing) |

### `gpt-5.6-sol-xhigh` — Issues 12 / Acc 5

**Files:** `rung-gpt-5.6-sol-xhigh-task-c1.md` … `c5.md`, `gpt-5.6-sol-xhigh-ladder4/review.md`, `review-reverify-c82e1b3b.md`, `review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| GX-c1-1 | — | N | Authorizer trust-root path not injective |
| GX-c1-2 | — | N | Early-callback dedupe partitioned by mutable transport identity |
| GX-c1-3 | — | N | Ordinary P-loop has no stale-plan transition once I begins |
| GX-c2-H | H | N | Process-synthesis has no lawful repair/re-entry for Process-level findings |
| GX-c2-M | M | N | Canonical blocker predicates overlapping / nondeterministic |
| GX-c3-H | H | N | Process repair bypasses owning Workflow ancestry |
| GX-c3-M | M | N | Blocker table deterministic only for listed prefix |
| GX-L4-H1 | H | A | `worktree_cwd` outside signed admission (round-23 ACCEPT) |
| GX-c82-H1 | H | A | Nested-Task must bind `worktree_cwd` (round-24; new freeze claim) |
| GX-c82-H2 | H | A | Doctor vs inspect-only (round-24 ACCEPT) |
| GX-c82-M1 | M | A | GST tombstones beyond N-1 (round-24 ACCEPT) |
| GX-9c9aa-M1 | M | A | CORR-11 wording misorders composition-Val vs Advisor (later after-Advisor compose) |

c4/c5 CLEAN does not erase L1.

### `gpt-5.6-sol-max` — Issues 17 / Acc 17

**Files:** `gpt-5.6-sol-max-ladder4/review.md` + 12 `review-reverify-*.md`. CLEAN reverifies (`3af884ef`, `71427c3d`, `9c9aa7d9`, `a8e7a463`, `ebd7ad9e`, `fe219ffe`) add no Issues. `ac500b96` H-1/H-2 are round-26 residue (same claims; not +Issues).

| ID | Sev | Acc | Headline |
|---|---|---|---|
| GM-r25-H1 | H | A | WS1 named sources omit catalog libs that still emit `/silver:*` |
| GM-r26-B1 | B | A | Mid-execution `wf_mint` may request new PUB-01 definitions |
| GM-r26-H1 | H | A | Executor role table forbids “invent a new WF” |
| GM-r26-M1 | M | A | FAST tests require always `memory_save` |
| GM-r26-M2 | M | A | `PP-SB-DEFAULT` forbids local AFs outside the catalog |
| GM-r28-H1 | H | A | `launch_intent` must carry closure identity |
| GM-r28-H2 | H | A | Closure hash is recursive over nested WFs |
| GM-r28-H3 | H | A | `context_refs` must be snapshotted or hashed |
| GM-r29-H1 | H | A | Cycle rejection |
| GM-r29-H2 | H | A | Hash correctness not just presence |
| GM-r29-H3 | H | A | Immutable `context_refs` snapshot as child read source |
| GM-r29-M1 | M | A | Clarify SHA ledger |
| GM-r30-H1 | H | A | Projector writes the snapshot |
| GM-r30-H2 | H | A | Tri-color / active-stack cycle detection |
| GM-r30-H3 | H | A | Remint revokes old Executor authority |
| GM-r30-M1 | M | A | TST-RFL-626 negative fixture |
| GM-c1868-H | H | A | Canonical row 1 does not classify still-running old Executor after revoke (live has still-running / post-revoke) |

### `grok-4.6-high` — Issues 6 / Acc 3

**Files:** `grok-4.6-high-ladder2/review.md`, `ladder3/review.md`, `ladder4/review.md`, `ladder4/review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| GRH-Q18 | — | N | Q18 historical-chain hygiene |
| GRH-L3-skim | — | N | L106/L372 wrap shorthand omits `plan_val_*` in the arrow (skim risk) |
| GRH-L4-M1 | M | A | HINST B4 restates only numeric remaining_depth 0 (live: `host_nest_refused` / numeric-only) |
| GRH-L4-M2 | M | A | YAML overview “always at remaining depth 0” without Codex sentinel (gone from live plan) |
| GRH-L4-M3 | M | A | Mermaids always-promote vs body skip-promote (live skip-promote) |
| GRH-L4-B1letter | — | N | HINST local headings B1–B5 reuse letter “B1” next to catalog-schema B1 |

### `grok-4.6-xhigh` — Issues 5 / Acc 4

**Files:** `grok-4.6-xhigh-ladder2/review.md`, `ladder3/review.md`, `ladder4/review-reverify-9c9aa7d9.md`, `rung-04-cursor-grok-4.6-xhigh/reverify-round-37.md` … `41.md` (+ `-max` variants: no extra finding lists). R37 PASS checklist verifies parent-requested landings (not extra Issues). R39–R41 n-1/n-2/n-3 are cite drift of R38 (not +Issues). KEEP REJECT L598 alias skips are not Issues.

| ID | Sev | Acc | Headline |
|---|---|---|---|
| GX-L2-H1 | H | A | In-flight unplanned control-plane spawn vs projector-only at remaining depth > 0 (live parent-proxy even when remaining depth > 0) |
| GX-Q18 | — | N | Q18 historical-chain hygiene |
| GX-R37-n1 | — | A | CORR-11 line window vs composition-Val line |
| GX-R38-n1 | — | A | L265 cooperative-read cite should retarget writes (writes-cite) |
| GX-R38-n2 | — | A | Row-1 cycle resume cites should be VALP-01 |

Alias: `cursor-grok-4.6-xhigh` merged into this slug.

### `kimi-k3-high` — Issues 14 / Acc 11

**Files:** `rung-kimi-k3-high-task-c1.md` … `c3.md`, `kimi-k3-high-ladder2/review.md`, `ladder3/review.md`, `ladder4/review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| KH-F1 | — | N | Process-graph omits AF/Workflow Validation-loop validators and AF-scope A-loop advisor (in-cycle) |
| KH1 | — | A | Clarify historical Q18 missing `p_*` |
| KH2 | — | A | A-loop knowledge/learning candidates disposition |
| KH3 | — | A | LPS cross-host JSON canonicalization (RFC 8785) |
| KH4 | — | N | POA re-satisfaction on pure approach pivot (already-fixed; Issue not Acc) |
| KH5 | — | A | P-loop Advisor-unavailability blocker ambiguity |
| KH6 | — | N | §1 vs §3 Mentor parenthetical asymmetry (declined) |
| KH-L2-M1 | M | A | Advisor-unavailable classification rows 13 vs 22 |
| KH-L2-M2 | M | A | SessionStart env-export unproven |
| KH-L2-M3 | M | A | remaining-depth not in envelope/spawn-proxy field lists |
| KH-L2-M4 | M | A | Escalation step-3 self-validation uninstrumented |
| KH-L2-M5 | M | A | Overlap-worktree E2E conditional vs unconditional |
| KH-L3-M1 | M | A | Ordinary V SM never names `v_two_clean` (live names it) |
| KH-L3-M2 | M | A | spawn-proxy `remaining_depth` has no named write transaction |

### `kimi-k3-max` — Issues 7 / Acc 4

**Files:** `rung-kimi-k3-max-task-c1.md`, `c2.md` (no `review.md`)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| O1 | — | N | Levels 0–3 repair-closure uses Iterate-only `awaiting_baseline_revalidation` (already-fixed) |
| O2 | — | A | P-loop / K/L applicability to Iterate rung executors |
| O3 | — | A | I-loop disposition → dirty mapping |
| O4 | — | A | Brief Q18 hygiene (4th recording; = KH1 landing) |
| O6 | — | N | Cosmetic “Advisor-owned” / Mentor / floor wording |
| O7 | — | A | `final-validation` vs `val_validated` sixth-receipt risk |
| O8 | — | N | Plan `[!]` optional vs brief marker list |

O5 is explicit carry-over of KH2–KH5 — not a Max Issue.

### `kimi-k3-xhigh` — Issues 6 / Acc 4

**Files:** `kimi-k3-xhigh-ladder2/review.md`, `ladder3/review.md`, `ladder4/review.md`, `ladder4/review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| KX-Q18 | — | N | Q18 historical-chain hygiene |
| KX-H1 | H | A | Plan-time Val unbound on POA-01 mid-flight replacement (live: replacement requires `plan_val_verified`) |
| KX-M1 | M | A | Plan-time Val non-convergence has no bound / blocker mapping (`plan_val_round` live) |
| KX-M2 | M | A | Second mermaid Val-fail path skips handoff node (later closed) |
| KX-M3 | M | A | Document control Date still 2026-08-14 (later Revised 2026-08-16 / Round-41) |
| KX-L4-M1 | M | N | “Val column applies only at Process” missing vs five-tool table (sentence not in live spec) |

### `minimax-m3` — Issues 1 / Acc 1

**Files:** `minimax-m3-high-ladder4/review.md` (`opencode-run.log`: no extra finding list)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| MM-L1 | L | A | Two `mermaid` blocks share overall structure but cover different flows (complementary; landed) |

### `opus-5-high` — Issues 16 / Acc 10

**Files:** `rung-opus-thinking-high-task-c1.md`, `c2.md`, `opus-5-high-ladder3/review.md`, `opus-5-high-ladder4/review.md`, `review-reverify-9c9aa7d9.md`

| ID | Sev | Acc | Headline |
|---|---|---|---|
| OH1 | — | A | Stale cross-ref `lines 80/190/274` |
| OH2 | — | A | `drain_only` absent from ingress substate whitelist |
| OH3 | — | A | Implementation-matrix rows under-name round-3/4 (P-loop / LPS / WBS) |
| OH4 | — | A | `launch_intent` omits `scope_execution_id` / `execution_attempt_id` |
| OH-L3-H1 | H | A | FAST path reuses catalog records whose contracts mandate forbidden V-loops |
| OH-L3-H2 | H | A | GST push failure hard-stops every non-trivial Job on protected `main` |
| OH-L3-M1 | M | A | Row 6 trigger omits Board-conflict case ABU-01 routes to it |
| OH-L3-M2 | M | A | Parent-proxy consume attributed to two different actors |
| OH-L3-M3 | M | A | FAST WBS ledger has no close condition |
| OH-L3-M4 | M | A | Document-integrity clause unsatisfiable vs own heading levels |
| OH-L4-B1 | B | N | WS1 H-5 mandate targets catalog ids that do not exist / collide |
| OH-L4-B2 | B | N | Frozen SHA points at the older of two named plan copies |
| OH-L4-H1 | H | N | WS1 completeness unsatisfiable vs shipped catalog + no bulk-rewrite |
| OH-L4-M1 | M | N | `nested_executor` class ambiguity for records WS1 adds |
| OH-L4-M2 | M | N | No field-level spec for the AF record WS1 must add |
| OH-L4-M3 | M | N | `router-coverage` invariant has no disposition under `silver`→`sb` rename |

### `opus-5-max` — Issues 7 / Acc 7

**Files:** `opus-5-max-ladder3/review.md`, `opus-5-max-ladder4/review-ebd7ad9e.md`, `review-9c9aa7d9.md` (CLEAN; does not erase)

| ID | Sev | Acc | Headline |
|---|---|---|---|
| OM-L3-M1 | M | A | `/silver:new-workflow` keeps `silver-` public prefix (round-21) |
| OM-L3-M2 | M | A | Rows 37/40 have no first-match carve for Executor out-of-plan mint (round-21) |
| OM-L3-L1 | L | A | Duplicate Codex `unbounded` parenthetical (round-21) |
| OM-L4-H1 | H | A | `context-refs-snapshot` GC has no reachable MVP trigger / undefined “fence release” |
| OM-L4-M1 | M | A | L511 diagram licenses `wf_mint` without in-plan narrowing |
| OM-L4-M2 | M | A | L263 special-file failures vs single-classification table |
| OM-L4-n1 | — | A | L470 WBS example omits “in-plan” on inserted-NW label |

### `opus-5-xhigh` — Issues 89 / Acc 85

**Files:** `rung-opus-thinking-xhigh-task-c1.md`, `c2.md`; `opus-5-xhigh-ladder3/` 5 reviews; `opus-5-xhigh-ladder4/` 15 reviews. Unique-across-rounds: each freeze’s new claims count; cite-only restatements do not.

**Headline census (89 IDs):** `OX1–OX9` (9); `L3-B1,HA,HB,MA,MB,MC,MD` (7); `rx-H1–H5,M1–M5` (10); `rv-H1–H5,M1–M4` (9); `65-H1,H2,M1,M2` (4); `b673-MA,MB,MC` (3); `r23-B1,H1,H2,M1,M2` (5); `r24-H3,H4,M3` (3); `r25-B1,H1,M1` (3); `r26-B1,H1,H2,M1` (4); `r27-B1,B2,H1,M1` (4); `r28-H1,H2,M1` (3); `r29-B1,H1,M1` (3); `r30-B1,H1,H2,H3,M1,M2` (6); plus 16 later-freeze rows in the table below. Subtotal 9+7+10+9+4+3+5+3+3+4+4+3+3+6 = 73; 73+16 = **89**.

**L1 unlabeled (9, all A):** OX1 ESC-01 repair-rejoin ordinal; OX2 `revalidation_cycle_id` arity; OX3 TRUST-01 local-fallback fixture; OX4 LPS-01 escaping; OX5 Leaf-Step terminal absent from SM; OX6 no ordinary counterpart to ladder-conflict/budget; OX7 Process-synthesis executor tier undeclared; OX8 A-loop Mentor freshness silent vs V; OX9 rows 6↔12 phase labelling.

**L3 `review.md` (7, all A, round-12):** B1 schema-illegal catalog amendment `[B]`; H-A `AF-EXECUTE` omitted from must-not-run `[H]`; H-B extra V-fields still enforced `[H]`; M-A `PP-SB-STARTUP-FAST` unreachable `[M]`; M-B FAST surfaces exclude thin-capture `[M]`; M-C H2 degrade fixture no test owner `[M]`; M-D Board-of-one unifier identity `[M]`.

**L3 `review-real-xhigh.md` (10, all A, round-13/15):** H-1 GST row 35 classifying vs non-gating; H-2 `.sb/` ledger-omit hole; H-3 classified-trivial K/L pre-read unbound; H-4 FAST leaf has no terminal; H-5 `AF-agent-delegate` / `sb:agent-wrap` missing from catalog; M-1 “amends those APO records” vs B1; M-2 GST UTC rollover tombstone; M-3 GST write-strategy unordered; M-4 `paths-ignore` PR-check semantics; M-5 `user.email` PII on dashboard.

**L3 `review-real-xhigh-reverify.md` (9, all A, round-17):** H-1 `/sb:agent-*` still mints wrap at Orchestrator; H-2 HINST B4 parent-proxy “only” at depth 0; H-3 rows 41–42 unreachable first-match; H-4 role-gate has no VAL/TST fixture; H-5 five-tool probe vs OpenCode/Pi instruction-only; M-1 depth unit unstated; M-2 Codex no `remaining_depth` max; M-3 L112 clause (3) no blocker row; M-4 Risks omit HNEST/HINST.

**L3 `review-real-xhigh-reverify-65fde3d6.md` (4, all A, round-19):** H-1 `/silver:new-workflow` authoring session not a Job; H-2 rows 41/42 shadowed by 11/12; M-1 Codex `unbounded` no consumer semantics; M-2 replacement-ladder probe undefined.

**L3 `review-real-xhigh-reverify-b673de8c.md` (3, all A, round-20):** M-A row 42 sibling vs spawn-target; M-B precomposed catalog-dispatch escape for authoring; M-C WS2 retires queue-builder only in installed copy.

**L4 Parent-ACCEPT freezes (31, all A):** r23 B-1/H-1/H-2/M-1/M-2; r24 H-3/H-4/M-3; r25 B-1/H-1/M-1; r26 B-1/H-1/H-2/M-1; r27 B-1/B-2/H-1/M-1; r28 H-1/H-2/M-1; r29 B-1/H-1/M-1; r30 B-1/H-1/H-2/H-3/M-1/M-2.

**L4 later freezes (16 headlines):**

| ID | Sev | Acc | Headline |
|---|---|---|---|
| OX-c1868-H1 | H | A | L122 still mandates superseded visited-set walk (live tri-color) |
| OX-c1868-H2 | H | N | L120 requires `context_refs_hash` on `launch_intent` (live: launcher may omit; projector stamps) |
| OX-a8e7-M1 | M | N | Row 1 limb (b) has no named detection oracle (PARTIAL; continued as 3af H-1) |
| OX-a8e7-M2 | M | A | Row 1 remediation cell not updated for round-31 match classes |
| OX-a8e7-N1 | — | A | `VAL/TST-RFL-604` cited two ways |
| OX-a8e7-N2 | — | A | `context_refs_hash` lacks explicit not-a-`prompt_hash` carve-out |
| OX-a8e7-N3 | — | A | VALP-01 omits cycle fixtures its testing row pins |
| OX-3af-H1 | H | A | Round-32 M-1 not propagated to four live-spec still-running statements |
| OX-3af-n1 | — | N | Superseded decision-log entries restate un-narrowed limb (b) with no supersession pointer |
| OX-ebd-n1 | — | N | Authoring directive left inside normative prose |
| OX-ebd-n2 | — | A | Self-referential markdown links to agent UUIDs (UUID backticks landed) |
| OX-fe219-M1 | M | A | L112 single-limb Executor-mint `iff` vs two-limb (round-35) |
| OX-fe219-M2 | M | A | GC rule has no terminal for normally completing launches (round-35) |
| OX-fe219-nit | — | A | `VAL/TST-RFL-626` does not pin non-regular-entry classes (round-35) |
| OX-71427-M1a | M | A | Canonical rows 37/40 two-limb vs third mid-I PUB-01 limb (round-36) |
| OX-9c9aa-n1 | — | A | Document-control `Revised` never advanced to round 36 (R37 recency) |

Headline total: 9+7+10+9+4+3+31+16 = **89**. Acc: 89 − 4 (c1868-H2, a8e7-M1, 3af-n1, ebd-n1) = **85**.

`qwen3.8-max` has no appendix inventory — omitted (skipped/not run; no `review.md`). Not a 0-issue finder.

---

**Live spec used for Accepted:** [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../../router_subagent_surfaces_85bf9f09.plan.md) + clarify banner ACCEPT ledger in [`.planning/router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md`](../../router_subagent_surfaces_85bf9f09-CLARIFY-260717-143757.md). L1 nit dispositions cross-checked against [NON-MATERIAL-NITS-APPLIED.md](NON-MATERIAL-NITS-APPLIED.md) then re-checked in the **current** live spec.
