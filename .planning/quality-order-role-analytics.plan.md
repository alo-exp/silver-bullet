---
name: Quality-order performance and assignment analytics
overview: Encoder-written post-facto evidence that quality-order hops and per-role model/effort/Panel assignments are cost-effective, plus optional init-opt-in auto-assignment from local fitness plus a pinned Artificial Analysis Intelligence vs total-cost Pareto catalog.
clarify: .planning/quality-order-role-analytics-CLARIFY-260830-20260830T113928Z.md
freeze-sha256: c123d8d2b81cde1bae9a4767fbf174429d51493cd499d40f59a0eee82680e118
status: planning
merge-destination: .planning/router_subagent_surfaces_85bf9f09.plan.md (and home twin) — merged 2026-08-30 (authorized)
---

# Quality-order performance and assignment analytics

Clarify locks: [`.planning/quality-order-role-analytics-CLARIFY-260830-20260830T113928Z.md`](quality-order-role-analytics-CLARIFY-260830-20260830T113928Z.md). Supersedes Cursor draft `quality-order_role_analytics_03e76c86` (ops dashboard + analog-ladder names).

**Freeze twins merged 2026-08-30** (authorized). This addendum remains the cited provenance; normative locks live in the freeze ([LS-role-analytics](router_subagent_surfaces_85bf9f09.plan.md#ls-role-analytics)). Twins: [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](router_subagent_surfaces_85bf9f09.plan.md) and `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` (must stay byte-identical; pin `freeze-sha256` above). **Execute as one coherent ship** with the six-role quality order. Live hop rows and token rates start at that combined execute, not from this file alone (L16). Schema ships in that same plan — not a separate analog-ladder encoder.

> **MERGE NOTE — Model Assignment Scope (L22), landed.** Scope (global host vs per-project; keep global when a project has its own scheme; cross-scope borrow/weight; tuple includes `scope`) **is incorporated into the main subagent-surfaces freeze** (authorized merge 2026-08-30). Treat the freeze as having landed Scope.

Language: **Panel** / **Role Panel** (L3). Main freeze heading is now **Role Panel** (authorized twin edit 2026-08-30). Public `/sb:panel` remains the one-off Job; Role Panel is the persisting quality-order session (N=1 included). Artifact review feedback is **pack-ledger**, the same hop-review contract as RFL Policy G (`skills/silver-review-fix-ladder/SKILL.md`). Do not invent a Board or one-finding review.

### Clarify lock register (this file is the addendum SoT)

Freeze may use this document without re-reading the clarify brief. Every lock below is specified in the body; IDs are listed so none live only in the brief.

| ID | Decision |
|---|---|
| L1 | Generic quality-order hops only. **No** analog-ladder nomenclature: no Policy F, no `verify_1`/`verify_2`, no CLEAN/NOT CLEAN as ladder terms, no rungs-as-ladder. |
| L2 | No operator real-time ops dashboard (who is active, queue depth, idle-kills as ops). |
| L3 | **Panel** (not Board). Main freeze heading is **Role Panel** (authorized twin edit 2026-08-30). |
| L4 | Two goals: (1) is the quality order effective / cost-effective? (2) is each role’s model assignment effective? |
| L5 | Poor role performance → bump **thinking effort** one step; if already max, next more capable model on the AA Intelligence Index vs total-cost Pareto. |
| L6 | Auto-**change** only if opted in at `/sb:init`. Else **recommend** at the start of the first session of the day, and only with high-confidence data. |
| L7 | Standalone analytics plan first. **Superseded 2026-08-30:** freeze twins merged (authorized). |
| L8 | Six roles, five pref keys; Authorizer is TCB, not a pref key. Authorizer LLM shares Verifier model/effort (different job/tools). |
| L9 | Job quality order: composition-Val → plan-time Val → I → Advisor two-clean → Ver-loop `v_verified` → Process-scope Advisor/Verifier → Process-final Val. FAST: Executor → Verifier → Validator (not a Job). |
| L10 | Encoder/ledger writes the row (role, run_id, hop, verdict, ts, artifact, sha if freeze-touching). Fail-closed if a hop completes with no ledger row. Transcript scrape is audit-only. No grep-bait verdict strings in instruction templates. |
| L11 | GST-01 stays Jobs dashboard. Do not stuff this analytics into GST or `origin/main` status heartbeats. |
| L12 | Fast forbidden unless the user says Fast. Unspecified Executor on Cursor: Grok 4.6 High, not Extra High / XHigh. |
| L13 | Advisory role ordinal (not a hard-block): Orchestrator < Executor < Verifier < Advisor < Validator. Same model across roles allowed (warn, do not identity-hard-stop). |
| L14 | Public Job default remains **Ladder**, not `/sb:panel`. A persisting **Role Panel** is always minted for each quality-order role with ≥1 assigned model (N=1 included). |
| L15 / Q1=A | AA Pareto catalog: `/sb:init` (first init, then refreshable pin) may fetch/refresh the in-repo catalog. **Spawn stays offline.** No live vendor-doc fetch at spawn (KEEP not reopened). |
| L16 / Q2 | Live rates start when the **merged freeze + analytics ship executes**. Schema is part of that one plan. **Merged into the subagent-surfaces freeze 2026-08-30** (authorized); execute as one coherent plan. No SPEC-template scope. |
| L17 / Q3 | Cost-effectiveness is **role performance vs cost of the assigned model(s)**, not hop-ablation vs FAST/Executor-only. Token mix × latest official API rates of the **provider actually used**. If host-agent or OmniRoute cannot supply per-task tokens, fall back to **AA total-cost as a general proxy**. Cost fields on **every** quality-order hop row. |
| L18 / Q4 | High checker fail% **defaults** to a **producer** upgrade signal. Also track **overturn rate** (producer fix the checker then accepts) before blaming the checker. |
| L19 / Q5 | Advisor “too much” = high A-rounds per I with little later-hop improvement. “Not helping” = low intervention **and** high later Verifier/Validator fail on Executor work. Measure the pair, with instance lists. |
| L20 / Q6 | Panel member effectiveness = **unifier-keep rate** only. Weak keep-rate is the drop-from-Panel signal. |
| L21 / Q7 | Recommend / auto-change only after **≥ 7 days of hop closes for the current assignment tuple** (`runtime`, `model`, `effort`, Panel membership, `scope`). User-changed assignments are a **new** tuple and a new 7-day clock. Post-facto views may show whatever rows exist (no min n). Cadence remains first session of the day. |
| L22 | Assignment **Scope** is **Global** (host agent) or **Per-project**. Analytics must match Scope; a per-project scheme still keeps the **global** series. Tuple includes `scope` (`global` \| `project:<id>`). Do not pool incompatible scopes. When deciding outgoing → incoming, **borrow / weight** other scopes’ analytics for those **same** models. **Landed in freeze 2026-08-30** (authorized merge). |

## 1. Scope / non-goals

### In scope

- **Performance analytics (L4-1):** did quality-order hops improve the work, and is each role’s `{ runtime, model, effort }` (and Panel membership) cost-effective?
- **Model assignment evaluation (L4-2):** recommend, or if opted in at `/sb:init` auto-change, the most cost-effective model / thinking-effort / Panel set for each quality-order role.
- **Assignment Scope (L22):** **Global** (host agent) or **Per-project**. Analytics series **must match** that Scope. Per-project schemes still keep a **global** series. Cross-scope borrow/weight for the same outgoing/incoming models when deciding a change — do not pool scopes into one 7-day clock.
- Encoder/ledger as source of truth. Post-facto views only.
- Token mix × pinned official **provider** API rates as hop cost; AA total-cost as proxy only when tokens are unavailable.
- Capability rank: pinned Artificial Analysis Intelligence Index vs **total cost** Pareto, refreshable at `/sb:init` (not at spawn).

### Non-goals

- Operator real-time ops dashboard (who is active, queue depth, idle-kills as ops) (L2).
- Analog-ladder nomenclature or a separate analog-ladder encoder (L1): no Policy F, no `verify_1`/`verify_2`, no CLEAN/NOT CLEAN as ladder terms, no rungs-as-ladder.
- SPEC-template workstreams.
- Editing freeze twins after this authorized merge except to keep twins byte-identical with the pin above (L7 superseded).
- GST-01 as this telemetry (Jobs dashboard only; `gst_stale` does not stop Jobs). Do not stuff this analytics into GST or `origin/main` status heartbeats (L11).
- Dedicated product-observability / SRE / APM workflow (freeze deferred post-MVP).
- Live vendor-doc or AA HTTP **at spawn**.
- Grep-bait verdict strings in instruction templates.
- Transcript scrape as source of rates (audit-only).
- New public `/sb:` route.
- Auto-changing assignments unless the user opted in at `/sb:init`.

## 2. Problem

Quality order (composition-Val → plan-time Val → I → Advisor two-clean → Ver-loop to `v_verified` → Process-scope Advisor/Verifier → Process-final Val) adds hops and cost. FAST is Executor → Verifier → Validator and is not a Job.

The operator cannot today prove, with encoder-written rows, whether those hops and each role’s model are worth their token cost, or which Panel member the unifier actually kept.

## 3. Goals

1. Honest **fail% / ok% with instance lists** (`run_id` + artifact) per hop and per assignment tuple.
2. **Cost on every hop:** token mix × pinned provider API rates (else AA total-cost proxy).
3. Fitness signals so SB can **recommend** (default) or **auto-change** (init opt-in) effort, then Pareto-next model, then Panel membership — **per Scope**, informed by other scopes’ series for the same models (L22).
4. Prove or falsify “this assignment is cost-effective for this role” **in that Scope**.

## 4. Source of truth

One JSONL object = one hop close. Written by **encoder / hook / projector projection**, never the model’s last sentence. Missing row after hop complete → **fail-closed** (do not advance the quality-order machine).

### Row fields (minimum)

- `schema_v`, `ts` (UTC)
- `run_id`, `job_id` (omit for FAST), `launch_id`, `wbs_node_id`
- `hop` (see taxonomy), `role`
- `assignment`: `{ runtime, model, effort, scope }` plus Panel member id when applicable. `scope` is `global` or `project:<id>` (L22).
- `verdict`: `ok | fail | skip | blocked` — **JSONL only**
- `artifact`, `artifact_sha256` when freeze-touching
- `token_mix` (prompt / completion / cached as the host or OmniRoute supplies)
- `cost_currency`, `cost_amount`, `cost_source`: `provider_rate | aa_proxy | unknown`
- `provider` (the billed path actually used)
- `duration_ms`, `blocked_id`
- `writer`: `encoder | hook | projector_projection`

Privacy: no secrets, prompt bodies, full work-spec text, raw email.

Store: `$primary_checkout/.planning/<run>/role-events.jsonl` plus monthly rollup `.planning/role-events/YYYY-MM.jsonl`. Extra worktrees omit `.planning/`.

Transcript scrape is **audit-only**.

## 5. Hop × event taxonomy

| Hop | Role | Close event | Fitness signal |
|---|---|---|---|
| Composition-Val | Validator | `comp_val_round` → `comp_val_verified` or fail | Advisor compose |
| Plan-time Val | Validator | `plan_val_round` (ceiling 8 / `launch_id`) → `plan_val_verified` or fail | Advisor plan |
| I | Executor | `i_end` | Later checker fail% + cost |
| Advisor two-clean | Advisor / Panel member / unifier | `a_round`, `panel_unify` | L19 pair; L20 keep-rate |
| Ver-loop | Verifier | `ver_round` → `v_verified` or fail | Producer default (usually Executor); L18 overturn |
| Process-scope A/V | Advisor / Verifier | process-scope round | Same as A/V |
| Process-final Val | Validator | `val_round` → `val_validated` or fail vs original intent | Producer of rolled-up work |
| FAST short-order | Executor, Verifier, Validator | `fast_*` | **Role-fitness only** (not Job cost-effectiveness of the six-role order) |
| Authorizer | TCB (not a pref key) | `admit` / `deny` / `override` | Admission health; model follows Verifier tuple |

Q-loop checker and unified code-review use the Advisor tuple unless the user set an override; they are not extra pref keys. Log hops against the tuple that actually ran.

## 6. Essential metrics

Rates always include **instance lists**.

1. **Quality-order effectiveness** — later-hop and Process-final fail% vs hop count. Must be able to **falsify** “the extra hops helped.”
2. **Cost-effectiveness** — assigned model(s) performing as expected **versus** measured hop cost (L17). Not hop-ablation vs FAST or Executor-only.
3. **Per-role fitness** — checker fail% **on that role’s output**; duration; blocked terminals; cost. High Verifier/Validator fail% → **producer** upgrade by default; **overturn rate** (producer fix the checker then accepts) before blaming the checker (L18).
4. **Advisor intervention (L19)** — too much = high A-rounds per I with little later-hop improvement. Not helping = low intervention **and** high later Verifier/Validator fail on Executor work.
5. **Panel member (L20)** — **unifier-keep rate** only. Weak keep-rate → drop from Panel.
6. **Assignment action (L5, L6, L21, L22)** — if poor: bump **thinking effort** one step; if already max, next more capable model on the pinned AA Intelligence vs total-cost Pareto. First session of the day. Auto-change only if `/sb:init` opt-in; else recommend. Gate: **≥ 7 days of hop closes on the current assignment tuple**, including `scope` (`global` | `project:<id>`). User-changed assignments start a **new** tuple and a new 7-day clock. Do **not** pool incompatible scopes as one series. When choosing outgoing → incoming for a scope, **borrow / weight** other scopes’ analytics for those same models (see §10).

**Reject:** GST push success; transcript counts; vanity charts without instance lists; live queue/idle-kill ops; KEEP REJECT “collision rates” as runtime quality.

## 7. Cost derivation

Priority:

1. Per-task **token mix** from the host agent or OmniRoute proxy for that hop.
2. × **pinned official API rates** for the **provider actually used** (web-fetched at `/sb:init` / first-session-of-day refresh — same spawn-offline KEEP as AA catalog).
3. If tokens cannot be read: **AA total-cost** for that model as a **general proxy**; stamp `cost_source=aa_proxy`.
4. If neither: `cost_source=unknown` (row still required; assignment eval must not pretend precision).

Do not fetch rates or AA at spawn.

## 8. Capability catalog

- Pin Intelligence Index vs **total cost** Pareto into the in-repo catalog at first `/sb:init`, refreshable (clarify Q1 = A / L15). **Spawn stays offline.** No live vendor-doc fetch at spawn (KEEP not reopened).
- Operator must Select all on [the AA chart](https://artificialanalysis.ai/?total-cost=intelligence-vs-total-cost) when ingesting a full frontier; default page is a subset.
- Local hop outcomes = **fitness**. AA Pareto = **capability / list price rank**. Both required for “most cost-effective.”
- Fast forbidden unless the user says Fast. Unspecified Cursor Executor: Grok 4.6 High, not Extra High / XHigh (L12).
- Advisory ordinal (not hard-block): Orchestrator < Executor < Verifier < Advisor < Validator. Same model across roles allowed (warn, do not identity-hard-stop) (L13).

## 9. Views (post-facto only)

- Per-role / per-tuple **per scope**: ok/fail/skip/blocked counts, fail%, cost, instance list. Global series always; plus `project:<id>` when that project has a per-project scheme.
- Advisor L19 pair; Panel L20 keep-rate.
- Overturn rate (L18).
- Optional `/sb:doctor` freshness: missing-row fail-closed, catalog pin age, rate-pin age.

No live ops tail. No statusline SoT.

## 10. Assignment scope and cross-scope transfer (L22)

> **MERGE NOTE.** §10 is also freeze text as of the authorized 2026-08-30 merge into [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](router_subagent_surfaces_85bf9f09.plan.md) and the home twin ([LS-role-analytics](router_subagent_surfaces_85bf9f09.plan.md#ls-role-analytics)).

Model assignments have **Scope**:

| Scope | Meaning | Analytics series |
|---|---|---|
| `global` | Assignment for a **host agent** (all projects that do not override) | Rows with `scope=global` |
| `project:<id>` | **Per-project** assignment scheme | Rows for **that project only**, **in addition to** the global series |

Rules:

1. Analytics **must correspond to Scope**. A global assignment is judged on the **global** series. A per-project scheme is judged on **that project's** series.
2. A project with a per-project scheme **does not stop** global tracking. Both series stay encoder-written.
3. The L21 7-day gate is **per assignment tuple**. The tuple is `{ runtime, model, effort, scope }` (plus Panel membership when applicable). `scope` is `global` or `project:<id>`.
4. **Do not pool** incompatible scopes as if they were one series or one 7-day clock.
5. When deciding a **change** for a given scope (outgoing model → incoming model), **as much as possible** inform that decision with **all other scopes’** analytics for those **same** models (outgoing and candidate incoming). Borrow / weight that evidence so the call is better than single-scope data alone. Other-scope rows **do not** count toward the target scope’s 7-day gate.
6. Same-model evidence from another scope is **transfer**, not identity: weight it; do not treat it as additional days on this tuple.

## 11. Assignment loop

```text
first session of calendar day
  AND (recommend always when L21 met
       OR auto-change if init opt-in)
  AND ≥ 7 days of hop closes on current tuple
       (tuple includes scope: global | project:<id>)
→ fitness for this scope = this-scope series
       + borrowed/weighted other-scope series
         for the same outgoing model and same incoming candidate
→ if fitness poor: effort += 1
→ if already max effort: next Pareto-capable model
→ if Panel: drop members with weak unifier-keep rate
```

User mid-window assignment edits **invalidate pooling** with the old tuple. Scope changes are a new tuple.

## 12. Implementation waves (combined freeze execute)

Do not run freeze WS0–WS8 from this file alone.

0. Schema + fail-closed write points on quality-order hop close (including token mix, cost, and `assignment.scope`). Projector/encoder, not LLM prose. Live rows begin at combined freeze+analytics execute (L16 / Q2).
1. Post-facto performance views (local files; Doctor freshness optional).
2. Recommend at first session of day when L21 holds.
3. `/sb:init` opt-in auto-change (effort → model → Panel membership).

## 13. KEEP / merge notes

- **MERGE NOTE (L22 Scope, landed 2026-08-30):** Model Assignment Scope is in the main subagent-surfaces freeze. This file remains the cited addendum.
- Six roles, five pref keys; Authorizer is TCB, not a pref key. Authorizer LLM shares Verifier model/effort (different job/tools) (L8).
- Public Job default remains **Ladder**, not `/sb:panel`; a persisting **Role Panel** is always minted per quality-order role with ≥1 assigned model, including N=1 (L14).
- Encoder write-points are the only required behavior change for measurement.
- Role Panel rename in the main freeze twins landed 2026-08-30 (authorized twin edit).
- This analytics store is **not** GST and **not** the deferred SRE/APM WF.
- Assignment Scope is Global or Per-project (L22). Do not pool scopes; do borrow/weight same-model evidence across scopes when deciding a change.

## 14. Open leftovers (`autonomous_default`)

A1–A5, A8–A9 in the clarify brief. No remaining blocking `decision_class` questions.
