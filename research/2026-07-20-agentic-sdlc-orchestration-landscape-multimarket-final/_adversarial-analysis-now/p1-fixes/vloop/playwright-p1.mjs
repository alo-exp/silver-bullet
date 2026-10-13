#!/usr/bin/env node
import playwrightPkg from "/Users/shafqat/.cursor/worktrees/repo/3ht3/research/2026-07-20-agentic-sdlc-orchestration-landscape-multimarket-final/_adversarial-audit/node_modules/playwright/index.js";
const { chromium } = playwrightPkg;
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const htmlPath = path.resolve(__dirname, "../../../landscape-report.html");
const url = "file://" + htmlPath;

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
const consoleErrors = [];
const pageErrors = [];
page.on("console", (m) => {
  if (m.type() === "error") consoleErrors.push(m.text());
});
page.on("pageerror", (e) => pageErrors.push(String(e)));
await page.goto(url, { waitUntil: "domcontentloaded", timeout: 60000 });
await page.waitForTimeout(3000);

const ev = await page.evaluate(() => {
  const body = document.body?.innerText || "";
  const rdEl = document.getElementById("report-data");
  let rd = null;
  try {
    rd = rdEl ? JSON.parse(rdEl.textContent || "{}") : null;
  } catch (e) {
    rd = { parseError: String(e) };
  }
  const apo = rd?.chart_data?.markets?.apo || {};
  const plugins = rd?.chart_data?.markets?.["sdlc-plugins"] || {};
  const saas = rd?.chart_data?.markets?.["agentic-sdlc-saas"] || {};
  const s1 = body.slice(0, 4000);
  return {
    title: document.title,
    h1: document.querySelector("h1")?.innerText?.trim() || "",
    renderFailed: /render failed|parseInline|TypeError/i.test(body),
    canvases: document.querySelectorAll("canvas").length,
    hasReportData: !!rdEl,
    s1HasDevinCore: /Devin/.test(s1) && /agentic-sdlc-saas core/i.test(s1),
    s1AdjacentOnlyHost: /Devin[\s\S]{0,200}adjacent-only host/i.test(s1) && !/not an adjacent-only host/i.test(s1),
    apoPlotted: apo.plotted_slugs || [],
    apoMq: (apo.mq_data || []).map((p) => p.slug + "/" + p.q),
    pluginsPlotted: plugins.plotted_slugs || [],
    saasPlotted: saas.plotted_slugs || [],
    bodyHasAgentHubCRM: /AgentHub[\s\S]{0,120}CRM|client-automation CRM/i.test(body),
    bodyHasATeamExcluded: /ATeam|A\.Team/.test(body) && /professional_services|FDE|excluded/i.test(body),
    bodySnippetDevin: (body.match(/[^\n]{0,80}Devin[^\n]{0,160}/) || [""])[0],
  };
});

await page.screenshot({ path: path.join(__dirname, "fileurl-1280.png"), fullPage: false });
await page.setViewportSize({ width: 375, height: 812 });
await page.waitForTimeout(500);
await page.screenshot({ path: path.join(__dirname, "fileurl-375.png"), fullPage: false });

const result = {
  url,
  consoleErrors: consoleErrors.slice(0, 20),
  pageErrors: pageErrors.slice(0, 10),
  ...ev,
  fileRenderPass:
    !ev.renderFailed &&
    ev.canvases > 0 &&
    ev.hasReportData &&
    pageErrors.length === 0 &&
    !ev.apoPlotted.includes("agenthub") &&
    !ev.apoPlotted.includes("ateam") &&
    ev.saasPlotted.includes("devin") &&
    ev.pluginsPlotted.includes("cc10x"),
};
fs.writeFileSync(path.join(__dirname, "playwright-fileurl.json"), JSON.stringify(result, null, 2) + "\n");
console.log(JSON.stringify(result, null, 2));
await browser.close();
process.exit(result.fileRenderPass ? 0 : 1);
