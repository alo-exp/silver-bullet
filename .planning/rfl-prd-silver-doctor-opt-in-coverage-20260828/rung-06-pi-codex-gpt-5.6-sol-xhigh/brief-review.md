# Rung 6 review brief — Pi Codex GPT-5.6 Sol Extra High

You are on rung 6/8: model=`codex/gpt-5.6-sol-xhigh`, reasoning=xhigh.
Phase: REVIEW-ONLY (`rung_6_review`)

## Scope (do not exceed)

1. `.planning/PRD-silver-doctor-opt-in-coverage.md` — review target (do **not** edit)
2. `.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/` — read charter, ledger, prior APPLY notes; write **only** `rung-06-pi-codex-gpt-5.6-sol-xhigh/review.md`

**FORBIDDEN** any other path. Do not open `.planning/router_subagent_surfaces_85bf9f09.plan.md` unless citing a PRD cross-link that already exists in the PRD. Do not implement doctor code. Do not `git checkout` / `git switch` / change branches.

## Charter goals

1. PRD is internally consistent and implementable as Session A (D10 completeness on live `sb-doctor.sh` + reconciler).
2. Bird's-eye: missing product slices, wrong scope fork, contradictions with stated current system, untestable "done when".
3. Ant's-eye: wrong paths, stale D10 lists, `--fix` swallow, host matrix, N/A vs FAIL, search_cli canary, Omni WS7 vs D10 stuffing, docs-pin, secrets, five-tool mutex.
4. Findings have `file:line` (or heading + quote) and severity HIGH / MED / LOW / NIT.

## Non-goals

- Implementing `/silver:doctor` or probes
- Editing the router-subagent freeze
- Session B unbounded generic installer
- Repo-wide audit

## Prior ACCEPTs (I-1…I-43) — do **not** re-file as new issues

Hunt **new** gaps only. IDs **F-6-1…**. Locked through rung 5 including: registry-pinned `install_commands`; secrets on stdout/stderr/JSON/receipts; repair-dispatch tests; provider-missing WARN mapping; non-TTY skip/nonzero; failed-apply observation; Phase 3 gated on WS6 installer; Omni current-host CLI; deferred Omni footnote not F4 row; `cross_tool` SB-owned `docs_pin`.

## Tasks

1. Read the PRD and charter. Run `graphify query "silver doctor opt-in D10 search_cli omniroute reconciler"` before exploring code. Retrieve prior notes via Graphify. Save via agentmemory `memory_save` if available.
2. Thorough bird's-eye **and** ant's-eye review. Report raw findings with line references and severity hints.
3. Write findings to `.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/rung-06-pi-codex-gpt-5.6-sol-xhigh/review.md`.
4. If CLEAN with no new gaps, say so explicitly in `review.md`.

## FORBIDDEN

- Do NOT triage, classify ACCEPT/REJECT, file issues, or apply fixes.
- Do NOT edit the PRD, plans, specs, tests, or docs.
- Do NOT claim PASS or recommend advancing — orchestrator verifies.
- Do NOT launch subagents or parallel work.
- Do NOT use Fast models.
