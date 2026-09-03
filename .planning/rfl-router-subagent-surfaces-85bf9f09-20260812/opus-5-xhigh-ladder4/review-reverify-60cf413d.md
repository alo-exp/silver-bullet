# RFL Ladder 4 — Opus Extra High — RE-VERIFY on `60cf413d…` — PARENT ACCEPT

**Reviewer:** Opus Extra High (`sb-opus-5-xhigh` / [`fa369f39-73a1-402d-8635-37d12fa2576d`](fa369f39-73a1-402d-8635-37d12fa2576d)). Review-only at review time. No Fast. No Max.
**Branch:** `main`
**Frozen SHA-256 at re-verify start:** `60cf413ddac0cbcb80073e776dd0f6d9d56302002d3a2019a682fbb5060410de`
**Official verdict:** **HASH MISMATCH** (plan moved mid-review to ~`5463fc19…` — GPT Max identity-binding Highs only).
**Parent ACCEPT (round-28 final):** H-1 / H-2 / M-1 incorporated on top of GPT Max H-1 / H-2 / H-3. Max **not** re-launched. No commit.

**Hash gate at review start:** both copies were `60cf413d…`. Mid-review the ACCEPT worker landed GPT Highs → `5463fc192eed0cc601d1406536f628ad7e8f8c0b3e182f7a57c5d249b21c6e27`. That mid-write is **not** the finished freeze.

**Round-27 landed check: PASS.** FAST AM skip / row 40 Advisor re-compose + composition-Val + plan-time Val re-bind. KEEP REJECT intact (public `/sb` only; catalog **id** `WF-SILVER-ROUTER` may remain; schema unchanged; no second AF; catalog generated, back-port then regen; exactly one `ART-AGENT-DELEGATE`).

The reviewer **sandboxed `build_catalog()`** — measurements treated as fact.

## VERDICT: HASH MISMATCH (findings still accepted)

### High H-1 — One artifact record; name the real emitters (accepted)

Do **not** only change `ATOMIC_SPECS` slug `AGENT_DELEGATE` → `AGENT-DELEGATE`: that plus `merge_delegate_catalog()` append yields **two records with the same id** and conflicting `path_pattern` (`.planning/apo/agent-delegate.*` vs `.planning/agent-<host>/<task-id>/*`). 16 invariant checks still PASS; no uniqueness test.

WS1 must name:

- `build_catalog()` artifacts comprehension (`f"ART-{slug}"`)
- `build_atomic_flows()` `artifact_refs`
- `merge_delegate_catalog()` append (~line 190)

**Exactly one** `ART-AGENT-DELEGATE` survives (hyphen; host-path pattern is the intended truth unless documented otherwise). Add `check-apo-invariants.py` **artifact-id uniqueness**. Inline AF `v_loop.artifact_refs` stays `["ART-AGENT-DELEGATE"]`.

### High H-2 — `WF-SILVER-ROUTER` slug + owning_skill (accepted)

Plan already retargets **triggers** to `/sb` and allows the catalog **id** to stay. Also retarget **`slug`** and **`owning_skill`** off `"silver"` to the renamed `skills/sb` skill (`sb`). A post-rename dangling `owning_skill: "silver"` is **in scope**. `check-apo-invariants.py` currently does not inspect `owning_skill` — add or name a check for this record (or all workflows this ship retargets). Sibling `WF-SILVER-NEW-WORKFLOW` already has to-be slug/owning_skill — same discipline.

### Medium M-1 — `PP-SB-STARTUP-FAST.workflow_refs` order (accepted)

`override_rules[0]` prefers `WF-SILVER-FEATURE`, but `workflow_refs` still lists `WF-SILVER-FAST` first. Reorder (FEATURE first, or FAST not first for durable/greenfield ranking) in `PROCESS_PACK_DEFS`. Fail-closed reclassify stays.

Parent ACCEPT 2026-08-16 (round-28 final): Opus H-1 / H-2 / M-1 incorporated with GPT Max H-1 / H-2 / H-3. Mid-write `5463fc19…` invalidated. Final SHA `aa3677a5531797f59465a1370b1909fb5c696a42067546b3b4f99f3ac4c5b30c`. Max not re-launched.
