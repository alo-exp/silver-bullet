# Assembly prompt

Final assembly QA before DR-PACKAGE:

1. `validate_report.py --report research_report.md --lang <profile>`
2. `verify_citations.py --report research_report.md` and
   `verify_claim_support.py verify --dir <run dir> --report research_report.md --strict`
   A `needs_review` item is not a pass: fix the claim to repeat its single supporting quote, or store the
   one supporting sentence as evidence, or check it against the source and say so in the report
3. Check TOC uniqueness and bibliography tail
4. Max 3 repair loops
