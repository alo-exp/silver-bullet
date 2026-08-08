# Changelog

## [0.52.0] — 2026-08-08

Minor release: five-tool routed compression stack, multi-AI orchestration primitive, and a batch of hook gate-integrity fixes — several gates were failing open or blocking Stop permanently.

## Features
- `feat(tools)`: activate five-tool routed stack — graphify, leanctx, context-mode, rtk, agentmemory (`d2e45587`)
- `feat(tools)`: five-tool reconciler and Cursor install integration (`5fd2e27f`)
- `feat(multi-ai)`: multi-AI primitive, deep-research composer, Excel matrix, and personas (`0981d91e`)
- `feat(multi-ai)`: Codex/OpenCode host adapters for live deep-research dispatch (`65a1ebe2`)
- `feat(clarify)`: per-plan CLARIFY filenames and planning path helper (`d63bc165`)

## Fixes
- `fix(hooks)`: stop instruction-ledger self-enrollment — the ledger extracted every markdown bullet including lines inside code fences, so pasting an agent completion report enrolled its own summary as new pending work and Stop could never be satisfied (`c452f9df`)
- `fix(hooks)`: stop instruction-ledger and review-fix-ladder gates failing open — `jq -e` over a generator emitted nothing at zero pending nodes and exited 4, and a bare `sb_rfl_compliance_stop` under `set -e` plus `trap 'exit 0' ERR` made a deny gate return ALLOW (`8f570b37`)
- `fix(hooks)`: add a real claude arm to `sb_leanctx_hooks_present()` — the hooks-wiring check silently passed on every host except cursor and codex (`c452f9df`)
- `fix(hooks)`: site regression gate no longer wedges on a BSD `mktemp` template (`2044c86c`)
- `fix(hooks)`: stop shell-hook duplication and orphan bash leaks (`c179c509`)
- `fix(hooks)`: site session gates skip agent-delegation false positives (#244, #245) (`cb4611cf`)
- `fix(leanctx)`: resolve the claude host MCP artifact to `~/.claude/settings.json`, and correct the claude guard path that pointed at `~/.codex/CLAUDE.md` (`54ab337b`, `c452f9df`)
- `fix(leanctx)`: dedupe the lean-ctx MCP server entry on SB install (`cd702db9`)
- `fix(doctor)`: report D10-routes `cross_tool unsupported` as a platform-limitation warning instead of a FAIL recommending `--fix=host`, which could never clear it (`c452f9df`)
- `fix(tests)`: repair a BSD-first `stat` probe that wedged CI — on GNU coreutils `-f` means `--file-system` and exits 0, so the fallback never ran and `chmod` received a junk mode (`03035708`)
- `fix(ci)`: repair the graphify artifact schema failing validation on main (`8800a63a`)
- `fix(agents)`: implement `agent_delegate_append_workdir_evidence` for the delegate log floor (`da7df161`)

## Docs
- LeanCTX operating guide (`9f349618`), public site reconcile (`25eb0cb7`), shared Graphify repository artifacts (`a79ecb77`)

---

## [0.51.7] — 2026-07-12

Patch release: Cursor desktop `/silver` commands fix — hyphen-safe command filenames and install identity lock.

## Fixes
- `fix(cursor)`: desktop-safe command filenames (`silver-<route>.md` stubs with `silver:` frontmatter) — Cursor desktop rejects colon-bearing command filenames (`27d268e7`)
- `fix(cursor)`: install identity lock — VERSION-aligned cache/current/local/marketplace pins prevent registry drift claiming version N against installPath N-1
- `fix(tests)`: install-cursor and host command naming regression coverage

---

## [0.51.6] — 2026-07-11

Patch release: Cursor desktop local-plugin materialization — fixes external-symlink security rejection under `~/.cursor/plugins/local/` so `/silver` commands register after public reinstall.

## Fixes
- `fix(cursor)`: materialize commands-only local plugin surface into `~/.cursor/plugins/local/silver-bullet` instead of symlinking outside `plugins/local` — Cursor desktop rejects external symlink targets and silently skips command registration (`aeb96fd0`)
- `fix(plugin-mirror)`: restore `plugins/silver-bullet/scripts` symlink to repo `scripts/` — canonical source remains via `../../scripts` (`8418c6f5`)
- `fix(tests)`: install-cursor regression coverage for materialized local plugin directory and commands-only backend caches

---

## [0.51.5] — 2026-07-11

Patch release: permanent Cursor desktop/TUI picker fix — local plugin discovery symlink, commands-only backend caches, marketplace SHA alignment at install, D14 commands-only contract, stale custom-agent quarantine, and tagged archive/public install regression coverage.

## Fixes
- `fix(cursor)`: commands-only picker install path for desktop and TUI — symlink `~/.cursor/plugins/local/silver-bullet`, sync marketplace SHA, prune skill-source from backend caches (`66330f22`)
- `fix(cursor)`: align manifest SHA with install before verify — registry/primary/backend SHA narrowing, local plugin link as desktop discovery fallback (`a6b0c000`)
- `fix(cursor)`: enforce D14 commands-only cache validation; stop malformed `/silverui` and internal/subagent route drift in TUI
- `fix(cursor)`: stale SB custom-agent cleanup and quarantine during install
- `fix(tests)`: archive install regression tests for tagged public release paths

---

## [0.51.4] — 2026-07-10

Patch release: Cursor slash-picker deduplication and custom subagents (install, doctor D21, RFL ladder), stack double-compression recovery hardening, MultAI deep-research port (`/silver:compare`), Codex user-scope registration, and tri-host post-release verify orchestrator.

## Features
- `feat(cursor)`: SB custom subagents installer — `install-cursor.sh`, doctor **D21** (`probe-global-agents.sh` + `--fix`), silver-init §3.2.3 tri-state consent (`04cc0643`…`e9acbc18`)
- `feat(cursor)`: RFL custom subagents — 6-rung review-fix ladder, hooks, tests, skill (`1781f06f`…`9fabd95f`)
- `feat(deep-research)`: port MultAI solution-landscape and solution-compare — need-profile interview, SCR extraction, weighted matrix SPA, `/silver:compare` (`daee7db8`…`632d75d4`)
- `feat(agents)`: `silver-agent-opencode` and `silver-agent-pi` delegation surfaces (`270a9356`)
- `feat(release)`: mandatory tri-host post-release verify orchestrator (`f7733878`)

## Fixes
- `fix(cursor)`: slash picker deduplication — prune backend plugin caches, honor `.cursorignore`, commands-only registration (`1c82c174`…`a8cb0109`)
- `fix(cursor)`: harden D21 doctor probe and host-agnostic allowlists (`d3732096`, `e9acbc18`)
- `fix(stack)`: double-compression mutex recovery, SEC-01/SEC-02 hardening, doctor D20 (`e8b1ab42`, `2285ccbd`, `0c90c675`)
- `fix(codex)`: register Silver Bullet plugin with user scope (`1de5bea1`)
- `fix(commands)`: align Cursor and Codex slash routes with `silver:` colon convention (`558da475`)
- `fix(cursor)`: skip unreachable marketplace SHAs during install (`5ec45704`)
- `fix(deep-research)`: v2 audit follow-ups and Thermos hardening (`250d2ea5`…`632d75d4`)
- `fix(ci)`: regenerate APO views; restore hook executability and completion-audit alignment (`0594a821`, `4bb36750`)

---

## [0.51.3] — 2026-07-08

Patch release: tri-host RC validation matrix green (cursor/codex/claude × fresh/upgrade), Cursor hook generator repairs, Claude home-path install alignment, Codex path-rewrite scoping, LeanCTX five-tool stack foundation, and **silver-deep-research v2 engine** (omitted from initial release notes).

## Fixes
- `fix(cursor)`: hook generation, merge dedupe, marketplace gitPath, slash command materialization (`05fa57b5`…`72a4821f`)
- `fix(hooks)`: restore canonical manifest; harden Claude/Codex install (`60d4e85e`)
- `fix(install)`: scope Codex path-rewrite to plugin surfaces — stops corrupting test fixtures (`ea40b1e6`)
- `fix(rc)`: cursor delegate smoke under `set -u`; Claude first-class RC host (`6500301e`, `b5c1eed4`)
- `fix(tests)`: install-claude/codex/doctor fixtures; `record-leanctx-usage` hook coverage (`70904e7f`, `334bed8f`)

## Features
- `feat(leanctx)`: five-tool stack config, install/merge scripts, hook gates (`230310ee`…`d391e9dd`)
- `feat(testing)`: five-tool pre-release gate via agent-cursor (`55d9ad52`)
- `feat(deep-research)`: **v2 engine** — `search_orchestrator` with SB-owned `skill_portals`, `capability_score` eval harness, `validate_report` language gates, adversarial/report-block references, and July 2026 landscape replay benchmark with behavioral delta doc (`16c29403`)

---

## [0.51.2] — 2026-07-06

Patch release: semantic-compress hook test isolation, agent bundle mirror sync, Stage 4a site scan completion, and pre-release gate site freshness wiring.

## Fixes
- `fix(test)`: isolate `test-semantic-compress-hook.sh` from active repo `.planning/` E2E state (`a8403113`)

## Chores
- `chore(sync)`: regenerate agent bundle mirrors and template base after create-release skill doc sync (`a8403113`)
- `docs(site)`: complete Stage 4a public site scan — changelog, release workflow, orchestrator, enterprise status (`1315ceed`)
- `docs(site)`: wire site freshness tests into `scripts/pre-release-gate.sh` (`1315ceed`)

---

## [0.51.1] — 2026-07-06

Patch release: CI green gate enforcement, scheduler stdout leak fix, completion-audit enterprise policy alignment, and CI runner compatibility for agent/E2E structural tests.

## Fixes
- `fix(ci)`: scheduler test isolation and orchestrator join-gate stdout leak (`d659c4d7`)
- `fix(ci)`: completion-audit enterprise policy shadowing + pre-release CI gate (`45b352b6`)
- `fix(ci)`: regen `atomic-flow-index.json`, agent preflight dry-run without host CLIs, matrix grep pipefail (`2f04515d`)
- `fix(ci)`: CI-safe mktemp work-dir for minimal-intent/tri-criteria dry-runs; E2E-096 fixture seed (`d367741b`)

## Documentation
- CI policy: never tag/release on red CI (`docs/RELEASE.md`, `AGENTS.md`)

## [0.51.0] — 2026-07-06

Minor release: **tri-criteria E2E validation harness** — live/cold matrix across Cursor, Claude, and Codex; multi-workflow orchestrator scheduler; greenfield 6/6 PASS with harness drain fix.

## Features
- `feat(tri-criteria)`: live/cold validation harness and multi-WF orchestrator scheduler (`69988bda`)
- `feat(tri-criteria)`: Claude/Codex host live harness and PASS evidence (`8fb6417d`)
- `feat(tri-criteria)`: complete tri-host live matrix (cursor+claude+codex) (`97522629`)
- `feat(tri-criteria)`: greenfield 6/6 matrix PASS with harness drain fix (`d728037b`)
- `feat(autonomous-enterprise)`: agent-claude track and orchestrator scheduler (`e2da8f2b`)
- `feat(audit)`: AF/FS compliance script and full catalog audit report (`3e2b3748`)
- `feat(new-workflow)`: Audit mode for catalog compliance checks (`7a0919a5`)
- `feat(skills)`: replace silver-research/multi-ai with silver-deep-research (`7c667aef`)
- `test(tri-criteria)`: sb-tri-criteria E2E framework scaffold for three orthogonal SB proof criteria (`11de816a`)

## Fixes
- `fix(tri-criteria)`: E2E scorer false fails and runtime composition wiring (`55017821`)
- `fix(agent-codex)`: preflight graphify and agentmemory before delegate (`d4640973`)
- `fix(agent-claude)`: preflight graphify and agentmemory before delegate (`61e95c7f`)
- `fix(agent-claude)`: folder trust seeding, ephemeral trust respawn, plugin cache alias (`0b9c2fcd`–`ed0d26ac`)
- `fix(codex)`: valid PostToolUse JSON on end-user plugin install (`8ff55d3b`)
- `fix(hooks)`: include hookEventName in dev-cycle-check advisories (`864e242b`)
- `fix(catalog)`: remediate 13 WF/AF audit failures to 157/157 PASS (`26edd496`)
- `fix(minimal-intent-e2e)`: score cmd passes work_dir and evidence to orchestrator (`1293cfff`)

## Documentation
- `docs(tri-criteria)`: exhaustive raw log sweep with zero remaining findings (`66fe3f1b`)
- `docs(proof)`: integrate MI-01 minimal-intent E2E PASS at live_e2e_proven (`87e15be8`)
- `docs`: require complex multi-workflow goals for autonomous proof (`cbc7d5cf`)

## Verification
- Tri-criteria greenfield matrix — **6/6 PASS** (cursor+claude+codex)
- `bash tests/scripts/test-release-version-alignment.sh` — PASS
- `bash tests/scripts/test-silver-bullet-template-parity.sh` — PASS
- `bash tests/scripts/test-render-agent-bundle-freshness.sh` — PASS
- `test-site-content-freshness.sh` + `test-site-doc-freshness.sh` — PASS

---

## [0.50.5] — 2026-07-05

Patch release: **tri-host pre-release smoke gate** — mandatory 12/12 isolated host smoke before tag (closes v0.50.4 gap); agent-codex harness improvements; Cursor CLI smoke timeout aligned to live API latency.

## Features
- `feat(agent-codex)`: v0.2.0 harness dir, R9 learnings, pilot PASS (`5ad16128`)

## Fixes
- `fix(agent-codex)`: close sibling-prompt gaps from compliance audit (`b7d3b76e`)
- `fix(agent-codex)`: unify runtime env for direct delegate worker path (`da752ec5`)
- `fix(pre-release)`: HOST_API_KEY alias and operator `~/.silver-bullet/cursor-api-key` fallback (`7b451552`)
- `fix(pre-release)`: Cursor CLI smoke default timeout 120s → 300s for live API routing check

## Verification
- `RTK_DISABLED=1 bash scripts/run-pre-release-host-smoke.sh` — **12/12 PASS** (tri-host isolated smoke)
- `bash tests/run-all-tests.sh` — **5068 passed, 0 failed (6/6 suites green)**
- `bash scripts/run-apo-authoring-compliance.sh` — 26/26 PASS
- `test-site-content-freshness.sh` + `test-site-doc-freshness.sh` — PASS

---

## [0.50.4] — 2026-07-05

Patch release: **pre-release test hardening** — full `run-all-tests.sh` green gate (5349/5349) before ship; fixes delegation v0.50.3 fallout and version-alignment drift.

## Fixes
- `fix(tests): outcomes-check teardown clears stop-coalesce state; jq-less Stop preserves SB_RUNTIME_STATE_DIR`
- `fix(hooks): SEC-04 hardened rm -f -- in agent-delegation-state and stop-coalesce`
- `fix(tests): e2e-live suite assert_file_contains arity for clarify-picker check`
- `fix(tests): flow-step V-loop excludes catalog pseudo-skills (distribution-only, pipe-composites)`
- `fix(tests): no-gsd-runtime allowlist for legacy GSD cleanup scripts`
- `fix(validate): host-agnostic allowlist for AF-AGENT-DELEGATE skills, worker template, delegate scripts`
- `fix(release): config/site version alignment to package.json; sentinel manifest 90 skills clean`
- `fix(tests): skill scenarios for silver-agent-codex, silver-agent-cursor, silver-agent-worker`

## Verification
- `bash tests/run-all-tests.sh` — **5349 passed, 0 failed (6/6 suites green)**
- `bash scripts/run-apo-authoring-compliance.sh` — 26/26 PASS
- ShellCheck on hooks/scripts — PASS
- `test-site-content-freshness.sh` + `test-site-doc-freshness.sh` — PASS

---

## [0.50.3] — 2026-07-05

Patch release: AF-AGENT-DELEGATE migration stage 5/6 — `SB_AGENT_DELEGATE_V2` default-on, parent delegate-wrapper whitelist removed (degraded fallback only).

## Features
- `feat(delegation): SB_AGENT_DELEGATE_V2 default-on when unset; SB_AGENT_DELEGATE_V2=0 rollback` — `agent-delegation-state.sh`
- `feat(delegation): stage 6 parent guard — direct delegate Bash requires SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` — `orchestrator-parent.sh`

## Documentation
- Updated host skills, AGENT-DELEGATE worker template, and APO authoring compliance for default-on V2
- RFL close-out: `.planning/reviews/AGENT-DELEGATE-AF-RFL-CLOSEOUT.md`

## Verification
- Dual-host live smoke (unset V2) on enterprise-e2e temp branches: Cursor `502ebe0`, Codex `6ffe2d9`
- Delegation structural suite + `run-apo-authoring-compliance.sh` 26/26 PASS

---

## [0.50.2] — 2026-07-03

Patch release: Cursor-3 REAL enterprise E2E certification (22/22 strict-clean), anti-faking methodology (void Cursor-1/2), and harness fixes E2E-091–E2E-100.

## Features
- `feat(e2e/cursor): Phase A ladder + rows 3/7/8 smoke expansion drivers` (63355ec5)
- `feat(e2e/cursor): batch 2 rows 2/4/5/9 PASS; E2E-095 FORCE brownfield skip fix` (d02b8584)

## Bug Fixes
- `fix(e2e): E2E-091 clarify n/a for routing row 1; E2E-092 cursor 1800s timeout` (32231c44)
- `fix(e2e/cursor): E2E-093 stream-json log capture; E2E-094 fast-path OUT-ORCH-01 n/a` (5fa5d2fc)
- `fix(e2e): E2E-096 row 10 outcome false-negative on autonomy summary` (e1ff9580)
- `fix(e2e): E2E-097 row 14 OUT-RELEASE-01 false partial` (0420501d)
- `fix(e2e): E2E-098 matrix graphify preamble satisfies OUT-KM-01` (87c4228f)
- `fix(e2e): E2E-099 row 15 review-triad triad evidence for OUT-RELEASE-01` (e371d311)
- `fix(codex-e2e): clear pre-release blockers for enterprise-e2e/codex` (5e40e2b4)
- `fix(codex-e2e): skip absent validate-host-install-surface in prerelease harness` (365bea43)
- `fix(ci): use CI-writable enterprise E2E fixture paths in script tests` (55a67ccb)
- `fix(ci): seed silver-bullet.json in outcome assessment temp fixture` (703eaf00)

## Documentation
- `docs(e2e): register E2E-091–100 and void Cursor-1/2 in methodology` (2834fe3d)
- `docs(e2e): cursor-3 REAL 22/22 strict-clean + Phase C RCS 100` (cca0ffc0)
- Merge `enterprise-e2e/cursor` → `main` (c507f1c) — ROUND-CURSOR-3-REAL-LEDGER, cursor3 drivers, §11a + Appendix D

---

## [0.50.1] — 2026-07-02

Patch release: test harness fixes for Claude plugin manifest, install-surface validation, outcomes-check isolation, orchestrator parent guard, plugin-cache uninstall cleanup, and local Claude install materialization fallback.

## Bug Fixes
- Remove invalid `agents` field from `.claude-plugin/plugin.json` (Claude schema rejects agents)
- Source `path-canonical.sh` in `plugin-cache-guard.sh` for F-07 uninstall cleanup
- Fix `test-outcomes-check.sh` isolated state dir and `run_hook` env propagation
- Fix `test-orchestrator-non-sb-workspace-guard.sh` to use non-readonly Bash for parent block assertion
- Materialize local Claude plugin cache when `claude plugin install` cannot fetch GitHub
- Restore agent-neutral `silver-migrate` hook-merge docs with `merge-cursor-hooks` coverage
- Seed Codex workspace trust in enterprise matrix `setup_workspace`

---

## [0.50.0] — 2026-07-02

Multi-host enterprise E2E harness merge: integrates `enterprise-e2e/cursor` Phase C strict-clean fixes, Codex sibling cherry-picks from `origin/main`, and Claude/round6 harness already on main.

## Features
- `feat(e2e): install-version row pass registry (one-pass-per-version)` (89e2ab8f)
- `feat(e2e): merge host certification methodology and gate harness on main` (38102e26)
- `feat(e2e): test-app branch isolation policy and harness preflight` (00d2ff30)
- `feat(e2e): wire JSON row-pass registry with install-version skip` (9ae769be)
- `feat(core): enforce host-agnostic SB core with pre-release validator` (06485ea6)

## Bug Fixes
- `fix(e2e/cursor): Phase C driver retry + Cursor-2 strict-clean green` (5d56b2ca)
- `fix(e2e/codex): spinner-immune idle watchdog + reliable hard timeout` (158556e4)
- `fix(e2e/codex): honor matrix ROWS argv order; pin baadf87 fixture` (1f035575)
- `fix(e2e/codex): TUI-aware KM/ORCH/HEAL outcome scoring` (be769ddd)
- `fix(e2e): cherry-pick Cursor strict-clean harness from enterprise-e2e/cursor` (6f86e144)
- `fix(e2e): cherry-pick harness registry skip and outcome scoring onto main` (dca46dad)
- `fix(e2e): Gate 2 smoke fails when matrix rows SKIP` (82437f6a)
- `fix(e2e): OUT-SKILL routing row 1 pass + T1 driver` (f901f1fa)
- `fix(tests): silver-doctor --fix grep on BSD/macOS` (0cc001ad)
- `fix(tests): use grep -Fq -- for flag needles in silver-doctor` (ee74f598)
- `fix(ci): restore create-release marketplace git-add paths` (fa47e747)

## Documentation
- Merge commit `62aa0de3` — enterprise-e2e/cursor harness and Phase C matrix fixes
- Merge commit `e9146308` — Codex sibling cherry-picks from origin/main

---

## [0.49.1] — 2026-07-01

## Bug Fixes
- `fix(ci): restore create-release marketplace git-add paths` (fa47e747)
- `fix(ci): seed graphify config in outcome assessment fixture` (28527b61)
- `fix(ci): use temp fixture when enterprise app path absent` (de78be98)
- `fix(ci): allow merge-cursor-hooks refs in host-agnostic scan` (201857a3)
- `fix(ci): sync site v0.49.0 and silver-migrate Cursor hook docs` (42fb4923)
- `fix(ci): codex runtime state pinning and sb-doctor test paths` (bad9a7c9)
- `fix(ci): align bundle tests with host-bundles layout and test bugs` (33e9523d)
- `fix(ci): resolve ShellCheck warnings blocking CI on main` (54ca5029)
- `fix(release): unblock v0.49.0 CI and Claude plugin install` (066806cf)

## Tests
- `test: align recommended-tools contracts with skill reference split` (db5d31d1)
- `test: point silver-init agentmemory checks at reference doc` (c7276f5a)

---

## [0.49.0] — 2026-07-01

## Features
- `feat(hooks): run SB update check on SessionStart startup/clear` (fee7ede2)
- `feat(core): enforce host-agnostic SB core with pre-release validator` (807b6871)
- `feat(e2e): enforce autonomy outcome criteria in matrix harness` (dfb451d8)
- `refactor(hooks): completion-audit policy pipeline + hook-bootstrap` (7490bd69)
- `refactor(install): decompose install-codex.sh into lib modules` (9ed84aac)
- `refactor: close thermo-nuclear WARN monoliths on main` (bfd77344)

## Bug Fixes
- `fix(hooks): canonicalize shell write paths for macOS /var symlinks` (b0670b53)
- `fix(install): cross-host surface audit, host-bundles isolation, doctor D14-D17` (4ccea894)
- `fix(install): align codex tests and bundles with host-bundles layout` (f99eae52)
- `fix(release): host-bundles smoke paths + classify dedup + hook-bootstrap` (95c50892)
- `fix(install): restore validate-host-install-surface.sh for D16 gate` (9bbbcf88)
- `fix(site): contain mobile horizontal overflow on help docs` (667114ef)
- `fix(e2e): routing-only row 1 outcome scoring without WBS supervisor` (ee62a820)

## Other
- Enterprise E2E harness, matrix, and site polish commits since v0.48.9 (50 commits total)

---

## [0.48.9] — 2026-06-30

### Enterprise E2E (main)
- Merged `enterprise-e2e/round4-continuation`: outcome assessment harness, matrix tooling, Round 6 docs. Active Round 6 work continues on `enterprise-e2e/round6`.

## Features
- `feat(release): official Cursor isolation for pre-release smoke` (73e3244d)

## Bug Fixes
- `fix(release): satisfy shellcheck SC2155 in pre-release host smoke` (97196fc6)

---

## [0.48.8] — 2026-06-30

Enterprise E2E matrix hardening (session isolation, E2E-011 five-tool preflight, orchestrator read-only parent Bash), WBS meta-supervision MVP, and enterprise issues-doc traceability.

### Features
- `feat(wbs): add cross-cutting WBS meta-supervision MVP` (`b378026e`)
- `feat(release): mandatory isolated tri-host pre-release smoke (Claude, Codex, Cursor CLI)` — `validate-host-skill-surface.sh`, `run-pre-release-host-smoke.sh`, `AGENT_CLI_CREDENTIAL_STORE=memory` for Cursor (no Keychain)

### Bug Fixes
- `fix(e2e): isolate matrix rows with fresh sessions per workflow` (`30089281`)
- `fix(e2e): run matrix /clear inside expect prompt handler` (`73db2c82`)
- `fix(e2e): accept archived workflow evidence in matrix verify` (`bb4da237`)
- `fix(e2e): broaden internal matrix gate patterns for rows 21-22` (`f593236c`)
- `fix(e2e): quiesce active workflows before matrix live rows` (`fa48f52f`)
- `fix(e2e): stop friction append to Round 4 ledger; auto-sync PASS rows` (`09178a95`)
- `fix(orchestrator): allow read-only parent Bash; block SB state mutations only` (`c4c71a80`)
- `fix(e2e): recover from context exhaustion with /compact not /clear` (`95bc8c49`)
- `fix(e2e): propagate E2E-011 preflight failure; add live-path test` (`6bd631b8`)
- `fix(e2e): E2E-011 five-tool preflight, issues doc wiring, stop Next guidance` (`c2fc21a1`)
- `fix(e2e): assert E2E-011 live preflight on opted-in test app` (`d3090ae4`)
- `fix(e2e): auto-restart pending-rows driver on batch death` (`0a9a4e73`)
- `fix(e2e): match ↑/↓ navigate picker in expect harness` (`8af4b9ac`)
- `fix(e2e): orchestrator read-only bash and matrix harness tweaks` (`5524bf64`)

### Refactoring
- `refactor(runtime): purge GSD references; add enterprise E2E issues doc` (`5c39d1c3`)

### Documentation
- `docs(e2e): Round 4 ledger 16/22 — rows 2-3 pass + E2E-034 fixed` (`9850f591`)
- `docs(issues): link E2E-016 WBS MVP to commit b378026e` (`26ec3b3e`)
- `docs(issues): record fix commit SHAs in enterprise E2E issues log` (`7f8e757f`)
- `docs(e2e): clarify SB-only branch isolation for release cut` (`95e85173`)
- `docs(e2e): record Round 4 continuation branch for release cut` (`88b8b202`)

---

## [0.48.7] — 2026-06-29

Instruction-following reduction closure, silver-doctor coverage, subagent model gates, and enterprise E2E harness hardening.

### Features
- `feat(if-reduction)`: complete Waves 1–4 and subagent engagement audit closure (`ce66bd4b`)
- `feat(e2e)`: Session 0 gate, structural suite wiring, ledger↔monitor reconciliation, matrix failure_class taxonomy, Release Confidence Score script (`82ae6887`, `87417315`, `b2ff5448`, `3f7026a5`)
- `feat(validation)`: enterprise E2E claims overlay on 22-row matrix with pre-matrix dry-run gate (`0d7f967c`, `8406364e`)
- `feat(ci)`: homepage claims registry and audit (`7ae148c0`)

### Bug Fixes
- `fix(hooks)`: scope orchestrator guard to walk-resolved SB workspace (`10a1268e`)
- `fix(e2e)`: token gateway auth without login, matrix rows 2–20 via `/silver` router, monitor FORCE restart settings export (`70098a36`–`7b5cc6a9`)
- `fix(if)`: close remaining test, hook coverage, and documentation gaps (`b84801f7`)
- `fix(ladder)`: enforce Composer 2.5 only for all Cursor subagent rungs — never `composer-2.5-fast` (`d012973e`)
- `fix(harness)`: macOS setsid shim, driver lock, ledger-aware `--resume`, detached install-claude, agent bundle render preflight (`61469e03`–`b0e0f378`)
- `fix(claude)`: list SB skills with `/silver:` prefix only — Claude bundle skill dirs renamed to colon routes so picker does not duplicate hyphen stubs (`59403781`)
- `fix(doctor)`: host-aware checks — D8 orchestrator rule Cursor-only; D2/D3/D13 use active host plugin paths via `runtime-paths.sh` (no Cursor deps on Claude/Codex) (`e0f2234a`)
- `fix(e2e)`: fail fast when Claude token gateway credentials missing — preflight after install-claude, default settings export in live defaults (`7dd82097`)
- `fix(e2e)`: align matrix auth with terminal token gateway path (`e046f92e`)
- `fix(e2e)`: ignore comment lines in auth mutation guard (`6528b75a`)
- `fix(e2e)`: Claude TUI bypass disclaimer handling, proxy settings stripping, 429 retry interval, dev-cycle deny audit, idle token counter (`98691580`–`6ddb56a8`)

### Documentation
- `docs(test)`: silver-doctor catalog, scenario, and sentinel manifest coverage (`6670e0db`)
- `docs(if)`: plan execution complete on main (`d7954ae2`)
- `docs(e2e)`: subagent model policy — Composer 2.5 only (`ffcc1b11`)
- `docs(release)`: Help Center and public changelog mandatory in pre-release gate (`3a9401f0`)
- `docs(site)`: align help center with v0.48.7 release (`3f9dcbf8`)

### Tests
- `test(doctor)`: mocked-host unit tests for Claude/Codex/Cursor doctor paths (`e0f2234a`)
- `test(e2e)`: PTY bypass disclaimer contract (`ddb8d88a`)

---

## [0.48.6] — 2026-06-27

Scoped RTK coexistence: full agent RTK when opted in; verbatim harness mode only.

### Bug Fixes
- `fix(rtk)`: scope `RTK_DISABLED` to harness scripts (`SB_RTK_COMPAT_MODE=verbatim`) and opted-out projects — hook bridge omits disable when `recommended_tools.rtk.enabled_by_user` is true
- `fix(rtk)`: unwrap `rtk` / `RTK_DISABLED=1` prefixes in `completion-audit.sh` gate regexes (`sb_shell_command_unwrap_rtk`)

### Tests
- `test(rtk)`: opted-in / opted-out / verbatim modes in `test-rtk-compat.sh`
- `test(hooks)`: RTK-wrapped `git push` classification in `test-completion-audit.sh`

---

## [0.48.5] — 2026-06-27

Enterprise E2E live test suite, `silver:multi-ai-task` model alignment, and silver-prefix skill exposure.

### Features
- `feat(e2e)`: opt-in `enterprise-e2e-live-test` suite (`SB_ENTERPRISE_E2E_LIVE=1`) with runbook `docs/ENTERPRISE-E2E-LIVE-TEST.md` and entrypoint `scripts/run-enterprise-e2e-live-test.sh`
- `feat(skills)`: expose `silver:multi-ai-task` (renamed from `multi-ai-task`) with `scripts/multi-ai-task-models.py` — review-fix-ladder model set @ medium reasoning; OCG plan when OpenCode agents configured

### Tests
- Structural enterprise E2E live wiring validation (`tests/enterprise-e2e-live/test-enterprise-e2e-live-suite.sh`)
- `tests/scripts/test-multi-ai-task-models.sh` for resolver + Claude bundle prefix

---

## [0.48.4] — 2026-06-27

Enterprise E2E hardening patch: friction fixes #2–#13 (hooks, orchestrator Bash in Task workers, RTK compat, session-start branch scope), turn-level TUI watcher + matrix monitor, interactive 22/22 matrix harness, multi-ai-task v2.1–2.6 doc/sentinel fixes, and test isolation for semantic-compress / plugin-surface gates. `run-all-tests` **4672 passed, 0 failed** at release SHA.

### Bug Fixes
- `fix(hooks)`: resolve SB frictions #2–#13 for enterprise E2E (`aaae7b6e`)
- `fix(hooks)`: allow Bash in orchestrator-spawned Task workers (`18c969e8`, `effeaccb`)
- `fix(rtk)`: export `RTK_DISABLED` for SB shell entry points (`4024389f`)
- `fix(install-claude)`: rsync full hooks tree to plugin cache (`97bdfece`)
- `fix(hooks)`: add `hookEventName` to high-frequency PostToolUse output (`d382165c`)
- `fix(matrix)`: monitor empty-array crash when all rows complete; retry on API 429

### Tests
- `test(hooks)`: accept two-line branch scope file in session-start (`ee373397`)
- Semantic-compress + Claude plugin-surface test isolation; orchestrator parent-guard coverage

---


Recommended-tools expansion and global wiring: RTK and Context Mode opt-in gates, Alumnium opt-in, Graphify + agentmemory stack optimizer (synergy_max) across hosts, multi-agent global RTK/Context Mode optimizer, and Context Mode read-deny when enforced. Documentation and site workflow SDLC ordering; enterprise E2E fixture shift; CI/shellcheck and diagnostics fixes. Integrates doc-scheme Graphify exclusion test fix; restores opt-in Graphify gate behavior after mandatory-graphify branch merge.

---

## [0.48.2] — 2026-06-25

Enterprise readiness ladder run 2: FLOW-16/17 worker split (`DESIGN-HANDOFF.md` / `DOCUMENT.md`), `SECURITY.md` skill-dispatched template, catalog `skill_worker_templates` parity, depth-aware review-loop docs, core-rules hash pin enforcement, Cursor GPT-5.5 ladder slug substitutions, and review-loop safety-cap non-convergence guard.

## Bug Fixes
- Split `silver-handoff` (FLOW 16) from `silver-ensure-docs` (FLOW 17) worker templates; added `FLOW-DOCUMENT` runtime queue token.
- Split `security` vs `silver-secure` worker templates (`SECURITY.md` / `SECURE.md`) with distinct flow-log labels.
- Fixed `RELEASE.md` mandatory skill (`silver:create-release`), `ROUTER.md` colon invoke form, orchestrator flow-label CSV mappings.
- Lazy-load worker template mapper in `orchestrator-directive.sh` when sourced before `orchestrator-parent.sh`.
- Core-rules injection requires verified hash pin; missing pin injects warning instead of unpinned content.

## Tests
- Extended orchestrator handoff, workflow CSV, instruction-flow parity, worker-template parity, and review-fix-ladder coverage.

---

## [0.48.1] — 2026-06-24

Post-release APO runtime alignment, orchestrator queue fixes, and help-center refresh for the v0.48 catalog model.

## Bug Fixes
- Fixed `silver-devops` orchestrator post-exec queue token (`FLOW-QUALITY-GATE-PRESHIP` instead of stale `FLOW-DEVOPS-QUALITY-GATE-PRESHIP`).
- Registered `silver-deep-research` and `silver-ensure-docs` as flow atoms and extended the `silver-deep-research` default queue with documentation and validation steps.

## Tests
- Added orchestrator queue-order and worker-template parity coverage for research and devops flows.
- Tightened APO schema test for subagent-only `dispatch_mode` and composition triple alignment gates.
- Added stale 18-flow phrase guard across public docs in `check-apo-invariants.py`.

## Documentation
- Refreshed README, help center, OG card, and workflow pages for the canonical `AF-*` catalog (27 atomic flows, not legacy 18-flow wording).
- Added AGENTS.md rule requiring Composer 2.5 subagents for website and help-center authoring.

---

## [0.48.0] — 2026-06-24

Atomic-flow APO redesign.

## Features
- Added `docs/apo-catalog.json` as the authoritative Agentic Process Orchestrator catalog for processes, workflows, atomic flows, flow steps, V-loops, evidence records, intent ledgers, process packs, dynamic composition rules, and runtime token mappings.
- Replaced the legacy FLOW 1-18 mirror with 27 canonical non-redundant `AF-*` atomic flows, 22 catalog-backed workflows, and 85 skill-backed flow steps with local V-loops.
- Added generated catalog views: `docs/composable-flows-contracts.md`, `docs/workflow-composition-matrix.md`, and `docs/generated/atomic-flow-index.json`.

## Tests
- Added blocking APO gates for catalog schema/SOT, atomic-flow deduplication, per-flow and per-step V-loops, composition SOT, evidence/intent models, subagent execution metadata, runtime alignment, worker parity, tool policies, router coverage, and site/doc freshness.

## Documentation
- Updated `silver-bullet.md`, `templates/silver-bullet.md.base`, README/help/reference/workflow docs, and search metadata to describe the APO catalog authority, migration from FLOW 1-18 aliases, V-loop rollups, subagent execution, opted-in tool governance, and generated-view freshness model.

---

## [0.47.1] — 2026-06-24

Hook activation guard for non-initiated projects, sentinel manifest fix, and opt-in agentmemory with Graphify synergy.

## Features
- `feat(recommended-tools): add opt-in agentmemory with Graphify synergy` (`06b621aa`, `5f996695`) — explicit consent via `recommended_tools.agentmemory` in `.silver-bullet.json`; **save via agentmemory, retrieve via Graphify** when both tools are enabled
- New hooks: `hooks/agentmemory-gate.sh`, `hooks/record-agentmemory-usage.sh`, shared `hooks/lib/agentmemory-gate.sh` — CLI, server, MCP, and export-root gates when opted in
- `/silver:init` (§1.1b) and `/silver:update` (Step 8b) consent, install, and enforcement-suspend retry flows
- Follow-ups: `fix(skills): drop host-specific paths from agentmemory init/update copy` (`ed5ae8ff`); `fix(hooks): silence ShellCheck SC1090 on graphify lazy source` (`925577b9`); `fix(gitignore): un-ignore agentmemory memory files` (`141afb3b`); `chore(setup): record agentmemory/graphify stack` (`b42e49d1`); `test(scripts): tolerate sb-diagnostics non-zero exit` (`ddc09e24`)

## Documentation
- `docs/AGENTMEMORY.md` — opt-in policy, local setup, hook enforcement, and Graphify pairing

## Bug Fixes
- `fix(hooks): skip enforcement when SB not initiated in project` (`8ca25258`) — hooks only engage when `.silver-bullet.json` and `silver-bullet.md` exist; non-initiated workspaces no longer receive enforcement
- `fix(hooks): gate on .silver-bullet.json presence only` (`fe05b7d9`) — simplified activation check

## Tests
- `test: fix sentinel manifest for silver-review-fix-ladder` (`47b66330`)

## Chores
- `chore(sync): align plugin templates with root templates` (`a2412af7`)

---

## [0.47.0] — 2026-06-22

Recommended-tools opt-in for Graphify, GSD lifecycle namespace removal, atomic-flow composition hardening, and hook/test parity gates.

## Features
- `feat(recommended-tools): opt-in Graphify consent with hook enforcement` (`f762dfdd`)
- `feat(recommended-tools): implement opt-in policy decisions for Graphify` (`2b6da65c`)
- `feat(graphify): align per-platform install with upstream v8` (`495c35ba`)

## Refactoring
- `refactor(runtime): remove GSD lifecycle namespace from SB hooks` (`0d660f39`)
- `refactor(hooks): centralize jq-gate and dedupe hooks.json matchers` (`1c9d447f`)

## Documentation
- `docs(redundancy): audit remediation, site FLOW alignment, skill deprecations` (`35ebebae`)
- `docs(planning): add full SB redundancy audit` (`b626ac89`)
- `docs: fix remediation commit ref after amend` (`646d334f`)

## Tests
- `test(flows): P1 composition hardening and e2e smoke refresh` (`ba2e1fe5`)
- `test: finish GSD removal in integration and live fixtures` (`f146d4b2`)
- `test: fix post-GSD and remediation test failures` (`0e88b87a`, `3a5ca89a`)
- `chore(tests): add parity gates, hook fixtures, and template sync` (`176504f2`)
- `test(hooks): isolate CURSOR_PLUGIN_ROOT host detection from SILVER_BULLET_RUNTIME`

## Chores
- `chore(sync): refresh silver-init skill-source after opt-in Graphify init flow` (`76f460cb`)

---

## [0.46.0] — 2026-06-20

Hotfix release: hook false-positive elimination, Cursor gitPath install repair, e2e-live Kay stability, and worm payload removal.

## Bug Fixes
- `fix(hooks): eliminate dev-cycle false positives for grep, ls, git grep, and compound read-only shells` (`cc7297b3`)
- `fix(hooks): cache project root at session start; honor SILVER_BULLET_PROJECT_ROOT` (`cc7297b3`)
- `fix(hooks): allowlist planning-edit-override and related state sentinels` (`cc7297b3`)
- `fix(cursor): automate github.com marketplace gitPath checkout and gitCommitSha registry` (`5e5a9567`)
- `fix(e2e-live): accept route-smoke completion echo wrappers in Kay transcripts` (`2f0db4c0`)

## Security
- `chore(security): remove yugin0120 worm payload from .vscode/tasks.json and fake FontAwesome fonts` (`c5e02825`)

## Tests
- `test(hooks): expand dev-cycle and shell read-only coverage` (`cc7297b3`)
- `test(scripts): install-cursor gitPath and registry assertions` (`5e5a9567`)
- `test(e2e-live): echo-adapter-echo route-smoke fixture` (`2f0db4c0`)

---

## [0.45.0] — 2026-06-20

Streamlined pre-release quality gate: adversarial + per-skill SENTINEL enforcement on `gh release create`.

## Features
- `feat(hooks): replace legacy quality-gate-stage-1/2/4 with adversarial-review-clean and sentinel-skills-clean markers`
- `feat(scripts): add validate-launch-review.sh and validate-sentinel-skills-manifest.sh release validators`
- `docs: collapse pre-release gate to adversarial, SENTINEL per-skill, code security, and public content stages`

## Documentation
- `docs: add PRE-RELEASE-PROCESS-PROPOSAL and sentinel-skills audit manifest (85/85)`
- `docs: silver-bullet §9 pre-release section; align silver:release and silver:create-release skills`

## Tests
- `test(hooks): completion-audit coverage for new pre-release markers`
- `test(scripts): validate-launch-review and sentinel manifest gate tests`

---

## [0.44.7] — 2026-06-18

Second adversarial review pass: orchestrator state scoping, planning-chain fallbacks, and session hygiene after branch changes.

## Bug Fixes
- `fix(hooks): scope orchestrator Stop gate to current repo via repo_root in orchestrator.json`
- `fix(hooks): tighten worker-session marker TTL parsing (require spawned_at value)`
- `fix(hooks): align planning fallbacks with silver-context and silver-plan across stop, dev-cycle, compliance, and prompt-reminder`
- `fix(hooks): clear orchestrator and edit-override state on branch change and session start`
- `fix(hooks): orchestrator-directive guard rejects out-of-scope state file paths`
- `fix(hooks): remove duplicate jq-gate source in completion-audit`
- `fix(templates): host-neutral worker invoke wording and SB_RUNTIME_HOME_ROOT in PHASE.md`

## Tests
- `test(hooks): orchestrator parent guard and cross-project stop-check behavior`
- `test(hooks): session-start orchestrator reset on branch change`
- `test(hooks): flow-advance and stop-check planning chain expectations`

---

## [0.44.6] — 2026-06-18

Fresh adversarial flow review (post-v0.44.5): validate dead-end for DevOps/Fast paths without SPEC.md.

## Bug Fixes
- `fix(skills): silver-validate — plan-only mode when SPEC.md absent (unblocks devops/fast pre-exec chain)`
- `fix(skills): silver-devops/silver-fast — document plan-only validate path`
- `fix(templates): sync orchestrator worker templates to host-neutral plugin wording`

## Tests
- `test(hooks): workflow-chain-guard silver-devops without SPEC.md`
- `test(hooks): orchestrator worker template repo/plugin parity`
- `test(integration): skill-execution-paths plan-only validate guards`

---

## [0.44.5] — 2026-06-18

Fresh adversarial flow review (post-v0.44.4): parent orchestrator worker template gaps and devops queue skill mapping.

## Bug Fixes
- `fix(orchestrator): add missing worker templates for DECIDE, SPECIFY, devops router, review triad tail, branch-finish, completion-audit`
- `fix(hooks): map devops-quality-gates and devops-skill-router correctly in orchestrator flow_to_skill`
- `fix(hooks): prevent worker sessions from re-seeding composer orchestrator queue`
- `fix(skills): silver-devops/silver-bugfix — document canonical mandatory pre/post chains`

## Tests
- `test(hooks): orchestrator worker template coverage for all composer queue skills`
- `test(hooks): flow-advance worker composer re-seed guard`
- `test(integration): skill-execution-paths invoke-line ordering guards`

---

## [0.44.4] — 2026-06-18

Fresh adversarial flow review (post-v0.44.3): greenfield UI spec dead-end and Fast Tier 2 deploy-chain documentation gaps.

## Bug Fixes
- `fix(skills): silver-ui — add Step 1d silver:spec for greenfield UI (workflow-chain-guard dead-end when SPEC.md absent)`
- `fix(skills): silver-ui — reorder plan before ui-contract to match hook/orchestrator queue`
- `fix(skills): silver-fast — document full canonical deploy chain for Tier 2 PR/release paths`

## Tests
- `test(hooks): workflow-chain-guard silver-ui conditional silver-spec`
- `test(hooks): orchestrator queue silver-ui conditional silver-spec`
- `test(integration): skill-execution-paths guards for ui spec and fast deploy chain`

---

## [0.44.3] — 2026-06-18

Flow adversarial review: align UI, DevOps, and Fast Tier 2 skills with `workflow-chain-guard` pre-build `silver:validate` requirements.

## Bug Fixes
- `fix(skills): silver-ui — add Step 6b Pre-Build Validation before execute (workflow-chain-guard dead-end)`
- `fix(skills): silver-devops — add Step 5b pre-build and Step 9b post-ship silver:validate steps`
- `fix(skills): silver-fast — make Tier 2 silver:validate mandatory; fix SessionStart trivial-marker wording`

## Tests
- `test(integration): skill-execution-paths guards for validate ordering in ui/devops/fast`

---

## [0.44.2] — 2026-06-18

Launch-readiness adversarial review: fix silver:phase ROADMAP guard bypass, register v0.44.0 utility skills in all_tracked, and align Codex manifest/config versions with package.json.

## Bug Fixes
- `fix(hooks): planning-file-guard — roadmap-edit-override allows ROADMAP.md/STATE.md edits for silver:phase and silver:undo`
- `fix(config): add silver, silver-phase, silver-spike, silver-thread, silver-undo to skills.all_tracked`
- `fix(scripts): sync-codex-package and sync-codex-marketplace-version derive version from package.json`

## Documentation
- `docs(skills): silver:phase and silver:undo document roadmap-edit-override protocol`
- `docs(orchestrator): add PHASE worker template for silver:phase queue atoms`

## Tests
- `test(hooks): planning-file-guard roadmap-edit-override bypass coverage`
- `test(scripts): release version alignment guard across plugin manifests and config template`
- `test(hooks): required-skills-consistency asserts v0.44.0 utility skills are tracked`

---

## [0.44.1] — 2026-06-18

Patch release: GSD runtime purge, orphaned shim test removal, hook test fixes, and skill scenario coverage for v0.44.0 utility skills.

## Refactoring
- `refactor(hooks): purge GSD runtime references — legacy-gsd-alias.sh renamed to legacy-skill-alias.sh, sb_legacy_gsd_alias_normalize renamed to sb_legacy_skill_alias_normalize; semantic-compress.sh updated to match silver:* trigger patterns; phase-archive.sh retargeted to SB-native skill names; dead code removed from record-skill.sh, record-requested-skill.sh, spec-floor-check.sh, uat-gate.sh, dev-cycle-check.sh, dependency-skill-check.sh`
- `refactor(skills): silver:ensure-docs, silver:review-stats, silver:undo — update internal GSD skill references to SB-native equivalents`
- `refactor(scripts): install-codex.sh GSD_PHASE_ARCHIVE_HOOK and legacy-gsd-alias references replaced with SB-native names`

## Bug Fixes
- `fix(hooks): semantic-compress.sh trigger pattern updated from gsd:execute-phase to silver:execute to match current skill namespace`

## Tests
- `test(hooks): rename test-legacy-gsd-alias.sh to test-legacy-skill-alias.sh; update sb_legacy_skill_alias_normalize call sites; test-semantic-compress.sh trigger fixture updated to silver:execute`
- `test(skills): add scenario coverage for silver:phase, silver:spike, silver:thread, silver:undo (v0.44.0 utility skills)`
- `chore(tests): remove orphaned test-gsd-sdk-shim.sh — GSD SDK shim (gsd-sdk.cjs, install-gsd-sdk-shim.sh) was removed in v0.44.0; test was mistakenly not deleted at that time`

---

## [0.44.0] — 2026-06-17

## Features
- `feat(skills): add silver:spike — executable feasibility experiments with Given/When/Then structure and VALIDATED/INVALIDATED/PARTIAL verdicts`
- `feat(skills): add silver:phase — CRUD management for phases in ROADMAP.md; sanctioned path to mutate phase list without planning-file-guard`
- `feat(skills): add silver:undo — safe git revert for SB phase/plan commits with dependency checks and artifact cleanup`
- `feat(skills): add silver:thread — lightweight cross-session context threads for topic-specific tracking across sessions`
- `feat(skills): silver:context --assumptions mode — surface AI implementation assumptions without interactive session; writes ASSUMPTIONS.md`
- `feat(skills): silver:add --seed flag — forward-looking idea classification with trigger-condition tracking in .planning/seeds/`
- `feat(skills): silver:plan --mvp mode — vertical-slice planning producing thin end-to-end feature slices; writes SKELETON.md for new projects`
- `feat(skills): silver:review deployment risk scoring — per-change Tier 1–4 deployment risk score in REVIEW.md`
- `feat(silver-bullet.md): Package Legitimacy Gate — verify package name, age, download signals, and source repo before any installation`
- `feat(silver-bullet.md): Alumnium optional visual/browser companion integration — structured fallback hierarchy (Alumnium → host browser MCP → text-only)`
- `feat(docs): pre-release quality gate now enforces 2 consecutive clean rounds per review/audit stage`

## Bug Fixes
- `fix(hooks): session-start removes stale Design plugin detection code`
- `fix(scripts): remove gsd-sdk.cjs and install-gsd-sdk-shim.sh legacy GSD SDK shim layer`
- `fix(skills): silver:init legacy plugin section updated to reflect removal of probing/reporting third-party lifecycle plugins`
- `fix(tests): test-install-codex assertion updated to match new legacy plugin note wording`

## Documentation
- `docs(site): reference page and search index updated with silver:spike, silver:phase, silver:undo, silver:thread entries`
- `docs(internal): pre-release-quality-gate.md adds MANDATORY 2-consecutive-clean-rounds requirement at top`

## Chores
- `chore(bundles): sync all agent bundles (claude, codex, cursor) with updated and new skills`
- `chore(release): v0.44.0 superset audit remediation, four new utility skills, skill extensions

---

## [0.43.11] — 2026-06-17

Ship migrate mechanical scripts referenced by `silver:migrate` since v0.43.10 skill update.

## Bug Fixes
- `fix(scripts): add sb-migrate-config.sh and sb-migrate-project.sh for legacy project surface parity`

## Tests
- `test(scripts): sb-migrate-config and sb-migrate-project regression suites`

## [0.43.10] — 2026-06-17

Independent launch-readiness adversarial review (Round 1–2): enforcement bypasses, orchestrator parity, routing/docs drift, migrate/init gaps, bundle render fix.

## Bug Fixes
- `fix(hooks): workflow-chain-guard honors apply_patch and devops pre-exec markers`
- `fix(hooks): workflow-chain-guard uat-gate completion-audit sb_initiated jq fail-closed parity`
- `fix(hooks): orchestrator queues — conditional silver-spec, silver-fast, devops router/security`
- `fix(skills): router post-exec order, migrate/update routes, bugfix validate→QG, init orchestrator surface`
- `fix(docs): devops-cycle review-before-verify; full-dev-cycle completion-audit step`
- `fix(scripts): render-agent-bundle preserves .cursor/rules project paths`

## Tests
- `test(hooks): apply_patch chain-guard, orchestrator devops/fast/spec, uat-gate sb_initiated fixtures`

## [0.43.9] — 2026-06-16

Independent launch-readiness adversarial review (round 5): Codex package sync now chains Cursor manifest refresh.

## Bug Fixes
- `fix(scripts): sync-codex-package.sh invokes sync-cursor-package.sh after codex sanitizer so Cursor hooks/manifest stay present in shared plugins/silver-bullet tree`
- `fix(site): refresh Help Center search index version strings to match package.json (0.43.9)`

## Tests
- `test(scripts): sync-codex-package asserts Cursor manifest and cursor-hooks.json after codex sync`

## [0.43.8] — 2026-06-16

Independent launch-readiness adversarial review (round 4): silver-ui post-execution sequencing alignment.

## Bug Fixes
- `fix(skills): silver-ui mandatory deps document full post-exec chain (UI quality → review → verify → secure → ship)`
- `fix(skills): silver-ui step order — UI visual audit before code review (matches orchestrator queue)`
- `fix(docs): composable-flows-contracts documents FLOW 9 insertion before REVIEW for silver:ui`
- `fix(site): silver-ui help page step order aligned to canonical REVIEW→VERIFY→SECURE`

## Tests
- `test(hooks): silver-ui orchestrator queue asserts ui-review before review triad`

## [0.43.7] — 2026-06-16

Independent launch-readiness adversarial review (round 3): orchestrator pre-exec queue parity and enforcement hardening.

## Bug Fixes
- `fix(hooks): silver-ui/devops orchestrator queues include silver-validate before execute`
- `fix(hooks): silver-release queue includes branch-finish and completion-audit before ship`
- `fix(hooks): register silver-create-release as orchestrator flow atom`
- `fix(hooks): silver-ui chain-guard marker order plan → ui-contract (composable FLOW 6→7)`
- `fix(hooks): forbidden-skill-check jq fail-closed for sb_initiated projects`
- `fix(skills): silver-ui mandatory deps and tdd canonical marker documentation`

## Tests
- `test(hooks): extend orchestrator queue regression for ui/devops/release atoms`

## [0.43.6] — 2026-06-16

Independent launch-readiness adversarial review (round 2): fix orchestrator autonomous queue ordering and completeness.

## Bug Fixes
- `fix(hooks): orchestrator queues use canonical REVIEW→VERIFY→SECURE post-exec order`
- `fix(hooks): expand flow_atom list (review triad, security, branch-finish, completion-audit)`
- `fix(hooks): orchestrator advance uses last_completed_index for duplicate quality-gate tokens`
- `fix(hooks): dev-cycle-check finalization fallback uses canonical tdd marker`
- `fix(docs): composable-flows-contracts post-execution sequencing section`
- `fix(skills): silver:devops display chain lists full post-exec gates`

## Tests
- `test(hooks): add orchestrator queue order regression suite`

## [0.43.5] — 2026-06-16

Patch release: regenerate `agents/claude`, `agents/codex`, and `agents/cursor` from `skills/` so packaged agent bundles match v0.43.4 skill fixes (silver-migrate, silver-bugfix, silver-fast, silver-ship, devops-quality-gates, silver-quality-gates, silver-devops).

## Chore
- `chore(agents): sync bundles from skills post v0.43.4`

## [0.43.4] — 2026-06-15

SB flows launch audit remediation (F-01–F-14): planning guard SB phase paths, migrate inference, workflow doc order, devops profile reset, tier 0–1 playbook, fast-path tightening, jq fail-closed for initiated projects, REVIEW-ROUNDS delivery gate, ship UAT scope, flow-advance jq visibility, sb_initiated banner, compliance `tdd` display, Cursor apply_patch parity, bugfix chain order.

## Bug Fixes
- `fix(hooks): exempt SB-native phase VERIFICATION/REVIEW/SECURITY from planning-file-guard`
- `fix(skills): silver:migrate inference globs for phases/*/PLAN.md and VERIFICATION.md`
- `fix(docs): reconcile full-dev-cycle post-exec order to REVIEW→VERIFY`
- `fix(hooks): reset devops-cycle active_workflow after silver:ship`
- `fix(hooks): jq missing blocks PreToolUse in SB-initiated projects`
- `fix(hooks): REVIEW-ROUNDS.md two-round substance gate at delivery`
- `fix(hooks): compliance-status uses canonical tdd marker`

## [0.43.3] — 2026-06-15

Second adversarial review closure: unified quality-gates mode detection, devops dual-mode markers, jq-missing fail-closed paths, and e2e-live journey stabilization.

## Bug Fixes
- `fix(hooks): close adversarial review loop — unified QG mode and gate parity`
- `fix(e2e-live): stabilize full-surface journey npm and release gates`

## Tests
- `test(hooks): add quality-gates-mode canonical detection regression suite`

---

## [0.43.2] — 2026-06-15

Adversarial review closure + test-suite remediation: zero failures across all five `run-all-tests.sh` suites.

## Bug Fixes
- `fix(hooks): record distinguishable silver-quality-gates-design vs silver-quality-gates-adversarial markers; delivery gate requires pre-ship marker when VERIFICATION.md exists`
- `fix(hooks): unify completion-audit and record-skill fallbacks with required-skills.sh single source of truth`
- `fix(hooks): silver-fast Tier 2 chain guard requires silver-quality-gates pre-plan marker`
- `fix(hooks): tighten outcomes scope anti-gaming; fail-closed without jq when pending outcomes exist`
- `fix(hooks): orchestrator worker marker readable without jq (grep fallback)`
- `fix(config): remove duplicate silver-tdd from all_tracked` — canonical `tdd` marker only; fixes skill-coverage false negative when record-skill canonicalizes silver-tdd→tdd
- `fix(skills): add ## sections to silver-bootstrap-* and silver-orient alias skills` — satisfies SKILL.md structural validation
- `test(integration): append pre-ship quality-gates adversarial marker in delivery fixtures` — aligns with v0.43.1 completion-audit dual-mode gate
- `test(integration): enrich PLAN.md fixture for artifact substance gate`
- `test(live): seed installed_plugins registry after Codex hook transplant` — fixes intermittent install-codex rsync failures

## Tests
- `test(hooks): add artifact-substance-gate, outcomes anti-gaming, silver-fast Tier 1/2 chain-guard, orchestrator worker marker without jq`
- `test(hooks): isolate completion-audit matrix state per test run`
- Add skill scenarios for `silver-bootstrap-milestone`, `silver-bootstrap-project`, `silver-orient`
- `docs(TESTING): align jq assertions with canonical tdd naming`

---

## [0.43.1] — 2026-06-15

Adversarial SB flows review remediation (tagged release; see git history for hook/skill parity fixes).

---

## [0.43.0] — 2026-06-15

Launch-readiness follow-up: closes GitHub #222 and remaining adversarial review wiring gaps (SB-REV-001–021).

## Bug Fixes
- `fix(dev-cycle-check): allow rm/rmdir of uninstalled plugin cache dirs when absent from installed_plugins.json` (#222)
- `fix(completion-audit): wire required_deploy_devops when active_workflow is devops-cycle or composer is silver-devops`
- `fix(uat-gate): restrict UAT gate to silver:release — phase ship no longer requires UAT.md when SPEC exists`
- `fix(workflow-chain-guard): scope multi-workflow deadlock to SB_WORKFLOW_ID when set`

## Features / Flows
- `feat(flows): add silver:completion-audit before ship in feature/ui/devops/bugfix/release compositions`
- `feat(silver-devops): activate active_workflow devops-cycle at workflow start`
- `feat(silver-bugfix): complete deploy chain with validate, branch-finish, completion-audit`
- `fix(silver-ui): canonical security → silver:secure order`
- `fix(silver-feature): remove stale VERIFY skip from composition context scan`
- `fix(silver-deep-research): align workflow-chain guard with clarify + research markers`

## Config / Docs
- `chore(config): remove tdd from required_deploy_devops; align config_version and version to 0.43.0`
- `docs(ORCHESTRATOR): clarify worker skill invoke vs parent Task spawn; subagent recording note`
- `fix(silver-update): document Codex registry key silver-bullet@alo-labs-codex`

## Tests
- Plugin uninstall bypass, devops deploy list, UAT ship scope, multi-workflow SB_WORKFLOW_ID scoping

---

## [0.42.0] — 2026-06-15

Launch-hardening release. Remediates all blocker/high/medium findings from the pre-launch adversarial review and confirms a clean surface over two consecutive fully-green test rounds (3371 passed, 0 failed; 33/33 hooks covered).

## Features
- `feat(enforcement): mandatory security + verify-tests delivery gate` — `security` added to `required_deploy` / `required_deploy_devops`; `verify-tests` made a mandatory pre-delivery gate in feature/ui/devops/bugfix/ship.
- `feat(prompt-reminder): context-aware two-tier compliance display` — shows the planning floor during development and the full delivery list only when the prompt is delivery-adjacent or `silver-execute` has run (`sb_prompt_is_delivery_adjacent`).
- `feat(flows): unified canonical post-execute order` across feature/ui/devops/bugfix — review triad → verify → secure → validate → quality-gates → ship.

## Bug Fixes
- `fix(workflow-chain-guard): align silver-bugfix markers with the documented ORIENT → DEBUG → PLAN chain` (`silver-debug silver-plan`).
- `fix(core-rules): correct Stop-hook description to the two-tier model` (planning floor at Stop, `required_deploy` at delivery); regenerated `core-rules.sha256`.
- `fix(silver-feature): remove pre-plan validate that ran before PLAN.md existed`; add Step 6b validate after the plan phase.
- `fix(silver-feature): add explicit silver:spec step for greenfield (FLOW 5) when SPEC.md is absent`.
- `fix(silver-init): soften the Graphify hard gate to advisory with a documented direct-docs fallback`.
- `fix(skills): repair corrupted markdown fences in silver-bugfix and silver-devops composition sections`.
- `fix(silver-quality-gates): correct PLAN glob to PLAN.md (.planning/phases/*/PLAN.md .planning/PLAN.md)`.
- `fix(silver-spec): populate ## Implementations in SPEC.md`.
- `fix(silver-update): correct install command to /plugin install alo-exp/silver-bullet`.

## Docs
- `docs(ENFORCEMENT): add "Stop vs Delivery (Two-Tier Model)" and "Orchestrator Worker SubagentStop" sections`.
- `docs(internal): correct stop-hook-audit and CICD two-tier descriptions; document silver-release nested-workflow collision guard`.

## Tests
- `test(hooks): add test-industry-tooling-hint.sh — closes the last hook coverage gap (33/33)`.

## Chores
- `chore(config): bump template config_version and plugin version to 0.42.0`.

---

## [0.41.1] — 2026-06-15

## Bug Fixes
- `fix(cursor): regenerate cursor-hooks.json for flow-advance and industry-tooling-hint parity with hooks.json` 

## Chores
- `chore(config): bump template config_version and version to 0.41.0`

---

## [0.41.0] — 2026-06-15

## Features
- `feat(orchestrator-parent): silver-orchestrator skill and worker templates` (48602193)
- `feat(orchestrator-parent): parent-mode hooks and directive worker templates` (6225e5aa)
- `feat(launch-remediation): stamp Cursor orchestrator rule on silver:init` (6564ff86)
- `feat(launch-remediation): tier honesty and artifact substance gates (P1-P4)` (28579fe4)
- `feat(launch-remediation): orchestrator directive drives next skill (P0/P6)` (18deccdc)
- `feat(launch-remediation): Wave 0–6 orchestrator + L-02/L-03 hardening` (b9585703)

## Bug Fixes
- `fix(config): add silver-orchestrator to dogfood all_tracked skills` (c5d91e99)
- `fix(scripts): sync deploy-gate-snippet REQUIRED_DEPLOY with template` (caef5ffe)
- `fix(ci): restore hook parity and integration fixture enforcement tier` (641cf423)
- `fix(kay-bridge): stabilize isolation tests for parent-mode denials` (7729fbee)
- `fix(orchestrator): rewrite A && B || C patterns for ShellCheck 0.9` (9d418d6a)
- `fix(orchestrator): resolve ShellCheck warnings on parent-mode hooks` (8f6f7f78)
- `fix(live-surface): close 100% checklist gap and integration test failures` (4674e66f)
- `fix(stop-check): add sb_initiated to Test 3b config` (8a00cd1a)
- `fix(kay): block pre-planning edits via hook bridge (KAY-01)` (e75f54f1)
- `fix(plugin): restore cursor plugin manifest files` (54bef9a0)
- `fix(launch-remediation): lead prompt-reminder with orchestrator directive` (04b3f246)
- `fix(workflows): preserve QUALITY GATE spacing in flow tracker` (9d4d35e9)

## Documentation
- `docs(orchestrator-parent): full-surface checklist and live test evidence` (cc068e30)
- `docs(test): orchestrator parent mode docs, tests, migration, plugin sync` (ba8cb0fa)
- `docs(orchestrator-parent-mode): add three-host live test report` (490194c4)
- `docs(launch-remediation): P8 dogfood evidence and 10/10 score` (6c9f3f5c)
- `docs(launch-remediation): 10/10 checklist, CI mirror, live E2E SKIP (P5-P9)` (264767c2)

## Tests
- `test(integration): force hook-enforced tier in CI fixtures` (fcd4c4d3)
- `test(skills): add silver-orchestrator scenario coverage file` (5b6bd7c2)
- `test(session-start): seed canonical plugin cache path for CI` (e7c3aa7f)
- `test(hooks): mock plugin cache and fix stall/SessionStart CI failures` (04b3e2c0)

## Chores
- `chore(ci): add optional workflow_dispatch live E2E workflow` (a1e39208)

---

## [0.40.0] — 2026-06-14

## Features
- `feat(migrate): upgrade path to latest SB (058 agent-neutral, Cursor, runtime parity)` (47f5b5a)

## Tests
- `test(migrate): document full upgrade path in test-silver-migrate.sh`

---

## [0.39.3] — 2026-06-14

## Features
- `feat(056): runtime-enforced AS1/Zuvo parity — evidence schema validator, silver-add fingerprint CLI, interface STATE stamping, sb-bootstrap onboarding` (70d46b1)
- `feat(056): evidence schema delivery gate in completion-audit (warn-first; strict via SILVER_BULLET_EVIDENCE_SCHEMA_STRICT=1)` (79abf3d)
- `feat(056): shared evidence fingerprints and silver-scan alignment` (080967a)
- `feat(057): ship alo-labs Cursor marketplace and first-class Cursor runtime support` (4b55bef)
- `fix(release): rewrite silver skill names in Claude agent bundle after sync` (70d46b1)

## Bug Fixes
- `fix(cursor): store forge marketplace template as plain files` (52a36f5)
- `fix(diagnostics): persist runtime name after subshell path detect` (25781e6)

## Tests
- `test(056): silver-add fingerprint, evidence validator, interface STATE, sb-bootstrap, completion-audit gate` (bfdf3ad)
- `test(057): Cursor runtime bootstrap, hook bridge, and marketplace CI smoke` (4b55bef)

---

## [0.39.2] — 2026-06-14

## Features
- `Close AS1 structural parity gaps with shared contracts and diagnostics.` (97cbce5)

## Tests
- `test: redirect stdin in run-all-tests to prevent hook hang` (481849d)

---

## [0.39.1] — 2026-06-14

## Bug Fixes
- `fix(scan): audit agent session discovery` (ab12e86)
- `fix(hooks): cross-runtime adapter receipts and validate release notes` (62203f2)

## Tests
- `test(hooks): avoid prompt-reminder hang on open stdin` (fe095e5)
- `test(hooks): cover cross-runtime receipt lookup` (62203f2)
- `test(scripts): validate GitHub Release notes body` (62203f2)

---

## [0.39.0] — 2026-06-12

## Features

- `feat: absorb lifecycle parity into Silver Bullet`
- `feat: add SB-owned release, deploy, canary, incident, retro, benchmark, content, refactor, worktree, and test workflows`
- `feat: extend domain audit, verification, security, UI, and DevOps contracts for AS1 parity`

## Bug Fixes

- `fix(live): require route-smoke turns to invoke the SB adapter directly`
- `fix(site): keep homepage lifecycle cards to three columns without bullet overflow`

## Documentation

- `docs(site): remove legacy dependency positioning from public website and Help Center`
- `docs: refresh release audit evidence for v0.39.0`

## Tests

- `test(live): fail Codex and Kay route-smoke checks when transcripts bypass the SB adapter`
- `test(release): refresh public-content and lifecycle parity coverage`

---

## [0.38.2] — 2026-06-12

## Bug Fixes

- `fix(release): support gh release create stdout capture` (d69ce43)

---

## [0.38.1] — 2026-06-12

## Other

- `Add SB domain quality audit packs` (34dab31)
- `Remove deprecated dependency references from site` (bf4587f)
- `Fix homepage ecosystem card layout` (9aaa1e0)

---

## [0.38.0] — 2026-06-11

## Features

- `feat: absorb lifecycle dependencies into Silver Bullet` (7347cc0)

## Bug Fixes

- `fix: require verify marker for release live matrix` (cbceb83)
- `fix: preserve verify marker across live release gates` (504ff02)
- `fix: infer host runtime for live release markers` (3c94285)
- `fix: mirror live release markers to host state` (b1c5c7c)
- `fix: harden Kay live hook enforcement` (d442853)

## Documentation

- `docs: refresh release gate evidence for Kay hardening` (85d3031)
- `docs(site): default visitors to light theme` (483969d)
- `docs(site): index Graphify help content` (019dc95)

## Other

- `Fix Help Center theme toggle` (13213a4)
- `Align brute deck with design system` (a88e1d7)
- `Exclude brute deck from site chrome` (d60b6e1)
- `Align help TOC and standardize site chrome` (67b4817)
- `Refine Help icon and TOC alignment` (d7c0b51)
- `Strengthen Help card glyph alignment rule` (b911273)
- `Apply glyph alignment to Help content cards` (db3d674)
- `Align Help callout icons with glyph tops` (7a6884b)
- `Tune Help callout icon visual alignment` (248ae4a)
- `Refresh Help callout alignment cache` (4b96d49)
- `Align Help callout icons to visible text` (633c451)
- `Top-align Help callout icons` (836696e)
- `Normalize Help Center page skeleton` (f6d7712)
- `Remove Help Center content box borders` (60063f5)
- `Fix workflow help breadcrumb links` (c783aba)
- `Refine Help Center icon alignment` (68b1457)
- `Top-align Help Center content icons` (0ade5a9)
- `Remove DevOps optional badges` (0d6e50d)
- `Normalize site font and skill command styling` (141d705)
- `Align help content box icons` (6c3bee5)
- `Fix help content box formatting` (aa4b1f4)
- `Apply S3 styling site-wide` (0fbd736)
- `Switch site fonts to IBM Plex` (120389b)
- `Center icons in homepage callouts` (40de7d6)
- `Promote S3 homepage theme` (e9e4071)

---

## [0.37.23] — 2026-06-10

## Features

- `feat(orchestration): keep SB in control of helper skill selection and workflow loop continuation`
- `feat(docs): migrate Lessons terminology to Learnings across the documentation scheme`
- `feat(memory): require Graphify-backed retrieval before planning and execution where available`

## Bug Fixes

- `fix(kay): default Codex-compatible live testing to MiniMax.io with MiniMax-M3`

## Documentation

- `docs(site): refresh public website and help center for SB-first orchestration, Graphify, Learnings, and Kay MiniMax-M3 testing`

## Tests

- `test(docs): verify Learnings doc scheme and template migration`
- `test(kay): verify MiniMax-M3 wrapper and isolated Kay config defaults`
- `test(runtime): verify Claude hook/runtime parity for workflow guards and session logging`

---

## [0.37.22] — 2026-06-09

## Bug Fixes

- `fix(codex): hydrate missing dependency skill sources from marketplace installs before fallback`
- `fix(codex): resolve hidden Silver quality-gate dimension sources from packaged Codex installs`
- `fix(codex): terminate live interactive sessions after verified completion prompts return`
- `fix(codex): initialize session-start markers for doc-scheme enforcement in live runs`
- `fix(codex): expose progressive-review-loop as a single /Silver picker entry`
- `fix(runtime): keep Claude progressive-review-loop escalation on Anthropic models`
- `fix(codex): stop hydrating retired helper-runtime skill surfaces into Codex installs`

## Removed

- `remove: retire Forge runtime files, docs, tests, and install surfaces`

## Tests

- `test: verify no active Forge runtime files or references remain`
- `test(codex): verify local installs keep one non-duplicated /Silver picker surface`
- `test(codex): verify marketplace-backed dependency skill discovery and install hydration`
- `test(codex): run full live release matrix with 53 passed and 0 failed`
- `test(release): rerun full suite with 2693 passed and 0 failed`

---

## [0.37.21] — 2026-06-08

## Bug Fixes

- `fix(codex): make packaged SB skill sources extensionless so Codex cannot surface /Silver Bullet picker duplicates`
- `fix(codex): expose only the silver route family in the native Codex picker mirror`
- `docs: refresh install and Help Center copy for the current Claude/Codex package model`

## Tests

- `test(codex): reject Markdown hidden skill-source files and redundant helper mirror entries`
- `test(codex): verify local installs expose one native /Silver picker surface`

---

## [0.37.20] — 2026-06-08

## Bug Fixes

- `fix(codex): normalize Silver picker titles`
- `fix(codex): resolve hidden quality-gate dimensions from packaged skill-source without exposing helper skills in the picker`
- `fix(live): ignore explicit non-use denials when scanning Codex transcripts for local skill-source bypasses`

## Tests

- `test: cover every SB skill scenario`
- `test(codex): verify picker title normalization, legacy stale-skill purging, and live local-source guard behavior`

---

## [0.37.19] — 2026-06-08

## Bug Fixes

- `fix(codex): prune stale SB picker surfaces from old cache versions and Codex temp backups`
- `fix(codex): keep local Codex skill picker entries exclusively on the native /Silver surface`
- `fix(runtime): clarify that Silver Bullet does not auto-switch host models`

## Tests

- `test(codex): cover stale marketplace, uppercase-backup, and sb-live-command temp picker cleanup`
- `test(runtime): reject stale automatic model-routing promises from current docs`

---

## [0.37.18] — 2026-06-08

## Bug Fixes

- `fix(codex): prevent plugin-cache skill source files from appearing in the Codex skill picker`
- `fix(codex): keep SB picker entries exclusively on the native /Silver surface`
- `fix(codex): refresh all installed SB cache versions from the safe package surface during install`

## Tests

- `test(codex): reject any packaged plugin *SKILL.md file that Codex could discover`
- `test(codex): verify isolated installs expose no duplicate /Silver Bullet picker entries`

---

## [0.37.16] — 2026-06-08

## Bug Fixes

- `fix(codex): use HOME-expanded runtime paths in generated package snippets`
- `fix(codex): keep SB picker skills on a single native /Silver surface`
- `fix(codex): add hook trigger parity coverage for exec_command and apply_patch`

## Documentation

- `docs: refresh website and Help Center for the current Codex package model`
- `docs: record June 2026 Codex picker and runtime path learnings`

---

## [0.37.15] — 2026-06-08

## Bug Fixes

- `fix(codex): remove plugin-owned SB skills surface from the Codex package`
- `fix(codex): mirror SB picker skills only through native ~/.codex/skills`
- `fix(codex): map legacy marketplace root skills into internal skill-source during install`

## Tests

- `test(codex): fail package sync when plugins/silver-bullet/skills exists`
- `test(codex): verify installer removes stale plugin skills during public-release refresh`
- `test(live): use native $silver entrypoint in full-surface prompts`

## [0.37.14] — 2026-06-08

## Bug Fixes

- `fix(codex): expose Silver Bullet picker skills only through the native /Silver mirror`
- `fix(codex): hydrate thin helper plugin skill surfaces in installs and isolated live runs`
- `fix(codex): suppress BrokenPipe tracebacks after transcript archival`
- `fix(live): ignore collapsed negative prompt text in local-source bypass scans`

## Tests

- `test(codex): prevent duplicate /Silver Bullet skill listings from the plugin manifest`
- `test(codex): verify helper plugin hydration and Codex PTY BrokenPipe handling`
- `test(live): gate Codex full-surface runs on hook failures, helper skills, and local-source bypass detection`

---

## [0.37.13] — 2026-06-07

## Bug Fixes

- `fix(codex): enforce native hook reliability in isolation`
- `fix(codex): enforce bare prompt workflow reliability`
- `fix(codex): mirror Silver Bullet picker skills`
- `fix(ci): satisfy shellcheck in prompt reminder`
- `fix(ci): keep deploy gate fallback aligned with template`
- `fix(ci): run secret scan on release branches`
- `fix(live): enforce Kay exec timeout in release gates`

## Tests

- `test(live): skip Kay timeout probe when expect is unavailable`
- `test(live): harden Kay MiniMax release gates`
- `test(live): fail release gates on Kay timeouts`

---

## [0.37.12] — 2026-06-01

## Bug Fixes

- `fix(codex): add native skill invocation adapter`
- `fix(codex): sanitize Codex packages and marketplace snapshots for runtime-native tool wording`

## Tests

- `test(codex): reject Claude-only tool requirements from Codex package surfaces`
- `test(codex): verify invoke-skill receipts before recording completed skills`

## Chores

- `chore(release): prepare v0.37.12`

---

## [0.37.11] — 2026-06-01

## Bug Fixes

- `fix(codex): reset the cached Codex marketplace clone before public refresh installs`
- `fix(codex): remove stale untracked Silver Bullet package skills before copying the live cache`

## Tests

- `test(codex): cover public-release refresh from a dirty marketplace clone with stale package skill directories`

## Chores

- `chore(release): prepare v0.37.11`

---

## [0.37.10] — 2026-06-01

## Bug Fixes

- `fix(codex): ignore stale top-level marketplace skills during public Codex refresh`
- `fix(codex): keep the published Silver Bullet package as the authoritative public-release skill surface`

## Tests

- `test(codex): cover public-release refresh with stale marketplace forge-delegate and writing-plans skill directories`

## Chores

- `chore(release): prepare v0.37.10`

---

## [0.37.9] — 2026-06-01

## Bug Fixes

- `fix(codex): expose /silver and /silver:* route tokens in Codex skill picker titles while preserving the Silver prefix`

## Tests

- `test(codex): assert every packaged silver route title includes its visible /silver route token`

## Chores

- `chore(release): prepare v0.37.9`

---

## [0.37.8] — 2026-05-31

## Bug Fixes

- `fix(codex): keep the plugin display name as Silver Bullet while prefixing Codex skill titles with Silver`
- `fix(codex): generate Silver: titles for every packaged Codex skill without duplicate Silver route prefixes`

## Tests

- `test(codex): assert plugin displayName remains Silver Bullet and every Codex skill title starts with Silver:`

## Chores

- `chore(release): prepare v0.37.8`

---

## [0.37.7] — 2026-05-31

## Bug Fixes

- `fix(codex): normalize SB skill picker labels to use the single Silver prefix`
- `fix(codex): prevent generated route skills from displaying as Silver: Silver: <skill>`

## Tests

- `test(codex): assert generated Codex picker labels do not use Silver Bullet or duplicate Silver prefixes`

## Chores

- `chore(release): prepare v0.37.7`

---

## [0.37.6] — 2026-05-31

## Bug Fixes

- `fix(codex): remove non-SB skills from the Silver Bullet package surface`
- `fix(codex): route plan-writing and branch-finishing workflow steps to Superpowers explicitly`
- `fix(codex): remove stale Forge delegation instructions from packaged SB runtime guidance`

## Tests

- `test(codex): assert Sidekick and Superpowers-owned skill directories are excluded from the SB Codex bundle`

## Chores

- `chore(release): prepare v0.37.6`

---

## [0.37.5] — 2026-05-31

## Bug Fixes

- `fix(codex): materialize the full Silver Bullet package during Codex marketplace release sync`
- `fix(codex): repair active Codex installs so the SB skill picker sees the packaged skills tree`
- `fix(codex): push marketplace package sync commits to the tracked upstream branch explicitly`

## Tests

- `test(codex): cover stale symlinked marketplace skills during release sync`
- `test(codex): cover marketplace sync from a local branch whose name differs from its upstream branch`

## Chores

- `chore(release): prepare v0.37.5`

---

## [0.37.4] — 2026-05-24

## Bug Fixes

- `fix(runtime): restrict Silver Bullet state writes to the active runtime root unless an explicit extra state root is allowlisted`
- `fix(tests): make Codex skill-recording tests self-isolate HOME and verify Kay state-root allowlisting`
- `fix(live): pin Kay-backed Codex runs to deepseek-v4-flash with low reasoning and text-only verification guards`

## Docs

- `docs(testing): restore Claude and Codex live-matrix defaults in release-facing test entrypoints`

## Chores

- `chore(release): prepare v0.37.4`

---

## [0.37.3] — 2026-05-22

## Bug Fixes

- `fix(codex): materialize the picker-facing skills tree as real files`
- `fix(tests): assert the Codex skills surface is not a symlink`

## Docs

- `docs(readme): reflect the materialized Codex skills tree`

## Chores

- `chore(release): prepare v0.37.3`

---

## [0.37.2] — 2026-05-21

## Bug Fixes

- `fix(live): route Kay live tests through opencode-go and keep MiniMax-M2.7 isolated`
- `fix(tests): skip direct MiniMax.io and Forge harness runs in Kay sessions`
- `fix(e2e): record completed surfaces in the inline full-surface journey`

## Docs

- `docs(readme): align live-test docs with the Kay opencode-go provider path`

## Chores

- `chore(release): prepare v0.37.2`

---

## [0.37.1] — 2026-05-19

## Bug Fixes

- `fix(release): harden CI gate before tagging` (`f4de5bd`)
- `fix(live): initialize runtime paths for the Claude/Codex live matrix`
- `fix(ci): replace inline trivial-file cleanup with a validator-friendly hook script`
- `fix(ci): seed Silver Bullet runtime env before direct hook test execution`

## Chores

- `chore(release): prepare v0.37.1`

---

## [Unreleased]

---

## [0.37.0] — 2026-05-19

## Highlights

- Silver Bullet now intercepts non-trivial SDLC intent, composes clarify and GSD handoffs around it, and keeps the orchestration boundary inside SB rather than ad hoc freestyle work.
- `silver:clarify` now behaves as a merged clarification front-end that absorbs Product Management framing and Superpowers brainstorming, then hands milestone creation to GSD when appropriate.
- Session logs now carry an `## Active Intent Ledger` section, and the request/completion hooks keep that ledger in sync even when skill state is already present from earlier runs.
- Release-prep docs, help surfaces, and month-level knowledge/learnings were updated to reflect the new orchestration model.

## [0.36.2] — 2026-05-17

## Bug Fixes

- `fix(live): stabilize Kay journey and archive transcript` (`e97f531`)

---

## [0.36.1] — 2026-05-17

## Refactoring

- `refactor(live): move Kay harness to KAY_HOME` (`4c74a24`)

## Bug Fixes

- `fix(release): wait for CI before publish` (`21a363f`)
- `fix(release): enforce marketplace repo push` (`370d43d`)

---

## [0.36.0] — 2026-05-17

## Bug Fixes

- `fix(tests): make live auth-cache test self-contained` (`3115713`)
- `fix(codex): align installer and live test paths` (`553e5ee`)

## Chores

- `chore(release): enforce marketplace sync` (`dc5ff0e`)

## Other

- `chore(release): prepare v0.36.0` (`491c010`)
- `Sync planning state for agents reorg` (`9418e85`)
- `refactor(live): move Kay harness to agents` (`7f0ee83`)

---

## [0.35.4] — 2026-05-16

## Bug Fixes

- Reorganize generated agent bundles under `agents/<agent-name>/...` so runtime-specific skill surfaces are generated from a shared canonical source.
- Harden the Kay-backed live e2e harness, including `gsd-scan` state recording and deterministic recovery from the injected route regression.
- Re-run the full verification gate, including the live e2e journey, before cutting the patch release.

---

## [0.35.3] — 2026-05-15

## Bug Fixes

- Fix the repo dogfood config so `skills.all_tracked` stays synchronized with the template, including `gsd-scan`.
- Keep the isolated Codex bundle and host-facing SB release surfaces synchronized for the patch release.
- Re-verify the repo with the full test suite and live harness before tagging the release.

---

## [0.35.2] — 2026-05-15

## Bug Fixes

- Fix the Codex live harness so `gsd-scan` state recording and live e2e completion are reliable again.
- Keep the isolated Codex bundle and host-facing SB release surfaces synchronized for the patch release.
- Re-verify the repo with the full test suite and live harness before tagging the release.

---

## [0.35.1] — 2026-05-15

## Bug Fixes

- Isolate Kay-backed Codex live tests so SB test runs no longer rewrite the user's real Codex hook cache.
- Stop duplicating Silver Bullet plugin hooks into user-level Codex hooks and seed trust from the installed plugin hook manifest.
- Pass Codex/Kay model-provider overrides through the live harness so MiniMax-backed isolated runs use `MiniMax-M2.7` consistently.
- Harden the live doc-scheme suite so Kay/MiniMax executes deterministic command-array updates instead of fragile synthesized shell heredocs.
- Seed isolated Kay/Codex live-test plugin caches and registry entries so E2E preflight runs without touching the user's real Codex state.
- Harden the inline E2E journey against unauthenticated GitHub CLIs and Kay/MiniMax turn loss by applying deterministic local recovery only inside the isolated test workspace.
- Package `scripts/workflows.sh` for Codex installs and teach composed-workflow skills to resolve it from the project or installed plugin, fixing missing workflow tracking in consumer repos.

---

## [0.35.0] — 2026-05-14

## Bug Fixes

- Align Silver Bullet hook and skill contracts with GSD lifecycle ownership.
- Fix Codex package version drift and stamp all release surfaces consistently.

## Features

- Position Silver Bullet as an Agentic Process Orchestrator around GSD.
- Add configurable plugin-runtime release gates so the four-stage/live-matrix gate can stay SB-plugin-specific until generalized.

## Documentation

- Refresh SB/GSD alignment guidance, enforcement docs, workflow docs, and release-gate notes.
- Update Help Center and website copy to describe SB+GSD first, with Superpowers and other plugins as selected helper boundaries.

---

## [0.34.0] — 2026-05-14

## Bug Fixes

- `harden codex-native live harness and release config` (`7cf1129`)

## Features

- `refresh Forge port for current SB` (`b71d838`)
- `align silver router flow composition with GSD` (`8271bda`)

## Other

- `prepare v0.34.0` (`04cd162`)
- `reconcile SB install and skill surface` (`6ad8327`)
- `update CHANGELOG and README badge for v0.33.0` (`4032476`)

---

## [0.33.0] — 2026-05-12

## Features

- `host-aware model routing and release hardening` (`a05c969`)
- `hard-block doc-scheme via full doc checklist coverage` (`54e32de`)
- `add silver handoff skill and retire deprecated tests` (`1b68ade`)

## Bug Fixes

- `stabilize codex release harness` (`917d857`)
- `align workflow docs with templates` (`9ba2b33`)
- `keep codex registry mirrors byte-identical` (`6077eec`)
- `create both codex config roots before writes` (`6debf4c`)
- `create codex config dirs before marketplace writes` (`e404985`)
- `seed codex cache aliases in both root variants` (`800ed5e`)
- `align v0.32.5 burn-down fixes` (`0134364`)
- `pin announcement to Silver Bullet Updates thread` (`e9a2662`)
- `stop waiting for pages in announcement` (`db535e1`)

## Tests

- `relax codex live enforcement state check` (`643d9b8`)
- `cover debug-dump hook` (`6093f9a`)

## Documentation

- `collapse live todo-app suite into one journey` (`c13001b`)
- `outline inline todo-app full-surface e2e` (`663dde2`)
- `add inline todo-app full-surface e2e design` (`cade841`)
- `clarify Agent SDK supports hooks via settingSources or programmatic API` (`5ce3bf2`)

## Other

- `Align skill coverage test with hook output` (`4093179`)
- `Seed Codex hooks mirror in install test` (`87e0f80`)
- `Make Codex install test portable on CI` (`b9c139a`)
- `Fix Codex install test setup for case-sensitive filesystems` (`b578ea8`)
- `Fix session-start prompt replay ordering` (`e53a484`)
- `Fix CI shellcheck warnings in hooks` (`2f67338`)
- `Fix shellcheck issue in skill discovery` (`0fd1636`)
- `Fix CI mode checks and remove transcript archives` (`9e7dc54`)
- `Checkpoint current Silver Bullet changes` (`74ae26f`)
- `enforce doc-scheme gates and strengthen documentation contract` (`6fbf1a8`)

---

## [0.32.4] — 2026-05-08

## Patch

**Codex picker surface restoration.** Silver Bullet now keeps skills as the source of truth while materializing the Codex-facing `silver:` command surface from the packaged skills tree, so `/silver` and `/silver:*` show up in the picker again without a separate Silver Bullet Commands plugin.

## Fixes

- `scripts/sync-codex-package.sh` now points the packaged `skills/` tree at the Codex marketplace skill bundle.
- `tests/integration/test-skill-execution-paths.sh` now recognizes the `silver:` command aliases and built-in command wrappers used by the Silver Bullet workflows.
- The Codex install and packaging tests now assert the picker-visible Silver Bullet command surface stays intact.

## [0.32.3] — 2026-05-07

## Patch


## Fixes

- `commands/*.md` now carry `silver:` labels so the picker shows the Silver Bullet surface inside the main plugin.
- `commands/silver.md` adds the `/silver` router inside the same SB bundle.
- The shared Codex marketplace no longer exposes a separate `plugins/silver` package.

---

## [0.32.2] — 2026-05-07

## Patch

**CI hardening and release safety.** Fixes the Codex installer path resolution on mixed-case config locations, makes the GSD SDK shim and workflow tests portable, and keeps the lifecycle-gap integration gate deterministic in CI.

## Fixes

- `scripts/install-codex.sh` now resolves `~/.Codex/config.toml` and `~/.codex/config.toml` safely and creates the config directory before writing.
- `tests/scripts/test-gsd-sdk-shim.sh` now supplies a local `gsd-tools.cjs` fixture so the shim test does not depend on ambient installs.
- `tests/scripts/test-workflows.sh` now uses a cross-platform mtime helper for the heartbeat assertion.
- `tests/integration/test-e2e-lifecycle-gaps.sh` now provides a local invocable `verification-before-completion` fixture so the post-review gate is deterministic in CI.

## [0.32.1] — 2026-05-07

## Live Release Hardening

**What:** Hardens the release path with the Claude/Codex live matrix, the todo-app live suite, and the mandatory pre-release quality-gate rerun.

## Features

- `tests/live/run-live-tests.sh` now runs the shared Claude/Codex live matrix as a release gate.
- `tests/e2e-live/run-e2e-live-tests.sh` adds the realistic todo-app live suite so SB is proven against an actual app workflow.
- `hooks/completion-audit.sh` now requires the sidekick quality-gate markers plus the full-test-suite rerun marker before `gh release create`.

## Fixes

- `scripts/install-claude.sh` refreshes the cached SB hooks deterministically and uses the stable interactive runner path.
- `hooks/session-start` now clears the sidekick quality-gate state along with the normal SB session markers.
- The completion-audit and session-start tests were updated to match the new mandatory release sequence.

## Documentation

- Release, testing, and internal quality-gate docs now describe the new two-stage live proof and the mandatory rerun before release.
- The SB workflow docs and templates now distinguish the main SB state file from the sidekick quality-gate file.

## Codex packaging and release refresh

**What:** Ships the Codex-facing SB package as SB-only, registers the shared Codex marketplace for third-party wrappers, and keeps Claude packaging intact.

## Features

- `scripts/install-codex.sh` now registers the shared `alo-labs/codex-plugins` marketplace, installs GSD and Superpowers from their official sources, and purges legacy SB skill copies from `~/.agents/skills`.
- `scripts/sync-codex-package.sh` now keeps the Codex bundle scoped to SB-owned surfaces only, with project-instance artifacts and third-party wrappers excluded from the package snapshot.
- Live E2E coverage now runs against both Claude and Codex with a shared harness and runtime adapters.

## Fixes

- GSD bootstrap no longer uses `eval`; the installer now invokes the parsed command directly.
- Codex live tests now isolate the blocked-edit guard only where needed so docs workflows remain open.

## Documentation

- README, site, templates, and Forge parity docs now reflect the `v0.32.0` release surfaces.
- SB Codex and Claude packaging descriptions now match the new split between SB-owned assets and dependency installs from official sources.

## [0.31.1] — 2026-05-06

## Patch

**Docs/state sync.** Aligns the shipped repo state with the `v0.31.1` tag, refreshes current-version surfaces, and leaves the inventory unchanged.

## [0.31.0] — 2026-04-28

## Headline

**Forge Port Completion.** Closes every dependency-port gap identified by the comprehensive Forge port audit (2026-04-28), aligned with `forgecode.dev/docs/`. The v0.28.0 first-round port was missing the entire Forge slash-command surface, several upstream agents/commands, and the Silver Bullet runtime spec + project-bootstrap templates that `silver-init` depends on. v0.31.0 ships all of these.

## Forge slash commands (NEW surface)

- `forge/commands/` directory established. Per `forgecode.dev/docs/commands/`, slash commands belong here and invoke with the `:` prefix.
- **45 GSD commands ported** from upstream → `forge/commands/gsd-*.md` (new-project, new-milestone, discuss-phase, plan-phase, execute-phase, analyze-dependencies, plan-milestone-gaps, verify-work, secure-phase, validate-phase, code-review, code-review-fix, add-phase, insert-phase, complete-milestone, audit-milestone, milestone-summary, map-codebase, autonomous, debug, explore, fast, do, quick, resume-work, pause-work, next, forensics, docs-update, pr-branch, ui-phase, ui-review, spec-phase, ai-integration-phase, audit-uat, eval-review, ingest-docs, import, add-backlog, scan, add-tests, add-todo, check-todos, cleanup, update).
- **3 Superpowers commands ported**: `:brainstorm`, `:execute-plan`, `:write-plan`.
- **1 KW product-management command ported**: `:pm-brainstorm`.
- Each ported command uses minimal Forge command frontmatter (`name`, `description`); body preserved verbatim. Claude-Code-only fields stripped.

## Forge agents (closing the gap)

- **`gsd-doc-classifier`** + **`gsd-doc-synthesizer`** ported from upstream GSD (32/33 → 33/33).
- **`code-reviewer`** ported from `obra/superpowers/agents/code-reviewer.md` with proper Forge frontmatter (`id`, `description`, `tool_supported: true`).

## SB templates port

- All `templates/*` copied to `forge/templates/`: `silver-bullet.md.base`, `workflow.md.base`, `silver-bullet.config.json.default`, `CHANGELOG-project.md.base`, `doc-scheme.md.base`, `CLAUDE.md.base`, plus subdirs (`knowledge/`, `learnings/`, `sessions/`, `specs/`, `workflows/`).
- `forge-sb-install.sh` now installs templates → `~/forge/silver-bullet/templates/` — closes the broken `silver-init` (forge edition) bootstrap path.
- `forge/AGENTS.project.template` enriched with adapted `CLAUDE.md.base` override directive.

## Skill name reconciliation

8 short-form GSD skills renamed to upstream long-form names so cross-references resolve correctly: `gsd-discuss-phase`, `gsd-execute-phase`, `gsd-plan-phase`, `gsd-secure-phase`, `gsd-validate-phase`, `gsd-verify-work`, `gsd-code-review`, `gsd-code-review-fix`. SKILL.md `name:` frontmatter updated to match new directory.

## Documentation

- `forge/PARITY.md`: corrects the v0.28.0 "skill bodies replace commands" claim; documents `forge/commands/` as the slash-command surface; adds Slash Command Map and SB Templates Map sections.
- `forge/PARITY-REPORT.md` regenerated with v0.31.0 inventory + audit-pass status across all categories.
- `forge/scripts/smoke-test.sh` extended to 8 sections (was 6); validates `forge/commands/` (≥40), critical command presence, `forge/templates/` (3 base templates), and the new `code-reviewer` agent.

## Installer

- `forge-sb-install.sh`: new `install_commands_to()` and `install_templates_to()` helpers. Global install now deploys commands → `~/forge/commands/` and templates → `~/forge/silver-bullet/templates/`.

## Audit alignment with forgecode.dev/docs

- Skills auto-load by description-context match (per `/docs/skills/`); cross-skill references are NOT chain-resolved.
- Slash commands are a separate Forge primitive (per `/docs/commands/`).
- Custom agents identified by `id` field, with `description` + `tool_supported: true` for inter-agent calls (per `/docs/creating-agents/`).

## Versions bumped

`package.json`, `.silver-bullet.json`, `templates/silver-bullet.config.json.default`, `forge/templates/silver-bullet.config.json.default`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, README badge — all → `0.31.0`.

## [0.30.0] — 2026-04-28

## Headline

**Open-Issue Sweep.** Closes every open GitHub issue against `alo-exp/silver-bullet` as of 2026-04-28: 17 in-scope issues plus 6 already-implemented closed at session start. Phase 76 ships four hook-layer bug fixes (#85, #86, #87, #88); Phase 77 documents the Claude Agent SDK / claude.ai/code runtime limitation that is the shared root cause of #48 and #50; Phases 78–79 file 7 design-strategic items as planted seeds; Phase 80 lands documentation including a new GSD vs Silver Bullet comparison and an SB-only install path.

## Bug fixes

- **#86** — `count_complete_flow_rows` now treats `skipped` as terminal alongside `complete`. Workflows with legitimately-skipped flows (e.g. FLOW 9 UI QUALITY for a CLI-only tool) no longer block `gh release create` indefinitely. Fix applied to `hooks/lib/workflow-utils.sh` and three inline fallbacks. 3 regression tests (`WF-PASS2-I/J/K`).
- **#88** — HOOK-14 filters porcelain output through a transient-path allowlist. Built-in defaults: `.codex/scheduled_tasks.lock`, `.codex/settings.local.json`, `.superpowers/`, `.planning/workflows/`, `REVIEW.md`. Project-configurable via `.silver-bullet.json` `hooks.stop_check.transient_path_ignore_patterns`. Closes the post-release infinite-loop where Stop kept blocking after a successful push because runtime artifacts kept the tree "dirty". 3 regression tests (`#88-A/B/C`).
- **#85** — Stop hook applies the `required_planning` floor only (typically `silver-quality-gates`, or `silver-blast-radius` + `devops-quality-gates` for devops). The full `required_deploy` list remains enforced by `completion-audit.sh` at delivery commands per the documented two-tier model. Ad-hoc skill-file additions no longer demand `deploy-checklist` / `create-release` / `testing-strategy` / `documentation` / `tech-debt`. 3 regression tests (`#85-A/B/C`).
- **#87** — SessionStart reads the `source` field from stdin (`startup`/`resume`/`clear`/`compact`). Only `startup` and `clear` mutate state; `resume` and `compact` are benign and no longer wipe `gsd-*` markers mid-feature. Branch-mismatch wipe path now requires BOTH `current_branch` and `stored_branch` non-empty, closing the Bug 3 data-loss path. Branch-file writes are verified post-write. 9 regression tests (`#87-A/B/C/D`).

## Documentation

- `silver-bullet.md §12` + `templates/silver-bullet.md.base §11` (closes #48, #50): new Runtime Compatibility section documenting that hooks fire only in Claude Code CLI, not in Claude Agent SDK or claude.ai/code web sessions.
- `docs/gsd-vs-silver-bullet.md` (new, closes #73): comprehensive comparison.
- `README.md` (closes #74): split install into Path A (full) / Path B (SB-only without GSD).
- `docs/internal/stop-hook-fp-audit-v0.30.md` (new, closes #71): exhaustive enumeration of every block-emitting code path in `stop-check.sh` and `completion-audit.sh`.
- `silver-bullet.md` + `templates/silver-bullet.md.base` (closes #59): explanatory comments document the §10 vs §9 numbering asymmetry; 9 skill files updated to reference `.base §9X` (was incorrectly `§10X`).

## Planted seeds

Seven items deferred to future milestones via `.planning/seeds/`: SEED-001 (#68 Skill Gap Check), SEED-002 (#67 SDLC roadmap), SEED-003 (#75 path parallelism), SEED-004 (#64 bypass-permissions trace), SEED-005 (#69 CLAUDE.md merge UX), SEED-006 (#70 cross-surface docs audit), SEED-007 (#72 intermediate-boundary verification). Each seed documents trigger conditions for re-surfacing.

## Tests

- 18 new regression tests across the three touched hook test files.
- 2 integration test alignments for the #85 stop-tier semantics.
- 19 integration suites + 4 hook unit-test files all green (1217 tests, 0 failed).

## Pre-closure

6 issues closed at session start as already-implemented in main: #62, #76, #79, #80, #81, #83.

## Other

- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` bumped to 0.30.0 (were stale at 0.26.0).
- Backlog issue #90 filed for follow-up regex-shape validation on `transient_path_ignore_patterns`.
- `.planning/milestones/v0.30.0-{REQUIREMENTS,ROADMAP}.md` and `.planning/workflows/<id>.md` document the milestone scope and composed-workflow tracker.

---

## [0.29.1] — 2026-04-28

## Headline

**Composed-workflow tracker (Pass 2).** Replaces the v0.22 single-file `.planning/WORKFLOW.md` model with per-instance `.planning/workflows/<id>.md` files plus a strict `SB_WORKFLOW_ID`-matched final-delivery gate. This closes the v0.29.0 deferred Pass 2: a stale milestone WORKFLOW.md from a prior `silver:*` composition can no longer silently pass the final-delivery gate, because the gate now requires an explicit, in-flight workflow id and verifies its Flow Log is 100% complete.

## Features

- **`scripts/workflows.sh`** — composed-workflow lifecycle helper with 7 ops: `start`, `heartbeat`, `complete-flow`, `complete`, `list`, `get`, `active`. Per-instance markdown files at `.planning/workflows/<id>.md`. ID scheme `<UTC-compact>-<6char>-<composer>` (e.g. `20260428T120000Z-7a9bcd-silver-feature`). On `complete`, files archive to `.planning/workflows/.archive/` and are removed from the active set, so the strict gate cannot match a stale id.
- **Strict `SB_WORKFLOW_ID` final-delivery gate** — `completion-audit.sh` now blocks `gh release create` / `gh pr create` / `gh pr merge` / `deploy` when `.planning/workflows/` has active files unless: (a) `SB_WORKFLOW_ID` is set, (b) it matches an active file, (c) the matched file's Flow Log is 100% complete. Backward-compatible: when no `.planning/workflows/` exists, the legacy required-skills gate continues unchanged.
- **Section-scoped Flow Log counting** — `hooks/lib/workflow-utils.sh` row-counters (`count_flow_log_rows`, `count_complete_flow_rows`) now scope to the `## Flow Log` heading and stop at the next `## ` heading. Closes the digit-row inflation hole (S4 regression guard) where Phase Iterations / Autonomous Decisions tables in the same file would falsely inflate Flow Log counts.
- **`compliance-status.sh` flow progress** — when `SB_WORKFLOW_ID` matches an active workflow, the status line now surfaces `FLOW <complete>/<total> (id=<id>)` instead of just an active count.
- **Composer integration** — 6 silver-* skills (`silver-feature`, `silver-bugfix`, `silver-ui`, `silver-devops`, `silver-deep-research`, `silver-release`) replace their legacy "Create WORKFLOW.md" step with workflows.sh-based start/complete-flow/complete instructions. Each skill instructs Claude to capture and export `SB_WORKFLOW_ID`.

## Tests

- 31 new unit tests for `scripts/workflows.sh` (`tests/scripts/test-workflows.sh`) covering id format, file format, complete-flow status flip, archive-on-complete, list/get/active operations, invalid id rejection, symlink-write refusal (SEC-02 pattern), composer slug sanitization, and heartbeat mtime advance.
- 8 new strict-gate hook tests (WF-PASS2-A..H) in `tests/hooks/test-completion-audit.sh`: missing `SB_WORKFLOW_ID` blocks, malformed id blocks, incomplete workflow blocks with progress, complete workflow + skills passes, mismatched id blocks, intermediate commits unaffected, no-workflows-dir falls through, and the digit-row inflation guard.
- 4 new integration scenarios in `tests/integration/test-compliance-status-scenarios.sh` (S4, S8, S9, plus reactivated S4 inflation guard) covering FLOW N/M display, malformed-id fallback, and section-scoped counting.

## Other

- `.planning/workflows/` added to `.gitignore`. Active and archived workflow files are local runtime state, never committed.

## Deferred

- Composer integration in remaining skills (`silver-spec`, `silver-fast`) — these don't have a "Create WORKFLOW.md" anchor today; will be added when those flows expand.
- `prompt-reminder.sh` already lists active workflow IDs in additionalContext (since v0.29.0). Pass 2 keeps that behavior; no changes needed.

---

## [0.29.0] — 2026-04-28

## Headline

**Multi-Agent Phase Coordination.** Any number of SB-bearing coding agents (Claude-SB, Forge-SB, Codex-SB, OpenCode-SB) can now cooperatively work on the same project folder. Each phase under `.planning/phases/<NNN>/` is owned by exactly one runtime at a time, enforced via a shared atomic lock primitive. Cross-runtime delegation (`/forge-delegate`) is the controlled exception.

## Features

- **Phase-lock primitive** — `.planning/scripts/phase-lock.sh` exposes 4 atomic operations (`claim`, `heartbeat`, `release`, `peek`) over `.planning/.phase-locks.json`. flock-atomic, gitignored, with stale-TTL steal recovery (default 1800s). Identity tags `claude` / `forge` / `codex` / `opencode` configurable via `multi_agent.identity_tags[]`.
- **Claude-SB integration** — three new hooks (`hooks/phase-lock-claim.sh`, `hooks/phase-lock-heartbeat.sh`, `hooks/phase-lock-release.sh`) wired via `PreToolUse`/`PostToolUse`/`Stop`/`SubagentStop`. Conflict path emits stderr block-message + exit 2 (Claude Code interprets as a hard block). Heartbeat throttled to once per 5 min per phase.
- **Forge-SB integration** — three new custom agents (`forge-claim-phase`, `forge-heartbeat-phase`, `forge-release-phase`) invoked at phase boundaries by 6 silver-* parent skills (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-release, silver-spec). `forge-session-init` peeks active locks and surfaces non-self locks in the session summary.
- **Cross-runtime delegation** — `/forge-delegate` (Claude-SB and Forge-SB sides). Spawns a sibling runtime with `SB_PHASE_LOCK_INHERITED=true` so the child does not double-claim under the parent's existing lock. Structured markdown result contract (`## FILES_CHANGED`, `## ASSUMPTIONS`, `## REQ-IDS`) integrated back into the parent phase's working SUMMARY. Default 1200s timeout; on timeout, parent's lock stays intact for manual continuation.
- **Informational lock-owner peek** — `completion-audit.sh` and `stop-check.sh` register an EXIT-trap helper that emits a stderr WARN when the phase resolved from `$PWD` has no active lock or is owned by a non-`claude` runtime. Non-blocking, preserves original exit code.
- **User-facing docs** — `docs/multi-agent-coordination.md` with state diagram, two-agent collaboration walkthrough, delegation flow, configuration reference, diagnostics. silver-bullet.md §11, templates/silver-bullet.md.base §10, forge/PARITY.md and forge/AGENTS.md.template all gain Multi-Agent Coordination sections.

## Fixes

- **Enforcement leak from stale `.planning/WORKFLOW.md`** (Pass 1 hotfix in v0.29.0): a previous milestone's `silver:*` composition left a WORKFLOW.md showing all flows complete on disk after the milestone shipped. `completion-audit.sh` and `dev-cycle-check.sh` short-circuited to "delivery allowed" without checking the required-skills floor — letting every commit and the entire next-milestone release pass against any state. The legacy WORKFLOW.md gate is retired across `completion-audit.sh`, `dev-cycle-check.sh`, and `spec-floor-check.sh`. Informational consumers (`prompt-reminder.sh`, `compliance-status.sh`) migrated to read `.planning/workflows/` directory shape (Pass 2 will populate it). Until then, all gates fall through to the legacy required-skills floor, which is the correct behavior whenever no composed workflow is active.

## Tests

- Phase-lock primitive: `tests/scripts/test-phase-lock.sh` (37 cases, 0 failed).
- Claude-SB hooks: `tests/hooks/test-phase-lock-claim.sh` (19 cases), `test-phase-lock-heartbeat.sh` (10 cases), `test-phase-lock-release.sh` (11 cases).
- Multi-agent integration: `tests/integration/test-multi-agent-coexistence.sh` (17 cases — TEST-01 two-agent race, TEST-02 stale-TTL steal, TEST-03 SB_PHASE_LOCK_INHERITED no-double-claim).
- Pass 1 hotfix coverage: `tests/hooks/test-completion-audit.sh` and `test-dev-cycle-check.sh` updated with WF-PASS1-A/B/C scenarios; `tests/integration/test-compliance-status-scenarios.sh` rewritten around the new `WORKFLOWS: N active` display.

## Other

- New config keys under `multi_agent`: `identity_tags[]`, `stale_lock_ttl_seconds`, `delegation_timeout_seconds`.
- New planning artifacts: `.planning/phases/070-*/070-SUMMARY.md` through `074-*/074-SUMMARY.md`, plus per-plan SUMMARY files inside Phase 71.
- `forge/PARITY-REPORT.md` updated with v0.29.0 outcomes and "ship v0.29.0" recommendation.

## Deferred to Pass 2

The proper composed-workflow tracker — `scripts/workflows.sh` helper + per-instance `.planning/workflows/<id>.md` files + strict `SB_WORKFLOW_ID`-matched final-delivery gate + composer integration across all silver-* skills — is deferred to v0.29.x or v0.30.0 backlog. Pass 1 (this release) restores correct gate enforcement; Pass 2 adds richer tracking on top.

---

## [0.28.0] — 2026-04-27

## Headline

**Complete port of Silver Bullet to the Forge coding agent.** Full SB workflow now runs on `forgecode.dev` with 100% structural and behavioural parity to Claude Desktop.

## Features

- `feat(forge,phase-65)`: Bulk-copy 106 skills to `forge/skills/` (61 SB + 14 Superpowers + 33 Anthropic knowledge-work) — all using identical Claude Code SKILL.md format (`6de1d98`)
- `feat(forge,phase-66)`: Convert 18 SB hooks to 10 Forge custom agents (`forge-pre-commit-audit`, `forge-pre-pr-audit`, `forge-task-complete-check`, `forge-roadmap-freshness`, `forge-spec-floor-check`, `forge-uat-gate`, `forge-pr-traceability`, `forge-ci-status-check`, `forge-forbidden-skill-check`, `forge-session-init`) — invoked as tools by the main agent at gating moments since Forge has no hooks (`bb8a651`)
- `feat(forge,phase-67)`: Port 31 GSD subagents to Forge custom agents at `forge/agents/` per `forgecode.dev/docs/creating-agents/` — proper context isolation, restricted `tools[]`, `tool_supported: true` (`9f3a351`)
- `feat(forge,phase-68)`: Rewrite `forge-sb-install.sh` as copy-based, idempotent installer; rewrite `AGENTS.md.template` as Forge-adapted silver-bullet.md (drives hook-agent gating + subagent-as-tool delegation); add `forge/PARITY.md` capability map (`86c2941`)
- `feat(forge,phase-69)`: Add `forge/scripts/smoke-test.sh` (21+ structural assertions); add `forge/PARITY-REPORT.md` documenting structural and behavioural parity; install on test app (`05b482b`)

## Documentation

- `docs(forge)`: Add Forge runtime evidence to PARITY-REPORT — Forge CLI v2.12.9 confirmed loading 114 skills + 46 agents; hook-agent invocation tests #1 (`forge-spec-floor-check`) and #2 (`forge-pre-commit-audit`) returned the exact specified BLOCK/ALLOW outputs (`ca0a7ff`)
- `docs(v0.28.0)`: Pivot Phase 66/67 to Forge custom agents after `forgecode.dev/docs/creating-agents/` research (`cdc53f5`)
- `docs(v0.28.0)`: Restructure milestone after Forge docs research — skill format identical, hooks→agents, subagents→agents (`9ef3836`)
- `docs`: Create milestone v0.28.0 roadmap, requirements, kickoff (`5d9c2b0`, `cc20b89`, `bbf8e63`)
- `docs(065)`: Create + preserve phase plans for historical record (`3a0aa12`, `18ffff3`)
- `docs(v0.28.0)`: Mark all 5 phases structurally complete (`6726354`)

## Fixes

- `fix`: Restore DOC-03 completion marker in REQUIREMENTS.md (`37033be`)

## Chores (carried over from v0.27.1 finalization)

- `chore`: Bump config_version and version to 0.27.1 (`eeccf87`)
- `chore(release)`: Update CHANGELOG and README badge for v0.27.1 (`a32009c`)

## Inventory

| Artifact | Count | Path |
|---|---|---|
| Skills | 106 | `forge/skills/` |
| Custom agents | 41 | `forge/agents/` |
| Installer | 1 | `forge-sb-install.sh` |
| Templates | 2 | `forge/AGENTS.md.template`, `forge/AGENTS.project.template` |
| Parity docs | 2 | `forge/PARITY.md`, `forge/PARITY-REPORT.md` |
| Smoke test | 1 | `forge/scripts/smoke-test.sh` |

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/alo-exp/silver-bullet/main/forge-sb-install.sh | bash
```

Or local:
```bash
git clone https://github.com/alo-exp/silver-bullet.git
bash silver-bullet/forge-sb-install.sh
```

---

## [0.27.1] — 2026-04-27

### Bug Fixes

- `fix: sync deploy-gate-snippet.sh hardcoded REQUIRED_DEPLOY with template` (ae15080): CI assertion caught deploy-gate snippet still had the old 12-skill list including superpowers v4 skills (testing-strategy, documentation, deploy-checklist, tech-dead). Scripts generated by /silver:init would always block deploys since these skills no longer exist in superpowers v5.x and can never be recorded.

---

## [0.27.0] — 2026-04-27

### Features

- `INIT-01: rewrite silver-init steps 3.1b/3.1c for comprehensive CLAUDE.md conflict resolution` (ce8e860): detects and handles existing CLAUDE.md — prompts overwrite, merge, or abort instead of silently clobbering
- `stop hook audit: enumerate false-positives, fix S-06 comment, add Test 15` (62d9b5f): documents all HOOK-14 exit paths; Test 15 covers same-branch state-drift edge case

### Bug Fixes

- `fix: remove superpowers v4 skills from required_deploy` (14c4b75): testing-strategy, documentation, deploy-checklist, tech-debt removed — skills no longer exist in superpowers v5.x and could never be recorded
- `fix(stop-check): skip enforcement when state is from a different branch` (4624e6d): cross-session branch-drift no longer causes spurious blocks when state was recorded on a different branch
- `fix: restore IS_NEW_FILE guard in silver-rem size-cap code block` (c04e9be): guard removed by SKL-01 trim was still required; restored to prevent size-cap block on new files
- `fix: restore mktemp/mv to silver-add Allowed Commands` (75a2d72): SKL-01 trim accidentally removed mktemp/mv which Step 4d still requires for atomic config rewrite
- `fix: correct marketplace source format and enrich plugin metadata` (7aa72a1)

### Tests

- `test: add TST-01 and TST-02 test coverage` (a947bba): session-log-init and stop-check branch-scope tests
- `fix: update stale S2.4 integration test comment and marker` (7eeb5ca): test now uses custom-marker-1 to accurately reflect CHR-03 sed filter removal

### Documentation

- `docs: create sb-without-gsd.md and sb-vs-gsd.md` (591f643): two new help pages clarifying Silver Bullet standalone use and its relationship with GSD
- `docs: fix install command and stale version refs in help site` (a5857e4)

### Chores

- `chore(skills): trim silver-add/silver-rem to <300 lines` (24ef1e5): §10a→9a subsection labels corrected

---

## [0.26.0] — 2026-04-25

### Bug Fixes

- `fix(phase-55): BUG-01/02/05 — hook & script bug fixes` (6587b62): T2-1 test fix, dev-cycle-check regex tightened, session-log-init TOCTOU fixed with UUID token
- `fix(phase-56): BUG-03/04 + QUAL-01/02 — skill bug fixes & quality` (001d00b): silver-add precise OAuth scope regex, silver-remove POSIX tmpfile+mv, session log discovery standardized, silver-rem INDEX.md mutations explicit
- `fix(silver-release): move tag creation after gsd-complete-milestone to eliminate post-release patches` (94835ee)
- `fix(silver-create-release): replace awk -v multiline with head/printf/tail for CHANGELOG` (1cb992b)
- `fix(dev-cycle-check): tighten quote-exemption to block quoted redirect targets` (ecc5f16)
- `fix(dev-cycle-check): add veto to prevent mixed-quote-style bypass` (26e96db)
- `fix(session-log-init): write lock file and sentinel-pid before disown` (869e987)
- `fix(review-r2): sentinel-lock cleanup + tee process-sub bypass gap` (f573b82)

### CI Hardening

- `feat(phase-57): CI-01/02 — CI hardening` (38bab1d): diff step enforces docs/workflows/ vs templates/workflows/ parity; jq assertions for required_deploy/all_tracked correctness

### Skill Quality

- `feat(phase-58): QUAL-03/04 — silver-scan quality improvements` (2d32132): local-tracker cross-reference in Step 4-iv; two-pass counter explanation in summary block

### Security

- `fix(security): add content injection guards to 3 hooks (SENTINEL H-1/H-2/H-3)` (e7fe6a0): allowlist regex + jq encoding in spec-session-record.sh, uat-gate.sh, roadmap-freshness.sh — SENTINEL v2.3 CLEAR

### Documentation & Chores

- `docs: accuracy fixes for v0.26.0 release` (7a57517): enforce 11-layer count, fix Node.js → Bash, update version badges
- `docs(consistency): fix enforcement layer count to 11 across all docs` (6c61778)
- `docs(site): update skill count, layer count, and version across site` (24b13b6)
- `chore: archive v0.26.0 milestone` (2084661)

---

## [0.25.1] — 2026-04-25

**Patch release.** Post-release CI fix and milestone archival.

### Bug Fixes

- **FIX** (`3cfc390`): `silver-scan` — removed literal `FIXME` from keyword list documentation to pass skill integrity CI test (`test-skill-integrity.sh` matches bare `FIXME` case-insensitively, no brackets required).

### Chores

- Milestone archival: `REQUIREMENTS.md` archived to `.planning/milestones/v0.25.0-REQUIREMENTS.md`, `ROADMAP.md` archived to `.planning/milestones/v0.25.0-ROADMAP.md`.
- Added `RETROSPECTIVE.md` with v0.25.0 retrospective section.
- Updated `ROADMAP.md`, `MILESTONES.md`, `PROJECT.md`, `STATE.md` to reflect milestone completion.
- Added `UAT.md` with 24/24 criteria PASS for v0.25.0.

---

## [0.25.0] — 2026-04-24

**Issue Capture & Retrospective Scan milestone.** Closes the loop on deferred-item capture: two new filing skills (`/silver-add`, `/silver-remove`), a knowledge/learnings capture skill (`/silver-rem`), mandatory auto-capture enforcement in all orchestrator skills, a forensics audit (13 gaps fixed, 100% equivalence with gsd-forensics), a marketplace-based update overhaul (`silver-update`), and a retrospective session scanner (`/silver-scan`).

### New Skills (FEAT)

- **FEAT-SCAN** (`3679980`, `5e434e3`): `/silver-scan` — retrospective session scanner. Globs `docs/sessions/*.md`, detects deferred items and knowledge/learnings insights, cross-references git log / CHANGELOG / GitHub Issues to exclude already-addressed items, Y/n human gate per candidate (20-cap per pass), files via `/silver-add` and `/silver-rem`.
- **FEAT-ADD** (Phase 49): `/silver-add` — classify-and-file skill for issues and backlog items. Routes to GitHub Issues + project board or local `docs/issues/ISSUES.md` / `BACKLOG.md`. Assigns IDs, caches board discovery, rate-limit resilient.
- **FEAT-REMOVE** (Phase 50): `/silver-remove` — removes issues/backlog items by ID. Closes GitHub issues as "not planned" or inline-marks `[REMOVED]` in local docs.
- **FEAT-REM** (Phase 50): `/silver-rem` — captures knowledge or learnings insights into `docs/knowledge/YYYY-MM.md` or `docs/learnings/YYYY-MM.md` per doc-scheme. Updates `docs/knowledge/INDEX.md` on new monthly file creation.

### Enforcement (CAPT)

- **CAPT-01/CAPT-03** (Phase 51): `silver-bullet.md` and `templates/silver-bullet.md.base` gain §3b-i and §3b-ii — mandatory auto-capture instructions. All five orchestrator skills (silver-feature, silver-bugfix, silver-ui, silver-devops, silver-fast) wired with Deferred-Item Capture blocks.
- **CAPT-02** (Phase 51): Session logs gain `## Items Filed` section. `silver-release` Step 9b presents consolidated post-release filing summary.

### Skills — Update & Forensics (UPD / FORN)

- **UPD-01/UPD-02** (Phase 53): `silver-update` overhauled — `claude mcp install silver-bullet@alo-labs` replaces git clone as sole install mechanism. Step 6 atomically removes stale `silver-bullet@silver-bullet` registry entry and cache directory post-install.
- **FORN-01/FORN-02** (Phase 52): `silver-forensics` audited against gsd-forensics across 6 functional dimensions. 13 gaps identified and fixed: scope-drift detection, stuck-loop file-frequency analysis, regression grep, evidence gathering expanded to 8 items, artifact completeness matrix, output-side redaction (path stripping, API key scrubbing, diff truncation).

### Bug Fixes (pre-release review)

- Fixed `silver-bullet.md` and template §5.1 to check `silver-bullet@alo-labs` registry key first (fallback to legacy key) — post-marketplace-update the legacy key is deleted.
- Fixed `silver-rem` hardcoded "Silver Bullet" project name in knowledge frontmatter; now reads from `.project.name` in config.
- Fixed `silver-rem` knowledge/learnings entries to insert immediately after the category heading (not at EOF).
- Fixed `silver-rem` overflow (-b) files missing YAML frontmatter and category headings on creation.
- Fixed `silver-scan` Step 7b missing `-F` flag on knowledge/learnings cross-reference grep (untrusted session log content).
- Fixed `silver-scan` `CANDIDATE_COUNT` now counts all presented candidates (Y+n), not just filed items.
- Fixed `silver-add` Step 4e rate-limit path now proceeds to session log (Step 6) before output step.
- Fixed `silver-release` Step 9b.2 `(none)` grep to use `-F` (portable fixed-string match).
- Fixed `silver-update` Step 6a jq path to use `.plugins["silver-bullet@silver-bullet"]` (correct nested structure).
- Fixed `silver-update` Step 6b `rm -rf` to guard against unset `$HOME`, symlinks, and path prefix.
- Fixed `silver-remove` to add strict `^SB-[IB]-[0-9]+$` regex guard after case statement, rejecting IDs with non-numeric trailing content.
- Fixed template §9 section: cleared live Silver Bullet project preferences from Mode Preferences table; corrected §10 cross-references to §9 within template.
- Bumped `version` and `config_version` in `templates/silver-bullet.config.json.default` to `0.25.0`.
- Fixed all 9 orchestrator skills pre-flight grep to use `[0-9]\+\.` instead of `10\.` when reading User Workflow Preferences — the section is §10 in the SB dev repo but §9 in every template-installed user project.
- Fixed `silver-rem` Step 6 `awk -v ins="${INSIGHT}"` injection vector (issue #57): insight text now passed via `ENVIRON["INSIGHT"]` to bypass awk's backslash-sequence interpretation of `-v` assignment values. Applies to both knowledge and learnings entry insertion.

## [0.24.0] — 2026-04-24

**Stability · Security · Quality milestone.** Fixes 6 session-stability bugs blocking day-to-day use, ports doc-scheme compliance gates to bugfix and devops workflows, tightens tamper-detection to stop false-positive blocks on commit messages, and adds project management system awareness to `/silver:init`.

### Session Stability (BUG)

- **BUG-01** (`f15615c`): Fixed trivial bypass SessionStart ordering — reordered hooks.json so `session-start` runs before `trivial-touch`, ensuring the trivial file survives all hook firings for admin sessions.
- **BUG-02** (`f15615c`): Fixed branch file written without trailing newline causing `mainmain` concatenation and spurious state wipes.
- **BUG-03** (`f15615c`): Scoped `dev-cycle-check.sh` tamper guard to the state file only — branch and trivial files are no longer falsely blocked.
- **BUG-04** (`e877602`): Fixed `completion-audit.sh` matching against full expanded heredoc body — now checks only the first command line, preventing false-positive `COMMIT BLOCKED` errors.
- **BUG-05** (`f15615c`): Purely administrative sessions (no Write/Edit calls) now correctly bypass enforcement via the trivial mechanism fixed by BUG-01.
- **BUG-06** (`0ca5f99`): `modularity/SKILL.md` Rationalization Prevention table extended with 3 planning-intent excuse rows and an Adversarial mode rule — "tracked in backlog / milestone plan / next phase" are no longer accepted as deferrals during review.

### Consistency & Quality (QA)

- **QA-05** (`dfe856d`): `dev-cycle-check.sh` tamper-detection now skips `git`/`gh` commands entirely and checks only the first command line — prevents false-positive blocks when commit messages or `gh --body` arguments mention the state file path. Two new tests (17e, 17f) cover the fix.
- **QA-06** (`dfe856d`): Doc-scheme compliance gate (conditional pre-ship step) ported to `silver-bugfix` (Step 7c), `silver-devops` (Step 10b), and both forge variants.

### Feature (FEAT)

- **FEAT-01** (`dfe856d`): `/silver:init` now prompts for project management system (GitHub Issues or GSD) in new Step 2.8. Answer written as `issue_tracker` field in `.silver-bullet.json` (default: `"gsd"`). `silver-feature` backlog-capture steps now route to `gh issue create` or `gsd-add-backlog` based on the configured value.

### Skills — doc-scheme gates (#37, #38)

- **DOC-SCH-03**: Added doc-scheme compliance gate to both `silver-ui` variants (PR #38).
- **DOC-SCH-04**: Forward-ported doc-scheme compliance gate to `forge/skills/silver-feature` and `forge/skills/silver-ui` (PR #37).

## [0.23.10] — 2026-04-24

**Forge-SB port + ci-status-check deadlock fix (Bug 2).** Ships Silver Bullet for Forge (34 Forge-native skills), fixes the remaining CI-gate deadlock (#32 — PostToolUse commit was hard-blocked; now warns only), and closes three open issues (#30, #33, installer curl|bash). Pre-release quality gate: 4-stage automated review (code review, consistency audit, public content refresh, security), all four stages clean.

### Forge-SB port (PR #35)

- **FORGE-01**: Added `forge/skills/` directory with 34 Forge-native SKILL.md files mirroring the Silver Bullet CC skill set — GSD workflows (12), quality dimensions (9 + master), Superpowers dependencies (7), silver orchestrators (6), plus AGENTS.md global and project templates.
- **FORGE-02**: Added `forge/scripts/install.sh` and `forge/AGENTS.md` — entry point for Forge-based projects. Forge uses `id:` frontmatter and `AGENTS.md` files; CC uses `name:` and `/plugin install`.
- **FORGE-03**: Added `forge/skills/tests/smoke_test.sh` — 33-assertion smoke test (all skills present + installer exists). All green before merge.
- **FORGE-04**: Restored `forge/skills/` after post-merge cleanup accidentally deleted it (d804e76).
- **FORGE-05**: Added missing `name:` frontmatter to forge-sb ported CC wrapper skills that were missing it.

### Hooks — ci-status-check.sh (#32)

- **BUG2-01**: PostToolUse/`git commit` now emits a **warning** instead of `decision:block` — the commit has already happened; blocking PostToolUse confused the model about whether the commit succeeded and created a deadlock when trying to commit a CI fix. Push, PR, and release operations remain hard-blocked.
- **BUG2-02**: Corrected the `ci-red-override` escape instruction in the CI failure message from "If you need to commit a CI fix" → "If you need to **push** a CI fix" — `git commit` is never blocked by the CI gate, so the instruction now accurately describes the only operation that needs the override.
- **BUG2-03**: Added Group 6 regression test (PreToolUse commit not blocked when CI red) and Group 7 regression tests (PostToolUse commit is warn-not-block, with a compound `git commit && git push` guard ensuring the push component routes to `emit_block`). Test suite: 14 tests, 14/0. Full suite: 1300/0, 4/4 green.
- **DOC-01**: README Layer 5 description updated to reflect the warn/block split for commit vs. push/PR/release.
- **DOC-02**: README manual escape hatch section rewritten — removed stale "CI fix commit" scenario; added dedicated ci-red-override guidance with correct "push" framing.
- **DOC-03**: `site/index.html` version badge updated `v0.23.8` → `v0.23.10`.

### Skills — doc-scheme compliance gate (#33)

- **DOC-SCH-01**: Added Step 13b to `silver-feature/SKILL.md` — before raising a PR, check whether `docs/doc-scheme.md` exists; if it does, gate on 4 doc updates (CHANGELOG entry, ARCHITECTURE current state, `knowledge/`, `learnings/`) before proceeding to Step 14 (finishing branch). Missing entries are treated as pre-ship defects.
- **DOC-SCH-02**: Added a `## Documentation` section to the `writing-plans` PLAN.md template so the doc-scheme obligation is visible at plan-writing time, not just at ship time.

### Skills — enforcement cleanup (#30)

- **RULES-01**: Removed misleading `review-loop-pass` bash snippet from `core-rules.md §3a` — the snippet showed `echo "review-loop-pass" >> state`, which tamper-detection blocks and which was removed from `required_deploy` in v0.23.6. The doc was describing a mechanism that no longer works.

### silver-init

- **INIT-01**: `silver-init/SKILL.md` — purge stale hook entries on update. When re-running `/silver:init` on an existing project, obsolete hook registrations from prior versions are removed before adding current ones.

### Installer

- **INST-01**: `scripts/install.sh` — support `curl | bash` remote install pattern. The installer now detects when it is running from a pipe (no TTY) and skips interactive prompts, enabling `curl -fsSL https://… | bash` one-liner installs.

### Cleanup

- **CLN-01**: Removed orphan `skills/ai-llm-safety/ai-llm-safety/SKILL.md` double-nested directory created by a path-join bug. The canonical file at `skills/ai-llm-safety/SKILL.md` is unaffected.
- **CLN-02**: Stripped `FLOW N` serial numbers from execution headings and templates — numbers were redundant with section titles and made reordering flows expensive.
- **CLN-03**: Updated composition proposal box style — full border, clean flow names.
- **CLN-04**: `site/index.html` copy improvements — capitalize "Composable" in compare card; use "orchestrates" language in Ecosystem and Compare sections.

## [0.23.9] — 2026-04-20

**Hotfix — ci-status-check deadlock (Bug 1) + dev-cycle false positive.** Two hook bugs introduced in v0.23.8 and surfaced in production. Both have TDD regression tests; suite at 1152/0, 4/4 green before tagging.

### Hooks — ci-status-check.sh (Bug 1)

- **BUG1-01**: `ci-status-check.sh` was blocking `git commit` at **PreToolUse** when CI was red, creating an unrecoverable deadlock — Claude could not commit the fix needed to make CI green. Fixed by splitting the trigger scope by hook event: PreToolUse blocks only `git push` and deploy operations (never `git commit`); PostToolUse warns after commit so Claude knows CI is red before pushing.

### Hooks — dev-cycle-check.sh

- **DC-01**: The fallback self-protection pattern `/silver-bullet[^/]*/hooks/` (used when `CLAUDE_PLUGIN_ROOT` is unset) also matched the silver-bullet source repo's own `hooks/` directory, blocking legitimate hook edits during development. Restricted the fallback to paths provably inside `${SB_RUNTIME_HOME_ROOT}/` (the installed plugin location only).

## [0.23.8] — 2026-04-20

**Pre-release quality gate patch.** Ten-round automated code-review sweep (Layers A/B/C × multiple passes) found and fixed shell-script safety regressions, incorrect hook output formats, and documentation drift. Rounds 9 and 10 both returned zero findings.

### Shell script hardening
- **RM-01**: All `rm -f` calls in `scripts/` hardened with `--` separator (`semantic-compress.sh`, `deploy-gate-snippet.sh`, `sync-marketplace-version.sh`, `tfidf-rank.sh`) — project invariant now covers both `hooks/` and `scripts/`.
- **TRAP-01**: `phase-archive.sh` ERR trap output corrected from PostToolUse block format to PreToolUse `permissionDecision:deny` format — hook was emitting invalid JSON on archive failures.
- **TRAP-02**: `pr-traceability.sh` trap disarm extended to include `INT TERM` (`trap - EXIT INT TERM`) — prior form left handlers live across `wait` calls.
- **SC2015-01**: `session-log-init.sh` two `A&&B||C` awk pipelines rewritten as `if/then/else` — eliminates SC2015 false-success risk on `awk` exit.
- **TRAIL-01**: `roadmap-freshness.sh` final code path now exits 0 explicitly after its informational `printf` — missing `exit 0` could propagate unexpected exit codes.

### Test fixes
- **TEST-01**: `test-session-log-init.sh` sentinel kill calls fixed to extract bare PID from `pid:lstart` format before `kill` — was passing the full `pid:lstart` string, causing `kill` to error silently.

### Documentation & consistency
- **DOC-01**: `site/index.html` version badge updated `v0.22.0` → `v0.23.8`.
- **DOC-02**: `docs/internal/CICD.md` shellcheck command updated to match CI (`--exclude=SC2317,SC1091,SC2329 hooks/*.sh hooks/lib/*.sh scripts/*.sh`); CI step table brought current with all pipeline steps added since v0.22.

## [0.23.7] — 2026-04-20

**Hotfix.** SC2015 rewrite of `compliance-status.sh` in v0.23.6 lost the executable bit on the file, causing the hook to fail silently.

### Fixes
- **HOT-01**: Restored `+x` permission on `compliance-status.sh` (lost during SC2015 rewrite).
- **HOT-02**: Rewrote remaining `A&&B||C` patterns in `compliance-status.sh` as `if/then/else` to satisfy shellcheck SC2015 without the permission regression.
- Additional code review pass (2 rounds, both clean before release).

## [0.23.6] — 2026-04-20

**Issue-cleanup patch.** Resolved 5 open GitHub issues: CI Node deprecation, semver validation in `silver-update`, review-loop-pass marker conflict, trivial-file name confusion, and cryptographic tag signing.

### CI
- **CI-01**: All GitHub Actions workflows opt into Node.js 24 via `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` — eliminates Node 20 deprecation warnings ahead of June 2026 deadline.

### silver-update (#29)
- **UPD-SEC-01**: `$LATEST` is validated as a semver string (`X.Y.Z`) before use in any file path or `git ref` — prevents path-traversal or ref injection from a crafted GitHub API response.

### Enforcement — review-loop-pass (#30)
- **ENF-01**: `review-loop-pass` marker removed from `required_deploy` list — the marker is written by `record-skill.sh` only after a manual Skill invocation, but the review-loop mechanism writes it via a direct state-file append, which `completion-audit.sh`'s tamper-detection hook blocked. Unblocking deploys that used the loop correctly.

### Trivial bypass naming (#31)
- **TRV-01**: Separated the two semantics that lived in a single touch-file (`trivial`): `trivial` now means "session has not modified any files" (bypass all enforcement); a new `ci-red-override` file is created when the user explicitly overrides a red CI gate. The two are no longer conflated.

### Cryptographic tag signing (#28)
- **SEC-01**: `silver-create-release` SKILL.md updated to sign Git tags with GPG when `git config user.signingkey` is set (`git tag -s`). Release process now optionally produces signed tags verifiable with `git tag -v`.

## [0.23.5] — 2026-04-19

**Skill hardening patch.** Iterative audit of `silver-update` and `silver-migrate` SKILL.md files closed terminology drift, missing template sections, and unresolved bash placeholders. Source verified across 4 independent agent audits (last 2 passes clean).

### silver-update
- **UPD-01**: Added explicit trigger phrase to description (`when the user runs /silver:update`) for skill-development compliance.
- **UPD-02**: Replaced fragile `curl | grep | sed` tag parse with `jq -r '.tag_name' | sed 's/^v//'` (jq is already a project prerequisite).
- **UPD-03**: Bound `$LATEST`, `$NEW_CACHE`, `$COMMIT_SHA`, `$NOW` as real shell variables. Removed unquoted/unresolved `<latest-version>` placeholders from executable commands.
- **UPD-04**: Atomic registry write — `mktemp` + `mv` with a concrete `jq --arg` expression that updates `version`, `installPath`, `lastUpdated`, `gitCommitSha`. Prevents mid-write corruption.
- **UPD-05**: Cancel-path `rm -rf` guarded by `${SB_RUNTIME_HOME_ROOT}/plugins/cache/` prefix match.

### silver-migrate
- **MIG-01**: Description updated with explicit `/silver:migrate` trigger + pre-v0.20.0 context.
- **MIG-02**: Fixed terminology drift — prose now consistently uses "flow/Flows" to match `templates/workflow.md.base` (`Flow Log`, `Next Flow`). Eliminates mismatched section headings in generated `.planning/WORKFLOW.md`.
- **MIG-03**: Renamed "Next Path section" → "Next Flow section" so emitted heading matches the template.
- **MIG-04**: Added instructions to emit `## Dynamic Insertions`, `## Autonomous Decisions`, and `## Deferred Improvements` empty-header tables (previously omitted — generated WORKFLOW.md was missing 3 template sections).
- **MIG-05**: Template read path now uses `${PLUGIN_ROOT}/templates/workflow.md.base` so it no longer depends on the downstream project's CWD.
- **MIG-06**: Disambiguated FLOW 13 (SHIP — `gsd-ship` / `deploy-checklist`) from FLOW 17 (RELEASE — `silver-create-release`). Previously both claimed `silver-create-release`.

## [0.23.4] — 2026-04-19

**Marketplace hardening.** Fixes version drift, modernizes the marketplace `source` schema, and introduces a dedicated marketplace repo so future Ālo Labs plugins can be cataloged together.

### Marketplace
- **MKTP-01**: Fixed stale version in `.claude-plugin/marketplace.json` (`0.13.1` → `0.23.4`). Was 10 releases out of date.
- **MKTP-02**: Modernized `source` schema from the older nested `{"source":"url","url":"..."}` form to the current `"source": "github:alo-exp/silver-bullet"` shorthand.
- **MKTP-03**: Created dedicated marketplace repo [alo-labs/claude-plugins](https://github.com/alo-labs/claude-plugins). End-users can now install via:
  ```
  /plugin marketplace add alo-labs/claude-plugins
  /plugin install silver-bullet@alo-labs
  ```
  (The self-listed `.claude-plugin/marketplace.json` in this repo remains for direct-repo installs: `/plugin marketplace add alo-exp/silver-bullet`.)
- **MKTP-04**: Added `scripts/sync-marketplace-version.sh` — bumps the in-repo marketplace.json to match plugin.json and prints the remote-sync command for the alo-labs/claude-plugins repo.
- **MKTP-05**: Added CI guard in `.github/workflows/ci.yml` that fails the build if `plugin.json.version ≠ marketplace.json.plugins[silver-bullet].version`. Prevents future drift.

## [0.23.3] — 2026-04-19

**Full 100%-vs-100% plugin-dev compliance audit.** Extracted 66 requirements across all 7 plugin-dev skills + 2 validator agents, verified SB against each, fixed all FAIL + material WARN findings, and gated release on two consecutive independent clean audits. Full audit trail in `.planning/PLUGIN-DEV-COMPLIANCE.md`.

### Resolved FAIL
- **FAIL-01**: `silver-init/SKILL.md` reduced from 5,454 → 3,459 words (under skill-development's 5,000 hard max). Phase 3 scaffold detail extracted to `skills/silver-init/references/scaffold-steps.md`.

### Resolved WARN
- **WARN-01**: Added `trap 'exit 0' ERR` to the 4 hooks that lacked it (`completion-audit.sh`, `forbidden-skill-check.sh`, `roadmap-freshness.sh`, `stop-check.sh`). Now universal across all 17 registered hooks, matching the project's stated invariant.
- **WARN-02**: Added concrete user-phrase triggers to all 9 quality-dimension skill descriptions (`security`, `reliability`, `modularity`, `scalability`, `testability`, `extensibility`, `reusability`, `usability`, `ai-llm-safety`). Triggers now phrase-based ("when the user asks to 'harden X'", "'add retries'", etc.) per skill-development §Description Quality.
- **WARN-08**: Deleted dead hook script `hooks/ensure-model-routing.sh` (was executable but unregistered in `hooks.json`).
- **WARN-09**: Added `"matcher": "startup|clear|compact"` to first SessionStart block in `hooks/hooks.json` for consistency.

### Audit methodology
Full systematic audit delegated to independent agents:
1. Extract every MUST/SHOULD/anti-pattern from plugin-dev authority docs
2. Verify 100% of SB (41 skills, 17 hooks, manifest, lib) against each requirement
3. Write findings to `.planning/PLUGIN-DEV-COMPLIANCE.md` with file-level evidence
4. Fix all FAIL + material WARN
5. Re-audit independently until 2 consecutive clean passes
6. Gate release on clean-pass verdict

Final audit: **66 requirements checked, 59 PASS, 0 FAIL, 3 accepted WARN (deliberate design choices), 4 N/A.**

## [0.23.2] — 2026-04-19

**plugin-dev compliance — broader-scope audit.** Re-ran the audit iteratively against a wider checklist (shellcheck, executability, schema, semver, name/dir parity, description length bounds) until two consecutive passes reported zero findings.

### Hook lib cleanliness
- **SHELL-01**: Added `# shellcheck shell=bash` directive to `hooks/lib/required-skills.sh` so shellcheck recognizes the shell for sourced-only files (SC2148).
- **SHELL-02**: Added `# shellcheck disable=SC2034` to `DEFAULT_REQUIRED` and `DEVOPS_DEFAULT_REQUIRED` since they are consumed via `source`, not in-file.

### Audit coverage (all passing)
- All 41 skills: plugin-dev description opener, version field, no grammar mismatches
- All 24 hook entries: `type` + `timeout` present
- Shellcheck: zero warnings + zero errors across `hooks/*.sh` and `hooks/lib/*.sh`
- plugin.json: all required fields (name, version, description, hooks, author, license)
- All three JSON files valid
- No 2nd-person imperative prose in skill bodies
- All hook scripts executable
- Semver compliant

## [0.23.1] — 2026-04-19

**plugin-dev compliance patch.** Second-pass audit surfaced residual gaps from v0.23.0 that passed the first-pass checks but failed a stricter re-scan. Two consecutive clean audit passes achieved before release.

### Skill descriptions
- **DESC-NORM**: Normalized 32 remaining skill descriptions to the plugin-dev standard `"This skill should be used when/for/to ..."` opener. Prior release fixed 9; this release fixes the rest. All 41 skills now conform.
- **DESC-GRAMMAR**: Fixed 6 imperative-verb grammar mismatches (`"used for apply"` → `"used to apply"`, etc.) across `artifact-review-assessor`, `devops-quality-gates`, `silver-blast-radius`, `silver-create-release`, `silver-migrate`, `silver-review-stats`, `silver-init`, `silver-update`, `silver`.

### Writing style
- **STYLE-02**: Fixed 3 residual second-person aphorisms in `security/SKILL.md` (`"your denylist"`, `"roll your own crypto"`, `"Rolling your own crypto"`). Dialog/error-message examples with 2nd-person left intact as legitimate example content.
- **STYLE-03**: Fixed 2 additional 2nd-person violations in `silver-init` (`"You can safely delete..."`) and `silver-spec` (`"include in your phrasing"`).

### Audit methodology
Cleanroom multi-pass audit introduced: scan → fix → re-scan until two consecutive passes report zero findings across manifest fields, hook timeouts, skill frontmatter, description grammar, prose style, and JSON validity.

## [0.23.0] — 2026-04-19

**plugin-dev compliance milestone.** Retroactively aligns 100% of Silver Bullet against the official Anthropic `plugin-dev` plugin standards — manifest, hooks, skills, and writing style.

### Plugin-dev Compliance (Phase 1 — Manifest & Hooks)
- **PLUGIN-01**: Added `"hooks": "./hooks/hooks.json"` field to `.claude-plugin/plugin.json` per plugin-dev `plugin-structure` standard.
- **PLUGIN-02**: Added explicit `timeout` fields to all 24 hook entries in `hooks/hooks.json` (values: 5–30s per hook criticality).
- **PLUGIN-03**: Bumped `.claude-plugin/plugin.json` version to `0.23.0`.

### plugin-dev Compliance (Phase 2 — Skill Descriptions & Versions)
- **SKILL-DESC**: Fixed 9 skill descriptions from bare "Use when..." to plugin-dev standard "This skill should be used when..." format: `ai-llm-safety`, `extensibility`, `modularity`, `reliability`, `reusability`, `scalability`, `security`, `testability`, `usability`.
- **SKILL-VER**: Added `version: 0.1.0` to YAML frontmatter of all 41 skills.

### plugin-dev Compliance (Phase 3 — Progressive Disclosure)
- **SILVER-FEATURE**: Extracted Supervision Loop detail (SL-1 → SL-6, ~400 words) to `skills/silver-feature/references/supervision-loop.md`; replaced with lean pointer. Word count: 3,049 → 2,704.
- **SILVER-INIT**: Extracted 4 heavy sections to references/scripts:
  - CI workflow YAML templates → `skills/silver-init/references/ci-templates.md` (13 stacks)
  - Doc migration procedure → `skills/silver-init/references/doc-migration.md`
  - Tech stack detection table → `skills/silver-init/references/stack-detection.md`
  - Hooks-merge Python script → `skills/silver-init/scripts/merge-hooks.py` (executable, chmod 755)
  - Word count: 6,446 → 5,419.

### plugin-dev Compliance (Phase 4 — Writing Style)
- **STYLE**: Fixed 23 second-person writing violations across 9 skills (imperative verb-first style):
  - All 7 ilities skills: `"You are NOT required to X"` → `"Not required to X"`, `"You ARE required to not make X worse"` → `"Required: do not make X worse"`, and related pronoun drops.
  - `silver-spec`: `"You MUST NOT proceed"` → `"Do NOT proceed"`.
  - `devops-skill-router`: `"You can also invoke"` → `"Also invocable"`.

### Documentation
- **CLAUDE.md**: Complete rewrite — added commands (test suite, linting, validation), full architecture reference (hook event map, two-tier enforcement, state machine, shared libraries), key invariants.

## [0.22.0] — 2026-04-18

**Backlog-resolution milestone.** Consolidates phases 34–38: security hardening,
hook-correctness fixes, consistency repairs, gitignore narrowing, and a full
public-surface refresh. Subsumes the undocumented 0.20.9 → 0.21.3 release window
into a single coherent entry. Closes issues [#14](https://github.com/alo-exp/silver-bullet/issues/14),
[#16](https://github.com/alo-exp/silver-bullet/issues/16),
[#20](https://github.com/alo-exp/silver-bullet/issues/20),
[#23](https://github.com/alo-exp/silver-bullet/issues/23).

### Security
- **SEC-01** (P34, `6cb66c5`): moved the Google Chat release-notification webhook out of `skills/silver-create-release/SKILL.md` into the `GCHAT_RELEASE_WEBHOOK` env var; added a `secret-scan` CI job that fails the build on hard-coded webhook URLs.
- **SEC-02** (P35, `e247ff3`): added `! -L` symlink guards to every hook that reads/writes state files (`stop-check.sh`, `session-start`, `completion-audit.sh`, trivial-flag touch/rm) — closes a symlink-replacement bypass on multi-user machines.
- **SEC-03** (P35, `e247ff3`): replaced hand-rolled JSON string concatenation in hook stdout with `jq -n` payloads across every hook that emits `PreToolUse`/`Stop` structured output — eliminates injection via filenames or branch names containing quotes.
- **SEC-04** (P35, `e247ff3`): batch security fixes across remaining hooks (safe `rm` patterns, `mktemp` for temp files, `set -euo pipefail` where missing).

### Fixes
- **HOOK-06** (P36, `4339060`): `stop-check.sh` no longer fails open when `.silver-bullet.json` is missing or unreadable — absent config now HARD-STOPs with a config-error message instead of silently allowing session end.
- **HOOK-07** (P36, `4339060`): closed a race in `stop-check.sh` where a concurrent `record-skill.sh` write could cause the required-skills diff to observe a stale state file; added flock around state reads on Stop.
- **HOOK-08** (P36, `4339060`): filled test coverage for the HOOK-14 trivial-session / clean-tree short-circuit paths in `stop-check.sh` (clean tree, dirty tree, trivial flag, read-only session matrix).
- **HOOK-14** carryover: `stop-check` skips enforcement for read-only sessions ([#14](https://github.com/alo-exp/silver-bullet/issues/14) via `58d98fb` / `efdaab5`).

### Consistency
- **CONS-01** (P37, `0b86dc6`): repaired broken skill references — `/gsd:silver-forensics` → `/gsd-forensics`, legacy `/silver:*` colon-form refs in SKILL.md files updated to current `/silver-*` names.
- **CONS-02** (P37, `0b86dc6`): reconciled `hooks.json` / `settings.json` schema drift; every hook entry now matches the Claude Code manifest schema and the registered hook script actually exists on disk.

### Ignore
- **IGNORE-01** (P38, this release, closes [#20](https://github.com/alo-exp/silver-bullet/issues/20)): narrowed the project `.gitignore` blanket `.codex/` rule to runtime-only subpaths (`projects/`, `local/`, `.silver-bullet/`, `settings.local.json`, `worktrees/`). Committed plugin config (`.codex/settings.json`, `.codex/commands/`) now tracked. Supersedes the interim fix in `c8b161a`.

### Docs
- **DOC-02** (P38, this release, closes [#23](https://github.com/alo-exp/silver-bullet/issues/23)): public-surface refresh across every user-visible file.
  - `README.md`: `Current version` bumped from v0.21.3 → v0.22.0 with milestone summary.
  - `site/index.html`: hero version badge v0.19.1 → v0.22.0; meta description / Twitter card skill count 39 → 41, added "18 hooks".
  - `site/help/getting-started/index.html`, `site/help/concepts/index.html`: skill count 39 → 41; version range extended to v0.22.0; added composable-flows line.
  - `docs/ARCHITECTURE.md`: design principle 2 corrected from "7 layers" → "10 layers" to match enforcement-layer count everywhere else.
  - `CHANGELOG.md`: this entry, consolidating 0.20.9–0.21.3 gap into the 0.22.0 release note.

### Tests
- Total: 1112 passed, 13 failed (2/3 suites green) — unchanged from v0.21.3 baseline. Hook coverage: 18/18.

## [0.20.8] — 2026-04-16

### Fixed
- `skills/silver-forensics/SKILL.md`: replaced 4 occurrences of non-existent `/gsd:silver-forensics` routing with correct `/gsd-forensics`. The bug caused silent agent failure when Silver Bullet tried to delegate GSD workflow issues to a command that never existed.

### Tests
- `tests/integration/test-skill-integrity.sh`: added Check 8 — regression test asserting `silver-forensics/SKILL.md` does not reference `/gsd:silver-forensics`. RED-GREEN verified.
- Total: 288 tests, 3/3 suites green.

### Docs / Planning
- Autonomous mode preference recorded in `silver-bullet.md §10e` and base template.
- `ROADMAP.md ## Backlog`: 17 deferred items (999.1–999.17) captured from forensics sweep and added for future work.
- `CHANGELOG.md`: corrected stale "972 tests" count in v0.20.6 entry to correct value (288).

## [0.20.7] — 2026-04-16

### Fixed
- `hooks/session-start`: now honours `SILVER_BULLET_STATE_FILE` env var (same pattern as `completion-audit.sh` and `stop-check.sh`), allowing tests to redirect state writes to a temp path.
- `tests/hooks/test-session-start.sh`: replaced fragile backup/restore machinery with `TMPSTATE` isolation via `SILVER_BULLET_STATE_FILE`. Running the full test suite no longer wipes the live session state file, ending the skill re-recording loop that blocked session completion after every test run.

### Tests
- Total: 288 tests, 3/3 suites green (no new tests — existing 12 session-start tests now run in full isolation)

## [0.20.6] — 2026-04-16

### Fixed
- `hooks/roadmap-freshness.sh`: new PreToolUse/Bash hook that blocks `git commit` when a phase `*-SUMMARY.md` is staged but the corresponding ROADMAP.md checkbox is not ticked (`[ ]`). Prevents autonomous execution from silently skipping the ROADMAP bookkeeping step.
- `skills/silver-feature/SKILL.md`: added explicit "TICK ROADMAP.md" step to the Per-Phase Loop so autonomous runs update the checkbox before the phase-completion commit.
- `.planning/ROADMAP.md`: ticked checkboxes for phases 23, 24, 27, 28 which were completed in the prior milestone but not updated due to the missing enforcement.

### Tests
- Total: 972 tests, 3/3 suites green (8 new tests for roadmap-freshness hook)

## [0.20.5] — 2026-04-16

### Changed
- `/silver` skill: renamed from "Smart Skill Router" to "Smart Skill Orchestrator" — better reflects its role composing and sequencing workflows rather than just dispatching
- Composable workflow building blocks renamed from "paths" to "flows" throughout: `silver-feature/SKILL.md` (20 occurrences in Composition Proposal and Supervision Loop), `silver/SKILL.md` (Composer note), `silver-bullet.md.base` §2h ("Composable Flows Catalog"), `ENFORCEMENT.md` ("composable flows mode"), `full-dev-cycle.md` both templates and docs copies

### Tests
- Total: 962 tests, 3/3 suites green

## [0.20.4] — 2026-04-16

### Changed
- All user-facing Silver Bullet skills now use the `/silver-*` naming convention: `blast-radius` → `silver-blast-radius`, `create-release` → `silver-create-release`, `forensics` → `silver-forensics`, `quality-gates` → `silver-quality-gates`. End users now see a clean `/silver-*` namespace in the Claude Code slash command menu.
- `hooks/lib/required-skills.sh`, `hooks/record-skill.sh`, `hooks/completion-audit.sh`, `hooks/stop-check.sh`, `hooks/dev-cycle-check.sh`: updated all references to use new skill names
- `.silver-bullet.json`, `templates/silver-bullet.config.json.default`: `required_planning`, `required_deploy`, and `all_tracked` arrays updated to new names
- 22 internal skills (dimension checkers, artifact reviewers, internal routing skills) marked `user-invocable: false` in SKILL.md frontmatter — hidden from Claude Code slash command menu to reduce context token overhead for end users
- README.md: all skill name references updated to new `silver-*` convention

### Tests
- Total: 962 tests, 3/3 suites green

## [0.20.3] — 2026-04-15

### Added
- `create-release` skill: Step 5 posts a Google Chat notification after publishing a release. Reads `notifications.google_chat_webhook` from `.silver-bullet.json`; silent skip if absent; warns but does not fail if `curl` errors.
- `.silver-bullet.json`: `notifications.google_chat_webhook` config key for project-local webhook URL storage.

## [0.20.2] — 2026-04-15

### Refactored
- `hooks/lib/workflow-utils.sh` (new): shared utility library — single source of truth for Flow Log row-counting regex, extracted from three hooks (TD-1)
- `completion-audit.sh`, `dev-cycle-check.sh`, `compliance-status.sh`: source shared lib with inline fallback definitions for resilience in test environments
- Fixed stale "workflow paths" terminology in `completion-audit.sh` output messages → "flows" (TD-2)

### Added
- Comprehensive skill execution path test suite: 169 tests covering sub-skill reference integrity, non-skippable gate presence, step ordering constraints, quality-gates 9-dimension completeness, and skill name consistency across all 41 orchestration skills (TD-3)

### Tests
- Total: 962 tests, 3/3 suites green (up from 793 in v0.20.0)

## [0.20.1] — 2026-04-15

### Fixed
- `compliance-status.sh` Bug-1: WORKFLOW.md flow progress (`FLOW N/M`) now shown in early-exit path (no state file) — was omitted before this fix
- `compliance-status.sh` Bug-2: Row-count regex tightened from `^\| [0-9]` to `^\| [0-9]+ \|` — Phase Iterations and Autonomous Decisions rows no longer inflate the total flow count
- Same Bug-2 regex fix applied to `completion-audit.sh` and `dev-cycle-check.sh` (same pattern, same exposure)

### Changed
- Terminology rename: "paths" → "flows" and "Composable Path Architecture" → "Composable Workflow Orchestration" project-wide (42 files)
- WORKFLOW.md sections renamed: `Path Log` → `Flow Log`, `Next Path` → `Next Flow`, `Last-path:` → `Last-flow:`
- Status output updated: `PATH N/M` → `FLOW N/M`, `PATH: N/A (legacy mode)` → `FLOW: N/A (legacy mode)`
- `dev-cycle-check.sh` stale messages updated: "All workflow paths complete" → "All flows complete", partial-progress "PATH %s/%s" → "FLOW %s/%s"

### Added
- 7-scenario integration test suite for `compliance-status.sh` WORKFLOW.md flow-progress display (S1–S7 covering early-exit, symlink, malformed, digit-row false positives, mixed counts)
- Bug-2 inflation regression tests for `completion-audit.sh` (WF3) and `dev-cycle-check.sh` (WF5)

## [0.15.3] — 2026-04-10

### Fixed — SENTINEL v2.3 Security Audit Findings
- SENTINEL-9.1: Sanitize VALIDATION.md warn_items in pr-traceability.sh — strip markdown link syntax and wrap in code fence to prevent injection into PR descriptions
- SENTINEL-3.1: Reject overly permissive src_pattern values (e.g., `.*`, `.+`, `/`) in dev-cycle-check.sh — fall back to `/src/` default
- Full SENTINEL v2.3 8-step adversarial security audit report: `SENTINEL-audit-silver-bullet-v0.15.1.md`

## [0.15.1] — 2026-04-09

### Fixed — Pre-Release QA Gate Findings
- CR-01: Resolve gh CLI at runtime in pr-traceability.sh (cross-platform, was hardcoded /opt/homebrew/bin/gh)
- CR-02: Remove --no-verify from auto-commit in pr-traceability.sh (was bypassing hook chain)
- CR-03: Validate spec_version (dotted semver) and jira_id (uppercase project key) before shell use
- WR-03: Add quote-stripping to uat-gate.sh spec-version comparison (prevents false mismatch on quoted YAML)
- WR-06: Add 'Accepted' to valid assumption status in review-spec QC-5
- WR-07: Align ingestion manifest status vocabulary (success/failed/skipped) across QC-1..5
- Idempotent awk insert in pr-traceability.sh SPEC.md Implementations (prevents duplicate entries)
- Diagnostic ERR traps in pr-traceability.sh and uat-gate.sh (was silent exit 0)
- package.json version updated to match release (was stale at 0.13.0)

## [0.15.0] — 2026-04-09

### Added — Granular Artifact Review Rounds (v0.15.0)
- Artifact reviewer framework: `skills/artifact-reviewer/SKILL.md` with
  interface contract (`reviewer-interface.md`), 2-consecutive-clean-pass
  loop (`review-loop.md`), per-artifact state tracking, and audit trail
- 8 new artifact reviewer skills: `review-spec`, `review-design`,
  `review-requirements`, `review-roadmap`, `review-context`,
  `review-research`, `review-ingestion-manifest`, `review-uat`
- Existing GSD reviewers (plan-checker, code-reviewer, verifier,
  security-auditor) formalized into the 2-pass framework via silver-bullet.md §3a
- Workflow wiring: silver-spec Steps 7a/8a/9a, silver-ingest Step 7a,
  silver-feature Step 17.0a — all NON-SKIPPABLE gates
- Post-command review gates in §3a-i for ROADMAP, REQUIREMENTS, CONTEXT, RESEARCH
- Complete artifact-reviewer mapping table in §3a (12 artifact types)

### Fixed — v0.14.0 Critical Bug Fixes
- BFIX-01: Shell injection via unvalidated owner/repo in `silver-ingest --source-url` — allowlist regex validation added
- BFIX-02: Command injection via unescaped WARN findings in `pr-traceability.sh` heredoc — replaced with `printf '%s'`
- BFIX-03: Confluence failure path now produces `[ARTIFACT MISSING: reason]` block (was buried in Assumptions)
- BFIX-04: Version mismatch block in §0/5.5 now shows content diff (was version numbers only)

## [0.14.0] — 2026-04-09

### Added — AI-Driven Spec & Multi-Repo Orchestration
- `skills/silver-spec/SKILL.md` — AI-driven Socratic elicitation skill (238 lines)
  guiding PM/BA through 9-domain requirements creation, producing SPEC.md + REQUIREMENTS.md
- `skills/silver-ingest/SKILL.md` — External artifact ingestion (428 lines) via
  JIRA (Atlassian MCP), Figma (Figma MCP), Google Docs (Workspace CLI with vision).
  Cross-repo spec fetch with version pinning. Resumable via INGESTION_MANIFEST.md
- `skills/silver-validate/SKILL.md` — Pre-build gap analysis (360 lines) with
  BLOCK/WARN/INFO findings. Hard-blocks gsd-plan-phase on BLOCK findings
- `hooks/spec-floor-check.sh` — PreToolUse hook that hard-blocks gsd-plan-phase
  without valid SPEC.md; advisory-only for gsd-fast/gsd-quick
- `hooks/spec-session-record.sh` — SessionStart hook capturing spec-id/version/JIRA ref
- `hooks/pr-traceability.sh` — PostToolUse hook auto-populating PR description with
  spec reference and updating SPEC.md Implementations section post-merge
- `hooks/uat-gate.sh` — PreToolUse hook blocking gsd-complete-milestone without UAT pass
- Canonical spec templates: `templates/specs/SPEC.md.template`, `DESIGN.md.template`,
  `REQUIREMENTS.md.template` with YAML frontmatter and standardized sections
- Multi-repo spec referencing: `silver-ingest --source-url` fetches + caches main repo
  SPEC.md with version pinning; session-start validation blocks on mismatch
- §3/§3a/§3d step non-skip enforcement: workflow steps cannot be bypassed, artifact
  existence required before phase advancement
- Spec Lifecycle section in silver-bullet.md.base
- MCP Connector Prerequisites (§2j) and Cross-Repo Conventions (§2k)

## [0.13.2] — 2026-04-09

### Fixed
- All hooks that used `set -euo pipefail` without an ERR trap now have
  `trap 'exit 0' ERR` added. Affected files: `hooks/session-start`,
  `hooks/compliance-status.sh`, `hooks/session-log-init.sh`,
  `hooks/ensure-model-routing.sh`, `hooks/semantic-compress.sh`,
  `hooks/record-skill.sh`, `hooks/ci-status-check.sh`,
  `hooks/dev-cycle-check.sh`. Prevents first-install failures from
  surfacing nonzero hook exits that cause Claude to reject the plugin.
- Restored `"hooks": "./hooks/hooks.json"` to `.claude-plugin/plugin.json`
  so the marketplace registers hooks automatically on install.

### Added
- `silver:init` Phase 3 step 3.7.5: after project scaffolding, merges SB
  hook entries from `hooks/hooks.json` into `${SB_RUNTIME_HOME_ROOT}/settings.json` using
  `python3`. Hook commands are registered with the actual install path
  substituted for `${CLAUDE_PLUGIN_ROOT}`. Idempotent — re-running init
  does not add duplicate entries. Also runs during update mode (step 5a).

## [0.13.1] — 2026-04-09

### Changed
- Model routing overhauled: Sonnet (LOW thinking effort) is now the default for all 24 GSD agents. Opus reserved exclusively for `gsd-planner` and `gsd-security-auditor` — the only two agents where reasoning depth measurably changes outcome quality. Previous scheme asked for Opus at phase transitions; new scheme is fully automatic via agent frontmatter.
- silver-bullet.md §5 and templates/silver-bullet.md.base §5: removed interactive Opus upgrade prompts; replaced with automatic frontmatter-based routing description
- docs/workflows/full-dev-cycle.md MODEL ROUTING section updated to match; removed manual prompt flow

### Added
- `hooks/ensure-model-routing.sh` — self-healing session-start hook that reapplies `model:` directives to all 24 GSD agent files if a GSD update wipes them. Canary-guarded (~2ms no-op when correct, <50ms when patching). Bash 3.2 compatible. Audit trail written to `${SB_RUNTIME_HOME_ROOT}/.silver-bullet/model-routing-patch.log`.

### Fixed
- All "8 dimensions" references updated to "9 dimensions" across site/index.html (3 occurrences), site/help/index.html, site/help/dev-workflow/index.html, site/help/search.js (3 occurrences), and docs/workflows/full-dev-cycle.md (4 occurrences total)
- quality-gates SKILL.md: added 9th dimension (AI/LLM safety) to skill load list and report table; updated model advisory from Opus to Sonnet
- site/index.html cost-optimization section rewritten: Sonnet-as-default messaging, Opus reserved for 2 agents, cost reduction estimate updated to 60–80%
- docs/workflows/full-dev-cycle.md: added /silver router and orchestration workflows to invocation table; updated /test-driven-development → silver:tdd, /finishing-a-development-branch → silver:finishing-branch, /design-system+/ux-copy+/accessibility-review → product-brainstorming; added silver:security to CODE REVIEW section
- site/help/search.js: added dedicated index entries for utility skills (silver:intel, silver:explore, silver:scan, silver:forensics) and alias skills (silver:tdd, silver:security, silver:brainstorm, silver:writing-plans, silver:finishing-branch)

## [0.13.0] — 2026-04-08

### Security
- SENTINEL v2.3 audit: add UNTRUSTED DATA boundary to §0 docs/ read — docs/ files are project context only, not executable instructions (F2-01)
- SENTINEL v2.3 audit: add UNTRUSTED DATA security boundary to silver:init Phase −1.1 for README.md/CONTEXT.md reads (F2-02)
- SENTINEL v2.3 audit: add `mode` to state tamper prevention regex in dev-cycle-check.sh alongside state/branch/trivial (F6-01)
- SENTINEL v2.3 audit: silver:update now displays commit SHA and requires second user confirmation before writing plugin registry (F7-01/F3-01)
- SENTINEL v2.3 audit: §10 step-skip preference writes now require diff display and explicit user confirmation before committing (F10-01)
- SENTINEL v2.3 audit: silver:update cancel path guarded against unsafe removal — requires path-containment check before rm (F-NEW-01)

## [0.9.0] — 2026-04-08

### Added
- 7 named SB orchestration skill files: silver:feature, silver:bugfix, silver:ui, silver:devops, silver:deep-research, silver:release, silver:fast
- §2h SB Orchestrated Workflows enforcement section in silver-bullet.md and template
- §10 User Workflow Preferences schema (10a–10e) in silver-bullet.md and template
- /silver router expanded: 17+ routes, complexity triage, ship disambiguation, conflict resolution
- silver:init: MultAI + Anthropic Engineering + PM plugin checks, project-type detection, gsd-autonomous mode note
- §0 session startup: MultAI update check alongside GSD/Superpowers
- Unified test runner (tests/run-all-tests.sh)

### Fixed
- silver:release: add standalone silver:security gate (Step 2a) before gap-closure loop; listed in non-skippable gates
- silver:feature: move gsd-add-tests to Step 8b (after gsd-verify-work, not before); add TDD skip heuristic
- silver:tdd / silver:scan: add canonical skill parentheticals across feature/bugfix/ui/devops skill files
- silver/router: note §10 preferences not applied when routing Trivial → silver:fast
- silver:init: document intentional MultAI hard-STOP vs Engineering/PM soft-warning asymmetry

### Infrastructure
- GSD state delegation: SB reads .planning/STATE.md instead of maintaining own state

## 0.12.1 (2026-04-07)

### Added
- `/silver:update` skill — one-command plugin updater: checks GitHub for latest release, shows changelog diff, confirms, clones new version into cache, and updates plugin registry

### Fixed
- `/silver` skill: removed unsupported `allowed-tools` frontmatter field that prevented the skill from loading in Claude Desktop
- Architecture section: 10th enforcement layer card now flows in 2-column grid (removed erroneous `grid-column:1/-1`)

## 0.12.0 (2026-04-07)

### Added
- `/silver` router skill — freeform dispatcher that routes natural language to the right Silver Bullet or GSD skill; delegates GSD intent to `/gsd:do` automatically
- Ten-layer enforcement model now fully documented in `silver-bullet.md` section 1 (Stop hook, UserPromptSubmit reminder, and Forbidden skill gate layers were previously undocumented)

### Changed

### Fixed
- `record-skill.sh`: greedy namespace stripping loop (mirrors `forbidden-skill-check.sh`) — double-namespaced invocations (e.g., `outer:inner:quality-gates`) were silently untracked (SENTINEL S6-001)
- `silver-bullet.md` section 1: enforcement layer count corrected from 7 to 10; Stop hook, UserPromptSubmit reminder, and Forbidden skill gate now listed explicitly
- `site/index.html`: all enforcement layer count references corrected from 7 to 10; architecture section updated with three missing layer cards
- `site/compare/index.html`: enforcement layer count corrected from 7 to 10

### Tech Debt
- `hooks/lib/required-skills.sh`: extracted `DEFAULT_REQUIRED` as single source of truth; sourced by `stop-check.sh`, `completion-audit.sh`, `prompt-reminder.sh` with inline fallback (TD-01)
- `stop-check.sh`: extracted `check_quality_gate_stages()` as testable pure function (TD-04)
- `templates/silver-bullet.config.json.default`: added `config_version` field (TD-07)
- Added 4 new tests: double-namespace bypass (forbidden-skill), main-branch filter (prompt-reminder), path traversal defense (prompt-reminder), double-namespace record (record-skill)

## 0.11.0 (2026-04-06)

### Added
- Stop hook (`stop-check.sh`) — blocks Claude from declaring task complete when required skills are missing; fires on `Stop` and `SubagentStop` events, survives compaction
- UserPromptSubmit hook (`prompt-reminder.sh`) — re-injects missing-skill list and core enforcement rules before every user message
- Forbidden skill gate (`forbidden-skill-check.sh`) — PreToolUse hook blocks deprecated/forbidden skills before they execute; configurable via `skills.forbidden` in `.silver-bullet.json`
- Review-loop proxy enforcement — `review-loop-pass-1`/`review-loop-pass-2` markers tracked in stop-check and completion-audit as proxy for F-01 compliance
- Stage ordering validation — prevents falsifying stage sequence (e.g. recording stage-3 before stage-2)
- Automatic model switching — agent definitions route to optimal Claude model tier (Sonnet/Haiku/Opus) based on task type
- 183-test comprehensive E2E harness (`tests/run-all-tests.sh`) — 129 unit tests + 54 integration scenario tests with 100% hook coverage

### Fixed
- 16 enforcement gaps closed from post-v0.10.0 audit: branch mismatch warning, plugin cache write blocking, scripting language bypass prevention, generalized tamper regex, destructive command warning, `gh pr merge` delivery gate, completion-audit missing `exit 0` (double-JSON bug), state JSON injection via stored branch name
- `DEFAULT_REQUIRED` skill list synchronized across `stop-check.sh`, `completion-audit.sh`, and `prompt-reminder.sh`
- `forbidden` key documented in `silver-bullet.config.json.default`

### Changed
- Enforcement layer count: 7 → 10 (Stop hook, UserPromptSubmit reminder, forbidden-skill gate added)

## 0.6.2 (2026-04-04)

### Fixed
- Enforcement layer count aligned to 7 across all surfaces (README, landing page, concepts page, compare page, search index, SENTINEL audit)
- Step counts 19/23 → 20/24 on landing page hero pills, workflow tabs, and compare page
- Landing page workflow tables completed: added missing step 20 (/create-release) for dev cycle and steps 22-24 for DevOps cycle
- Landing page layer cards now match CLAUDE.md canonical 7-layer list (was missing Skill Tracker, had Stage Enforcer split into two)
- Layer ordering aligned to CLAUDE.md canonical sequence across concepts page, search index, and README
- PreToolUse → PostToolUse in landing page HARD STOP gate description
- Broken relative link in compare page footer (help/ → ../help/)
- Stale /tmp/ references in help reference page, search index, and silver:init skill
- Test files updated from /tmp/.silver-bullet-* to ${SB_RUNTIME_HOME_ROOT}/.silver-bullet/ paths
- session-log-init sentinel subshell fully detached from pipeline (fixes test hangs)
- session-log-init grep pattern updated to match new mode file path
- SENTINEL audit doc updated: 8→7 layers, post-remediation note added
- context.md updated: stale step counts, version, and branding
- Missing Required badge on step 9 (/requesting-code-review) in dev cycle table
- Stale worktree .codex/worktrees/agent-ad2bff3d removed
- mkdir -p defense-in-depth added to completion-audit.sh
- Plugin boundary check changed from substring grep to prefix match

## 0.6.1 (2026-04-03)

### Fix: Comprehensive cross-file consistency audit
- Regenerated `.silver-bullet.json` from v0.2.0 template (was stuck at v0.1.0 with 13 obsolete skill names)
- Synced `CLAUDE.md` with `templates/CLAUDE.md.base` (7 enforcement layers, GSD/Superpowers ownership rules, file safety rules)
- Updated all 8 quality dimension skills (`modularity`, `reusability`, `scalability`, `security`, `reliability`, `usability`, `testability`, `extensibility`) from Superpowers-era references to GSD terminology
- Updated `forensics` skill reference from `superpowers:systematic-debugging` to `/gsd:debug`

### Enhanced: DevOps workflow parity
- Added Step 0 (SESSION MODE) to `devops-cycle.md` with pre-answer template
- Added SKILL DISCOVERY section with DevOps-specific examples
- Added MODEL ROUTING section before DISCUSS phase
- Added post-plan skill gap check to Step 6
- Added forensics failure protocol to Step 8 verification
- Added KNOWLEDGE.md, CHANGELOG.md, and session log to Step 18 finalization
- Added worktree isolation rule for docs agents to Step 18
- Added autonomous completion cleanup after Step 24

### Fix: Help site completeness
- Added DevOps Step 0, code review, and skill discovery sections to help page
- Added dev-workflow init (Steps 1–2) and post-review (Steps 11–12) to search index
- Added DevOps Step 0 and code review search entries
- Fixed duplicate `hooks` anchor for trivial-changes section in concepts page
- Added `whats-next` search entry for getting-started page

### Fix: Hook and config alignment
- Reordered `finalization_skills` in `dev-cycle-check.sh` to match `compliance-status.sh` and `completion-audit.sh`
- Bumped `plugin.json` and `package.json` descriptions to "20-step (app) and 24-step (DevOps)"
- Fixed `CHANGELOG.md` DevOps step count from 23 to 24

## 0.6.0 (2026-04-03)

### Fix: `/create-release` skill rename (critical)
- Renamed `skills/release-notes/` → `skills/create-release/` to fix naming collision with Claude Code 2.1.3's built-in `/release-notes` command, which was hijacking invocations and showing Claude Code's own changelog instead of Silver Bullet's release skill
- Updated 16+ references across hooks, workflows, templates, config files, README, CLAUDE.md, and all help site pages

### Enhanced: Review loop enforcement — double approval required
- Review loops (spec review, plan review, code review, verification) must now iterate until the reviewer returns ✅ Approved **twice in a row** — a single clean pass is no longer sufficient
- Completely self-limiting: loop ends naturally on two consecutive clean passes; maximum iteration cap removed
- Updated `CLAUDE.md`, `templates/CLAUDE.md.base`, `docs/workflows/full-dev-cycle.md`, `templates/workflows/*.md`, and help site

### Enhanced: CI gate hook is now blocking
- `hooks/ci-status-check.sh` now emits `blockToolUse: true` on CI failure — Claude must stop all other work immediately and invoke `/gsd:debug`
- Previously emitted only an advisory warning that could be ignored

### Enhanced: Expanded CI stack detection in `/silver:init`
- Detects and generates CI workflow templates for 8 additional stacks: Java/Maven, Java/Gradle, Ruby/RSpec, PHP/Composer, .NET/C#, Elixir/Mix, Swift, Dart/Flutter
- Go template updated to use `go-version: stable`

## 0.5.0 (2026-04-03)

### New: Semantic context compression
- New PostToolUse hook (`hooks/semantic-compress.sh`) that fires on GSD phase transitions and injects ranked context into the next prompt via `hookSpecificOutput.additionalContext`
- TF-IDF ranking of source and doc file chunks against the active phase goal — highest-relevance chunks are injected, lowest are dropped, keeping context tight
- Pure shell implementation (awk + sort) — no external dependencies beyond standard POSIX tools
- Cache-backed: MD5 hash of file mtimes + phase goal used as cache key; repeated calls within the same phase are instant
- Source files prioritised over doc files in ranking; configurable score weighting
- Configurable via `.silver-bullet.json` `semantic_compression` block (enable/disable, chunk size, max chunks injected, min score threshold, include/exclude globs)
- New scripts: `scripts/extract-phase-goal.sh`, `scripts/tfidf-rank.sh`, `scripts/semantic-compress.sh`
- 31 tests across 5 test suites covering TF-IDF scoring, caching, phase-goal extraction, hook wiring, and end-to-end integration

### New: Help site
- Full documentation site at sb.alolabs.dev — Getting Started, Core Concepts, Dev Workflow, DevOps Workflow, Command Reference
- Full-text search across all help content (TF-IDF JS index, ~50 entries)
- Nav search on all sub-pages
- Dark mode support

### Fixes
- Enforcement count corrected: 8 total enforcement points (Silver Bullet installs 6, GSD adds 2) — was described as 7
- DevOps quality gates dimension count: 7 IaC-adapted (usability excluded) — was incorrectly described as 8 in some places
- GSD install command updated to `npx get-shit-done-cc@^1.30.0` in all documentation
- README: hooks architecture updated to document all 9 hooks (4 enforcement + 4 support + session-start)
- README: Built-in skills table now lists all 7 Silver Bullet skills (was 3)
- Help reference: clarified which skills are Silver Bullet's own vs. from Superpowers/Engineering plugins

## 0.2.0 (2026-04-01)

### Major: GSD integration as primary execution engine
- GSD (get-shit-done) is now the primary skill set — fresh 200K-token context per agent, wave-based parallel execution, dependency graphs, atomic per-task commits
- Workflows restructured: GSD commands drive DISCUSS → PLAN → EXECUTE → VERIFY; Silver Bullet skills fill gaps (quality gates, code review, testing, docs, deploy)
- 8 individual quality gate skills collapsed into `/quality-gates` aggregate (individual files kept for modularity)

### New: DevOps workflow
- `devops-cycle.md` — 24-step workflow for infrastructure/DevOps work
- `/blast-radius` skill — pre-change risk analysis with LOW/MEDIUM/HIGH/CRITICAL gate
- `/devops-quality-gates` skill — 7 IaC-adapted quality dimensions (usability excluded)
- Incident fast path for emergency production changes
- Environment promotion section (dev → staging → prod)
- `.yml`/`.yaml` files enforced as infrastructure code in devops-cycle

### New: Design plugin dependency
- Design plugin (anthropics/knowledge-work-plugins/design) added as required dependency
- Session-start hook injects Design plugin context alongside Superpowers

### New: Project type detection
- `/silver:init` Phase 2.6 asks application vs DevOps/infrastructure
- Sets `active_workflow` in config to `full-dev-cycle` or `devops-cycle`

### New: DevOps plugin integration
- `/devops-skill-router` skill — context-aware routing table mapping IaC toolchain + cloud provider to the best available plugin skill with fallback chains
- 5 optional DevOps plugins supported: hashicorp/agent-skills, awslabs/agent-plugins, pulumi/agent-skills, ahmedasmar/devops-claude-skills, wshobson/agents
- `/silver:init` Phase 2.7 auto-detects which DevOps plugins are installed
- `devops-cycle.md` contextual enrichment trigger points at DISCUSS, PLAN, EXECUTE, VERIFY, FINALIZATION
- `devops_plugins` section added to config for tracking installed plugins

### Hook updates
- All hooks updated to align with GSD-integrated workflow
- `record-skill.sh` — tracked skills list updated (removed GSD-replaced skills, added new skills)
- `dev-cycle-check.sh` — reads `active_workflow` from config; YAML files not auto-exempted in devops-cycle
- `compliance-status.sh` — phases updated: removed EXECUTION (now GSD), updated REVIEW and FINALIZATION skill lists
- `completion-audit.sh` — required deploy skills updated to match new workflow
- `deploy-gate-snippet.sh` — default required deploy skills updated

### Updated
- `full-dev-cycle.md` rewritten as 19-step GSD-primary workflow (down from 31)
- `CLAUDE.md.base` updated: 7 enforcement layers, trivial-change note clarifies DevOps YAML exception
- `silver-bullet.config.json.default` updated to v0.2.0 with new skill lists
- README rewritten for four-plugin ecosystem, two workflows, seven enforcement layers
- `plugin.json` updated to v0.2.0

## 0.1.0 (2026-03-31)

- Initial release
- Full dev cycle workflow (31-step enforced process)
- 8 quality-ility skills enforced during planning:
  - `/modularity` — file size limits, single responsibility, change locality
  - `/reusability` — DRY, composable components, Rule of Three
  - `/scalability` — stateless design, efficient data access, async processing
  - `/security` — OWASP top 10, input validation, secrets management, defense in depth
  - `/reliability` — fault tolerance, retries with backoff, circuit breakers, graceful degradation
  - `/usability` — intuitive APIs, actionable errors, progressive disclosure, accessibility
  - `/testability` — dependency injection, pure functions, test seams, deterministic behavior
  - `/extensibility` — open-closed principle, plugin architecture, versioned interfaces
- Six-layer compliance enforcement system
- `/silver:init` setup skill
- Superpowers + Engineering plugin dependency management
