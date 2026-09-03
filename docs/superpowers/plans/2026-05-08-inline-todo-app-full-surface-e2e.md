# Inline Todo-App Full-Surface E2E Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current multi-scenario todo-app live E2E suite with one inline full-surface journey that exercises the SB-owned surface, records explicit coverage, files real end-user friction with `silver:add` and a `todo-app` tag, and makes release gating depend on that proof.

**Architecture:** Keep the existing live runtime matrix as the low-level runtime contract. Replace the current multi-scenario todo-app E2E suite with a single higher-order inline journey that drives a scripted turn sequence through the terminal TUI/runner layer, so the session can be automated turn-by-turn without pretending the desktop chat pane is scriptable. For Codex, that means adding a small terminal driver alongside the existing Claude `expect` wrapper. The journey writes a coverage ledger, files issues immediately when frustration appears, and emits a release marker that the completion audit hook can enforce.

**Tech Stack:** Bash, jq, gh CLI, existing Silver Bullet skills, existing live test harness, terminal TUI/PTY automation via `expect` where needed.

---

### Task 1: Add turn-sequence, terminal drivers, and coverage-ledger helpers

**Files:**
- Modify: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/helpers.sh`
- Create: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/lib/coverage-ledger.sh`
- Create: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/lib/turn-driver.sh`
- Create: `/Users/shafqat/projects/silver-bullet/repo/scripts/codex-interactive-invoke.expect`
- Test: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/test-e2e-live-ledger.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/e2e-live/test-e2e-live-ledger.sh` that sources the new helper files, appends three ledger entries, and fails if:
1. the ledger file is not created,
2. entries are not appended in order,
3. the completion check does not reject a missing SB surface.

Use a concrete shell assertion shape like:

```bash
source "$(cd "$(dirname "$0")" && pwd)/lib/coverage-ledger.sh"
LEDGER_FILE="$(mktemp)"
init_coverage_ledger "$LEDGER_FILE"
ledger_append "$LEDGER_FILE" "silver:init" "scaffold created" "no" "init-files.json"
ledger_append "$LEDGER_FILE" "silver:feature" "clear-completed shipped" "no" "feature-diff"
ledger_append "$LEDGER_FILE" "silver:quality-gates" "pre-ship sweep passed" "no" "gate-log"
ledger_require_all "$LEDGER_FILE" "silver:init" "silver:feature" "silver:quality-gates"
```

Then assert that deleting one required entry causes `ledger_require_all` to exit non-zero.

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/test-e2e-live-ledger.sh
```

Expected: fail because the helper files, the ledger functions, and the Codex terminal driver do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Implement the helpers as small Bash functions:

```bash
init_coverage_ledger() {
  local ledger_file="$1"
  cat >"$ledger_file" <<'EOF'
# Silver Bullet Inline Coverage Ledger
EOF
}

ledger_append() {
  local ledger_file="$1" surface="$2" note="$3" issue="$4" evidence="$5"
  printf '## %s\n- issue: %s\n- evidence: %s\n- note: %s\n\n' "$surface" "$issue" "$evidence" "$note" >>"$ledger_file"
}

ledger_require_all() {
  local ledger_file="$1"; shift
  local surface
  for surface in "$@"; do
    grep -q "^## ${surface}$" "$ledger_file"
  done
}
```

In `turn-driver.sh`, add a small ordered prompt runner:

```bash
run_prompt_sequence() {
  local prompt_file="$1"
  while IFS= read -r prompt; do
    [[ -n "$prompt" ]] || continue
    run_prompt "$prompt"
  done < "$prompt_file"
}
```

Wire the helpers into `tests/e2e-live/helpers.sh` so the scenario scripts can source them directly.

Add a Codex terminal driver that can be invoked from the harness when turn-by-turn
automation is needed:

```expect
#!/usr/bin/expect -f
set timeout -1
set prompt_file [lindex $argv 0]
set fh [open $prompt_file r]
set prompt [read $fh]
close $fh
spawn codex
expect ">"
send -- "$prompt\r"
expect eof
```

The exact terminal handshake can be refined during implementation, but the
important part is that the runner has a dedicated Codex interactive path instead
of relying on the desktop chat pane.

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/test-e2e-live-ledger.sh
```

Expected: PASS, with ordered ledger entries and a non-zero failure on the intentionally missing surface case.

- [ ] **Step 5: Commit**

```bash
git add tests/e2e-live/helpers.sh tests/e2e-live/lib/coverage-ledger.sh tests/e2e-live/lib/turn-driver.sh tests/e2e-live/test-e2e-live-ledger.sh
git commit -m "test(e2e-live): add coverage ledger helpers"
```

### Task 2: Replace the live todo-app suite with one inline full-surface journey

**Files:**
- Create: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/run-e2e-live-tests.sh`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/test-e2e-live-suite.sh`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/README.md`
- Delete: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/scenarios/test-e2e-live-install-ux.sh`
- Delete: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/scenarios/test-e2e-live-init-and-feature.sh`
- Delete: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/scenarios/test-e2e-live-regression-repair.sh`
- Delete: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/scenarios/test-e2e-live-release-prep.sh`

- [ ] **Step 1: Write the failing test**

Add a harness assertion that the new scenario exists and is the only live todo-app scenario. The sanity test should fail until the new scenario file is present and the runner lists exactly one item.

Use an exact check like:

```bash
mapfile -t scenario_list < <("${SCRIPT_DIR}/run-e2e-live-tests.sh" --list)
[[ "${#scenario_list[@]}" -eq 1 ]]
[[ "${scenario_list[0]}" == "${SCRIPT_DIR}/scenarios/test-e2e-live-full-surface-journey.sh" ]]
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/test-e2e-live-suite.sh
```

Expected: fail because the scenario does not exist yet and the runner still knows about the old multi-scenario suite.

- [ ] **Step 3: Write minimal implementation**

Create `tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh` as the main live journey. The script should:

1. prepare a clean todo-app workspace,
2. refresh the relevant runtime install,
3. run a scripted prompt sequence that covers install/bootstrap, discovery/framing, feature delivery, deliberate bugfix, cleanup, and release prep,
4. call `silver:add` at the point where real dissatisfaction appears,
5. append a ledger entry after each major SB surface,
6. write the inline release marker only if the ledger is complete.

The turn sequence should be explicit rather than hidden in prose. Example shape:

```bash
journey_prompts=(
  '/silver-init Initialize SB on this todo-app project and scaffold the workspace.'
  '/silver-explore What is the cleanest next enhancement for this todo app?'
  '/silver-feature Implement the chosen enhancement and update the UI.'
  '/silver-bugfix Reproduce and fix the first real defect discovered during the run.'
  '/silver-fast Make one trivial, genuinely small cleanup change.'
  '/silver-release Prepare the todo-app for release and finish the branch.'
)

for prompt in "${journey_prompts[@]}"; do
  response="$(run_prompt "$prompt")"
  ledger_append "$LEDGER_FILE" "$surface" "$summary" "$issue_state" "$evidence"
done
```

The script should explicitly pause for issue capture whenever the prompt output
or browser state shows friction, and it should call `silver:add` for any real
user-facing dissatisfaction. The resulting issue should be created in the SB repo
and labeled `todo-app`.

Update `run-e2e-live-tests.sh` so it runs exactly one scenario: the full-surface journey.

Keep the existing full Claude/Codex matrix marker, and add a new inline-journey
marker when the full-surface journey completes.

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/test-e2e-live-suite.sh
```

Expected: PASS, with the single full-surface scenario listed and no old scenario
files still wired into the suite.

- [ ] **Step 5: Commit**

```bash
git add tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh tests/e2e-live/run-e2e-live-tests.sh tests/e2e-live/test-e2e-live-suite.sh tests/e2e-live/README.md
git rm tests/e2e-live/scenarios/test-e2e-live-install-ux.sh tests/e2e-live/scenarios/test-e2e-live-init-and-feature.sh tests/e2e-live/scenarios/test-e2e-live-regression-repair.sh tests/e2e-live/scenarios/test-e2e-live-release-prep.sh
git commit -m "test(e2e-live): add inline full-surface todo-app journey"
```

### Task 3: Teach `silver:add` to carry the todo-app tag and prove it

**Files:**
- Modify: `/Users/shafqat/projects/silver-bullet/repo/skills/silver-add/SKILL.md`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh`
- Create: `/Users/shafqat/projects/silver-bullet/repo/tests/scripts/test-silver-add-todo-app-tag.sh`

- [ ] **Step 1: Write the failing test**

Create `tests/scripts/test-silver-add-todo-app-tag.sh` with a stubbed `gh`
executable in `PATH` that records its arguments. The test should drive a synthetic
`silver:add` filing for the todo-app run and then assert that the issue create/edit
flow includes a `todo-app` label in addition to the normal Silver Bullet labels.

The stub should capture a command sequence like:

```bash
gh issue create --label filed-by-silver-bullet --label bug --label todo-app
gh issue edit 123 --add-label todo-app
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/scripts/test-silver-add-todo-app-tag.sh
```

Expected: fail because the `silver:add` instructions do not yet require the
`todo-app` tag path.

- [ ] **Step 3: Write minimal implementation**

Update `skills/silver-add/SKILL.md` so the GitHub path explicitly says:

1. if the filing is for the inline todo-app journey, the issue must be tagged
   `todo-app`,
2. the label must be created idempotently if it does not exist,
3. the resulting GitHub issue should include the tag in the created issue and any
   later edit path.

Mirror that behavior in the live journey script by filing through `silver:add`
and then verifying the returned issue URL has the `todo-app` label attached.

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/scripts/test-silver-add-todo-app-tag.sh
```

Expected: PASS, with the stub showing the `todo-app` label was created/applied.

- [ ] **Step 5: Commit**

```bash
git add skills/silver-add/SKILL.md tests/scripts/test-silver-add-todo-app-tag.sh tests/e2e-live/scenarios/test-e2e-live-full-surface-journey.sh
git commit -m "feat(silver-add): tag todo-app issue filings"
```

### Task 4: Make the inline journey a release gate and document it

**Files:**
- Modify: `/Users/shafqat/projects/silver-bullet/repo/hooks/completion-audit.sh`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/tests/hooks/test-completion-audit.sh`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/docs/TESTING.md`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/docs/RELEASE.md`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/tests/live/README.md`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/tests/e2e-live/README.md`
- Modify: `/Users/shafqat/projects/silver-bullet/repo/docs/ENFORCEMENT.md`

- [ ] **Step 1: Write the failing test**

Extend the completion-audit test suite so a release is blocked unless the new
inline journey marker exists. Use a concrete marker path such as:

```bash
INLINE_E2E_MATRIX_FILE="${SB_RUNTIME_HOME_ROOT}/.silver-bullet/inline-e2e-matrix"
```

Add a test that asserts:

1. release is blocked without the marker,
2. release is allowed when the marker contains `matrix=inline-full-surface`,
3. the block message mentions the inline todo-app journey explicitly.

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/hooks/test-completion-audit.sh
```

Expected: fail on the new inline marker case because the hook does not yet know
about it.

- [ ] **Step 3: Write minimal implementation**

Teach `hooks/completion-audit.sh` to require both the existing release markers and
the new inline todo-app marker before allowing `gh release create`.

Use a simple settled-state check:

```bash
require_marker "$INLINE_E2E_MATRIX_FILE" "matrix=inline-full-surface"
```

Then update the docs to explain:

- the inline todo-app journey is the higher-order end-user proof
- the existing runtime matrix remains the lower-level contract
- `silver:add` is the required path for filing dissatisfaction during the run

- [ ] **Step 4: Run the test to verify it passes**

Run:

```bash
bash /Users/shafqat/projects/silver-bullet/repo/tests/hooks/test-completion-audit.sh
```

Expected: PASS, including the new inline journey gate.

- [ ] **Step 5: Commit**

```bash
git add hooks/completion-audit.sh tests/hooks/test-completion-audit.sh docs/TESTING.md docs/RELEASE.md docs/ENFORCEMENT.md tests/live/README.md tests/e2e-live/README.md
git commit -m "fix(release): gate on inline todo-app journey"
```

### Task 5: Run the full suite and validate the inline journey end to end

**Files:**
- None new; verify all touched files and the live journey behavior.

- [ ] **Step 1: Run the repo test suite**

Run:

```bash
cd /Users/shafqat/projects/silver-bullet/repo
bash tests/run-all-tests.sh
```

Expected: all suites green, with the new live journey and release gate tests included.

- [ ] **Step 2: Run the live todo-app journey manually once**

Run the new inline journey scenario with the terminal TUI or prompt driver and
confirm it actually walks the todo-app forward, files any real friction through
`silver:add`, and writes the inline marker.

- [ ] **Step 3: Verify the release gate and docs**

Confirm that the completion audit blocks when the inline marker is absent and
passes when present, and that `docs/TESTING.md` and `docs/RELEASE.md` describe
the new contract in the same words the tests enforce.

- [ ] **Step 4: Commit or clean up**

If any follow-up edits remain after the validation pass, commit them with a
single focused message; otherwise leave the tree clean and ready for the next
release step.
