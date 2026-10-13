#!/usr/bin/env bash
# Parallel OpenCode deep-research dispatch — Canonical SDLC Process Architecture
# Maps ocg-* subagent slugs to opencode-go models (primary invocation pattern).
set -u

REPO="/Users/shafqat/projects/silver-bullet/repo"
BRIEF="${REPO}/research/2026-07-12-canonical-sdlc-process-architecture/RESEARCH-BRIEF.md"
BASE_OUT="${REPO}/research/2026-07-12-canonical-sdlc-process-architecture"
OPENCODE="${OPENCODE_BIN:-$HOME/.opencode/bin/opencode}"
AGENT_TIMEOUT="${AGENT_TIMEOUT:-3600}"

# User-requested ocg agents → model mapping (from ~/.config/opencode/opencode.jsonc)
MODELS=(
  "opencode-go/minimax-m3:ocg-minimax-m3"
  "opencode-go/qwen3.7-plus:ocg-qwen3.7-plus"
  "opencode-go/deepseek-v4-flash:ocg-deepseek-v4-flash"
  "opencode-go/kimi-k2.7-code:ocg-kimi-k2.7-code"
  "opencode-go/mimo-v2.5:ocg-mimo-v2.5"
)

mkdir -p "$BASE_OUT"
PROMPT="$(cat "$BRIEF")"

PIDS=()
for entry in "${MODELS[@]}"; do
  MODEL="${entry%%:*}"
  SLUG="${entry##*:}"
  OUT_DIR="${BASE_OUT}/${SLUG}"
  mkdir -p "$OUT_DIR"
  OUT_FILE="${OUT_DIR}/research_report.md"
  ERR_FILE="${OUT_DIR}/run.err"
  LOG_FILE="${OUT_DIR}/run.log"
  TITLE="sdlc-arch-${SLUG}-$(date -u +%Y%m%dT%H%M%SZ)"

  AGENT_PROMPT="${PROMPT}

---
## Agent-specific instructions

- **Your agent slug:** ${SLUG}
- **Your model:** ${MODEL}
- **Output directory (write ALL artifacts here):** ${OUT_DIR}/
- Invoke /silver:deep-research methodology at ultradeep depth.
- Use web search and fetch for real sources. Write all required files to your output directory.
- Primary deliverable: ${OUT_FILE} with all 10 required sections.
- Set run_manifest.json agent_slug=${SLUG}, model=${MODEL}, started_at=$(date -u +%Y-%m-%dT%H:%M:%SZ).
"

  echo "[$(date +%H:%M:%S)] Launching ${SLUG} on ${MODEL}"

  (
  cd "$REPO" || exit 1
  "$OPENCODE" run \
    --dir "$REPO" \
    --model "$MODEL" \
    --title "$TITLE" \
    --auto \
    "$AGENT_PROMPT" \
    > "$OUT_FILE" 2> "$ERR_FILE"
  echo $? > "${OUT_DIR}/exit.code"
  ) &
  PIDS+=("$!")
  echo -e "${SLUG}\n$!" > "${OUT_DIR}/pid.txt"
done

echo "[$(date +%H:%M:%S)] All ${#PIDS[@]} agents dispatched. PIDs: ${PIDS[*]}"
echo "${PIDS[*]}" > "${BASE_OUT}/dispatch.pids"

for i in "${!PIDS[@]}"; do
  PID="${PIDS[$i]}"
  WAITED=0
  while kill -0 "$PID" 2>/dev/null; do
    if [[ "$WAITED" -ge "$AGENT_TIMEOUT" ]]; then
      echo "[$(date +%H:%M:%S)] PID=$PID exceeded ${AGENT_TIMEOUT}s — killing"
      kill -9 "$PID" 2>/dev/null || true
      break
    fi
    sleep 15
    WAITED=$((WAITED + 15))
  done
  wait "$PID" 2>/dev/null || true
done

echo "[$(date +%H:%M:%S)] Dispatch complete."
echo "--- Output sizes ---"
find "$BASE_OUT" -maxdepth 2 -type f \( -name '*.md' -o -name '*.jsonl' -o -name '*.json' -o -name '*.err' \) -exec ls -la {} \;
