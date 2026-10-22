import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  cpSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync
} from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { describe, test } from "node:test";
import { fileURLToPath } from "node:url";
import prettier from "prettier";

// Each lesson in docs/contributing/change-safety-playbook.md keeps a positive scenario (compliant
// source passes its guard) and negative scenarios (each planted regression fails it). Gates run as
// real processes against a temporary copy of only the inputs they read.
const repo = join(dirname(fileURLToPath(import.meta.url)), "..");
const classes = "force-app/main/default/classes";

function workspace(t, copies = [], files = {}) {
  const directory = mkdtempSync(join(tmpdir(), "pcb-lesson-"));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  for (const path of copies) {
    cpSync(join(repo, path), join(directory, path), { recursive: true });
  }
  for (const [path, content] of Object.entries(files)) {
    mkdirSync(dirname(join(directory, path)), { recursive: true });
    writeFileSync(join(directory, path), content);
  }
  return directory;
}

function edit(directory, path, change) {
  const file = join(directory, path);
  const before = readFileSync(file, "utf8");
  const after = change(before);
  assert.notEqual(after, before, `${path}: the planted change did not apply`);
  writeFileSync(file, after);
}

function gate(script, cwd, env = {}) {
  const result = spawnSync(process.execPath, [join(repo, "scripts", script)], {
    cwd,
    env: { ...process.env, ...env },
    encoding: "utf8"
  });
  return { status: result.status, output: result.stdout + result.stderr };
}

function passes(result) {
  assert.equal(result.status, 0, result.output);
}

function fails(result, message) {
  assert.notEqual(result.status, 0, `expected a failure:\n${result.output}`);
  assert.match(result.output, message);
}

const apexTest = (body, path = `${classes}/LessonTest.cls`) => ({
  [path]: `@isTest\nprivate class LessonTest {\n  @isTest\n  static void run() {\n${body}\n  }\n}\n`
});

const isolation = (t, files) =>
  gate(
    "check-test-data-isolation.mjs",
    workspace(t, [], { [`${classes}/.keep`]: "", ...files })
  );

describe("Lesson: tests fail only in an established org (subscriber DML)", () => {
  test("positive: in-memory standard records and package-owned DML pass", (t) => {
    passes(
      isolation(
        t,
        apexTest(`
    Account inMemory = new Account(Name = 'Parser input');
    Contact person = new Contact(LastName = 'Renderer', AccountId = inMemory.Id);
    User runner = new User(Id = UserInfo.getUserId());
    insert new PermissionSetAssignment(AssigneeId = runner.Id, PermissionSetId = null);
    Prompt_Template__c fixture = new Prompt_Template__c(Name = 'insert new Account();');
    insert fixture;
    // insert inMemory;
    /* delete person; */
    Database.insert(new List<Prompt_Template__c>{ fixture }, AccessLevel.USER_MODE);
    update new Prompt_Template__c(Id = fixture.Id, Name = inMemory.Name);`)
      )
    );
  });

  test("positive: the restricted-user suite may insert its one User", (t) => {
    passes(
      isolation(
        t,
        apexTest(
          "    insert new User(LastName = 'Restricted');",
          "integration-tests/security/main/default/classes/LessonTest.cls"
        )
      )
    );
  });

  const violations = {
    "insert new Account": "insert new Account(Name = 'x');",
    "variable DML": "Account a = new Account();\n    insert a;",
    "multiline DML": "Contact c = new Contact();\n    upsert\n      c;",
    "collection literal": "insert new List<Contact>{ new Contact() };",
    "array variable": "Account[] rows = new Account[]{};\n    update rows;",
    "nested generic map":
      "Map<String, List<Account>> byName = null;\n    delete byName.get('x');",
    "map values": "Map<Id, Contact> byId = null;\n    delete byId.values();",
    "inline query": "delete [SELECT Id FROM Account];",
    "user-mode DML": "Account a = new Account();\n    insert as user a;",
    "SObject list alias":
      "Account a = new Account();\n    insert new List<SObject>{ a };",
    merge:
      "Account a = new Account();\n    Account b = new Account();\n    merge a b;",
    "Database.update variable":
      "User u = new User();\n    Database.update(u, false);",
    "Database.insert new":
      "Database.insert(new Account(), AccessLevel.USER_MODE);",
    "case-insensitive name": "Account Acct = new Account();\n    insert acct;",
    "Database.undelete": "Contact c = new Contact();\n    Database.undelete(c);"
  };
  for (const [name, body] of Object.entries(violations)) {
    test(`negative: ${name} fails`, (t) => {
      fails(isolation(t, apexTest(`    ${body}`)), /DML makes tests depend/);
    });
  }

  test("negative: an @isTest helper not named *Test.cls is still scanned", (t) => {
    fails(
      isolation(t, {
        [`${classes}/LessonHarness.cls`]:
          "@isTest\npublic class LessonHarness {\n  public static void seed() { insert new Contact(); }\n}\n"
      }),
      /LessonHarness\.cls:3: Contact DML/
    );
  });

  test("negative: the security exemption covers User only", (t) => {
    fails(
      isolation(
        t,
        apexTest(
          "    insert new Account(Name = 'x');",
          "integration-tests/security/main/default/classes/LessonTest.cls"
        )
      ),
      /Account DML/
    );
  });

  test("negative: other integration suites may not insert a User", (t) => {
    fails(
      isolation(
        t,
        apexTest(
          "    insert new User(LastName = 'x');",
          "integration-tests/flow-runtime/main/default/classes/LessonTest.cls"
        )
      ),
      /User DML/
    );
  });
});

describe("Lesson: a published-template test resolved a draft fixture (LIMIT 1)", () => {
  test("positive: semantic, ordered, and bounded queries pass", (t) => {
    passes(
      isolation(
        t,
        apexTest(`
    Id a = [SELECT Id FROM Prompt_Template__c WHERE Developer_Key__c = :key LIMIT 1].Id;
    Id b = [SELECT Id FROM Prompt_Template_Version__c ORDER BY Version_Number__c DESC LIMIT 1].Id;
    Id c = [SELECT Id FROM Prompt_Template__c WHERE Id = :ids[0] LIMIT 1].Id;
    List<Prompt_Template__c> d = [SELECT Id FROM Prompt_Template__c LIMIT 10];
    Integer e = [SELECT COUNT() FROM Prompt_Template__c];`)
      )
    );
  });

  const violations = {
    "unqualified LIMIT 1":
      "[SELECT Id FROM Prompt_Template_Version__c LIMIT 1]",
    "lowercase multiline":
      "[\n      select Id\n      from Prompt_Template__c\n      limit 1\n    ]",
    "WHERE only in a subquery":
      "[SELECT Id, (SELECT Id FROM Versions__r WHERE Version_Number__c = 1) FROM Prompt_Template__c LIMIT 1]"
  };
  for (const [name, query] of Object.entries(violations)) {
    test(`negative: ${name} fails`, (t) => {
      fails(
        isolation(t, apexTest(`    Object row = ${query};`)),
        /LIMIT 1 without WHERE or ORDER BY/
      );
    });
  }
});

describe("Lesson: tests depend on org data (SeeAllData)", () => {
  test("positive: SeeAllData=false and a commented mention pass", (t) => {
    passes(
      isolation(t, {
        [`${classes}/LessonTest.cls`]:
          "// Never @isTest(SeeAllData=true).\n@isTest(SeeAllData=false)\nprivate class LessonTest {}\n"
      })
    );
  });

  for (const [name, annotation] of Object.entries({
    "class annotation": "@isTest(SeeAllData=true)",
    "method annotation, mixed case":
      "@IsTest(isParallel=false seeAllData = TRUE)"
  })) {
    test(`negative: ${name} fails`, (t) => {
      fails(
        isolation(t, {
          [`${classes}/LessonTest.cls`]: `@isTest\nprivate class LessonTest {\n  ${annotation}\n  static void run() {}\n}\n`
        }),
        /SeeAllData=true/
      );
    });
  }

  test("negative: integration suites are scanned too", (t) => {
    fails(
      isolation(t, {
        "integration-tests/flow-runtime/main/default/classes/LessonTest.cls":
          "@isTest(SeeAllData=true)\nprivate class LessonTest {}\n"
      }),
      /SeeAllData=true/
    );
  });
});

describe("Lesson: profile display names differ by org and locale", () => {
  test("positive: license-and-permission selection and reads pass", (t) => {
    passes(
      isolation(
        t,
        apexTest(`
    Profile p = [
      SELECT Id FROM Profile
      WHERE UserLicense.LicenseDefinitionKey = 'SFDC' AND PermissionsModifyAllData = FALSE
      ORDER BY Name, Id LIMIT 1
    ];
    String shown = [SELECT Profile.Name FROM User WHERE Id = :UserInfo.getUserId()].Profile.Name;
    Id ps = [SELECT Id FROM PermissionSet WHERE Name = 'Prompt_Context_Configure'].Id;`)
      )
    );
  });

  for (const [name, query] of Object.entries({
    "Profile by Name":
      "[SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]",
    "User by Profile.Name":
      "[SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1]",
    "Profile Name IN": "[SELECT Id FROM Profile WHERE Name IN ('A', 'B')]",
    "Profile Name LIKE": "[SELECT Id FROM Profile WHERE Name LIKE 'Stand%']"
  })) {
    test(`negative: ${name} fails`, (t) => {
      fails(
        isolation(t, apexTest(`    Object row = ${query};`)),
        /never by display name/
      );
    });
  }
});

const guidanceInputs = [
  "AGENTS.md",
  "docs/contributing",
  "docs/quality-gates/README.md",
  ".github",
  "package.json"
];

describe("Lesson: a validated deployment overwrote or bypassed org source", () => {
  test("positive: the current guidance and automation pass", (t) => {
    passes(gate("check-agent-guidance.mjs", workspace(t, guidanceInputs)));
  });

  const workflow = ".github/workflows/quality.yml";
  const plants = {
    "--ignore-conflicts in CI": [
      workflow,
      (s) => s.replace("--wait 60", "--wait 60 --ignore-conflicts"),
      /bypasses source-conflict protection/
    ],
    "tracking reset in an npm script": [
      "package.json",
      (s) =>
        s.replace(
          '"scripts": {',
          '"scripts": {\n    "sync": "sf project reset tracking",'
        ),
      /resets source tracking/
    ],
    "mutating deploy in CI": [
      workflow,
      (s) => s.replace("sf project deploy validate", "sf project deploy start"),
      /deploys instead of validating|check-only deploy validate/
    ],
    "validation without RunLocalTests": [
      workflow,
      (s) => s.replace("--test-level RunLocalTests", "--test-level NoTestRun"),
      /check-only deploy validate with RunLocalTests/
    ],
    "scratch org creation in CI": [
      workflow,
      (s) =>
        s.replace(
          "- run: npm ci",
          "- run: npm ci\n      - run: sf org create scratch --alias ci"
        ),
      /creates or deletes a scratch org/
    ],
    "approval rule removed from AGENTS.md": [
      "AGENTS.md",
      (s) => s.replace("explicit user approval", "approval"),
      /missing required guidance: explicit user approval/
    ],
    "conflict section removed from the playbook": [
      "docs/contributing/change-safety-playbook.md",
      (s) =>
        s.replace("## Source tracking and conflicts", "## Source tracking"),
      /Source tracking and conflicts/
    ],
    "lesson-guard tests dropped from ci:gates": [
      "package.json",
      (s) => s.replace(" && npm run test:lesson-guards", ""),
      /ci:gates must include test:lesson-guards/
    ]
  };
  for (const [name, [path, change, message]] of Object.entries(plants)) {
    test(`negative: ${name} fails`, (t) => {
      const directory = workspace(t, guidanceInputs);
      edit(directory, path, change);
      fails(gate("check-agent-guidance.mjs", directory), message);
    });
  }
});

describe("Lesson: a scheduled job blocked deploying a class it referenced", () => {
  const schedulable = `${classes}/PromptTemplateHealthSchedulable.cls`;

  test("positive: Schedulables that start workers by name pass", (t) => {
    passes(gate("check-apex-surface.mjs", workspace(t, [classes])));
  });

  test("negative: a Schedulable that constructs its worker fails", (t) => {
    const directory = workspace(t, [classes]);
    edit(directory, schedulable, (s) =>
      s.replace(
        "(Queueable) Type.forName('PromptTemplateHealthQueueable').newInstance()",
        "new PromptTemplateHealthQueueable()"
      )
    );
    fails(
      gate("check-apex-surface.mjs", directory),
      /must not reference PromptTemplateHealthQueueable/
    );
  });

  test("negative: a Schedulable that reads another class's constant fails", (t) => {
    const directory = workspace(t, [classes]);
    edit(directory, schedulable, (s) =>
      s.replace(
        "System.enqueueJob(",
        "System.debug(PromptContextSchedules.HEALTH_CRON);\n    System.enqueueJob("
      )
    );
    fails(
      gate("check-apex-surface.mjs", directory),
      /must not reference PromptContextSchedules/
    );
  });
});

describe("Lesson: static-analysis severity was treated as one category", () => {
  // A stand-in for the Salesforce CLI that writes the given results, so the gate's threshold is
  // tested without an analyzer install.
  function analyzer(t, { violations, exitCode = 0, writeResults = true }) {
    const bin = workspace(t, [], {
      sf: `#!/usr/bin/env node
const args = process.argv.slice(2);
const output = args[args.indexOf("--output-file") + 1];
if (${writeResults}) require("node:fs").writeFileSync(output, JSON.stringify({ violations: ${JSON.stringify(violations ?? [])} }));
process.exit(${exitCode});
`
    });
    chmodSync(join(bin, "sf"), 0o755);
    return gate("scan-code-analyzer.mjs", repo, {
      PATH: `${bin}:${process.env.PATH}`
    });
  }
  const finding = (severity) => ({
    rule: `Rule${severity}`,
    severity,
    message: "m",
    primaryLocationIndex: 0,
    locations: [{ file: "A.cls", startLine: 1 }]
  });

  test("positive: moderate and lower findings stay advisory", (t) => {
    const result = analyzer(t, { violations: [3, 4, 5].map(finding) });
    passes(result);
    assert.match(result.output, /\(3 advisory\)/);
  });

  for (const severity of [1, 2]) {
    test(`negative: a severity ${severity} finding fails`, (t) => {
      fails(
        analyzer(t, { violations: [finding(3), finding(severity)] }),
        new RegExp(`Rule${severity} \\(severity ${severity}\\)`)
      );
    });
  }

  test("negative: an analyzer that does not complete fails", (t) => {
    fails(analyzer(t, { exitCode: 2 }), /did not complete/);
  });

  test("negative: an analyzer that writes no results fails", (t) => {
    assert.notEqual(analyzer(t, { writeResults: false }).status, 0);
  });
});

const releaseInputs = [
  "package.json",
  "README.md",
  ".gitignore",
  ".github",
  "docs/install/try-demo-scratch-org.md"
];

describe("Lesson: generated analyzer output must stay out of the repository", () => {
  test("positive: a clean tree passes", (t) => {
    passes(gate("check-public-release.mjs", workspace(t, releaseInputs)));
  });

  test("negative: committed analyzer results fail", (t) => {
    const directory = workspace(t, releaseInputs, {
      "code-analyzer-results-2026.json": "{}"
    });
    fails(
      gate("check-public-release.mjs", directory),
      /generated analyzer output/
    );
  });

  test("negative: dropping the ignore rule fails", (t) => {
    const directory = workspace(t, releaseInputs);
    edit(directory, ".gitignore", (s) =>
      s.replace("code-analyzer-results-*\n", "")
    );
    fails(
      gate("check-public-release.mjs", directory),
      /must ignore code-analyzer-results-\*/
    );
  });
});

describe("Lesson: a green local command was described as deployed", () => {
  const screenshotInputs = ["README.md", "docs"];
  const manifest = "docs/screenshots/manifest.json";

  test("positive: screenshots scoped to deployed-org evidence pass", (t) => {
    passes(
      gate("check-screenshot-contract.mjs", workspace(t, screenshotInputs))
    );
  });

  test("negative: a manifest that widens the evidence scope fails", (t) => {
    const directory = workspace(t, screenshotInputs);
    edit(directory, manifest, (s) =>
      s.replace(
        '"browser-verified deployed-org state"',
        '"browser-verified workspace state"'
      )
    );
    fails(
      gate("check-screenshot-contract.mjs", directory),
      /scoped to deployed-org state/
    );
  });

  test("negative: a manifest that names a username instead of an alias fails", (t) => {
    const directory = workspace(t, screenshotInputs);
    edit(directory, manifest, (s) =>
      s.replace(
        '"approvedOrgAlias": "promptcontextbuilder"',
        '"approvedOrgAlias": "admin@example.com"'
      )
    );
    fails(gate("check-screenshot-contract.mjs", directory), /safe org alias/);
  });

  test("negative: dropping the evidence vocabulary fails", (t) => {
    const directory = workspace(t, guidanceInputs);
    edit(directory, "docs/contributing/change-safety-playbook.md", (s) =>
      s.replace("## Evidence vocabulary", "## Evidence")
    );
    fails(
      gate("check-agent-guidance.mjs", directory),
      /## Evidence vocabulary/
    );
  });
});

describe("Lesson: local gates failed on other branches in nested worktrees", () => {
  const nested = join(
    repo,
    ".claude/worktrees/other/force-app/main/default/lwc"
  );
  const own = join(repo, "force-app/main/default/lwc/promptGenerator");
  const jestConfig = createRequire(import.meta.url)(
    join(repo, "jest.config.js")
  );
  const ignoredBy = (patterns, path) =>
    patterns.some((pattern) =>
      new RegExp(pattern.replace("<rootDir>", repo)).test(path)
    );

  test("positive: this checkout's tests, modules, and files are checked", async () => {
    const testFile = join(own, "__tests__/promptGenerator.test.js");
    assert.equal(ignoredBy(jestConfig.testPathIgnorePatterns, testFile), false);
    assert.equal(ignoredBy(jestConfig.modulePathIgnorePatterns, own), false);
    const info = await prettier.getFileInfo(join(own, "promptGenerator.js"), {
      ignorePath: join(repo, ".prettierignore")
    });
    assert.equal(info.ignored, false);
  });

  test("negative: a nested worktree's tests, modules, and files are skipped", async () => {
    const testFile = join(nested, "x/__tests__/x.test.js");
    assert.equal(ignoredBy(jestConfig.testPathIgnorePatterns, testFile), true);
    assert.equal(ignoredBy(jestConfig.modulePathIgnorePatterns, nested), true);
    const info = await prettier.getFileInfo(join(nested, "x/x.js"), {
      ignorePath: join(repo, ".prettierignore")
    });
    assert.equal(info.ignored, true);
  });

  // Built at run time so this file never contains a machine-local path itself.
  const machinePath = ["", "Users", "someone", "private"].join("/");

  test("positive: the release gate still scans this checkout and .claude settings", (t) => {
    fails(
      gate(
        "check-public-release.mjs",
        workspace(t, releaseInputs, { ".claude/settings.json": machinePath })
      ),
      /\.claude\/settings\.json: contains a machine-local absolute path/
    );
  });

  test("negative: the release gate ignores another branch's worktree", (t) => {
    passes(
      gate(
        "check-public-release.mjs",
        workspace(t, releaseInputs, {
          ".claude/worktrees/other/notes.md": machinePath
        })
      )
    );
  });
});
