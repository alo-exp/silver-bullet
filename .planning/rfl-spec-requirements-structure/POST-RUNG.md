# POST-RUNG — parent checklist

After **every** rung on [`.planning/rfl-spec-requirements-structure/`](./), the launcher/parent (not the rung model) does this. Do not skip because the verdict was CLEAN. Do not dump raw `review.md`. Do not execute freeze YAML. Do not rewrite the freeze plan except ledger SHA metadata. Do not clobber `rung-NN-*/review.md` while a reviewer is writing it.

Skill: [`skills/silver-review-fix-ladder/SKILL.md`](../../skills/silver-review-fix-ladder/SKILL.md) Policy C + Per-Rung Workflow.

## Order (mandatory)

1. **Review returns** (`rung_N_review`) — one review-only Task at the rung model. Parent does **not** triage inside the reviewer prompt.
2. **Policy C artifact-first** (`rung_N_triage`):
   - Write `rung-NN-*/policy-c-payload.json` (`schema: rfl.policy_c.v1`).
   - Encode:

     ```bash
     python3 scripts/review-fix-ladder.py --write-policy-c \
       --rung-dir .planning/rfl-spec-requirements-structure/rung-NN-<slug>/ \
       --table-json-file .planning/rfl-spec-requirements-structure/rung-NN-<slug>/policy-c-payload.json
     python3 scripts/review-fix-ladder.py --assert-policy-c \
       --rung-dir .planning/rfl-spec-requirements-structure/rung-NN-<slug>/
     ```

   - Canonical files: `POLICY-C.json` + `POLICY-C.md` under the rung dir. Paste **encoder stdout** to the user (issue table → triage table → blockers/highs/mediums → disposition → resolved table after APPLY).
3. **ISSUE-LEDGER.md** — append this rung’s findings (ACCEPT / REJECT-as-wrong + why-wrong). Forbidden reject reasons: advisory, doc-only, non-gating, non-blocking nit, CLEAN-so-ignore.
4. **APPLY** (`rung_N_fix_parallel`) — parent Edit/Write every ACCEPT (including LOW / NIT). Write `APPLY.md`. Pin freeze SHA-256 to APPLY’s SHA in `CHARTER.md` Freeze, `LADDER-STATUS.json` `freeze.sha256` / `apply_sha`, and Policy C `apply_sha`.
5. **Verify_1** then **Verify_2** — **separate** Tasks. Model: **Grok 4.5 High** native Cursor (`cursor-grok-4.5-high` / `sb-grok-4-5-high`). Readonly. Never Pi / Omni / `agent-pi`. Never Grok 4.6 for Verify. After each pass, run charter verification signals and log pass/fail.
6. **LADDER-STATUS.json** — keep `status: active` until the whole ladder finishes:

     ```bash
     python3 scripts/review-fix-ladder.py --mark-ladder-status active \
       --run-dir .planning/rfl-spec-requirements-structure \
       --rung-id rung-NN-<slug> \
       --current-phase rung_N_verify_2
     ```

   - `current_rung` must be a **string**. Record `rung_NN.verify_1` / `verify_2` PASS, `applied`, `apply_sha`.
   - Then: `python3 scripts/review-fix-ladder.py --assert-rfl-advance --run-dir .planning/rfl-spec-requirements-structure --rung-dir <rung> --next-action next_rung_review`
7. **CHARTER.md** — last completed rung, current phase, freeze SHA pinned to APPLY.
8. **LADDER.md** — that row DONE (or SKIPPED/BLOCKED). Verify is **per rung**, not extra V1/V2 ladder rows.
9. Advance to N+1 **only** after two clean verifies + greps + ACCEPTs applied (or REJECT-as-wrong recorded).

## Host routing (do not remap)

| Family | Review host | Verify |
|--------|-------------|--------|
| GLM / Kimi / Gemini / Grok | Cursor `Task` (`sb-*`) | Grok 4.5 High native Cursor |
| GPT | Pi Codex (`/silver:agent-codex`) | Grok 4.5 High native Cursor |
| Claude / Opus | Pi (`/silver:agent-claude`) | Grok 4.5 High native Cursor |

- **Cursor-family never via Pi** (Omni tool-call translation is broken).
- **Claude via Pi.** GPT via Pi Codex. User-named host wins.
- **Never Fast.** Never Grok 4.6 Extra High as unspecified default. Do not remap GPT/Claude onto Grok High for **review**.

## Sibling artifacts (only when they apply)

| Step | Artifact | Gate |
|------|----------|------|
| Policy C | `POLICY-C.json` + `.md` | before next phase |
| BLOCKED / quota | `BLOCKED.md` + `QUOTA-CLASSIFY.json` | before next rung or substitute |
| Skip after retry-once | `SKIPPED.md` | before starting N+1 |
| STOP / compliance | `STOP.md` with which check failed | block advance |
| ACCEPT apply | `APPLY.md` or resolved table complete | before `rung_{N+1}_review` |
| Two verifies | `verify_1.md` + `verify_2.md` (or BLOCKED/SKIPPED) | before N+1 |

CLEAN with no findings still gets HIGH/MED/LOW/NIT `"none"` plus blockers/highs/mediums **none**.

## Encoder-mandatory user update (paste stdout)

1. Rung identity (family + High / Extra High / Max)
2. Verdict: CLEAN \| NOT CLEAN \| BLOCKED \| SKIPPED
3. Issue table grouped HIGH / MED / LOW / NIT
4. Triage table: ACCEPT vs REJECT-as-wrong + reason
5. Blockers / Highs / Mediums (or none)
6. Disposition: ACCEPT-apply \| REJECT-as-wrong \| HOLD \| SKIP
7. After APPLY: resolved table (`pending` only while `rung_N_fix_parallel`)

At ladder end: `--ladder-matrix` / Policy D. `--mark-ladder-status completed` only when every reviewed rung has Policy C.
