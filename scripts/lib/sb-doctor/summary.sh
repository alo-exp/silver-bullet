#!/usr/bin/env bash
# sb-doctor module — auto-split from sb-doctor.sh
doctor_print_summary() {
  if [[ "$FORMAT" == "json" ]]; then
    jq -n \
      --argjson pass "$PASS" --argjson fail "$FAIL" --argjson warn "$WARN" \
      --arg lines "$(printf '%s\n' "${REPORT_LINES[@]}")" \
      '{pass:$pass,fail:$fail,warn:$warn,lines:($lines|split("\n"))}'
  else
    echo
    echo "Silver Bullet doctor: ${PASS} PASS, ${WARN} WARN, ${FAIL} FAIL"
    if [[ "$FAIL" -eq 0 ]]; then
      echo "OVERALL: PASS"
    else
      echo "OVERALL: FAIL"
    fi
  fi
}
