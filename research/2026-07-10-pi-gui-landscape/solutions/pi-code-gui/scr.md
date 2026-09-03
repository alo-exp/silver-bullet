# Solution Capability Report: Pi Code Gui

## Executive summary

**Pi Code Gui** ([NimbleTronAI/pi-code-gui](https://github.com/NimbleTronAI/pi-code-gui)) is the leading **VS Code extension** that loads `@earendil-works/pi-coding-agent` at runtime and exposes editor-native bridge tools as Pi SDK `customTools` [E009]. It streams chat, thinking blocks, and tool execution inside a webview panel rather than a standalone desktop window [E010].

## Product overview

- **What it is:** VS Code extension with webview UI + SDK integration layer.
- **Runtime model:** Uses official Pi coding-agent SDK in-process; registers VS Code APIs as custom tools [E009].
- **License:** OSS (see repository) [S006].
- **Fit:** Developers who want Pi inside the editor they already use.

## Core capabilities

### Pi SDK fidelity
- Loads `@earendil-works/pi-coding-agent` SDK at runtime [E009].
- Bridge tools map editor capabilities into Pi tool surface [E009].

### IDE UX
- Streaming assistant panel with thinking + tool call visualization [E010].
- Stays inside VS Code workbench (no separate Electron shell).

## Gaps vs desktop shells

- No standalone multi-session desktop workspace or git worktree manager comparable to pi-gui [E002].
- Terminal/diff experience depends on VS Code native views (partial vs integrated Pi desktop flows).

## Pricing & TCO signals

- Free OSS extension; requires VS Code + Pi SDK dependencies.

## Sources

[S006] NimbleTronAI/pi-code-gui — architecture and features.
