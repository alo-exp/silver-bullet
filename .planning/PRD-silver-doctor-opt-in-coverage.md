# PRD: Silver Bullet doctor coverage for every opt-in recommended tool

**Status:** ready for Session A implementation  
**Owner / session intent:** Session A implementer (paste-ready). Close D10 completeness for every key already in `.silver-bullet.json` `recommended_tools`, plus freeze Omni four-surface as a **separate** WS7 component. Do **not** build an unbounded “fix any arbitrary tool” installer.  
**Product name freeze:** implement [`/silver:doctor`](../skills/silver-doctor/SKILL.md). [`/sb:doctor`](router_subagent_surfaces_85bf9f09.plan.md) is the freeze **public alias of the same doctor**. One doctor. Do not fork a second command, skill, or runner.  
**Sources combined into this PRD:**

1. Original parent brief: *proper `/silver:doctor` (freeze `/sb:doctor`) coverage for every Silver Bullet opt-in recommended tool, not only Omni.*
2. Adversarial review `759a2827` (`ROLE: adversarial-doctor-prompt`, `VERDICT` insufficient for arbitrary-tool autonomy) — `MUST_ADD` / `SHOULD_ADD` / `MUST_NOT` / `SCOPE_FORK`.
3. Live D10 table in [`skills/silver-doctor/SKILL.md`](../skills/silver-doctor/SKILL.md) (Check catalog D1–D22 + D10-*; default coverage rows Graphify / agentmemory / RTK / Context Mode / LeanCTX / Alumnium / `five_tool_routed`).
4. Freeze Omni doctor headings (read-only, do not edit the freeze file): YAML todo `omni-agent-doctor`; public alias `/sb:doctor`; `/sb:doctor --fix` repair table; WS7 ownership in [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](router_subagent_surfaces_85bf9f09.plan.md). Cite **headings**, not freeze line numbers (they drift).

**This PRD is Session A only.** Session B (“autonomous agent that can fix any arbitrary tool setup”) is a different product. It is recorded under Non-goals and Out of scope so an implementer cannot silently expand.

---

## Problem / why now

`/silver:doctor` is the install-and-activation audit users run when Silver Bullet enforcement is drifting. The skill already maps D10 onto the five-tool stack plus Alumnium-when-opted-in. The product config, however, already lists **seven** `recommended_tools` keys, and the freeze already absorbs Omni `/sb:doctor` four-surface work as WS7. Those three layers are not the same list:

| Layer | What it contains today | Gap |
|---|---|---|
| Config | [`.silver-bullet.json`](../.silver-bullet.json) keys `graphify`, `agentmemory`, `alumnium`, **`search_cli`**, `rtk`, `context_mode`, `leanctx` | `search_cli` is a first-class opt-in with `install_commands` / `provider_classes` and a user-facing doc ([`docs/SEARCH-CLI.md`](../docs/SEARCH-CLI.md)) |
| Live D10 allowlist | `RT_COMPONENT_IDS=(graphify agentmemory rtk context_mode leanctx alumnium cross_tool)` in [`scripts/lib/recommended-tools/common.sh`](../scripts/lib/recommended-tools/common.sh) | No `search_cli`. No Omni. Registry [`hooks/lib/recommended-tools-registry.sh`](../hooks/lib/recommended-tools-registry.sh) and SKILL D10 table omit `search_cli`. No `probe-search_cli.sh` yet (planned under [`scripts/lib/recommended-tools/`](../scripts/lib/recommended-tools/); do not link it as if it exists) |
| Freeze Omni (planned) | YAML `omni-agent-doctor`; public `/sb:doctor` = setup + health + diagnosis + troubleshooting/`--fix` for daemon/providers + **current doctor host CLI** (freeze catalogs five CLIs; Session A audits the current host only) | **Planned only.** There is no `recommended_tools.omniroute` key, no `probe-omniroute.sh`, no `scripts/install-omniroute-sb.sh` in this tree. Omni is **not** a D10 Graphify/RTK probe |

The original brief asked for four surfaces (Setup, Health, Diagnosis, Troubleshooting/`--fix`) on every opt-in tool, consulting latest official upstream docs, using the existing Alumnium extra-tool pattern rather than inventing a parallel doctor.

The adversarial review then showed why that brief is unsafe if read as “fix any tool”:

- Live doctor is an **allowlisted, consent-gated reconciler** ([`scripts/sb-doctor.sh`](../scripts/sb-doctor.sh) + [`scripts/reconcile-recommended-tools.sh`](../scripts/reconcile-recommended-tools.sh)), not a generic installer.
- `--fix` currently **swallows** reconciler stderr (`2>/dev/null || true`) and sets `DOCTOR_FIX_APPLIED=1` even when apply JSON is empty.
- [`tests/scripts/test-silver-doctor.sh`](../tests/scripts/test-silver-doctor.sh) proves Alumnium **N/A vs FAIL** on live probes, but does **not** run `sb-doctor.sh --fix` (it only asserts the skill documents the flag, and that unsupported hosts must not recommend `--fix=host`).
- Stale [`scripts/lib/sb-doctor/checks.sh`](../scripts/lib/sb-doctor/checks.sh) still has a consent-only loop that can record PASS without probing; tests already forbid D10 from using that path.

**Why now:** `search_cli` is the canary that config ≠ doctor. Omni four-surface is freeze-committed as WS7 and will be stuffed into Graphify probes if Session A is not explicit. A later “arbitrary tool” goal would turn doctor into an unbounded curl-bash installer unless Session A first finishes the allowlist contract.

---

## Goals and non-goals

### Session fork (mandatory)

| Session | Goal | This PRD |
|---|---|---|
| **A — D10 completeness** | Every `recommended_tools` key has D10 Setup / Health / Diagnosis / `--fix` on the existing reconciler + probe contract. Unknown tools fail closed. Omni four-surface is a **separate** opted-in WS7 component, not a generic engine. | **This document. Implement this.** |
| **B — unbounded arbitrary-tool doctor** | An autonomous agent that can fix *any* tool setup the user names (SPA docs, random MCP, `install_commands` from untrusted JSON). | **Out of scope. Reject for this session.** |

Do not let “inventory all keys” silently become a generic installer.

### Goals (Session A)

1. **One doctor.** Implement against [`scripts/sb-doctor.sh`](../scripts/sb-doctor.sh), [`scripts/reconcile-recommended-tools.sh`](../scripts/reconcile-recommended-tools.sh), [`scripts/lib/recommended-tools/probe-*.sh`](../scripts/lib/recommended-tools/), [`skills/silver-doctor/SKILL.md`](../skills/silver-doctor/SKILL.md), and [`tests/scripts/test-silver-doctor.sh`](../tests/scripts/test-silver-doctor.sh). `/sb:doctor` remains the public alias.
2. **Coverage table as the done artifact.** Every in-scope tool has rows for Setup, Health, Diagnosis, `--fix` action, N/A rule, host support, class, and official-docs pin (URL + commit/tag/ref). **In-scope includes derived `cross_tool` / `D10-routes`**, not only `.silver-bullet.json` `recommended_tools` keys.
3. **Close the `search_cli` canary** using the Alumnium extra-tool pattern: registry + probe + `rt_run_component` + SKILL row + N/A-vs-FAIL tests + bounded `--fix`.
4. **Honest D10 semantics.** Opted-out → PASS N/A (never FAIL). Opted-in broken → FAIL with evidence id. `CONFIGURED ≠ LIVE` stays true: `mcp.json` / `hooks.json` / `command -v` are configuration, not live MCP in this chat.
5. **Make `--fix` proveable.** Dry-run/plan writes nothing. Apply does not swallow reconciler failure. Failed or malformed apply is observable (not applied, nonzero, stderr kept, honest receipt). Second apply is idempotent. Secrets never appear in doctor **stdout, stderr, JSON reports, or receipts** (JSON stdout stays parseable).
6. **Fail closed on unknown tools.** Names, URLs, or `install_commands` not on the allowlist do not execute. A **known component id is not a command allowlist**: project-local `install_commands` must match the repo-owned registry pin (`scripts/install-*-sb.sh` or exact pinned argv/digest). A tampered known-key payload must not execute.
7. **Omni as WS7 component, later in this Session A phasing, not stuffed into Graphify probes.** Four freeze surfaces: Setup, Health, Diagnosis, Troubleshooting/`--fix`, including daemon `:20128`, providers, **current doctor host CLI only** (freeze catalogs five CLIs), `chat_admission_busy` / `OMNIROUTE_CHAT_MAX_HEAVY_IN_FLIGHT`, OAuth remains manual.

### Non-goals (Session A)

- Session B autonomy: Google/SPA install of unknown tools; “any MCP in Cursor settings”; a nested Task that fetches docs and invents shell.
- A second doctor next to `sb-doctor.sh`.
- Treating [`scripts/lib/sb-doctor/checks.sh`](../scripts/lib/sb-doctor/checks.sh) / [`fix.sh`](../scripts/lib/sb-doctor/fix.sh) as source of truth unless the same change deletes or regenerates them.
- Invented `graphify doctor`. SKILL already forbids it.
- `lean-ctx init --agent *`. Five-tool mutex stays.
- Dumping API keys, `.env`, MCP `env` blocks, OAuth tokens, or `~/.codex/auth.json` into reports.
- Automatic rollback of `--fix` (receipt + re-run doctor is the recovery story).
- FAIL on opted-out Alumnium / `search_cli` / Omni.
- Claiming Health from PATH or an MCP key **alone** (`command -v` or a JSON key without the class Health contract). `search_cli` Health is PATH **plus** non-secret version (locked).
- Editing [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](router_subagent_surfaces_85bf9f09.plan.md).
- Git checkout/switch, `SetActiveBranch`, Fast effort, commits unless a later human asks.

---

## Users and jobs-to-be-done

| User | Job | Success looks like |
|---|---|---|
| Operator on Cursor (primary D10 host) | After `/silver:init` or a stack drift, run `/silver:doctor` and know which opted-in tool is mis-wired | FAIL lines name `D10-<tool>` with a scoped `--fix=local\|host\|packages\|all` |
| Operator who did **not** opt into Alumnium, search-cli, or Omni | Confirm the default tree is green (**green** = no FAIL, not “no WARN”; Graphify skill/package skew WARN is expected and non-blocking) | `D10-alumnium` / future `D10-search_cli` are PASS N/A (`pending`/`disabled`), never FAIL. Omni PASS N/A exists **once Phase 3 lands**; while Phase 3 is deferred there is no Omni D10 row (coverage-table footnote only) |
| Operator on Claude or Codex | Doctor still audits host-agnostic SB core and host install surface | `cross_tool` unsupported → WARN, **must not** recommend `--fix=host`; D8/D21/D22 stay host N/A as today |
| Implementer of a new allowlisted tool | Add one probe+repair module without teaching doctor to fetch SPA installers | Plugin-shaped contract (probe, repair, N/A, `--fix` test, docs pin) — **later phase**, still allowlisted |
| Freeze Omni operator (WS7, when opted in) | Setup / health / diagnosis / `--fix` for daemon + providers + **current doctor host CLI only** | Separate component; OAuth click stays manual; `chat_admission_busy` diagnosed from official OmniRoute troubleshooting docs |

Doctor is **not** a Job in the catalog sense (freeze: inspect/`--fix`, Process setup). Nested agents must not become the repair engine.

---

## Current system

### Canonical runner

Live path is [`scripts/sb-doctor.sh`](../scripts/sb-doctor.sh):

- `run_doctor_checks()` drives D1–D22.
- `doctor_record_reconciler_d10()` is the live D10 path: `--mode verify` (or `plan` when `--dry-run`), then maps reconciler component states:
  - `ready` → PASS
  - `disabled` | `pending` | `unsupported` → **PASS N/A**
  - `suspended` / `reload_required` → WARN
  - `repairable` / `failed` → FAIL
  - Advisory evidence uses one general rule: **core Health ready + named warning evidence** → `doctor_record_reconciler_d10()` emits **WARN**. Locked WARNs that use this path: `search_cli` provider-missing, installed CLI/formula version ≠ `docs_pin`, Graphify skill vs package skew, Omni `chat_admission_busy`, Omni provider expired. Graphify skill vs package skew is an **expected, non-blocking** advisory in this repo’s own tree (`--fix` does not clear it; see Official docs consult policy). Do **not** invent a per-tool special case that bypasses this mapping.
  - Vendor-doctor **skip** (`RT_SKIP_VENDOR_DOCTOR=1` or recorded skip): **not** Health evidence and **not** component PASS N/A. Final D10 follows remaining class checks (CLI/MCP/hooks). Skip must never make the component PASS by itself; if remaining evidence is ready, PASS **with skip recorded**; if remaining evidence is FAIL, FAIL.
- `cross_tool` is recorded as `D10-routes`: **PASS** (live `record pass`; message may contain “N/A”) when reconciler evidence is `no_five_tool_consent`. This is **not** F2 opted-out **PASS N/A** (`pending`/`disabled`). **WARN** only on the unsupported-host branch (`rt_host_supported` is Cursor-only for five-tool/`cross_tool` — never recommend `--fix=host` there); **FAIL** on hook-order / route-drift / shell-rewrite evidence. Do not describe the no-consent case as WARN. Coverage-table `N/A rule` for derived `cross_tool`: no five-tool consent → **PASS**; unsupported host → **WARN**; opted-out five-tool stack is not a `disabled` row.

Stale split: [`scripts/lib/sb-doctor/checks.sh`](../scripts/lib/sb-doctor/checks.sh) still contains a consent-only `for tool in graphify agentmemory rtk context_mode alumnium` PASS loop. [`tests/scripts/test-silver-doctor.sh`](../tests/scripts/test-silver-doctor.sh) asserts D10 must **not** use that path. Session A edits `sb-doctor.sh` + reconciler + probes. Do not treat `lib/sb-doctor/{checks,fix}.sh` as truth unless deleted/regenerated in the same change.

### Reconciler and probes

[`scripts/reconcile-recommended-tools.sh`](../scripts/reconcile-recommended-tools.sh) is the consent-gated apply/verify engine. Probes live under [`scripts/lib/recommended-tools/`](../scripts/lib/recommended-tools/):

| Probe / helper | Role |
|---|---|
| [`probe-graphify.sh`](../scripts/lib/recommended-tools/probe-graphify.sh) | CLI, `graphify-mcp`, Cursor MCP key, `graphify-out` index |
| [`probe-agentmemory.sh`](../scripts/lib/recommended-tools/probe-agentmemory.sh) | CLI, `localhost:3111`, MCP keys, export root |
| [`probe-rtk.sh`](../scripts/lib/recommended-tools/probe-rtk.sh) | CLI, min version, `hooks.json` `rtk hook cursor`, vendor doctor |
| [`probe-context-mode.sh`](../scripts/lib/recommended-tools/probe-context-mode.sh) | Node min, CLI, MCP, **`CONTEXT_MODE_PLATFORM=cursor context-mode doctor` on default D10** |
| [`probe-leanctx.sh`](../scripts/lib/recommended-tools/probe-leanctx.sh) | CLI, MCP prefix `lctx_`, overlap MCP off, never `lean-ctx init --agent *` |
| [`probe-alumnium.sh`](../scripts/lib/recommended-tools/probe-alumnium.sh) | Extra-tool pattern: CLI + Cursor MCP when opted in; PASS N/A when not |
| [`probe-cross-tool.sh`](../scripts/lib/recommended-tools/probe-cross-tool.sh) | Route/heartbeat/mutex |
| [`vendor-doctor.sh`](../scripts/lib/recommended-tools/vendor-doctor.sh) | Timeout-bounded, stdin closed, skippable via `RT_SKIP_VENDOR_DOCTOR=1` |
| [`receipts.sh`](../scripts/lib/recommended-tools/receipts.sh) | Apply receipts (no automatic rollback) |
| [`common.sh`](../scripts/lib/recommended-tools/common.sh) | `RT_COMPONENT_IDS`, `RT_VALID_HOSTS`, scope helpers |

There is **no** `probe-search_cli.sh` and **no** `probe-omniroute.sh`.

Authorization already fail-closes unknown entry-points (`rt_validate_authorization`). Mutations require `consent==enabled` and not suspended (`rt_mutation_allowed`). `rt_any_five_tool_mutation_allowed` is only graphify / agentmemory / rtk / context_mode / leanctx (Alumnium is extra-tool, not in that mutex set).

### `RT_COMPONENT_IDS` vs config keys

Hardcoded in [`scripts/lib/recommended-tools/common.sh`](../scripts/lib/recommended-tools/common.sh):

```text
RT_COMPONENT_IDS=(graphify agentmemory rtk context_mode leanctx alumnium cross_tool)
RT_VALID_HOSTS=(cursor claude codex opencode goose hermes)
```

`rt_host_supported` for D10 five-tool / `cross_tool` is **Cursor only**. Non-Cursor `cross_tool` is permanently `unsupported`; doctor must WARN and must not recommend `--fix=host` (already tested). `doctor_host_install_script` only knows `claude|codex|cursor`.

**`search_cli` does not inherit that Cursor-only gate.** Agent-host support is **Cursor, Claude, and Codex** (missing CLI / missing version → FAIL when opted in). That is not an OS/package-manager matrix. Session A `--fix=packages` is the **Homebrew** pin on macOS. If `brew` is absent or the OS is not that package platform: still FAIL missing CLI when opted in; **do not** suggest a brew repair that cannot run; Diagnosis records `unsupported_package_manager`; `--fix=packages` skips with that evidence (no invented apt/choco installer). Skip outcome: `DOCTOR_FIX_APPLIED=0` for that component, receipt **not-applied**, process exit follows the severity→exit table (this skip is WARN-class → **zero** unless a FAIL also exists). Same skip contract when `--fix=local` / `--fix=host` omit `search_cli` because `rt_scope_includes_component` excludes it. Do not copy Alumnium `probe-alumnium.sh` `fu=1` / unsupported just because `rt_host_supported` is false. Do not change five-tool/`cross_tool` Cursor-only behavior.

Adding a key to [`.silver-bullet.json`](../.silver-bullet.json) does **nothing** until registry + probe + `rt_run_component` + SKILL + N/A-vs-FAIL tests land. That is why **`search_cli` is the canary**. Session A **must** ship an enumeration/parity test: every `.silver-bullet.json` `recommended_tools` key **and** derived `cross_tool` (plus `omniroute` when Phase 3 lands) appears in `RT_COMPONENT_IDS` / extra-tool list, [`hooks/lib/recommended-tools-registry.sh`](../hooks/lib/recommended-tools-registry.sh), `rt_run_component` dispatch, and the SKILL D10 table. A SKILL row alone is not enough.

### `search_cli` canary

Config already has `recommended_tools.search_cli` (`enabled_by_user` null in the SB repo, `binary`, `install_commands`, `provider_classes`, **`required_when_enabled`: false** — unique vs every other key including Alumnium, which is `true`). Hooks `sb_recommended_tool_enforced()` skip when that flag is false; **doctor/reconciler do not read it today.** Session A: keep `required_when_enabled: false` (do not copy Alumnium `true`). That flag gates **hook enforcement**, not **audit honesty**; D10 audits what the operator opted into, so opted-in missing CLI is still **FAIL**. The divergence is **deliberate**, not drift to “fix.” D10 still uses `enabled_by_user`: opted-out → PASS N/A; opted-in missing CLI → FAIL. **Absent key** (downstream `.silver-bullet.json` with no `search_cli` / `omniroute` object) ≡ opted-out PASS N/A (`pending`). Do **not** scaffold missing keys into the project file. A newly added `RT_COMPONENT_IDS` id with no prior reconciler state is first-run `pending`, not an upgrade error. Do not treat “not required” as D10 PASS N/A when opted in.

Product doc: [`docs/SEARCH-CLI.md`](../docs/SEARCH-CLI.md) (optional Deep Research provider; `brew tap 199-biotechnologies/tap` plus a **versioned** formula pin recorded in `docs_pin` / registry — not a floating `brew install search-cli` that can resolve N+1 later; keys via `search config set keys.brave …`; missing provider is not a blanket blocker). Installed `search --version` (or formula version) that differs from the pin is D10 **WARN** `version_drift`. **Direction of drift:** installed **older** than pin → repairable via `--fix=packages` pinned install; installed **newer** than pin → WARN only, `--fix` **must not downgrade**, and the WARN is **expected to persist** after apply (exclude that fixture from converge-to-`ready` assertions).

Zero mentions in probes, `RT_COMPONENT_IDS`, or the SKILL D10 table. Session A phase 1 is this key, modeled on Alumnium **extra-tool consent/registry** — not Alumnium’s Cursor-only host gate.

### `--fix` swallow (live blast radius)

[`doctor_apply_fixes()`](../scripts/sb-doctor.sh) today:

1. No-op unless `DOCTOR_FIX=1`. `--dry-run` returns without writes. Already-applied flag returns.
2. If reconciler exists: always `doctor_run_reconciler apply` with `--entry-point doctor-fix`. Capture is `RECONCILER_JSON="$(bash "$reconciler" … 2>/dev/null || true)"`. Then **`DOCTOR_FIX_APPLIED=1` even when JSON is empty**.
3. Remaining mutations, first matching failed check then `break`: D13/D14/D16/D18/D19 host install (`claude|codex|cursor` only); D20 mutex clear + agentmemory export scaffold; D4 hooks merge; D21 [`install-cursor-sb-agents.sh`](../scripts/install-cursor-sb-agents.sh); D15 print-only. **Session A must close this `break`:** `--fix=all` is **one ordered pass** that converges all **in-scope** eligible failures (reconciler then matching legacy mutations). **Eligible** means gated by the same `--fix=` keyword as the blast-radius table — not every D* check on every `--fix`. `--fix=local` never runs D4 / D13/D14/D16/D18/D19 / D21.
4. Scopes: `local` → project; `host` → host; `packages` → packages; `all` → all. Live [`rt_scope_includes_component`](../scripts/lib/recommended-tools/common.sh) is **three-way**: `project` = graphify, agentmemory, **cross_tool**; `host` = rtk, context_mode, leanctx, alumnium, **cross_tool**; `packages` = graphify, agentmemory, rtk, context_mode, leanctx, alumnium (Session A adds `search_cli` here). `packages` is not “the other half of a two-way split.” `cross_tool` is not in `packages`.

SKILL documents:

```bash
bash scripts/sb-doctor.sh --fix=local
bash scripts/sb-doctor.sh --fix=host
bash scripts/sb-doctor.sh --fix=packages
bash scripts/sb-doctor.sh --fix=all
```

`--fix=packages` is required for the `search_cli` canary (CLI install). `--fix=local` / `--fix=host` silently skip it unless `rt_scope_includes_component` includes `search_cli` in those scopes (Phase 1: packages only).

Tests do **not** execute those apply paths for D10 tools.

### Host matrix

| Host | D10 five-tool + routes | `search_cli` D10 (locked) | Host install `--fix` | Omni CLI per host (freeze, later) |
|---|---|---|---|---|
| Cursor | Supported | Supported: opted-in missing CLI/version → FAIL | `install-cursor.sh`, MCP/hooks merge | `cursor-agent` / `agent` |
| Claude | `cross_tool` unsupported WARN | Same as Cursor (host-agnostic CLI) | `install-claude.sh` for D13/D14/D16/… | `claude` |
| Codex | same | Same as Cursor | `install-codex.sh` | `codex` |
| OpenCode / Goose / Hermes | in `RT_VALID_HOSTS` but not D10-supported | Out of Session A D10 (no FAIL required) | no `doctor_host_install_script` | `opencode`, `pi` (freeze Omni only) |

Every new check needs explicit Cursor vs Claude vs Codex behavior. Freeze five CLIs apply to Omni only **as a catalog**; Session A Omni D10 requires the **current doctor host CLI only**. Five-tool/`cross_tool` stay Cursor-only; **`search_cli` does not.**

### `CONFIGURED ≠ LIVE`

SKILL Step 2 (D10 table, ~L52–66): default D10 verifies **installation and configuration**, not live MCP session tools. MCP keys in Cursor `mcp.json` and hook lines in `hooks.json` prove configuration. `reload_required` means config was written but this session has not proven liveness. Do not treat `command -v` or a JSON key as live MCP. `--deep` Graphify stdio handshake is WARN only.

False-green catalog the review named: consent-only PASS (stale checks.sh), MCP key ≠ live session, vendor-doctor skip treated as Health PASS, `reload_required` as green, health URL without proving the daemon is the opted-in instance.

---

## Requirements: functional

### F1. Four surfaces, mapped per tool class

Do not copy Omni daemon language onto Graphify CLI. Require a coverage table (schema in F4) with one row-set per tool:

| Surface | Meaning (must be instantiated per class) |
|---|---|
| **Setup** | Binary/MCP/hooks/config present as contracted; install script or `install_commands` from the **repo-owned registry pin** only (known id ≠ executable payload) |
| **Health** | Class-appropriate liveness: CLI version, HTTP health, vendor doctor (timeout-bounded), daemon ping. Not `command -v` alone |
| **Diagnosis** | Evidence ids (`repairable` reasons, mutex, route drift, missing MCP key, busy-class for Omni only) |
| **Troubleshooting / `--fix`** | Scoped apply: `local` / `host` / `packages` / `all`; dry-run first; receipts; no secret dump |

Tool classes: `CLI` / `MCP` / `daemon` / `hooks` / `vendor-doctor`. A tool may occupy multiple classes (RTK is CLI + hooks + vendor-doctor).

### F2. N/A vs FAIL

Copy the Alumnium contract already in SKILL and [`test-silver-doctor.sh`](../tests/scripts/test-silver-doctor.sh):

- Not opted in (`enabled_by_user` null/false) → **PASS N/A** (`pending`/`disabled`). Default tree must not FAIL.
- Opted in on a supported host, missing CLI/MCP/config → **FAIL** `D10-<tool>` with evidence. For **`search_cli`**, supported hosts are **Cursor, Claude, and Codex** (not Cursor-only).
- Unsupported host → PASS or WARN per existing `unsupported` mapping; never recommend `--fix=host` for Cursor-only `cross_tool`. Do **not** mark `search_cli` unsupported solely because `rt_host_supported` is false.
- Derived `cross_tool` with `no_five_tool_consent` → **PASS** (not PASS N/A, not WARN). See current-system `D10-routes` bullet.
- Unknown component id (not in `RT_COMPONENT_IDS` / extra-tool list) → doctor **emits PASS N/A** with reason `unsupported` (fail-closed: **no installer, no `--fix` suggestion**). Never FAIL the default D10 component tree for a name the allowlist does not know. Never “try to install.” **Do not stay silent:** if `.silver-bullet.json` has an opted-in (`enabled_by_user` true) key that is not allowlisted, doctor **WARNs** with the key name and “not in the allowlist; no repair” (`D10-unknown_key`). That WARN does not FAIL other components; doctor **exit is nonzero** so CI notices.

### F3. Latest official docs pin

Before writing a probe or `--fix` path for a tool, consult **version-matched** official docs (not a marketing SPA). Record URL + commit/tag/ref in the coverage table. Prefer GitHub markdown / raw docs. Omni troubleshooting belongs to [OmniRoute `docs/guides/TROUBLESHOOTING.md`](https://github.com/diegosouzapw/OmniRoute/blob/main/docs/guides/TROUBLESHOOTING.md) (`chat_admission_busy`, `OMNIROUTE_CHAT_MAX_HEAVY_IN_FLIGHT`) — that class of doc, not a homepage. See Official docs consult policy below.

### F4. Coverage table schema

Ship the table in the SKILL (D10 section) and keep tests asserting every `recommended_tools` key **and** derived `cross_tool` (plus Omni when the WS7 phase lands) has a row. Columns:

| Column | Required content |
|---|---|
| `tool` | Config / component id (`graphify`, `search_cli`, …). Omni row uses **`omniroute`** (locked; see Open questions → Session A defaults) |
| `class` | CLI / MCP / daemon / hooks / vendor-doctor (comma-ok) |
| `Setup` | What D10 verifies when opted in |
| `Health` | What counts as live enough for this class; explicit CONFIGURED vs LIVE |
| `Diagnosis` | Evidence ids from the canonical list below / typical FAIL text |
| `--fix` action | Scope + script (`install-*-sb.sh`, reconciler apply, restart daemon, …) |
| `N/A rule` | Opted-out / unsupported host / skip vendor-doctor (**skip is not Health evidence**; remaining class checks decide PASS/FAIL). Derived `cross_tool`: no five-tool consent → **PASS** (not PASS N/A) |
| `host support` | Five-tool/`cross_tool`: Cursor only. **`search_cli`: Cursor + Claude + Codex.** Omni (phase 3): require the **current doctor host’s CLI only**, not all five; OpenCode/Goose/Hermes inspect `opencode`; `pi` is Omni CLI identity (not five-tool `RT_VALID_HOST`); prefer `cursor-agent` over generic `agent` |
| `docs_pin` | Official URL + version/ref consulted |

Do not claim Health = `command -v` **alone** or an `mcp.json` key. `search_cli` Health is PATH **plus** non-secret version.

**Canonical evidence ids** (Diagnosis column and tests use these; convention `D10-<component>.<reason>` or the shared tokens below):

| Id | Meaning |
|---|---|
| `D10-<tool>` | Component FAIL envelope (missing CLI/MCP/config) |
| `missing_cli` | Opted-in CLI not on PATH (`D10-<component>.missing_cli`) |
| `no_five_tool_consent` | `cross_tool` / `D10-routes` no-consent PASS |
| `provider_missing` | search_cli provider absent (WARN) |
| `version_drift` | installed CLI/formula ≠ `docs_pin` (WARN) |
| `vendor_skip` | vendor-doctor skipped (not Health) |
| `unsupported_package_manager` | brew/OS cannot run packages repair |
| `busy` | Omni `chat_admission_busy` (WARN) |
| `provider_expired` | Omni provider expired (WARN) |
| `unknown_key` | opted-in JSON key not on the allowlist (WARN) |
| `duplicate_key` | overlapping LeanCTX MCP keys |

### F5. `--fix` dry-run, idempotency, secrets

- `--dry-run` / reconciler `--mode plan` writes nothing (already partially true; keep it).
- Apply must **not** swallow reconciler stderr; must **not** set `DOCTOR_FIX_APPLIED=1` on empty JSON, failed apply, or malformed apply JSON. Failed/malformed apply: `DOCTOR_FIX_APPLIED=0`, nonzero exit, stderr preserved, receipt must not claim success. **`DOCTOR_FIX_APPLIED` is the result of one invocation, not an intra-invocation early-return.** Convergence is a **single ordered pass** (reconciler, then in-scope legacy mutations, no `break`, no unbounded fixpoint). Re-run checks after apply is verify, not a second apply loop inside the same `--fix`.
- Verify-mode probe during checks; apply only under `--fix`; re-run checks after apply (already in `main`). Do not apply during verify.
- Second `--fix` on a converged fixture is idempotent (`changed=false` / no additional mutation), matching existing reconciler hooks/mcp batch tests.
- Doctor **stdout, stderr, `SB_DOCTOR_FORMAT=json` reports, and receipts** contain **no** secrets (API keys, `.env`, MCP `env`, OAuth tokens, `~/.codex/auth.json`). JSON stdout stays parseable when diagnostics go to stderr.
- Confirmation required for `packages`, network installs, and daemon restart **when stdin is a TTY** **and** the ordered pass **would execute** a confirm-class mutation (plan-triggered, not “scope requested”). If the planned pass has no confirm-class mutation, do not prompt and do not require `SB_DOCTOR_ASSUME_YES=1`. Non-interactive tests and CI **must** set `SB_DOCTOR_ASSUME_YES=1` (locked name) so those scopes can apply without a TTY **when a confirm-class mutation is actually planned**. **Confirmation unobtainable** (non-TTY without that flag, **or** TTY decline / EOF / invalid) **when a confirm-class mutation is planned**: **no writes** in that `--fix` invocation; nonzero; receipt not-applied. Same contract for `--fix=all` — do not apply local/host while skipping packages. Default for humans stays confirm-on-packages. MCP/hook merge may stay unattended when consent is already `enabled` **and** confirmation was obtained or assume-yes is set. OAuth consent stays manual (freeze).

**Process exit (severity → exit).** Doctor process exit is:

| Recorded severity | Exit |
|---|---|
| FAIL | nonzero |
| WARN | **zero**, except enumerated escalating WARNs: `unknown_key` → **nonzero** |
| PASS / PASS N/A | zero |

A WARN-only tree (including expected Graphify skew) exits **zero**. A FAIL tree exits **nonzero**. `unsupported_package_manager` skip and out-of-scope component skip are WARN-class (exit zero unless FAIL also exists); `DOCTOR_FIX_APPLIED=0` when nothing was written.

### F6. Fail-closed unknown tools

`rt_validate_authorization` already fail-closes unknown entry-points. Session A must not add a generic executor for arbitrary names, URLs, or `install_commands` from untrusted JSON. A **known** `recommended_tools` key does not authorize a swapped `install_commands` payload: execute only repo-owned `scripts/install-*-sb.sh` or exact pinned argv/digest from **[`hooks/lib/recommended-tools-registry.sh`](../hooks/lib/recommended-tools-registry.sh)** — that file is the **authoritative, source-controlled command/version pin**. It is **never** merged with project-local `.silver-bullet.json`. `RT_COMPONENT_IDS` in [`scripts/lib/recommended-tools/common.sh`](../scripts/lib/recommended-tools/common.sh) is the id allowlist; the F-7-1 parity test fails if registry and `RT_COMPONENT_IDS` disagree. Tests must include a tampered-known-key fixture that **refuses** execution. New tools need a probe+repair module on the existing consent contract.

### F7. Omni is a separate WS7 component

Freeze headings to implement against (do not edit the freeze file):

- YAML todo `omni-agent-doctor`: WS7 `/sb:doctor` setup + health + diagnosis + troubleshooting/`--fix` for Omni daemon/providers + **current doctor host CLI** (freeze catalogs five CLIs; Session A does not require all five); silver-doctor SKILL; docs/Doctor only; does not own quality-order/runtime ([`.planning/router_subagent_surfaces_85bf9f09.plan.md`](router_subagent_surfaces_85bf9f09.plan.md), heading `omni-agent-doctor`).
- Public alias heading: `/sb:doctor` = public inspect + setup/health/diagnosis/troubleshooting/`--fix`.
- Repair table (freeze Omni `/sb:doctor --fix`): opted-out tools pass as `disabled` (same as Graphify); `--fix` does install/restart; **only OAuth consent stays manual**; checks include `omniroute` binary + daemon health, compression/memory **off**, provider active vs expired.
- WS7 owns Omni four-surface from absorbed omni origin SHA `745c7f4166f70dff9181d7c8a639eb2e3519eedeb25487dda2f97e84425c2c26` (origin todo `doctor-fix`).
- Busy class: `chat_admission_busy` / `OMNIROUTE_CHAT_MAX_HEAVY_IN_FLIGHT` — Omni daemon Health only. Do not invent equivalents for Graphify/agentmemory unless upstream documents them.

`omniroute` is **not** a current `recommended_tools` key. Do not stuff Omni into D10 Graphify/RTK probes. Install/init runtime stays WS6 (`install-omniroute-sb.sh` when that phase lands). **Phase 3 is gated on that WS6 installer existing in-tree.** If it is absent, defer Phase 3: no partial Omni `--fix` install path, no unauthorized duplicate installer. Doctor may report Omni as planned/unavailable until the installer lands.

---

## Requirements: non-functional

### NF1. Hosts

Primary D10 matrix is Cursor. Claude and Codex must keep existing N/A / WARN behavior. OpenCode / Goose / Hermes remain in `RT_VALID_HOSTS` without pretending D10 five-tool is live there. Omni five CLIs (`claude`, `codex`, `cursor-agent`/`agent`, `opencode`, `pi`) are freeze Omni-only. **Omni Setup does not require all five CLIs.** Require the CLI for the **current doctor host** only. Combined OpenCode/Goose/Hermes: inspect `opencode` (inspect `pi` only when the doctor host is Pi). `pi` is an Omni CLI identity, not a five-tool `RT_VALID_HOST`. Prefer `cursor-agent` over generic `agent` when both names exist.

### NF2. Five-tool mutex

Routed ownership stays:

| Route | Owner |
|---|---|
| `sb_shell` | RTK |
| `sb_webfetch` / `sb_grep` / `sb_slice` | Context Mode |
| `sb_graph` | Graphify |
| `sb_remember` | agentmemory |
| `sb_read` / wire / PathJail / injection | LeanCTX |

Never enable overlapping LeanCTX shell/sandbox/fetch MCP. Never `lean-ctx init --agent *`. RTK before Context Mode on preToolUse. Duplicate `leanctx` **and** `lean-ctx` MCP keys: D10 reports **FAIL** (`D10-leanctx` / duplicate-key evidence) when LeanCTX is opted in. Catalog D22 may still label the same class of finding as WARN in the SKILL check list — implementers must not treat D22 WARN as a license to PASS D10. D10 FAIL is the Session A contract.

### NF3. No SPA curl-bash

“Latest official docs” must not become `curl … | bash` from a marketing SPA. Install commands come from allowlisted `install_commands` / `scripts/install-*-sb.sh` / Homebrew or npm **as pinned in those scripts**. `--fix=packages` may install upstream CLIs only through those pins. No license-clicking, no scraping, no nested Task that Googles and executes.

### NF4. Skill sync

After SKILL edits: `bash scripts/sync-codex-package.sh` (and plugin command stubs if doctor command text changes: `bash scripts/generate-plugin-commands.sh`). Do not hand-edit generated mirrors.

### NF5. Branch and process

Stay on the current git branch. No checkout/switch. No `SetActiveBranch`. No Fast. Graphify query + agentmemory save on the implementing session. Parent verifies evidence.

---

## `--fix` policy and blast radius

Quote this as a hard constraint. Change only what the coverage table allows.

**Live behavior to keep or tighten:**

| Scope | May write | Must not |
|---|---|---|
| `--dry-run` / plan | nothing | apply |
| `--fix=local` | project index, D20 **export scaffold**, consent-scoped local repairs | D4 hooks, D13/D14/D16/D18/D19 host install, D21 CSBA, host MCP/hooks, package installs |
| `--fix=host` | D4 hooks merge, D13/D14/D16/D18/D19 host install (`claude\|codex\|cursor`), D20 **mutex clear**, D21 [`install-cursor-sb-agents.sh`](../scripts/install-cursor-sb-agents.sh), MCP merge, route ownership (Cursor) | recommend itself on `cross_tool unsupported`; `--fix=local` must not run these |
| `--fix=packages` | allowlisted CLI installs (`install-*-sb.sh` / **registry-pinned** `install_commands` only); **upgrade/repair to pin** when installed is **older** than pin | unpinned npm/curl; swapped known-id payloads; confirmation required; **must not downgrade** a newer installed formula to the pin |
| `--fix=all` | **one ordered pass** of **in-scope** eligible failures (reconciler then matching legacy; no `break`; no unbounded fixpoint) | secrets, OAuth automation, unknown tools; “try the next repair and stop”; out-of-scope D* for the keyword |
| D4 | `--fix=host` (or `all`) | `--fix=local` |
| D13/D14/D16/D18/D19 | `--fix=host` (or `all`); host install for `claude\|codex\|cursor` | `--fix=local`; other runtimes |
| D20 export scaffold | `--fix=local` (or `all`) | host-only scopes if split |
| D20 mutex clear | `--fix=host` (or `all`) | `--fix=local` |
| D21 | `--fix=host` (or `all`); [`install-cursor-sb-agents.sh`](../scripts/install-cursor-sb-agents.sh) scoped by `CSBA_REPO_ROOT` | `--fix=local`; writing agents into the SB checkout when doctoring another project |
| D15 | print-only | mutating Claude descriptions |
| Omni (later phase) | `--fix=packages` (or `all`); install + restart **dead** daemon; write compression/memory off | OAuth without a user click; dumping `~/.codex/auth.json`; restart for busy |

**Required Session A repairs to `--fix` itself:**

1. Do not discard reconciler stderr (`2>/dev/null`).
2. Do not `|| true` then mark applied.
3. Do not set `DOCTOR_FIX_APPLIED=1` when JSON is empty, malformed, or apply failed. Surface exit status, stderr, and an honest receipt.
4. Dry-run/plan before apply remains the default doctor path without `--fix`.
5. **Confirmation unobtainable** (non-TTY without `SB_DOCTOR_ASSUME_YES=1`, **or** TTY decline / EOF / invalid): **no writes** for the whole `--fix` invocation; nonzero; receipt not-applied. Never hang. CI with `SB_DOCTOR_ASSUME_YES=1` still applies. Do not apply local/host while skipping packages. Default for humans stays confirm-on-packages.
6. Receipt via [`receipts.sh`](../scripts/lib/recommended-tools/receipts.sh); recovery = receipt + re-run doctor, not undo. Receipts contain **no** secrets.
7. Freeze: `--fix` does install/restart; only OAuth consent stays manual. **Busy daemon is not a restart trigger.** `chat_admission_busy` → **WARN** (daemon alive, saturated); Diagnosis points at `OMNIROUTE_CHAT_MAX_HEAVY_IN_FLIGHT`; `--fix` must not restart solely for busy. **Provider expired** → **WARN**; OAuth stays manual; `--fix` must not claim to re-auth. Restart is for a **dead** daemon after the WS6 installer exists.

Unrelated IDE preferences stay inspect-only. When freeze WS for host nested/install Doctor writes lands, **HNEST-01** (nested-host Doctor write) and **HINST-01** (host-install Doctor write) remain the two mandated idempotent Doctor writes. Doctor does not repair arbitrary control-plane or product state.

---

## Official docs consult policy

Session A implementers MUST, per tool, before writing probe/`--fix` code:

1. Identify the **installed or targeted version** (CLI `--version`, npm package, Homebrew formula, git tag).
2. Open **version-matched official docs** — GitHub `README` / `docs/` markdown / raw.githubusercontent, or vendor `doctor` help. Record `docs_pin` as `URL@ref`.
3. Prefer troubleshooting-class pages for Diagnosis/`--fix` (Omni: [TROUBLESHOOTING.md](https://github.com/diegosouzapw/OmniRoute/blob/main/docs/guides/TROUBLESHOOTING.md) for `chat_admission_busy` and `OMNIROUTE_CHAT_MAX_HEAVY_IN_FLIGHT`). There is **no** repo-root `docs/TROUBLESHOOTING.md` today; do not invent one as a substitute for upstream, and do not link that path as if it exists.
4. Reject SPA marketing pages and JS-only sites as a source of install commands.
5. In-repo product docs remain the SB contract and must stay consistent with probes:

| Tool | In-repo contract | Upstream pin starting points |
|---|---|---|
| Graphify | [`docs/GRAPHIFY.md`](../docs/GRAPHIFY.md), [`docs/code-intelligence-contract.md`](../docs/code-intelligence-contract.md) | Graphify CLI/help for the installed package version (skill vs package skew is already a WARN at 0.9.35 vs 0.9.48). `--fix` for that WARN: **none — advisory; upstream `graphify install` is operator-run, not doctor-run** |
| agentmemory | [`docs/AGENTMEMORY.md`](../docs/AGENTMEMORY.md) | health URL / MCP docs for that version |
| RTK | [`docs/RTK.md`](../docs/RTK.md) | `rtk doctor` if non-interactive |
| Context Mode | SKILL D10 row; [`docs/STACK-OPTIMIZATION.md`](../docs/STACK-OPTIMIZATION.md) | `context-mode doctor` with `CONTEXT_MODE_PLATFORM=cursor` |
| LeanCTX | [`docs/LEANCTX.md`](../docs/LEANCTX.md) | `lean-ctx doctor` if non-interactive; never `init --agent *` |
| Alumnium | [`docs/ALUMNIUM.md`](../docs/ALUMNIUM.md) | `alumnium doctor` if non-interactive; MCP `npx -y alumnium mcp` |
| `cross_tool` | [`docs/code-intelligence-contract.md`](../docs/code-intelligence-contract.md) (five-tool mutex / `D10-routes`) | **SB-owned pin:** Silver Bullet commit/ref of that contract — not an upstream package version |
| search_cli | [`docs/SEARCH-CLI.md`](../docs/SEARCH-CLI.md) | [search-cli](https://github.com/199-biotechnologies/search-cli) README/install for the **pinned formula version**; `docs_pin` must match that version, not a floating latest |
| Omni (phase 3) | planned `docs/OMNIROUTE.md` (not in-tree today; do not treat the path as live) | OmniRoute README + upstream TROUBLESHOOTING.md at the absorbed/ref version |

`--fix=packages` ToS: installing an upstream CLI is allowed only through pinned scripts; doctor must not click through licenses or scrape ToS pages.

---

## Inventory of tools in and out of D10

### In D10 today (live allowlist)

| Id | Opt-in in this repo | SKILL default D10 coverage (abridged) | Probe |
|---|---|---|---|
| `graphify` | enabled | CLI; `graphify-mcp`; Cursor MCP `graphify`; real `graphify-out`; no invented `graphify doctor`; `--deep` stdio WARN | [`probe-graphify.sh`](../scripts/lib/recommended-tools/probe-graphify.sh) |
| `agentmemory` | enabled | CLI; HTTP `:3111`; MCP `agentmemory` / `user-agentmemory`; export dir | [`probe-agentmemory.sh`](../scripts/lib/recommended-tools/probe-agentmemory.sh) |
| `rtk` | enabled | CLI; min version; `rtk hook cursor`; RTK before CM; no LeanCTX shell rewrite; vendor `rtk doctor` if non-interactive | [`probe-rtk.sh`](../scripts/lib/recommended-tools/probe-rtk.sh) |
| `context_mode` | enabled | Node min; CLI; MCP; instruction fragment; **vendor `context-mode doctor` on default D10**; vendor fail → `D10-context_mode` FAIL | [`probe-context-mode.sh`](../scripts/lib/recommended-tools/probe-context-mode.sh) |
| `leanctx` | enabled | CLI; MCP `leanctx` / `lean-ctx` / `user-leanctx`; `lctx_` prefix; overlap MCP off; duplicate keys FAIL; vendor doctor if non-interactive | [`probe-leanctx.sh`](../scripts/lib/recommended-tools/probe-leanctx.sh) |
| `alumnium` | **not** opted in (`enabled_by_user` null) | When opted in: CLI + Cursor MCP; vendor doctor if non-interactive; no provider-key checks. Not opted in → PASS N/A | [`probe-alumnium.sh`](../scripts/lib/recommended-tools/probe-alumnium.sh) |
| `cross_tool` | derived | Exclusive owners, RTK shell, no double rewrite, RTK-before-CM; `D10-routes` | [`probe-cross-tool.sh`](../scripts/lib/recommended-tools/probe-cross-tool.sh) |

Catalog D1–D22 (jq, plugin cache, hooks, activation, migrate, Cursor orchestrator, tracker, hook smoke, state dir, install surface, host-agnostic core, marketplace, mutex, Cursor SB agents, duplicate LeanCTX MCP) stay as they are unless a D10 change forces a recording tweak.

### In config, out of D10 (Session A phase 1)

| Id | Status | Required work |
|---|---|---|
| `search_cli` | Config + [`docs/SEARCH-CLI.md`](../docs/SEARCH-CLI.md); **zero** probe/registry/SKILL D10; `required_when_enabled: false` (keep) | Extra-tool consent/registry (not Cursor-only host gate): `RT_COMPONENT_IDS`, `rt_scope_includes_component` **packages**, registry, `probe-search_cli.sh`, SKILL row, N/A vs FAIL on Cursor/Claude/Codex, bounded `--fix=packages` (CLI install only; **do not** write provider keys into doctor output) |

### Freeze-planned, not a `recommended_tools` key (Session A phase 3)

| Id | Status | Required work |
|---|---|---|
| `omniroute` (locked: `recommended_tools.omniroute`, D10 id `D10-omniroute`) | Planned WS7; YAML `omni-agent-doctor` pending | Separate component: four surfaces; daemon `:20128`; compression/memory off; **current doctor host CLI only** (not all five); OAuth manual; busy-class Health from official TROUBLESHOOTING.md; tests in [`test-silver-doctor.sh`](../tests/scripts/test-silver-doctor.sh) **and** [`test-router-doctor-report.sh`](../tests/scripts/test-router-doctor-report.sh) |

### Out of Session A (do not doctor)

- Arbitrary Cursor MCP servers, random CLIs, SPA-discovered tools.
- Provider API keys for search-cli / Alumnium / Omni (diagnose “key missing” without printing values).
- Quality-order / runtime ownership (freeze: WS7 does not own it).
- `lean-ctx` FTS as primary when Context Mode owns FTS.
- A generic doctor plugin marketplace (phase 4 is allowlisted modules only, still not Session B).

---

## Implementation plan

Phased. Each phase has its own tests. Do not start Omni or a plugin interface while `search_cli` is still invisible to D10.

### Phase 1 — `search_cli` canary (first)

Mirror Alumnium **extra-tool consent/registry** (not Alumnium’s Cursor-only `rt_host_supported`):

1. Consult [search-cli](https://github.com/199-biotechnologies/search-cli) at the formula/version SB documents; pin URL+ref in the coverage table.
2. Add `search_cli` to `RT_COMPONENT_IDS` (or an extra-tool list equivalent to alumnium — do not put it in `rt_any_five_tool_mutation_allowed`). Also update [`rt_scope_includes_component`](../scripts/lib/recommended-tools/common.sh): include `search_cli` in **`packages`** (CLI install / `install_commands`, same as Alumnium). Include it in **`host`** only if Session A adds host MCP/hooks for search-cli; do **not** add it to **`project`** unless a project-scoped artifact exists. If this function is not updated, `reconcile-recommended-tools.sh --scope packages` and `sb-doctor.sh --fix=packages` silently skip `search_cli`.
3. Registry + new `probe-search_cli.sh` (create under `scripts/lib/recommended-tools/`; it does not exist yet): when opted in, require CLI on PATH **and** a non-secret `search --version` (or equivalent). Do **not** invent provider-key Health that dumps `search config` secrets. Missing CLI when opted in → FAIL. Not opted in → PASS N/A. Provider-missing is WARN/Diagnosis text only. Deep Research `deep`/`ultradeep` is **not** a D10 FAIL (research manifests only).
4. SKILL D10 row + coverage-table columns.
5. Tests: opted-out N/A; opted-in missing CLI FAIL **on Cursor, Claude, and Codex** (do not `fu=1` off Cursor); PATH without version is not Health PASS; provider-missing is WARN not FAIL (core Health ready **plus** warning evidence — not `ready` PASS and not `repairable` FAIL); `--dry-run` no writes; **`--fix=packages`** install path only through **registry-pinned** `install_commands` / brew pin (`rt_scope_includes_component` must include `search_cli` in `packages`); tampered known-id `install_commands` refuses execution; second apply idempotent; **stdout, stderr, JSON, and receipts** have no secrets (JSON remains parseable).
6. Tighten `--fix` swallow (F5) in [`sb-doctor.sh`](../scripts/sb-doctor.sh) in this phase: do **not** mark apply-success on empty JSON or swallowed stderr. That bug affects every tool, not only search-cli. Phase 1 is not done while this swallow remains.

### Phase 2 — remaining D10 gaps on tools already in the allowlist

Not new components; honesty and `--fix` proof:

- Version skew: RTK / Context Mode / LeanCTX `min_version` below pin → **FAIL**. Graphify: D10 **WARN** when skill vs package skew is the known CLI warning (do not invent a Graphify `min_version` in config unless Open questions default is later overridden). Graphify must not PASS solely because PATH exists. Health URL without instance identity (e.g. agentmemory not just `:3111` responding) → **WARN**; name how identity is proved.
- Vendor doctor: record skip vs fail; `RT_SKIP_VENDOR_DOCTOR=1` is **not** Health evidence ([`vendor-doctor.sh`](../scripts/lib/recommended-tools/vendor-doctor.sh)). Final D10 follows remaining class checks (skip never PASSes the component by itself). Require **one live or hermetic vendor-doctor path** in reconciler tests so skip cannot masquerade as Health (locked; was OQ4).
- `--fix` tests for at least one five-tool component (fixture: broken hook line or missing MCP key → apply → re-probe ready) in [`test-reconcile-recommended-tools.sh`](../tests/scripts/test-reconcile-recommended-tools.sh) and/or [`test-silver-doctor.sh`](../tests/scripts/test-silver-doctor.sh).
- **`--fix=all` composition:** one **ordered pass** converges a fixture with **two in-scope** coexisting failures (close live first-match `break`; no unbounded fixpoint). `--fix=local` must not run D4 / D13/D14/D16/D18/D19 / D21. Second apply then idempotent. `DOCTOR_FIX_APPLIED` is set at the **end** of the invocation.
- **`/sb:doctor` executable alias (Phase 2):** both names resolve to the same skill/runner and forward `--fix` / `--dry-run` without a second implementation. Documentation alone does not close AC 6.
- **Repair-dispatch contract:** every advertised coverage-table `--fix` action has a plan/dispatch test that the named scope/script is wired (class-level mutation fixtures as needed). One live five-tool fixture does **not** prove the other table rows.
- False-green: keep `CONFIGURED ≠ LIVE` wording; do not promote `--deep` Graphify stdio or `reload_required` to PASS.
- Stale `lib/sb-doctor/checks.sh` consent-only loop: delete, regenerate, or keep tests that prove live D10 does not use it.
- **`docs_pin` backfill:** every coverage-table row already in D10 (Graphify, agentmemory, RTK, Context Mode, LeanCTX, Alumnium, `cross_tool`) records official URL + commit/tag/ref. Required by F4/AC 1; do it in this phase, not only for `search_cli`.

### Phase 3 — freeze Omni four-surface as its own component

Only after phases 1–2. Still Session A (opted-in completeness), **not** Session B.

**Gate:** `scripts/install-omniroute-sb.sh` (WS6) must exist in-tree before Phase 3 `--fix` install work. If it does not, **defer** Phase 3 (no partial install `--fix`, no duplicate installer). Doctor may report Omni planned/unavailable.

- Add `recommended_tools.omniroute` (locked JSON key; D10 id `D10-omniroute`) with Alumnium-style extra-tool consent.
- **Reconciler registration (required, same bar as `search_cli`):** registry entry, `RT_COMPONENT_IDS` / extra-tool list, `rt_run_component` dispatch, `rt_scope_includes_component` (scopes that may verify/repair Omni — not Graphify stuffing), SKILL D10 row, N/A-vs-FAIL tests. A JSON key plus an uncalled `probe-omniroute.sh` is not Phase 3 done.
- `probe-omniroute.sh` + install script owned by WS6; doctor/docs owned by WS7.
- Surfaces: Setup (binary, daemon `:20128`, compression/memory off, **current-host CLI** present — not all five); Health (daemon ping; **`chat_admission_busy` → WARN**, daemon alive/saturated — not FAIL, not restart); Diagnosis (provider expired → **WARN**, missing CLI → FAIL when opted in); `--fix` (install/restart **only if the WS6 installer has landed**; restart a **dead** daemon only; **not** busy; **not** expired OAuth). **OAuth consent stays fully manual** — doctor must not automate a browser/OAuth click. “One click” in freeze language means the human still performs OAuth; `--fix` only install/restart.
- Opted-out → PASS N/A / `disabled`.
- Do not fold this into Graphify probes.
- Do not edit the freeze plan file; implement in doctor/skill/tests/docs only.

### Phase 4 — later fail-closed doctor plugin interface (allowlisted only)

After Omni, if still in Session A budget: a **module contract** (probe + repair + N/A + `--fix` test + docs pin) so *new allowlisted* tools do not require a one-off special case. Still fail-closed. Still not “fix any tool from a URL.” Session B remains rejected.

---

## Test plan

Prove `--fix`, not only probes. Extend [`tests/scripts/test-silver-doctor.sh`](../tests/scripts/test-silver-doctor.sh) and [`tests/scripts/test-reconcile-recommended-tools.sh`](../tests/scripts/test-reconcile-recommended-tools.sh). Omni phase also [`tests/scripts/test-router-doctor-report.sh`](../tests/scripts/test-router-doctor-report.sh) when that fixture exists (it is not in-tree today).

Rows tagged **per-tool** run once per newly covered tool (minimum: `search_cli`; then Omni; plus at least one existing five-tool `--fix` fixture). Rows tagged **global** apply once to doctor itself — do **not** multiply them per tool.

| Scope | Case | Expected |
|---|---|---|
| per-tool | Opted-out | PASS N/A (`pending`/`disabled`); never FAIL |
| per-tool | Opted-in, CLI/MCP missing | FAIL `D10-<tool>` / `missing_cli` |
| global | `--dry-run` / plan | no writes; doctor still reports |
| per-tool | `--fix=<scope>` on allowlisted fixture | mutates fixture then re-probe → `ready` / PASS (**except** newer-than-pin `version_drift`, which stays WARN) |
| per-tool | `--fix=packages` for `search_cli` | applies **versioned** brew/registry pin matching `docs_pin` when installed is **older** than pin; **must not downgrade** newer; skipped if `rt_scope_includes_component` omits `search_cli` from `packages`; skip with Diagnosis if brew/OS unsupported (`DOCTOR_FIX_APPLIED=0`, WARN-class exit) |
| global | Tampered known-id `install_commands` | refuse execution; no installer |
| per-tool | Installed `search_cli` **older** than `docs_pin` | D10 **WARN** `version_drift`; `--fix=packages` repairs to pin → then PASS |
| per-tool | Installed `search_cli` **newer** than `docs_pin` | D10 **WARN** `version_drift`; `--fix=packages` does **not** downgrade; WARN persists (not a converge-to-`ready` fixture) |
| global | `--fix=all` two **in-scope** coexisting failures | one **ordered pass** converges both; then second apply idempotent; `DOCTOR_FIX_APPLIED` at end of invocation |
| global | `--fix=local` with D4/D13/D14/D16/D18/D19/D21 failing | does **not** run those host mutations |
| global | `/sb:doctor` alias | same runner/skill as `/silver:doctor`; `--fix` / `--dry-run` forwarded (not docs-only) |
| global | Confirmation unobtainable **when a confirm-class mutation is planned** (non-TTY without assume-yes **or** TTY decline/EOF) | **no writes** for that `--fix`; nonzero; receipt not-applied |
| global | Vendor-doctor skip | recorded skip, **not** Health evidence; remaining checks decide PASS/FAIL; skip never PASSes the component alone |
| per-tool | Phase 3 Omni busy | WARN `busy`; no restart-for-busy |
| per-tool | Phase 3 Omni provider expired | WARN `provider_expired`; OAuth manual; no `--fix` re-auth |
| per-tool | Opted-in `search_cli` missing CLI on Claude/Codex | FAIL `D10-search_cli` (not PASS N/A / `fu=1`) |
| per-tool | PATH without version (`search_cli`) | not Health PASS |
| per-tool | Provider-missing (`search_cli`) | WARN `provider_missing` (ready Health + warning evidence); not FAIL; no dumped key |
| global | Second `--fix` | idempotent |
| global | Failed/malformed apply JSON | not applied; nonzero; stderr kept; receipt not success |
| global | JSON / stdout / stderr / receipts | no secrets; JSON stdout parseable |
| global | Repair-dispatch (each advertised `--fix` action) | named scope/script is wired; one live five-tool fixture is not enough |
| global | Unsupported host `cross_tool` | WARN; must not recommend `--fix=host` (already present — keep) |
| global | Unknown component id | PASS N/A reason `unsupported`; no installer; no `--fix` suggestion |
| global | Opted-in unknown JSON key | WARN `unknown_key` with the key name; doctor exit **nonzero**; other components not FAIL-poisoned |
| global | WARN-only tree (no FAIL; may include Graphify skew) | doctor exit **zero** |
| global | FAIL tree | doctor exit **nonzero** |
| global | Duplicate leanctx/lean-ctx MCP keys (opted in) | D10 FAIL `D10-leanctx` / `duplicate_key`; D22 WARN label does not downgrade D10 |
| global | `cross_tool` no five-tool consent | D10-routes **PASS** (not PASS N/A, not WARN) |
| global | Absent `recommended_tools` key | PASS N/A `pending`; do not scaffold the key into the project file |
| global | Config↔allowlist↔SKILL parity | every `.silver-bullet.json` `recommended_tools` key + derived `cross_tool` (+ `omniroute` in Phase 3) is in `RT_COMPONENT_IDS` / extra-tool list, registry, `rt_run_component`, and SKILL D10 table |
| global | Vendor-doctor skip (hermetic/live path) | keep `RT_SKIP_VENDOR_DOCTOR=1` in unit tests; one hermetic/live path still proves skip ≠ Health (pairs with the skip-is-not-evidence row above) |
| global | Stale checks.sh consent-only PASS | D10 must not use that loop; tests fail if live D10 uses it; canary that only the stale loop could turn green stays non-green |
| global | MCP key present, session tools not proven | CONFIGURED, not Health PASS (`reload_required` stays non-green) |
| global | Health URL without proving opted-in instance | **WARN** with identity evidence (not Health PASS; not FAIL solely because a port responds) |
| global | `min_version` below pin (RTK / CM / LeanCTX) | **FAIL**; Graphify skill vs package skew → **WARN** |
| global | `--fix` with packages/daemon (CI) | applies when `SB_DOCTOR_ASSUME_YES=1` **and** a confirm-class mutation is planned |
| global | Phase 3 Omni | [`test-router-doctor-report.sh`](../tests/scripts/test-router-doctor-report.sh) green in addition to the two doctor/reconciler scripts, **when that fixture exists** |

Targeted commands while iterating:

```bash
bash tests/scripts/test-silver-doctor.sh
bash tests/scripts/test-reconcile-recommended-tools.sh
bash scripts/sb-doctor.sh --dry-run
# Phase 3 only:
bash tests/scripts/test-router-doctor-report.sh
```

Do not claim Session A done on SKILL wording alone. Do not require `bash tests/run-all-tests.sh` for every probe tweak; do require the two doctor/reconciler scripts green before calling the phase done.

Sync: `bash scripts/sync-codex-package.sh` after SKILL edits. If doctor-facing SKILL/command text changes, also `bash scripts/generate-plugin-commands.sh`.

---

## Out of scope / MUST NOT

From review `759a2827`, binding on Session A:

- A generic “run whatever `install_commands` / curl|bash / npx the agent found in a SPA” installer for unknown tools.
- Reading, printing, or writing API keys, `.env`, MCP `env` blocks, OAuth tokens, `~/.codex/auth.json`, or provider keys into doctor **stdout, stderr, JSON reports, or receipts**.
- Bypassing five-tool routed ownership or enabling overlapping LeanCTX shell/sandbox/fetch MCP.
- Treating “arbitrary tool setup” as “any MCP the user named in Cursor settings.”
- Nested Task/subagent that Googles install docs and executes them; Pi/Omni **as the doctor implementer** for this work (Omni is a *patient* in phase 3, not the worker).
- Silent `git checkout` / `git switch` / `SetActiveBranch`.
- Inventing a parallel doctor next to `sb-doctor.sh`.
- Claiming live MCP tool liveness from `mcp.json` or `command -v` **alone**.
- Recommending `--fix=host` for `cross_tool unsupported` on non-Cursor hosts.
- FAIL on opted-out tools (Alumnium / `search_cli` / Omni unset must be PASS N/A).
- Key-stealing “diagnosis” that dumps host MCP env to prove Health.
- Editing [`.planning/router_subagent_surfaces_85bf9f09.plan.md`](router_subagent_surfaces_85bf9f09.plan.md).
- Committing unless a later human asks.
- Fast effort / Fast model slugs.
- Session B unbounded arbitrary-tool autonomy in the same implementation session.

---

## Acceptance criteria / done when

Session A is done when all of the following are true:

1. **Coverage table** exists in [`skills/silver-doctor/SKILL.md`](../skills/silver-doctor/SKILL.md) with the F4 schema for every current `recommended_tools` key, including `search_cli`, **and** a derived `cross_tool` / `D10-routes` row. Omni **F4 schema rows exist only after phase 3**, clearly labeled WS7 / extra-tool. If phase 3 is deferred, add a **coverage-table footnote / planned note** (“planned WS7, not D10 Graphify”) — **not** an F4 schema row. Every F4 row has a `docs_pin` (`cross_tool` uses the SB mutex contract at a Silver Bullet commit/ref).
2. **`search_cli` is a live D10 extra-tool** (registry + probe + N/A vs FAIL tests on Cursor/Claude/Codex + **`--fix=packages` proof** + `rt_scope_includes_component` packages), not merely a JSON key.
3. **`--fix` no longer marks success on swallowed/empty/malformed/failed reconciler JSON.** Dry-run writes nothing. Secrets absent from stdout, stderr, JSON, and receipts (tested). JSON stdout stays parseable.
4. **At least one existing allowlisted tool** has an automated `--fix` fixture (broken → apply → ready → second apply idempotent), not only Alumnium probe N/A vs FAIL, **plus** repair-dispatch/plan coverage for every advertised `--fix` action, **plus** one `--fix=all` fixture with two **in-scope** coexisting failures that converges in one **ordered pass**, **plus** `--fix=local` does not run D4 / D13/D14/D16/D18/D19 / D21.
5. **Unknown tools fail closed.** No generic SPA installer. Known-id swapped `install_commands` refuse execution. Opted-in unknown JSON key → WARN `unknown_key` + nonzero (not a silent green tree). Config↔allowlist↔SKILL **parity test** required (F-7-1).
6. **`/silver:doctor` is the implementation; `/sb:doctor` is the same public alias**, proven by a test that both names resolve to [`scripts/sb-doctor.sh`](../scripts/sb-doctor.sh) / the same skill and forward `--fix` / `--dry-run`. Documentation alone is not enough.
7. **Omni**, if phase 3 is included in the same session: WS6 installer must already exist; **registry + `rt_run_component` + scopes + SKILL + N/A-vs-FAIL** (not an inert JSON key); four freeze surfaces; current-host CLI only; busy → WARN no restart; provider expired → WARN, OAuth manual; not stuffed into Graphify probes. If phase 3 is deferred, a coverage-table **footnote** lists Omni as “planned WS7, not D10 Graphify” (not an F4 row).
8. **`bash tests/scripts/test-silver-doctor.sh`** and **`bash tests/scripts/test-reconcile-recommended-tools.sh`** green. If phase 3 is included: **`bash tests/scripts/test-router-doctor-report.sh`** green as well (when that fixture exists). SKILL synced via `scripts/sync-codex-package.sh`. If doctor-facing SKILL/command text changes, also `bash scripts/generate-plugin-commands.sh`. Does not require full `run-all-tests.sh`.
9. **Stale consent-only D10 path** is proven unused. Tests must **fail** if live D10 uses `checks.sh` consent-only PASS. Pair that with a **canary fixture that only the stale loop could turn green**, and assert the canary stays **non-green**. That is the positive done signal (not a double negative).
10. **No freeze-file edits, no branch switch, no commit** unless the human later asks.
11. **Session A defaults locked in this PRD** are implemented (not re-litigated): Omni key `omniroute`; search_cli Health = PATH + version; search_cli hosts = Cursor/Claude/Codex (not Cursor-only `rt_host_supported`); brew pin is **versioned** and matches `docs_pin`; `--fix=packages` **must not downgrade** newer-than-pin; `SB_DOCTOR_ASSUME_YES=1` for non-interactive `--fix` **when a confirm-class mutation is planned**; **confirmation unobtainable** (non-TTY without that flag **or** TTY decline/EOF) → **no writes** for that `--fix`; Graphify skill/package skew is D10 WARN (`--fix` none); RTK/CM/LeanCTX `min_version` below pin is **FAIL**; vendor-doctor skip is not Health evidence; known-id `install_commands` are pinned in [`hooks/lib/recommended-tools-registry.sh`](../hooks/lib/recommended-tools-registry.sh); Phase 3 gated on WS6 installer **and** reconciler registration; `--fix=all` is one ordered in-scope pass; absent keys ≡ PASS N/A `pending`; FAIL → nonzero, WARN → zero except `unknown_key`.

Phase 4 plugin interface is **not** required to close Session A.

---

## Open questions

### Session A defaults (locked — implement these; do not block on re-asking)

1. **Omni key name.** Use `recommended_tools.omniroute` and D10 id `D10-omniroute`. Override only if freeze YAML later names a different key.
2. **search_cli Health depth.** Default D10 = CLI on PATH **plus** non-secret version. Provider-missing is **WARN** via ready Health plus warning evidence (not `ready` PASS, not `repairable` FAIL), never a dumped key. Deep Research `deep`/`ultradeep` is **not** a D10 FAIL. **Host support:** Cursor, Claude, and Codex. Do not copy Alumnium Cursor-only `rt_host_supported`.
3. **`--fix` confirmation UX.** Tests and CI use **`SB_DOCTOR_ASSUME_YES=1`** when a confirm-class mutation is **planned**. Humans still confirm packages/network/daemon restart on a TTY. The gate is **plan-triggered** (ordered pass would execute a confirm-class mutation), not “`--fix=packages` was requested.” **Confirmation unobtainable** (non-TTY without the flag, **or** TTY decline/EOF) **when planned**: **no writes** for that `--fix` invocation; nonzero; never hang.
4. **Vendor-doctor skip in CI.** Keep `RT_SKIP_VENDOR_DOCTOR=1` in unit tests. Require **one live or hermetic vendor-doctor path** in reconciler tests so skip cannot masquerade as Health. Phase 2 owns this.
5. **Graphify min_version.** Do **not** add a Graphify `min_version` pin in config in Session A. D10 **WARN** on the known skill vs package skew; PATH-only is not Health PASS.

### Still open (do not block Session A close)

6. **Phase 3 in the same session vs follow-up.** SCOPE_FORK order says Omni after `search_cli`. If timeboxed, defer Omni with a coverage-table **footnote** (“planned WS7”), not a partial probe and **not** an F4 schema row. Phase 3 `--fix` install also waits for the WS6 installer.
7. **Stale `lib/sb-doctor/{checks,fix}.sh`.** Delete vs generate-from-runner. Tests already forbid using them for D10; pick one in implementation to avoid a third doctor.

---

## Appendix: copy-paste implementer prompt

Paste the following into a new session together with this PRD. Do not implement Session B.

```text
Implement Session A only from .planning/PRD-silver-doctor-opt-in-coverage.md
(Silver Bullet doctor coverage for every opt-in recommended tool).

Workspace: the silver-bullet repo. Stay on the current git branch.
Do NOT git checkout/switch. Do NOT SetActiveBranch.
Do NOT edit .planning/router_subagent_surfaces_85bf9f09.plan.md.
Do not commit unless asked. No Fast.

Freeze: implement /silver:doctor. /sb:doctor is the public alias of the same
doctor. One runner: scripts/sb-doctor.sh. Do not invent a parallel doctor.

SCOPE: Session A = D10 completeness for every .silver-bullet.json
recommended_tools key, using the existing reconciler + probe contract.
Session B = unbounded arbitrary-tool installer. Session B is forbidden.

Order:
1) Close search_cli (canary) on the extra-tool consent/registry pattern
   (not Alumnium Cursor-only host gate): registry + probe-search_cli.sh +
   RT_COMPONENT_IDS + rt_scope_includes_component packages + SKILL D10
   row + N/A vs FAIL tests on Cursor, Claude, and Codex + bounded
    --fix=packages. Health = PATH + version matching docs_pin (WARN on
    formula/version drift). Versioned brew pin, not floating latest.
    Consult official search-cli docs for that pinned version; record
    URL@ref. Missing brew/unsupported OS: FAIL missing CLI, do not
    suggest a brew repair. Do not dump provider keys.
    Keep required_when_enabled: false (hook enforcement, not audit
    honesty — D10 still FAILs opted-in missing CLI).
2) Remaining D10 gaps: --fix must not swallow reconciler stderr or mark
   DOCTOR_FIX_APPLIED on empty JSON; dry-run writes nothing; prove --fix
   on a fixture (not only probes); vendor-doctor skip ≠ Health PASS;
    one hermetic/live vendor-doctor path so skip cannot masquerade as Health
    (skip is not Health evidence; remaining checks decide);
    prove --fix=all converges two in-scope coexisting failures in one
    ordered pass (close first-match break; --fix=local never runs D4 /
    D13/D14/D16/D18/D19 / D21); prove /sb:doctor is an executable alias
    of the same runner (not docs-only); RTK/CM/LeanCTX min_version below
    pin is FAIL; Graphify skill/package skew is WARN; CONFIGURED ≠ LIVE; stale
   scripts/lib/sb-doctor/checks.sh consent-only loop must not be D10.
3) Freeze Omni four-surface as its OWN WS7 component (omni-agent-doctor):
    JSON key recommended_tools.omniroute / D10-omniroute plus registry,
    rt_run_component, scopes, SKILL, N/A-vs-FAIL (not an inert key).
    Setup, Health, Diagnosis, Troubleshooting/--fix for daemon/providers/
    current-host CLI only. chat_admission_busy → WARN, no restart-for-busy;
    provider expired → WARN, OAuth stays manual.
    Do NOT stuff Omni into Graphify/RTK probes. Gate Phase 3 --fix install
    on scripts/install-omniroute-sb.sh existing. If timeboxed, defer with a
   coverage-table footnote (“planned WS7”), not an F4 schema row and not a
   partial probe. Omni Setup requires the current doctor host CLI only.
4) Later (optional): fail-closed doctor plugin interface for NEW
   allowlisted tools only — still not Session B.

Live truth (do not “fix” the stale split by editing checks.sh as SoT):
- scripts/sb-doctor.sh (doctor_record_reconciler_d10, doctor_apply_fixes)
- scripts/reconcile-recommended-tools.sh --entry-point doctor-fix
- scripts/lib/recommended-tools/common.sh RT_COMPONENT_IDS and
  rt_scope_includes_component (search_cli in packages)
- skills/silver-doctor/SKILL.md D10 table
- tests/scripts/test-silver-doctor.sh
- tests/scripts/test-reconcile-recommended-tools.sh
  (non-interactive --fix fixtures: SB_DOCTOR_ASSUME_YES=1)
- Phase 3 only: tests/scripts/test-router-doctor-report.sh

Coverage table schema (ship in the SKILL): tool, class, Setup, Health,
Diagnosis, --fix action, N/A rule, host support, docs_pin.

N/A vs FAIL: opted-out PASS N/A never FAIL; opted-in broken FAIL;
unknown tools fail closed; no --fix=host recommendation for non-Cursor
cross_tool unsupported.

--fix blast radius: local/host/packages/all as documented; confirmation
is plan-triggered (fires when the ordered pass would execute a
confirm-class mutation); tests/CI set
SB_DOCTOR_ASSUME_YES=1 so packages/daemon fixtures do not hang;
confirmation unobtainable (non-TTY without that flag or TTY decline/EOF)
when a confirm-class mutation is planned
means no writes for that --fix (nonzero, no hang); receipts;
no secrets in stdout/stderr/JSON/receipts; JSON stays parseable;
idempotent second apply; failed/malformed apply is not success.
--fix=all is one ordered in-scope pass. DOCTOR_FIX_APPLIED is set at
the end of the invocation, not as an intra-invocation early-return.
Known-id install_commands must match hooks/lib/recommended-tools-registry.sh;
tampered payload refuses. Absent keys ≡ PASS N/A pending (no scaffold).
Opted-in unknown JSON key → WARN unknown_key + nonzero.
FAIL → nonzero; WARN → zero except unknown_key. Do not downgrade
newer-than-pin CLIs. Graphify skew WARN is advisory (--fix none).
Config/allowlist/SKILL parity test required.

MUST NOT: SPA curl|bash; dump secrets; bypass five-tool mutex;
lean-ctx init --agent *; nested Task that Googles and executes;
claim Health from mcp.json or command -v alone; FAIL opted-out tools.

Graphify query first. Save agentmemory without secrets. After SKILL
edits: bash scripts/sync-codex-package.sh. If doctor-facing SKILL or
command text changes: also bash scripts/generate-plugin-commands.sh.
After code: graphify update .
Parent will verify evidence, not assertions.
```

---

*End of PRD. Implementer: treat headings in this file as the contract. Review origin: worker `759a2827` plus the original “every SB opt-in tool” brief. Session A only.*
