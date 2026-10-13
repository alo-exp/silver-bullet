# verify_1 — rung 5 Pi Codex GPT-5.6 Sol High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high`)  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md` (F-5-1…F-5-10 all ACCEPT-applied, I-34…I-43)

## Overall: **PASS**

Every F-5-1…F-5-10 ACCEPT text is present in the live PRD. SHA matches APPLY / expected digest / POLICY-C `apply_sha`. Charter signals OK. No residual undoes an ACCEPT.

## SHA-256

| | Digest |
|--|--------|
| Live PRD | `b3c5327ef93e457d5c0b3501305ed2bbe5a1fdc309616178427fbeb85b3bd6d7` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `b3c5327ef93e457d5c0b3501305ed2bbe5a1fdc309616178427fbeb85b3bd6d7` |
| Match | **yes** |

## Per-finding table

| ID | Sev | Verdict | Evidence (heading / file:line + excerpt) |
|----|-----|---------|------------------------------------------|
| F-5-1 | HIGH | **PASS** | L58 / F6 L251 / F1 Setup L201 / test L457 / prompt L620–621: known component id ≠ command allowlist; registry-pinned `install_commands` (`scripts/install-*-sb.sh` or exact argv/digest); tampered-known-key fixture refuses. |
| F-5-2 | HIGH | **PASS** | Goals L57 / F5 L246 / MUST NOT L496 / AC3 L519 / test L463 / prompt L617–618: no secrets in stdout, stderr, JSON, receipts; JSON stdout stays parseable. |
| F-5-3 | MED | **PASS** | Phase 2 L419–420 / AC4 L520 / test L464: repair-dispatch/plan for every advertised `--fix`; one live five-tool fixture is not enough. |
| F-5-4 | MED | **PASS** | L103 / test L460 / locked default L538: provider-missing → ready Health + warning evidence → WARN (not `ready` PASS, not `repairable` FAIL). |
| F-5-5 | MED | **PASS** | F5 L247 / repair list L326 / test L472 / locked default L539 / prompt L616–617: non-TTY without `SB_DOCTOR_ASSUME_YES=1` skips packages/daemon, nonzero, never hang. |
| F-5-6 | MED | **PASS** | F5 L243 / repair list L324 / test L462 / goals L57 / AC3 L519: failed/malformed apply → `DOCTOR_FIX_APPLIED=0`, not applied, nonzero, stderr kept, honest receipt. |
| F-5-7 | HIGH | **PASS** | F7 L263 / Phase 3 Gate L429 / AC7 L523 / AC11 L527 / prompt L589–590: Phase 3 gated on WS6 `install-omniroute-sb.sh`; else defer, no partial Omni `--fix` install. |
| F-5-8 | MED | **PASS** | F4 host support L235 / NF1 L271 / Phase 3 L433 / prompt L592: Omni requires current doctor host CLI only; OpenCode inspects `opencode`; `pi` is Omni CLI identity not five-tool `RT_VALID_HOST`; prefer `cursor-agent`. |
| F-5-9 | MED | **PASS** | AC1 L517 / AC7 L523 / open Q6 L545 / prompt L590–591: deferred Omni = coverage-table footnote (“planned WS7”), **not** an F4 schema row. |
| F-5-10 | LOW | **PASS** | AC1 L517 / docs table L352 / F4 `docs_pin` L236 + backfill L423: `cross_tool` `docs_pin` = SB mutex contract at a Silver Bullet commit/ref. |

## Charter verification signals

From repo root (Python line scan of live PRD; `shasum -a 256` for digest):

| Check | Result |
|-------|--------|
| `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` | EXISTS |
| `rg` Session A\|Session B\|search_cli\|MUST NOT\|generic installer\|omniroute\|WS7\|sb-doctor.sh\|CONFIGURED\|fail.closed\|N/A | Hits present (Session A/B; search_cli; MUST NOT; generic installer; omniroute; WS7; sb-doctor.sh; CONFIGURED≠LIVE; fail-closed / fail closed; N/A) — ~148 matching lines |
| `rg` four surfaces\|Setup\|Health\|Diagnosis\|--fix | Hits present (four surfaces; Setup/Health/Diagnosis/`--fix` throughout) — ~113 matching lines |

## Spot-checks

| Check | Result |
|-------|--------|
| SHA live == APPLY / POLICY-C `apply_sha` | yes (`b3c5327e…bd6d7`) |
| Known-id install_commands registry-pinned + tampered refuse | L58, L201, L251, L457, L521, L620–621 |
| Secrets cover stdout/stderr/JSON/receipts + parseable JSON | L57, L246, L463, L519 |
| Every-`--fix` repair-dispatch + one five-tool fixture | L420, L464, L520 |
| Provider-missing WARN mapping | L103, L460, L538 |
| Non-TTY skip/nonzero/no hang | L247, L326, L472, L539 |
| Failed/malformed apply observation | L243, L324, L462 |
| Phase 3 WS6 installer gate | L263, L429, L527 |
| Omni current-host CLI matrix | L235, L271, L433, L592 |
| Deferred Omni footnote not F4 row | L517, L523, L545, L591 |
| `cross_tool` docs_pin = SB commit/ref | L352, L517 |
| Prior rung locks (search_cli hosts, packages scope, assume-yes name) | Intact (not undone by F-5 edits) |

## Residuals (do not undo ACCEPT)

1. **L103 / L104 “N/A” in messaging** — result states remain PASS / WARN as locked; gloss text may still contain the substring “N/A”.
2. **Freeze Omni still names YAML `omni-agent-doctor`** alongside locked JSON key `omniroute` — both required by prior locks; F-5-7/9 do not remove that pairing.
3. **Shell `rg` via lean-ctx allowlist returned empty** in this verify session; charter presence was confirmed by reading the live PRD and Python line scan. Digest confirmed with `shasum -a 256`.

## Verdict rule

PASS only if every ACCEPT present and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
