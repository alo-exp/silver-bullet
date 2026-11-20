#!/usr/bin/env bash
# shellcheck disable=SC2034  # variables are consumed by the sourcing tests
# shellcheck shell=bash
# Shared fixtures for the integrity corpora (test-integrity-attacks.sh, test-integrity-honest.sh):
# a real project under a sandboxed runtime home, baselined by the real library, and the helpers
# that drive the real hooks around a REAL command.

source "$TL_REPO_ROOT/tests/lib/cov-a-dc.sh"
# shellcheck source=../../hooks/lib/integrity.sh
source "$TL_REPO_ROOT/hooks/lib/integrity.sh"

SD="$SB_RUNTIME_STATE_DIR"
RT="$SB_RUNTIME_NAME"
FX="$TL_TMP/fx"
export SD STATE PROJ FX RT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.test GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.test
CFG_NEW='{"skills":{"required_planning":[]}}'

# ih_diff ORIGFILE NEWFILE PATH: a unified diff turning ORIGFILE into NEWFILE, named a/PATH b/PATH
ih_diff() { diff -u --label "a/$3" --label "b/$3" "$1" "$2" || true; }

# ih_project NAME [jq filter]: a baselined project; the state holds one sealed unrelated skill.
ih_project() {
  SB_CONTRACT_UNLOCK_WINDOW=7200
  mkproj "$1" ".skills.all_tracked=[\"inst-a\",\"inst-b\"] | ${2:-.}"
  PROJ="$(cd "$PROJ" && pwd -P)"
  export PROJ
  rm -rf "$(_sb_iv_rec_file "$PROJ")"* "$SD/trivial" "$SD/unlock-hint" "$SD/seal-events.log" "$STATE" "$STATE.seal" "$STATE.hwm"
  printf '{}\n' >"$PROJ/.silver-bullet.prompt.json"
  printf 'rules\n' >"$PROJ/CLAUDE.md"
  printf 'agents\n' >"$PROJ/AGENTS.md"
  mkdir -p "$PROJ/.planning" "$PROJ/docs" "$PROJ/dist"
  for f in ROADMAP STATE PROJECT; do printf '%s\n' "$f" >"$PROJ/.planning/$f.md"; done
  printf 'readme\n' >"$PROJ/docs/README.md"
  printf 'a\n' >"$PROJ/src/app.js"
  git -C "$PROJ" add -A >/dev/null 2>&1
  git -C "$PROJ" commit -q -m base >/dev/null 2>&1 || true
  printf 'inst-b\n' >"$STATE"
  sb_state_seal_write "$STATE"
  sb_integrity_baseline "$PROJ" session
  # the recorder has tracked a skill here (record-skill.sh marks the keyed record)
  sb_integrity_baseline "$PROJ" tracked
  rm -rf "$FX"
  mkdir -p "$FX"
  printf '%s' "$SD" >"$FX/d.txt"
  printf '%s' "$PROJ" >"$FX/pd.txt"
  printf 'inst-a\n' >"$FX/forged.state"
  printf '%s\n' "$CFG_NEW" >"$FX/new.json"
  cp "$PROJ/.silver-bullet.json" "$FX/cfg.orig"
  ih_diff "$FX/cfg.orig" "$FX/new.json" .silver-bullet.json >"$FX/cfg.diff"
  awk 'NR <= 2 { print $0 " 2020-01-01 00:00:00.000000000 +0000"; next } { print }' "$FX/cfg.diff" >"$FX/cfg-space.diff"
  sed 's/^/  /' "$FX/cfg.diff" >"$FX/cfg-indent.diff"
  ih_diff "$FX/cfg.orig" "$FX/new.json" src/app.js >"$FX/h.diff"
  ih_diff "$PROJ/silver-bullet.md" "$FX/d.txt" silver-bullet.md >"$FX/md.diff"
  ih_diff /dev/null "$FX/forged.state" .silver-bullet/trivial >"$FX/tr.diff"
  ih_diff /dev/null "$FX/forged.state" trivial >"$FX/tr0.diff"
  python3 - "$FX" "$PROJ" <<'PYE'
import sys, base64, quopri, subprocess
fx, proj = sys.argv[1:3]
def mbox(path, body, enc):
    if enc == "base64":
        payload = base64.encodebytes(body.encode()).decode(); cte = "base64"
    else:
        payload = quopri.encodestring(body.encode()).decode(); cte = "quoted-printable"
    open(path, "w").write(
        "From 0000000000000000000000000000000000000000 Mon Sep 17 00:00:00 2001\n"
        "From: t <t@example.test>\nDate: Thu, 1 Jan 2026 00:00:00 +0000\nSubject: [PATCH] x\n"
        "MIME-Version: 1.0\nContent-Type: text/plain; charset=UTF-8\nContent-Transfer-Encoding: %s\n\n%s" % (cte, payload))
cfg = open(fx + "/cfg.diff").read()
mbox(fx + "/cfg-b64.mbox", "x\n---\n" + cfg, "base64")
mbox(fx + "/cfg-qp.mbox", "x\n---\n" + cfg, "qp")
md = open(fx + "/md.diff").read()
mbox(fx + "/md-b64.mbox", "x\n---\n" + md, "base64")
PYE
  (cd "$PROJ" && tar -cf "$FX/s.tar" -C "$FX" forged.state && mkdir -p "$FX/tarroot" && cp "$PROJ/silver-bullet.md" "$FX/tarroot/" && printf 'changed\n' >"$FX/tarroot/silver-bullet.md" && tar -cf "$FX/root.tar" -C "$FX/tarroot" silver-bullet.md)
  # the state-file tar: member named like the state file
  mkdir -p "$FX/st" && cp "$FX/forged.state" "$FX/st/$(basename "$STATE")" && tar -cf "$FX/s.tar" -C "$FX/st" "$(basename "$STATE")"
}

ih_edit() { run_dc "$(edit_json "$PROJ/src/app.js" Edit PreToolUse "$BIG_OLD" "$BIG_NEW")"; }

# ih_run CMD: the hooks around a REAL command: Pre (decision kept), the command itself, Post.
ih_run() {
  run_dc "$(bash_json "$1" PreToolUse)"
  IH_PRE="$(decision)"
  (cd "$PROJ" && env SD="$SD" STATE="$STATE" PROJ="$PROJ" FX="$FX" RT="$RT" bash -c "$1" >/dev/null 2>&1) || true
  run_dc "$(bash_json "$1" PostToolUse)"
}

ih_rec() { # SKILL: the real recorder, as the host runs it
  printf '%s' "$(jq -cn --arg s "$1" '{hook_event_name:"PostToolUse",tool_name:"Skill",tool_input:{skill:$s}}')" \
    | (cd "$PROJ" && SILVER_BULLET_PROJECT_ROOT="$PROJ" bash "$TL_REPO_ROOT/hooks/record-skill.sh") >/dev/null 2>&1 || true
}

ih_session_start() { # SOURCE
  mkdir -p "$SB_RUNTIME_HOME_ROOT/plugins/cache/alo-labs/silver-bullet/test"
  printf '{"hook_event_name":"SessionStart","source":"%s"}' "${1:-startup}" \
    | (cd "$PROJ" && SILVER_BULLET_PROJECT_ROOT="$PROJ" bash "$TL_REPO_ROOT/hooks/session-start") >/dev/null 2>&1 || true
}

ih_session_start_out() { # SOURCE → the hook's output
  mkdir -p "$SB_RUNTIME_HOME_ROOT/plugins/cache/alo-labs/silver-bullet/test"
  printf '{"hook_event_name":"SessionStart","source":"%s"}' "${1:-startup}" \
    | (cd "$PROJ" && SILVER_BULLET_PROJECT_ROOT="$PROJ" bash "$TL_REPO_ROOT/hooks/session-start") 2>/dev/null || true
}
ih_status() { sb_integrity_forget; sb_integrity_verify "$PROJ" ""; printf '%s' "$SB_IV_STATUS"; }

ih_hook() { # HOOK JSON → output in TL_OUT
  tl_run_stdin "$2" bash -c 'cd "$1" && exec bash "$2"' _ "$PROJ" "$TL_REPO_ROOT/hooks/$1"
}

# ih_lapse: the unlock window of the running skill is over (the entries it refreshed stay accepted).
ih_lapse() { SB_CONTRACT_UNLOCK_WINDOW=-1; sb_integrity_forget; }
ih_diverged() { sb_integrity_forget; sb_integrity_verify "$PROJ" ""; printf '%s' "$SB_IV_DIVERGED"; }
not_deny() { if [[ "$(decision)" == deny ]]; then echo deny; else echo ok; fi; }
