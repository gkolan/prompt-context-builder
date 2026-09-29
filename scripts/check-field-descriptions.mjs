import { readdirSync, readFileSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = process.cwd();
const objectsRoot = join(root, "force-app/main/default/objects");
const failures = [];

for (const objectName of readdirSync(objectsRoot)) {
  const fieldsDirectory = join(objectsRoot, objectName, "fields");
  try {
    if (!statSync(fieldsDirectory).isDirectory()) {
      continue;
    }
  } catch {
    continue;
  }
  for (const fileName of readdirSync(fieldsDirectory)) {
    if (!fileName.endsWith(".field-meta.xml")) {
      continue;
    }
    const fieldPath = join(fieldsDirectory, fileName);
    if (!/<description(?:\s|>)/.test(readFileSync(fieldPath, "utf8"))) {
      failures.push(relative(root, fieldPath));
    }
  }
}

if (failures.length > 0) {
  console.error(
    "Salesforce field description check failed:\n" +
      failures.map((fileName) => `${fileName}: add a description.`).join("\n")
  );
  process.exit(1);
}

console.log("Every Salesforce custom field has a description.");
