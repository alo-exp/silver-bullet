# Solution Capability Report: pi-web

## Executive summary

**PI WEB** ([jmfederico/pi-web](https://github.com/jmfederico/pi-web)) is the leading **browser-based control plane** for Pi Coding Agent. Sessions run in real server-side workspaces and stay alive after the browser disconnects, enabling laptop→phone→tablet supervision [E004][E005]. MIT-licensed; published on pi.dev as `@jmfederico/pi-web` with `pi-coding-agent` peer dependency [E006].

## Product overview

- **What it is:** TypeScript web UI + session daemon architecture (split-process).
- **Runtime model:** Browser is control surface; agent runtimes live on machine/server [E004].
- **License:** MIT [S003].
- **Homepage:** https://pi-web.dev/ [S004].

## Core capabilities

### Persistence & remote dev
- Keeps Pi sessions running in real repositories and git worktrees [E004].
- Supervise multiple sessions in parallel [E004].
- Register remote PI WEB runtimes as trusted machines; proxy projects/files/terminals [E005].

### Pi integration
- Peer dependency on `@earendil-works/pi-coding-agent` (>=0.74.0) [E006].
- Installable as Pi package exposing `/pi-web` command [S009].

### GUI features
- Project/workspace management, file browser, terminals, session browser [S003].
- Trusted browser-side plugins for workspace panels [S003].

## Integrations & ecosystem

- npm global install and Pi package registry [S009].
- Remote machine mesh for dev boxes / workstations [E005].

## Pricing & TCO signals

- Free OSS. Requires self-hosted machine or server for remote use.

## Strengths

- Best multi-device and persistent-session story [E004][E005].
- Strong fit for "agent on server, UI in browser" workflows [S004].

## Limitations

- Not a native desktop app — depends on running PI WEB server process.
- More operational complexity than single-user Electron apps.
- Separate from lighter local-only `agegr/pi-web` variant [S012].

## Best for / Avoid if

- **Best for:** Developers who want Pi sessions on a workstation/server and supervision from any browser/device.
- **Avoid if:** You want a single-user offline-native desktop without running a web stack (choose pi-gui).

## Evidence appendix

| Ref | Evidence |
|-----|----------|
| E004 | Persistent workspaces [S003] |
| E005 | Remote machines [S003] |
| E006 | Peer dependency [S009] |
