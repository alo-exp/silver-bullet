#!/usr/bin/env bash
# R13-12: `make setup` must work where the system Python is externally managed (PEP 668):
# it installs into a virtualenv, never into the interpreter it was pointed at.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init

command -v make >/dev/null 2>&1 || { echo "SKIP: make not installed"; tl_results; exit 0; }

W="$TL_TMP/proj"
mkdir -p "$W"
cp "$TL_REPO_ROOT/Makefile" "$TL_REPO_ROOT/requirements-dev.txt" "$W/"
LOG="$TL_TMP/py.log"
: >"$LOG"

# Fake "system" python: refuses `pip install` like an externally-managed interpreter, and
# `-m venv DIR` builds a venv whose python records the pip installs it receives.
cat >"$TL_BIN/fakepy" <<FAKE
#!/usr/bin/env bash
echo "system \$*" >>"$LOG"
if [[ "\$1 \$2" == "-m pip" ]]; then
  echo "error: externally-managed-environment" >&2; exit 1
fi
if [[ "\$1 \$2" == "-m venv" ]]; then
  mkdir -p "\$3/bin"
  printf '#!/usr/bin/env bash\necho "venv \$*" >>"$LOG"\n' >"\$3/bin/python"
  chmod +x "\$3/bin/python"
  exit 0
fi
exit 0
FAKE
chmod +x "$TL_BIN/fakepy"

cd "$W"
tl_run make -o prereqs setup PYTHON=fakepy
assert_eq "setup succeeds on an externally managed python" 0 "$TL_STATUS"
assert_file_exists "virtualenv created" "$W/.venv/bin/python"
assert_contains "venv created by the system python" "$(cat "$LOG")" "system -m venv .venv"
assert_contains "packages installed by the venv python" "$(cat "$LOG")" "venv -m pip install -r requirements-dev.txt"
assert_not_contains "system python never runs pip" "$(cat "$LOG")" "system -m pip"

: >"$LOG"
tl_run make -o prereqs setup PYTHON=fakepy
assert_eq "second setup succeeds" 0 "$TL_STATUS"
assert_not_contains "second setup reuses the venv" "$(cat "$LOG")" "-m venv"
assert_contains "second setup still installs" "$(cat "$LOG")" "venv -m pip install"

printf 'showpath:\n\t@echo "$$PATH"\n' >"$W/extra.mk"
tl_run make -f Makefile -f extra.mk showpath
assert_match "venv bin first on PATH once it exists" "^$W/.venv/bin:" "$TL_OUT$TL_ERR"

# A different venv location is honoured.
rm -rf "$W/.venv"
tl_run make -o prereqs setup PYTHON=fakepy VENV=other-env
assert_file_exists "VENV override honoured" "$W/other-env/bin/python"

# Without a venv module the failure says what to install.
cat >"$TL_BIN/nopy" <<'FAKE'
#!/usr/bin/env bash
exit 1
FAKE
chmod +x "$TL_BIN/nopy"
tl_run make -o prereqs setup PYTHON=nopy VENV=none-env
assert_eq "setup fails without venv support" 2 "$TL_STATUS"
assert_contains "failure names the package to install" "$TL_OUT$TL_ERR" "python3-venv"

# A venv on PATH must stay active inside tests/run-all-tests.sh, which rebuilds PATH
# (R13-12: a symlink to the venv python resolved to the base interpreter).
V="$TL_TMP/venv run \$(touch $TL_TMP/PWNED)'q\"b"
mkdir -p "$V/t"
if python3 -m venv --without-pip "$V/.venv" >/dev/null 2>&1; then
  site="$("$V/.venv/bin/python" -c 'import site;print(site.getsitepackages()[0])')"
  echo "VALUE = 1" >"$site/sbvenvprobe.py"
  cat >"$V/t/test-venv-probe.sh" <<'PROBE'
#!/usr/bin/env bash
if python3 -c 'import sbvenvprobe' 2>/dev/null; then echo "venv package importable"; echo "Results: 1 passed, 0 failed"; else echo "venv package NOT importable"; echo "Results: 0 passed, 1 failed"; exit 1; fi
PROBE
  tl_run env PATH="$V/.venv/bin:$PATH" bash "$TL_REPO_ROOT/tests/run-all-tests.sh" "$V/t/test-venv-probe.sh"
  assert_eq "runner keeps the venv python active" 0 "$TL_STATUS"
  assert_contains "venv-only module imports through the runner" "$TL_OUT" "venv package importable"
  assert_file_absent "a venv path with shell metacharacters is never evaluated" "$TL_TMP/PWNED"
else
  echo "SKIP: python3 -m venv unavailable"
fi

tl_results
