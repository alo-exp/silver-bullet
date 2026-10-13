# verify_2 — rung 7 Pi Claude Opus 5 High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high` / `cursor-grok-4.5-high`) — independent second verify  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs re-read:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md`, [`CHARTER.md`](../CHARTER.md), live PRD (not a copy of `verify_1.md`)  
**Branch:** `main` @ `eb2e6e46` (no switch)

## Overall: **PASS**

Independent re-hash and re-read: every F-7-1…F-7-13 ACCEPT from Policy C / APPLY is present in the live PRD and not undone. SHA matches expected. Charter signals green. FAIL ids: *(none)*.

## SHA-256

| Source | Digest |
|--------|--------|
| Live PRD (`crypto.createHash('sha256')` via Context Mode; 68685 bytes) | `e5cf0853236d005cb74860d95cd0c8082409f30ffe70427f6c6d55ad52b7f5ef` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `e5cf0853236d005cb74860d95cd0c8082409f30ffe70427f6c6d55ad52b7f5ef` |
| Match | **yes** |

## Charter signals (orchestrator)

Ran from repo root (Context Mode `ctx_execute` re-implementation of CHARTER `rg`):

1. `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` → **exists**
2. `Session A|Session B|search_cli|MUST NOT|generic installer|omniroute|WS7|sb-doctor.sh|CONFIGURED|fail.closed|N/A` → **hits present** (**157** lines; Session A 36 / Session B 9 / search_cli 47 / MUST NOT 2 / generic installer 2 / omniroute 17 / WS7 19 / sb-doctor.sh 18 / CONFIGURED 6 / fail-closed 9 / N/A 40)
3. `four surfaces|Setup|Health|Diagnosis|--fix` → **hits present** (**143** lines; four surfaces 2 / Setup 12 / Health 38 / Diagnosis 15 / `--fix` 107)

## Per-finding table (independent quotes)

| ID | Sev | Verdict | Live PRD evidence (own line quotes) |
|----|-----|---------|-------------------------------------|
| F-7-1 | HIGH | **ACCEPT** | Canary **L143**: enumeration/parity test — every `.silver-bullet.json` `recommended_tools` key **and** derived `cross_tool` (plus `omniroute` when Phase 3 lands) in `RT_COMPONENT_IDS` / extra-tool, registry, `rt_run_component`, SKILL D10. Test plan **L499** / AC **L554**: Config↔allowlist↔SKILL parity (+ `omniroute` Phase 3). Phase 3 **L453**: same registration bar. |
| F-7-2 | HIGH | **ACCEPT** | Blast table **L327–L335**: D4 / D13–D19 / D21 → `--fix=host` (or `all`); D20 export scaffold → `--fix=local`; D20 mutex clear → `--fix=host`; `--fix=local` must not run host mutations. Live close **L159** / Phase 2 **L439** / test **L482**: `--fix=local` never / must not run D4 / D13–D19 / D21. |
| F-7-3 | MED | **ACCEPT** | Current-system **L103**: advisory rule **core Health ready + named warning evidence** → WARN; locked WARNs listed (provider-missing, version≠docs_pin, Graphify skew, Omni busy, provider expired). Test **L490**: provider-missing = ready Health + warning evidence. |
| F-7-4 | MED | **ACCEPT** | Repair list **L345** / test **L484** / locked **L560** / prompt **L572**: Confirmation unobtainable (non-TTY without `SB_DOCTOR_ASSUME_YES=1` **or** TTY decline/EOF) → **no writes** for whole `--fix`; nonzero; receipt not-applied. |
| F-7-5 | MED | **ACCEPT** | Evidence table **L254** / test **L497** / AC **L554** / prompt **L667**: opted-in unknown JSON key → WARN `unknown_key` + nonzero; no installer; other components not FAIL-poisoned. |
| F-7-6 | MED | **ACCEPT** | Fail-closed **L268**: pin file [`hooks/lib/recommended-tools-registry.sh`](../../../hooks/lib/recommended-tools-registry.sh) is authoritative source-controlled command/version pin; **never** merged with project `.silver-bullet.json`. Locked **L560** / prompt **L665**. |
| F-7-7 | MED | **ACCEPT** | Canary **L147**: Absent key ≡ PASS N/A `pending`; do not scaffold; new `RT_COMPONENT_IDS` id first-run `pending`. Test **L498** / locked **L560** / prompt **L666**. |
| F-7-8 | MED | **ACCEPT** | NF4 **L308–L310** / Sync **L520** / AC 8 **L557**: `generate-plugin-commands.sh` when doctor-facing SKILL/command text changes; does not require full `run-all-tests.sh`. |
| F-7-9 | LOW | **ACCEPT** | Phase 2 **L436** / tests **L503–L504** / locked **L560**: RTK/CM/LeanCTX `min_version` below pin → **FAIL**; Graphify skill vs package skew → **WARN**; Health URL without instance identity → **WARN**. |
| F-7-10 | LOW | **ACCEPT** | F5 **L260** / blast **L330** / Phase 2 **L439** / test **L481** / prompt **L663–L664**: one ordered pass; `DOCTOR_FIX_APPLIED` at **end** of invocation; no unbounded fixpoint. |
| F-7-11 | LOW | **ACCEPT** | Canonical table **L241–L254**: `missing_cli`, `provider_missing`, `version_drift`, `vendor_skip`, `unsupported_package_manager`, `busy`, `provider_expired`, `unknown_key`, plus `no_five_tool_consent` (**L247**). |
| F-7-12 | NIT | **ACCEPT** | Repo-root links use `../` (59 relative `](../` hits; 0 bare `hooks|scripts|…` link style). **L24** / **L126** / **L427**: `probe-search_cli.sh` planned, not linked as existing. **L359**: no live link to missing repo-root `docs/TROUBLESHOOTING.md` (upstream OmniRoute URL only). |
| F-7-13 | NIT | **ACCEPT** | Test-plan preamble **L470**: rows tagged **per-tool** vs **global**; global not multiplied per tool. Table **L474+** uses Scope column. |

## Regression hunt (APPLY failure modes)

| Hunt | Result |
|------|--------|
| Config↔allowlist↔SKILL parity never required | **fixed** L143 / L499 / L554 |
| `--fix` blast without D*/scope map; local runs host | **fixed** L327–L335 / L159 / L439 / L482 |
| Locked WARNs without ready+warning path | **fixed** L103 / L490 |
| Non-TTY vs TTY-decline partial writes | **fixed** L345 / L484 / L560 |
| Opted-in unknown key silently green | **fixed** L254 / L497 / L554 |
| Registry not a single pin file / merge from project JSON | **fixed** L268 / L560 |
| Absent key / first-run pending undefined | **fixed** L147 / L498 |
| AC 8 omits `generate-plugin-commands.sh` | **fixed** L310 / L520 / L557 |
| min_version / Graphify / Health URL assertability | **fixed** L436 / L503–L504 |
| `DOCTOR_FIX_APPLIED` early-return vs one-pass | **fixed** L260 / L439 / L481 |
| Evidence-id vocabulary missing | **fixed** L241–L254 |
| Dead `.planning/` links / missing TROUBLESHOOTING / probe as live | **fixed** L24 / L359; `../` links |
| Test-plan per-tool vs global untagged | **fixed** L470+ |
| SHA drift vs APPLY | **none** — match `e5cf0853…b7f5ef` |
| Prior I-1…I-51 locks (secrets, assume-yes, WS6 gate, registry pin, search_cli hosts, Omni key, vendor skip) | **intact** (L560 bundle; not undone by F-7 edits) |

## Residuals (do not undo ACCEPT)

1. **L159** still narrates live first-match `break` while locking Session A must close it — intentional before/after; F-7-2/F-7-10 require the close + scope map, not deletion of the live description.
2. **`probe-search_cli.sh` / Omni TROUBLESHOOTING** named as planned or upstream — F-7-12 ACCEPT requires no live link treating missing repo paths as existing; satisfied.
3. Freeze Omni still pairs YAML `omni-agent-doctor` with locked JSON key `omniroute` — prior lock; F-7 edits do not remove that pairing.

## Graphify / tools note

- `graphify query "silver doctor PRD F-7-1 parity --fix local confirmation unknown_key registry"` run first.
- Context Mode `ctx_execute` for SHA-256 + line extraction + charter signal counts; agentmemory `memory_save` for this verify_2 pass.
- Scope lock honored: only this `verify_2.md` written; PRD / freeze / doctor code untouched. Independent of verify_1.

## Verdict rule

PASS only if every ACCEPT present, SHA matches, and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
