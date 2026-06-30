#!/usr/bin/env node
/**
 * Layer 3 — Gemini vision gate with golden-string anti-hallucination grounding.
 *
 * Usage:
 *   GEMINI_API_KEY=... node vision-gate.mjs --image path.png --golden golden.json [--label NAME]
 *   node vision-gate.mjs --self-test   # validates grounding logic without API
 *
 * Cursor subagent path: pass PNG via Task file_attachments + this prompt template.
 */
import { readFileSync, existsSync } from 'fs';
import { basename, dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const MODEL = process.env.VISION_MODEL || 'gemini-3.5-flash';
const API_KEY = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY;

const GROUNDING_PROMPT = `You are a visual QA inspector. Analyze the attached screenshot.

REQUIRED OUTPUT (JSON only, no markdown fences):
{
  "verdict": "PASS" | "FAIL",
  "quoted_strings": ["exact string 1", "exact string 2", ...],
  "observations": "brief layout/visual notes",
  "hallucination_risk": "low" | "medium" | "high"
}

RULES:
1. Quote at least 5 exact text strings visible in the image (copy verbatim, including punctuation).
2. Do NOT invent text not visible in the image.
3. If you cannot read 5 strings clearly, set verdict FAIL and hallucination_risk high.
4. For SDG/UN images: look for SDG YOUTH, United Nations, Youth Office, open source week, Youth-Led Open Source AI.
5. For Silver Bullet homepage: look for tagline, terminal mocks, platform pills.`;

function parseArgs() {
  const args = process.argv.slice(2);
  const opts = { selfTest: false, image: null, golden: null, label: 'vision-check' };
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--self-test') opts.selfTest = true;
    else if (args[i] === '--image' && args[i + 1]) opts.image = args[++i];
    else if (args[i] === '--golden' && args[i + 1]) opts.golden = args[++i];
    else if (args[i] === '--label' && args[i + 1]) opts.label = args[++i];
  }
  return opts;
}

function loadGolden(path) {
  if (!path || !existsSync(path)) return { strings: [] };
  const data = JSON.parse(readFileSync(path, 'utf8'));
  return { strings: data.strings || data.golden || [] };
}

function normalizeForMatch(s) {
  return s.toLowerCase().replace(/\s+/g, ' ').trim();
}

function stringInGolden(quoted, goldenStrings) {
  const q = normalizeForMatch(quoted);
  if (q.length < 3) return false;
  return goldenStrings.some((g) => {
    const gn = normalizeForMatch(g);
    return gn.includes(q) || q.includes(gn);
  });
}

export function validateGrounding(response, goldenStrings) {
  const quoted = response.quoted_strings || [];
  const minQuotes = 5;
  const failures = [];

  if (quoted.length < minQuotes) {
    failures.push(`Only ${quoted.length} quoted strings (need ${minQuotes})`);
  }

  const ungrounded = [];
  for (const q of quoted) {
    if (!stringInGolden(q, goldenStrings)) ungrounded.push(q);
  }
  if (ungrounded.length > 0) {
    failures.push(`Ungrounded quotes: ${ungrounded.map((s) => JSON.stringify(s)).join(', ')}`);
  }

  if (response.verdict !== 'PASS' && failures.length === 0) {
    failures.push(`Model verdict FAIL: ${response.observations || 'no reason'}`);
  }

  return {
    pass: failures.length === 0 && response.verdict === 'PASS',
    failures,
    quotedCount: quoted.length,
    ungrounded,
  };
}

async function callGeminiVision(imagePath, prompt) {
  if (!API_KEY) throw new Error('GEMINI_API_KEY or GOOGLE_API_KEY required for vision-gate API path');
  const imageBytes = readFileSync(imagePath);
  const b64 = imageBytes.toString('base64');
  const mime = imagePath.endsWith('.png') ? 'image/png' : 'image/jpeg';

  const url = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;
  const body = {
    contents: [{
      parts: [
        { text: prompt },
        { inline_data: { mime_type: mime, data: b64 } },
      ],
    }],
    generationConfig: { temperature: 0.1, responseMimeType: 'application/json' },
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-goog-api-key': API_KEY },
    body: JSON.stringify(body),
  });
  const json = await res.json();
  if (!res.ok) throw new Error(`Gemini API ${res.status}: ${JSON.stringify(json).slice(0, 500)}`);
  const text = json.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) throw new Error('Empty Gemini response');
  return JSON.parse(text.replace(/^```json\s*/i, '').replace(/```\s*$/i, ''));
}

function runSelfTest() {
  const golden = {
    strings: [
      'SDG YOUTH',
      'Connect',
      'United Nations',
      'Youth Office',
      'open source week_',
      'Youth-Led Open Source AI for Sustainable Futures: Bridging Developed and Developing Countries',
    ],
  };
  const good = {
    verdict: 'PASS',
    quoted_strings: [
      'SDG YOUTH',
      'United Nations',
      'Youth Office',
      'open source week_',
      'Youth-Led Open Source AI for Sustainable Futures',
    ],
    observations: 'SDG banner',
    hallucination_risk: 'low',
  };
  const bad = {
    verdict: 'PASS',
    quoted_strings: [
      'Silver Bullet',
      'THE PROCESS LAYER',
      'Claude Code',
      'Install Silver Bullet',
      'Maximize AI-driven',
    ],
    observations: 'hallucinated SB content',
    hallucination_risk: 'low',
  };
  const goodResult = validateGrounding(good, golden.strings);
  const badResult = validateGrounding(bad, golden.strings);
  console.log(`SELF-TEST good-SDG: ${goodResult.pass ? 'PASS' : 'FAIL'} ${goodResult.failures.join('; ') || ''}`);
  console.log(`SELF-TEST bad-hallucination: ${badResult.pass ? 'FAIL (should reject)' : 'PASS (correctly rejected)'} ${badResult.ungrounded.join(', ')}`);
  process.exit(goodResult.pass && !badResult.pass ? 0 : 1);
}

async function main() {
  const opts = parseArgs();
  if (opts.selfTest) return runSelfTest();
  if (!opts.image) {
    console.error('Usage: vision-gate.mjs --image PATH --golden PATH [--label NAME]');
    process.exit(2);
  }
  if (!existsSync(opts.image)) {
    console.error(`Image not found: ${opts.image}`);
    process.exit(2);
  }

  const golden = loadGolden(opts.golden);
  const started = Date.now();
  let response;
  try {
    response = await callGeminiVision(opts.image, GROUNDING_PROMPT);
  } catch (err) {
    console.log(JSON.stringify({
      label: opts.label,
      image: opts.image,
      pass: false,
      error: err.message,
      delivery: 'gemini-api-inline-base64',
      latencyMs: Date.now() - started,
    }, null, 2));
    process.exit(1);
  }

  const validation = validateGrounding(response, golden.strings);
  const result = {
    label: opts.label,
    image: basename(opts.image),
    model: MODEL,
    delivery: 'gemini-api-inline-base64',
    pass: validation.pass,
    quotedCount: validation.quotedCount,
    ungrounded: validation.ungrounded,
    failures: validation.failures,
    modelResponse: response,
    latencyMs: Date.now() - started,
  };
  console.log(JSON.stringify(result, null, 2));
  process.exit(validation.pass ? 0 : 1);
}

main().catch((e) => { console.error(e); process.exit(1); });
