import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { join, relative } from "node:path";

const root = process.cwd();
const excludedDirectories = new Set([
  ".git",
  ".sf",
  ".sfdx",
  "coverage",
  "node_modules"
]);
const textExtensions = new Set([
  ".apex",
  ".cls",
  ".css",
  ".html",
  ".js",
  ".json",
  ".md",
  ".xml",
  ".yaml",
  ".yml"
]);
const forbiddenContent = [
  {
    label: "a machine-local absolute path",
    pattern: /(?:\/Users\/|[A-Za-z]:\\Users\\)[^\s)`]*/g
  },
  {
    label: "a full Salesforce Org ID",
    pattern: /\b00D[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?\b/g
  },
  {
    label: "a private key",
    pattern: /-----BEGIN (?:RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----/g
  }
];

// Nested git worktrees hold other branches' checkouts, not this release.
const nestedWorktrees = join(root, ".claude", "worktrees");

function walk(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    if (entry.isDirectory() && excludedDirectories.has(entry.name)) {
      return [];
    }

    const path = join(directory, entry.name);
    if (path === nestedWorktrees) {
      return [];
    }
    if (entry.isDirectory()) {
      return walk(path);
    }
    if (!entry.isFile()) {
      return [];
    }
    return [path];
  });
}

const failures = [];
for (const path of walk(root)) {
  const repositoryPath = relative(root, path);
  if (/verbatim-conversation/i.test(repositoryPath)) {
    failures.push(
      `${repositoryPath}: private planning transcripts belong outside the repository`
    );
    continue;
  }
  if (/^code-analyzer-results-.*\.(?:json|log)$/.test(repositoryPath)) {
    failures.push(
      `${repositoryPath}: generated analyzer output belongs outside the repository`
    );
    continue;
  }

  const extension = path.slice(path.lastIndexOf("."));
  if (!textExtensions.has(extension) || statSync(path).size > 2_000_000) {
    continue;
  }

  const content = readFileSync(path, "utf8");
  for (const rule of forbiddenContent) {
    const matches = content.match(rule.pattern);
    if (matches) {
      failures.push(`${repositoryPath}: contains ${rule.label}: ${matches[0]}`);
    }
  }
  if (extension === ".md") {
    const recordIds = content.match(
      /\b(?:001|003|a0[A-Za-z0-9])[A-Za-z0-9]{12}(?:[A-Za-z0-9]{3})?\b/g
    );
    if (recordIds) {
      failures.push(
        `${repositoryPath}: contains an environment-specific Salesforce record ID: ${recordIds[0]}`
      );
    }
  }
}

const packageJson = JSON.parse(
  readFileSync(join(root, "package.json"), "utf8")
);
if (packageJson.name !== "prompt-context-builder") {
  failures.push("package.json: package name must be prompt-context-builder");
}
if (!packageJson.private) {
  failures.push(
    "package.json: must remain private to prevent accidental npm publication"
  );
}
if (!existsSync(join(root, "README.md"))) {
  failures.push("README.md: required for a public repository");
}
if (!existsSync(join(root, ".github", "SECURITY.md"))) {
  failures.push(
    ".github/SECURITY.md: required for private vulnerability reporting"
  );
}
if (!existsSync(join(root, ".github", "CODE_OF_CONDUCT.md"))) {
  failures.push(
    ".github/CODE_OF_CONDUCT.md: required for public community participation"
  );
}
if (!existsSync(join(root, ".github", "CODEOWNERS"))) {
  failures.push(".github/CODEOWNERS: required for public review routing");
}
if (!existsSync(join(root, "docs", "install", "try-demo-scratch-org.md"))) {
  failures.push(
    "docs/install/try-demo-scratch-org.md: required for public source evaluation"
  );
}
if (
  packageJson.scripts?.["demo:setup-source"] !==
  "sf apex run --file scripts/apex/seedVerificationTemplates.apex"
) {
  failures.push(
    "package.json: demo:setup-source must use the reviewed seed script"
  );
}
if (
  packageJson.scripts?.["demo:verify-source"] !==
  "sf apex run --file scripts/apex/verifyVerificationTemplates.apex"
) {
  failures.push(
    "package.json: demo:verify-source must use the reviewed verification script"
  );
}

const gitignoreLines = new Set(
  readFileSync(join(root, ".gitignore"), "utf8")
    .split(/\r?\n/)
    .map((line) => line.trim())
);
for (const ignoredPath of [
  ".sf/",
  ".sfdx/",
  "coverage/",
  "node_modules/",
  "*.log",
  "code-analyzer-results-*",
  ".env",
  ".env.*",
  "!.env.example",
  ".npmrc.local"
]) {
  if (!gitignoreLines.has(ignoredPath)) {
    failures.push(`.gitignore: must ignore ${ignoredPath}`);
  }
}

if (failures.length > 0) {
  console.error("Public-release checks failed:\n");
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log("Public-release hygiene checks passed.");
