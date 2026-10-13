# Solution Capability Report: OpenClaw

## Executive summary

**OpenClaw** ([openclaw/openclaw](https://github.com/openclaw/openclaw)) is a **personal AI assistant** platform with gateway daemon, multi-channel messaging (WhatsApp, Telegram, Slack, Discord, etc.), and companion apps for macOS/iOS/Android [E011]. It shares Pi-runtime lineage in the broader agent ecosystem but optimizes for **always-on assistant** workflows rather than a dedicated Pi coding-agent IDE [E012].

## Product overview

- **What it is:** Gateway + channel connectors + node apps.
- **Runtime model:** Assistant orchestration across devices and chat surfaces [E011].
- **License:** OSS [S007].
- **Fit:** Messaging-first personal automation; secondary fit as Pi coding GUI.

## Core capabilities

### Multi-channel assistant
- Gateway daemon routes conversations across chat providers [E011].
- Companion apps for desktop/mobile nodes [E011].

### GUI surfaces
- macOS menu bar / mobile nodes provide graphical control [E011].
- Documentation emphasizes Windows Hub and nodes; not a code-centric IDE layout [E012].

## Gaps for Pi coding GUI use case

- No first-class wrap of `@earendil-works/pi-coding-agent` as primary coding loop (partial vs shortlisted Pi shells).
- Lacks integrated repo worktrees, diff review, and session browser tailored to software delivery [E012].

## Pricing & TCO signals

- Self-hosted OSS; operational cost is running gateway + channel credentials.

## Sources

[S007] openclaw/openclaw — README and docs-by-goal sections.
