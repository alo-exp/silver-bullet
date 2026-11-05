#!/usr/bin/env bash
# hooks/lib/skill-discovery.sh: name variants, installed-skill lookup and canonical names.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/testlib.sh"
tl_init
LIB="$TL_REPO_ROOT/hooks/lib/skill-discovery.sh"
unset SILVER_BULLET_SKILL_ROOTS SB_PLUGIN_ROOT
unset -f rg 2>/dev/null || true
# shellcheck source=../../hooks/lib/skill-discovery.sh
source "$LIB"

variants() { sb_skill_name_variants "$1" | tr '\n' ' ' | sed 's/ $//'; }
assert_eq "sb:x variants" "sb:x sb-x silver-x" "$(variants sb:x)"
assert_eq "other namespace variants" "host:name host-name" "$(variants host:name)"
assert_eq "sb-x variants" "sb-x sb:x silver-x" "$(variants sb-x)"
assert_eq "silver-x variants" "silver-x sb:x sb-x" "$(variants silver-x)"
assert_eq "plain hyphenated variants" "a-b-c a:b-c" "$(variants a-b-c)"
assert_eq "single word has itself only" "word" "$(variants word)"
if sb_skill_name_variants "" >/dev/null; then tl_fail "empty name has no variants"; else tl_pass "empty name has no variants"; fi

# ---- installed lookup -------------------------------------------------------
R="$TL_TMP/roots"
mkdir -p "$R/direct/skills/alpha-skill" "$R/flat/beta-skill" "$R/named/skills/dir-x"
: >"$R/direct/skills/alpha-skill/SKILL.md"
: >"$R/flat/beta-skill/SKILL.md"
printf -- '---\nname: gamma-skill\n---\n' >"$R/named/skills/dir-x/SKILL.md"
installed() { SILVER_BULLET_SKILL_ROOTS="$1" sb_skill_is_installed "$2"; }
ok() { if "$@"; then tl_pass "$*"; else tl_fail "$*"; fi; }
nok() { if "$@"; then tl_fail "NOT: $*"; else tl_pass "NOT: $*"; fi; }

nok sb_skill_is_installed ""
nok sb_skill_is_installed "silver"
nok sb_skill_is_installed "silver:anything"
ok installed "$R/direct" alpha-skill
ok installed "::$R/direct" alpha-skill
ok installed "$R/flat" beta-skill
ok installed "$R/named" gamma-skill
mkdir -p "$R/direct/skills/silver-alpha2"
: >"$R/direct/skills/silver-alpha2/SKILL.md"
ok installed "$R/direct" sb:alpha2
nok installed "$R/direct" missing-skill
nok installed "$R/flat:$R/named" missing-skill

# frontmatter lookup through rg when present and grep otherwise
tl_stub rg 'exit 0'; hash -r
ok installed "$R/named" frontmatter-only-via-rg
rm -f "${TL_BIN:?}/rg"; hash -r
NORG="$(tl_path_without rg)"
ok env PATH="$NORG" SILVER_BULLET_SKILL_ROOTS="$R/named" bash -c 'source "$1"; sb_skill_is_installed gamma-skill' _ "$LIB"
nok env PATH="$NORG" SILVER_BULLET_SKILL_ROOTS="$R/named" bash -c 'source "$1"; sb_skill_is_installed delta-skill' _ "$LIB"
nok installed "$R/empty-root" gamma-skill

# plugin cache layouts at several depths
C="$TL_TMP/x/plugins/cache"
mkdir -p "$C/a/skills/d1" "$C/b/c/skills/d2" "$C/e/f/g/skills/d3" "$C/h/upstream/skills/d4" "$C/i/j/upstream/skills/d5" "$C/k/l/m/upstream/skills/d6"
for d in d1 d2 d3 d4 d5 d6; do
  f="$(find "$C" -type d -name "$d")"
  : >"$f/SKILL.md"
  ok installed "$C" "$d"
done
nok installed "$C" d7

# virtual lifecycle markers count as installed without any root
ok bash -c 'source "$1"; sb_skill_is_installed silver-plan' _ "$LIB"
nok bash -c 'source "$1"; sb_skill_is_installed totally-unknown-skill' _ "$LIB"
ok bash -c 'source "$1"; source "$2"; sb_skill_is_installed silver-plan' _ "$LIB" "$TL_REPO_ROOT/hooks/lib/required-skills.sh"

# default roots: the repository's own skills, a bogus plugin root, and the runtime roots
ok env SB_PLUGIN_ROOT="$TL_TMP/not-a-dir" bash -c 'source "$1"; sb_skill_is_installed sb:quality-gates' _ "$LIB"
mkdir -p "$HOME/.agents/skills/home-skill"
: >"$HOME/.agents/skills/home-skill/SKILL.md"
ok bash -c 'source "$1"; sb_skill_is_installed home-skill' _ "$LIB"
mkdir -p "$SB_RUNTIME_PLUGIN_CACHE_ROOT/pk/skills/cache-skill"
: >"$SB_RUNTIME_PLUGIN_CACHE_ROOT/pk/skills/cache-skill/SKILL.md"
ok bash -c 'source "$1"; sb_skill_is_installed cache-skill' _ "$LIB"

# ---- canonical names --------------------------------------------------------
canon() { sb_skill_canonical_name "$1"; }
if sb_skill_canonical_name "" >/dev/null; then tl_fail "empty has no canonical name"; else tl_pass "empty has no canonical name"; fi
assert_eq "sb:security" "security" "$(canon sb:security)"
assert_eq "sb:tdd" "tdd" "$(canon sb:tdd)"
assert_eq "sb:verify-tests" "verify-tests" "$(canon sb:verify-tests)"
assert_eq "sb:devops-quality-gates" "devops-quality-gates" "$(canon sb:devops-quality-gates)"
assert_eq "sb:devops-skill-router" "devops-skill-router" "$(canon sb:devops-skill-router)"
assert_eq "sb:request-review" "silver-review-request" "$(canon sb:request-review)"
assert_eq "sb:receive-review" "silver-review-triage" "$(canon sb:receive-review)"
assert_eq "sb:plan" "silver-plan" "$(canon sb:plan)"
assert_eq "bare sb" "silver" "$(canon sb)"
assert_eq "sb-plan" "silver-plan" "$(canon sb-plan)"
assert_eq "retired silver: namespace preserved" "silver:plan" "$(canon silver:plan)"
assert_eq "foreign namespaces unwrapped" "name" "$(canon host:ns:name)"
assert_eq "plain name unchanged" "plain-name" "$(canon plain-name)"

tl_results
