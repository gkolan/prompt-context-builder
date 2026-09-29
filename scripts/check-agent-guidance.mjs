import { existsSync, readFileSync } from "node:fs";
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

if (failures.length > 0) {
  console.error("Agent-guidance checks failed:\n" + failures.join("\n"));
  process.exit(1);
}

console.log(
  "Mandatory agent and contributor change-safety guidance is present and linked."
);
