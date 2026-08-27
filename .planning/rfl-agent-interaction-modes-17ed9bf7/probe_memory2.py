#!/usr/bin/env python3
import json
import urllib.request

paths = [
    "/tools",
    "/mcp",
    "/remember",
    "/recall",
    "/save",
    "/v1/remember",
    "/v1/save",
    "/iii/remember",
    "/iii/memory",
    "/engine/memory",
    "/api/v1/memory",
    "/api/memory",
    "/sessions",
    "/status",
]
out = []
for p in paths:
    url = "http://127.0.0.1:3111" + p
    for method in ("GET", "POST"):
        try:
            req = urllib.request.Request(url, method=method, data=b"{}" if method == "POST" else None)
            if method == "POST":
                req.add_header("Content-Type", "application/json")
            with urllib.request.urlopen(req, timeout=2) as resp:
                out.append({"url": url, "method": method, "status": resp.status, "body": resp.read()[:200].decode("utf-8", "replace")})
        except Exception as exc:
            out.append({"url": url, "method": method, "error": str(exc)[:180]})
print(json.dumps(out, indent=2))
