# Self-Verification: Graphify + agentmemory in Goose (Pi runtime, Global)

Machine-level audit for **Block Goose** (Pi coding-agent runtime) — no Silver Bullet prerequisite.

Goose uses the **Pi** upstream platform for Graphify and `agentmemory connect pi`.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host goose --apply`

---

## Phase 1 — Pre-flight

```bash
which graphify && which agentmemory
test -f ~/.config/goose/config.yaml && echo goose-config-ok
```

---

## Phase 2 — Global config artifacts

### 2.1 Graphify skill (Pi path)

```bash
test -f ~/.pi/agent/skills/graphify/SKILL.md && grep -q graphify ~/.pi/agent/skills/graphify/SKILL.md && echo OK
```

**Apply:** `graphify install --platform pi` && `graphify pi install`

### 2.2 agentmemory (Pi extension)

```bash
grep -i agentmemory ~/.config/goose/config.yaml 2>/dev/null
agentmemory status 2>/dev/null | grep -i pi
```

**Apply:** `agentmemory connect pi` (see agentmemory `integrations/pi.md`)

### 2.3 synergy_max `.env`

```bash
grep AGENTMEMORY_INJECT_CONTEXT=true ~/.agentmemory/.env
```

---

## Phase 3 — Server and hooks

```bash
curl -sf http://localhost:3111/agentmemory/health
graphify hook status
```

---

## Phase 4 — Manual synergy test (Goose UI)

1. In Goose, invoke graphify skill or run `graphify query` from a project terminal.
2. Capture a note via agentmemory/Pi tools if exposed.
3. Export, re-index, query — confirm memory nodes appear in graph.

---

## Appendix — If Silver Bullet is active

SB maps host id `goose` → graphify platform `pi`. Project-level `.pi/agent/` artifacts may also exist; global `~/.pi/agent/skills/graphify/` takes precedence for new sessions.
