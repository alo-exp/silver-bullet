# Rung 07 review — Pi Claude Opus 5 High

**Phase:** REVIEW-ONLY (`rung_7_review`)
**Model:** `claude/claude-opus-5-high` (reasoning high), Pi via Omni fill-first (Sourcevo → Gmail). No Grok remap, no Fast.
**Target:** `.planning/PRD-silver-doctor-opt-in-coverage.md`
**PRD SHA-256 reviewed:** `67b7fb32d64e6defc6db4b18d41d6ff2e6df9085562c472c352275a783fa73d8` (653 lines, post-rung-6 bytes — matches `LADDER-STATUS.json.rung_06.prd_sha`)
**Prior-findings guard:** I-1…I-51 treated as locked; not re-filed.
**Result:** **NOT CLEAN** — 13 new raw findings (HIGH 2 / MED 6 / LOW 3 / NIT 2). No triage, no PRD edits, no verdict on advancement.

---

## Method and scope

- **Graphify first (attempted, unavailable).** `graphify query "sb-doctor.sh recommended tools reconciler rt_scope_includes_component rt_run_component D10 checks"` failed: `error: graph file not found: graphify-out/graph.json`. Only `graphify-out/graph.json.corrupt-20260828T1201` remains in this tree, plus a `0.9.35` skill vs `0.9.48` package skew warning (the same skew the PRD cites at `:347`). Fell back to direct reads of the two in-scope paths. Recorded in agentmemory (`memory_save`, non-secret).
- Read: charter, `LADDER.md`, `LADDER-STATUS.json`, `ISSUE-LEDGER.md` (I-1…I-51), all six prior `APPLY.md` notes, and prior rung reviews for de-duplication.
- Read the complete live PRD (653 lines). Did **not** open `scripts/`, `skills/`, `hooks/`, `tests/`, `.silver-bullet.json`, or the freeze plan. Freeze is cited only through cross-links already present in the PRD (`:5`, `:11`, `:72`, `:258`, `:517`).
- All findings below are derivable from the PRD text plus the ladder artifacts, so line citations are stable against the reviewed SHA.

---

## Bird's-eye review

The Session A / Session B fork, the allowlist-not-installer thesis, the `search_cli` canary, the Omni-as-separate-WS7 boundary, and the six applied ledger clusters all hold. After 51 accepted findings the document is dense but coherent, and the locked-defaults block (`:546-552`) plus AC 11 (`:538`) genuinely prevent re-litigation. The remaining bird's-eye problems are not about what the PRD says — they are about **what the PRD stops short of making mandatory**:

1. **The root cause is diagnosed but not closed by anything durable.** The whole problem statement (`:20-27`, `:143`) is that three layers drift: `.silver-bullet.json` keys, `RT_COMPONENT_IDS` / registry, and the SKILL D10 table. Session A fixes today's instance (`search_cli`) by hand. The only anti-drift requirement is a single prose clause in F4 (`:225`), which never reaches the test plan or any acceptance criterion, and which covers only the SKILL row — not the allowlist/registry/`rt_run_component` parity that actually produced the canary. The eighth key will reproduce the bug.
2. **`--fix` blast radius is now under-specified in the opposite direction.** I-45 replaced the live first-match `break` with "one invocation converges all eligible failures" (`:159`, `:314`). Nothing in the PRD defines *eligible* for the non-reconciler doctor mutations (D4/D13/D14/D16/D18/D19/D20/D21/D15). Under the old `break` at most one such repair fired; under the new contract every matching one fires, on every scope, unless a scope→check map is written. The scope table's own "must not" cells (`:311-312`) become unenforceable.
3. **Three of the four locked WARN outcomes have no mechanism.** The PRD's D10 state mapping (`:99-104`) is exhaustive: `ready`/`disabled`/`pending`/`unsupported`/`suspended`/`reload_required`/`repairable`/`failed`. I-37 added exactly one bespoke advisory path (provider-missing, `:103`). Version-pin drift (`:149`, `:462`), Graphify skill/package skew (`:418`, `:482`), Omni busy and Omni provider-expired (`:437`, `:467-468`) are all locked as **WARN** with no stated route through that mapping.
4. **"Done" is scoped to two test scripts, not to a shippable repo state.** AC 8 (`:535`) names `test-silver-doctor.sh`, `test-reconcile-recommended-tools.sh`, and `sync-codex-package.sh`; `:496` explicitly discourages the full suite. NF4 (`:294`) already says plugin command stubs need regenerating when doctor command text changes — which Phase 1 guarantees. An implementer can satisfy every acceptance criterion and leave derived surfaces stale.
5. **Fail-closed is asserted for *execution* but not for *visibility*.** Unknown component ids are PASS N/A with no installer (`:217`) — correct for safety, but it means a mistyped opted-in key produces a fully green tree with no signal, which is precisely the false-green class the PRD itself catalogues at `:190`.

Everything else at the product level is sound: the session fork is not reopened, Omni is not stuffed into Graphify, Session B stays rejected, and OQ 6/7 remain correctly non-blocking (`:554-557`).

---

## Ant's-eye review

Spot-checked the applied ledger against live bytes: I-1 (`SB_DOCTOR_ASSUME_YES=1`, `:248`), I-3/I-17 (unknown id, `:217`/`:477`), I-15/I-31 (`D10-routes` PASS, `:105`/`:216`), I-24/I-29 (`rt_scope_includes_component` packages, `:160`/`:408`/`:460`/`:618`), I-27 (`search_cli` hosts, `:141`/`:214`/`:236`), I-34 (registry-pinned payload, `:58`/`:252`/`:313`), I-35 (four secret channels, `:247`/`:474`), I-40 (WS6 gate, `:264`/`:432`), I-44 (Phase 3 registration, `:435`), I-45 (`--fix=all`, `:159`/`:314`/`:421`), I-47 (executable alias, `:422`/`:464`/`:533`), I-48 (TTY decline, `:248`/`:327`/`:465`), I-49 (brew platform, `:141`/`:460`), I-51 (versioned pin, `:149`/`:462`) — all present and intact as filed.

New ant's-eye gaps cluster in four places: the **status-derivation mechanism** (how a locked WARN is actually produced), the **exit/write contract** (non-TTY vs TTY partial-apply asymmetry), the **trust-anchor identity** (which file is "the registry"), and **config-shape edge cases** (absent key vs `null`, downstream installs, state migration). Several test-plan rows also encode non-deterministic expectations ("FAIL or WARN"), which cannot be asserted.

---

## Raw findings

### F-7-1 — HIGH — The config↔allowlist↔SKILL parity test that would close the PRD's own root cause is never required

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:20-27` — the three-layer drift table; "Those three layers are not the same list."
- `:143` — "Adding a key to `.silver-bullet.json` does **nothing** until registry + probe + `rt_run_component` + SKILL + N/A-vs-FAIL tests land. That is why **`search_cli` is the canary**."
- `:225` — "Ship the table in the SKILL (D10 section) and keep tests asserting every `recommended_tools` key **and** derived `cross_tool` (plus Omni when the WS7 phase lands) has a row."
- `:452-484` — test plan; no parity/enumeration row.
- `:528-538` — AC 1 requires the table to *exist*; AC 2 requires `search_cli` specifically; no AC requires an enumeration test.

The PRD identifies drift between `.silver-bullet.json` keys, `RT_COMPONENT_IDS` / `hooks/lib/recommended-tools-registry.sh`, and the SKILL D10 table as the defect class, then closes only the current instance. The single anti-drift sentence lives in F4 prose at `:225` and is (a) absent from the test-plan table, (b) absent from every acceptance criterion, (c) scoped to *SKILL rows only* — it would not catch a key that has a SKILL row but no `RT_COMPONENT_IDS` entry, no registry entry, or no `rt_run_component` dispatch arm, which is a strict superset of how `search_cli` failed. `:496` further tells the implementer not to run the full suite, so no other freshness gate compensates.

Consequence: Session A can be fully accepted while the next `recommended_tools` key (or the Omni key at Phase 3, or a downstream fork's key) silently repeats the canary. This is distinct from I-18 (cover `cross_tool` in the table), I-44 (Phase 3 registration work), and I-4 (test rows for the false-green catalog): none of them mandate an executable parity assertion over the key set. The PRD needs a named test that enumerates config keys → allowlist/extra-tool list → registry → dispatch → SKILL row, with an explicit statement of which mismatches are FAIL vs WARN, and an AC that names it.

---

### F-7-2 — HIGH — Closing the `--fix` first-match `break` widens blast radius because no scope→doctor-check eligibility map exists

**References:**

- `:159` — "Remaining mutations, first matching failed check then `break`: D13/D14/D16/D18/D19 host install …; D20 mutex clear …; D4 hooks merge; D21 `install-cursor-sb-agents.sh`; D15 print-only. **Session A must close this `break`:** `--fix=all` is **one invocation that converges all eligible failures** in dependency order…"
- `:160` — "Scopes: `local` → project; `host` → host; `packages` → packages; `all` → all" — described only as the reconciler scope mapping.
- `:308-319` — blast-radius table: `--fix=local` must not touch "host MCP/hooks, package installs"; `--fix=host` may write "hooks, MCP merge, route ownership"; D4/D13-D21/D15 appear as **their own rows with no scope attribution**.
- `:314` — `--fix=all` "converges all eligible failures in dependency order".
- `:423` — repair-dispatch tests are tied to "every advertised **coverage-table** `--fix` action"; the coverage table is per `recommended_tools` tool (`:225-237`), so D4/D13-D21 have no dispatch row at all.

The word **eligible** is never defined for the nine legacy doctor mutations. Two readings are equally compliant: (a) legacy mutations are gated by the same scope keyword, so `--fix=local` performs none of D4/D13/D21 (consistent with the `--fix=local` must-not cell), or (b) legacy mutations are scope-independent and now all fire on any `--fix`, which directly violates that same cell. Under the pre-existing `break` the ambiguity was bounded to one repair per invocation; I-45 removes that bound without supplying the map, so the *worst* reading became strictly worse. `--fix=local` could now merge hooks (D4) and write Cursor SB agents (D21) in a project the operator only asked to repair locally, and the receipt/no-rollback policy (`:69`, `:328`) makes that unrecoverable except by re-running doctor.

This is not I-45 (which fixed convergence semantics) nor I-36 (per-component repair dispatch for coverage-table rows). The PRD needs an explicit scope → {D-check} eligibility table, plus the dependency order it promises (reconciler first, then which legacy checks in what order), and a test that `--fix=local` performs no host/package writes on a fixture where every legacy check is failing.

---

### F-7-3 — MED — Three of the four locked WARN outcomes have no path through the documented D10 state mapping

**References:**

- `:99-104` — the complete state mapping: `ready`→PASS; `disabled|pending|unsupported`→PASS N/A; `suspended`/`reload_required`→WARN; `repairable`/`failed`→FAIL; plus one bespoke advisory rule for provider-missing.
- `:103` — the only mechanism sentence: "Record core Health plus warning evidence so `doctor_record_reconciler_d10()` emits **WARN**."
- `:149`, `:462` — installed `search --version` / formula version ≠ pin → D10 **WARN**.
- `:418`, `:482` — Graphify skill vs package skew → D10 **WARN**.
- `:437`, `:467-468` — Omni `chat_admission_busy` → **WARN**; provider expired → **WARN**.
- `:538` (AC 11) — all four are locked as implemented defaults.

I-37 supplied a mechanism for exactly one advisory WARN. The other three are stated as outcomes only. Because a component is either `ready` (→PASS) or `repairable`/`failed` (→FAIL) in the enumerated mapping, an implementer has no sanctioned way to reach WARN for version drift, Graphify skew, busy, or expired without either (a) generalising the `:103` "core Health ready + warning evidence" pattern into a named component substate, or (b) inventing a per-tool special case in `doctor_record_reconciler_d10()`. The PRD should either declare the `:103` pattern the general advisory-WARN mechanism (and say that every locked WARN uses it), or add the substate to the mapping at `:99-104`. Without that, four AC-11 items are individually locked and collectively unimplementable through the documented path, and the corresponding test rows (`:462`, `:467-468`, `:482`) cannot be written against a defined evidence shape.

---

### F-7-4 — MED — Non-TTY and TTY-decline paths give contradictory partial-write contracts for the same underlying condition

**References:**

- `:248` — "**Non-TTY without that flag:** do **not** apply packages/network/daemon; nonzero exit; report that confirmation is required; never hang. **TTY decline / EOF / invalid:** confirm guarded scopes **before any writes** in that invocation; no writes; nonzero; receipt not-applied."
- `:327` — same pair, with the explicit gloss "(no partial local/host apply mixed with skipped packages)" attached only to the TTY-decline branch.
- `:483` — test row: non-TTY without the flag "skip those mutations, nonzero, never hang" — implying other mutations still applied.
- `:465` — test row: TTY decline "no writes; nonzero; receipt not-applied".
- `:314` — `--fix=all` mixes unattended (local/host) and guarded (packages/daemon) mutations in one invocation.

Both branches describe *the same situation*: confirmation for guarded scopes is unobtainable. The TTY branch forbids partial application and requires zero writes; the non-TTY branch permits (indeed implies) local/host writes with packages skipped — the exact partial state `:327` calls out as unacceptable. Either the "no partial apply" rationale applies to both, or it applies to neither, but the PRD asserts both simultaneously. Consequences an implementer cannot resolve: whether a non-TTY `--fix=all` that converged local/host but skipped packages writes an "applied" receipt, and what the exit status means when the residual failure is *policy-skipped* rather than *broken*.

Relatedly, the PRD requires nonzero exit in at least four distinct situations (`:244` failed/malformed apply, `:248` ×2, `:327`) but never defines doctor's overall exit contract or distinguishes those codes from an ordinary "checks FAILed" exit — so a test asserting "nonzero" cannot distinguish "confirmation required" from "apply crashed" from "one D10 tool is broken". This is neither I-38 (non-TTY skip rule) nor I-48 (TTY decline rule); it is the unreconciled seam between them plus the missing status vocabulary.

---

### F-7-5 — MED — A mistyped or unrecognised opted-in key produces a silently green tree

**References:**

- `:217` — "Unknown component id (not in `RT_COMPONENT_IDS` / extra-tool list) → doctor **emits PASS N/A** with reason `unsupported` (fail-closed: **no installer, no `--fix` suggestion**). Never FAIL the default tree for a name the allowlist does not know."
- `:477` — test row: "Unknown component id | PASS N/A reason `unsupported`; no installer; no `--fix` suggestion".
- `:190` — the PRD's own false-green catalogue: "consent-only PASS …, MCP key ≠ live session, vendor-doctor skip treated as Health PASS, `reload_required` as green…".
- `:81` — the primary job-to-be-done: "know which opted-in tool is mis-wired".
- `:143` — adding a key does nothing until the wiring lands.

The execution half of fail-closed is right and must stay. The **reporting** half is missing: if an operator sets `recommended_tools.search-cli` (hyphen), `searchcli`, or `omniroute` before Phase 3, the tool they believe they enabled is invisible, D10 is green, and the PRD's primary JTBD silently fails. This is structurally identical to the false-greens at `:190` — a PASS that proves nothing was probed. I-3 and I-17 locked *no installer / no FAIL*; neither requires the unknown key to be **surfaced**. The PRD should require doctor to enumerate unrecognised `recommended_tools` keys as an informational/WARN line (with the key name and "not in the allowlist; no repair available"), and state whether that line affects exit status, so that fail-closed does not become fail-silent. A test row for "opted-in unknown key is reported, not merely PASS N/A" would follow.

---

### F-7-6 — MED — "The registry" is never resolved to a single file, and it is the trust anchor for `install_commands`

**References:**

- `:24` — names `hooks/lib/recommended-tools-registry.sh` as the registry that omits `search_cli`.
- `:55`, `:381`, `:409` — Phase 1 requires "Registry + `probe-search_cli.sh`" under `scripts/lib/recommended-tools/`; no file named.
- `:58` — "project-local `install_commands` must match the repo-owned **registry pin** (`scripts/install-*-sb.sh` or exact pinned argv/digest)".
- `:202`, `:252`, `:313` — Setup/F6/blast-radius all route command trust through "the repo-owned registry pin".
- `:149` — the versioned brew formula pin is "recorded in `docs_pin` / registry".
- `:435` — Phase 3 requires an Omni "registry entry" with the same ambiguity.

The PRD mentions exactly one concrete registry path (`hooks/lib/…`, in the *hooks* tree) while every Phase-1/Phase-3 instruction lives in the *scripts/reconciler* tree, and the security-critical clause (I-34) says only "repo-owned registry pin". Three implementations are compliant: extend the hooks registry, create a new reconciler-side registry, or keep the pin inline in each probe. Worse, "repo-owned" is satisfied by any file in the repo — including one generated from or merged with project config — which would quietly re-open the tampered-payload hole I-34 was filed to close. The PRD should name the file that owns the pinned argv/digest and the versioned formula, state that it is a source-controlled repo artifact never merged with project-local JSON, and say whether the hooks registry and the reconciler registry are one file or two (and which is authoritative when they disagree).

---

### F-7-7 — MED — Absent keys, downstream configs, and reconciler-state migration are undefined; only `null`/`false` is covered

**References:**

- `:147` — "`enabled_by_user` null in the SB repo"; "D10 still uses `enabled_by_user`: opted-out → PASS N/A".
- `:213` — "Not opted in (`enabled_by_user` null/false) → **PASS N/A** (`pending`/`disabled`)."
- `:23` — the seven keys enumerated are the keys in **this repo's** `.silver-bullet.json`.
- `:132-136` — `RT_COMPONENT_IDS` is hardcoded; Phase 1 (`:408`) and Phase 3 (`:434-435`) add ids to it.
- `:363-387` — inventory tables assume the key exists.

Every opt-out rule is written against a key that exists with `null`/`false`. Silver Bullet is installed into downstream projects whose `.silver-bullet.json` predates `search_cli` (and certainly predates `omniroute`), so the key will frequently be **absent**, not null. The PRD never says absent ≡ opted-out, and never says whether doctor/reconciler should scaffold the key, warn, or ignore it. Adding an id to `RT_COMPONENT_IDS` also changes the component set the reconciler enumerates and records state/consent for; nothing addresses whether existing reconciler state, receipts, or consent records need migration, or whether an unknown-to-old-state component id is a first-run `pending` (the desired outcome) or an error on upgrade. The PRD's own upgrade-path concern is otherwise well handled, so this is a real hole rather than an out-of-scope operational detail. It is not I-3/I-17 (unknown *ids*, i.e. keys present but unallowlisted) — this is the inverse: allowlisted ids with **no key**.

---

### F-7-8 — MED — AC 8 conflicts with NF4 and omits derived-surface regeneration, so "done" can mean a red tree

**References:**

- `:294` (NF4) — "After SKILL edits: `bash scripts/sync-codex-package.sh` (**and plugin command stubs if doctor command text changes: `bash scripts/generate-plugin-commands.sh`**). Do not hand-edit generated mirrors."
- `:535` (AC 8) — "`test-silver-doctor.sh` and `test-reconcile-recommended-tools.sh` green … SKILL synced via `scripts/sync-codex-package.sh`." No mention of `generate-plugin-commands.sh` or of any freshness/parity check.
- `:496` — "Do not require `bash tests/run-all-tests.sh` for every probe tweak; do require the two doctor/reconciler scripts green before calling the phase done."
- `:410`, `:422`, `:528` — Phase 1 adds a SKILL D10 row and coverage-table columns; Phase 2 adds an executable `/sb:doctor` alias; both change doctor command text and surfaces.
- `:486-494`, `:614-623` — targeted commands and the paste prompt likewise name only `sync-codex-package.sh`.

NF4's conditional ("if doctor command text changes") is guaranteed to fire: the coverage table, the `--fix=packages` example, and the `/sb:doctor` alias all change doctor-facing command text. AC 8 nevertheless closes Session A on two test scripts plus one sync command, and `:496` explicitly discourages the broader suite. An implementer who follows the acceptance criteria literally ships stale generated mirrors (agent bundles / plugin command stubs / skill-source), which this repo enforces separately. The PRD is internally inconsistent (NF4 requires a step AC 8 does not), and the "done when" is weaker than the repo's actual merge bar. AC 8 should either inherit NF4's conditional regeneration verbatim or name the freshness checks that must pass before Session A is called done.

---

### F-7-9 — LOW — Test-plan rows whose expectation is "FAIL **or** WARN" are not assertable

**References:**

- `:481` — "Health URL without proving opted-in instance | **FAIL or WARN** with evidence; not Health PASS".
- `:482` — "`min_version` below pin (RTK / CM / LeanCTX) | **FAIL or WARN** per existing probe; Graphify skill vs package skew → WARN".
- `:418` — Phase 2: "Version skew: **FAIL or WARN** on `min_version`".
- `:190` — the false-green catalogue names "health URL without proving the daemon is the opted-in instance" as a defect to close.
- Charter goal 2 — "untestable 'done when'".

Two of the false-green catalogue's five entries are converted into test rows whose expected value is a disjunction, so no assertion can be written: a run that WARNs and a run that FAILs both pass. "Per existing probe" defers to code the PRD elsewhere refuses to treat as source of truth. Additionally, `:481` names no **mechanism** for proving that a responding health URL belongs to the opted-in instance (agentmemory `:3111` is the concrete case at `:116`/`:368`) — without an identity signal there is nothing to assert either way. Fixing this needs a per-tool decision (RTK/CM/LeanCTX min_version: FAIL; Graphify skew: WARN — already locked at `:552`) and one sentence on how instance identity is established, or an explicit statement that `:481` is a WARN-only advisory.

---

### F-7-10 — LOW — The `DOCTOR_FIX_APPLIED` early-return is not reconciled with the new convergence requirement

**References:**

- `:157` — "No-op unless `DOCTOR_FIX=1`. `--dry-run` returns without writes. **Already-applied flag returns.**"
- `:159` — Session A must close the first-match `break` so one invocation converges all eligible failures.
- `:244` — "must **not** set `DOCTOR_FIX_APPLIED=1` on empty JSON, failed apply, or malformed apply JSON."
- `:245` — "Verify-mode probe during checks; apply only under `--fix`; **re-run checks after apply**."
- `:246` — second `--fix` on a converged fixture is idempotent.

The PRD gives `DOCTOR_FIX_APPLIED` two jobs that now conflict: honesty about whether the reconciler apply succeeded (`:244`) and a guard that makes `doctor_apply_fixes()` return early (`:157`). With re-run-after-apply (`:245`) plus convergence (`:159`), a repair that only becomes reachable after an earlier repair (the "dependency order" case) may be blocked by the flag on the second pass — or, conversely, an implementer may drop the guard and produce an unbounded apply loop. Neither behaviour is specified, and neither the idempotency criterion (`:246`) nor the two-failure fixture (`:463`) distinguishes "converged in one pass" from "guard suppressed the second pass". The PRD should state whether convergence is a single ordered pass or a bounded fixpoint loop (and its iteration bound), and what role the already-applied flag plays inside one invocation versus across invocations.

---

### F-7-11 — LOW — Tests assert "with evidence id" but no evidence-id vocabulary is defined

**References:**

- `:214` — "Opted in on a supported host, missing CLI/MCP/config → **FAIL** `D10-<tool>` **with evidence**."
- `:233` — coverage-table column `Diagnosis` = "Evidence ids / typical FAIL text".
- `:457` — test row: "Opted-in, CLI/MCP missing | FAIL `D10-<tool>` **with evidence id**".
- `:105` — the only concrete evidence id in the document: `no_five_tool_consent`.
- `:103`, `:141`, `:437`, `:460` — advisory/skip/platform/busy evidence is described in prose ("warning evidence", "unsupported package manager", "recorded skip") with no identifier.

One evidence id is named; the rest are prose. Tests that assert on evidence ids (`:457`) and a coverage-table column that must list them (`:233`) cannot be written consistently, and different probes will invent divergent strings for the same conditions (provider missing, version drift, brew unavailable, vendor-doctor skipped, daemon busy, provider expired). Since the coverage table is the "done artifact" (`:54`) and Diagnosis is one of its nine columns, a short canonical id list — or an explicit naming convention plus the requirement that every table row's Diagnosis cell uses it — belongs in F4.

---

### F-7-12 — NIT — Repo-root-relative links resolve incorrectly from `.planning/`, and three link targets are files the PRD says do not exist

**References:**

- `:5`, `:53`, `:115-124`, `:347-355` and ~78 inline links total use repo-root-relative hrefs (`skills/silver-doctor/SKILL.md`, `scripts/sb-doctor.sh`, `docs/GRAPHIFY.md`, …) from a document living in `.planning/`, so they resolve to `.planning/skills/…`, `.planning/scripts/…`, `.planning/docs/…`. (`.planning/scripts/` exists but contains only `phase-lock.sh`; `.planning/docs/` does not exist.)
- `:341` — links `[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)` in the same sentence that states "There is **no** repo-root `docs/TROUBLESHOOTING.md` today".
- `:355` — links planned `docs/OMNIROUTE.md`; `:409` links `probe-search_cli.sh`, both stated as not existing (`:126`).
- `:24` — link text is `scripts/lib/recommended-tools/probe-search_cli.sh` but the href is the directory `scripts/lib/recommended-tools/`; `:53` does the same for `probe-*.sh`.

I-26 (F-3-3) accepted the principle that links from this file must resolve from `.planning/` and fixed the freeze links to sibling paths; the same fix was never applied to the other ~78 links. Deliberately linking not-yet-existing files is defensible as an implementer target, but doing it in the same sentence that denies their existence (`:341`) reads as a contradiction, and the text/href mismatch at `:24`/`:53` is straightforwardly wrong. Cosmetic only — no contract impact.

---

### F-7-13 — NIT — The test-plan preamble scopes the table per-tool, but most rows are global

**References:**

- `:452` — "For **each newly covered tool** (minimum: `search_cli`; then Omni; plus at least one existing five-tool `--fix` fixture):" followed immediately by the table.
- `:464` (`/sb:doctor` alias), `:473` (failed/malformed apply), `:477` (unknown component id), `:479` (stale checks.sh canary), `:480` (`reload_required`), `:483` (non-interactive `--fix`), `:484` (Phase 3 report test) — none are per-tool cases.
- `:460`, `:462`, `:469`, `:470`, `:471` — `search_cli`-specific rows sit in the same table.

Three row classes (per-tool, tool-specific, global-invariant) share one table under a per-tool preamble. A literal reading multiplies global rows across tools (an alias test per tool, a stale-loop canary per tool); a loose reading risks skipping a per-tool instantiation of `--fix=<scope>` or opted-out N/A for the second newly covered tool. Splitting the table, or tagging each row `per-tool` / `global`, removes the ambiguity. Also note `:460`'s expectation embeds a conditional ("skipped if `rt_scope_includes_component` omits `search_cli`") that describes the bug the row is meant to prevent rather than a pass condition.

---

## Severity count

| Severity | IDs | Count |
|---|---|---:|
| HIGH | F-7-1, F-7-2 | 2 |
| MED | F-7-3, F-7-4, F-7-5, F-7-6, F-7-7, F-7-8 | 6 |
| LOW | F-7-9, F-7-10, F-7-11 | 3 |
| NIT | F-7-12, F-7-13 | 2 |

**Total: 13.**

---

## De-duplication statement

No item from I-1…I-51 was intentionally re-filed. Nearest neighbours and the distinction in each case:

| New | Nearest prior | Why it is new |
|---|---|---|
| F-7-1 | I-18 (`cross_tool` row), I-4 (test rows) | Those add specific rows; F-7-1 is the absence of any executable key-set parity assertion across config / allowlist / registry / dispatch, and its absence from the test plan and every AC. |
| F-7-2 | I-45 (`--fix=all` converges) | I-45 fixed convergence semantics for the reconciler + legacy sequence; F-7-2 is the undefined scope → legacy-check eligibility map that I-45 made load-bearing. |
| F-7-3 | I-37 (provider-missing WARN), I-51 (version WARN), I-50 (busy/expired WARN) | Those lock the *outcomes*; F-7-3 is that only one of the four has a stated route through the `:99-104` state mapping. |
| F-7-4 | I-38 (non-TTY skip), I-48 (TTY decline) | Both are individually intact; F-7-4 is the contradiction between their partial-write contracts plus the missing exit-status vocabulary. |
| F-7-5 | I-3 / I-17 (unknown id → PASS N/A, no installer) | Those govern *execution*; F-7-5 concerns *visibility* — an unrecognised opted-in key is never surfaced, creating a new false-green. |
| F-7-6 | I-34 (registry-pinned `install_commands`) | I-34 established that a pin must exist; F-7-6 is that no file is named as the pin's owner, leaving the trust anchor ambiguous. |
| F-7-7 | I-3 (unknown component id) | Inverse case: allowlisted id with the config key **absent**, plus reconciler-state migration on upgrade. |
| F-7-8 | I-5 (AC 8 phase-3 test) | I-5 added a test script to AC 8; F-7-8 is AC 8 vs NF4 on derived-surface regeneration and freshness. |
| F-7-9 | I-4 (false-green test rows) | I-4 added the rows; F-7-9 is that two of them carry disjunctive, unassertable expectations. |
| F-7-10 | I-39 (failed apply not success), I-45 | Neither addresses the `already-applied` early-return's interaction with in-invocation convergence. |
| F-7-11 | I-8 (D10 FAIL vs D22 WARN) | Different axis: no canonical evidence-id vocabulary for the Diagnosis column and the "with evidence id" assertions. |
| F-7-12 | I-26 (freeze links sibling-relative) | Same principle, unapplied to the other ~78 links; plus text/href mismatches and links to files denied in the same sentence. |
| F-7-13 | I-21 / I-25 (merge duplicate rows) | Structural scoping of the whole table rather than duplicate rows. |

---

## Charter compliance

- **REVIEW-ONLY honoured.** No edit to `.planning/PRD-silver-doctor-opt-in-coverage.md`; PRD SHA unchanged at `67b7fb32…` after this review. No triage, no disposition, no PASS claim, no ladder advancement.
- **Scope honoured.** Only the PRD and the ladder directory were read. The freeze plan was not opened; it is referenced solely through cross-links already present in the PRD (`:5`, `:11`, `:72`, `:258`, `:517`). No doctor code, probes, tests, hooks, `.silver-bullet.json`, or `site/` files were opened. No `git checkout` / `git switch` / `SetActiveBranch`. No commits.
- **Only file written:** `.planning/rfl-prd-silver-doctor-opt-in-coverage-20260828/rung-07-pi-claude-opus-5-high/review.md`.
- **No subagents launched. No Fast model or Fast effort.**
- **Graphify:** query attempted first as required; the tool is currently unusable in this checkout (`graphify-out/graph.json` missing; only `graph.json.corrupt-20260828T1201` present). Recorded in agentmemory. This is an environment defect, not a scope decision, and is out of scope to repair here.
- **agentmemory:** non-secret rung-start note saved.

**Verdict statement: NOT CLEAN.** Worst finding: **F-7-1 (HIGH)** — the config↔allowlist↔SKILL parity assertion that would close the PRD's stated root cause is required only in F4 prose, is absent from the test plan and all acceptance criteria, and covers only SKILL rows; **F-7-2 (HIGH)** is a close second because closing the `--fix` `break` without a scope→check eligibility map can widen `--fix=local` blast radius under a no-rollback policy.
