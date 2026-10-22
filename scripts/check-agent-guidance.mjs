import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

const root = process.cwd();
const requirements = new Map([
  [
    "AGENTS.md",
    [
      "## Mandatory session guidance",
      "docs/contributing/change-safety-playbook.md",
      "Account`, `Contact`, or `User",
      "unqualified\n  `LIMIT 1`",
      "explicit user approval",
      "Scheduled Apex",
      "Never claim universal org compatibility",
      "docs/screenshots/README.md",
      "npm run check:screenshots"
    ]
  ],
  [
    "docs/contributing/change-safety-playbook.md",
    [
      "## Session-start checklist",
      "## Org-independent Apex test data",
      "### Deterministic record selection",
      "## Static analysis",
      "## Approved-org validation",
      "## Source tracking and conflicts",
      "## Scheduled Apex lifecycle",
      "## Deployment sequence",
      "## Evidence vocabulary",
      "## Screenshot evidence",
      "## Meaning of any-org compatibility",
      "## Handoff checklist"
    ]
  ],
  [
    "docs/quality-gates/README.md",
    [
      "change safety playbook",
      "Agent-guidance presence and navigation",
      "Isolation-gate boundary",
      "## Screenshot boundary"
    ]
  ],
  [
    "docs/contributing/README.md",
    [
      "change safety playbook",
      "check:test-data-isolation",
      "screenshot evidence procedure"
    ]
  ],
  [
    ".github/pull_request_template.md",
    [
      "select fixtures deterministically",
      "Source conflicts",
      "Scheduled Apex",
      "Screenshot evidence"
    ]
  ]
]);

const failures = [];
for (const [relativePath, requiredText] of requirements) {
  const absolutePath = join(root, relativePath);
  if (!existsSync(absolutePath)) {
    failures.push(`${relativePath}: required agent guidance is missing`);
    continue;
  }

  const source = readFileSync(absolutePath, "utf8");
  for (const text of requiredText) {
    if (!source.includes(text)) {
      failures.push(`${relativePath}: missing required guidance: ${text}`);
    }
  }
}

const packageJson = JSON.parse(
  readFileSync(join(root, "package.json"), "utf8")
);
if (
  packageJson.scripts?.["check:agent-guidance"] !==
  "node scripts/check-agent-guidance.mjs"
) {
  failures.push(
    "package.json: check:agent-guidance must run scripts/check-agent-guidance.mjs"
  );
}
if (!packageJson.scripts?.["ci:gates"]?.includes("check:agent-guidance")) {
  failures.push("package.json: ci:gates must include check:agent-guidance");
}
if (!packageJson.scripts?.["ci:gates"]?.includes("check:screenshots")) {
  failures.push("package.json: ci:gates must include check:screenshots");
}
if (!packageJson.scripts?.["ci:gates"]?.includes("test:lesson-guards")) {
  failures.push("package.json: ci:gates must include test:lesson-guards");
}

// Lessons: conflict protection is bypassed only with explicit user approval, a check-only
// validation is not a deployment, and scratch orgs are created or deleted only when authorized.
// No unattended automation may do any of these.
const workflowDirectory = join(root, ".github", "workflows");
const automation = [
  ["package.json", JSON.stringify(packageJson.scripts ?? {})],
  ...(existsSync(workflowDirectory) ? readdirSync(workflowDirectory) : []).map(
    (name) => [
      `.github/workflows/${name}`,
      readFileSync(join(workflowDirectory, name), "utf8")
    ]
  )
];
const forbiddenAutomation = [
  [/--ignore-conflicts\b/, "bypasses source-conflict protection"],
  [
    /\breset\s+tracking\b|force:source:tracking:reset/,
    "resets source tracking"
  ],
  [
    /\bproject\s+deploy\s+(?:start|quick)\b|force:source:(?:deploy|push)\b|force:mdapi:deploy\b/,
    "deploys instead of validating"
  ],
  [
    /\borg\s+(?:create|delete)\s+scratch\b|force:org:(?:create|delete)\b/,
    "creates or deletes a scratch org"
  ]
];
for (const [relativePath, source] of automation) {
  for (const [pattern, reason] of forbiddenAutomation) {
    if (pattern.test(source)) {
      failures.push(`${relativePath}: automation ${reason}`);
    }
  }
}
const quality = automation.find(
  ([relativePath]) => relativePath === ".github/workflows/quality.yml"
)?.[1];
if (
  !/sf project deploy validate\b[^\n]*--test-level RunLocalTests/.test(
    quality ?? ""
  )
) {
  failures.push(
    ".github/workflows/quality.yml: org validation must be a check-only deploy validate with RunLocalTests"
  );
}

if (failures.length > 0) {
  console.error("Agent-guidance checks failed:\n" + failures.join("\n"));
  process.exit(1);
}

console.log(
  "Mandatory change-safety guidance is present and linked, and automation cannot bypass it."
);
