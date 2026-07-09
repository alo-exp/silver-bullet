# Solution Capability Report: pi-gui

## Executive summary

**pi-gui** ([minghinmatthewlam/pi-gui](https://github.com/minghinmatthewlam/pi-gui)) is the most mature open-source **native desktop shell** for the Pi coding agent. It wraps `@earendil-works/pi-coding-agent` through a dedicated `pi-sdk-driver` package, preserves Pi session files as source of truth, and ships Codex-style threading with git worktrees, multi-agent orchestration, terminal, and diff review [E001][E002]. MIT-licensed public beta for macOS (Apple Silicon) and Linux (AppImage) [E003].

## Product overview

- **What it is:** Electron desktop app (`apps/desktop`) with marketing site (`apps/website`).
- **Runtime model:** UI shell only — agent execution stays in upstream Pi SDK; no forked agent loop [E001].
- **License:** MIT [E003].
- **Status (Jul 2026):** Active beta (`v0.1.0-beta.29` release line); ~580+ GitHub stars; 20 releases.

## Core capabilities

### Pi SDK fidelity
- Uses `packages/pi-sdk-driver` adapter over `@earendil-works/pi-coding-agent` [E001].
- Session management, model/auth setup, and agent execution delegated to upstream `pi` [E001].

### Desktop UX
- Threaded timeline of messages and collapsible tool calls [E002].
- Git worktrees per thread for parallel isolated work [E002].
- Integrated PTY terminal (`node-pty`) [E002].
- Inline diff viewer (⌘/Ctrl+D) [E002].
- `@` file mentions and image drag/drop in composer [E002].

### Orchestration
- Multi-agent orchestration: orchestrator thread can spin up child worker threads [E002].

### Platform support
- macOS Apple Silicon + Linux AppImage beta [E003].
- No official Windows build documented in README (gap vs Pi Desktop).

## Integrations & ecosystem

- Multiple model providers via OAuth/API key in Settings [E002].
- Skills & extensions management view for Pi ecosystem [E002].
- Homepage install via GitHub Releases or Homebrew cask [S002].

## Security & compliance

- Local-first desktop; credentials follow Pi's standard `~/.pi/agent/` storage (inherited from SDK).
- Beta software — expect permission re-confirmation on macOS after Homebrew upgrades [S002].

## Pricing & TCO signals

- Free OSS (MIT). User pays model API costs only.

## Strengths

- Best alignment with "dedicated Pi GUI" need: purpose-built desktop, not a generic assistant [E001][E002].
- Strong session/worktree model for parallel agent threads [E002].
- Active maintenance and community momentum (frequent beta releases) [S001].

## Limitations

- No Windows build in current beta scope [E003].
- Electron footprint vs lighter Tauri alternatives.
- Still prerelease — production hardening ongoing.

## Best for / Avoid if

- **Best for:** macOS/Linux developers wanting a Codex-style native Pi desktop with orchestration and worktrees.
- **Avoid if:** You need Windows desktop today (consider Pi Desktop) or browser-only remote supervision (consider PI WEB).

## Evidence appendix

| Ref | Evidence |
|-----|----------|
| E001 | SDK driver architecture [S001] |
| E002 | Feature list [S001] |
| E003 | Beta platforms + MIT [S001][S002] |
