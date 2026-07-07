# Enterprise E2E — Silver Bullet Issues

Continuous issue log for enterprise E2E matrix sessions (Rounds 1–4). **Policy:** TUI monitor scripts and operators append new issues here — not the human ledger ([ROUND-4-LEDGER.md](../../.planning/enterprise-e2e/ROUND-4-LEDGER.md) is run metadata only).

**Last updated:** 2026-07-04  
**SB repo HEAD at update:** `52022bf6`

---

## Issue status legend

| Status | Meaning |
|--------|---------|
| **fixed** | Shipped on `main`; verify in next matrix row |
| **open** | Known gap; not yet fixed |
| **friction** | Correct behavior but UX cost; may accept or tune |
| **false-positive-replay** | TUI monitor re-ingested historical row logs before offset reset — not a real new defect |

---

## Session issues (fixed / open / friction)

### Fixed (this session)

| ID | Severity | Component | Issue | Fix |
|----|----------|-----------|-------|-----|
| E2E-001 | friction→fixed | orchestrator | Parent blocked **all** Bash (`ORCHESTRATOR PARENT — Bash is forbidden`) during orient/list steps | Narrow guard: allow read-only / non-SB-state Bash; block only mutations to `.silver-bullet/`, `STATE.md`, `ROADMAP.md`, `.planning/workflows/` |
| E2E-002 | open→fixed | harness | Context-full recovery used `/clear` (destructive) | `recover_from_context_exhaustion` now sends `/compact`; matrix fresh-row `/clear` unchanged |
| E2E-003 | annoyance→fixed | hooks/runtime | Residual `gsd-session-state.sh` SessionStart errors in TUI monitor | Removed GSD references from runtime; TUI monitor matches generic SessionStart missing-script |
| E2E-004 | friction→fixed | stop-check | Stop denials lacked actionable next step | Block reasons now include skill to invoke, worker template, or SessionStart guidance |
| E2E-005 | chore→fixed | runtime | GSD namespace strings in hooks, templates, APO catalog | Purged from runtime surfaces; `legacy_flow_alias_to_entity` replaces `gsd_alias_to_entity` |
| E2E-010 | annoyance→fixed | SessionStart | `node:internal/modules/cjs/loader` errors on some rows | `scripts/prune-stale-claude-user-hooks.sh` + `install-claude.sh`; TUI watch downgrades to annoyance when harness ignores |
| E2E-011 | gap→fixed | recommended_tools | Enterprise Session 0 must opt-in all five tools with preflight enforcement | `enterprise_e2e_assert_all_recommended_tools_opted_in` + alumnium preflight in `enterprise_e2e_code_intel_preflight` |
| E2E-013 | gap→fixed | host modes | Plan/Debug mode interaction with SB hooks undocumented at runtime | Documented in `docs/ORCHESTRATOR.md` §Host modes — Plan/Debug; matrix runs Agent mode only |
| E2E-014 | friction→fixed | stop-check | Repeated Stop churn when multiple gates fire sequentially | `hooks/lib/stop-coalesce.sh` — first Stop block wins; downstream hooks suppress (E2E-014) |
| E2E-015 | open→fixed | ledger | Round 4 friction no longer appends to human ledger (`SB_E2E_LEDGER_NO_UX_APPEND=1`) | Policy enforced: `watch-enterprise-e2e-tui.sh` respects env; friction → findings jsonl + **this file** |
| E2E-016 | gap→fixed | wbs-supervision | No cross-cutting WBS meta-supervision over host agent / subagent loop | MVP `b378026e`: `hooks/lib/wbs-supervisor.sh`, Stop + PostToolUse + SessionStart + subagent handoff; [WBS-META-SUPERVISION.md](../architecture/WBS-META-SUPERVISION.md) |
| E2E-026 | blocker→fixed | hook | planning-file-guard blocked write (TUI-watch false positive on matrix prompt echo) | `enterprise_e2e_outcome_watch_is_hook_deliberation_fp` + TUI watch FP filter @ `52022bf6` |
| E2E-081 | blocker→fixed | harness | 0-token stall — no workflow progress (MCP auth / mode banner) | `claude-interactive-invoke.expect` dismisses 0-token mode banner + Enter wake @ `52022bf6` |

### Open

| ID | Severity | Component | Issue | Recommendation |
|----|----------|-----------|-------|----------------|
| *(none)* | — | — | All previously open blockers addressed in this session | Re-verify on next matrix row |

### Post-v0.50.2 harness fixes (E2E-101 – E2E-115)

Registered from `git log 779464af..HEAD` and Codex/Claude REAL ledgers. See [ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md](../testing/ENTERPRISE-E2E-HOST-CERTIFICATION-METHODOLOGY.md) §11a–§11b.

| ID | Severity | Component | Symptom | Fix SHA | Status |
|----|----------|-----------|---------|---------|--------|
| E2E-101 | gap→fixed | harness/codex | Codex matrix checked out wrong test-app branch — row evidence clobber | `b3e036b3`, `4412bb01` | **fixed** — `enterprise_e2e_fixture_assert_branch_lock` |
| E2E-102 | gap→fixed | harness/codex | Stale evidence SKIP without live rerun; batch EXIT trap | `59ec1456` | **fixed** — `SB_E2E_MATRIX_FORCE_ALL` + pid trap |
| E2E-103 | blocker→fixed | harness/codex | Row 3 stub-only — 84B planning file, no api/currency commits | `356e87ec`, `b40f44fc` | **fixed** — force3 row + PLAN/GATES/TRACE invoke clause |
| E2E-104 | gap→fixed | harness/codex | Rows 14/15/16 outcome partials without live product delta | `968a8008`, `7f822474`, `8e748967` | **fixed** — force1416/141619 outcome drivers |
| E2E-105 | gap→fixed | harness/claude | Claude routing state bleed across matrix rows | `80438bda` | **fixed** — isolated Claude state roots per row |
| E2E-106 | gap→fixed | harness/claude | §5b smoke rows 6/11 missing baseline rev / printf clauses | `8219477f`, `da61d5fb` | **fixed** — matrix §5b baseline rev gate |
| E2E-107 | friction→fixed | harness/claude | Bracketed-paste matrix prompts collapsed — slash route not submitted | `d3ea981a` | **fixed** — collapsed paste confirm in expect |
| E2E-108 | gap→fixed | harness/codex | Slow Codex install on every REAL driver launch | `7a625546`, `ab822e00` | **fixed** — session0 skip + `SB_E2E_SKIP_CODEX_INSTALL` |
| E2E-109 | gap→fixed | harness | Row3 pilot mkdir before fixture root exported | `4815d4b4` | **fixed** — export fixture root before pilot |
| E2E-110 | gap→fixed | harness/claude | Custom API key disclaimer blocked matrix launch | `6935a7c0` | **fixed** — inherit keys API-key bypass in matrix env |
| E2E-111 | gap→fixed | harness | Hook audit failed on isolated Claude state roots | `5e5590cc` | **fixed** — allow audit on isolated state |
| E2E-112 | gap→fixed | harness | Pilot `row_passed` used stale log slice | `ba77d1b0` | **fixed** — latest matrix log slice |
| E2E-113 | gap→fixed | harness | Strict-clean ledger pass summary wrong variable | `b20a31f7` | **fixed** — `$LEDGER` in pass summary |
| E2E-114 | gap→fixed | harness/codex | Codex-3 REAL §5a/§5b product audit methodology missing | `d0a271fb`, `d57274f8` | **fixed** — docs + fixture reset |
| E2E-115 | gap→fixed | ci | Enterprise E2E script tests used non-writable fixture paths in CI | `f86cb6a5` | **fixed** — CI-writable paths |

### Friction (accepted / monitor)

| ID | Severity | Component | Issue | Notes |
|----|----------|-----------|-------|-------|
| E2E-086 | friction→fixed | harness/cursor | Cursor matrix row attempt logs stayed 0 bytes — `cursor-agent --print` ignored `CLAUDE_INTERACTIVE_LOG_FILE`; OUT-SKILL-01/OUT-WORLD-01 false fails | `tests/live/agents/cursor/agent.sh` writes log file; matrix tees output + seeds state slug; outcome scorer checks `state.requested` @ cursor branch |
| E2E-087 | friction→fixed | harness/cursor | `silver-deep-research`/`silver-feature` hit `CLAUDE_INTERACTIVE_TIMEOUT` 900s — evidence present but OUT-KM-01/OUT-WORLD-01 fail | 2b197be9: cursor matrix default timeout 1800s |
| E2E-088 | friction→fixed | outcome/cursor | Post-retry @1800s: 12/22 fail on OUT-HANDOFF-01/OUT-SUPER-01 (3–4), OUT-KM-01 session partial (6–7,12,14–16,18,20), OUT-MEASURE-01 (16), internal gates 21–22 | SB harness @8feda5fc; retry2 completed ~4h — evidence PASS 9/12 agent rows; outcome files still FAIL |
| E2E-089 | friction→fixed | harness/cursor | Retry2 row logs 0–317B (timeout/connection noise); matrix evidence PASS but outcome FAIL; row 20 timeout; parallel codex batch regressed rows 9–10–13–17 outcome files | Headless log streaming in `cursor/agent.sh`; matrix evidence resolver + hook/heal/super scorer @3d4ef10e; rescore harness **21–22/22** — **not** strict-clean (evidence-only rows) |
| E2E-090 | gap→fixed | harness | Parallel Codex/Cursor/Claude matrix tracks shared one test-app checkout — row 21–22 evidence clobber risk | `hosts.json` `test_app_git_branch` + `enterprise_e2e_ensure_test_app_branch`; pattern `enterprise-e2e/round-N-{host}`; see [TEST-APP-BRANCH-POLICY.md](../../.planning/enterprise-e2e/TEST-APP-BRANCH-POLICY.md) |
| E2E-091 | gap→fixed | outcome/cursor | Row 1 `OUT-CLARIFY-01` false fail on routing-only `silver-router` session | `enterprise_e2e_outcome_score_clarify` → `n/a` when routing evidence present @ `32231c44` |
| E2E-092 | gap→fixed | harness/cursor | tmux driver inherited 900s timeout vs 1800s cursor matrix default — row 6 timeout + 124 B log | `matrix.sh` enforces cursor ≥1800s; `cursor3-real-driver.sh` exports timeout env @ `32231c44` |
| E2E-093 | gap→fixed | harness/cursor | §5b log floor fail — `cursor-agent --print` summary-only; harness truncated attempt log; stream-json / composite transcript missing | `tests/live/agents/cursor/agent.sh` stream-json + `stdbuf`; `enterprise_e2e_matrix_finalize_attempt_log` composite footer; outcome scoring surface @ `5fa5d2fc` |
| E2E-094 | gap→fixed | outcome/cursor | Row 6 `OUT-ORCH-01` false fail on `silver-fast` fast-path after live retry | `enterprise_e2e_outcome_score_orch` → `n/a` when row 6 evidence + `silver-fast` state present @ `5fa5d2fc` |
| E2E-095 | gap→fixed | harness/cursor | Brownfield evidence SKIP without `SB_E2E_MATRIX_FORCE=1` — row 2 initial 0 B skip | `cursor3-real-driver.sh` + pipeline driver export `FORCE` + `FORCE_ALL` @ `d02b8584` |
| E2E-096 | gap→fixed | outcome/cursor | Row 10 autonomy scorer false-negative — negated "operator pauses" in stream-json summary + matrix prompt "SB OVERRIDE" instruction tripped babysitting regex | Babysitting exclusion + `SB OVERRIDE:` colon-required detector @ `e1ff9580`; rescored live log 427233 B |
| E2E-097 | gap→fixed | outcome/cursor | Row 14 `OUT-RELEASE-01` partial — `silver-release` lacks ship-readiness dir | Row 14 uses CHANGELOG + release phase SHIP evidence path @ `0420501d` |
| E2E-098 | gap→fixed | outcome/cursor | Row 14 `OUT-KM-01` partial — matrix graphify preamble without agentmemory MCP in TUI | Matrix graphify preamble + MCP-disabled env → pass @ `87c4228f` |
| E2E-099 | gap→fixed | outcome/cursor | Row 15 `OUT-RELEASE-01` partial on `review-triad` — lacks ship-readiness/CHANGELOG | `triad-currency.md` triad evidence path @ `e371d311` |
| E2E-100 | gap→fixed | harness/cursor | Rows 21–22 internal gates lack attempt logs (<2048 B §5b floor) | `.cursor3-monitor-loop.sh` exempts internal harness rows 21–22 @ `cca0ffc0` |

 ○low·/effort

 
⎿ SessionStart:startuph | row 11; tui-watch @ 2026-06-29T18:22:44Z |
| E2E-084 | annoyance | stall | n(shift+tabtocycle)·←foragents0tokens

 ○low·/effort

  [>0q
⚠17MCPserversneedau | row 11; tui-watch @ 2026-06-29T18:22:44Z |
| E2E-083 | annoyance | stall | ft+tabtocycle)·←foragents     0 tokens

 ○low·/effort

 
⎿ SessionStart:startuph | row 6; tui-watch @ 2026-06-29T18:11:37Z |
| E2E-082 | annoyance | stall | n(shift+tabtocycle)·←foragents0tokens

 ○low·/effort

  [>0q
⚠17MCPserversneedau | row 6; tui-watch @ 2026-06-29T18:11:37Z |
| E2E-080 | annoyance | stall | ft+tabtocycle)·←foragents     0 tokens

 ○low·/effort

 
⎿ SessionStart:startuph | row 4; tui-watch @ 2026-06-29T18:00:34Z |
| E2E-079 | annoyance | stall | n(shift+tabtocycle)·←foragents0tokens

 ○low·/effort

  [>0q
⚠17MCPserversneedau | row 4; tui-watch @ 2026-06-29T18:00:34Z |
| E2E-078 | annoyance | orchestrator | ───────────────

 ❯  

 ──────────────────────────────────────────────────────── | row 3; tui-watch @ 2026-06-29T18:00:34Z |
| E2E-077 | annoyance | stall | n(shift+tabtocycle)·←foragents0tokens



`FLOW-QUALITY-GATE-PREPLAN→silver-conte | row 3; tui-watch @ 2026-06-29T18:00:34Z |
| E2E-076 | annoyance | hook | nts48503tokens

 
⎿ PreToolUse:Bashhookerror
 ⎿  Failed to run: Plugindirecry do | row 3; tui-watch @ 2026-06-29T18:00:34Z |
| E2E-075 | annoyance | hook | 
 
 
 
 
46653

 
⎿ PreToolUse:Bashhookerror
 ⎿  Failed to run: Plugindirecry do | row 3; tui-watch @ 2026-06-29T18:00:34Z |
| E2E-074 | annoyance | hook |  
⎿ Read34lines
 ⎿  PreToolUse:Read hook error
Failed to run: Plugin directorydo | row 3; tui-watch @ 2026-06-29T18:00:33Z |
| E2E-073 | annoyance | hook | nts45079tokens

 
⎿ PreToolUse:Bashhookerror
 ⎿  Failed to run: Plugindirecry do | row 3; tui-watch @ 2026-06-29T18:00:33Z |
| E2E-072 | annoyance | hook | PreToolUse:Bashhookerror
 ⎿  Failed to run: Plugindirecry does nt exist:
  $HOME/.codex/plugin/cache/alo-labs/ | row 3; tui-watch @ 2026-06-29T17:59:22Z |
| E2E-071 | annoyance | hook | PreToolUse:Bashhookerror
 ⎿  Failed to run: Plugindirecry does nt exist:
  $HOME/.codex/plugin/cache/alo-labs/ | row 3; tui-watch @ 2026-06-29T17:59:22Z |
| E2E-070 | annoyance | hook | PreToolUse:Read hook error | row 3; tui-watch @ 2026-06-29T17:59:21Z |
| E2E-069 | annoyance | hook | PreToolUse:Bashhookerror
 ⎿  Failed to run: Plugindirecry doesnotexist:
  $HOME/.codex/plugins/cache/alo-labs/ | row 3; tui-watch @ 2026-06-29T17:59:21Z |
| E2E-068 | annoyance | orchestrator | sfromyourclipboard

 

 ──────────────────────────────────────────────────────── | row 3; tui-watch @ 2026-06-29T17:59:20Z |
| E2E-067 | annoyance | stall | ermissionson(shift+tabtocycle)0tokens

 

  ❯ /silver Add currency field t order | row 3; tui-watch @ 2026-06-29T17:59:19Z |
| E2E-066 | annoyance | stall | ft+tabtocycle)·←foragents     0 tokens

 ○low·/effort

 
⎿ SessionStart:startuph | row 3; tui-watch @ 2026-06-29T17:59:19Z |
| E2E-065 | annoyance | stall | n(shift+tabtocycle)·←foragents0tokens

 ○low·/effort

  [>0q
⚠17MCPserversneedau | row 3; tui-watch @ 2026-06-29T17:59:19Z |
| E2E-064 | annoyance | orchestrator | orchestrator parent may be implementing inline | row 3; tui-watch @ 2026-06-29T17:58:21Z |
| E2E-063 | annoyance | orchestrator | eportfrom

 .planning/research/2026-06-29-orders-runtime/comparison-report.mdbef | row 2; tui-watch @ 2026-06-29T17:55:27Z |
| E2E-062 | annoyance | hook | ng rquired
  field "hookEventName"
PstToolUse:Bashhook errr
⎿ Faied with no-bloc | row 2; tui-watch @ 2026-06-29T17:55:27Z |
| E2E-061 | annoyance | hook | ssingrequired
field"hookEventName"

✶Wrangling… (2m 12s · ↑ 7.2k toens)
⎿ Tip: U | row 2; tui-watch @ 2026-06-29T17:55:27Z |
| E2E-060 | annoyance | hook | required
    field "hookEventName"
⎿  PostToolUse:Bash hook rro
⎿ Failedwithnon- | row 2; tui-watch @ 2026-06-29T17:55:27Z |
| E2E-059 | annoyance | orchestrator |  
 
 
 
 
·

 
 
 
 
 
 
 
 
50

 
 
 
 
 
 
 
 
✢

 
 
 
 
 
 
 
 
✳

 
 
 
 
  | row 2; tui-watch @ 2026-06-29T17:54:26Z |
| E2E-058 | annoyance | hook | rhascompleted.
  ⎿  PreToolUse:Bash hook error
⎿  Failedwith non-blocking status | row 2; tui-watch @ 2026-06-29T17:54:26Z |
| E2E-057 | annoyance | hook | ingrequired

 field"hookEventName"

 ⎿ PostToolUse:Bashhookerror

 ⎿ Failedwithn | row 2; tui-watch @ 2026-06-29T17:54:26Z |
| E2E-056 | annoyance | hook | g required
   field"hookEventName"

✳Wrangling… (59s · ↑ 2.9ktokens · thought fo | row 2; tui-watch @ 2026-06-29T17:54:26Z |
| E2E-055 | annoyance | orchestrator | 
 
 
 
 
 
✽

 
 
 
 
 
 
 
 
✻

 
 
 
 
 
 
 
 
✶

 
 
 
 
 
 
 
 
✳

 
 
 
 
  | row 2; tui-watch @ 2026-06-29T17:52:57Z |
| E2E-054 | annoyance | stall | null)
✢ Wrangling… (17s · ↓ 400 tokens · thought for 11s)
  ⎿ Tip:Trysettingenvi | row 2; tui-watch @ 2026-06-29T17:52:57Z |
| E2E-053 | annoyance | stall | ermissionson(shift+tabtocycle)0tokens

 

  ❯ /silver Should we use Postgres or  | row 2; tui-watch @ 2026-06-29T17:52:57Z |
| E2E-052 | annoyance | hook | hfileor
  directory
PreToolUse:Bash hok error
⎿ Hook JSON output vlidatin failed | row 2; tui-watch @ 2026-06-29T17:52:57Z |
| E2E-051 | annoyance | hook |  2>&1 / head -20)
⎿ PreToolUse:Bsh hook rrr
⎿ Failed withnon-blockingstatuscode: | row 2; tui-watch @ 2026-06-29T17:52:57Z |
| E2E-050 | annoyance | hook | letmeread
directly.
PreToolUse:Bash hook error
⎿ Faied with no-blockingstatuscod | row 2; tui-watch @ 2026-06-29T17:52:57Z |
| E2E-049 | annoyance | hook | nts46643tokens

 
⎿ PreToolUse:Bashhookerror
 ⎿  Failed with non-blocing statusc | row 2; tui-watch @ 2026-06-29T17:52:57Z |
| E2E-048 | annoyance | hook | 
·

 
 
 
 
 
 
 
⎿ PreToolUse:Bashhookerror
 ⎿  Failed with non-blocing statusc | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-047 | annoyance | hook | g required
   field"hookEventName"

·Wrangling… (31s · ↓ 1.6ktokens · thought fo | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-046 | annoyance | hook | g required
   field"hookEventName"

✢Wrangling… (31s · ↓ 1.6ktokens · thought fo | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-045 | annoyance | hook | issng equired
field"hookEventName"

· Wrangling…(29s·↓1.5ktokens·thinkingwithlow | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-044 | annoyance | hook | ssing equired
feld "hookEventName"
Failed with non-blocking status code: bash:
/ | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-043 | annoyance | hook | required
    field "hookEventName"

·Wrangling…(29s·↓1.4ktokens·thinkingwithlowe | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-042 | annoyance | hook | equired
     field "hookEventName"

✶ Wrangling… (28s · ↓ 1.4k tokens · thinking | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-041 | annoyance | hook | ingrequired
  fild "hookEventName"
PreToolUse:Bash hook error
⎿ Faied with no-bl | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-040 | annoyance | hook | equired
     field "hookEventName"


 ·Wrangling…(25s·↓1.4ktokens)

 ⎿ Tip:Tryse | row 2; tui-watch @ 2026-06-29T17:52:56Z |
| E2E-039 | annoyance | orchestrator | dual-orchestrator / slash-skill deliberation | row 2; tui-watch @ 2026-06-29T17:52:47Z |
| E2E-038 | annoyance | hook | PreToolUse:Bash hok error
⎿ Hook JSON output vlidatin failed — hookSpecificOutputis missing equired
feld "hookEventName" | row 2; tui-watch @ 2026-06-29T17:52:46Z |
| E2E-037 | annoyance | hook | PreToolUse:Bsh hook rrr
⎿ Failed withnon-blockingstatuscode:bash:
  /Users/shafqt/.claud/hoks/gsd-validate-commit.sh:Nos | row 2; tui-watch @ 2026-06-29T17:52:46Z |
| E2E-036 | annoyance | hook | PreToolUse:Bash hook error
⎿ Faied with no-blockingstatuscode:bash:
  /Users/shafqt/.claud/hoks/gsd-validate-commit.sh:N | row 2; tui-watch @ 2026-06-29T17:52:46Z |
| E2E-035 | annoyance | hook | PreToolUse:Bashhookerror
 ⎿  Failed with non-blocing statuscode:bash:
  $HOME/.codex/hooks/gsd-vaidate-commit. | row 2; tui-watch @ 2026-06-29T17:52:46Z |
| E2E-034 | annoyance | hook | PreToolUse:Bashhookerror
 ⎿  Failed with non-blocing statuscode:bash:
  $HOME/.codex/hooks/gsd-vaidate-commit. | row 2; tui-watch @ 2026-06-29T17:52:46Z |
| E2E-032 | annoyance | stall | ft+tabtocycle)·←foragents     0 tokens

 ○low·/effort

 
⎿ SessionStart:startuph | row 2; tui-watch @ 2026-06-29T17:51:46Z |
| E2E-031 | annoyance | stall | 0 tokens | row 2; tui-watch @ 2026-06-29T17:51:44Z |
| E2E-030 | annoyance | stall | n(shift+tabtocycle)·←foragents0tokens

 
`.planning/research/2026-06-29-orders-r | row 2; tui-watch @ 2026-06-29T17:45:23Z |
| E2E-029 | annoyance | hook | ingrequired

 field"hookEventName"

 

 ✽Combobulating…(3m47s·↑15.4ktokens)

 ⎿  | row 2; tui-watch @ 2026-06-29T17:45:23Z |
| E2E-028 | annoyance | hook | ingrequired

 field"hookEventName"

 ⎿ stoppedatauditcompletionperuserinstructio | row 2; tui-watch @ 2026-06-29T17:45:23Z |
| E2E-027 | annoyance | stall | 0tokens | row 2; tui-watch @ 2026-06-29T17:45:18Z |
| E2E-025 | annoyance | orchestrator | dual-orchestrator parent inline deliberation | row 1; tui-watch @ 2026-06-29T17:45:15Z |
| E2E-024 | annoyance | hook | hookEventName missing on PostToolUse hook | row 1; tui-watch @ 2026-06-29T17:45:15Z |
| E2E-023 | annoyance | hook | SessionStart node cjs/loader hook error | row 1; tui-watch @ 2026-06-29T17:45:15Z |
| E2E-020 | friction | orchestrator | Parent must spawn Task before first Edit — ~30s re-route on some flows | Expected; improved by Bash allowlist for `ls`, `git status`, `npm test` |
| E2E-021 | friction | hooks | PreToolUse hook JSON validation noise (`hookEventName` missing) | Non-blocking; upstream host strictness |
| E2E-022 | friction | matrix | Row `/clear` at session start is intentional (fresh context per row) | Distinct from context-full `/compact` recovery |

---

## E2E-016 — WBS meta-supervision (MVP)

Cross-cutting supervision: SB as user representative over decompose → execute → verify → validate intent.

| Deliverable | Status |
|-------------|--------|
| Design doc `docs/architecture/WBS-META-SUPERVISION.md` | Shipped |
| `hooks/lib/wbs-supervisor.sh` + Stop/PostToolUse shims | Shipped |
| State `.silver-bullet/wbs/current.json` | Shipped |
| SessionStart + UserPromptSubmit + SubagentStart integration | Shipped |
| Tests `tests/hooks/test-wbs-supervisor.sh` | Shipped |

**MVP behavior:** WBS stub on prompt; Stop blocks open items / pending intent validation; PostToolUse logs edit evidence; worker handoff snapshot.

**v2 deferred:** bidirectional subagent WBS sync, auto-decompose via skill, Plan/Debug branching, PreToolUse drift.

---

## Orchestrator parent Bash scope (E2E-001)

**Before:** `orchestrator-directive-guard.sh` blocked every Bash in parent mode.

**After:** Parent may use Bash unless the command appears to **mutate SB-managed state**:

- Blocked targets: `.silver-bullet/`, `.silver-bullet.json`, `.planning/STATE.md`, `.planning/ROADMAP.md`, `.planning/workflows/`, `orchestrator.json`, `orchestrator-directive.json`, `silver-bullet.md`
- Allowed examples: `git status`, `git log`, `ls`, `npm test`, read-only `jq -r`
- Still blocked in parent: Edit, Write, MultiEdit, apply_patch
- Workers: unchanged — full Bash after Task spawn

**Agent guidance:** Session-start injects updated parent context; use Read/Grep/Glob or read-only Bash for inspection; spawn Task worker for writes.

**Tests:** `tests/hooks/test-orchestrator-parent-guard.sh` — `ls` passes; `echo x > .planning/STATE.md` blocked.

---

## Routing philosophy — critical analysis

**User intent:** Bare prompts (no active workflow) should route via `/silver`; SB fulfills 100% intent via composed/dynamic/atomic flows including Q&A; catalog enriches over time.

### Agree (design direction)

1. **`skills/silver/SKILL.md`** explicitly biases “most non-trivial bare user intent” toward `/silver` and lists Q&A as a narrow direct-answer exception (Step 2).
2. **Parent orchestrator mode** composes queues via `silver-feature`, `silver-ui`, etc., and `flow-advance.sh` advances atomic flows — architecture supports dynamic composition.
3. **APO catalog + composable-flows-contracts** provide entity IDs and migration aliases — catalog can grow without renaming skills.

### Partially disagree / honest gaps (current vs desired)

| Desired | Current behavior | Gap |
|---------|------------------|-----|
| 100% bare prompt → `/silver` | Q&A, status-only, trivial exceptions allow freestyle | Agents often answer “how does X work?” without `/silver` — **acceptable for pure Q&A, leaky for “how do I fix X?”** (H-05 narrowing helps but is skill-doc-only) |
| Dynamic workflow for any intent | Composers exist for ~20 domain workflows; unknown intent → `silver:clarify` or `silver:fast` | No runtime **dynamic queue builder** for novel multi-step intents not matching a composer table row |
| Q&A via atomic flow | No `silver:qa` or `/silver` sub-flow with evidence artifact | Q&A bypasses state recording — Stop hook may not reflect “answered question” sessions |
| Catalog enrichment | `docs/apo-catalog.json` generated offline | No automatic promotion from successful matrix rows into catalog — manual `generate-apo-catalog.py` |

### Recommendations

1. **Hook-level H-05:** Extend `prompt-reminder.sh` or `record-requested-skill.sh` to nudge `/silver` when user message matches fix/debug/implement patterns and no workflow is active.
2. **Atomic Q&A flow:** Add `AF-QA` / `silver:orient` lightweight queue (read-only tools + optional graphify) so Q&A still records a skill marker when SB-initiated.
3. **Router catalog loop:** After matrix PASS, script promotion of new `skill_to_entity` entries from workflow evidence filenames.
4. **Do not** re-enable cooperative parent inline execution — parent/worker split is working; reduce friction via Bash scope (done) not by collapsing modes.

**Headline:** Routing **documentation and composers** match the vision; **enforcement is soft** (skill-doc exceptions, no PreToolUse bare-prompt gate). Dynamic composition works for known domains; **novel intents rely on agent discipline** to invoke `/silver`.

---

## Plan & Debug mode (host interaction)

### Current behavior

| Host mode | SB hook impact | Notes |
|-----------|----------------|-------|
| **Agent (default)** | Full PreToolUse/Stop/UserPromptSubmit stack | Orchestrator parent guard active |
| **Plan** (`SwitchMode` → plan) | Parent may call `SwitchMode` (allowed tool) | No dedicated SB hook detects Plan mode; edits still blocked in parent via guard |
| **Debug** | Not switchable via SB hooks | System-enforced; SB Stop/PreToolUse still fire if host allows tool use |
| **Ask** | Read-only by host | Aligns with SB parent read-only subset |

### Gaps

- No `hooks/*` reads host mode from stdin today.
- `silver` router does not branch composition for “plan-only” vs “execute” phases.
- Debug mode sessions may hit `dev-cycle-check` and `orchestrator-directive-guard` without tailored messages.

### Recommended SB adjustments

1. **Document** in `docs/ORCHESTRATOR.md`: Plan mode = parent may plan via Read/Grep + Task PLAN worker; Debug mode = route to `silver:debug` / `silver:forensics` queue, not freestyle Bash.
2. **Future (non-trivial):** SessionStart or PreToolUse parses mode hint; inject `SB PLAN MODE` context block (similar to parent block).
3. **Dynamic workflow branching:** When `SwitchMode` to plan detected, `flow-advance` could insert PLAN/DECIDE atoms before EXECUTE — requires orchestrator-state schema extension.

**Implementation this session:** Documentation only (no reliable hook detection found).

---

## Recommended tools — opt-in & enforcement

| Tool | Config key | Gate hook | Enterprise E2E requirement | Status |
|------|------------|-----------|----------------------------|--------|
| Graphify | `recommended_tools.graphify` | `graphify-gate.sh` | Session 0 opt-in + `graphify query` per row | **Hooks present**; matrix verifies query ref in ledger |
| agentmemory | `recommended_tools.agentmemory` | `agentmemory-gate.sh` | Session 0 opt-in + export ref on review rows | **Hooks present** |
| RTK | `recommended_tools.rtk` | `rtk-gate.sh`, `token-compression-tools-gate.sh` | Session 0 opt-in | **Hooks present**; global RTK hook may bypass project gate |
| Context Mode | `recommended_tools.context_mode` | `context-mode-gate.sh`, `context-mode-read-deny.sh` | Session 0 opt-in | **Hooks present** |
| Alumnium | `recommended_tools.alumnium` | `alumnium-gate.sh` | UI/clarify rows | **In template**; matrix rows 5/15 less strict than graphify |

### Gaps (E2E-011)

- ~~`silver:init` defaults `enabled_by_user: null` (pending) — enterprise operator must explicitly opt in all five during Session 0.~~ **Preflight enforces:** `enterprise_e2e_assert_all_recommended_tools_opted_in` fails fast when any of graphify/agentmemory/alumnium/rtk/context_mode is not `enabled_by_user: true` on the fixture.
- ~~No single preflight asserts all five gates fired in a dry-run matrix row.~~ **Implemented:** `enterprise_e2e_code_intel_preflight` dry-run + live paths cover all five tools; live path records graphify query when stale.
- Alumnium enforcement is softer (MCP hint vs hard deny) compared to Graphify — accepted for UI/clarify rows.

---

## Context compaction vs `/clear` (E2E-002)

| Trigger | Command | Rationale |
|---------|---------|-----------|
| Context window full (harness stall) | `/compact` | Preserves SB state markers and session continuity |
| Matrix row fresh session start | `/clear` | Intentional isolated row context |
| User `/clear` | Host handles | Destructive — SB SessionStart re-runs on `clear` matcher |

---

## Append policy

1. TUI monitors (`.planning/enterprise-e2e/.tui-monitor-*.py`, `scripts/watch-enterprise-e2e-tui.sh`) append new issues to `docs/issues/ENTERPRISE-E2E-SB-ISSUES.md` via `scripts/lib/enterprise-e2e-issues-append.py` (override path: `SB_E2E_ISSUES_FILE`); dedupe by excerpt prefix. **Round start:** `enterprise_e2e_reset_tui_monitor_offsets` seeks `.e2e-tui-watch-offsets.json` and `.tui-monitor-agent-offset.json` to EOF so historical attempt logs are not replayed; any E2E-086+ IDs filed before that fix are `false-positive-replay`.
2. Format: `| ID | severity | component | issue | fix/commit |`
3. Link fixes to commit SHA in the **Fixed** table.
4. Do **not** duplicate friction rows in ROUND-N-LEDGER.md (Round 4+ policy).

---

## Related

- [BACKLOG.md](./BACKLOG.md) — long-lived SB product backlog
- [ROUND-3-LEDGER.md](../../.planning/enterprise-e2e/ROUND-3-LEDGER.md) — matrix pass evidence
- [ROUND-4-GATES.md](../../.planning/enterprise-e2e/ROUND-4-GATES.md) — Round 4 run metadata
- [ORCHESTRATOR.md](../ORCHESTRATOR.md) — parent/worker model
