---
name: "sb:agent-pi"
title: "Agent Pi"
description: On-demand parent-supervised delegation of a single real task to Pi CLI as a subagent — briefings, checkpoints, failure escalation, and completion evidence. Use when the host agent (Codex or Claude parent) should supervise while Pi executes via pi -p in a target project CWD. Not for enterprise E2E matrix runs.
argument-hint: "<task brief> [--work-dir <path>] [--log <path>] [--interaction-mode auto|interactive|non-interactive] [--checkpoint <n>]"
user-invocable: true
version: 0.1.0
---

**Interaction modes:** `--interaction-mode auto|interactive|non-interactive` (default `auto`). Permission `--mode` remains `permissive|strict`. Spec: [`docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md`](../../docs/specs/AGENT-DELEGATION-INTERACTION-MODES.md).

**Pinned NI fast path:** `--interaction-mode non-interactive` (or `--non-interactive` / `--use-print` / `--use-exec`) writes `mode.json` `{requested, classified:null, resolved:non-interactive, reason:[pin]}` and execs the native one-shot CLI with no classifier, D3/TUI probe, D4, recommended-tools preflight, quota-retry, or tail-idle watcher. Re-enable wrappers with `--quota-retry` / `AGENT_*_QUOTA_RETRY_MAX` and existing idle env. `auto` still runs the full resolver. Interactive is one native CLI or PTY (`pi` without `-p`).


# /sb:agent-pi — Pi CLI Subagent Delegation

On-demand, **single-task** supervision model: the **host parent** plans, briefs, checkpoints, and escalates; **Pi CLI** executes in the target project working directory via **`pi -p --provider opencode-go --model mimo-v2.5`** (NI) or **`pi`** without `-p` (interactive REPL).

**Contrast with Sidekick:** Sidekick is session-persistent (quality gates, cross-session advisor). This skill activates **per task** and tears down when the task completes or escalates.

**Contrast with `/sb:agent-codex`, `/sb:agent-claude`, and `/sb:agent-opencode`:** Multi-host on-demand delegation siblings. Use **agent-pi** when Pi CLI (`pi -p`) is the intended executor with MiMo V2.5 via opencode-go; use **agent-opencode** for OpenCode CLI (`opencode run`); use **agent-claude** for Claude Code TUI; use **agent-codex** for Codex CLI.

**Contrast with enterprise E2E matrix:** Reuses proven Pi live adapter (`scripts/lib/agent-adapters/pi.sh`, `pi -p` with tail-idle completion, quota retry, model pin). Does **not** load matrix ledger, §5b product gates, fixture branch locks, or row outcome writers.

---

## When to use

| Use `/sb:agent-pi` | Delegate inline or via host Task instead |
|------------------------|------------------------------------------|
| Host is Codex/Claude and Pi is the preferred executor for the target repo | Host can edit directly with lower latency |
| Task needs Pi-native SB hooks/skills in **real** project CWD | Pure SB-repo work on the host checkout |
| Parent wants Sidekick-like supervision (brief → checkpoint → escalate) for one bounded task | Full SB composer queue (`sb:feature`, orchestrator workers) |
| Cross-host handoff: "run this in Pi while I supervise" | Enterprise E2E matrix certification (use matrix harness) |

---

## Roles

| Role | Agent | Responsibilities |
|------|-------|------------------|
| **Parent (supervisor)** | Codex / Claude parent session | Task brief, acceptance criteria, checkpoints, failure ladder, mentor notes, graphify retrieval, agentmemory capture |
| **Worker (executor)** | Pi CLI in `PI_WORK_DIR` | Implement, test, commit per brief; report blockers in final message |

Parent **must not** implement the delegated task in parallel in the same files. Parent may fix harness blockers in SB repo only.

---

## Activation (on-demand)

1. Parent receives a delegatable task (user request or orchestrator handoff).
2. Parent invokes **`/sb:agent-pi`** with a structured brief (below).
3. Parent runs `bash scripts/agent-pi/invoke.sh` (preflight + env + delegate) **once per delegation wave**.
4. On completion or escalation, parent records evidence and clears delegation state.

No session-persistent marker is written. Each invocation is independent.

---

## Parent orchestrator rules

When `orchestrator_mode` is `parent` in `.silver-bullet.json`:

1. Parent **may** invoke this skill directly (host→Pi bridge; hook allows `agent-pi/invoke.sh` with degraded fallback or `agent-pi-delegate.sh`).
2. Parent **must not** Edit/Write project source for work delegated to Pi — supervise only.
3. Alternative: `silver-bullet invoke-skill sb:agent-pi` then run delegate.sh.
4. For SB-repo harness fixes blocking delegation, spawn a worker or use `SB OVERRIDE:` with audit reason.
5. After Pi completes, parent verifies acceptance criteria before claiming done.

**Logs:** write under `.planning/agent-pi/` (gitignored). Do not commit pi-run logs — they may contain secrets.

---

## AF-AGENT-DELEGATE worker path (default-on)

**`SB_AGENT_DELEGATE_V2`** defaults on (unset → worker path). Set **`SB_AGENT_DELEGATE_V2=0`** to rollback to legacy routing without the native worker gate.

Use the canonical delegation atomic flow instead of direct wrapper supervision:

1. Complete **FS-DELEGATE-BRIEF** (brief + `ownership_scope` path prefixes).
2. Call **`sb_orchestrator_seed_delegation_directive`** (`host=pi`, `task_id`, `brief_path`, ownership JSON).
3. Spawn native worker **`.silver-bullet/orchestrator-workers/AGENT-DELEGATE.md`** (Task subagent).
4. Worker launches `agent-pi-delegate.sh`; external agent loads **`silver-agent-worker`** contract.
5. Host runs **FS-DELEGATE-MENTOR** — verify evidence vs brief before user report.

**Degraded fallback only:** direct `agent-pi-delegate.sh` from parent requires `SB_AGENT_DELEGATE_DIRECT_FALLBACK=1` or audited `SB OVERRIDE:` (emits `EV-DELEGATE-DEGRADED-FALLBACK`). Not the happy path.

---

## Step 1 — Brief (parent)

Produce a delegation brief before invoke:

```markdown
## Task
<one paragraph — what Pi must deliver>

## Acceptance criteria
- [ ] <observable outcome 1>
- [ ] <observable outcome 2>

## Constraints
- Branch: <name or create>
- Do not: <scope limits>
- SB routes (if any): /sb:plan → /sb:execute

## Model pin (mandatory — no drift)
- Provider: opencode-go
- Model: mimo-v2.5
- Invocation: pi -p --provider opencode-go --model mimo-v2.5 (always)
- Do **not** override PI_PROVIDER / PI_MODEL in brief or ephemeral homes — harness rejects drift.

## Evidence required
- Commit SHA or explicit "no commit" rationale
- Tests run + result
- Files touched (paths)
```

Save to `.planning/agent-pi/<task-id>/brief.md` when the task spans multiple checkpoints.

**Graphify (parent, before brief):** `graphify query "<task scope files hooks>"`  
**agentmemory:** capture brief + routing decision.

---

## Step 2 — Environment (isolation)

Set explicitly — **fixture vs real project**:

| Variable | Real product project | SB fixture / live-test |
|----------|---------------------|-------------------------|
| `PI_WORK_DIR` | Target repo root (e.g. `enterprise-grade-test-app`) | Fixture clone path |
| `SB_ROOT` | Plugin root (default: the installed plugin; the host adapter ships in `scripts/lib/agent-adapters/`, no SB clone needed) | SB repo checkout |
| `SB_AGENT_PI_FIXTURE` | `0` (default) | `1` — enables live-test guard patterns |
| `SB_AGENT_PI_LIGHTWEIGHT` | `1` (delegate default) | `0` — keep full MCP boot in child |
| `SB_LIVE_PI_ISOLATION_ACTIVE` | `0` unless isolating config | `1` for hermetic live tests |

**Do not set** `SB_E2E_ENTERPRISE_MATRIX`, `SB_E2E_LEDGER_FILE`, or matrix batch PID files for normal delegation.

### Model policy (MANDATORY)

MiMo V2.5 via **opencode-go** only. Harness, delegate wrapper, and live adapter pin via `agent_pi_pin_mimo_model_env` — any override fails preflight.

| Env | Pinned value | Purpose |
|-----|--------------|---------|
| `PI_PROVIDER` | `opencode-go` | `pi -p --provider` argument |
| `PI_MODEL` | `mimo-v2.5` | `pi -p --model` argument |

Invocation is always `pi -p --provider opencode-go --model mimo-v2.5`. Do **not** set alternate models in briefs, ephemeral config homes, or delegation prompts — no model drift in ephemeral homes.

### Harness env (reuse)

| Env | Default | Purpose |
|-----|---------|---------|
| `PI_RUN_TIMEOUT` | 900 | Hard run timeout (seconds) |
| `PI_RUN_TAIL_IDLE_TIMEOUT` | 45 | Tail-idle complete after activity |
| `AGENT_PI_QUOTA_RETRY_INTERVAL` | 60 | 429 / quota backoff |
| `AGENT_PI_QUOTA_RETRY_MAX` | 5 | Max quota retries |
| `RTK_DISABLED` | 1 | Set during delegate for readable ops logs |
| `SB_ORCHESTRATOR_WORKER` | 1 (lightweight) | Pi child executes directly — hooks must not spawn parent Task workers |
| `SB_ORCHESTRATOR_PARENT` | 0 (lightweight) | Paired with worker flag for subprocess |
| `SB_AGENT_PI_LOG_FLOOR` | 512 | Minimum log bytes for PASS evidence (§5b adapted) |
| `PI_BIN` | auto-resolve | Native CLI path (`/opt/homebrew/bin/pi`, `~/.local/bin/pi`, or PATH) |

Optional: `AGENT_PI_MONITOR_INTERVAL` (default 30) — parent `monitor.sh` poll interval (seconds).

### Auth policy

- **Pi CLI auth** via native install (Homebrew or `~/.local/bin/pi`).
- **No mid-delegation key rotation** — auth failures escalate to user.
- **No inherit-keys shortcuts** (E2E-110) — do not paste API keys into briefs; `agent-delegate-common.sh` rejects secret patterns.
- Delegate inherits caller auth (not `env -i` clean-env).

---

## Step 3 — Invoke (parent)

**Path policy:** `--log` and `--brief-file` may be repo-relative; `agent-pi-delegate.sh` canonicalizes them to **absolute paths** before read/write (relative paths resolve from their parent directory, not `PI_WORK_DIR`). Prefer absolute paths in briefs and automation to avoid ambiguity.

**Preflight (mandatory):**

```bash
export SB_ROOT=/path/to/silver-bullet/repo
bash scripts/agent-pi/preflight.sh --sb-root "$SB_ROOT"
```

**Launch (recommended path — `pi -p` primary):**

```bash
export PI_WORK_DIR=/path/to/target/project

bash scripts/agent-pi/invoke.sh \
  --work-dir "$PI_WORK_DIR" \
  --brief-file .planning/agent-pi/<task-id>/brief.md \
  --log .planning/agent-pi/<task-id>/pi-run.log
```

Inline prompt (small tasks):

```bash
bash scripts/agent-pi/invoke.sh \
  --work-dir "$PI_WORK_DIR" \
  --prompt "Add GET /api/health returning {status: ok}. Run tests. Commit on branch feature/..." \
  --log .planning/agent-pi/smoke/pi-run.log
```

**Parent monitor (channel timeline)** — run in a second terminal while Pi works:

```bash
bash scripts/agent-pi/monitor.sh --log .planning/agent-pi/<task-id>/pi-run.log
```

Monitor emits checkpoint bullets: prompt submitted, byte growth, log-floor status, stall/auth/quota signals. Do **not** claim PASS on 0-byte or sub-floor logs.

Direct `scripts/agent-pi-delegate.sh` remains for worker/orchestrator paths; production parents should use `invoke.sh`.

---

## Step 4 — Supervision model (checkpoints)

Sidekick-inspired **single-task** lifecycle:

| Phase | Parent action |
|-------|---------------|
| **Brief** | Issue brief + acceptance criteria + model pin |
| **Launch** | Run delegate.sh; tail log |
| **Checkpoint 1** | Confirm Pi acknowledged task (log shows `prompt.submitted` / `pi -p`) |
| **Checkpoint 2** | Mid-task: if idle > 5 min with no log growth, prepare escalation |
| **Complete** | Verify acceptance criteria against git diff / test output / commit |
| **Mentor note** | Short retrospective: what worked, what to change next delegation |

### Failure escalation ladder

| Class | Signals | Parent action |
|-------|---------|---------------|
| **Stuck** | Idle timeout, no post-submit output | Re-brief with narrower scope; retry once |
| **Quota (429)** | provider error lines only (`Error:`/`API Error:` lines, HTTP status lines, JSON error objects, provider quota sentences); test output that merely contains `429` or `quota` is not one; the unchanged-tree check sees tracked and untracked files but not git-ignored files, writes outside the work dir, or changes past the first 4 MiB of a large untracked file | short 60s retries only for unknown/transient 429 and only if the work dir is unchanged since the attempt (git, including untracked file contents) or `--quota-retry` was passed; 5-hour/weekly/monthly fail-fast. the 5-hour window is classified and reported (`[agent-pi] quota 5h; window resets in <N>s`); nothing is scheduled, re-run after the window |
| **Auth** | `auth`, `login`, `not logged in` | Stop — user must refresh Pi credentials; do not rotate keys in prompt |
| **OmniRoute/OpenCode 401** | `401`, `Missing API key`, `invalid_api_key` after attempt + one retry | Substitute another available host or model per the review-fix-ladder launcher policy. Never Fast. Never Extra High as unspecified default. Do not skip-failed. |
| **Model policy** | `PI_PROVIDER must be opencode-go` / `PI_MODEL must be mimo-v2.5` | Fix env — harness enforces pin; do not override in brief |
| **Harness** | `ERROR:` from adapter harness | Fix SB harness; file issue if reproducible |
| **Product** | Pi completed but acceptance fails | New brief with gap list; do not claim PASS |
| **Log floor** | Log < `SB_AGENT_PI_LOG_FLOOR` bytes with no brownfield waiver | FAIL — extend timeout or fix harness path |
| **0-token stall** | Banner splash, no post-submit tokens | Operator auth if banner blocks submit; E2E-081 submit-order awareness |

Escalate to user when: auth required, two stuck retries fail, or acceptance criteria impossible without locked decision.

### R9 harness learnings (production delegation)

| Learning | Delegation application |
|----------|------------------------|
| **E2E-081 submit order** | Interactive fallback must not starve route submit — parent verifies `prompt submitted` in log before checkpoint 2 |
| **E2E-110** | No inherit-keys shortcuts — brief secret scan enforced |
| **Stale locks** | Do not reuse `.e2e-live-test*.lock` from matrix; delegation clears matrix env |
| **SB-only plugins** | `preflight.sh` validates Pi install surface |
| **Channel timeline** | Parent runs `monitor.sh` bullets between checkpoints |
| **Model pin** | `agent_pi_pin_mimo_model_env` in harness, delegate, and adapter — no drift across ephemeral homes |

---

## Step 5 — Completion criteria (§5b adapted for production delegation)

Delegation is **PASS** only when **all** hold:

1. Log ends without harness `ERROR:` (exit 0 from delegate.sh).
2. Log size ≥ `SB_AGENT_PI_LOG_FLOOR` (default 512 B) **or** documented brownfield waiver with file:line pre-existence proof.
3. Every acceptance criterion checked with evidence (commit SHA, test command output, or file paths).
4. **Committed product delta** on target branch when brief requires code change — uncommitted dirty tree alone is insufficient.
5. Parent recorded summary in `.planning/agent-pi/<task-id>/result.md` or agentmemory.
6. `graphify update .` run in repos Pi modified (when graphify enabled).

**FAIL** if any criterion unmet — document `failure_class`: `stuck` | `quota` | `auth` | `model-policy` | `harness` | `product` | `log-floor` | `0-token`.

Honest outcomes: do not claim PASS on timeout-only logs, inherited baseline artifacts, or parent-routing-only with zero worker delta.

---

## Step 6 — Capture (mandatory)

**agentmemory:** delegation brief, log path, commit SHA, PASS/FAIL, escalation taken.  
**Graphify:** `graphify query "agent-pi delegation outcomes"` after save + update.

---

## Security (delegation boundary)

| Risk | Mitigation |
|------|------------|
| **Secrets in brief/log** | Best effort, not a guarantee. One linear-time scanner (`scripts/lib/agent_redact.py`) serves the brief check and the log redactor. `agent-delegate-common.sh` refuses a brief that holds a literal credential and names the rule and line; logs and Codex transcripts are redacted (names, schemes and prefixes kept, JSONL lines re-serialized so a transcript stays valid JSONL). Guarantee: every value the scan refuses is also redacted in logs, and the scan runs in time linear in the input (checked by ratio tests, not by wall-clock claims). What it checks is the rule tables in the module, one row per form: vendor-prefix tokens, secret-named assignments (tiered by the last word of the name), `Authorization`/Bearer headers, CLI credentials (`--password`, `--token`, `mysql -p`, `docker login`, `sshpass`, `redis-cli -a`, `aws configure set`, `curl -u`, ...), URL userinfo, XML, `.netrc` and private-key blocks. Logs are created 0600 and redacted after the run and on interrupt (a SIGKILL leaves the raw 0600 log); the brief itself is still passed to the host CLI as an argument, so it is visible to local `ps`; the pinned non-interactive path (`--interaction-mode non-interactive`) execs the host CLI directly, so its stdout is not passed through the redactor. Only literal values are refused: references (`${VAR}`, `process.env.X`, `vault:`/`op://`/ARN references, YAML tags such as `!Ref`, Key Vault and `%env()%` references), code expressions (calls, subscripts and method chains whose arguments are identifiers, numbers or harmless literals, type annotations), placeholders (`(sensitive value)`, `<redacted>`, `***`, `known after apply`), file paths and UUID request/session ids are accepted; a credential name given as a string subscript or as the first literal argument of a call (`define('DB_PASSWORD', '...')`, `app.config['SECRET_KEY'] = '...'`) is paired with its value; Python string prefixes in any case (`b'..'`, `rb'..'`, `f".."`, triple quotes), template literals, C# `@".."`, Rust `r#".."#` and Ruby `%q()` are read as one literal; a literal fallback behind a reference (`process.env.X || 'lit'`, `${VAR:-lit}`, `x | default('lit')`, `os.getenv('X') or 'lit'`) is judged like any literal (empty, trivial and placeholder defaults stay honest), (identifiers inside calls are not secrets: UUIDs, ARNs, resource names, digests, SHAs, URLs without userinfo and paths, unless the parameter itself is named like a credential, e.g. `client_secret=`), and so are the literal arguments of `SecretStr(...)`/`set_password(...)`/`login(user, '...')`. Limits: one call handles at most 16 MiB (`SB_REDACT_MAX_BYTES`, bytes) and 60 s (`SB_REDACT_BUDGET_SEC`, clamped to 0-600; junk, zero, negative, `nan` or `inf` mean 60). Past a limit, or on any internal error, the scan refuses the brief ("too large or too complex to scan"), the redactor withholds the log with a marker, and a transcript whose redaction fails is removed (fail closed). Accepted residuals: (1) unknown formats: a secret with no known vendor prefix under a name that is not credential-like (`MY_THING=<random>`, a bare random token in prose, session cookies under `sessionid=`); (2) weak values: passphrases, dictionary or low-entropy passwords (`correct-horse-battery-staple`, `Spring#2025`), passwords under 8 characters and keys under 16 characters under non-password names are masked in logs when under a credential name but do not block a brief; (3) split secrets: values split across lines, a backslash-newline continuation or string concatenation; (4) encoded or encrypted secrets: base64-wrapped env text, Ansible vault blobs, hex-encoded or doubly URL-encoded values; (5) separator forms outside the grammars: name/value pairs separated only by tabs or spaces outside the netrc, CLI, Dockerfile `ENV`, Markdown-table and name/value (`name:`/`value:`) grammars, YAML folded or literal block scalars (`api_token: >-` with the value on the next line), `.pgpass` colon lines, Terraform maps keyed by a plain name, JSON map values keyed by a host, and CLI tools that are not in the table when they use a non-generic flag whose name carries no credential word, a positional literal argument of a call whose name is not a credential name (`login("user", "pw")`), a bare Heroku CLI uuid and a Rails `master.key` file body; (6) mimicry: values that imitate a reference, placeholder or dummy (a password containing `example`, `test-` or `...`, or one that starts with `${` or `$(`); (7) prose false positives: a prose label such as `pass:` or `token:` followed by a random-looking single token ("this pass: `<sha>`") is refused; (8) inputs over the limits are refused or withheld, not scanned; (9) unchanged: the pinned non-interactive path's stdout is not redacted, the brief is visible in `ps`, and a SIGKILL leaves the raw 0600 log (and, for a Codex TUI capture, a raw `.capture.*` temp file in the private 0700 transcript directory: a named `CODEX_TRANSCRIPT_DIR` is swept of stale ones (older than ten minutes) at the next capture, while a default per-run directory is only removed by the 24-hour sweep of old `sb-codex-transcripts.*` directories); (10) representation: a JSON line that holds a secret is re-serialized (escapes, number spelling and key order may change, duplicate keys collapse), and a JSON object quoted inside a sentence is scanned as text, not decoded; (13) cost: the time is linear, but an input made only of credential-name anchors (a flood of `with_token(` or `define('PASSWORD', `) costs about 4 s per MiB per call, so such a crafted input over roughly 15 MiB exceeds the 60 s budget and is refused or withheld; (12) code shapes that hide a literal (also: nested quotes inside a fallback literal, and a UUID or identifier passed positionally to a call): string concatenation or `join`/`format` of literals, a literal after a placeholder or tag on the same line, YAML anchors (`password: &pw value` masks only the anchor), positional arguments of calls other than `login(...)` and the named setters, heredocs (`<<~EOS`, `<<<EOT`), `ENV.fetch('X') { 'lit' }` and `.unwrap_or(...)` blocks, and lambda or comprehension wrappers; (11) in logs a value under a credential name is masked even when the scan would not refuse it (a dictionary-word passphrase, a prose label such as `pass: merge`, a PEM header mentioned in prose), and an `Authorization` header keeps its scheme word and masks the next word (or everything after it when it holds `name=value` pairs); A refusal can be overridden with `SB_AGENT_ALLOW_SECRET_LIKE_BRIEF=1` set in the user's own shell (announced on stderr; read from the delegate's environment, never from the brief) |
| **Permission mode** | Pi has no permission controls, so it has no strict mode: `--mode strict` (explicit, or the default for a work dir outside the current project) is refused with a clear message; pass `--mode permissive` to run Pi deliberately. `--mode` otherwise defaults to `permissive` only for a work dir that is the current project (same git toplevel) |
| **Matrix env bleed** | `agent-pi/env.sh` clears `SB_E2E_*` ledger/lock vars |
| **Model drift** | `agent_pi_pin_mimo_model_env` rejects non-MiMo overrides in harness, delegate, adapter |
| **Credential rotation in prompt** | Forbidden — auth failures escalate to user |
| **SB-only plugin surface** | Preflight validates host install |

Run `security` / SENTINEL lens on harness changes under `scripts/agent-pi/` before merge. Delegation logs live under `.planning/agent-pi/` (gitignored) — do not commit.

---

## When parent should not delegate

- Trivial host-local edit (≤3 files, no Pi advantage).
- Task requires host-only tools without Pi equivalent.
- User explicitly wants parent implementation.
- Enterprise E2E matrix row — use matrix harness instead.

---

## References

- Sibling hosts: [`docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md`](../../docs/skills/AGENT-HOST-DELEGATION-SIBLING-PROMPT.md)
- Claude sibling: [`skills/silver-agent-claude/SKILL.md`](../silver-agent-claude/SKILL.md)
- Codex sibling: [`skills/silver-agent-codex/SKILL.md`](../silver-agent-codex/SKILL.md)
- OpenCode sibling: [`skills/silver-agent-opencode/SKILL.md`](../silver-agent-opencode/SKILL.md)
- Harness: `scripts/agent-pi/` (`invoke.sh`, `preflight.sh`, `monitor.sh`, `env.sh`), `scripts/agent-pi-delegate.sh`
- Live adapter: `scripts/lib/agent-adapters/pi.sh`
- CLI lib: `scripts/lib/pi-cli.sh` (`agent_pi_pin_mimo_model_env`)
