# Landscape Report — Pi coding agent GUI shells (2026-07-10)

## Market snapshot

The Pi ecosystem (`@earendil-works/pi-coding-agent`, [pi.dev](https://pi.dev)) ships a terminal-first agent. Third-party **GUI shells** wrap that runtime instead of forking the agent loop. As of July 2026 we identified **14 candidates**; five OSS projects meet scope and maintenance gates for deep SCR evaluation.

## Segments

| Segment | Representative projects | Primary value |
|---------|-------------------------|---------------|
| Native desktop (Electron) | pi-gui, Pi Desktop | Daily driver GUI with threads, terminal, diffs |
| Web control plane | PI WEB | Persistent server-side sessions + remote supervision |
| IDE extension | Pi Code Gui, vscode-pi (not shortlisted) | In-editor chat + bridge tools |
| Personal assistant / nodes | OpenClaw | Multi-channel messaging and companion apps |

## Shortlist rationale

1. **pi-gui** — Most mature dedicated Pi desktop shell; SDK driver package; worktrees + orchestration.
2. **PI WEB** — Best when sessions must outlive the browser and span devices.
3. **Pi Desktop** — Richest packaged desktop feature set including Windows builds and council planning.
4. **Pi Code Gui** — Best VS Code-native experience with SDK `customTools` bridge.
5. **OpenClaw** — Included as Pi-runtime-adjacent OSS assistant; weaker fit for dedicated coding GUI.

## Evaluated but not shortlisted

- **vscode-pi** — RPC companion to global `pi` binary; lighter GUI than Pi Code Gui [S010].
- **Pi Studio (Tauri)** — Bundled runtime via PiManager; less Pi-package-native [S011].
- **agegr/pi-web** — Local-first alternate web UI; smaller community vs jmfederico/pi-web [S012].

## Recommendation direction

Default **macOS/Linux desktop**: **pi-gui**. Add **PI WEB** when remote supervision or session persistence is primary. Use **Pi Desktop** for **Windows** desktop packaging. Use **Pi Code Gui** when staying inside VS Code. Treat **OpenClaw** as assistant infrastructure, not a Pi coding GUI default.
