import { execFile, spawn, type ChildProcessWithoutNullStreams } from "node:child_process"
import { existsSync, readFileSync } from "node:fs"
import { homedir } from "node:os"
import { basename, isAbsolute, join, resolve } from "node:path"
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { Type, type TSchema } from "typebox"

type JsonObject = Record<string, any>
type McpTool = {
  name: string
  description?: string
  inputSchema?: JsonObject
}

type ToolSpec = {
  command: string
  args?: string[]
  env?: Record<string, string>
}

type ToolManifest = {
  schema?: string
  scope?: string
  profile?: string
  tools?: Record<string, ToolSpec>
}

type PiStackConfig = {
  manifest?: string
  profile?: string
  servers?: Record<string, { enabled?: boolean }>
}

const START_TIMEOUT_MS = 15_000
const CALL_TIMEOUT_MS = 120_000
const GRAPH_PREFIX = "sb_graph_"
const CONTEXT_PREFIX = "sb_cm_"

function readJson(path: string): JsonObject {
  try {
    const value = JSON.parse(readFileSync(path, "utf8"))
    return value && typeof value === "object" && !Array.isArray(value) ? value : {}
  } catch {
    return {}
  }
}

function piAgentDir(): string {
  return process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent")
}

function stackConfigPath(): string {
  return join(piAgentDir(), "extensions", "silver-bullet-five-tool-stack", "config.json")
}

function loadStack(): { config: PiStackConfig; manifest: ToolManifest; manifestPath: string } {
  const config = readJson(stackConfigPath()) as PiStackConfig
  const defaultManifest = join(homedir(), ".silver-bullet", "five-tool-stack", "instances.json")
  const manifestPath = config.manifest || process.env.SB_GLOBAL_TOOLSTACK_MANIFEST || defaultManifest
  return { config, manifest: readJson(manifestPath) as ToolManifest, manifestPath }
}

function toolSpec(manifest: ToolManifest, name: string): ToolSpec | undefined {
  const spec = manifest.tools?.[name]
  if (!spec || typeof spec.command !== "string" || !spec.command) return undefined
  return {
    command: spec.command,
    args: Array.isArray(spec.args) ? spec.args.map(String) : [],
    env: spec.env && typeof spec.env === "object" ? { ...spec.env } : {},
  }
}

function jsonSchemaPropertyToTypebox(property: JsonObject): TSchema {
  const description = typeof property.description === "string"
    ? { description: property.description }
    : undefined
  const values = Array.isArray(property.enum) ? property.enum : []
  if (values.length > 0) {
    const literals = values.map((value: unknown) => Type.Literal(String(value)))
    return literals.length === 1 ? literals[0] : Type.Union(literals, description)
  }

  switch (property.type) {
    case "number":
    case "integer":
      return Type.Number(description)
    case "boolean":
      return Type.Boolean(description)
    case "array":
      return Type.Array(
        property.items && typeof property.items === "object"
          ? jsonSchemaPropertyToTypebox(property.items as JsonObject)
          : Type.Unknown(),
        description,
      )
    case "object": {
      const nested = property.properties
      if (nested && typeof nested === "object") {
        const required = new Set(Array.isArray(property.required) ? property.required : [])
        const fields: Record<string, TSchema> = {}
        for (const [key, value] of Object.entries(nested as Record<string, JsonObject>)) {
          const field = jsonSchemaPropertyToTypebox(value || {})
          fields[key] = required.has(key) ? field : Type.Optional(field)
        }
        return Type.Object(fields, description)
      }
      return Type.Record(Type.String(), Type.Unknown(), description)
    }
    default:
      return Type.String(description)
  }
}

function jsonSchemaToTypebox(schema?: JsonObject): TSchema {
  const properties = schema?.properties
  if (!properties || typeof properties !== "object") return Type.Object({})
  const required = new Set(Array.isArray(schema?.required) ? schema.required : [])
  const fields: Record<string, TSchema> = {}
  for (const [key, value] of Object.entries(properties as Record<string, JsonObject>)) {
    const field = jsonSchemaPropertyToTypebox(value || {})
    fields[key] = required.has(key) ? field : Type.Optional(field)
  }
  return Type.Object(fields)
}

function textContent(result: JsonObject): Array<{ type: "text"; text: string }> {
  if (Array.isArray(result.content)) {
    return result.content.map((block: JsonObject) => {
      if (block?.type === "text") return { type: "text", text: String(block.text ?? "") }
      return { type: "text", text: JSON.stringify(block) }
    })
  }
  if (result.structuredContent !== undefined) {
    return [{ type: "text", text: JSON.stringify(result.structuredContent) }]
  }
  return [{ type: "text", text: JSON.stringify(result) }]
}

function withTimeout<T>(promise: Promise<T>, timeoutMs: number, label: string): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined
  return new Promise<T>((resolvePromise, rejectPromise) => {
    timer = setTimeout(() => rejectPromise(new Error(`${label} timed out after ${timeoutMs}ms`)), timeoutMs)
    promise.then(resolvePromise, rejectPromise).finally(() => {
      if (timer) clearTimeout(timer)
    })
  })
}

class LineMcpClient {
  private child: ChildProcessWithoutNullStreams | undefined
  private buffer = Buffer.alloc(0)
  private nextId = 1
  private pending = new Map<number, { resolve: (value: JsonObject) => void; reject: (error: Error) => void }>()
  private connected = false
  private lastError = ""

  constructor(private readonly name: string, private readonly spec: ToolSpec) {}

  async start(): Promise<McpTool[]> {
    this.child = spawn(this.spec.command, this.spec.args || [], {
      stdio: ["pipe", "pipe", "pipe"],
      env: { ...process.env, ...(this.spec.env || {}) },
    })
    this.child.stdout.on("data", (chunk: Buffer) => this.consume(chunk))
    this.child.stderr.on("data", (chunk: Buffer) => {
      const text = chunk.toString("utf8").trim()
      if (text) this.lastError = text.slice(-500)
    })
    this.child.on("error", (error) => this.failPending(error))
    this.child.on("exit", (code, signal) => {
      this.connected = false
      this.failPending(new Error(`${this.name} MCP exited (${code ?? "signal"}${signal ? `/${signal}` : ""})`))
    })

    const initialized = await withTimeout(
      this.request("initialize", {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "silver-bullet-pi", version: "1.0.0" },
      }),
      START_TIMEOUT_MS,
      `${this.name} MCP initialize`,
    )
    if (initialized.error) throw new Error(`${this.name} MCP initialize failed`)
    this.notify("notifications/initialized", {})
    const listing = await withTimeout(this.request("tools/list", {}), START_TIMEOUT_MS, `${this.name} MCP tools/list`)
    this.connected = true
    return Array.isArray(listing.result?.tools) ? listing.result.tools : []
  }

  async call(name: string, args: Record<string, unknown>, signal?: AbortSignal): Promise<JsonObject> {
    if (!this.connected || !this.child) throw new Error(`${this.name} MCP is not connected`)
    if (signal?.aborted) throw new Error(`${this.name} MCP call aborted`)
    const request = this.request("tools/call", { name, arguments: args })
    const abort = new Promise<JsonObject>((_, reject) => {
      signal?.addEventListener("abort", () => reject(new Error(`${this.name} MCP call aborted`)), { once: true })
    })
    return withTimeout(Promise.race([request, abort]), CALL_TIMEOUT_MS, `${this.name} MCP ${name}`)
  }

  async close(): Promise<void> {
    this.connected = false
    this.failPending(new Error(`${this.name} MCP closed`))
    if (!this.child) return
    this.child.kill("SIGTERM")
    this.child = undefined
  }

  private request(method: string, params: JsonObject): Promise<JsonObject> {
    const id = this.nextId++
    return new Promise<JsonObject>((resolvePromise, rejectPromise) => {
      this.pending.set(id, { resolve: resolvePromise, reject: rejectPromise })
      try {
        this.child?.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", id, method, params })}\n`)
      } catch (error) {
        this.pending.delete(id)
        rejectPromise(error instanceof Error ? error : new Error(String(error)))
      }
    })
  }

  private notify(method: string, params: JsonObject): void {
    try {
      this.child?.stdin.write(`${JSON.stringify({ jsonrpc: "2.0", method, params })}\n`)
    } catch {
      // The associated request will report the process failure.
    }
  }

  private consume(chunk: Buffer): void {
    this.buffer = Buffer.concat([this.buffer, chunk])
    while (this.buffer.length > 0) {
      const headerEnd = this.buffer.indexOf(Buffer.from("\r\n\r\n"))
      const shortHeaderEnd = this.buffer.indexOf(Buffer.from("\n\n"))
      const framedEnd = headerEnd >= 0 ? headerEnd + 4 : shortHeaderEnd >= 0 ? shortHeaderEnd + 2 : -1
      if (framedEnd > 0) {
        const header = this.buffer.subarray(0, framedEnd).toString("utf8")
        const match = header.match(/content-length\s*:\s*(\d+)/i)
        if (match) {
          const length = Number(match[1])
          if (this.buffer.length < framedEnd + length) return
          const body = this.buffer.subarray(framedEnd, framedEnd + length).toString("utf8")
          this.buffer = this.buffer.subarray(framedEnd + length)
          this.handleMessage(body)
          continue
        }
      }

      const newline = this.buffer.indexOf(0x0a)
      if (newline < 0) return
      const line = this.buffer.subarray(0, newline).toString("utf8").trim()
      this.buffer = this.buffer.subarray(newline + 1)
      if (line) this.handleMessage(line)
    }
  }

  private handleMessage(raw: string): void {
    try {
      const message = JSON.parse(raw) as JsonObject
      if (typeof message.id !== "number") return
      const waiter = this.pending.get(message.id)
      if (!waiter) return
      this.pending.delete(message.id)
      if (message.error) waiter.reject(new Error(`${this.name} MCP error: ${JSON.stringify(message.error)}`))
      else waiter.resolve(message)
    } catch {
      // Ignore non-JSON diagnostic lines; MCP stderr is handled separately.
    }
  }

  private failPending(error: Error): void {
    for (const waiter of this.pending.values()) waiter.reject(error)
    this.pending.clear()
  }
}

function alreadyRtkRewritten(command: string, rtkCommand: string): boolean {
  const trimmed = command.trim()
  return trimmed.startsWith("rtk ")
    || trimmed === "rtk"
    || trimmed.startsWith(`${rtkCommand} `)
    || trimmed === rtkCommand
    || basename(trimmed.split(/\s+/)[0] || "") === "rtk"
}

async function rewriteWithRtk(command: string, spec: ToolSpec, cwd: string): Promise<string | undefined> {
  if (alreadyRtkRewritten(command, spec.command)) return undefined
  try {
    const result = await new Promise<{ stdout: string }>((resolvePromise, rejectPromise) => {
      execFile(
        spec.command,
        [...(spec.args || []), "rewrite", command],
        {
          cwd,
          env: { ...process.env, ...(spec.env || {}) },
          timeout: 15_000,
          maxBuffer: 1024 * 1024,
        },
        (error, stdout) => {
          if (error) rejectPromise(error)
          else resolvePromise({ stdout: String(stdout) })
        },
      )
    })
    const rewritten = result.stdout.trim()
    return rewritten && rewritten !== command ? rewritten : undefined
  } catch {
    return undefined
  }
}

function registerMcpTool(
  pi: ExtensionAPI,
  client: LineMcpClient,
  prefix: string,
  tool: McpTool,
): void {
  const exposedName = `${prefix}${tool.name}`
  try {
    pi.registerTool({
      name: exposedName,
      label: exposedName,
      description: tool.description || `Silver Bullet ${tool.name} MCP tool`,
      promptSnippet: tool.description || tool.name,
      parameters: jsonSchemaToTypebox(tool.inputSchema),
      async execute(_toolCallId, params, signal) {
        const result = await client.call(tool.name, params as Record<string, unknown>, signal)
        return { content: textContent(result), details: { source: "silver-bullet-five-tool-stack", server: prefix } }
      },
    })
  } catch (error) {
    console.error(`[silver-bullet-five-tool-stack] skipped ${exposedName}: ${String(error)}`)
  }
}

function registerAlias(
  pi: ExtensionAPI,
  client: LineMcpClient,
  name: string,
  description: string,
  target: McpTool,
): void {
  try {
    pi.registerTool({
      name,
      label: name,
      description,
      promptSnippet: description,
      parameters: jsonSchemaToTypebox(target.inputSchema),
      async execute(_toolCallId, params, signal) {
        const result = await client.call(target.name, params as Record<string, unknown>, signal)
        return { content: textContent(result), details: { source: "silver-bullet-five-tool-stack", server: name } }
      },
    })
  } catch (error) {
    console.error(`[silver-bullet-five-tool-stack] skipped ${name}: ${String(error)}`)
  }
}

export default async function silverBulletFiveToolStack(pi: ExtensionAPI): Promise<void> {
  const { config, manifest, manifestPath } = loadStack()
  const graphify = toolSpec(manifest, "graphify")
  const contextMode = toolSpec(manifest, "context_mode")
  const rtk = toolSpec(manifest, "rtk")

  if (!existsSync(manifestPath)) {
    console.error(`[silver-bullet-five-tool-stack] global manifest missing: ${manifestPath}`)
    return
  }

  if (rtk && config.servers?.rtk?.enabled !== false) {
    pi.on("tool_call", async (event, ctx) => {
      if (event.toolName !== "bash") return
      const command = typeof event.input.command === "string" ? event.input.command : ""
      if (!command) return
      const rewritten = await rewriteWithRtk(command, rtk, ctx.cwd)
      if (rewritten) event.input.command = rewritten
    })
  }

  const clients: LineMcpClient[] = []
  const startServer = async (name: string, spec: ToolSpec | undefined, prefix: string) => {
    if (!spec || config.servers?.[name]?.enabled === false) return
    const client = new LineMcpClient(name, spec)
    try {
      const tools = await client.start()
      clients.push(client)
      for (const tool of tools) registerMcpTool(pi, client, prefix, tool)
      const queryTool = tools.find((tool) => tool.name === "query_graph")
      if (name === "graphify" && queryTool) {
        registerAlias(pi, client, "sb_graphify_query", "Query the shared Silver Bullet Graphify knowledge graph.", queryTool)
      }
      const executeTool = tools.find((tool) => tool.name === "ctx_execute")
      if (name === "context_mode" && executeTool) {
        registerAlias(pi, client, "sb_context_execute", "Execute a bounded Context Mode analysis task.", executeTool)
      }
    } catch (error) {
      await client.close()
      console.error(`[silver-bullet-five-tool-stack] ${name} unavailable: ${String(error)}`)
    }
  }

  await Promise.all([
    startServer("graphify", graphify, GRAPH_PREFIX),
    startServer("context_mode", contextMode, CONTEXT_PREFIX),
  ])

  pi.on("session_shutdown", async () => {
    await Promise.all(clients.map((client) => client.close()))
  })
}
