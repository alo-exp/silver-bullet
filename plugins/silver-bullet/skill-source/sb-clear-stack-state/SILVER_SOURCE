---
name: "sb:clear-stack-state"
title: "Clear Stack State"
description: "Use when `/sb:clear-stack-state` is invoked or the five-tool stack compression mutex is dirty (sb_stack_double_compression) and tool calls are blocked — clears mutex state and optionally scaffolds agentmemory export root."
version: 0.1.0
---

# /sb:clear-stack-state — Stack compression mutex recovery

Clears global five-tool stack compression mutex violations so PreToolUse stops denying routed surfaces after a double-compression wedge.

## When to use

- Hooks return `sb_stack_double_compression` or STACK COMPRESSION CONFLICT
- Subagents inherit a dirty mutex from the parent runtime home
- After a wedged session where prior tool success cannot be trusted

## Process

### Step 1: Prefer self-heal

Complete one **compliant routed-owner** tool call on the owned surface (see [docs/LEANCTX.md](../../docs/LEANCTX.md) Recovery). The coordinator calls `sb_stack_record_routed_owner_success` → `sb_stack_clear_mutex_violations` on success.

### Step 2: Manual clear

From project root:

```bash
bash scripts/sb-doctor.sh --fix
```

This runs check **D20** and invokes `sb_stack_clear_mutex_violations` when the five-tool coordinator is active. When agentmemory is opted in, `--fix` also scaffolds `.agentmemory/memory`.

### Step 3: Verify

```bash
bash scripts/sb-doctor.sh
```

Confirm **D20** passes (`stack compression mutex clean`).

### Last resort

```bash
rm -f "${SB_RUNTIME_STATE_DIR:-$HOME/.silver-bullet}/stack-compression-mutex"
```

No audit trail — use only when doctor fix cannot run.

## References

- [docs/LEANCTX.md](../../docs/LEANCTX.md) — Recovery (stack compression mutex)
- `hooks/lib/stack-compression-coordinator.sh` — `sb_stack_clear_mutex_violations`, `sb_stack_record_routed_owner_success`
