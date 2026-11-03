# Chapter agent prompt

Generate one report section at a time per `report_profiles` language.

- Load block from `reference/report-blocks/`
- Cite with stable `[N]` from bibliography plan
- Write each factual sentence from the ONE stored evidence quote that backs it: repeat that sentence's
  words and figures in the same order (only the first word's capital and punctuation may
  change; keep case, plurals, figures, `?` and `*` exactly as the quote has them). Do not reword, reorder, change voice or merge two quotes in one sentence; a
  paraphrase is `needs_review`, not `supported`. If a sentence needs two facts, write two sentences
  with one quote each
- Append to `research_report.md` — do not truncate
