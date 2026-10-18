# shellcheck shell=bash
# Helpers for the marketplace-sync tests (package J-install-sync-2).
#
# Builds a local "agent-plugins" marketplace repository (bare remote plus
# working clones) and small script trees, so the marketplace sync scripts run
# against local git only: no network, no push to a real remote.
#
#   source "$TL_REPO_ROOT/tests/lib/j-install-sync-helpers.sh"
#   j_git_identity                       # fixed author/committer, no signing
#   j_make_remote "$TL_TMP/mk"           # $J_REMOTE (bare) + $J_SEED (working clone)
#   j_clone_remote "$TL_TMP/work"        # fresh clone tracking origin/main

j_git_identity() {
  export GIT_AUTHOR_NAME="SB Test" GIT_AUTHOR_EMAIL="sb-test@example.invalid"
  export GIT_COMMITTER_NAME="SB Test" GIT_COMMITTER_EMAIL="sb-test@example.invalid"
  export GIT_CONFIG_COUNT=2 GIT_CONFIG_KEY_0=commit.gpgsign GIT_CONFIG_VALUE_0=false \
    GIT_CONFIG_KEY_1=core.hooksPath GIT_CONFIG_VALUE_1=/dev/null
  export GIT_ALLOW_PROTOCOL=file
}

# j_marketplace_json <source-json>: marketplace with a foreign plugin and a stale silver-bullet.
j_marketplace_json() {
  jq -n --argjson src "$1" '{
    name: "test-market",
    metadata: {version: "1.0.0", note: null},
    plugins: [
      {name: "other", version: "9.9.9", keywords: ["a", null], source: {source: "github", repo: "o/other"}},
      {name: "silver-bullet", version: "0.0.1", description: "keep me", source: $src}
    ]
  }'
}

# j_make_remote <dir>: sets J_REMOTE (bare repo) and J_SEED (working clone) holding all three manifests.
j_make_remote() {
  local dir="$1"
  mkdir -p "$dir"
  J_REMOTE="$dir/remote.git"
  J_SEED="$dir/seed"
  git init -q --bare -b main "$J_REMOTE"
  git init -q -b main "$J_SEED"
  mkdir -p "$J_SEED/.claude-plugin" "$J_SEED/.agents/plugins" "$J_SEED/.cursor-plugin"
  j_marketplace_json '{"source":"github","repo":"o/sb"}' >"$J_SEED/.claude-plugin/marketplace.json"
  j_marketplace_json '{"source":"github","repo":"o/sb","ref":"v0.0.1"}' >"$J_SEED/.agents/plugins/marketplace.json"
  j_marketplace_json '{"source":"github","repo":"o/sb","ref":"main","sha":"0000","path":"plugins/silver-bullet"}' >"$J_SEED/.cursor-plugin/marketplace.json"
  git -C "$J_SEED" add -A
  git -C "$J_SEED" commit -q -m seed
  git -C "$J_SEED" remote add origin "$J_REMOTE"
  git -C "$J_SEED" push -q -u origin main
}

# j_clone_remote <dir>: clone of J_REMOTE tracking origin/main.
j_clone_remote() {
  git clone -q "$J_REMOTE" "$1"
}

# j_remote_show <path>: content of a file at the remote's main.
j_remote_show() {
  git -C "$J_REMOTE" show "main:$1"
}
