# Self-Verification Prompt: RTK + Context Mode in Cursor

**Purpose:** RTK + Context Mode verification only — not Graphify+agentmemory (see `docs/graphify-am/verification/`). Concise global audit: [cursor-verify-rtk-cm.md](verification/cursor-verify-rtk-cm.md).

## Purpose

This prompt tells **Cursor** (the AI code editor) how to **self-verify** that **RTK + Context Mode** are installed and working correctly in the local environment. It produces a pass/fail report per check, plus an overall verdict.

Cursor has its own **native hooks system** (`~/.cursor/hooks.json`, schema `version: 1`) and **MCP support** (`~/.cursor/mcp.json`). Both integration paths are covered:

1. **Context Mode** as an MCP server (registered in `~/.cursor/mcp.json`) + as a `preToolUse` / `postToolUse` hook (registered in `~/.cursor/hooks.json`).
2. **RTK** as a `preToolUse` hook that fires automatically when Cursor is about to run a shell command — transparent rewriting (`git status` → `rtk git status`). RTK's `hook cursor` reads from the allow-list in `~/.cursor/cli-config.json`.

If any check fails, the prompt tells the user exactly which commands to run to fix it.

---

## Pre-Flight (Read-Only)

Before running any checks, do the following three pre-flight checks. They take 30 seconds and confirm the tools exist at all.

### Check 1 — RTK binary exists

Ask the user to run this in their terminal and paste the output:

```bash
which rtk && rtk --version
```

**Expected output:** A path to the `rtk` binary (e.g., `$HOME/.local/bin/rtk`) and the version string (e.g., `rtk 0.42.4`).

**Pass criteria:** The output contains a path under `/Users/...`, `/usr/local/...`, or `/opt/homebrew/...` and a version `0.42` or newer. Cursor wiring requires **RTK >= 0.42.0** (older versions mishandle `rtk rewrite` exit code 3 — see [rtk-ai/rtk#1112](https://github.com/rtk-ai/rtk/issues/1112)).

**Fail modes:**
- `command not found` → RTK is not installed. Install: `brew tap rtk-ai/rtk && brew install rtk` (macOS) or `curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/master/install.sh | sh` (Linux).
- Version is `0.3x` or older → outdated. Re-run the install command above.

### Check 2 — RTK binary identity (the name-collision trap)

Ask the user to run this and paste the output:

```bash
rtk --help 2>&1 | head -5
```

**Expected first line:** `rtk — high-performance CLI proxy` or `rtk rewrite` listed in the commands section. This is the rtk-ai/rtk (Rust Token Killer) binary.

**Wrong binary:** If the first line says `rtk-check` or mentions `Rust Type Kit`, the user has the `reachingforthejack/rtk` package installed instead. This is a different project that uses the same binary name. **Uninstall and reinstall:**

```bash
brew uninstall rtk 2>/dev/null  # or: cargo uninstall rtk
brew tap rtk-ai/rtk && brew install rtk  # or: curl installer
```

### Check 3 — Context Mode binary exists

Ask the user to run this in their terminal and paste the output:

```bash
which context-mode
# Also try the absolute path, since on Apple Silicon Homebrew installs to
# /opt/homebrew/bin which is often NOT in the user's shell PATH:
ls -la /opt/homebrew/bin/context-mode 2>/dev/null
ls -la ~/.local/bin/context-mode 2>/dev/null
```

**Expected output:** A path to the `context-mode` binary. The most common locations:

- `/opt/homebrew/bin/context-mode` (Homebrew on Apple Silicon — common)
- `/usr/local/bin/context-mode` (Homebrew on Intel Mac / Linux)
- `~/.local/bin/context-mode` (npm global with custom prefix)
- `~/.npm-global/bin/context-mode` (npm global with prefix)

**Pass criteria:** A path under `/opt/homebrew/...`, `/usr/local/...`, or `/Users/...` exists. The `--version` flag is slow to start (>2s) — this is a known characteristic of the bundled CLI, not a failure.

**Fail modes:**
- `which context-mode` returns nothing AND no path exists under `/opt/homebrew/bin/context-mode` or `~/.local/bin/context-mode` → Context Mode is not installed. Install: `npm install -g context-mode`. Requires Node >= 22.5.
- Version is older than `1.0.100` → outdated. Re-run `npm install -g context-mode@latest`.

---

## Check A — Context Mode MCP Server Is Connected (Cursor Does This)

Cursor has built-in MCP support. Context Mode should appear in the available tools. The config lives at `~/.cursor/mcp.json`.

**Step A.1** — Confirm `~/.cursor/mcp.json` exists and contains `context-mode`. Ask the user to run:

```bash
cat ~/.cursor/mcp.json | jq '.mcpServers | keys'
```

**Pass criteria:** The output lists `"context-mode"` (and possibly other MCP servers).

**Fail modes:**
- File doesn't exist → create it with this content:

  ```json
  {
    "mcpServers": {
      "context-mode": {
        "command": "context-mode"
      }
    }
  }
  ```

- File exists but no `context-mode` key → add the entry above. The user can also re-run the SB install script: `bash scripts/enable-rtk-context-mode.sh --tool context_mode` (idempotent).

**Step A.2** — Verify the binary the config points to is actually launchable. Ask the user to run:

```bash
# Use the bare name from the config
command -v context-mode
# Then test the MCP server can respond (initialize via stdio)
{
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}'
} | /opt/homebrew/bin/context-mode mcp 2>&1 | head -5
```

**Expected second command output:** A JSON response with `{"result":{"serverInfo":{"name":"context-mode","version":"1.0.x"},"jsonrpc":"2.0","id":1}}`.

**Note on bare vs absolute path:** Cursor's MCP config uses `"command": "context-mode"` (bare name) — Cursor inherits the user's shell PATH, so this works even on Apple Silicon where `/opt/homebrew/bin` is not on the system PATH. The Claude Desktop MCP trap (must use absolute path) does **not** apply to Cursor.

**Step A.3** — Confirm `context-mode` is registered in Cursor's hook config. Ask the user to run:

```bash
jq '.hooks.preToolUse[] | select(.command | contains("context-mode"))' ~/.cursor/hooks.json
```

**Expected output:** A JSON object with `"command": "context-mode hook cursor pretooluse"` (or similar) and a `matcher` covering `Shell|Read|Grep|Glob|WebFetch|mcp_web_fetch|mcp_fetch_tool|Task|MCP:ctx_execute|MCP:ctx_execute_file|MCP:ctx_batch_execute|MCP:(?!ctx_)`. This is the **preToolUse hook** for Context Mode — different from the MCP server, but both must be wired for full integration.

**Fail modes:**
- No matching entry → run `bash scripts/optimize-rtk-context-mode.sh --host cursor` (idempotent re-merge) OR add manually. The expected entry shape:

  ```json
  {
    "hooks": {
      "preToolUse": [
        {
          "command": "context-mode hook cursor pretooluse",
          "matcher": "Shell|Read|Grep|Glob|WebFetch|mcp_web_fetch|mcp_fetch_tool|Task|MCP:ctx_execute|MCP:ctx_execute_file|MCP:ctx_batch_execute|MCP:(?!ctx_)",
          "failClosed": false
        }
      ]
    }
  }
  ```

  The `failClosed: false` (default) means a hook failure does NOT block the agent — Cursor falls back to running the tool normally. Set `failClosed: true` only after verifying the hook works.

**Step A.4** — Test the MCP server end-to-end. Run the Cursor-aware doctor:

```bash
CONTEXT_MODE_PLATFORM=cursor context-mode doctor
```

**Expected output:** A multi-section report showing:

- `◇ Native hook config: PASS — Loaded $HOME/.cursor/hooks.json`
- `◆ preToolUse: PASS — preToolUse hook configured`
- `◆ postToolUse: PASS — postToolUse hook configured`
- `◆ Plugin enabled: PASS — context-mode found in $HOME/.cursor/mcp.json`
- `◆ FTS5 / SQLite: PASS — native module works`
- `◆ npm (MCP): PASS — v1.0.x`

**Fail modes:**
- `[FAIL]` or `[ERROR]` for any of the above → see the specific failure's remediation in the doctor output.
- `▲ Cursor: WARN — vX.Y.Z, latest v1.0.x` → Context Mode is outdated. Run `/context-mode:ctx-upgrade` (in Cursor's chat) or `npm install -g context-mode@latest`.
- `▲ Claude compatibility: WARN — Claude-compatible hooks detected; native Cursor hooks are the supported configuration` → A `~/.codex/settings.json` was detected with hooks. Native Cursor hooks take precedence in Cursor; this warning is informational only.
- All `[PASS]` → Check A passes. Proceed to Check B.

**Note on `CONTEXT_MODE_PLATFORM=cursor`:** This env var forces the doctor to use Cursor's adapter (storage paths under `~/.cursor/context-mode/`) instead of guessing from process tree. **Always set it when running the doctor manually** — without it, the doctor may report low confidence or default to a wrong platform.

---

## Check B — Context Mode Sandbox Actually Compresses

This is the deeper test. The doctor above confirms the server runs; this check confirms it actually compresses.

**Step B.1** — Run the doctor in verbose mode to see runtime availability. The doctor's "Runtimes" section is the authoritative source:

```bash
CONTEXT_MODE_PLATFORM=cursor context-mode doctor | grep -A 20 "Runtimes"
```

**Pass criteria:** Each line shows `JavaScript`, `TypeScript`, `Python`, `Shell`, `Ruby`, `Rust`, `PHP`, `Perl` with an available runtime (e.g., `bun (1.3.14) ⚡`, `python3 (Python 3.14.4)`, `rustc (rustc 1.95.0)`).

**Fail modes:**
- `JavaScript: node (v22.x)` without `⚡` and no `bun` → install Bun for 3-5x speedup: `brew install bun` (macOS) or `curl -fsSL https://bun.sh/install | bash` (Linux).
- `TypeScript` missing entirely → Bun is not installed and `tsx` / `ts-node` is not global. Install Bun (preferred) or `npm install -g tsx`.
- Missing language runtimes → install via Homebrew / system package manager.

**Step B.2** — Direct MCP compression test (proves the server actually delivers compressed output). Pipe the JSON-RPC `tools/call` request to the MCP server:

```bash
{
  echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"verify","version":"1.0"}}}'
  sleep 0.5
  echo '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  sleep 0.5
  echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"ctx_execute","arguments":{"language":"javascript","code":"const arr = []; for (let i = 0; i < 1000; i++) arr.push({id: i, value: `item-${i}`, ts: Date.now()}); console.log(JSON.stringify({count: arr.length, sample: arr.slice(0, 3)}));"}}}'
  sleep 2
  echo '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"ctx_stats","arguments":{}}}'
  sleep 1
} | /opt/homebrew/bin/context-mode mcp > /tmp/cm-verify.json 2>&1

# Extract the compression stats
jq -r '.result.content[0].text' /tmp/cm-verify.json | tail -30
```

**Expected output:** A `ctx_stats` report showing token savings percentage. For a realistic compression workload (e.g., processing a 1MB log file through a sandbox script), savings should be > 80%.

**Pass criteria:** The `ctx_execute` call returns a small JSON snippet (the `console.log` output) and `ctx_stats` reports savings > 0% on the test workload. On a 5000-entry log test (typical), expect > 99% savings.

**Fail modes:**
- `ctx_execute` returns "Runtime error" or hangs → Node/Bun version mismatch. `node --version` must be >= 22.5 (with Bun installed, Bun handles execution and Node version is less critical).
- `ctx_stats` reports 0% savings → instrumentation is not active. Restart Cursor.

---

## Check C — RTK preToolUse Hook Is Wired in Cursor

RTK's automatic command-rewriting path requires a `preToolUse` entry in `~/.cursor/hooks.json` with matcher `"Shell"` and command `"rtk hook cursor"`.

**Step C.1** — Confirm the RTK hook entry exists. Ask the user to run:

```bash
jq '.hooks.preToolUse[] | select(.command | contains("rtk"))' ~/.cursor/hooks.json
```

**Pass criteria:** Output is a JSON object with `"command": "rtk hook cursor"` (or a path-prefixed variant) and `"matcher": "Shell"`.

**Fail modes:**
- No matching entry → run the official RTK Cursor installer: `rtk init -g --agent cursor`. This appends the RTK entry to `~/.cursor/hooks.json` (idempotent — safe to re-run).
- Entry exists but matcher is something other than `"Shell"` → RTK only rewrites Shell commands; an incorrect matcher (e.g., `"Bash"`) means nothing gets rewritten. Fix: change matcher to `"Shell"` or re-run `rtk init -g --agent cursor`.

**Step C.2** — **CRITICAL** — Confirm the **allow-list coupling**. RTK's Cursor hook only rewrites commands matching `permissions.allow` entries in `~/.cursor/cli-config.json`. If the allow-list is missing or incomplete, RTK silently returns `{}` and the raw command runs. Ask the user to run:

```bash
# Check that the user's allow-list exists and has the right shape
jq '.permissions.allow' ~/.cursor/cli-config.json | head -30
```

**Pass criteria:** The allow-list contains entries like `"Shell(git *)"`, `"Shell(ls *)"`, `"Shell(cat *)"`, `"Shell(find *)"`, `"Shell(npm *)"`, etc. — i.e., broad coverage of common read-heavy dev commands.

**Fail modes:**
- File doesn't exist or `permissions.allow` is empty/missing → merge SB's research-backed allow-list: `bash scripts/optimize-rtk-context-mode.sh --host cursor` (idempotent re-merge) OR copy `scripts/lib/cursor-cli-allowlist.json` into `~/.cursor/cli-config.json` `permissions.allow`. The expected coverage: `git`, `gh`, `npm`/`pnpm`/`yarn`/`bun`, `cargo`/`go`/`rustc`, `kubectl`/`docker`/`helm`/`terraform`/`pulumi`, `aws`/`gcloud`/`az`, `pytest`/`vitest`/`jest`/`mocha`/`tap`, `rg`/`grep`/`cat`/`head`/`tail`/`find`/`ls`, `jq`, `node`/`python`/`ruby`, file ops (`cp`/`mv`/`rm`/`mkdir`/`chmod`), shell wrappers (`bash`/`sh`/`zsh`).
- Allow-list only has narrow entries (e.g., just `"Shell(git status)"`) → RTK cannot rewrite most commands. Broaden the allow-list per the recommendation above.

**Step C.3** — Test the hook actually rewrites. Run the official verification command:

```bash
echo '{"tool_name":"Shell","tool_input":{"command":"git status"}}' | rtk hook cursor
```

**Expected output:**

```json
{"continue":true,"permission":"allow","updated_input":{"command":"rtk git status"}}
```

The presence of `updated_input.command` containing `rtk` confirms the rewrite worked.

**Pass criteria:** The output contains `updated_input.command` that starts with `rtk ` (e.g., `rtk git status`, `rtk ls`, etc.).

**Fail modes:**
- Output is `{}` or `{"continue":true,"permission":"allow"}` (no `updated_input`) → allow-list is missing `Shell(git *)`. Re-check C.2 and broaden the allow-list.
- Output is `{"continue":true,"permission":"deny","user_message":"..."}` → a deny rule matched (e.g., RTK detected a dangerous command like `rm -rf /`). This is correct behavior, not a bug — try a different command like `npm --version`.
- `command not found: rtk` → RTK binary is not on Cursor's PATH. Run `which rtk` and ensure it's installed at a path Cursor can find.

**Step C.4** — Test a non-Shell rewrite (must be a pass-through). RTK only rewrites Shell commands; other tools should pass through unchanged:

```bash
echo '{"tool_name":"Read","tool_input":{"file_path":"/etc/passwd"}}' | rtk hook cursor
```

**Expected output:** `{}` (empty JSON object) — the hook returns pass-through because the matcher is `Shell`, not `Read`.

**Pass criteria:** Empty `{}` (no rewrite attempted).

**Fail modes:**
- Output contains `updated_input` → matcher is wrong (e.g., matching all tools). Fix: set matcher back to `"Shell"`.

**Step C.5** — Confirm `rtk gain` shows real data. RTK's gain tracker logs every successful rewrite:

```bash
rtk gain
```

**Pass criteria:** A non-empty table with at least one row. Note: `rtk gain` may warn `[warn] No hook installed — run \`rtk init -g\` for automatic token savings` on Cursor — **this warning is misleading** on Cursor, since RTK tracks Cursor wirings via `~/.cursor/hooks.json` separately from Claude Code's `~/.codex/settings.json`. Savings still accrue when the hook rewrites commands.

**Fail modes:**
- Table is empty → no rewrites have fired yet. Run a Shell command via Cursor (e.g., `git status`) and re-check.

---

## Check D — Cursor-Specific Integration Points

This check covers the **Cursor-only** wiring that RTK and Context Mode need but the Claude Code equivalent doesn't. Failure of any of these means partial integration.

### Check D.1 — Cursor rules installed

Context Mode requires `.mdc` rule files to route MCP tool usage — Cursor does NOT surface hook-injected `additional_context` to the model ([forum.cursor.com #155689](https://forum.cursor.com/t/native-posttooluse-hooks-accept-and-log-additional-context-successfully-but-the-injected-context-is-not-surfaced-to-the-model/155689)). The rules must be present at:

1. **Global rules**: `~/.cursor/rules/`
2. **Project rules**: `.cursor/rules/` (in the current working directory or each project Cursor is opened against)

Ask the user to run:

```bash
echo "=== Global rules ==="
ls -la ~/.cursor/rules/ | grep -E "context-mode|token-compression"
echo ""
echo "=== Project rules ==="
ls -la .cursor/rules/ 2>/dev/null | grep -E "context-mode|token-compression"
```

**Pass criteria:** Both lists contain `context-mode.mdc` (Context Mode routing rules) and `token-compression-enforcement.mdc` (SB enforcement — optional but recommended).

**Fail modes:**
- Missing global rules → install with `bash scripts/install-recommended-tools-cursor.sh --global` (idempotent) or `bash scripts/optimize-rtk-context-mode.sh --host cursor` (also merges allow-list + hooks).
- Missing project rules → copy `templates/context-mode.mdc` to `.cursor/rules/` in the project, or use SB's `/silver:init` to scaffold.
- Rules present but stale (mtime > 30 days) → re-run the installer; upstream Context Mode may have updated the rule content.
- **Doctor loads project `.cursor/hooks.json` instead of `~/.cursor/hooks.json`** → remove the workspace copy. Global `~/.cursor/hooks.json` is authoritative for personal Cursor; a repo-local `.cursor/hooks.json` overrides it and causes doctor drift. SB plugin hooks merge into global via `merge-cursor-hooks.py`, not project hooks.

### Check D.2 — Hook ordering: RTK before Context Mode

RTK and Context Mode both register `preToolUse` hooks. **Order matters**: RTK must rewrite the command BEFORE Context Mode sees it (so CM can decide whether to deny the rewritten `rtk` command). Ask the user to run:

```bash
jq '.hooks.preToolUse | to_entries[] | {idx: .key, cmd: (.value.command | split(" ")[0])}' ~/.cursor/hooks.json | head -40
```

**Pass criteria:** The RTK entry (`cmd: "rtk"`) appears with a **lower index** than the Context Mode entry (`cmd: "context-mode"`). Cursor runs hooks in array order; lower index runs first.

**Fail modes:**
- Context Mode appears before RTK → edit `~/.cursor/hooks.json` and reorder the `preToolUse` array so `rtk hook cursor` comes first. OR re-run `bash scripts/optimize-rtk-context-mode.sh --host cursor` which enforces this order.
- No clear ordering visible (e.g., one hook is missing) → re-check Checks A.3 and C.1.

### Check D.3 — `beforeShellExecution` and `afterShellExecution` hooks

Cursor also has dedicated shell execution hooks (`beforeShellExecution`, `afterShellExecution`) that are separate from `preToolUse`. RTK registers for `preToolUse` only (it doesn't need before/after wrappers), but Context Mode may register for both. Ask the user to run:

```bash
jq '.hooks | {before: .beforeShellExecution, after: .afterShellExecution}' ~/.cursor/hooks.json
```

**Pass criteria:** Either both are absent (acceptable — `preToolUse` is sufficient) OR `afterShellExecution` contains a Context Mode entry (for capturing shell output stats). No `beforeShellExecution` should be wired for Context Mode — it would re-route commands Cursor already routed.

**Fail modes:**
- `beforeShellExecution` contains a `context-mode` entry → Cursor will run CM's hook TWICE (once in `preToolUse`, once in `beforeShellExecution`). Remove the duplicate from `beforeShellExecution`.

---

## Check E — End-to-End Smoke Test (Both Tools, One Session)

This is the headline test. The user runs a real Cursor session that exercises both tools — RTK's hook fires automatically, and Context Mode's MCP tools are called by Cursor directly.

**Step E.1** — In a fresh Cursor conversation, ask:

> "Run `git status` in the current working directory. Then run `mcp__context-mode__ctx_stats` and tell me the per-tool savings."

**Expected behavior:**

- Cursor invokes the `Shell` tool. The `preToolUse` hook rewrites `git status` → `rtk git status` transparently. The shell output is the compressed form.
- Cursor calls `mcp__context-mode__ctx_stats` (this MCP tool name has the `mcp__` prefix and uses underscore instead of dot — Cursor's MCP tool naming convention).
- `ctx_stats` reports per-tool savings. Zero MCP savings is acceptable for this single-turn test; what matters is that the call succeeds.

**Pass criteria:** Both calls succeed. The git status output is the compressed form (RTK fired).

**Step E.2** — Add an MCP call that exercises the compression. Ask Cursor:

> "Use `mcp__context-mode__ctx_fetch_and_index` to fetch https://example.com and summarize the page in 3 sentences."

**Expected behavior:** Cursor calls `ctx_fetch_and_index`, which fetches the page, indexes it into the FTS5 store, and returns a small summary (200-500 words), not the full ~50KB HTML.

**Pass criteria:** The visible response is a clean summary, not raw HTML.

**Step E.3** — Re-run the doctor in a terminal and confirm accumulated state:

```bash
CONTEXT_MODE_PLATFORM=cursor context-mode doctor 2>&1 | grep -E "PASS|WARN|FAIL"
```

**Pass criteria:** More `PASS` entries than before E.1 — the doctor's session log should now contain the fetch_and_index call.

---

## Final Verdict

After running all checks, produce a summary table:

| Check | Description | Result |
|-------|-------------|--------|
| 1 | RTK binary exists | ✅ / ❌ |
| 2 | RTK binary identity (rtk-ai/rtk, not Rust Type Kit) | ✅ / ❌ |
| 3 | Context Mode binary exists | ✅ / ❌ |
| A.1 | `~/.cursor/mcp.json` contains context-mode | ✅ / ❌ |
| A.2 | MCP server responds to JSON-RPC initialize | ✅ / ❌ |
| A.3 | `preToolUse` hook entry exists in `~/.cursor/hooks.json` | ✅ / ❌ |
| A.4 | `CONTEXT_MODE_PLATFORM=cursor context-mode doctor` shows all green | ✅ / ❌ |
| B.1 | Doctor reports available runtimes (JS, TS, Python, etc.) | ✅ / ❌ |
| B.2 | `ctx_execute` actually compresses (savings > 80% on test) | ✅ / ❌ |
| C.1 | RTK `preToolUse` hook entry exists with matcher `"Shell"` | ✅ / ❌ |
| C.2 | Allow-list coupling: `~/.cursor/cli-config.json` `permissions.allow` covers common commands | ✅ / ❌ |
| C.3 | `rtk hook cursor` rewrites `git status` → `rtk git status` | ✅ / ❌ |
| C.4 | Non-Shell tools pass through unchanged (`{}` output) | ✅ / ❌ |
| C.5 | `rtk gain` shows real data after C.3 | ✅ / ❌ |
| D.1 | Cursor rules installed (`context-mode.mdc`) at global and project level | ✅ / ❌ |
| D.2 | RTK hook ordered before Context Mode hook in `preToolUse` array | ✅ / ❌ |
| D.3 | No duplicate `beforeShellExecution` for Context Mode | ✅ / ❌ |
| E.1 | Single session: Shell call triggers RTK rewrite | ✅ / ❌ |
| E.2 | `ctx_fetch_and_index` returns summary, not raw HTML | ✅ / ❌ |
| E.3 | Doctor shows accumulated session state after E.1+E.2 | ✅ / ❌ |

**Overall verdict:**

- **🟢 100% Working** — All 19 checks pass. RTK and Context Mode are fully wired in Cursor with automatic hook firing, MCP integration, allow-list coupling, and rule-based routing.
- **🟡 Partially Working** — 13-18 checks pass. Some integration is missing; specific check(s) failed. The most common gaps are C.2 (allow-list incomplete) and D.1 (Cursor rules not installed).
- **🔴 Not Working** — 12 or fewer checks pass. Either RTK, Context Mode, or both are not properly installed. Re-run the failing checks' fail-mode sections.

---

## What This Verification Does NOT Cover (Known Gaps)

- **Cross-tool combined savings on a single session.** Check E exercises both tools in one session but measures each independently. Combined-compression metrics require Cursor's native token counter, which is not surfaced via MCP.
- **The `additional_context` bug.** Cursor does not surface hook-injected `additional_context` to the model ([forum.cursor.com #155689](https://forum.cursor.com/t/native-posttooluse-hooks-accept-and-log-additional-context-successfully-but-the-injected-context-is-not-surfaced-to-the-model/155689)). Context Mode's routing MUST go through `.mdc` rules and MCP tool descriptions — never through hook-injected context. Check D.1 is the workaround for this.
- **Plugin-based Context Mode install.** Cursor also supports installing Context Mode as a plugin (via Cursor's plugin marketplace), which auto-registers the MCP and hooks. This verification assumes the manual `npm install -g context-mode` + manual wiring path. The plugin path should produce identical wire format; if it does not, file an issue upstream.
- **Workspace team-shared hook configs.** Cursor supports team-shared hooks via `.cursor/hooks.json` in version-controlled workspaces. The doctor reports these as `SKIP — no team-shared hook configs found` when absent. If the user is in a workspace with team hooks, those take precedence over global `~/.cursor/hooks.json`.
- **Leftover `.mcp.json` files.** Older Context Mode versions wrote `~/.mcp.json` (Claude Code format). Cursor ignores this file but it may confuse manual inspection. The doctor reports `SKIP — no plugin cache exists yet (Claude Code has not installed context-mode here)` when the file is absent; if it exists, the doctor does not flag it as a problem (Cursor ignores it).
- **`rtk gain --agent cursor` does not exist.** `rtk gain` is a global tracker across all agents. The misleading "No hook installed" warning is upstream RTK behavior — it tracks Claude Code hook registration specifically. Cursor wiring is verified via `~/.cursor/hooks.json` (Check C.1) instead.
- **The doctor env var `CONTEXT_MODE_PLATFORM=cursor`.** Without this env var, Context Mode guesses the platform from the process tree and may default to Claude Code's adapter (storage under `~/.codex/context-mode/`). On a fresh Cursor install with no Claude Code adapter, this guess may be wrong; the doctor reports low confidence. **Always set the env var for manual doctor runs.**

---

## Output Format

After running all checks, paste the table above plus the overall verdict in plain text. The user can read this in 30 seconds to know whether the stack is working in Cursor.

If you (Cursor) cannot complete any check yourself because you lack a tool (e.g., the user runs the shell commands), explicitly mark it as **[USER-VERIFIED]** in the result column and tell the user what to look for in their output.