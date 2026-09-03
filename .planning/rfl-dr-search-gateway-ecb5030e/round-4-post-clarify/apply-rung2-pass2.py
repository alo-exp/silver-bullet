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
    "    slots[\"fleet-slots.lock/ 0.lock..N-1.lock\"]\n  end",
    "    slots[\"fleet-slots.lock/ 0.lock..N-1.lock\"]\n    tok[\"reddit-oauth-token.json + .lock\"]\n  end",
    "K7",
)

one(
    "- `config.example.toml`: comments name `SEARCH_KEYS_BRAVE` / `SEARCH_KEYS_SERPER` **and** `SEARCH_KEYS_GITHUB` / `SEARCH_KEYS_GITLAB` / `SEARCH_KEYS_STACKEXCHANGE` / `SEARCH_KEYS_YOUTUBE` / `SEARCH_KEYS_REDDIT` / `SEARCH_KEYS_REDDITSECRET` **and** `SEARCH_KEYS_X` / `SEARCH_KEYS_XWEB_GUEST` (and `X_BEARER_TOKEN` / `X_GUEST_TOKEN` / `XWEB_COOKIES` as in §6.8); `SEARCH_BRAVE_KEY` / `SEARCH_SERPER_KEY` absent",
    "- `config.example.toml` **Phase 1:** comments name `SEARCH_KEYS_BRAVE` / `SEARCH_KEYS_SERPER` **and** `SEARCH_KEYS_GITHUB` / `SEARCH_KEYS_GITLAB` / `SEARCH_KEYS_STACKEXCHANGE` / `SEARCH_KEYS_YOUTUBE` / `SEARCH_KEYS_REDDIT` / `SEARCH_KEYS_REDDITSECRET`; `SEARCH_BRAVE_KEY` / `SEARCH_SERPER_KEY` absent. **Phase 2:** comments also name `SEARCH_KEYS_X` / `SEARCH_KEYS_XWEB_GUEST` (and `X_BEARER_TOKEN` / `X_GUEST_TOKEN` / `XWEB_COOKIES` as in §6.8)",
    "K8",
)

one(
    "Cache fingerprint: provider + normalized query (lowercase, stable `site:` order) + domains/filters.",
    "Cache fingerprint: provider + mode + normalized query (lowercase, stable `site:` order) + domains/filters + `--allow-private` boolean.",
    "K9",
)

one(
    "Phase 3 adds `.planning/research/_search-cache/` to the SB repo `.gitignore`.",
    "Phase 3 adds `.planning/research/_search-cache/` to the researched project's root `.gitignore` when one exists (and to the SB repo's own `.gitignore` for SB self-runs); the orchestrator-written inner `{SEARCH_CACHE_DIR}/.gitignore` remains the primary guard.",
    "K10a",
)

one(
    "SB root `.gitignore` lists `.planning/research/_search-cache/`.",
    "researched-project root `.gitignore` (when one exists) lists `.planning/research/_search-cache/` (and the SB repo `.gitignore` for SB self-runs); inner `{SEARCH_CACHE_DIR}/.gitignore` remains the primary guard.",
    "K10b",
)

one(
    "official[github gitlab se hn discourse youtube registries reddit]",
    "official[github gitlab se hn discourse youtube registries reddit x xweb]",
    "K11",
)

one(
    "**Rung 2 Kimi ACCEPTs:** §6.4 Serper free 2,500 vs Starter 50k; §3.2 `partial_success`; §2.7 step 4 keys via `search config set` only (no env persist); probe native list includes `x`/`xweb`; cargo-install `SB_SEARCH_BIN` is `$HOME/.cargo/bin/search`; §4.4 X-credit-0 alert includes xweb.",
    "**Rung 2 Kimi ACCEPTs:** §6.4 Serper free 2,500 vs Starter 50k; §3.2 `partial_success`; §2.7 step 4 keys via `search config set` only (no env persist); probe native list includes `x`/`xweb`; cargo-install `SB_SEARCH_BIN` is `$HOME/.cargo/bin/search`; §4.4 X-credit-0 alert includes xweb. **Rung 2 Kimi pass-2 ACCEPTs:** §7 mermaid quota includes `reddit-oauth-token.json`+.lock; §6.12 `config.example.toml` X keys are Phase-2-gated; §2.3 fingerprint includes `--allow-private`; researched-project (not SB-only) root `.gitignore`; §7 mermaid providers include `x`/`xweb`.",
    "L85",
)

if text == orig:
    raise SystemExit("no change")
PLAN.write_text(text, encoding="utf-8")
digest = hashlib.sha256(text.encode("utf-8")).hexdigest()
print(f"wrote {len(text)} bytes, {text.count(chr(10))+1} lines")
print(f"sha256 {digest}")

old_sha = "9b79d0144559ac6abbe360f39f7c894742295bb0f1e245124b21606559099a21"
led = LEDGER.read_text(encoding="utf-8")
if old_sha not in led:
    raise SystemExit("ledger missing prior SHA")
led = led.replace(old_sha, digest)
rows1 = (
    "| I-50 | NIT | ACCEPT | §4.4 X-credit-0 alert includes xweb (K6) |\n"
    "| I-51 | NIT | ACCEPT | §7 mermaid quota includes reddit-oauth-token.json+.lock (K7) |\n"
    "| I-52 | LOW | ACCEPT | §6.12 config.example.toml X keys Phase-2-gated (K8) |\n"
    "| I-53 | NIT | ACCEPT | §2.3 fingerprint includes --allow-private (K9) |\n"
    "| I-54 | NIT | ACCEPT | researched-project (not SB-only) root .gitignore (K10) |\n"
    "| I-55 | NIT | ACCEPT | §7 mermaid providers include x/xweb (K11) |"
)
if rows1.split("\n")[0] not in led:
    raise SystemExit("ledger I-50 row missing")
if "| I-51 |" in led:
    raise SystemExit("I-51 already present")
led = led.replace(
    "| I-50 | NIT | ACCEPT | §4.4 X-credit-0 alert includes xweb (K6) |",
    rows1,
    1,
)
rows2 = (
    "| I-50 | NIT | §4.4 X-credit-0 alert includes xweb (K6) | rung-02 Kimi K3 High | yes | yes |\n"
    "| I-51 | NIT | §7 mermaid quota includes reddit-oauth-token.json+.lock (K7) | rung-02 Kimi pass-2 | yes | yes |\n"
    "| I-52 | LOW | §6.12 config.example.toml X keys Phase-2-gated (K8) | rung-02 Kimi pass-2 | yes | yes |\n"
    "| I-53 | NIT | §2.3 fingerprint includes --allow-private (K9) | rung-02 Kimi pass-2 | yes | yes |\n"
    "| I-54 | NIT | researched-project (not SB-only) root .gitignore (K10) | rung-02 Kimi pass-2 | yes | yes |\n"
    "| I-55 | NIT | §7 mermaid providers include x/xweb (K11) | rung-02 Kimi pass-2 | yes | yes |"
)
led = led.replace(
    "| I-50 | NIT | §4.4 X-credit-0 alert includes xweb (K6) | rung-02 Kimi K3 High | yes | yes |",
    rows2,
    1,
)
LEDGER.write_text(led, encoding="utf-8")
print("ledger updated I-51..I-55")
