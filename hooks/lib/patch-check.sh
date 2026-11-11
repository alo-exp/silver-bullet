# shellcheck shell=bash
# Silver Bullet — patch writes (patch, git apply, git am).
#
# A patch applies whatever paths its diff names, so the hooks cannot know what it writes unless
# they read the diff. A patch write is allowed only when ALL of these hold:
#   (a) the patch comes from ONE readable regular file given as a plain operand or -i/--input:
#       not standard input, a pipe, a redirect, a heredoc or a process substitution;
#   (b) no option moves where the patch applies or relaxes its path checks (--directory, -d, -C,
#       --unsafe-paths, --include/--exclude, --git-dir, --work-tree, -o ...): an option that is
#       not on the allowlist is refused;
#   (c) every path the diff names (---/+++, `diff --git`, rename/copy headers) is relative, free of
#       `..`, outside every protected target (the state directory, the host runtime directory,
#       .git, .planning, .silver-bullet, the contract, instruction and planning files), and
#       inside the project tree.
# Anything else is refused with `cannot inspect patch: <why>`. The paths of an allowed patch are
# recorded as writes ("patch<TAB>path") so the planning floor judges them like any other write.
#
#   sb_pf_patch_verdict       prints why the loaded command's patch write cannot be inspected ("" if it can)
#   sb_pf_patch_message WHY   the deny text
#   sb_pf_path_protected PATH a canonical path Silver Bullet protects from patch-like writers

SB_PF_PATCH_NAMES='silver-bullet.md .silver-bullet.json .silver-bullet.prompt.json CLAUDE.md AGENTS.md ROADMAP.md STATE.md PROJECT.md RELEASE.md REQUIREMENTS.md UAT.md'

# One TSV line per patch command: status (OK|DENY), file-or-why, strip, cwd, original file, kind.
# shellcheck disable=SC2016  # a jq program
_SB_PF_PATCH_JQ='
def base: split("/") | last;
def digits: test("^[0-9]+$");
def opt_reason($t): "the option " + $t + " does not keep the patch inside the project";
def init: {ops: [], why: null, wait: null, strip: null, input: null, ro: false, end: false, ctl: false};
def common($t; $flags; $ro; $ctl):
  if ($t | IN($flags[])) then .
  elif ($t | IN($ro[])) then .ro = true
  elif ($t | IN($ctl[])) then .ctl = true
  else .why = opt_reason($t) end;
def parse($kind; $args):
  ["-R","--reverse","-N","--forward","-s","--silent","--quiet","-f","--force","-t","--batch","-E","--remove-empty-files","-l","--ignore-whitespace","-u","--unified","--no-backup-if-mismatch","--verbose"] as $pflags
  | ["--index","--cached","--3way","-3","--apply","--reverse","-R","-v","--verbose","-q","--quiet","--reject","--recount","--unidiff-zero","--inaccurate-eof","--allow-overlap","--ignore-space-change","--ignore-whitespace","--no-add","--intent-to-add","--binary"] as $aflags
  | ["-3","--3way","-s","--signoff","-k","--keep","-u","--utf8","-q","--quiet","--keep-cr","--no-keep-cr","--scissors","--no-scissors","--ignore-space-change","--ignore-whitespace","--committer-date-is-author-date","--ignore-date","--reject"] as $mflags
  | reduce $args[] as $t (init;
      if .why != null then .
      elif .wait != null then
        (if .wait == "p" then (if ($t | digits) then .strip = $t else .why = "the strip count " + $t + " is not a number" end)
         else .input = $t end) | .wait = null
      elif .end then .ops += [$t]
      elif $t == "--" then .end = true
      elif $t == "-" then .why = "the patch is read from standard input"
      elif ($t | startswith("-") | not) then .ops += [$t]
      elif ($t | test("^-p[0-9]+$")) then .strip = $t[2:]
      elif ($t | test("^-p.+")) then .why = "the strip count is not a number"
      elif $kind == "patch" and $t == "-p" then .wait = "p"
      elif $kind == "patch" and ($t | test("^--strip=[0-9]+$")) then .strip = $t[8:]
      elif $kind == "patch" and $t == "--strip" then .wait = "p"
      elif $kind == "patch" and ($t == "-i" or $t == "--input") then .wait = "i"
      elif $kind == "patch" and ($t | startswith("--input=")) then .input = $t[8:]
      elif $kind == "patch" and $t == "--dry-run" then .ro = true
      elif $kind == "patch" and ($t | IN($pflags[])) then .
      elif $kind == "apply" and ($t | IN("--check","--stat","--numstat","--summary")) then .ro = true
      elif $kind == "apply" and ($t | IN($aflags[])) then .
      elif $kind == "apply" and ($t | test("^--whitespace=[a-z-]+$")) then .
      elif $kind == "apply" and ($t | test("^-C[0-9]+$")) then .
      elif $kind == "am" and ($t | IN("--continue","-r","--resolved","--skip","--abort","--quit")) then .ctl = true
      elif $kind == "am" and ($t | IN($mflags[])) then .
      elif $kind == "am" and ($t | test("^--whitespace=[a-z-]+$")) then .
      elif $kind == "am" and ($t | test("^-C[0-9]+$")) then .
      else .why = opt_reason($t) end)
  | if .why == null and .wait != null then .why = "an option is missing its value" else . end;
def finish($kind; $cwd):
  . as $s
  | if $s.ro or $s.ctl then empty
    elif $s.why != null then ["DENY", $s.why, "-", $cwd, "-", $kind]
    elif $kind == "patch" then
      (if $s.input != null then
         (if ($s.ops | length) > 1 then ["DENY", "patch has more operands than a file and a patch", "-", $cwd, "-", $kind]
          else ["OK", $s.input, ($s.strip // "0"), $cwd, ($s.ops[0] // "-"), $kind] end)
       elif ($s.ops | length) == 2 then ["OK", $s.ops[1], ($s.strip // "0"), $cwd, $s.ops[0], $kind]
       elif ($s.ops | length) > 2 then ["DENY", "patch has more operands than a file and a patch", "-", $cwd, "-", $kind]
       else ["DENY", "the patch is read from standard input", "-", $cwd, "-", $kind] end)
    elif ($s.ops | length) == 0 then ["DENY", "the patch is read from standard input", "-", $cwd, "-", $kind]
    elif ($s.ops | length) > 1 then ["DENY", "more than one patch file is given", "-", $cwd, "-", $kind]
    else ["OK", $s.ops[0], ($s.strip // "1"), $cwd, "-", $kind] end;
.commands[]? | (.argv // []) as $a | (.cwd // "") as $cwd | (($a[0] // "") | base) as $p
| if $p == "patch" then parse("patch"; $a[1:]) | finish("patch"; $cwd)
  elif $p == "git" then
    (reduce $a[1:][] as $t ({sub: null, skip: false, opts: [], rest: []};
       if .sub != null then .rest += [$t]
       elif .skip then .skip = false | .opts += [$t]
       elif ($t | IN("-C","-c","--git-dir","--work-tree","--namespace","--exec-path","--super-prefix","--config-env")) then .skip = true | .opts += [$t]
       elif ($t | startswith("-")) then .opts += [$t]
       else .sub = $t end)) as $g
    | if $g.sub == "apply" or $g.sub == "am" then
        (($g.opts | map(select(. != "--no-pager"))) as $bad
         | if ($bad | length) > 0 then ["DENY", "the git option " + $bad[0] + " changes where the patch applies", "-", $cwd, "-", $g.sub]
           else (parse($g.sub; $g.rest) | finish($g.sub; $cwd)) end)
      else empty end
  else empty end
| map(if . == "" then "-" else . end) | @tsv'

# The path-like names of a diff, one per line; \001QUOTED / \001AMBIG when a header cannot be read.
_sb_pf_diff_paths() { # FILE
  awk '
    function emit(s) {
      sub(/\t.*$/, "", s); sub(/[ \r]+$/, "", s)
      if (s ~ /^"/) { print "\001QUOTED"; return }
      if (s != "") print s
    }
    /^--- / { emit(substr($0, 5)); next }
    /^\+\+\+ / { emit(substr($0, 5)); next }
    /^\*\*\* [^0-9]/ { emit(substr($0, 5)); next }
    /^Index: / { emit(substr($0, 8)); next }
    /^diff --git / {
      rest = substr($0, 12)
      if (rest ~ /"/) { print "\001QUOTED"; next }
      if (split(rest, t, " ") == 2) { emit(t[1]); emit(t[2]) } else print "\001AMBIG"
      next
    }
    /^(rename|copy) (from|to) / { s = $0; sub(/^(rename|copy) (from|to) /, "", s); emit(s); next }
  ' "$1"
}

# A canonical path that patch-like writers must not reach.
sb_pf_path_protected() {
  local p="$1" name home_root state_dir
  home_root="$(sb_pf_canon "${SB_RUNTIME_HOME_ROOT:-/nonexistent-sb-home}")"
  state_dir="$(sb_pf_canon "${SB_RUNTIME_STATE_DIR:-/nonexistent-sb-state}")"
  case "$p" in
    "$home_root" | "$home_root"/* | "$state_dir" | "$state_dir"/*) return 0 ;;
    */.git | */.git/* | */.planning | */.planning/* | */.silver-bullet | */.silver-bullet/*) return 0 ;;
  esac
  for name in $SB_PF_PATCH_NAMES; do
    [[ "${p##*/}" != "$name" ]] || return 0
  done
  return 1
}

# Prints "DENY<TAB>why" or "PATH<TAB>absolute path" lines for the loaded command's patch writes.
_sb_pf_patch_scan() {
  local status file strip cwd orig kind p abs root n comps comp rest bad dir
  while IFS=$'\t' read -r status file strip cwd orig kind; do
    if [[ "$status" == DENY ]]; then printf 'DENY\t%s\n' "$file"; continue; fi
    [[ "$cwd" != "-" ]] || cwd="$PWD"
    [[ "$file" == /* ]] || file="$cwd/$file"
    if [[ ! -f "$file" || ! -r "$file" ]]; then
      printf 'DENY\tthe patch file %s is missing, unreadable or not a regular file\n' "${file##*/}"
      continue
    fi
    if [[ "$(wc -c <"$file" | tr -d ' ')" -gt 2097152 ]]; then
      printf 'DENY\tthe patch file %s is larger than 2 MiB\n' "${file##*/}"
      continue
    fi
    root=""
    if declare -f sb_find_project_config_walk_only_from >/dev/null 2>&1; then
      dir="$(sb_find_project_config_walk_only_from "$cwd" 2>/dev/null || true)"
      [[ -z "$dir" ]] || root="$(sb_pf_canon "$(dirname "$dir")")"
    fi
    bad=""
    while IFS= read -r p; do
      case "$p" in
        $'\001QUOTED') bad="a path in the diff is quoted, so it cannot be read reliably"; break ;;
        $'\001AMBIG') bad="a diff header names paths that cannot be told apart (spaces)"; break ;;
        /dev/null) continue ;;
        /* | '~'*) bad="the diff names the absolute path $p"; break ;;
      esac
      comps="$p"
      while [[ -n "$comps" ]]; do
        comp="${comps%%/*}"
        rest="${comps#"$comp"}"
        comps="${rest#/}"
        if [[ "$comp" == ".." ]]; then bad="the diff names $p, which leaves the project"; break 2; fi
      done
      # Judged as written and as stripped: -p cannot hide a protected name.
      if sb_pf_path_protected "$(sb_pf_canon "$p" "$cwd")"; then
        bad="the diff names $p, a file Silver Bullet protects"; break
      fi
      n="${strip:-0}"
      abs="$p"
      while [[ "$n" -gt 0 && "$abs" == */* ]]; do abs="${abs#*/}"; n=$((n - 1)); done
      [[ "$n" -eq 0 ]] || continue
      if sb_pf_path_protected "$(sb_pf_canon "$abs" "$cwd")"; then
        bad="the diff names $p, a file Silver Bullet protects"; break
      fi
      abs="$(sb_pf_canon "$abs" "$cwd")"
      if [[ -n "$root" ]]; then
        case "$abs" in "$root" | "$root"/*) ;; *) bad="the diff names $p, outside the project"; break ;; esac
      fi
      printf 'PATH\t%s\n' "$abs"
    done < <({ [[ "$orig" == "-" ]] || printf '%s\n' "$orig"; _sb_pf_diff_paths "$file"; })
    if [[ -n "$bad" ]]; then printf 'DENY\t%s\n' "$bad"; fi
  done < <(printf '%s' "${SB_SA_JSON:-}" | jq -r "$_SB_PF_PATCH_JQ" 2>/dev/null)
}

sb_pf_patch_verdict() {
  local kind val
  while IFS=$'\t' read -r kind val; do
    if [[ "$kind" == DENY ]]; then printf '%s' "$val"; return 0; fi
  done < <(_sb_pf_patch_scan)
  return 0
}

sb_pf_patch_message() {
  printf '🛑 Silver Bullet cannot inspect patch: %s.\n\nA patch writes every path its diff names, so it is allowed only from one readable patch file (patch -p1 -i FILE, git apply FILE, git am FILE) whose paths stay inside the project and outside protected files, without options that move where it applies (--directory, -d, -C, --unsafe-paths ...). Save the patch to a file first, or ask the user to apply it from their own terminal.' "$1"
}
