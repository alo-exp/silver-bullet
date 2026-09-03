#!/usr/bin/env python3
import hashlib
from pathlib import Path

PLAN = Path("/Users/shafqat/.cursor/plans/dr_search_gateway_prd_ecb5030e.plan.md")
LEDGER = Path(__file__).resolve().parent / "ISSUE-LEDGER.md"
text = PLAN.read_text(encoding="utf-8")
orig = text


def one(old, new, label):
    global text
    c = text.count(old)
    if c != 1:
        raise SystemExit(f"{label}: expected 1 hit, got {c}")
    text = text.replace(old, new, 1)


one(
    "and (if the user connects email to the host agent) autonomously signs up and configures keys.",
    "and (if the user connects email to the host agent) drives signup under per-row `signup_automation` gates (creation defaults `manual_only`; existing-account check first) and configures keys.",
    "R2P4-3",
)

one(
    "- **X `search/all` (archive upgrade):** same X developer app; paid upgrade only. MVP completeness uses `search/recent` + fallbacks above.",
    "- **X `search/all` (archive upgrade):** `signup_automation: manual_only`. same X developer app; paid upgrade only. MVP completeness uses `search/recent` + fallbacks above.",
    "R2P4-2",
)

one(
    "Orchestrator **must not** embed `site:` in `-q` for **bare-host** Method B (use `-d` only; see §6.9).",
    "Orchestrator **must not** embed `site:` in `-q` for **bare-host** Method B (use `-d` only; see §6.9). **Locked X complement exception (2026-08-31):** the dedicated X Serper last-resort leg carries `site:x.com` in `-q` and **omits `-d`** (hash the query as given). This is a locked exception to the bare-host `-d` rule — do not \"correct\" it to `-d x.com`.",
    "R2P4-1-s63",
)

one(
    "must **not** also paste `site:` into `-q` (double `site:`).",
    "must **not** also paste `site:` into `-q` (double `site:`). **Locked X complement exception (2026-08-31):** dedicated Serper `site:x.com` in `-q` (omit `-d`) is a locked exception to this bare-host rule; hash the query as given.",
    "R2P4-1-s69",
)

one(
    "**Rung 2 Kimi pass-3 ACCEPTs:** §2.2 bucket short-names include `x`/`xweb`; xweb envs load via `resolve_keys` (not figment `SEARCH_KEYS_XWEB_GUEST`).",
    "**Rung 2 Kimi pass-3 ACCEPTs:** §2.2 bucket short-names include `x`/`xweb`; xweb envs load via `resolve_keys` (not figment `SEARCH_KEYS_XWEB_GUEST`). **Rung 2 Kimi pass-4 ACCEPTs:** dedicated X `site:x.com` in `-q` is a locked exception to the §6.3/§6.9 bare-host `-d` rule; §2.8 X `search/all` stamps `signup_automation: manual_only`; frontmatter overview no longer claims autonomous signup.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
print(f"sha256 {digest}")

old_sha = "f7cf259f122f70e28e854d28ea8f620a52640e8eb4b527369e08564fb3c92260"
led = LEDGER.read_text(encoding="utf-8")
if old_sha not in led:
    raise SystemExit("ledger missing prior SHA")
led = led.replace(old_sha, digest)
led = led.replace(
    "| I-57 | LOW | ACCEPT | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) |",
    "| I-57 | LOW | ACCEPT | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) |\n"
    "| I-58 | LOW | ACCEPT | X site:x.com in -q is locked exception to bare-host -d (R2P4-1) |\n"
    "| I-59 | NIT | ACCEPT | §2.8 X search/all stamps signup_automation manual_only (R2P4-2) |\n"
    "| I-60 | NIT | ACCEPT | frontmatter overview no longer claims autonomous signup (R2P4-3) |",
    1,
)
led = led.replace(
    "| I-57 | LOW | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) | rung-02 Kimi pass-3 | yes | yes |",
    "| I-57 | LOW | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) | rung-02 Kimi pass-3 | yes | yes |\n"
    "| I-58 | LOW | X site:x.com in -q is locked exception to bare-host -d (R2P4-1) | rung-02 Kimi pass-4 | yes | yes |\n"
    "| I-59 | NIT | §2.8 X search/all stamps signup_automation manual_only (R2P4-2) | rung-02 Kimi pass-4 | yes | yes |\n"
    "| I-60 | NIT | frontmatter overview no longer claims autonomous signup (R2P4-3) | rung-02 Kimi pass-4 | yes | yes |",
    1,
)
if "| I-58 |" not in led:
    raise SystemExit("ledger I-58 missing after edit")
LEDGER.write_text(led, encoding="utf-8")
print("ledger updated I-58..I-60")
