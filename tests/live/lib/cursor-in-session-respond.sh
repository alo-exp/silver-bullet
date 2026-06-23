#!/usr/bin/env bash
# Write an in-session response for cursor live harness requests.
#
# Usage:
#   bash tests/live/lib/cursor-in-session-respond.sh <session_dir> <request_id> <response_text>
#   printf 'LADDER_PASS: ...' | bash tests/live/lib/cursor-in-session-respond.sh <session_dir> <request_id> -
set -euo pipefail

session_dir="${1:?session_dir required}"
request_id="${2:?request_id required}"
response_text="${3:-}"

if [[ "$response_text" == "-" ]]; then
  response_text="$(cat)"
fi

python3 - "$session_dir" "$request_id" "$response_text" <<'PY'
import json
import sys
from datetime import datetime, timezone
from pathlib import Path

session_dir = Path(sys.argv[1])
request_id = sys.argv[2]
text = sys.argv[3]
response_path = session_dir / f"response-{request_id}.json"
payload = {
    "id": request_id,
    "status": "ok",
    "text": text,
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
response_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
print(f"wrote {response_path}")
PY
