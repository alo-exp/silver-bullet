---
decision_class: resolved
status: captured-complete
q1: A
q2: merge-and-execute-with-freeze
q3: role-performance-vs-token-cost
q4: split-producer-default-plus-overturn
q5: a-rounds-vs-later-fail
q6: unifier-keep-rate
q7: 7-days-per-assignment
l22: assignment-scope-global-or-project
created: 2026-08-30
topic: quality-order-role-analytics
clarify-path-rule: scripts/lib/planning-clarify-path.sh
plan-basename: quality-order-role-analytics
mode: light-FLOW-3
next: silver:plan
supersedes: ~/.cursor/plans/quality-order_role_analytics_03e76c86.plan.md
freeze-sha256: 48192e7565708f58560d13f0ea415145c5fce9ac03a55c68d8cb22254b4ab543
---

# Clarify Brief — Quality-order performance + assignment analytics

Standalone analytics plan (later: [`.planning/quality-order-role-analytics.plan.md`](quality-order-role-analytics.plan.md)). **Do not** merge into freeze twins this session. **Do not** edit [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](router_subagent_surfaces_85bf9f09.plan.md) or `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`.

## Problem statement

Silver Bullet’s freeze quality order adds hops (composition-Val, plan-time Val, I, Advisor two-clean, Ver-loop to `v_verified`, Process-scope Advisor/Verifier, Process-final Val). Those hops cost extra model calls. The operator has no **honest, encoder-written** evidence that (1) the order improves the actual work enough to justify that cost, or (2) each role’s model / thinking-effort / Panel membership is the most cost-effective assignment.

A prior Cursor draft ([`quality-order_role_analytics_03e76c86`](file:///Users/shafqat/.cursor/plans/quality-order_role_analytics_03e76c86.plan.md)) mixed freeze hops with analog review-ladder nomenclature and an operator **real-time ops** view (who is active, queue depth, idle-kills). **The user superseded that draft.** This brief is the replacement framing.

## Current context

- **Freeze (KEEP, byte-identical twins, Planning. Not execute.):** SHA-256 `48192e7565708f58560d13f0ea415145c5fce9ac03a55c68d8cb22254b4ab543` (655179 bytes). Verified on disk this session. Appendix F: twins must stay identical; this session does not touch them.
- **Out of scope:** SPEC-template work (`.planning/spec_template_world_class.plan.md`, `.planning/spec-template-world-class/`, `.planning/rfl-spec-template-world-class/`).
- **Cautionary lesson (keep, no analog-ladder names):** [`.planning/VERIFIER-FAIL-ANALYTICS.md`](VERIFIER-FAIL-ANALYTICS.md) derived rates from transcript/artifact scrape. That is **audit-only**. Rates must come from encoder/ledger structured close. Do not put grep-bait verdict strings in instruction templates.
- **Project docs** (`.planning/PROJECT.md`, `REQUIREMENTS.md`, `ROADMAP.md`, `STATE.md`) describe shipped SB orchestration; they do **not** yet own quality-order performance analytics. Freeze §2.6 defers dedicated product-observability/SRE WF; GST-01 is the Jobs dashboard, not product telemetry.
- **AA ranking source (fetched this session via Context Mode, not WebFetch):** [Intelligence Index vs Cost](https://artificialanalysis.ai/?total-cost=intelligence-vs-total-cost) shows a Pareto line (“Most attractive quadrant”). Default page: 29 of 624 models. Index v4.1.1 (GDPval-AA v2, τ³-Banking, Terminal-Bench v2.1, SciCode, Humanity's Last Exam, GPQA Diamond, CritPt, AA-Omniscience, AA-LCR). Prior in-repo snapshot: [`.planning/omni-free-aa50-2026-08-26/_ingest_aa.md`](omni-free-aa50-2026-08-26/_ingest_aa.md) (2026-08-25, 618 slugs). Operator must **Select all** in the models dropdown for the full frontier; SPA chart is not a spawn-time catalog.
- **Freeze already:** pinned in-repo catalog (refreshable); **no live vendor-doc fetch at spawn**; unified comparator uses Intelligence Index score then AA source rank. Public Panel commands already exist in freeze substance (`/sb:panel` | `/sb:panel-start` | `/sb:panel-end`); heading text still says “Board of Advisors”. User lock for **this plan’s language:** Board → persisting **Panel**.
- **Graphify (CLI):** MCP `user-graphify` down; `graphify query` used before exploration. Clarify skill: `skills/silver-clarify/SKILL.md` (light FLOW 3; not `next=spec`).

## PM framing

| | |
|---|---|
| **Who** | The SB operator (human), and later SB itself when auto-assignment is opted in |
| **Job** | After quality-order runs, know whether the extra hops paid off, and whether each role’s model/effort/Panel membership should stay, upgrade, or drop |
| **Value** | Spend the least for the best quality-order results, with data — not folklore |
| **Success** | Encoder-backed views prove (or falsify) quality-order cost-effectiveness; per-role fitness and Panel member contribution are measurable; SB can **recommend** (default) or **auto-change** (init opt-in) assignments using local outcomes + AA Pareto ranking |

This is **performance visibility** and **model-assignment evaluation**, not operational visibility and not product APM.

## Visual companion

`decision_class: autonomous_default` — `--text`. Topic is a plan + metrics, not a product UI. Operator real-time dashboard is **out of scope**. AA chart indexed via `ctx_fetch_and_index` (SPA; not a substitute for a pinned catalog).

## Options considered

1. **Simpler — post-facto views + recommend-only.** Ledger + next-day-session recommendations. No auto-change. Rejected as the *whole* plan: user locked a second-half vision (SB auto-determines model/Panel). Keep as **Wave A default behavior** when opt-in is off.
2. **Ambitious — auto effort → model → Panel at `/sb:init` opt-in.** Matches user vision. Keep as **Wave B**, gated: first session of the day, only with high-confidence data.
3. **Remove/simplify — Doctor “ledger freshness” only.** Rejected: does not answer effectiveness or assignment fitness.
4. **Opposite — operator real-time ops dashboard** (active role, queue depth, idle-kills as ops). **Rejected by user.** Do not revive from the superseded draft.

**Recommended:** one standalone plan covering **both** Performance Analytics and Monitoring **and** Model Assignment Evaluation. Post-facto views only. Panel language. Generic quality-order hops. Auto-change only if opted in at `/sb:init`; otherwise recommend at the start of the next day’s first session.

## Recommendation

Lock the direction below. Leave numbered **blocking** questions for the user (Q1 asked this turn). `silver:plan` writes [`.planning/quality-order-role-analytics.plan.md`](quality-order-role-analytics.plan.md) after Q1–Q7 resolve (or after remaining Qs are explicitly deferred with `autonomous_default`).

### Locked (user + freeze KEEP)

| ID | Lock | Source |
|---|---|---|
| L1 | Generic quality-order analytics. **No** analog-ladder nomenclature in the plan (no Policy F, no `verify_1`/`verify_2`, no CLEAN/NOT CLEAN as ladder terms, no rungs-as-ladder). | User reframing |
| L2 | No operator real-time ops dashboard (who is active, queue depth, idle-kills as ops visibility). | User |
| L3 | **Panel** (not Board). Freeze “Board of Advisors” → persisting Panel (`/sb:panel`). Analytics language is Panel now; freeze twins unchanged until user says merge. | User; freeze public trio already `/sb:panel*` |
| L4 | Two goals: (1) is the quality order effective / cost-effective? (2) is each role’s model assignment effective? | User |
| L5 | Vision: SB uses analytics to pick the most cost-effective model or multi-model Panel for quality-order roles. Poor role performance → bump **thinking effort** one step; if already max effort, move to the **next more capable** model on the AA Intelligence Index vs total-cost Pareto. | User |
| L6 | Auto **change** only if opted in at `/sb:init`. Else **recommend** at the start of the first session of the day, and only if enough high-confidence data exists. | User |
| L7 | Write a standalone analytics plan first; **this session does not edit freeze twins**. Intended destination (Q2): **merge into the subagent-surfaces freeze and execute as one coherent plan**. No SPEC-template scope. | User; Q2 |
| L8 | Six roles, five pref keys; Authorizer is TCB, not a pref key. Authorizer LLM shares Verifier model/effort (different job/tools). | Freeze §4.1 |
| L9 | Job quality order: composition-Val → plan-time Val → I → Advisor two-clean → Ver-loop `v_verified` → Process-scope Advisor/Verifier → Process-final Val. FAST: Executor → Verifier → Validator (not a Job). | Freeze §4.5 + ordinary-delivery; user KEEP |
| L10 | Encoder/ledger writes the row (role, run_id, hop, verdict, ts, artifact, sha if freeze-touching). Fail-closed if a hop completes with no ledger row. Transcript scrape is audit-only. No grep-bait verdict strings in instruction templates. | User + freeze fail-closed spirit + cautionary lesson |
| L11 | GST-01 stays Jobs dashboard. Do not stuff this analytics into GST or `origin/main` status heartbeats. | Freeze GST-01 + deferred observability |
| L12 | Fast forbidden unless the user says Fast. Unspecified Executor on Cursor: Grok 4.6 High, not Extra High / XHigh. | Freeze + user KEEP |
| L13 | Advisory role ordinal (not a hard-block): Orchestrator < Executor < Verifier < Advisor < Validator. Same model across roles allowed (warn, do not identity-hard-stop). | Freeze §4.1 |
| L14 | Quality-order default remains **Ladder**, not Panel. Panel is opt-in / persisting Advisor multi-model. | Freeze KR-panel-public-trio-only substance |
| L15 | AA Pareto catalog: `/sb:init` (first init, then refreshable pin) may fetch/refresh the in-repo catalog. **Spawn stays offline.** No live vendor-doc fetch at spawn (KEEP not reopened). | User Q1 = **A** |
| L16 | Live rates start when the **merged freeze + analytics ship executes**. Schema is part of that one plan (not a separate analog-ladder encoder today). | User Q2 |
| L17 | Cost-effectiveness is **role performance vs cost of the assigned model(s)**, not hop-ablation vs FAST/Executor-only. Track **token mix** per task/hop and derive USD (or billed currency) from **latest official API rates of the provider actually used**. Rates via web fetch (pin/refresh like L15; **not** at spawn). If host-agent or OmniRoute proxy cannot supply per-task tokens, fall back to **AA total-cost as a general proxy**. Cost fields belong on **every** quality-order hop row. | User Q3 |
| L18 | High checker fail% **defaults** to a **producer** upgrade signal (Verifier fail → Executor, or whichever role produced the checked work). Also track **overturn rate** (producer fix that the checker then accepts) before blaming the checker as noisy/under-powered. | User Q4 = split |
| L19 | Advisor “too much” = high A-rounds per I with little later-hop improvement. “Not helping” = low intervention **and** high later Verifier/Validator fail on Executor work. Measure the pair (A-rounds per I vs later fail%), with instance lists. | User Q5 = pair |
| L20 | Panel member effectiveness = **unifier-keep rate** only (what the unifier kept from that member). Weak keep-rate is the drop-from-Panel signal. | User Q6 = keep-only |
| L21 | Recommend / auto-change only after **≥ 7 days of hop closes for the current assignment tuple** (`runtime`, `model`, `effort`, Panel membership; **`scope` added by L22**). User-changed assignments must **not** be pooled with the prior tuple; the 7-day clock is per tuple. Post-facto views may show whatever rows exist (no min n). Eval cadence remains first session of the day. | User Q7 = C + assignment-change note |
| L22 | Assignment **Scope** is **Global** (host agent) or **Per-project**. Analytics **must match Scope**: global assignment → global series; a project with a per-project scheme → **that project's** series **and** the global series still. 7-day gate stays per tuple; tuple includes `scope` (`global` \| `project:<id>`). Do **not** pool incompatible scopes as one series. When deciding outgoing → incoming for a scope, **borrow / weight** other scopes' analytics for those **same** models (outgoing and candidate incoming) so the decision is better than single-scope data alone. **MERGE NOTE:** this brief/plan **records** Scope only; another session **must incorporate** Model Assignment Scope into the main subagent-surfaces freeze twins. Do not edit those twins here. | User follow-up 2026-08-30; course-correct same day |

### Autonomous defaults (log; do not stall)

| ID | Default | Why not blocking |
|---|---|---|
| A1 | This work **is not** the deferred product-observability/SRE WF. Separate store, separate plan. Confirm-only unless the user objects. | Freeze deferred post-MVP already distinguishes GST vs product telemetry |
| A2 | Views are **post-facto** (after hop close). File/JSONL queries and summaries — not a live ops tail. | User excluded ops dashboard |
| A3 | Store: run-dir JSONL + monthly rollup under `$primary_checkout/.planning/` (extra worktrees omit ledger dirs). Privacy: no secrets, prompt bodies, work-spec full text, raw email. | Matches freeze extra-tree omit + GST refuse-write spirit |
| A4 | Include FAST short-order Verifier/Validator in **role-fitness** rates; **exclude** FAST from Job quality-order cost-effectiveness (FAST is not the six-role Job order). | Freeze FAST carve-out |
| A5 | Authorizer rows (`admit`/`deny`/`override`) may live in the same ledger as TCB health. **Model assignment** for Authorizer follows the Verifier tuple (not a fifth pref-key fitness series). | Freeze Authorizer = Verifier weights |
| A6 | Attribution: producer-upgrade default + overturn metric (L18). | User Q4 |
| A7 | Do not instrument analog-ladder encoders. Schema ships in the combined freeze+analytics plan; live rows begin at combined execute (L16). | User Q2 |
| A9 | Provider API-rate fetch and token-cost derivation refresh with the same cadence as assignment eval (init pin + first session of day), not at spawn. | Freeze spawn-offline KEEP + Q3 |
| A8 | Capability rank source = Artificial Analysis Intelligence Index vs **total cost** Pareto (not Intelligence-only). Pin + refresh; do not fetch vendor docs **at spawn** (Q1). | User + freeze catalog KEEP |

### Proposed hop × event taxonomy (seed for `silver:plan`; not freeze text)

One encoder row = one hop close. Verdict enum lives **only** in JSONL.

| Hop | Role | Event examples | Terminal / signal |
|---|---|---|---|
| Composition-Val | Validator | `comp_val_round` | `comp_val_verified` vs fail → fitness of Advisor compose |
| Plan-time Val | Validator | `plan_val_round` (ceiling 8 / `launch_id`) | `plan_val_verified` vs fail → fitness of Advisor plan |
| I | Executor | `i_start` / `i_end` | Duration + later Verifier/Validator fail on I artifacts |
| Advisor two-clean | Advisor / Panel member / unifier | `a_round`, `panel_member`, `unify` | Intervention rate; two-clean streak; member contribution |
| Ver-loop | Verifier | `ver_round` | `v_verified` vs fail; **producer** upgrade signal |
| Process-scope A/V | Advisor / Verifier | process-scope round | Same as A/V at Process join |
| Process-final Val | Validator | `val_round` | `val_validated` vs original user intent |
| FAST short-order | Executor, Verifier, Validator | `fast_*` | Role-fitness only |
| Authorizer | TCB (not pref key) | `admit` / `deny` / `override` | Admission health, not a separate model key |

**Essential metrics (freeze-justified, performance not ops)**

1. **Quality-order effectiveness:** later-hop fail rate and Process-final fail rate **with instance lists** (`run_id` + artifact), vs hop count and estimated cost. Must be able to **falsify** “the extra hops are worth it.”
2. **Cost-effectiveness:** assigned model(s) performing as expected **versus** measured hop cost (token mix × pinned provider API rates; AA total-cost proxy only if tokens unavailable). Cost on every hop (L17).
3. **Per-role model fitness:** fail% of checks **on that role’s output**; duration; blocked terminals; **cost**. Used to upgrade/downgrade model or effort.
4. **Advisor intervention:** “too much” = high A-round count / consult rate with little later-hop improvement. “Not helping” = low intervention **and** high later Verifier/Validator fail on Executor work (Q5).
5. **Panel member contribution:** which member’s output the unifier kept; unique accepted findings; later-hop success when that member’s advice was adopted; candidate for dropping a weak member (Q6).
6. **Assignment recommendation / auto-change:** effort bump then Pareto-next model; Panel membership add/drop. First session of day; high-confidence gate (Q7).

**Reject as this plan’s metrics:** GST push success; transcript-derived counts; vanity charts without instance lists; KEEP REJECT “collision rates” as runtime quality; live queue depth / idle-kills as ops.

### Implementation waves (plan-only; do not execute freeze WS)

0. **Schema + fail-closed write points** on quality-order hop close (encoder/hook/projector projection), including token mix + derived cost, shipped in the **same execute** as freeze quality-order hops (L16). No instruction-template verdict bait.
1. **Post-facto performance views** (local files / Doctor freshness optional). Prove or falsify hop cost-effectiveness.
2. **Model-assignment evaluation** — recommendations at first session of day.
3. **Opt-in auto-change** at `/sb:init` (effort then model then Panel membership), still using pinned AA catalog + local ledger. **Not** product APM WF.

## Assumptions

- `[ASSUMPTION: quality-order performance analytics is a third store, not GST and not the deferred SRE/APM WF | Status: Accepted | Owner: clarify A1]`
- `[ASSUMPTION: fail% of a checker hop is a producer-upgrade signal; overturn rate gates blaming the checker | Status: Accepted | Owner: user Q4]`
- `[ASSUMPTION: AA Pareto (intelligence vs total cost) is the capability rank; local hop outcomes are the fitness rank; both are required for “most cost-effective” | Status: Accepted | Owner: user vision]`
- `[ASSUMPTION: live HTTP to artificialanalysis.ai at spawn remains forbidden; init-time fetch/refresh of the pinned catalog is allowed (Q1 = A) | Status: Accepted | Owner: user Q1]`
- `[ASSUMPTION: the worker brief truncated the user’s full models= chart URL; indexed the `total-cost=intelligence-vs-total-cost` view instead (29/624 models until Select all) | Status: Accepted | Owner: this clarify]`
- `[ASSUMPTION: freeze heading “Board of Advisors” stays until the user authorizes a freeze edit; this plan and brief say Panel | Status: Accepted | Owner: user L3]`
- `[ASSUMPTION: a per-project assignment scheme never stops the global series; cross-scope borrow/weight informs change decisions without merging 7-day clocks | Status: Accepted | Owner: user L22]`

## Resolved questions

All blocking Qs locked 2026-08-30. `silver:plan` may write [`.planning/quality-order-role-analytics.plan.md`](quality-order-role-analytics.plan.md).

1. **AA catalog — A.** L15.
2. **Live rates — merge-and-execute-with-freeze.** L7 / L16.
3. **Cost — role-performance-vs-token-cost.** L17.
4. **Attribution — split.** L18.
5. **Advisor intervention — pair.** L19.
6. **Panel member — unifier-keep-rate.** L20.
7. **Enough — 7 days per current assignment tuple.** L21.

**Follow-up lock (not a Q1–Q7 reopen):** **L22** — assignment Scope (global vs per-project), matching analytics series, tuple `scope`, cross-scope borrow/weight. Locked 2026-08-30. **MERGE NOTE:** record-only here; incorporate Scope into the main freeze later (do not edit freeze twins from this file).

Non-blocking leftovers remain A1–A5, A8–A9 (autonomous defaults).

## Next-step notes (`silver:plan`)

After Q1–Q7: write [`.planning/quality-order-role-analytics.plan.md`](quality-order-role-analytics.plan.md). **This session still does not edit freeze twins**; merge is the intended later execute (L7 / L16).

Do **not** write `.planning/SPEC.md` / `REQUIREMENTS.md` from this skill. Do **not** commit unless asked.
