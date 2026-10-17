# shellcheck shell=bash
# Coverage tracer for Silver Bullet test runs.
#
# tests/coverage/run-coverage.sh exports BASH_ENV pointing at this file, so every
# non-interactive bash process started during a coverage run sources it before
# running its script. When SB_COV_DIR is set, xtrace is switched on and written to
# a per-process trace file under "$SB_COV_DIR/raw". Subshells inherit the open
# descriptor; new bash processes source this file again and open their own file.
#
# The trace descriptor is a fixed high number so it cannot collide with the
# {var}-allocated descriptors (10+) or the small lock descriptors scripts use.
# PS4 fields are separated by ASCII unit separators (0x1f):
#   +<sep><BASH_SOURCE><sep><LINENO><sep><BASHPID><sep><function depth><sep><command text>
# The process id and function depth let sbcov.py follow each process's run of
# records for one line across interleaved callee, subshell and process-substitution
# records (the depth is empty outside functions, which keeps `set -u` scripts
# quiet). sbcov.py reads only the first word of the command text.

if [[ -n "${SB_COV_DIR:-}" && -d "${SB_COV_DIR}/raw" ]]; then
  # The group-level 2>/dev/null is temporary; only fd 237 stays open.
  if { exec 237>>"${SB_COV_DIR}/raw/${BASHPID}.${RANDOM}${RANDOM}.trace"; } 2>/dev/null; then
    printf '#PWD\x1f%s\n' "$PWD" >&237
    BASH_XTRACEFD=237
    PS4=$'+\x1f${BASH_SOURCE[0]-}\x1f${LINENO}\x1f${BASHPID}\x1f${FUNCNAME[0]+${#FUNCNAME[@]}}\x1f'
    set -x
  fi
fi
