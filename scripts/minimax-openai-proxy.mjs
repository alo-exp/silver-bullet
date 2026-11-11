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
 *   MINIMAX_OPENAI_MAX_BODY_BYTES — request / response size limit, default 16 MiB
 *   MINIMAX_OPENAI_TIMEOUT_MS — upstream timeout, default 120000
 */
import http from 'node:http';
import https from 'node:https';
import { realpathSync } from 'node:fs';
import zlib from 'node:zlib';
import { fileURLToPath, URL } from 'node:url';

const UPSTREAM = (process.env.MINIMAX_OPENAI_UPSTREAM || 'https://api.minimax.io').replace(
  /\/$/,
  '',
);
const PORT = Number(process.env.MINIMAX_OPENAI_PROXY_PORT || 18721);
const MAX_BODY_BYTES = Number(process.env.MINIMAX_OPENAI_MAX_BODY_BYTES || 16 * 1024 * 1024);
const UPSTREAM_TIMEOUT_MS = Number(process.env.MINIMAX_OPENAI_TIMEOUT_MS || 120000);

// Headers that describe one hop, not the message: never copied from the upstream response (the
// body is re-emitted whole, so its length is recomputed and its framing is ours).
const HOP_BY_HOP = [
  'connection',
  'keep-alive',
  'proxy-authenticate',
  'proxy-authorization',
  'te',
  'trailer',
  'transfer-encoding',
  'upgrade',
  'content-length',
  'content-encoding',
];

/** True when this file is the script node was started with, through symlinks and spaces. */
export function isMainModule(metaUrl = import.meta.url, argv1 = process.argv[1]) {
  if (!argv1) return false;
  try {
    return realpathSync(fileURLToPath(metaUrl)) === realpathSync(argv1);
  } catch {
    return false;
  }
}

/** Decode an upstream body according to its content-encoding header (identity when absent). */
export function decodeBody(body, encoding) {
  const options = { maxOutputLength: MAX_BODY_BYTES };
  switch (String(encoding || '').trim().toLowerCase()) {
    case 'gzip':
    case 'x-gzip':
      return zlib.gunzipSync(body, options);
    case 'deflate':
      return zlib.inflateSync(body, options);
    case 'br':
      return zlib.brotliDecompressSync(body, options);
    default:
      return body;
  }
}

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

class BodyTooLarge extends Error {}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > MAX_BODY_BYTES) {
        reject(new BodyTooLarge(`request body exceeds ${MAX_BODY_BYTES} bytes`));
        return;
      }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

/** `upstream` defaults to the configured MiniMax upstream; tests inject others. */
export function forwardRequest(method, path, headers, body, upstream = UPSTREAM) {
  const target = new URL(`${upstream}${upstreamPath(path)}`);
  const lib = target.protocol === 'https:' ? https : http;
  // Ask for an unencoded body: the proxy rewrites JSON, so it must be able to read it.
  const fwdHeaders = { ...headers, host: target.host, 'accept-encoding': 'identity' };
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
        let size = 0;
        let aborted = false;
        res.on('data', (c) => {
          if (aborted) return;
          size += c.length;
          if (size > MAX_BODY_BYTES) {
            aborted = true;
            req.destroy(new Error(`upstream response exceeds ${MAX_BODY_BYTES} bytes`));
            return;
          }
          chunks.push(c);
        });
        res.on('end', () => {
          if (aborted) return;
          resolve({ status: res.statusCode || 500, headers: res.headers, body: Buffer.concat(chunks) });
        });
      },
    );
    req.setTimeout(UPSTREAM_TIMEOUT_MS, () => req.destroy(new Error('upstream timed out')));
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
    let outBody = decodeBody(upstream.body, upstream.headers['content-encoding']);
    const outHeaders = { ...upstream.headers };
    for (const name of HOP_BY_HOP) delete outHeaders[name];
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
    res.writeHead(err instanceof BodyTooLarge ? 413 : 502, { 'content-type': 'application/json' });
    res.end(JSON.stringify({ error: { message: String(err.message || err) } }));
  }
});

if (isMainModule()) {
  server.listen(PORT, '127.0.0.1', () => {
    console.error(`minimax-openai-proxy http://127.0.0.1:${PORT}/v1 -> ${UPSTREAM}/v1`);
  });
}
