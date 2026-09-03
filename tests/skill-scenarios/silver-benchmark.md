# silver-benchmark Scenario

## Purpose

Validate SB-owned repeatable benchmark and adversarial evaluation workflow.

## Expected Behavior

- Writes `.planning/BENCHMARK.md`.
- Defines repeatable fixture, constraints, rubric, and compared candidates before running.
- Records correctness, evidence quality, safety, cost, latency, and tool-use data.
- Applies `silver:domain-audit --pack benchmark-eval`.
- Routes decisions into `silver:deep-research`, `silver:review`, or implementation planning.
