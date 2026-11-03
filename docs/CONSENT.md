# User consent for the opt-in tool stack

Silver Bullet can recommend, install, wire and enforce seven optional tools: Graphify,
agentmemory, Alumnium, search-cli, RTK, Context Mode and LeanCTX. Installing a tool or
changing machine-wide host configuration is a decision for the person at the keyboard, not for
a repository. This page describes where that decision is recorded and how scripts use it.

## Trust model

`.silver-bullet.json` is committed, repository-controlled content. For the tool stack it may

- **recommend** a tool (`recommended_tools.<id>.enabled_by_user: true`),
- **turn a tool off** for the project (`enabled_by_user: false`, `enforcement_suspended: true`,
  `required_when_enabled: false`),
- **tune validated values** (TTLs, a loopback health URL, a project-relative export root, a
  minimum version written as digits and dots).

It never grants consent and never supplies a command, URL or path that Silver Bullet runs,
fetches, prints as an instruction or writes outside the project:

| Setting in the project file | What Silver Bullet does with it |
|---|---|
| `enabled_by_user: true` | A recommendation. The session shows a one-time notice; gates stay inactive until the user confirms. |
| `install_commands`, `platform_install_commands`, `benefits_summary`, `license_note`, `install_failure_reason`, `cli_command` | Ignored. Install and setup instructions come only from the built-in tables in `hooks/lib/recommended-tools.sh`. |
| `health_url` | Used only when it is `http(s)` to `localhost`, `127.0.0.1` or `[::1]`; passed to `curl` after `--`. |
| `graph_path`, `export_root` | Used only as a project-relative path of plain characters with no `.`, `..` or empty component. |
| `usage_state_file`, `query_state_file` | Used only inside the runtime state directory and only for a stamp named `<name>-usage` or `<name>-query` (lowercase letters, digits, dashes; matched case-insensitively), so it can never name one of SB's own state files; otherwise the default stamp path is used. |
| `min_version`, `min_node_version` | Used only when it is 1 to 3 dotted numbers; never evaluated arithmetically before that check. |
| `read_deny_bytes` | May raise the Context Mode read threshold or set it to 0 (off); a lower value is ignored. |

## The consent store

One JSON file per user, outside every repository:

```
${XDG_CONFIG_HOME:-$HOME/.config}/silver-bullet/consent.json        (mode 0600)
```

```json
{
  "schema": 1,
  "machine":  { "<tool>": { "<capability>": RECORD } },
  "projects": { "<project key>": { "<tool>": { "enforce": RECORD } } },
  "log":      [ { "at": "...", "action": "grant|decline|revoke", "tool": "...",
                  "capabilities": ["..."], "scope": "machine|<project key>", "source": "..." } ]
}
```

`RECORD` is `{"decision": "granted" | "declined", "at": "<UTC ISO-8601>", "source": "<label>"}`.
The log keeps the newest 200 changes. Unknown keys are preserved on every write.

Capabilities:

| Capability | Meaning | Scope |
|---|---|---|
| `install` | Install or upgrade the tool on this machine (npm -g, brew, uv, curl or sh). | machine |
| `wire` | Change machine-wide host configuration for it (`~/.claude.json`, `~/.cursor`, LaunchAgents, `~/.agentmemory/.env`). | machine |
| `enforce` | Let Silver Bullet's hooks apply the tool's blocking gates. | one project, or machine (every project) |

A project key is the project root's physical path; a linked git worktree maps to its main
checkout. A project record wins over a machine record. No record means `unset`: nothing is
installed or wired and no gate blocks.

Writes are atomic (temp file in the same directory, then rename), keep the file's mode, back the
previous version up to `consent.json.bak`, change nothing when the decision is already
recorded, and refuse to write through a symlink (the `.bak` backup is written as a fresh file,
so a symlink planted there is replaced, never followed). Concurrent writers are serialized with a
lock directory (`.consent.lock`, taken over when its owner process is gone), so parallel grants
and revokes do not lose one another's update.

## What consent does and does not defend against

Consent defends against **repository content**: a cloned repo cannot opt you in to installs,
host wiring or blocking gates. It does not defend against the agent itself. The coding agent runs
as your OS user, so it can run `sb-consent.sh` or edit the store; the `source` label in the log is
not authenticated. Agents should record or change consent only when the user says so. The practical
effect is limited: granting adds gates or allows installs and wiring the agent could already
perform with its shell, and declining switches off opt-in gates, as editing the old
`enabled_by_user` flag did.

`sb-consent.sh --project DIR` accepts any directory inside the project and records the one that
holds `.silver-bullet.json`. The one-time migration notice's **Yes** command grants `enforce`
only; installing and wiring are machine-wide and need their own `grant ... --capabilities
install,wire`.

## How the gates decide

A gate acts when all of these hold:

1. the user granted `enforce` for the tool (this project or machine-wide) and did not decline it;
2. the working directory is inside an initiated Silver Bullet project (walk-up discovery; a
   cached project root from another session never activates a gate);
3. the project file does not turn the tool off.

The consent check is the first thing every opt-in hook does, before any `jq` or `python3`
process, so a user who never opted in pays one file test per hook call.

## Bash API

`source hooks/lib/user-consent.sh`:

| Function | Result |
|---|---|
| `sb_consent_store_path` | Print the store path. |
| `sb_consent_tool_valid TOOL` | Status 0 for a known tool id. |
| `sb_consent_capability_valid CAP` | Status 0 for `install`, `wire` or `enforce`. |
| `sb_consent_project_key DIR` | Print the project key for DIR (status 1: no such directory). |
| `sb_consent_decision TOOL CAP [PROJECT_DIR]` | Print `granted`, `declined` or `unset`. |
| `sb_consent_granted TOOL CAP [PROJECT_DIR]` | Status 0 only when granted. |
| `sb_consent_store_mentions TOOL` | Cheap pre-check; status 1 means no record exists. |
| `sb_consent_set DECISION TOOL CAPS SCOPE [SOURCE]` | `DECISION` is `granted`, `declined` or `unset`; `CAPS` a comma list; `SCOPE` is `machine` or a project directory (enforce only). Status 2 and a message on stderr for a usage error or an unwritable store. |
| `sb_consent_status_lines [PROJECT_DIR]` | One `<tool> <capability> <decision>` line per pair. |

`hooks/lib/recommended-tools.sh` builds on it: `sb_recommended_tool_consent CONFIG TOOL` prints
`pending`, `enabled` or `disabled`, and `sb_recommended_tool_enforced CONFIG TOOL` is the single
test every gate uses.

## CLI

`scripts/sb-consent.sh`:

```
sb-consent.sh path
sb-consent.sh status [--project DIR]
sb-consent.sh check TOOL CAPABILITY [--project DIR]     # exit 0 only when granted
sb-consent.sh grant|decline|revoke TOOL (--project DIR | --all-projects)
                                   [--capabilities install,wire,enforce] [--source TEXT]
```

`TOOL` is a tool id or `all`. `--project DIR` records `enforce` for that project (and
`install`/`wire` for the machine, since they are machine-wide); `--all-projects` records every
listed capability for the machine. Exit status: 0 success, 1 `check` not granted, 2 error, 64
usage error.

Example: `bash scripts/sb-consent.sh grant graphify --project "$PWD" --source "user said yes"`.

Scripts that install or wire a tool should call `sb-consent.sh check TOOL install` (or `wire`)
and print the `grant` command when it fails instead of proceeding.

## Migration

A project that already has `enabled_by_user: true` was treated as consented before. It now gets
a one-time notice per tool and project (marker under the runtime state dir) telling the user
what changed and giving the exact `grant` and `decline` commands. Until the user answers, the
tool's gates are inactive.
