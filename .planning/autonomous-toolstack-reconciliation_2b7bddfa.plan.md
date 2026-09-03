---
name: autonomous-toolstack-reconciliation
overview: Consolidate Silver Bullet’s installer, `/silver:init`, `/silver:update`, SessionStart, and `/silver:doctor` around one consent-aware, host-aware five-tool reconciliation engine. The engine will install, verify, repair, and report Graphify, agentmemory, RTK, Context Mode, and LeanCTX without duplicate ownership or false health claims.
todos:
  - id: reconciler-contract
    content: Implement the shared consent-aware probe/reconcile engine and structured state contract.
    status: pending
  - id: graphify-worktrees
    content: Repair Graphify MCP packaging, atomic MCP merge, and worktree-local index bootstrap.
    status: pending
  - id: route-ownership
    content: Enforce deterministic host resolution, RTK-exclusive shell ownership, and SB/global heartbeat arbitration.
    status: pending
  - id: installer-init-update
    content: Integrate reconciliation into the Cursor installer, `/silver:init`, `/silver:update`, and SessionStart.
    status: pending
  - id: doctor-repair
    content: Make `/silver:doctor` read-only by default and add complete five-tool diagnosis, bounded repair, and reload receipts.
    status: pending
  - id: tests-docs-mirrors
    content: Add regression/E2E coverage, update canonical docs, regenerate mirrors, and run release-quality validation.
    status: pending
isProject: false
---

# Autonomous Five-Tool Toolstack Reconciliation

## Review-fix-ladder record

- Scope: this plan only.
- Rung: GPT-5.6 Sol High, high reasoning, single rung.
- Accepted findings `RFL-P1`–`RFL-P9`: repair authorization, doctor mode semantics, suspended state, reload receipt lifecycle, bridge heartbeat contract, agentmemory and Context Mode negative tests, no-op idempotency, generated-mirror mapping, and absolute artifact links.
- Earlier `verify_1` runs exposed missing host-evidence transport, authorization, worktree receipt isolation, partial activation, and negative-test details. Those contracts were corrected.
- An earlier `verify_2` exposed an omitted `/silver:update` repair path and ambiguous partial-activation state mapping. Those contracts were corrected.
- Orchestrator checks then detected literal LeanCTX compression markers inserted by prior fix passes. The corrupted plan was discarded and deterministically rebuilt from the reviewed contract.
- Recovery verification previously produced two separate clean verify-only passes and clean orchestrator signals before this ledger correction. Final post-edit pass status is reported in the session closeout rather than written back here, avoiding a self-referential edit after verification.

## Delivery, scope, and ship path (clarified)

Resolved by interactive `/silver:clarify` — see [clarify brief](autonomous-toolstack-reconciliation_2b7bddfa-CLARIFY-260717-20260717T075811Z.md).

- Phased delivery in three phases, each independently reviewable:
  - Phase A — Sections 1-3: canonical engine, Graphify + worktree indexing, route/hook ownership and heartbeat. This lands the live-regression fixes first.
  - Phase B — Sections 4-7: installer, `/silver:init`, `/silver:update` + SessionStart, `/silver:doctor`.
  - Phase C — Sections 8-10: reload receipts + host evidence, tests, docs + mirrors.
- Host scope: Cursor only for this implementation. The engine contract stays host-neutral, but only Cursor paths are implemented and verified now; Claude and Codex parity are deferred.
- Ship path: merge to `main` without a version bump or plugin release. Global CI on `main` still runs but is not a merge blocker under the validation bar below.
- Validation bar per phase: new/focused five-tool tests plus `bash -n` syntax checks and ShellCheck where available. Run the full [`tests/run-all-tests.sh`](tests/run-all-tests.sh) once before the final merge, not per phase.
- Section 10 scope: docs correctness and mirror-freshness work are in scope now; the plugin release, 100% `site/**` review, tag, and CI-green release gates are deferred until a release is actually cut.

## Goals and invariants

- Preserve explicit per-tool consent. SB may install or repair a tool only when `enabled_by_user:true`; pending, opted-out, and suspended tools are never mutated.
- Make one implementation authoritative. Skills collect consent and present outcomes; scripts perform deterministic probing, planning, repair, and state derivation.
- Enforce one route owner: LeanCTX owns wire/read/PathJail/injection; Context Mode owns grep/slice/web fetch; RTK exclusively owns shell rewriting; Graphify owns graph retrieval; agentmemory owns capture.
- Use canonical states `unsupported`, `disabled`, `pending`, `suspended`, `failed`, `reload_required`, `repairable`, and `ready`.
- Keep `/silver:doctor`, `/silver:doctor --deep`, and all `verify`/`plan` reconciler calls read-only. Authorized apply paths are `/silver:init`, `/silver:update`, installer reconciliation, and `/silver:doctor --fix`.
- Treat Cursor MCP reload as an external host action. SB may repair packages and configuration, but it must not claim a server is live until the current Cursor session exposes and successfully invokes its expected tools.

## 1. Build the canonical reconciliation engine

- Add [`scripts/reconcile-recommended-tools.sh`](scripts/reconcile-recommended-tools.sh) with:
  - `--project-root`, `--host`, `--mode verify|plan|apply`, `--scope project|host|packages|all`, and `--format text|json`.
  - A versioned JSON result containing component ID, consent, canonical state, activation detail, configured/live evidence, repairability, planned or attempted actions, failures, and `restart_required`.
  - Runtime resolution through [`hooks/lib/runtime-paths.sh`](hooks/lib/runtime-paths.sh), never by testing whether a host home directory happens to exist.
- Add reusable probes and repairs under [`scripts/lib/recommended-tools/`](scripts/lib/recommended-tools/):
  - Graphify CLI/MCP/index/platform registration.
  - agentmemory CLI/server/MCP/export/persistence/bridge.
  - RTK identity and exclusive hook ownership.
  - Context Mode runtime/MCP/hooks/rules.
  - LeanCTX CLI/MCP/prefix/disabled overlap surfaces/PathJail roots.
  - Cross-tool route, hook-order, heartbeat, receipt, and convergence checks.
- Refactor shared predicates from [`hooks/lib/recommended-tools.sh`](hooks/lib/recommended-tools.sh), [`scripts/lib/global-toolstack/common.sh`](scripts/lib/global-toolstack/common.sh), and existing gate libraries instead of duplicating health logic.

Authorization contract:

- Only the top-level reconciler is executable and parses CLI input. Component helpers are sourced/imported libraries with no executable main.
- Mutation requires `--mode apply` and exactly one `--entry-point init|update|installer|doctor-fix`.
- Missing, duplicate, empty, or unknown entry points fail closed. Supplying an entry point with `verify` or `plan` also fails closed.
- Validate mode, entry point, host, scope, canonical project root, consent, and suspension before loading any mutating helper:
  - `init` and `update`: `project|host|packages|all`.
  - `installer`: `host|packages`; `project|all` only with an explicit canonical project root.
  - `doctor-fix`: exact mapping from `--fix=local|host|packages|all` to `project|host|packages|all`.
- This boundary prevents accidental internal elevation; it is not represented as security against an adversarial local user who can directly execute repository scripts.

State and idempotency contract:

- Derive state by first-match precedence: `unsupported`, `disabled`, `pending`, `suspended`, `failed`, `reload_required`, `repairable`, then `ready`.
- Report MCP activation separately as `activation_status:none|partial|full`, with exact per-server/tool success, failure, or missing evidence.
- A matching live reload receipt or activation other than `full` forces canonical `reload_required`. `partial` is detail, never a canonical state. `ready` requires full activation and no matching receipt.
- Suspended tools permit probes and reporting only; prohibit package, config, hook, index, mirror, heartbeat, receipt, and cleanup mutations.
- Use atomic writes, backups, no-follow checks, per-scope locks, and bounded timeouts.
- A no-op apply must not rewrite configuration, backups, receipts, receipt timestamps, or state files. Normalize volatile probe timestamps, durations, process/session IDs, and transient output out of convergence comparisons. Heartbeats update only when their cadence is due.

## 2. Repair Graphify packaging and worktree indexing

- Change Cursor-capable install commands in [`templates/silver-bullet.config.json.default`](templates/silver-bullet.config.json.default), [`skills/silver-init/SKILL.md`](skills/silver-init/SKILL.md), and [`skills/silver-init/references/recommended-tools-opt-in.md`](skills/silver-init/references/recommended-tools-opt-in.md) to install `graphifyy[mcp]`.
- Detect uv/pipx base-only installations and upgrade them without inventing a version. Require both `graphify` and `graphify-mcp`, plus a successful MCP stdio handshake, before writing Cursor MCP configuration.
- Rewrite [`scripts/lib/global-toolstack/patch-mcp.py`](scripts/lib/global-toolstack/patch-mcp.py) as one in-memory, atomic merge that preserves unrelated servers and cannot lose Graphify while merging LeanCTX.
- Treat [`graphify-out/`](graphify-out/) as worktree-local ignored cache:
  - Resolve roots with `git rev-parse --show-toplevel`, supporting normal `.git` directories and worktree `.git` files.
  - Build a missing index only for consented, unsuspended Graphify and only through an authorized apply path.
  - Use a per-worktree lock and a bounded `graphify update . --no-cluster`; never retry unbounded after timeout.
  - Reject a symlinked graph directory and report stale build commit or tracked sources newer than the graph.
- Refresh stale Graphify platform artifacts after package upgrades so installed rules/skills match the package version.

## 3. Make route ownership and bridge arbitration deterministic

- Update [`scripts/optimize-five-tool-stack.sh`](scripts/optimize-five-tool-stack.sh), [`scripts/install-leanctx-sb.sh`](scripts/install-leanctx-sb.sh), and [`scripts/optimize-rtk-context-mode.sh`](scripts/optimize-rtk-context-mode.sh) to require the reconciler’s explicit host and target project.
- Assert all ten `five_tool_routed` owners and exactly one shell owner:
  - LeanCTX: `sb_wire`, `sb_read`, `sb_pathjail`, `sb_injection`.
  - Context Mode: `sb_grep`, `sb_slice`, `sb_webfetch`.
  - RTK: `sb_shell`.
  - Graphify: `sb_graph`.
  - agentmemory: `sb_remember`.
- Keep LeanCTX tools prefixed `lctx_`; disable its shell, sandbox, fetch, and FTS surfaces when Context Mode and RTK are active.
- Make [`scripts/lib/global-toolstack/patch-hooks.py`](scripts/lib/global-toolstack/patch-hooks.py) and [`scripts/lib/global-toolstack/fix-shell-compression-hook.py`](scripts/lib/global-toolstack/fix-shell-compression-hook.py) enforce RTK before Context Mode and remove every `lean-ctx hook rewrite`.
- LeanCTX shell-rewrite regression (clarified: investigate, then choose the more robust option). Run a short Phase A spike into LeanCTX startup/init behavior to determine why it re-inserts `lean-ctx hook rewrite` after Cursor restarts, then implement whichever of the following two end states is more robust and record the decision plus evidence in the clarify brief and agentmemory:
  - Option 1 — remove LeanCTX shell-rewrite ownership entirely in `five_tool_routed` (preferred if it does not disable a relied-upon LeanCTX capability), so the hook cannot be re-inserted at all.
  - Option 2 — keep the LeanCTX observer but guarantee RTK-first ordering and idempotent per-session self-heal that runs after any LeanCTX startup observer.
  - Either way, RTK remains the sole `sb_shell` owner and LeanCTX retains only `sb_wire`, `sb_read`, `sb_pathjail`, and `sb_injection`.
- Remove LeanCTX’s startup shell ownership where possible per the spike outcome. Keep [`scripts/lib/global-toolstack/session-bootstrap.sh`](scripts/lib/global-toolstack/session-bootstrap.sh) as a read-only final verifier unless invoked through authorized reconciler apply.

Heartbeat contract:

- Replace marker-only global deferral with schema-v1 heartbeats at `${SB_RUNTIME_STATE}/recommended-tools/heartbeats/<project-id>/<worktree-id>/<session-id>.json`; path resolution is owned by [`hooks/lib/runtime-paths.sh`](hooks/lib/runtime-paths.sh).
- Store canonical project/worktree roots and stable IDs, host, nonempty current session ID, bridge version, `sb_initiated`, consent summary, suspension state, `written_at`, and `expires_at`.
- Only [`hooks/session-start`](hooks/session-start) and the active SB bridge write heartbeats.
- Write atomically under a per-worktree lock at eligible SessionStart and at most once per 60 seconds; use a five-minute TTL.
- Global project gates defer only for an unexpired, schema-valid heartbeat matching project, worktree, host, session, consent, `sb_initiated:true`, and unsuspended state.
- Expired, malformed, copied, mismatched, or suspended heartbeats never cause deferral. Authorized apply may remove invalid files; bounded cleanup removes expired files older than 24 hours and never runs for suspended or verification-only calls.
- Machine-level compression and restart verification never defer to the SB bridge.

## 4. Integrate the SB installer

- Extend [`scripts/install-cursor.sh`](scripts/install-cursor.sh) to deploy the reconciler, probes, global repair framework, and current host snapshots on every fresh install and upgrade.
- Do not install optional third-party packages without project consent.
- When an explicit project root is supplied, reconcile already-consented tools; otherwise deploy host infrastructure and report project work as pending.
- Verify Cursor plugin identity, hook registration, host config syntax, and global/SB arbitration.
- Batch MCP and hook writes, then emit one reload receipt rather than multiple restart prompts.
- Make [`scripts/install-recommended-tools-cursor.sh`](scripts/install-recommended-tools-cursor.sh), [`scripts/install-global-toolstack.sh`](scripts/install-global-toolstack.sh), and [`scripts/lib/global-toolstack/install-body.sh`](scripts/lib/global-toolstack/install-body.sh) delegate to the reconciler.
- Keep ownership explicit: global infrastructure owns binaries, MCP, global hooks, and global rules; SB owns project consent, project index/export state, freshness, and workflow gates.

## 5. Make `/silver:init` convergent and complete

- Refactor [`skills/silver-init/SKILL.md`](skills/silver-init/SKILL.md) so Phase 1 gathers consent and delegates all install/verification work to the reconciler.
- Bring LeanCTX into the executable flow, not only its reference file. Persist all five consent values and install outcomes atomically.
- Invoke [`scripts/optimize-five-tool-stack.sh`](scripts/optimize-five-tool-stack.sh) when LeanCTX is enabled.
- Remove duplicate host-detection pseudocode and select the host-specific merger deterministically; Cursor uses [`scripts/lib/install-cursor/merge-cursor-hooks.py`](scripts/lib/install-cursor/merge-cursor-hooks.py).
- On fresh and update-mode init:
  - Reconcile every opted-in tool, including incomplete installations that superficially appear healthy.
  - Build the current worktree’s missing Graphify index.
  - Repair SB bridge registration before allowing global project gates to defer.
  - Preserve consent and isolate failures so one tool does not disable unrelated tools.
  - Resume after reload without re-prompting or reinstalling healthy components.
- Completion output reports configured, live, reload-required, suspended, and failed tools separately. It never claims full toolstack enforcement while live MCP evidence is pending.

## 6. Extend `/silver:update` and SessionStart

- Add LeanCTX retry and full host snapshot reconciliation to [`skills/silver-update/SKILL.md`](skills/silver-update/SKILL.md).
- Refresh deployed global scripts, rules, hooks, and MCP merge behavior after every SB plugin update.
- Make [`hooks/session-start`](hooks/session-start) verification-only:
  - Detect hook ownership drift and a missing worktree Graphify index, but do not repair them.
  - Emit structured directions to `/silver:init`, `/silver:update`, installer reconciliation, or `/silver:doctor --fix`.
  - Write only an eligible heartbeat under Section 3’s bounded exception.
  - Request receipt verification without creating, clearing, superseding, or persisting receipt state.
- SessionStart may supply host MCP evidence only if its environment actually invoked every expected tool. If it cannot call host tools, it reports liveness as unproven and never fabricates evidence from config, process, discovery, or stdio state.

## 7. Make `/silver:doctor` authoritative and truthful

- Refactor [`scripts/sb-doctor.sh`](scripts/sb-doctor.sh):
  - Default and `--deep` are read-only; `--deep` adds only bounded expensive probes.
  - `--dry-run` maps to reconciler `plan` and never mutates.
  - Only `--fix=local|host|packages|all` maps to `doctor-fix` apply.
- Replace D10’s consent-only report and nonexistent helper call with full reconciler results for all five tools.
- Diagnose:
  - Graphify CLI/MCP extra, stdio, platform version, worktree index, and staleness.
  - agentmemory CLI, server health, host MCP tools, export root, persistence, bridge, and gitleaks.
  - Context Mode Node/runtime version, MCP tools, hooks, rules, workspace shadowing, and upstream doctor.
  - LeanCTX CLI, `lctx_` namespace, disabled overlaps, PathJail root, and rewrite recurrence.
  - RTK identity, allow-list rewrite behavior, sole shell ownership, and order before Context Mode.
  - Ten route owners, parity, heartbeat validity, and absence of an enforcement vacuum.
- Replace first-failure repair with bounded, dependency-ordered convergence and honest action failures.
- Version JSON output with evidence, actions, remaining failures, activation status, receipts, and restart requirement while preserving existing text and exit compatibility.
- Update [`skills/silver-doctor/SKILL.md`](skills/silver-doctor/SKILL.md) and its stale check catalog.

## 8. Implement reload receipts and live host evidence

Receipt lifecycle:

- The reconciler exclusively creates, supersedes, verifies, persists activation state to, clears, and deletes receipts.
- Store independent project/worktree receipts at `${SB_RUNTIME_STATE}/recommended-tools/reload-receipts/<host>/<project-id>/<worktree-id>/<receipt-id>.json`, resolved through [`hooks/lib/runtime-paths.sh`](hooks/lib/runtime-paths.sh).
- A different worktree must never stale, supersede, update, clear, clean up, or delete another worktree’s receipt.
- For host-global changes with known active scopes, create linked per-scope receipts sharing `change_set_id`. Otherwise create `${SB_RUNTIME_STATE}/recommended-tools/reload-receipts/<host>/_host-global/_host-global/<receipt-id>.json`; only an authorized `host|all` apply on that host may mutate it.
- Store schema version, receipt scope, random receipt ID and cryptographic nonce, optional change set, identities, writer entry point, pre/post canonical config hashes, affected servers, expected tools, session/process provenance when observable, activation detail, predecessor metadata, and required user action.
- Supersede or stale only receipts with the same exact identity and change lineage. Identity mismatch makes a receipt ineligible, not stale. A no-op apply never refreshes it.

Host-evidence transport:

- Add `--host-evidence-stdin`. Accept exactly one UTF-8 JSON object of at most 64 KiB; reject oversized input, trailing documents, or trailing non-whitespace data. Never accept the attestation via arguments, environment variables, or a long-lived evidence file.
- The skill creates a schema-v1 attestation immediately after real current-session tool calls. It includes receipt ID/nonce/scope, host, project/worktree identity, trusted session ID, current config hashes, `observed_at`, and an exact server/tool result set with bounded success or failure evidence.
- Treat the attestation as liveness evidence only. It conveys no consent, caller identity, scope, or repair authorization.
- Under a locked receipt read, validate exact ID, nonce, scope, identities, host, independently obtained nonempty current session, expected server/tool set without duplicates or omissions, result shape, current and expected hashes, age no more than 120 seconds, and future skew no more than 15 seconds.
- Reject malformed schema/types, missing receipt, wrong ID/nonce/host/scope, oversized or trailing stdin, stale/future time, empty or mismatched session, hash mismatch, replay after receipt consumption or same-key supersession, duplicate IDs, and unexpected or missing tools.
- Structurally valid tool failures are accepted as partial liveness evidence, not rejected attestations.
- `verify` and `plan` consume evidence only in memory and report canonical `reload_required`, activation detail, and `clear_eligible` without writes.
- A later authorized apply requires a fresh valid attestation. It persists `none|partial` evidence while retaining canonical `reload_required`, or atomically clears the receipt only when every expected tool succeeds; only the absent receipt then permits `ready`.
- When config is repaired but Cursor is stale, report `CONFIGURED: yes`, `LIVE: no`, and `ACTION: Tools & MCP → graphify off/on, then start a new chat; fallback Developer: Reload Window`.

## 9. Add regression and acceptance coverage

- Extend:
  - [`tests/scripts/test-recommended-tools-policy.sh`](tests/scripts/test-recommended-tools-policy.sh)
  - [`tests/scripts/test-optimize-five-tool-stack.sh`](tests/scripts/test-optimize-five-tool-stack.sh)
  - [`tests/scripts/test-install-leanctx-sb.sh`](tests/scripts/test-install-leanctx-sb.sh)
  - [`tests/hooks/test-five-tool-mutual-exclusion.sh`](tests/hooks/test-five-tool-mutual-exclusion.sh)
  - [`tests/hooks/test-session-start-recommended-tools.sh`](tests/hooks/test-session-start-recommended-tools.sh)
  - [`tests/scripts/test-install-cursor.sh`](tests/scripts/test-install-cursor.sh)
  - [`tests/scripts/test-silver-doctor.sh`](tests/scripts/test-silver-doctor.sh)
- Add direct reconciler, atomic MCP merge, worktree bootstrap, heartbeat, receipt, attestation, and target-project fixtures.
- Required lifecycle scenarios:
  - Fresh install, explicit opt-in/out, update retry, suspended install, and isolated component failure.
  - Existing base-only Graphify upgraded to MCP capability.
  - A `.git`-file worktree receives exactly one local graph build under concurrent starts.
  - Two simulated Cursor restarts retain one RTK shell owner and no LeanCTX rewrite.
  - SB bridge heartbeat active, absent, expired, cadence-limited, malformed, identity-mismatched, suspended, and repaired.
  - MCP configured, error, stale, reload-required, partial, fully live, and cleared.
  - Doctor default, `--deep`, and `--dry-run` perform no writes; authorized multi-action repair converges.
- Required component negatives:
  - agentmemory absent CLI, unhealthy server, missing MCP tools, broken export persistence, missing bridge, and missing gitleaks.
  - Context Mode missing runtime, wrong version, missing MCP registration, hook/rule drift, workspace shadowing, and failing upstream doctor.
- Required authorization and receipt cases:
  - Reject missing/unknown entry point, entry point with verify/plan, direct apply without entry point, installer project/all without root, mismatched doctor scope, and all forbidden mode/entry-point/scope combinations before mutating helpers load.
  - Create concurrent receipts for two worktrees and host-global/linked changes; prove exact selection and cross-worktree isolation.
- Required host-evidence cases:
  - Oversized or trailing stdin, malformed schema/types, missing receipt, wrong ID/nonce/host/scope, future/stale time, replay, hash mismatch, empty/mismatched session, and duplicate/unexpected/missing server/tool IDs.
  - Valid all-success evidence is clear-eligible in read-only mode but clears only under fresh authorized apply.
  - Valid bounded tool failures produce `none|partial`, retain `reload_required`, and never become ready.
- State-model fixtures prove partial activation remains `reload_required`, full read-only evidence remains `reload_required` while a receipt exists, and `ready` appears only after fresh all-success authorized apply clears it.
- A second reconciliation must be byte-stable apart from normalized volatile probe output; heartbeat changes only when cadence is due.
- Add the focused suite to [`tests/scripts/lib/five-tool-prerelease.sh`](tests/scripts/lib/five-tool-prerelease.sh).
- Validation cadence (clarified): per phase, run only the new/focused five-tool tests plus `bash -n` syntax checks and ShellCheck where available. Run the full [`tests/run-all-tests.sh`](tests/run-all-tests.sh) once before the final merge, not per phase. Remote CI on `main` still runs but is not a merge blocker under the clarified ship path.

## 10. Update canonical docs, generated mirrors, and release gates

- Correct MCP-extra and reload semantics in:
  - [`docs/GRAPHIFY.md`](docs/GRAPHIFY.md)
  - [`docs/AGENTMEMORY.md`](docs/AGENTMEMORY.md)
  - [`docs/RTK.md`](docs/RTK.md)
  - [`docs/CONTEXT-MODE.md`](docs/CONTEXT-MODE.md)
  - [`docs/LEANCTX.md`](docs/LEANCTX.md)
  - [`docs/STACK-OPTIMIZATION.md`](docs/STACK-OPTIMIZATION.md)
  - [`docs/RUNTIME-COMPATIBILITY.md`](docs/RUNTIME-COMPATIBILITY.md)
- Make source-to-mirror generation deterministic:
  - [`skills/`](skills/) → [`agents/claude/`](agents/claude/), [`agents/codex/`](agents/codex/), [`agents/cursor/`](agents/cursor/), and [`plugins/silver-bullet/skill-source/`](plugins/silver-bullet/skill-source/) via [`scripts/sync-codex-package.sh`](scripts/sync-codex-package.sh); verify with [`tests/scripts/test-render-agent-bundle-freshness.sh`](tests/scripts/test-render-agent-bundle-freshness.sh).
  - [`templates/`](templates/) → [`plugins/silver-bullet/templates/`](plugins/silver-bullet/templates/) via [`scripts/sync-templates.sh`](scripts/sync-templates.sh) and its freshness test.
  - Canonical skill frontmatter → [`plugins/silver-bullet/commands/`](plugins/silver-bullet/commands/) via [`scripts/generate-plugin-commands.sh`](scripts/generate-plugin-commands.sh) and command freshness tests.
  - Explicit manifest entries from [`scripts/`](scripts/) and [`hooks/`](hooks/) → [`plugins/silver-bullet/scripts/`](plugins/silver-bullet/scripts/) and [`plugins/silver-bullet/hooks/`](plugins/silver-bullet/hooks/) through new [`scripts/sync-runtime-mirrors.sh`](scripts/sync-runtime-mirrors.sh) regenerate/`--check` modes; enforce with new [`tests/scripts/test-runtime-mirror-freshness.sh`](tests/scripts/test-runtime-mirror-freshness.sh).
- Docs correctness and mirror-freshness work above are in scope now (clarified), independent of any release.
- After implementation edits, capture decisions through agentmemory and run `graphify update .`.
- Release gates are DEFERRED (clarified: merge to `main` without a version bump for now). Do not run these until a release is actually cut: [`scripts/pre-release-gate.sh`](scripts/pre-release-gate.sh), manual 100% review of [`site/**`](site/) for release-claim accuracy, [`tests/scripts/test-site-content-freshness.sh`](tests/scripts/test-site-content-freshness.sh), [`tests/scripts/test-site-doc-freshness.sh`](tests/scripts/test-site-doc-freshness.sh), [`tests/run-all-tests.sh`](tests/run-all-tests.sh), and green remote CI before tagging. When a release is later cut, these gates become mandatory again.






