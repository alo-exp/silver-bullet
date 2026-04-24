---
id: ai-llm-safety
title: AI/LLM Safety Quality Dimension
description: Enforces safe AI usage practices, prevents prompt injection, and ensures model safety
trigger:
  - "AI safety"
  - "LLM safety"
  - "prompt injection"
  - "AI/LLM safety"
---

# AI/LLM Safety Quality Dimension

When AI or LLM features are involved, specific safety considerations apply.

## Checklist

Mark each item ✅ Pass / ❌ Fail / ⚠️ N/A:

### Prompt Injection Prevention
- [ ] User input sanitized before inclusion in prompts
- [ ] Prompt templates separated from user data
- [ ] Output parsing validates response structure
- [ ] Injection attempts logged and monitored

### Model Usage
- [ ] Model outputs treated as untrusted
- [ ] Validation on all model responses
- [ ] Rate limiting on model calls
- [ ] Cost controls implemented

### Sensitive Data
- [ ] No sensitive data sent to external models
- [ ] Data minimization principle applied
- [ ] Retention policies defined
- [ ] PII handled appropriately

### Output Safety
- [ ] Model outputs filtered for sensitive content
- [ ] Harmful content blocked
- [ ] Hallucination mitigation (citations, validation)
- [ ] Confidence levels surfaced

### Alignment & Governance
- [ ] Model behavior tested before deployment
- [ ] Human oversight on high-stakes decisions
- [ ] Audit trail for model decisions
- [ ] Rollback capability if issues found

## When to Check
- Design-time: when AI/LLM features are in scope
- Pre-ship: verify all safety measures implemented

## Fix if Failing
Add input sanitization. Implement output validation. Add rate limiting. Add audit logging.

## Note
If this project does not use AI/LLM features, mark all items ⚠️N/A with explanation: "No AI/LLM features in scope."
