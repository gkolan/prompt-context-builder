import { execFileSync } from "node:child_process";
import {
  cpSync,
  mkdtempSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Runs Salesforce Graph Engine (path-based FLS and CRUD analysis) on a temporary copy of the
// production Apex. Graph Engine cannot parse `??` inside a for-each header, so the copy drops only
// that fallback; the analyzed data flow is otherwise identical. Fails when the engine errors or when
// any FLS or CRUD violation is reported. Requires Java and the Code Analyzer plugin; not in ci:gates.
const knownFalsePositives = new Set([
  // `List<Request> safeRequests = requests ?? new List<Request>();` is never null; Graph Engine
  // does not model the null-coalescing assignment.
  "ApexNullPointerException:PromptContextController.cls",
  "ApexNullPointerException:PromptContextInputApi.cls"
]);

function stripCoalesce(header) {
  let text = header;
  while (text.includes("??")) {
    const start = text.indexOf("??");
    let depth = 0;
    let end = start + 2;
    for (; end < text.length; end++) {
      if (text[end] === "(") depth++;
      if (text[end] === ")") {
        if (depth === 0) break;
        depth--;
      }
    }
    text = text.slice(0, start).trimEnd() + text.slice(end);
  }
  return text;
}

function rewriteForEachHeaders(source) {
  let output = "";
  let index = 0;
  const pattern = /\bfor\s*\(/g;
  let match;
  while ((match = pattern.exec(source)) !== null) {
    const start = match.index + match[0].length;
    let depth = 1;
    let end = start;
    while (depth > 0 && end < source.length) {
      if (source[end] === "(") depth++;
      if (source[end] === ")") depth--;
      end++;
    }
    let header = source.slice(start, end - 1);
    if (
      header.includes(":") &&
      header.includes("??") &&
      !header.includes(";")
    ) {
      header = stripCoalesce(header);
    }
    output += source.slice(index, start) + header + ")";
    index = end;
    pattern.lastIndex = end;
  }
  return output + source.slice(index);
}

const workspace = mkdtempSync(join(tmpdir(), "pcb-sfge-"));
try {
  cpSync("force-app", join(workspace, "force-app"), { recursive: true });
  cpSync("sfdx-project.json", join(workspace, "sfdx-project.json"));
  const classes = join(workspace, "force-app/main/default/classes");
  for (const name of readdirSync(classes).filter((file) =>
    file.endsWith(".cls")
  )) {
    const path = join(classes, name);
    writeFileSync(path, rewriteForEachHeaders(readFileSync(path, "utf8")));
  }
  const results = join(workspace, "sfge-results.json");
  execFileSync(
    "sf",
    [
      "code-analyzer",
      "run",
      "--rule-selector",
      "sfge",
      "--workspace",
      "force-app",
      "--target",
      "force-app/main/default/classes",
      "--output-file",
      results
    ],
    { cwd: workspace, stdio: "inherit" }
  );
  const failures = [];
  for (const violation of JSON.parse(readFileSync(results, "utf8"))
    .violations) {
    const file = (violation.locations?.[0]?.file ?? "").split("/").pop();
    if (file.includes("Test")) continue;
    if (knownFalsePositives.has(`${violation.rule}:${file}`)) continue;
    failures.push(
      `${violation.rule} ${file}:${violation.locations?.[0]?.startLine ?? ""} ${violation.message.slice(0, 200)}`
    );
  }
  if (failures.length) {
    console.error(failures.join("\n"));
    process.exit(1);
  }
  console.log("Graph Engine completed with no unreviewed production findings.");
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
