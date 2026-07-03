# Round 7 Enterprise E2E — Session Handoff

**Written:** 2026-07-01T14:40Z  
**SB HEAD:** `b92cdc3a` on `enterprise-e2e/multi-host`  
**Prior:** [ROUND-6-SESSION-HANDOFF.md](./ROUND-6-SESSION-HANDOFF.md)  
**Gates:** [ROUND-7-GATES.md](./ROUND-7-GATES.md)

---

## Gap analysis — why 6 rounds missed the install surface bug

| Layer | What Rounds 1–6 checked | What they missed |
|-------|-------------------------|------------------|
| Matrix rows (22) | Workflow execution, autonomy, evidence artifacts | Post-install **user-facing surface** |
| Outcome criteria (27→28) | Routing, gates, KM, hooks, world-class composite | **OUT-SURFACE-01** — host isolation + token budget |
| Pre-release overlay | Install **script existence**, tri-host smoke optional | Deterministic **layout audit** after render |
| sb-doctor D15/D16 | Existed but not in E2E round gates | Not blocking strict-clean verdict |

### Root cause

Claude plugin auto-discovers every `agents/<subdir>/` as `silver-bullet:<subdir>:` namespaces ([`scripts/lib/agent-bundle-paths.sh`](../../scripts/lib/agent-bundle-paths.sh)). When Codex/Cursor bundles lived under `agents/codex` and `agents/cursor`, Claude's Agents Library showed foreign hosts and inflated description tokens (~17.8k vs 15k limit).

Enterprise E2E focused on **runtime workflow behavior** inside a test app fixture, not **SB package layout** visible to end users at install time.

### Fix (branch `fix/claude-agent-surface-cross-env`)

- Move Codex/Cursor rendered bundles to `host-bundles/{codex,cursor}/`.
- Keep only `agents/claude/` under `agents/`.
- Scope `.claude-plugin/plugin.json` to `./agents/claude`.
- Token budget now ~3.1k (well under 14k harness limit).

---

## Harness additions (implemented)

1. **`tests/scripts/test-claude-agent-surface-isolation.sh`** — live + bleed fixture checks.
2. **`scripts/validate-host-install-surface.sh`** — extended foreign-namespace string scan in Claude bundle.
3. **`OUT-SURFACE-01`** — round criterion in registry, rubric, `enterprise_e2e_outcome_assess_round`.
4. **`enterprise_e2e_preflight_install_surface`** — runs after `install-claude.sh` in matrix preflight.
5. **`validation_overlay_check_host_install_surface`** — pre-release overlay dry-run.

---

## Round 7 acceptance criteria

1. Fix branch merged to active E2E branch.
2. `test-claude-agent-surface-isolation.sh` PASS.
3. `test-outcome-assessment.sh` PASS (28 criteria).
4. Matrix preflight includes install surface audit (no `SB_E2E_SURFACE_SKIP` unless documented).
5. Phase C: `OUT-SURFACE-01 pass` in round assessment.
6. 22/22 matrix + zero new issues + prior round strict-clean for 2× consecutive.

---

## FORCE plan (if restarting matrix)

Do **not** start full 22-row live matrix unless no driver is running.

```bash
# Verify no active driver
test -f .e2e-live-test.lock && kill -0 "$(cat .e2e-live-test.lock)" 2>/dev/null && echo "DRIVER ALIVE — poll only" || echo "safe to launch"

# Recommended FORCE rows after surface fix verification
export SB_E2E_MATRIX_FORCE=1
RTK_DISABLED=1 bash scripts/run-enterprise-e2e-live-test.sh --skip-code-intel-preflight 1 3 4 6
```

Prioritize rows **1** (router), **3** (feature), **4** (bugfix), **6** (fast) for autonomy + surface preflight smoke before full 22.

---

## Patch dependency (updated @ harness merge)

| Item | Blocks live verification? | Status |
|------|----------------------------|--------|
| Harness `1a9e5900` → `enterprise-e2e/multi-host` | No (tests + wiring) | **DONE** @ `b92cdc3a` |
| Surface-fix WIP (bundle relocation) | **Yes** — `agents/codex|cursor` still present | Stashed on fix branch |
| Round 6 in-flight drivers (codex R3, cursor retry) | **Yes** — poll only | batch PID 21441 RUNNING |

---

## agentmemory / graphify

After harness edits: `graphify update .` and agentmemory capture of gap analysis + criterion OUT-SURFACE-01.
