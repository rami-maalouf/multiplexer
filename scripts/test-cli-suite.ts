// the shell entry point holds the shared account lock around both live suites.
import { join } from "node:path";

for (const name of ["test-cli-features.ts", "test-cli.ts"]) {
  const child = Bun.spawn(["bun", join(import.meta.dir, name)], { stdin: "ignore", stdout: "inherit", stderr: "inherit" });
  const result = await child.exited;
  if (result !== 0) process.exit(result ?? 1);
}
