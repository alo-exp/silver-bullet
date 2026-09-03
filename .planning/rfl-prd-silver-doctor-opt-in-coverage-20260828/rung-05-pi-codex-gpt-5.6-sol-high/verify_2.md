# verify_2 — rung 5 Pi Codex GPT-5.6 Sol High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high` / `cursor-grok-4.5-high`) — independent second verify  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs re-read:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md`, [`CHARTER.md`](../CHARTER.md), live PRD (not a copy of `verify_1.md`)  
**Branch:** `main` @ `2562d11c` (no switch)

## Overall: **PASS**

Independent re-check: every F-5-1…F-5-10 ACCEPT from Policy C / APPLY is present in the live PRD and not undone. SHA matches expected. Charter `rg` signals green. FAIL ids: *(none)*.

## SHA-256

| Source | Digest |
|--------|--------|
| Live PRD (`hashlib.sha256` + `shasum -a 256`) | `b3c5327ef93e457d5c0b3501305ed2bbe5a1fdc309616178427fbeb85b3bd6d7` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `b3c5327ef93e457d5c0b3501305ed2bbe5a1fdc309616178427fbeb85b3bd6d7` |
| Match | **yes** |

## Charter signals (orchestrator)

Ran from repo root:

1. `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` → **exists**
2. `rg … Session A|Session B|search_cli|MUST NOT|generic installer|omniroute|WS7|sb-doctor.sh|CONFIGURED|fail.closed|N/A` → **hits present** (148 lines; Session A/B, `search_cli`, MUST NOT / generic installer, omniroute, WS7, `sb-doctor.sh`, CONFIGURED, fail-closed / N/A)
3. `rg … four surfaces|Setup|Health|Diagnosis|--fix` → **hits present** (113 lines; four-surface Omni, Setup/Health/Diagnosis/`--fix`)

## Per-finding table (independent quotes)

| ID | Sev | Verdict | Live PRD evidence (own line quotes) |
|----|-----|---------|-------------------------------------|
| F-5-1 | HIGH | **ACCEPT** | **L58**: known component id ≠ command allowlist; registry pin `scripts/install-*-sb.sh` or exact argv/digest; tampered known-key must not execute. Also **L201** Setup, **L251** F6, test **L457**, AC **L521**/**L527**, prompt **L620–621**. |
| F-5-2 | HIGH | **ACCEPT** | **L57** / F5 **L246** / MUST NOT **L496** / AC3 **L519** / test **L463** / prompt **L617–618**: no secrets in stdout, stderr, JSON, receipts; JSON stdout stays parseable. |
| F-5-3 | MED | **ACCEPT** | Phase 2 **L420** repair-dispatch for every advertised `--fix`; one live five-tool fixture not enough. AC4 **L520**, test **L464**. |
| F-5-4 | MED | **ACCEPT** | **L103** / test **L460** / locked default **L538**: provider-missing → ready Health + warning evidence → WARN (not `ready` PASS, not `repairable` FAIL). |
| F-5-5 | MED | **ACCEPT** | F5 **L247** / repair list **L326** / test **L472** / locked default **L539** / prompt **L616–617**: non-TTY without `SB_DOCTOR_ASSUME_YES=1` skips packages/network/daemon, nonzero, never hang. |
| F-5-6 | MED | **ACCEPT** | F5 **L243** / repair list **L324** / test **L462** / goals **L57** / AC3 **L519**: failed/malformed apply → `DOCTOR_FIX_APPLIED=0`, not applied, nonzero, stderr kept, honest receipt. |
| F-5-7 | HIGH | **ACCEPT** | F7 **L263** / Phase 3 Gate **L429** / AC7 **L523** / AC11 **L527** / prompt **L589–590**: Phase 3 gated on WS6 `install-omniroute-sb.sh`; else defer, no partial Omni `--fix` install. |
| F-5-8 | MED | **ACCEPT** | F4 host support **L235** / NF1 **L271** / Phase 3 **L433** / prompt **L592**: Omni requires current doctor host CLI only; OpenCode inspects `opencode`; `pi` is Omni CLI identity not five-tool `RT_VALID_HOST`; prefer `cursor-agent`. |
| F-5-9 | MED | **ACCEPT** | AC1 **L517** / AC7 **L523** / open Q6 **L545** / prompt **L590–591**: deferred Omni = coverage-table footnote (“planned WS7”), **not** an F4 schema row. |
| F-5-10 | LOW | **ACCEPT** | AC1 **L517** / docs table **L352** / F4 `docs_pin` **L236** + backfill **L423**: `cross_tool` `docs_pin` = SB mutex contract at a Silver Bullet commit/ref. |

## Regression hunt (APPLY failure modes)

| Hunt | Result |
|------|--------|
| Known-id `install_commands` treated as free executable / no tampered refuse | **fixed** L58 / L201 / L251 / L457 / L620–621 |
| Secrets only on stdout (stderr/receipts omitted) | **fixed** L57 / L246 / L463 / L496 / L519 |
| Only one five-tool `--fix` fixture; no per-action dispatch | **fixed** L420 / L464 / L520 |
| Provider-missing still `ready` PASS or `repairable` FAIL | **fixed** L103 / L460 / L538 → WARN |
| Non-TTY without assume-yes hangs or applies packages/daemon | **fixed** L247 / L326 / L472 / L539 |
| Failed/malformed apply marked success / swallows stderr | **fixed** L243 / L324 / L462 |
| Phase 3 Omni install without WS6 installer / partial `--fix` | **fixed** L263 / L429 / L527 |
| Omni Setup requires all five CLIs / wrong `opencode`/`pi` identity | **fixed** L235 / L271 / L433 / L592 |
| Deferred Omni as F4 schema row (or missing footnote) | **fixed** L517 / L523 / L545 / L591 |
| `cross_tool` `docs_pin` as upstream package version | **fixed** L352 / L517 |
| SHA drift vs APPLY | **none** — match `b3c5327e…bd6d7` |
| Prior rung locks (`search_cli` hosts, packages scope, assume-yes name) | **intact** (not undone by F-5 edits) |

## Residuals (do not undo ACCEPT)

1. **L103 / L104 “N/A” in messaging** — result states remain PASS / WARN as locked; gloss text may still contain the substring “N/A”.
2. **Freeze Omni still names YAML `omni-agent-doctor`** alongside locked JSON key `omniroute` — both required by prior locks; F-5-7/9 do not remove that pairing.
3. Current-system allowlist / planned Omni gaps remain correctly documented as *today’s* tree; they are Session A work, not regressions of the ACCEPT locks.

## Graphify / tools note

- `graphify query "silver doctor opt-in PRD F-5 install_commands omniroute"` run first (CLI; surfaced PRD, `sb-doctor.sh`, OmniRoute opt-in).
- Context Mode `ctx_execute` / `ctx_execute_file` for hashlib SHA + line extraction; native Read before citing; Shell for `shasum` / charter `rg`.
- agentmemory `memory_save` for this verify_2 pass.
- Scope lock honored: only this `verify_2.md` written; PRD / freeze / doctor code untouched. Independent of verify_1.
