# verify_1 — rung 3 Cursor Gemini 3.7 Flash High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high`)  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md` (F-3-1…F-3-3 all ACCEPT-applied)

## Overall: **PASS**

Every F-3-1…F-3-3 ACCEPT text is present in the live PRD. SHA matches APPLY / expected digest. Charter signals OK. No residual undoes an ACCEPT.

## SHA-256

| | Digest |
|--|--------|
| Live PRD | `21624b374d90ec93d36367bfa7008240564e8ca5cb3ce83c98fb7abf27f8ce6c` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `21624b374d90ec93d36367bfa7008240564e8ca5cb3ce83c98fb7abf27f8ce6c` |
| Match | **yes** |

## Per-finding table

| ID | Sev | Verdict | Evidence (heading / file:line + excerpt) |
|----|-----|---------|------------------------------------------|
| F-3-1 | LOW | **PASS** | Phase 1 step 2 L397: update `rt_scope_includes_component` — include `search_cli` in **`packages`**; **`host`** only if Session A adds MCP/hooks; not **`project`** unless a project artifact exists; warns silent skip on `--scope packages` / `--fix=packages` if omitted. |
| F-3-2 | NIT | **PASS** | Test plan: single merged row L448 `Stale checks.sh consent-only PASS` (canary stays non-green). Former duplicate titles `Stale checks.sh path` and `Consent-only PASS (stale checks.sh)` **absent**. |
| F-3-3 | NIT | **PASS** | Freeze markdown **hrefs** are sibling `router_subagent_surfaces_85bf9f09.plan.md` (L5, L11, L248, L486). No href with `.planning/` prefix; literal `.planning/.planning/` count **0**. |

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
| Phase 1 step 2 `rt_scope_includes_component` / packages | L397 explicit |
| Duplicate stale checks.sh test rows | Merged to one row L448 |
| Sibling freeze links (not `.planning/.planning/`) | All freeze plan hrefs sibling-only |
| Prior rung locks (assume-yes / omniroute / PASS N/A unsupported / no `3ht3`) | Intact (not undone by F-3 edits) |

## Residuals (do not undo ACCEPT)

1. **F-3-3 display text:** L11/L248/L486 still *show* `` `.planning/router_subagent_surfaces_85bf9f09.plan.md` `` in link labels while href is sibling — correct for markdown resolution; ACCEPT was about avoiding nested `.planning/.planning/` targets.
2. **Appendix L540** plain-text path `.planning/router_subagent_surfaces_85bf9f09.plan.md` (not a relative markdown link) — outside F-3-3 link-href scope.

## Verdict rule

PASS only if every ACCEPT present and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
