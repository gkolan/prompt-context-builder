import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

// Runs Salesforce Code Analyzer's Recommended rules on force-app and fails on any critical (1) or
// high (2) finding. Moderate and lower findings are advisory debt; review them by category and in
// changed files, as the change-safety playbook describes. Results go to a temporary folder so no
// analyzer output can be committed. Requires the Salesforce CLI and the code-analyzer plugin.
const outputDirectory = mkdtempSync(join(tmpdir(), "pcb-code-analyzer-"));
const outputFile = join(outputDirectory, "results.json");
try {
  try {
    execFileSync(
      "sf",
      [
        "code-analyzer",
        "run",
        "--workspace",
        "force-app",
        "--rule-selector",
        "Recommended",
        "--output-file",
        outputFile
      ],
      // Progress output is noise in a passing gate; it is printed only when the run fails.
      { stdio: ["ignore", "ignore", "pipe"], maxBuffer: 64 * 1024 * 1024 }
    );
  } catch (error) {
    console.error(String(error.stderr ?? "").slice(-4000));
    console.error(
      `Code Analyzer did not complete (${error.code ?? error.status}). Install the Salesforce CLI and run "sf plugins install code-analyzer".`
    );
    process.exit(1);
  }
  const violations = JSON.parse(readFileSync(outputFile, "utf8")).violations;
  const serious = violations.filter((violation) => violation.severity <= 2);
  for (const violation of serious) {
    const location =
      violation.locations[violation.primaryLocationIndex ?? 0] ?? {};
    console.error(
      `${violation.rule} (severity ${violation.severity}) ${location.file}:${location.startLine}: ${violation.message}`
    );
  }
  if (serious.length) {
    console.error(
      `Code Analyzer found ${serious.length} critical or high finding(s).`
    );
    process.exit(1);
  }
  console.log(
    `Code Analyzer passed: no critical or high findings (${violations.length} advisory).`
  );
} finally {
  rmSync(outputDirectory, { recursive: true, force: true });
}
