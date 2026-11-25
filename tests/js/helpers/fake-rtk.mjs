// Stand-in for `rtk rewrite <command>`; RTK_MODE selects the behaviour and every
// invocation is appended to RTK_LOG (argv after the script, cwd, marker env).
import { appendFileSync } from "node:fs";

const [sub, command] = process.argv.slice(2);
if (process.env.RTK_LOG) {
  appendFileSync(process.env.RTK_LOG, `${JSON.stringify({ argv: process.argv.slice(2), cwd: process.cwd(), mark: process.env.SPEC_ENV_MARK ?? null })}\n`);
}
const mode = process.env.RTK_MODE || "prefix";
if (mode === "fail") process.exit(1);
if (mode === "empty") process.stdout.write("  \n");
else if (mode === "same") process.stdout.write(`${command}\n`);
else process.stdout.write(`rtk ${command} [${sub}]\n`);
