#!/usr/bin/env python3
from pathlib import Path

PLAN = Path("/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md")
text = PLAN.read_text(encoding="utf-8")
orig = text

old1 = "- **Modify** `src/providers/brave.rs` — bounded: `bucket::acquire(\"brave\", …, collector)` before HTTP\n"
new1 = (
    old1
    + "- **Modify** `src/doctor.rs` — bounded: pings through `bucket::acquire(..., collector)`; "
    "honor `--quota-dir`/`--cache-dir`; slot-exempt; `doctor_skip_requires_domain` for discourse; "
    "registries = 4 acquires; `doctor_rate_limited` warning (M5)\n"
)
if text.count(old1) != 1:
    raise SystemExit(f"§8.1 brave.rs: expected 1, got {text.count(old1)}")
text = text.replace(old1, new1, 1)

old2 = "8. `src/providers/serper.rs` — bucket acquire only (keep `augment_query` `site:`)\n"
new2 = (
    "8. `src/providers/serper.rs` — bucket acquire only (keep `augment_query` `site:`); "
    "**`src/doctor.rs`** — bounded: acquire pings, honor `--quota-dir`/`--cache-dir`, "
    "slot-exempt, `doctor_skip_requires_domain`, registries=4, `doctor_rate_limited`\n"
)
if text.count(old2) != 1:
    raise SystemExit(f"§8.4 item 8: expected 1, got {text.count(old2)}")
text = text.replace(old2, new2, 1)

old3 = "`SB_DR_FLEET_SLOTS` is orchestrator-only (fork does not read it)."
new3 = (
    old3
    + " `src/doctor.rs` is on the §8.1/§8.4 Modify checklists (bounded doctor patch)."
)
if text.count(old3) != 1:
    raise SystemExit("L85 ACCEPT bullet missing")
text = text.replace(old3, new3, 1)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
