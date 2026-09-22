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

requireExact(
  customPermissions(readPermissionSet("Prompt_Context_Configure")),
  new Set([
    "Prompt_Context_Configure",
    "Prompt_Context_Diagnostics",
    "Prompt_Context_Generate"
  ]),
  "Prompt Context Configure"
);

requireExact(
  customPermissions(readPermissionSet("Prompt_Context_Generate")),
  new Set(["Prompt_Context_Generate"]),
  "Prompt Context Generate"
);

console.log("Permission Set custom-permission contract passed.");
