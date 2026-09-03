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
    "(short names: `stackexchange`, `github`, `gitlab`, `youtube`, `serper`, `brave`, `hn`, `reddit`, `registries`, `discourse-<sanitized-host>`)",
    "(short names: `stackexchange`, `github`, `gitlab`, `youtube`, `serper`, `brave`, `hn`, `reddit`, `registries`, `x`, `xweb`, `discourse-<sanitized-host>`)",
    "R2P3-1",
)

one(
    "Phase 2 unpaid: `xweb_guest_token` / `xweb_cookies` (`X_GUEST_TOKEN` / `SEARCH_KEYS_XWEB_GUEST` / `XWEB_COOKIES`) in 0600 `config.toml`.",
    "Phase 2 unpaid: `xweb_guest_token` / `xweb_cookies` in 0600 `config.toml`. Env via `resolve_keys` (not figment `split(\"_\")`): `X_GUEST_TOKEN` then `SEARCH_KEYS_XWEB_GUEST`; `XWEB_COOKIES`. Figment `SEARCH_KEYS_XWEB_GUEST` would nest to `keys.xweb.guest` and miss the flat field — do **not** rely on figment for xweb.",
    "R2P3-2",
)

one(
    "**Rung 2 Kimi pass-2 ACCEPTs:** §7 mermaid quota includes `reddit-oauth-token.json`+.lock; §6.12 `config.example.toml` X keys are Phase-2-gated; §2.3 fingerprint includes `--allow-private`; researched-project (not SB-only) root `.gitignore`; §7 mermaid providers include `x`/`xweb`.",
    "**Rung 2 Kimi pass-2 ACCEPTs:** §7 mermaid quota includes `reddit-oauth-token.json`+.lock; §6.12 `config.example.toml` X keys are Phase-2-gated; §2.3 fingerprint includes `--allow-private`; researched-project (not SB-only) root `.gitignore`; §7 mermaid providers include `x`/`xweb`. **Rung 2 Kimi pass-3 ACCEPTs:** §2.2 bucket short-names include `x`/`xweb`; xweb envs load via `resolve_keys` (not figment `SEARCH_KEYS_XWEB_GUEST`).",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
print(f"sha256 {digest}")

old_sha = "0f3258bc4a2b9ed937504c65a8c4a1259d92f5dd1e7f55cff4a370e401f3a79f"
led = LEDGER.read_text(encoding="utf-8")
if old_sha not in led:
    raise SystemExit("ledger missing prior SHA")
led = led.replace(old_sha, digest)
led = led.replace(
    "| I-55 | NIT | ACCEPT | §7 mermaid providers include x/xweb (K11) |",
    "| I-55 | NIT | ACCEPT | §7 mermaid providers include x/xweb (K11) |\n"
    "| I-56 | NIT | ACCEPT | §2.2 bucket short-names include x/xweb (R2P3-1) |\n"
    "| I-57 | LOW | ACCEPT | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) |",
    1,
)
led = led.replace(
    "| I-55 | NIT | §7 mermaid providers include x/xweb (K11) | rung-02 Kimi pass-2 | yes | yes |",
    "| I-55 | NIT | §7 mermaid providers include x/xweb (K11) | rung-02 Kimi pass-2 | yes | yes |\n"
    "| I-56 | NIT | §2.2 bucket short-names include x/xweb (R2P3-1) | rung-02 Kimi pass-3 | yes | yes |\n"
    "| I-57 | LOW | xweb envs via resolve_keys not figment SEARCH_KEYS_XWEB_GUEST (R2P3-2) | rung-02 Kimi pass-3 | yes | yes |",
    1,
)
if "| I-56 |" not in led:
    raise SystemExit("ledger I-56 missing after edit")
LEDGER.write_text(led, encoding="utf-8")
print("ledger updated I-56..I-57")
