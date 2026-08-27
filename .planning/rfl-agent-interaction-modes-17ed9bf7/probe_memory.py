#!/usr/bin/env python3
import json
import urllib.request

urls = [
    "http://127.0.0.1:3111/",
    "http://127.0.0.1:3111/health",
    "http://127.0.0.1:3111/docs",
    "http://127.0.0.1:3111/openapi.json",
    "http://127.0.0.1:3111/agentmemory",
    "http://127.0.0.1:3111/api",
]
out = []
for url in urls:
    try:
        with urllib.request.urlopen(url, timeout=3) as resp:
            out.append({"url": url, "status": resp.status, "body": resp.read()[:500].decode("utf-8", "replace")})
    except Exception as exc:
        out.append({"url": url, "error": str(exc)})
print(json.dumps(out, indent=2))
