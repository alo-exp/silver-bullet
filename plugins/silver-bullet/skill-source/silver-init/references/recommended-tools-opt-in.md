# Recommended tools opt-in (silver:init Phase 1.1)

Host-specific install matrices live in `scripts/lib/host-install-guides/<runtime>.md`.
Load this reference when executing Phase 1.1a–§1.1f during `/silver:init` or update-mode retry.

### 1.1a Graphify (recommended tool — opt-in)

Graphify powers SB's retrieval-oriented project memory. SB **asks for explicit permission**
before enabling mandatory enforcement. Consent is stored in `.silver-bullet.json` under
`recommended_tools.graphify.enabled_by_user` (`null` = pending, `true` = opted in, `false` = opted out).

**Benefits (present concisely when asking):**
- Scoped retrieval saves tokens vs broad file reads
- Team-shared knowledge graph indexes code + docs in the repo
- Portable across all supported hosts agents

**Fresh init default:** always start with `enabled_by_user: null` (pending). Do not pre-opt-in
or pre-opt-out from org defaults or template overrides — the user must explicitly choose each
fresh init.

**Update mode re-prompt:** when `.silver-bullet.json` already exists (update mode) or after
`/silver:update`, if `enabled_by_user` is still `null`, run the same consent prompt as fresh init.

#### Step 1 — Read existing consent

If `.silver-bullet.json` exists, read consent and suspension state:
```bash
jq -r '.recommended_tools.graphify.enabled_by_user // "null"' .silver-bullet.json 2>/dev/null || echo null
jq -r '.recommended_tools.graphify.enforcement_suspended // false' .silver-bullet.json 2>/dev/null || echo false
```

Store as `graphify_consent` and `graphify_suspended` for this init run. Fresh setup defaults to `null` / `false`.

#### Step 2 — Ask when consent is pending

If `graphify_consent` is `null`, use ask the user directly (do **not** auto-install) — applies to
**both fresh init and update mode**:

- Question: "Silver Bullet recommends **Graphify** for project-memory retrieval.\n\nBenefits: scoped queries save tokens; team-shared knowledge graph; works across agents.\n\nEnable Graphify for this project? Hooks will require `graphify query` before substantive edits when enabled."
- Options:
  - "A. Yes — enable Graphify (install + mandatory enforcement)"
  - "B. No — skip Graphify (advisory/docs fallback only)"

If **A**: set `graphify_consent=true`. If **B**: set `graphify_consent=false`.

Record the choice — it will be written to `.silver-bullet.json` in Phase 3.4 (fresh) or preserved in update mode:
```json
"recommended_tools": {
  "graphify": {
    "enabled_by_user": true,
    "enforcement_suspended": false,
    "install_status": null,
    "install_failure_reason": null
  }
}
```
(or `false` when opted out). Preserve other `recommended_tools.graphify` fields from the template.

#### Step 3 — Install and index (when opted in or retrying suspended install)

Run when `graphify_consent` is `true` AND either:
- this is a fresh opt-in (user just chose Yes), OR
- `graphify_suspended` is `true` (update mode / post-`/silver:update` retry)

**Detect host** (same logic as `hooks/lib/runtime-paths.sh`):
```bash
if [[ -n "${SILVER_BULLET_RUNTIME:-}" ]]; then
  SB_HOST="$SILVER_BULLET_RUNTIME"
elif [[ -n "${SILVER_BULLET_RUNTIME:-}" ]]; then
  SB_HOST="${SILVER_BULLET_RUNTIME}"
else
  # shellcheck source=hooks/lib/runtime-paths.sh
  source "${PLUGIN_ROOT}/hooks/lib/runtime-paths.sh"
  SB_HOST="${SILVER_BULLET_RUNTIME}"
fi
echo "$SB_HOST"
```

**Step 3a — CLI package** (upstream recommends `uv tool install`; `pipx` is the pip alternative):
```bash
command -v graphify
```

If missing, attempt install (user already consented):
```
uv tool install graphifyy
```
or:
```
pipx install graphifyy
```

Re-check `command -v graphify`.

**Step 3b — Skill registration:** Read `recommended_tools.graphify.platform_install_commands.<SB_HOST>.pre_index` from `.silver-bullet.json`. Per-runtime matrices: `scripts/lib/host-install-guides/<SB_HOST>.md`.

Read `recommended_tools.graphify.platform_install_commands.<host>.pre_index` from `.silver-bullet.json` when present.

**Step 3c — Build index** (when CLI is present):
```bash
graphify update . --no-cluster
```

**Step 3d — Platform always-on** (after index; per upstream [Make your assistant always use the graph](https://github.com/safishamsi/graphify#make-your-assistant-always-use-the-graph)):


Read `platform_install_commands.<host>.post_index` from config when present.

**Step 3e — Optional git hooks** (advisory; upstream recommends for auto-rebuild):
```bash
graphify hook install
```

Confirm `graphify-out/graph.json` exists (or path in config).

**On full success** (CLI present + index exists), clear suspension in config:
```bash
jq '.recommended_tools.graphify.enforcement_suspended = false
  | .recommended_tools.graphify.install_status = "ok"
  | .recommended_tools.graphify.install_failure_reason = null' .silver-bullet.json
```

**On install or index failure** — do **not** block init; suspend enforcement but preserve consent:
```bash
jq --arg reason "<brief failure reason>" '
  .recommended_tools.graphify.enforcement_suspended = true
  | .recommended_tools.graphify.install_status = "failed"
  | .recommended_tools.graphify.install_failure_reason = $reason
' .silver-bullet.json
```

Output: "Graphify opted in but install failed — enforcement suspended until upgrade; retry on /silver:update."

Hooks treat suspended Graphify like opted-out (no graphify-gate blocks) while remembering `enabled_by_user: true`.

#### Step 4 — Opted out

If `graphify_consent` is `false`: set `enforcement_suspended: false`, `install_status: null`. Output "Graphify opted out — enforcements disabled for this project." Continue init.

#### Step 5 — Already consented projects

If consent is already `true` or `false` in an existing config, respect it without re-asking **unless**:
- consent is `null` — always re-prompt (Step 2; fresh init and update mode)
- consent is `true` AND `enforcement_suspended` is `true` — retry install (Step 3) without re-asking

When `true`, not suspended, and CLI missing: surface install instructions (Step 3).

### 1.1b agentmemory (recommended tool — opt-in)

agentmemory powers SB session capture and git-backed memory export. It pairs with Graphify:
**save via agentmemory, retrieve via Graphify**. SB asks for explicit permission before
enabling mandatory enforcement. Consent is stored in `.silver-bullet.json` under
`recommended_tools.agentmemory.enabled_by_user` (`null` = pending, `true` = opted in, `false` = opted out).

**Benefits (present concisely when asking):**
- Session capture with proactive context injection
- Git-backed memory export to `.agentmemory/` for team sharing
- Synergy with Graphify: temporal capture + structural retrieval

#### Step 1 — Read current consent

```bash
jq -r '.recommended_tools.agentmemory.enabled_by_user // "null"' .silver-bullet.json 2>/dev/null || echo null
jq -r '.recommended_tools.agentmemory.enforcement_suspended // false' .silver-bullet.json 2>/dev/null || echo false
```

Store as `agentmemory_consent` and `agentmemory_suspended`.

#### Step 2 — Ask when consent is pending

If `agentmemory_consent` is `null`, ask the user (do **not** auto-install):

- Question: "Silver Bullet recommends **agentmemory** for session capture and git-backed memory.\n\nBenefits: proactive context injection; `.agentmemory/` export for team sharing; pairs with Graphify for retrieval.\n\nEnable agentmemory for this project? Hooks will require CLI, server, and MCP wiring when enabled."
- Options:
  - "A. Yes — enable agentmemory (install + mandatory enforcement)"
  - "B. No — skip agentmemory"

If **A**: set `agentmemory_consent=true`. If **B**: set `agentmemory_consent=false`.

#### Step 3 — Install and wire (when opted in or retrying suspended install)

Run when `agentmemory_consent` is `true` AND (fresh opt-in OR `agentmemory_suspended` is `true`).

**Step 3a — CLI:**
```bash
npm install -g @agentmemory/agentmemory
command -v agentmemory
```

**Step 3b — Server config and start:**
```bash
mkdir -p ~/.agentmemory
# Write cost-minimized ~/.agentmemory/.env per docs/AGENTMEMORY.md
nohup agentmemory > ~/.agentmemory/server.log 2>&1 &
curl -sf http://localhost:3111/agentmemory/health
```

**Step 3c — Project export root:**
```bash
mkdir -p .agentmemory/memory .agentmemory/snapshots
```

Add agentmemory gitignore block if missing (see `docs/AGENTMEMORY.md`).

**Step 3d — Platform MCP wiring** (detect `SB_HOST` same as Graphify):

| Host | Pre-index | Post-index |
|------|-----------|------------|
| `<SB_HOST>` | *(none)* | `agentmemory connect (see install guide)` |
| `<SB_HOST>` | `host plugin marketplace (see install guide) add rohitg00/agentmemory`; `host plugin add agentmemory@agentmemory` | `agentmemory connect (see install guide) --with-hooks` |
| `<SB_HOST>` | *(none)* | Merge MCP block per `docs/AGENTMEMORY.md` (host MCP config) |

Read `recommended_tools.agentmemory.platform_install_commands.<host>` from config when present.

**Step 3e — gitleaks (required with bridge):**
```bash
command -v gitleaks || brew install gitleaks   # macOS
command -v gitleaks && gitleaks version
```
The bridge uses regex first, then gitleaks as a second-line scan (JWTs and other patterns regex skips). SB optimizer installs gitleaks and sets `GITLEAKS_PATH` in the bridge launchd plist when `synergy_max` runs.

**On full success**, clear suspension:
```bash
jq '.recommended_tools.agentmemory.enforcement_suspended = false
  | .recommended_tools.agentmemory.install_status = "ok"
  | .recommended_tools.agentmemory.install_failure_reason = null' .silver-bullet.json
```

**On failure** — suspend enforcement, preserve consent (same pattern as Graphify Step 3).

#### Step 4 — Opted out

If `agentmemory_consent` is `false`: output "agentmemory opted out — enforcements disabled." Continue init.

#### Step 5 — Already consented

Same rules as Graphify §1.1a Step 5: re-prompt when `null`; retry when suspended; surface install when `true` and CLI missing.

#### Step 3f — Optimize Graphify + agentmemory stack

When **either** Graphify or agentmemory is opted in (`enabled_by_user: true`), run the synergy optimizer after install steps complete:

```bash
bash scripts/sb-optimize-stack.sh --apply
bash scripts/sb-optimize-stack.sh --verify
```

- Default profile: `synergy_max` (see `optimization_profiles` in config template)
- On success: records `optimization.last_applied_at` and `optimization.score` in `.silver-bullet.json`
- On partial failure: do **not** block init — surface score and warnings; user can retry via `/silver:update`
- See `docs/STACK-OPTIMIZATION.md` and `docs/research/graphify-agentmemory-optimization.md`

### 1.1e RTK (recommended tool — opt-in)

RTK (`rtk-ai/rtk`) compresses shell output via upstream PreToolUse hooks. Separate consent from Context Mode. Config key: `recommended_tools.rtk.enabled_by_user`.

**Benefits:** 60–99% shell output savings on ~75 commands once wired; automatic after `rtk init`.

**Wrong-binary warning:** `reachingforthejack/rtk` (Rust Type Kit) shares the `rtk` name — verify `rtk gain --help` after install.

#### Step 1 — Read consent

```bash
jq -r '.recommended_tools.rtk.enabled_by_user // "null"' .silver-bullet.json 2>/dev/null || echo null
jq -r '.recommended_tools.rtk.enforcement_suspended // false' .silver-bullet.json 2>/dev/null || echo false
```

#### Step 2 — Ask when `null`

Question: "Silver Bullet recommends **RTK** for shell output compression.\n\nBenefits: automatic PreToolUse rewrite for git, npm, cargo, kubectl, etc.\n\n**Note:** Codex uses AGENTS.md awareness only (no live Bash rewrite yet).\n\nEnable RTK for this project?"

- **Yes** → `enabled_by_user: true`
- **No** → `enabled_by_user: false`

#### Step 3 — Install when opted in or retrying suspended

**OS gate:** On native Windows, set `enforcement_suspended: true`, `install_failure_reason: "Windows requires WSL"`, skip install.

1. Run `install_commands` from config (Homebrew or curl installer — see `docs/RTK.md`)
2. Verify: `rtk --version` (v0.4x), `rtk gain --help`
3. Run host `platform_install_commands` (`rtk init -g`, `rtk init -g (see install guide)`, or `rtk init -g (see install guide)`)
4. **Run optimization:** `bash scripts/optimize-rtk-context-mode.sh --host <runtime>|auto` — merges hooks, MCP, host CLI config allow-list, and global rules (see `docs/RTK.md` optimization checklist)
5. Verify host hook artifact (grep `rtk` in settings/hooks/AGENTS.md)
6. Run `bash scripts/enable-rtk-context-mode.sh --tool rtk`

On success: `install_status: "ok"`, `enforcement_suspended: false`. On failure: suspend, preserve consent.

#### Step 4 — Opted out / already consented

Same pattern as Graphify §1.1a Steps 4–5.

### 1.1f Context Mode (recommended tool — opt-in)

Context Mode compacts MCP results and recovers session state across host-supported context compaction. Separate consent from RTK. Config key: `recommended_tools.context_mode.enabled_by_user`.

**License disclosure (required at consent):** ELv2 — not OSI-open; commercial bundling requires upstream license (`license_note` in config).

**MCP note:** Highest value when several MCP servers are loaded (Playwright, GitHub MCP, etc.).

#### Step 1 — Read consent

```bash
jq -r '.recommended_tools.context_mode.enabled_by_user // "null"' .silver-bullet.json 2>/dev/null || echo null
jq -r '.recommended_tools.context_mode.enforcement_suspended // false' .silver-bullet.json 2>/dev/null || echo false
```

#### Step 2 — Ask when `null`

Include ELv2 license disclosure and MCP-value note in the question.

#### Step 3 — Install when opted in or retrying suspended

**OS gate:** Native Windows → suspend with `Windows requires WSL`.

1. **Node >= 22.5** check first
2. `npm install -g context-mode` (or host plugin path per host — see `docs/CONTEXT-MODE.md`)
3. Host-specific plugin/MCP/hook steps from `platform_install_commands`
4. **Run optimization:** `bash scripts/optimize-rtk-context-mode.sh --host <runtime>|auto` — full hook set (`sessionStart`, `afterAgentResponse`), MCP merge, task host allow-list, global host rules directory directory (see `docs/CONTEXT-MODE.md`)
5. **Scaffold instruction fragment** into `silver-bullet.md` and `project instruction file` from `templates/context-mode-hint.md.base` (idempotent sentinel block — see `references/scaffold-steps.md`)
6. **Host-specific:** copy `context-mode.mdc` to `host rules path (see install guide) ` per upstream (also done by optimize script)
7. Remind user to **restart agent** after plugin install
8. Run `bash scripts/enable-rtk-context-mode.sh --tool context_mode`

On success/failure: same jq pattern as Graphify/agentmemory.

#### Step 4 — Opted out / already consented

Same pattern as Graphify §1.1a Steps 4–5.

