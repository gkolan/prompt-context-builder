import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const specificationFiles = [
  "specs/prompt-context-builder/12-match-records-by-field-value-and-bulk-processing.md",
  "specs/prompt-context-builder/13-record-files-and-bedrock-document-input.md",
  "specs/prompt-context-builder/14-prompt-input-log-and-delivery-options.md",
  "specs/prompt-context-builder/15-common-entry-build-record.md"
];
const migrationCommitments = [
  /backward-compatible read/i,
  /remain backward compatible/i,
  /default old published/i,
  /old template\/api behavior/i,
  /install\/upgrade/i,
  /package upgrade occurs/i,
  /upgrade verification/i
];

const failures = [];
for (const relativeFile of specificationFiles) {
  const source = readFileSync(join(root, relativeFile), "utf8");
  if (!/day-one rule/i.test(source)) {
    failures.push(`${relativeFile}: add an explicit day-one rule.`);
  }
  for (const pattern of migrationCommitments) {
    if (pattern.test(source)) {
      failures.push(
        `${relativeFile}: remove migration or backward-compatibility requirement ${pattern}.`
      );
    }
  }
}

if (failures.length > 0) {
  console.error("Day-one contract checks failed:\n" + failures.join("\n"));
  process.exit(1);
}

console.log("Day-one contract check passed.");
