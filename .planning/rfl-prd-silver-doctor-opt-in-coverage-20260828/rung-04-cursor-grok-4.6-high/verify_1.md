# verify_1 — rung 4 Cursor Grok 4.6 High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high`)  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md` (F-4-1…F-4-7 all ACCEPT-applied)

## Overall: **PASS**

Every F-4-1…F-4-7 ACCEPT text is present in the live PRD. SHA matches APPLY / expected digest. Charter signals OK. No residual undoes an ACCEPT.

## SHA-256

| | Digest |
|--|--------|
| Live PRD | `241daa69b7961f1ecd60c7bf3e642875914e1fca6fdc95f7e6a928717ec0622b` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `241daa69b7961f1ecd60c7bf3e642875914e1fca6fdc95f7e6a928717ec0622b` |
| Match | **yes** |

## Per-finding table

| ID | Sev | Verdict | Evidence (heading / file:line + excerpt) |
|----|-----|---------|------------------------------------------|
| F-4-1 | MED | **PASS** | L139: `search_cli` D10 on **Cursor, Claude, and Codex**; do not copy Alumnium `fu=1` / unsupported from Cursor-only `rt_host_supported`; five-tool/`cross_tool` stay Cursor-only. Also L212, L234 host-support cell, L408, L452, L519, L530. |
| F-4-2 | LOW | **PASS** | L158: live `rt_scope_includes_component` is **three-way** — `project` includes **cross_tool**; `host` includes **cross_tool**; `packages` lists graphify/agentmemory/rtk/context_mode/leanctx/alumnium (Session A adds `search_cli`); not a two-way split. |
| F-4-3 | LOW | **PASS** | SKILL examples L165 `--fix=packages`; test plan L451 `--fix=packages` for `search_cli`; Phase 1 step 2 L405 + prompt L565 `rt_scope_includes_component packages`. |
| F-4-4 | LOW | **PASS** | Non-goals L71 / F1 L201 / F4 L237 / MUST NOT L494 / prompt L611: PATH / `command -v` ban qualified as **alone**; `search_cli` remains PATH **plus** version. |
| F-4-5 | LOW | **PASS** | L103 + F2 L214: `D10-routes` / `no_five_tool_consent` → **PASS** (not PASS N/A, not WARN). Coverage `N/A rule` L233 matches. |
| F-4-6 | LOW | **PASS** | Test rows L453 PATH without version → not Health PASS; L454 provider-missing → WARN/Diagnosis. L145 / L378 / prompt L569 keep `required_when_enabled: false`. |
| F-4-7 | NIT | **PASS** | Prompt L577 names `recommended_tools.omniroute` / `D10-omniroute`; L573 names hermetic/live vendor-doctor path. |

## Charter verification signals

From repo root:

| Check | Result |
|-------|--------|
| `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` | EXISTS |
| `rg` Session A\|Session B\|search_cli\|MUST NOT\|generic installer\|omniroute\|WS7\|sb-doctor.sh\|CONFIGURED\|fail.closed\|N/A | Hits present (Session A/B fork; search_cli; MUST NOT; omniroute; WS7; sb-doctor.sh; CONFIGURED≠LIVE; fail-closed; N/A) |
| `rg` four surfaces\|Setup\|Health\|Diagnosis\|--fix | Hits present (four surfaces; Setup/Health/Diagnosis/`--fix` throughout) |

## Spot-checks

| Check | Result |
|-------|--------|
| search_cli hosts Cursor/Claude/Codex; not Alumnium fu=1 | L139, L212, L452 explicit |
| three-way scope map + cross_tool | L158 |
| `--fix=packages` on SKILL + test + prompt | L165, L451, L565–567 |
| PATH/`command -v` alone | L71, L201, L237, L611 |
| D10-routes no-consent = PASS not PASS N/A | L103, L214, L233 |
| provider-missing WARN + PATH-without-version + required_when_enabled false | L453–454, L145/L378/L569 |
| prompt omniroute + hermetic vendor-doctor | L573, L577 |
| Prior rung locks (assume-yes / packages Phase 1 / sibling freeze hrefs) | Intact (not undone by F-4 edits) |

## Residuals (do not undo ACCEPT)

1. **L103 message may contain “N/A”** while result state is PASS — intentional live-recorder gloss; F-4-5 ACCEPT is PASS-not-PASS-N/A for the result state.
2. **Prompt still mentions YAML `omni-agent-doctor`** alongside locked `omniroute` (L576–577) — both required; not a regression.

## Verdict rule

PASS only if every ACCEPT present and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
