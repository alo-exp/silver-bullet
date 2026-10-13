#!/usr/bin/env bash
set -euo pipefail

out_dir="${GRAPHIFY_OUT_DIR:-graphify-out}"

required_files=(
  "graph.json"
  "GRAPH_REPORT.md"
  "manifest.json"
)

for file in "${required_files[@]}"; do
  path="$out_dir/$file"
  if [[ ! -s "$path" ]]; then
    echo "Missing or empty Graphify artifact: $path" >&2
    exit 1
  fi
done

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to validate Graphify JSON artifacts" >&2
  exit 1
fi

# Accept NetworkX graph-attr nesting (.graph.hyperedges) or top-level
# hyperedges (current graphify AST update / some merge-driver outputs).
jq -e '
  type == "object" and
  (.directed | type == "boolean") and
  (.graph | type == "object") and
  ((.graph.hyperedges // .hyperedges) | type == "array") and
  (.nodes | type == "array") and
  (.links | type == "array")
' "$out_dir/graph.json" >/dev/null

jq -e 'type == "object"' "$out_dir/manifest.json" >/dev/null

echo "Graphify artifacts are present and valid in $out_dir"

