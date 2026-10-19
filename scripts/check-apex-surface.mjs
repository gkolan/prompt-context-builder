import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";

// Pins the production Apex security surface. Each exception below is reviewed in
// docs/architecture/security-and-data-access.md; changing a count requires the same review.
const classesDirectory = join(process.cwd(), "force-app/main/default/classes");
const approvedWithoutSharing = new Set(["PromptContextInputLogSelector"]);
const approvedSystemModeUses = new Map([
  // Digest-checked recovery of the caller's own user-scoped request key after Save Input authorization.
  ["PromptContextInputLogSelector", 1],
  // Immutable version and source-version inserts during an authorized publish.
  ["PromptTemplateService", 2]
]);
// Entry classes that authorize by delegating every call to a class that calls PromptContextAccess.
const approvedDelegation = new Map([
  ["PromptContextInputApi", "PromptContextPreparationService"]
]);
const failures = [];
const sources = new Map();

for (const fileName of readdirSync(classesDirectory).sort()) {
  if (!fileName.endsWith(".cls") || /Test\w*\.cls$/.test(fileName)) continue;
  sources.set(
    fileName.replace(/\.cls$/, ""),
    readFileSync(join(classesDirectory, fileName), "utf8")
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .replace(/\/\/.*$/gm, "")
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
