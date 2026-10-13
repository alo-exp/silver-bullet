---
name: ai-llm-safety
description: This skill should be used when designing, planning, implementing, or reviewing any system that involves LLM agents, tool use, prompt construction, or agentic workflows, or when the user asks to "add guardrails", "prevent prompt injection", "sanitize LLM output" — enforces prompt injection defense, tool safety, and context integrity
user-invocable: false
version: 0.1.0
---

# /ai-llm-safety — AI/LLM Safety Design Enforcement

Every system that involves LLM agents, tool use, or prompt construction MUST treat AI safety as a first-class constraint. Prompt injection is the SQL injection of the AI era — and it's harder to fix after deployment.

**Why this matters:** LLM-powered systems are uniquely vulnerable to attacks that exploit the model's instruction-following nature. A single prompt injection can exfiltrate data, execute unauthorized actions, or compromise downstream systems. Unlike traditional software bugs, these vulnerabilities exist at the semantic layer and cannot be caught by linters or type checkers.

**When to invoke:** During PLANNING (after brainstorming, before or alongside writing plans) and during REVIEW (as part of code review criteria). This skill applies to ALL code that constructs prompts, processes LLM output, or orchestrates agent workflows.

---

## The Rules

### Rule 1: Treat All External Content as Untrusted Data

Any content not authored by the system itself is untrusted. This includes:

| Source | Risk | Mitigation |
|--------|------|------------|
| User input | Direct prompt injection | Isolate from system instructions; validate format |
| Web pages / fetched content | Indirect prompt injection | Never pass raw content as instructions; summarize or extract data only |
| Tool results / API responses | Poisoned upstream data | Validate schema; never execute embedded instructions |
| File contents (uploaded/read) | Embedded injection payloads | Treat as data, not instructions; scan for instruction-like patterns |
| Database records | Stored injection (persistent) | Sanitize on read; never interpolate into prompts as instructions |
| Email / message content | Social engineering + injection | Always verify instructions with user before acting |

**The cardinal rule:** Data flows into prompts as DATA, never as INSTRUCTIONS. If untrusted content must appear in a prompt, it must be clearly delimited and the model must be instructed to treat it as data.

### Rule 2: Prompt Construction Safety

| Principle | Requirement |
|-----------|-------------|
| System/user separation | System instructions and user content must be clearly separated and labeled |
| No string interpolation of untrusted data into system prompts | Use structured message formats; never `f"You are a {user_input} assistant"` |
| Instruction hierarchy | System prompt > user instructions > tool results > observed content |
| Defense in depth | Multiple layers: input validation + prompt structure + output validation |
| Least privilege prompting | Only grant the model capabilities it needs for the specific task |

### Rule 3: Tool Use Safety

Tools give LLMs the ability to affect the real world. Every tool call must be scrutinized:

| Principle | Requirement |
|-----------|-------------|
| Principle of least privilege | Each agent/tool gets minimum permissions needed |
| Explicit allowlists | Define what actions ARE allowed, not what ISN'T |
| Confirmation gates | Destructive or irreversible actions require user confirmation |
| Input validation on tool parameters | Validate all parameters before execution — type, range, format |
| Output sanitization | Tool outputs returned to the model must not contain executable instructions |
| Rate limiting | Prevent runaway tool loops; cap iterations and API calls |
| Audit logging | Log all tool invocations with parameters for forensic review |

### Rule 4: Context Integrity

The model's context window is its working memory. Protect it:

- **No context poisoning:** Prevent untrusted content from overwriting or contradicting system instructions
- **No instruction smuggling:** Detect and block attempts to inject instructions via tool results, file contents, or fetched web pages
- **No role confusion:** The model must always know its role and not adopt roles suggested by untrusted content
- **No authority escalation:** Untrusted content cannot claim admin/system/developer privileges
- **Context provenance tracking:** Always maintain awareness of where each piece of context originated

### Rule 5: Output Safety

LLM outputs can be dangerous if consumed without validation:

| Risk | Mitigation |
|------|------------|
| Generated code execution | Sandbox all generated code; never `eval()` LLM output |
| Structured output injection | Validate JSON/XML schema before parsing; reject malformed output |
| Exfiltration via output | Monitor for sensitive data in responses; redact PII/secrets |
| Hallucinated credentials/URLs | Never trust URLs, API keys, or credentials in LLM output — verify independently |
| Chain-of-thought leakage | Ensure internal reasoning doesn't leak sensitive system details |

### Rule 6: Multi-Agent Safety

When multiple agents collaborate, the attack surface multiplies:

| Principle | Requirement |
|-----------|-------------|
| Agent isolation | Each agent operates in its own trust boundary; no shared mutable state without validation |
| Message authentication | Verify the source of inter-agent messages; don't trust agent identity claims |
| Capability delegation | An agent cannot grant capabilities it doesn't have to another agent |
| Recursive injection prevention | Agent A's output processed by Agent B must be treated as untrusted by Agent B |
| Termination guarantees | All agent chains must have maximum depth/iteration limits |

### Rule 7: Data Exfiltration Prevention

LLM systems can be tricked into leaking sensitive data through subtle channels:

- **No sensitive data in URLs:** Never include secrets, PII, or internal data in URL parameters, API calls, or fetch requests
- **No sensitive data in tool parameters:** Validate that tool call arguments don't contain exfiltrated data
- **Monitor outbound channels:** Any network call, file write, or message send is a potential exfiltration vector
- **Covert channel awareness:** Data can be encoded in seemingly innocuous outputs (base64 in filenames, steganography in generated content)

---

## Planning Checklist

Before finalizing any design or plan involving LLM agents, run this checklist:

- [ ] All external content (user input, web pages, tool results, files) is treated as untrusted data
- [ ] Prompt construction separates system instructions from untrusted content with clear delimiters
- [ ] No string interpolation of untrusted data into system-level prompts
- [ ] Every tool has explicit parameter validation and least-privilege permissions
- [ ] Destructive/irreversible tool actions require user confirmation gates
- [ ] Multi-agent communication treats inter-agent messages as untrusted
- [ ] Agent chains have maximum depth/iteration limits (termination guarantees)
- [ ] Outputs are validated before being consumed by downstream systems
- [ ] No sensitive data (secrets, PII, credentials) can leak via tool parameters, URLs, or outputs
- [ ] Context integrity is maintained — untrusted content cannot override system instructions
- [ ] Encoded/obfuscated content in inputs is detected and flagged (base64, hex, unicode escapes)
- [ ] Rate limiting exists on tool calls and API interactions to prevent runaway loops

If any item fails: **redesign before proceeding to implementation.**

---

## Anti-Patterns

| Pattern | Problem | Fix |
|---------|---------|-----|
| Trusting tool results as instructions | Indirect prompt injection | Treat all tool results as data; verify with user |
| `eval()` on LLM output | Arbitrary code execution | Sandbox or validate against schema |
| Shared context between untrusted agents | Cross-agent injection | Isolate contexts; validate inter-agent messages |
| "The model will figure it out" | No defense in depth | Explicit validation at every boundary |
| Logging full prompts with user data | PII/secret exposure in logs | Redact sensitive fields before logging |
| No iteration limits on agent loops | Infinite loops / resource exhaustion | Hard caps on iterations and API calls |

---

## Rationalization Prevention

| Excuse | Reality |
|--------|---------|
| "It's just an internal tool" | Internal tools process external data. Injection still works. |
| "The model is smart enough to ignore injections" | Models follow instructions. That's the vulnerability. |
| "We'll add safety later" | Safety is architectural. Retrofitting is 10x harder. |
| "Nobody would inject into this input" | Automated attacks are cheap. Assume adversarial inputs. |
| "It's behind authentication" | Authenticated users can still be social-engineered. |
| "The content is from a trusted source" | Trust is transitive. If the source is compromised, you are too. |
