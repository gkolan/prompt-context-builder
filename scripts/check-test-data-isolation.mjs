import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join, relative, sep } from "node:path";
import {
  inlineSoqlPattern,
  lineOf,
  stripCommentsAndStrings
} from "./apex-source.mjs";

// Enforces the Apex test-data lessons in docs/contributing/change-safety-playbook.md for every
// @isTest class in force-app and integration-tests. scripts/lesson-guards.test.mjs proves each rule
// passes compliant code and fails a planted violation.
const root = process.cwd();
const classesDirectory = join(root, "force-app/main/default/classes");
const integrationRoot = join(root, "integration-tests");
// The restricted-user suite inserts one minimum-access User so security is tested for real.
const userDmlAllowedIn = join("integration-tests", "security") + sep;

const files = readdirSync(classesDirectory)
  .filter((name) => name.endsWith(".cls"))
  .map((name) => join(classesDirectory, name));
if (existsSync(integrationRoot)) {
  for (const entry of readdirSync(integrationRoot, { recursive: true })) {
    if (String(entry).endsWith(".cls")) {
      files.push(join(integrationRoot, String(entry)));
    }
  }
}

// A variable whose type is, or is a collection of, a subscriber object: "Account a",
// "Contact[] rows", "Map<String, List<User>> byName".
const declarationPattern =
  /\b(?:\w+\s*<[^;(){}=]*?\b(Account|Contact|User)\b[^;(){}=]*?>|(Account|Contact|User)\s*(?:\[\s*\])?)\s+(\w+)/g;
// A DML target that creates or queries subscriber records in place.
const inlineSubscriberPattern =
  /\bnew\s+(?:(?:List|Set)\s*<\s*)?(Account|Contact|User)\b|^\s*\[\s*SELECT\b[^\]]*?\bFROM\s+(Account|Contact|User)\b/i;
const failures = [];

for (const file of files.sort()) {
  const source = stripCommentsAndStrings(readFileSync(file, "utf8"));
  if (!/@isTest\b/i.test(source)) continue;
  const path = relative(root, file);
  const fail = (index, message) =>
    failures.push(`${path}:${lineOf(source, index)}: ${message}`);

  // Lesson: tests failed only in an established org because subscriber validation rules, flows,
  // and triggers ran on inserted standard records. Apex names are case-insensitive.
  const variables = new Map();
  for (const match of source.matchAll(declarationPattern)) {
    variables.set(match[3].toLowerCase(), match[1] ?? match[2]);
  }
  const dmlType = (target) => {
    const inline = target.match(inlineSubscriberPattern);
    if (inline) return inline[1] ?? inline[2];
    // The target itself ("byId.values()"), or a subscriber variable passed as a value rather
    // than read through ".Field" ("AssigneeId = runner.Id" is allowed).
    const names = [
      target.match(/^\s*(\w+)/)?.[1],
      ...Array.from(
        target.matchAll(/(?<![\w.])(\w+)\b(?!\s*[.(])/g),
        (match) => match[1]
      )
    ];
    for (const name of names) {
      const type = name && variables.get(name.toLowerCase());
      if (type) return type;
    }
    return null;
  };
  const checkDml = (index, target) => {
    const type = dmlType(target);
    if (!type) return;
    if (type === "User" && path.startsWith(userDmlAllowedIn)) return;
    fail(
      index,
      `${type} DML makes tests depend on subscriber validation rules and automation; keep it in memory or use a package-owned fixture.`
    );
  };
  for (const match of source.matchAll(
    /(?<![\w.])(?:insert|update|upsert|delete|undelete|merge)\s+(?:as\s+(?:user|system)\s+)?([^;]*);/gi
  )) {
    checkDml(match.index, match[1]);
  }
  for (const match of source.matchAll(
    /\bDatabase\s*\.\s*(?:insert|update|upsert|delete|undelete|merge)(?:Async|Immediate)?\s*\(([^;]*)/gi
  )) {
    checkDml(match.index, match[1]);
  }

  // Lesson: tests must not depend on records outside their own transaction.
  for (const match of source.matchAll(
    /@isTest\s*\([^)]*\bSeeAllData\s*=\s*true\b/gi
  )) {
    fail(
      match.index,
      "SeeAllData=true makes tests depend on org data the source does not own."
    );
  }

  for (const match of source.matchAll(inlineSoqlPattern)) {
    const query = match[0];
    // Lesson: profile display names differ by org, edition, and locale.
    if (
      /\bFROM\s+Profile\b[\s\S]*\bWHERE\b[\s\S]*(?<![\w.])Name\s*(?:=|!=|<>|\bIN\b|\bLIKE\b)/i.test(
        query
      ) ||
      /\bProfile\s*\.\s*Name\s*(?:=|!=|<>|\bIN\b|\bLIKE\b)/i.test(query)
    ) {
      fail(
        match.index,
        "select a Profile by license and permissions, never by display name."
      );
    }
    // Lesson: a published-template test resolved a draft fixture because LIMIT 1 picked any row.
    const outerQuery = query.replace(/\(\s*SELECT\b[^()]*\)/gi, "");
    if (
      /\bLIMIT\s+1\b/i.test(outerQuery) &&
      !/\b(?:WHERE|ORDER\s+BY)\b/i.test(outerQuery)
    ) {
      fail(
        match.index,
        "LIMIT 1 without WHERE or ORDER BY selects an arbitrary row once a sibling fixture exists."
      );
    }
  }
}

if (failures.length > 0) {
  console.error(
    "Apex test data isolation checks failed:\n" + failures.join("\n")
  );
  process.exit(1);
}

console.log(
  "Apex tests avoid subscriber Account, Contact, and User DML, SeeAllData, profile names, and unqualified LIMIT 1."
);
