# Cursor grok-4.6-high (Pi hang×2 substitute)

Independent RFL round-2 rung 10 review. Native Cursor Task Grok 4.6 High after named Pi `claude/claude-opus-5-high` hung twice (EXIT 124). Review-only. No APPLY, no Policy C, no verify, no rung 11, no freeze edits, no branch switch.

## Freeze identity (hashlib.sha256, start + immediately before this file)

Expected: `564c94ab56734e7bbb0e49ef009cfcce2edc2edafc5c42835e4ce481dfd114f4` / **646464** bytes.

| Copy | SHA-256 | Bytes | Match |
|---|---|---|---|
| `.planning/router_subagent_surfaces_85bf9f09.plan.md` | `564c94ab56734e7bbb0e49ef009cfcce2edc2edafc5c42835e4ce481dfd114f4` | 646464 | yes |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `564c94ab56734e7bbb0e49ef009cfcce2edc2edafc5c42835e4ce481dfd114f4` | 646464 | yes |
| `git show HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` | `564c94ab56734e7bbb0e49ef009cfcce2edc2edafc5c42835e4ce481dfd114f4` | 646464 | yes |

Obsolete SHA `e48a524b…` / 644327 was **not** reviewed. Copies are byte-identical; no split; review proceeds.

Line count of verified freeze: **4383**. Quotes below are from on-disk Python dumps of those bytes, not lean-ctx compressed Read.

**HEAD note (not a freeze split):** git `HEAD` at review time is `1433879575176143513725d0f48c2a80ff1d9fc0` on `main` (memory auto-snapshots after freeze commit). `bbda814c` (`Retire public /sb:fusion; one-off panel vs sitting panel-start.`) is an ancestor. The freeze blob at `HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` is still `564c94ab…` / 646464.

## Bird’s-eye

The freeze is a shippable process spec after F-5-1: one Process-first `/sb` router, generated `sb:<route>` catalog, six roles (Orchestrator, Advisor, Executor, Authorizer, Verifier, Validator), Cursor-first MVP, FAST = classified-trivial not a Job, quality-order Part A before Part B, ship WS0 → WS0b → WS1–7 → WS8 → docs-release then `ap10-partial-emit`.

TOC (L172–348) walks PRD → Analysis KEEP REJECT → Architecture → Design/WS0–WS8 → locked clarify → appendices A–F. YAML frontmatter: **exactly 35 todos, all `pending`**, including `sb-panel`, `sb-panel-start`, `sb-ladder-panel-panel-start-compose`, `docs-release`, `ap10-partial-emit` (L19–123). Appendix F (L4376) restates that count. Appendix B (L4212–4250) maps every YAML id to a named test and WS.

Live-spec MUST catalog is in §2.7 (LS-plan-executed-coverage through LS-autonomous-e2e-order). KEEP REJECT canonical body is §3.3 (KR-* plus compact pointers). Control-plane roles are specified in §4.1. Failure-mode **headings exist for rows 1–42** in §5.1 (unique set complete). Exactly **one** mermaid block (L1493): classify → FAST short order vs Job Advisor-compose path. Q1–Q3 are under `### Clarify decisions (locked)` (L4156–4187) and marked decided.

Public `/sb:fusion` is **not** a live public command. The two `fusion` hits are historical / KEEP REJECT retirement language (L356 document-control Revised; L2773 “formerly `/sb:fusion`”). Public trio is `/sb:ladder` | `/sb:panel` | `/sb:panel-start` (+ terminator `/sb:panel-end`). No `/sb:parallel` or `/sb:council` strings. Quality-order default remains Ladder (L738, L2407).

The spec is internally strong on Executor tiers, FAST-not-a-Job, AP 1.0 partial emit, Doctor Omni expansion, and ship order. Remaining defects are KEEP REJECT catalog lag after F-5-1 (M1) and `/sb:panel-end` empty-session outcome collision (M2). Neither reopens locked product.

## Eight charter topics

### 1. Executor Trivial / Regular / Complex — **PASS**

Definitions and dispatch are implementable.

- L1165: Trivial → FAST (`/sb:fast` required, not a Job); Regular / Complex are Job Executor thinking-levels; user MAY set one `{ model, thinking-level }` for all three or per-tier; **unspecified thinking-level uses the host built-in Executor tuple (Cursor: Grok 4.6 High)**; do not substitute Extra High / XHigh; Fast forbidden unless the user says Fast.
- L1166: fail-closed classification (intent, `/sb:fast` vs Job, durable-write vs read-only, touch/scope); uncertainty → Regular Job; examples: read-only Q&A → Trivial FAST; one-file durable edit → Regular Job; multi-file/architecture → Complex Job.
- L1194 / L1208: `thinking-level` = `effort`; runtime shared unless per-tier; unspecified Cursor Executor = Grok 4.6 High, not XHigh, not highest-available.
- L1212 table: Cursor Executor default `high` (Grok 4.6 High; not XHigh as unspecified default).
- L1301 host built-ins: Cursor Executor column is Grok 4.6 High (`host_native`).
- L41 YAML `fast-short-quality-order`: Trivial maps to FAST short order; not skip-all-quality.
- Remaining “highest available” at Iterate / Levels 0–3 (L2676, L2700) is **not** unspecified Executor → XHigh (rung-5 APPLY intact; not re-filed).

Job vs non-Job / FAST overlap is consistent: Trivial is the FAST path; Regular/Complex are Jobs with full quality order.

### 2. Public trio (post F-5-1) — **PASS** (with M1 restatement lag and M2 panel-end outcome hole)

Live public ids match the locked mapping. `/sb:fusion` is retired, not aliased.

- L356 Revised: retire live public `/sb:fusion` (KEEP REJECT: no public aliases). `/sb:panel` = one-off fuse-and-done (formerly fusion); former sitting-body `/sb:panel` = `/sb:panel-start`; `/sb:panel-end` ends live `panel-start` (idempotent no-op after one-off `/sb:panel`; not Ladder). Help: `/sb:panel` is **not** a room; `-start` is.
- Glossary L166: compose grammar, FAST not a legal `<route>`, panel-end pairing, help room rule.
- LS-ladder-parallel L729–764: first-class `/sb:ladder` / `/sb:panel` / `/sb:panel-start`; Ladder default inside quality-order (L738); Panel fuse-and-done ends member sessions (L745–747); Panel-start sitting body stays live (L748); panel-end pairing/idempotence (L749); compose any Job route; FAST fail-closed as `<route>` (L762); one-level XOR (L763); WS1 emit includes `/sb:panel-end` (L764).
- YAML: `sb-panel` (L61–62 one-off Consolidator then end members), `sb-panel-start` (L64–65 sitting + panel-end), `sb-ladder-panel-panel-start-compose` (L67–68; FAST not a legal route).
- §2.3 / Appendix D rows L478–479, L484, L489 and L4331–4332, L4337, L4342: trio + terminator present; fusion **not** listed as a live public surface.
- L2407: do **not** default quality-order to `/sb:panel` (Ladder default).
- L2773: public trio restated; “No public aliases (formerly `/sb:fusion`)”.
- Zero `/sb:parallel` / `/sb:council`. Historical “Model Council” appears only as a negative (not Perplexity one-shot) at L478 / L748 / L4331.

Findings against this topic: M1 (KEEP REJECT catalog still names the old first-class duo and has no KR-* for fusion retirement) and M2 (panel-end fail-closed vs no-op when current-panel is empty). Live ids themselves are not fusion.

### 3. AP 1.0 partial emit — **PASS**

- YAML `ap10-partial-emit` (L121–123): after docs-release; generate plugin.json+skills/+optional mcp.json from skills/; keep three host adapters; not 1:1 replace.
- §3.4 L1022: **partial — not yet a 1:1 replace.** Hooks/commands/marketplace outside AP v1; Claude Code not listed as AP client in the 2026-08-27 fetch.
- §4.8 L2757–2759: not a fourth control plane; optional generated package beside three host adapters.
- LS-ship-sequence L659: `ap10-partial-emit` after docs-release; not a numbered WS; not Part A; does not replace HINST-01.
- §5.2 L3351–3361: ship order stays WS0 → WS0b → WS1–7 → WS8 → docs-release; emit starts after docs-release; dual-publish; rollback = stop generator.
- Appendix B L4250: todo maps to `test-ap10-plugin-emit.sh` after docs-release.

### 4. Doctor expansion — **PASS** (gap noted as L3)

WS7 (L3772–3778) plus YAML `omni-agent-doctor` (L100–101) specify `/sb:doctor` as inspect + **setup + health + diagnosis + troubleshooting/`--fix`** for Omni daemon/providers and five host CLIs once opted in; official OmniRoute docs (not a stale SB pin) as source of truth; `docs/OMNIROUTE.md` companion only. Also nesting-config probe/write (HNEST-01) and three-host install ensure (HINST-01). Site/help list includes `/sb:fast`, `/sb:improve`, `/sb:contribute`, `/sb:ladder`, `/sb:panel`, `/sb:panel-start`, `/sb:panel-end`, `/sb:deep-research`, `/sb:legacy-dr` (L3777). Doctor does not own Part A quality-order runtime (L101, L3343).

Gap: help/Doctor text does not require an assertion that `/sb:fusion` is retired / not an alias (L3). That does not undo the WS7 expansion.

### 5. KEEP REJECT drift — **PASS** as closed locks; **M1** is missing F-5-1 restatement in the canonical catalog

Closed locks still closed in KR-* bodies: catalog generated (KR-catalog-generated L928); FAST overlay / not a Job / short order (KR-fast-overlay L932); exclusive `wbs-projector` + DFS tri-color + two-limb mint (KR-projector-exclusive L940); no dual `/silver` (KR-no-dual-silver L964); Authorizer not Approver / not a pref key (KR-authorizer-not-pref L972); no `sb:agent-wrap` (KR-kr-15 L984); `/sb:improve` always a Job via LS-workflow-evolution pointer (L924); Q1–Q3 not reopened (L356 “No KEEP REJECT / Q1–Q3 reopen”, L4158).

Drift: fusion retirement is labeled KEEP REJECT in the Revised cell (L356) and restated at L2773, but **§3.3 has no KR-* whose lock sentence is “no public `/sb:fusion` / no alias”**. KR-kr-13 (L976) still says first-class `/sb:ladder` and `/sb:panel` (compose grammar adds panel-start). See M1. Not a silent reopen of a closed lock; it is incomplete restatement after F-5-1.

### 6. Q1–Q3 — **PASS**

L4156–4187: Q1 FAST/trivial/`/sb:improve` decided; Q2 WS1 emit vs WS4 runtime vs WS7 docs decided (A); Q3 deep-research decided (`WF-DEEP-RESEARCH` / `/sb:deep-research` / `/sb:legacy-dr`; no `/sb:multi-ai-task` alias). Companion omni is composed with **no new A/B/C** (L4189–4191). Document control L356: no Q1–Q3 reopen. YAML todos remain pending (L4160). Not reopened as product questions.

### 7. FAST not a Job — **PASS**

Glossary L147–148; product statement L386–394; KR-fast-overlay L932; FAST vs Job L1326–1328; quality-order L2162–2166 (qualified: no Advisor/Board, composition-Val, plan-time Val, A-loop, or Process-final-Val-as-Job; **does** run Executor → Verifier → Validator); mermaid L1495–1502; Q1 L4166–4173; compose L762; YAML L40–41 and L68. `/sb:fast` required. Not a legal ladder/panel/panel-start `<route>`. Rung-8 H1 qualified hops remain; unqualified “no A/V/Val” has **not** returned.

### 8. Catalog / WS ship order — **PASS**

KR-catalog-generated L928. LS-ship-sequence L653–660: WS0 → WS0b → WS1–WS7 → WS8 → docs-release; `ap10-partial-emit` after docs-release; Part A then Part B inside WS1–WS7. §5.2 heading L3331 and body L3335 / L3355 match. YAML order L19–123 and Appendix B L4252 match. Numbered WS0, WS0b, WS1–WS8 sections exist (L3372–3810).

## Integrity / ant’s-eye extras (not findings to “fix” where locked)

- **YAML:** 35 pending ids; claimed 23+3+5+1+1+1+1 = 35 (L9–10, L4160, L4252, L4376). Matches.
- **Mermaid:** exactly one (` ```mermaid ` at L1493). FAST short order drawn; Job path has Advisor → composition-Val → plan-time Val → Executor → A-loop → Verifier → Process-final Val. No duplicate mermaid.
- **Failure rows 1–42:** heading set complete in §5.1. Duplicate headings: row 1 at L1600 / L2259 / L4040 (rung-4 APPLY sites — not re-filed); row 4 at L2202 / L3049 (rung-4/7 APPLY — not re-filed); row 14 at L3125 and L3319 (**F-2 HOLD — observed, not filed**).
- **GFM:** `ws0--ws0b` count = **0**. TOC slug is `#52-ship-sequence-ws0-ws0b-ws17-ws8-docs-release` (L296). Single-hyphen after punct strip. Not filed.
- **§4.2 heading** is `Process router `/sb`, catalog generation, FAST vs Job` (L1303). Stale “Proposed architecture” not used as the live §4.2 title.
- **Row-4 architecture heading** is `#### \`blocked_launch_prompt_spec\` (row 4)` (L2202 / L3049). `VAL/TST-RFL-626` remains in bodies as a named-test bullet (expected).
- **Executor producer:** post-Val K/L is Executor; `knowledge_postwrite` is not the producer (L1161, L2158). Short order Executor → Verifier → Validator for FAST and Job role hops (L11–12, L2166, L3339).

## Locked product — drift only

| Lock | Status |
|---|---|
| Exclusive `wbs-projector` | Intact KR-projector-exclusive L940 |
| `primary_checkout` sole write root | Intact compact pointer L924 + §4.3 |
| DFS tri-color | Intact L940 |
| Two-limb mint | Intact L940 |
| FAST not a Job; `/sb:fast` required | Intact |
| Short order Executor → Verifier → Validator | Intact |
| `/sb:improve` always a Job | Intact Q1 L4171, YAML L70–71 |
| Authorizer not Approver | Intact L150, L972 |
| No `/sb:multi-ai-task` | Intact L487, L4340 |
| No `sb:agent-wrap` | Intact L492, L4345 |
| OmniRoute routing-only | Intact L164, L4351 |
| No public `/sb:agent-omni` | Intact L167, L4357 |
| Public `/sb` no dual `/silver` | Intact KR-no-dual-silver L964 |
| Catalog generated | Intact L928 |
| Ship WS0 → WS0b → WS1–7 → WS8 → docs-release then ap10 | Intact |
| Q1–Q3 locked | Intact |
| Unspecified Executor Grok 4.6 High not Extra High; Fast only if user says Fast | Intact L1165 / L1208 / L1212 |
| GFM `ws0--ws0b` = 0 | Intact |
| No public `/sb:parallel` or `/sb:council` | Intact (zero hits) |
| Public `/sb:fusion` retired; trio as locked | Live ids intact; KR catalog restatement lag = M1 |

## HIGH

**none**

## MED

### M1 — F-5-1 KEEP REJECT is not in the canonical §3.3 catalog; KR-kr-13 still names the old first-class duo

§3.3 L922: “This section is the **only canonical KEEP REJECT catalog**.” Document-control Revised L356 labels fusion retirement **KEEP REJECT: no public aliases** and names the new trio. §4.8 L2773 restates “No public aliases (formerly `/sb:fusion`).”

No KR-* entry states that lock. KR-kr-13 L976 still reads: “first-class `/sb:ladder` and `/sb:panel` (not quality-order-only modes) plus `/sb:ladder|panel|panel-start <route>` compose”. Panel-start appears only in the compose grammar, not as a first-class public Job peer. Fusion retirement is absent.

LS-ladder-parallel and Appendix D are correct for live ids. An implementer who treats §3.3 as the only closed-lock list can miss “no public `/sb:fusion` alias” and can miss `/sb:panel-start` as a first-class Job. This is missing restatement after F-5-1, not a reopen and not a live fusion command.

### M2 — `/sb:panel-end` empty `current-panel` outcome is not unique (fail-closed vs no-op)

Independent audit of the **new** names (sitting body = `/sb:panel-start`; one-off = `/sb:panel`). Not a demand for the retired `/sb:fusion` id.

Same MUST paragraph L749 (also glossary L166, §2.3 L479, Appendix D L4332):

1. Fail-closed if no matching live `/sb:panel-start` (do not mint; do not end an unrelated panel-start).
2. End-twice on an already-ended `panel_session_id` is a no-op success.
3. After one-off `/sb:panel` (members already ended), `/sb:panel-end` is an idempotent no-op.
4. Does not apply to Ladder. Partial member shutdown → recovery receipt.

When the operator supplies no `panel_session_id` and `current-panel` is empty, (1) and (3) collide: never-ran-panel-start, already-ended panel-start without id, and post-one-off-panel all look like “no matching live panel-start”. The freeze does not say how to distinguish fail-closed from success-noop (no “last completed was one-off `/sb:panel`” receipt). WS4 `test-sb-panel-end.sh` cannot uniquely code that case. L764 assigns pairing to WS4 but does not resolve the empty-current-panel fork.

## LOW

### L1 — Public inventory lists retired `/sb:multi-ai-task` but not retired `/sb:fusion`

§2.3 L487 and Appendix D L4340 give `/sb:multi-ai-task` an explicit **RETIRED** row. Fusion is omitted from those tables (correctly not listed as live). A scanner of Appendix D alone will not see fusion retirement except via L2773 / L356. Completeness gap, not a live public fusion id.

### L2 — `retire-multi-ai-task` absorb text still names only ladder and panel

YAML L109–110 and WS2 L3547: absorb into `/sb:ladder`/`/sb:panel` then delete. After F-5-1 the sitting collaboration Job is `/sb:panel-start`. Compose YAML L67–68 already includes panel-start. Absorb prose should name the trio or say “ladder / panel / panel-start” so sitting-body behavior is not stuffed into one-off `/sb:panel`.

### L3 — Doctor / WS7 help list does not require fusion-retired language

L3777 help surfaces: ladder, panel, panel-start, panel-end, fast, improve, contribute, deep-research, legacy-dr. No MUST that help/`/sb:doctor` state `/sb:fusion` is retired and not an alias. Aligns with L1.

### L4 — Compose parenthetical at L756 omits Panel-start

“Explicit `/sb:ladder|panel|panel-start clarify` **is** the multi-model independent (Panel) or sequential capability-order (Ladder) run of **that** workflow.” Panel-start sitting cycle is specified at L748; this sentence still describes two modes. Harmless if readers have L748; easy to mis-implement compose-of-panel-start as fuse-and-done.

## NIT

### N1 — §5.2 heading omits `ap10-partial-emit`

L3331 heading is `Ship sequence: WS0 → WS0b → WS1–7 → WS8 → docs-release`. Body L3351–3355 and LS L659 place emit after docs-release and refuse a numbered WS. Heading is consistent with “not a numbered WS”; a pointer in the heading would reduce TOC misses. Not a GFM `--` request.

### N2 — Mixed `sb:fast` vs `/sb:fast` in ordinary-delivery

L2397, L2410, L2414 use `sb:fast` / `classified-trivial / \`sb:fast\`` while the required public command is `/sb:fast` (L148, L386, L4334). Catalog id vs public command is explained at L4346; the mixed form is noisy, not a second product path.

## F-2 HOLD (observe only)

Duplicate `#### \`blocked_advisor_state\` (row 14)` at L3125 (canonical failure-mode catalog) and L3319 (race-fixture / worktree-merge site). L3321 body says row 14 is retired/non-classifying for Board conflict. Intentional HOLD. **Not filed as a fix.**

## Already applied (rungs 4–8) — no regression

- §4.2 title is the process-router / FAST vs Job heading (not stale Proposed architecture).
- `blocked_corrupt_state` (row 1) and `blocked_launch_prompt_spec` (row 4) remain at the APPLY sites.
- Unspecified Executor “highest available thinking effort” sentence has **not** returned; Cursor unspecified is Grok 4.6 High.
- §3.3 completeness is qualified with compact pointers (L924).
- FAST hops stay qualified (L2162, L1161, mermaid L1495–1498).
- Classification + thinking-level=effort contract present (L1165–1166, L1194, L1208).
- GFM `--` not demanded; `ws0--ws0b` stays 0.

## Verdict

**NOT CLEAN**

HIGH: 0 · MED: 2 (M1, M2) · LOW: 4 (L1–L4) · NIT: 2 (N1, N2)

Eight topics: 1 PASS · 2 PASS · 3 PASS · 4 PASS · 5 PASS (M1 restatement) · 6 PASS · 7 PASS · 8 PASS.

CLEAN requires zero HIGH and zero MED. M1 and M2 remain. Do not treat this review as ladder PASS or as a start of rung 11.
