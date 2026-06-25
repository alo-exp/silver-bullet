# Silver Bullet Inline Todo-App Full-Surface E2E — Design Spec

> **SUPERSEDED (2026-06-25):** Replaced by enterprise-grade-test-app Claude supervised matrix.
> See `.planning/enterprise-e2e/CLAUDE-TUI-PROTOCOL.md` and
> `enterprise-grade-test-app/docs/WORKFLOW_E2E_MATRIX.md`.

**Date:** 2026-05-08  
**Status:** Draft for review  
**Author:** Brainstorming session (Superpowers:brainstorming)

## 1. Overview

Silver Bullet needs a live end-user test that is not just a mechanical CLI smoke.
The goal is to use the current desktop session itself, inline, against the todo app
fixture in `tests/test-app/`, and to keep advancing that app while exercising the
full Silver Bullet surface the way a real user would.

This design keeps the existing live matrix (`tests/live/run-live-tests.sh`) as the
lower-level runtime contract, but adds a new higher-order live journey that proves:

- the installed Silver Bullet surface is usable in a real session
- the todo app can be developed forward while SB workflows are used naturally
- dissatisfaction and defects are filed immediately through `silver:add`
- coverage is explicit, not implied

The new suite is intentionally **interactive**. It is not the old Codex-CLI-only
matrix, and it is not a pure unit test. It is an operator-in-the-loop acceptance
journey that should feel like genuine SB usage.

## 2. Why the Current Suite Is Not Enough

The current `tests/e2e-live/` suite already does a good job of proving runtime
bootstrap, feature delivery, bug repair, and release prep. It also verifies the
installed command surface and the installation UX.

What it does **not** yet guarantee is that:

- the live run feels like an actual user session rather than a checklist
- we use enough of the SB surface inline to have high confidence in the install
  as an end-user experience
- issues or rough edges discovered during the session are captured immediately
  and tracked back to the repo
- coverage is explicit enough to make "100% of SB surface" a hard expectation

That gap is the reason for this design.

## 3. Goals

1. Exercise Silver Bullet inline in the current desktop session, not through the
   older Codex-CLI-only live flow.
2. Keep working on the todo app while we exercise SB, so the session feels like
   real development instead of synthetic command playback.
3. Cover the full SB-owned live surface that a user is meant to rely on in this
   repo.
4. File every real dissatisfaction or defect immediately with `silver:add`, and
   tag it for the todo-app run.
5. Keep the todo app persistent for the duration of the run, but reset it before
   and after the run so the next run starts from a clean baseline.
6. Produce a coverage ledger that proves which SB skills or families were used.

## 4. Non-Goals

- Do not add a separate Silver Bullet plugin.
- Do not reintroduce the removed `using-silver-bullet` compatibility path.
- Do not automate the host picker UI itself.
- Do not turn the run into a blind script that just calls skills without real app
  evolution.
- Do not count dependency-owned skills as SB coverage.
- Do not replace the existing live matrix; this is an additive higher-order gate.

## 5. Proposed Execution Model

### 5.1 One living todo-app workspace per run

Each run starts from a clean copy of `tests/test-app/`, then keeps one workspace
alive for the whole run. That workspace is the thing being improved while SB is
used inline.

The run ends by resetting the workspace back to the fixture baseline, so the next
run starts clean again.

### 5.2 Operator-in-the-loop, not headless-only

The current session acts as the control plane. The model:

- uses the todo-app fixture as the product under test
- uses browser or shell tools as needed for the app
- uses SB workflows inline in the conversation
- pauses at explicit checkpoints to evaluate whether the experience feels like a
  real end-user session

### 5.3 Coverage ledger

The run must maintain a coverage ledger with one entry per required SB surface.
Each entry records:

- skill or family name
- where it was exercised in the live journey
- what app artifact or decision it produced
- whether any issue was filed
- evidence pointer: file, test, browser proof, or GitHub issue URL

The run only passes when every required SB surface has a ledger entry and every
real dissatisfaction has been filed.

## 6. Required SB Surface Coverage

The suite should not hardcode a tiny allowlist. It should instead align to the SB
owned, user-facing surface that this repo expects users to experience in practice.

The registry is split into two kinds of entries:

- **SB-owned coverage** — counts toward the 100% goal
- **dependency/orchestration coverage** — must be observed when they naturally
  appear in the live run, but they do not count toward SB's own coverage target

The coverage registry should include at least these groups:

| Group | Representative SB surfaces | How the todo-app run should exercise them |
|------|-----------------------------|-------------------------------------------|
| Install / bootstrap | `silver:init`, `silver:add`, `silver:remove` | Install SB into the desktop session, scaffold the todo app, file an issue when something feels off, and retire at least one temporary artifact or issue during cleanup |
| Discovery / framing | `silver:explore`, `gsd-scan`, `silver:research`, `silver:blast-radius` | Use them before the first feature and again before any larger change or risky tweak |
| Feature delivery | `silver:feature`, `silver:ui`, `silver:fast` | Build at least one real user-visible enhancement, one UI refinement, and one trivial change that is genuinely small enough for the fast path |
| Defect handling | `silver:bugfix`, `silver:forensics`, `tdd` | Deliberately surface or reproduce a bug, reconstruct it, write a regression test, and fix it |
| Governance / quality | `silver:quality-gates`, `requesting-code-review`, `receiving-code-review` | Run quality checks before moving forward, then review the work and respond to findings |
| Release readiness | `silver:create-release`, `silver:release`, `finishing-branch` | Prepare the todo-app branch for release, create release notes/tag, and clean up the branch state |
| Project orchestration | `gsd-new-project`, `gsd-new-milestone`, `gsd-discuss-phase`, `gsd-plan-phase`, `gsd-execute-phase`, `gsd-verify-work`, `gsd-ship`, `gsd-code-review`, `gsd-ui-phase`, `gsd-ui-review`, `gsd-secure-phase`, `gsd-debug`, `gsd-forensics` | Use these as the structured backbone of the journey where they naturally fit the app work |

The implementation must treat the current integration coverage list as the source
of truth for the exact tracked items, but the live suite should only count SB-owned
surfaces toward the SB coverage goal.

## 7. Proposed Journey

The todo-app run should feel like a real development arc:

1. **Install and initialize**
   - confirm the SB install is active in this desktop session
   - initialize SB on the todo app
   - create the project scaffold and validate that the live command surface is
     available

2. **Initial product thinking**
   - use discovery and research to decide the first meaningful enhancement
   - record the chosen approach before touching implementation

3. **Deliver a real feature**
   - implement a user-visible todo-app improvement
   - include a UI change, not just a backend or test change
   - keep the app feeling like a product a real person would use

4. **Deliberate defect and repair**
   - surface a real bug or regression during the journey
   - use forensics/debugging to reconstruct the cause
   - write or update a regression test and fix the defect

5. **Quality and review**
   - run quality gates at the right times
   - request review, respond to review, and verify the result

6. **Fast-path cleanup**
   - include at least one genuinely trivial change that uses the fast path

7. **Release prep**
   - prepare the todo-app branch for a release-like finish
   - generate release notes or tags where appropriate
   - close out temporary work cleanly

8. **Issue filing**
   - whenever a real end-user dissatisfaction appears, stop and file it immediately
   - use `silver:add`
   - tag the issue for the todo-app run so it is easy to find later

## 8. Issue Filing Rules

If the session surfaces friction, confusion, or a defect that a real end user would
care about, we do not paper over it.

Instead:

1. classify it as issue or backlog item using `silver:add`
2. file it in the Silver Bullet repo
3. tag it with `todo-app`
4. include enough context to reproduce it from the inline session
5. continue the todo-app journey unless the issue blocks the current step

If the item is not truly a defect, the run should still either:

- file it as a backlog item, or
- explicitly explain why it is not actionable and keep moving

The suite is not passing if a real dissatisfaction is noticed and then forgotten.

## 9. Coverage Ledger

The suite should write a human-readable ledger for the run. The ledger should be
append-only for the duration of the session and should contain entries like:

| Step | Surface | Evidence | Issue? |
|------|---------|----------|--------|
| Install | `silver:init` | scaffold files created in todo-app workspace | no |
| Discovery | `silver:explore` | decision note in session transcript | no |
| Feature | `silver:feature` | feature diff + tests | maybe |
| UI | `silver:ui` | browser screenshot / DOM proof | maybe |
| Bugfix | `silver:bugfix`, `silver:forensics`, `tdd` | failing test -> fix -> green test | yes/no |
| Cleanup | `silver:fast`, `silver:remove` | tiny change or retired temp artifact | maybe |
| Governance | `silver:quality-gates`, `requesting-code-review`, `receiving-code-review` | review notes / gate output | no |
| Release | `silver:create-release`, `silver:release`, `finishing-branch` | tag / release note / branch cleanup | no |

The ledger is the proof artifact for "100% coverage" in the live run.

## 10. Reset and Cleanup

The todo app should be reset after the run so the next run starts clean.

The live session must also leave behind:

- the coverage ledger
- any issues that were filed
- the final state of the todo-app branch or workspace

It should not leave behind random scratch files without either using them or
retiring them explicitly.

## 11. Acceptance Criteria

This design is considered complete when the implementation can prove all of the
following:

- the session used the live todo-app fixture inline in the desktop environment
- the session exercised the required SB surface through real app development
- the session filed every real user-facing dissatisfaction through `silver:add`
  with `todo-app` tagging
- the session produced a coverage ledger that shows every required SB surface
  was actually used
- the todo app still works at the end of the run
- the run resets cleanly after completion

## 12. Risks and Mitigations

- **Risk: The run becomes too mechanical.**  
  Mitigation: force the session to make real product decisions and only count
  skill usage when it produces real app evolution or a real operational outcome.

- **Risk: Not every SB surface is naturally needed by a tiny todo app.**  
  Mitigation: use sidecar episodes that still advance the app, such as UI
  refinement, regression repair, release prep, and cleanup, instead of pretending
  a skill was used when it was not.

- **Risk: Issues are noticed but not captured.**  
  Mitigation: make `silver:add` part of the live-run contract whenever dissatisfaction
  is discovered.

- **Risk: The run drifts away from the real end-user experience.**  
  Mitigation: keep the run centered on one persistent todo-app workspace, one
  human-readable ledger, and concrete browser-visible app changes.
