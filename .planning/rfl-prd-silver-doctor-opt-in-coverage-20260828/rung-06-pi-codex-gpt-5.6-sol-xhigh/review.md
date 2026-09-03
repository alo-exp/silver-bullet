# Rung 06 review — Pi Codex GPT-5.6 Sol Extra High

**Phase:** REVIEW-ONLY (`rung_6_review`)  
**Target:** `.planning/PRD-silver-doctor-opt-in-coverage.md`  
**Prior-findings guard:** I-1…I-43 were treated as locked and were not re-filed.  
**Result:** 8 new raw findings. This review does not triage them or apply changes.

## Method and scope

- Ran the required Graphify query first: `graphify query "silver doctor opt-in D10 search_cli omniroute reconciler"`.
- Used a second scoped Graphify query to retrieve PRD/prior-review context.
- Read the charter, issue ledger, prior rung reviews, and all prior APPLY notes inside the locked ladder directory.
- Reviewed the complete live PRD at the post-rung-5 bytes. No doctor code, freeze plan, specs, tests, or docs were opened or edited.
- Saved a non-secret review summary to agentmemory.

## Bird's-eye review

The Session A / Session B fork remains clear, and the post-rung-5 PRD now carries the earlier trust-boundary, secret-channel, failed-apply, repair-dispatch, host, Omni-gating, and docs-pin decisions. The remaining bird's-eye gaps are narrower but still affect whether the document's completion claims are executable:

1. Phase 3 does not enumerate the reconciler registration and dispatch work that the PRD itself says every new config key requires. A Phase 3 implementation can therefore create an inert Omni key and probe while satisfying the literal phase bullets.
2. `--fix=all` is advertised as dependency-ordered convergence, but the stated current runner repairs only the first matching legacy failure and breaks. Existing acceptance language proves individual dispatch, not composed convergence with multiple simultaneous failures.
3. The public `/sb:doctor` alias is a frozen product surface, yet “done” requires only that it be documented as the same alias. No owner or executable equivalence test proves that `/sb:doctor`, its flags, and its exit/report behavior actually reach the one runner.
4. Conditional Phase 3 names Omni busy/provider conditions without assigning deterministic final statuses or repair recommendations, leaving two central four-surface outcomes implementation-defined.

## Ant's-eye review

The locked details from I-1…I-43 remain present: `search_cli` packages scope; Cursor/Claude/Codex behavior; PATH-plus-version Health; provider-missing advisory WARN; registry-pinned command trust; no secrets in stdout/stderr/JSON/receipts; failed/malformed apply nonzero; non-TTY assume-yes behavior; Omni WS6 gate/current-host CLI/deferred footnote; and SB-owned `cross_tool` docs pin.

New ant's-eye gaps are concentrated in boundaries not covered by those decisions:

- vendor-doctor skip has only a negative rule (“not Health PASS”), not an exact D10 state;
- TTY refusal/EOF and partial-write semantics are absent even though non-TTY behavior is locked;
- agent-host support and operating-system/package-manager support are conflated for a Homebrew-only `search_cli` repair;
- the static docs ref and exact command allowlist do not actually pin the version installed later by unversioned Homebrew.

## Raw findings

### F-6-1 — HIGH — Phase 3 omits the reconciler registration/dispatch work required to make Omni live

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:142` — “Adding a key … does nothing until registry + probe + `rt_run_component` + SKILL + N/A-vs-FAIL tests land.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:431-436` — Phase 3 lists the config key, `probe-omniroute.sh`, WS6 installer ownership, surfaces, opted-out behavior, and file-ownership guards.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:517-524` — acceptance requires a separate Omni component and green tests, but does not name registration or dispatch.

Phase 1 explicitly requires `RT_COMPONENT_IDS`/an extra-tool list, registry wiring, `rt_run_component`, and `rt_scope_includes_component`. Phase 3 does not require the Omni equivalents: registry entry, component allowlist registration, `rt_run_component` dispatch, or the scopes that may verify/repair it. This contradicts the PRD's own current-system rule at line 142. An implementer can follow every Phase 3 bullet and still produce an inert `recommended_tools.omniroute` key whose probe is never called and whose `--fix` action is unreachable. The missing work is distinct from I-40's WS6-installer gate and I-41's current-host CLI rule.

### F-6-2 — MED — `--fix=all` promises composed convergence that the plan and tests do not prove

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:158` — after reconciler apply, legacy doctor mutations repair the first matching failed check and then `break`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:313` — `--fix=all` promises “dependency-ordered convergence of the above.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:419-420` — Phase 2 requires one live five-tool fixture plus per-action repair dispatch.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:455-463,520` — tests prove an allowlisted fixture, idempotency, and dispatch for each advertised action, but not multiple coexisting failures.

Per-action plan/dispatch coverage (I-36) proves that each repair can be selected in isolation; it does not prove that one `--fix=all` invocation converges a fixture containing two failures across the reconciler and first-match legacy path, or two legacy failures. The stated `break` means the advertised one-command convergence may leave later failures unresolved. The PRD does not choose between (a) one invocation must converge all eligible failures in dependency order, or (b) repeated doctor invocations are expected and `--fix=all` means only “attempt the next repair.” The second-apply idempotency criterion assumes the first apply reached convergence, so this ambiguity also weakens that proof.

### F-6-3 — MED — Vendor-doctor skip has no deterministic final D10 state

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:99-103` — reconciler states map to PASS/PASS N/A/WARN/FAIL; no vendor-skip state is identified.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:121` — vendor doctor is skippable through `RT_SKIP_VENDOR_DOCTOR=1`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:234` — the F4 `N/A rule` must cover “skip vendor-doctor.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:418,467,527,540` — skip must be recorded and must not masquerade as Health PASS; a hermetic/live path proves that negative invariant.

“Not Health PASS” leaves several materially different implementations compliant: component WARN, component FAIL, PASS N/A for only the vendor subcheck while other evidence makes the component PASS, or no component result. The coverage-table schema asks for a skip rule but supplies no required value, and the test plan asserts only the negative. Because RTK, Context Mode, LeanCTX, and Alumnium can combine vendor-doctor evidence with other Health evidence, the PRD needs a per-class or per-tool final-state rule for skipped vendor doctors; otherwise operators and tests cannot know whether the same fixture should exit green, warning, or failure.

### F-6-4 — MED — The frozen `/sb:doctor` alias is documented, not proven as an executable alias

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:5` — `/sb:doctor` is the public alias of the same doctor; “One doctor.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:53` — Goal 1 repeats the public-alias requirement.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:258` — the freeze alias includes inspect plus setup/health/diagnosis/`--fix`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:446-473` — the test plan has no alias-routing/equivalence case.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:522` — AC 6 requires only that `/sb:doctor` be **documented** as the same public alias.

The acceptance criterion can pass if prose says the commands are aliases even when `/sb:doctor` is absent, points elsewhere, drops `--fix`/`--dry-run`, or forks report/exit semantics. The PRD also does not assign alias-stub generation or routing to a phase. This is a missing product slice rather than a request for a second runner: an executable contract test should prove both names resolve to the same skill/runner and forward the supported flags without creating parallel implementation state.

### F-6-5 — LOW — TTY confirmation defines when to prompt but not refusal, EOF, or partial-apply semantics

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:69` — no automatic rollback; receipt plus re-run is the recovery story.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:247,326` — packages/network/daemon restart require confirmation on a TTY; non-TTY behavior is explicit.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:309-318` — `--fix=all` can combine unattended local/host mutations with guarded package/daemon mutations.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:452-473` — no TTY accept/decline/EOF test exists.

The non-TTY branch is locked, but the human TTY branch does not define accepted input, the result of “no”/EOF/invalid input, exit status, receipt status, or whether guarded confirmation is collected before earlier `--fix=all` mutations occur. Two implementations can both “require confirmation” while one exits cleanly with no writes and another applies local/host changes, skips packages, writes a partial receipt, and exits either zero or nonzero. Given the explicit no-rollback policy, partial-apply behavior must be observable and testable rather than incidental.

### F-6-6 — LOW — `search_cli` host support is defined by agent host but not by OS/package-manager capability

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:140` — calls `search_cli` a “host-agnostic brew CLI.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:148` — the documented installer is `brew tap … && brew install search-cli`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:177-181,213,235` — Cursor, Claude, and Codex are unconditionally supported for D10.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:406-410,456` — Phase 1 and its repair proof use the Brew path.

Cursor/Claude/Codex identify the agent host, not the operating system or availability of Homebrew. The PRD therefore requires missing-CLI FAIL and advertises a bounded package repair on every one of those hosts without defining macOS/Linux/other-platform support, behavior when `brew` itself is absent, or the N/A/FAIL/diagnosis boundary for an unsupported package platform. “Host-agnostic brew CLI” hides this second matrix. This need not authorize another installer, but the coverage table and tests need a deterministic platform/package-manager contract so fail-closed behavior does not become a misleading repair suggestion.

### F-6-7 — MED — Omni busy/provider-expired conditions lack status and repair mappings

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:59,85` — `chat_admission_busy` and provider diagnosis are central Omni outcomes.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:259-261` — checks include provider active versus expired, and busy-class is Omni daemon Health.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:433` — Phase 3 says Health includes daemon ping/busy-class and Diagnosis distinguishes provider expiry, while `--fix` only installs/restarts and OAuth remains manual.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:448-473` — generic new-tool cases do not assert busy, provider-expired, or manual-remediation outcomes.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:523` — AC 7 names busy-class and manual OAuth but no expected statuses.

The PRD does not say whether a responsive but saturated daemon is PASS-with-diagnosis, WARN, or FAIL, nor whether an expired provider is WARN, FAIL, `repairable`, or a manual-action state. It also does not say whether `--fix` may restart on busy, must only recommend tuning `OMNIROUTE_CHAT_MAX_HEAVY_IN_FLIGHT`, or must avoid suggesting an automated fix for expired OAuth. These choices affect exit status, evidence, receipt text, and the “only OAuth stays manual” boundary. Phase 3 cannot have deterministic four-surface tests until those mappings are locked.

### F-6-8 — MED — The `search_cli` docs pin can drift from the version installed by the pinned command

**References:**

- `.planning/PRD-silver-doctor-opt-in-coverage.md:148` — install command is unversioned `brew install search-cli`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:289` — Homebrew/npm installs are described as “pinned in those scripts.”
- `.planning/PRD-silver-doctor-opt-in-coverage.md:338-339` — identify the installed/target version and consult version-matched docs at `URL@ref`.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:406` — consult search-cli at the formula/version SB documents.
- `.planning/PRD-silver-doctor-opt-in-coverage.md:410,456` — tests prove a registry-pinned command/Brew pin.

I-34 correctly closes command-payload authorization, but exact authorization of the argv `brew install search-cli` does not pin the package version that Homebrew resolves at a later date. A static `docs_pin` can therefore describe version N while the same accepted command installs N+1, violating F3's version-matched rule without tripping the tampered-command test. The PRD needs to distinguish a trusted command pin from an artifact/version pin and define how the installed/targeted formula version is tied to the recorded docs ref (or how drift is detected and reported).

## Severity count

| Severity | Findings | Count |
|---|---|---:|
| HIGH | F-6-1 | 1 |
| MED | F-6-2, F-6-3, F-6-4, F-6-7, F-6-8 | 5 |
| LOW | F-6-5, F-6-6 | 2 |
| NIT | — | 0 |

No prior I-1…I-43 item was intentionally re-filed. In particular, F-6-2 concerns multi-failure composition rather than per-component repair dispatch; F-6-8 concerns artifact-version drift rather than command-payload authorization; and the Omni findings do not reopen the accepted WS6 gate, current-host CLI rule, or deferred-footnote rule.
