# Solution Capability Report: pi-desktop

## Executive summary

**Pi Desktop** ([FaqFirebase/pi-desktop](https://github.com/FaqFirebase/pi-desktop)) is a feature-rich **Electron GUI** for the Pi coding agent with chat, integrated terminal, file tree, CodeMirror editor, diff viewer, and **Windows/macOS/Linux** release builds [E007]. Apache 2.0 licensed. Optional **Multi-Agent Council Planning** brings Pi, Claude, and Codex into a read-only planning council before Pi executes [E008].

## Product overview

- **What it is:** All-in-one desktop IDE-like shell for Pi.
- **License:** Apache-2.0 [S005].
- **Homepage:** https://pi-desktop.dev/ (linked from README).

## Core capabilities

### Pi agent UX
- Streaming chat with thinking blocks and tool use [E007].
- Command palette for skills, prompt templates, built-in commands [E007].
- Session fork/branch tree, context compaction, model switching [E007].
- Package browser connected to pi.dev/packages [E007].

### Desktop IDE features
- Multiple workspaces, each with own Pi process [E007].
- Review rail with permissions, approvals, changed files [E007].
- File tree + CodeMirror 6 editor + diff viewer + file search [E007].
- Terminal with ANSI colors [E007].

### Multi-agent (optional)
- Council planning with Pi + Claude + Codex; off by default; increases token cost [E008].

### Platform
- Release installers for Linux, macOS, and Windows (unsigned Windows builds documented) [E007].

## Strengths

- Broadest **cross-platform desktop** coverage in shortlist [E007].
- Richest built-in IDE affordances (editor, packages browser, themes) [E007].
- Unique council planning mode for high-stakes tasks [E008].

## Limitations

- Heavier Electron app; smaller community than pi-gui by stars/velocity [S001 vs S005].
- Council mode adds cost/complexity; not pure Pi-only orchestration [E008].
- Windows builds community-tested/unsigned — SmartScreen friction [E007].

## Best for / Avoid if

- **Best for:** Users needing Windows desktop or IDE-like Pi GUI with terminal + editor in one window.
- **Avoid if:** You want the most Pi-native/Codex-style threading model (pi-gui) or minimal footprint.

## Evidence appendix

| Ref | Evidence |
|-----|----------|
| E007 | Feature list + Windows [S005] |
| E008 | Council planning [S005] |
