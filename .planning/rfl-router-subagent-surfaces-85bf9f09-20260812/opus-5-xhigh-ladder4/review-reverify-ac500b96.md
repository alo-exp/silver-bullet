# RFL Ladder 4 — Opus Extra High — RE-VERIFY on `ac500b96…` — PARENT ACCEPT

**Reviewer:** Opus Extra High (`sb-opus-5-xhigh` / [`942927ab-f98e-4101-aafa-17c7be8b417b`](942927ab-f98e-4101-aafa-17c7be8b417b)). Review-only at review time. No Fast. No Max.
**Branch:** `main`
**Frozen SHA-256 at re-verify:** `ac500b960f2ade792b4cc97f542986e39582bae9a295e8be8a9cca6f2955974b`
**Parent ACCEPT (round-27):** B-1 / B-2 / H-1 / M-1 incorporated (with GPT Max leftover H-1 / H-2). Max **not** re-launched. No commit.

**Hash gate: PASS.** Both plan copies hashed to `ac500b960f2ade792b4cc97f542986e39582bae9a295e8be8a9cca6f2955974b` at review time. Branch `main`, untouched during review.

**Round-26 landed check: PASS.** Reconcile-before-regen, OpenCode/Pi attach, inline AF V-loop, FAST AM skip, row 40 PUB-01 closure, in-plan Executor invent. KEEP REJECT is intact.

The reviewer **sandboxed the generator** — measurements treated as fact.

## VERDICT: NOT CLEAN

### Blocker B-1 — Name `DELEGATE_STEP_DEFS`; adding to ORDER is not enough (accepted)

`build_delegate_flow_steps()` indexes `DELEGATE_STEP_DEFS[step_id]`. Adding `FS-SILVER_AGENT_OPENCODE` / `FS-SILVER_AGENT_PI` to `DELEGATE_FLOW_STEP_ORDER` without dict entries is `KeyError`. WS1 must name `DELEGATE_STEP_DEFS` and `build_delegate_flow_steps` / `merge_delegate_catalog` overwrites at ~186/212 — **not** generic `build_flow_steps` in `generate-apo-catalog.py`. Specify intended `skill` / `purpose` / `classification` mirroring `FS-SILVER_AGENT_{CODEX,CURSOR,CLAUDE}`. Add those `DELEGATE_STEP_DEFS` entries **and** ORDER in the same step.

### Blocker B-2 — Rename and FS-* ids must move together (accepted)

`build_flow_steps` derives `FS-` + `name.upper().replace("-","_")` from skill **directory** names. WS2 `silver-agent-*` → `sb-agent-*` therefore forks twins unless hardcoded delegate tables retarget in the **same** commit. `DELEGATE_FLOW_STEP_ORDER`, `DELEGATE_STEP_DEFS`, `AF-AGENT-DELEGATE.owning_skills`, and the `"silver-agent-worker"` filter (~`generate-apo-catalog.py`:550) retarget to post-rename `sb-agent-*` / `FS-SB_AGENT_*` **with** the directory rename. After rename: **one** id set only (no `FS-SILVER_AGENT_*` + `FS-SB_AGENT_*` twins). No `FS-SB_AGENT_WORKER` leak. Reciprocity / no-dangling-owning_skill use the **new** ids. `WF-SILVER-*` may remain does **not** apply to derived `FS-*` ids. Generic `build_flow_steps` derivation vs hardcoded `DELEGATE_*` tables must not both emit.

### High H-1 — Name `PRECOMPOSED` (accepted)

`classify_skill` / `PRECOMPOSED` currently contains `silver-new-workflow`. After rename, `FS-SB_NEW_WORKFLOW.classification` becomes `flow-step-skill` instead of `precomposed-workflow`. WS2/WS1: add `sb-new-workflow` to `PRECOMPOSED` (drop or keep historical silver key). Add a check or named assertion so this classification cannot silently downgrade (parity of committed vs generator is insufficient if both are wrong).

### Medium M-1 — Kill leftover “catalog JSON edit” for FAST (accepted)

Remaining “only intended FAST **catalog JSON edit** is `PP-SB-STARTUP-FAST.override_rules[0]`” sentences still implied a hand-edit of `docs/apo-catalog.json`. Change lives in generator `PROCESS_PACK_DEFS`, then regen. Index/target value stay (prefer `WF-SILVER-FEATURE` for 3-day greenfield).

Parent ACCEPT 2026-08-16 (round-27): B-1 / B-2 / H-1 / M-1 incorporated. Max not re-launched.
