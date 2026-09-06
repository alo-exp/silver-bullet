# Generic Five-Tool Runtime

The five-tool runtime is an optional, host-neutral layer for Graphify,
agentmemory, Context Mode, LeanCTX, and RTK. It can be installed, inspected,
validated, and repaired without Silver Bullet, its hooks, or a trusted plugin.
Silver Bullet adds a separate adapter for project enforcement when it is
installed in a host.

## Standalone commands

From a checkout or a copied runtime package:

```bash
python3 scripts/lib/five_tool_runtime/cli.py install
python3 scripts/lib/five_tool_runtime/cli.py inspect
python3 scripts/lib/five_tool_runtime/cli.py validate
python3 scripts/lib/five_tool_runtime/cli.py repair
```

Use `FIVE_TOOL_STACK_HOME` for an explicit test or operator root. The manifest
is written atomically as `manifest.json` and contains one selected executable
per tool, launch arguments, merged environment, transport, selected version,
capabilities, five host projections, and coordination rules.

The default roots are:

- Unix-like systems: `$XDG_STATE_HOME/five-tool-stack`, then
  `$XDG_DATA_HOME/five-tool-stack`, then `~/.local/state/five-tool-stack`.
- Windows: `%LOCALAPPDATA%/five-tool-stack`, falling back to
  `%APPDATA%/five-tool-stack`.

The generic runtime accepts `.exe`, `.cmd`, `.bat`, and PowerShell launcher
names and treats JSON as UTF-8 with platform-independent newlines. Windows
fixtures are covered on non-Windows runners; a live Windows run is still
recommended for launcher-specific behavior.

## Coordination contract

All five hosts consume one manifest-selected instance per tool. RTK is the
single shell-output rewrite owner. Context Mode and LeanCTX may both be
available, but their overlapping routes are mutually excluded by the host
projection: OpenCode uses its native Context Mode plugin when available,
whereas Claude, Codex, and Cursor use the shared MCP projection. Pi keeps its
native additive extension and does not enable a second RTK shell owner.

## Silver Bullet adapter and migration

Silver Bullet's installers and Doctor use the same generic repair primitives,
then apply SB hooks and enforcement only when SB is installed for that host.
The old `~/.silver-bullet/five-tool-stack/instances.json` file is accepted only
as an explicit compatibility source; it is never discovered or written by the
generic package. Existing SB adapter tests may set `SB_GLOBAL_TOOLSTACK_HOME`
to preserve that legacy path while migrating. New installations should use the
generic root and `manifest.json`.

Doctor reports generic manifest readiness separately from SB hook readiness.
An absent generic manifest is a warning when the optional stack is not
installed; malformed or partial generic state is repairable with
`sb-doctor.sh --fix=host` or `--fix=all`.
