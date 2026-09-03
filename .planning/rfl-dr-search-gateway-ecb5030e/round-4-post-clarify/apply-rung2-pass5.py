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
    "Fleet never passes `--x` / `-m social`.",
    "Fleet never passes `--x` (the shorthand that forces `-m social -p xai`); the X union's xAI leg passes explicit `-m social -p xai` (§1.2 leg B). `-m social` is never the default mode for non-X channels.",
    "R2P5-1",
)

one(
    "Dedup by tweet URL/id in the orchestrator (preferred) or the fork if one process unions.",
    "Dedup by tweet URL/id in the orchestrator (locked; §1.4).",
    "R2P5-2",
)

one(
    "`buckets/<host>.lock` + `buckets/<host>.json`",
    "`buckets/{id}.lock` + `buckets/{id}.json`",
    "R2P5-3",
)

one(
    "serper[Serper site via -d]",
    'serper["Serper site: via -d (bare host) or -q (X / path-scoped)"]',
    "R2P5-4",
)

one(
    "**Rung 2 Kimi pass-4 ACCEPTs:** dedicated X `site:x.com` in `-q` is a locked exception to the §6.3/§6.9 bare-host `-d` rule; §2.8 X `search/all` stamps `signup_automation: manual_only`; frontmatter overview no longer claims autonomous signup.",
    "**Rung 2 Kimi pass-4 ACCEPTs:** dedicated X `site:x.com` in `-q` is a locked exception to the §6.3/§6.9 bare-host `-d` rule; §2.8 X `search/all` stamps `signup_automation: manual_only`; frontmatter overview no longer claims autonomous signup. **Rung 2 Kimi pass-5 ACCEPTs:** §6.1 fleet never `--x` shorthand (xAI leg still explicit `-m social -p xai`); §1.2 X dedup is orchestrator-only; §6.3 quota files use `{id}` not `<host>`; §7 Serper node names `-d` bare-host and `-q` X/path-scoped exceptions.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
print(f"sha256 {digest}")

old_sha = "44bf064c33810669bf945f91a4e05afa24e5c82fef36a43dabe499f159d28fc4"
led = LEDGER.read_text(encoding="utf-8")
if old_sha not in led:
    raise SystemExit("ledger missing prior SHA")
led = led.replace(old_sha, digest)
led = led.replace(
    "| I-60 | NIT | ACCEPT | frontmatter overview no longer claims autonomous signup (R2P4-3) |",
    "| I-60 | NIT | ACCEPT | frontmatter overview no longer claims autonomous signup (R2P4-3) |\n"
    "| I-61 | LOW | ACCEPT | §6.1 fleet never --x shorthand; xAI leg still -m social -p xai (R2P5-1) |\n"
    "| I-62 | NIT | ACCEPT | §1.2 X dedup orchestrator-only not fork (R2P5-2) |\n"
    "| I-63 | NIT | ACCEPT | §6.3 quota files buckets/{id} not <host> (R2P5-3) |\n"
    "| I-64 | NIT | ACCEPT | §7 Serper node names -d bare-host and -q exceptions (R2P5-4) |",
    1,
)
led = led.replace(
    "| I-60 | NIT | frontmatter overview no longer claims autonomous signup (R2P4-3) | rung-02 Kimi pass-4 | yes | yes |",
    "| I-60 | NIT | frontmatter overview no longer claims autonomous signup (R2P4-3) | rung-02 Kimi pass-4 | yes | yes |\n"
    "| I-61 | LOW | §6.1 fleet never --x shorthand; xAI leg still -m social -p xai (R2P5-1) | rung-02 Kimi pass-5 | yes | yes |\n"
    "| I-62 | NIT | §1.2 X dedup orchestrator-only not fork (R2P5-2) | rung-02 Kimi pass-5 | yes | yes |\n"
    "| I-63 | NIT | §6.3 quota files buckets/{id} not <host> (R2P5-3) | rung-02 Kimi pass-5 | yes | yes |\n"
    "| I-64 | NIT | §7 Serper node names -d bare-host and -q exceptions (R2P5-4) | rung-02 Kimi pass-5 | yes | yes |",
    1,
)
if "| I-61 |" not in led:
    raise SystemExit("ledger I-61 missing after edit")
LEDGER.write_text(led, encoding="utf-8")
print("ledger updated I-61..I-64")
