# Assembly prompt

Final assembly QA before DR-PACKAGE:

1. `validate_report.py --report research_report.md --lang <profile>`
2. `verify_citations.py --report research_report.md` and
   `verify_claim_support.py verify --dir <run dir> --report research_report.md --strict`
3. Check TOC uniqueness and bibliography tail
4. Max 3 repair loops
