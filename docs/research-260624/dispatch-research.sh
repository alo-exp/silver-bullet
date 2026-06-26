#!/usr/bin/env bash
# Dispatch the Silver Bullet prior-art research prompt to 6 OCG models in parallel.
# Each invocation runs the `build` primary agent on a different model.

set -u
PROMPT_FILE="/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/SB_PRIOR_ART_RESEARCH_PROMPT.md"
OUTPUT_DIR="/Users/shafqat/projects/silver-bullet/repo/docs/research-260624/agent-output"
mkdir -p "$OUTPUT_DIR"

# Models to dispatch (matches ocg-* subagent set)
MODELS=(
  "opencode-go/minimax-m3:ocg-minimax-m3"
  "opencode-go/qwen3.7-max:ocg-qwen3.7-max"
  "opencode-go/deepseek-v4-pro:ocg-deepseek-v4-pro"
  "opencode-go/glm-5.2:ocg-glm-5.2"
  "opencode-go/kimi-k2.6:ocg-kimi-k2.6"
  "opencode-go/mimo-v2.5-pro:ocg-mimo-v2.5-pro"
)

# Per-agent timeout in seconds (25 min)
AGENT_TIMEOUT=1500

# Read prompt once into a variable (avoid re-reading 6 times)
PROMPT=$(cat "$PROMPT_FILE")

# Launch all 6 in parallel
PIDS=()
for entry in "${MODELS[@]}"; do
  MODEL="${entry%%:*}"
  SLUG="${entry##*:}"
  OUTPUT_FILE="$OUTPUT_DIR/$SLUG.md"
  ERR_FILE="$OUTPUT_DIR/$SLUG.err"
  TITLE="sb-prior-art-${SLUG}-$(date +%s)"

  echo "[$(date +%H:%M:%S)] Launching $SLUG on $MODEL"

  (
    # Run the agent; redirect both stdout (output) and stderr (logs)
    npx -y opencode-ai run \
      --model "$MODEL" \
      --title "$TITLE" \
      --dangerously-skip-permissions \
      "$PROMPT" \
      > "$OUTPUT_FILE" 2> "$ERR_FILE"
  ) &
  PIDS+=("$!")
done

echo "[$(date +%H:%M:%S)] All 6 dispatched. PIDs: ${PIDS[*]}"
echo "[$(date +%H:%M:%S)] Waiting for completion (timeout ${AGENT_TIMEOUT}s per agent)..."

# Wait for all with timeout fallback
for i in "${!PIDS[@]}"; do
  PID="${PIDS[$i]}"
  WAITED=0
  while kill -0 "$PID" 2>/dev/null; do
    if [ "$WAITED" -ge "$AGENT_TIMEOUT" ]; then
      echo "[$(date +%H:%M:%S)] Agent PID=$PID exceeded ${AGENT_TIMEOUT}s, killing"
      kill -9 "$PID" 2>/dev/null
      break
    fi
    sleep 10
    WAITED=$((WAITED+10))
  done
  wait "$PID" 2>/dev/null
done

echo "[$(date +%H:%M:%S)] All agents complete."
echo "---"
echo "Output sizes:"
ls -la "$OUTPUT_DIR"/*.md "$OUTPUT_DIR"/*.err 2>/dev/null | awk '{print $5, $9}'