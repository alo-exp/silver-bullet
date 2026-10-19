Now I'll write the comprehensive review:
Review written to `skills/multi-ai-task/self-review.md`.

**Summary of findings:**

- **Score: 11/16** on the skill's own rubric — strong on parent/worker split, evidence model, catalog of composable units, and SE+DevOps coverage. Weakest on enforcement (honor system, no CI/IDE integration) and v-loop depth (end-tests only, no intent gate or per-step rollup).

- **2 high-severity bugs found:** (1) `run-manifest.json` defined in two files with divergent field sets — `output-schema.md` is stale and missing v2.1.0 fields; (2) `most-severe` rule says downgrade lone dissenter, but code-review example says don't — directly contradictory for the rule's primary use case.

- **Top ROI fix:** Add `--timeout` to the Mechanism 2 dispatch snippet (prevents the most common silent failure mode, single-file change).

- **Biggest structural concern:** Only 1 of 5 claimed task types has a proven worked example. Both code-review and fact-check are deferred to v2.2.0. The task-agnostic claim is backed by design, not evidence.
