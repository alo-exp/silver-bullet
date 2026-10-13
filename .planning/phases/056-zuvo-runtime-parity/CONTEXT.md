# CONTEXT — Phase 056: Zuvo / AS1 Runtime Parity

**Gathered:** 2026-06-14  
**Status:** Plan approved pending — implementation deferred until PLAN.md review  
**Supersedes:** Any in-flight parity implementation started without a formal plan (uncommitted WIP in working tree)

## Background

Commit `97cbce5` and release `v0.39.2` closed AS1 parity **on paper**: shared contracts (`docs/evidence-schema.md`, fingerprint guidance in `silver:add`, interface `STATE.md` template, `sb-diagnostics.sh`, refreshed `docs/sb-vs-as1.md`). Audit session `115077ee` found the **runtime layer** still missing for five structural contracts:

1. Evidence schema **validation** (validator script + delivery hook gate)
2. `silver:add` **fingerprint helper** (`scripts/silver-add.sh` + shared normalization)
3. Interface **STATE init** on project bootstrap (`stamp-interface-state.sh` wired into `silver:init`)
4. Install **UX** one-command probe (`sb-bootstrap.sh` + docs surfacing)
5. **Doc honesty** — parity ledger claims "implemented in-repo" before enforcement exists

Capability families (domain-audit packs, `silver:test` modes, canary, incident, benchmark, etc.) are **not** in scope — they landed in prior milestones.

## Locked decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Fingerprint canonical source | `scripts/lib/evidence_common.py` | Single normalization + hash implementation shared by shell and Python callers |
| Audit finding fingerprint | `sha256(normalize(domain) + "\n" + normalize(scope) + "\n" + normalize(finding))` | Matches `skills/silver-add/SKILL.md` contract |
| Scan candidate fingerprint | `sha256(normalize(title) + "\n" + normalize(context))` | Distinct shape from audit findings; same `normalize_text()` |
| Shell bridge | `scripts/silver-add.sh` invokes Python for `fingerprint`; bash for `dedup`/`prioritize` | Avoid duplicating hash logic in bash |
| Evidence schema enforcement | Warn-first on final delivery (`completion-audit.sh`); opt-in block via `SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1` | Matches doc-scheme gate pattern; avoids blocking mid-milestone PRs with legacy tables |
| Interface STATE stamping | Non-destructive: skip if file exists unless `SILVER_BULLET_FORCE_INTERFACE_STATE=1` | Preserves user-edited design state |
| UI project detection | `silver:init` stack/workflow heuristics + `package.json` frontend deps | Same signals as `stamp-interface-state.sh` |
| Install UX | `sb-bootstrap.sh` wraps `sb-diagnostics.sh` + init next-steps; does not replace marketplace install | SB install stays explicit/safe; bootstrap is probe + guidance |
| Numeric scoring | **Out of scope** | SB uses BLOCK/WARN/INFO + confidence; no AS1-style unified numeric grades |
| Multi-provider review | **Out of scope** | Sidekick/Kay routing excluded per user directive |
| Auto-routing | **Out of scope** | SB keeps explicit `/silver` entry; by design |

## Constraints

- Hooks must fail-open on missing `jq`/`python3` (visible warn, exit 0).
- New scripts live under repo `scripts/`; Codex package picks them up via `scripts/sync-codex-package.sh` (symlinked `plugins/silver-bullet/scripts/`).
- Skill changes must mirror to `agents/claude/`, `agents/codex/`, and `plugins/silver-bullet/skill-source/` via existing render/sync pipeline.
- Do not modify installed plugin cache under `${SB_RUNTIME_HOME_ROOT}/plugins/cache/`.
- Preserve uncommitted WIP as reference only — implementation follows PLAN.md waves.

## Assumptions

| Assumption | Status |
|------------|--------|
| Uncommitted WIP (validator, fingerprint script, hook gate, tests) is directionally correct | Accepted — reconcile in Wave 0 |
| `tests/run-all-tests.sh` auto-discovers new `tests/scripts/test-*.sh` files | Accepted |
| `completion-audit.sh` delivery path is the correct insertion point for evidence schema gate | Accepted — same tier as doc-scheme gate |
| Zuvo migrators care about behavioral parity, not command-name clones | Accepted |

## Open questions

- None blocking plan. Strict-mode default flip (`SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1` by default) deferred to a follow-up after one release cycle of warn-only telemetry.

## Planning handoff

**In scope:** Land runtime scripts, hook integration, init wiring, tests, plugin sync, parity ledger honesty update.  
**Out of scope:** Multi-provider review, auto-routing, numeric scoring, new capability families.
