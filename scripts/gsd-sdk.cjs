#!/usr/bin/env node
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

function fail(message, code = 1) {
  process.stderr.write(`gsd-sdk: ${message}\n`);
  process.exit(code);
}

function toBool(value) {
  if (typeof value === 'boolean') return value;
  if (value === null || value === undefined) return false;
  if (typeof value === 'number') return value !== 0;
  const text = String(value).trim();
  if (text === '') return false;
  try {
    return toBool(JSON.parse(text));
  } catch {
    return text === 'true' || text === '1' || text.toLowerCase() === 'yes';
  }
}

function parseMaybeJson(text) {
  const trimmed = String(text ?? '').trim();
  if (!trimmed) return '';
  try {
    return JSON.parse(trimmed);
  } catch {
    return trimmed;
  }
}

function pickField(obj, fieldPath) {
  const parts = String(fieldPath || '').split('.');
  let current = obj;
  for (const part of parts) {
    if (current === null || current === undefined) return undefined;
    const bracketMatch = part.match(/^(.+?)\[(-?\d+)]$/);
    if (bracketMatch) {
      const key = bracketMatch[1];
      const index = parseInt(bracketMatch[2], 10);
      current = current[key];
      if (!Array.isArray(current)) return undefined;
      current = index < 0 ? current[current.length + index] : current[index];
    } else {
      current = current[part];
    }
  }
  return current;
}

function stripGlobalFlags(argv) {
  const out = [];
  let cwd = process.cwd();
  let ws = null;
  let raw = false;
  let pick = null;
  let defaultValue;

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--cwd' || arg === '--ws' || arg === '--pick' || arg === '--default') {
      const value = argv[i + 1];
      if (value === undefined || value.startsWith('--')) {
        fail(`missing value for ${arg}`);
      }
      if (arg === '--cwd') cwd = value;
      if (arg === '--ws') ws = value;
      if (arg === '--pick') pick = value;
      if (arg === '--default') defaultValue = value;
      i += 1;
      continue;
    }
    if (arg.startsWith('--cwd=')) {
      cwd = arg.slice('--cwd='.length);
      continue;
    }
    if (arg.startsWith('--ws=')) {
      ws = arg.slice('--ws='.length);
      continue;
    }
    if (arg.startsWith('--pick=')) {
      pick = arg.slice('--pick='.length);
      continue;
    }
    if (arg.startsWith('--default=')) {
      defaultValue = arg.slice('--default='.length);
      continue;
    }
    if (arg === '--raw') {
      raw = true;
      continue;
    }
    out.push(arg);
  }

  return { cwd, ws, raw, pick, defaultValue, argv: out };
}

function findToolsPath() {
  const candidates = [];
  if (process.env.GSD_TOOLS_PATH) candidates.push(process.env.GSD_TOOLS_PATH);
  if (process.env.GSD_HOME) candidates.push(path.join(process.env.GSD_HOME, 'bin', 'gsd-tools.cjs'));

  const runtimeName = process.env.SILVER_BULLET_RUNTIME
    || process.env.SB_RUNTIME_NAME
    || ((process.env.CODEX_CI || process.env.CODEX_THREAD_ID || process.env.CODEX_INTERNAL_ORIGINATOR_OVERRIDE) ? 'codex' : 'claude');
  const runtimeHomeRoot = process.env.SB_RUNTIME_HOME_ROOT
    || path.join(os.homedir(), `.${runtimeName}`);

  const selfDir = path.dirname(fs.realpathSync(__filename));
  candidates.push(
    path.join(selfDir, 'gsd-tools.cjs'),
    path.join(selfDir, 'gsd-tools'),
    path.join(runtimeHomeRoot, 'get-shit-done', 'bin', 'gsd-tools.cjs'),
    path.join(runtimeHomeRoot, 'get-shit-done', 'bin', 'gsd-tools'),
    path.join(os.homedir(), '.kilo', 'get-shit-done', 'bin', 'gsd-tools.cjs'),
    path.join(os.homedir(), '.kilo', 'get-shit-done', 'bin', 'gsd-tools')
  );

  for (const candidate of candidates) {
    if (candidate && fs.existsSync(candidate) && fs.statSync(candidate).isFile()) {
      return candidate;
    }
  }

  const which = spawnSync('bash', ['-lc', 'command -v gsd-tools.cjs || command -v gsd-tools'], {
    encoding: 'utf8',
  });
  if (which.status === 0) {
    const resolved = String(which.stdout || '').trim();
    if (resolved && fs.existsSync(resolved)) {
      return resolved;
    }
  }

  fail('could not locate gsd-tools.cjs. Set GSD_TOOLS_PATH or install the GSD runtime.');
}

const toolsPath = findToolsPath();

function runTools(args, extraEnv = {}) {
  const result = spawnSync(process.execPath, [toolsPath, ...args], {
    encoding: 'utf8',
    env: { ...process.env, ...extraEnv },
  });
  return {
    status: result.status ?? 1,
    stdout: String(result.stdout ?? ''),
    stderr: String(result.stderr ?? ''),
    error: result.error || null,
  };
}

function forwardToTools(baseFlags, args) {
  const result = runTools([...baseFlags, ...args]);
  if (result.error) {
    fail(result.error.message || String(result.error));
  }
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  process.exit(result.status);
}

function extractConfigBool(baseFlags, key) {
  const result = runTools([...baseFlags, 'config-get', key]);
  if (result.status !== 0) return undefined;
  return toBool(parseMaybeJson(result.stdout));
}

function readText(filePath) {
  try {
    return fs.readFileSync(filePath, 'utf8');
  } catch {
    return '';
  }
}

function findContextFile(absPhaseDir) {
  try {
    const entries = fs.readdirSync(absPhaseDir)
      .filter(name => name === 'CONTEXT.md' || /-CONTEXT\.md$/.test(name))
      .sort();
    return entries.length ? path.join(absPhaseDir, entries[0]) : '';
  } catch {
    return '';
  }
}

function parseDecisionsWithCategories(contextMd) {
  if (!contextMd || typeof contextMd !== 'string') return [];
  const blockMatch = contextMd.match(/<decisions>([\s\S]*?)<\/decisions>/);
  if (!blockMatch) return [];

  const out = [];
  const seen = new Set();
  let currentCategory = '';
  for (const rawLine of blockMatch[1].split(/\r?\n/)) {
    const categoryMatch = rawLine.match(/^\s*###\s+(.+?)\s*$/);
    if (categoryMatch) {
      currentCategory = categoryMatch[1].trim();
      continue;
    }
    const decisionMatch = rawLine.match(/^\s*-\s*\*\*(D-[A-Za-z0-9_-]+):\*\*\s*(.+?)\s*$/);
    if (!decisionMatch) continue;
    const id = decisionMatch[1];
    if (seen.has(id)) continue;
    seen.add(id);
    out.push({
      id,
      text: decisionMatch[2],
      category: currentCategory,
    });
  }
  return out;
}

function collectPlanText(absPhaseDir) {
  try {
    const entries = fs.readdirSync(absPhaseDir).filter(name => /PLAN\.md$/.test(name));
    return entries.map(name => readText(path.join(absPhaseDir, name))).join('\n');
  } catch {
    return '';
  }
}

function coverageForDecision(decision, planText) {
  const escaped = decision.id.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  return new RegExp(`\\b${escaped}\\b`).test(planText);
}

function formatDecision(decision) {
  const category = decision.category ? ` [${decision.category}]` : '';
  return `- ${decision.id}${category}: ${decision.text}`;
}

function decisionCoveragePlan(ctx, phaseDirArg, contextPathArg, pick) {
  if (!phaseDirArg) {
    fail('Usage: gsd-sdk query check.decision-coverage-plan <phase-dir> [context-path]');
  }

  const baseFlags = ['--cwd', ctx.cwd, ...(ctx.ws ? ['--ws', ctx.ws] : [])];
  const cwd = ctx.cwd;
  const absPhaseDir = path.isAbsolute(phaseDirArg) ? phaseDirArg : path.join(cwd, phaseDirArg);
  const providedContext = contextPathArg ? (path.isAbsolute(contextPathArg) ? contextPathArg : path.join(cwd, contextPathArg)) : '';
  const contextPath = providedContext && fs.existsSync(providedContext) ? providedContext : findContextFile(absPhaseDir);
  const gateEnabled = extractConfigBool(baseFlags, 'workflow.context_coverage_gate') !== false;

  let skippedReason = '';
  if (!gateEnabled) {
    skippedReason = 'gate disabled';
  } else if (!contextPath) {
    skippedReason = 'no CONTEXT.md';
  }

  let decisions = [];
  if (!skippedReason) {
    const contextMd = readText(contextPath);
    decisions = parseDecisionsWithCategories(contextMd);
    if (decisions.length === 0) skippedReason = 'no decisions';
  }

  let result;
  if (skippedReason) {
    result = {
      passed: true,
      skipped: true,
      total: 0,
      covered: 0,
      uncovered: [],
      message: `✓ Decision coverage: skipped — ${skippedReason}`,
    };
  } else {
    const planText = collectPlanText(absPhaseDir);
    const uncovered = decisions.filter(decision => !coverageForDecision(decision, planText));
    const covered = decisions.length - uncovered.length;
    if (uncovered.length === 0) {
      result = {
        passed: true,
        skipped: false,
        total: decisions.length,
        covered,
        uncovered: [],
        message: `✓ Decision coverage: ${covered}/${decisions.length} CONTEXT.md decisions covered by plans`,
      };
    } else {
      result = {
        passed: false,
        skipped: false,
        total: decisions.length,
        covered,
        uncovered,
        message: [
          `⚠ Decision coverage: ${covered}/${decisions.length} CONTEXT.md decisions covered by plans`,
          '',
          'Uncovered decisions:',
          ...uncovered.map(formatDecision),
        ].join('\n'),
      };
    }
  }

  emitJson({ data: result }, pick);
}

function decisionCoverageVerify(ctx, phaseDirArg, contextPathArg, pick) {
  if (!phaseDirArg) {
    fail('Usage: gsd-sdk query check.decision-coverage-verify <phase-dir> [context-path]');
  }

  const baseFlags = ['--cwd', ctx.cwd, ...(ctx.ws ? ['--ws', ctx.ws] : [])];
  const cwd = ctx.cwd;
  const absPhaseDir = path.isAbsolute(phaseDirArg) ? phaseDirArg : path.join(cwd, phaseDirArg);
  const providedContext = contextPathArg ? (path.isAbsolute(contextPathArg) ? contextPathArg : path.join(cwd, contextPathArg)) : '';
  const contextPath = providedContext && fs.existsSync(providedContext) ? providedContext : findContextFile(absPhaseDir);
  const gateEnabled = extractConfigBool(baseFlags, 'workflow.context_coverage_gate') !== false;

  let skippedReason = '';
  if (!gateEnabled) {
    skippedReason = 'gate disabled';
  } else if (!contextPath) {
    skippedReason = 'no CONTEXT.md';
  }

  let decisions = [];
  if (!skippedReason) {
    const contextMd = readText(contextPath);
    decisions = parseDecisionsWithCategories(contextMd);
    if (decisions.length === 0) skippedReason = 'no decisions';
  }

  let result;
  if (skippedReason) {
    result = {
      skipped: true,
      blocking: false,
      total: 0,
      honored: 0,
      not_honored: [],
      message: `### Decision Coverage\n\nSkipped — ${skippedReason}.`,
    };
  } else {
    const planText = collectPlanText(absPhaseDir);
    const notHonored = decisions.filter(decision => !coverageForDecision(decision, planText));
    const honored = decisions.length - notHonored.length;
    result = {
      skipped: false,
      blocking: false,
      total: decisions.length,
      honored,
      not_honored: notHonored,
      message: [
        '### Decision Coverage',
        '',
        `${honored}/${decisions.length} CONTEXT.md decisions honored by plans.`,
        ...(notHonored.length
          ? ['', 'Not honored:', ...notHonored.map(formatDecision)]
          : []),
      ].join('\n'),
    };
  }

  emitJson(result, pick);
}

function emitJson(value, pick) {
  if (pick) {
    let picked = pickField(value, pick);
    if (picked === undefined && value && typeof value === 'object' && value.data) {
      picked = pickField(value.data, pick);
    }
    process.stdout.write(picked === undefined || picked === null ? '' : String(picked));
    return;
  }
  process.stdout.write(JSON.stringify(value));
}

function translateQueryTarget(target, tail) {
  const parts = String(target).split('.');
  if (parts[0] === 'frontmatter' && parts[1] === 'get') {
    const out = ['frontmatter', 'get'];
    const rest = [...tail];
    if (rest[0] && !rest[0].startsWith('--')) {
      out.push(rest.shift());
    }
    if (rest[0] && !rest[0].startsWith('--')) {
      out.push('--field', rest.shift());
    }
    return out.concat(rest);
  }
  if (parts[0] === 'frontmatter' && parts[1] === 'set') {
    const out = ['frontmatter', 'set'];
    const rest = [...tail];
    if (rest[0] && !rest[0].startsWith('--')) {
      out.push(rest.shift());
    }
    if (rest[0] && !rest[0].startsWith('--')) {
      out.push('--field', rest.shift());
    }
    if (rest[0] && !rest[0].startsWith('--')) {
      out.push('--value', rest.shift());
    }
    return out.concat(rest);
  }
  if (parts[0] === 'frontmatter' && parts[1] === 'merge') {
    return ['frontmatter', 'merge', ...tail];
  }
  if (parts[0] === 'frontmatter' && parts[1] === 'validate') {
    return ['frontmatter', 'validate', ...tail];
  }
  if (parts[0] === 'intel' && parts.length === 1 && tail.length === 0) {
    return ['intel', 'status'];
  }
  if (parts.length >= 2) {
    return [parts[0], parts.slice(1).join('.'), ...tail];
  }
  return [target, ...tail];
}

function main() {
  const { cwd, ws, raw, pick, defaultValue, argv } = stripGlobalFlags(process.argv.slice(2));
  const baseFlags = [
    '--cwd', cwd,
    ...(ws ? ['--ws', ws] : []),
  ];

  if (argv.length === 0) {
    fail('Usage: gsd-sdk query <command> [args]');
  }

  if (argv[0] !== 'query') {
    forwardToTools([...baseFlags, ...(raw ? ['--raw'] : []), ...(pick ? ['--pick', pick] : []), ...(defaultValue !== undefined ? ['--default', defaultValue] : [])], argv);
    return;
  }

  const queryArgs = argv.slice(1);
  if (queryArgs.length === 0) {
    fail('Usage: gsd-sdk query <command> [args]');
  }

  const target = queryArgs[0];
  const tail = queryArgs.slice(1);

  if (target === 'check' && tail[0] === 'auto-mode') {
    const autoChain = toBool(extractConfigBool(baseFlags, 'workflow._auto_chain_active'));
    const autoAdvance = toBool(extractConfigBool(baseFlags, 'workflow.auto_advance'));
    emitJson({
      active: autoChain || autoAdvance,
      auto_chain_active: autoChain,
      auto_advance: autoAdvance,
    }, pick);
    return;
  }

  if (target === 'check.auto-mode') {
    const autoChain = toBool(extractConfigBool(baseFlags, 'workflow._auto_chain_active'));
    const autoAdvance = toBool(extractConfigBool(baseFlags, 'workflow.auto_advance'));
    emitJson({
      active: autoChain || autoAdvance,
      auto_chain_active: autoChain,
      auto_advance: autoAdvance,
    }, pick);
    return;
  }

  if (target === 'check.decision-coverage-plan') {
    decisionCoveragePlan({ cwd, ws }, tail[0], tail[1], pick);
    return;
  }

  if (target === 'check.decision-coverage-verify') {
    decisionCoverageVerify({ cwd, ws }, tail[0], tail[1], pick);
    return;
  }

  const translated = translateQueryTarget(target, tail);
  forwardToTools([...baseFlags, ...(raw ? ['--raw'] : []), ...(pick ? ['--pick', pick] : []), ...(defaultValue !== undefined ? ['--default', defaultValue] : []), ...translated], []);
}

main();
