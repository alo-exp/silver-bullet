# silver-benchmark Scenario

## Purpose

Validate SB-owned repeatable benchmark and adversarial evaluation workflow.

## Expected Behavior

- Writes `.planning/BENCHMARK.md`.
- Defines repeatable fixture, constraints, rubric, and compared candidates before running.
- Records correctness, evidence quality, safety, cost, latency, and tool-use data.
- Applies `sb:domain-audit --pack benchmark-eval`.
- Routes decisions into `sb:deep-research`, `sb:review`, or implementation planning.
