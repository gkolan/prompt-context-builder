import { existsSync, readdirSync, readFileSync } from "node:fs";
import { basename, join } from "node:path";
import { stripCommentsAndStrings } from "./apex-source.mjs";

// Pins the production Apex security surface. Each exception below is reviewed in
// docs/architecture/security-and-data-access.md; changing a count requires the same review.
const classesDirectory = join(process.cwd(), "force-app/main/default/classes");
const approvedWithoutSharing = new Set(["PromptContextInputLogSelector"]);
const approvedSystemModeUses = new Map([
  // Digest-checked recovery of the caller's own user-scoped request key after Save Input authorization.
  ["PromptContextInputLogSelector", 1],
  // Immutable version and source-version inserts during an authorized publish, and the one
  // lifecycle-field writer that runs only after a user-mode edit proof on the same rows.
  ["PromptTemplateService", 3]
]);
// Entry classes that authorize by delegating every call to a class that calls PromptContextAccess.
const approvedDelegation = new Map([
  ["PromptContextInputApi", "PromptContextPreparationService"],
  // Scheduled classes start their worker by name; each worker authorizes itself.
  ["PromptTemplateHealthSchedulable", "PromptTemplateHealthQueueable"],
  ["PromptContextInputPurgeSchedulable", "PromptContextInputPurgeQueueable"]
]);
const failures = [];
const sources = new Map();

for (const fileName of readdirSync(classesDirectory).sort()) {
  if (!fileName.endsWith(".cls") || /Test\w*\.cls$/.test(fileName)) continue;
  sources.set(
    fileName.replace(/\.cls$/, ""),
    stripCommentsAndStrings(
      readFileSync(join(classesDirectory, fileName), "utf8"),
      true
    )
  );
}

const authorizes = (source) => /PromptContextAccess\.require\w+\(/.test(source);

for (const [className, source] of sources) {
  if (
    /\bwithout sharing\b/.test(source) &&
    !approvedWithoutSharing.has(className)
  ) {
    failures.push(
      `${className}: production Apex must not declare without sharing.`
    );
  }
  if (/\bTest\.isRunningTest\(\)/.test(source)) {
    failures.push(
      `${className}: production Apex must not branch on Test.isRunningTest().`
    );
  }

  const systemModeUses = (source.match(/\bSYSTEM_MODE\b/g) ?? []).length;
  const allowed = approvedSystemModeUses.get(className) ?? 0;
  if (systemModeUses !== allowed) {
    failures.push(
      `${className}: found ${systemModeUses} SYSTEM_MODE uses; the reviewed count is ${allowed}.`
    );
  }

  for (const match of source.matchAll(/\[\s*SELECT\b[\s\S]*?\]/gi)) {
    if (!/\bWITH\s+(USER|SYSTEM)_MODE\b/i.test(match[0])) {
      const line = source.slice(0, match.index).split("\n").length;
      failures.push(
        `${className}:${line}: inline SOQL must declare WITH USER_MODE.`
      );
    }
  }
  for (const match of source.matchAll(
    /Database\.(query|queryWithBinds|countQuery|countQueryWithBinds|getQueryLocator|getQueryLocatorWithBinds|insert|update|upsert|delete|undelete)\(([^;]*);/g
  )) {
    if (!/AccessLevel\.(USER|SYSTEM)_MODE/.test(match[2])) {
      failures.push(
        `${className}: Database.${match[1]} must pass an explicit AccessLevel.`
      );
    }
  }
  if (
    /(^|[;{])\s*(insert|update|upsert|delete|undelete|merge)\s+[\w(]/im.test(
      source
    )
  ) {
    failures.push(
      `${className}: use Database DML with an explicit AccessLevel, not DML statements.`
    );
  }

  const isEntry =
    /@AuraEnabled(\([^)]*\))?\s+(public|global)\s+static\b/.test(source) ||
    /@InvocableMethod\b/.test(source) ||
    /\bglobal\s+static\b/.test(source) ||
    /implements\s+[^{]*\b(Queueable|Schedulable|Database\.Batchable)\b/.test(
      source
    );
  if (isEntry && !authorizes(source)) {
    const delegate = approvedDelegation.get(className);
    if (!delegate || !authorizes(sources.get(delegate) ?? "")) {
      failures.push(
        `${className}: entry class must call PromptContextAccess.require*().`
      );
    }
  }
}

// Salesforce refuses to deploy any class a pending scheduled job depends on. A Schedulable that
// names no other package class (it starts its worker through Type.forName) leaves every other
// class deployable while the job stays scheduled.
for (const [className, source] of sources) {
  if (!/implements\s+[^{]*\bSchedulable\b/.test(source)) continue;
  const code = stripCommentsAndStrings(source);
  for (const otherClass of sources.keys()) {
    if (
      otherClass !== className &&
      new RegExp(`\\b${otherClass}\\b`).test(code)
    ) {
      failures.push(
        `${className}: a Schedulable must not reference ${otherClass}; start the worker with Type.forName so a pending job never blocks deployment.`
      );
    }
  }
}

// Apex rejects these as variable, parameter, or field names. The compiler only reports them in an
// org, so catch them before an org validation is needed.
const reservedIdentifiers = new Set(
  (
    "abstract activate and any array as asc autonomous begin bigdecimal blob break bulk by byte " +
    "case cast catch char class collect commit const continue currency date datetime decimal " +
    "default delete desc do double else end enum exception exit export extends false final " +
    "finally float for from global goto group having hint if implements import in inner insert " +
    "instanceof int integer interface into join like limit list long loop map merge new not " +
    "null nulls number object of on or outer override package parallel pragma private " +
    "protected public retrieve return rollback savepoint search select set short sort stat " +
    "static string super switch synchronized system testmethod then this throw time " +
    "transaction trigger true try undelete update upsert virtual void webservice when where while"
  ).split(" ")
);
const declarationPattern =
  /\b(?:[A-Z][A-Za-z0-9_]*(?:\.[A-Z][A-Za-z0-9_]*)*(?:<[^;(){}=]*>)?(?:\[\])?)\s+([a-z][A-Za-z0-9_]*)\s*(?=[=;,)])/g;
const integrationRoot = join(process.cwd(), "integration-tests");
const apexFiles = readdirSync(classesDirectory)
  .filter((name) => name.endsWith(".cls"))
  .map((name) => join(classesDirectory, name));
if (existsSync(integrationRoot)) {
  for (const entry of readdirSync(integrationRoot, { recursive: true })) {
    if (String(entry).endsWith(".cls")) {
      apexFiles.push(join(integrationRoot, String(entry)));
    }
  }
}
for (const filePath of apexFiles.sort()) {
  const fileName = basename(filePath);
  const source = stripCommentsAndStrings(readFileSync(filePath, "utf8"));
  for (const match of source.matchAll(declarationPattern)) {
    if (reservedIdentifiers.has(match[1].toLowerCase())) {
      const line = source.slice(0, match.index).split("\n").length;
      failures.push(
        `${fileName}:${line}: "${match[1]}" is reserved in Apex and cannot name a variable.`
      );
    }
  }
}

for (const className of [
  ...approvedWithoutSharing,
  ...approvedSystemModeUses.keys()
]) {
  if (!sources.has(className)) {
    failures.push(
      `${className}: approved exception names a class that no longer exists.`
    );
  }
}

if (failures.length) {
  console.error(failures.join("\n"));
  process.exit(1);
}
console.log(
  `Apex security surface passed for ${sources.size} production classes.`
);
