# shellcheck shell=bash
# Production skill↔atom join resolution — migration_map + catalog fallbacks (Phase B).

_sb_skill_atom_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${_sb_skill_atom_lib_dir}/orchestrator-directive.sh" ]]; then
  # shellcheck source=lib/orchestrator-directive.sh
  source "${_sb_skill_atom_lib_dir}/orchestrator-directive.sh"
fi

# Validate atom id exists in catalog; prints atom id or empty.
sb_scheduler_catalog_atom_exists() {
  local catalog_file="$1" atom_id="$2"
  [[ -n "$catalog_file" && -f "$catalog_file" && -n "$atom_id" ]] || return 1
  jq -e --arg id "$atom_id" '.atomic_flows[] | select(.id == $id)' "$catalog_file" >/dev/null 2>&1
}

# Full resolution chain: queue token, skill, FLOW-*, slug, gsd alias → AF-*.
sb_scheduler_resolve_atom_id() {
  local catalog_file="$1" token="$2"
  [[ -n "$catalog_file" && -f "$catalog_file" && -n "$token" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1

  if [[ "$token" == AF-* ]]; then
    sb_scheduler_catalog_atom_exists "$catalog_file" "$token" || return 1
    printf '%s' "$token"
    return 0
  fi

  local resolved normalized skill
  resolved="$(jq -r --arg t "$token" '
    .migration_map.runtime_queue_tokens[$t]
    // .migration_map.skill_to_entity[$t]
    // .migration_map.gsd_alias_to_entity[$t]
    // empty
  ' "$catalog_file" 2>/dev/null || true)"
  if [[ -n "$resolved" && "$resolved" != "null" ]]; then
    if sb_scheduler_catalog_atom_exists "$catalog_file" "$resolved"; then
      printf '%s' "$resolved"
      return 0
    fi
  fi

  # FLOW-* and legacy FLOW N tokens via runtime_queue_tokens or legacy_flows values.
  resolved="$(jq -r --arg t "$token" '
    (.migration_map.legacy_flows // {}) | to_entries[] | select(.value == $t or .key == $t) | .value
    | select(startswith("AF-"))
  ' "$catalog_file" 2>/dev/null | head -1 || true)"
  if [[ -n "$resolved" ]]; then
    printf '%s' "$resolved"
    return 0
  fi

  # Slug match on atomic_flows (FIXTURE-READ-A, orient, etc.).
  resolved="$(jq -r --arg t "$token" '
    .atomic_flows[]
    | select(
        .id == $t
        or .slug == $t
        or ((.slug // "") | ascii_downcase) == ($t | ascii_downcase)
      )
    | .id
  ' "$catalog_file" 2>/dev/null | head -1 || true)"
  if [[ -n "$resolved" ]]; then
    printf '%s' "$resolved"
    return 0
  fi

  # Normalize via flow_to_skill then re-resolve (FLOW-PLAN → silver-plan → AF-PLAN).
  if declare -f sb_orchestrator_flow_to_skill >/dev/null 2>&1; then
    normalized="$(sb_orchestrator_flow_to_skill "$token" 2>/dev/null || true)"
    if [[ -n "$normalized" && "$normalized" != "$token" ]]; then
      resolved="$(sb_scheduler_resolve_atom_id "$catalog_file" "$normalized" 2>/dev/null || true)"
      if [[ -n "$resolved" ]]; then
        printf '%s' "$resolved"
        return 0
      fi
    fi
  fi

  # silver-{slug} → atomic_flows slug tail.
  if [[ "$token" == silver-* ]]; then
    local slug_tail="${token#silver-}"
    resolved="$(jq -r --arg slug "$slug_tail" '
      .atomic_flows[]
      | select(((.slug // "") | ascii_downcase | gsub("-"; "")) == ($slug | gsub("-"; "")))
      | .id
    ' "$catalog_file" 2>/dev/null | head -1 || true)"
    if [[ -n "$resolved" ]]; then
      printf '%s' "$resolved"
      return 0
    fi
  fi

  # Reverse skill_to_entity lookup when token matches entity id usage.
  resolved="$(jq -r --arg t "$token" '
    .migration_map.skill_to_entity | to_entries[] | select(.value == $t) | .value
  ' "$catalog_file" 2>/dev/null | head -1 || true)"
  if [[ -n "$resolved" && "$resolved" == AF-* ]]; then
    printf '%s' "$resolved"
    return 0
  fi

  return 1
}

# True when handoff row matches completed atom or skill (join gate).
sb_scheduler_handoff_matches_completion() {
  local handoff_json="$1" atom_id="$2" skill="$3"
  [[ -n "$handoff_json" ]] || return 1
  command -v jq >/dev/null 2>&1 || return 1
  jq -e --arg atom "$atom_id" --arg skill "$skill" '
    (.atomic_flow_id == $atom and $atom != "")
    or (.next_skill == $skill and $skill != "")
    or ((.next_skill // "") | test("^silver:"))
    and ($skill != "" and (.next_skill | gsub("^silver:"; "silver-")) == ($skill | gsub("^silver:"; "silver-")))
  ' <<<"$handoff_json" >/dev/null 2>&1
}
