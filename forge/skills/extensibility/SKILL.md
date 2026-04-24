---
id: extensibility
title: Extensibility Quality Dimension
description: Enforces open-closed design, plugin architectures, stable interfaces, and versioning
trigger:
  - "extensibility"
  - "extensible"
  - "plugin"
  - "open closed"
---

# Extensibility Quality Dimension

Systems must be able to grow without breaking existing consumers. Open for extension, closed for modification.

## Checklist

Mark each item ✅ Pass / ❌ Fail / ⚠️ N/A:

### Open/Closed Principle
- [ ] New features added without modifying existing code
- [ ] Extension points defined (hooks, events, plugins)
- [ ] Abstract base classes/interfaces for customization
- [ ] Strategy pattern for swappable algorithms

### Stable Interfaces
- [ ] Public APIs are versioned
- [ ] Breaking changes require major version bump
- [ ] Deprecation warnings before removal
- [ ] Interface stability across minor versions

### Plugin Architecture
- [ ] Extension points documented
- [ ] Plugins can add functionality without core changes
- [ ] Plugin lifecycle managed (install, enable, disable)
- [ ] Sandboxing prevents plugin from breaking core

### Configuration
- [ ] Behavior controlled by configuration
- [ ] New options added without code changes
- [ ] Configuration is discoverable and documented
- [ ] Environment-specific settings supported

### Versioning Strategy
- [ ] Semantic versioning followed
- [ ] Changelog maintained
- [ ] Migration paths documented
- [ ] Backwards compatibility maintained

## When to Check
- Design-time: verify extension points in the design
- Pre-ship: verify no unnecessary breaking changes

## Fix if Failing
Add extension points. Extract interfaces. Refactor to plugin architecture. Version your APIs.
