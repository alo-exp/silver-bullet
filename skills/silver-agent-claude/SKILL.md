---
name: silver-agent-claude
description: On-demand parent-supervised delegation of a single real task to Claude TUI as a subagent — briefings, checkpoints, failure escalation, and completion evidence. Use when the host agent (Codex or Claude parent) should supervise while Claude Code executes in a target project CWD. Not for enterprise E2E matrix runs.
argument-hint: "<task brief> [--work-dir <path>] [--log <path>] [--interaction-mode auto|interactive|non-interactive] [--checkpoint <n>]"
user-invocable: true
version: 0.1.0
---

**Interaction modes:** `--interaction-mode auto|interactive|non-interactive` (default `auto`). Permission `--mode` remains `permissive|strict`. Session continuity requires interactive. Auto-selected NI that misses acceptance gets one interactive retry. Spec: [`docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md`](../../docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md).

**Pinned NI fast path:** `--interaction-mode non-interactive` (or `--non-interactive` / `--use-print` / `--use-exec`) writes `mode.json` `{requested, classified:null, resolved:non-interactive, reason:[pin]}` and execs the native one-shot CLI with no classifier, D3/TUI probe, D4, recommended-tools preflight, quota-retry, or tail-idle watcher. Re-enable wrappers with `--quota-retry` / `AGENT_*_QUOTA_RETRY_MAX` and existing idle env. `auto` still runs the full resolver. Interactive is one native CLI or PTY (`pi` without `-p`).


# /sb:agent-claude — Claude TUI Subagent Delegation

**Plugin root**: `SB_ROOT` is the Silver Bullet plugin root, the installed plugin unless a fixture overrides it, two directories above this file (`${SB_ROOT}/skills/silver-agent-claude/SKILL.md`). Run Silver Bullet scripts and read its templates through `${SB_ROOT}`, never relative to the project working directory: a downstream project does not contain them.

On-demand, **single-task** supervision model: the **host parent** plans, briefs, checkpoints, and escalates; **Claude TUI** executes in the target project working directory.

**Contrast with Sidekick:** Sidekick is session-persistent (quality gates, cross-session advisor). This skill activates **per task** and tears down when the task completes or escalates.

**Contrast with `/sb:agent-codex`:** Multi-host on-demand delegation siblings. Use **agent-claude** when Claude Code TUI is the intended executor; use **agent-codex** for Codex CLI.

**Contrast with enterprise E2E matrix:** Reuses proven Claude invoke harness (`claude-interactive-invoke.expect`, OAuth auth, idle/quiet timeouts, 429 retry, isolated `CLAUDE_CONFIG_DIR`). Does **not** load matrix ledger, §5b product gates, fixture branch locks, or row outcome writers.

---

## When to use

| Use `/sb:agent-claude` | Delegate inline or via host Task instead |
|----------------------------|------------------------------------------|
| Host is Codex and Claude is the preferred executor for the target repo | Host can edit directly with lower latency |
| Task needs Claude-native SB hooks/skills in **real** project CWD | Pure SB-repo work on the host checkout |
| Parent wants Sidekick-like supervision (brief → checkpoint → escalate) for one bounded task | Full SB composer queue (`sb:feature`, orchestrator workers) |
| Cross-host handoff: "run this in Claude while I supervise" | Enterprise E2E matrix certification (use matrix harness) |

---

## Roles

| Role | Agent | Responsibilities |
|------|-------|------------------|
| **Parent (supervisor)** | Codex / Claude parent session | Task brief, acceptance criteria, checkpoints, failure ladder, mentor notes, graphify retrieval, agentmemory capture |
| **Worker (executor)** | Claude TUI in `CLAUDE_WORK_DIR` | Implement, test, commit per brief; report blockers in final message |

Parent **must not** implement the delegated task in parallel in the same files. Parent may fix harness blockers in SB repo only.

---

## Activation (on-demand)

1. Parent receives a delegatable task (user request or orchestrator handoff).
2. Parent invokes **`/sb:agent-claude`** with a structured brief (below).
3. Parent runs `bash "${SB_ROOT}/scripts/agent-claude/invoke.sh"` (preflight + env + delegate) **once per delegation wave**.
4. On completion or escalation, parent records evidence and clears delegation state.

No session-persistent marker is written. Each invocation is independent.

---

## Parent orchestrator rules

When `orchestrator_mode` is `parent` in `.silver-bullet.json`:

1. Parent **may** invoke this skill directly (host→Claude bridge; hook allows `agent-claude/invoke.sh` with degraded fallback or `agent-claude-delegate.sh`).
2. Parent **must not** Edit/Write project source for work delegated to Claude — supervise only.
3. Alternative: `silver-bullet invoke-skill sb:agent-claude` then run delegate.sh.
4. For SB-repo harness fixes blocking delegation, spawn a worker or use `SB OVERRIDE:` with audit reason.
5. After Claude completes, parent verifies acceptance criteria before claiming done.

**Logs:** write under `.planning/agent-claude/` (gitignored). Do not commit claude-run logs — they may contain secrets.

---

## AF-AGENT-DELEGATE worker path (default-on)

**`SB_AGENT_DELEGATE_V2`** defaults on (unset → worker path). Set **`SB_AGENT_DELEGATE_V2=0`** to rollback to legacy routing without the native worker gate.

Use the canonical delegation atomic flow instead of direct wrapper supervision:

1. Complete **FS-DELEGATE-BRIEF** (brief + `ownership_scope` path prefixes).
2. Call **`sb_orchestrator_seed_delegation_directive`** (`host=claude`, `task_id`, `brief_path`, ownership JSON).
3. Spawn native worker from the plugin template **`${SB_ROOT}/templates/orchestrator-workers/AGENT-DELEGATE.md`** (Task subagent; never the project copy).
4. Worker launches `agent-claude-delegate.sh`; external agent loads **`silver-agent-worker`** contract.
5. Host runs **FS-DELEGATE-MENTOR** — verify evidence vs brief before user report.

**Degraded fallback only:** direct `agent-claude-delegate.sh` from parent requires `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` or audited `SB OVERRIDE:` (emits `EV-DELEGATE-DEGRADED-FALLBACK`). Not the happy path.

---

## Step 1 — Brief (parent)

Produce a delegation brief before invoke:

```markdown
## Task
<one paragraph — what Claude must deliver>

## Acceptance criteria
- [ ] <observable outcome 1>
- [ ] <observable outcome 2>

## Constraints
- Branch: <name or create>
- Do not: <scope limits>
- SB routes (if any): /sb:plan → /sb:execute (Claude picker syntax)

## Evidence required
- Commit SHA or explicit "no commit" rationale
- Tests run + result
- Files touched (paths)
```

Save to `.planning/agent-claude/<task-id>/brief.md` when the task spans multiple checkpoints.

**Graphify (parent, before brief):** `graphify query "<task scope files hooks>"`  
**agentmemory:** capture brief + routing decision.

---

## Step 2 — Environment (isolation)

Set explicitly — **fixture vs real project**:

| Variable | Real product project | SB fixture / live-test |
|----------|---------------------|-------------------------|
| `CLAUDE_WORK_DIR` | Target repo root (e.g. `enterprise-grade-test-app`) | Fixture clone path |
| `SB_ROOT` | Plugin root (default: the installed plugin; the host adapter ships in `scripts/lib/agent-adapters/`, no SB clone needed) | SB repo checkout |
| `SB_AGENT_CLAUDE_FIXTURE` | `0` (default) | `1` — enables live-test guard patterns |
| `SB_AGENT_CLAUDE_LIGHTWEIGHT` | `1` (delegate default) | `0` — keep full MCP boot in child |
| `SB_LIVE_CLAUDE_ISOLATION_ACTIVE` | `0` unless isolating config | `1` for hermetic live tests |

**Do not set** `SB_E2E_ENTERPRISE_MATRIX`, `SB_E2E_LEDGER_FILE`, or matrix batch PID files for normal delegation.

### Harness env (reuse)

| Env | Default | Purpose |
|-----|---------|---------|
| `CLAUDE_INTERACTIVE_TIMEOUT` | 900 | Hard PTY timeout (seconds) |
| `CLAUDE_INTERACTIVE_QUIET_TIMEOUT` | 120 | Quiet-after-activity complete |
| `CLAUDE_INTERACTIVE_READY_TIMEOUT` | 20 (harness); **120** via delegate | Prompt acceptance |
| `SB_AGENT_CLAUDE_MODEL_READY_TIMEOUT` | 120 | Delegate override for ready timeout when model boot is slow |
| `CLAUDE_INTERACTIVE_IDLE_TIMEOUT` | 1800 (harness); **3600** via delegate | Idle watchdog |
| `AGENT_CLAUDE_QUOTA_RETRY_INTERVAL` | 60 | 429 / quota backoff |
| `AGENT_CLAUDE_QUOTA_RETRY_MAX` | 5 | Max quota retries |
| `CLAUDE_USE_INTERACTIVE` | 1 (delegate) | Force expect TUI path |
| `RTK_DISABLED` | 1 | Set during delegate for readable ops logs |
| `SB_ORCHESTRATOR_WORKER` | 1 (lightweight) | Claude child executes directly — hooks must not spawn parent Task workers |
| `SB_ORCHESTRATOR_PARENT` | 0 (lightweight) | Paired with worker flag for exec/PTY subprocess |
| `SB_AGENT_CLAUDE_LOG_FLOOR` | 512 | Minimum log bytes for PASS evidence (§5b adapted) |
| `AGENT_CLAUDE_MONITOR_INTERVAL` | 30 | Parent `monitor.sh` poll interval (seconds) |

Optional: `CLAUDE_MODEL` (default `sonnet`), `CLAUDE_EFFORT` (default `low`).

### Auth policy

- **OAuth / Keychain** via `claude auth login` — preflight checks auth status.
- **No mid-delegation key rotation** — auth failures escalate to user.
- **No inherit-keys shortcuts** (E2E-110) — do not paste API keys into briefs; `agent-delegate-common.sh` rejects secret patterns.
- Proxy/MiniMax hosts: document Claude host settings env (under isolated `CLAUDE_CONFIG_DIR`); delegate inherits caller auth (not `env -i` clean-env).

---

## Step 3 — Invoke (parent)

**Path policy:** `--log` and `--brief-file` may be repo-relative; `agent-claude-delegate.sh` canonicalizes them to **absolute paths** before read/write (relative paths resolve from their parent directory, not `CLAUDE_WORK_DIR`). Prefer absolute paths in briefs and automation to avoid ambiguity.

**Preflight (mandatory):**

```bash
export SB_ROOT=/path/to/silver-bullet/repo
bash "${SB_ROOT}/scripts/agent-claude/preflight.sh" --sb-root "$SB_ROOT"
```

**Launch (recommended path):**

```bash
export CLAUDE_WORK_DIR=/path/to/target/project

bash "${SB_ROOT}/scripts/agent-claude/invoke.sh" \
  --work-dir "$CLAUDE_WORK_DIR" \
  --brief-file .planning/agent-claude/<task-id>/brief.md \
  --log .planning/agent-claude/<task-id>/claude-run.log
```

Inline prompt (small tasks):

```bash
bash "${SB_ROOT}/scripts/agent-claude/invoke.sh" \
  --work-dir "$CLAUDE_WORK_DIR" \
  --prompt "Add GET /api/health returning {status: ok}. Run tests. Commit on branch feature/..." \
  --log .planning/agent-claude/smoke/claude-run.log
```

**Parent monitor (channel timeline)** — run in a second terminal while Claude works:

```bash
bash "${SB_ROOT}/scripts/agent-claude/monitor.sh" --log .planning/agent-claude/<task-id>/claude-run.log
```

Monitor emits checkpoint bullets: prompt submitted, byte growth, log-floor status, stall/auth/quota signals. Do **not** claim PASS on 0-byte or sub-floor logs.

**Print fallback** when expect/PTY unavailable:

```bash
bash "${SB_ROOT}/scripts/agent-claude/invoke.sh" --use-print --work-dir "$CLAUDE_WORK_DIR" --brief-file ...
```

Parent should prefer interactive TUI for supervision; use `--use-print` only after a `stuck`/`harness` timeout or when automation requires non-PTY.

Direct `scripts/agent-claude-delegate.sh` remains for worker/orchestrator paths; production parents should use `invoke.sh`.

Claude route prefix in prompts: use `/sb:*` or `[$silver]` (Claude picker), not `$sb:*` (Codex).

---

## Step 4 — Supervision model (checkpoints)

Sidekick-inspired **single-task** lifecycle:

| Phase | Parent action |
|-------|---------------|
| **Brief** | Issue brief + acceptance criteria |
| **Launch** | Run delegate.sh; tail log |
| **Checkpoint 1** | Confirm Claude acknowledged task (log shows prompt submitted) |
| **Checkpoint 2** | Mid-task: if idle > 5 min with no log growth, prepare escalation |
| **Complete** | Verify acceptance criteria against git diff / test output / commit |
| **Mentor note** | Short retrospective: what worked, what to change next delegation |

### Failure escalation ladder

| Class | Signals | Parent action |
|-------|---------|---------------|
| **Stuck** | Idle timeout, no post-submit output, `Queued follow-up` | Re-brief with narrower scope; Enter-wake (E2E-081); retry once |
| **Quota (429)** | provider error lines only (`Error:`/`API Error:` lines, HTTP status lines, JSON error objects, provider quota sentences); a bare `429` or `quota` in test output or file names is not one; the unchanged-tree check sees tracked and untracked files but not git-ignored files, writes outside the work dir, or changes past the first 4 MiB of a large untracked file | delegate re-runs only if the work dir is unchanged since the attempt (git) or `--quota-retry` was passed; 5-hour/weekly windows are never short-retried; if exhausted, schedule resume |
| **Auth** | `auth`, `login`, `not logged in` | Stop — user must refresh Claude credentials; do not rotate keys in prompt |
| **Harness** | `ERROR:` from expect harness | Fix SB harness; file issue if reproducible |
| **Product** | Claude completed but acceptance fails | New brief with gap list; do not claim PASS |
| **Log floor** | Log < `SB_AGENT_CLAUDE_LOG_FLOOR` bytes with no brownfield waiver | FAIL — extend timeout or fix harness path |
| **0-token stall** | Splash banner, mode banner, no post-submit tokens | Harness Enter-wake (E2E-081); operator auth if banner blocks submit |

Escalate to user when: auth required, two stuck retries fail, or acceptance criteria impossible without locked decision.

### R9 harness learnings (production delegation)

| Learning | Delegation application |
|----------|------------------------|
| **E2E-081 submit order** | Enter-wake for 0-token banner must not starve `/sb:*` route submit — parent verifies `prompt submitted` in log before checkpoint 2 |
| **E2E-105** | Fresh `CLAUDE_CONFIG_DIR` + `${SB_RUNTIME_STATE_DIR}` per delegation wave in lightweight mode |
| **E2E-110** | No inherit-keys shortcuts — OAuth auth policy documented; brief secret scan enforced |
| **Stale locks** | Do not reuse `.e2e-live-test*.lock` from matrix; delegation clears matrix env |
| **SB-only plugins** | `preflight.sh` validates Claude install surface |
| **Channel timeline** | Parent runs `monitor.sh` bullets between checkpoints |

---

## Step 5 — Completion criteria (§5b adapted for production delegation)

Delegation is **PASS** only when **all** hold:

1. Log ends without harness `ERROR:` (exit 0 from delegate.sh).
2. Log size ≥ `SB_AGENT_CLAUDE_LOG_FLOOR` (default 512 B) **or** documented brownfield waiver with file:line pre-existence proof.
3. Every acceptance criterion checked with evidence (commit SHA, test command output, or file paths).
4. **Committed product delta** on target branch when brief requires code change — uncommitted dirty tree alone is insufficient.
5. Parent recorded summary in `.planning/agent-claude/<task-id>/result.md` or agentmemory.
6. `graphify update .` run in repos Claude modified (when graphify enabled).

**FAIL** if any criterion unmet — document `failure_class`: `stuck` | `quota` | `auth` | `harness` | `product` | `log-floor` | `0-token`.

Honest outcomes: do not claim PASS on timeout-only logs, inherited baseline artifacts, or parent-routing-only with zero worker delta.

---

## Step 6 — Capture (mandatory)

**agentmemory:** delegation brief, log path, commit SHA, PASS/FAIL, escalation taken.  
**Graphify:** `graphify query "agent-claude delegation outcomes"` after save + update.

---

## Security (delegation boundary)

| Risk | Mitigation |
|------|------------|
| **Secrets in brief/log** | Best effort, not a guarantee. One linear-time scanner (`scripts/lib/agent_redact.py`) serves the brief check and the log redactor. `agent-delegate-common.sh` refuses a brief that holds a literal credential and names the rule and line; logs and Codex transcripts are redacted (names, schemes and prefixes kept, JSONL lines re-serialized so a transcript stays valid JSONL). Guarantee: every value the scan refuses is also redacted in logs, and the scan runs in time linear in the input (checked by ratio tests, not by wall-clock claims). What it checks is the rule tables in the module, one row per form: vendor-prefix tokens, secret-named assignments (tiered by the last word of the name), `Authorization`/Bearer headers, CLI credentials (`--password`, `--token`, `mysql -p`, `docker login`, `sshpass`, `redis-cli -a`, `aws configure set`, `curl -u`, ...), URL userinfo, XML, `.netrc` and private-key blocks. Logs are created 0600 and redacted after the run and on interrupt (a SIGKILL leaves the raw 0600 log); the brief itself is still passed to the host CLI as an argument, so it is visible to local `ps`; the pinned non-interactive path (`--interaction-mode non-interactive`) execs the host CLI directly, so its stdout is not passed through the redactor. Only literal values are refused: references (`${VAR}`, `process.env.X`, `vault:`/`op://`/ARN references, YAML tags such as `!Ref`, Key Vault and `%env()%` references), code expressions (calls, subscripts and method chains whose arguments are identifiers, numbers or harmless literals, type annotations), placeholders (`(sensitive value)`, `<redacted>`, `***`, `known after apply`), file paths and UUID request/session ids are accepted; a credential name given as a string subscript or as the first literal argument of a call (`define('DB_PASSWORD', '...')`, `app.config['SECRET_KEY'] = '...'`) is paired with its value; Python string prefixes in any case (`b'..'`, `rb'..'`, `f".."`, triple quotes), template literals, C# `@".."`, Rust `r#".."#` and Ruby `%q()` are read as one literal; a literal fallback behind a reference (`process.env.X || 'lit'`, `${VAR:-lit}`, `x | default('lit')`, `os.getenv('X') or 'lit'`) is judged like any literal (empty, trivial and placeholder defaults stay honest), (identifiers inside calls are not secrets: UUIDs, ARNs, resource names, digests, SHAs, URLs without userinfo and paths, unless the parameter itself is named like a credential, e.g. `client_secret=`), and so are the literal arguments of `SecretStr(...)`/`set_password(...)`/`login(user, '...')`. Limits: one call handles at most 16 MiB (`SB_REDACT_MAX_BYTES`, bytes) and 60 s (`SB_REDACT_BUDGET_SEC`, clamped to 0-600; junk, zero, negative, `nan` or `inf` mean 60). Past a limit, or on any internal error, the scan refuses the brief ("too large or too complex to scan"), the redactor withholds the log with a marker, and a transcript whose redaction fails is removed (fail closed). Accepted residuals: (1) unknown formats: a secret with no known vendor prefix under a name that is not credential-like (`MY_THING=<random>`, a bare random token in prose, session cookies under `sessionid=`); (2) weak values: passphrases, dictionary or low-entropy passwords (`correct-horse-battery-staple`, `Spring#2025`), passwords under 8 characters and keys under 16 characters under non-password names are masked in logs when under a credential name but do not block a brief; (3) split secrets: values split across lines, a backslash-newline continuation or string concatenation; (4) encoded or encrypted secrets: base64-wrapped env text, Ansible vault blobs, hex-encoded or doubly URL-encoded values; (5) separator forms outside the grammars: name/value pairs separated only by tabs or spaces outside the netrc, CLI, Dockerfile `ENV`, Markdown-table and name/value (`name:`/`value:`) grammars, YAML folded or literal block scalars (`api_token: >-` with the value on the next line), `.pgpass` colon lines, Terraform maps keyed by a plain name, JSON map values keyed by a host, and CLI tools that are not in the table when they use a non-generic flag whose name carries no credential word, a positional literal argument of a call whose name is not a credential name (`login("user", "pw")`), a bare Heroku CLI uuid and a Rails `master.key` file body; (6) mimicry: values that imitate a reference, placeholder or dummy (a password containing `example`, `test-` or `...`, or one that starts with `${` or `$(`); (7) prose false positives: a prose label such as `pass:` or `token:` followed by a random-looking single token ("this pass: `<sha>`") is refused; (8) inputs over the limits are refused or withheld, not scanned; (9) unchanged: the pinned non-interactive path's stdout is not redacted, the brief is visible in `ps`, and a SIGKILL leaves the raw 0600 log (and, for a Codex TUI capture, a raw `.capture.*` temp file in the private 0700 transcript directory: a named `CODEX_TRANSCRIPT_DIR` is swept of stale ones (older than ten minutes) at the next capture, while a default per-run directory is only removed by the 24-hour sweep of old `sb-codex-transcripts.*` directories); (10) representation: a JSON line that holds a secret is re-serialized (escapes, number spelling and key order may change, duplicate keys collapse), and a JSON object quoted inside a sentence is scanned as text, not decoded; (13) cost: the time is linear, but an input made only of credential-name anchors (a flood of `with_token(` or `define('PASSWORD', `) costs about 4 s per MiB per call, so such a crafted input over roughly 15 MiB exceeds the 60 s budget and is refused or withheld; (12) code shapes that hide a literal (also: nested quotes inside a fallback literal, and a UUID or identifier passed positionally to a call): string concatenation or `join`/`format` of literals, a literal after a placeholder or tag on the same line, YAML anchors (`password: &pw value` masks only the anchor), positional arguments of calls other than `login(...)` and the named setters, heredocs (`<<~EOS`, `<<<EOT`), `ENV.fetch('X') { 'lit' }` and `.unwrap_or(...)` blocks, and lambda or comprehension wrappers; (11) in logs a value under a credential name is masked even when the scan would not refuse it (a dictionary-word passphrase, a prose label such as `pass: merge`, a PEM header mentioned in prose), and an `Authorization` header keeps its scheme word and masks the next word (or everything after it when it holds `name=value` pairs); A refusal can be overridden with `SB_AGENT_ALLOW_SECRET_LIKE_BRIEF=1` set in the user's own shell (announced on stderr; read from the delegate's environment, never from the brief) |
| **Permission mode** | `--mode` defaults to `permissive` only when `--work-dir` has the same git toplevel as the current project (`CLAUDE_PROJECT_DIR`, else the cwd; for a non-git project only that exact directory); a nested clone, another worktree, a fresh clone or a scratch dir defaults to `strict` (the choice is printed). `strict` never adds bypass flags (no hook-trust bypass, workspace-write sandbox on Codex). Override with `--mode` or `SB_AGENT_DELEGATE_DEFAULT_MODE` |
| **Folder trust** | Trust for `--work-dir` is seeded only in the ephemeral `CLAUDE_CONFIG_DIR`. The real `~/.claude.json` is untouched unless `SB_AGENT_CLAUDE_SEED_FOLDER_TRUST_GLOBAL=1` (then: abort on a file that does not parse, one-time `.sb-backup`, temp file + rename) |
| **Matrix env bleed** | `agent-claude/env.sh` clears `SB_E2E_*` ledger/lock vars |
| **Ephemeral CLAUDE_CONFIG_DIR** | Lightweight mode isolates config per wave; destroyed after task |
| **Credential rotation in prompt** | Forbidden — auth failures escalate to user |
| **SB-only plugin surface** | Preflight validates host install |

Run `security` / SENTINEL lens on harness changes under `scripts/agent-claude/` before merge. Delegation logs live under `.planning/agent-claude/` (gitignored) — do not commit.

---

## When parent should not delegate

- Trivial host-local edit (≤3 files, no Claude advantage).
- Task requires host-only tools without Claude equivalent.
- User explicitly wants parent implementation.
- Enterprise E2E matrix row — use matrix harness instead.

---

## References

- Sibling hosts: [`docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md`](../../docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md)
- Harness: `scripts/agent-claude/` (`invoke.sh`, `preflight.sh`, `monitor.sh`, `env.sh`), `scripts/claude-interactive-invoke.expect`, `scripts/agent-claude-delegate.sh`
- Live adapter: `scripts/lib/agent-adapters/claude.sh`
- Auth: `scripts/lib/claude-matrix-auth.sh`
- E2E adapter (matrix only): `scripts/enterprise-e2e/lib/adapters/claude.sh`
- Protocol (matrix): `.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md`
