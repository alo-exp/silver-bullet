# shellcheck shell=bash
# Helpers for the scripts/lib/recommended-tools tests (probes, repairs, receipts).
# Source after tests/lib/testlib.sh and tl_init.
#
# Everything lives in the sandboxed HOME / TL_TMP: external tools are stubs, the
# "repo" the libraries resolve helper scripts from is a staged copy whose helper
# scripts only log their invocations.

export HR_RTLIB="$TL_REPO_ROOT/scripts/lib/recommended-tools"
HR_STAGE="$TL_TMP/hr-repo"
HR_LOG="$TL_TMP/hr-calls.log"
HR_PROJ="$TL_TMP/hr-proj"
export HR_LOG

# rc_of <cmd...>: print 0 or 1 (never fails)
rc_of() { local rc=0; "$@" >/dev/null 2>&1 || rc=1; printf '%s' "$rc"; }

# hr_stage_repo: a fake repo root with the real hook libs and logging helpers.
hr_stage_repo() {
  rm -rf "$HR_STAGE"
  mkdir -p "$HR_STAGE/scripts/lib/global-toolstack" "$HR_STAGE/hooks"
  ln -s "$TL_REPO_ROOT/hooks/lib" "$HR_STAGE/hooks/lib"
  local py
  for py in patch-mcp patch-hooks install-pi; do
    cat >"$HR_STAGE/scripts/lib/global-toolstack/$py.py" <<EOF
import os, sys
env = " ".join("%s=%s" % (k, os.environ[k]) for k in sorted(os.environ) if k.startswith("RT_PATCH_") or k in ("RT_HOST", "TOOLSTACK_REPO_ROOT"))
open(os.environ["HR_LOG"], "a").write("$py %s | %s\n" % (" ".join(sys.argv[1:]), env))
out = os.environ.get("HR_PY_OUT_$py".replace("-", "_"), "")
if out:
    print(out)
hook = os.environ.get("HR_PY_HOOK_$py".replace("-", "_"))
if hook:
    os.system(hook)
sys.exit(int(os.environ.get("HR_PY_RC_$py".replace("-", "_"), "0")))
EOF
  done
  cat >"$HR_STAGE/scripts/lib/merge-token-compression-config.py" <<'EOF'
import os, sys
open(os.environ["HR_LOG"], "a").write("merge-token-compression %s\n" % " ".join(sys.argv[1:]))
sys.exit(int(os.environ.get("HR_PY_RC_merge_token", "0")))
EOF
  local sh
  for sh in optimize-rtk-context-mode install-leanctx-sb; do
    cat >"$HR_STAGE/scripts/$sh.sh" <<EOF
#!/usr/bin/env bash
printf '%s %s | batch=%s progress=%s\n' "$sh" "\$*" "\${RT_CROSS_TOOL_BATCH:-}" "\${TOOLSTACK_INSTALL_IN_PROGRESS:-}" >>"\$HR_LOG"
exit "\${HR_SH_RC_${sh//-/_}:-0}"
EOF
  done
  : >"$HR_LOG"
  export RT_REPO_ROOT="$HR_STAGE"
}

# hr_project: a git project with the given .silver-bullet.json (default: empty object)
hr_project() {
  if [[ ! -d "$HR_PROJ/.git" ]]; then
    tl_git_repo "$HR_PROJ"
  fi
  printf '%s\n' "${1:-{\}}" >"$HR_PROJ/.silver-bullet.json"
  export RT_PROJECT_ROOT="$HR_PROJ"
}

# hr_consent <tool>=<enabled|disabled|pending|suspended> ...: build project config
hr_consent() {
  local json='{"sb_initiated":true,"recommended_tools":{}}' spec tool state
  for spec in "$@"; do
    tool="${spec%%=*}"; state="${spec#*=}"
    case "$state" in
      enabled) json="$(jq -c --arg t "$tool" '.recommended_tools[$t] = {enabled_by_user:true}' <<<"$json")" ;;
      disabled) json="$(jq -c --arg t "$tool" '.recommended_tools[$t] = {enabled_by_user:false}' <<<"$json")" ;;
      suspended) json="$(jq -c --arg t "$tool" '.recommended_tools[$t] = {enabled_by_user:true,enforcement_suspended:true}' <<<"$json")" ;;
      pending) json="$(jq -c --arg t "$tool" '.recommended_tools[$t] = {enabled_by_user:null}' <<<"$json")" ;;
    esac
  done
  hr_project "$json"
}

# hr_manifest <tool>=<command> ...: write the global toolstack manifest
hr_manifest() {
  local json='{"tools":{}}' spec
  for spec in "$@"; do
    json="$(jq -c --arg t "${spec%%=*}" --arg c "${spec#*=}" '.tools[$t].command = $c' <<<"$json")"
  done
  export SB_GLOBAL_TOOLSTACK_MANIFEST="$TL_TMP/hr-manifest.json"
  printf '%s\n' "$json" >"$SB_GLOBAL_TOOLSTACK_MANIFEST"
}

# hr_bin <name> [body]: executable stub in a dedicated bin dir that is on PATH
HR_BIN="$TL_TMP/hr-bin"
mkdir -p "$HR_BIN"
case ":$PATH:" in *":$HR_BIN:"*) ;; *) PATH="$HR_BIN:$PATH"; export PATH ;; esac
hr_bin() {
  printf '#!/usr/bin/env bash\n%s\n' "${2:-exit 0}" >"$HR_BIN/$1"
  chmod +x "$HR_BIN/$1"
  hash -r
}
hr_nobin() { rm -f "$HR_BIN/$1"; hash -r; }

# hr_state <probe-json>: component state summary "canonical|activation|evidence,csv|repairable"
hr_state() {
  jq -r '"\(.canonical_state)|\(.activation_status)|\(.evidence | join(","))|\(.repairable)"' <<<"$1"
}

# hr_path_without <name>...: print a PATH made of the essential coreutils plus the
# current stubs, minus the named commands. Much cheaper than tl_path_without (which
# mirrors the whole PATH) and rebuilt on every call, so later stubs are honoured.
HR_ESSENTIALS="bash sh env cat head tail tr sed awk grep egrep cut sort uniq wc paste find xargs date mkdir rmdir rm cp mv ln chmod touch mktemp dirname basename readlink realpath stat od uname id kill sleep sha256sum shasum jq git python3 python timeout gtimeout printf true false test tee diff comm expr nohup"
hr_path_without() {
  local dir="$TL_TMP/hr-path-$RANDOM$RANDOM" name skip ex real
  mkdir -p "$dir"
  for name in $HR_ESSENTIALS; do
    skip=0
    for ex in "$@"; do [[ "$name" == "$ex" ]] && skip=1; done
    [[ "$skip" -eq 0 ]] || continue
    real="$(PATH="$HR_ORIG_PATH" command -v "$name" 2>/dev/null || true)"
    [[ -n "$real" && -x "$real" ]] && ln -s "$real" "$dir/$name"
  done
  for real in "$HR_BIN"/* "$TL_BIN"/*; do
    [[ -x "$real" ]] || continue
    name="${real##*/}"
    skip=0
    for ex in "$@"; do [[ "$name" == "$ex" ]] && skip=1; done
    [[ "$skip" -eq 0 && ! -e "$dir/$name" ]] && ln -s "$real" "$dir/$name"
  done
  printf '%s' "$dir"
}
HR_ORIG_PATH="$PATH"
