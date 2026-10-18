# shellcheck shell=bash
# Shared helpers for the E-core-hooks coverage tests. Source after tl_init.
#
#   ec_project [dir]         git repo + .silver-bullet.json + silver-bullet.md in $EC_PROJ
#   ec_cfg '<json>'          overwrite $EC_PROJ/.silver-bullet.json
#   ec_stage_hooks DIR [lib...]   copy hooks/ (scripts + lib) to DIR, then drop the named lib files

EC_REPO="$TL_REPO_ROOT"

ec_project() {
  EC_PROJ="${1:-$TL_TMP/proj}"
  mkdir -p "$EC_PROJ"
  tl_git_repo "$EC_PROJ"
  EC_CFG="$EC_PROJ/.silver-bullet.json"
  printf '# Silver Bullet\n' >"$EC_PROJ/silver-bullet.md"
  printf '%s\n' '.silver-bullet.json' 'silver-bullet.md' >>"$EC_PROJ/.git/info/exclude"
  printf '%s\n' '{"config_version":"0.40.0","sb_initiated":true,"project":{"src_pattern":"/src/","active_workflow":"full-dev-cycle"},"skills":{}}' >"$EC_CFG"
}

ec_cfg() { printf '%s\n' "$1" >"$EC_CFG"; }

ec_stage_hooks() {
  # Symlink farm (coverage maps DEST/hooks/... to the real files): every hooks/ entry
  # and every hooks/lib entry linked into DEST/hooks, minus the named lib files.
  # "-" as the first exclusion drops the whole lib directory.
  local dest="${1:?}"
  shift
  local f ex skip
  rm -rf "${dest:?}"
  mkdir -p "$dest/hooks/lib"
  for f in "$EC_REPO"/hooks/*; do
    [[ "${f##*/}" == "lib" ]] || ln -s "$f" "$dest/hooks/${f##*/}"
  done
  if [[ "${1:-}" == "-" ]]; then
    rmdir "$dest/hooks/lib"
    return 0
  fi
  for f in "$EC_REPO"/hooks/lib/*; do
    skip=0
    for ex in "$@"; do [[ "${f##*/}" == "$ex" ]] && skip=1; done
    [[ "$skip" -eq 1 ]] || ln -s "$f" "$dest/hooks/lib/${f##*/}"
  done
}

# ec_real NAME: the real NAME on PATH with every $TL_BIN entry removed, wherever it sits,
# so a shim never resolves to itself.
ec_real() {
  local p path=""
  local IFS=:
  for p in $PATH; do
    [[ "$p" == "$TL_BIN" ]] || path="${path:+$path:}$p"
  done
  PATH="$path" command -v "$1"
}

# ec_fail NAME GLOB: shim NAME so it exits 1 when its argument string matches the case
# glob (e.g. '*"--show-current"*'); every other call runs the real command.
ec_fail() {
  local name="$1" glob="$2" real
  real="$(ec_real "$name")"
  tl_stub "$name" "case \"\$*\" in $glob) exit 1;; esac; exec $real \"\$@\""
  hash -r
}
# ec_unfail NAME: remove the shim
ec_unfail() { rm -f "${TL_BIN:?}/${1:?}"; hash -r; }

# ec_flaky_fn NAME N: export a function NAME that succeeds for its first N-1 calls and
# fails afterwards (call counter in $TL_TMP/flaky-NAME).
ec_flaky_fn() {
  local name="$1" n="$2"
  rm -f "$TL_TMP/flaky-$name"
  eval "$name() { local c; c=\$(cat '$TL_TMP/flaky-$name' 2>/dev/null || echo 0); echo \$((c + 1)) >'$TL_TMP/flaky-$name'; [[ \$c -lt $((n - 1)) ]]; }"
  export -f "${name?}"
}

# ec_freeze_date YYYY-MM-DD: stub `date` so the calendar-day format ('+%Y-%m-%d') is fixed and
# a run that straddles midnight cannot flip the result; every other date call is the real one.
ec_freeze_date() {
  local day="$1" real
  real="$(ec_real date)"
  tl_stub date "if [[ \"\$*\" == \"+%Y-%m-%d\" || \"\$*\" == \"'+%Y-%m-%d'\" ]]; then printf '%s\n' '$day'; exit 0; fi; exec $real \"\$@\""
  hash -r
}
