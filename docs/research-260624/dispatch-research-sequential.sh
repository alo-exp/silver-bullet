#!/usr/bin/env bash
# Sequential dispatch: run 6 OCG models one after another.
# Avoids MCP port conflicts that come with parallel subprocesses.

set -u
PROMPT_FILE="/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/SB_PRIOR_ART_RESEARCH_PROMPT.md"
OUTPUT_DIR="/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output"
mkdir -p "$OUTPUT_DIR"

MODELS=(
  "opencode-go/minimax-m3:ocg-minimax-m3"
  "opencode-go/qwen3.7-max:ocg-qwen3-7-max"
  "opencode-go/deepseek-v4-pro:ocg-deepseek-v4-pro"
  "opencode-go/glm-5.2:ocg-glm-5.2"
  "opencode-go/kimi-k2.6:ocg-kimi-k2.6"
  "opencode-go/mimo-v2.5-pro:ocg-mimo-v2.5-pro"
)

AGENT_TIMEOUT=1500
PROMPT=$(cat "$PROMPT_FILE")

for entry in "${MODELS[@]}"; do
  MODEL="${entry%%:*}"
  SLUG="${entry##*:}"
  OUTPUT_FILE="$OUTPUT_DIR/$SLUG.md"
  ERR_FILE="$OUTPUT_DIR/$SLUG.err"
  TITLE="sb-prior-art-${SLUG}-$(date +%s)"

  echo "[$(date +%H:%M:%S)] === Starting $SLUG on $MODEL ==="

  START=$(date +%s)
  (
    npx -y opencode-ai run \
      --model "$MODEL" \
      --title "$TITLE" \
      --dangerously-skip-permissions \
      "$PROMPT" \
      > "$OUTPUT_FILE" 2> "$ERR_FILE"
  ) &
  PID=$!

  WAITED=0
  while kill -0 "$PID" 2>/dev/null; do
    if [ "$WAITED" -ge "$AGENT_TIMEOUT" ]; then
      echo "[$(date +%H:%M:%S)] TIMEOUT — killing PID=$PID after ${AGENT_TIMEOUT}s"
      kill -9 "$PID" 2>/dev/null
      break
    fi
    sleep 15
    WAITED=$((WAITED+15))
    if [ $((WAITED % 60)) -eq 0 ]; then
      echo "[$(date +%H:%M:%S)]   ... still running ($((WAITED/60))m elapsed)"
    fi
  done
  wait "$PID" 2>/dev/null
  EXIT_CODE=$?
  END=$(date +%s)
  DURATION=$((END-START))

  SIZE=$(stat -f%z "$OUTPUT_FILE" 2>/dev/null || echo 0)
  echo "[$(date +%H:%M:%S)]   done. exit=$EXIT_CODE duration=${DURATION}s output_size=$SIZE bytes"
  echo "---"
done

echo "[$(date +%H:%M:%S)] === All 6 agents complete ==="
ls -la "$OUTPUT_DIR"/*.md "$OUTPUT_DIR"/*.err 2>/dev/null | awk '{print $5, $9}'