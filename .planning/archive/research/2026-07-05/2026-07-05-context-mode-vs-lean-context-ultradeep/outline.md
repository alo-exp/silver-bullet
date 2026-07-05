# Outline — Research Report

## Executive Summary
- Conditional winner: Context Mode as SB default; Lean Context for governance/read-path/Apache-2.0 cases
- Confidence: medium-high for SB policy; medium for absolute capability superiority

## Introduction
- Research question and methodology (live fetch + SB docs)
- Assumptions and scope boundaries

## Main Analysis

### Finding 1: Problem framing and architecture
- LeanCTX as five-subsystem context engineering layer [1][2]
- Context Mode as MCP-layer sandbox + FTS5 memory [6]
- Evidence: ev architecture rows

### Finding 2: Retrieval, indexing, and compression surfaces
- Lean: AST read modes, hybrid MCP+shell [5]
- CM: ctx_execute, ctx_fetch_and_index, FTS5 RRF [6]
- SB: CM + RTK split [10]

### Finding 3: Agent UX and install/runtime
- Lean: single Rust binary, lean-ctx setup [4][5]
- CM: Node >=22.5, npm global, plugin/hooks merge [6][8]
- Complexity comparison

### Finding 4: Platform compatibility
- Lean: 30+ tools, Cursor CLI-Redirect [1][11]
- CM: 17+ platforms, Cursor plugin path [6][8]
- Goose/Hermes gaps on CM side [8]

### Finding 5: Privacy, security, offline
- Both local-first [1][6]
- PathJail vs MCP sandbox hardening [2][6]
- Savings ledger vs ctx_stats [12][6]

### Finding 6: Maturity, documentation, licensing
- Apache-2.0 vs ELv2 [5][6][8]
- SB hook gates exist for CM only [8][10]
- Lean Team/Enterprise commercial plane [3]

### Finding 7: Silver Bullet recommended-tool fit
- Tier 1c contract [9]
- Synergy with Graphify/agentmemory/RTK [9][10]
- Lean lists RTK as addon — composable stack [1]

## Synthesis & Insights
- Complementary stack hypothesis
- When to recommend each

## Limitations & Caveats
- No live install benchmark
- search-cli unavailable
- Vendor metrics unverified

## Recommendations
- SB default, exceptions, future evaluation path

## Bibliography
- [1]–[12] mapped to sources.jsonl

## Appendix: Methodology
- AF-DECIDE ultradeep phases, validation commands
