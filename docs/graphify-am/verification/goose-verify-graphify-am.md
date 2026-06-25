# Self-Verification: Graphify + agentmemory in Goose (Pi runtime, Global)

Machine-level audit for **Block Goose** — no Silver Bullet prerequisite. Produces a pass/fail report per check.

> Goose runs on the **Pi** coding-agent runtime. Graphify installs via `--platform pi`, and `agentmemory connect pi` is the agentmemory wiring path.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host goose --apply`
**Host detection:** `~/.config/goose/config.yaml` exists OR `~/.pi/agent/` exists ⇒ host is `goose`. Setup script skips silently otherwise.

---

## Phase 1 — Pre-flight (read-only)

### 1.1 Graphify CLI

```bash
which graphify && graphify --version 2>/dev/null | head -1
```

**Pass:** binary on PATH.

**Fail:** `uv tool install graphifyy` or `pipx install graphifyy`.

### 1.2 agentmemory CLI

```bash
# Hardened probe — survives Homebrew-managed npm installs in non-interactive subshells
# where `brew shellenv` hasn't been sourced (PATH may not include /opt/homebrew/bin).
for bin in agentmemory \
           "$(npm config get prefix 2>/dev/null)/bin/agentmemory" \
           /opt/homebrew/bin/agentmemory \
           /usr/local/bin/agentmemory \
           "$HOME/.npm-global/bin/agentmemory"; do
  [ -x "$bin" ] && { echo "$bin"; "$bin" --version 2>/dev/null | head -1; break; }
done
```

**Pass:** an absolute path is printed and the version line is non-empty.

**Fail (npm direct):** `npm install -g @agentmemory/agentmemory`.

**Fail (Homebrew → npm, macOS):** `brew install @agentmemory/agentmemory` (or `brew tap … && brew install …` if not in core). Homebrew installs via npm and symlinks the CLI to `/opt/homebrew/bin/agentmemory`; remember to add `eval "$(/opt/homebrew/bin/brew shellenv)"` to `~/.zshrc` so the binary is on PATH in interactive shells.

### 1.3 Goose CLI

```bash
which goose 2>/dev/null
```

**Pass:** binary on PATH.

**Fail:** install per upstream docs.

> **Warn (acceptable):** the Goose CLI is not required to PASS global setup. Pi runtime + config files alone are authoritative. The CLI is only needed to invoke Goose for the manual synergy test (Phase 4). The setup script writes to `~/.config/goose/config.yaml` and `~/.pi/agent/skills/` regardless.

### 1.4 Goose / Pi home exists

```bash
test -f ~/.config/goose/config.yaml && echo goose-config-ok
test -d ~/.pi/agent && echo pi-home-ok
```

**Pass:** at least one of `goose-config-ok` or `pi-home-ok` printed (Pi runtime alone is sufficient).

**Fail:** install Goose or create the home directories manually.

> **Phase 1.3 fallback when the Goose CLI is absent:** the doc accepts the missing CLI as a WARN because Pi runtime + the global config files (`~/.config/goose/config.yaml`, `~/.pi/agent/`) are authoritative. To exercise Phase 4 manually without the Goose CLI, drive `graphify update` and `graphify query` from a regular terminal inside the target repo (they read the same `graphify-out/graph.json` that Goose would consume). The CLI is only required to invoke Goose itself for the UI-based capture step.

### 1.5 gitleaks

```bash
which gitleaks && gitleaks version 2>/dev/null | head -1
```

**Pass:** binary on PATH (bridge second-line secret scan).

**Fail:** `brew install gitleaks` (macOS) — global setup attempts install on `--apply`.

---

## Phase 2 — Global config artifacts

### 2.1 Graphify skill (Pi path)

```bash
test -f ~/.pi/agent/skills/graphify/SKILL.md && grep -q graphify ~/.pi/agent/skills/graphify/SKILL.md && echo OK
```

**Pass:** `OK` — skill file exists and contains graphify content.

> Pi loads skills on demand from `~/.pi/agent/skills/`; no separate `settings.json` "always-on" hook is required. (Contrast with Claude/Codex/OpenCode, which write `CLAUDE.md` / `AGENTS.md` / `plugin` entries for always-on behavior.)

**Fail:** `graphify install --platform pi`.

### 2.2 agentmemory (Pi extension)

```bash
test -d ~/.pi/agent/extensions/agentmemory && \
  test -f ~/.pi/agent/extensions/agentmemory/index.ts && \
  test -f ~/.pi/agent/settings.json && \
  grep -q 'agentmemory' ~/.pi/agent/settings.json 2>/dev/null && echo OK
```

**Pass:** `OK` — `~/.pi/agent/extensions/agentmemory/{index,security}.ts` are installed AND `~/.pi/agent/settings.json` references the extension.

**Fail (manual install required — `agentmemory connect pi` is automated only for some agents):**

```bash
agentmemory connect pi          # prints step-by-step manual install instructions
# Then:
mkdir -p ~/.pi/agent/extensions/agentmemory
# Copy integrations/pi/index.ts and integrations/pi/security.ts from the agentmemory repo
# (https://github.com/rohitg00/agentmemory/tree/main/integrations/pi) to:
#   ~/.pi/agent/extensions/agentmemory/
# Then add to ~/.pi/agent/settings.json:
#   { "extensions": ["~/.pi/agent/extensions/agentmemory"] }
```

> **Why manual?** As of agentmemory 0.9.27, `agentmemory connect pi` reports: *"pi uses a TypeScript extension file. Automated copy + register isn't implemented yet — manual install required."*

### 2.3 synergy_max `.env`

```bash
test -f ~/.agentmemory/.env && grep -q '^AGENTMEMORY_INJECT_CONTEXT=true' ~/.agentmemory/.env && grep -q '^AGENTMEMORY_EXPORT_ROOT=' ~/.agentmemory/.env && echo OK
```

**Pass:** `OK` printed; `AGENTMEMORY_EXPORT_ROOT` value is absolute.

**Fail:** `bash scripts/graphify-am-global-setup.sh --host goose --apply`.

> **About duplicate keys in `~/.agentmemory/.env`:** the file commonly contains up to **three** copies of the same keys (`AGENTMEMORY_INJECT_CONTEXT`, `AGENTMEMORY_EXPORT_ROOT`, etc.):
> 1. The **base template** at the top of the file (originally written by `agentmemory init` or by hand).
> 2. The **SB synergy_max managed block** (`# === SB synergy_max managed block === … # === end SB synergy_max managed block ===`), written by `scripts/sb-optimize-stack.sh` and stripped/replaced idempotently on re-runs.
> 3. The **graphify-am synergy_max managed block** (`# === graphify-am synergy_max managed block === … # === end graphify-am synergy_max managed block ===`), written by `scripts/graphify-am-global-setup.sh` and likewise idempotent.
>
> This is **expected and harmless**: shells and Node `dotenv` parsers use **last-write-wins** for duplicate keys, and all three sources agree on the values. The check above only needs the keys to be present at all. Run `awk -F= '/^[A-Z][A-Z_0-9]+=/ {c[$1]++} END {for (k in c) if (c[k]>1) print k"="c[k]"x"}' ~/.agentmemory/.env` to confirm the duplicate count.

---

## Phase 3 — Server and persistence

### 3.1 Health

```bash
curl -sf http://localhost:3111/agentmemory/health | python3 -c "import sys,json; print(json.load(sys.stdin)['status'])"
```

**Pass:** `healthy`.

**Fail:** `nohup agentmemory > ~/.agentmemory/server.log 2>&1 &` or re-run global setup.

### 3.2 launchd (macOS)

```bash
launchctl list 2>/dev/null | grep com.agentmemory.server
```

**Pass:** server PID listed. To enable auto-start at login:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.agentmemory.server.plist
```

**Warn if missing:** the plist exists at `~/Library/LaunchAgents/com.agentmemory.server.plist` but is not loaded. Bootstrap it manually.

### 3.3 Git hooks (global template)

```bash
git rev-parse --is-inside-work-tree >/dev/null 2>&1 && graphify hook status
```

**Pass:** `post-commit` and `post-checkout` installed (run inside any repo).

**Fail:** `graphify hook install`.

### 3.4 Bridge (project-bound)

```bash
# 3.4a — process running?
launchctl list 2>/dev/null | grep com.agentmemory.bridge
# 3.4b — AGENTMEMORY_REPO_ROOT actually set in the plist and points at an existing repo?
plutil -extract EnvironmentVariables.AGENTMEMORY_REPO_ROOT raw ~/Library/LaunchAgents/com.agentmemory.bridge.plist 2>/dev/null && \
  test -d "$(plutil -extract EnvironmentVariables.AGENTMEMORY_REPO_ROOT raw ~/Library/LaunchAgents/com.agentmemory.bridge.plist)/.git" && \
  echo bridge-repo-ok
```

**Pass:** both `3.4a` shows a PID AND `3.4b` prints `bridge-repo-ok`. The bridge auto-commits `.agentmemory/memory/` snapshots to the repo at `AGENTMEMORY_REPO_ROOT`.

**Warn if missing (3.4a):** bridge only applies when `--repo <path>` was passed to global setup. To enable later:

```bash
bash scripts/graphify-am-global-setup.sh --host goose --apply --repo /path/to/project
```

**Warn if missing (3.4b):** the plist exists and is loaded, but `AGENTMEMORY_REPO_ROOT` is unset, points outside the repo, or the repo has no `.git` directory. Re-bootstrap:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.agentmemory.bridge.plist 2>/dev/null
bash scripts/graphify-am-global-setup.sh --host goose --apply --repo /path/to/project
```

---

## Phase 4 — Manual synergy test (Goose UI)

### 4.0 Pre-flight: `.gitignore` whitelist

```bash
# Repo .gitignore must whitelist these (otherwise the bridge's auto-commits are ignored):
cd <repo> && grep -E '^\!\.agentmemory/(memory|snapshots|profile\.md)' .gitignore
```

**Pass:** all three lines present (`!.agentmemory/memory/`, `!.agentmemory/snapshots/`, `!.agentmemory/profile.md`). Silver Bullet-managed repos satisfy this via the `agentmemory managed block` in `.gitignore`.

### 4.1–4.5 Manual flow

1. Open a git repo with code. (The repo's `.gitignore` must whitelist `.agentmemory/memory/`, `.agentmemory/snapshots/`, and `.agentmemory/profile.md` — see 4.0.)
2. In Goose, invoke the graphify skill (`/graphify`) and use the agentmemory extension to capture a short note (e.g. "we use jq for all JSON in this repo").
3. Wait for the bridge, OR trigger a manual export. **The `vaultDir` must resolve to (or under) the path stored in `AGENTMEMORY_EXPORT_ROOT`** — which by default is the repo's `.agentmemory/`:

   ```bash
   curl -sf -X POST http://localhost:3111/agentmemory/obsidian/export \
     -H 'Content-Type: application/json' \
     -d '{"vaultDir":"'"$(grep '^AGENTMEMORY_EXPORT_ROOT=' ~/.agentmemory/.env | tail -1 | cut -d= -f2)"'/memory"}'
   ```

   > **API constraint (verified against agentmemory 0.9.27):** `obsidian/export` rejects `vaultDir` values that do not resolve to (or under) the configured `AGENTMEMORY_EXPORT_ROOT`. The error response is `"vaultDir must be inside <AGENTMEMORY_EXPORT_ROOT>"`. So the example above sources `AGENTMEMORY_EXPORT_ROOT` from `.env` (`tail -1` to handle the duplicate-key case noted in 2.3) and targets `${EXPORT_ROOT}/memory`. To get memories into the repo's `.agentmemory/memory/` (the whitelisted git path) without a manual export, rely on the `com.agentmemory.bridge` auto-snapshot — see Phase 3.4 for its `AGENTMEMORY_REPO_ROOT`.
4. From repo root: `graphify update . --no-cluster`
5. `graphify query "agentmemory vault" --budget 1500` — expect `.agentmemory/memory/MOC.md` nodes.

**Pass:** query returns memory-related nodes (e.g. `agentmemory vault`, `MOC.md`, `Sessions`, `Memories`).

> If the Goose CLI is not installed (Phase 1.3 warning), invoke `graphify update` and `graphify query` from a regular terminal — they read the same `graphify-out/graph.json`.

---

## Appendix — If Silver Bullet is active in a repo

- SB maps host id `goose` → graphify platform `pi`. Project-level `.pi/agent/` artifacts may also exist; global `~/.pi/agent/skills/graphify/` takes precedence for new sessions.
- `SILVER_BULLET_RUNTIME=goose bash scripts/sb-optimize-stack.sh --apply --host goose` adds project-level optimization (gitignore block, index refresh, consent timestamps) when opted in.
- Hooks (`graphify-gate`, `agentmemory-gate`) apply only when `recommended_tools.*.enabled_by_user: true`.
- Global setup remains authoritative for `~/.agentmemory/.env` and `~/.config/goose/config.yaml`.

## Notes

- Goose uses the **Pi** runtime upstream, so Graphify installs via `--platform pi` and writes the skill to `~/.pi/agent/skills/graphify/`. There is no separate "always-on" hook layer beyond the skill itself (Pi loads skills on demand).
- The agentmemory extension is a **TypeScript module** at `~/.pi/agent/extensions/agentmemory/`, registered via `~/.pi/agent/settings.json`. Pi uses agentmemory's **native REST hooks** at `:3111` — no MCP required.
- The verification doc mirrors the Claude/Codex/OpenCode verification docs 1:1 except for the skill-loading mechanism (Pi loads skills, others use rules/plugins) and the manual-install requirement for the agentmemory TypeScript extension.
- See `docs/graphify-am/PLATFORM-MATRIX.md` for the canonical install command set and artifact paths.