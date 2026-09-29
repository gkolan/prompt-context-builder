import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const classesDirectory = join(root, "force-app/main/default/classes");
const testFiles = readdirSync(classesDirectory)
  .filter(
    (fileName) =>
      fileName.endsWith("Test.cls") ||
      fileName === "PromptContextTestDataFactory.cls"
  )
  .sort();
const subscriberObjects = ["Account", "Contact", "User"];
const failures = [];

for (const fileName of testFiles) {
  const source = readFileSync(join(classesDirectory, fileName), "utf8");
  const subscriberVariables = new Set();
  const declarationPattern = new RegExp(
    `(?:List\\s*<\\s*)?(?:${subscriberObjects.join("|")})(?:\\s*>)?\\s+(\\w+)`,
    "g"
  );
  for (const match of source.matchAll(declarationPattern)) {
    subscriberVariables.add(match[1]);
  }

  const lines = source.split(/\r?\n/);
  lines.forEach((line, index) => {
    const normalized = line.trim();
    if (
      /PromptContextTestDataFactory\.createAccount\(true\)/.test(normalized) ||
      /PromptContextTestDataFactory\.createContacts\([^;]*,\s*true\)/.test(
        normalized
      )
    ) {
      failures.push(
        `${fileName}:${index + 1}: customer-object test data must stay in memory.`
      );
    }

    const directDml = normalized.match(
      /\b(?:insert|update|upsert|delete|undelete)\s+(?:new\s+)?(Account|Contact|User)\b/
    );
    if (directDml) {
      failures.push(
        `${fileName}:${index + 1}: ${directDml[1]} DML makes tests depend on subscriber validation rules and automation.`
      );
    }

    const variableDml = normalized.match(
      /\b(?:insert|update|upsert|delete|undelete)\s+(\w+)\s*;/
    );
    if (variableDml && subscriberVariables.has(variableDml[1])) {
      failures.push(
        `${fileName}:${index + 1}: DML on ${variableDml[1]} makes tests depend on subscriber automation.`
      );
    }

    const databaseDml = normalized.match(
      /\bDatabase\.(?:insert|update|upsert|delete|undelete)\(\s*(\w+)/
    );
    if (databaseDml && subscriberVariables.has(databaseDml[1])) {
      failures.push(
        `${fileName}:${index + 1}: Database DML on ${databaseDml[1]} makes tests depend on subscriber automation.`
      );
    }
  });
}

if (failures.length > 0) {
  console.error(
    "Apex test data isolation checks failed:\n" + failures.join("\n")
  );
  process.exit(1);
}

console.log(
  "Apex tests do not perform DML on subscriber-owned Account, Contact, or User records."
);
