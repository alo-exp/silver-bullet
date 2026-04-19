#!/usr/bin/env bash
# TF-IDF chunk ranker. Bash 3.2+ compatible (no mapfile, no declare -A).
# Usage: printf 'file1\nfile2\n' | tfidf-rank.sh "query terms"
# Output: score TAB file TAB start_line TAB end_line TAB chunk_text
#         sorted descending by score; tabs in chunk_text replaced with spaces.
#
# Multiline chunk text is newline-escaped (\n) when written to TMP_CHUNKS so
# that each chunk occupies exactly one line. awk unescapes before scoring.
set -euo pipefail
trap 'exit 0' ERR

QUERY="${1:-}"
CHUNK_LINES=40                                 # force-split interval when no blank line found
MAX_CHUNK_BYTES="${SB_CHUNK_BYTES:-1024}"      # passed by semantic-compress.sh; default matches spec

# Read file paths from stdin (bash 3.2 compatible — no mapfile)
FILES=()
while IFS= read -r f; do
  [[ -n "$f" ]] && FILES+=("$f")
done

[[ ${#FILES[@]} -eq 0 ]] && exit 0

# Collect all chunks into a temp file: one chunk per line.
# Format per line: file TAB start TAB end TAB escaped_chunk_text
# Newlines in chunk text are stored as literal \n (two chars) to keep one line per chunk.
TMP_CHUNKS=$(mktemp)
trap 'rm -f "$TMP_CHUNKS"' EXIT

for f in "${FILES[@]}"; do
  [[ -f "$f" ]] || continue
  chunk_start=1
  chunk_text=""
  chunk_line_count=0
  lineno=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    (( lineno++ )) || true
    # Sanitise: replace tabs with spaces
    safe_line="${line//$'\t'/ }"
    # Append with \n escape (two chars) instead of real newline
    chunk_text="${chunk_text}${safe_line}\\n"
    (( chunk_line_count++ )) || true
    chunk_size=${#chunk_text}
    is_blank=0; [[ -z "${line// }" ]] && is_blank=1
    force=0;    [[ $chunk_line_count -ge $CHUNK_LINES ]] && force=1
    oversize=0; [[ $chunk_size -ge $MAX_CHUNK_BYTES ]] && oversize=1
    if [[ $is_blank -eq 1 || $force -eq 1 || $oversize -eq 1 ]] && [[ $chunk_line_count -gt 0 ]]; then
      printf '%s\t%s\t%s\t%s\n' "$f" "$chunk_start" "$lineno" "$chunk_text" >> "$TMP_CHUNKS"
      chunk_start=$(( lineno + 1 ))
      chunk_text=""
      chunk_line_count=0
    fi
  done < "$f"
  if [[ $chunk_line_count -gt 0 ]]; then
    printf '%s\t%s\t%s\t%s\n' "$f" "$chunk_start" "$lineno" "$chunk_text" >> "$TMP_CHUNKS"
  fi
done

total=$(wc -l < "$TMP_CHUNKS" | tr -d ' ')
[[ "$total" -eq 0 ]] && exit 0

# If empty query, output chunks with score 0 preserving order (unescape \n → space for readability)
if [[ -z "$QUERY" ]]; then
  while IFS=$'\t' read -r cf cs ce ct; do
    printf '0\t%s\t%s\t%s\t%s\n' "$cf" "$cs" "$ce" "$ct"
  done < "$TMP_CHUNKS"
  exit 0
fi

# TF-IDF scoring via awk.
# Each line of TMP_CHUNKS: file TAB start TAB end TAB escaped_chunk_text
# awk unescapes \n to spaces for term-frequency counting.
awk -F'\t' -v query="$QUERY" -v total="$total" '
BEGIN {
  n = split(query, qterms, " ")
}
{
  file  = $1
  start = $2
  end   = $3
  # Field 4: original escaped text (original case, \n two-char sequences preserved)
  raw     = $4
  escaped = raw
  gsub(/\\n/, " ", escaped)    # space-join for term-frequency counting
  text = tolower(escaped)      # lowercase for scoring only
  chunks_file[NR]  = file
  chunks_start[NR] = start
  chunks_end[NR]   = end
  chunks_text[NR]  = text      # lowercased, space-joined (scoring only)
  chunks_raw[NR]   = raw       # original case, \n-escaped (output)
  for (i = 1; i <= n; i++) {
    term = tolower(qterms[i])
    if (length(term) < 2) continue
    if (index(text, term) > 0) df[term]++
  }
}
END {
  for (i = 1; i <= NR; i++) {
    text  = chunks_text[i]
    score = 0
    nw    = split(text, words, /[^a-zA-Z0-9]+/)
    for (j = 1; j <= n; j++) {
      term = tolower(qterms[j])
      if (length(term) < 2) continue
      tf_count = 0
      for (w = 1; w <= nw; w++) {
        if (words[w] == term) tf_count++
      }
      tf  = (nw > 0) ? tf_count / nw : 0
      idf = (df[term] > 0) ? log(total / df[term]) : 0
      score += tf * idf
    }
    printf "%.6f\t%s\t%s\t%s\t%s\n", score, chunks_file[i], chunks_start[i], chunks_end[i], chunks_raw[i]
  }
}
' "$TMP_CHUNKS" | sort -t$'\t' -k1 -rn
