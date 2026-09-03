# CONTEXT — Phase 057: First-Class Cursor Runtime Support

**Date:** 2026-06-14  
**Branch:** `phase-057-cursor-support`

## Problem

Silver Bullet enforces workflows via hooks and state under
`${SB_RUNTIME_HOME_ROOT}/.silver-bullet/`. Claude and Codex are supported;
Cursor uses a different hook protocol (camelCase events, `Shell` tool name).

## Goal

Cursor users get the same enforcement: session-start, record-skill,
completion-audit, stop-check, doc-scheme gates, diagnostics.

## Decisions

- Runtime name: `cursor`, home `~/.cursor`, state `~/.cursor/.silver-bullet`
- Hook delivery: `cursor-hooks.json` + `cursor-hook-bridge.sh`
- Install: `scripts/install-cursor.sh` + `merge-cursor-hooks.py`
