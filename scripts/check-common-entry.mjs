import { readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const apiPath = join(
  root,
  "force-app/main/default/classes/PromptContextInputApi.cls"
);
const servicePath = join(
  root,
  "force-app/main/default/classes/PromptContextPreparationService.cls"
);
const controllerPath = join(
  root,
  "force-app/main/default/classes/PromptContextController.cls"
);

const apiSource = readFileSync(apiPath, "utf8");
const controllerSource = readFileSync(controllerPath, "utf8");
let serviceSource;
try {
  serviceSource = readFileSync(servicePath, "utf8");
} catch {
  throw new Error(
    "PromptContextPreparationService.cls must own the common prompt-preparation process."
  );
}

const failures = [];
for (const [channel, expectedCall] of [
  ["APEX", /prepareInternal\(requests, 'APEX'\)/],
  ["FLOW", /prepareInternal\(requests, 'FLOW'\)/]
]) {
  if (!expectedCall.test(apiSource)) {
    failures.push(
      `PromptContextInputApi.cls must use the common path for ${channel}.`
    );
  }
}
if (
  !/PromptContextPreparationService\.execute\(\s*serviceRequests,\s*channel\s*\)/.test(
    apiSource
  )
) {
  failures.push(
    "PromptContextInputApi.cls must call the common preparation service."
  );
}

if (!controllerSource.includes("PromptContextPreparationService.execute(")) {
  failures.push(
    "PromptContextController.generatePrompt must use the common preparation service."
  );
}
if (controllerSource.includes("PromptTemplateService.generatePublished(")) {
  failures.push(
    "PromptContextController.generatePrompt must not bypass the common preparation service."
  );
}

for (const forbiddenOwner of [
  "PromptContextSelector.",
  "PromptContextService.",
  "PromptTemplateService.",
  "PromptContextResourcePlanner."
]) {
  if (apiSource.includes(forbiddenOwner)) {
    failures.push(
      `PromptContextInputApi.cls must not prepare prompts through ${forbiddenOwner}`
    );
  }
}

for (const requiredOwner of [
  "PromptContextSelector.",
  "PromptContextBulkService.",
  "PromptTemplateService.",
  "PromptContextResourcePlanner."
]) {
  if (!serviceSource.includes(requiredOwner)) {
    failures.push(
      `PromptContextPreparationService.cls must own calls through ${requiredOwner}`
    );
  }
}

if (failures.length > 0) {
  console.error("Common-entry checks failed:\n" + failures.join("\n"));
  process.exit(1);
}

console.log("Common prompt-preparation entry check passed.");
