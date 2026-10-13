# PLAN — Phase 106: Doctor opt-in coverage (Session A)

**SILVER BULLET > PLAN**

| | |
|---|---|
| **Mode** | Standard (not `--mvp`). ROADMAP is v0.39.3 Zuvo parity (complete); no `**Mode:** mvp` for this workstream. No `SKELETON.md`. |
| **Workstream** | Session A of [PRD-silver-doctor-opt-in-coverage.md](../../PRD-silver-doctor-opt-in-coverage.md) |
| **Clarify** | [PRD-silver-doctor-opt-in-coverage-CLARIFY-260830-20260830T102936Z.md](../../PRD-silver-doctor-opt-in-coverage-CLARIFY-260830-20260830T102936Z.md) (`decision_class: locked-defaults`) |
| **GSD framing** | `.planning/{PROJECT,REQUIREMENTS,ROADMAP,STATE}.md` are the last shipped milestone (v0.39.3, 2026-06-14). **Do not restamp.** The PRD + clarify brief are the phase framing. |
| **Slices** | One plan. Wave 1 = PRD Phase 1. Wave 2 = PRD Phase 2. Phase 3 Omni deferred. Phase 4 out of Session A close. |
| **Next skill** | `/silver:execute` (do not start from this PLAN worker) |

## 1. Goal

Make `/silver:doctor` (public alias `/sb:doctor`) an honest D10 audit of every **allowlisted** `recommended_tools` key plus derived `cross_tool`: opted-out is PASS N/A, opted-in broken is FAIL with evidence, `--fix` is proveable (no swallow), unknown tools fail closed. Close the `search_cli` canary that config ≠ doctor. Do **not** build Session B (generic installer).

## 2. Scope

### In (Session A, this plan)

- Live doctor path only: `scripts/sb-doctor.sh` + `scripts/reconcile-recommended-tools.sh` + `scripts/lib/recommended-tools/probe-*.sh` + `hooks/lib/recommended-tools-registry.sh` + `scripts/lib/recommended-tools/common.sh` + `skills/silver-doctor/SKILL.md` + `tests/scripts/test-silver-doctor.sh` + `tests/scripts/test-reconcile-recommended-tools.sh`.
- Plan slice 1 / Wave 1: `search_cli` extra-tool (Alumnium **consent/registry** pattern, **not** Cursor-only `rt_host_supported`) + close `--fix` swallow in the same wave.
- Plan slice 2 / Wave 2: honesty on the existing allowlist (`docs_pin` backfill, vendor-skip ≠ Health, `min_version` FAIL, Graphify skew WARN, `--fix` fixtures, `/sb:doctor` alias, repair-dispatch, stale-loop canary). Delete stale `scripts/lib/sb-doctor/{checks,fix}.sh` unless a non-D10 caller appears.
- `/sb:doctor` remains the public alias of `/silver:doctor` (same runner; no second doctor).

### Out (explicit)

| Item | Disposition |
|---|---|
| Session B unbounded SPA/curl-bash / any-MCP installer | Rejected |
| PRD Phase 3 Omni `omniroute` four-surface | Deferred until `scripts/install-omniroute-sb.sh` exists. Coverage-table **footnote** only (“planned WS7, not D10 Graphify”) — **not** an F4 row, **not** a partial probe |
| PRD Phase 4 allowlisted plugin interface | Out of Session A close |
| Editing `.planning/router_subagent_surfaces_85bf9f09.plan.md` | Forbidden |
| Git branch switch / `SetActiveBranch` / commit | Forbidden unless a later human asks |
| Invented `graphify doctor`, `lean-ctx init --agent *`, secret dumps, automatic `--fix` rollback | Forbidden |
| Graphify `min_version` pin in config | Out of Session A (WARN on skill/package skew only) |
| `search_cli` in `--fix` scopes `project` or `host` | Not in Phase 1; packages only |
| Changing `required_when_enabled: false` on `search_cli` | Keep false (hook enforcement ≠ D10 honesty) |
| SPEC.md / REQUIREMENTS.md compilation | Not this FLOW 3/6 pass |
| Full `bash tests/run-all-tests.sh` as the phase-done gate | Not required; targeted doctor + reconciler tests are |

## 3. Current-system facts (do not re-litigate)

Settled in clarify; implement as written.

- Canonical D10 is `doctor_record_reconciler_d10()` in `scripts/sb-doctor.sh`. Graphify: **no directed path** `scripts/sb-doctor.sh` → `scripts/lib/sb-doctor/checks.sh`.
- `RT_COMPONENT_IDS=(graphify agentmemory rtk context_mode leanctx alumnium cross_tool)` — no `search_cli`, no Omni.
- `rt_host_supported` is Cursor-only for five-tool / `cross_tool`. **`search_cli` does not inherit that gate** (Cursor + Claude + Codex).
- Live `rt_scope_includes_component`: `project` = graphify, agentmemory, cross_tool; `host` = rtk, context_mode, leanctx, alumnium, cross_tool; `packages` = graphify, agentmemory, rtk, context_mode, leanctx, alumnium. **`search_cli` must be added to `packages` only** in Wave 1.
- `--fix` swallow (live): `RECONCILER_JSON="$(bash "$reconciler" … 2>/dev/null || true)"` then `DOCTOR_FIX_APPLIED=1` even on empty JSON. Legacy mutations `break` after first match. Tests do not execute D10 apply paths today.
- Config already has `recommended_tools.search_cli` (`enabled_by_user` null, `required_when_enabled: false`, floating `brew install search-cli`). Zero probe / `RT_COMPONENT_IDS` / SKILL D10 row.
- Registry `hooks/lib/recommended-tools-registry.sh` is id + display-name only today (no command/version pin). F6 requires it become the **authoritative, source-controlled** pin; never merge project-local `install_commands`.
- SKILL D10 table is a 2-column abridged list (no F4 schema). `D10-routes` SKILL text currently says WARN on no-consent; live runner PASSes `no_five_tool_consent`. Wave 2 must make SKILL match live PASS (PRD F2).
- Callers of `lib/sb-doctor/checks.sh` / `fix.sh`: `tests/scripts/test-silver-doctor.sh` only (asserts D10 must **not** source them). `core.sh` / `summary.sh` have no script callers found in this PLAN pass.
- Missing (expected): `probe-search_cli.sh`, `probe-omniroute.sh`, `scripts/install-omniroute-sb.sh`, `tests/scripts/test-router-doctor-report.sh`.
- Config `min_version` today: `rtk=0.42.0`, `leanctx=3.9.9`, **no** `context_mode.min_version`, **no** Graphify `min_version`. RTK probe uses `version_mismatch` as repairable; LeanCTX probe has no min_version FAIL path found in this PLAN pass.
- `/sb:doctor` is documented as the public alias; plugin command stub is `plugins/silver-bullet/commands/silver-doctor.md` only. Wave 2 must prove both names resolve to `scripts/sb-doctor.sh` / the same skill and forward `--fix` / `--dry-run` (AC 6). Documentation alone does not close.

## 4. Dependencies

### Files / modules

| Area | Files |
|---|---|
| Runner | `scripts/sb-doctor.sh` (`doctor_run_reconciler`, `doctor_apply_fixes`, `doctor_record_reconciler_d10`, severity→exit) |
| Reconciler | `scripts/reconcile-recommended-tools.sh` (`rt_run_component` dispatch + source list) |
| Allowlist / scopes | `scripts/lib/recommended-tools/common.sh` |
| Command pin | `hooks/lib/recommended-tools-registry.sh` |
| Probes | `scripts/lib/recommended-tools/probe-*.sh` (new `probe-search_cli.sh`); `vendor-doctor.sh`; `receipts.sh` |
| Pattern | `scripts/lib/recommended-tools/probe-alumnium.sh` (consent/registry only — **do not** copy `fu=1` on `!rt_host_supported`) |
| Skill | `skills/silver-doctor/SKILL.md` → sync via `scripts/sync-codex-package.sh`; command stubs via `scripts/generate-plugin-commands.sh` if doctor-facing command text changes |
| Product doc | `docs/SEARCH-CLI.md` (must stop advertising a floating brew install once the pin lands) |
| Tests | `tests/scripts/test-silver-doctor.sh`, `tests/scripts/test-reconcile-recommended-tools.sh` |
| Stale split | `scripts/lib/sb-doctor/checks.sh`, `fix.sh` (delete in Wave 2) |

### Ordering

1. Official docs consult + `docs_pin` for `search_cli` **before** probe/`--fix` code (PRD Official docs consult policy).
2. TDD: failing tests for new logic **before** product-code edits.
3. Registry pin + `RT_COMPONENT_IDS` + `rt_scope_includes_component packages` **before** `rt_run_component search_cli` (otherwise `--fix=packages` silently skips).
4. Close `--fix` swallow in the **same** wave as `search_cli` (Wave 1). `--fix=all` ordered-pass / `--fix=local` host-mutation fence is Wave 2.
5. SKILL F4 table for existing tools (`docs_pin` backfill) is Wave 2 (AC 1). Wave 1 adds the `search_cli` row so the canary is documented.
6. Delete stale `checks.sh`/`fix.sh` only after the caller scan in Wave 2. If a **non-D10** caller appears, switch to generate-from-runner (implementation finding, not a product fork).
7. After SKILL edits: `bash scripts/sync-codex-package.sh`. If doctor-facing command text changes: also `bash scripts/generate-plugin-commands.sh`.

### Rollback / compatibility

- Additive extra-tool: opted-out `search_cli` must remain PASS N/A on the default tree (this repo’s `enabled_by_user` is null).
- Do not change five-tool / `cross_tool` Cursor-only `rt_host_supported`.
- Do not put `search_cli` in `rt_any_five_tool_mutation_allowed`.
- `--fix` confirmation: plan-triggered. `SB_DOCTOR_ASSUME_YES=1` required in non-interactive tests **when a confirm-class mutation is planned**. Confirmation unobtainable → no writes for the whole invocation.
- Recovery from a bad `--fix` = receipt + re-run doctor (no automatic undo).
- Keep `RT_SKIP_VENDOR_DOCTOR=1` in unit tests; Wave 2 adds one hermetic/live path so skip cannot masquerade as Health.

### Unknowns that must be resolved during execute (not blockers for this PLAN)

- Exact versioned Homebrew formula / git ref for search-cli `docs_pin` (must come from version-matched official docs at implement time; current `docs/SEARCH-CLI.md` and project JSON are **floating** and are not a valid pin).
- Context Mode `min_version` value to write into config (consult CM official docs / in-repo `docs/STACK-OPTIMIZATION.md`; do not invent).
- How `/sb:doctor` is wired on each host (skill alias vs command stub vs `silver-bullet.md` public-alias table). Execute locates the existing alias mechanism and adds a **test**; do not invent a second runner.

## 5. TDD policy

- **Implementation logic requires TDD before code edits:** new probe states, N/A vs FAIL, `--fix` swallow/apply, confirmation gate, fail-closed install pin, min_version FAIL, vendor-skip ≠ Health, `--fix` fixtures, alias resolution, parity test, stale-loop canary.
- **Docs/config/infra-only** (SKILL table wording, `docs_pin` URLs, `docs/SEARCH-CLI.md` pin text, plugin command stub generation, deleting unused stale files after tests exist) may skip application TDD but still needs verification evidence (grep/assert in the two targeted test scripts, or a dedicated assertion that the SKILL table has F4 columns).
- Red tests land first in Wave 1 for `search_cli` + swallow, and first in Wave 2 for honesty/`--fix` proof, then product code turns them green.

## 6. Tasks (ordered waves)

### Wave 1 — `search_cli` canary + close `--fix` swallow (PRD Phase 1)

**Goal:** `search_cli` is a live D10 extra-tool on Cursor/Claude/Codex, and `--fix` no longer marks success on swallowed/empty/malformed/failed reconciler JSON.

**AC links:** 2, 3, 5 (search_cli + fail-closed pin + unknown-key groundwork), 8 (targeted tests), 11 (locked defaults that Wave 1 owns). Partial AC 1 (`search_cli` F4 row + Omni footnote).

#### 1.0 Official docs consult (before probe/`--fix`)

- Consult [search-cli](https://github.com/199-biotechnologies/search-cli) README/install at the **formula/version** SB will pin. Prefer GitHub markdown. Reject SPA curl-bash.
- Record `docs_pin` as `URL@ref`. Pin must match the versioned brew formula (not floating `brew install search-cli`).
- In-repo contract: `docs/SEARCH-CLI.md` must be updated to the same pin.
- **Health locked:** PATH **plus** non-secret `search --version` (or formula version). Provider-missing is WARN (`provider_missing`) via ready Health + warning evidence — not `ready` PASS and not `repairable` FAIL. Do not dump `search config` / API keys. Deep Research `deep`/`ultradeep` is not a D10 FAIL.

#### 1.1 Red tests (TDD)

Extend `tests/scripts/test-silver-doctor.sh` and `tests/scripts/test-reconcile-recommended-tools.sh` so the following fail until Wave 1 code lands:

| Case | Expected |
|---|---|
| Opted-out / absent `search_cli` key | PASS N/A `pending`/`disabled`; never FAIL; do not scaffold the key |
| Opted-in missing CLI on **cursor, claude, and codex** | FAIL `D10-search_cli` / `missing_cli` (not PASS N/A, not `fu=1`) |
| PATH without version | not Health PASS |
| Provider-missing | WARN `provider_missing`; no dumped key |
| `--dry-run` / plan | no writes |
| Empty / malformed / failed apply JSON | `DOCTOR_FIX_APPLIED=0`; nonzero; stderr kept; receipt not success |
| Tampered known-id `install_commands` (project JSON ≠ registry pin) | refuse execution |
| Installed older than pin | WARN `version_drift`; `--fix=packages` repairs to pin (hermetic fixture; CI uses `SB_DOCTOR_ASSUME_YES=1` when a confirm-class mutation is planned) |
| Installed newer than pin | WARN `version_drift`; `--fix` **must not downgrade**; WARN persists (exclude from converge-to-`ready`) |
| brew/OS unsupported | `unsupported_package_manager`; `DOCTOR_FIX_APPLIED=0`; WARN-class exit unless FAIL also exists |
| Confirmation unobtainable when confirm-class mutation planned | no writes; nonzero; receipt not-applied |
| Secrets | none in stdout, stderr, JSON, receipts; JSON stdout parseable |
| WARN-only tree | exit **zero**; FAIL tree exit **nonzero** |

`--fix=packages` tests must fail if `rt_scope_includes_component` omits `search_cli` from `packages`.

#### 1.2 Allowlist + registry pin

- Add `search_cli` to `RT_COMPONENT_IDS` in `scripts/lib/recommended-tools/common.sh`. **Do not** add it to `rt_any_five_tool_mutation_allowed`.
- `rt_scope_includes_component`: include `search_cli` in **`packages` only**. Do not add to `project` or `host`.
- Registry: add `search_cli` to `SB_RECOMMENDED_TOOL_IDS` + display name **and** the F6 command/version pin (versioned brew argv/digest). Registry is authoritative; **never** merge `.silver-bullet.json` `install_commands`.
- Keep `required_when_enabled: false`. Hook enforcement stays off; opted-in missing CLI is still D10 FAIL.
- Do not copy Alumnium Cursor-only `rt_host_supported` / `fu=1`.

**Assumption (logged):** adding `search_cli` to `SB_RECOMMENDED_TOOL_IDS` may surface in session-start / prompt-reminder copy. Execute must confirm `sb_recommended_tool_enforced()` still skips when `required_when_enabled` is false. Do not turn on hook FAIL for this key.

#### 1.3 Probe + repair + reconciler dispatch

Create `scripts/lib/recommended-tools/probe-search_cli.sh`:

- `rt_probe_search_cli` / `rt_repair_search_cli`.
- Consent: `disabled`/`pending`/absent → canonical pending/disabled (doctor PASS N/A). First-run new id with no prior state is `pending`, not an upgrade error.
- Opted-in on Cursor/Claude/Codex: require CLI on PATH **and** non-secret version. Missing CLI → `missing_cli` FAIL.
- Do **not** mark unsupported solely because `rt_host_supported` is false.
- `version_drift` WARN (older: packages-repairable to pin; newer: no downgrade).
- `provider_missing` WARN (Diagnosis text only).
- `unsupported_package_manager` when brew/OS cannot run the pin.
- Repair: registry-pinned packages install only. No provider-key writes.

Wire `scripts/reconcile-recommended-tools.sh`: `source probe-search_cli.sh` and `rt_run_component search_cli`.

Map doctor advisory evidence with the **general** rule (core Health ready + named warning evidence → WARN). Do not invent a per-tool bypass.

#### 1.4 Close `--fix` swallow (same wave; affects every tool)

In `scripts/sb-doctor.sh`:

1. Stop discarding reconciler stderr (`2>/dev/null`).
2. Stop `|| true` then marking applied.
3. Do not set `DOCTOR_FIX_APPLIED=1` when JSON is empty, malformed, or apply failed. Surface exit status, stderr, honest receipt (`receipts.sh`; no secrets).
4. `DOCTOR_FIX_APPLIED` is the result of **one invocation**, not an intra-invocation early-return (`[[ "$DOCTOR_FIX_APPLIED" -eq 1 ]] && return 0` at the start of `doctor_apply_fixes` currently prevents a honest second look in the same run).
5. `--dry-run` / reconciler `--mode plan` still writes nothing.
6. Confirmation gate: if the ordered pass **would execute** a confirm-class mutation (`packages` / network install) and confirmation is unobtainable (non-TTY without `SB_DOCTOR_ASSUME_YES=1`, or TTY decline/EOF/invalid) → **no writes** for the whole `--fix` invocation; nonzero; never hang. If the planned pass has no confirm-class mutation, do not prompt.
7. JSON stdout stays parseable (`SB_DOCTOR_FORMAT=json`).

Wave 1 does **not** yet have to close the legacy first-match `break` or the `--fix=local` host-mutation fence (Wave 2 / AC 4). Swallow + empty-JSON honesty is the Wave 1 bar (AC 3).

#### 1.5 SKILL (canary row)

- Add `search_cli` to the D10 coverage table using **F4 columns**: tool, class, Setup, Health, Diagnosis, `--fix` action, N/A rule, host support (Cursor+Claude+Codex), `docs_pin`.
- Health must not claim `command -v` alone.
- Add coverage-table **footnote**: Omni is “planned WS7, not D10 Graphify” — **not** an F4 schema row.
- Keep `/sb:doctor` described as the public alias (executable proof is Wave 2).

#### 1.6 Sync + Wave 1 verify

- `bash scripts/sync-codex-package.sh` after SKILL edits.
- `bash tests/scripts/test-silver-doctor.sh`
- `bash tests/scripts/test-reconcile-recommended-tools.sh`
- `bash scripts/sb-doctor.sh --dry-run` (default tree: no FAIL from `search_cli`; Graphify skew WARN expected and non-blocking).

**Expected files/areas:** `probe-search_cli.sh` (new); `common.sh`; `recommended-tools-registry.sh`; `reconcile-recommended-tools.sh`; `sb-doctor.sh`; `skills/silver-doctor/SKILL.md` (+ generated mirrors); `docs/SEARCH-CLI.md`; the two test scripts.

**Risks / rollback:** A wrong brew pin could make opted-in operators FAIL until packages apply. Default tree stays opted-out. If registry pin is omitted, tamper fixture cannot pass. Rollback = revert the extra-tool wiring; swallow fix should stay even if `search_cli` is reverted (it is a blast-radius bug on every tool).

---

### Wave 2 — remaining D10 honesty + `--fix` proof (PRD Phase 2)

**Goal:** Existing allowlist is honest (F4 `docs_pin`, vendor-skip, min_version, Graphify WARN, CONFIGURED ≠ LIVE), `--fix` is proveable on five-tool + `--fix=all` + local fence, `/sb:doctor` alias is tested, stale consent-only path is deleted (or generate-from-runner if a non-D10 caller appears), Session A ACs 1/4/6/9 close.

**AC links:** 1, 4, 5 (parity + `unknown_key`), 6, 7 (footnote only), 8, 9, 10, 11.

#### 2.0 Official docs consult (existing allowlist)

Before probe/`--fix` honesty edits, consult version-matched official docs per tool and record `docs_pin` (`URL@ref`):

| Tool | In-repo contract | Upstream starting point |
|---|---|---|
| graphify | `docs/GRAPHIFY.md`, `docs/code-intelligence-contract.md` | Graphify CLI/help for installed package. Skill vs package skew (0.9.35 vs 0.9.48 observed) is **expected WARN**; `--fix` none (operator `graphify install`) |
| agentmemory | `docs/AGENTMEMORY.md` | health URL / MCP docs for that version |
| rtk | `docs/RTK.md` | `rtk doctor` if non-interactive |
| context_mode | SKILL D10 row; `docs/STACK-OPTIMIZATION.md` | `CONTEXT_MODE_PLATFORM=cursor context-mode doctor` |
| leanctx | `docs/LEANCTX.md` | `lean-ctx doctor` if non-interactive; never `init --agent *` |
| alumnium | `docs/ALUMNIUM.md` | `alumnium doctor` if non-interactive; MCP `npx -y alumnium mcp` |
| cross_tool | `docs/code-intelligence-contract.md` | **SB-owned pin:** Silver Bullet commit/ref of that contract |

Reject SPA marketing pages as install-command sources.

#### 2.1 Red tests (TDD) then honesty probes

| Case | Expected |
|---|---|
| `min_version` below pin (RTK / CM / LeanCTX) | **FAIL**. Add a Context Mode `min_version` pin from docs consult if still absent. **Do not** add Graphify `min_version` |
| Graphify skill vs package skew | D10 **WARN**; PATH-only is not Health PASS; `--fix` does not clear it |
| Vendor-doctor skip (`RT_SKIP_VENDOR_DOCTOR=1`) | recorded `vendor_skip`; **not** Health evidence; remaining class checks decide PASS/FAIL; skip never PASSes the component alone |
| One hermetic/live vendor-doctor path | skip cannot masquerade as Health (keep skip in other unit tests) |
| Duplicate `leanctx` and `lean-ctx` MCP keys when opted in | D10 FAIL `D10-leanctx` / `duplicate_key`; D22 WARN label does not downgrade D10 |
| `cross_tool` `no_five_tool_consent` | `D10-routes` **PASS** (not PASS N/A, not WARN). SKILL text must match |
| Unsupported host `cross_tool` | WARN; must not recommend `--fix=host` (keep existing test) |
| MCP key present, session tools not proven | CONFIGURED, not Health PASS (`reload_required` stays non-green) |
| `--deep` Graphify stdio | WARN only |
| Health URL without proving opted-in instance (agentmemory) | **WARN** with identity evidence |
| Opted-in unknown JSON key | WARN `unknown_key` + doctor exit **nonzero**; other components not FAIL-poisoned |
| Unknown component id | PASS N/A reason `unsupported`; no installer; no `--fix` suggestion |
| Config↔allowlist↔SKILL parity (F-7-1) | every `.silver-bullet.json` `recommended_tools` key **and** derived `cross_tool` is in `RT_COMPONENT_IDS`, registry, `rt_run_component`, and SKILL D10 F4 table |

#### 2.2 `--fix` fixtures and composition

- **One five-tool fixture:** broken hook line or missing MCP key → `--fix` apply → re-probe `ready` → second apply idempotent (`changed=false` / no additional mutation).
- **`--fix=all`:** fixture with **two in-scope** coexisting failures converges in **one ordered pass** (reconciler, then matching legacy mutations, **no `break`**, no unbounded fixpoint). `DOCTOR_FIX_APPLIED` set at **end** of invocation.
- **`--fix=local`:** must **not** run D4 / D13 / D14 / D16 / D18 / D19 / D21.
- Blast-radius table in the PRD is the hard constraint (local vs host vs packages vs all).
- **Repair-dispatch:** every advertised coverage-table `--fix` action has a plan/dispatch test that the named scope/script is wired. One live five-tool fixture is not enough.

#### 2.3 `/sb:doctor` executable alias (AC 6)

- Locate the host alias mechanism (skill name / plugin command stub / public-alias table). Both `/sb:doctor` and `/silver:doctor` must resolve to `scripts/sb-doctor.sh` / the same skill and forward `--fix` / `--dry-run`.
- Add a test. If a command stub is missing, generate it via `scripts/generate-plugin-commands.sh` after SKILL/frontmatter alias text — **do not** implement a second doctor.

#### 2.4 Stale split: delete `checks.sh` + `fix.sh` (locked default)

1. Re-scan for non-D10 callers of `scripts/lib/sb-doctor/checks.sh` and `fix.sh`.
2. If none (PLAN pass found only `test-silver-doctor.sh` asserting they must not be used): **delete** both. Do **not** generate-from-runner.
3. If a non-D10 caller appears: switch to generate-from-runner rather than leaving a third doctor (implementation finding).
4. Strengthen tests (AC 9): live D10 must not use the consent-only PASS loop **and** a **canary fixture that only the stale loop could turn green stays non-green**.
5. Leave `core.sh` / `summary.sh` unless Wave 2 proves they exist only to serve the deleted split (then delete with the same canary coverage). Do not leave a second doctor-shaped surface.

#### 2.5 SKILL F4 coverage table (AC 1)

Replace the abridged 2-column D10 list with the F4 schema for:

`graphify`, `agentmemory`, `rtk`, `context_mode`, `leanctx`, `alumnium`, `search_cli`, derived `cross_tool` / `D10-routes`.

Every row has `docs_pin`. `cross_tool` pin is the SB mutex contract at a Silver Bullet commit/ref. Omni remains a **footnote**, not a row. Keep CONFIGURED ≠ LIVE wording.

Canonical evidence ids in Diagnosis column: `D10-<tool>`, `missing_cli`, `no_five_tool_consent`, `provider_missing`, `version_drift`, `vendor_skip`, `unsupported_package_manager`, `unknown_key`, `duplicate_key` (Omni `busy` / `provider_expired` only in the footnote as future ids).

#### 2.6 Sync + Wave 2 / Session A verify

- `bash scripts/sync-codex-package.sh`
- `bash scripts/generate-plugin-commands.sh` if doctor-facing command text / alias changed
- `bash tests/scripts/test-silver-doctor.sh`
- `bash tests/scripts/test-reconcile-recommended-tools.sh`
- `bash scripts/sb-doctor.sh --dry-run` (green default = no FAIL; Graphify skew WARN allowed; exit 0)

**Expected files/areas:** existing `probe-*.sh` (honesty), `vendor-doctor.sh`, `sb-doctor.sh` (ordered pass / local fence / alias), SKILL + generated mirrors, possibly `.silver-bullet.json` Context Mode `min_version` pin, delete `scripts/lib/sb-doctor/checks.sh` + `fix.sh`, the two test scripts.

**Risks / rollback:** `--fix=all` without `break` could apply more host mutations than operators expect — blast-radius tests and `--fix=local` fence are the control. Deleting `checks.sh` is safe only after the caller scan. min_version FAIL can turn currently-green trees red if a machine is below pin — that is the intended honesty; default CI fixtures must use versions that match the pin or skip with documented N/A.

## 7. Acceptance criteria coverage

| AC | Wave / task | Status in this plan |
|---|---|---|
| 1 Coverage table F4 + `search_cli` + `cross_tool` + `docs_pin`; Omni footnote not row | W1.5 (search_cli row + Omni footnote); W2.5 (full table) | In |
| 2 `search_cli` live extra-tool (registry + probe + N/A vs FAIL on Cursor/Claude/Codex + `--fix=packages` + packages scope) | W1.1–1.3 | In |
| 3 `--fix` no swallow; dry-run no writes; secrets tested | W1.1, W1.4 | In |
| 4 Five-tool `--fix` fixture + repair-dispatch + `--fix=all` two in-scope + `--fix=local` fence | W2.2 | In |
| 5 Unknown tools fail closed; tamper refuse; `unknown_key` WARN nonzero; F-7-1 parity | W1.1–1.2 (tamper + pin); W2.1 (parity + unknown_key) | In |
| 6 `/sb:doctor` alias tested, same runner, forwards `--fix`/`--dry-run` | W2.3 | In |
| 7 Omni | Deferred; W1.5 / W2.5 footnote only | **Out of implementation; in as footnote** |
| 8 Targeted tests green + SKILL sync | W1.6, W2.6 | In |
| 9 Stale consent-only path unused + positive canary non-green | W2.4 | In |
| 10 No freeze-file edits, no branch switch, no commit unless asked | Process constraint on execute | In (constraint) |
| 11 Session A locked defaults | Spread across W1–W2; listed in §9 | In |
| Phase 4 plugin interface | — | **Out of Session A close** |

## 8. Verification plan (`/silver:verify` can run as written)

Do not invent extra criteria. Do not require `bash tests/run-all-tests.sh` for phase-done.

### Targeted (required)

```bash
bash tests/scripts/test-silver-doctor.sh
bash tests/scripts/test-reconcile-recommended-tools.sh
```

Both must be green.

### After SKILL edits

```bash
bash scripts/sync-codex-package.sh
# if doctor-facing command / alias text changed:
bash scripts/generate-plugin-commands.sh
```

Do not hand-edit generated mirrors under `agents/` or `plugins/silver-bullet/skill-source/`.

### Manual / script smoke (required evidence, not a full suite)

```bash
bash scripts/sb-doctor.sh --dry-run
```

Expect: no FAIL on the default opted-out `search_cli` / Alumnium tree; Graphify skill/package skew may WARN; process exit **zero** unless FAIL or `unknown_key`.

### Phase 3 only (not this plan)

```bash
bash tests/scripts/test-router-doctor-report.sh
```

Not in-tree; do not fail Session A on its absence.

### Verify checklist (falsifiable)

1. SKILL D10 table has F4 columns for every current `recommended_tools` key including `search_cli`, plus `cross_tool` / `D10-routes`, each with `docs_pin`. Omni is a footnote, not a row.
2. `probe-search_cli.sh` exists; reconciler sources it and `rt_run_component search_cli`; `rt_scope_includes_component` includes `search_cli` in `packages` only.
3. Opted-in missing CLI FAILs on cursor, claude, and codex fixtures.
4. `sb-doctor.sh` does not contain `2>/dev/null || true` around reconciler apply then `DOCTOR_FIX_APPLIED=1`. Empty JSON does not mark applied.
5. At least one five-tool `--fix` fixture + `--fix=all` two-failure fixture + `--fix=local` does not run D4/D13/D14/D16/D18/D19/D21.
6. `/sb:doctor` alias test exists and passes.
7. `scripts/lib/sb-doctor/checks.sh` and `fix.sh` are gone **or** generate-from-runner with evidence of a non-D10 caller; canary fixture stays non-green.
8. No edits to `.planning/router_subagent_surfaces_85bf9f09.plan.md`. No git branch switch. No commit unless the human asked.

## 9. Assumptions (logged)

1. Planning mode is **Standard**. This is doctor/reconciler coverage, not a new-product walking skeleton.
2. Phase folder `106-doctor-opt-in-coverage-session-a` continues the numeric catalog after `105-aui-master-loop-and-autonomous-progress`. One `PLAN.md` (not `{phase}-NN-PLAN.md` splits) because clarify locked **one plan covering PRD phases 1–2**.
3. GSD STATE/ROADMAP stay on v0.39.3. This workstream does not invent a new product milestone.
4. `required_when_enabled: false` stays. Adding `search_cli` to `SB_RECOMMENDED_TOOL_IDS` is for F-7-1 parity; hook enforcement must remain skipped.
5. Wave 1 `--fix` scope for `search_cli` is `packages` only (Homebrew pin on macOS).
6. Stale `checks.sh`/`fix.sh` → **delete** in Wave 2 unless a non-D10 caller appears (then generate-from-runner).
7. `core.sh`/`summary.sh` are not in the locked delete set; Wave 2 may delete them only if they solely serve the stale split.
8. Phase 3 Omni stays deferred; `scripts/install-omniroute-sb.sh` is absent.
9. Graphify MCP was down during PLAN; Graphify **CLI** was used (`query`, `path` doctor→checks = no directed path). Skill/package skew WARN 0.9.35 vs 0.9.48 is expected.
10. Implementers must consult version-matched official docs **before** writing probe/`--fix` (not this PLAN’s floating SEARCH-CLI brew line).
11. No commit, no branch switch, no `SetActiveBranch` from execute unless a later human asks.

## 10. Unresolved questions (non-blocking)

None that block `/silver:execute`. Revisit only if:

- A non-D10 caller of `checks.sh`/`fix.sh` appears in Wave 2 (switch to generate-from-runner).
- `scripts/install-omniroute-sb.sh` lands before Wave 2 closes (then a **follow-up plan** can take Phase 3; do not stretch this PLAN).
- Session-start copy regresses when `search_cli` joins `SB_RECOMMENDED_TOOL_IDS` (keep enforcement off; adjust reminder copy if needed, do not FAIL opted-out trees).

No `decision_class: blocking` question for the user.

## 11. Process constraints for execute

- Stay on the current git branch. No checkout/switch. No `SetActiveBranch`.
- No Fast. Nested Tasks: `cursor-grok-4.6-high` only (not Grok 4.6 Extra High/XHigh unless the human names it).
- Graphify query/path/explain before codebase exploration; `graphify update .` after code edits.
- agentmemory `memory_save` after meaningful chunks.
- Native Read before Write/Edit of durable files. Never paste compression markers into edits.
- Do not edit `.planning/router_subagent_surfaces_85bf9f09.plan.md`.
- Do not start Omni or a plugin interface while `search_cli` is still invisible to D10 (Wave 1 first).

## 12. Next skill

**`/silver:execute`** — implement Wave 1 then Wave 2 against this PLAN. Do not start execute from the PLAN worker.
