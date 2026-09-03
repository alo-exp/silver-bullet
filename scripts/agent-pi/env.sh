#!/usr/bin/env bash
# Print or export delegation env for /silver:agent-pi (host-agnostic).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/agent-pi/lib.sh
source "${SCRIPT_DIR}/lib.sh"

EXPORT=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --export) EXPORT=1; shift ;;
    -h|--help)
      cat <<'EOF'
Usage: env.sh [--export]

Clears matrix env and applies on-demand Pi delegation defaults (MiMo V2.5 / opencode-go).
With --export, prints export statements suitable for eval.
EOF
      exit 0
      ;;
    *) printf 'ERROR: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

agent_pi_apply_delegate_env

if [[ "$EXPORT" -eq 1 ]]; then
  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    printf 'export %s=%q\n' "$name" "${!name-}"
  done < <(agent_pi_delegate_env_names)
else
  printf 'agent-pi env: model=%s provider=%s lightweight=%s worker=%s\n' \
    "${PI_MODEL}" "${PI_PROVIDER}" \
    "${SB_AGENT_PI_LIGHTWEIGHT}" "${SB_ORCHESTRATOR_WORKER}"
fi
