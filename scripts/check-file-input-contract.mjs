import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const sourceRoot = join(process.cwd(), "force-app/main/default");
const failures = [];
const templateObjects = ["Prompt_Template__c", "Prompt_Template_Version__c"];
const policyFields = [
  "File_Input_Mode__c",
  "Maximum_Files__c",
  "Require_File__c",
  "Allowed_File_Formats__c",
  "Provider_Profile_Key__c",
  "File_Citations_Enabled__c"
];
const requiredPaths = [
  "classes/PromptContextFilePolicy.cls",
  "classes/PromptContextFilePolicy.cls-meta.xml",
  "classes/PromptContextFileSelector.cls",
  "classes/PromptContextFileSelector.cls-meta.xml",
  "customPermissions/Prompt_Context_Send_Files.customPermission-meta.xml"
];
const providerFields = [
  "Active__c",
  "Named_Credential__c",
  "Service_Path__c",
  "Bedrock_Region__c",
  "Model_Id__c",
  "Bedrock_Api__c",
  "Endpoint_Class__c",
  "Document_Input_Supported__c",
  "S3_Source_Supported__c",
  "Allowed_File_Formats__c",
  "Maximum_Files__c",
  "Maximum_File_Bytes__c",
  "Maximum_Pdf_Pages__c",
  "Supports_Citations__c",
  "Last_Verified_Date__c",
  "Review_Reference__c"
];

for (const objectName of templateObjects) {
  for (const fieldName of policyFields) {
    const fieldPath = join(
      sourceRoot,
      `objects/${objectName}/fields/${fieldName}.field-meta.xml`
    );
    if (!existsSync(fieldPath)) {
      failures.push(`${objectName} is missing ${fieldName}.`);
    }
  }
}

// All Eligible Files trims to the limit; only a user selection over the limit stops the request.
for (const [objectName, fieldName] of [
  ["Prompt_Template__c", "File_Input_Mode__c"],
  ["Prompt_Template__c", "Maximum_Files__c"],
  ["Prompt_Template_Version__c", "Maximum_Files__c"]
]) {
  const fieldPath = join(
    sourceRoot,
    `objects/${objectName}/fields/${fieldName}.field-meta.xml`
  );
  const helpText = existsSync(fieldPath)
    ? (/<inlineHelpText[^>]*>([\s\S]*?)<\/inlineHelpText>/.exec(
        readFileSync(fieldPath, "utf8")
      )?.[1] ?? "")
    : "";
  if (
    /always stops|without omitting/i.test(helpText) ||
    !helpText.includes("first eligible files")
  ) {
    failures.push(
      `${objectName}.${fieldName} help text must say All Eligible Files uses the first eligible files, up to the limit.`
    );
  }
}

for (const relativePath of requiredPaths) {
  if (!existsSync(join(sourceRoot, relativePath))) {
    failures.push(`Missing file-input component: ${relativePath}.`);
  }
}

for (const fieldName of providerFields) {
  const fieldPath = join(
    sourceRoot,
    `objects/Prompt_Context_Provider__mdt/fields/${fieldName}.field-meta.xml`
  );
  if (!existsSync(fieldPath)) {
    failures.push(`Prompt Context Provider is missing ${fieldName}.`);
  }
}

for (const forbiddenPath of [
  "objects/Prompt_Input_File__c",
  "objects/Prompt_Input_File_Version__c"
]) {
  if (existsSync(join(sourceRoot, forbiddenPath))) {
    failures.push(`${forbiddenPath} must not be added.`);
  }
}

const apiSource = readFileSync(
  join(sourceRoot, "classes/PromptContextInputApi.cls"),
  "utf8"
);
for (const expectedText of ["selectedContentVersionIds", "selectedFilesJson"]) {
  if (!apiSource.includes(expectedText)) {
    failures.push(`PromptContextInputApi.cls must contain ${expectedText}.`);
  }
}

const preparationSource = readFileSync(
  join(sourceRoot, "classes/PromptContextPreparationService.cls"),
  "utf8"
);
for (const expectedText of [
  "PromptContextFilePolicy.selectFiles",
  "selectedFilesJson"
]) {
  if (!preparationSource.includes(expectedText)) {
    failures.push(
      `PromptContextPreparationService.cls must contain ${expectedText}.`
    );
  }
}

const contractSource = readFileSync(
  join(sourceRoot, "classes/PromptContextContract.cls"),
  "utf8"
);
for (const expectedText of [
  "MAX_SELECTED_FILES = 5",
  "MAX_FILE_BYTES",
  "MAX_TOTAL_FILE_BYTES",
  "MAX_LINKED_FILES_INSPECTED = 500",
  "PROVIDER_REVIEW_MAX_AGE_DAYS = 90"
]) {
  if (!contractSource.includes(expectedText)) {
    failures.push(`PromptContextContract.cls must contain ${expectedText}.`);
  }
}

const reasonSource = readFileSync(
  join(sourceRoot, "classes/PromptContextReasonCodes.cls"),
  "utf8"
);
for (const reasonCode of [
  "FILES_NOT_ENABLED",
  "FILE_REQUIRED",
  "TOO_MANY_FILES",
  "TOO_MANY_LINKED_FILES",
  "FILE_TOO_LARGE",
  "TOTAL_FILE_BYTES_EXCEEDED",
  "UNSUPPORTED_FILE_TYPE",
  "FILE_NOT_LINKED_TO_RECORD",
  "FILE_NOT_ACCESSIBLE",
  "FILE_VERSION_STALE"
]) {
  if (!reasonSource.includes(reasonCode)) {
    failures.push(`PromptContextReasonCodes.cls is missing ${reasonCode}.`);
  }
}

if (failures.length > 0) {
  console.error("File input contract checks failed:\n" + failures.join("\n"));
  process.exit(1);
}

console.log("File input contract check passed.");
