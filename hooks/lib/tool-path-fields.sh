# shellcheck shell=bash
# Silver Bullet — the file-like fields of a tool payload (one key list for every reader).
#
# sb_tool_input_path_fields INPUT: the strings a file or MCP tool's `tool_input` names as a path, one per line. The
# explicit keys (file_path, path, filePath, destination, source, target, from, to, old_path, new_path, src, dst,
# relative_path, ...) and the file_paths / paths arrays are paths whatever they hold: a value with a newline is
# judged as paths line by line (a trailing newline adds nothing). Every other string whose key says path, file,
# dest, src, source, target, uri or name (nested objects such as edits[].path included) except the content-like keys
# (content, text, body, data, old_string, new_string, input, command, code, patch, diff) is read too, but only when
# it is one line: a multi-line value there is text (a notebook cell, a note), not a path.
# Readers: the dev-cycle write guard (planning-floor.sh, sb_pf_write_records) and the write trace
# (agent-writes.sh), so the PreToolUse gate and the Stop backstop cannot drift apart.
sb_tool_input_path_fields() {
  printf '%s' "${1:-}" | jq -r '
    .tool_input | objects
    | ([.file_path, .notebook_path, .path, .filePath, .destination, .source, .target,
        .from, .to, .old_path, .new_path, .oldPath, .newPath, .src, .dst, .sourcePath,
        .destinationPath, .relative_path, .relativePath] | .[] | strings),
      ([.. | objects | to_entries[] | select((.value | type) == "string")
       | select(.key | test("^(content|text|body|data|old_string|new_string|old_str|new_str|input|command|code|patch|diff)$") | not)
       | select(.key | test("(path|file|dest|src|source|target|uri|name)"; "i")) | .value
       | select(contains("\n") | not)] | .[]),
      ((.file_paths // .paths // []) | arrays | .[] | strings)' 2>/dev/null
}
