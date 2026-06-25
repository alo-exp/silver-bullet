# Self-Verification: Graphify + agentmemory in Hermes (Global)

Machine-level audit for **Hermes** agent — no Silver Bullet prerequisite.

**Setup script:** `bash scripts/graphify-am-global-setup.sh --host hermes --apply`

---

## Phase 1 — Pre-flight

```bash
which graphify && which agentmemory
test -d ~/.hermes && echo hermes-home-ok
```

---

## Phase 2 — Global config artifacts

### 2.1 Graphify skill

```bash
test -f ~/.hermes/skills/graphify/SKILL.md && echo graphify-skill-ok
```

**Apply:** `graphify install --platform hermes` && `graphify hermes install`

### 2.2 agentmemory wiring

```bash
grep -i agentmemory ~/.hermes/config.yaml 2>/dev/null
agentmemory status 2>/dev/null | grep -i hermes
```

**Apply:** `agentmemory connect hermes`

### 2.3 synergy_max `.env`

```bash
grep AGENTMEMORY_INJECT_CONTEXT=true ~/.agentmemory/.env
grep AGENTMEMORY_EXPORT_ROOT ~/.agentmemory/.env
```

---

## Phase 3 — Server and hooks

```bash
curl -sf http://localhost:3111/agentmemory/health
graphify hook status
launchctl list 2>/dev/null | grep com.agentmemory.server || true
```

---

## Phase 4 — Manual synergy test (Hermes UI)

1. Confirm graphify skill loads in Hermes sessions.
2. Save a decision via agentmemory.
3. In a git repo: export → `graphify update . --no-cluster` → `graphify query`.

---

## Appendix — If Silver Bullet is active

Hermes is in SB `multi_agent.identity_tags`. Global `~/.hermes/` config is independent of `.silver-bullet.json`.
