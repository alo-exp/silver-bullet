# /silver:handoff — spec_template_world_class RFL rung 07 (fresh session on main)

Reusable handoff prompt for a **fresh session on `main`**. Task-detail mode included (user requested). **No implementation in the handoff itself** — transfer only. Nested: Verify + Triage = **Composer 2.5**; APPLY = **Grok 4.6 High** (`cursor-grok-4.6-high` / `sb-grok-4-6-high`); Review = **Pi `claude/claude-opus-5-high`**. Never Fast. Never Grok 4.6 Extra High/XHigh as default. Do **not** switch branches.

---

## Project Identity

- **Repo:** silver-bullet (`alo-exp/silver-bullet`)
- **Origin:** https://github.com/alo-exp/silver-bullet.git
- **Canonical root:** [`/Users/shafqat/projects/silver-bullet/repo`](/Users/shafqat/projects/silver-bullet/repo)
- **Branch:** `main` (stay here). HEAD [`11362001d`](https://github.com/alo-exp/silver-bullet/commit/11362001d) (`memory: auto-snapshot 2026-08-30T16:55:09Z`). Tracking: `main...origin/main` **ahead 2, behind 1**. Do **not** `git pull` / rebase / merge / checkout to “catch up” unless the user asks — freeze twins and rung-07 artifacts are **untracked**.
- **Plugin / tag:** `v0.52.0` (`package.json` 0.52.0). Not a plugin-release slice. Planning `STATE.md` still reads **v0.39.3 Zuvo Runtime Parity** complete — that is **not** the active work.
- **Working tree junk (do not commit):** `.alumnium/logs/`, `.agentmemory/snapshots`, `${SB_RUNTIME_HOME_ROOT}/...`, MCP logs, secrets. Unrelated dirty: `.planning/router_subagent_surfaces_85bf9f09.plan.md`, `.silver-bullet.json`, `.silver-bullet/cursor-models-catalog.json`.

## Current Goal and Milestone

- **Active work:** finish Policy F on RFL **rung 07** (Pi Claude Opus 5 High) for the frozen SPEC-template plan. Need **2 consecutive CLEAN** reviews on an **unchanged** freeze SHA. Streak is **0** (pass 10 was NOT CLEAN → ACCEPT-apply).
- **Posture:** pass 10 APPLY landed and verify_1-apply **PASS 9/9**. Pass 11 legal brief exists. First Pi invoke **EXIT 124**. Fresh retry **11b is in flight** (do not double-launch).
- **User lock:** **commit only after rung 7 Policy F complete (streak 2)**. Do **not** commit after pass 11 alone. Do **not** start rung 8 Extra High until streak 2.

## Read First

1. [`.planning/spec_template_world_class.plan.md`](../spec_template_world_class.plan.md) — canonical freeze (keep byte-identical with [`phases/01-world-class-spec/PLAN.md`](../spec-template-world-class/phases/01-world-class-spec/PLAN.md))
2. [`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/brief-review-rerun-11.md`](../rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/brief-review-rerun-11.md) — **only legal** pass-11 brief (`--write-review-brief`)
3. [`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-apply-rerun-10.md`](../rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/verify_1-apply-rerun-10.md) — pass 10 APPLY verify PASS 9/9
4. [`skills/silver-review-fix-ladder/SKILL.md`](../../skills/silver-review-fix-ladder/SKILL.md) — Policy A/B/C/F/G + APPLY ACCEPT completeness
5. [`.planning/rfl-spec-template-world-class/RETRO-2-CONSECUTIVE-CLEAN.md`](../rfl-spec-template-world-class/RETRO-2-CONSECUTIVE-CLEAN.md) — Policy F encoder contract
6. [`README.md`](../../README.md) / [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) / [`docs/TESTING.md`](../../docs/TESTING.md)

**Stale on disk (do not treat as live):** [`CHARTER.md`](../rfl-spec-template-world-class/CHARTER.md), [`LADDER.md`](../rfl-spec-template-world-class/LADDER.md), [`LADDER-STATUS.json`](../rfl-spec-template-world-class/LADDER-STATUS.json) still say rung 05 / freeze `e0560762…` / rung 07 `pending`. Live truth is the rung-07 artifacts + twin `shasum`.

## Constraints and Invariants

- Stay on **`main`**. No silent checkout. No Fast. Nested models as locked above. Subagents previously hit **usage limits** — prefer **foreground shell** for Pi invoke / encoder if Task workers stall.
- Graphify first (`graphify query` CLI, not MCP `query_graph`); save via agentmemory; retrieve via Graphify. After code edits: `graphify update .`.
- **Do not edit the frozen plan** except via Grok APPLY of a triaged ACCEPT pack. Confirm `shasum -a 256` + `cmp` on both twins before citing.
- **Policy B:** rungs are review/verify only. Launcher/parent applies ACCEPT. Pi never `--continue` on EXIT **1** or **124** — fresh invoke only.
- **Policy F (HARD):** 2 consecutive CLEAN (zero ACCEPT) on **unchanged SHA**. REJECT does not break streak. ACCEPT-apply **resets streak to 0**. Do not advance to rung 8 until streak 2.
- **Policy G:** `--write-review-brief` is the **only legal brief**. Hand-written one-ID residual briefs are non-compliant. Residual-only = do not re-file ledger rows; file **all** valid residuals (HIGH / MED / LOW / nit). APPLY **all ACCEPTs including nits** as one pack.
- **KEEP REJECT / R7b-F17 REJECT — do not reopen.** Two files (SPEC + REQUIREMENTS); Clarify does not write SPEC.md; ingest stays; no third canonical kind doc; 9-turn interview wording left intact.

## Verification and Release State

- **Plan freeze (post pass-10 APPLY):** SHA-256 `fcf094919aeb37c13cc7125f52276052ea9b2777e44d842d02ec4242aaef06e2` — both twins byte-identical (`shasum` + `cmp` reconfirmed 2026-09-01). 204983 bytes each. Previous pin `56cdd698…` is history.
- Pass 10 review: **NOT CLEAN** (0H / 4M / 3L / 2 nit) → triaged ACCEPT pack **R7j-F01–F09**.
- Pass 10 APPLY: [`APPLY-rerun-10.md`](../rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/APPLY-rerun-10.md). verify_1-apply-rerun-10 **PASS**, **9/9 LANDED**, F17 not encoded, verify_2 skipped (APPLY-after-NOT-CLEAN).
- **Policy F streak: 0** (need 2 consecutive CLEAN). `LADDER-STATUS.json` `consecutive_clean_reviews: 0` matches live streak; its `current_rung` / freeze SHA do **not**.
- Pass 11: brief at [`brief-review-rerun-11.md`](../rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/brief-review-rerun-11.md). Attempt 11 EXIT **124** (7200s hard-timeout; fail-fast skipped `--continue`). Attempt **11b in flight** via **foreground shell Pi** (`invoke.sh` pid **6234** / delegate pid **6240**): [`review-attempt11b-stdout.txt`](../rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/logs/review-attempt11b-stdout.txt) still **0 bytes**, **no** `review-rerun-11.md`, **no** `review-attempt11b-exit.txt`. Cursor Task [`8e69d302-89fc-4b79-9537-e228d30c4252`](8e69d302-89fc-4b79-9537-e228d30c4252) was **intentionally aborted** (do **not** resume/re-dispatch it); the **shell Pi invoke** is the authoritative worker — check pids / exit file / `review-rerun-11.md`, not the Task UUID.
- Twins + rung-07 dir + ISSUE-LEDGER + LADDER-STATUS are **`??` untracked**. Latest tag **v0.52.0**. No plugin release for this slice.

## Open Follow-ups

1. **Do not double-launch pass 11.** Check pids / `review-rerun-11.md` / `review-attempt11b-exit.txt` first. If 11b still running, wait or inspect; if EXIT 1/124, **fresh** Pi invoke from [`logs/launch-review-attempt11b.sh`](../rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/logs/launch-review-attempt11b.sh) — never `--continue`.
2. When `review-rerun-11.md` lands (≥2500 bytes, real findings or CLEAN): Composer 2.5 **verify_1** (and **verify_2 only if CLEAN**); Composer 2.5 **triage**; if ACCEPT pack → Grok 4.6 High **APPLY all ACCEPTs including nits** → Composer verify_1-apply → streak **0** → new `--write-review-brief` for pass 12.
3. If pass 11 is **CLEAN**: record `--record-rung-review-outcome clean`; streak **1**; same freeze SHA; launch pass 12 (still Claude High, still Pi). Need a **second** consecutive CLEAN for Policy F.
4. **Commit** the freeze twins + rung-07 evidence **only after streak 2**. Then (and only then) consider rung 8 Pi `claude-opus-5-xhigh`.
5. Refresh stale CHARTER / LADDER.md / LADDER-STATUS when convenient — not a blocker for pass 11.

## First 3 Actions for Next Session

1. In `/Users/shafqat/projects/silver-bullet/repo`, stay on **`main`**. Do not switch branches. Reconfirm freeze `fcf09491…` with `shasum -a 256` + `cmp` on both twins.
2. `graphify query "spec_template_world_class rung-07 Policy F pass 11 Claude High"` then inspect pass-11b: pids 6234/6240, `review-rerun-11.md`, `logs/review-attempt11b-exit.txt`. Do not start a second Pi invoke while 11b is live.
3. Continue the Policy F loop on **rung 07 only** with the model locks below. Commit only at streak 2. Do not start rung 8.

---

## Task Details (explicit)

### Plan freeze (post R7j APPLY) — reconfirmed 2026-09-01

| Copy | SHA-256 |
|---|---|
| [`.planning/spec_template_world_class.plan.md`](../spec_template_world_class.plan.md) | `fcf094919aeb37c13cc7125f52276052ea9b2777e44d842d02ec4242aaef06e2` |
| [`.planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md`](../spec-template-world-class/phases/01-world-class-spec/PLAN.md) | `fcf094919aeb37c13cc7125f52276052ea9b2777e44d842d02ec4242aaef06e2` |

`cmp` identical. 204983 bytes each. Git: both **`??` untracked**. Historical SHAs (`56cdd698…` pass 9, `e0560762…` still printed in CHARTER/LADDER-STATUS) are **not** the current freeze.

### KEEP REJECT (do not reopen)

| Lock | Notes |
|---|---|
| Two canonical files | SPEC + REQUIREMENTS only |
| Clarify does not write SPEC.md | |
| Ingest stays | |
| No third canonical kind doc | |
| **R7b-F17 REJECT** | Nine always-on turns vs “9-turn interview” is numeric-only; already disambiguated — **not encoded**; interview wording left intact |
| Migration record | Non-canonical / not QC-parsed / not a SCAN re-anchor target |

### Landed this conversation (through 2026-09-01)

- Pass 10 Pi Claude High: **NOT CLEAN**, new IDs `R7j-F01`–`R7j-F09` (4 MED / 3 LOW / 2 nit). Ledger IDs not re-filed.
- R7j pack APPLY (Grok 4.6 High) on twins; freeze advanced `56cdd698…` → `fcf09491…`.
- verify_1-apply-rerun-10 **PASS 9/9**. F17 not encoded. Prior R7i/R7h/R7g/… encodings retained.
- Pass 11 brief written via `--write-review-brief`. First invoke EXIT 124. Fresh 11b Pi invoke **running** (stdout still empty at handoff time).
- **User lock:** commit after streak 2, not after pass 11. No rung 8 until streak 2.

### Model locks (this continuation)

| Role | Model | Host |
|---|---|---|
| Review (rung 07) | `claude/claude-opus-5-high` | Pi OmniRoute (`scripts/agent-pi/invoke.sh`). Not Cursor Task. Not Fast. |
| Verify + Triage | **Composer 2.5** | Native Cursor (session lock; overrides CHARTER’s Grok 4.5 High verify line for this ladder) |
| APPLY / fix | **Grok 4.6 High** | Native Cursor Task `cursor-grok-4.6-high` / `sb-grok-4-6-high` |
| Rung 08 (later) | `claude-opus-5-xhigh` | Pi — **do not start** until Policy F streak 2 |

Pi env used for 11b: `PI_PROVIDER=omniroute`, `PI_MODEL=claude/claude-opus-5-high`, `PI_CONTINUE_MAX=0`, timeouts 7200, `PI_EXPECT_FILE_MIN_BYTES=2500`. Launch script: [`logs/launch-review-attempt11b.sh`](../rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/logs/launch-review-attempt11b.sh).

### Run dir

[`.planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/`](../rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/) — 7 of 8 rungs in CHARTER. Entire directory **untracked**.

### What NOT to do

- Do **not** switch branches. Work from `main` only.
- Do **not** start **rung 8 Extra High**.
- Do **not** reopen KEEP REJECT or **R7b-F17**.
- Do **not** write one-ID residual briefs; only `--write-review-brief`.
- Do **not** `Pi --continue` after EXIT 1/124.
- Do **not** commit until Policy F streak **2**.
- Do **not** double-launch pass 11 while 11b is alive.
- Do **not** skip nits on APPLY. Do **not** remap Claude review onto Grok.

---

## Copy-paste prompt for next session

```text
Continue Silver Bullet SPEC-template RFL from main. Do NOT switch branches.

Repo: /Users/shafqat/projects/silver-bullet/repo
Branch: main (HEAD 11362001d; origin ahead 2 behind 1 — do not pull/rebase unless I ask)
Run dir: .planning/rfl-spec-template-world-class/rung-07-pi-claude-opus-5-high/
Rung: 07 Pi claude/claude-opus-5-high (Policy F streak 0; need 2 consecutive CLEAN)

Freeze SHA pin (twins must stay byte-identical):
fcf094919aeb37c13cc7125f52276052ea9b2777e44d842d02ec4242aaef06e2
  .planning/spec_template_world_class.plan.md
  .planning/spec-template-world-class/phases/01-world-class-spec/PLAN.md
Reconfirm with shasum -a 256 + cmp before citing. Twins are untracked (??). CHARTER/LADDER-STATUS freeze e0560762… is stale.

State:
- Pass 10 APPLY landed; verify_1-apply-rerun-10 PASS 9/9 (R7j-F01–F09).
- Pass 11 legal brief: brief-review-rerun-11.md (--write-review-brief only).
- First Pi invoke EXIT 124 (7200s timeout; no --continue).
- Fresh Pi 11b may still be running (invoke.sh ~pid 6234, delegate ~pid 6240, logs/review-attempt11b-stdout.txt). Cursor Task 8e69d302-89fc-4b79-9537-e228d30c4252 was intentionally aborted — do not resume it; check the shell Pi process only.
- Handoff: .planning/handoffs/2026-09-01-spec-template-world-class-rfl-rung07-handoff.md

Model locks:
- Review: Pi OmniRoute claude/claude-opus-5-high (never Cursor Task, never Fast, never --continue on EXIT 1/124)
- Verify + Triage: Composer 2.5
- APPLY: Grok 4.6 High (cursor-grok-4.6-high / sb-grok-4-6-high)
- Subagents hit usage limits earlier — use foreground shell for Pi/encoder if needed

Commit criteria: commit AFTER rung 7 Policy F complete (streak 2 on unchanged SHA). NOT after pass 11 alone. Freeze twins + rung-07 artifacts stay untracked until then.

Exact next actions:
1. Stay on main. graphify query first. Confirm freeze SHA. Check whether 11b is still running (ps + review-rerun-11.md + review-attempt11b-exit.txt). Do not double-launch.
2. If 11b died EXIT 1/124: fresh Pi invoke via logs/launch-review-attempt11b.sh (never --continue). If still running: wait/inspect until review-rerun-11.md exists (>=2500 bytes).
3. Composer 2.5 verify_1 (verify_2 only if CLEAN). Composer 2.5 triage. If ACCEPT: Grok 4.6 High APPLY the full pack including nits; then verify_1-apply; streak resets to 0; --write-review-brief for the next pass.
4. If CLEAN: record clean; streak += 1; same SHA; another Claude High pass. Stop at streak 2, then commit.
5. agentmemory save; graphify update . after edits.

Do NOT:
- start rung 8 Extra High (claude-opus-5-xhigh)
- reopen KEEP REJECT or R7b-F17 REJECT
- write one-ID residual briefs
- commit before streak 2
- switch branches
- skip nits on APPLY
```
