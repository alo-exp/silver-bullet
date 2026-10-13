# Cursor grok-4.6-high (Pi hang×2 substitute)

Independent RFL round-2 rung 11 review of the live freeze after rung-10 APPLY `f507e80f`. Native Cursor Task Grok 4.6 High after named Pi `claude/claude-opus-5-xhigh` hung twice (EXIT 124, last hard-timeout 7200s, named-model-ran yes, 779-byte checkpoint stub). Review-only. This is not a copy of rung-10 or any prior-rung review. OpenCode rungs 1–3 remain SKIP. No Policy C, APPLY, verify, YAML execution, freeze edits, or branch switch.

## Freeze identity (hashlib, start and immediately before write)

Expected: `088a18a6dc755ffee2ec68755cf72df0d28c5fde53d9c6f86198fb6672719f4e` / **648963** bytes. Live freeze is 4389 lines. Branch `main`. HEAD at write: `1369b96ebad69b6a3df295a7a70f032fc24bfd24` (descendant of freeze APPLY `f507e80f`; brief named `33c203e4` as an earlier descendant). All three copies MATCH at review start and immediately before this write; copies are byte-identical.

| Copy | Bytes | SHA-256 | Result |
|---|---|---|---|
| Repo working tree `.planning/router_subagent_surfaces_85bf9f09.plan.md` | 648963 | `088a18a6dc755ffee2ec68755cf72df0d28c5fde53d9c6f86198fb6672719f4e` | MATCH |
| Cursor plans `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | 648963 | `088a18a6dc755ffee2ec68755cf72df0d28c5fde53d9c6f86198fb6672719f4e` | MATCH |
| `git show HEAD:.planning/router_subagent_surfaces_85bf9f09.plan.md` | 648963 | `088a18a6dc755ffee2ec68755cf72df0d28c5fde53d9c6f86198fb6672719f4e` | MATCH |

Line cites below are from hashlib-verified on-disk bytes (Python over the working-tree copy after SHA match). Not from lean-ctx compressed Read. Replaced stub: 779 bytes, first line `# Pi claude/claude-opus-5-xhigh` (rejected checkpoint-stub header). Graphify CLI query run first (MCP `user-graphify` was in error; CLI returned 456-node subgraph including the freeze plan node). agentmemory `memory_save` at start.

Obsolete SHAs not reviewed: `e48a524b…` / 644327; `564c94ab…` / 646464.

## Verdict

**CLEAN**

HIGH: **none**. MED: **none**. LOW: **none**. NIT: **none**.

Rung-10 APPLY (`f507e80f`) locks are still on disk. No regression of ACCEPT’d items. No new contradiction on the eight charter topics. YAML todos remain `pending` because the freeze is planning-only (L128, L360), which matches the claimed ship rather than contradicting it.

## Charter topics (PASS/FAIL)

### 1. Executor Trivial / Regular / Complex — **PASS**

Bird’s-eye: three named Executor complexity tiers, one shared runtime unless per-tier override, `thinking-level` = `effort`, classification fail-closed to Regular Job. Cursor unspecified default is Grok 4.6 High, not Extra High / XHigh. Fast only if the user says Fast.

Ant’s-eye (hashlib lines):

- L1170: **Trivial** (no complexity) → FAST path (classified-trivial, **not a Job**, `/sb:fast` required). **Regular** / **Complex** are Job Executor thinking-levels. User MAY set one `{ model, thinking-level }` for all three or per-tier; user-named per-tier wins. Unspecified thinking-level uses the host built-in Executor tuple (Cursor: **Grok 4.6 High**); do **not** substitute Grok Extra High / XHigh as the unspecified default; Fast is forbidden unless the user explicitly says Fast.
- L1171: Classification inputs = user intent, requested route (`/sb:fast` vs Job), durable-write vs read-only, file-touch/scope. Uncertainty or mixed signals → **Regular Job** (not FAST). Examples: read-only Q&A → Trivial FAST; one-file durable edit → Regular Job; multi-file or architecture change → Complex Job.
- L1199: Executor complexity-tier `{ model, thinking-level }` maps onto `{ runtime, model, effort }`; runtime shared across Trivial/Regular/Complex unless per-tier runtime is specified.
- L1213: When a tier thinking-level is unspecified, use the host built-in Executor tuple (Cursor: Grok 4.6 High — not XHigh as the unspecified default; not highest-available). Fast remains forbidden unless the user explicitly says Fast. User-named Extra High / XHigh still wins when explicit.
- L1217: Cursor Executor default `high` (Grok 4.6 High; not XHigh as unspecified default).
- L1306: Host built-in table Cursor Executor = Grok 4.6 High (`host_native`).
- L1333: Executor tier Trivial maps to FAST; Regular and Complex are Jobs (full quality order). Orchestrator classifies using the Complexity-tiers contract (uncertainty → Regular Job, not FAST).

“Highest available” remains only on Iterate Ladder Verifier/Validator rungs (L2705: `verifier_max` / `validator_max`). That is not unspecified Executor → XHigh (rung-5 APPLY still intact). The removed sentence “Executor defaults to the highest available thinking effort” has not returned. YAML `model-preferences` (L85–87) restates Trivial/Regular/Complex and Authorizer-not-a-pref-key.

Overlap with FAST is explicit, not dual-product: Trivial = classified-trivial = FAST, not a Job (L147–148, L1170, L1333).

### 2. Public trio post fusion retirement — **PASS**

Bird’s-eye: public first-class Jobs are `/sb:ladder` | `/sb:panel` | `/sb:panel-start` plus terminator `/sb:panel-end`. Public `/sb:fusion` is **retired** (KR-no-public-fusion: no alias). `/sb:panel` = one-off fuse-and-done; `/sb:panel-start` = sitting; `/sb:panel-end` ends live panel-start only; no-op after one-off `/sb:panel` with last-panel receipt; fail-closed without receipt; not Ladder. Help: `/sb:panel` is not a room; `-start` is. Quality-order default **Ladder**. No public `/sb:parallel` or `/sb:council` (zero occurrences of those public ids). No `/sb:multi-ai-task` as a live command (RETIRED row, no alias).

Ant’s-eye:

- L166 glossary: compose grammar `/sb:ladder|panel|panel-start <route>`; `/sb:fast` is not a legal `<route>`; `/sb:panel-end` pairing with fail-closed / one-off no-op / end-twice no-op; Does not mint a Job; Does **not** apply to Ladder; Do not invent `/sb:fusion`. Help: `/sb:panel` is **not** a room; `-start` is.
- L356 Document control Revised 2026-08-28: retire live public `/sb:fusion`; `/sb:panel` is one-off fuse-and-done (formerly `/sb:fusion`); former sitting-body `/sb:panel` is `/sb:panel-start`; public trio named; Help room sentence; YAML/tests renamed (`sb-panel` / `sb-panel-start` / `sb-ladder-panel-panel-start-compose`).
- L478 `/sb:panel-start`: sitting body; member interactive sessions maintained; not Panel fuse-and-done; not Perplexity one-shot Model Council; Not FAST; No `/sb:multi-ai-task`.
- L479 `/sb:panel-end`: live match → end that panel-start; empty current-panel without `panel_session_id`: no live match **and** no last-panel receipt → **fail-closed**; last completed one-off `/sb:panel` → **idempotent no-op success**; panel-start already ended → **no-op success**; Does not mint a Job; Does **not** apply to Ladder; Do not invent `/sb:fusion`.
- L482 and L4340: `/sb:fusion` **RETIRED this ship**. Must **not** appear as a public `/sb` or `/silver` route. **No alias.** Not a live command. One-off is `/sb:panel`; sitting is `/sb:panel-start`.
- L485 `/sb:ladder`; L490 `/sb:panel` fuse-and-done then **ends member sessions**.
- L488 `/sb:multi-ai-task` **RETIRED this ship**; **No alias.**
- L739: Inside quality-order, if the user specifies no mode, **Ladder is the default**.
- L743: Fast remains forbidden unless the user explicitly says Fast (Ladder rung order).
- L749–750: Panel-start sitting cycle; panel-end pairing/idempotence restated (rung-10 M2 still present).
- L757 compose parenthetical: sequential capability-order (Ladder), multi-model independent fuse-and-done (Panel), or sitting-cycle (Panel-start). Rung-10 L4 still present.
- L763: FAST `/sb:fast` is **not** a legal `<route>` (fail-closed).
- L764: one-level compose; nested ladder/panel/panel-start fail-closes; Do not invent `/sb:multi-ai-task`.
- L979–981 `### KR-no-public-fusion`: KEEP REJECT — no public `/sb:fusion` / no alias. Public first-class Jobs are `/sb:ladder`, `/sb:panel`, and `/sb:panel-start` (+ terminator `/sb:panel-end`). `/sb:panel` is one-off fuse-and-done; `/sb:panel-start` is the sitting body. Compact pointer also at L925 and KR-kr-13 L977.
- L2778: Public trio remains `/sb:ladder` | `/sb:panel` | `/sb:panel-start` (+ `/sb:panel-end`). Help room sentence. No public aliases (formerly `/sb:fusion`).
- L3782 / L4375: Help/`/sb:doctor` MUST state `/sb:fusion` is retired and not an alias (rung-10 L3 still present).
- L3418: `/sb:panel` worker `PANEL.md`; formerly `FUSION.md` — historical rename, not a live public fusion id.

`/sb:fusion` appears 16 times; every live-spec site is RETIRED / do-not-invent / formerly / Help-must-state-retired. No leftover treating fusion as a live public command. `/sb:parallel` count 0; `/sb:council` count 0. L3366 forbids introducing parallel-council aliases in the AP emit test. YAML `sb-panel` (L61–63) ends member sessions; `sb-panel-start` (L64–66) is the sitting Job + `/sb:panel-end`.

### 3. AP 1.0 partial emit after docs-release — **PASS**

- L17 YAML overview: Agent Plugins 1.0 is **partial** — not a 1:1 replace; after docs-release (§3.4 / §4.8).
- L121–123 YAML `ap10-partial-emit` **pending**, after docs-release; `test-ap10-plugin-emit.sh`; keep three host adapters.
- L1027: **No. Decision: partial — not yet a 1:1 replace.**
- L1044: Generate an AP 1.0 tree as an **additive emit**. YAML `ap10-partial-emit`.
- L2762–2778 §4.8: not a fourth control plane; not 1:1 replace of `/sb` / six roles / FAST-not-a-Job / HINST-01.
- L3336 heading stays `WS0 → WS0b → WS1–7 → WS8 → docs-release` (rung-10 N1 REJECT-as-wrong still honored: `ap10-partial-emit` is **not** in the heading).
- L3356–3360: `ap10-partial-emit` starts **after docs-release**. Not a numbered WS. Dual-publish three host packages.
- L3815: After docs-release, YAML `ap10-partial-emit` may generate the AP 1.0 additive tree; it does **not** replace the second docs pass.
- L4255 Appendix B maps `ap10-partial-emit` to after docs-release.
- L660 LS-ship-sequence: partial emit is **after docs-release**, **not** a numbered WS that reorders the ship, **not** Part A.

### 4. Doctor expansion (WS7) — **PASS**

WS7 (L3777–3806) owns docs/Doctor/site only (runtime stays other WS). Required Doctor surfaces:

- L498 / L4356: `/sb:doctor` public inspect + setup/health/diagnosis/troubleshooting/`--fix`; Omni binary/daemon/providers + five host CLIs once opted in.
- L3782: update `scripts/sb-doctor.sh` plus help for `/sb:fast`, `/sb:improve`, `/sb:contribute`, `/sb:ladder`, `/sb:panel`, `/sb:panel-start`, `/sb:panel-end`, `/sb:deep-research`, `/sb:legacy-dr`, OmniRoute / agent-slug, autonomous E2E order. Help/`/sb:doctor` MUST state `/sb:fusion` is retired and not an alias. AP 1.0 partial-emit **docs** may land here; generators stay `ap10-partial-emit` after docs-release.
- L3783: Omni setup + health + diagnosis + troubleshooting/`--fix` (origin doctor-fix; D10-style); consult official OmniRoute docs when opted in; opted-out tools pass as `disabled`.
- L3793: Init/Doctor must probe host nesting config, write documented max if unset/below, skip if already at max, not probe unrelated knobs, and ensure SB installed on present Cursor/Codex/Claude hosts.
- YAML `omni-agent-doctor` (L100–102) and Appendix B L4248 map to WS7 tests `test-silver-doctor.sh` / `test-router-doctor-report.sh`.
- L2970: Doctor reports which bind path resolved (process env vs `rt_git_main_worktree_root` fallback).
- L1243: Init warns if Advisor equals Executor; Doctor shows the warning; do not hard-refuse with `blocked_advisor_state`.

No gap vs claimed public trio / FAST / fusion-retired / Omni Doctor. Contribute Job runtime stays WS4; Omni install/init stays WS6; autonomous E2E runtime stays WS4 — ownership split is stated, not missing.

### 5. KEEP REJECT drift; F-5-1 restated in §3.3 — **PASS**

§3.3 is the only canonical KEEP REJECT catalog (L921–923). Compact pointers at L925 include no `/sb:multi-ai-task`, no public `/sb:fusion` / no alias (`[KR-no-public-fusion](#kr-no-public-fusion)`), no public `/sb:agent-omni`, OmniRoute routing-only, `/sb:improve` always a Job, `primary_checkout` sole write root.

F-5-1 / fusion retirement is a first-class KR entry after r10 APPLY:

- L979 `### KR-no-public-fusion`
- L981 KEEP REJECT body (quoted in topic 2).
- KR-kr-13 (L975–977) is a pointer that now lists `/sb:ladder`, `/sb:panel`, **and** `/sb:panel-start`, and points at KR-no-public-fusion.

Closed locks sampled (no silent reopen): KR-catalog-generated (L927–929); KR-fast-overlay short order + not a Job (L931–933); KR-projector-exclusive DFS tri-color + two-limb mint (L939–941); KR-no-dual-silver (L963–965); KR-authorizer-not-pref Authorizer not Approver (L971–973); KR-ws0-preserve-evidence (L955–957). L4163: KEEP REJECT items are **closed**; do not reopen except the Q1 amendment to KR-fast-overlay.

The leftover compact list L1003–1006 (“Named KEEP REJECT themes… exclusive”) still points at KR-* above for full sentences and does not reopen fusion. Fusion is locked in KR-no-public-fusion / L925, so omitting the retired name from that leftover bullet is not a new contradiction.

### 6. Q1–Q3 still locked — **PASS**

- L4161 `### Clarify decisions (locked)`
- L4165: Q1–Q3 are **decided**. YAML stays pending with the 35-id arithmetic. Dual `/silver` still forbidden. No `sb:agent-wrap`. No `/sb:multi-ai-task` alias.
- L4167–4178 Q1 decided: FAST = classified-trivial; `/sb:fast` required; not a Job; not GST; not Evolution/`/sb:improve`; short order Executor → Verifier → Validator; `/sb:improve` always a Job.
- L4180–4184 Q2 decided (A): WS1 emit / WS4 runtime / WS7 docs.
- L4186–4192 Q3 decided: `WF-DEEP-RESEARCH` + `/sb:deep-research`; `/sb:legacy-dr` until retired; no `/sb:multi-ai-task` alias.
- L4163 / L356 / L4165: no KEEP REJECT / Q1–Q3 reopen in the r10 fusion retirement revision.

Not reopened as product questions.

### 7. FAST = classified-trivial, not a Job — **PASS**

- L147–148 glossary: Job vs FAST. FAST required public `/sb:fast`. Not a Job; not GST-01; not Evolution/`/sb:improve`. Maps Executor **Trivial**. Short order **Executor → Verifier → Validator**. **Not** a legal `/sb:ladder|panel|panel-start <route>`.
- L41 YAML `fast-short-quality-order`: Part A short order Executor → Verifier → Validator; Trivial maps here; not a Job; not skip-all-quality.
- L394 / L805 / L4175: FAST **must** run Executor → Verifier → Validator; **not** skip-all-quality. FAST Validator is not Job Process-final Val.
- L806 / L4178: skip list is Job GST / Advisor-first / Board / composition-Val / plan-time Val / A-loop / Process-final-Val-as-Job / post-Val K/L / Q-loop / thermos / Evolution / Authorizer-as-quality-order-role — **qualified**, not the rung-8 H1-forbidden unqualified “no A/V/Val”.
- L1166: classified-trivial I is `AF-FAST-PATH`'s Executor; no Advisor A-loop and no Job Process-final Val; FAST **does** run Executor → Verifier → Validator.
- L1333 FAST vs Job carve-out (quoted in topic 1).
- L1498–1556 single mermaid: `/sb classify trivial?` → yes `/sb:fast` → FAST Executor → FAST Verifier → FAST Validator (short order; not Job Process-final Val) → thin capture. Job path is the other branch.
- L763 compose: `/sb:fast` is **not** a legal `<route>` (fail-closed).
- L931–933 KR-fast-overlay.

Unqualified “no A/V/Val” wording has not returned as a live contradiction.

### 8. Catalog generated; ship WS0 → WS0b → WS1–7 → WS8 → docs-release then `ap10-partial-emit` — **PASS**

- KR-catalog-generated L929: complete `sb:<route>` catalog is **generated**; do not JSON-edit `docs/apo-catalog.json` as SOT.
- LS-ship-sequence L650–661: WS0 → WS0b → WS1–WS7 → WS8 → docs-release. `ap10-partial-emit` after docs-release. Inside WS1–WS7: Part A then Part B. FAST short order named. YAML todo order is the execution sequence.
- FR-16 L606; §5.2 heading L3336; body L3340; L3360; L3375; Appendix B L4257: hygiene → Part A prereqs → Part A core → Part B → WS8 → docs-release → `ap10-partial-emit`.
- Exactly 35 YAML todos, all `status: pending` (counted ids L19–L121; Appendix F L4382; L4257 arithmetic 23+3+5+1+1+1+1=35). Freeze status Planning (L360): do not run WS0/WS0b/WS1–WS8 from this rewrite. Pending YAML vs claimed ship is consistent.

WS1 emit includes `/sb:panel-start` and `/sb:panel-end` (L27, L3539) plus `/sb:fast` / improve / contribute / deep-research / legacy-dr.

## Also audited

**YAML todos vs claimed ship.** 35 pending pointers, not a claim that workstreams already shipped. Overview L9–17 matches Appendix B L4257. `ap10-partial-emit` is last. No todo still named `sb:fusion` or live fusion Job.

**Broken refs.** TOC uses GFM single-hyphen slugs. Heading L3336 slug in TOC L296 is `#52-ship-sequence-ws0-ws0b-ws17-ws8-docs-release`. String `ws0--ws0b` count = **0** (GFM lock). Nested markdown in some TOC entries (file paths, `$defs`) is noisy for a naive slugger; not filed as a GFM `--` defect (lock: do not demand double-hyphen TOC slugs).

**Truncated headings.** First-clause heading style remains at L1805 (`Nested profile`) and L2974 (`the five-field work spec`); body sentences complete the clause. L1003 “Named KEEP REJECT themes… exclusive” is the same leftover compact heading (body L1005–1006 defers to KR-*). Not a regression of rung-4/7 heading APPLY (`§4.2` current title L1308; `#### \`blocked_corrupt_state\` (row 1)` at L1582; `#### \`blocked_launch_prompt_spec\` (row 4)` architecture heading intact). Not filed.

**TOC-GFM.** `ws0--ws0b` stays **0**. Observed, not a finding.

**Mermaid.** Exactly **one** ` ```mermaid ` fence (starts L1498, closes L1556). Word “mermaid” appears 9 times (prose + fence). L1558: the Proposed-architecture mermaid is the **single** Process quality-order sketch (rung-4: remaining “Proposed architecture” as SHA-lineage / H-1 receipt is legitimate). Appendix F L4387: no duplicate mermaid block. FAST short-order and Job six-role path are both in that diagram (L1500–1545).

**Failure-mode rows 1–42.** Table in §5.1 contains unique numeric rows 1..42 with none missing.

**F-2 HOLD (observe only, not filed).** Duplicate `#### \`blocked_advisor_state\` (row 14)` at L3130 and L3324. Also table L3011 and mentions L1243 / L1288 / L3326 (retired/non-classifying). Intentional HOLD.

**Locked product drift check (report only if contradiction).** Exclusive `wbs-projector` L154 / L941; `primary_checkout` sole write root L151 / L925; DFS tri-color L941 / L1563; two-limb mint L941 / L1320; FAST not a Job; Executor→Verifier→Validator; `/sb:improve` always a Job L483 / L4176; Authorizer not Approver L150 / L973; no `/sb:multi-ai-task`; no `sb:agent-wrap` L493 / L4351; OmniRoute routing-only L164 / L499; no public `/sb:agent-omni` L167 / L4363; public `/sb` no dual `/silver` L463 / L965. No drift found that reopens these.

**Rung 4–10 APPLY regression check.** Stale `§4.2 Proposed architecture` has not returned as the live §4.2 title (L1308 is Process router `/sb`, catalog generation, FAST vs Job). `blocked_launch_prompt_spec` (row 4) heading intact. KR-no-public-fusion present. Panel-end empty current-panel fork present. RETIRED fusion rows present. Doctor fusion-retired MUST present. Compose parenthetical includes Panel-start. Public `/sb:fast` vs catalog `sb:fast` (L481 vs L494) intact (rung-10 N2). No regression.

## Bird’s-eye completeness

The freeze is still a shippable **planning** spec: PRD §2 + LS-* MUST catalog, KEEP REJECT §3.3 (including new KR-no-public-fusion), architecture §4 (six roles, FAST vs Job, quality order, ladder/panel/panel-start), design §5 (rows 1–42, WS0→WS8, Part A/B, AP emit after docs-release), locked Q1–Q3, Appendix D inventory matching §2.3. Control-plane roles remain six; Authorizer is TCB not a preference key. Public trio replace (not dual-run) former Fusion vs sitting Panel. Quality-order default Ladder. Catalog generated. YAML 35 pending is the execution backlog, not a silent claim of completion.

Ant’s-eye did not find a HIGH/MED contradiction remaining after r10 APPLY. Residual first-clause headings and the leftover compact KR-themes bullet are style, not lock drift.

## CLEAN

Zero HIGH. Zero MED. Eight charter topics **PASS**.

Replaced rejected stub (779 bytes, `# Pi claude/claude-opus-5-xhigh`). This file is the official rung-11 substitute review. Graphify update + agentmemory `memory_save` follow the write.
