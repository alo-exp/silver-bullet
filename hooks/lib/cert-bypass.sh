# shellcheck shell=bash
# Agent-host cert runs — skip substantive tool gates so delegate workers can land README edits.
# Set SB_AGENT_CERT_RUN=1 in run-cert-cell.sh / agent-*-delegate.sh before Claude --print.

sb_cert_run_bypass_active() {
  [[ "${SB_AGENT_CERT_RUN:-}" == "1" || "${SB_AGENT_CERT_RUN:-}" == "true" ]]
}

sb_cert_run_bypass() {
  if sb_cert_run_bypass_active; then
    exit 0
  fi
}
