#!/usr/bin/env bash
# sb-doctor module — auto-split from sb-doctor.sh
doctor_host_install_script() {
  case "${1:-}" in
    claude) printf '%s\n' "${REPO_ROOT}/scripts/install-claude.sh" ;;
    codex) printf '%s\n' "${REPO_ROOT}/scripts/install-codex.sh" ;;
    cursor) printf '%s\n' "${REPO_ROOT}/scripts/install-cursor.sh" ;;
    *) return 1 ;;
  esac
}

doctor_apply_fixes() {
  local runtime="$1" check_id install_script fixed=0
  [[ "$DOCTOR_FIX" -eq 1 ]] || return 0
  [[ "$DOCTOR_FIX_APPLIED" -eq 1 ]] && return 0
  [[ "$FAIL" -eq 0 ]] && return 0
  for check_id in "${FAILED_CHECK_IDS[@]}"; do
    case "$check_id" in
      D13|D14|D16|D18|D19)
        install_script="$(doctor_host_install_script "$runtime" || true)"
        if [[ -n "$install_script" && -x "$install_script" ]]; then
          printf 'sb-doctor: --fix running %s for %s\n' "$install_script" "$check_id" >&2
          bash "$install_script" >&2 || true
          fixed=1
        fi
        ;;
      D15)
        printf 'sb-doctor: --fix D15 requires shortening Claude agent descriptions\n' >&2
        ;;
      D4)
        case "$runtime" in
          cursor) bash "${REPO_ROOT}/scripts/install-cursor.sh" --merge-hooks-only >&2 || true; fixed=1 ;;
          *)
            install_script="$(doctor_host_install_script "$runtime" || true)"
            [[ -n "$install_script" && -x "$install_script" ]] && bash "$install_script" >&2 || true
            fixed=1
            ;;
        esac
        ;;
      D21)
        local csba_fix_scope="global"
        if [[ -f "${PROJ_ROOT}/.silver-bullet.json" ]]; then
          csba_fix_scope="$(jq -r '.cursor_sb_agents.agents_install_scope // "global"' "${PROJ_ROOT}/.silver-bullet.json")"
        fi
        local csba_fix_flags=(--fix)
        if [[ "$csba_fix_scope" == "project" ]]; then
          csba_fix_flags+=(--project)
        else
          csba_fix_flags+=(--global)
        fi
        printf 'sb-doctor: --fix running install-cursor-sb-agents.sh for D21\n' >&2
        bash "${REPO_ROOT}/scripts/install-cursor-sb-agents.sh" "${csba_fix_flags[@]}" >&2 || true
        fixed=1
        ;;
    esac
    [[ "$fixed" -eq 1 ]] && break
  done
  [[ "$fixed" -eq 1 ]] && DOCTOR_FIX_APPLIED=1
}
