import fs from "node:fs";
import path from "node:path";

const workspace = process.cwd();
const permissionSetDirectory = path.join(
  workspace,
  "force-app/main/default/permissionsets"
);

function readPermissionSet(name) {
  return fs.readFileSync(
    path.join(permissionSetDirectory, `${name}.permissionset-meta.xml`),
    "utf8"
  );
}

function customPermissions(source) {
  return new Set(
    [
      ...source.matchAll(
        /<customPermissions>[\s\S]*?<name>([^<]+)<\/name>[\s\S]*?<\/customPermissions>/g
      )
    ].map((match) => match[1])
  );
}

function requireExact(actual, expected, permissionSetName) {
  const missing = [...expected].filter((name) => !actual.has(name));
  const unexpected = [...actual].filter((name) => !expected.has(name));
  if (missing.length || unexpected.length) {
    throw new Error(
      `${permissionSetName} custom-permission contract differs: missing [${missing.join(
        ", "
      )}], unexpected [${unexpected.join(", ")}]`
    );
  }
}

function fieldPermissions(source) {
  return new Set(
    [...source.matchAll(/<field\s*>\s*([^<]+)<\/field>/g)].map((match) =>
      match[1].trim()
    )
  );
}

function requireFields(source, expected, permissionSetName) {
  const actual = fieldPermissions(source);
  const missing = expected.filter((fieldName) => !actual.has(fieldName));
  if (missing.length) {
    throw new Error(
      `${permissionSetName} is missing field access for [${missing.join(", ")}]`
    );
  }
}

requireExact(
  customPermissions(readPermissionSet("Prompt_Context_Configure")),
  new Set([
    "Prompt_Context_Configure",
    "Prompt_Context_Diagnostics",
    "Prompt_Context_Generate",
    "Prompt_Context_Save_Input"
  ]),
  "Prompt Context Configure"
);

const inputLogFields = [
  "Prompt_Input_Log__c.Last_Reason_Code__c",
  "Prompt_Input_Log__c.Processing_Expires_At__c",
  "Prompt_Input_Log__c.Prompt_Text__c",
  "Prompt_Input_Log__c.Selected_Files_JSON__c"
];
requireFields(
  readPermissionSet("Prompt_Context_Save_Input"),
  inputLogFields,
  "Prompt Context Save Input"
);
requireFields(
  readPermissionSet("Prompt_Context_Process_Input"),
  inputLogFields,
  "Prompt Context Process Input"
);
requireFields(
  readPermissionSet("Prompt_Context_Configure"),
  inputLogFields,
  "Prompt Context Configure"
);

// Publish, deactivate, save, and the health job own these fields. An author who could edit them
// directly could republish an inactive template, serve an old version, or mark a template Healthy.
const lifecycleFields = [
  "Status__c",
  "Version__c",
  "Fingerprint__c",
  "Published_At__c",
  "Draft_Revision__c",
  "Last_Health_Checked_At__c",
  "Last_Health_Codes__c",
  "Last_Health_Status__c",
  "Last_Health_Version__c"
].map((fieldName) => `Prompt_Template__c.${fieldName}`);
for (const fileName of fs.readdirSync(permissionSetDirectory).sort()) {
  const source = fs.readFileSync(
    path.join(permissionSetDirectory, fileName),
    "utf8"
  );
  for (const block of source.match(
    /<fieldPermissions>[\s\S]*?<\/fieldPermissions>/g
  ) ?? []) {
    const fieldName = block.match(/<field\s*>\s*([^<]+)<\/field>/)?.[1].trim();
    if (
      lifecycleFields.includes(fieldName) &&
      /<editable>\s*true\s*<\/editable>/.test(block)
    ) {
      throw new Error(
        `${fileName} must not grant edit access to ${fieldName}; package services write it.`
      );
    }
  }
  for (const block of source.match(
    /<objectPermissions>[\s\S]*?<\/objectPermissions>/g
  ) ?? []) {
    if (
      /<object\s*>\s*Prompt_Template__c\s*<\/object>/.test(block) &&
      /<allowDelete>\s*true\s*<\/allowDelete>/.test(block)
    ) {
      throw new Error(
        `${fileName} must not grant Delete on Prompt_Template__c; deactivate keeps version history.`
      );
    }
  }
}

// Generation reads only the template header and its fixed published version, so people who only
// generate prompts must not be able to read unpublished draft text or draft data sets.
const generateSource = readPermissionSet("Prompt_Context_Generate");
const draftReads = [
  ...[...fieldPermissions(generateSource)].filter(
    (fieldName) =>
      fieldName === "Prompt_Template__c.Template_Body__c" ||
      fieldName.startsWith("Prompt_Context_Source__c.")
  ),
  ...(/<object\s*>\s*Prompt_Context_Source__c\s*<\/object>/.test(generateSource)
    ? ["Prompt_Context_Source__c object"]
    : [])
];
if (draftReads.length) {
  throw new Error(
    `Prompt Context Generate must not read draft settings: [${draftReads.join(", ")}]`
  );
}

requireExact(
  customPermissions(readPermissionSet("Prompt_Context_Generate")),
  new Set(["Prompt_Context_Generate"]),
  "Prompt Context Generate"
);

requireExact(
  customPermissions(readPermissionSet("Prompt_Context_Save_Input")),
  new Set(["Prompt_Context_Save_Input"]),
  "Prompt Context Save Input"
);

requireExact(
  customPermissions(readPermissionSet("Prompt_Context_Process_Input")),
  new Set(["Prompt_Context_Process_Input"]),
  "Prompt Context Process Input"
);

console.log("Permission Set custom-permission contract passed.");
