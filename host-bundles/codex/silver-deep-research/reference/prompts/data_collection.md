# Data collection prompt

Batch retrieval per `reference/search-orchestration.md`.

1. Run `search_orchestrator.py` or host search
2. Register each source via `citation_manager.py register-source`
3. Persist spans via `evidence_store.py add`
4. Record `run_manifest.json` retrieval block
