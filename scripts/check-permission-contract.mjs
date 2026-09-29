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
