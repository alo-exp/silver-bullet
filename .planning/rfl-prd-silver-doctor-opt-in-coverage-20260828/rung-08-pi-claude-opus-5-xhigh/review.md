# Review — rung 8 Pi Claude Opus 5 Extra High (REVIEW-ONLY)

**Rung:** 8/8 — `claude/claude-opus-5-xhigh`, reasoning `xhigh`, phase `rung_8_review`
**Target:** [`.planning/PRD-silver-doctor-opt-in-coverage.md`](../../PRD-silver-doctor-opt-in-coverage.md)
**PRD SHA-256 read (unmodified):** `e5cf0853236d005cb74860d95cd0c8082409f30ffe70427f6c6d55ad52b7f5ef` — matches brief. **No edit made to the PRD.**
**Retrieval:** `graphify query "silver doctor opt-in coverage checks tool detection"` (38911-node graph; surfaced `scripts/sb-doctor.sh` `doctor_apply_fixes()` L278, `run_doctor_checks()` L356, `doctor_run_reconciler()` L190) + `graphify explain "silver doctor"`; `memory_search` for prior-rung ledger state. agentmemory healthy (v0.9.29).
**Prior ACCEPTs honored:** I-1…I-64 read from [`ISSUE-LEDGER.md`](../ISSUE-LEDGER.md) and rung-07 [`APPLY.md`](../rung-07-pi-claude-opus-5-high/APPLY.md). None re-filed.

## Verdict

**NOT CLEAN.** 12 new findings: **1 HIGH, 5 MED, 4 LOW, 2 NIT.**

The PRD is in good shape after seven rungs — scope fork, allowlist contract, `--fix` blast radius, N/A-vs-FAIL, and the parity test are all solid. The new findings cluster on one bird's-eye theme the ladder has not yet touched: **the PRD specifies check *severities* exhaustively but never specifies what severities do to the process exit code**, and several locked WARNs have no defined remediation, no test row, or no coverage-table `--fix` cell. Ant's-eye findings are residue from earlier applies (stale "five host CLIs", a D-check range that swallows an undefined check) plus one real downgrade/idempotency contradiction.

---

## HIGH

### F-8-1 — HIGH — No severity→exit-code contract; only three special cases specify `nonzero`, and the one WARN that does contradicts the implied default

**Where:** L217 (F2), L484 / L492 / L497 (test plan), L554 (AC 5); absent everywhere else.

> L217: "That WARN does not FAIL other components; doctor **exit is nonzero** so CI notices."

The PRD names exactly three conditions that make doctor exit nonzero: `unknown_key` WARN (L217, L497, L554), confirmation-unobtainable (L264, L345, L484), and failed/malformed apply (L260, L492). **It never states what a D10 `FAIL` does to the exit code.** AC 8 (L557) requires `test-silver-doctor.sh` green, and the charter's verification signals shell out to `bash scripts/sb-doctor.sh --dry-run`, so exit status is load-bearing for both CI and the operator JTBD at L79 — yet the contract is unwritten.

Worse, the specified cases are mutually inconsistent as a set. L217 justifies nonzero for a *WARN* with "so CI notices," which only makes sense if WARN is not normally nonzero. That leaves an implementer with two incompatible readings, both defensible from the text:

- **WARN → zero, FAIL → nonzero (`unknown_key` special-cased):** then `unknown_key` needs bespoke exit plumbing that no AC or test row describes beyond the assertion itself, and it is the only WARN in the entire catalog with that property.
- **WARN → nonzero generally:** then every locked WARN at L103 (`provider_missing`, `version_drift`, Graphify skew, Omni `busy`, Omni `provider_expired`), plus `suspended` / `reload_required` (L101), plus unsupported-host `cross_tool` (L105, L495), plus Health-URL-without-identity (L436) turns the default tree red — including the Graphify skew that L365 says is **already present in this repo** (see F-8-2).

This is not a wording nit: the same fixture flips between pass and fail depending on which reading the implementer picks, and the test plan's `nonzero` assertions at L484/L492/L497 cannot be written without resolving it.

**Suggested resolution direction (not applied):** add an explicit severity→exit table to F5 or the blast-radius section — e.g. FAIL → nonzero; WARN → zero **except** the enumerated escalating WARNs (`unknown_key`); PASS/PASS N/A → zero — plus a `global` test row asserting the exit code for a WARN-only tree and for a FAIL tree.

---

## MED

### F-8-2 — MED — The Graphify skew WARN is permanently true in this repo, has no `--fix` action, and no stated interaction with "default tree is green"

**Where:** L365 (docs policy table), L103 (locked WARN list), L436 (Phase 2), L575 (OQ5 locked), vs L82 (users/JTBD) and L234 (F4 required column).

> L365: "skill vs package skew is already a WARN at 0.9.35 vs 0.9.48"
> L575: "Do **not** add a Graphify `min_version` pin in config in Session A."

The PRD locks a WARN whose triggering condition is already true in the SB checkout, then forbids the config change that would express a pin. Three consequences are unaddressed:

1. **F4 (L234) makes `--fix` action a required column for every row.** Graphify's WARN has no repair — the natural one (`graphify install`, per the live CLI's own "Run 'graphify install' to update" banner) is neither allowlisted nor mentioned, and L64 forbids an invented `graphify doctor`. The cell has no defined value, and the repair-dispatch test at L494 ("each advertised `--fix` action ... named scope/script is wired") has nothing to bind to.
2. **L82 promises the non-opted-in operator "the default tree is green."** A permanent WARN is not green under any ordinary reading, and combined with F-8-1 it may be nonzero.
3. AC 8 requires `test-silver-doctor.sh` green while a live-probe WARN is permanently present, so the test must either tolerate or assert the skew — the PRD says neither.

**Direction:** state that Graphify skew WARN is an *expected, non-blocking* advisory in the SB repo's own tree, give it an explicit `--fix` cell value (`none — advisory; upstream `graphify install` is operator-run, not doctor-run`), and say whether "green" in L82 means "no FAIL" rather than "no WARN".

### F-8-3 — MED — `required_when_enabled: false` vs a hard D10 FAIL: doctor is stricter than the enforcement layer, and the PRD never reconciles it

**Where:** L147.

> L147: "Hooks `sb_recommended_tool_enforced()` skip when that flag is false; **doctor/reconciler do not read it today.** Session A: keep `required_when_enabled: false` (do not copy Alumnium `true`). ... opted-in missing CLI → FAIL. ... Do not treat 'not required' as D10 PASS N/A when opted in."

The PRD locks two facts that pull opposite ways and never states the resolution as an intentional product decision:

- The config declares `search_cli` **not required** when enabled, and the hook layer honors that by not enforcing it.
- D10 will nonetheless **FAIL** (`D10-search_cli` / `missing_cli`, L475, L488) when it is opted in and the CLI is missing.

So an operator who opts into an explicitly-optional Deep Research provider and later removes the binary gets a hard doctor FAIL for a tool Silver Bullet's own enforcement path deliberately ignores — plausibly a nonzero exit (F-8-1) blocking CI. The PRD instructs "Do not treat 'not required' as D10 PASS N/A when opted in" (which prevents a false green) but never says why FAIL rather than WARN is correct here, and never says whether `required_when_enabled` should eventually become a doctor-read field. An implementer reading only L147 cannot tell whether the divergence is the design or an oversight to be flagged.

**Direction:** one sentence of rationale — e.g. "`required_when_enabled` gates *hook enforcement*, not *audit honesty*; D10 audits what the operator opted into, so FAIL is correct and the flag stays doctor-invisible in Session A" — plus a note that this is deliberate divergence, not drift to be 'fixed'.

### F-8-4 — MED — `version_drift` WARN vs `--fix=packages` pinned install: downgrade behavior and post-apply idempotency are contradictory

**Where:** L149, L249, L478, L491, L560.

> L149: "a **versioned** formula pin ... Installed `search --version` (or formula version) that differs from the pin is D10 **WARN**."
> L478: "`--fix=packages` for `search_cli` | applies **versioned** brew/registry pin matching `docs_pin`"

Drift is defined symmetrically ("differs from the pin"), so it fires when the installed version is **newer** than the pin — the common case after any unrelated `brew upgrade`. The PRD then advertises a packages repair that installs the pinned version. Two unresolved forks:

1. **Is `--fix=packages` expected to downgrade?** Installing an older pinned formula over a newer installed one is a destructive, surprising act on a shared machine, and it is not in the blast-radius table's "may write" cell for `packages` (L330) except by implication. Nothing says whether drift-upward is repairable at all or advisory-only.
2. **If it does not downgrade, the idempotency and convergence claims break.** L491 requires "Second `--fix` | idempotent" and L481 requires `--fix=all` to converge in one ordered pass. A drift-upward WARN that `--fix=packages` cannot clear means the component never reaches `ready` after apply, so the L477 per-tool row ("mutates fixture then re-probe → `ready` / PASS") is unsatisfiable for that fixture while the WARN persists.

**Direction:** state the drift direction policy explicitly — e.g. installed **older** than pin → repairable via pinned install; installed **newer** than pin → WARN only, `--fix` must not downgrade, and the WARN is expected to persist after apply (so it is excluded from the converge-to-`ready` assertion).

### F-8-5 — MED — Two canonical evidence ids have no test-plan row, including the one the PRD singles out as an implementer trap

**Where:** evidence vocabulary L255 / L247; NF2 L302; test plan L473–L506.

> L302: "Duplicate `leanctx` **and** `lean-ctx` MCP keys: D10 reports **FAIL** ... Catalog D22 may still label the same class of finding as WARN ... implementers must not treat D22 WARN as a license to PASS D10. D10 FAIL is the Session A contract."

`duplicate_key` (L255) and `no_five_tool_consent` (L247) are both in the canonical evidence-id table, which L241 says "Diagnosis column **and tests** use these." Neither has a test-plan row:

- **`duplicate_key`** is the one contract the PRD explicitly warns will be mis-implemented (D22 WARN vs D10 FAIL). It is stated only in prose in NF2, appears in no AC, and has no row — so the exact confusion the PRD predicts is left unenforced by the test plan. Given the ladder already accepted `min_version` FAIL (L504) and Graphify skew WARN as test rows, this severity-conflict case is a conspicuous omission.
- **`no_five_tool_consent`** carries the subtle `D10-routes` **PASS** (not PASS N/A, not WARN) rule that consumed two prior findings (I-15, I-31). The only `cross_tool` row present is the unsupported-host WARN (L495). The no-consent PASS itself — the case those two findings were about — is untested, so a regression back to WARN or PASS N/A would pass CI.

**Direction:** two `global` rows — `Duplicate leanctx/lean-ctx MCP keys (opted in) | D10 FAIL D10-leanctx / duplicate_key; D22 WARN label does not downgrade D10` and `cross_tool no five-tool consent | D10-routes PASS (not PASS N/A, not WARN)`.

### F-8-6 — MED — Confirmation gate trigger is undefined: scope *requested* vs package mutation *actually planned*

**Where:** L264 (F5), L345 (blast radius item 5), L484 (test row), L505 (test row).

> L264: "Confirmation required for `packages`, network installs, and daemon restart **when stdin is a TTY** ... **Confirmation unobtainable** ...: **no writes** in that `--fix` invocation ... Same contract for `--fix=all` — do not apply local/host while skipping packages."

I-55 locked *what happens* when confirmation is unobtainable (no writes, nonzero). It did not lock *when the gate fires*. For `--fix=all` on a non-TTY without `SB_DOCTOR_ASSUME_YES=1`, two readings survive:

- **Scope-triggered:** `all` includes `packages`, so the gate fires unconditionally and the entire invocation is a no-op — even when the tree has zero package-class failures and only, say, a D4 hooks drift to repair. Non-interactive `--fix=all` then becomes permanently useless without the assume-yes flag.
- **Plan-triggered:** the gate fires only when the plan actually contains a package install / network fetch / daemon restart; otherwise local+host apply normally. "Do not apply local/host while skipping packages" then reads as "when packages *were* planned and got skipped."

The sentence quoted above forecloses the third option (apply local/host, silently skip packages) but does not choose between these two, and they differ observably in the L484 fixture: whether the fixture must contain a package-class failure to produce "no writes / nonzero" is exactly the thing left unsaid. L505 ("`--fix` with packages/daemon (CI) | applies when `SB_DOCTOR_ASSUME_YES=1`") tests only the positive path.

**Direction:** pick one — plan-triggered is the more defensible ("the gate fires when the ordered pass would execute a confirm-class mutation") — and add the qualifier to the L484 row so the fixture is unambiguous.

---

## LOW

### F-8-7 — LOW — `D13–D19` range includes a print-only check and a check that does not exist in the PRD

**Where:** L327, L328, L332, L439, L482, L553 use the range; L159 uses the enumeration.

> L159 (enumeration): "D13/D14/D16/D18/D19 host install (`claude|codex|cursor` only) ... D15 print-only."
> L327 (range): "D4 hooks, **D13–D19** host install, D21 CSBA ..."

The enumerated host-install set is **{D13, D14, D16, D18, D19}**. The range `D13–D19` additionally sweeps in **D15**, which L336 pins as **print-only** ("must not: mutating Claude descriptions"), and **D17**, which appears **nowhere in the PRD** (verified: zero occurrences). So the range formulation says `--fix=host` may write D15 — directly contradicting L336 — and asserts a scope rule about an undefined D17.

This matters because L482 and L553 turn the range into a test assertion ("`--fix=local` with D4/D13–D19/D21 failing | does **not** run those host mutations"). An implementer writing that fixture must decide what a "D15 host mutation" or a "D17 failure" even is.

**Direction:** use the enumeration `D13/D14/D16/D18/D19` consistently in all six places, or write `D13–D19 host-install checks (D13, D14, D16, D18, D19; D15 is print-only)`.

### F-8-8 — LOW — Stale "five host CLIs" residue contradicts the locked current-host-only rule

**Where:** L82 (users table), L405 (inventory table); vs L288 (NF1), L455 (Phase 3), L236 (F4 host-support column).

> L288: "**Omni Setup does not require all five CLIs.** Require the CLI for the **current doctor host** only."
> L405 (still): "four surfaces; daemon `:20128`; compression/memory off; **five host CLIs**; OAuth manual"
> L82 (still): "Setup / health / diagnosis / `--fix` for daemon + providers + **five CLIs**"

I-41 locked the current-host-only matrix in NF1, F4, and Phase 3, but two summary cells were not updated and still state the superseded requirement without qualifier. These are the two tables an implementer skims first (JTBD success criteria, and the in-scope inventory's "Required work" cell), so the stale text is likely to be read as the requirement. L177's column header "Omni five CLIs (freeze, later)" is acceptable as a *matrix label* (it enumerates which CLI belongs to which host) but reads the same way at a glance.

**Direction:** append "(current doctor host CLI only)" to L82 and L405; optionally retitle the L177 column "Omni CLI per host (freeze, later)".

### F-8-9 — LOW — `unsupported_package_manager` skip has no defined `DOCTOR_FIX_APPLIED` / exit outcome

**Where:** L141, L251, L478; vs L260.

> L141: "`--fix=packages` skips with that evidence (no invented apt/choco installer)."
> L260: "**`DOCTOR_FIX_APPLIED` is the result of one invocation, not an intra-invocation early-return.**"

The PRD defines outcomes precisely for success, failure, malformed apply, and confirmation-unobtainable — but a *skip for unsupported package manager* is none of those. It is not a failure (the tree is honestly unrepairable on this OS), yet nothing was applied. Undefined:

- Is `DOCTOR_FIX_APPLIED` 0 or 1 when the only in-scope repair was skipped for this reason?
- Does the invocation exit zero (nothing went wrong) or nonzero (requested repair did not happen)?
- Does the receipt record a not-applied entry, as it must for confirmation-unobtainable (L345)?

The same question applies to the sibling skip at L172 (`--fix=local` / `--fix=host` skipping `search_cli` because `rt_scope_includes_component` excludes it). L478 asserts only "skip with Diagnosis," not the invocation outcome. Resolving F-8-1 should resolve this by construction; if it is left implicit the two skip paths will likely be implemented inconsistently.

### F-8-10 — LOW — Users table promises an Omni PASS N/A row that cannot exist when Phase 3 is deferred

**Where:** L82; vs L280, L550, L559.

> L82: "`D10-alumnium` / future `D10-search_cli` / **Omni rows are PASS N/A** (`pending`/`disabled`), never FAIL"
> L280: "`omniroute` is **not** a current `recommended_tools` key."
> L550/L559: deferred Phase 3 gets "a **coverage-table footnote** ... — **not** an F4 schema row."

In the deferred case — which OQ6 (L578) treats as a likely outcome and AC 7 fully specifies — there is no `omniroute` config key, no registry entry, and no `rt_run_component` dispatch, so doctor emits **no Omni component line at all**. The JTBD success criterion at L82 nonetheless tells the non-opted-in operator to expect an Omni row reading PASS N/A. Those cannot both be true.

I-42 corrected the *coverage table* (footnote, not F4 row); the *users table* promise about runtime D10 output was not swept.

**Direction:** qualify L82 — "Omni rows are PASS N/A **once Phase 3 lands**; while Phase 3 is deferred there is no Omni D10 row (coverage-table footnote only)".

---

## NIT

### F-8-11 — NIT — Dead bare-UUID links to the origin review (three occurrences)

**Where:** L9, L526, L683.

> L9: "Adversarial review [759a2827](759a2827-2237-4cc8-93d9-e4db97c3f040)"

The link target is a bare UUID with no scheme and no extension, so Markdown resolves it as the relative path `.planning/759a2827-2237-4cc8-93d9-e4db97c3f040`, which does not exist (verified). Every renderer produces a broken link, three times, including in the PRD's closing provenance line.

Distinct from I-63, which covered `../` prefixes for repo-root paths and forbade linking *missing in-tree files* (`docs/TROUBLESHOOTING.md`, `probe-search_cli.sh`) as live; this is an external artifact reference that should not be a link at all.

**Direction:** render as inline code — `review 759a2827` — or give it a resolvable location. Provenance value is preserved either way.

### F-8-12 — NIT — `Status: draft` after eight review rungs and a locked SHA

**Where:** L3.

> L3: "**Status:** draft"

The PRD is the frozen contract for a paste-ready implementer session (L4), carries a locked SHA in the ladder brief, ships a copy-paste prompt (L586+), and has absorbed 64 applied findings across seven rungs. L681 tells the implementer to "treat headings in this file as the contract." Leaving `draft` in the header invites exactly the re-litigation of locked defaults that AC 11 (L560) and the "locked — implement these; do not block on re-asking" heading (L568) exist to prevent.

**Direction:** promote to `ready for Session A implementation` (or `approved`) when the ladder closes.

---

## Bird's-eye assessment (no finding filed)

Confirmed sound, recorded so a later rung does not re-plough it:

- **Scope fork (L38–L46)** is unambiguous; Session B is rejected in Goals, Non-goals, Out of scope, and the implementer prompt. No leakage path found.
- **Fail-closed chain (F6 L268, blast radius L330, AC 5 L554)** is now closed end-to-end: id allowlist → registry-pinned argv/digest → never merged with project JSON → tampered-payload refusal fixture. I probed for a bypass via `install_commands` and found none.
- **Phase gating** is coherent: Phase 1 owns the `--fix` swallow (L432), Phase 3 is double-gated on the WS6 installer *and* reconciler registration (L450, L453). Phase 2's `docs_pin` backfill (L444) correctly prevents `search_cli` being the only pinned row.
- **`--fix` blast-radius table (L323–L338)** and the F5 invariants are mutually consistent; the ordered-pass / `DOCTOR_FIX_APPLIED`-at-end rule (I-61) reads cleanly against the live `break` described at L159.
- **CONFIGURED ≠ LIVE (L188–L190)** and the false-green catalog are propagated into three test rows (L500, L502, L503). No gap found.
- **Freeze discipline:** every freeze reference is a heading citation, not a line number (L14, L273–L278). The PRD does not require opening the freeze file to implement Session A — I did not open it.

## Scope compliance

- Read: PRD (review target, **not modified**), ladder `CHARTER.md` / `ISSUE-LEDGER.md` / `LADDER.md` / rung-07 `APPLY.md` / rung-08 `brief-review.md`.
- Wrote: **only** this file.
- Freeze file `.planning/router_subagent_surfaces_85bf9f09.plan.md` **not opened**. No doctor code implemented. No `git checkout` / `git switch`. No subagents launched. No triage, no PASS claim, no advance. Not Fast.
