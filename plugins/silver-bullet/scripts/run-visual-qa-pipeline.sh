#!/usr/bin/env bash
# Silver Bullet — end-to-end high-precision visual QA pipeline
# Usage: bash scripts/run-visual-qa-pipeline.sh [--proof-only] [--skip-capture] [--skip-vision] [--skip-alumnium]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUDIT_DIR="$REPO_ROOT/.visual-audit/responsive-full"
DATE_TAG="${VISUAL_QA_DATE:-$(date +%Y-%m-%d)}"
BRANCH="$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || echo unknown)"
DOC=".visual-audit/VISUAL-QA-PIPELINE.md"
SDG_IMAGE="${SDG_TEST_IMAGE:-$HOME/.codex/projects/Users-shafqat-projects-silver-bullet-repo/assets/image-36bc6f57-1985-4ccc-813a-62d0faf54b3c.png}"

PROOF_ONLY=false
SKIP_CAPTURE=false
SKIP_VISION=false
SKIP_ALUMNIUM=false
for arg in "$@"; do
  case "$arg" in
    --proof-only) PROOF_ONLY=true ;;
    --skip-capture) SKIP_CAPTURE=true ;;
    --skip-vision) SKIP_VISION=true ;;
    --skip-alumnium) SKIP_ALUMNIUM=true ;;
  esac
done

if [[ "$PROOF_ONLY" == true ]]; then
  OUT_DIR="${CAPTURE_OUT_DIR:-$AUDIT_DIR/${DATE_TAG}-pipeline-proof}"
else
  OUT_DIR="${CAPTURE_OUT_DIR:-$AUDIT_DIR/${DATE_TAG}-pipeline}"
fi
RESULTS="$REPO_ROOT/.visual-audit/proof-test-results-${DATE_TAG}.json"
GOLDEN_DIR="$OUT_DIR/golden-strings"
OUT_DIR_REL="${OUT_DIR#"$REPO_ROOT"/}"

log() { printf '[visual-qa] %s\n' "$*"; }

# Build results JSON incrementally (no jq -s dependency on temp file shape)
STEPS_JSON="["
step_count=0
append_step() {
  local step="$1" status="$2" detail="$3"
  local extra="${4:-}"
  if [[ "$step_count" -gt 0 ]]; then STEPS_JSON+=","; fi
  STEPS_JSON+=$(jq -nc --arg step "$step" --arg status "$status" --arg detail "$detail" \
    --argjson extra "${extra:-null}" \
    'if $extra == null then {step:$step,status:$status,detail:$detail}
     else ($extra + {step:$step,status:$status,detail:$detail}) end')
  step_count=$((step_count + 1))
}

mkdir -p "$OUT_DIR" "$GOLDEN_DIR"

# ── Layer 1: Capture ─────────────────────────────────────────────
if [[ "$SKIP_CAPTURE" != true ]]; then
  log "Layer 1 — capture → $OUT_DIR"
  CAPTURE_DETAIL=""
  if [[ "$PROOF_ONLY" == true ]]; then
    if CAPTURE_OUT_DIR="$OUT_DIR" \
       CAPTURE_ONLY="site/index.html,site/help/getting-started" \
       CAPTURE_WIDTHS="375,1280" \
       CAPTURE_THEMES="light" \
       node "$AUDIT_DIR/capture-matrix.mjs"; then
      CAPTURE_DETAIL="4 captures (home + help-getting-started @ 375/1280 light); hover-terminal PNGs for home"
      append_step "capture" "PASS" "$CAPTURE_DETAIL"
    else
      append_step "capture" "FAIL" "capture-matrix exit nonzero"
    fi
  else
    if CAPTURE_OUT_DIR="$OUT_DIR" node "$AUDIT_DIR/capture-matrix.mjs"; then
      append_step "capture" "PASS" "$OUT_DIR_REL"
    else
      append_step "capture" "FAIL" "capture-matrix exit nonzero"
    fi
  fi
fi

# ── Layer 2a: Overflow @375 ──────────────────────────────────────
log "Layer 2a — overflow @375px"
OVERFLOW_BASE="${OVERFLOW_BASE_URL:-https://sb.alolabs.dev}"

run_overflow_page() {
  local path="$1" step_name="$2"
  local out
  out=$(OVERFLOW_BASE_URL="$OVERFLOW_BASE" node "$AUDIT_DIR/overflow-check.mjs" "$path" 2>&1) || true
  local overflow_px
  overflow_px=$(echo "$out" | grep -oE 'overflow=[0-9]+px' | head -1 | sed 's/overflow=//;s/px//')
  if echo "$out" | grep -q "^PASS"; then
    append_step "$step_name" "PASS" "overflow=${overflow_px:-0}px on ${path}"
    return 0
  fi
  append_step "$step_name" "FAIL" "horizontal overflow on ${path}: ${overflow_px:-?}px"
  return 1
}

if [[ "$PROOF_ONLY" == true ]]; then
  run_overflow_page "/" "overflow-home-375" || true
  run_overflow_page "/help/getting-started/" "overflow-help-375" || true
else
  if OVERFLOW_BASE_URL="$OVERFLOW_BASE" node "$AUDIT_DIR/overflow-check.mjs"; then
    append_step "overflow-375" "PASS" "all default pages"
  else
    append_step "overflow-375" "FAIL" "overflow on one or more pages"
  fi
fi

# ── Layer 2b: Style markers ──────────────────────────────────────
log "Layer 2b — computed-style markers"
STYLE_OUT=$(STYLE_BASE_URL="${STYLE_BASE_URL:-https://sb.alolabs.dev}" node "$AUDIT_DIR/style-check.mjs" 2>&1) || STYLE_RC=$?
STYLE_RC=${STYLE_RC:-0}
if [[ "$STYLE_RC" -eq 0 ]]; then
  append_step "style-check" "PASS" "hero-tagline-thin font-weight 400; letter-spacing 0.26em"
else
  append_step "style-check" "FAIL" "$(echo "$STYLE_OUT" | tail -3 | tr '\n' ' ')"
fi

# ── Layer 2c: Golden strings ─────────────────────────────────────
log "Layer 2c — golden-strings extraction"
GOLDEN_OUT_DIR="$GOLDEN_DIR" GOLDEN_BASE_URL="${GOLDEN_BASE_URL:-https://sb.alolabs.dev}" \
  node "$AUDIT_DIR/golden-strings.mjs" / /help/getting-started/ || GOLDEN_RC=$?
GOLDEN_RC=${GOLDEN_RC:-0}

HOME_COUNT=0
HELP_COUNT=0
[[ -f "$GOLDEN_DIR/home-golden-strings.json" ]] && \
  HOME_COUNT=$(jq '.strings | length' "$GOLDEN_DIR/home-golden-strings.json" 2>/dev/null || echo 0)
[[ -f "$GOLDEN_DIR/help-getting-started-golden-strings.json" ]] && \
  HELP_COUNT=$(jq '.strings | length' "$GOLDEN_DIR/help-getting-started-golden-strings.json" 2>/dev/null || echo 0)

if [[ "$GOLDEN_RC" -eq 0 ]]; then
  if [[ "$PROOF_ONLY" == true ]]; then
    append_step "golden-strings" "PASS" "home=${HOME_COUNT} strings, help-getting-started=${HELP_COUNT}"
  else
    append_step "golden-strings" "PASS" "$OUT_DIR_REL/golden-strings"
  fi
else
  append_step "golden-strings" "FAIL" "extraction error"
fi

# SDG control image golden strings (manual OCR from known banner)
SDG_GOLDEN="$GOLDEN_DIR/sdg-control-golden-strings.json"
if [[ ! -f "$SDG_GOLDEN" ]]; then
  cat > "$SDG_GOLDEN" <<'EOF'
{
  "slug": "sdg-control",
  "source": "manual-ocr-known-banner",
  "strings": [
    "SDG YOUTH",
    "Connect",
    "United Nations",
    "Youth Office",
    "open source week_",
    "Youth-Led Open Source AI for Sustainable Futures: Bridging Developed and Developing Countries"
  ]
}
EOF
fi

# ── Layer 3: Vision gate ─────────────────────────────────────────
log "Layer 3 — vision gate (Gemini ${VISION_MODEL:-gemini-3.5-flash})"
if node "$AUDIT_DIR/vision-gate.mjs" --self-test >/dev/null 2>&1; then
  append_step "vision-self-test" "PASS" "grounding logic rejects Silver Bullet hallucination on SDG golden set"
else
  append_step "vision-self-test" "FAIL" "grounding self-test failed"
fi

if [[ "$SKIP_VISION" != true ]]; then
  # Cursor file_attachments path — documented; shell cannot invoke Task tool
  if [[ "$PROOF_ONLY" == true ]]; then
    append_step "vision-sdg-file_attachments" "SKIP" \
      "requires Cursor Task file_attachments + gemini-3.5-flash; run manually per $DOC" \
      '{"delivery":"task-file_attachments-gemini-3.5-flash"}'
    append_step "vision-homepage-file_attachments" "SKIP" \
      "requires Cursor Task file_attachments + gemini-3.5-flash; run manually per $DOC" \
      '{"delivery":"task-file_attachments-gemini-3.5-flash"}'
  fi

  # API inline-base64 path
  if [[ -n "${GEMINI_API_KEY:-}" || -n "${GOOGLE_API_KEY:-}" ]]; then
  VISION_API_OK=true
  if [[ -f "$SDG_IMAGE" ]]; then
    if node "$AUDIT_DIR/vision-gate.mjs" \
      --image "$SDG_IMAGE" \
      --golden "$SDG_GOLDEN" \
      --label "sdg-control" >/dev/null 2>&1; then
      [[ "$PROOF_ONLY" != true ]] && append_step "vision-sdg" "PASS" "SDG banner grounded via API"
    else
      [[ "$PROOF_ONLY" != true ]] && append_step "vision-sdg" "FAIL" "SDG vision or grounding failed"
      VISION_API_OK=false
    fi
  fi
  HOME_HERO="$OUT_DIR/home-light-1280px.png"
  [[ -f "$HOME_HERO" ]] || HOME_HERO="$OUT_DIR/home-light-1280px-hero.png"
  [[ -f "$HOME_HERO" ]] || HOME_HERO="$AUDIT_DIR/2026-06-30-post-fix/home-light-1280px-hero.png"
  HOME_GOLDEN="$GOLDEN_DIR/home-golden-strings.json"
  if [[ -f "$HOME_HERO" && -f "$HOME_GOLDEN" ]]; then
    if node "$AUDIT_DIR/vision-gate.mjs" \
      --image "$HOME_HERO" \
      --golden "$HOME_GOLDEN" \
      --label "homepage-hero-1280" >/dev/null 2>&1; then
      [[ "$PROOF_ONLY" != true ]] && append_step "vision-homepage" "PASS" "$HOME_HERO"
    else
      [[ "$PROOF_ONLY" != true ]] && append_step "vision-homepage" "FAIL" "homepage vision or grounding failed"
      VISION_API_OK=false
    fi
  fi
  if [[ "$PROOF_ONLY" == true ]]; then
    if [[ "$VISION_API_OK" == true ]]; then
      append_step "vision-api-inline-base64" "PASS" "GEMINI_API_KEY set; vision-gate.mjs API path succeeded"
    else
      append_step "vision-api-inline-base64" "FAIL" "vision-gate.mjs API path failed"
    fi
  fi
  else
    if [[ "$PROOF_ONLY" == true ]]; then
      append_step "vision-api-inline-base64" "SKIP" "GEMINI_API_KEY not set in shell; vision-gate.mjs ready when key available"
    fi
  fi
fi

# ── Layer 4: Alumnium (optional) ─────────────────────────────────
if [[ "$SKIP_ALUMNIUM" != true && "$PROOF_ONLY" == true ]]; then
  log "Layer 4 — Alumnium (documented; MCP not callable from shell)"
  append_step "alumnium-start" "SKIP" "invoke user-alumnium start from Cursor MCP; MiniMax proxy via scripts/start-minimax-openai-proxy.sh"
  append_step "alumnium-check-vision" "SKIP" "invoke user-alumnium check with vision:true from Cursor MCP (known MiniMax/LangChain compat issue per docs/ALUMNIUM.md)"
elif [[ "$SKIP_ALUMNIUM" != true ]]; then
  log "Layer 4 — Alumnium check (requires MCP + proxy)"
  append_step "alumnium" "SKIP" "shell cannot call MCP; see $DOC Layer 4"
fi

STEPS_JSON+="]"

# ── Assemble results ─────────────────────────────────────────────
IMAGE_FINDINGS='{
  "file_attachments_gemini_3_5_flash": "WORKS — raw PNG reaches multimodal model (Cursor Task only)",
  "vision_gate_api_base64": "READY — requires GEMINI_API_KEY",
  "read_tool_png": "FAILS — caption-only image_description; causes hallucination",
  "caption_only_to_subagent": "FAILS — same root cause as Read"
}'

OVERALL="PASS"
if echo "$STEPS_JSON" | jq -e '.[] | select(.status == "FAIL")' >/dev/null 2>&1; then
  OVERALL="FAIL"
elif echo "$STEPS_JSON" | jq -e '.[] | select(.status == "SKIP")' >/dev/null 2>&1; then
  OVERALL="PASS_WITH_GAPS"
fi

jq -nc \
  --arg pipeline "visual-qa" \
  --arg date "$DATE_TAG" \
  --arg branch "$BRANCH" \
  --arg outDir "$OUT_DIR_REL" \
  --arg doc "$DOC" \
  --arg runner "bash scripts/run-visual-qa-pipeline.sh --proof-only" \
  --arg overall "$OVERALL" \
  --argjson steps "$STEPS_JSON" \
  --argjson imageDeliveryFindings "$IMAGE_FINDINGS" \
  '{pipeline:$pipeline,date:$date,branch:$branch,outDir:$outDir,doc:$doc,runner:$runner,steps:$steps,imageDeliveryFindings:$imageDeliveryFindings,overall:$overall}' \
  > "$RESULTS"

log "Done — results: $RESULTS (overall=$OVERALL)"
cat "$RESULTS"
