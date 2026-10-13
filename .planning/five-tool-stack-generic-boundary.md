# Five-Tool Stack Generic Boundary

Status: implementation contract for the no-Silver-Bullet runtime layer.

## Package boundary

The generic runtime lives under `scripts/lib/five_tool_runtime/` and is
intentionally free of Silver Bullet imports, environment variables, paths,
hooks, skills, and trust state. It can be copied or packaged independently.
Silver Bullet consumes it as an adapter; it does not become a runtime
dependency of the generic package.

The package owns:

- platform-neutral global-root resolution;
- the versioned global manifest and its validation/repair primitives;
- explicit legacy-manifest migration supplied by the caller;
- executable identity, launch arguments, environment, transport, selected
  version, and capability metadata;
- the five host projection capabilities and duplicate/mutual-exclusion rules.

The package does not own SB hooks, plugin registration, project state, or
host-specific policy. Those remain in the SB adapter and are applied only when
SB is installed for that host.

## Global locations

`FIVE_TOOL_STACK_HOME` is the test/operator override. Without it:

- Windows uses `%LOCALAPPDATA%/five-tool-stack` and falls back to
  `%APPDATA%/five-tool-stack`;
- Unix-like systems use `$XDG_STATE_HOME/five-tool-stack`, then
  `$XDG_DATA_HOME/five-tool-stack`, then `~/.local/state/five-tool-stack`.

The canonical manifest is `manifest.json`. The SB adapter may pass the
pre-existing `~/.silver-bullet/five-tool-stack/instances.json` as a legacy
source for one-way migration; the generic package never discovers that path
itself and never writes it.

## Manifest schema

The current schema identifier is `five-tool-stack/v1`. Each tool entry contains
`identity`, `command`, `args`, `env`, `transport`, `version`, and `capabilities`.
The manifest also records the five supported host projections and generic
coordination rules: one global instance per tool, one RTK rewrite, and native
Context Mode versus MCP mutual exclusion.

## Migration and repair

`install`/`repair` loads the canonical manifest when valid, otherwise imports a
caller-supplied legacy manifest, normalizes all five tool entries, and writes
atomically. Validation reports missing, malformed, duplicated, or stale
entries without deleting unrelated host configuration. Host adapters then
repair only their own projection.

## Windows contract

All paths are `pathlib.Path` values; command resolution accepts `.exe`, `.cmd`,
and PowerShell launcher names through the platform resolver. JSON is UTF-8 and
written with platform-independent newlines. Tests use deterministic Windows
path/environment fixtures and do not require a live Windows host.
