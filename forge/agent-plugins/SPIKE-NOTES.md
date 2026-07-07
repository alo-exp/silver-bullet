# Phase 0 — Codex thin install spike

**Date:** 2026-07-07  
**CLI:** `codex-cli 0.142.5`  
**Outcome:** PASS (with `url` + `path` + `ref` source shape)

## What we verified

1. `codex plugin marketplace add <git-url> --sparse .agents/plugins` works for a Git-backed unified marketplace (local path works for dev; Git URL + `--sparse` for remote).
2. A Codex marketplace entry can install `silver-bullet` from `alo-exp/silver-bullet` **without** vendoring `plugins/silver-bullet/` into the marketplace repo.
3. Installed cache layout: `~/.codex/plugins/cache/<marketplace-name>/silver-bullet/<version>/` (marketplace name remains `alo-labs-codex` in production).
4. `skill-source/`, `commands/`, and `.codex-plugin/plugin.json` materialize from the Git subpath fetch. Symlinked `hooks/` may need installer-side `materialize_silver_bullet_package` (existing behavior).

## Source shape that works

`github` + `path` is **not** discovered by Codex 0.142.5. Use `url` source:

```json
{
  "name": "silver-bullet",
  "source": {
    "source": "url",
    "url": "https://github.com/alo-exp/silver-bullet.git",
    "ref": "v0.51.2",
    "path": "plugins/silver-bullet"
  },
  "version": "0.51.2"
}
```

## Approach chosen

- **Production:** thin `alo-labs/agent-plugins` repo with `.agents/plugins/marketplace.json` using `url` + `path` + `ref` (no wrapper `install.sh` required).
- **Release sync:** bump `version` and `ref` in the Codex manifest only; stop rsyncing `plugins/silver-bullet/` into the marketplace repo.
- **Installer:** register `https://github.com/alo-labs/agent-plugins`; hydrate cache from thin manifest (via `codex plugin add` when available, or direct Git fetch fallback for tests/offline).

## Not verified in spike

- Sparse checkout of the unified `agent-plugins` repo on a cold machine (documented in README; follows Codex `--sparse .agents/plugins` contract).
- End-to-end `--public-release` against the live `alo-labs/agent-plugins` GitHub repo (repo must be created manually — see Phase 7).
