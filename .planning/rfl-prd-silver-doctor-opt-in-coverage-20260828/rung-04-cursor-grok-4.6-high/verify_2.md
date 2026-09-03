# verify_2 — rung 4 Cursor Grok 4.6 High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high` / `cursor-grok-4.5-high`) — independent second verify  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs re-read:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md`, [`CHARTER.md`](../CHARTER.md), live PRD  
**Branch:** `main` @ `81560474` (no switch)

## Overall: **PASS**

Independent re-check: every F-4-1…F-4-7 ACCEPT from Policy C / APPLY is present in the live PRD and not undone. SHA matches expected. Charter `rg` signals green. FAIL ids: *(none)*.

## SHA-256

| Source | Digest |
|--------|--------|
| Live PRD (`shasum -a 256`) | `241daa69b7961f1ecd60c7bf3e642875914e1fca6fdc95f7e6a928717ec0622b` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `241daa69b7961f1ecd60c7bf3e642875914e1fca6fdc95f7e6a928717ec0622b` |
| Match | **yes** |

## Charter signals (orchestrator)

Ran from repo root:

1. `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` → **exists**
2. `rg … Session A|Session B|search_cli|MUST NOT|generic installer|omniroute|WS7|sb-doctor.sh|CONFIGURED|fail.closed|N/A` → **hits present** (145 lines; Session A/B, `search_cli`, MUST NOT / generic installer, omniroute, WS7, `sb-doctor.sh`, CONFIGURED, fail-closed / N/A)
3. `rg … four surfaces|Setup|Health|Diagnosis|--fix` → **hits present** (104 lines; four-surface Omni, Setup/Health/Diagnosis/`--fix`)

## Per-finding table (independent quotes)

| ID | Sev | Verdict | Live PRD evidence (own line quotes) |
|----|-----|---------|-------------------------------------|
| F-4-1 | MED | **ACCEPT** | **L139**: `search_cli` D10 FAIL on missing CLI/version applies on **Cursor, Claude, and Codex**; do not copy Alumnium `fu=1` / unsupported from Cursor-only `rt_host_supported`; five-tool/`cross_tool` stay Cursor-only. Also **L212**, host-support cell **L234**, tests **L408**/**L452**, AC **L519**, OQ **L530**. |
| F-4-2 | LOW | **ACCEPT** | **L158**: live `rt_scope_includes_component` is **three-way** — `project` includes **cross_tool**; `host` includes **cross_tool**; `packages` = graphify/agentmemory/rtk/context_mode/leanctx/alumnium (Session A adds `search_cli`); not a two-way split; `cross_tool` not in `packages`. |
| F-4-3 | LOW | **ACCEPT** | SKILL example **L165** `bash scripts/sb-doctor.sh --fix=packages`; canary note **L169**; Phase 1 step 2 **L405** updates `rt_scope_includes_component` packages; test row **L451**; implementer prompt **L565** names `rt_scope_includes_component packages`. |
| F-4-4 | LOW | **ACCEPT** | Non-goals **L71** / F1 **L201** / F4 **L237** / MUST NOT **L494**/prompt **L611**: PATH / `command -v` ban qualified as **alone**; `search_cli` remains PATH **plus** non-secret version. |
| F-4-5 | LOW | **ACCEPT** | Current-system **L103** + F2 **L214**: `D10-routes` / `no_five_tool_consent` → **PASS** (not PASS N/A, not WARN). Coverage `N/A rule` **L233** matches live recorder. |
| F-4-6 | LOW | **ACCEPT** | Test rows **L453** PATH without version → not Health PASS; **L454** provider-missing → WARN/Diagnosis. **L145** / **L378** / prompt **L569** keep `required_when_enabled: false`. |
| F-4-7 | NIT | **ACCEPT** | Prompt **L577** names `recommended_tools.omniroute` / `D10-omniroute`; **L573** (and Phase 2 **L416** / AC **L519**) name hermetic/live vendor-doctor path. |

## Regression hunt (APPLY failure modes)

| Hunt | Result |
|------|--------|
| `search_cli` still treated as Cursor-only / Alumnium `fu=1` | **fixed** L139 / L212 / L234 / L452 |
| Scope map still two-way (missing `cross_tool` in project/host) | **fixed** L158 three-way |
| `--fix=packages` / `rt_scope_includes_component` omitted from SKILL/test/prompt | **fixed** L165 / L405 / L451 / L565 |
| Unqualified PATH/`command -v` Health ban (no “alone”) | **fixed** L71 / L201 / L237 / L611 |
| `no_five_tool_consent` described as PASS N/A | **fixed** L103 / L214 / L233 → PASS |
| Missing PATH-without-version / provider-missing rows; `required_when_enabled` flipped true | **fixed** L453–L454; false kept L145 / L569 |
| Prompt omits omniroute / hermetic vendor-doctor | **fixed** L577 / L573 |
| SHA drift vs APPLY | **none** — match `241daa69…ec0622b` |

## Residuals (do not undo ACCEPT)

1. **L24** current-system allowlist still correctly documents *today’s* live tree without `search_cli` — Session A gap, not a regression of the ACCEPT locks.
2. Display/link text elsewhere may still contrast Cursor-only five-tool vs host-agnostic `search_cli`; the locked contracts above are the implementer SoT.

## Graphify / tools note

- `graphify query` run first (CLI; surfaced PRD, `sb-doctor.sh`, recommended-tools surfaces).
- Context Mode + Shell for SHA / charter `rg` / line extraction; native Write for this file only.
- agentmemory `memory_save` for this verify_2 pass.
- Scope lock honored: only this `verify_2.md` written; PRD / freeze / doctor code untouched. Independent of verify_1.
