# /silver:handoff — router_subagent_surfaces (fresh session on main)

Reusable handoff prompt for a **fresh session on `main`**. Task-detail mode included (user requested). **No implementation in the handoff itself** — transfer only. Nested subagents: **`sb-grok-4-6-xhigh`** (`cursor-grok-4.6-xhigh`) only. Never Fast. Do **not** switch branches.

---

## Project Identity

- **Repo:** silver-bullet (`alo-exp/silver-bullet`)
- **Origin:** https://github.com/alo-exp/silver-bullet.git
- **Canonical root:** [`/Users/shafqat/projects/silver-bullet/repo`](/Users/shafqat/projects/silver-bullet/repo)
- **Branch:** `main` (stay here). Pushed slice: [`e4d0761c`](https://github.com/alo-exp/silver-bullet/commit/e4d0761c) (Round-41 freeze + APPLY ACCEPT completeness) then [`2bc8157e`](https://github.com/alo-exp/silver-bullet/commit/2bc8157e) (host-agnostic worker wording). CI on `2bc8157e` failed because `test-reload-receipts.sh` assertions passed (30/0) then EXIT-trap `rm` raced a leftover `~/.local/share/lean-ctx` dir. Start the next session from the post-fix SHA on `main` after that cleanup commit is green.
- **Plugin / tag:** `v0.52.0` (`package.json` 0.52.0). Not a plugin-release slice.
- **Working tree junk (do not commit):** `.alumnium/logs/`, `${SB_RUNTIME_HOME_ROOT}/...`, MCP logs, secrets.

## Current Goal and Milestone

- **Active work:** implement the frozen [`router_subagent_surfaces_85bf9f09`](../router_subagent_surfaces_85bf9f09.plan.md) architecture (public `/sb`, six-role control plane, WBS projector, nested quality loops). Planning `STATE.md` / `ROADMAP.md` still read **v0.39.3 Zuvo Runtime Parity** complete — that is **not** the active milestone.
- **Posture:** spec freeze **Round-41 ACCEPT CLEAN**. YAML implementation todos remain `pending` — that is the **ship**, not a leftover.
- **RFL product instruction just landed:** launcher APPLY ACCEPT must fix **every non-wrong finding**, including Low / deferred / nitpicks / minor.

## Read First

1. [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) — canonical freeze (keep byte-identical with `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md`)
2. [`.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/RFL-LADDER-4-START.md`](../rfl-router-subagent-surfaces-85bf9f09-20260812/RFL-LADDER-4-START.md) — current-freeze sentence
3. [`.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/MODEL-RANKING-4-LADDERS.md`](../rfl-router-subagent-surfaces-85bf9f09-20260812/MODEL-RANKING-4-LADDERS.md) — ranking (Accepted desc)
4. [`skills/silver-review-fix-ladder/SKILL.md`](../../skills/silver-review-fix-ladder/SKILL.md) — Policy A/B/C + **APPLY ACCEPT completeness**
5. [`README.md`](../../README.md) / [`docs/ARCHITECTURE.md`](../../docs/ARCHITECTURE.md) / [`docs/TESTING.md`](../../docs/TESTING.md)

## Constraints and Invariants

- Stay on **`main`**. No silent checkout. No Fast. Nested: `sb-grok-4-6-xhigh` only.
- Graphify first; save via agentmemory; retrieve via Graphify. After code edits: `graphify update .`. Edit `skills/` then `bash scripts/sync-codex-package.sh` (and `sync-templates.sh` if `templates/` changes).
- **Do not edit the frozen plan** unless a new ACCEPT freeze is required. Confirm `shasum -a 256` + `cmp` on both copies before citing.
- **Policy B:** rungs are review/verify only. The **launcher** applies ACCEPT. Do not tell rungs `OR fix divide()`.
- **APPLY ACCEPT completeness (HARD):** land **every finding that is not wrong**, including **Low, deferred, nitpicks, and minor** if still applicable. Skip only KEEP REJECT / user-locked rejects, factually wrong, superseded/stale, or no longer true on the current freeze. Do **not** skip a still-valid nit because the rung was “CLEAN for ladder purposes” or the item is a “non-blocking nit”. Anti-churn for historical changelog / KEEP REJECT aliases still applies — **do not reopen KEEP REJECT**.
- Coverage MUST: 100% of **plan-executed deltas** (map each YAML todo / WS / live-spec MUST → named test/assertion). Not repo-wide line coverage. Ship blocked until that map is green.

## Verification and Release State

- **Plan freeze (Round-41):** SHA-256 `a96045f96743fb33da4e30e1e9eb80a47eb4969641ad78b625a827c48b55df6f` — both copies byte-identical (`shasum` + `cmp` reconfirmed 2026-08-18).
- Extra High + Max re-verify Round-41 **CLEAN** (0H/0M/0L): [`reverify-round-41.md`](../rfl-router-subagent-surfaces-85bf9f09-20260812/rung-04-cursor-grok-4.6-xhigh/reverify-round-41.md), [`reverify-round-41-max.md`](../rfl-router-subagent-surfaces-85bf9f09-20260812/rung-04-cursor-grok-4.6-xhigh/reverify-round-41-max.md).
- Coverage MUST **PASS** at plan L30 / L98 / L711.
- Policy B live harness: [`tests/live/lib/review-fix-ladder-common.sh`](../../tests/live/lib/review-fix-ladder-common.sh) (`review_fix_ladder_launcher_apply_accept`), [`tests/live/lib/review-fix-ladder-triage-scenario.sh`](../../tests/live/lib/review-fix-ladder-triage-scenario.sh). Launcher APPLY ACCEPT; rungs review-only.
- Targeted RFL tests green after the completeness instruction: `bash tests/scripts/test-review-fix-ladder.sh` (80/0), `bash tests/hooks/test-review-fix-ladder-guard.sh` (28/0).
- **CI:** Secret Scan green on `2bc8157e`. CI validate failed on five-tool offline `test-reload-receipts.sh` cleanup (not assertions). Cleanup is now fail-closed for leftover lean-ctx cache; re-run CI on the follow-up commit.
- Latest tag **v0.52.0**. No plugin release for this slice. Site-only exemption does not apply.

## Open Follow-ups

YAML todos in the plan frontmatter — **all 10 `status: pending`** (the ship):

1. `capability-contract`
2. `execution-registry`
3. `model-preferences`
4. `nested-orchestration`
5. `nested-quality-loops`
6. `authorizer-trust`
7. `host-surfaces`
8. `universal-migration`
9. `validation-tests` (includes the coverage MUST)
10. `docs-release`

Do not treat `pending` as a spec leftover.

## First 3 Actions for Next Session

1. In `/Users/shafqat/projects/silver-bullet/repo`, stay on **`main`**, `git pull` / confirm HEAD is the post-push SHA. Reconfirm plan freeze `a96045f9…` with `shasum` + `cmp`. Do not switch branches.
2. `graphify query "router_subagent_surfaces capability-contract wbs-projector /sb APPLY ACCEPT"` then start **implementation** of the pending YAML todos (not another review freeze unless findings force it).
3. Keep the coverage map as you go: each YAML todo / WS / live-spec MUST → named test/assertion. Run targeted tests; full `bash tests/run-all-tests.sh` before relying on `origin/main` CI.

---

## Task Details (explicit)

### Plan freeze (Round-41) — reconfirmed

| Copy | SHA-256 |
|---|---|
| [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](../router_subagent_surfaces_85bf9f09.plan.md) | `a96045f96743fb33da4e30e1e9eb80a47eb4969641ad78b625a827c48b55df6f` |
| `~/.cursor/plans/router_subagent_surfaces_85bf9f09.plan.md` | `a96045f96743fb33da4e30e1e9eb80a47eb4969641ad78b625a827c48b55df6f` |

`cmp` identical. 557324 bytes each. Hashed in [`RFL-LADDER-4-START.md`](../rfl-router-subagent-surfaces-85bf9f09-20260812/RFL-LADDER-4-START.md) at 2026-08-17T09:22:00Z. Historical SHAs (`81af8287…` Round-40, `2fb45355…` Round-39, …) are not the current freeze.

### KEEP REJECT (do not reopen)

| Lock | Notes |
|---|---|
| Exclusive `hooks/lib/wbs-projector.sh` | Admission requests; not a second packet writer |
| Unlimited **tree** nesting | Recursive cycles fail-closed |
| DFS **tri-color / recursion-stack** | Visited-set alone insufficient |
| Two-limb in-plan Executor mint | (a) Work Plan–cited **or** (b) pre-existing catalog WF supporting that cited node |
| Mid-I new PUB-01 / new catalog WF | **row 40, not row 37** |
| Remint mints a **new `launch_id`** | Not put-if-absent on the old pair only |
| Public `/sb` | No dual `/silver` window |
| Catalog generated | APO SOT; do not JSON-edit catalog; FAST overlay is generator |
| `nested_executor` **lock-only** | Not a catalog JSON field; B1 schema unchanged |
| B1 schema unchanged | `additionalProperties: false` |
| Authorizer **not** Approver | Authorizer admits |
| ESC-02 **no A** | I then V |
| `prompt_hash` **inner-only** | |
| Launcher **may omit** `context_refs_hash` | Projector stamps |
| L598 **no abandonment-by-silence** | L598 is work-spec JCS / inner `prompt_hash` — skip alias churn |
| OFF-01 **post-MVP** | Out of this ship’s coverage mandate |
| Limb (b) **observable post-revoke effects only** | |
| pid-exists is **not** FAIL | |
| FAST is **not** a Job | Classify-not-mint; not GST |
| Wrap is **Advisor-composed** | Non-trivial |
| No process-death oracle | |

### Landed this conversation (through 2026-08-18)

- Round-37–41 nits on the live spec (document-control recency, cite retargets, coverage MUST). Round-41 Extra High + Max **CLEAN**.
- 100% test coverage of **plan-executed deltas** is a live-spec MUST (not repo-wide).
- Policy B live harness: launcher APPLY ACCEPT; rungs review-only.
- Ranking table: [`.planning/rfl-router-subagent-surfaces-85bf9f09-20260812/MODEL-RANKING-4-LADDERS.md`](../rfl-router-subagent-surfaces-85bf9f09-20260812/MODEL-RANKING-4-LADDERS.md) — sorted by Accepted; `qwen3.8-max` **omitted** (skipped/not run); Gemini 3.6 was L1-specified (`ledger.json`); L3–L4 specify 3.7; **TOTAL 259 / 74 / 92 / 162 / 62.5** (Issues / B+H / M+L / Accepted / Acceptance %).
- **RFL instruction (this slice):** APPLY ACCEPT completeness in [`skills/silver-review-fix-ladder/SKILL.md`](../../skills/silver-review-fix-ladder/SKILL.md), [`templates/orchestrator-workers/REVIEW-TRIAGE.md`](../../templates/orchestrator-workers/REVIEW-TRIAGE.md), live harness comments/prompts, and `tests/scripts/test-review-fix-ladder.sh`. Sync via `sync-codex-package.sh` + `sync-templates.sh`.

### Ranking (do not re-count unless asked)

23 ranked slugs. Rank 1 `opus-5-xhigh` (85 Accepted). `gemini-3.6-flash-high` stays in table (L1 specified). Do not invent OpenCode Max. Do not add qwen as a 0-issue finder.

### Implementation notes

- Cursor MVP first. Codex/Claude/OpenCode host adapters are post-MVP.
- Projector is the sole WBS/packet writer. Children submit receipts; spawn-proxy helper owns jsonl.
- Live E2E (real Cursor host, real subagent, real WBS, extra-worktree heuristic) is the MVP host proof.
- AGENTS.md generic subagent default is Grok 4.6 Medium; **this continuation overrides** to `sb-grok-4-6-xhigh`. RFL GPT/Claude/OpenCode rungs keep their family slugs. Never Fast.
