# Rung 4 review — Cursor Grok 4.6 High (REVIEW-ONLY)

**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md) (live, post-rung-3 APPLY)  
**Charter:** [`.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/CHARTER.md`](../CHARTER.md)  
**Ledger:** [`.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/ISSUE-LEDGER.md`](../ISSUE-LEDGER.md) — I-1…I-26 closed; re-filed only if still broken  
**PRD SHA-256:** `21624b374d90ec93d36367bfa7008240564e8ca5cb3ce83c98fb7abf27f8ce6c` (matches rung-3 APPLY)  
**Scope:** PRD internal consistency + implementability as Session A. No PRD edits, no freeze edits, no doctor implementation.  
**Prior rungs:** GLM 5.2 High (I-1…I-14), Kimi K3 High (I-15…I-23), Gemini 3.7 Flash High (I-24…I-26).

## Verdict: **NOT CLEAN**

The PRD is Session-A-implementable and internally mature after three APPLY passes. Session A/B, Omni WS7 isolation, `--fix` swallow, N/A-vs-FAIL for opted-out/unknown, coverage-table schema, AC 11 locked defaults, and OQ 6/7 non-blocking branches all hold. Remaining gaps are residual underspecification around the `search_cli` canary’s **host model**, incomplete **propagation of I-24** (`rt_scope_includes_component` / `--fix=packages`) into the test plan and paste prompt, and a few **wording clashes** (PATH Health, `D10-routes` PASS vs PASS N/A) that can still fork an implementer.

Counts: **HIGH 0 / MED 1 / LOW 5 / NIT 1** (7 findings).

---

## Bird's-eye

- **Session A/B fork remains airtight.** Session A is D10 completeness on the live reconciler + probe contract; Session B (unbounded generic installer) is rejected in the session fork table (L42–49), non-goals (L61–73), F6/NF3, MUST NOT (L471–489), and the copy-paste prompt (L532–548). No path lets “inventory all keys” become a SPA curl-bash installer.
- **Four surfaces are class-instantiated, not Omni-copied.** F1 (L187–198) maps Setup / Health / Diagnosis / `--fix` per `CLI|MCP|daemon|hooks|vendor-doctor`. F7 + Phase 3 keep Omni daemon/busy-class/`chat_admission_busy` off Graphify/RTK probes. That isolation still holds.
- **`search_cli` canary is the right first phase**, modeled on Alumnium extra-tool (registry + probe + `RT_COMPONENT_IDS` + SKILL + N/A vs FAIL + bounded `--fix`). I-24 correctly added `rt_scope_includes_component` / `packages` to Phase 1 step 2 (L397). The **host** half of that canary is still unlocked: “mirror Alumnium” inherits Cursor-only `rt_host_supported`, while locked Health is PATH + version of a brew CLI (F-4-1).
- **`--fix` contract is coherent** across live blast radius (L147–164), F5 (L231–238), blast-radius table (L292–319), Phase 1 step 6 (no swallow hedge), AC 3, and `SB_DOCTOR_ASSUME_YES=1`. Dry-run / empty-JSON / secrets / idempotency / TTY confirm vs CI assume-yes do not contradict.
- **N/A vs FAIL** is locked for opted-out (`pending`/`disabled` PASS N/A), opted-in broken (FAIL `D10-<tool>`), and unknown id (PASS N/A `unsupported`, no installer — I-3/I-17). Derived `cross_tool` / `D10-routes` no-consent is PASS-not-WARN (I-15) but still **PASS vs PASS N/A** (F-4-5).
- **Coverage table (F4) + AC 1** require every current `recommended_tools` key including `search_cli`, derived `cross_tool`, `docs_pin` on every row, Omni only after phase 3 (or an explicit “planned WS7” row). Phase 2 `docs_pin` backfill (I-20) is in the plan. Host-support **column** exists; search_cli **value** does not (F-4-1).
- **Test plan vs AC** mostly lines up (AC 3 swallow, AC 4 five-tool `--fix` fixture, AC 8/phase-3 `test-router-doctor-report.sh`, AC 9 positive stale-loop canary, AC 11 vendor-doctor hermetic + Graphify WARN + assume-yes). Missing rows: provider-missing WARN and PATH-without-version (F-4-6); `--fix=<scope>` never names `packages` for the canary (F-4-3).
- **OQ 6/7 stay correctly open.** OQ6 (phase 3 same-session vs defer) is branched in AC 7/8. OQ7 (delete vs generate stale `checks.sh`) is optional given AC 9’s unused-path + canary. Do not treat them as blockers.
- **Implementer prompt** carries Session A/B, swallow, assume-yes (I-23), coverage schema, Omni-as-patient-not-worker. It does **not** carry I-24’s `rt_scope_includes_component` / packages (F-4-3) or the locked `omniroute` / `D10-omniroute` key (F-4-7).

---

## Ant's-eye

### Closed ledger still holds (I-1…I-26)

Spot-checked against live PRD bytes; none of I-1…I-26 are still broken as originally filed.

| Cluster | Still present |
|---------|----------------|
| I-1 / I-23 `SB_DOCTOR_ASSUME_YES=1` | F5 L238, test L452, OQ3 L519, AC 11 L507, prompt L577 / L589 |
| I-2 / I-22 locked defaults 1–5 + AC 11 | L515–521; still-open 6–7 at L523–526 |
| I-3 / I-17 unknown → PASS N/A `unsupported` | F2 L207, test L446 |
| I-4 false-green catalog rows | L449–451 (`reload_required`, health URL, `min_version`) |
| I-5 AC 8 + `test-router-doctor-report.sh` | L453, L504 |
| I-6 / I-19 AC 9 positive canary | L448, L505 |
| I-7 swallow hedge removed | Phase 1 step 6 L401 |
| I-8 D10 FAIL vs D22 catalog WARN | NF2 L276 |
| I-9 OAuth fully manual | Phase 3 L420; “one click” glossed |
| I-10 / I-11 `omniroute` + PATH+version Health | L376, L398, L517–518 |
| I-15 `D10-routes` no-consent is PASS not WARN | L103 (PASS vs PASS N/A leftover = F-4-5, new) |
| I-16 / I-21 hermetic vendor-doctor, merged skip row | L408, L447, L520 |
| I-18 `cross_tool` in Goal 2 / F4 / AC 1 | L54, L215, L497 |
| I-20 Phase 2 `docs_pin` backfill | L412 |
| I-24 `rt_scope_includes_component` in Phase 1 step 2 | L397 (not in prompt/test/SKILL examples = F-4-3, new) |
| I-25 single stale `checks.sh` test row | L448 |
| I-26 sibling freeze hrefs | L5, L11, L72, L248, L486 → `router_subagent_surfaces_85bf9f09.plan.md` |

### Live current-system vs PRD claims

Graphify + file checks (charter: contradictions with stated current system):

- **Config:** seven `recommended_tools` keys; `search_cli.enabled_by_user` is null; binary `search`; brew `install_commands`; `provider_classes` present. No `probe-search_cli.sh` / `probe-omniroute.sh` / `docs/OMNIROUTE.md` / `docs/TROUBLESHOOTING.md`. Matches L23–25, L124, L143, L331.
- **Allowlist:** `RT_COMPONENT_IDS=(graphify agentmemory rtk context_mode leanctx alumnium cross_tool)` in [`scripts/lib/recommended-tools/common.sh`](../../../scripts/lib/recommended-tools/common.sh) L8. Matches L133.
- **`--fix` swallow:** still live on `doctor_apply_fixes` (`2>/dev/null \|\| true`, `DOCTOR_FIX_APPLIED=1` on empty JSON). Matches L32, L152. Session A repair, not a PRD stale-claim.
- **`rt_host_supported`:** Cursor only ([`common.sh`](../../../scripts/lib/recommended-tools/common.sh) L102–107). Alumnium extra-tool sets `fu=1` (unsupported) when it fails ([`probe-alumnium.sh`](../../../scripts/lib/recommended-tools/probe-alumnium.sh) L62). This is the landmine under “mirror Alumnium” (F-4-1).
- **`rt_scope_includes_component`:** live matrix is three-way with `cross_tool` in `project` **and** `host`, and `packages` containing **both** graphify/agentmemory and rtk/context_mode/leanctx/alumnium ([`common.sh`](../../../scripts/lib/recommended-tools/common.sh) L247–270). L154’s two-way “splits A vs B” is stale (F-4-2).
- **Unique config flag omitted:** `search_cli.required_when_enabled` is **false**; every other key (including Alumnium) is **true**. Hooks use it in `sb_recommended_tool_enforced()` ([`hooks/lib/recommended-tools.sh`](../../../hooks/lib/recommended-tools.sh) L56–67); doctor/reconciler do not read it today (F-4-6 adjacent).

### Residual gaps (new)

1. **Host model for the canary is the last load-bearing unspecified.** F4 requires a `host support` cell; the host matrix (L166–173) has columns for five-tool+routes, host-install `--fix`, and Omni CLIs — not `search_cli`. F2’s “opted in on a **supported host**” has no definition for this tool. Copying Alumnium yields Cursor-only PASS N/A on Claude/Codex even when the brew CLI is missing; honoring PATH+version + JTBD L82 (host-agnostic core) needs a per-component host gate, because `rt_host_supported` is global.
2. **I-24 closed the body hole, not the entry surfaces.** Phase 1 step 2 now says: put `search_cli` in `packages`; host only if MCP/hooks; not `project`. Test plan L442 still says `--fix=<scope>`. SKILL examples quoted at L159–161 are `--fix=local|host|all` (no `packages`). Prompt order item 1 lists `RT_COMPONENT_IDS` / extra-tool, not `rt_scope_includes_component`. An implementer who pastes the prompt and follows the SKILL snippet can still `--fix=local` and silently skip the canary.
3. **PATH Health wording vs locked OQ2.** Non-goal L71 and MUST NOT L594 ban “Health from PATH / `command -v`.” F1 L194 says “not `command -v` **alone**.” OQ2/AC 11 lock PATH **plus** version. Unqualified L71 can make a reader reject the locked default.
4. **`D10-routes` result state.** L103 documents live **PASS** with N/A-in-message for `no_five_tool_consent`. F2 L204 teaches not-opted-in → **PASS N/A**. I-15 fixed WARN vs PASS only. Coverage-table `N/A rule` for derived `cross_tool` is still unspecified.
5. **Test plan vs locked search_cli Health.** Table has opted-out N/A and opted-in missing CLI FAIL. No row for provider-missing → WARN (not FAIL, not dumped key) and no row for PATH without version → not Health PASS — both required by Phase 1 step 3 / OQ2 / AC 11.
6. **Prompt vs AC 11.** Paste prompt never names `recommended_tools.omniroute` / `D10-omniroute` (says `omni-agent-doctor` only) and never names the hermetic vendor-doctor path. Body locks both.

---

## Findings table

| ID | Severity | Location | Summary |
|----|----------|----------|---------|
| F-4-1 | MED | Host matrix L166–173; F2 L206; F4 `host support` L226; Phase 1 L392–398; OQ2 L518; JTBD L82; live `rt_host_supported` [`common.sh`](../../../scripts/lib/recommended-tools/common.sh) L102–107; [`probe-alumnium.sh`](../../../scripts/lib/recommended-tools/probe-alumnium.sh) L62 | `search_cli` **host support is unlocked**. “Mirror Alumnium extra-tool” inherits Cursor-only `rt_host_supported` → unsupported/`fu=1` on Claude/Codex. Locked Health is PATH + `search --version` of a brew CLI (host-agnostic). F2 FAIL applies only on a “supported host”; F4 requires a host-support cell; the matrix has no search_cli column. Copy-Alumnium → false PASS N/A for opted-in missing CLI off Cursor. Honor PATH+version on Claude → must special-case host gates without changing five-tool Cursor-only. Session A has no locked default. |
| F-4-2 | LOW | Current system L154 vs live [`common.sh`](../../../scripts/lib/recommended-tools/common.sh) L247–270 | L154 says `rt_scope_includes_component` “splits graphify/agentmemory vs rtk/context_mode/leanctx/alumnium.” Live function is three scopes: `project`={graphify,agentmemory,**cross_tool**}, `host`={rtk,context_mode,leanctx,alumnium,**cross_tool**}, `packages`={graphify,agentmemory,rtk,context_mode,leanctx,alumnium}. Packages is not “the other half”; `cross_tool` is omitted. I-24 updated Phase 1 step 2 (L397) but left this current-system map stale. |
| F-4-3 | LOW | Phase 1 step 2 L397 (has the contract); test plan L442; SKILL examples L159–161; implementer prompt L550–555 | I-24’s packages/`rt_scope_includes_component` instruction did not land on the surfaces an implementer actually follows first. Test plan `--fix=<scope>` never names `--fix=packages` for `search_cli`. Quoted SKILL commands are `--fix=local\|host\|all` only. Prompt order (1) lists registry + probe + `RT_COMPONENT_IDS`/extra-tool, not the scope function. Same silent-skip as F-3-1 if the paste prompt + SKILL snippet are treated as sufficient. |
| F-4-4 | LOW | Non-goals L71; F1 Health L194; F4 L229; MUST NOT L594; OQ2 L518; AC 11 L507 | L71/L594 forbid “claiming Health from PATH” / “from `command -v`” with no “alone” qualifier. F1 already says not `command -v` **alone**. Locked OQ2/AC 11 **are** PATH + version. After I-11, this leftover can still make an implementer reject the locked Health default or under-test it. |
| F-4-5 | LOW | Current system L103; F2 L204; JTBD L82; Goal 2 L54; F4 `N/A rule` L225 | `D10-routes` / `no_five_tool_consent` is documented as **PASS** (message contains “N/A”). F2’s not-opted-in rule is **PASS N/A**. I-15 closed WARN vs PASS only; APPLY text said “PASS N/A.” Derived `cross_tool` has no F2 bullet and no coverage-table N/A-rule value. Tests asserting PASS N/A vs PASS will disagree. |
| F-4-6 | LOW | Phase 1 step 3 L398; test plan L437–453; AC 11 L507; OQ2 L518; inventory L370; `.silver-bullet.json` `search_cli.required_when_enabled=false` vs Alumnium `true`; [`recommended-tools.sh`](../../../hooks/lib/recommended-tools.sh) L56–67 | Test plan has no row for **provider-missing → WARN** (not FAIL, no dumped key) and no row for **PATH without version → not Health PASS**, both locked by OQ2/AC 11/Phase 1 step 3. Inventory also omits the unique `required_when_enabled: false` flag (hooks skip enforcement; doctor does not read it today). “Mirror Alumnium” can copy `required_when_enabled: true` into search_cli or, conversely, treat “not required” as D10 PASS N/A when opted in. |
| F-4-7 | NIT | Implementer prompt L546–566 vs OQ1 L517 / AC 11 L507 / I-16 L520 | Paste prompt never names locked JSON key `omniroute` / D10 id `D10-omniroute` (only YAML `omni-agent-doctor`) and never names the hermetic vendor-doctor path. Body + AC 11 lock both. Prompt is “together with this PRD,” so not load-bearing — but it already got I-23 for the same class of drift. |

---

## Counts

| Severity | IDs | Count |
|----------|-----|-------|
| HIGH | — | 0 |
| MED | F-4-1 | 1 |
| LOW | F-4-2, F-4-3, F-4-4, F-4-5, F-4-6 | 5 |
| NIT | F-4-7 | 1 |

**Total: HIGH 0 / MED 1 / LOW 5 / NIT 1** (7 findings).

---

## Review notes

- **Charter compliance:** REVIEW-ONLY. No edits to the PRD, freeze plan, or doctor code. No triage / ACCEPT / REJECT.
- **Graphify:** CLI `graphify query "PRD silver doctor opt-in D10 search_cli omniroute rt_scope_includes_component --fix"` (MCP namespace `user-graphify` was down). Surfaced `rt_scope_includes_component()` in `common.sh` L247, `doctor_apply_fixes()` in `sb-doctor.sh`, search-cli docs, OmniRoute WS notes.
- **Closed items:** I-1…I-26 not re-filed. F-4-3 is **prompt/test/SKILL propagation** of I-24, not I-24 itself (Phase 1 step 2 is fixed). F-4-5 is the PASS vs PASS N/A leftover after I-15, not a WARN regression.
- **Worst finding:** F-4-1 (MED) — `search_cli` host support unspecified; Alumnium/`rt_host_supported` Cursor-only vs PATH+version brew CLI.
