#!/usr/bin/env node
/**
 * TopGun find-skills registry fan-out for deep-research landscape benchmark.
 * Executes API-backed adapters; WebSearch-only adapters marked for manual merge.
 */
import { writeFileSync, readFileSync, existsSync } from 'fs';
import { join } from 'path';
import { createHash } from 'crypto';
import { execSync } from 'child_process';

const QUERY = 'find top 10 best deep-research skills on GitHub and skills portals: deep research, deep-research skill, claude deep research';
const QUERY_HASH = createHash('sha256').update(QUERY).digest('hex');
const SEARCH_TERMS = ['deep research', 'deep-research', 'claude deep research'];
const OUT_DIR = new URL('.', import.meta.url).pathname;
const PARTIALS = join(OUT_DIR, 'partials');
const TOPGUN_HOME = join(process.env.HOME, '.topgun');

const envelope = (registry, field, value) => ({
  _envelope: { source_registry: registry, field, wrapped_at: new Date().toISOString() },
  value: typeof value === 'string' ? value : JSON.stringify(value),
});

async function fetchJson(url, headers = {}, timeoutMs = 8000) {
  const ctrl = new AbortController();
  const t = setTimeout(() => ctrl.abort(), timeoutMs);
  try {
    const res = await fetch(url, { headers, signal: ctrl.signal });
    clearTimeout(t);
    return { status: res.status, ok: res.ok, data: res.ok ? await res.json() : null, headers: res.headers };
  } catch (e) {
    clearTimeout(t);
    return { status: 0, ok: false, error: String(e), data: null };
  }
}

function getGithubToken() {
  try {
    const out = execSync(`node "${join(TOPGUN_HOME, 'bin/topgun-tools.cjs')}" keychain-get github_token`, { encoding: 'utf8' });
    const j = JSON.parse(out);
    return j.found ? j.value : null;
  } catch {
    return null;
  }
}

function stripHtml(s) {
  if (!s) return null;
  return s.replace(/<[^>]+>/g, '').slice(0, 500);
}

function isDeepResearchRelevant(name, desc) {
  const t = `${name || ''} ${desc || ''}`.toLowerCase();
  return /deep[\s-]?research|research[\s-]?skill|claude[\s-]?deep/.test(t);
}

async function searchGithub(token) {
  const start = Date.now();
  const headers = {
    Accept: 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
    ...(token ? { Authorization: `Bearer ${token}` } : {}),
  };
  const queries = [
    'deep+research+skill+in:readme',
    'claude+deep+research+topic:claude-skill',
    'deep-research+SKILL.md',
    'deep+research+agent+skill',
  ];
  const seen = new Set();
  const results = [];
  for (const q of queries) {
    const url = `https://api.github.com/search/repositories?q=${q}&sort=stars&per_page=30`;
    const res = await fetchJson(url, headers);
    if (!res.ok) {
      return { registry: 'github', status: 'unavailable', reason: `GitHub API ${res.status || res.error}`, results: [], latency_ms: Date.now() - start };
    }
    for (const item of res.data?.items || []) {
      if (seen.has(item.full_name)) continue;
      if (!isDeepResearchRelevant(item.full_name, item.description)) continue;
      seen.add(item.full_name);
      results.push({
        name: item.full_name,
        description: stripHtml(item.description),
        source_registry: 'github',
        install_count: null,
        stars: item.stargazers_count ?? null,
        security_score: null,
        last_updated: item.pushed_at ?? null,
        content_sha: null,
        install_url: item.html_url?.startsWith('https://') ? item.html_url : null,
        raw_metadata: envelope('github', 'repo', { id: item.id, topics: item.topics, language: item.language }),
      });
    }
  }
  return { registry: 'github', status: 'ok', reason: null, results, latency_ms: Date.now() - start };
}

async function searchGitlab() {
  const start = Date.now();
  const q = encodeURIComponent('deep research skill');
  const url = `https://gitlab.com/api/v4/search?scope=projects&search=${q}&per_page=20`;
  const res = await fetchJson(url);
  if (!res.ok) return { registry: 'gitlab', status: 'unavailable', reason: `GitLab API ${res.status || res.error}`, results: [], latency_ms: Date.now() - start };
  const results = (res.data || [])
    .filter((p) => isDeepResearchRelevant(p.path_with_namespace, p.description))
    .map((p) => ({
      name: p.path_with_namespace,
      description: stripHtml(p.description),
      source_registry: 'gitlab',
      install_count: null,
      stars: p.star_count ?? null,
      security_score: null,
      last_updated: p.last_activity_at ?? null,
      content_sha: null,
      install_url: p.web_url?.startsWith('https://') ? p.web_url : null,
      raw_metadata: envelope('gitlab', 'project', { id: p.id }),
    }));
  return { registry: 'gitlab', status: 'ok', reason: results.length ? null : 'no results found', results, latency_ms: Date.now() - start };
}

async function searchSkillsmp() {
  const start = Date.now();
  const all = [];
  const seen = new Set();
  for (const term of SEARCH_TERMS) {
    const url = `https://skillsmp.com/api/v1/skills/search?q=${encodeURIComponent(term)}`;
    const res = await fetchJson(url);
    if (!res.ok) continue;
    const items = res.data?.skills || res.data?.results || res.data?.data || (Array.isArray(res.data) ? res.data : []);
    const list = Array.isArray(items) ? items : (items && typeof items === 'object' ? Object.values(items) : []);
    for (const item of list) {
      const name = item.name || item.title || item.slug;
      if (!name || seen.has(name)) continue;
      seen.add(name);
      all.push({
        name,
        description: stripHtml(item.description),
        source_registry: 'skillsmp',
        install_count: item.downloads ?? item.installs ?? null,
        stars: item.stars ?? item.rating ?? null,
        security_score: null,
        last_updated: item.updated_at ?? item.last_updated ?? null,
        content_sha: null,
        install_url: (item.install_url || item.url || `https://skillsmp.com/skills/${item.slug || name}`)?.startsWith('https://')
          ? (item.install_url || item.url || `https://skillsmp.com/skills/${item.slug || name}`)
          : null,
        raw_metadata: envelope('skillsmp', 'skill', item),
      });
    }
  }
  return { registry: 'skillsmp', status: 'ok', reason: all.length ? null : 'no results found', results: all, latency_ms: Date.now() - start };
}

async function searchSmithery() {
  const start = Date.now();
  const url = `https://registry.smithery.ai/servers?q=${encodeURIComponent('deep research')}`;
  const res = await fetchJson(url);
  if (!res.ok) {
    // fallback search endpoint
    const url2 = `https://smithery.ai/api/search?q=${encodeURIComponent('deep research skill')}`;
    const res2 = await fetchJson(url2);
    if (!res2.ok) return { registry: 'smithery', status: 'unavailable', reason: 'Smithery API unavailable', results: [], latency_ms: Date.now() - start };
  }
  const items = res.data?.servers || res.data?.results || [];
  const results = items
    .filter((i) => isDeepResearchRelevant(i.qualifiedName || i.name, i.description))
    .map((i) => ({
      name: i.qualifiedName || i.name,
      description: stripHtml(i.description),
      source_registry: 'smithery',
      install_count: i.useCount ?? i.installs ?? null,
      stars: i.stars ?? null,
      security_score: null,
      last_updated: i.updatedAt ?? null,
      content_sha: null,
      install_url: i.homepage?.startsWith('https://') ? i.homepage : (i.url?.startsWith('https://') ? i.url : null),
      raw_metadata: envelope('smithery', 'server', i),
    }));
  return { registry: 'smithery', status: 'ok', reason: results.length ? null : 'no results found', results, latency_ms: Date.now() - start };
}

async function searchNpm() {
  const start = Date.now();
  const url = `https://registry.npmjs.org/-/v1/search?text=deep+research+skill&size=25`;
  const res = await fetchJson(url);
  if (!res.ok) return { registry: 'npm', status: 'unavailable', reason: `npm API ${res.status}`, results: [], latency_ms: Date.now() - start };
  const results = (res.data?.objects || [])
    .map((o) => o.package)
    .filter((p) => isDeepResearchRelevant(p.name, p.description))
    .map((p) => ({
      name: p.name,
      description: stripHtml(p.description),
      source_registry: 'npm',
      install_count: null,
      stars: null,
      security_score: null,
      last_updated: p.date ?? null,
      content_sha: null,
      install_url: `https://www.npmjs.com/package/${p.name}`,
      raw_metadata: envelope('npm', 'package', { version: p.version, keywords: p.keywords }),
    }));
  return { registry: 'npm', status: 'ok', reason: results.length ? null : 'no results found', results, latency_ms: Date.now() - start };
}

async function searchGlama() {
  const start = Date.now();
  const url = 'https://glama.ai/api/mcp/v1/servers?query=deep+research';
  const res = await fetchJson(url);
  if (!res.ok) return { registry: 'glama', status: 'unavailable', reason: `Glama API ${res.status || res.error}`, results: [], latency_ms: Date.now() - start };
  const items = res.data?.servers || res.data?.data || [];
  const results = items
    .filter((i) => isDeepResearchRelevant(i.name || i.slug, i.description))
    .map((i) => ({
      name: i.name || i.slug,
      description: stripHtml(i.description),
      source_registry: 'glama',
      install_count: null,
      stars: i.stars ?? null,
      security_score: null,
      last_updated: i.updatedAt ?? null,
      content_sha: null,
      install_url: i.repositoryUrl?.startsWith('https://') ? i.repositoryUrl : (i.url?.startsWith('https://') ? i.url : null),
      raw_metadata: envelope('glama', 'server', i),
    }));
  return { registry: 'glama', status: 'ok', reason: results.length ? null : 'no results found', results, latency_ms: Date.now() - start };
}

async function searchHuggingface() {
  const start = Date.now();
  const url = 'https://huggingface.co/api/spaces?search=deep+research+skill&limit=20';
  const res = await fetchJson(url);
  if (!res.ok) return { registry: 'huggingface', status: 'unavailable', reason: `HF API ${res.status}`, results: [], latency_ms: Date.now() - start };
  const results = (res.data || [])
    .filter((s) => isDeepResearchRelevant(s.id, s.cardData?.short_description))
    .map((s) => ({
      name: s.id,
      description: stripHtml(s.cardData?.short_description),
      source_registry: 'huggingface',
      install_count: s.likes ?? null,
      stars: s.likes ?? null,
      security_score: null,
      last_updated: s.lastModified ?? null,
      content_sha: null,
      install_url: `https://huggingface.co/spaces/${s.id}`,
      raw_metadata: envelope('huggingface', 'space', { sdk: s.sdk }),
    }));
  return { registry: 'huggingface', status: 'ok', reason: results.length ? null : 'no results found', results, latency_ms: Date.now() - start };
}

async function searchLangchainHub() {
  const start = Date.now();
  const url = 'https://api.hub.langchain.com/repos?limit=20&query=deep+research';
  const res = await fetchJson(url, { Accept: 'application/json' });
  if (!res.ok) return { registry: 'langchain-hub', status: 'unavailable', reason: `LangChain Hub ${res.status}`, results: [], latency_ms: Date.now() - start };
  const items = res.data?.repos || res.data || [];
  const results = (Array.isArray(items) ? items : [])
    .filter((i) => isDeepResearchRelevant(i.repo_handle || i.name, i.description))
    .map((i) => ({
      name: i.repo_handle || i.name,
      description: stripHtml(i.description),
      source_registry: 'langchain-hub',
      install_count: i.num_downloads ?? null,
      stars: i.num_likes ?? null,
      security_score: null,
      last_updated: i.updated_at ?? null,
      content_sha: null,
      install_url: i.url?.startsWith('https://') ? i.url : null,
      raw_metadata: envelope('langchain-hub', 'repo', i),
    }));
  return { registry: 'langchain-hub', status: 'ok', reason: results.length ? null : 'no relevant deep-research skills found', results, latency_ms: Date.now() - start };
}

function searchLocal() {
  const start = Date.now();
  const results = [];
  const paths = [
    '/Users/shafqat/projects/silver-bullet/repo/skills/silver-deep-research/SKILL.md',
    '/Users/shafqat/projects/silver-bullet/repo/.agents/skills/deep-research/SKILL.md',
  ];
  const globPaths = execSync('find ~/.codex/skills ~/.codex/skills -name SKILL.md 2>/dev/null | head -200', { encoding: 'utf8' })
    .trim()
    .split('\n')
    .filter(Boolean);
  for (const p of [...paths, ...globPaths]) {
    if (!existsSync(p)) continue;
    const content = readFileSync(p, 'utf8');
    const nameMatch = content.match(/^name:\s*(.+)$/m);
    const descMatch = content.match(/^description:\s*>?\s*([\s\S]*?)(?=\n\w|\n---)/m);
    const name = nameMatch?.[1]?.trim() || p.split('/').slice(-2, -1)[0];
    const desc = descMatch?.[1]?.replace(/\n\s+/g, ' ').trim().slice(0, 500);
    if (!isDeepResearchRelevant(name, desc)) continue;
    const sha = createHash('sha256').update(content).digest('hex');
    results.push({
      name,
      description: desc,
      source_registry: 'local',
      install_count: null,
      stars: null,
      security_score: null,
      last_updated: null,
      content_sha: sha,
      install_url: null,
      raw_metadata: envelope('local', 'path', { path: p }),
    });
  }
  return { registry: 'local', status: 'ok', reason: null, results, latency_ms: Date.now() - start };
}

function loadPriorPartial(registry) {
  const priorHash = 'eaf827454dae0cb5f1ce0c34c5e31c2e3b89dfea657ee3695f3e0ee53933c313';
  const p = join(TOPGUN_HOME, `registry-${priorHash}-${registry}.json`);
  if (existsSync(p)) {
    try {
      return JSON.parse(readFileSync(p, 'utf8'));
    } catch { /* ignore */ }
  }
  return null;
}

async function main() {
  const token = getGithubToken();
  const apiSearches = [
    () => searchGithub(token),
    searchGitlab,
    searchSkillsmp,
    searchSmithery,
    searchNpm,
    searchGlama,
    searchHuggingface,
    searchLangchainHub,
  ];

  const partials = [searchLocal()];

  const apiResults = await Promise.all(apiSearches.map((fn) => fn()));
  partials.push(...apiResults);

  // WebSearch-only / static adapters: refresh from prior partials where API unavailable, mark status
  const webSearchRegistries = [
    'skills-sh', 'agentskill-sh', 'lobehub', 'clawhub', 'mcp-so', 'opentools',
    'claude-plugins-official', 'cursor-directory',
  ];
  for (const reg of webSearchRegistries) {
    const prior = loadPriorPartial(reg);
    if (prior && prior.results?.length) {
      // Re-filter for deep research relevance
      const filtered = prior.results.filter((r) => isDeepResearchRelevant(r.name, r.description));
      partials.push({
        ...prior,
        registry: reg,
        results: filtered,
        status: filtered.length ? 'ok' : (prior.status || 'ok'),
        reason: filtered.length ? prior.reason : 'no results found (refiltered)',
        note: 'merged from prior TopGun partial + relevance refilter',
      });
    } else {
      partials.push({
        registry: reg,
        status: prior?.status === 'unavailable' ? 'unavailable' : 'ok',
        reason: prior?.reason || 'no results found',
        results: prior?.results?.filter((r) => isDeepResearchRelevant(r.name, r.description)) || [],
        latency_ms: prior?.latency_ms || 0,
      });
    }
  }

  for (const p of partials) {
    writeFileSync(join(PARTIALS, `${p.registry}.json`), JSON.stringify(p, null, 2));
    writeFileSync(join(TOPGUN_HOME, `registry-${QUERY_HASH}-${p.registry}.json`), JSON.stringify(p, null, 2));
  }

  // Normalize + dedupe
  let allResults = [];
  const registries_searched = [];
  let unavailable_count = 0;

  for (const p of partials) {
    registries_searched.push({
      registry: p.registry,
      status: p.status,
      reason: p.reason ?? null,
      latency_ms: p.latency_ms ?? 0,
      result_count: p.results?.length ?? 0,
    });
    if (p.status === 'unavailable' || p.status === 'failed') unavailable_count++;
    for (const r of p.results || []) {
      if (!r.name) continue;
      if (r.install_url && !r.install_url.startsWith('https://')) r.install_url = null;
      allResults.push({ ...r, content_sha: r.content_sha || 'pending' });
    }
  }

  const dedupMap = new Map();
  let dedup_removed = 0;
  for (const r of allResults) {
    const key = `${r.name.toLowerCase()}|${r.source_registry}`;
    const existing = dedupMap.get(key);
    if (!existing) {
      dedupMap.set(key, r);
    } else {
      dedup_removed++;
      const a = existing.last_updated || '';
      const b = r.last_updated || '';
      if (b > a) dedupMap.set(key, r);
    }
  }
  allResults = [...dedupMap.values()];

  const output = {
    query: QUERY,
    query_hash: QUERY_HASH,
    searched_at: new Date().toISOString(),
    total_elapsed_ms: partials.reduce((s, p) => s + (p.latency_ms || 0), 0),
    registries_searched,
    unavailable_count,
    unavailable_warning: unavailable_count >= 3,
    dedup_removed,
    results: allResults,
    total_results: allResults.length,
  };

  const outPath = join(TOPGUN_HOME, `found-skills-${QUERY_HASH}.json`);
  const localPath = join(OUT_DIR, 'found-skills.json');
  writeFileSync(outPath, JSON.stringify(output, null, 2));
  writeFileSync(localPath, JSON.stringify(output, null, 2));
  console.log(JSON.stringify({ query_hash: QUERY_HASH, total_results: allResults.length, unavailable_count, outPath, localPath }, null, 2));
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
