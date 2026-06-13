---
name: "silver:benchmark"
title: "Benchmark"
description: >
  This skill should be used for SB-owned benchmark and adversarial evaluation
  workflows across agents, models, providers, prompts, or implementation
  approaches.
argument-hint: "<benchmark task> [--providers <list>] [--rounds N]"
version: 0.1.0
---

# /silver:benchmark - Agent And Approach Evaluation

SB-owned benchmark workflow for repeatable evaluation. External providers may
enrich the run only when installed and requested; SB owns the fixture, scoring,
evidence, and final decision.

## Output

Write or update `.planning/BENCHMARK.md`.

The report must include:

- task fixture, constraints, and accepted-answer rubric;
- compared agents/models/providers/approaches;
- cost, latency, tool use, evidence quality, and correctness observations;
- self-evaluation bias checks when applicable;
- winning decision or inconclusive result with next step;
- retained artifacts and cleanup notes.

## Process

1. Display `SILVER BULLET > BENCHMARK`.
2. Define a task fixture that can be repeated without hidden context.
3. Define scoring before running candidates: correctness, requirement coverage,
   safety, maintainability, verification quality, cost, and latency.
4. Run each candidate under the same constraints. If external providers are not
   available, benchmark local approaches or prompt variants and record the
   limitation.
5. Use an adversarial review pass for top candidates when the result will
   influence architecture, release, security, or high-cost work.
6. Invoke or apply `silver:domain-audit --pack benchmark-eval`.
7. Normalize findings into `silver:review` or `silver:research` when the
   benchmark drives implementation.

## Exit Gate

A benchmark result is valid only when the fixture, rubric, raw evidence, and
decision rationale are sufficient for another session to reproduce the
comparison.
