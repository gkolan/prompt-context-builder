import fs from "node:fs";
import path from "node:path";
import { promptBuilderSourceFiles } from "./prompt-builder-files.mjs";

const workspace = process.cwd();
const roots = [
  path.join(workspace, "AGENTS.md"),
  path.join(workspace, "README.md"),
  path.join(workspace, "CHANGELOG.md"),
  path.join(workspace, "SUPPORT.md"),
  path.join(workspace, "docs"),
  path.join(workspace, "specs"),
  path.join(workspace, ".github", "CODE_OF_CONDUCT.md"),
  path.join(workspace, ".github", "CONTRIBUTING.md"),
  path.join(workspace, ".github", "SECURITY.md"),
  path.join(workspace, ".github", "pull_request_template.md")
];
const markdownFiles = [];
const requiredFiles = [
  "AGENTS.md",
  "README.md",
  "CHANGELOG.md",
  "SUPPORT.md",
  ".github/CODE_OF_CONDUCT.md",
  ".github/CODEOWNERS",
  ".github/CONTRIBUTING.md",
  ".github/SECURITY.md",
  ".github/pull_request_template.md",
  ".github/ISSUE_TEMPLATE/bug_report.yml",
  ".github/ISSUE_TEMPLATE/config.yml",
  ".github/ISSUE_TEMPLATE/feature_request.yml",
  "docs/README.md",
  "docs/diagnostics/README.md",
  "docs/flow-guides/README.md",
  "docs/install/try-demo-scratch-org.md",
  "docs/quality-gates/documentation-standard.md",
  "docs/contributing/change-safety-playbook.md",
  "docs/screenshots/README.md",
  "docs/screenshots/manifest.json"
];

function collect(currentPath) {
  const stat = fs.statSync(currentPath);
  if (stat.isFile()) {
    if (currentPath.endsWith(".md")) {
      markdownFiles.push(currentPath);
    }
    return;
  }
  for (const entry of fs.readdirSync(currentPath, { withFileTypes: true })) {
    collect(path.join(currentPath, entry.name));
  }
}

for (const root of roots) {
  collect(root);
}

const failures = [];
const linkPattern = /\[[^\]]*\]\(([^)]+)\)/g;
const prohibitedStyle = [
  { pattern: /\u2014/g, name: "em dash" },
  { pattern: /\u2013/g, name: "en dash" },
  {
    pattern: /\b(?:simply|just|easily|straightforward)\b/gi,
    name: "filler word"
  },
  { pattern: /\bas mentioned above\b/gi, name: "backward reference" },
  { pattern: /\bit['’]s worth noting\b/gi, name: "filler phrase" },
  {
    pattern: /\bnot (?:just|only|merely)\b[^.\n]*\bbut\b/gi,
    name: "not-X-but-Y construction"
  },
  { pattern: /\brather than\b/gi, name: "staged contrast" },
  {
    pattern:
      /\b(?:let['’]s dive in|let['’]s explore|here['’]s what you need to know|without further ado)\b/gi,
    name: "staged opener"
  },
  {
    pattern:
      /\b(?:the real question is|at its core|what really matters|the heart of the matter)\b/gi,
    name: "inflated framing"
  },
  {
    pattern: /\b(?:I hope this helps|let me know if|would you like me to)\b/gi,
    name: "chatbot residue"
  }
];

for (const requiredFile of requiredFiles) {
  if (!fs.existsSync(path.join(workspace, requiredFile))) {
    failures.push(`${requiredFile}: required documentation file is missing`);
  }
}

for (const markdownFile of markdownFiles) {
  const source = fs.readFileSync(markdownFile, "utf8");
  const relativeFile = path.relative(workspace, markdownFile);
  if (!source.startsWith("# ")) {
    failures.push(`${relativeFile}: must start with one level-one title`);
  }
  for (const { pattern, name } of prohibitedStyle) {
    pattern.lastIndex = 0;
    if (pattern.test(source)) {
      failures.push(`${relativeFile}: contains prohibited ${name}`);
    }
  }
  let insideCodeFence = false;
  source.split(/\r?\n/).forEach((line, index) => {
    const trimmedLine = line.trim();
    if (!trimmedLine.startsWith("```")) {
      return;
    }
    if (!insideCodeFence && trimmedLine === "```") {
      failures.push(
        `${relativeFile}:${index + 1}: opening code fences need a language`
      );
    }
    insideCodeFence = !insideCodeFence;
  });
  if (insideCodeFence) {
    failures.push(`${relativeFile}: contains an unclosed code fence`);
  }
  for (const match of source.matchAll(linkPattern)) {
    const rawTarget = match[1].trim().replace(/^<|>$/g, "");
    if (rawTarget.startsWith("#") || /^(?:https?:|mailto:)/i.test(rawTarget)) {
      continue;
    }
    const fileTarget = decodeURIComponent(rawTarget.split("#", 1)[0]);
    const resolved = path.resolve(path.dirname(markdownFile), fileTarget);
    if (!fs.existsSync(resolved)) {
      failures.push(`${relativeFile}: missing ${rawTarget}`);
    }
  }
}

for (const directory of fs.readdirSync(path.join(workspace, "docs"), {
  withFileTypes: true
})) {
  if (
    directory.isDirectory() &&
    !fs.existsSync(path.join(workspace, "docs", directory.name, "README.md"))
  ) {
    failures.push(`docs/${directory.name}: missing README.md`);
  }
}

// A junior administrator follows the walkthrough literally, so every field it names must be a real
// Prompt Builder label, including labels rendered by its child components.
const builderSource = promptBuilderSourceFiles(workspace)
  .map((relativeFile) =>
    fs.readFileSync(path.join(workspace, relativeFile), "utf8")
  )
  .join("\n");
const builderLabels = new Set(
  [
    ...builderSource.matchAll(
      /(?:label|source-label|selected-label)="([^"]+)"/g
    ),
    ...builderSource.matchAll(/\blabel:\s*"([^"]+)"/g)
  ].map((match) => match[1])
);
const walkthrough = fs.readFileSync(
  path.join(workspace, "docs/step-by-step-guide/README.md"),
  "utf8"
);
for (const table of walkthrough.matchAll(
  /^\| Field in Prompt Builder[^\n]*\n\|[-| ]+\|\n((?:\|[^\n]*\n)+)/gm
)) {
  for (const row of table[1].trim().split("\n")) {
    const fieldLabel = row.split("|")[1].trim();
    if (!builderLabels.has(fieldLabel)) {
      failures.push(
        `docs/step-by-step-guide/README.md: "${fieldLabel}" is not a Prompt Builder label`
      );
    }
  }
}

if (failures.length > 0) {
  console.error("Documentation checks failed:\n" + failures.join("\n"));
  process.exitCode = 1;
} else {
  console.log(`Documentation checks passed for ${markdownFiles.length} files.`);
}
