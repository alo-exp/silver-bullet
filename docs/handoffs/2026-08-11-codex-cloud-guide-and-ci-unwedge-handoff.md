# Handoff — Codex Cloud guide + CI unwedge (PR #246)

**Branch:** `claude/codex-cloud-usage-guide-30dna0`
**PR:** https://github.com/alo-exp/silver-bullet/pull/246
**Head at handoff:** `61bb1d1` (pushed; working tree clean)
**Prior session ran in:** Claude Code on the web — a remote, ephemeral container.
That matters: several things could not be verified there and are listed under
"Why a local session is needed".

---

## 1. Why you are picking this up

The PR started as a docs request (how to use Codex Cloud alongside the desktop
agent). Writing it surfaced that CI had been red on `main` since 2026-08-08,
and unwedging that turned into the bulk of the work. One assertion is still
failing and needs a machine with a real toolchain to finish.

---

## 2. What is already done (all committed and pushed)

| Commit | What |
|---|---|
| `6d95a6b` | `docs/CODEX-CLOUD.md` + link from `docs/RUNTIME-COMPATIBILITY.md` |
| `0c0e6ec` | Break the reconcile ↔ installer recursion that wedged CI |
| `b345c6a` | Stop `sync-codex-package.sh` gutting tracked trees when `rsync` is absent |
| `d6c0b6f` | Stop the test suite mutating the checkout it runs in |
| `61bb1d1` | Scope Cursor subagent config to the target project |

### 2.1 The recursion (root cause of the 3-hour CI hang)

`reconcile-recommended-tools.sh --mode apply` → `optimize-rtk-context-mode.sh`
→ `install-recommended-tools-global.sh` → `install-recommended-tools-cursor.sh`
→ `rt_installer_post_install` → back into `reconcile --mode apply`. Nothing
marked the in-flight apply, so the 5-process cycle repeated until the GitHub
runner was reclaimed (`exit 143`, 3h41m–4h38m per run).

Fix: the reconciler exports `SB_RT_APPLY_ACTIVE=1` for the duration of an
apply; `rt_installer_post_install` skips its nested reconcile when set;
`optimize_context_mode_cursor` honors it alongside the pre-existing
`TOOLSTACK_INSTALL_IN_PROGRESS`.

Result: `tests/scripts/test-reconcile-recommended-tools.sh` went from 3h+
(killed) to ~27s, 61 passed. CI `validate` went from ~3h to ~13 min.

### 2.2 Repo-mutation class (scripts writing into the SB checkout)

Four production defects, all the same shape — a script resolving its write
target from its own location instead of the project it was told to act on:

- `install-cursor-sb-agents.sh` hardwired `REPO_ROOT` as the target project.
  Now splits `PROJECT_ROOT` (follows `CSBA_REPO_ROOT`) from `REPO_ROOT`.
- `sb-doctor.sh --fix` called that installer unscoped — doctoring any project
  reconfigured Silver Bullet.
- `export-enterprise-evidence.sh` rewrote the tracked
  `.planning/enterprise-e2e/CERTIFICATION-STATUS.json` as a side effect.
- `install-cursor.sh` ran the subagent installer unscoped (`61bb1d1`).

Plus `sync-codex-package.sh` / `sync-cursor-package.sh`: both `rm -rf` tracked
trees *before* repopulating with `rsync`, so a missing `rsync` deleted 52
tracked files under `plugins/silver-bullet/templates/` and exited. Both now
preflight `rsync`/`python3` before touching anything.

New opt-in redirects, defaults unchanged: `SB_CERT_ARTIFACT`,
`SB_CERT_SITE_COPY`, `SB_E2E_RUNS_DIR`.

Verified in the prior environment: a full `tests/scripts/` sweep mutates
nothing tracked and leaves no untracked files.

---

## 3. The one open failure — pick this up first

CI `validate` fails on exactly one assertion in
`tests/scripts/test-install-cursor.sh`:

```
FAIL: install-cursor merges full SB hook count — template 88 vs merged 86
    missing from merged hooks.json (event/matcher :: hook):
      preToolUse/Read|Grep :: stack-compression-coordinator.sh
      preToolUse/Shell    :: site-regression-gate.sh
```

### What is known

- Both entries exist in `hooks/cursor-hooks.json` (88 entries) with unique
  `(event, command, matcher)` keys. The template and both plugin mirrors are
  byte-identical to `main`; `scripts/generate-cursor-hooks.py` reproduces them
  exactly.
- `merge-cursor-hooks.py` is lossless against a pristine `hooks.json`
  (88 in / 88 out). Its dedupe key is `(command, matcher)` per event.
- `patch-hooks.py` only *removes* lean-ctx rewrite entries — not these two.
- The test **passes locally** (64/64) under an `rsync` stand-in, and **hangs on
  `main`** with a real `rsync` (it was another entry into the recursion). So
  there is no clean pre-fix baseline for this assertion; CI never reached it
  before `0c0e6ec`.

### RESOLVED: the entries are genuinely absent, not relocated

The widened diagnostic in `61bb1d1` answered it (CI run 31535652332). The
toolstack-path hypothesis is **dead** — the two entries are lost, and the
assertion is right to fail:

| Hook | In `hooks/cursor-hooks.json` | In merged `~/.cursor/hooks.json` |
|---|---|---|
| `site-regression-gate.sh` | `preToolUse/Shell`, `stop/.*`, `subagentStop/.*` | `stop/.*`, `subagentStop/.*` — **`preToolUse/Shell` lost** |
| `stack-compression-coordinator.sh` | `Edit\|Write\|MultiEdit\|Shell`, `Read\|Grep`, `WebFetch`, `CallMcpTool\|MCP` | same minus **`Read\|Grep`** |

`patch-hooks.py` does add a toolstack coordinator entry
(`bash <home>/.cursor/hooks/toolstack/stack-compression-coordinator.sh`), but
its matcher is `Edit|Write|MultiEdit|Shell|CallMcpTool|MCP|WebFetch` — it
contains neither `Read` nor `Grep`. So the `Read|Grep` compression coverage is
**not** picked up elsewhere, and `site-regression-gate` loses its preToolUse
Shell gate outright. This is a real functional gap, not a stale assertion.

### Where to look

Neither loss is explained by the code read so far, which is why it needs a
local repro:

- `merge-cursor-hooks.py` dedupes on `(command, matcher)` per event, and both
  missing entries have unique keys — so the add loop should keep them.
  Its `is_stale_sb_hook()` cleanup is the only removal path; check whether a
  second merge pass (`--merge-hooks-only` runs twice in this test) plus the
  `stable_install_path()` versioned→`current` symlink rewrite makes these two
  look stale.
- `patch-hooks.py` removes only lean-ctx rewrite entries, but
  `ensure_rtk_before_cm()` does `pretool.pop()` + re-insert, and
  `insert_before_bridge()` reorders — worth confirming nothing is dropped
  when the list is mutated mid-iteration.
- `scripts/lib/global-toolstack/fix-shell-compression-hook.py` is unread and
  its name suggests it rewrites Shell-matcher hooks. Start here.

### Reproducing

Needs real `rsync` (see §4) — the prior session's stand-in made the test pass
64/64 locally, masking this:

```bash
bash tests/scripts/test-install-cursor.sh
# on failure it now prints both the missing entries and what merged holds
```

Decide the fix only after you know which stage drops them: if merge, fix
`merge-cursor-hooks.py`; if a patcher, fix that; if the hooks are genuinely
meant to be superseded, the toolstack matcher needs `Read|Grep` added and the
assertion updated to match — but do not just relax the assertion.

---

## 4. Why a local session is needed

The prior container lacked tooling, so these are unverified rather than known-good:

- **No `rsync`** — `install-cursor.sh`, `sync-codex-package.sh`,
  `sync-cursor-package.sh` and everything downstream could only be exercised
  through a hand-written stand-in (`rm -rf dest; cp -a src/. dest/`, flags
  dropped). Re-run those tests with real `rsync`.
- **No `codex` / `claude` / `cursor` CLIs, no `openpyxl`** — these tests failed
  with `127` and were confirmed to fail identically on `origin/main`, so they
  are environment gaps, not regressions. Confirm on a real machine:
  `test-codex-cli-isolation`, `test-codex-hook-transplant`,
  `test-codex-skill-frontmatter-yaml`, `test-install-claude`,
  `test-install-codex`, `test-install-cursor-archive`, `test-kay-codex-isolation`,
  `test-silver-init-merge-hooks`, `test-solution-research-python`,
  `test-sync-codex-marketplace-version`, `test-sync-codex-package`,
  `test-sync-cursor-marketplace-version`, `test-tri-host-install-smoke`.
- **No `graphify`** — `graphify-out/graph.json` exists and CLAUDE.md requires
  `graphify query` before grepping. That rule went unmet for every file touched
  this session; work was done by direct read/grep. Consider re-running
  `graphify update .` locally.
- **Egress blocked to `developers.openai.com` and `community.openai.com`** —
  the Codex Cloud platform claims in `docs/CODEX-CLOUD.md` (no MCP surface in
  cloud task containers, agent-phase internet off by default, setup scripts
  have internet) came from search results, not the primary docs. Re-verify
  before anyone relies on them; the doc carries a caveat saying so.

---

## 5. Suggested order of work

1. Fix the two dropped preToolUse hooks (§3) — the diagnostic already
   identified them; start at `fix-shell-compression-hook.py`.
2. Re-run the full sweep with real tooling; confirm the 13 environment failures
   above are green locally and that nothing new appears.
3. Confirm the tree stays clean after a full sweep — that invariant is the
   point of `d6c0b6f` and `61bb1d1` and is worth protecting with a check.
4. Re-verify the Codex Cloud doc against OpenAI's published cloud docs.
5. Get `validate` green, then merge.

## 6. Notes

- Two containers get confused easily in the PR history: "cloud task container"
  in `docs/CODEX-CLOUD.md` means **Codex Cloud's** per-task sandbox; references
  to sandbox limitations mean the **prior session's own** remote container.
- `test-sync-cursor-marketplace-version.sh` deliberately mutates the in-repo
  manifest (that is what it asserts) and restores it via trap. Do not
  "sandbox" it — that would delete the assertion.
- The recursion fix is load-bearing and was verified by reverting it: both
  guards off reproduces the hang (`rc=124`), restoring them completes.
