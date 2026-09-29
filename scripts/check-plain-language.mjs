import fs from "node:fs";
import path from "node:path";

const workspace = process.cwd();
const visibleSourceFiles = [
  "force-app/main/default/lwc/promptTemplateBuilder/promptTemplateBuilder.html",
  "force-app/main/default/lwc/promptTemplateBuilder/promptTemplateBuilder.js",
  "force-app/main/default/lwc/promptGenerator/promptGenerator.html",
  "force-app/main/default/customLabels/CustomLabels.labels-meta.xml",
  "force-app/main/default/classes/PromptContextInputApi.cls",
  "force-app/main/default/classes/PromptContextInputLogService.cls",
  "force-app/main/default/classes/PromptContextSchema.cls",
  "force-app/main/default/classes/PromptContextService.cls",
  "force-app/main/default/classes/PromptContextSourceStrategies.cls",
  "force-app/main/default/classes/PromptContextValidator.cls",
  "force-app/main/default/classes/PromptTemplateGovernanceService.cls",
  "force-app/main/default/classes/PromptTemplateLanguage.cls",
  "force-app/main/default/classes/PromptTemplateService.cls"
];
const editableMetadataRoots = ["force-app/main/default"];
const customerDocumentationRoots = [
  "docs/build-templates",
  "docs/diagnostics",
  "docs/faqs",
  "docs/flow-guides",
  "docs/install",
  "docs/lightning-record-page",
  "docs/production-operations",
  "docs/screenshots",
  "docs/start-here",
  "docs/step-by-step-guide"
];
const unclearPhrases = [
  "active source",
  "access manifest",
  "context query source",
  "context source",
  "data access manifest",
  "developer key",
  "immutable history",
  "null placement",
  "query filter",
  "query capacity",
  "query scope",
  "raw soql",
  "related correlation field",
  "related-source",
  "requested rows",
  "root field",
  "root value",
  "root record",
  "runtime access",
  "runtime users",
  "schema or access",
  "schema health",
  "snapshot",
  "source reference name",
  "source rules",
  "source setup",
  "supported operator",
  "template cap",
  "template body fingerprint",
  "tie-breaker"
];
const unclearMetadataTerms = [
  "aggregate",
  "api name",
  "bind-variable",
  "context source",
  "correlation",
  "developer key",
  "fingerprint",
  "filters json",
  "immutable",
  "json",
  "query",
  "result mode",
  "root field",
  "schema",
  "snapshot",
  "sort json",
  "source mode"
];
const unclearDocumentationPhrases = [
  "access manifest",
  "atomic",
  "bounded",
  "context source",
  "correlation id",
  "developer key",
  "fingerprint",
  "immutable",
  "principal",
  "query scope",
  "query source",
  "root object",
  "root record",
  "runtime access",
  "runtime users",
  "schema health"
];
const unclearCommentPhrases = [
  "access manifest",
  "atomic result",
  "bounded",
  "immutable",
  "principal",
  "root object",
  "root record",
  "runtime choices",
  "runtime user",
  "scalar aggregate",
  "schema allowlist",
  "schema health",
  "schema-health",
  "snapshot"
];
const prohibitedProductWriting = [
  ["CUSTOM_SINK", /\bcustom_sink\b/i],
  ["sink", /\bsinks?\b/i],
  ["envelope", /\benvelopes?\b/i],
  ["disposition", /\bdispositions?\b/i],
  ["canonical", /\bcanonical\b/i],
  ["adapter", /\badapters?\b/i],
  ["idempotency", /\bidempotenc\w*\b/i],
  ["payload", /\bpayloads?\b/i],
  ["correlation", /\bcorrelation\b/i],
  ["bounded", /\bbounded\b/i],
  ["atomic", /\batomic\w*\b/i],
  ["canary", /\bcanary\b/i],
  ["keyset", /\bkeyset\b/i],
  ["fail closed", /\bfails? closed\b/i],
  ["loudly", /\bloudly\b/i],
  ["AI", /\bai\b/i],
  ["LLM", /\bllms?\b/i],
  ["language model", /\blanguage models?\b/i],
  ["model call", /\bmodel calls?\b/i],
  ["model response", /\bmodel responses?\b/i],
  ["model invocation", /\bmodel invocations?\b/i]
];
const metadataTextPattern =
  /<(description|errorMessage|inlineHelpText|label|pluralLabel)\b[^>]*>\s*([\s\S]*?)\s*<\/\1>/g;

function filesBelow(relativeRoot, suffixes = [".xml"]) {
  const absoluteRoot = path.join(workspace, relativeRoot);
  const files = [];
  for (const entry of fs.readdirSync(absoluteRoot, { withFileTypes: true })) {
    const relativePath = path.join(relativeRoot, entry.name);
    if (entry.isDirectory()) {
      files.push(...filesBelow(relativePath, suffixes));
    } else if (suffixes.some((suffix) => entry.name.endsWith(suffix))) {
      files.push(relativePath);
    }
  }
  return files;
}

const failures = [];

for (const relativeFile of visibleSourceFiles) {
  const source = fs.readFileSync(path.join(workspace, relativeFile), "utf8");
  for (const phrase of unclearPhrases) {
    if (source.toLowerCase().includes(phrase)) {
      failures.push(`${relativeFile}: replace customer-facing "${phrase}"`);
    }
  }
  if (/[\u2013\u2014]/u.test(source)) {
    failures.push(
      `${relativeFile}: replace en or em dashes in customer-facing text`
    );
  }
}

for (const root of editableMetadataRoots) {
  for (const relativeFile of filesBelow(root)) {
    const source = fs.readFileSync(path.join(workspace, relativeFile), "utf8");
    const visibleText = [...source.matchAll(metadataTextPattern)]
      .map((match) => match[2].replace(/\s+/g, " "))
      .join(" ")
      .toLowerCase();
    for (const term of unclearMetadataTerms) {
      if (visibleText.includes(term)) {
        failures.push(`${relativeFile}: replace customer-facing "${term}"`);
      }
    }
  }
}

const customerDocumentationFiles = [
  "README.md",
  "docs/README.md",
  ...customerDocumentationRoots.flatMap((root) => filesBelow(root, [".md"]))
];
for (const relativeFile of customerDocumentationFiles) {
  const source = fs
    .readFileSync(path.join(workspace, relativeFile), "utf8")
    .toLowerCase();
  for (const phrase of unclearDocumentationPhrases) {
    if (source.includes(phrase)) {
      failures.push(`${relativeFile}: replace reader-facing "${phrase}"`);
    }
  }
}

const productWritingFiles = [
  ...filesBelow("docs", [".md"]),
  ...filesBelow("specs/prompt-context-builder", [".md"])
];
for (const relativeFile of productWritingFiles) {
  const source = fs.readFileSync(path.join(workspace, relativeFile), "utf8");
  for (const [term, pattern] of prohibitedProductWriting) {
    if (pattern.test(source)) {
      failures.push(`${relativeFile}: replace product-writing term "${term}"`);
    }
  }
}

for (const relativeFile of filesBelow("force-app/main/default", [
  ".cls",
  ".js"
])) {
  const source = fs.readFileSync(path.join(workspace, relativeFile), "utf8");
  const comments = [
    ...(source.match(/\/\*\*[\s\S]*?\*\//g) ?? []),
    ...(source.match(/^\s*\/\/.*$/gm) ?? [])
  ].join(" ");
  const normalizedComments = comments.toLowerCase();
  for (const phrase of unclearCommentPhrases) {
    if (normalizedComments.includes(phrase)) {
      failures.push(`${relativeFile}: replace source-comment "${phrase}"`);
    }
  }
  if (/[\u2013\u2014]/u.test(comments)) {
    failures.push(
      `${relativeFile}: replace en or em dashes in source comments`
    );
  }
}

if (failures.length > 0) {
  console.error("Plain-language checks failed:\n" + failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log("Customer-facing Salesforce language checks passed.");
}
