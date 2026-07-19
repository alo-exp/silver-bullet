#!/usr/bin/env bash
# Launcher for final multimarket ultradeep DR live run (long-running; allowlisted).
set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO_ROOT/research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final"
mkdir -p "$OUT"
cd "$REPO_ROOT"
exec python3 skills/silver-deep-research-multi-ai/scripts/dr_multi_ai_cli.py \
  "Agentic SDLC orchestration landscape multimarket final — APO primary, SDLC plugins secondary (BMAD GSD Superpowers Spec Kit Oh My Zuvo OSS), agentic SDLC SaaS tertiary (Factory Devin Augment Cosmos)" \
  --mode ultradeep \
  --research-type solution-landscape \
  --output-root "$OUT" \
  --ocg-pool lite \
  --cursor-pool none \
  --include-only ocg-minimax-m3 \
  --include-only ocg-qwen3.7-plus \
  --include-only ocg-deepseek-v4-flash \
  --include-only ocg-kimi-k2.7-code \
  --include-only ocg-mimo-v2.5 \
  --include-only gemini-3.5-flash \
  --include-only gpt-5.6-luna-medium \
  --include-only claude-opus-4.8-medium \
  --timeout-sec 1200 \
  --force \
  >"$OUT/run.log" 2>&1
