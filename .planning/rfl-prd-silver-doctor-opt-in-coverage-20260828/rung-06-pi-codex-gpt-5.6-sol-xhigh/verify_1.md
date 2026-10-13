# verify_1 — rung 6 Pi Codex GPT-5.6 Sol Extra High

**Verifier:** Cursor Grok 4.5 High (`sb-grok-4-5-high`)  
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)  
**Inputs:** `review.md`, `APPLY.md`, `POLICY-C.json` / `POLICY-C.md` (F-6-1…F-6-8 all ACCEPT-applied, I-44…I-51)

## Overall: **PASS**

Every F-6-1…F-6-8 ACCEPT text is present in the live PRD. SHA matches APPLY / expected digest / POLICY-C `apply_sha`. Charter signals OK. No residual undoes an ACCEPT.

## SHA-256

| | Digest |
|--|--------|
| Live PRD | `67b7fb32d64e6defc6db4b18d41d6ff2e6df9085562c472c352275a783fa73d8` |
| Expected (brief / APPLY / POLICY-C `apply_sha`) | `67b7fb32d64e6defc6db4b18d41d6ff2e6df9085562c472c352275a783fa73d8` |
| Match | **yes** |

## Per-finding table

| ID | Sev | Verdict | Evidence (heading / file:line + excerpt) |
|----|-----|---------|------------------------------------------|
| F-6-1 | HIGH | **PASS** | Phase 3 L435 / AC7 L534 / prompt L602–603: registry + `RT_COMPONENT_IDS` / extra-tool + `rt_run_component` + scopes + SKILL + N/A-vs-FAIL; not an inert JSON key. |
| F-6-2 | MED | **PASS** | Fix table L314 / live blast L159 / Phase 2 L421 / test L463 / AC4 L531 / locked L538: `--fix=all` **one invocation** converges all eligible failures; close live first-match `break`; two-coexisting-failures fixture. |
| F-6-3 | MED | **PASS** | F4 N/A rule L235 / Phase 2 L419 / test L466 / hermetic L478 / locked L538: vendor-doctor skip is **not** Health evidence; remaining class checks decide; skip never PASSes alone. |
| F-6-4 | MED | **PASS** | Phase 2 L422 / test L464 / AC6 L533 / prompt L598–599: `/sb:doctor` same runner/skill as `/silver:doctor`; `--fix` / `--dry-run` forwarded (not docs-only). |
| F-6-5 | LOW | **PASS** | F5 L248 / repair list L327 / test L465 / locked L538 / prompt L640: TTY decline/EOF — confirm guarded scopes before any writes; no writes; nonzero; receipt not-applied. |
| F-6-6 | LOW | **PASS** | Host matrix L141 / test L460 / prompt L589–590: agent-host Cursor/Claude/Codex stays; `--fix=packages` is Homebrew pin on macOS; missing brew / unsupported OS → FAIL missing CLI, skip packages with Diagnosis (no invented apt/choco). |
| F-6-7 | MED | **PASS** | Repair list L329 / Phase 3 L437 / tests L467–468 / AC7 L534 / prompt L605–606: busy → WARN no restart; provider expired → WARN, OAuth manual; restart only a dead daemon. |
| F-6-8 | MED | **PASS** | Canary L149 / test L460 / L462 / locked L538 / prompt L586–587: versioned formula pin in `docs_pin` / registry; installed ≠ pin is WARN (command pin ≠ artifact pin). |

## Charter verification signals

From repo root (`test -f` + `rg` as in CHARTER.md; `hashlib.sha256` / `shasum -a 256` for digest):

| Check | Result |
|-------|--------|
| `test -f .planning/PRD-silver-doctor-opt-in-coverage.md` | EXISTS |
| `rg` Session A\|Session B\|search_cli\|MUST NOT\|generic installer\|omniroute\|WS7\|sb-doctor.sh\|CONFIGURED\|fail.closed\|N/A | Hits present (Session A/B; search_cli; MUST NOT; generic installer; omniroute; WS7; sb-doctor.sh; CONFIGURED≠LIVE; fail-closed / fail closed; N/A) — **153** matching lines |
| `rg` four surfaces\|Setup\|Health\|Diagnosis\|--fix | Hits present (four surfaces; Setup/Health/Diagnosis/`--fix` throughout) — **129** matching lines |

## Spot-checks

| Check | Result |
|-------|--------|
| SHA live == APPLY / POLICY-C `apply_sha` | yes (`67b7fb32…a73d8`) |
| Phase 3 reconciler registration (not inert key) | L435, L534, L602–603 |
| `--fix=all` one-invocation + close first-match break | L159, L314, L421, L463 |
| Vendor-doctor skip ≠ Health evidence | L235, L419, L466 |
| `/sb:doctor` executable alias test | L422, L464, L533 |
| TTY decline/EOF no writes | L248, L327, L465 |
| Homebrew macOS / missing brew Diagnosis skip | L141, L460, L589 |
| Busy WARN / expired WARN + OAuth manual | L329, L437, L467–468 |
| Versioned search_cli formula pin + drift WARN | L149, L460, L462 |
| Prior rung locks (secrets, assume-yes, WS6 gate, registry-pinned install_commands) | Intact (not undone by F-6 edits) |

## Residuals (do not undo ACCEPT)

1. **L159 still describes live first-match `break`** as current behavior while locking that Session A must close it — intentional before/after contrast; F-6-2 ACCEPT requires the close, not deletion of the live description.
2. **Freeze Omni still names YAML `omni-agent-doctor`** alongside locked JSON key `omniroute` — both required by prior locks; F-6-1/7 do not remove that pairing.
3. **Branch stayed `main`** — no checkout/switch during verify.

## Verdict rule

PASS only if every ACCEPT present and no new contradiction undoes an ACCEPT → **satisfied**. FAIL ids: **none**.
