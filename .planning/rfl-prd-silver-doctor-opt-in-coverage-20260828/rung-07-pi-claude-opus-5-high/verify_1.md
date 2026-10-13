# verify_1 — rung 7 Pi Claude Opus 5 High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high`)  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md` (F-7-1…F-7-13 all ACCEPT-applied, I-52…I-64)

## Overall: **PASS**

Every F-7-1…F-7-13 ACCEPT text is present in the live PRD. SHA matches APPLY / expected digest / POLICY-C `apply_sha`. Charter signals OK. No residual undoes an ACCEPT. Prior I-1…I-51 locks remain intact.

## SHA-256

| | Digest |
|--|--------|
| Live PRD | `e5cf0853236d005cb74860d95cd0c8082409f30ffe70427f6c6d55ad52b7f5ef` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `e5cf0853236d005cb74860d95cd0c8082409f30ffe70427f6c6d55ad52b7f5ef` |
| Match | **yes** |

## Per-finding table

| ID | Sev | Verdict | Evidence (heading / file:line + excerpt) |
|----|-----|---------|------------------------------------------|
| F-7-1 | HIGH | **PASS** | Canary L143 / test L499 / AC L554 / prompt L668: enumeration/parity — every `.silver-bullet.json` `recommended_tools` key + derived `cross_tool` (+ `omniroute` Phase 3) in `RT_COMPONENT_IDS`/extra-tool, registry, `rt_run_component`, SKILL D10 table. |
| F-7-2 | HIGH | **PASS** | Blast-radius map L327–335 / live L159 / Phase 2 L439 / test L482 / prompt L620–621: D4/D13–D19/D21 → `--fix=host`; D20 export scaffold → local; mutex clear → host; `--fix=local` must not run D4/D13–D19/D21. |
| F-7-3 | MED | **PASS** | Current-system L103 / test L490: locked WARNs = **core Health ready + named warning evidence** (provider-missing, version≠`docs_pin`, Graphify skew, Omni busy, Omni expired). |
| F-7-4 | MED | **PASS** | F5 L264 / repair L345 / test L484 / locked L560 / OQ L572: confirmation unobtainable (non-TTY without `SB_DOCTOR_ASSUME_YES=1` **or** TTY decline/EOF) → **no writes** for whole `--fix`; nonzero; receipt not-applied. |
| F-7-5 | MED | **PASS** | F2 L217 / evidence L254 / test L497 / AC L554: opted-in unknown JSON key → WARN `unknown_key` + doctor **nonzero**; no installer; other components not FAIL-poisoned. |
| F-7-6 | MED | **PASS** | F5 L268 / locked L560: authoritative pin = [`hooks/lib/recommended-tools-registry.sh`](../../../hooks/lib/recommended-tools-registry.sh); **never** merged from project `.silver-bullet.json`; `RT_COMPONENT_IDS` is id allowlist. |
| F-7-7 | MED | **PASS** | Canary L147 / test L498 / locked L560: absent key ≡ opted-out PASS N/A `pending`; do not scaffold; new `RT_COMPONENT_IDS` id with no prior state = first-run `pending`. |
| F-7-8 | MED | **PASS** | NF4 L310 / L520 / AC 8 L557: `bash scripts/generate-plugin-commands.sh` when doctor-facing SKILL/command text changes; does not require full `run-all-tests.sh`. |
| F-7-9 | LOW | **PASS** | Phase 2 L436 / tests L503–504 / locked L560: RTK/CM/LeanCTX `min_version` below pin → **FAIL**; Graphify skill/package skew → **WARN**; Health URL without instance identity → **WARN**. |
| F-7-10 | LOW | **PASS** | F5 L260 / blast L330 / Phase 2 L439 / test L481 / prompt L663–664: convergence = **one ordered pass**; `DOCTOR_FIX_APPLIED` at **end** of invocation; no unbounded fixpoint. |
| F-7-11 | LOW | **PASS** | Canonical list L241–254: `missing_cli`, `provider_missing`, `version_drift`, `vendor_skip`, `unsupported_package_manager`, `busy`, `provider_expired`, `unknown_key`, `no_five_tool_consent` (plus envelope/`duplicate_key`). |
| F-7-12 | NIT | **PASS** | L24 / L126 / L359: `.planning/` repo-root links use `../` (59 hits); no local `docs/TROUBLESHOOTING.md` link as live; `probe-search_cli.sh` named as planned / “do not link as if it exists” (0 markdown file links). |
| F-7-13 | NIT | **PASS** | Test plan L474+: rows tagged **per-tool** (10) vs **global** (23). |

## Charter verification signals

From repo root (`test -f` + pattern scan as in CHARTER.md; `hashlib`/`crypto.createHash('sha256')` for digest):

| Check | Result |
|-------|--------|
| `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` | EXISTS |
| `rg` Session A\|Session B\|search_cli\|MUST NOT\|generic installer\|omniroute\|WS7\|sb-doctor.sh\|CONFIGURED\|fail.closed\|N/A | Hits present — **178** matching lines |
| `rg` four surfaces\|Setup\|Health\|Diagnosis\|--fix | Hits present — **148** matching lines |

## Spot-checks

| Check | Result |
|-------|--------|
| SHA live == APPLY / POLICY-C `apply_sha` | yes (`e5cf0853…b7f5ef`) |
| Config↔allowlist↔SKILL parity test required | L143, L499, L554 |
| `--fix=` scope → D-check map + local never D4/D13–D19/D21 | L327–335, L439, L482 |
| Locked WARNs = ready + named warning evidence | L103 |
| Confirmation unobtainable → no writes whole `--fix` | L264, L345, L484 |
| Opted-in unknown key WARN + nonzero | L217, L497 |
| Registry file is authoritative pin (never merged) | L268 |
| Absent key ≡ pending; no scaffold | L147, L498 |
| AC 8 + `generate-plugin-commands.sh` | L310, L557 |
| min_version FAIL / Graphify WARN / Health URL identity WARN | L436, L503–504 |
| One ordered pass; `DOCTOR_FIX_APPLIED` at end | L260, L439, L481, L663–664 |
| Canonical evidence ids incl. required set | L241–254 |
| Link hygiene (../; no fake TROUBLESHOOTING / probe link) | L24, L359; 0 bad local TROUBLESHOOTING links; 0 probe-search_cli.md links |
| Test-plan per-tool vs global tags | L474+ (10 / 23) |
| Prior rung locks (assume-yes, omniroute key, secrets, registry-pinned install_commands, `--fix=all` close break, CONFIGURED≠LIVE, fail-closed, WS7, generic installer ban) | Intact (counts: assume-yes 7, omniroute key 5, secrets 12, registry pin 7, fix-all break 2, CONFIGURED≠LIVE 5, WS7 19, fail-closed 9) |

## Residuals (do not undo ACCEPT)

1. **L159 still describes live first-match `break`** while locking Session A must close it — intentional before/after contrast; F-7-2/F-7-10 ACCEPT the close, not deletion of the live description.
2. **`probe-search_cli.sh` appears as planned work** (backticks / phase text) but is not linked as a live file; F-7-12 satisfied.
3. **Upstream OmniRoute `TROUBLESHOOTING.md` GitHub URLs remain** — distinct from the forbidden missing repo-root `docs/TROUBLESHOOTING.md` link (L359).
4. **Branch stayed `main`** — no checkout/switch during verify.

## Verdict rule

PASS only if every ACCEPT present and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
