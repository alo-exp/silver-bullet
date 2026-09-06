#!/usr/bin/env bash
# Shared helpers for review-fix-ladder triage scenario
# (review → triage → file → launcher APPLY ACCEPT → verify).

review_fix_ladder_triage_scenario_enabled() {
  [[ "${SB_LIVE_REVIEW_FIX_LADDER_TRIAGE_SCENARIO:-0}" == "1" ]]
}

review_fix_ladder_seed_triage_workspace() {
  local work_dir="$1"
  local fixture_dir="$2"
  local resolver="$3"
  local mock_adapter="$4"

  if [[ ! -d "${work_dir}/.git" ]]; then
    git -C "$work_dir" init -q
    git -C "$work_dir" config user.email "triage-ladder-smoke@silver-bullet.test"
    git -C "$work_dir" config user.name "Triage Ladder Smoke"
  fi

  review_fix_ladder_seed_workspace "$work_dir" "$fixture_dir" "$resolver"

  cat >"${work_dir}/.silver-bullet.json" <<EOF
{
  "project": {"name": "triage-ladder-smoke", "active_workflow": "full-dev-cycle"},
  "issue_tracker": "custom",
  "issue_tracker_adapter": {
    "type": "custom",
    "create_issue_command": "${mock_adapter}",
    "dedupe_command": null,
    "payload_schema": "silver-triage-issue-v1"
  },
  "state": {"state_file": "${work_dir}/.silver-bullet/state", "trivial_file": "${work_dir}/.silver-bullet/trivial"}
}
EOF
  mkdir -p "${work_dir}/.silver-bullet" "${work_dir}/docs/issues"
  touch "${work_dir}/.silver-bullet/state" "${work_dir}/.silver-bullet/trivial"
  git -C "$work_dir" add .silver-bullet.json .silver-bullet docs/issues
  git -C "$work_dir" commit -q -m "triage scenario adapter config" || true
}

review_fix_ladder_write_mock_adapter() {
  local adapter_path="$1"
  local log_path="$2"
  cat >"$adapter_path" <<EOF
#!/usr/bin/env bash
payload=\$(cat)
echo "\$payload" >> "${log_path}"
jq -n --arg id "PM-TRIAGE-1" --arg url "https://pm.local/TRIAGE-1" \
  '{id: \$id, url: \$url, status: "created"}'
EOF
  chmod +x "$adapter_path"
}

review_fix_ladder_phase_from_prompt() {
  local prompt="$1"
  if printf '%s' "$prompt" | grep -qiE 'rung_[0-9]+_review|review-only|raw findings only'; then
    printf 'review\n'
  elif printf '%s' "$prompt" | grep -qiE '/sb:triage|sb:triage|rung_[0-9]+_triage|triage subagent'; then
    printf 'triage\n'
  elif printf '%s' "$prompt" | grep -qiE 'rung_[0-9]+_fix|fix subagent|APPLY ACCEPT|launcher apply accept'; then
    printf 'fix\n'
  elif printf '%s' "$prompt" | grep -qiE 'verify-only|verify_1|verify_2|readonly: true'; then
    printf 'verify\n'
  elif printf '%s' "$prompt" | grep -qiE 'LADDER_PASS'; then
    printf 'verify\n'
  else
    printf 'unknown\n'
  fi
}

review_fix_ladder_phase_prompt() {
  local phase="$1"
  local rung_index="$2"
  local rung_total="$3"
  local model="$4"
  local reasoning="$5"

  case "$phase" in
    review)
      cat <<EOF
Review-fix ladder triage scenario rung ${rung_index}/${rung_total}: state=rung_${rung_index}_review, model=${model}, reasoning=${reasoning}.

Scope: smoke-target.py only. Read CHARTER.md.

You are a review-only subagent. Report raw findings only — do NOT triage, classify, or fix.

Reply with one line starting REVIEW_RAW: naming the divide() zero-check defect from the charter.
EOF
      ;;
    triage)
      cat <<EOF
Review-fix ladder triage scenario rung ${rung_index}/${rung_total}: state=rung_${rung_index}_triage.

Invoke /sb:triage on the review findings for smoke-target.py. Classify the divide() defect.

Reply with one line starting TRIAGE_PASS: and include VALID-NONBLOCKER for the zero-check finding. Do not fix files.
EOF
      ;;
    file)
      cat <<EOF
Review-fix ladder triage scenario rung ${rung_index}/${rung_total}: state=rung_${rung_index}_file_valid_issues.

Orchestrator step: file valid issues via scripts/silver-add.sh adapter-create for VALID-NONBLOCKER findings.
EOF
      ;;
    fix)
      cat <<EOF
Review-fix ladder triage scenario: APPLY ACCEPT (launcher, not rung).

The launcher applies ACCEPT fixes to smoke-target.py, including every finding that is not wrong (Low, deferred, nitpicks, and minor if still applicable). Do not spawn a rung or fix subagent to patch the fixture. Do not tell the rung to fix.
EOF
      ;;
    verify)
      cat <<EOF
Review-fix ladder triage scenario rung ${rung_index}/${rung_total}: verify-only pass (readonly: true).

Verify smoke-target.py against CHARTER.md. Reply with LADDER_PASS: and one sentence on zero-check behavior.
EOF
      ;;
    *)
      return 1
      ;;
  esac
}

review_fix_ladder_cursor_phase_response() {
  local phase="$1"
  case "$phase" in
    review)
      printf '%s\n' 'REVIEW_RAW: divide() lacks a zero-divisor guard and will raise ZeroDivisionError when b is 0.'
      ;;
    triage)
      printf '%s\n' 'TRIAGE_PASS: VALID-NONBLOCKER — divide() must reject zero divisors per charter; filed via /sb:triage.'
      ;;
    fix)
      printf '%s\n' 'FIX_PASS: added zero check in divide() returning ValueError for b == 0.'
      ;;
    verify)
      printf '%s\n' 'LADDER_PASS: divide() now rejects zero divisors with an explicit error instead of ZeroDivisionError.'
      ;;
    *)
      printf '%s\n' 'LADDER_PASS: triage scenario phase complete.'
      ;;
  esac
}

review_fix_ladder_assert_phase_response() {
  local phase="$1"
  local response="$2"
  case "$phase" in
    review)
      printf '%s' "$response" | grep -qiE 'REVIEW_RAW:|ZeroDivisionError|zero check|BUG: no zero'
      ;;
    triage)
      printf '%s' "$response" | grep -qiE 'TRIAGE_PASS:|VALID-NONBLOCKER|/sb:triage|sb:triage'
      ;;
    fix)
      printf '%s' "$response" | grep -qiE 'FIX_PASS:|b == 0|!= 0|ValueError|ZeroDivisionError'
      ;;
    verify)
      review_fix_ladder_response_passes "$response"
      ;;
    *)
      return 1
      ;;
  esac
}

review_fix_ladder_assert_review_triage_separation() {
  local review_response="$1"
  local triage_response="$2"
  if printf '%s' "$review_response" | grep -qiE 'VALID-BLOCKER|VALID-NONBLOCKER|TRIAGE_PASS'; then
    return 1
  fi
  if ! printf '%s' "$triage_response" | grep -qiE 'TRIAGE_PASS:|VALID-'; then
    return 1
  fi
  return 0
}

review_fix_ladder_github_available() {
  command -v gh >/dev/null 2>&1 || return 1
  if [[ -n "${GITHUB_TOKEN:-}" || -n "${GH_TOKEN:-}" ]]; then
    return 0
  fi
  gh auth status >/dev/null 2>&1
}

review_fix_ladder_github_owner_repo() {
  local work_dir="$1"
  local remote owner_repo
  remote="$(git -C "$work_dir" remote get-url origin 2>/dev/null || true)"
  if [[ "$remote" == /* || "$remote" == file:* ]]; then
    printf '%s' "${SB_RFL_GITHUB_REPO:-alo-exp/enterprise-grade-test-app}"
    return 0
  fi
  owner_repo="$(printf '%s' "$remote" | sed 's|https://github.com/||;s|.git$||;s|git@github.com:||;s|:|/|')"
  printf '%s' "$owner_repo"
}

review_fix_ladder_seed_github_workspace() {
  local work_dir="$1"
  local fixture_dir="$2"
  local resolver="$3"

  if [[ ! -d "${work_dir}/.git" ]]; then
    git -C "$work_dir" init -q
    git -C "$work_dir" config user.email "triage-ladder-smoke@silver-bullet.test"
    git -C "$work_dir" config user.name "Triage Ladder Smoke"
  fi

  review_fix_ladder_seed_workspace "$work_dir" "$fixture_dir" "$resolver"

  cat >"${work_dir}/.silver-bullet.json" <<EOF
{
  "project": {"name": "triage-ladder-github", "active_workflow": "full-dev-cycle"},
  "issue_tracker": "github",
  "issue_tracker_adapter": {
    "type": "github",
    "create_issue_command": null,
    "dedupe_command": null,
    "payload_schema": "silver-triage-issue-v1"
  },
  "state": {"state_file": "${work_dir}/.silver-bullet/state", "trivial_file": "${work_dir}/.silver-bullet/trivial"}
}
EOF
  mkdir -p "${work_dir}/.silver-bullet" "${work_dir}/docs/issues"
  touch "${work_dir}/.silver-bullet/state" "${work_dir}/.silver-bullet/trivial"
  git -C "$work_dir" add .silver-bullet.json .silver-bullet docs/issues
  git -C "$work_dir" commit -q -m "triage scenario github adapter config" || true
}

review_fix_ladder_prepare_github_workdir() {
  local app_root="$1"
  local work_dir="$2"
  rm -rf "$work_dir"
  git clone --quiet "$app_root" "$work_dir"
}

review_fix_ladder_github_file_issue() {
  local work_dir="$1"
  local title="$2"
  local body="$3"
  local owner_repo label issue_url issue_num

  owner_repo="$(review_fix_ladder_github_owner_repo "$work_dir")"
  [[ -n "$owner_repo" ]] || return 1
  label="${SB_RFL_GITHUB_ISSUE_LABEL:-rfl-triage-e2e}"

  gh label create "$label" \
    --color "FBCA04" \
    --description "Review-fix-ladder triage E2E (auto)" \
    --repo "$owner_repo" >/dev/null 2>&1 || true
  gh label create "filed-by-silver-bullet" \
    --color "5319E7" \
    --description "Filed by Silver Bullet" \
    --repo "$owner_repo" >/dev/null 2>&1 || true

  issue_url="$(gh issue create \
    --repo "$owner_repo" \
    --title "$title" \
    --body "$body" \
    --label "$label" \
    --label "filed-by-silver-bullet" 2>/dev/null || true)"
  issue_url="$(printf '%s' "$issue_url" | grep -oE 'https://github.com/[^[:space:]]+/issues/[0-9]+' | tail -n 1 || true)"
  [[ -n "$issue_url" ]] || return 1
  printf '%s\n' "$issue_url"
}

review_fix_ladder_github_close_issue() {
  local work_dir="$1"
  local issue_num="$2"
  local owner_repo
  owner_repo="$(review_fix_ladder_github_owner_repo "$work_dir")"
  [[ -n "$owner_repo" && -n "$issue_num" ]] || return 0
  gh issue close "$issue_num" --repo "$owner_repo" --reason "not planned" >/dev/null 2>&1 || true
}
