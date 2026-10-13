# SECURE — Stack double-compression recovery

| Field | Value |
|-------|-------|
| Phase | `stack-double-compression-recovery` |
| Branch | `fix/stack-double-compression-recovery` |
| Base commit | `2dc1eccd` (recovery land) + SUMMARY `59c533f0` |
| Reviewed | 2026-07-10 (UTC+10) |
| Security commits | [`9203419a`](https://github.com/alo-exp/silver-bullet/commit/9203419a) (SECURE.md), [`b8253191`](https://github.com/alo-exp/silver-bullet/commit/b8253191) (hook fixes) |
| Skill | `silver-secure` (FLOW 11 SECURE) |
| Verdict | **PASS** (no open BLOCK findings) |

## Scope reviewed

- `hooks/lib/stack-compression-coordinator.sh` — mutex record/clear, recovery (`sb_stack_tool_is_compliant_routed_owner`), bash marker tightening
- `hooks/stack-compression-coordinator.sh` — PreToolUse deny/allow + self-heal path
- `hooks/lib/agentmemory-gate.sh` + `hooks/agentmemory-gate.sh` — auto-scaffold export root (RED-5)
- `scripts/sb-doctor.sh` + `scripts/lib/sb-doctor/fix.sh` — D20 check and `--fix`
- `skills/silver-clear-stack-state/SKILL.md` — manual recovery playbook
- Targeted tests: RED-1..5, D20, mutual-exclusion, agentmemory gate

## Findings

### BLOCK (fixed in this SECURE pass)

| ID | Area | Issue | Fix |
|----|------|-------|-----|
| SEC-01 | agentmemory scaffold | `export_root` from `.silver-bullet.json` could contain `..` or resolve outside `project_root`; `mkdir -p` in hook/doctor scaffold could create directories off-repo | Added `sb_agentmemory_export_rel_is_safe`, `sb_agentmemory_export_path_is_project_scoped`; `abs_export_path` / scaffold / `export_exists` reject escape paths |
| SEC-02 | Mutex recovery | Native `Read`/`Grep`/`WebFetch` were treated as “compliant routed owner” and could clear `stack-compression-mutex` without an MCP/Bash recovery action — enforcement bypass | Removed native surface tools from `sb_stack_tool_is_compliant_routed_owner`; recovery limited to Bash (no double-wrap) and allowed MCP tools |

### WARN (accepted)

| ID | Area | Issue | Mitigation |
|----|------|-------|------------|
| SEC-W01 | Doctor `--fix` D20 | Clears mutex + scaffolds agentmemory without proving a compliant tool call | Intentional human/agent operator escape hatch; documented in `silver-clear-stack-state` skill; requires shell access to run doctor |
| SEC-W02 | Manual `rm` | Skill documents last-resort `rm` of mutex file (no audit trail) | Operator-only; doctor `--fix` preferred |
| SEC-W03 | cert-bypass | `sb_cert_run_bypass_active` skips agentmemory gate (including scaffold) | Existing cert-run contract; not introduced by this phase |
| SEC-W04 | Mutex state scope | Mutex file lives in `SB_RUNTIME_STATE_DIR` (user home), not project | By design — cross-session wedge recovery; not a privilege escalation across OS users |

### INFO

| ID | Note |
|----|------|
| SEC-I01 | Hook `umask 0077` on coordinator + agentmemory gates — state/mutex files user-only |
| SEC-I02 | `export_exists` rejects symlink export roots (pre-existing) |
| SEC-I03 | Bash leanctx marker tightened (RED-2/3) — reduces false double-wrap denials on install paths |
| SEC-I04 | Recovery self-heal requires MCP tool that passes `sb_stack_should_deny_mcp_tool` (e.g. `ctx_search`) |

## Threat model

- **Attacker:** compromised agent session or malicious `.silver-bullet.json` in a project the user already opened
- **Assets:** filesystem outside repo, compression enforcement integrity
- **Out of scope:** OS-level multi-user attacks, remote code execution via doctor (doctor already trusted operator tool)

## Hook deny/allow integrity

| Path | Behavior | Assessment |
|------|----------|------------|
| Mutex dirty + non-compliant tool | `emit_block` + `sb_stack_double_compression` | OK |
| Mutex dirty + compliant MCP | Clear mutex, allow tool, record owner | OK |
| Mutex dirty + native Read | Deny (post SEC-02) | OK |
| Double-wrap bash | Deny + record violation | OK |
| Wrong-owner `lctx_*` | Deny via routing | OK |
| agentmemory scaffold | Only under validated project export path | OK (post SEC-01) |

## Doctor D20 `--fix` side effects

1. `sb_stack_clear_mutex_violations` — removes `stack-compression-mutex` in runtime state dir
2. `sb_agentmemory_scaffold_export_root` — creates `.agentmemory/memory` + `snapshots` when agentmemory opted in

Both are idempotent and scoped (mutex: user state dir; scaffold: project-contained export root after SEC-01).

## Tests (post-fix)

| Suite | Result |
|-------|--------|
| `test-agentmemory-gate-lib.sh` | 9/9 (includes traversal block) |
| `test-five-tool-mutual-exclusion.sh` | 22/22 (includes native Read block when mutex dirty) |
| `test-stack-compression-coordinator.sh` | 20/20 |
| `test-agentmemory-gate.sh` | 8/8 |

## Exit gate

- **BLOCK findings:** 0 open (2 fixed)
- **Clear for VALIDATE:** **Yes**
- **Blockers:** None

## Residual risk

Operator can always run `sb-doctor.sh --fix` or delete mutex state to resume work; this is product-intentional recovery, not a silent bypass of unrelated security boundaries.
