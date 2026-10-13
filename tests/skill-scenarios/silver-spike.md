# Silver Spike Skill Scenario

## Skill: silver-spike
## Context: Focused feasibility experiments before committing to an implementation approach

### Scenario: Validate External API Integration Approach

**Trigger:** "Can we use library X for real-time sync without blowing our latency budget?"

**Workflow:**
1. Clarify the technical question and constraints (or use `--quick` to skip intake).
2. Decompose into 2–5 independently runnable experiments with clear hypotheses.
3. Run experiments in order of risk; record each result immediately in `.planning/spikes/<NNN>-<slug>/README.md`.
4. Synthesize findings in `.planning/spikes/MANIFEST.md` with a recommended next step.
5. File deferred out-of-scope items via `sb:add`; optionally wrap up via `sb:rem` with `--wrap-up`.
