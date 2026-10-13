# Cursor Task kimi-k3-high (no Pi)

RFL round 2 — rung 5 review-only of the `router_subagent_surfaces_85bf9f09` freeze. Raw findings only; no triage, no ACCEPT/REJECT, no Policy C, no APPLY, no freeze edits. Parent: d5150f38-4d37-458d-9bdb-5e6f985975d3.

## 0. Freeze integrity

Known post-rung-4 SHA-256: `d620d812388d26d8c8885243d09f7742ec5a7e7fd8357b038245310d34221ab0` / 641529 bytes.

Live hashing during this review (all times 2026-08-28, UTC+10):

| Time | repo `.planning/…plan.md` | `~/.cursor/plans/…plan.md` |
|---|---|---|
| ~01:21 | `28713951db27…` (641355 B) — **MISMATCH** | `d620d812…` (641529 B) OK |
| ~01:22 | `d620d812…` (641529 B) OK | `d620d812…` OK |
| 01:26:48 | `28713951db27…` (641355 B) — **MISMATCH** (mtime 01:26:48) | `d620d812…` OK |
| 01:27:43 | `d620d812…` (641529 B) OK (mtime 01:27:43) | `d620d812…` OK |

**FAIL-integrity (observed, transient).** The repo copy oscillated between the canonical post-rung-4 bytes and a stale pre-rung-4 variant at least twice inside the review window; an active sync process is rewriting it in both directions. Final state at write time: both copies `d620d812…` / 641529 B. The stale variant (`28713951db2720a81da75e64d4c69f530f5032b94c10719e1ee1fd4f1dc5368a`, 641355 B) differs in exactly 10 lines — precisely the rung-4 ACCEPT-applied fixes it should already contain: six stale `§4.2 Proposed architecture` cross-refs (L434, L435, L1286, L2243, L2404, L2747) and four pre-uniformity row headings (L1598 `(worktree merge)`, L2200 missing `(row 4)`, L2257 `(row 1 remint)`, L4038 `(specified risks)`). Full diff saved at `_copy-diff.txt` in this rung dir. Content review below is against the canonical `d620d812` bytes; the 10-line delta does not touch any mandated-topic lock text.

## 1. Verdict

**NOT CLEAN** — driven by the integrity oscillation (F-5-1) plus one internal contradiction on a mandated lock (F-5-2). On the canonical bytes alone, all eight mandated topics otherwise PASS and all brief-listed KEEP REJECT items are present.

Counts: **HIGH 1 / MED 1 / LOW 1 / NIT 1**.

## 2. Findings

### F-5-1 (HIGH) — Freeze copies not stably byte-identical; active sync oscillation
- **Location:** `.planning/router_subagent_surfaces_85bf9f09.plan.md` vs `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`; integrity requirement at plan L4381 (Appendix F: "This file and `~/.cursor/plans/…` must remain byte-identical after every edit").
- **Observed:** repo copy flipped `28713951…` → `d620d812…` → `28713951…` → `d620d812…` across ~6 minutes of review (mtimes 01:22, 01:26:48, 01:27:43). The stale variant lacks the rung-4 APPLY fixes (see §0).
- **Impact:** any rung hashing or quoting the repo copy can silently review pre-rung-4 bytes; rung-4's accepted fixes intermittently vanish from the repo-side freeze; Appendix F's byte-identical clause was violated twice during this window. Rung 6 verify could PASS or FAIL depending on timing.
- **Recommendation:** parent to identify and quiesce the competing sync writer (plan-sync hook/watcher direction fight) before rung 6; re-hash both copies at rung-6 start. Do not "fix" by editing freeze content — the canonical bytes are already correct.

### F-5-2 (MED) — Executor unspecified-effort default contradicts the Grok 4.6 High (not XHigh) lock
- **Location:** plan L1206 and L1210 vs L1164 and L1299.
- **Observed:** L1206 states "Executor defaults to the highest available thinking effort for that runtime unless the user specifies a level", and the L1210 table gives Cursor Executor default "`xhigh` if supported, else `high`". The same paragraph's tier overlay (L1206) and the Executor role (L1164) lock the opposite: "When a tier thinking-level is unspecified, use the host built-in Executor tuple (Cursor: Grok 4.6 High — **not XHigh** as the unspecified default)"; the built-in table (L1299) confirms Cursor Executor = Grok 4.6 High. For Cursor `host_native`, `xhigh` slugs exist, so "highest available" ≠ the locked default.
- **Impact:** an implementer reading the table/general sentence would default an unspecified Cursor Executor (Regular/Complex tiers) to Grok 4.6 XHigh, violating mandated topic 1's lock and the workspace subagent policy the freeze codifies.
- **Recommendation:** parent Policy C — likely scope "highest available" to user-named models outside the built-in-tuple path, or correct the L1210 Cursor cell to `high` for the unspecified case.

### F-5-3 (LOW) — §3.3 "listed in full below" completeness claim vs locks living only outside the KR catalog
- **Location:** plan L921–923 vs L487/L4338 (`/sb:multi-ai-task` retired, no alias), L836/L2771 (no public `/sb:agent-omni`; OmniRoute routing-only), L672 (`/sb:improve` always a Job), L858/L2193 (`primary_checkout` sole write root); named-themes list L999–1000.
- **Observed:** §3.3 self-describes as "the **only canonical KEEP REJECT catalog**" with "Every KEEP REJECT lock from the freeze … listed in full below", and the named-themes list omits the items above. All of these locks ARE present and consistent elsewhere (LS-retire-multi-ai, LS-agent-pin, LS-workflow-evolution, §4.3, §2.3, Appendix D) — the gap is the completeness claim, not the locks.
- **Impact:** a reader treating §3.3 as exhaustive (as instructed) would miss four brief-mandated KEEP REJECT-class locks.
- **Recommendation:** either add KR pointer entries (as done for KR-kr-13/15/16/17) or soften L921–923 to "canonical KR-* catalog; further locks live in the LS-* entries they cite".

### F-5-4 (NIT) — TOC anchor for the "As-is (today)" heading likely broken under GitHub slug rules
- **Location:** plan L212 (TOC) vs heading L1363.
- **Observed:** TOC link `#as-is-today-canonical-skill-skillssilver-new-workflowskillmd` (single hyphen after "today"); the body heading contains "today) — Canonical" whose em-dash slugifies to a double hyphen (`#as-is-today--canonical-skill-…`) under github-slugger rules. Only unresolved anchor of 276 internal links checked.
- **Impact:** dead TOC jump on GitHub-rendered views; cosmetic.
- **Recommendation:** regenerate that one TOC anchor (double hyphen) or drop the em-dash from the heading.

## 3. Mandated topics (canonical `d620d812` bytes)

1. **Executor Trivial/Regular/Complex — PASS with F-5-2 tension.** Trivial → FAST `/sb:fast`, classified-trivial, not a Job (L1164, L1326); Regular/Complex are Job Executor thinking-levels (L1164); unspecified default Grok 4.6 High, not XHigh (L1164, L1206, L1299); Fast forbidden unless the user says Fast (L1164, L1206, L742). Contradictory "highest available / `xhigh` if supported" residue at L1206/L1210 filed as F-5-2.
2. **Public trio — PASS.** `/sb:ladder` | `/sb:fusion` | `/sb:panel` (+`/sb:panel-end`) first-class Jobs (L737, L748, L478–479, Appendix D L4329–4335, FR-13 L602). Zero occurrences of `/sb:parallel` or `/sb:council` in either copy. "Explicitly **not** Perplexity's one-shot Model Council" present (L478, L748, L4329).
3. **AP 1.0 partial emit after docs-release — PASS.** Feasibility "partial — not yet a 1:1 replace" (L1021); additive generate-only emit (L1038, §4.8 L2755–2771); `ap10-partial-emit` after docs-release, not a numbered WS, not Part A (L659, L3349–3359, L3808).
4. **Doctor (WS7) — PASS.** `/sb:doctor` public inspect + setup/health/diagnosis/troubleshooting/`--fix` (L497, Appendix D L4348); WS7 owns Omni doctor setup+health+diagnosis+`--fix` from absorbed omni SHA `745c7f41…` (L3776, L4189).
5. **KEEP REJECT catalog consistency — PASS with F-5-3.** All brief-listed items present: exclusive `wbs-projector` (L939, L999), `primary_checkout` sole write root (L858, L2193), DFS tri-color + two-limb mint (L939), FAST not a Job + `/sb:fast` required + short order Executor → Verifier → Validator (L931, L999), `/sb:improve` always a Job (L672), Authorizer not Approver (L971), no `/sb:multi-ai-task` (L487, L770, L4338), no `sb:agent-wrap` (L492, L983), OmniRoute routing-only (L498, L2771), no public `/sb:agent-omni` (L504, L836, L2902), public `/sb` no dual `/silver` (L963), catalog generated (L927). Completeness-claim gap filed as F-5-3.
6. **Q1–Q3 — PASS.** Q1 FAST unify + required `/sb:fast` + short order + not a Job + `/sb:improve` always Job (L4160–4171). Q2 decided (A): WS1 emit, WS4 Job+FAST runtime, WS7 docs/Doctor/site (L4173–4177). Q3: `WF-DEEP-RESEARCH` + public `/sb:deep-research`, legacy as `/sb:legacy-dr`, no multi-ai-task alias (L4179–4185, LS-deep-research L811–821).
7. **FAST not a Job — PASS.** L522, L801, L1436, L2180, L3266 (row 36 FAST-scoped), GST exclusion consistent everywhere checked.
8. **Ship order — PASS.** WS0 → WS0b → WS1–7 → WS8 → docs-release, then `ap10-partial-emit` (L653–660, L3329–3359, L3801–3808); Part A before Part B inside WS1–WS7 (L660, L3335–3347, L3368).

## 4. HOLDs honored / not filed

- **F-2 HOLD:** duplicated `#### blocked_advisor_state (row 14)` at L3123 and L3317 confirmed present and consistent (retired/non-classifying; warn-only). Intentional; not filed.
- **Row-1 heading triple** (`#### blocked_corrupt_state (row 1)` at L1598, L2257, L4038) is the rung-4 uniformity end-state; each site is context-specific (worktree merge / remint revoke / risks). Not filed.
- **NIT-1 not re-raised:** the only `Proposed architecture` occurrence in the canonical bytes is the legitimate SHA-lineage receipt at L4208. The six stale `§4.2 Proposed architecture` cross-refs exist **only** in the oscillating stale repo variant — covered by F-5-1, not filed as content findings.
- KR-kr-18 self-described duplicate pointer (L993–995) is documented as intentional; not filed.

## 5. Appendix F self-check (canonical bytes, recomputed)

- YAML frontmatter: exactly 1 block (L1–125); exactly **35** todos, all `pending` — matches L4158 arithmetic (23+3+5+1+1+1+1) and L4374.
- Exactly one `#` title, one `## How to read this document`, one `## Table of contents`; one mermaid fence; no standalone Addendum headings.
- 276 internal anchor links checked; 1 suspect (F-5-4).
- Failure-mode table rows 1–42 complete and ordered (L2989–3032); rows 34/35 dashboard-only, row 36 FAST-scoped, rows 37–40 mint-class distinctions, rows 41/42 HINST-01 — all consistent with the row detail sections spot-checked (rows 1–5, 14, 36–42).

## 6. Method note

Graphify query run first (396-node subgraph; oriented on KEEP REJECT / Q1–Q3 / ship sequence nodes). Section reads via sandboxed extraction; mandated quotes verified against current on-disk bytes with `rg` after the integrity oscillation was detected. No freeze bytes were modified; no commits; branch untouched (main).
