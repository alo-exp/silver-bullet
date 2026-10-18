#!/usr/bin/env bash
# scripts/lib/recommended-tools/vendor-doctor.sh: bounded, non-interactive vendor
# `doctor` runs (shared timeout helper, timeout(1), watchdog and no-sleep paths)
# and the usable-subcommand probe. Vendor CLIs are stubs in the sandboxed HOME.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

RTLIB="$TL_REPO_ROOT/scripts/lib/recommended-tools"
export RT_REPO_ROOT="$TL_REPO_ROOT"
rc_of() { local rc=0; "$@" >/dev/null 2>&1 || rc=1; printf '%s' "$rc"; }

# ======================================================== vendor doctor
BIN2="$TL_TMP/vbin"; mkdir -p "$BIN2"
printf '#!/usr/bin/env bash\nexit 0\n' >"$BIN2/okcmd"
printf '#!/usr/bin/env bash\nexit 3\n' >"$BIN2/badcmd"
printf '#!/usr/bin/env bash\ntrap "" TERM\nsleep 6\n' >"$BIN2/stubborn"
printf '#!/usr/bin/env bash\nsleep 30\n' >"$BIN2/hang"
chmod +x "$BIN2"/*
vd() { # <env-assignments...> -- <args...>; runs in a fresh shell, prints rc
  local envs=()
  while [[ "$1" != "--" ]]; do envs+=("$1"); shift; done
  shift
  local rc=0
  env "${envs[@]}" bash -c 'source "$1/vendor-doctor.sh"; shift; rt_run_vendor_doctor "$@"' _ "$RTLIB" "$@" >/dev/null 2>&1 || rc=$?
  printf '%s' "$rc"
}
assert_eq "skip flag -> 2" "2" "$(vd RT_SKIP_VENDOR_DOCTOR=1 -- "$BIN2/okcmd")"
assert_eq "apply mode -> 2" "2" "$(vd RT_MODE=apply -- "$BIN2/okcmd")"
assert_eq "no command -> 2" "2" "$(vd RT_MODE=verify --)"
assert_eq "shared timeout helper: success" "0" "$(vd RT_MODE=verify -- "$BIN2/okcmd")"
assert_eq "shared timeout helper: failure" "1" "$(vd RT_MODE=verify -- "$BIN2/badcmd")"
assert_eq "shared timeout helper: timeout" "1" "$(vd RT_MODE=verify RT_VENDOR_DOCTOR_TIMEOUT=1 -- "$BIN2/hang")"
# without the shared helper: timeout(1)
assert_eq "timeout(1) runner: success" "0" "$(vd RT_MODE=verify RT_REPO_ROOT="$TL_TMP/no-repo" -- "$BIN2/okcmd")"
assert_eq "timeout(1) runner: failure" "1" "$(vd RT_MODE=verify RT_REPO_ROOT="$TL_TMP/no-repo" -- "$BIN2/badcmd")"
# neither helper nor timeout/gtimeout: watchdog
NOTO="$(tl_path_without timeout gtimeout)"
assert_eq "watchdog: success" "0" "$(vd RT_MODE=verify RT_REPO_ROOT="$TL_TMP/no-repo" PATH="$NOTO" -- "$BIN2/okcmd")"
assert_eq "watchdog: failure" "1" "$(vd RT_MODE=verify RT_REPO_ROOT="$TL_TMP/no-repo" PATH="$NOTO" -- "$BIN2/badcmd")"
SECONDS=0
assert_eq "watchdog: hung command is terminated" "1" "$(vd RT_MODE=verify RT_REPO_ROOT="$TL_TMP/no-repo" PATH="$NOTO" RT_VENDOR_DOCTOR_TIMEOUT=1 -- "$BIN2/hang")"
assert_eq "watchdog: bounded run time" "1" "$([[ $SECONDS -lt 15 ]] && echo 1 || echo 0)"
assert_eq "watchdog: TERM-ignoring command is killed" "1" "$(vd RT_MODE=verify RT_REPO_ROOT="$TL_TMP/no-repo" PATH="$NOTO" RT_VENDOR_DOCTOR_TIMEOUT=1 -- "$BIN2/stubborn")"
# no sleep(1): nothing can bound the run, so the probe is reported failed
NOSLEEP="$(tl_path_without timeout gtimeout sleep)"
assert_eq "no sleep available -> failure" "1" "$(vd RT_MODE=verify RT_REPO_ROOT="$TL_TMP/no-repo" PATH="$NOSLEEP" -- "$BIN2/okcmd")"
# errexit state is restored
assert_eq "errexit preserved after the run" "e" "$(bash -c 'set -e; source "$1/vendor-doctor.sh"; rt_run_vendor_doctor "$2" >/dev/null 2>&1 || true; case $- in *e*) echo e;; *) echo x;; esac' _ "$RTLIB" "$BIN2/okcmd")"
assert_eq "errexit stays off when it was off" "x" "$(bash -c 'set +e; source "$1/vendor-doctor.sh"; rt_run_vendor_doctor "$2" >/dev/null 2>&1; case $- in *e*) echo e;; *) echo x;; esac' _ "$RTLIB" "$BIN2/okcmd")"
# sourcing twice is a no-op
assert_eq "second source is skipped" "ok" "$(bash -c 'source "$1/vendor-doctor.sh"; RT_VENDOR_DOCTOR_TIMEOUT=7; source "$1/vendor-doctor.sh"; [[ "$RT_VENDOR_DOCTOR_TIMEOUT" == 7 ]] && echo ok' _ "$RTLIB")"
# runner selection
runner() { env "$@" bash -c 'source "$1/vendor-doctor.sh"; rt_vendor_doctor_runner' _ "$RTLIB"; }
assert_eq "runner: timeout" "timeout" "$(runner RT_X=1)"
mkdir -p "$TL_TMP/gt"; printf '#!/bin/sh\nexit 0\n' >"$TL_TMP/gt/gtimeout"; chmod +x "$TL_TMP/gt/gtimeout"
assert_eq "runner: gtimeout" "gtimeout" "$(runner PATH="$(tl_path_without timeout):$TL_TMP/gt")"
assert_eq "runner: none" "" "$(runner PATH="$NOTO")"

# subcommand usability
# shellcheck source=/dev/null
source "$RTLIB/vendor-doctor.sh"
mkdir -p "$TL_TMP/doc"
mk_doc() { printf '#!/usr/bin/env bash\n%s\n' "$2" >"$TL_TMP/doc/$1"; chmod +x "$TL_TMP/doc/$1"; }
mk_doc good 'echo "usage: good doctor [--check]"'
mk_doc unknown 'echo "Error: unknown command doctor"; exit 1'
mk_doc tty 'echo "this requires a tty and an interactive prompt"'
mk_doc ttyflag 'echo "interactive prompt unless --yes is given"'
mk_doc helponly 'if [[ "$1" == help ]]; then echo "usage: doctor help"; fi'
mk_doc silent 'exit 0'
usable() { PATH="$TL_TMP/doc:$PATH" rc_of rt_vendor_doctor_subcommand_usable "$1"; }
assert_eq "usable doctor" "0" "$(usable good)"
assert_eq "unknown command" "1" "$(usable unknown)"
assert_eq "tty-only doctor skipped" "1" "$(usable tty)"
assert_eq "tty doctor with a batch flag is fine" "0" "$(usable ttyflag)"
assert_eq "falls back to 'help doctor'" "0" "$(usable helponly)"
assert_eq "silent doctor counts as usable" "0" "$(usable silent)"
assert_eq "missing binary" "1" "$(usable definitely-not-installed)"
assert_eq "empty binary name" "1" "$(rc_of rt_vendor_doctor_subcommand_usable "")"

tl_results
