#!/usr/bin/env node
/**
 * MiniMax OpenAI-compatible proxy for Alumnium v0.21.0.
 *
 * MiniMax returns `"parsed": true` (boolean); Alumnium/LangChain expect a record
 * or absent (LchainSchema in alumnium src/llm/LchainSchema.ts).
 *
 *   OPENAI_CUSTOM_URL=http://127.0.0.1:18721/v1
 *   node scripts/minimax-openai-proxy.mjs
 *
 * Env:
 *   MINIMAX_OPENAI_UPSTREAM  — default https://api.minimax.io
 *   MINIMAX_OPENAI_PROXY_PORT — default 18721
 */
import http from 'node:http';
import https from 'node:https';
import { URL } from 'node:url';

const UPSTREAM = (process.env.MINIMAX_OPENAI_UPSTREAM || 'https://api.minimax.io').replace(
  /\/$/,
  '',
);
const PORT = Number(process.env.MINIMAX_OPENAI_PROXY_PORT || 18721);

function upstreamPath(path) {
  if (path.startsWith('/v1/') || path === '/v1') return path;
  if (path.startsWith('/')) return `/v1${path}`;
  return `/v1/${path}`;
}

/** Recursively fix MiniMax fields that break Alumnium Zod serialization. */
export function normalizeMiniMaxJson(value) {
  if (value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.map(normalizeMiniMaxJson);
  if (typeof value !== 'object') return value;

  const out = {};
  for (const [key, child] of Object.entries(value)) {
    if (key === 'parsed' && typeof child === 'boolean') {
      if (child) out[key] = {};
      continue;
    }
    if (key === 'user' && child === undefined) {
      out[key] = null;
      continue;
    }
    out[key] = normalizeMiniMaxJson(child);
  }
  if (out.type === 'output_text') {
    if (!Array.isArray(out.logprobs)) out.logprobs = [];
    if (!Array.isArray(out.annotations)) out.annotations = [];
  }
  return out;
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

function forwardRequest(method, path, headers, body) {
  const target = new URL(`${UPSTREAM}${upstreamPath(path)}`);
  const lib = target.protocol === 'https:' ? https : http;
  const fwdHeaders = { ...headers, host: target.host };
  delete fwdHeaders['content-length'];
  delete fwdHeaders['transfer-encoding'];

  return new Promise((resolve, reject) => {
    const req = lib.request(
      {
        protocol: target.protocol,
        hostname: target.hostname,
        port: target.port || (target.protocol === 'https:' ? 443 : 80),
        method,
        path: `${target.pathname}${target.search}`,
        headers: fwdHeaders,
      },
      (res) => {
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () =>
          resolve({ status: res.statusCode || 500, headers: res.headers, body: Buffer.concat(chunks) }),
        );
      },
    );
    req.on('error', reject);
    if (body?.length) req.write(body);
    req.end();
  });
}

function normalizeSseBody(text) {
  return text
    .split('\n')
    .map((line) => {
      if (!line.startsWith('data:')) return line;
      const payload = line.slice(5).trim();
      if (!payload || payload === '[DONE]') return line;
      try {
        return `data: ${JSON.stringify(normalizeMiniMaxJson(JSON.parse(payload)))}`;
      } catch {
        return line;
      }
    })
    .join('\n');
}

const server = http.createServer(async (req, res) => {
  try {
    const body = await readBody(req);
    const path = req.url || '/';
    const headers = { ...req.headers };
    delete headers.host;

    const upstream = await forwardRequest(req.method || 'GET', path, headers, body);
    let outBody = upstream.body;
    const outHeaders = { ...upstream.headers };
    const ct = outHeaders['content-type'] || '';

    if (ct.includes('text/event-stream')) {
      outBody = Buffer.from(normalizeSseBody(outBody.toString('utf8')));
    } else if (ct.includes('application/json') && outBody.length) {
      try {
        outBody = Buffer.from(JSON.stringify(normalizeMiniMaxJson(JSON.parse(outBody.toString('utf8')))));
      } catch {
        /* non-JSON */
      }
    }
    outHeaders['content-length'] = String(outBody.length);

    res.writeHead(upstream.status, outHeaders);
    res.end(outBody);
  } catch (err) {
    res.writeHead(502, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: { message: String(err.message || err) } }));
  }
});

if (import.meta.url === `file://${process.argv[1]}`) {
  server.listen(PORT, '127.0.0.1', () => {
    console.error(`minimax-openai-proxy http://127.0.0.1:${PORT}/v1 -> ${UPSTREAM}/v1`);
  });
}
