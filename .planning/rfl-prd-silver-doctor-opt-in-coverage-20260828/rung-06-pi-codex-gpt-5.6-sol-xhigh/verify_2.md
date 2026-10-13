# verify_2 — rung 6 Pi Codex GPT-5.6 Sol Extra High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high` / `cursor-grok-4.5-high`) — independent second verify  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs re-read:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md`, [`CHARTER.md`](../CHARTER.md), live PRD (not a copy of `verify_1.md`)  
**Branch:** `main` @ `e2606b92` (no switch)

## Overall: **PASS**

Independent re-hash and re-read: every F-6-1…F-6-8 ACCEPT from Policy C / APPLY is present in the live PRD and not undone. SHA matches expected. Charter signals green. FAIL ids: *(none)*.

## SHA-256

| Source | Digest |
|--------|--------|
| Live PRD (`hashlib.sha256` via Context Mode; 62329 bytes) | `67b7fb32d64e6defc6db4b18d41d6ff2e6df9085562c472c352275a783fa73d8` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `67b7fb32d64e6defc6db4b18d41d6ff2e6df9085562c472c352275a783fa73d8` |
| Match | **yes** |

## Charter signals (orchestrator)

Ran from repo root (Context Mode `ctx_execute` re-implementation of CHARTER `rg` — shell `rg` returned empty under lean-ctx allowlist this session):

1. `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` → **exists**
2. `Session A|Session B|search_cli|MUST NOT|generic installer|omniroute|WS7|sb-doctor.sh|CONFIGURED|fail.closed|N/A` → **hits present** (**153** lines; Session A 35 / Session B 9 / search_cli 46 / MUST NOT 2 / generic installer 2 / omniroute 14 / WS7 19 / sb-doctor.sh 18 / CONFIGURED 6 / fail-closed 7 / N/A 37)
3. `four surfaces|Setup|Health|Diagnosis|--fix` → **hits present** (**129** lines; four surfaces 2 / Setup 12 / Health 36 / Diagnosis 14 / `--fix` 96)

## Per-finding table (independent quotes)

| ID | Sev | Verdict | Live PRD evidence (own line quotes) |
|----|-----|---------|-------------------------------------|
| F-6-1 | HIGH | **ACCEPT** | Phase 3 **L435**: registry + `RT_COMPONENT_IDS` / extra-tool + `rt_run_component` + scopes + SKILL + N/A-vs-FAIL; “JSON key plus uncalled `probe-omniroute.sh` is not Phase 3 done.” AC7 **L534** / prompt **L602–603**: not an inert JSON key. |
| F-6-2 | MED | **ACCEPT** | Fix table **L314** / live blast **L159** / Phase 2 **L421** / test **L463** / locked **L538** / prompt **L597–598** / **L638**: `--fix=all` **one invocation** converges all eligible failures; close live first-match `break`; two coexisting failures fixture. |
| F-6-3 | MED | **ACCEPT** | Current-system **L104** / F4 N/A **L235** / Phase 2 **L419** / test **L466** / hermetic **L478** / locked **L538**: vendor-doctor skip is **not** Health evidence; remaining class checks decide; skip never PASSes alone. |
| F-6-4 | MED | **ACCEPT** | Phase 2 **L422** / test **L464** / AC6 **L533** / prompt **L598–599**: `/sb:doctor` same runner/skill as `/silver:doctor`; `--fix` / `--dry-run` forwarded (not docs-only). |
| F-6-5 | LOW | **ACCEPT** | F5 **L248** / repair list **L327** / test **L465** / locked **L538** / prompt **L640**: TTY decline/EOF — confirm guarded scopes **before any writes**; no writes; nonzero; receipt not-applied (no partial apply). |
| F-6-6 | LOW | **ACCEPT** | Host matrix **L141** / test **L460** / prompt **L589–590**: agent-host Cursor/Claude/Codex stays; `--fix=packages` is Homebrew pin on macOS; missing brew / unsupported OS → FAIL missing CLI, skip packages with Diagnosis (no invented apt/choco). |
| F-6-7 | MED | **ACCEPT** | Repair list **L329** / Phase 3 **L437** / tests **L467–468** / AC7 **L534** / prompt **L605–606**: busy → WARN no restart; provider expired → WARN, OAuth manual; restart only a **dead** daemon. |
| F-6-8 | MED | **ACCEPT** | Canary **L149** / test **L460** / **L462** / locked **L538** / prompt **L586–587**: versioned formula pin in `docs_pin` / registry; installed ≠ pin is WARN (command pin ≠ artifact pin); not floating latest. |

## Regression hunt (APPLY failure modes)

| Hunt | Result |
|------|--------|
| Phase 3 Omni as inert JSON key / no reconciler registration | **fixed** L435 / L534 / L602–603 |
| `--fix=all` still first-match break only (no multi-failure convergence) | **fixed** L159 / L314 / L421 / L463 / L538 |
| Vendor-doctor skip treated as Health PASS | **fixed** L104 / L235 / L419 / L466 |
| `/sb:doctor` docs-only alias | **fixed** L422 / L464 / L533 |
| TTY decline/EOF partial apply | **fixed** L248 / L327 / L465 |
| Brew repair on non-macOS / missing brew suggested | **fixed** L141 / L460 / L589–590 |
| Busy/expired → restart or automated OAuth | **fixed** L329 / L437 / L467–468 |
| Floating `brew install search-cli` / silent pin drift | **fixed** L149 / L460 / L462 / L586–587 |
| SHA drift vs APPLY / POLICY-C `apply_sha` | **none** — match `67b7fb32…a73d8` |
| Prior rung locks (secrets, assume-yes, WS6 gate, registry-pinned `install_commands`, search_cli hosts) | **intact** (L538 bundle; not undone by F-6 edits) |

## Residuals (do not undo ACCEPT)

1. **L159 still describes live first-match `break`** as current behavior while locking that Session A must close it — intentional before/after contrast; F-6-2 ACCEPT requires the close, not deletion of the live description.
2. **Freeze Omni still names YAML `omni-agent-doctor`** alongside locked JSON key `omniroute` — both required by prior locks; F-6-1/7 do not remove that pairing.

## Graphify / tools note

- `graphify query` / `explain` run first (CLI; surfaced PRD node, CHARTER, ISSUE-LEDGER, `sb-doctor.sh`).
- Context Mode `ctx_execute` for hashlib SHA + line extraction + charter signal counts; agentmemory `memory_save` for this verify_2 pass.
- Scope lock honored: only this `verify_2.md` written; PRD / freeze / doctor code untouched. Independent of verify_1.

## Verdict rule

PASS only if every ACCEPT present and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
